#!/usr/bin/env bash
# ==============================================================================
# scripts/convert.sh - Convert upstream obsidian-second-brain to generic naming
# ==============================================================================
# Idempotent. Safe to run after every `git pull upstream main`.
# What it changes:
#   1. _CLAUDE.md         → _AGENTS.md             (all file references)
#   2. ## For future Claude → ## Synopsis           (preamble header)
#   3. future-Claude      → future agent           (every form: Future-Claude,
#      Future Claude, future Claude, future-Claude - all normalize to
#      "future agent" / "Future agent")
#   4. references/claude-md-template.md      → references/agents-md-template.md
#      references/claude-md-assistant-template.md → ...-assistant-template.md
#   5. Template file renames on disk
#
# Usage:
#   bash scripts/convert.sh                        # dry-run (preview only)
#   bash scripts/convert.sh --apply                # apply changes
#   bash scripts/convert.sh --setup                # apply + git assume-unchanged
#   bash scripts/convert.sh --status               # check if conversion is current
#   bash scripts/convert.sh --dry-run              # explicit dry-run (same as default)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

MODE="${1:---dry-run}"
CHANGED=0
WARNINGS=0

# ── File type filters ─────────────────────────────────────────────────────────
EXTENSIONS='\.(md|py|sh|yml|yaml|json|toml|html|cff|txt)$'

declare -a PATTERNS=(
  # File references - _CLAUDE.md → _AGENTS.md
  '_CLAUDE\.md:_AGENTS.md'
  # Preamble header - ## For future Claude → ## Synopsis
  '## For future Claude:## Synopsis'
  # future-Claude (hyphenated, lowercase) → future agent
  'future-Claude:future agent'
  # Future-Claude (hyphenated, capital at sentence start) → Future agent
  'Future-Claude:Future agent'
  # future Claude (space, lowercase) → future agent
  'future Claude:future agent'
  # Future Claude (space, capital) → Future agent
  'Future Claude:Future agent'
)

# ── Template file renames ─────────────────────────────────────────────────────
declare -a TEMPLATE_RENAMES=(
  'references/claude-md-template.md:references/agents-md-template.md'
  'references/claude-md-assistant-template.md:references/agents-md-assistant-template.md'
)

# ── Template reference renames (in file content) ──────────────────────────────
declare -a TEMPLATE_REFS=(
  'claude-md-template:agents-md-template'
  'claude-md-assistant-template:agents-md-assistant-template'
)

# ── Files to exclude from assume-unchanged (our additions) ────────────────────
declare -a OUR_FILES=(
  'adapters/omp/adapter.sh'
  'scripts/convert.sh'
  'FORK_MAINTENANCE.md'
)

# ── Helpers ────────────────────────────────────────────────────────────────────

# Files that belong to us (not upstream transforms) should NOT be assume-unchanged
is_our_file() {
  local rel="$1"
  for f in "${OUR_FILES[@]}"; do
    [[ "$rel" == "$f" ]] && return 0
  done
  return 1
}

# ── Mode: status ───────────────────────────────────────────────────────────────
status_check() {
  local issues=0

  # Check preamble header on a representative file
  local sample=""
  for f in "$REPO_ROOT"/commands/*.md; do
    sample="$f"
    break
  done

  if [[ -f "$sample" ]] && grep -q '## For future Claude' "$sample" 2>/dev/null; then
    warn "Preamble still uses '## For future Claude' - conversion not applied"
    issues=$((issues + 1))
  fi

  # Check file reference
  if [[ -f "$REPO_ROOT/CLAUDE.md" ]] && grep -q 'obsidian-second-brain.*CLAUDE' "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
    # This file is CLAUDE.md itself (the repo's own CLAUDE.md) - its self-ref is fine
    # Check actual _CLAUDE.md references in commands
    if grep -r '_CLAUDE\.md' "$REPO_ROOT/commands" --include='*.md' -q 2>/dev/null; then
      warn "Commands still reference _CLAUDE.md - conversion not applied"
      issues=$((issues + 1))
    fi
  fi

  # Check template names
  if [[ -f "$REPO_ROOT/references/claude-md-template.md" ]]; then
    warn "Template file still at claude-md-template.md - rename not applied"
    issues=$((issues + 1))
  fi

  if [[ $issues -eq 0 ]]; then
    info "Conversion is current."
    return 0
  else
    info "Found $issues issue(s). Run 'bash scripts/convert.sh --apply' to fix."
    return 1
  fi
}

# ── Mode: dry-run / apply ──────────────────────────────────────────────────────

apply_content_renames() {
  local f
  local tmp
  tmp=$(mktemp)

  find "$REPO_ROOT" \
    -path "$REPO_ROOT/.git" -prune -o \
    -path "$REPO_ROOT/dist" -prune -o \
    -path "$REPO_ROOT/scripts/convert.sh" -prune -o \
    -type f -print \
    | while read -r f; do

    # Skip binary/non-text files
    local ext="${f##*.}"
    case "$ext" in
      md|py|sh|yml|yaml|json|toml|html|cff|txt|rb|go|rs) ;;
      *) continue ;;
    esac

    # Skip files that should keep Claude-specific naming intentionally
    local rel="${f#$REPO_ROOT/}"
    case "$rel" in
      CLAUDE.md)            continue ;;  # repo's own operating instructions
      FORK_MAINTENANCE.md)  continue ;;  # talks about the conversion literally
      *.github/*)           ;;           # don't skip
      _includes/*)          ;;           # don't skip
      llms.txt)             ;;           # don't skip
      *) ;;
    esac

    cp "$f" "$tmp"

    # Apply content patterns
    for entry in "${PATTERNS[@]}"; do
      local old="${entry%%:*}"
      local new="${entry##*:}"
      if grep -q "$old" "$tmp" 2>/dev/null; then
        if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
          # sed -i portably
          sed -i '' "s/$old/$new/g" "$tmp" 2>/dev/null || true
        fi
        dirty=1
      fi
    done

    # Apply template reference renames
    for entry in "${TEMPLATE_REFS[@]}"; do
      local old="${entry%%:*}"
      local new="${entry##*:}"
      if grep -q "$old" "$tmp" 2>/dev/null; then
        if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
          sed -i '' "s/$old/$new/g" "$tmp" 2>/dev/null || true
        fi
        dirty=1
      fi
    done

    if [[ $dirty -eq 1 ]]; then
      if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
        cp "$tmp" "$f"
      fi
      echo "  $rel"
      CHANGED=$((CHANGED + 1))
    fi
  done

  rm -f "$tmp"
}

apply_template_renames() {
  for entry in "${TEMPLATE_RENAMES[@]}"; do
    local src="$REPO_ROOT/${entry%%:*}"
    local dst="$REPO_ROOT/${entry##*:}"
    if [[ -f "$src" ]]; then
      if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
        mkdir -p "$(dirname "$dst")"
        mv "$src" "$dst"
      fi
      echo "  ${entry%%:*} → ${entry##*:}"
      CHANGED=$((CHANGED + 1))
    fi
  done
}

apply_example_rename() {
  local old="$REPO_ROOT/examples/sample-vault/_CLAUDE.md"
  local new="$REPO_ROOT/examples/sample-vault/_AGENTS.md"
  if [[ -f "$old" ]]; then
    if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
      mv "$old" "$new"
    fi
    echo "  examples/sample-vault/_CLAUDE.md → _AGENTS.md"
    CHANGED=$((CHANGED + 1))
  fi
}

# ── Setup: git assume-unchanged ───────────────────────────────────────────────
setup_git_assume_unchanged() {
  info "Setting up git assume-unchanged for converted files..."
  local count=0 f flags ext

  # Read tracked files into array (avoids subshell pipe issue)
  local -a tracked=()
  while IFS= read -r f; do tracked+=("$f"); done < <(git -C "$REPO_ROOT" ls-files)

  for f in "${tracked[@]}"; do
    # Skip our own files
    is_our_file "$f" && continue

    # Check extension
    ext="${f##*.}"
    case "$ext" in
      md|py|sh|yml|yaml|json|toml|html|cff|txt) ;;
      *) continue ;;
    esac

    # Check if already assume-unchanged (flags char is 'h')
    flags=$(git -C "$REPO_ROOT" ls-files -v "$f" 2>/dev/null)
    [[ "${flags:0:1}" == "h" ]] && continue

    git -C "$REPO_ROOT" update-index --assume-unchanged "$f"
    count=$((count + 1))
  done

  info "Marked $count files as assume-unchanged."
  info "To unmark: git -C $REPO_ROOT update-index --no-assume-unchanged <file>"
  info "To see all: git -C $REPO_ROOT ls-files -v | grep '^h'"
}

# ── Main ───────────────────────────────────────────────────────────────────────

case "$MODE" in
  --status)
    status_check
    exit $?
    ;;

  --setup)
    MODE="--apply"
    apply_content_renames
    apply_template_renames
    apply_example_rename
    setup_git_assume_unchanged
    ;;

  --apply)
    info "Applying conversion..."
    apply_content_renames
    apply_template_renames
    apply_example_rename
    ;;

  --dry-run|-h|--help|*)
    if [[ "$MODE" != "--dry-run" ]]; then
      cat <<'EOF'
Usage:
  bash scripts/convert.sh                        # dry-run (default)
  bash scripts/convert.sh --dry-run              # explicit dry-run
  bash scripts/convert.sh --apply                # apply all renames
  bash scripts/convert.sh --setup                # apply + git assume-unchanged
  bash scripts/convert.sh --status               # check if conversion is current
EOF
      exit 0
    fi
    info "Dry-run - files that would change:"
    apply_content_renames
    apply_template_renames
    apply_example_rename
    ;;
esac

if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
  info "Done. $CHANGED files changed."
  if [[ $WARNINGS -gt 0 ]]; then
    warn "$WARNINGS warnings."
  fi
else
  if [[ $CHANGED -eq 0 ]]; then
    info "No changes needed - conversion is current."
  else
    info "Would change $CHANGED file(s). Run with --apply to apply."
  fi
fi

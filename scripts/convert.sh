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
#   6. ~/Projects/personal/obsidian-second-brain/ → neutral instruction
#      (pyproject.toml + uv.lock symlinked into vault, so uv run works from vault CWD)
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

# Literal content replacements. Keep these as plain strings, not regexes.
declare -a CONTENT_REPLACEMENTS=(
  # File references - _CLAUDE.md → _AGENTS.md
  '_CLAUDE.md:_AGENTS.md'
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
  # Bootstrap template strings - bare "Claude" as generic agent reference
  'Claude Operating Manual:Vault Operating Manual'
  'Claude should auto-save:The agent should auto-save'
  'Claude should **ask**:The agent should **ask**'
  'Claude automatically saves:The agent automatically saves'
  'Claude will read it:the agent will read it'
  'Claude, update my _AGENTS.md:update my _AGENTS.md'
)

# Hardcoded author repo path - replaced with neutral instruction
# pyproject.toml and uv.lock are symlinked into the vault by setup.sh
# so uv run -m works from the vault directory directly.
declare -a REPO_PATH_PATTERNS=(
  'Run the Python command from the repo root:Run the Python research command'
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
  '.gitignore'
  'AGENTS.md'
  'FORK_MAINTENANCE.md'
  'FORK_TODO.md'
  'adapters/omp/adapter.sh'
  'commands/obsidian-distill.md'
  'install.sh'
  'scripts/__init__.py'
  'scripts/build.sh'
  'scripts/convert.sh'
  'scripts/setup.sh'
)

# ── Helpers ────────────────────────────────────────────────────────────────────

# Files that belong to us (not upstream transforms) should NOT be assume-unchanged
is_our_file() {
  local rel="$1"
  local f
  for f in "${OUR_FILES[@]}"; do
    [[ "$rel" == "$f" ]] && return 0
  done
  return 1
}

assert_no_hidden_our_files() {
  local hidden=()
  local f flags

  for f in "${OUR_FILES[@]}"; do
    flags=$(git -C "$REPO_ROOT" ls-files -v -- "$f" 2>/dev/null || true)
    if [[ -n "$flags" && "${flags:0:1}" == "h" ]]; then
      hidden+=("$f")
    fi
  done

  if [[ ${#hidden[@]} -gt 0 ]]; then
    warn "Fork-owned files are assume-unchanged:"
    for f in "${hidden[@]}"; do
      warn "  $f"
    done
    die "Run: git update-index --no-assume-unchanged <path>"
  fi
}

is_tracked_path() {
  git -C "$REPO_ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

replace_literal_in_file() {
  local path="$1"
  local old="$2"
  local new="$3"

  python3 - "$path" "$old" "$new" <<'PY'
import sys

path, old, new = sys.argv[1:]
with open(path, "r", encoding="utf-8", newline="") as handle:
    data = handle.read()
data = data.replace(old, new)
with open(path, "w", encoding="utf-8", newline="") as handle:
    handle.write(data)
PY
}

apply_literal_replacements() {
  local path="$1"
  local entry old new

  for entry in "${CONTENT_REPLACEMENTS[@]}"; do
    old="${entry%%:*}"
    new="${entry#*:}"
    replace_literal_in_file "$path" "$old" "$new"
  done

  for entry in "${REPO_PATH_PATTERNS[@]}"; do
    old="${entry%%:*}"
    new="${entry#*:}"
    replace_literal_in_file "$path" "$old" "$new"
  done

  for entry in "${TEMPLATE_REFS[@]}"; do
    old="${entry%%:*}"
    new="${entry#*:}"
    replace_literal_in_file "$path" "$old" "$new"
  done
}

make_converted_temp() {
  local path="$1"
  local tmp
  tmp=$(mktemp)
  cp "$path" "$tmp"
  apply_literal_replacements "$tmp"

  if cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 1
  fi

  printf '%s\n' "$tmp"
}

atomic_replace_file() {
  local src="$1"
  local dst="$2"

  python3 - "$src" "$dst" <<'PY'
import os
import shutil
import sys
import tempfile

src, dst = sys.argv[1:]
directory = os.path.dirname(dst) or "."
fd, tmp = tempfile.mkstemp(prefix=f".{os.path.basename(dst)}.", dir=directory)
os.close(fd)
try:
    shutil.copyfile(src, tmp)
    shutil.copystat(dst, tmp)
    os.replace(tmp, dst)
except Exception:
    try:
        os.unlink(tmp)
    except FileNotFoundError:
        pass
    raise
PY
}

rename_destination_for_source() {
  local rel="$1"
  local entry src dst

  for entry in "${TEMPLATE_RENAMES[@]}"; do
    src="${entry%%:*}"
    dst="${entry#*:}"
    if [[ "$rel" == "$src" ]]; then
      printf '%s\n' "$dst"
      return 0
    fi
  done

  if [[ "$rel" == "examples/sample-vault/_CLAUDE.md" ]]; then
    printf '%s\n' "examples/sample-vault/_AGENTS.md"
    return 0
  fi

  return 1
}

path_is_expected_conversion() {
  local rel="$1"
  local dst head_tmp converted_tmp rc

  is_our_file "$rel" && return 1
  is_tracked_path "$rel" || return 1

  if dst=$(rename_destination_for_source "$rel"); then
    [[ ! -e "$REPO_ROOT/$rel" && -e "$REPO_ROOT/$dst" ]] && return 0
    return 1
  fi

  [[ -f "$REPO_ROOT/$rel" ]] || return 1

  head_tmp=$(mktemp)
  if ! git -C "$REPO_ROOT" show "HEAD:$rel" >"$head_tmp" 2>/dev/null; then
    rm -f "$head_tmp"
    return 1
  fi

  if converted_tmp=$(make_converted_temp "$head_tmp"); then
    if cmp -s "$converted_tmp" "$REPO_ROOT/$rel"; then
      rc=0
    else
      rc=1
    fi
    rm -f "$converted_tmp" "$head_tmp"
    return "$rc"
  fi

  rm -f "$head_tmp"
  return 1
}

add_unique_candidate() {
  local list_name="$1"
  local candidate="$2"
  local existing count i
  eval "count=\${#${list_name}[@]}"
  i=0
  while [[ "$i" -lt "$count" ]]; do
    eval "existing=\${${list_name}[$i]}"
    [[ "$existing" == "$candidate" ]] && return 0
    i=$((i + 1))
  done
  eval "${list_name}+=(\"\$candidate\")"
}

path_in_list() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
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

  if grep -r '_CLAUDE\.md' "$REPO_ROOT/commands" --include='*.md' -q 2>/dev/null; then
    warn "Commands still reference _CLAUDE.md - conversion not applied"
    issues=$((issues + 1))
  fi

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
  local f ext rel converted_tmp

  while IFS= read -r f; do
    ext="${f##*.}"
    case "$ext" in
      md|py|sh|yml|yaml|json|toml|html|cff|txt|rb|go|rs) ;;
      *) continue ;;
    esac

    rel="${f#$REPO_ROOT/}"
    case "$rel" in
      CLAUDE.md)            continue ;;
      FORK_MAINTENANCE.md)  continue ;;
      *.github/*)           ;;
      _includes/*)          ;;
      llms.txt)             ;;
      *) ;;
    esac

    if converted_tmp=$(make_converted_temp "$f"); then
      if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
        atomic_replace_file "$converted_tmp" "$f"
      fi
      rm -f "$converted_tmp"
      echo "  $rel"
      CHANGED=$((CHANGED + 1))
    fi
  done < <(
    find "$REPO_ROOT" \
      -path "$REPO_ROOT/.git" -prune -o \
      -path "$REPO_ROOT/.venv" -prune -o \
      -path "$REPO_ROOT/dist" -prune -o \
      -path "$REPO_ROOT/scripts/convert.sh" -prune -o \
      -type f -print
  )
}

apply_template_renames() {
  local entry src dst rel_src rel_dst
  for entry in "${TEMPLATE_RENAMES[@]}"; do
    rel_src="${entry%%:*}"
    rel_dst="${entry#*:}"
    src="$REPO_ROOT/$rel_src"
    dst="$REPO_ROOT/$rel_dst"
    if [[ -f "$src" ]]; then
      if [[ "$MODE" == "--apply" ]] || [[ "$MODE" == "--setup" ]]; then
        mkdir -p "$(dirname "$dst")"
        mv "$src" "$dst"
      fi
      echo "  $rel_src -> $rel_dst"
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
    echo "  examples/sample-vault/_CLAUDE.md -> _AGENTS.md"
    CHANGED=$((CHANGED + 1))
  fi
}

setup_git_assume_unchanged() {
  info "Setting up git assume-unchanged for converted files..."
  assert_no_hidden_our_files

  local entry flag path state rel_src count=0 stale=0 missing=0
  local -a candidates=()
  local -a status_candidates=()

  while IFS= read -r -d '' entry; do
    flag="${entry:0:1}"
    path="${entry:2}"
    [[ "$flag" == "h" ]] || continue
    is_our_file "$path" && continue

    if path_is_expected_conversion "$path"; then
      add_unique_candidate candidates "$path"
    else
      git -C "$REPO_ROOT" update-index --no-assume-unchanged "$path"
      warn "Unmarked non-conversion assume-unchanged path: $path"
      stale=$((stale + 1))
    fi
  done < <(git -C "$REPO_ROOT" -c core.quotepath=false ls-files -z -v)

  while IFS= read -r -d '' entry; do
    state="${entry:0:2}"
    path="${entry:3}"
    [[ "$state" == *M* || "$state" == *D* ]] || continue
    add_unique_candidate candidates "$path"
    add_unique_candidate status_candidates "$path"
  done < <(git -C "$REPO_ROOT" -c core.quotepath=false status --porcelain -z)

  for entry in "${TEMPLATE_RENAMES[@]}"; do
    rel_src="${entry%%:*}"
    add_unique_candidate candidates "$rel_src"
  done
  add_unique_candidate candidates "examples/sample-vault/_CLAUDE.md"

  for path in "${candidates[@]}"; do
    is_our_file "$path" && continue
    if path_is_expected_conversion "$path"; then
      flag=$(git -C "$REPO_ROOT" ls-files -v -- "$path" 2>/dev/null || true)
      if [[ -n "$flag" && "${flag:0:1}" != "h" ]]; then
        git -C "$REPO_ROOT" update-index --assume-unchanged "$path"
        count=$((count + 1))
      fi
    elif [[ "${#status_candidates[@]}" -gt 0 ]] && path_in_list "$path" "${status_candidates[@]}"; then
      warn "Not marking non-conversion change: $path"
    fi
  done

  assert_no_hidden_our_files

  while IFS= read -r -d '' entry; do
    state="${entry:0:2}"
    path="${entry:3}"
    [[ "$state" == *M* || "$state" == *D* ]] || continue
    is_our_file "$path" && continue
    if path_is_expected_conversion "$path"; then
      warn "Expected conversion was not marked assume-unchanged: $path"
      missing=$((missing + 1))
    fi
  done < <(git -C "$REPO_ROOT" -c core.quotepath=false status --porcelain -z)

  if [[ $missing -gt 0 ]]; then
    die "Expected converted paths remain visible after assume-unchanged setup."
  fi

  info "Marked $count converted file(s) as assume-unchanged."
}

# ── Main ───────────────────────────────────────────────────────────────────────

case "$MODE" in
  --status)
    status_check
    exit $?
    ;;

  --setup)
    assert_no_hidden_our_files
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

echo "Done. $CHANGED file(s) affected."

#!/usr/bin/env bash
# setup.sh - obsidian-second-brain one-command installer
#
# Usage:
#   bash scripts/setup.sh "/path/to/your/vault"              # Claude Code (default)
#   bash scripts/setup.sh --platform omp "/path/to/your/vault"  # Oh My Pi
#
# What it does (Claude Code):
#   1. Validates the vault path
#   2. Adds OBSIDIAN_VAULT_PATH to ~/.claude/settings.json
#   3. Wires the PostCompact background agent hook
#   4. Makes the hook script executable
#   5. Registers slash commands in ~/.claude/commands/
#   6. Configures the MCP server for Claude Code (optional)
#
# What it does (Oh My Pi):
#   1. Validates the vault path
#   2. Adds OBSIDIAN_VAULT_PATH to ~/.omp/agent/config.json
#   3. Links skill into ~/.omp/agent/skills/

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$HOME/.config/obsidian-second-brain/.env"

# ── parse args ────────────────────────────────────────────────────────────────
PLATFORM="claude"
VAULT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/setup.sh [--platform claude|omp] <vault-path>

Without --platform, defaults to Claude Code.
  claude - Claude Code (settings.json, hooks, slash commands, MCP)
  omp    - Oh My Pi     (config.json, skill link, no hooks)
EOF
      exit 0
      ;;
    *) VAULT="$1"; shift ;;
  esac
done

case "$PLATFORM" in
  claude|omp) ;;
  *) echo "Unknown platform: $PLATFORM (use: claude or omp)"; exit 1 ;;
esac

# ── helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
step()   { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ── vault path ───────────────────────────────────────────────────────────────

if [[ -z "$VAULT" ]]; then
  echo "Usage: $0 [--platform claude|omp] <path-to-obsidian-vault>"
  echo "  --platform omp   install for Oh My Pi (default: Claude Code)"
  exit 1
fi

VAULT="${VAULT/#\~/$HOME}"  # expand leading ~

if [[ ! -d "$VAULT" ]]; then
  red "Vault path not found or not a directory: $VAULT"
  exit 1
fi

echo ""
echo "obsidian-second-brain setup"
echo "==========================="
echo "Vault:    $VAULT"
echo "Skill:    $SKILL_DIR"
echo "Platform: $PLATFORM"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# CLAUDE CODE
# ══════════════════════════════════════════════════════════════════════════════
if [ "$PLATFORM" = "claude" ]; then

SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$SKILL_DIR/hooks/obsidian-bg-agent.sh"
SESSION_HOOK="$SKILL_DIR/hooks/load_vault_context.py"

# ── make hook executable ──────────────────────────────────────────────────────
step "1. Making hook scripts executable..."
chmod +x "$HOOK_SCRIPT"
[[ -f "$SESSION_HOOK" ]] && chmod +x "$SESSION_HOOK"
green "   Done - $HOOK_SCRIPT"
green "   Done - $SESSION_HOOK"

# ── ensure settings.json exists ───────────────────────────────────────────────
step "2. Updating ~/.claude/settings.json..."

if [[ ! -f "$SETTINGS" ]]; then
  mkdir -p "$(dirname "$SETTINGS")"
  echo '{}' > "$SETTINGS"
fi

# Validate JSON
if ! jq empty "$SETTINGS" 2>/dev/null; then
  red "   ~/.claude/settings.json is not valid JSON. Fix or delete it, then re-run."
  exit 1
fi

# ── add env var ───────────────────────────────────────────────────────────────
jq --arg vault "$VAULT" '
  .env = (.env // {}) | .env.OBSIDIAN_VAULT_PATH = $vault
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
green "   OBSIDIAN_VAULT_PATH set"

# Wire the vault path into the research toolkit .env so standalone runs resolve it
if [ -f "$ENV_FILE" ]; then
  if ! grep -q 'OBSIDIAN_VAULT_PATH' "$ENV_FILE" 2>/dev/null; then
    echo "OBSIDIAN_VAULT_PATH=$VAULT" >> "$ENV_FILE"
    green "   OBSIDIAN_VAULT_PATH added to $ENV_FILE"
  fi
fi

# ── add PostCompact hook ──────────────────────────────────────────────────────
step "3. Adding PostCompact background agent hook..."

HOOK_CMD="$HOOK_SCRIPT"

# Check if hook already exists
EXISTING=$(jq -r '
  .hooks.PostCompact // [] |
  .[].hooks // [] |
  .[].command // ""
' "$SETTINGS" 2>/dev/null | grep -F "$HOOK_CMD" || true)

if [[ -n "$EXISTING" ]]; then
  green "   PostCompact hook already wired - skipping"
else
  jq --arg cmd "$HOOK_CMD" '
    .hooks.PostCompact = (.hooks.PostCompact // [])
    | .hooks.PostCompact += [{"hooks": [{"command": $cmd}]}]
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  green "   Added: PostCompact → $HOOK_CMD"
fi

# ── add SessionStart hook ────────────────────────────────────────────────────
SESSION_HOOK_CMD="python3 $SESSION_HOOK"

EXISTING_SESSION=$(jq -r '
  .hooks.SessionStart // [] |
  .[].hooks // [] |
  .[].command // ""
' "$SETTINGS" 2>/dev/null | grep -F "$SESSION_HOOK" || true)

if [[ -n "$EXISTING_SESSION" ]]; then
  green "   SessionStart hook already wired - skipping"
else
  jq --arg cmd "$SESSION_HOOK_CMD" '
    .hooks.SessionStart = (.hooks.SessionStart // [])
    | .hooks.SessionStart += [{"hooks": [{"command": $cmd}]}]
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  green "   Added: SessionStart → $SESSION_HOOK_CMD"
fi

# ── register slash commands ──────────────────────────────────────────────────
step "4. Registering slash commands in ~/.claude/commands/..."

COMMANDS_SRC="$SKILL_DIR/commands"
COMMANDS_DST="$HOME/.claude/commands"

if [[ ! -d "$COMMANDS_SRC" ]]; then
  yellow "   No commands/ directory found at $COMMANDS_SRC - git clone the full repo?"
else
  mkdir -p "$COMMANDS_DST"
  count=0
  for cmd in "$COMMANDS_SRC"/*.md; do
    [[ -f "$cmd" ]] || continue
    name=$(basename "$cmd")
    link="$COMMANDS_DST/$name"

    if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "$cmd" ]]; then
      continue  # already pointing here
    fi

    # Remove stale link/file
    [[ -e "$link" || -L "$link" ]] && rm -f "$link"

    ln -s "$cmd" "$link"
    count=$((count + 1))
  done
  green "   Linked $count commands into $COMMANDS_DST"
fi

# ── optional: MCP server (Claude Code only) ───────────────────────────────────
step "5. MCP server (optional - Claude Code only)..."
echo "   The obsidian-vault MCP server gives Claude faster vault access."
echo "   Without it, Claude reads/writes vault files directly (works fine)."
echo ""
REPLY=n
if [[ -t 0 ]]; then
  read -r -p "   Configure MCP server for Claude Code? [y/N] " REPLY
fi
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo ""
  echo "   Claude Code MCP config is at ~/.claude/.claude.json or project .claude.json"
  echo "   Add to the mcp_servers block:"
  echo ""
  echo '   {'
  echo '     "mcp_servers": {'
  echo '       "obsidian-vault": {'
  echo '         "command": "cmd or uvx",'
  echo '         "args": ["obsidian-vault-mcp"],'
  echo '         "env": {'
  echo '           "OBSIDIAN_VAULT_PATH": "'"$VAULT"'"'
  echo '         }'
  echo '       }'
  echo '     }'
  echo '   }'
  echo ""
  echo "   See github.com/ohmypi/obsidian-vault-mcp-server for installation."
fi

# ── done (claude) ─────────────────────────────────────────────────────────────
echo ""
echo "==========================="
green "Setup complete."
echo ""
echo "Next step: Open Claude Code in your vault directory and run:"
echo ""
echo "   /obsidian-init"
echo ""
echo "That's it. Claude will scan your vault and generate its operating manual."
echo ""
echo "Background agent logs: /tmp/obsidian-bg-agent.log"
echo "Health check:          python scripts/vault_health.py --path \"$VAULT\""
echo ""

fi # ── end claude ──

# ══════════════════════════════════════════════════════════════════════════════
# OH MY PI
# ══════════════════════════════════════════════════════════════════════════════
if [ "$PLATFORM" = "omp" ]; then

OMP_CONFIG="$HOME/.omp/agent/config.json"
OMP_SKILLS_DIR="$HOME/.omp/agent/skills"

# ── add env var to OMP config ─────────────────────────────────────────────────
step "1. Updating ~/.omp/agent/config.json..."

mkdir -p "$(dirname "$OMP_CONFIG")"

if [[ ! -f "$OMP_CONFIG" ]]; then
  echo '{}' > "$OMP_CONFIG"
fi

if ! jq empty "$OMP_CONFIG" 2>/dev/null; then
  red "   ~/.omp/agent/config.json is not valid JSON. Fix or delete it, then re-run."
  exit 1
fi

jq --arg vault "$VAULT" '
  .env = (.env // {}) | .env.OBSIDIAN_VAULT_PATH = $vault
' "$OMP_CONFIG" > "$OMP_CONFIG.tmp" && mv "$OMP_CONFIG.tmp" "$OMP_CONFIG"
green "   OBSIDIAN_VAULT_PATH set in $OMP_CONFIG"

# Wire into research toolkit .env
if [ -f "$ENV_FILE" ]; then
  if ! grep -q 'OBSIDIAN_VAULT_PATH' "$ENV_FILE" 2>/dev/null; then
    echo "OBSIDIAN_VAULT_PATH=$VAULT" >> "$ENV_FILE"
    green "   OBSIDIAN_VAULT_PATH added to $ENV_FILE"
  fi
fi

# ── link skill ────────────────────────────────────────────────────────────────
step "2. Linking skill into ~/.omp/agent/skills/..."

mkdir -p "$OMP_SKILLS_DIR"
OMP_LINK="$OMP_SKILLS_DIR/obsidian-second-brain"

if [[ -L "$OMP_LINK" ]] && [[ "$(readlink "$OMP_LINK")" == "$SKILL_DIR" ]]; then
  green "   Skill already linked"
elif [[ -d "$OMP_LINK" ]]; then
  yellow "   $OMP_LINK is a directory - remove it first or move it, then re-run."
  exit 1
else
  ln -s "$SKILL_DIR" "$OMP_LINK"
  green "   Linked → $OMP_LINK"
fi

# ── done (omp) ────────────────────────────────────────────────────────────────
echo ""
echo "==========================="
green "Setup complete."
echo ""
echo "Your OMP agent will load the skill on the next session."
echo "Run /obsidian-init from within the vault to generate _AGENTS.md."
echo ""
echo "Health check: python scripts/vault_health.py --path \"$VAULT\""
echo ""

fi # ── end omp ──

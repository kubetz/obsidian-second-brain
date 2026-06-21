#!/bin/bash

set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SKILLS_DIR="$CLAUDE_DIR/skills"
OMP_SKILLS_DIR="$HOME/.omp/agent/skills"
CONFIG_DIR="$HOME/.config/obsidian-second-brain"
ENV_FILE="$CONFIG_DIR/.env"
INSTALL_TARGET="${1:-claude}"  # claude (default) or omp

echo "Installing obsidian-second-brain..."

case "$INSTALL_TARGET" in
  claude) echo "  Target: Claude Code" ;;
  omp)    echo "  Target: Oh My Pi (~/.omp/agent/skills/)" ;;
  *)      echo "  Unknown target: $INSTALL_TARGET (use: claude or omp)"; exit 1 ;;
esac
echo ""

# Create directories if needed
mkdir -p "$COMMANDS_DIR"
mkdir -p "$SKILLS_DIR"
mkdir -p "$OMP_SKILLS_DIR"

# Detect platform once
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_WINDOWS=0 ;;
esac

build_platform_dist() {
  platform="$1"
  bash "$SKILL_DIR/scripts/build.sh" --platform "$platform"
}
LEGACY_COMMANDS_SRC="$SKILL_DIR"
LEGACY_COMMANDS_SRC="$LEGACY_COMMANDS_SRC/commands"


# ── Claude Code install ───────────────────────────────────────────────
if [ "$INSTALL_TARGET" = "claude" ]; then

build_platform_dist claude-code
DIST_DIR="$SKILL_DIR/dist/claude-code"

# Link commands into ~/.claude/commands/ (copy on Windows without Developer Mode)
echo "Installing slash commands..."
COMMANDS_SRC="$DIST_DIR/commands"
COMMANDS_COPIED=0
for file in "$COMMANDS_SRC/"*.md; do
  name=$(basename "$file")
  dest="$COMMANDS_DIR/$name"
  if [ -L "$dest" ]; then
    link_target=$(readlink "$dest")
    case "$link_target" in
      "$LEGACY_COMMANDS_SRC/$name"|"$SKILL_DIR"/dist/*/commands/"$name") rm "$dest" ;;
    esac
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "  skipping $name (already exists)"
  elif [ "$IS_WINDOWS" -eq 0 ]; then
    ln -s "$file" "$dest"
    echo "  linked $name"
  elif MSYS=winsymlinks:nativestrict ln -s "$file" "$dest" 2>/dev/null; then
    echo "  linked $name"
  else
    cp "$file" "$dest"
    COMMANDS_COPIED=1
    echo "  installed $name"
  fi
done
if [ "$COMMANDS_COPIED" -eq 1 ]; then
  echo "  (symlinks require Developer Mode - commands were copied; run update.sh to refresh)"
fi

# Link skill into ~/.claude/skills/
SKILL_LINK="$SKILLS_DIR/obsidian-second-brain"
if [ -L "$SKILL_LINK" ]; then
  link_target=$(readlink "$SKILL_LINK")
  case "$link_target" in
    "$SKILL_DIR"|"$SKILL_DIR"/dist/*) rm "$SKILL_LINK" ;;
  esac
fi
if [ -e "$SKILL_LINK" ] || [ -L "$SKILL_LINK" ]; then
  echo "Skill already linked at $SKILL_LINK"
elif [ "$IS_WINDOWS" -eq 0 ]; then
  ln -s "$DIST_DIR" "$SKILL_LINK"
  echo "Skill linked at $SKILL_LINK"
else
  if MSYS=winsymlinks:nativestrict ln -s "$DIST_DIR" "$SKILL_LINK" 2>/dev/null; then
    echo "Skill linked at $SKILL_LINK"
  else
    cp -R "$DIST_DIR" "$SKILL_LINK"
    echo "Skill copied to $SKILL_LINK"
  fi
fi

echo ""
echo "Done. Restart Claude Code to activate the commands."

fi

# ── Oh My Pi install ───────────────────────────────────────────────────
if [ "$INSTALL_TARGET" = "omp" ]; then

build_platform_dist omp
DIST_DIR="$SKILL_DIR/dist/omp"
bash "$SKILL_DIR/scripts/convert.sh" --dist "$DIST_DIR"

OMP_LINK="$OMP_SKILLS_DIR/obsidian-second-brain"
if [ -L "$OMP_LINK" ]; then
  link_target=$(readlink "$OMP_LINK")
  case "$link_target" in
    "$SKILL_DIR"|"$SKILL_DIR"/dist/*) rm "$OMP_LINK" ;;
  esac
fi
if [ -e "$OMP_LINK" ] || [ -L "$OMP_LINK" ]; then
  echo "Skill already linked at $OMP_LINK"
elif [ "$IS_WINDOWS" -eq 0 ]; then
  ln -s "$DIST_DIR" "$OMP_LINK"
  echo "Skill linked at $OMP_LINK"
else
  if MSYS=winsymlinks:nativestrict ln -s "$DIST_DIR" "$OMP_LINK" 2>/dev/null; then
    echo "Skill linked at $OMP_LINK"
  else
    cp -R "$DIST_DIR" "$OMP_LINK"
    echo "Skill copied to $OMP_LINK"
  fi
fi

# Also symlink commands into OMP's command path
OMP_COMMANDS_DIR="$HOME/.omp/commands"
mkdir -p "$OMP_COMMANDS_DIR"
for file in "$DIST_DIR/.omp/commands/"*.md; do
  name=$(basename "$file")
  dest="$OMP_COMMANDS_DIR/$name"
  if [ -L "$dest" ]; then
    link_target=$(readlink "$dest")
    case "$link_target" in
      "$LEGACY_COMMANDS_SRC/$name"|"$SKILL_DIR"/dist/*/.omp/commands/"$name") rm "$dest" ;;
    esac
  fi
  [ -e "$dest" ] || [ -L "$dest" ] && continue
  ln -s "$file" "$dest"
done
echo "Commands linked into ~/.omp/commands/"

echo ""
echo "Done. Your OMP agent will load the skill on the next session."

fi
# ── Research toolkit setup (optional) ──────────────────────────────
echo ""
echo "Research toolkit (optional): /x-read, /x-pulse, /research, /research-deep, /youtube"
echo "These commands need API keys for Grok (xAI) and Perplexity. YouTube key is optional."
echo ""
read -r -p "Set up research toolkit now? [y/N] " setup_research
setup_research=${setup_research:-N}

if [[ "$setup_research" =~ ^[Yy]$ ]]; then
  # Verify uv is available
  if ! command -v uv >/dev/null 2>&1; then
    case "$(uname -s)" in
      Darwin)               uv_hint="brew install uv" ;;
      Linux)                uv_hint="curl -LsSf https://astral.sh/uv/install.sh | sh" ;;
      MINGW*|MSYS*|CYGWIN*) uv_hint="powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\"" ;;
      *)                    uv_hint="see https://docs.astral.sh/uv/getting-started/installation/" ;;
    esac
    echo "  ⚠️  'uv' not found. Install with: $uv_hint"
    echo "     Then re-run this installer to finish research toolkit setup."
  else
    echo "  Installing Python deps via uv..."
    (cd "$SKILL_DIR" && uv sync --quiet)
    echo "  Python deps ready."
  fi

  # Set up config dir + .env
  mkdir -p "$CONFIG_DIR"
  if [ -f "$ENV_FILE" ]; then
    echo "  $ENV_FILE already exists - leaving it untouched."
  else
    cp "$SKILL_DIR/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "  Created $ENV_FILE (permissions 600)."
  fi

  echo ""
  echo "  Now paste your API keys into: $ENV_FILE"
  echo "    XAI_API_KEY=          (https://console.x.ai)"
  echo "    PERPLEXITY_API_KEY=   (https://perplexity.ai/settings/api)"
  echo "    YOUTUBE_API_KEY=      (https://console.cloud.google.com - optional)"
  echo ""
  read -r -p "  Press Enter to open the file in your default editor (or Ctrl+C to skip)... " _
  default_editor=open
  case "$(uname -s)" in
    Linux)                default_editor=xdg-open ;;
    MINGW*|MSYS*|CYGWIN*) default_editor=notepad ;;
  esac
  ${EDITOR:-$default_editor} "$ENV_FILE"
fi


# ── Common: next steps ────────────────────────────────────────────────
echo ""
echo "Next steps:"
echo "  1. Run /obsidian-init to generate your vault's _AGENTS.md"
echo "  2. (If research toolkit installed) Verify keys: cat $ENV_FILE"
echo ""

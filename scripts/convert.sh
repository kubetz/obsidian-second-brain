#!/usr/bin/env bash
# ==============================================================================
# scripts/convert.sh - Dist-only naming neutralization
# ==============================================================================
# Source files stay upstream-canonical. This helper rewrites generated dist trees
# after adapter-specific build output has been copied.
#
# Usage:
#   bash scripts/convert.sh --dist <dist-dir>
#   bash scripts/convert.sh --help
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"


usage() {
  cat <<'EOF'
Usage:
  bash scripts/convert.sh --dist <dist-dir>
  bash scripts/convert.sh --help

Neutralizes generated dist output. Source files remain upstream-canonical.
EOF
}

DIST_DIR=""


while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --dist)
      shift
      [[ $# -gt 0 ]] || die "--dist requires a path"
      DIST_DIR="$1"
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

[[ -n "$DIST_DIR" ]] || die "Missing required --dist <dist-dir>"

if [[ ! -d "$DIST_DIR" ]]; then
  die "Dist directory not found: $DIST_DIR"
fi

CANONICAL_DIST_DIR="$(python3 - "$DIST_DIR" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
)"
CANONICAL_DIST_ROOT="$(python3 - "$REPO_ROOT/dist" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
)"

case "$CANONICAL_DIST_DIR" in
  "$CANONICAL_DIST_ROOT"|"$CANONICAL_DIST_ROOT"/*) ;;
  *) die "Refusing to neutralize outside dist/: $DIST_DIR" ;;
esac

SUMMARY_DIST_PATH="$(python3 - "$CANONICAL_DIST_ROOT" "$CANONICAL_DIST_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
path = Path(sys.argv[2])
rel = path.relative_to(root)
print("dist" if str(rel) == "." else f"dist/{rel}")
PY
)"


COUNTS="$(python3 - "$CANONICAL_DIST_DIR" <<'PY'
from pathlib import Path
import os
import shutil
import sys
import tempfile

dist = Path(sys.argv[1])

suffixes = {'.md', '.py', '.sh', '.yml', '.yaml', '.json', '.toml', '.html', '.cff', '.txt', '.rb', '.go', '.rs'}
replacements = [
    ('_CLAUDE.md', '_AGENTS.md'),
    ('## For future Claude', '## Synopsis'),
    ('Follow: For future Claude, Core concepts', 'Follow: Synopsis, Core concepts'),
    ('future-Claude', 'future agent'),
    ('Future-Claude', 'Future agent'),
    ('future Claude', 'future agent'),
    ('Future Claude', 'Future agent'),
    ('Claude Operating Manual', 'Vault Operating Manual'),
    ('Claude should auto-save', 'The agent should auto-save'),
    ('Claude should **ask**', 'The agent should **ask**'),
    ('Claude automatically saves', 'The agent automatically saves'),
    ('Claude will read it', 'the agent will read it'),
    ('Claude, update my _AGENTS.md', 'update my _AGENTS.md'),
    ('Run the Python command from the repo root', 'Run the Python research command'),
    ('claude-md-template', 'agents-md-template'),
    ('claude-md-assistant-template', 'agents-md-assistant-template'),
]
renames = {
    'claude-md-template.md': 'agents-md-template.md',
    'claude-md-assistant-template.md': 'agents-md-assistant-template.md',
    '_CLAUDE.md': '_AGENTS.md',
}


def is_helper_copy(path: Path) -> bool:
    return path.name == 'convert.sh' and path.parent.name == 'scripts'


def replace_file(path: Path) -> bool:
    try:
        with path.open('r', encoding='utf-8', newline='') as handle:
            before = handle.read()
    except UnicodeDecodeError:
        return False

    after = before
    for old, new in replacements:
        after = after.replace(old, new)

    if after == before:
        return False

    fd, tmp_name = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    os.close(fd)
    tmp = Path(tmp_name)
    try:
        with tmp.open('w', encoding='utf-8', newline='') as handle:
            handle.write(after)
        shutil.copystat(path, tmp)
        os.replace(tmp, path)
    except Exception:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise
    return True


neutralized = 0
for path in sorted(dist.rglob('*')):
    if not path.is_file():
        continue
    if is_helper_copy(path):
        continue
    if path.suffix.lower() not in suffixes:
        continue
    if replace_file(path):
        neutralized += 1

renamed = 0
for path in sorted(dist.rglob('*'), key=lambda item: len(item.parts), reverse=True):
    if not path.exists() or not path.is_file():
        continue
    new_name = renames.get(path.name)
    if not new_name:
        continue
    target = path.with_name(new_name)
    if target.exists():
        raise SystemExit(f'Rename destination already exists: {target}')
    path.rename(target)
    renamed += 1

print(neutralized, renamed)
PY
)"
read -r NEUTRALIZED_COUNT RENAMED_COUNT <<< "$COUNTS"

info "Neutralized $NEUTRALIZED_COUNT file(s) and renamed $RENAMED_COUNT path(s) in $SUMMARY_DIST_PATH."

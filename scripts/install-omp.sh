#!/usr/bin/env bash
set -eo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VAULT=""

fail() {
  echo "error: $*" >&2
  exit 1
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

contains() {
  local wanted="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$wanted" ]] && return 0
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      [[ $# -gt 1 ]] || fail "--vault requires a path"
      VAULT="$2"
      shift 2
      ;;
    *)
      fail "usage: bash scripts/install-omp.sh --vault <directory>"
      ;;
  esac
done

[[ -n "$VAULT" ]] || fail "--vault is required"
[[ -d "$VAULT" ]] || fail "vault directory not found: $VAULT"
VAULT="$(cd "$VAULT" && pwd -P)"
[[ -d "$VAULT/.obsidian" && -r "$VAULT/.obsidian" ]] || fail "readable .obsidian directory required"
command -v bash >/dev/null || fail "bash required"
command -v python3 >/dev/null || fail "python3 required"

bash "$ROOT/scripts/build.sh" --platform omp

DIST="$ROOT/dist/omp"
BASE="$VAULT/.agents"
SKILLS="$BASE/skills"
COMMANDS="$BASE/commands"
OLD_MANIFEST="$BASE/obsidian-second-brain.manifest"
NEW_MANIFEST="$DIST/.agents/obsidian-second-brain.manifest"
ROOT_AGENTS="$VAULT/AGENTS.md"

# This is deliberately one preflight before any vault mutation.  Python gives
# us canonical path handling on macOS without relying on GNU readlink.
python3 - "$VAULT" "$DIST" <<'PY'
from pathlib import Path
import os
import re
import sys

vault = Path(sys.argv[1])
dist = Path(sys.argv[2])
base = vault / ".agents"
commands = base / "commands"
skills = base / "skills"
old_manifest = base / "obsidian-second-brain.manifest"
root_agents = vault / "AGENTS.md"
new_agents = dist / ".agents"
new_commands = new_agents / "commands"
new_skills = new_agents / "skills"
new_manifest = new_agents / "obsidian-second-brain.manifest"

COMMAND_NAME = re.compile(r"[a-z0-9][a-z0-9-]*\.md\Z")
SKILL_NAME = re.compile(r"[a-z0-9][a-z0-9-]*\Z")
REQUIRED_SKILLS = {
    "obsidian-core",
    "obsidian-distill",
    "obsidian-crystallize",
    "obsidian-nightly",
}
FACTUAL_CLAUDE_VALUES = (
    "Anthropic Claude",
    "claude-haiku-4-5",
    "claude-watch",
    "claude-video",
)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def lexists(path: Path) -> bool:
    return os.path.lexists(path)


def require_directory(path: Path, label: str) -> None:
    if path.is_symlink() or not path.is_dir():
        fail(f"missing or unsafe {label}: {path}")


def require_file(path: Path, label: str) -> None:
    if path.is_symlink() or not path.is_file():
        fail(f"missing or unsafe {label}: {path}")


def canonical_direct(parent: Path, name: str, label: str) -> Path:
    parent_real = os.path.realpath(os.fspath(parent))
    destination = parent / name
    destination_real = os.path.realpath(os.fspath(destination))
    try:
        inside_parent = os.path.commonpath((parent_real, destination_real)) == parent_real
    except ValueError:
        inside_parent = False
    if not inside_parent or os.path.dirname(destination_real) != parent_real:
        fail(f"{label} escapes its direct destination: {destination}")
    return destination


def parse_manifest(path: Path, label: str) -> list[tuple[str, str]]:
    try:
        data = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        fail(f"cannot read {label}: {exc}")
    if not data:
        fail(f"empty {label}: {path}")
    lines = data.split("\n")
    if lines[-1] == "":
        lines.pop()
    if not lines:
        fail(f"empty {label}: {path}")

    entries: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for line_number, line in enumerate(lines, 1):
        if not line or line.count("\t") != 1:
            fail(f"malformed {label} line {line_number}")
        kind, name = line.split("\t")
        valid = (
            kind == "command" and COMMAND_NAME.fullmatch(name)
        ) or (
            kind == "skill" and SKILL_NAME.fullmatch(name)
        )
        if not valid:
            fail(f"invalid {label} entry on line {line_number}")
        entry = (kind, name)
        if entry in seen:
            fail(f"duplicate {label} entry on line {line_number}")
        seen.add(entry)
        entries.append(entry)
    return entries


if os.path.realpath(os.fspath(vault)) != os.fspath(vault):
    fail(f"vault is not canonical: {vault}")
require_directory(dist, "OMP build tree")
require_file(dist / "AGENTS.md", "OMP root AGENTS.md")
require_file(dist / "INSTALL.md", "OMP installation guide")
try:
    generated_root_agents = (dist / "AGENTS.md").read_text(encoding="utf-8")
except (OSError, UnicodeDecodeError) as exc:
    fail(f"cannot read OMP root AGENTS.md: {exc}")
if "<!-- managed-by: obsidian-second-brain-omp -->" not in generated_root_agents:
    fail("OMP root AGENTS.md is not managed")
require_directory(new_agents, "OMP .agents tree")
require_directory(new_commands, "OMP commands tree")
require_directory(new_skills, "OMP skills tree")
require_file(new_manifest, "OMP manifest")

new_entries = parse_manifest(new_manifest, "new manifest")
new_command_names = {name for kind, name in new_entries if kind == "command"}
new_skill_names = {name for kind, name in new_entries if kind == "skill"}
if not REQUIRED_SKILLS <= new_skill_names:
    fail("new manifest is missing required OMP skills")
expected_commands = {f"{name}.md" for name in new_skill_names if name != "obsidian-core"}
if new_command_names != expected_commands:
    fail("new manifest wrappers do not match non-core skills")

for kind, name in new_entries:
    source_parent = new_commands if kind == "command" else new_skills
    source = canonical_direct(source_parent, name, f"new {kind} entry")
    if kind == "command":
        require_file(source, f"new command {name}")
        try:
            wrapper = source.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            fail(f"cannot read new command {name}: {exc}")
        skill_name = name[:-3]
        if f"skill://{skill_name}" not in wrapper or "$ARGUMENTS" not in wrapper:
            fail(f"invalid wrapper for {skill_name}")
    else:
        require_directory(source, f"new skill {name}")
        require_file(source / "SKILL.md", f"new skill entrypoint {name}")

actual_commands = {path.name for path in new_commands.iterdir()}
actual_skills = {path.name for path in new_skills.iterdir()}
if actual_commands != new_command_names or actual_skills != new_skill_names:
    fail("new manifest does not exactly describe OMP commands and skills")

# The converter permits only these factual external values.  Everything else
# must be agent-neutral, including path names.
for current_root, directory_names, file_names in os.walk(dist, followlinks=False):
    current = Path(current_root)
    for name in directory_names:
        child = current / name
        if child.is_symlink():
            fail(f"unsafe symlink in OMP build: {child}")
        if "claude" in name.lower():
            fail(f"forbidden token in OMP build path: {child}")
    for name in file_names:
        child = current / name
        if child.is_symlink():
            fail(f"unsafe symlink in OMP build: {child}")
        if "claude" in name.lower():
            fail(f"forbidden token in OMP build path: {child}")
        try:
            text = child.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        except OSError as exc:
            fail(f"cannot read OMP build file {child}: {exc}")
        neutralized = text
        for factual_value in FACTUAL_CLAUDE_VALUES:
            neutralized = neutralized.replace(factual_value, "")
        if "SKILL_ROOT" in neutralized or re.search(r"claude", neutralized, re.IGNORECASE):
            fail(f"forbidden token in OMP build file: {child}")

# Never follow an existing vault destination.  Direct canonical joins make the
# manifest a name list rather than an authority to choose arbitrary paths.
expected_base = vault / ".agents"
if os.path.realpath(os.fspath(base)) != os.fspath(expected_base):
    fail(f"unsafe .agents base: {base}")
if lexists(base):
    if base.is_symlink() or not base.is_dir():
        fail(f"unsafe .agents base: {base}")
for directory, label in ((commands, "commands"), (skills, "skills")):
    if lexists(directory):
        if directory.is_symlink() or not directory.is_dir():
            fail(f"unsafe .agents {label} directory: {directory}")
    expected = base / directory.name
    if os.path.realpath(os.fspath(directory)) != os.fspath(expected):
        fail(f"unsafe .agents {label} directory: {directory}")

old_entries: list[tuple[str, str]] = []
if lexists(old_manifest):
    require_file(old_manifest, "old manifest")
    canonical_direct(base, old_manifest.name, "old manifest")
    old_entries = parse_manifest(old_manifest, "old manifest")

for kind, name in old_entries:
    parent = commands if kind == "command" else skills
    destination = canonical_direct(parent, name, f"old {kind} entry")
    if lexists(destination) and destination.is_symlink():
        fail(f"unsafe managed destination: {destination}")

for kind, name in new_entries:
    parent = commands if kind == "command" else skills
    destination = canonical_direct(parent, name, f"new {kind} destination")
    if lexists(destination) and destination.is_symlink():
        fail(f"unsafe generated destination: {destination}")
    if lexists(destination) and (kind, name) not in old_entries:
        fail(f"unowned destination conflict: {destination}")

canonical_direct(vault, root_agents.name, "root AGENTS.md")
if lexists(root_agents):
    if root_agents.is_symlink() or not root_agents.is_file():
        fail(f"unsafe root AGENTS.md destination: {root_agents}")
    try:
        root_text = root_agents.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        fail(f"cannot read root AGENTS.md: {exc}")
    if (
        "<!-- managed-by: obsidian-second-brain-omp -->" not in root_text
        and "Generated by adapters/omp/adapter.sh" not in root_text
    ):
        fail(f"user-owned root AGENTS.md conflict: {root_agents}")
PY

NEW_SKILLS=()
NEW_COMMANDS=()
OLD_SKILLS=()
OLD_COMMANDS=()
line=""
while IFS= read -r line || [[ -n "$line" ]]; do
  kind="${line%%$'\t'*}"
  name="${line#*$'\t'}"
  if [[ "$kind" == "skill" ]]; then
    NEW_SKILLS+=("$name")
  else
    NEW_COMMANDS+=("$name")
  fi
  line=""
done < "$NEW_MANIFEST"

if path_exists "$OLD_MANIFEST"; then
  line=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    kind="${line%%$'\t'*}"
    name="${line#*$'\t'}"
    if [[ "$kind" == "skill" ]]; then
      OLD_SKILLS+=("$name")
    else
      OLD_COMMANDS+=("$name")
    fi
    line=""
  done < "$OLD_MANIFEST"
fi

BASE_EXISTED=0
SKILLS_EXISTED=0
COMMANDS_EXISTED=0
OLD_MANIFEST_EXISTED=0
ROOT_AGENTS_EXISTED=0
path_exists "$BASE" && BASE_EXISTED=1
path_exists "$SKILLS" && SKILLS_EXISTED=1
path_exists "$COMMANDS" && COMMANDS_EXISTED=1
path_exists "$OLD_MANIFEST" && OLD_MANIFEST_EXISTED=1
path_exists "$ROOT_AGENTS" && ROOT_AGENTS_EXISTED=1

stage="$BASE/.obsidian-second-brain-stage.$$"
backup="$BASE/.obsidian-second-brain-backup.$$"
journal="$BASE/.obsidian-second-brain-journal.$$"
STAGE_CREATED=0
BACKUP_CREATED=0
JOURNAL_CREATED=0
BASE_CREATED=0
SKILLS_CREATED=0
COMMANDS_CREATED=0

journal_record() {
  if [[ $# -eq 1 ]]; then
    printf '%s\n' "$1" >> "$journal"
  else
    printf '%s\t%s\n' "$1" "$2" >> "$journal"
  fi
}

cleanup_workdirs() {
  [[ "$STAGE_CREATED" -eq 0 ]] || rm -rf "$stage"
  [[ "$BACKUP_CREATED" -eq 0 ]] || rm -rf "$backup"
  [[ "$JOURNAL_CREATED" -eq 0 ]] || rm -f "$journal"
}

restore_backup() {
  local kind="$1"
  local name="$2"
  local destination="$BASE/$kind/$name"
  rm -rf "$destination"
  cp -a "$backup/$kind/$name" "$destination"
}

rollback() {
  set +e
  local record action name index
  local records=()
  if [[ "$JOURNAL_CREATED" -eq 1 && -f "$journal" ]]; then
    record=""
    while IFS= read -r record || [[ -n "$record" ]]; do
      records+=("$record")
      record=""
    done < "$journal"
  fi

  for ((index=${#records[@]} - 1; index >= 0; index--)); do
    record="${records[$index]}"
    action="${record%%$'\t'*}"
    name="${record#*$'\t'}"
    [[ "$action" == "$record" ]] && name=""
    case "$action" in
      created-skill) rm -rf "$SKILLS/$name" ;;
      restore-skill) restore_backup "skills" "$name" ;;
      created-command) rm -rf "$COMMANDS/$name" ;;
      restore-command) restore_backup "commands" "$name" ;;
      created-root) rm -f "$ROOT_AGENTS" ;;
      restore-root)
        rm -f "$ROOT_AGENTS"
        cp -a "$backup/root-AGENTS.md" "$ROOT_AGENTS"
        ;;
      created-manifest) rm -f "$OLD_MANIFEST" ;;
      restore-manifest)
        rm -f "$OLD_MANIFEST"
        cp -a "$backup/manifest" "$OLD_MANIFEST"
        ;;
      created-commands-dir) rmdir "$COMMANDS" 2>/dev/null || true ;;
      created-skills-dir) rmdir "$SKILLS" 2>/dev/null || true ;;
      created-base) rmdir "$BASE" 2>/dev/null || true ;;
    esac
  done

  cleanup_workdirs
  [[ "$COMMANDS_CREATED" -eq 0 ]] || rmdir "$COMMANDS" 2>/dev/null || true
  [[ "$SKILLS_CREATED" -eq 0 ]] || rmdir "$SKILLS" 2>/dev/null || true
  [[ "$BASE_CREATED" -eq 0 ]] || rmdir "$BASE" 2>/dev/null || true
}

on_exit() {
  local status=$?
  trap - EXIT
  if [[ "$status" -ne 0 ]]; then
    rollback
  else
    cleanup_workdirs
  fi
  exit "$status"
}

trap on_exit EXIT

if [[ "$BASE_EXISTED" -eq 0 ]]; then
  mkdir "$BASE"
  BASE_CREATED=1
fi
if path_exists "$stage" || path_exists "$backup" || path_exists "$journal"; then
  fail "installer work path already exists"
fi
mkdir "$stage"
STAGE_CREATED=1
mkdir "$backup"
BACKUP_CREATED=1
mkdir "$stage/skills" "$stage/commands" "$backup/skills" "$backup/commands"
(
  set -C
  : > "$journal"
)
JOURNAL_CREATED=1
[[ "$BASE_CREATED" -eq 0 ]] || journal_record "created-base"

if [[ "$SKILLS_EXISTED" -eq 0 ]]; then
  mkdir "$SKILLS"
  SKILLS_CREATED=1
  journal_record "created-skills-dir"
fi
if [[ "$COMMANDS_EXISTED" -eq 0 ]]; then
  mkdir "$COMMANDS"
  COMMANDS_CREATED=1
  journal_record "created-commands-dir"
fi

# Stage only manifest-owned artifacts.  Unlisted source files never gain
# ownership merely because they happened to be present in dist/omp.
for name in "${NEW_SKILLS[@]}"; do
  cp -a "$DIST/.agents/skills/$name" "$stage/skills/$name"
done
for name in "${NEW_COMMANDS[@]}"; do
  cp -a "$DIST/.agents/commands/$name" "$stage/commands/$name"
done
cp -a "$NEW_MANIFEST" "$stage/manifest"

# Backups are manifest-scoped: old managed paths, the previous manifest, and a
# recognized managed root AGENTS.md.  Neighboring user entries are untouched.
backup_managed_path() {
  local kind="$1"
  local name="$2"
  local destination="$BASE/$kind/$name"
  if path_exists "$destination"; then
    [[ ! -L "$destination" ]] || fail "unsafe managed destination: $destination"
    cp -a "$destination" "$backup/$kind/$name"
  fi
}

for name in "${OLD_SKILLS[@]}"; do
  backup_managed_path "skills" "$name"
done
for name in "${OLD_COMMANDS[@]}"; do
  backup_managed_path "commands" "$name"
done
if [[ "$OLD_MANIFEST_EXISTED" -eq 1 ]]; then
  cp -a "$OLD_MANIFEST" "$backup/manifest"
fi
if [[ "$ROOT_AGENTS_EXISTED" -eq 1 ]]; then
  cp -a "$ROOT_AGENTS" "$backup/root-AGENTS.md"
fi

install_entry() {
  local kind="$1"
  local name="$2"
  local destination="$BASE/$kind/$name"
  local old_names=("${OLD_SKILLS[@]}")
  [[ "$kind" == "commands" ]] && old_names=("${OLD_COMMANDS[@]}")

  [[ -d "$BASE" && ! -L "$BASE" ]] || fail "unsafe .agents base during commit"
  [[ -d "$BASE/$kind" && ! -L "$BASE/$kind" ]] || fail "unsafe .agents $kind directory during commit"
  if path_exists "$destination"; then
    [[ ! -L "$destination" ]] || fail "unsafe generated destination: $destination"
    contains "$name" "${old_names[@]}" || fail "unowned destination conflict: $destination"
    path_exists "$backup/$kind/$name" || fail "destination changed after preflight: $destination"
    journal_record "restore-${kind%?}" "$name"
    rm -rf "$destination"
  else
    journal_record "created-${kind%?}" "$name"
  fi
  cp -a "$stage/$kind/$name" "$destination"
}

remove_stale_entry() {
  local kind="$1"
  local name="$2"
  local destination="$BASE/$kind/$name"
  if path_exists "$destination"; then
    [[ ! -L "$destination" ]] || fail "unsafe managed destination: $destination"
    path_exists "$backup/$kind/$name" || fail "destination changed after preflight: $destination"
    journal_record "restore-${kind%?}" "$name"
    rm -rf "$destination"
  fi
}

# Commit in the prescribed order: skills, wrappers, root AGENTS.md, manifest.
for name in "${NEW_SKILLS[@]}"; do
  install_entry "skills" "$name"
done
for name in "${OLD_SKILLS[@]}"; do
  contains "$name" "${NEW_SKILLS[@]}" || remove_stale_entry "skills" "$name"
done

if [[ "${OBSIDIAN_SECOND_BRAIN_TEST_FAIL_AFTER:-}" == "skills" ]]; then
  echo "test failpoint after skills" >&2
  exit 1
fi

for name in "${NEW_COMMANDS[@]}"; do
  install_entry "commands" "$name"
done
for name in "${OLD_COMMANDS[@]}"; do
  contains "$name" "${NEW_COMMANDS[@]}" || remove_stale_entry "commands" "$name"
done

if path_exists "$ROOT_AGENTS"; then
  [[ ! -L "$ROOT_AGENTS" && -f "$ROOT_AGENTS" ]] || fail "unsafe root AGENTS.md destination during commit"
  grep -qF '<!-- managed-by: obsidian-second-brain-omp -->' "$ROOT_AGENTS" || \
    grep -qF 'Generated by adapters/omp/adapter.sh' "$ROOT_AGENTS" || \
    fail "user-owned root AGENTS.md conflict: $ROOT_AGENTS"
  path_exists "$backup/root-AGENTS.md" || fail "root AGENTS.md changed after preflight"
  if ! cmp -s "$DIST/AGENTS.md" "$ROOT_AGENTS"; then
    journal_record "restore-root"
    cp -a "$DIST/AGENTS.md" "$ROOT_AGENTS"
  fi
else
  [[ "$ROOT_AGENTS_EXISTED" -eq 0 ]] || fail "root AGENTS.md changed after preflight"
  journal_record "created-root"
  cp -a "$DIST/AGENTS.md" "$ROOT_AGENTS"
fi

if path_exists "$OLD_MANIFEST"; then
  [[ "$OLD_MANIFEST_EXISTED" -eq 1 && ! -L "$OLD_MANIFEST" && -f "$OLD_MANIFEST" ]] || \
    fail "manifest changed after preflight"
  path_exists "$backup/manifest" || fail "manifest backup missing"
  if ! cmp -s "$stage/manifest" "$OLD_MANIFEST"; then
    journal_record "restore-manifest"
    cp -a "$stage/manifest" "$OLD_MANIFEST"
  fi
else
  [[ "$OLD_MANIFEST_EXISTED" -eq 0 ]] || fail "manifest changed after preflight"
  journal_record "created-manifest"
  cp -a "$stage/manifest" "$OLD_MANIFEST"
fi

skills_count=${#NEW_SKILLS[@]}
commands_count=${#NEW_COMMANDS[@]}
echo "Installed $skills_count skills and $commands_count commands."
echo "Next: /obsidian-health /obsidian-nightly /obsidian-crystallize /skill:obsidian-distill"

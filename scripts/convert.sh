#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
source "$SCRIPT_DIR/lib.sh"

usage() { echo "Usage: bash scripts/convert.sh --dist <repo>/dist/omp"; }
DIST_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dist) [[ $# -gt 1 ]] || die "--dist requires a path"; DIST_DIR="$2"; shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[[ -n "$DIST_DIR" ]] || die "Missing required --dist <dist-dir>"
[[ -d "$DIST_DIR" ]] || die "Dist directory not found: $DIST_DIR"
CANONICAL_DIST="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$DIST_DIR")"
EXPECTED_DIST="$(python3 -c 'from pathlib import Path; import sys; print((Path(sys.argv[1]) / "dist" / "omp").resolve())' "$REPO_ROOT")"
[[ "$CANONICAL_DIST" == "$EXPECTED_DIST" ]] || die "Refusing to neutralize non-OMP dist tree: $DIST_DIR"

python3 - "$CANONICAL_DIST" <<'PY'
from pathlib import Path
import os
import re
import shutil
import sys
import tempfile

root = Path(sys.argv[1])
text_suffixes = {
    ".md", ".py", ".sh", ".yml", ".yaml", ".json", ".toml", ".html",
    ".cff", ".txt", ".rb", ".go", ".rs",
}
external_values = (
    "Anthropic Claude",
    "claude-haiku-4-5",
    "claude-watch",
    "claude-video",
)
calendar_connector = re.compile(
    re.escape("claude.ai Google Calendar connector"), re.IGNORECASE
)
future_claude = re.compile(r"future[- ]Claude", re.IGNORECASE)
word_replacements = (
    (re.compile(r"\bClaude's\b"), "the agent's"),
    (re.compile(r"\bClaude\b"), "the agent"),
    (re.compile(r"\bCLAUDE\b"), "AGENT"),
    (re.compile(r"\bclaude\b"), "agent"),
)


class ConversionError(RuntimeError):
    pass


def read_utf8(path: Path) -> str | None:
    try:
        with path.open("r", encoding="utf-8", newline="") as handle:
            return handle.read()
    except UnicodeDecodeError:
        return None


def is_text_artifact(path: Path) -> bool:
    return (
        path.suffix.lower() in text_suffixes
        and not (path.name == "convert.sh" and path.parent.name == "scripts")
    )


def collect_entries(tree: Path) -> tuple[list[tuple[Path, Path]], dict[Path, str]]:
    entries: list[tuple[Path, Path]] = []
    texts: dict[Path, str] = {}
    for path in sorted(tree.rglob("*"), key=lambda value: value.relative_to(tree).as_posix()):
        relative = path.relative_to(tree)
        if path.is_symlink():
            raise ConversionError(f"refusing to neutralize symlink: {relative.as_posix()}")
        entries.append((path, relative))
        if path.is_file() and is_text_artifact(path):
            text = read_utf8(path)
            if text is not None:
                texts[relative] = text
    return entries, texts


def make_sentinels(
    entries: list[tuple[Path, Path]], texts: dict[Path, str]
) -> dict[str, str]:
    sources = [part for _, relative in entries for part in relative.parts]
    sources.extend(texts.values())
    attempt = 0
    while True:
        sentinels = {
            value: f"\ue000OSB_FACT_{index}_{attempt}\ue001"
            for index, value in enumerate(external_values)
        }
        if all(
            sentinel not in source
            for sentinel in sentinels.values()
            for source in sources
        ):
            return sentinels
        attempt += 1


def mask_external(value: str, sentinels: dict[str, str]) -> str:
    for factual, sentinel in sentinels.items():
        value = value.replace(factual, sentinel)
    return value


def restore_external(value: str, sentinels: dict[str, str]) -> str:
    for factual, sentinel in sentinels.items():
        value = value.replace(sentinel, factual)
    return value


def transform(value: str, *, path_component: bool, sentinels: dict[str, str]) -> str:
    value = mask_external(value, sentinels)

    value = value.replace("_CLAUDE.md", "_AGENTS.md")
    value = value.replace("claude-md-template.md", "agents-md-template.md")
    value = value.replace(
        "claude-md-assistant-template.md", "agents-md-assistant-template.md"
    )
    value = future_claude.sub("future agent", value)

    value = value.replace(
        "mcp__claude_ai_Google_Calendar__list_calendars",
        "the connected Google Calendar MCP calendar-listing tool",
    )
    value = value.replace(
        "mcp__claude_ai_Google_Calendar__list_events",
        "the connected Google Calendar MCP event-listing tool",
    )
    value = calendar_connector.sub("connected Google Calendar MCP", value)

    value = value.replace("claude_md_personal", "agents_md_personal")
    value = value.replace("claude_md_assistant", "agents_md_assistant")
    value = value.replace("ask_claude", "ask_agent")
    value = value.replace("_print_frames_for_claude", "_print_frames_for_agent")
    value = value.replace("FRAMES-FOR-CLAUDE", "FRAMES-FOR-AGENT")
    value = value.replace("<!-- CLAUDE:", "<!-- AGENT:")

    value = value.replace("claude-code", "omp")
    if path_component and value == ".claude":
        value = ".agents"
    else:
        value = value.replace(".claude/", ".agents/")
    value = value.replace("Claude Code", "OMP")
    value = value.replace("Claude Desktop", "a desktop agent")
    value = value.replace("calling Claude", "calling the agent")
    for pattern, replacement in word_replacements:
        value = pattern.sub(replacement, value)
    return restore_external(value, sentinels)


def has_forbidden_token(value: str, sentinels: dict[str, str]) -> bool:
    return re.search(r"claude", mask_external(value, sentinels), re.IGNORECASE) is not None


def transformed_component(component: str, sentinels: dict[str, str]) -> str:
    converted = transform(component, path_component=True, sentinels=sentinels)
    if (
        not converted
        or converted in {".", ".."}
        or "/" in converted
        or "\x00" in converted
    ):
        raise ConversionError(f"invalid converted path component: {component!r}")
    return converted


def plan_paths(
    entries: list[tuple[Path, Path]], sentinels: dict[str, str]
) -> dict[Path, str]:
    destinations: dict[tuple[str, ...], Path] = {}
    new_names: dict[Path, str] = {}
    for _, relative in entries:
        converted_parts = tuple(
            transformed_component(component, sentinels) for component in relative.parts
        )
        converted_relative = Path(*converted_parts)
        previous = destinations.get(converted_parts)
        if previous is not None:
            raise ConversionError(
                "path collision after conversion: "
                f"{previous.as_posix()} and {relative.as_posix()} "
                f"would both become {converted_relative.as_posix()}"
            )
        destinations[converted_parts] = relative
        if has_forbidden_token(converted_relative.as_posix(), sentinels):
            raise ConversionError(
                f"forbidden claude token in path: {converted_relative.as_posix()}"
            )
        new_names[relative] = converted_parts[-1]
    return new_names


def plan_texts(texts: dict[Path, str], sentinels: dict[str, str]) -> dict[Path, str]:
    converted: dict[Path, str] = {}
    for relative, text in texts.items():
        output = transform(text, path_component=False, sentinels=sentinels)
        if has_forbidden_token(output, sentinels):
            raise ConversionError(f"forbidden claude token in file: {relative.as_posix()}")
        converted[relative] = output
    return converted


def replace_text(path: Path, content: str) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=".__osb.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
        shutil.copystat(path, temporary, follow_symlinks=False)
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def validate_stage(stage: Path, sentinels: dict[str, str]) -> None:
    entries, texts = collect_entries(stage)
    for _, relative in entries:
        if has_forbidden_token(relative.as_posix(), sentinels):
            raise ConversionError(f"forbidden claude token in path: {relative.as_posix()}")
    for relative, text in texts.items():
        if has_forbidden_token(text, sentinels):
            raise ConversionError(f"forbidden claude token in file: {relative.as_posix()}")


def neutralize_stage(stage: Path) -> tuple[int, int]:
    entries, texts = collect_entries(stage)
    sentinels = make_sentinels(entries, texts)
    new_names = plan_paths(entries, sentinels)
    converted_texts = plan_texts(texts, sentinels)

    changed = 0
    for relative, output in converted_texts.items():
        if output != texts[relative]:
            replace_text(stage / relative, output)
            changed += 1

    renamed = 0
    for path, relative in sorted(
        entries, key=lambda item: (-len(item[1].parts), item[1].as_posix())
    ):
        new_name = new_names[relative]
        if new_name == path.name:
            continue
        destination = path.with_name(new_name)
        if destination.exists() or destination.is_symlink():
            raise ConversionError(f"rename destination exists: {destination}")
        os.replace(path, destination)
        renamed += 1

    validate_stage(stage, sentinels)
    return changed, renamed


def stage_copy(source: Path) -> Path:
    stage = Path(
        tempfile.mkdtemp(prefix=f".{source.name}.convert-stage-", dir=source.parent)
    )
    stage.rmdir()
    try:
        shutil.copytree(source, stage, symlinks=True, copy_function=shutil.copy2)
    except BaseException:
        shutil.rmtree(stage, ignore_errors=True)
        raise
    return stage


def publish(stage: Path) -> None:
    backup = Path(
        tempfile.mkdtemp(prefix=f".{root.name}.convert-backup-", dir=root.parent)
    )
    backup.rmdir()
    original_moved = False
    try:
        os.replace(root, backup)
        original_moved = True
        try:
            os.replace(stage, root)
        except BaseException:
            os.replace(backup, root)
            original_moved = False
            raise
    except BaseException:
        if original_moved and backup.exists() and not root.exists():
            os.replace(backup, root)
        raise
    shutil.rmtree(backup, ignore_errors=True)


stage: Path | None = None
try:
    stage = stage_copy(root)
    changed, renamed = neutralize_stage(stage)
    if changed or renamed:
        publish(stage)
        stage = None
    print(f"Neutralized {changed} file(s) and renamed {renamed} path(s) in dist/omp.")
except Exception as error:
    print(f"conversion failed: {error}", file=sys.stderr)
    sys.exit(1)
finally:
    if stage is not None and stage.exists():
        shutil.rmtree(stage, ignore_errors=True)
PY

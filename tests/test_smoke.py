"""Smoke tests for the two highest-risk subsystems: the adapter build pipeline
and the vault health checker. Both run the real scripts via subprocess and only
depend on the Python standard library, so CI needs nothing beyond pytest.

Adapted from the test added by the bmassenz fork (the only fork that shipped
any automated test). See FORK_INSIGHTS.md items #47/#48.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

EXPECTED_CONVERT_H_PATHS = {
    "commands/example.md",
    "examples/sample-vault/_CLAUDE.md",
    "hooks/example.sh",
    "references/claude-md-assistant-template.md",
    "references/claude-md-template.md",
}


def _run(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        cwd=repo,
        check=False,
        capture_output=True,
        text=True,
    )


def _git_flags(repo: Path) -> dict[str, str]:
    result = _run(repo, "git", "ls-files", "-v")
    assert result.returncode == 0, result.stderr
    return {line[2:]: line[0] for line in result.stdout.splitlines() if line}


def _write(path: Path, content: str, mode: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    if mode is not None:
        path.chmod(mode)


def _make_convert_fixture(tmp_path: Path) -> Path:
    repo = tmp_path / "convert-fixture"
    repo.mkdir()

    (repo / "scripts").mkdir()
    shutil.copy2(REPO_ROOT / "scripts/convert.sh", repo / "scripts/convert.sh")
    shutil.copy2(REPO_ROOT / "scripts/lib.sh", repo / "scripts/lib.sh")

    for rel in (
        ".gitignore",
        "AGENTS.md",
        "FORK_MAINTENANCE.md",
        "FORK_TODO.md",
        "adapters/omp/adapter.sh",
        "commands/obsidian-distill.md",
        "install.sh",
        "scripts/__init__.py",
        "scripts/build.sh",
        "scripts/setup.sh",
    ):
        _write(repo / rel, f"fixture for {rel}\n")

    _write(repo / "README.md", "No conversion text here.\n")
    _write(repo / "commands/example.md", "## For future Claude\nSee _CLAUDE.md.\n")
    _write(repo / "hooks/example.sh", "#!/usr/bin/env bash\necho _CLAUDE.md\n", 0o755)
    _write(repo / "references/claude-md-template.md", "Use claude-md-template and _CLAUDE.md.\n")
    _write(
        repo / "references/claude-md-assistant-template.md",
        "Use claude-md-assistant-template.\n",
    )
    _write(repo / "examples/sample-vault/_CLAUDE.md", "# Claude Operating Manual\n")

    for args in (
        ("git", "init"),
        ("git", "config", "user.email", "test@example.com"),
        ("git", "config", "user.name", "Test User"),
        ("git", "add", "."),
        ("git", "commit", "-m", "fixture"),
    ):
        result = _run(repo, *args)
        assert result.returncode == 0, result.stdout + result.stderr

    return repo


def _json_from_stdout(stdout: str) -> dict:
    """vault_health.py prints a couple of human-readable lines before the JSON
    payload even in --json mode. Scan for the first line that opens the object."""
    lines = stdout.splitlines()
    for index, line in enumerate(lines):
        if line.strip() == "{":
            return json.loads("\n".join(lines[index:]))
    raise AssertionError(f"JSON payload not found in stdout:\n{stdout}")


def test_convert_setup_marks_only_expected_conversions(tmp_path):
    repo = _make_convert_fixture(tmp_path)

    result = _run(repo, "bash", "scripts/convert.sh", "--setup")
    assert result.returncode == 0, result.stdout + result.stderr

    assert "## Synopsis" in (repo / "commands/example.md").read_text(encoding="utf-8")
    assert "_AGENTS.md" in (repo / "commands/example.md").read_text(encoding="utf-8")
    assert "_AGENTS.md" in (repo / "hooks/example.sh").read_text(encoding="utf-8")
    assert (repo / "hooks/example.sh").stat().st_mode & 0o111
    assert (repo / "references/agents-md-template.md").is_file()
    assert (repo / "references/agents-md-assistant-template.md").is_file()
    assert (repo / "examples/sample-vault/_AGENTS.md").is_file()

    flags = _git_flags(repo)
    h_paths = {path for path, flag in flags.items() if flag == "h"}
    assert h_paths == EXPECTED_CONVERT_H_PATHS
    assert flags["AGENTS.md"] != "h"
    assert flags["README.md"] != "h"
    assert flags["scripts/build.sh"] != "h"

    unmark = _run(
        repo,
        "git",
        "update-index",
        "--no-assume-unchanged",
        *sorted(EXPECTED_CONVERT_H_PATHS),
    )
    assert unmark.returncode == 0, unmark.stdout + unmark.stderr

    rerun = _run(repo, "bash", "scripts/convert.sh", "--setup")
    assert rerun.returncode == 0, rerun.stdout + rerun.stderr
    flags = _git_flags(repo)
    h_paths = {path for path, flag in flags.items() if flag == "h"}
    assert h_paths == EXPECTED_CONVERT_H_PATHS


def test_convert_setup_unmarks_stale_non_conversion_flags(tmp_path):
    repo = _make_convert_fixture(tmp_path)

    hidden = _run(repo, "git", "update-index", "--assume-unchanged", "README.md")
    assert hidden.returncode == 0, hidden.stdout + hidden.stderr

    result = _run(repo, "bash", "scripts/convert.sh", "--setup")
    assert result.returncode == 0, result.stdout + result.stderr
    output = result.stdout + result.stderr
    assert "Unmarked non-conversion assume-unchanged path: README.md" in output
    assert _git_flags(repo)["README.md"] == "H"


def test_convert_setup_refuses_hidden_fork_owned_files(tmp_path):
    repo = _make_convert_fixture(tmp_path)

    hidden = _run(repo, "git", "update-index", "--assume-unchanged", "AGENTS.md")
    assert hidden.returncode == 0, hidden.stdout + hidden.stderr

    result = _run(repo, "bash", "scripts/convert.sh", "--setup")
    assert result.returncode != 0
    output = result.stdout + result.stderr
    assert "Fork-owned files are assume-unchanged:" in output
    assert "AGENTS.md" in output


def test_codex_cli_build_generates_expected_files():
    """The codex-cli adapter must emit the AGENTS.md dispatcher and the command
    bodies. This guards the adapter pipeline that every command change depends on."""
    result = subprocess.run(
        ["bash", "scripts/build.sh", "--platform", "codex-cli"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert (REPO_ROOT / "dist/codex-cli/AGENTS.md").is_file()
    assert (REPO_ROOT / "dist/codex-cli/.codex/commands/obsidian-save.md").is_file()


def test_vault_health_json_reports_clean_linked_vault(tmp_path):
    """A minimal two-note vault with reciprocal wikilinks should report zero
    issues: no orphans, no broken links, no missing frontmatter."""
    vault = tmp_path / "vault"
    vault.mkdir()
    (vault / "Home.md").write_text(
        "# Home\n\nSee [[Project Alpha]].\n",
        encoding="utf-8",
    )
    (vault / "Project Alpha.md").write_text(
        "---\n"
        "type: project\n"
        "aliases:\n"
        "  - Project Alpha\n"
        "---\n"
        "# Project Alpha\n\nBack to [[Home]].\n",
        encoding="utf-8",
    )

    result = subprocess.run(
        [sys.executable, "scripts/vault_health.py", "--path", str(vault), "--json"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    payload = _json_from_stdout(result.stdout)
    assert payload["total_notes"] == 2
    assert payload["total_issues"] == 0
    assert payload["counts"]["Broken links"] == 0
    assert payload["counts"]["Orphans"] == 0


def test_substitution_check_passes_on_repo():
    """The repo source must be free of banned substitution characters in prose
    (the CI gate). Characters inside code fences/spans are allowed."""
    result = subprocess.run(
        [sys.executable, "scripts/sweep_non_ascii.py", "--check"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_substitution_check_flags_prose_em_dash(tmp_path):
    """--check must fail (exit 1) when a banned character appears in prose, and
    must NOT fail when it only appears inside an inline code span."""
    # Build the em-dash from its code point so this test's own source stays
    # ASCII (the CI gate scans .py files too); the written fixtures get the
    # real character.
    em = "\u2014"
    bad = tmp_path / "bad.md"
    bad.write_text(f"A prose line with an em{em}dash.\n", encoding="utf-8")
    flagged = subprocess.run(
        [sys.executable, "scripts/sweep_non_ascii.py", "--check", str(bad)],
        cwd=REPO_ROOT, check=False, capture_output=True, text=True,
    )
    assert flagged.returncode == 1, flagged.stdout

    ok = tmp_path / "ok.md"
    ok.write_text(f"A filename in code: `2026-01-01 {em} note.md` is fine.\n", encoding="utf-8")
    passed = subprocess.run(
        [sys.executable, "scripts/sweep_non_ascii.py", "--check", str(ok)],
        cwd=REPO_ROOT, check=False, capture_output=True, text=True,
    )
    assert passed.returncode == 0, passed.stdout


def test_health_normalizes_dashes_in_links(tmp_path):
    """Regression for #63: a wikilink written with a regular hyphen must resolve
    against a filename written with an em-dash (the #31 behavior). The non-ASCII
    sweep once rewrote _normalize_dashes()'s operands into ASCII hyphens, turning
    it into a no-op; this locks the behavior so an automated pass cannot silently
    undo it again. Em-dash built from its code point so this source stays ASCII."""
    em = "\u2014"
    (tmp_path / f"2026-05-22 {em} Learnings Review.md").write_text(
        "---\ntype: concept\n---\n# Learnings Review\n\nBack to [[Home]].\n",
        encoding="utf-8",
    )
    (tmp_path / "Home.md").write_text(
        "# Home\n\nSee [[2026-05-22 - Learnings Review]].\n", encoding="utf-8"
    )
    result = subprocess.run(
        [sys.executable, "scripts/vault_health.py", "--path", str(tmp_path), "--json"],
        cwd=REPO_ROOT, check=False, capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert '"broken_link"' not in result.stdout, (
        "hyphen-written link to em-dash filename was flagged broken:\n" + result.stdout
    )


def test_architect_scan_emits_manifest(tmp_path):
    """architect_scan.py must produce a JSON manifest with the expected shape
    on a minimal project (no network, no install)."""
    proj = tmp_path / "proj"
    (proj / "src" / "billing").mkdir(parents=True)
    (proj / "src" / "billing" / "charge.py").write_text("def charge():\n    pass\n", encoding="utf-8")
    (proj / "pyproject.toml").write_text(
        '[project]\nname = "paymentbot"\ndependencies = ["requests"]\n', encoding="utf-8"
    )

    result = subprocess.run(
        [sys.executable, "scripts/architect_scan.py", "--path", str(proj)],
        cwd=REPO_ROOT, check=False, capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    data = _json_from_stdout(result.stdout)
    assert data["name"] == "paymentbot"
    assert data["kind"] == "python"
    assert any(m["name"] == "billing" for m in data["modules"])
    assert "requests" in data["dependencies"]
    assert any(lang["language"] == "Python" for lang in data["languages"])

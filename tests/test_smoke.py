"""Smoke tests for the two highest-risk subsystems: the adapter build pipeline
and the vault health checker. Both run the real scripts via subprocess and only
depend on the Python standard library, so CI needs nothing beyond pytest.

Adapted from the test added by the bmassenz fork (the only fork that shipped
any automated test). See FORK_INSIGHTS.md items #47/#48.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _json_from_stdout(stdout: str) -> dict:
    """vault_health.py prints a couple of human-readable lines before the JSON
    payload even in --json mode. Scan for the first line that opens the object."""
    lines = stdout.splitlines()
    for index, line in enumerate(lines):
        if line.strip() == "{":
            return json.loads("\n".join(lines[index:]))
    raise AssertionError(f"JSON payload not found in stdout:\n{stdout}")


def test_dist_only_neutralization_preserves_source():
    canonical_source_paths = (
        REPO_ROOT / "references/claude-md-template.md",
        REPO_ROOT / "references/claude-md-assistant-template.md",
        REPO_ROOT / "examples/sample-vault/_CLAUDE.md",
    )
    generated_source_paths = (
        REPO_ROOT / "references/agents-md-template.md",
        REPO_ROOT / "references/agents-md-assistant-template.md",
        REPO_ROOT / "examples/sample-vault/_AGENTS.md",
    )
    platform_cases = (
        (
            "codex-cli",
            REPO_ROOT / "dist/codex-cli/.codex/references",
            REPO_ROOT / "dist/codex-cli/.codex/commands/obsidian-save.md",
        ),
        (
            "gemini-cli",
            REPO_ROOT / "dist/gemini-cli/.gemini/references",
            REPO_ROOT / "dist/gemini-cli/.gemini/commands/obsidian-save.md",
        ),
        (
            "opencode",
            REPO_ROOT / "dist/opencode/.opencode/references",
            REPO_ROOT / "dist/opencode/.opencode/commands/obsidian-save.md",
        ),
        (
            "omp",
            REPO_ROOT / "dist/omp/.omp/references",
            REPO_ROOT / "dist/omp/.omp/commands/obsidian-save.md",
        ),
    )

    for path in canonical_source_paths:
        assert path.is_file()
    for path in generated_source_paths:
        assert not path.exists()

    for platform, references_dir, command_file in platform_cases:
        result = subprocess.run(
            ["bash", "scripts/build.sh", "--platform", platform],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stdout + result.stderr

        assert (references_dir / "claude-md-template.md").is_file()
        assert (references_dir / "claude-md-assistant-template.md").is_file()

        convert = subprocess.run(
            ["bash", "scripts/convert.sh", "--dist", f"dist/{platform}"],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        assert convert.returncode == 0, convert.stdout + convert.stderr


        for path in canonical_source_paths:
            assert path.is_file()
        for path in generated_source_paths:
            assert not path.exists()

        assert (references_dir / "agents-md-template.md").is_file()
        assert (references_dir / "agents-md-assistant-template.md").is_file()
        assert not (references_dir / "claude-md-template.md").exists()
        assert not (references_dir / "claude-md-assistant-template.md").exists()

        command_text = command_file.read_text(encoding="utf-8")
        assert "## Synopsis" in command_text
        assert "_AGENTS.md" in command_text
        assert "## For future Claude" not in command_text
        assert "_CLAUDE.md" not in command_text

        status = subprocess.run(
            [
                "git",
                "status",
                "--porcelain",
                "--",
                "commands",
                "references",
                "examples/sample-vault",
            ],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        assert status.returncode == 0, status.stdout + status.stderr
        assert status.stdout == ""


def test_claude_dist_converts_only_when_requested():
    result = subprocess.run(
        ["bash", "scripts/build.sh", "--platform", "claude-code"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    assert (REPO_ROOT / "dist/claude-code/references/claude-md-template.md").is_file()
    assert not (REPO_ROOT / "dist/claude-code/references/agents-md-template.md").exists()

    source_command = REPO_ROOT / "commands/obsidian-save.md"
    dist_command = REPO_ROOT / "dist/claude-code/commands/obsidian-save.md"
    source_text = source_command.read_text(encoding="utf-8")
    dist_text = dist_command.read_text(encoding="utf-8")
    if "## For future Claude" in source_text:
        assert "## For future Claude" in dist_text
    if "_CLAUDE.md" in source_text:
        assert "_CLAUDE.md" in dist_text

    convert = subprocess.run(
        ["bash", "scripts/convert.sh", "--dist", "dist/claude-code"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    assert convert.returncode == 0, convert.stdout + convert.stderr

    assert (REPO_ROOT / "dist/claude-code/references/agents-md-template.md").is_file()
    assert not (REPO_ROOT / "dist/claude-code/references/claude-md-template.md").exists()

    command_text = dist_command.read_text(encoding="utf-8")
    assert "## Synopsis" in command_text
    assert "_AGENTS.md" in command_text
    assert "## For future Claude" not in command_text
    assert "_CLAUDE.md" not in command_text


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

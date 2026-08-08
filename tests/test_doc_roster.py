"""SKILL.md and README.md must know every command that exists (fix 22/24).

The audit found six SKILL sections describing removed flows or stale steps,
and README counts that disagreed with the filesystem. The roster fence: every
command file appears in both docs, and the headline count is the file count.
"""

from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_every_command_is_in_skill_and_readme():
    commands = sorted(p.stem for p in (REPO_ROOT / "commands").glob("*.md"))
    skill = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    missing = [f"SKILL.md lacks {c}" for c in commands if c not in skill]
    missing += [f"README.md lacks {c}" for c in commands if c not in readme]
    assert missing == [], "\n".join(missing)


def test_headline_count_matches_filesystem():
    n = len(list((REPO_ROOT / "commands").glob("*.md")))
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    assert f"{n} commands" in readme, f"README does not state the real count ({n})"
    assert f"## {n} Commands" in readme, "README's command-table heading disagrees"


def test_readme_keeps_the_omp_project_local_installer_contract():
    """OMP is a first-class eighth build, not an undocumented generated tree."""
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    lower = readme.lower()
    assert "nine platform" in lower
    for required in (
        "Oh My Pi (OMP)",
        "bash scripts/build.sh --platform omp",
        "bash install.sh omp --vault /absolute/path/to/vault",
        "<vault>/.agents/commands",
        "<vault>/.agents/skills",
        "AGENTS.md",
        "/name",
        "/skill:<name>",
    ):
        assert required in readme


def test_readme_counts_and_omp_placement_remain_consistent():
    """The eighth-build copy must not split the Hermes/OpenRouter instructions."""
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    assert 'href="#49-commands"' in readme
    assert "49 commands total." in readme
    assert "That ships all 49 commands" in readme
    assert "48 non-calendar generic commands" in readme
    assert (
        "OMP excludes both calendar and the source-authoring `/create-command`, "
        "so it installs 47 command/skill pairs."
    ) in readme

    hermes_close = "The AI-first vault rule still applies on every write regardless of model."
    omp_heading = "### Oh My Pi (OMP)"
    assert readme.index(omp_heading) > readme.index(hermes_close)


def test_fork_guides_keep_the_surviving_overlay_boundary():
    """Forward ports must not resurrect the pre-cutover OMP architecture."""
    guides = "\n".join(
        (REPO_ROOT / name).read_text(encoding="utf-8")
        for name in ("AGENTS.md", "FORK_MAINTENANCE.md")
    )
    for required in (
        "commands/obsidian-distill.md",
        "commands/obsidian-crystallize.md",
        "commands/obsidian-nightly.md",
        "adapters/omp/adapter.sh",
        "scripts/convert.sh",
        "scripts/install-omp.sh",
        "dist/omp",
        "project-local",
        "47 command/skill pairs",
    ):
        assert required in guides
    for retired in (
        ".omp/commands",
        "scripts/__init__.py",
        "scripts/setup.sh --platform omp",
        "~/.omp/agent/skills",
    ):
        assert retired not in guides


def test_generated_site_metadata_tracks_the_eighth_build_and_nightly_command():
    """Generated discovery copy must carry the same public roster."""
    command_count = len(list((REPO_ROOT / "commands").glob("*.md")))
    index = (REPO_ROOT / "docs" / "index.html").read_text(encoding="utf-8")
    assert "eight other supported platforms" in index
    assert f"{command_count} commands" in index
    assert 'href="commands/obsidian-nightly.html"' in index

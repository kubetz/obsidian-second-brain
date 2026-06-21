# obsidian-second-brain - Fork Operating Guide

> Written for AI agents working with this fork.
> Read this file first, then read `FORK_MAINTENANCE.md` for detailed maintenance procedures.

## Philosophy

We keep our permanent diff against upstream small - only additive files and targeted infill in existing ones. Source files stay upstream-canonical; agent-neutral naming is generated only in `dist/` and installed output.

## Purpose

This is a fork of [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) - a cross-CLI skill that turns an Obsidian vault into an AI-maintained second brain.

Our goal: make the project platform-neutral and add first-class OMP support, so agents on any CLI can use the same skill without confusion.

## Key files

| File | Purpose |
|---|---|
| `AGENTS.md` | Fork operating guide for AI agents |
| `FORK_MAINTENANCE.md` | Detailed maintenance docs - owned files, dist conversion patterns, pull/build ritual, deferred work |
| `adapters/omp/adapter.sh` | OMP build adapter |
| `commands/obsidian-distill.md` | Fork-owned command infill |
| `install.sh` | OMP install target and generated-dist install path |
| `scripts/__init__.py` | Package marker for `uv run -m` |
| `scripts/build.sh` | Platform dist builder with OMP target |
| `scripts/convert.sh` | Dist-only helper for agent-neutral renames |
| `scripts/setup.sh` | OMP setup and generated-dist install path |
| `tests/test_smoke.py` | Smoke coverage for dist-only conversion and build outputs |
| `uv.lock` | Locked Python tooling/dependency state for this fork |

## Dist-only workflow

Fork-owned source files are the paths above. Do not treat generated neutralized files as permanent source diffs.

Canonical source uses upstream names such as `_CLAUDE.md`, `## For future Claude`, and `references/claude-md-template.md`. Neutral names such as `_AGENTS.md`, `## Synopsis`, and `agents-md-template.md` belong only in `dist/` or installed output.

Build OMP output with:

```bash
bash scripts/build.sh --platform omp
```

That build creates a platform-shaped dist tree. To neutralize upstream/Claude-specific naming in any dist tree, run:

```bash
bash scripts/convert.sh --dist dist/<platform>
```

`scripts/convert.sh` converts only the supplied dist tree, including `dist/claude-code`; it does not mutate upstream-canonical source files.

## Design decisions

| Decision | Why |
|---|---|
| `pyproject.toml` + `uv.lock` symlinked into vault | Research commands use `uv run -m`. Symlinks let them run from the vault CWD directly - no need to know where the repo is. `setup.sh` creates these on install. |

## Extending this file

If you find something worth preserving for future agent work (a gotcha, a pattern, a decision rationale), add it here. Keep it concise - the detail belongs in the toolchain files.

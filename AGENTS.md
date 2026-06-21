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
| `FORK_MAINTENANCE.md` | Detailed maintenance docs - files, dist conversion patterns, pull/build ritual, conflict resolution |
| `FORK_TODO.md` | Remaining tasks for full OMP support |
| `adapters/omp/adapter.sh` | OMP build adapter |
| `scripts/convert.sh` | Dist-only helper for agent-neutral renames |

## Dist-only workflow

Do not edit generated neutralized files in the source tree. Canonical source uses upstream names such as `_CLAUDE.md`, `## For future Claude`, and `references/claude-md-template.md`.

Build OMP output with:

```bash
bash scripts/build.sh --platform omp
```

That build creates a platform-shaped dist tree. To neutralize upstream/Claude-specific naming in any dist tree, run:

```bash
bash scripts/convert.sh --dist dist/<platform>
```

`scripts/convert.sh` converts the supplied dist tree, including `dist/claude-code`. It does not mutate upstream-canonical source files.

## Design decisions

| Decision | Why |
|---|---|
| `pyproject.toml` + `uv.lock` symlinked into vault | Research commands use `uv run -m`. Symlinks let them run from the vault CWD directly - no need to know where the repo is. `setup.sh` creates these on install. |

## Extending this file

If you find something worth preserving for future agent work (a gotcha, a pattern, a decision rationale), add it here. Keep it concise - the detail belongs in the toolchain files.

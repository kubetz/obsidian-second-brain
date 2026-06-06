# obsidian-second-brain — Fork Operating Guide

> Written for AI agents working with this fork.
> Read this file first, then read `FORK_MAINTENANCE.md` for detailed maintenance procedures.

## Philosophy

We keep our permanent diff against upstream small — only additive files and targeted infill in existing ones. Upstream content that undergoes text replacements (85+ files) is treated as **ephemeral transforms**, regenerated after every pull and never committed in converted form.

## Purpose

This is a fork of [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) — a cross-CLI skill that turns an Obsidian vault into an AI-maintained second brain.

Our goal: make the project **platform-neutral** and add first-class **OMP** support, so agents on any CLI can use the same skill without confusion.

## Key files

| File | Purpose |
|---|---|
| `FORK_MAINTENANCE.md` | Detailed maintenance docs — files, convert patterns, pull ritual, conflict resolution |
| `FORK_TODO.md` | Remaining tasks for full OMP support |
| `adapters/omp/adapter.sh` | OMP build adapter |
| `scripts/convert.sh` | Single source of truth for all agent-neutral renames |

**Read `FORK_MAINTENANCE.md` for:** the full list of files added or changed, convert patterns, the pull+convert ritual, gitignore details, and conflict resolution.

## assume-unchanged trap

The conversion marks 85+ ephemeral files as `git assume-unchanged` so they never show up in `git status`. **Our own files (`scripts/convert.sh`, `adapters/omp/adapter.sh`, `scripts/setup.sh`, `FORK_*.md`) are explicitly excluded from assume-unchanged** — they're in the `OUR_FILES` array in `convert.sh`.

**If you edit any file and git doesn't see the change**, it's probably assume-unchanged. Run:

```bash
git update-index --no-assume-unchanged <path>
```

Then stage and commit normally. After committing, re-run `bash scripts/convert.sh --setup` to refresh the assume-unchanged marks on ephemeral files.

## Workflow

After pulling from upstream:

```bash
git pull upstream main
bash scripts/convert.sh --setup    # renames + assume-unchanged
bash scripts/build.sh --platform omp  # rebuild OMP dist
```

## Extending this file

If you find something worth preserving for future agent work (a gotcha, a pattern, a decision rationale), add it here. Keep it concise — the detail belongs in the toolchain files.

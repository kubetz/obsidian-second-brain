# Fork Maintenance

This fork of [obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) generalizes the project for agent-neutral naming and adds Oh My Pi (OMP) support.

## Philosophy

We keep our permanent diff against upstream small - only additive files and targeted infill in existing ones. The 87+ files that undergo text replacements (`_CLAUDE.md` → `_AGENTS.md`, `## For future Claude` → `## Synopsis`, etc.) are treated as **ephemeral transforms** of upstream content, regenerated after every pull. They are never committed in converted form.

## Files we own (committed)

| File | Type | Notes |
|---|---|---|
| `adapters/omp/adapter.sh` | New | Oh My Pi platform adapter |
| `scripts/convert.sh` | New | Idempotent conversion script |
| `FORK_MAINTENANCE.md` | New | This file |
| `scripts/build.sh` | Modified | Added `omp` to --help |
| `install.sh` | Modified | Added `--omp` flag |
| `scripts/setup.sh` | Modified | Added `--platform omp` mode |

## The pull + convert ritual

After every upstream pull:

```bash
# 1. Fetch upstream changes
git pull upstream main

# 2. Apply generic naming to the fresh upstream content
bash scripts/convert.sh --apply

# 3. Refresh git assume-unchanged (if files were added upstream)
bash scripts/convert.sh --setup

# 4. Verify the conversion took
bash scripts/convert.sh --status
```

## Git assume-unchanged

To keep `git status` clean, the conversion uses `git update-index --assume-unchanged` on all transformed files. Git will not check these files for local modifications, so `pull` produces clean merges.

Run `bash scripts/convert.sh --setup` after the initial conversion and after any upstream pull that adds new text files.

Useful commands:

```bash
# See which files are marked assume-unchanged
git ls-files -v | grep '^h'

# Unmark a single file temporarily
git update-index --no-assume-unchanged <path>

# Force git to re-check all assume-unchanged files
git update-index --really-refresh
```

## Adding a new file to the assume-unchanged set

Tracked files matching extensions `.md`, `.py`, `.sh`, `.yml`, `.yaml`, `.json`, `.toml`, `.html`, `.cff`, `.txt` are included. If upstream adds a new file with an unlisted extension, add it to the `case "$ext"` block in `scripts/convert.sh`'s `setup_git_assume_unchanged()`.

## When things conflict

Our modifications are **additive** - they add branches to case statements, new files to arrays, and new entries to switch blocks. If upstream changes the same area:

1. The conflict is usually in one file, not 87 - easy to resolve.
2. After resolving, run `bash scripts/convert.sh --apply` to re-apply the conversion.
3. Run `bash scripts/convert.sh --status` to verify.

The only common conflict source: upstream adding a new platform. That touches `scripts/build.sh` and `adapters/lib.sh` in the same additive fashion we do. Resolve by keeping both additions.

## OMP hooks

OMP supports hooks but in a fundamentally different shape - TypeScript modules using `HookAPI` from `@oh-my-pi/pi-coding-agent/extensibility/hooks`. The existing Claude Code hooks (Python/bash) are **not converted** in this fork. See `https://omp.sh/docs/hooks` for the OMP hook API surface. Conversion is feasible but non-trivial and deferred.

# Fork Maintenance

This fork of [obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) generalizes the project for agent-neutral naming and adds Oh My Pi (OMP) support.

## Philosophy

We keep our permanent diff against upstream small - only additive files and targeted infill in existing ones. The 85+ files that undergo text replacements (`_CLAUDE.md` → `_AGENTS.md`, `## For future Claude` → `## Synopsis`, bare `Claude` → `the agent` in vault output, etc.) are treated as **ephemeral transforms** of upstream content, regenerated after every pull. They are never committed in converted form.

## Files we own (committed)

| File | Type | Notes |
|---|---|---|
| `.gitignore` | Modified | Added ephemeral transform output patterns |
| `AGENTS.md` | New | Fork operating guide for AI agents |
| `FORK_MAINTENANCE.md` | New | This file |
| `FORK_TODO.md` | New | Fork task list |
| `adapters/omp/adapter.sh` | New | Oh My Pi platform adapter |
| `commands/obsidian-distill.md` | Modified | Fork-owned command infill |
| `install.sh` | Modified | Added `--omp` flag |
| `scripts/__init__.py` | New | Package marker for uv run -m |
| `scripts/build.sh` | Modified | Added OMP platform target |
| `scripts/convert.sh` | New | Idempotent conversion script |
| `scripts/setup.sh` | Modified | Added OMP section |

## Convert patterns

`scripts/convert.sh` applies these text replacements across all tracked source files:

1. `_CLAUDE.md` → `_AGENTS.md` (file references in text)
2. `## For future Claude` → `## Synopsis` (preamble headers)
3. `future-Claude` / `Future-Claude` / `future Claude` / `Future Claude` → `future agent` / `Future agent` (all forms)
4. Bootstrap template strings: `Claude Operating Manual` → `Vault Operating Manual`, `Claude should auto-save` → `The agent should auto-save`, `Claude, update my _CLAUDE.md` → `update my _AGENTS.md`
5. Template filename renames on disk (claude-md-*.md → agents-md-*.md)

The ephemeral transform outputs (the new filenames) are gitignored. Only `scripts/convert.sh` itself is committed with these patterns.


## After editing our own files

Our fork-owned files sometimes contain banned substitution characters (curly quotes, em-dashes, typographic apostrophes) from prose writing. The CI pipeline checks for these with `scripts/sweep_non_ascii.py --check` and will fail if they're present.

Before committing:

```bash
python scripts/sweep_non_ascii.py --apply
```

This replaces all banned characters with ASCII equivalents while preserving code fences and backtick spans.

## The pull + convert ritual

After every upstream pull:

```bash
# 1. Fetch and rebase (NO merge commits)
git fetch upstream
git rebase upstream/main

# 2. Apply generic naming to the fresh upstream content
bash scripts/convert.sh --apply

# 3. Set assume-unchanged on converted files
bash scripts/convert.sh --setup

# 4. Verify the conversion took
bash scripts/convert.sh --status
```

## Git assume-unchanged - how it works

To keep `git status` focused on real fork work, `bash scripts/convert.sh --setup`
marks only deterministic conversion outputs with `git update-index
--assume-unchanged`.

The mark set is intentionally narrow:

1. A content-changed path is marked only when the worktree bytes exactly equal
   the deterministic conversion of the `HEAD` blob for that same path.
2. Deliberate tracked source deletions from file renames are marked when the
   generated destination exists:
   - `references/claude-md-template.md`
   - `references/claude-md-assistant-template.md`
   - `examples/sample-vault/_CLAUDE.md`
3. Stale lowercase-`h` paths from the old broad-extension workflow are unmarked
   when they are not expected conversions.
4. Fork-owned files in the table above are never silently repaired. If any is
   lowercase `h`, `--setup` fails before converting content and tells you to run
   `git update-index --no-assume-unchanged <path>`.

Run `bash scripts/convert.sh --setup` after every `--apply`.

### Why the flag can be lost

Git stores the assume-unchanged bit in the index, not in the committed tree.
After a rebase, branch switch, checkout, or file replacement, paths that should
be hidden can become visible again. Re-running `--setup` re-evaluates the current
worktree against converted `HEAD` content and re-marks only paths that still
match the conversion exactly.

If you edit a transformed upstream file for a real feature, it no longer matches
the converted `HEAD` bytes. `--setup` leaves that path visible and warns:
`Not marking non-conversion change: <path>`.

### How an AI agent evaluates assume-unchanged state

After a rebase or merge, the AI should verify and fix assume-unchanged state
before yielding. The logic:

1. **Run `git status`.** If clean, done. If dirty, proceed.
2. **Run `bash scripts/convert.sh --setup`.** This re-applies conversion,
   re-marks expected conversions, unmarks stale non-conversion lowercase-`h`
   paths, and fails loudly if a fork-owned file is hidden.
3. **Re-check `git status`.** If clean, done.
4. **If a fork-owned file caused failure**, unmark it explicitly:

   ```bash
   git update-index --no-assume-unchanged <path>
   ```

   Then rerun `bash scripts/convert.sh --setup`.
5. **If non-conversion changes remain visible**, handle them normally. They are
   real worktree changes, not ephemeral conversion noise.

Useful commands:

```bash
# See which files are marked assume-unchanged
git ls-files -v | grep '^h'

# Unmark a single file temporarily
git update-index --no-assume-unchanged <path>

# Force git to re-check all assume-unchanged files
git update-index --really-refresh
```

## Gitignore

Ephemeral transform outputs that git would see as new/untracked files are covered by `.gitignore`:

```
references/agents-md-*.md
examples/sample-vault/_AGENTS.md
```

These are regenerated by `bash scripts/convert.sh --setup` and never committed.
`assume-unchanged` handles only tracked files whose worktree state exactly
matches the deterministic conversion or deliberate rename-source deletion.

## Adding a new conversion target

Do not broaden assume-unchanged by extension. Add the source text or rename to
`scripts/convert.sh`, then make the deterministic conversion check recognize
the resulting path. A path should be marked only when its worktree state can be
derived from the committed `HEAD` blob or from a deliberate tracked source
rename.

## Editing our own files

Fork-owned files are the paths listed in **Files we own (committed)**. They are
also listed in `scripts/convert.sh`'s `OUR_FILES` array and must never be marked
assume-unchanged.

**If changes don't appear in `git diff` or `git status`:** the file is
accidentally assume-unchanged. Unmark it:

```bash
git update-index --no-assume-unchanged <path>
```
Then stage and commit normally. Before yielding, run
`bash scripts/convert.sh --setup` so expected conversion outputs are hidden
again.

**Caveat:** After a checkout, branch switch, or restore, always verify with
`git status` before committing. If fork-owned edits are missing from the final
diff, check `git ls-files -v | grep '^h'` for unexpectedly marked files.

## When things conflict

Our modifications are **additive** - they add branches to case statements, new files to arrays, and new entries to switch blocks. If upstream changes the same area:

1. The conflict is usually in one file, not 87 - easy to resolve.
2. After resolving, run `bash scripts/convert.sh --apply` to re-apply the conversion.
3. Run `bash scripts/convert.sh --status` to verify.

The only common conflict source: upstream adding a new platform. That touches `scripts/build.sh` and `adapters/lib.sh` in the same additive fashion we do. Resolve by keeping both additions.

## OMP hooks

OMP supports hooks but in a fundamentally different shape - TypeScript modules using `HookAPI` from `@oh-my-pi/pi-coding-agent/extensibility/hooks`. The existing Claude Code hooks (Python/bash) are **not converted** in this fork. See `https://omp.sh/docs/hooks` for the OMP hook API surface. Conversion is feasible but non-trivial and deferred.

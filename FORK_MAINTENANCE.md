# Fork Maintenance

This fork of [obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) keeps upstream source canonical, adds Oh My Pi (OMP) support, and generates agent-neutral naming only in `dist/` or installed output.

## Philosophy

Keep the permanent diff against upstream small. Source files use upstream names such as `_CLAUDE.md`, `## For future Claude`, and `references/claude-md-template.md`. Platform-neutral names such as `_AGENTS.md`, `## Synopsis`, and `agents-md-template.md` are generated after build in `dist/<platform>/`.

Do not commit neutralized source-tree files. If they appear in the source tree, delete them and rebuild the target dist tree.

## Files we own (committed)

| File | Type | Notes |
|---|---|---|
| `AGENTS.md` | New | Fork operating guide for AI agents |
| `FORK_MAINTENANCE.md` | New | This file |
| `FORK_TODO.md` | New | Fork task list |
| `adapters/omp/adapter.sh` | New | Oh My Pi platform adapter |
| `commands/obsidian-distill.md` | New | Fork-owned command infill |
| `install.sh` | Modified | Adds OMP install target and installs from generated dist |
| `scripts/__init__.py` | New | Package marker for `uv run -m` |
| `scripts/build.sh` | Modified | Adds OMP platform target and builds platform dist trees |
| `scripts/convert.sh` | Modified | Optional dist-only neutralization helper |
| `scripts/setup.sh` | Modified | Adds OMP setup and installs from generated dist |

## Dist conversion patterns

`scripts/convert.sh` is the single source of truth for agent-neutral naming, but it operates only on generated dist directories:

```bash
bash scripts/convert.sh --dist dist/<platform>
```

`bash scripts/build.sh --platform <platform>` creates the platform-shaped dist tree without running this helper. If you skip `convert.sh`, copied source content remains upstream/Claude-specific except for adapter-local path and tool-name rewrites. Run `convert.sh` explicitly when you want agent-neutral dist content; it converts whichever dist tree it is given, including `dist/claude-code`.

Current dist-only replacements:

1. `_CLAUDE.md` -> `_AGENTS.md` in file content.
2. `## For future Claude` -> `## Synopsis`.
3. `future-Claude` / `Future-Claude` / `future Claude` / `Future Claude` -> `future agent` / `Future agent`.
4. Bootstrap template strings such as `Claude Operating Manual` -> `Vault Operating Manual` and `Claude should auto-save` -> `The agent should auto-save`.
5. Template references `claude-md-template` -> `agents-md-template` and `claude-md-assistant-template` -> `agents-md-assistant-template`.
6. Recursive dist file renames: `claude-md-template.md` -> `agents-md-template.md`, `claude-md-assistant-template.md` -> `agents-md-assistant-template.md`, and `_CLAUDE.md` -> `_AGENTS.md`.

## After editing our own files

Fork-owned files sometimes contain banned substitution characters from prose writing. CI checks this with `scripts/sweep_non_ascii.py --check`.

Before committing, check for banned characters:

```bash
python scripts/sweep_non_ascii.py --check
```

Resolve any findings before staging the fork-owned file.

## Pull + build ritual

After every upstream pull:

```bash
git fetch upstream
git rebase upstream/main
```

Build the platform output you need:

```bash
bash scripts/build.sh --platform omp
```

If you need agent-neutral dist content, run the converter explicitly:

```bash
bash scripts/convert.sh --dist dist/omp
```

Source should remain upstream-canonical after both commands. Neutralized output belongs under `dist/<platform>/`.

## Gitignore

`dist/` is ignored because it is generated build output. Source-tree neutralized files are not ignored; if `references/agents-md-*.md` or `examples/sample-vault/_AGENTS.md` appears outside `dist/`, treat it as stale generated output and remove it.

## Adding a new conversion target

Add the literal replacement or dist rename to `scripts/convert.sh`, then add or update smoke coverage that builds a representative platform, runs `convert.sh --dist dist/<platform>`, and verifies both facts:

1. Source files stayed canonical.
2. The converted platform dist tree contains the neutralized text or renamed path.

Do not add source mutation.

## Editing our own files

Fork-owned files are the paths listed in **Files we own (committed)**. They are normal tracked source files; edit, review, stage, and commit them normally.

## When things conflict

Our modifications are additive: they add branches to case statements, new files to arrays, and new entries to switch blocks. If upstream changes the same area, the conflict is usually in one file, not dozens.

After resolving, build the target platform dist tree and inspect generated output. Source files should remain upstream-canonical; platform-neutral naming belongs in `dist/<platform>/`.

The only common conflict source: upstream adding a new platform. That touches `scripts/build.sh` and `adapters/lib.sh` in the same additive fashion we do. Resolve by keeping both additions.

## OMP hooks

OMP supports hooks but in a different shape: TypeScript modules using `HookAPI` from `@oh-my-pi/pi-coding-agent/extensibility/hooks`. The existing Claude Code hooks (Python/bash) are not converted in this fork. See `https://omp.sh/docs/hooks` for the OMP hook API surface. Conversion is feasible but non-trivial and deferred.

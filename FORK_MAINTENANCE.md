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
| `adapters/omp/adapter.sh` | New | Oh My Pi platform adapter |
| `commands/obsidian-distill.md` | New | Fork-owned command infill |
| `install.sh` | Modified | Adds OMP install target and installs from generated dist |
| `scripts/__init__.py` | New | Package marker for `uv run -m` |
| `scripts/build.sh` | Modified | Adds OMP platform target and builds platform dist trees |
| `scripts/convert.sh` | New | Optional dist-only neutralization helper |
| `scripts/setup.sh` | Modified | Adds OMP setup and installs from generated dist |
| `tests/test_smoke.py` | Modified | Smoke coverage for dist-only conversion and build outputs |
| `uv.lock` | Modified | Locked Python tooling/dependency state for this fork |

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

## Deferred work

### OMP hook conversion

OMP supports hooks as TypeScript modules using `HookAPI` from `@oh-my-pi/pi-coding-agent/extensibility/hooks`, not bash or Python subprocess hooks. The three Claude Code hooks below need OMP-specific ports rather than direct script reuse.

Reference: `https://omp.sh/docs/hooks`.

#### OMP hook surface

Account for the full OMP hook surface before porting any hook:

| OMP event | Available? | Surface | Purpose |
|---|---|---|---|
| `session_start` | yes | Observational | Fires once per session; candidate replacement for session-start context loading |
| `session_shutdown` | yes | Observational | No current port target |
| `turn_start` / `turn_end` | yes | Observational | No current port target |
| `tool_call` | yes | Gate | Can return `{ block: true, reason }` to refuse a call |
| `tool_result` | yes | Rewrite | Can return `{ content?, details?, isError? }` to mutate model-visible tool output |
| `session_before_compact` | yes | Gate | Can return `{ cancel: true }` to veto compaction |
| `session_before_branch` | yes | Gate | Can veto branching |
| `session_before_switch` | yes | Gate | Can veto tree switching |
| `session_before_tree` | yes | Gate | Can veto tree creation |
| `message_*` | yes | Observational | Useful for auditing, not for current hook parity |
| `tool_execution_*` | yes | Observational | Useful for auditing, not for current hook parity |

Missing event: OMP has no `session_after_compact` or `compact_done` event. It can veto compaction before it happens, but it cannot react to a completed compaction.

#### Hook 1: `load_vault_context.py` - session start

| Field | Value |
|---|---|
| Source file | `hooks/load_vault_context.py` |
| Claude mechanism | `SessionStart` bash hook |
| OMP mechanism | `session_start` TypeScript hook |
| Feasibility | Feasible |
| Priority | Medium - saves tokens per session |

Current function: injects `_AGENTS.md` into context once per session when the current working directory is inside the vault.

OMP conversion: rewrite as a TypeScript `session_start` hook under the OMP hook tree. The port should read `OBSIDIAN_VAULT_PATH`, load the vault root `_AGENTS.md` only when the session is inside that vault, and inject the file through the real OMP context API after that API is confirmed.

```ts
// ~/.omp/agent/hooks/pre/load-vault-context.ts
import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

export default function (pi: HookAPI) {
  pi.on("session_start", async (event) => {
    const vault = process.env.OBSIDIAN_VAULT_PATH;
    if (!vault) return;

    const guide = await readFile(join(vault, "_AGENTS.md"), "utf8");
    // Confirm the real OMP context API before wiring this:
    // pi.addContext(guide), pi.injectSystem(guide), or equivalent.
  });
}
```

Check before implementation: confirm whether OMP's `HookAPI` exposes a context-injection method. If not, inspect the `ExtensionAPI` superset from `@oh-my-pi/pi-coding-agent/extensibility/extensions` for an equivalent such as `addContext()` or `injectSystem()`.

#### Hook 2: `validate-ai-first.sh` - post tool use

| Field | Value |
|---|---|
| Source file | `hooks/validate-ai-first.sh` |
| Claude mechanism | `PostToolUse` bash hook |
| OMP mechanism | `tool_result` TypeScript rewrite |
| Feasibility | Partial - UX differs |
| Priority | Low - commands carry rules inline |

Current function: after every Write/Edit, validates that the changed file has correct frontmatter, a `## Synopsis` preamble, `ai-first: true`, and no banned non-ASCII characters. The current hook is non-blocking and warning-only.

OMP conversion: use `tool_result`, inspect Write/Edit results, then surface warnings by mutating the content the model sees.

```ts
// ~/.omp/agent/hooks/post/validate-ai-first.ts
import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";
import { readFile } from "node:fs/promises";

export default function (pi: HookAPI) {
  pi.on("tool_result", async (event) => {
    if (event.toolName !== "write" && event.toolName !== "edit") return;

    // Inspect the written file and collect warnings.
    // Append warnings to returned content/details so the model sees them.
  });
}
```

UX difference: Claude Code's `PostToolUse` sends warnings to stderr, which is visible in the user's UI. OMP's `tool_result` rewrites what the model sees. The warning goes to the model, not directly to the user; the model could paraphrase it, ignore it, or surface it. Preserve that semantic difference in any implementation notes or user-facing docs.

Validation rules to port from `hooks/validate-ai-first.sh`:

1. Frontmatter delimiters (`--- ... ---`) are well formed.
2. Frontmatter uses spaces, not tabs, because YAML requires spaces.
3. Required fields exist: `date`, `type`, `tags`, and `ai-first: true`.
4. A `## Synopsis` preamble exists in the body.
5. Banned non-ASCII substitution characters are absent, including em dashes, en dashes, curly quotes, smart apostrophes, and Unicode math; delegate the actual check to `scripts/sweep_non_ascii.py`.

#### Hook 3: `obsidian-bg-agent.sh` - post compact

| Field | Value |
|---|---|
| Source file | `hooks/obsidian-bg-agent.sh` |
| Claude mechanism | `PostCompact` bash hook |
| OMP mechanism | No matching post-compact event |
| Feasibility | Blocked |
| Priority | Low - user can run `/obsidian-save` manually |

Current function: after Claude compacts a session, spawns a headless `claude --dangerously-skip-permissions -p` process to propagate the compact summary to the vault. It records decisions, tasks, people, project updates, dev logs, ideas, learnings, shoutouts, and mentions.

OMP conversion: infeasible without a new event. OMP has `session_before_compact` as a veto gate, but no event that fires after compaction completes. Do not fake post-compact parity.

Options if this work is revived:

1. Replace compaction: write a `session_before_compact` hook that cancels compaction, then runs custom logic inline to extract vault-worthy content from the transcript before allowing a later compaction. This is messy and fragile.
2. Periodic alternative: run a periodic agent via cron or `at` that reads the latest transcript and propagates vault-worthy material. This loses immediacy but is architecturally cleaner.
3. Upstream enhancement: request a `compact_done` or `session_after_compact` event from the OMP project.

Prompt and constraints to preserve from `hooks/obsidian-bg-agent.sh`:

```text
INSTRUCTIONS:
1. Read _AGENTS.md at the vault root first - follow its rules exactly.
2. Identify all vault-worthy items in the summary:
   - Decisions made or confirmed
   - Tasks created, assigned, or completed
   - People mentioned (new interactions, context added)
   - Projects worked on or updated
   - Dev work done (code written, bugs fixed, features shipped)
   - Ideas, learnings, or insights
   - Shoutouts or mentions worth logging
3. Before creating any note, search for an existing one. Never duplicate.
4. Update or create notes:
   - People: update interaction log; create stub if missing
   - Projects: update status, Recent Activity, Key Decisions
   - Dev work: create or update Dev Logs/YYYY-MM-DD - Project.md
   - Tasks: add to the right Boards/ kanban column
   - Ideas: save to Ideas/
   - Decisions: append to project note's Key Decisions
5. Update today's daily note:
   - Create from template if missing
   - Link everything touched

CONSTRAINTS:
- Use filesystem tools only (Read, Write, Edit, Glob, Grep)
- Run completely silently. No output, no questions.
- If nothing vault-worthy, exit with no changes.
- Match vault's existing style, schemas, conventions.
- Do not archive, delete, or merge - only add or update.
```

If rebuilt as a periodic transcript-reading agent, keep the same behavior: read the vault `_AGENTS.md` first, search before creating notes, update existing notes in place, update today's daily note, link everything touched, and use filesystem tools only.

#### Summary table

| Hook | Claude mechanism | OMP mechanism | Feasibility | Priority |
|---|---|---|---|---|
| `load_vault_context.py` | `SessionStart` bash hook | `session_start` TypeScript hook | Feasible | Medium - saves tokens per session |
| `validate-ai-first.sh` | `PostToolUse` bash hook | `tool_result` TypeScript rewrite | Partial - UX differs | Low - commands carry rules inline |
| `obsidian-bg-agent.sh` | `PostCompact` bash hook | No matching event | Blocked | Low - user can run `/obsidian-save` manually |

#### Key files and APIs

| Reference | Why |
|---|---|
| `hooks/load_vault_context.py` | Session-start context-loading logic to port |
| `hooks/validate-ai-first.sh` | Validation rules to port |
| `hooks/obsidian-bg-agent.sh` | Background propagation prompt and constraints to preserve |
| `scripts/sweep_non_ascii.py` | Shared banned-character checker for validate hook |
| `scripts/convert.sh` | Dist-only naming conversion to run after porting |
| `FORK_MAINTENANCE.md` | Pull, build, and conversion workflow |
| `https://omp.sh/docs/hooks` | OMP hook API reference |
| `@oh-my-pi/pi-coding-agent/extensibility/hooks` | `HookAPI` types |
| `@oh-my-pi/pi-coding-agent/extensibility/extensions` | Possible context-injection superset |

Local hook check:

```bash
omp -p '/extensions'
# Hooks live at ~/.omp/agent/hooks/pre/*.ts or ~/.omp/agent/hooks/post/*.ts
```

### Pi adapter

Dropped from scope. If revived, follow the OMP adapter pattern in `adapters/omp/adapter.sh`. Pi stores skills at `~/.pi/skills/` and has no hook system.

### OMP meta-skill

Not needed. The dist-only workflow is covered by:

- `scripts/convert.sh` - optional dist neutralizer
- `FORK_MAINTENANCE.md` - build and convert workflow docs

The OMP adapter copies `scripts/` and `references/` into the dist tree, so `convert.sh` ships with every OMP build.

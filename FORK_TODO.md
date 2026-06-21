# Fork TODO

Unfinished work and reference material for future maintainers.

## Deferred: OMP Hook Conversion

OMP supports hooks but as TypeScript modules via `HookAPI` from `@oh-my-pi/pi-coding-agent/extensibility/hooks`, not bash/Python subprocesses. The three Claude Code hooks below need to be rewritten for OMP.

Reference: [omp.sh/docs/hooks](https://omp.sh/docs/hooks)

### OMP Hook Surface

| OMP Event | Available? | Purpose |
|---|---|---|
| `session_start` | yes | Observational - fires once per session |
| `session_shutdown` | yes | Observational |
| `turn_start` / `turn_end` | yes | Observational |
| `tool_call` | yes (gate) | Can `{ block: true, reason }` to refuse |
| `tool_result` | yes (rewrite) | Can `{ content?, details?, isError? }` to mutate |
| `session_before_compact` | yes (gate) | Can `{ cancel: true }` to veto compaction |
| `session_before_branch` | yes (gate) | Can veto branching |
| `session_before_switch` | yes (gate) | Can veto tree switching |
| `session_before_tree` | yes (gate) | Can veto tree creation |
| `message_*` | yes | Observational |
| `tool_execution_*` | yes | Observational |

**Missing:** OMP has no `session_after_compact` / `compact_done` event. You can veto compaction but cannot react to it.

### Hook 1: `load_vault_context.py` - SessionStart

**File:** `hooks/load_vault_context.py`
**Function:** Injects `_AGENTS.md` into context once per session when cwd is inside vault.

**OMP conversion:** Feasible. Rewrite as a TypeScript `session_start` hook.

```
// ~/.omp/agent/hooks/pre/load-vault-context.ts
import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

export default function (pi: HookAPI) {
  pi.on("session_start", async (event) => {
    const vault = process.env.OBSIDIAN_VAULT_PATH;
    if (!vault) return;
    // Try to read _AGENTS.md and inject into context
    // Use pi.addContext() or equivalent OMP API
  });
}
```

**Check:** Does OMP's `HookAPI` expose a context-injection method? Look for `pi.addContext()`, `pi.injectSystem()`, or similar on the `ExtensionAPI` superset (`@oh-my-pi/pi-coding-agent/extensibility/extensions`).

### Hook 2: `validate-ai-first.sh` - PostToolUse

**File:** `hooks/validate-ai-first.sh`
**Function:** After every Write/Edit, validates the file has correct frontmatter, `## Synopsis` preamble, `ai-first: true`, and no banned non-ASCII chars. Non-blocking warning.

**OMP conversion:** Partially feasible via `tool_result`. OMP fires `tool_result` after every tool invocation. You could inspect the result for Write/Edit tools and surface warnings by mutating the content the model sees.

```
// ~/.omp/agent/hooks/post/validate-ai-first.ts
import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";
import { readFile } from "node:fs/promises";

export default function (pi: HookAPI) {
  pi.on("tool_result", async (event) => {
    if (event.toolName !== "write" && event.toolName !== "edit") return;
    // Inspect the written file, surface warnings as content note
  });
}
```

**⚠️ UX difference:** Claude Code's `PostToolUse` sends warnings to stderr (visible in the user's UI). OMP's `tool_result` rewrites what the model sees - the warning goes to the model, not the user. The model could paraphrase it, ignore it, or surface it. The semantics differ.

**Validation rules to port** (from `hooks/validate-ai-first.sh`):
1. Frontmatter delimiters (`--- ... ---`) are well-formed
2. No tabs inside frontmatter (YAML requires spaces)
3. Required fields: `date`, `type`, `tags`, `ai-first: true`
4. `## Synopsis` preamble exists in body
5. No banned non-ASCII substitution characters (em/en-dashes, curly quotes, smart apostrophes, Unicode math) - delegate to `scripts/sweep_non_ascii.py` for the actual check

### Hook 3: `obsidian-bg-agent.sh` - PostCompact

**File:** `hooks/obsidian-bg-agent.sh`
**Function:** After Claude compacts a session, spawns a headless `claude --dangerously-skip-permissions -p` to propagate the compact summary to the vault (decisions, tasks, people, dev logs).

**OMP conversion:** Infeasible without a new event.

OMP has `session_before_compact` (veto gate) but no event that fires *after* compaction completes. You cannot react to a compaction that already happened. Options:

1. **Replace compaction:** Write a `session_before_compact` hook that cancels it, then runs your own logic inline to extract vault-worthy content from the transcript before letting compaction proceed. Messy and fragile.
2. **Periodic alternative:** Instead of reacting to compaction, run a periodic agent via cron or `at` that reads the latest transcript and propagates. Loses the immediacy but is architecturally clean.
3. **Upstream enhancement:** Request a `compact_done` or `session_after_compact` event from the OMP project.

**Prompt to port** (from `hooks/obsidian-bg-agent.sh` lines 61-93):
```
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
- Do not archive, delete, or merge — only add or update.
```

### Summary Table

| Hook | Claude mechanism | OMP mechanism | Feasibility | Priority |
|---|---|---|---|---|
| load_vault_context | `SessionStart` bash hook | `session_start` TS hook | ✅ Feasible | Medium - saves tokens per session |
| validate-ai-first | `PostToolUse` bash hook | `tool_result` TS rewrite | ⚠️ Partially - UX differs | Low - commands carry rules inline |
| obsidian-bg-agent | `PostCompact` bash hook | No event available | ❌ Blocked | Low - user runs `/obsidian-save` manually |

### Key files to reference during conversion

| File | Why |
|---|---|
| `hooks/load_vault_context.py` | SessionStart logic to port |
| `hooks/validate-ai-first.sh` | Validation rules to port |
| `hooks/obsidian-bg-agent.sh` | Propagation prompt to port |
| `scripts/sweep_non_ascii.py` | Non-ASCII check (referenced by validate hook) |
| `scripts/convert.sh` | Naming conversion to apply after porting |
| `FORK_MAINTENANCE.md` | Pull + convert workflow |
| `https://omp.sh/docs/hooks` | OMP hook API reference |
| `@oh-my-pi/pi-coding-agent/extensibility/hooks` | HookAPI types |
| `@oh-my-pi/pi-coding-agent/extensibility/extensions` | ExtensionAPI superset (for addContext etc.) |

### Testing hooks locally

```bash
omp -p '/extensions'   # confirm hook loaded and from which path
# Hooks live at ~/.omp/agent/hooks/pre/*.ts or ~/.omp/agent/hooks/post/*.ts
```

---

## Future: Pi Adapter

Dropped from scope. If revisited, follow the OMP adapter pattern (`adapters/omp/adapter.sh`). Pi stores skills at `~/.pi/skills/`. It has no hook system.

---

## Future: OMP Meta-skill for Conversion Workflow

Not created - the dist-only workflow is covered by:
- `scripts/convert.sh` - optional dist neutralizer
- `FORK_MAINTENANCE.md` - build + convert workflow docs

The OMP adapter copies `scripts/` and `references/` into the dist tree, so `convert.sh` ships with every OMP build.

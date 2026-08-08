---
description: Run the existing sleeptime vault-consolidation procedure on demand.
category: maintenance
triggers_en: ["run nightly maintenance", "close out the vault for today", "consolidate the vault overnight"]
triggers_es: ["ejecutar mantenimiento nocturno", "cerrar la bóveda por hoy", "consolidar la bóveda durante la noche"]
triggers_pt: ["executar manutenção noturna", "encerrar o cofre por hoje", "consolidar o cofre durante a noite"]
triggers_zh: ["执行夜间整理", "结束今日笔记整理", "夜间整合知识库"]
exclude: [hermes]
---

Use the obsidian-second-brain skill. Execute `/obsidian-nightly`:

Read `_CLAUDE.md` first if it exists, then read `references/folder-map.md`. Resolve the vault's existing folders for daily notes, boards, entities, concepts, decisions, sources, logs, and indexes from those sources before writing. With no folder map, default to the wiki-style `wiki/entities/` + `wiki/concepts/` + `wiki/decisions/`, else the Obsidian-style `People/` + `Knowledge/` (and `Ideas/`) + `Knowledge/`. Do not assume `wiki/*`, `Daily/`, `Logs/`, or `log.md` paths when the vault defines another schema; a resolved folder that does not exist is a skip, not an error.

This is a sleeptime consolidation pass: the vault should be smarter when the user wakes up.

Phase 1 - Close the day:
- Read today's daily note in the resolved daily-note location. Append a `## End of Day` section with a 3-5 bullet summary.
- Move already-completed kanban or board tasks to Done using the vault's existing board structure.

Phase 2 - Reconcile:
- Scan the resolved entity folder for outdated roles, companies, or descriptions that conflict with newer daily notes.
- Scan the resolved concept folder for claims contradicted by recently ingested sources.
- Flag every contradiction as a `type: conflict` note with `status: open` in the resolved decision folder. Link or quote the conflicting evidence clearly; do not rewrite either source.

Phase 3 - Synthesize:
- Scan sources ingested today and yesterday in the resolved source locations. Find concepts supported by at least two unrelated recent sources.
- If patterns are found, create a synthesis note in the resolved concept folder with evidence and interpretation.

Phase 4 - Heal:
- Find notes created today with no incoming links. Add links from relevant existing pages.
- Flag entity timeline entries that may need an `until` date without changing dates autonomously.
- Rebuild `index.md` or the vault's resolved primary index to reflect today's changes.

Phase 5 - Log:
- Append an operation-log entry using the vault's existing log location and shape: if `Logs/` exists write `**HH:MM** - nightly | End of day + X flagged, Y synthesized, Z orphans linked` to `Logs/YYYY-MM-DD.md`; otherwise append `## [YYYY-MM-DD] nightly | End of day + X flagged, Y synthesized, Z orphans linked` to `log.md`.

Do not ask questions. Do not delete, archive, merge, or resolve contradictions destructively. Only add, update, and link. Save and stop.

---

**AI-first rule:** Every note created or updated by this command MUST follow `references/ai-first-rules.md` - `## For future agent` preamble, rich frontmatter (`type`, `date`, `tags`, `ai-first: true`, plus type-specific fields), recency markers per external claim, mandatory `[[wikilinks]]` for every person/project/concept referenced, sources preserved verbatim with URLs inline, and confidence levels where applicable. If that path does not resolve from your working directory, search upward for it; if you still cannot read it, say so before writing rather than producing a note that silently skips the rule.

**Anti-fabrication:** Search exhaustively before claiming any note, person, or file is absent - false absence is the most common failure mode - and never invent facts, entities, dates, or evidence (mark unknowns as `TBD`). See the anti-fabrication and search-completeness hard rules in `references/ai-first-rules.md`.

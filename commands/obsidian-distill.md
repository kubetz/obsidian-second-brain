---
description: Distill durable knowledge from a conversation with auditable source excerpts
category: vault
triggers_en: ["distill this conversation", "extract knowledge from conversation", "save this as learning", "create notes from this", "obsidian distill"]
---

Use the obsidian-second-brain skill. Execute `/obsidian-distill`:

1. Read vault context first:
   - Read `_CLAUDE.md` first if it exists in the vault root, especially the Folder Map and any command-specific rules.
   - Read `index.md` if it exists so new notes integrate with the current vault instead of creating duplicates.
   - Use the vault's existing folder map and naming style. Prefer existing project, knowledge, decision, writing, or source folders over inventing new top-level folders.

2. Classify the conversation before writing anything:
   - **Domain** - the broad subject, using the vault's existing domain names when possible.
   - **Nature** - one or more of `teaching`, `peer ideation`, `editing / proofreading`, `planning / decision-making`, `troubleshooting / debugging`, or `other`.
   - **Distillation mode** - one or more of `source-archive`, `knowledge-distill`, `output-polish`, `decision-record`, or `learning-path`.
   - **Scope** - `full-conversation`, `selected-excerpts`, or `single-thread`.
   - **Durable output** - concepts, decisions, methods, reusable examples, polished writing, code, plans, or other material worth preserving.
   - Derive `display_title`, ASCII-safe `file_title`, short kebab-case `slug`, classification values, and `knowledge_tags`. If the domain is unclear, use the user's supplied title or the clearest topic in the conversation.

3. Save the auditable source transcript:
   - Choose the source path from the vault schema and call it `source_path`:
     - Use an existing conversation-source folder from `_CLAUDE.md` or `index.md` if one exists.
     - Otherwise use `raw/transcripts/YYYY-MM-DD - <file_title>.md`.
   - Treat this as immutable raw-source material, not a synthesized AI-first note. Use Source Note frontmatter from `/obsidian-ingest`: `date`, `tags: [source, transcript, conversation]`, `source_type: transcript`, `content_hash`, optional `source_title` or `source_url` if known, plus `nature`, `mode`, and `scope` when useful for retrieval.
   - Add `## For future Claude` with 2-3 sentences explaining what was preserved, why it matters, and whether the transcript is full or excerpted. This heading is for retrieval, not a signal that the raw transcript is a synthesized note.
   - Include the minimum verbatim source needed to audit the distilled notes:
     - For `full-conversation`, include every user and assistant turn.
     - For `selected-excerpts` or `single-thread`, include only relevant teaching, ideation, decision, troubleshooting, context-setting, and output-producing turns.
     - Omit operational setup, command chatter, ingestion boilerplate, unrelated branches, and ephemeral context unless needed to understand preserved material.
   - If anything is omitted, add `## Omitted ranges` with turn ranges and short reasons. Do not summarize omitted knowledge; include any durable material verbatim instead.
   - Preserve included source exactly as it appeared. Do not synthesize, clean up, reorder, or merge source blocks.

4. Add source transcript block IDs:
   - Annotate every included user block with `^<slug>-u-1`, `^<slug>-u-2`, and so on.
   - Annotate every included assistant block with `^<slug>-a-1`, `^<slug>-a-2`, and so on.
   - Put each block ID on its own line immediately after the paragraph or block it anchors, followed by one blank line before the next block:

     ```text
     What do you think about this approach?
     ^llm-ideas-u-3

     I think the tradeoff is worth it because...
     ^llm-ideas-a-3
     ```

   - Do not put block IDs on the same line as text, inside lists, after blank content, or separated from their anchored paragraph by extra blank lines.

5. Save finished output only when the conversation produced one:
   - If the conversation created a reusable draft, design, code snippet, plan, prompt, or polished idea, save that artifact to the most appropriate existing vault location.
   - Prefer existing project, writing, knowledge, or decision locations found in `_CLAUDE.md` and `index.md`.
   - Do not invent new top-level artifact folders unless the vault already uses them or the user explicitly asks for that structure.
   - Link the artifact back to the source transcript. The source transcript remains the evidence; the artifact should be usable without rereading the conversation.

6. Synthesize reusable notes:
   - Read every included source block and group durable material by concept, decision, method, example, output, or open question, regardless of conversation order.
   - Search existing notes exhaustively by aliases and nearby terms before creating a new note. Update or extend existing notes when they cover the same concept.
   - Use the vault's existing knowledge, project, decision, or domain folders. If no suitable folder exists, create the smallest schema-consistent location and update the Folder Map later.
   - For teaching, create focused concept notes or add `## Learning path` inside a note when useful.
   - For ideation, capture emerged ideas, user-vs-AI provenance, refinements, rejected options, and conclusions.
   - For editing, capture reusable techniques and patterns; keep final polished output in step 5.
   - For planning or decisions, capture the decision, alternatives, tradeoffs, rejected paths, and rationale.
   - For troubleshooting, capture symptoms, diagnosis steps, root cause, resolution, and the related project note if any.
   - For mixed conversations, create the smallest set of notes that preserves the durable signal.

7. Apply provenance rules to every synthesized note:
   - Frontmatter includes `date`, a correct `type`, `tags`, `source`, `confidence`, `verification`, and `ai-first: true`.
   - `source` must point to the chosen source transcript path, for example `source: "[[<source_path>]]"`.
   - `## For future Claude` is mandatory and states what the note covers, why it matters, and any scope or staleness caveat.
   - Every substantive claim, idea, decision, example, or technique links to a path-qualified source block, such as `[[<source_path>#^<slug>-a-N]]` or `[[<source_path>#^<slug>-u-N]]`.
   - Block references prove only what the conversation said. They do not prove external factual truth.
   - Preserve URLs inline for external factual claims. Add recency markers for time-sensitive claims.
   - Mark unsourced external claims as `conversation-stated` or `needs-verification` instead of presenting them as verified fact.
   - Name notes by their concept or artifact, not by the conversation title.
   - Do not create notes for purely ephemeral context.

8. Create a syllabus only when warranted:
   - Create a syllabus only if the teaching spans multiple subtopics, multiple notes need an ordered path, the output is course-like, or the user explicitly requested one.
   - Include `## For future Claude`, prerequisites, recommended order, module links, complexity, and key source block links.
   - If the teaching is a single focused concept, add `## Learning path` inside that concept note only if useful.

9. Update vault structure:
   - Update today's daily note using the vault's existing daily-note location and link to everything created or updated.
   - Update root `index.md` or the relevant domain/project index without polluting the root with every leaf note forever.
   - Append an operation-log entry using the vault's existing log location and format.
   - If a new folder was necessary and is not already in `_CLAUDE.md`'s Folder Map, add it with a short description.
   - Confirm each path-qualified source block link resolves to an existing block ID before finishing.

10. Report back:
    - Source transcript path and whether it is full or excerpted.
    - Notes, artifacts, syllabus, daily note, log, index, and Folder Map paths created or updated.
    - Any omitted ranges, unresolved verification gaps, or skipped outputs with reasons.

Distill only durable signal. Search before creating anything. Keep enough verbatim source for auditability, but do not archive noise just because it appeared in the conversation.

---

**AI-first rule:** Every synthesized note or reusable artifact created or updated by this command MUST follow `references/ai-first-rules.md` - `## For future Claude` preamble, rich frontmatter (`type`, `date`, `tags`, `ai-first: true`, plus type-specific fields), recency markers per external claim, mandatory `[[wikilinks]]` for every person/project/concept referenced, sources preserved verbatim with URLs inline, and confidence levels where applicable. Raw transcripts remain immutable Source Notes; synthesized outputs are for future-Claude retrieval, not human reading.

**Anti-fabrication:** Search exhaustively before claiming any note, person, or file is absent - false absence is the most common failure mode - and never invent facts, entities, or dates (mark unknowns as `TBD`). See the anti-fabrication and search-completeness hard rules in `references/ai-first-rules.md`.

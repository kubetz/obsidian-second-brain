---
description: Distill durable knowledge from a conversation - preserves auditable source excerpts and synthesizes reusable notes
category: vault
triggers_en: ["distill this conversation", "extract knowledge from conversation", "save this as learning", "create notes from this", "obsidian distill"]
---

Use the obsidian-second-brain skill. Execute `/obsidian-distill`:

Read the conversation. Distill only durable signal into the vault, preserving enough verbatim source material for auditability. Do the following in order, without asking questions.

### Step 0 - Analyze scope and classify

Analyze the conversation to determine:

- **Broad domain** - the subject matter (e.g. "LLM", "Rust", "Baking", "Startup Planning")
- **Nature** - classify as one or more of:
  - **teaching** - AI taught the user a subject (Q&A, explanations, examples)
  - **peer ideation** - user and AI debated, brainstormed, riffed on ideas
  - **editing / proofreading** - AI refined the user's existing writing or ideas
  - **planning / decision-making** - user works through a plan with AI's feedback
  - **troubleshooting / debugging** - user resolved a problem with AI's help
  - **other** - describe briefly
- **Distillation mode** - classify the primary output as one or more of:
  - **source-archive** - preserve mostly raw material for later use
  - **knowledge-distill** - extract reusable concepts, methods, or explanations
  - **output-polish** - preserve a finished artifact, draft, code snippet, or polished idea
  - **decision-record** - preserve choices, tradeoffs, rejected paths, and rationale
  - **learning-path** - produce a curriculum, syllabus, or ordered study plan
- **Scope worth preserving** - decide whether the durable source is:
  - **full-conversation** - most of the conversation is relevant signal
  - **selected-excerpts** - only some turns are durable; omit setup, operational chatter, or unrelated branches
  - **single-thread** - one focused teaching, ideation, decision, or troubleshooting thread inside a larger session
- **Key output worth preserving** - what makes this conversation vault-worthy:
  - Written output (final draft, polished ideas, code)
  - New concepts / insights that did not exist before
  - Decisions made or paths rejected
  - A process or method the user might want to repeat

Derive:
- `folder = Knowledge/<Domain>/` - follow the vault's existing directory style (Title Case with spaces between words, not PascalCase, e.g. `Knowledge/Startup Planning/`, `Knowledge/Rust/`, `Knowledge/Microeconomics/`). Acronyms stay uppercase: `Knowledge/LLM/`.
- `display_title` - concise human title for synopsis/frontmatter if the original title matters.
- `file_title` - ASCII-safe title for filenames and wikilinks. Replace banned or path-unsafe characters: em/en dash -> `-`, curly quotes -> straight quotes or remove, `/` and `:` -> `-`, repeated whitespace -> single spaces. Trim leading/trailing spaces and punctuation.
- `source_path = Research/Conversations/YYYY-MM-DD - <file_title>.md` - ASCII hyphen only. Do not use em dash.
- `slug` - short kebab-case form of `file_title` for block IDs, e.g. `llm-fundamentals`, `rust-debug`.
- `conversation_tags` - domain and nature tags. The frontmatter must also include the type tag `conversation`.
- `knowledge_tags` - broad domain tags only (never the conversation title). The frontmatter must also include the type tag `knowledge`.

If the domain is not obvious from content, use the title the user specifies.

### Step 1 - Save the source transcript

Create `Research/Conversations/YYYY-MM-DD - <file_title>.md` with:

- Frontmatter:

  ```yaml
  ---
  date: YYYY-MM-DD
  type: conversation
  tags: [conversation, $conversation_tags]
  nature: [<classification(s)>]
  mode: [<distillation-mode(s)>]
  scope: full-conversation | selected-excerpts | single-thread
  ai-first: true
  ---
  ```

- `## Synopsis` - 2-3 sentences describing what was preserved, why it matters, and whether the transcript is full or excerpted.
- The minimum verbatim source needed to verify the extracted knowledge:
  - For `full-conversation`, include every user and assistant turn.
  - For `selected-excerpts` or `single-thread`, include only relevant teaching, ideation, decision, troubleshooting, context-setting, and output-producing turns.
  - Omit operational setup, command execution chatter, ingestion boilerplate, unrelated branches, and purely ephemeral context unless needed to understand preserved material.
- `## Omitted ranges` when scope is not `full-conversation`:
  - List omitted turn ranges and short reasons, e.g. `Turns 1-14 - video ingestion setup, no durable knowledge.`
  - Do not summarize omitted knowledge. If a range contains durable knowledge, include the relevant verbatim blocks instead.
- Every included user turn and assistant turn, presented verbatim as they appeared.
- Annotate each included user block with `^<slug>-u-1`, `^<slug>-u-2`, ... (sequential within included source).
- Annotate each included assistant block with `^<slug>-a-1`, `^<slug>-a-2`, ... (sequential within included source).
- **Placement:** block ID on its own line, immediately after the paragraph or block it anchors, with one blank line before the next block:

  ```text
  What do you think about this approach?
  ^llm-ideas-u-3

  I think the tradeoff is worth it because...
  ^llm-ideas-a-3
  ```

- Do NOT put block IDs on the same line as text, inside a list, or separated from their paragraph by extra blank lines.
- Do NOT synthesize or reorganize the included source. The included transcript is immutable evidence, even when excerpted.

### Step 2 - Extract preserved output (if any)

If the conversation produced substantive written output (a draft, a design doc, a code snippet, a set of polished ideas), save it to the appropriate location:
- **Writing / article** - `Writings/` or `Knowledge/<Domain>/`
- **Code** - `Code/` or `Projects/<Project>/`
- **Design decisions** - `Projects/<Project>/` or `Knowledge/ADRs/`

Use your judgment. The key rule: the source transcript is the evidence; anything extracted here is a finished artifact someone (or a future agent) could use directly without reading the conversation.

### Step 3 - Extract structured knowledge or insights

Read every included block. Group related material by concept, decision, method, example, output, or open question, regardless of conversation order. Do not assume turns form clean user/assistant pairs.

Before creating a new `Knowledge/<Domain>/<Concept>.md`, search the vault exhaustively for existing notes about the same concept, including aliases and nearby terms. Update or extend an existing note when appropriate. Do not create duplicates because the title differs.

Create notes in `Knowledge/<Domain>/` appropriate to the nature:

- **For teaching segments:** one note per durable subtopic when multiple reusable concepts were taught; one focused note when the teaching is about a single concept. Follow: Synopsis, Core concepts, Examples, Sources, Connections, Open questions. If useful for a single topic, add `## Learning path` inside the note instead of creating a syllabus.
- **For peer ideation / brainstorming:** create or update `Knowledge/<Domain>/Ideas <file_title>.md` - capture the ideas that emerged, whose idea it was (user or AI), which ones were refined or rejected, and any conclusions.
- **For editing / proofreading:** create or update `Knowledge/<Domain>/Process - <file_title>.md` - capture techniques used, patterns caught, and rules of thumb the user can apply next time. The final draft goes in Step 2.
- **For planning / decision-making:** create or update `Knowledge/<Domain>/Decision Log - <file_title>.md` - capture what was decided, what alternatives were considered, why each was rejected.
- **For troubleshooting / debugging:** create or update `Knowledge/<Domain>/Debugging Log - <file_title>.md` - capture root cause, diagnosis steps, and resolution. Update the relevant `Projects/` note if a project was involved.
- **For mixed or other nature:** use the smallest set of notes that captures the durable signal worth keeping.

Rules (apply to all types):
- Frontmatter uses:

  ```yaml
  ---
  date: YYYY-MM-DD
  type: knowledge
  tags: [knowledge, $knowledge_tags]
  source: "[[Research/Conversations/YYYY-MM-DD - <file_title>]]"
  confidence: stated
  verification: conversation-stated
  ai-first: true
  ---
  ```

- `## Synopsis` is mandatory and must state what the note covers, why it matters, and any scope or staleness caveat.
- Synthesize. Do NOT just re-list the conversation blocks.
- Every substantive claim, idea, decision, or example should trace back to a path-qualified source block link like `[[Research/Conversations/YYYY-MM-DD - <file_title>#^<slug>-a-N]]` or `[[Research/Conversations/YYYY-MM-DD - <file_title>#^<slug>-u-N]]` so it resolves from extracted notes and can be verified against the source transcript.
- Block references prove provenance only: they show what the conversation said. They do not prove external factual truth.
- If the conversation included a URL or source for an external factual claim, preserve the URL inline with a recency marker.
- If an external factual claim has no source URL, mark `verification: conversation-stated` or `verification: needs-verification` in frontmatter or inline instead of presenting it as verified fact.
- Name notes by their concept, not by the conversation name.
- Use recency markers ("as of June 2026") on time-sensitive claims.
- Use confidence levels (`stated | high | medium | speculation`) and separate verification markers (`conversation-stated | needs-verification | source-verified`) where appropriate.
- Do not create notes for content that is purely ephemeral or personal context with no lasting value.

### Step 4 - Create a syllabus only when warranted

Create `Knowledge/<Domain>/Syllabus - <file_title>.md` only when at least one is true:
- The preserved teaching spans multiple subtopics or chapters.
- Multiple Knowledge notes were created and need an ordered learning path.
- The output is meant as a reusable course, curriculum, or onboarding path.
- The user explicitly asked for a syllabus.

When creating a syllabus, use:

```yaml
---
date: YYYY-MM-DD
type: syllabus
tags: [syllabus, knowledge, $knowledge_tags]
source: "[[Research/Conversations/YYYY-MM-DD - <file_title>]]"
ai-first: true
---
```

Include:
- `## Synopsis` - what this syllabus teaches, who it is for, and what source it came from.
- The recommended teaching order for someone else to follow.
- Prerequisites and dependencies between subtopics.
- For each module: link to the Knowledge note, estimated complexity, and key block IDs from the source transcript.

If the teaching is a single focused concept, do not create a syllabus. Add `## Learning path` inside the concept note only if useful.

### Step 5 - Update the vault structure

- Create today's daily note at `Daily/YYYY-MM-DD.md` if it does not exist - link to everything created.
- Update indexes without polluting the root:
  - If the domain has many notes or a `Knowledge/<Domain>/index.md`, update or create that domain index and link all new domain notes there.
  - If only 1-3 notes were created and no domain index exists, adding entries directly under `## Knowledge/<Domain>/` in root `index.md` is acceptable.
  - Root `index.md` should prefer linking domain indexes over listing every leaf note forever.
- Append to `Logs/YYYY-MM-DD.md` with a summary line.
- If `Knowledge/<Domain>/` is not yet in `_AGENTS.md`'s Folder Map, add a row: `Knowledge/<Domain>/` - <short description>.

### Verification checklist

- [ ] `Research/Conversations/YYYY-MM-DD - <file_title>.md` - source transcript exists, with `ai-first: true`, `type: conversation`, type tag, correct `scope`, and ASCII-safe filename.
- [ ] Source transcript scope is correct - full conversation only when most turns are durable signal; otherwise omitted ranges are listed with reasons.
- [ ] Included source blocks are verbatim and not synthesized or reorganized.
- [ ] Every included user/assistant block has exactly one block ID.
- [ ] No dangling block IDs exist at the end of the source transcript or after blank content.
- [ ] Step 2 output created (if applicable) - finished artifact someone could reuse.
- [ ] Knowledge/insight notes created (at minimum one) - synthesized, with `ai-first: true`, type tag, path-qualified `source`, and `#^` block references.
- [ ] Existing concept notes were searched before new notes were created; duplicates were not created under alternate names.
- [ ] External factual claims preserve URLs/recency markers when available; unsourced external claims are marked `conversation-stated` or `needs-verification`.
- [ ] Syllabus created only if warranted - multi-topic, multiple notes, course-like, or explicitly requested.
- [ ] `Daily/YYYY-MM-DD.md` - links to everything created today.
- [ ] `Logs/YYYY-MM-DD.md` - operation log entry.
- [ ] `index.md` and/or `Knowledge/<Domain>/index.md` updated without root-index pollution.
- [ ] `_AGENTS.md` updated (if `Knowledge/<Domain>/` is not yet in Folder Map).
- [ ] Every source block link (`[[Research/Conversations/YYYY-MM-DD - <file_title>#^<slug>-a-N]]` or `...#^<slug>-u-N]]`) resolves to an existing block ID in the source transcript.

If any of these is missing or wrong, fix it before finishing.

---

**AI-first rule:** Every note created or updated by this command MUST follow `references/ai-first-rules.md` - `## Synopsis` preamble, rich frontmatter (`type`, `date`, `tags`, `ai-first: true`, plus type-specific fields), recency markers per external claim, mandatory `[[wikilinks]]` for every person/project/concept referenced, sources preserved verbatim with URLs inline, and confidence levels where applicable. The vault is for future agent retrieval - not human reading.

**Anti-fabrication:** Search exhaustively before claiming any note, person, or file is absent - false absence is the most common failure mode - and never invent facts, entities, or dates (mark unknowns as `TBD`). See the anti-fabrication and search-completeness hard rules in `references/ai-first-rules.md`.

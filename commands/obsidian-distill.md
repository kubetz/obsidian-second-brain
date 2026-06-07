---
description: Distill a conversation into structured knowledge - saves raw conversation, synthesizes insights, creates a syllabus
category: vault
triggers_en: ["distill this conversation", "extract knowledge from conversation", "save this as learning", "create notes from this", "obsidian distill"]
---

Use the obsidian-second-brain skill. Execute `/obsidian-distill`:

Read the entire conversation. Do the following in order, without asking questions.

### Step 0 - Analyze and classify

Analyze the conversation to determine:

- **Broad domain** - the subject matter (e.g. "LLM", "Rust", "Baking", "Startup Planning")
- **Nature** - classify as one or more of:
  - **teaching** - AI taught the user a subject (Q&A, explanations)
  - **peer ideation** - user and AI debated, brainstormed, riffed on ideas
  - **editing / proofreading** - AI refined the user's existing writing or ideas
  - **planning / decision-making** - user works through a plan with AI's feedback
  - **troubleshooting / debugging** - user resolved a problem with AI's help
  - **other** - describe briefly
- **Key output worth preserving** - what makes this conversation vault-worthy:
  - Written output (final draft, polished ideas, code)
  - New concepts / insights that didn't exist before
  - Decisions made or paths rejected
  - A process or method the user might want to repeat

Derive:
- `folder = Knowledge/<Domain>/` - Title Case with spaces between words (e.g. `Knowledge/Startup Planning/`, `Knowledge/Rust/`, `Knowledge/Microeconomics/`). Acronyms stay uppercase: `Knowledge/LLM/`.
- `slug` - short kebab-case form of the conversation for block IDs, e.g. `llm-fundamentals`, `rust-debug`.
- `conversation_tags` - based on domain and nature.
- `knowledge_tags` - broad domain only (never the conversation title).

If the domain isn't obvious from content, use the title the user specifies.

### Step 1 - Save the raw conversation

Create `Research/Conversations/YYYY-MM-DD — <Title>.md` with:

- Frontmatter: `type: conversation`, `tags: [$conversation_tags]`, `nature: <the classification(s)>`, `date: YYYY-MM-DD`
- Synopsis: 2-3 sentences describing what was covered and why it matters
- Every user turn and assistant turn, presented verbatim as they appeared
- Annotate each user block with `<slug>-u-1`, `<slug>-u-2`, ... (sequential)
- Annotate each assistant block with `<slug>-a-1`, `<slug>-a-2`, ... (sequential)
- **Placement:** block ID on its own line, immediately after the paragraph it anchors, with one blank line before the next block:

  ```
  What do you think about this approach?
  ^llm-ideas-u-3

  I think the tradeoff is worth it because...
  ^llm-ideas-a-3
  ```

- Do NOT put block IDs on the same line as text, inside a list, or separated from their paragraph by extra blank lines.
- Do NOT synthesize or reorganize. This is the immutable source.

### Step 2 - Extract preserved output (if any)

If the conversation produced substantive written output (a draft, a design doc, a code snippet, a set of polished ideas), save it to the appropriate location:
- **Writing / article** - `Writings/` or `Knowledge/<Domain>/`
- **Code** - `Code/` or `Projects/<Project>/`
- **Design decisions** - `Projects/<Project>/` or `Knowledge/ADRs/`

Use your judgment. The key rule: the raw conversation is the source; anything extracted here is a finished artifact someone (or a future agent) could use directly without reading the conversation.

### Step 3 - Extract structured knowledge or insights

Read every block pair. Identify the distinct themes, ideas, decisions, or concepts. Ignore sequence - group related content even if it appeared pages apart.

Create notes in `Knowledge/<Domain>/` appropriate to the nature:

- **For teaching conversations:** one note per subtopic. Follow: Synopsis, Core concepts, Sources (with `#^<slug>-a-N` links), Connections, Open questions.
- **For peer ideation / brainstorming:** create `Knowledge/<Domain>/Ideas <Title>.md` - capture the ideas that emerged, whose idea it was (user or AI), which ones were refined or rejected, and any conclusions.
- **For editing / proofreading:** create `Knowledge/<Domain>/Process — <Title>.md` - capture techniques used, patterns caught, and rules of thumb the user can apply next time. The final draft goes in Step 2.
- **For planning / decision-making:** create `Knowledge/<Domain>/Decision Log — <Title>.md` - capture what was decided, what alternatives were considered, why each was rejected.
- **For troubleshooting / debugging:** create `Knowledge/<Domain>/Debugging Log — <Title>.md` - capture root cause, diagnosis steps, and resolution. Update the relevant `Projects/` note if a project was involved.
- **For mixed or other nature:** use your judgment. At minimum create one note that captures the signal worth keeping.

Rules (apply to all types):
- Frontmatter uses `type: knowledge`, `tags: [$knowledge_tags]`, `source: "[[YYYY-MM-DD — <Title>]]"`, `date: YYYY-MM-DD`
- Synthesize. Do NOT just re-list the conversation blocks.
- Every substantive claim or idea should trace back to a `#^<slug>-a-N` or `#^<slug>-u-N` block reference so it can be verified.
- Name notes by their concept, not by the conversation name.
- Use recency markers ("as of June 2026") on time-sensitive claims.
- Use confidence levels (`stated | high | medium | speculation`) where appropriate.
- Do not create notes for content that's purely ephemeral or personal context with no lasting value.

### Step 4 - Create a syllabus (only if teaching)

If nature is **teaching**, create `Knowledge/<Domain>/Syllabus — <Title>.md`:
- Frontmatter: `type: syllabus`, `tags: [$knowledge_tags, syllabus]`, `source: "[[YYYY-MM-DD — <Title>]]"`
- The recommended teaching order for someone else to follow
- Prerequisites (what each subtopic depends on)
- For each module: link to the Knowledge note, estimated complexity, and key block IDs from the raw conversation

Otherwise, skip this step.

### Step 5 - Update the vault structure

- Create today's daily note at `Daily/YYYY-MM-DD.md` if it doesn't exist - link to everything created
- Update `index.md` (at vault root) - add entries under `## Knowledge/<Domain>/` for each new note. Format: `- [[Knowledge/<Domain>/Note Name]] — brief description`
- Append to `Logs/YYYY-MM-DD.md` with a summary line
- If `Knowledge/<Domain>/` is not yet in `_AGENTS.md`'s Folder Map, add a row: `Knowledge/<Domain>/` - <short description>

### Verification checklist

- [ ] `Research/Conversations/YYYY-MM-DD — <Title>.md` - raw conversation with block IDs, placement correct
- [ ] Step 2 output created (if applicable) - finished artifact someone could reuse
- [ ] Knowledge/insight notes created (at minimum one) - synthesized, with `#^` block references
- [ ] Syllabus created (if teaching) - progression with prerequisites
- [ ] `Daily/YYYY-MM-DD.md` - links to everything created today
- [ ] `Logs/YYYY-MM-DD.md` - operation log entry
- [ ] `index.md` updated - catalog entries for all new notes
- [ ] `_AGENTS.md` updated (if `Knowledge/<Domain>/` not yet in Folder Map)
- [ ] Spot-check: every `#^<slug>-a-N` or `#^<slug>-u-N` reference resolves to an existing block ID in the raw conversation

If any of these is missing or wrong, fix it before finishing.

---

**AI-first rule:** Every note created or updated by this command MUST follow `references/ai-first-rules.md` - `## Synopsis` preamble, rich frontmatter (`type`, `date`, `tags`, `ai-first: true`, plus type-specific fields), recency markers per external claim, mandatory `[[wikilinks]]` for every person/project/concept referenced, sources preserved verbatim with URLs inline, and confidence levels where applicable. The vault is for future agent retrieval - not human reading.

**Anti-fabrication:** Search exhaustively before claiming any note, person, or file is absent - false absence is the most common failure mode - and never invent facts, entities, or dates (mark unknowns as `TBD`). See the anti-fabrication and search-completeness hard rules in `references/ai-first-rules.md`.

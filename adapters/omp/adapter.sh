#!/usr/bin/env bash
# =============================================================================
# adapters/omp/adapter.sh - Oh My Pi projection of Agent Skills
# =============================================================================
# OMP natively discovers project-local .agents/commands and .agents/skills.
# Keep this adapter deliberately thin: Agent Skills remains the canonical
# compiler, while this file adds OMP command bridges and installation metadata.
# =============================================================================

OMP_PLATFORM="omp"
OMP_ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reuse the canonical Agent Skills compiler and its .agents/skills core path.
# shellcheck source=adapters/agent-skills/adapter.sh
source "$OMP_ADAPTER_DIR/../agent-skills/adapter.sh"

adapter_build() {
  local src="$1" dst="$2"
  local skills_dir="$dst/.agents/skills"

  mkdir -p "$skills_dir"

  # Agent Skills owns frontmatter projection, inclusion semantics, embedded
  # write rules, tool-neutral wording, and SKILL_ROOT/reference rewrites.
  _ask_emit_skills "$src/commands" "$skills_dir" "$src/references/ai-first-rules.md"
  # Repository authoring depends on source-only build/install files, so OMP is
  # the one additional Agent Skills consumer that intentionally omits it.
  rm -rf "$skills_dir/create-command"
  _ask_emit_core "$src" "$skills_dir/$ASK_CORE"
  _omp_remove_source_only_core_files "$skills_dir/$ASK_CORE"

  # OMP alone receives the neutral vocabulary/schema boundary. Run it before
  # generating the tiny command bridges and deterministic manifest.
  bash "$src/scripts/convert.sh" --dist "$dst"

  _omp_emit_wrappers "$skills_dir" "$dst/.agents/commands"
  _omp_emit_manifest "$dst/.agents"
  _omp_emit_agents "$dst/AGENTS.md"
  _omp_emit_install_hint "$dst/INSTALL.md"
}

_omp_remove_source_only_core_files() {
  local core="$1" relative
  local -a source_only=(
    "references/DELTAS.template.md"
    "references/pi-testing.md"
    "scripts/build.sh"
    "scripts/build_site.py"
    "scripts/conformance_report.py"
    "scripts/convert.sh"
    "scripts/install-codex-wrappers.sh"
    "scripts/install-omp.sh"
    "scripts/quick-install.sh"
    "scripts/run-command.sh"
    "scripts/setup.sh"
    "scripts/setup_settings_hook.py"
    "scripts/update-vault-integration.sh"
  )

  for relative in "${source_only[@]}"; do
    rm -f "$core/$relative"
  done
}

_omp_emit_wrappers() {
  local skills_dir="$1" commands_dir="$2" skill name

  mkdir -p "$commands_dir"
  while IFS= read -r skill; do
    name="$(basename "$skill")"
    [[ "$name" == "$ASK_CORE" ]] && continue

    cat > "$commands_dir/$name.md" <<EOF
---
description: "Run the $name obsidian-second-brain Agent Skill."
---

Read and follow \`skill://$name\` for this request. The Agent Skill is the
single source of truth; do not duplicate or reconstruct its body here.

Resolve the vault root as \`\$OBSIDIAN_VAULT_PATH\` when it is set; otherwise use
the current working directory. Pass the user's arguments through unchanged:
\$ARGUMENTS

If \`skill://$name\` cannot be read, report that the matching Agent Skill is not
installed or discovered and stop.
EOF
  done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -name '*' -exec test -f '{}/SKILL.md' ';' -print | LC_ALL=C sort)
}

_omp_emit_manifest() {
  local agents_dir="$1" path name
  : > "$agents_dir/obsidian-second-brain.manifest"
  for path in "$agents_dir/commands"/*.md; do
    [[ -f "$path" ]] || continue
    name="$(basename "$path")"
    printf 'command\t%s\n' "$name" >> "$agents_dir/obsidian-second-brain.manifest"
  done
  for path in "$agents_dir/skills"/*/SKILL.md; do
    [[ -f "$path" ]] || continue
    name="$(basename "$(dirname "$path")")"
    printf 'skill\t%s\n' "$name" >> "$agents_dir/obsidian-second-brain.manifest"
  done
  LC_ALL=C sort -o "$agents_dir/obsidian-second-brain.manifest" "$agents_dir/obsidian-second-brain.manifest"
}

_omp_emit_agents() {
  local output="$1"

  cat > "$output" <<'EOF'
<!-- managed-by: obsidian-second-brain-omp -->

1. Resolve the vault root from `$OBSIDIAN_VAULT_PATH` when it is set; otherwise use the current working directory.
2. Read `_AGENTS.md` at the vault root before reading or writing vault content.
3. Prefer `.agents/commands` and `.agents/skills` for obsidian-second-brain workflows.
4. Enforce `.agents/skills/obsidian-core/references/ai-first-rules.md`; if that path does not resolve from your working directory, search upward for it, and if you still cannot read it, say so before writing. Every created or updated note uses `## For future agent`.
EOF
}

_omp_emit_install_hint() {
  local output="$1"

  cat > "$output" <<'EOF'
# Oh My Pi (OMP)

Install this OMP projection from the repository:

```bash
bash install.sh omp --vault /absolute/path/to/vault
```

Invoke an installed workflow with `/name [args]` or `/skill:<name> [args]`.
EOF
}

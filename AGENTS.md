# obsidian-second-brain Fork Operating Guide

> Read this first when changing the fork. `FORK_MAINTENANCE.md` contains the
> forward-port procedure and the stricter ownership rules.

## Overlay contract

This fork keeps upstream source canonical and carries a deliberately narrow OMP
overlay. Do not turn a generated artifact, a local installation, or a convenience
copy into a second source of truth.

- `commands/obsidian-distill.md` is upstream's canonical source-distillation
  workflow. Do not rewrite or rename it.
- The fork adds `commands/obsidian-crystallize.md` for auditable
  conversation-to-knowledge work and `commands/obsidian-nightly.md` for the
  existing on-demand vault-consolidation procedure.
- `adapters/omp/adapter.sh` is a thin projection of the upstream Agent Skills
  adapter. Keep shared skill generation in that upstream adapter rather than
  cloning it for OMP.
- Only generated `dist/omp` and its installed vault copy use neutral OMP
  vocabulary such as `_AGENTS.md`. Upstream source and every non-OMP build
  retain their canonical vocabulary.
- OMP has no repository-backed scheduler. The nightly command is manually
  invokable; Hermes alone may emit its optional scheduled blueprint from the
  canonical nightly command body.

## Surviving fork surfaces

| Path | Responsibility |
|---|---|
| `AGENTS.md` | Concise overlay contract for maintainers and agents |
| `FORK_MAINTENANCE.md` | Forward-port ritual and ownership boundaries |
| `commands/obsidian-crystallize.md` | Fork-owned conversation crystallization command |
| `commands/obsidian-nightly.md` | On-demand projection of the shipped nightly procedure |
| `adapters/omp/adapter.sh` | Thin OMP build adapter over Agent Skills |
| `scripts/convert.sh` | OMP-only generated-tree neutralizer |
| `scripts/install-omp.sh` | Project-local, manifest-owned OMP installer |
| `install.sh` and `scripts/build.sh` | Small OMP dispatch and build integration points |
| `adapters/hermes/adapter.sh` | Optional nightly blueprint derived from the canonical command |
| `README.md`, `adapters/OWNERS.md`, and focused tests | Nine-build roster and OMP public contract |

## OMP contract

Build and install OMP with the only supported path:

```bash
bash scripts/build.sh --platform omp
bash install.sh omp --vault /absolute/path/to/vault
```

The installer requires an existing Obsidian vault and copies only generated,
manifest-owned entries into `<vault>/.agents/commands` and
`<vault>/.agents/skills`. It may manage the marked root `AGENTS.md`, but it
always preserves the vault's `_AGENTS.md` and unrelated project files. The
installed commands bridge to `skill://<name>`; the skills remain their single
source of truth.

The repository has nine builds and 49 source commands. The seven non-calendar
generic builds ship 48 commands (Hermes ships 47 command skills plus the opt-in
nightly blueprint); OMP also omits source-authoring `create-command`, so it
installs 47 command/skill pairs.

## Forward-port rules

When upstream changes, begin from the new upstream revision and replay only the
surviving overlay. Preserve upstream files unless an OMP integration point or a
documented command contract requires a targeted infill.

1. Keep upstream `obsidian-distill` byte-for-byte canonical. Keep
   `obsidian-crystallize` and `obsidian-nightly` as separate commands with their
   own selection contracts.
2. Reuse the upstream Agent Skills compiler for OMP. Do not fork shared
   generation logic.
3. Run the neutralizer only through the OMP adapter and only against generated
   `dist/omp`; never neutralize source or another platform's output.
4. Keep installation project-local and copy-based. The manifest is the ownership
   boundary for replacement and removal.
5. Regenerate and review the OMP artifact after a forward port. Its wrappers,
   skill directories, manifest, and root guide must agree, while
   `dist/agent-skills` remains canonical.
6. Keep public roster text at nine builds, 49 total commands, 48 non-calendar
   generic commands, and 47 OMP command/skill pairs.

If a proposed change needs broader source rewrites, a duplicate compiler, or a
new install location, it is not part of this overlay. Re-evaluate the product
contract before adding it.

## Maintaining this guide

Record durable fork decisions here only when they change the overlay boundary.
Put operational detail in `FORK_MAINTENANCE.md`; do not document generated
output as if it were source.

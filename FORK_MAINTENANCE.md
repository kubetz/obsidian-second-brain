# Fork Maintenance

This fork forward-ports a small OMP overlay onto canonical upstream
[obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain).
The goal is not a second platform implementation: upstream remains the source
of shared behavior, and the fork owns only the OMP projection and its two
additional command contracts.

## Architecture that survives a forward port

### Canonical upstream

- `commands/obsidian-distill.md` remains the source-distillation command. Keep
  its body, name, and selection semantics upstream-canonical.
- Shared Agent Skills generation remains in `adapters/agent-skills/adapter.sh`.
- Source prose and non-OMP generated builds retain upstream naming and schema.

### Fork overlay

| Surface | Rule |
|---|---|
| `commands/obsidian-crystallize.md` | Fork-owned conversation workflow; it is distinct from upstream distill and must keep its auditable transcript and derived-output contract. |
| `commands/obsidian-nightly.md` | Fork-owned on-demand packaging of the existing nightly procedure. Hermes consumes this command body for its one optional scheduled blueprint. |
| `adapters/omp/adapter.sh` | Thin adapter over Agent Skills. It emits OMP skills, wrappers, manifest, and root guide; do not duplicate the upstream compiler. |
| `scripts/convert.sh` | The sole neutral-schema transform. Its only valid target is canonical `dist/omp`. |
| `scripts/install-omp.sh` | Project-local, copy-based installer. A validated manifest is its only managed-path authority. |
| `install.sh` and `scripts/build.sh` | Minimal integration points for `install.sh omp` and the OMP build target. |
| `adapters/hermes/adapter.sh` | Reads the canonical nightly command body instead of maintaining a second procedure. |
| `AGENTS.md`, `README.md`, `adapters/OWNERS.md`, and focused tests | Preserve the operational and public roster contracts. |

The public roster is nine builds and 49 source commands. Calendar is
Claude-Code-only, so the seven non-calendar generic builds ship 48 commands (Hermes
ships 47 command skills plus the opt-in nightly blueprint). OMP additionally
excludes source-authoring `create-command`, yielding 47 installed command/skill
pairs.

## OMP build and installation contract

Build OMP only through:

```bash
bash scripts/build.sh --platform omp
```

The adapter delegates skill and core generation to Agent Skills, then produces
the OMP-specific tree:

```text
dist/omp/
├── AGENTS.md
├── INSTALL.md
└── .agents/
    ├── commands/
    ├── obsidian-second-brain.manifest
    └── skills/
```

Each command wrapper reads its matching `skill://<name>`; it does not duplicate
the skill procedure. `obsidian-core` is support-only and has no wrapper. OMP
omits `obsidian-calendar` and `create-command`.

The adapter invokes `scripts/convert.sh` after generating the OMP skills and
before finalizing wrappers and the manifest. The converter must reject every
target except canonical `dist/omp`, including the source tree and sibling
neutral `_AGENTS.md` schema.

Install only with:

```bash
bash install.sh omp --vault /absolute/path/to/vault
```

The installer requires an existing vault with `.obsidian/`, rebuilds and
preflights before mutation, then copies manifest-owned output only to
`<vault>/.agents/skills` and `<vault>/.agents/commands`. It can replace a
recognized managed root `AGENTS.md`; it never replaces `_AGENTS.md` or
unrelated project files. It has no global installation path and no scheduler.

## Forward-port ritual

Use this procedure whenever adopting a new upstream revision.

1. **Start from upstream.** Create the migration branch at the selected
   upstream commit. Do not carry generated trees or local installed output
   forward.
2. **Reapply only the overlay.** Restore the fork surfaces in the table above
   and the small documented integration infills. Let upstream win everywhere
   else.
3. **Protect command identities.** Confirm upstream `obsidian-distill` is
   unchanged, crystallization remains `obsidian-crystallize`, and nightly
   remains an explicit, manually invokable `obsidian-nightly` command.
4. **Keep OMP thin.** Verify the OMP adapter still calls the upstream Agent
   Skills helpers. If upstream changes those helpers, adapt the call boundary
   rather than copying their implementation.
5. **Contain neutralization.** Build OMP and verify conversion affected only
   `dist/omp`. The Agent Skills artifact and all other generated trees must
   remain canonical.
6. **Check installation ownership.** Confirm the generated manifest matches
   exactly the OMP wrappers and skills, and that the installer can update only
   those manifest-owned paths plus a recognized managed root guide.
7. **Refresh the public contract.** Keep README, the ownership table, generated
   site metadata, and focused roster assertions synchronized with nine builds,
   49 total commands, 48 non-calendar generic commands, and 47 OMP pairs.
8. **Run the repository's current verification commands.** Exercise the OMP
   build and a clean project-local install before migrating a real vault.

## Change rules

### Adding or changing a command

Edit the canonical command first. The Agent Skills adapter remains the shared
projection; OMP receives emitted skills and derives wrappers from them. Do not
hand-maintain a second OMP command body or routing table. When changing nightly,
keep Hermes's optional blueprint command-derived.

### Changing neutral naming

Make the change in `scripts/convert.sh` only when it is necessary at the OMP
distribution boundary. Preserve factual external values that are deliberately
allowlisted, retain atomic path renames, and add focused coverage for both
content and path behavior. Never generalize the converter to another build.

### Changing installation

Treat the generated manifest as data to validate, not as trusted shell input.
Preflight source, collisions, ownership, and the root guide before touching the
vault. Updates may replace or remove only previous manifest-owned entries; all
other `.agents` content is user-owned.

## Things that must not return

- Source-tree neutralization or neutralization of a non-OMP build.
- A parallel OMP skill compiler, duplicate command procedures, or a separate
  nightly body.
- Provider-global installation state, global shared skills, or hidden
  project-external configuration.
- An OMP scheduler or lifecycle automation inferred from the manually invokable
  nightly command.
- Any compatibility layer that makes a generated path look like a maintained
  source path.

Keep this file focused on the surviving overlay. Delete obsolete migration
notes rather than preserving them as alternate architecture.

# diff-vault — diff computation & apply procedure

## Contents
- PRD change detection (`prd_sha256`)
- Per-axis diff computation (entities / flows / decisions / OQs / constraints / design-system)
- Apply mechanics (Step 6)
- `vault.json` refresh (Step 6.5) + advisory lock
- Vault metadata update (Step 7)
- Halts: `prd_path_missing`, `memory_in_use`

Loaded by Steps 1.5 and 3–7. The SKILL.md body holds the step skeleton + rails; this file holds the mechanics each axis and the apply phase need.

## PRD change detection (Step 1.5)

When `vault.json` contains a `prd_sha256` field (multi-scope vault), compute the sha256 of the CURRENT PRD file at `vault.json.prd_path_at_generation`:

```bash
CURRENT_SHA=$(shasum -a 256 "<vault.prd_path_at_generation>" | awk '{print $1}')
RECORDED_SHA="<vault.json.prd_sha256>"
```

Comparison logic:
- `CURRENT_SHA == RECORDED_SHA` → PRD unchanged since vault generation; proceed with normal diff-vault flow (vault revision detection only).
- `CURRENT_SHA != RECORDED_SHA` → PRD CHANGED since generation; emit informational note in the diff report: "PRD content changed since vault generation (sha: ...) — revisions detected per current diff" + proceed with normal flow.
- `vault.json.prd_sha256` absent (legacy vault) → SKIP this check gracefully; emit advisory note: "Vault generated before multi-scope support; PRD change detection unavailable. Consider regenerating vault."
- `vault.json.prd_path_at_generation` points to a non-existent file → halt `prd_path_missing` (see below).

Emit `prd_sha256_changed: yes | no | n/a` in the VAULT-DIFF.md header for downstream visibility. When the vault has scope, the new `CURRENT_SHA` also flows into the handoff YAML's `scope:` block (the `--auto` / chain-integration reference covers that emission).

## Per-axis diff computation (Step 3)

Build an internal diff model. For each axis, classify items into the diff outcome categories (see SKILL.md body table).

### Entities (`03-data-model.md`)
- For each entity in old vault: present in new model? same fields? changed types? new constraints?
- For each entity in new model: not in old vault? → Added.
- Apply name-matching first; then field-level matching by name.

### Flows (`04-flows.md`)
- For each flow ID (`F-U-001`, `F-S-002`, etc.) in old vault: present in new model? same steps? same DoD? cross-cutting handoff still valid?
- For each flow in new model: no analog in old vault? → Added.
- For removed flows: do NOT delete the section; mark with banner `> **Removed in v{X.Y}**: not present in source as of <new PRD version>. Retained for history. See Changelog.`

### Decisions (`05-decisions.md`)
- For each ADR in old vault: source citation still resolvable in new PRD? If old PRD §X.Y was renumbered or moved, attempt to re-anchor to new §X.Y.
- For each new decision-shaped statement in new PRD: not represented as an ADR in vault? → Added (new D-XXX).
- For ADR that contradicts new PRD: → Decision conflict. **User must resolve.**

### Open Questions
- For each `[x]` resolved OQ in vault: does new PRD now answer it differently? → Resolved-OQ conflict. **User must resolve.**
- For each `[ ]` open OQ in vault: does new PRD now answer it? → Auto-resolve candidate.
- For each new gap in new PRD that wasn't in old vault: → New OQ.

### Constraints, overview, architecture
- Diff at section level. For section-level changes, present old vs new side-by-side.

### Design-system content (conditional)
- If new source has design-system content but old vault lacks those sections → Added sections (require user confirmation to insert).
- If old vault has design-system sections but new source no longer has them → flag for user (rare; usually means tokens file removed). Default action: keep but mark stale.

## Apply approved changes (Step 6)

For each approved change, use `Edit` (preferred) or `Write` (when restructuring large sections) to update the vault file:

1. **Auto-resolved OQs** → mark `[x]` in OQ section + roll-up; insert resolution pointer to new PRD §X.Y.
2. **New OQs** → append `[ ] **OQ-{CODE}-{N+1}**` entries to the relevant doc's Open Questions section + roll-up.
3. **Added entities / flows / decisions** → append to the relevant doc per existing convention. Use the same `OUTPUT_MODE` (compact / full) as the existing vault.
4. **Changed** → in-place update; preserve IDs. Add `> **Changed in v{X.Y}**: <1-line summary>` banner above the changed block.
5. **Removed** → annotate banner; do NOT delete content.
6. **Resolved-OQ conflicts** (per user choice):
   - Supersede: change `[x]` resolution pointer to new PRD; if it was promoted to D-XXX, mark old ADR `Status: Superseded by D-NNN` and create D-NNN.
   - Keep vault: append rationale `> Vault retains prior resolution; new PRD line out-of-scope (see Vault Lock §<...>).` to the OQ entry. Add to `Out of Scope` section of the relevant doc.
   - Capture both: split into two ADRs / two field constraints with explicit scope qualifiers.
7. **Decision conflicts** (per user choice): same logic as Resolved-OQ conflicts.

## Refresh `vault.json` (Step 6.5)

After applying approved changes, regenerate `vault.json` from the now-updated markdown so AI consumers don't see stale state.

1. Read all 7 markdown files (post-apply state).
2. Rebuild the manifest fields per `generate-intent/references/vault-contract.md` §schema:
   - `entities[]` from `03-data-model.md` DBML — add new entries this round, preserve existing.
   - `flows[]` from `04-flows.md` — add new flow IDs, optionally mark removed flows with their banner annotation in metadata. Existing flow IDs stay even when their content changed.
   - `adrs[]` from `05-decisions.md` — new D-XXX entries get `status: accepted` (or `superseded` if this round flipped a prior decision).
   - `open_questions[]` — refresh `status` per markdown checkbox state. Auto-resolved OQs flip `open` → `resolved`. New OQs get `status: open`.
   - `open_questions_summary.total` and `by_priority` / `by_status` — recompute from the new array.
   - `vault_version` — match the post-bump version from Step 7 (write both; sequence so vault.json reflects the new version).
   - `generated_at` — update to the current timestamp.
   - `source_documents[]` — replace the prior PRD entry with the new source per Step 7.
3. Write to `<VAULT_DIR>/vault.json`. Overwrites the prior manifest.

**vault.json advisory lock (REQUIRED):** acquire an exclusive file lock on `<VAULT_DIR>/vault.json.lock` per `generate-intent/references/vault-contract.md §Concurrency contract` BEFORE overwriting vault.json. Backoff + retry 3x; fail with `memory_in_use` halt if all retries fail. Release the lock after the atomic write (temp file + rename) completes. Concurrent diff-vault + bind-codebase + generate-intent writes would otherwise corrupt the manifest.

> **Idempotency**: re-running against an unchanged source produces an unchanged `vault.json` (same field values, only `generated_at` updates). The Step 8 self-check verifies markdown ↔ JSON consistency.

> **Why a separate step**: the Step 6 markdown edits are content; the JSON regen is structural. Keeping them adjacent but distinct lets self-check verify each independently.

## Update vault metadata (Step 7)

1. **Bump vault version** in `00-index.md` Vault Lock Status:
   - Patch bump: v1.1 → v1.2 (resolved OQs, minor changes, no scope shift).
   - Minor bump: v1.1 → v2.0 (significant additions/changes, e.g., new feature scope from new PRD).
   - Skill suggests; user confirms via `AskUserQuestion`.
2. **Append Changelog entry** to `00-index.md`:

```markdown
### v{X.Y} ({YYYY-MM-DD})

Vault diff applied from <new source filename + version>.

- **Auto-resolved OQs** ({N}): OQ-OV-1, OQ-AR-3, ...
- **New OQs** ({N}): OQ-FL-12, OQ-DM-13, ...
- **Added**: {N} entities, {N} flows, {N} decisions, {N} sections.
- **Changed**: {N} entities, {N} flows, {N} decisions.
- **Removed (annotated)**: {N} flows, {N} decisions. Content retained for history.
- **Conflicts resolved**: {N} (decisions: <list of D-XXX, action taken>; resolved-OQ: <list>).
- **Source**: <new PRD filename + version + date>.
```

3. **Update `Last updated`** date.
4. **Update PRD source reference** in Vault Lock Status:
   - From: `**PRD source**: <old filename, version, date> — <FINAL | DRAFT>`
   - To: `**PRD source**: <new filename, version, date> — <FINAL | DRAFT>` (prior version moved into Changelog history).

## Halt — `prd_path_missing`

Triggered when `vault.json.prd_path_at_generation` points to a non-existent file. ALWAYS STOP (even under `--auto`).

Message: "PRD at `<path>` no longer exists; cannot detect changes. Move PRD back or regenerate vault with the current PRD path."

## Halt — `memory_in_use`

Triggered when the `vault.json.lock` advisory lock cannot be acquired after 3 backoff retries (Step 6.5). Stop the apply phase; tell the user another vault writer (diff-vault / bind-codebase / generate-intent) holds the lock and to retry once it releases.

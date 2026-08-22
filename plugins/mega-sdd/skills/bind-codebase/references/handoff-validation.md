# Handoff-integrity validation (binding→units) — the manual surface

The deterministic handoff-integrity validator, invoked manually. This ships ONE slice — binding→units OQ-ID propagation (+ the CONFLICT slices below). Vault→binding and units→bolts boundaries are expansion candidates if this slice proves out. Until 5.x this procedure lived in `commands/validate-handoff.md`; the surface cull relocated it here — invoke by phrase through the front door (`/mega-sdd` → "validate handoff") or run the script directly.

## What it does

Walks the binding docs (`binding.md` / `binding-*.md`, container + per-vault) Resolution Tables, collects all `OQ-*` IDs, then walks the vaults' `units/U-*.md` frontmatter. Reports every OQ-ID declared in a binding LIVE section that is NOT cited in any unit's frontmatter as a `oq_id_dropped` blocker. **OQ declaration universe for the reverse (extras) check:** binding docs ∪ `vault.json` `open_questions[]` ids (`tag` or `id`) — an express-born vault has NO binding doc, and its vault.json is the OQ authority (a unit citing a vault-declared OQ is not an "extra"; an id in NEITHER source still flags `oq_id_extra`). The summary carries both counts (`oq_ids_in_binding`, `oq_ids_in_vault`).

State file: `<cwd>/.mega-sdd/.validation-blockers.json` (OVERWRITE-NOT-APPEND — reflects current truth, not history).

## Why this exists (audit response)

Audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md` §F traced one OQ-ID drop. Real-run inventory revealed 27 of 27 OQs are dropped in TF Import phase-1 + phase-2 units — the audit only saw the tip. The skill-body prose rule in `generate-units` Step 12.5.g cannot enforce this; the model may write a unit without citing the OQ regardless of what the skill body says.

This validator + `PreToolUse` hook on `mega-sdd:execute-bolts` is the [HOOK-VALIDATE] enforcement layer that closes the loop: drops detected automatically when a unit is saved (`PostToolUse` on Write/Edit), bolt generation blocked until drops are resolved (`PreToolUse` on the bolt-gen skill).

## Usage

```bash
bash <plugin-root>/scripts/validate-handoff-binding-units.sh --cwd="$(pwd)"
```

No other arguments. The current project root (CWD) is auto-detected.

## Expected outputs

**PASS (no drops):**
```json
{
  "status": "PASS",
  "summary": {
    "binding_docs_checked": 2,
    "units_checked": 27,
    "oq_ids_in_binding": 27,
    "oq_ids_cited_by_some_unit": 27,
    "drops": 0,
    "extras": 0
  }
}
```

**FAIL (drops):**
```json
{
  "status": "FAIL",
  "summary": {
    "drops": 17,
    ...
  },
  "drops": [
    {
      "type": "oq_id_dropped",
      "oq_id": "OQ-DM-P2-1",
      "source_binding": ".mega-sdd/vaults/binding-phase-2.md",
      ...
    }
  ],
  "next_action": "propagation drops: append the listed OQ-/CONFLICT-IDs to the relevant unit's frontmatter binding_refs; conflict/binding drops: resolve via resolve-oq --binding ..."
}
```

## How to resolve drops (per drop type — S4)

- `oq_id_dropped` / `conflict_id_dropped` (propagation): add the missing ID to the relevant unit's frontmatter `binding_refs:` (below).
- `conflict_unresolved` (the moat's invariant #2): frontmatter edits can NEVER clear this — resolve the CONFLICT via `resolve-oq --binding <binding.md>` (writes the structural ✅ RESOLVED marker the validator reads), or re-run `bind-codebase` until conflicts=0.
- `binding_missing` (units cite CONFLICT-IDs but no binding doc exists): restore the deleted/moved binding.md or re-run `bind-codebase`.
- `binding_stale_recertify` (freshness RECERTIFY — binding basi): a file the binding ANCHORS was changed between `binding_metadata.head` and current HEAD by an **OUT-OF-PIPELINE commit** (unit-attributed bolt commits — `feat(U-XXX):` / `(bolt): U-XXX` / `Unit:` trailer, the shared B1 `unit_of()` grammar — are excluded: they touch anchored files by design and are governed by the B1/B3 gates), so the recorded verdicts no longer describe the code. Frontmatter edits can NEVER clear this — jalankan `/mega-sdd:sync` (incremental) atau re-bind via `bind-codebase`; the changed files are named in the drop's `expected` keterangan. Legacy head-less bindings / missing binding.json / HEAD-moved-without-out-of-pipeline-anchor-hit surface as advisory extras only (`binding_head_absent` / `binding_json_absent` / `binding_head_mismatch`), never a block.

For each `oq_id_dropped` entry: open the unit(s) that implement the OQ's resolution (use the binding doc's Resolution Table to find which unit consumes the decision), and add the OQ-ID to its frontmatter `binding_refs:` list:

```yaml
---
unit_id: U-005
...
binding_refs:
  - OQ-DM-P2-1
  - C-...
---
```

Save the file. `PostToolUse` will auto-re-validate; the state file updates automatically.

## Implementation

The procedure invokes `plugins/mega-sdd/scripts/validate-handoff-binding-units.sh`. The script is deterministic bash + python, no LLM judgment. Same script runs from the `PostToolUse` hook when units are saved.

## Scope

- ✅ Binding → units OQ-ID propagation (slice 1; LIVE-section IDs only — auto-resolved/recommendation OQs AND still-open `## Open Questions` OQs are advisory extras: no resolution ⇒ nothing to cite)
- ✅ Binding → units CONFLICT-ID propagation + CONFLICT *resolution* gate (slice 2 — shipped; unresolved conflict blocks, structural ✅/RESOLVED markers clear)
- ✅ Binding-doc presence backstop (`binding_missing` — units citing conflicts with zero binding docs fail closed)
- ✅ Binding freshness RECERTIFY (`binding_stale_recertify` — `binding_metadata.head` vs non-unit-attributed commits in `<head>..HEAD` ∩ binding.json anchor paths; out-of-pipeline commits only — bolt commits ride B1/B3; migration-safe ladder for legacy artifacts)
- ❌ Binding → units Hard Rule propagation (slice 3)
- ➡ Vault → binding coverage: the dedicated validator was removed in v7 (advisory-only; the claims ledger + analyze cover the surface)
- ❌ Units → bolts traceability (slice 5; partially covered by the bolt-orphans/postflight gates)

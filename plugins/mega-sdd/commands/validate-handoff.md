---
description: Validate cross-artifact handoff integrity (Iter 67.6 walking-skeleton slice 1 — binding→units OQ-ID propagation). Halts deterministically when traceability IDs drop at the binding→unit boundary.
---

# /mega-sdd:validate-handoff

Manually invoke the deterministic handoff-integrity validator. Iter 67.6 ships ONE slice — binding→units OQ-ID propagation. Vault→binding and units→bolts boundaries are expansion candidates if this slice proves out.

## What it does

Walks `<cwd>/.mega-sdd/vaults/binding*.md` Resolution Tables, collects all `OQ-*` IDs, then walks `<cwd>/.mega-sdd/vaults/*-bound/units/U-*.md` frontmatter. Reports every OQ-ID declared in any binding doc that is NOT cited in any unit's frontmatter as a `oq_id_dropped` blocker.

State file: `<cwd>/.mega-sdd/.validation-blockers.json` (OVERWRITE-NOT-APPEND — reflects current truth, not history).

## Why this exists (audit response)

Audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md` §F traced one OQ-ID drop. Real-run inventory revealed 27 of 27 OQs are dropped in TF Import phase-1 + phase-2 units — the audit only saw the tip. The skill-body prose rule in `generate-units` Step 12.5.g (added Iter 67.5) cannot enforce this; the model may write a unit without citing the OQ regardless of what the skill body says.

This validator + `PreToolUse` hook on `mega-sdd:execute-bolts` is the [HOOK-VALIDATE] enforcement layer that closes the loop: drops detected automatically when a unit is saved (`PostToolUse` on Write/Edit), bolt generation blocked until drops are resolved (`PreToolUse` on the bolt-gen skill).

## Usage

```
/mega-sdd:validate-handoff
```

No arguments. The current project root (CWD) is auto-detected.

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
  "next_action": "Append the listed OQ-IDs to the relevant unit's frontmatter binding_refs..."
}
```

## How to resolve drops

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

This command invokes `plugins/mega-sdd/scripts/validate-handoff-binding-units.sh`. The script is deterministic bash + python, no LLM judgment. Same script runs from the `PostToolUse` hook when units are saved.

## Scope (slice 1 only)

- ✅ Binding → units OQ-ID propagation
- ❌ Binding → units CONFLICT-ID propagation (slice 2 — same pattern)
- ❌ Binding → units Hard Rule propagation (slice 3)
- ❌ Vault → binding coverage (slice 4)
- ❌ Units → bolts traceability (slice 5)

If slice 1 proves out via real-run evidence (PostToolUse fires + PreToolUse blocks bolt-gen + clean-up clears state), slices 2-5 follow the identical pattern with different field-sets.

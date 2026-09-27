# Halt guidance — bind family

Per-type guidance for halts emitted by: the per-unit JIT bind (execute-bolts pre-flight 3.9: `write-unit-binding.sh` → `bolts/U-XXX/binding.json`).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### bind_conflict

- `bind_conflict` — the legacy name (a layout-2 `binding.md`) of `binding_conflict`. An existing layout-2 vault with an unresolved CONFLICT still blocks `execute-bolts` (moat invariant #2). ALWAYS STOP. Resolution: `/mega-sdd:migrate-paths --vault-layout=3`, then the mandatory full JIT re-bind (`rebind-units.sh --units=all`), which re-raises every live CONFLICT as `binding_conflict` — then `resolve-oq --binding`.

### binding_conflict

- `binding_conflict` — execute-bolts pre-flight 3.9 (spec 2026-09-10 Appendix F4): `write-unit-binding.sh` recorded a claim with `verdict: CONFLICT` in `<vault>/bolts/U-XXX/binding.json` and `validate-handoff-binding-units.sh --units=` turned it into a `conflict_unresolved` drop — the SAME `.validation-blockers.json` gate the PreToolUse hook denies `execute-bolts` / `bolt-implementer` dispatches on. ALWAYS STOP for the listed unit(s); other units proceed, dependents skip with the reason. Details: registry §Type-specific schemas (`binding_conflict`). Resolution: `resolve-oq --binding` → `write-unit-binding.sh --resolve <id>=KEEP_VAULT|KEEP_CODE|SPLIT|DEFER --by=user` (the file is hook-guarded evidence — never edited by hand; DEFER downgrades the CONFLICT to an OQ the unit carries), or fix the code/unit and re-run pre-flight 3.9. Resolution codes (the displayer renders this legend — the enum never surfaces bare): KEEP_VAULT = code harus diubah mengikuti vault; KEEP_CODE = vault di-update mengikuti kenyataan code; DEFER = jadi OQ yang dibawa unit — gate terbuka, execute-bolts prompt sebelum bolt final; SPLIT = claim dipecah jadi sub-claim.

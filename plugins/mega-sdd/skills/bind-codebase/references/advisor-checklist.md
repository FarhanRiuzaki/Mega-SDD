# Binding advisor checklist (phase-advisor dispatch focus — phase: bind)

Reads: `binding.md` (draft verdicts), `codebase-map.md`, the vault, the KB (if present).

## Hunt these (priority order)
1. **false_confirmed (PRIORITY)** — for every CONFIRMED verdict, open the cited codebase anchor: does it REALLY exist and match the vault claim? A CONFIRMED backed by a hallucinated/unrelated anchor is the worst failure — it silently lets a real conflict through the moat.
2. **missed_match** — for every "not found → OQ/NEW", is it actually present in the codebase under a different name/path (should be CONFIRMED or CONFLICT)?
3. **false_conflict** — is a CONFLICT a real contradiction or a false alarm? FLAG ONLY (never downgrade — human-only).
4. **state_map_error** — Implementation State Map mislabel (IMPLEMENTED vs NEW) vs the actual anchor.

## Materialization (done by bind-codebase, not the advisor)
- `false_confirmed` / `missed_match`, confidence HIGH → a canonical `### CONFLICT-NNN` (tagged `source: advisor` / `ADV-`), fail-safe blocking.
- same, confidence MED/LOW → raise an OQ (non-blocking, surfaced).
- `false_conflict` / `state_map_error` → FLAG for human review; NEVER auto-applied.

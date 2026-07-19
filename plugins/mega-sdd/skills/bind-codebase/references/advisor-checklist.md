# Binding advisor checklist (phase-advisor dispatch focus — phase: bind)

Your dispatch carries a compact **seed** — `.advisor-bundle.md` (the draft verdict+anchor set + the codebase-map / vault / KB **paths** + the map's sha256) — **not the pasted corpus.** The bundle is a SEED, never your horizon: you have `Read`/`Grep`/`Glob`, so **open the on-disk sources yourself and expand past the bundle.** Evidence that is NOT in the bundle is IN SCOPE and finding it is the point — a bundle-bounded review is a moat regression, not a saving.

Reads (open these on disk): `.advisor-bundle.md` (seed) → then the `codebase_map_path` it names, the vault docs, the KB (if present), and each cited codebase anchor.

## Hunt these (priority order)
1. **false_confirmed (PRIORITY)** — for every CONFIRMED verdict, open the cited codebase anchor: does it REALLY exist and match the vault claim? A CONFIRMED backed by a hallucinated/unrelated anchor is the worst failure — it silently lets a real conflict through the moat.
2. **missed_match** — for every "not found → OQ/NEW", **Grep the WHOLE codebase-map** (at the bundle's `codebase_map_path`): is it actually present under a different name/path (should be CONFIRMED or CONFLICT)? This is the case the seed cannot contain — you MUST grep the full map, not just the bundle's verdicts.
3. **false_conflict** — is a CONFLICT a real contradiction or a false alarm? FLAG ONLY (never downgrade — human-only).
4. **state_map_error** — Implementation State Map mislabel (IMPLEMENTED vs NEW) vs the actual anchor.

## Materialization (done by bind-codebase, not the advisor)
- `false_confirmed` / `missed_match`, confidence HIGH → a canonical `### CONFLICT-NNN` (tagged `source: advisor` / `ADV-`), fail-safe blocking.
- same, confidence MED/LOW → raise an OQ (non-blocking, surfaced).
- `false_conflict` / `state_map_error` → FLAG for human review; NEVER auto-applied.

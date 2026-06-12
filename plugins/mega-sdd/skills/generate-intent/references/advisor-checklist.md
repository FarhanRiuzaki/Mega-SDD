# Intent advisor checklist (phase-advisor dispatch focus — phase: intent)

Reads: the vault (7 files) + the source (PRD/BRD/Figma/brief/KB).

## Hunt these
1. **fabrication** — any claim/entity/flow with no traceable source → should be an OQ, not an assertion.
2. **missed_oq** — a genuine gap in the source that was silently filled instead of surfaced.
3. **misclassification** — an OQ tagged business vs tech incorrectly (drives `resolution_mode` downstream).
4. **coverage_gap** — a material source section with no representation in the vault.

## Materialization (done by generate-intent, not the advisor)
- `fabrication` → demote the claim to an OQ (or flag it) + Changelog note.
- `missed_oq` → add an OQ to the roll-up (run it through the Step 3.5 classifier).
- `misclassification` → retag the OQ category.
- `coverage_gap` → add an OQ or a flagged note.

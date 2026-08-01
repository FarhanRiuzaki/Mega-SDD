# Intent advisor checklist (phase-advisor dispatch focus — phase: intent)

Your dispatch carries a compact **seed** — the vault DIR path + the source PATHS (PRD/BRD/brief/screenshot files/KB) + the scope id / phase N-of-total when present + the drafted OQ roll-up COUNTS — **not the pasted corpus.** The seed is never your horizon: you have `Read`/`Grep`/`Glob`, so **open the on-disk files yourself and expand past the seed.** Evidence that is NOT in the dispatch is IN SCOPE and finding it is the point — a dispatch-bounded review is a moat regression, not a saving.

Reads (open these on disk): the vault's 7 files (+ `constitution.md` when present) at the given DIR → then EVERY named source file. For `coverage_gap` you MUST sweep the WHOLE source (Grep/Read it fully) against the vault — a gap is, by definition, the thing the seed cannot contain. **Two carve-outs, checked BEFORE raising findings:**
- **Scope/phase filter:** on a `--scope`/`--phase` run the on-disk source is the UNFILTERED corpus while the vault is deliberately filtered — read `00-index.md`'s Scope / "Sibling scopes" / §Phase block FIRST; source sections belonging to a sibling scope or an out-of-phase domain are **OUT OF SCOPE for `coverage_gap`**, not gaps.
- **Figma via MCP:** frames the dispatcher marks `MCP-loaded, unreadable by you` have no on-disk path — **never raise `fabrication` against a Figma-cited claim** you cannot open; screenshot FILES are in scope.

**A named path that does not open is an `unreadable_source` finding — never return an empty findings list you could not earn** (a partially-blind pass must never be recorded as clean).

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

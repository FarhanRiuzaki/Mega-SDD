# bind-codebase — OQ resolution (Steps 2.6, 2.7, 2.11)

## Contents
- 2.6 Tech-OQ auto-resolution (scan)
- 2.7 Tech-OQ recommendation surfacing
- 2.11 Deferred-OQ auto-resolution

All three annotate verdicts and surface OQs; none relaxes the CONFLICT gate.

## 2.6 Tech-OQ auto-resolution (scan)

For each vault OQ with `category: tech` AND `resolution_mode: scan` AND `classification_confidence: high` (only high-confidence auto-resolves):

a. Read the OQ's `scan_query` (a codebase-map section reference or grep pattern).
b. Execute the scan against the codebase-map (and KB if present).
c. Apply the outcome:
   - **Single unambiguous match** → OQ `status: resolved`, `resolution: <found value>`, `resolved_at: <now>`, `scan_citations: [<found at>]`. Update `vault.json`.
   - **No match** → keep `status: pending`; flip `resolution_mode: scan` → `blocking`; note "scan returned no match". User reviews.
   - **Multiple ambiguous matches** → keep `status: pending`; flip to `blocking`; list candidates in the OQ entry.
d. Append to `binding.md` under `## Tech-OQ Auto-Resolved (Scan)`:
   ```markdown
   | OQ-ID | Category | Question | Scan target | Resolution | Citations |
   |---|---|---|---|---|---|
   | OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |
   ```
e. **Medium/low confidence** tech-scan OQs → skip auto-resolution; pass through unchanged (already listed in `00-index.md` "## Auto-Classification Review").

## 2.7 Tech-OQ recommendation surfacing

For each OQ with `category: tech` AND `resolution_mode: recommend` AND `classification_confidence: high`:

a. **Validate required fields:** `recommendation`, `rationale`, `scan_citations` (≥1), `fallback_if_wrong`. Missing any → halt `oq_recommend_underspecified` (should have been caught at generate-intent; fix the vault upstream).
b. **Verify `scan_citations` exist** in the codebase-map / KB — each MUST resolve to a real entry. Citations that don't resolve indicate fabrication → halt `oq_recommend_citation_invalid`.
c. **Surface in `binding.md`** under `## Tech-OQ Recommendations (review required)`:
   ```markdown
   ### OQ-AR-7 [P2] [tech / recommend] [conf: high]
   **Question**: What HTTP error envelope shape?
   **Recommendation**: Use RFC 7807 problem+json envelope.
   **Rationale**: Industry standard; integrates with most HTTP clients. Existing app/Http/Resources/ErrorResource.php uses an ad-hoc shape — recommendation moves toward consistency.
   **Citations**: app/Http/Resources/ErrorResource.php:12
   **Fallback if wrong**: If RFC 7807 doesn't fit, consider JSON:API error format.
   **User actions**: [ACCEPT] flip to resolved · [OVERRIDE] own resolution · [REJECT] flip to blocking
   ```
d. **Recommendations are NOT auto-resolved.** They appear for one-pass user review; the bind run does NOT block on them (they don't block downstream). User accepts later via `resolve-oq --binding --accept-recommendations`.
e. **Medium/low confidence** tech-recommend OQs → skip surfacing; flow through as blocking (already in "## Auto-Classification Review").

**Anti-halu rails:** NEVER auto-accept a recommendation (always user-in-the-loop for `recommend` mode). NEVER pass a recommendation with unverifiable citations downstream (citation verification is mandatory). `rationale` + `fallback_if_wrong` are the audit trail — if either is missing, the recommendation can't be trusted → halt.

## 2.11 Deferred-OQ auto-resolution

Logical position: after Hard Rules emission, since it processes user-deferred OQs against the now-augmented codebase-map. For each vault OQ with `status: deferred` AND `defer_to: binding`:

a. **Extract** the OQ text + section context.
b. **Search the codebase-map for evidence:** entity name → §3 (data models); endpoint path → §4 (routes); file/symbol → §2 (public interfaces); otherwise string-search all sections with a conservative fuzzy threshold.
c. **High-confidence match** (single unambiguous hit): set `status: resolved`, `resolved_at: <now>`, `resolution: "Auto-resolved by bind-codebase. Evidence: <codebase-map citation>"`. Append to `binding.md` `## Auto-Resolved Deferred OQs`:
   ```markdown
   | OQ-ID | Question | Evidence (codebase-map) | Status |
   |---|---|---|---|
   | OQ-DATA-001 | ... | §3 entry: User table line 42 | auto-resolved |
   ```
d. **No match / ambiguous** (multiple hits or low confidence): do NOT modify status (stays `deferred`); propagate to `binding.md` `## Open Questions` with `Auto-resolve attempted: no match found`. The user walks these via `/mega-sdd:resolve-oq --binding <binding.md>`.
e. **Conservative threshold:** when in doubt, fall back to manual resolution (d). Never silently auto-resolve a deferred OQ that could be wrong; never write an evidence string that doesn't exist in the codebase-map.

Update aggregate counts (`claims_total` / `confirmed` / `conflict` / `oq`) to include any newly auto-resolved deferred OQs in `confirmed`.

# bind-codebase — OQ resolution (Steps 2.6, 2.7, 2.11)

## Contents
- 2.6 Tech-OQ auto-resolution (scan)
- 2.7 Tech-OQ recommendation surfacing
- 2.11 Deferred-OQ auto-resolution

All three annotate verdicts and surface OQs; none relaxes the CONFLICT gate.

> **Write-surface rule (W5):** `vault.json` is never hand-edited here. Every OQ status change below is recorded in the **vault markdown** (checkbox + annotation + classification bracket — the exact grammar `scripts/_lib/vault_md.py` parses), and the Step-6 `derive-vault-json.sh` run mirrors it into `vault.json`. Per-OQ `status` / `resolution` / `resolution_mode` / `resolved_at` are DERIVED keys — a `--patch` that sets them on an md-homed OQ exits 2, and a hand-written value is overwritten by the next derive. The `--patch <tmp-patch>` lane (appended to the same Step-6 derive run) carries only (a) non-derived JSON-only fields on md-homed OQs (e.g. `scan_citations`) and (b) md-homeless `defer_to: binding` orphan entries, which have no markdown line to edit.

## 2.6 Tech-OQ auto-resolution (scan)

For each vault OQ with `category: tech` AND `resolution_mode: scan` AND `classification_confidence: high` (only high-confidence auto-resolves):

> **`--express` override (the default spine):** every "codebase-map" evidence surface in this file re-targets to GROUND truth — `state.json` (manifests, `derived.framework_pack`), `scripts/query-symbol-index.sh` queries, and targeted file Reads — with real `file:line` citations; a `scan_query` written as `codebase-map §X` re-targets to that section's underlying source (the manifest/config/symbol itself). Applies to BOTH the tech-OQ scan (2.6) AND the deferred-OQ step (2.11) below. The map is consulted only on the classic lane. Confidence rules unchanged on both lanes.

a. Read the OQ's `scan_query` (a codebase-map section reference or grep pattern).
b. Execute the scan against the codebase-map (and KB if present).
c. Apply the outcome (markdown is the write surface; the Step-6 derive carries it into `vault.json`):
   - **Single unambiguous match** → record the auto-resolution in the vault markdown: flip the OQ checkbox `[ ]` → `[x]` in the origin doc AND the `00-index.md` roll-up, and append the annotation `→ **Resolved v{vault version}** (YYYY-MM-DD): <found value>` to the OQ line (the exact grammar the deriver parses — it derives `status: resolved` + `resolution` from it and script-stamps `resolved_at` on the transition). Supply `scan_citations: [<found at>]` via `--patch <tmp-patch>` on the same Step-6 derive run (non-derived JSON-only key — allowed on md-homed OQs).
   - **No match** → status stays `open` (checkbox unchanged); flip the OQ line's classification bracket `[tech / scan]` → `[tech / blocking]` in the origin doc + roll-up (the deriver mirrors `resolution_mode` from the bracket); note "scan returned no match" in the `binding.md` `## Open Questions` row. User reviews.
   - **Multiple ambiguous matches** → status stays `open`; same `[tech / scan]` → `[tech / blocking]` bracket edit; list the candidates in the `binding.md` `## Open Questions` row.
d. Append to `binding.md` under `## Tech-OQ Auto-Resolved (Scan)`:
   ```markdown
   | OQ-ID | Category | Question | Scan target | Resolution | Citations |
   |---|---|---|---|---|---|
   | OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |
   ```
e. **Medium/low confidence** tech-scan OQs → skip auto-resolution; pass through unchanged (already listed in `00-index.md` "## Auto-Classification Review").

## 2.7 Tech-OQ recommendation surfacing

For each OQ with `category: tech` AND `resolution_mode: recommend` AND `classification_confidence: high` OR `medium` (S4 — generate-intent's shipped heuristics emit recommend at `medium`; restricting to `high` made this step dead code; surfacing is advisory and never blocks):

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
d. **Recommendations are NOT auto-resolved.** They appear for one-pass user review; the bind run does NOT block on them (they don't block downstream). User accepts later via the standard `resolve-oq` walk — the OQ stays `open` in `vault.json` until then.
e. **Low confidence** tech-recommend OQs → skip surfacing; pass through UNCHANGED (`resolution_mode` is never mutated on confidence grounds — per `binding-contract.md` §Confidence gate; they are already in "## Auto-Classification Review").

**Anti-halu rails:** NEVER auto-accept a recommendation (always user-in-the-loop for `recommend` mode). NEVER pass a recommendation with unverifiable citations downstream (citation verification is mandatory). `rationale` + `fallback_if_wrong` are the audit trail — if either is missing, the recommendation can't be trusted → halt.

## 2.11 Deferred-OQ auto-resolution

Logical position: after Hard Rules emission, since it processes user-deferred OQs against the now-augmented codebase-map. For each vault OQ with `status: deferred` AND `defer_to: binding`:

a. **Extract** the OQ text + section context.
b. **Search the codebase-map for evidence:** entity name → §4 (data models); endpoint path → §3 (routes); file/symbol → §2 (public interfaces); otherwise string-search all sections with a conservative fuzzy threshold.
c. **High-confidence match** (single unambiguous hit) — record it where the OQ lives:
   - **md-homed deferred OQ** (the normal case — the OQ line sits in a vault doc as `[ ]` + `**Deferred (v{X.Y})**: …`): flip the checkbox `[ ]` → `[x]` in the origin doc AND the `00-index.md` roll-up, and replace the `**Deferred (v{X.Y})**: …` annotation with `→ **Resolved v{vault version}** (YYYY-MM-DD): Auto-resolved by bind-codebase. Evidence: <codebase-map citation>` — the Step-6 derive mirrors `status: resolved` + `resolution` from these edits and script-stamps `resolved_at` on the transition.
   - **md-homeless orphan** (a `defer_to: binding` entry with no vault-md line — e.g. a DEFER-demoted binding conflict): there is no markdown to edit; record the resolution via `--patch <tmp-patch>` on the Step-6 derive run — file content `{"open_questions":{"OQ-XXX":{"status":"resolved","resolution":"Auto-resolved by bind-codebase. Evidence: <codebase-map citation>"}}}` (the deriver accepts patch keys on `defer_to: binding` orphans and preserves the entry on every future derive).
   Append to `binding.md` `## Auto-Resolved Deferred OQs`:
   ```markdown
   | OQ-ID | Question | Evidence (codebase-map) | Status |
   |---|---|---|---|
   | OQ-DATA-001 | ... | §4 entry: User table line 42 | auto-resolved |
   ```
d. **No match / ambiguous** (multiple hits or low confidence): do NOT modify the OQ (markdown untouched — status stays `deferred`); propagate to `binding.md` `## Open Questions` with `Auto-resolve attempted: no match found`. The user walks these via `resolve-oq --binding <binding.md>`.
e. **Conservative threshold:** when in doubt, fall back to manual resolution (d). Never silently auto-resolve a deferred OQ that could be wrong; never write an evidence string that doesn't exist in the codebase-map.

Update aggregate counts (`claims_total` / `confirmed` / `conflict` / `oq`) to include any newly auto-resolved deferred OQs in `confirmed`.

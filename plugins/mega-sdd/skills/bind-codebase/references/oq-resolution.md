# bind-codebase — OQ resolution (Steps 2.6, 2.7, 2.11)

## Contents
- 2.6 Tech-OQ auto-resolution (scan)
- 2.7 Tech-OQ decisions (recommend) — verify + list
- 2.11 Deferred-OQ auto-resolution

All three annotate verdicts and resolve OQs; none relaxes the CONFLICT gate. **The rule (`generate-intent/references/vault-core.md §AI technical decisions`): an OQ reaches a human only when the AI cannot answer it — a `tech` OQ is DECIDED, never handed to a `resolve-oq` walk.** A CONFLICT is not an OQ: it stays human-in-the-loop, always.

> **Write-surface rule:** `vault.json` is never hand-edited here. Every OQ status change below is recorded in the **vault markdown** (checkbox + annotation + classification bracket — the exact grammar `scripts/_lib/vault_md.py` parses), and the Step-6 `derive-vault-json.sh` run mirrors it into `vault.json`. Per-OQ `status` / `resolution` / `resolution_mode` / `resolved_at` are DERIVED keys — a `--patch` that sets them on an md-homed OQ exits 2, and a hand-written value is overwritten by the next derive. The `--patch <tmp-patch>` lane (appended to the same Step-6 derive run) carries only (a) non-derived JSON-only fields on md-homed OQs (e.g. `scan_citations`) and (b) md-homeless `defer_to: binding` orphan entries, which have no markdown line to edit. (Field-test hardening note: when a patch never supplied those fields but the OQ's md block carries dedicated hint lines — `` `scan_query: "…"` `` — the deriver falls back to them at the LOWEST precedence; the patch remains the authoring lane and always wins.)

## 2.6 Tech-OQ auto-resolution (scan)

For each OPEN vault OQ with `category: tech` AND `resolution_mode: scan` (every `classification_confidence` — confidence flags the category call for the Auto-Classification Review, it does not gate the probe):

> **`--express` override (the default spine):** every "codebase-map" evidence surface in this file re-targets to GROUND truth — `state.json` (manifests, `derived.framework_pack`), `scripts/query-symbol-index.sh` queries, and targeted file Reads — with real `file:line` citations; a `scan_query` written as `codebase-map §X` re-targets to that section's underlying source (the manifest/config/symbol itself). Applies to BOTH the tech-OQ scan (2.6) AND the deferred-OQ step (2.11) below. The map is consulted only on the classic lane. Confidence rules unchanged on both lanes.

a. Read the OQ's `scan_query` (a codebase-map section reference or grep pattern).
b. Execute the scan against the codebase-map (and KB if present).
c. Apply the outcome (markdown is the write surface; the Step-6 derive carries it into `vault.json`):
   - **Single unambiguous match** → record the auto-resolution in the vault markdown: flip the OQ checkbox `[ ]` → `[x]` in its OQ line (layout-2: constraints.md — the one home; legacy: origin doc AND the 00-index roll-up), and append the annotation `→ **Resolved v{vault version}** (YYYY-MM-DD): <found value>` to the OQ line (the exact grammar the deriver parses — it derives `status: resolved` + `resolution` from it and script-stamps `resolved_at` on the transition). Supply `scan_citations: [<found at>]` via `--patch <tmp-patch>` on the same Step-6 derive run (non-derived JSON-only key — allowed on md-homed OQs).
   - **Multiple matches** → DECIDE, never hand it to a human: pick per the §AI technical decisions order (what the codebase does MOST / in the newest code → the pack → an installed dependency → current docs → the simplest option), flip `[ ]` → `[x]`, append `→ **Resolved v{vault version}** (AI decision, YYYY-MM-DD): <pick> (chosen over: <the other candidates>)`, and supply `recommendation` / `rationale` / `scan_citations` (the winner's anchor) / `fallback_if_wrong` via the patch. It joins 2.7's `## AI Technical Decisions` table.
   - **No match** → DECIDE the same way from the pack / current docs / convention (the citation names that basis — `pack:<framework> §<section>`, `docs:<library>@<version>`, `PRD §X`; never an invented codebase anchor), same annotation + patch fields. ONLY when the question is a FACT no source contains (not a choice) is it handed to a human: leave it `[ ]`, flip the bracket `[tech / scan]` → `[business]` (the deriver mirrors category + mode from the bracket), and note "fact absent from every source" in the `binding.md` `## Open Questions` row. Never write `[tech / blocking]`.
d. Append to `binding.md` under `## Tech-OQ Auto-Resolved (Scan)`:
   ```markdown
   | OQ-ID | Category | Question | Scan target | Resolution | Citations |
   |---|---|---|---|---|---|
   | OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |
   ```
e. An OQ the user flipped to `[business]` in the vault.md "## Auto-Classification Review" (legacy: 00-index.md) is no longer tech — skip it; it is the stakeholder's.

## 2.7 Tech-OQ decisions (recommend) — verify + list

For each OQ with `category: tech` AND `resolution_mode: recommend`, at every `classification_confidence`. The authoring phase writes these ALREADY decided (`[x]` + `(AI decision …)`); a vault written before that rule may still carry them `open` — bind decides those here (step d), so a re-bind is the migration path:

a. **Validate required fields:** `recommendation`, `rationale`, `scan_citations` (≥1), `fallback_if_wrong`. Missing any → halt `oq_recommend_underspecified` (should have been caught at generate-intent; fix the vault upstream).
b. **Verify `scan_citations`**: a citation naming a codebase path / codebase-map / KB entry MUST resolve to a real entry; `pack:<framework> §<section>` MUST name an existing pack section; `PRD §X` MUST exist in the source document; `docs:<library>@<version>` is a labelled external basis (recorded, not verified here). A citation that does not resolve indicates fabrication → halt `oq_recommend_citation_invalid`.
c. **List in `binding.md`** under `## AI Technical Decisions` (information — nothing here is a request):
   ```markdown
   ### OQ-AR-7 [P2] [tech / recommend] [conf: high]
   **Question**: What HTTP error envelope shape?
   **Recommendation**: Use RFC 7807 problem+json envelope.
   **Rationale**: Industry standard; integrates with most HTTP clients. Existing app/Http/Resources/ErrorResource.php uses an ad-hoc shape — recommendation moves toward consistency.
   **Citations**: app/Http/Resources/ErrorResource.php:12
   **Fallback if wrong**: If RFC 7807 doesn't fit, consider JSON:API error format.
   **Override (any time)**: `resolve-oq single-oq OQ-AR-7` — the human answer replaces the AI's pick
   ```
d. **Still `open`? Decide it now.** Once (a) + (b) pass, flip `[ ]` → `[x]` and append `→ **Resolved v{vault version}** (AI decision, YYYY-MM-DD): <the recommendation, one line>` — the Step-6 derive mirrors `status: resolved` + `resolution` + `resolved_by: ai`. The bind run never blocks on a decision and never emits a question for one.
e. **A pick that reads as business** (scope, limits / thresholds, money, retention, regulation, edge-case behaviour, `[LOCKED]`, or a source-vs-code contradiction) is NOT decided: leave it `[ ]`, flip the bracket to `[business]`, and carry it in `## Open Questions` for the stakeholder. `validate-vault-oqs.sh` fails an AI decision that slipped through (`oq_decided_business_signal`).

**Anti-halu rails:** NEVER accept a decision whose citations fail verification, and NEVER decide a business matter (rail e). A decision is a labelled choice, not a fact about the source — never invent a codebase anchor to justify it. `rationale` + `fallback_if_wrong` are the audit trail — if either is missing, the decision can't be trusted → halt.

## 2.11 Deferred-OQ auto-resolution

Logical position: after Hard Rules emission, since it processes user-deferred OQs against the now-augmented codebase-map. For each vault OQ with `status: deferred` AND `defer_to: binding`:

a. **Extract** the OQ text + section context.
b. **Search the codebase-map for evidence:** entity name → §4 (data models); endpoint path → §3 (routes); file/symbol → §2 (public interfaces); otherwise string-search all sections with a conservative fuzzy threshold.
c. **High-confidence match** (single unambiguous hit) — record it where the OQ lives:
   - **md-homed deferred OQ** (the normal case — the OQ line sits in a vault doc as `[ ]` + `**Deferred (v{X.Y})**: …`): flip the checkbox `[ ]` → `[x]` in its OQ line (layout-2: constraints.md; legacy: origin doc AND the 00-index roll-up), and replace the `**Deferred (v{X.Y})**: …` annotation with `→ **Resolved v{vault version}** (YYYY-MM-DD): Auto-resolved by bind-codebase. Evidence: <codebase-map citation>` — the Step-6 derive mirrors `status: resolved` + `resolution` from these edits and script-stamps `resolved_at` on the transition.
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

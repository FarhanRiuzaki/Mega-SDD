# bind-codebase Trigger + Blocking Test

## Trigger cases

### B1: Explicit
- **Prompt:** `/mega-sdd:bind-codebase ./vaults/v1`
- **Expect:** Skill invocation; reads `./codebase-map.md` by default

### B2: Auto-route from orchestrate-flow (brownfield)
- **Setup:** CWD has vault + codebase-map, no bound-vault
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes bind-codebase next

## Behavior — clean binding

### CB1: All CONFIRMED
- **Setup:** vault with claims that all match codebase-map
- **Expect:**
  - `binding.md` written with `conflict: 0`
  - `bound-vault/` produced
  - Hand-off message points to `generate-units`

## Behavior — blocking

### BL1: One CONFLICT
- **Setup:** vault has "API uses Bearer auth", codebase-map says "session cookies"
- **Expect:**
  - `binding.md` written with `conflict: 1`, table shows the conflict
  - `bound-vault/` NOT produced (does not exist)
  - Blocker YAML emitted
  - Hand-off message points to `resolve-oq --binding`

### BL2: All OQ, --strict
- **Setup:** vault references "user.deleted_at field", codebase-map data model doesn't mention it (treated as OQ); user invokes with `--strict`
- **Expect:**
  - `binding.md` written with `oq: 1, conflict: 0`
  - `bound-vault/` NOT produced (because --strict)
  - Hand-off to resolve-oq

### BL3: All OQ, default mode
- **Same setup as BL2** but no `--strict`
- **Expect:**
  - `bound-vault/` produced (default mode treats OQ as non-blocking)
  - OQ propagated to bound-vault for unit grounding

## Halt cases

### H1: Missing codebase-map
- **Setup:** no codebase-map.md exists
- **Expect:** halt with instruction to run scan-codebase

### H2: Vault missing vault.json
- **Setup:** malformed vault directory
- **Expect:** halt with vault repair instruction

### B6: Deferred-OQ auto-resolution (v1.1+)
- **Setup:** vault has OQ-X with `status: deferred, defer_to: binding`, AND codebase-map.md has an exact unambiguous match for the entity/endpoint/file referenced in OQ-X.text
- **Run:** `/mega-sdd:bind-codebase ./vault`
- **Expect:**
  - `binding.md` has a "## Auto-Resolved Deferred OQs" section listing OQ-X with evidence citation
  - vault.json: OQ-X is now `status: resolved`, has `resolved_at` and `resolution` (citing evidence)
  - aggregate counts: OQ-X is included in `confirmed`, not in `oq`

### B7: Deferred-OQ propagation when no match
- **Setup:** vault has OQ-Y with `status: deferred, defer_to: binding`, AND codebase-map.md has NO evidence for it
- **Run:** `/mega-sdd:bind-codebase ./vault`
- **Expect:**
  - `binding.md` has "## Open Questions" section with OQ-Y as a row
  - vault.json: OQ-Y still `status: deferred` (unchanged)
  - Hand-off message suggests `/mega-sdd:resolve-oq --binding`

### B8: Mixed deferred + CONFLICT scenario
- **Setup:** vault has 1 OQ deferred (auto-resolves) + 1 OQ deferred (propagates) + 1 vault claim that conflicts with code
- **Expect:**
  - `bound-vault/` NOT produced (CONFLICT blocks)
  - binding.md has all three sections: Auto-Resolved Deferred OQs (1), Open Questions (1), Conflicts (1, BLOCKING)
  - Hand-off points to `resolve-oq --binding`

## Implementation-State Classification (v1.2+, Iter 1)

### IS1: IMPLEMENTED state — endpoint with handler
- **Setup:** vault claims `POST /api/users`; codebase-map §4 has the route AND §2 has handler symbol `UserController@store`
- **Run:** `/mega-sdd:bind-codebase ./vault`
- **Expect:**
  - Claim verdict: CONFIRMED
  - Implementation State Map row: `state: IMPLEMENTED`, `confidence: high`, `anchor: routes/api.php:N + UserController.php:N`
  - binding.md has the "## Implementation State Map" section populated

### IS2: NEW state — claim absent from codebase
- **Setup:** vault claims `POST /api/audit-log`; codebase-map has neither the route nor a handler
- **Expect:**
  - Verdict downgraded from CONFIRMED → OQ (no anchor at all)
  - Implementation State Map row: `state: NEW`, `confidence: n/a`, `anchor: —`

### IS3: UNKNOWN state — partial match (deferred PARTIAL)
- **Setup:** vault claims `POST /api/orders` with handler having all params (a, b, c); codebase-map §4 has the route AND §2 has handler symbol but signature is `(a, b)` only
- **Expect:**
  - Iter 1 marks: `state: UNKNOWN`, `confidence: low`, anchor cites the signature mismatch
  - Note in binding.md: "Iter 2 will refine via stub/signature detection"

### IS4: KB-CONFIRMED but UNKNOWN state
- **Setup:** codebase-map silent on claim X, but KB domain file marks `[VERIFIED]` for the business rule
- **Expect:**
  - Verdict: CONFIRMED (via KB)
  - Implementation State Map row: `state: UNKNOWN`, `confidence: low`, anchor cites KB file
  - Rationale: KB documents domain knowledge, not necessarily code implementation

### IS5: Blocking rules unchanged
- **Setup:** vault has 1 CONFLICT + 5 CONFIRMED (3 IMPLEMENTED + 2 UNKNOWN states)
- **Expect:**
  - bound-vault NOT produced (CONFLICT blocks)
  - binding.md still has Implementation State Map section for the 5 CONFIRMED claims
  - Hand-off points to resolve-oq

## Tech-OQ Auto-Resolution (v1.3+, Iter 2)

### TQ1: Scan-mode high-confidence — single match
- **Setup:** vault has OQ-AR-1 `category: tech`, `resolution_mode: scan`, `confidence: high`, `scan_query: codebase-map §test_frameworks`; codebase-map has exactly one entry `phpunit` in §test_frameworks
- **Run:** `/mega-sdd:bind-codebase ./vault`
- **Expect:**
  - OQ-AR-1 flipped to `status: resolved`, `resolution: phpunit`, `scan_citations: [phpunit.xml:1]` in vault.json — the annotation carries `(AI decision, <date>)` so it derives `resolved_by: ai` (no human answered it; it must not read as a human answer)
  - binding.md "## Tech-OQ Auto-Resolved (Scan)" table includes OQ-AR-1
  - Pipeline NOT blocked (oq count decreases by 1)

### TQ2: Scan-mode — no match → the AI DECIDES (never asked)
- **Setup:** OQ-AR-2 `resolution_mode: scan`; codebase-map §referenced has 0 hits; the question is a CHOICE ("which test runner?"), the framework pack names one
- **Expect:**
  - OQ-AR-2 flipped `[x]` + `→ **Resolved v{X}** (AI decision, <date>): <pick>`; vault.json `status: resolved`, `resolved_by: ai`
  - `scan_citations` names the real basis (`pack:<framework> §…` / `docs:<lib>@<ver>` / `PRD §X`) — NEVER an invented codebase anchor
  - `recommendation` / `rationale` / `fallback_if_wrong` present; row in binding.md "## AI Technical Decisions"
  - NO `[tech / blocking]` bracket written; nothing routed to a resolve-oq walk

### TQ2b: Scan-mode — no match AND the answer is a FACT no source contains
- **Setup:** OQ-AR-2b asks what the legacy batch job's cut-off hour is; nothing in the codebase / KB / PRD says
- **Expect:**
  - NOT decided — stays `[ ]`; bracket flipped `[tech / scan]` → `[business]` with the note "fact absent from every source"
  - binding.md "## Open Questions" lists it for the stakeholder

### TQ3: Scan-mode high-confidence — multiple matches
- **Setup:** OQ-AR-3 `resolution_mode: scan`, `confidence: high`; codebase-map §referenced has 3 matches (e.g., jest + mocha + vitest all detected)
- **Expect:**
  - the AI picks reuse-first (the one the codebase uses MOST / in the newest code) and resolves it `(AI decision, <date>): <pick> (chosen over: <the others>)`; `scan_citations` = the winner's anchor
  - row in binding.md "## AI Technical Decisions"; `resolved_by: ai`; no ask, no `[tech / blocking]`

### TQ4: Medium/low-confidence scan-mode — resolved like any other
- **Setup:** OQ-AR-4 `resolution_mode: scan`, `confidence: medium`; codebase-map has clear single match
- **Expect:**
  - Resolved exactly as TQ1 — `classification_confidence` grades the CATEGORY call, it does not gate the probe
  - An OQ the user flipped to `[business]` in "## Auto-Classification Review" is skipped (it is the stakeholder's)

### TQ5: Recommend-mode — verified + listed (decided, never asked)
- **Setup:** OQ-AR-7 `resolution_mode: recommend` (any confidence), already `[x]` + `(AI decision …)` from generate-intent; all 4 required fields populated (`recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`); citations resolve
- **Expect:**
  - binding.md "## AI Technical Decisions" section has the full OQ-AR-7 block (decision + rationale + citations + fallback + the override command `resolve-oq single-oq OQ-AR-7`) — NO ACCEPT/OVERRIDE/REJECT request
  - OQ is `resolved` with `resolved_by: ai`; it never enters a resolve-oq walk and never trips `oq_gate`
  - Under `--auto`, the handoff emits `status: completed` with `next_action.suggested_skill: mega-sdd:generate-units`

### TQ5b: Recommend-mode still OPEN (vault written before the rule) — bind decides it
- **Setup:** OQ-AR-7b `[ ] … [tech / recommend]`, 4 fields populated, citations resolve
- **Expect:** bind flips it `[x]` + `(AI decision, <date>): <recommendation>`; Step-6 derive yields `resolved_by: ai` — a re-bind is the migration path

### TQ5c: A "recommend" pick that reads as business — NOT decided
- **Setup:** OQ-AR-7c tagged `[tech / recommend]` but asks "what is the limit for failed logins?" / "the PRD names Postgres but the repo is MySQL — which is authoritative?"
- **Expect:** left `[ ]`, bracket flipped to `[business]`, carried in "## Open Questions"; if it slipped through as an AI decision, `validate-vault-oqs.sh` FAILs `oq_decided_business_signal`

### TQ6: Recommend-mode underspecified — halt
- **Setup:** OQ-AR-8 `resolution_mode: recommend`, `confidence: high`, but `fallback_if_wrong` is missing
- **Expect:**
  - HALT with `oq_recommend_underspecified` blocker YAML
  - missing_fields: [fallback_if_wrong]
  - Pipeline pauses; user fixes vault.json then re-runs

### TQ7: Recommend-mode citation invalid — halt
- **Setup:** OQ-AR-9 `resolution_mode: recommend`, `scan_citations: [app/Foo/Bar.php:99]`; codebase-map does NOT contain this entry
- **Expect:**
  - HALT with `oq_recommend_citation_invalid` blocker YAML
  - invalid_citations: [app/Foo/Bar.php:99]
  - Detects fabrication; user corrects vault.json

### TQ8: Strict mode + tech-OQ auto-resolve interaction
- **Setup:** vault has 3 OQs: 1 business-blocking + 2 tech-scan-high-conf (both with single matches in codebase-map); user invokes with `--strict`
- **Expect:**
  - 2 tech-scan OQs auto-resolved → moved to CONFIRMED-equivalent for accounting
  - 1 business-blocking OQ remains; `--strict` mode blocks bound-vault production
  - binding.md aggregate: claims_total includes 2 newly-resolved; oq=1 (business only)

## Suggested Unit Hard Rules emission (v1.4+, Iter 3)

### SHR1: Implementation-state-derived Hard rule
- **Setup:** binding has claim C-007 `state: IMPLEMENTED` with anchor `app/Http/Controllers/UserController.php:45`; vault_source links to 04-flows.md §read-endpoints
- **Expect:** binding.md "## Suggested Unit Hard Rules" → Hard rules table includes row: `DO NOT modify app/Http/Controllers/UserController.php | applies to 04-flows.md §read-endpoints`

### SHR2: KB [VERIFIED] gotcha → Hard rule
- **Setup:** KB domain file 30-swift-messaging.md has Gotcha G-002 marked `[VERIFIED]` AND file path stable in codebase-map (`app/Services/MT202Dispatcher.php`)
- **Expect:** Hard rules table includes row: `DO NOT modify app/Services/MT202Dispatcher.php | source: KB [VERIFIED] gotcha`

### SHR3: KB [INFERRED] gotcha → Anti-pattern only (NOT Hard rule)
- **Setup:** KB has a Gotcha marked `[INFERRED]` (single-source claim)
- **Expect:** Suggestion appears in Anti-patterns table ONLY, NOT in Hard rules. Per DESIGN-OQ-6.

### SHR4: KB [OPEN] item → Anti-pattern with caveat
- **Setup:** KB has `## 10. Open Questions` entry that's mechanically relevant
- **Expect:** Anti-pattern row references the OQ; Hard rules table NOT populated for this item

### SHR5: Hard rule with unanchored target → suppressed
- **Setup:** KB suggests `DO NOT modify <file>` but codebase-map doesn't list `<file>`
- **Expect:** Suggestion SUPPRESSED (would fail `hard_rule_unanchored` at bolt time); falls back to Anti-pattern entry with note "file not in codebase-map; verify path before promoting to Hard rule"

### SHR6: CONFLICT resolution KEEP_CODE → Hard rule
- **Setup:** binding has CONFLICT user resolved as KEEP_CODE for `app/Services/Foo.php`
- **Expect:** Hard rule emitted `DO NOT modify app/Services/Foo.php` for downstream units that might touch this file

### SHR7: CONFLICT resolution KEEP_VAULT → no Hard rule
- **Setup:** binding had CONFLICT user resolved as KEEP_VAULT (intentional rewrite)
- **Expect:** NO Hard rule emitted (the conflict file is being deliberately changed)

### SHR8: Empty section when no suggestions
- **Setup:** clean greenfield-ish binding, no KB, no CONFLICTs
- **Expect:** "## Suggested Unit Hard Rules" section exists with both sub-tables empty (rather than omitted) — generate-units reads it; no rules to insert

### Canonical CONFLICT heading emission
- On a blocking run: every ACTIVE conflict in `binding.md` is written as a canonical `### CONFLICT-N` detail heading (with `conflict_class` + `resolution_complexity`), not table-only — the heading form is the token `validate-handoff-binding-units.sh` reads.

## Sync-lane handoff — claim-scoped re-bind routes generate-units through reconcile

Living-vault continuous-sync design `2026-06-10-living-vault-continuous-sync-design.md` §3.3 (Mode D chain: `bind-codebase --paths` → `generate-units (S6 reconcile)`) + §3.6 (reconcile = re-read the refreshed binding, UPDATE existing unit IDs in place for id-stability, recompute `status`/stale/superseded). The completed→generate-units handoff `suggested_args` MUST be state-aware — keyed on WHAT BIND ACTUALLY DID (a claim-scoped re-bind that actually executed vs a full re-bind, including a `--paths` run that fell back), not on whether the `--paths` flag was passed; the operative emission spec is `bind-codebase/references/auto-memory-handoff.md §Handoff emission`.

### SY1: `--paths` re-bind (clean) → generate-units `--reconcile`
- **Setup:** vault + prior `binding.md` already exist; bind invoked as `/mega-sdd:bind-codebase ./vault --paths=@<vault>/.sync-changed-paths.txt --auto` (S4 claim-scoped re-bind, the living-vault sync lane per §3.4). Re-verdict is clean (no CONFLICTs).
- **Expect:**
  - `bound/` produced (no CONFLICT)
  - handoff `status: completed`; `next_action.suggested_skill: mega-sdd:generate-units`
  - handoff `next_action.suggested_args: ["--reconcile", "--auto"]` — the sync lane MUST route generate-units through the S6 reconcile (in-place id-stable UPDATE + `status`/stale/superseded recompute per §3.3/§3.6), NOT a fresh generation
  - a bare `["--auto"]` here is a **FAIL** — dropping `--reconcile` makes generate-units regenerate from scratch, breaking unit id-stability + stale/superseded handling in the sync lane

### SY2: full re-bind (no `--paths`) → `--auto` only
- **Setup:** bind invoked as `/mega-sdd:bind-codebase ./vault --auto` (full re-bind; no `--paths`), clean re-verdict
- **Expect:**
  - handoff `next_action.suggested_args: ["--auto"]` — NO `--reconcile` (a full re-bind drives a fresh generate-units generation, not an in-place reconcile)
  - non-regression guard: `--reconcile` is emitted ONLY when a claim-scoped re-bind actually executed (the `--paths` sync lane with no fallback), never on a full re-bind (including a `--paths` run that fell back to a full re-bind — see SY3), and never on the halted→`resolve-oq` branch

### SY3: `--paths` passed BUT fell back to full re-bind → `--auto` only (state-based discriminator)
- **Setup:** vault + prior `binding.md` exist; bind invoked as `/mega-sdd:bind-codebase ./vault --paths=@<vault>/.sync-changed-paths.txt --auto`, but a fallback trigger fires — per binding-contract.md "Fallback to full re-bind" (prior `binding.md` unparseable / vault regenerated since last bind WITHOUT a diff-vault patch record (a diff-vault apply's bump + present `VAULT-DIFF.md` is a PATCH, not a regeneration — it does NOT fire this trigger) / changed paths >40% of anchored files / a carried-forward anchor file vanished) — so bind DEGRADES to a full re-bind and rewrites `binding.md` whole. Clean re-verdict.
- **Expect:**
  - handoff `next_action.suggested_args: ["--auto"]` — NO `--reconcile`, IDENTICAL to a plain full re-bind (SY2). The discriminator is WHAT BIND ACTUALLY DID (claim-scoped re-bind executed vs full re-bind), NOT whether the `--paths` flag was passed
  - emitting `["--reconcile", "--auto"]` here is a **FAIL** — a fallback run regenerated the whole binding exactly like a full re-bind, so reconciling in place would mis-key off the flag and contradict the full-re-bind handoff rule (and SY2's "never on a full re-bind" guard)

## Pass criteria

All triggers fire. Blocking gate behaves per binding-contract.md. Deferred-OQ auto-resolution (B6) and propagation (B7) follow bind-codebase §2.5. Implementation-State Classification (IS1-IS5) follows §2.5 per binding-contract.md §Implementation-State Classification. Tech-OQ Auto-Resolution + AI decisions (TQ1-TQ8, incl. TQ2b / TQ5b / TQ5c) follows §2.6-§2.7. Suggested Unit Hard Rules (SHR1-SHR8) follows §2.8 — `[VERIFIED]` + mechanically detectable → Hard rules; everything else → Anti-patterns. Sync-lane handoff (SY1-SY3): the completed→generate-units `--reconcile` discriminator is STATE-based — it keys on WHAT BIND ACTUALLY DID, not on whether the `--paths` flag was passed. A claim-scoped re-bind that actually executed (living-vault §3.3/§3.6, no fallback) emits the handoff with `["--reconcile", "--auto"]` (in-place id-stable reconcile + status/stale/superseded recompute); a full re-bind — whether a plain `--auto` run (SY2) OR a `--paths` run that fell back to a full re-bind (SY3, per binding-contract.md "Fallback to full re-bind") — keeps `["--auto"]` (fresh generation); `--reconcile` never leaks to a full re-bind or to the halted→resolve-oq branch. No silent guesses; no fabricated citations. Tech OQs are decided by the AI (cited, reversible via `resolve-oq single-oq`) and never asked; business OQs, missing facts and CONFLICTs are never decided; no decision with unverifiable citations under any condition.

---

## Iter 33 — Predictive checks

### BC-PH1 — binding_input_complete predictive check entry

**Setup:** N/A — documentation test

**Verify:**
- Grep `references/predictive-checks.md` for `## bind-codebase preflight checks` section
- Confirm `check_id: binding_input_complete` entry present
- Confirm command checks for vault.json AND codebase-map.md
- Confirm fatal=yes; predicts_halt=bind_conflict or dep_missing
- Confirm on_fail hint instructs "Run scan-codebase first if codebase-map.md absent; run generate-intent first if vault.json absent"

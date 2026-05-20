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
  - OQ-AR-1 flipped to `status: resolved`, `resolution: phpunit`, `scan_citations: [phpunit.xml:1]` in vault.json
  - binding.md "## Tech-OQ Auto-Resolved (Scan)" table includes OQ-AR-1
  - Pipeline NOT blocked (oq count decreases by 1)

### TQ2: Scan-mode high-confidence — no match
- **Setup:** OQ-AR-2 `resolution_mode: scan`, `confidence: high`; codebase-map §referenced has 0 hits
- **Expect:**
  - OQ-AR-2 stays `status: pending`; `resolution_mode` flipped from `scan` to `blocking` with note "scan returned no match"
  - binding.md "## Open Questions" section lists OQ-AR-2 (not in Auto-Resolved table)
  - No silent guess emitted

### TQ3: Scan-mode high-confidence — multiple matches
- **Setup:** OQ-AR-3 `resolution_mode: scan`, `confidence: high`; codebase-map §referenced has 3 matches (e.g., jest + mocha + vitest all detected)
- **Expect:**
  - OQ-AR-3 stays `status: pending`; flipped to `blocking` with note "scan ambiguous — 3 matches: jest, mocha, vitest"
  - User reviews manually

### TQ4: Medium/low-confidence scan-mode — skipped
- **Setup:** OQ-AR-4 `resolution_mode: scan`, `confidence: medium`; codebase-map has clear single match
- **Expect:**
  - Auto-resolution SKIPPED (per DESIGN-OQ-3 high-conf gate)
  - OQ-AR-4 stays `pending` with `resolution_mode: scan` unchanged
  - User reviews via 00-index.md "## Auto-Classification Review" before re-running binding

### TQ5: Recommend-mode high-confidence — surfaced
- **Setup:** OQ-AR-7 `resolution_mode: recommend`, `confidence: high`; all 4 required fields populated (`recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`); citations resolve in codebase-map
- **Expect:**
  - binding.md "## Tech-OQ Recommendations (review required)" section has full OQ-AR-7 block
  - Recommendation displays with all 4 fields + ACCEPT/OVERRIDE/REJECT user actions
  - OQ stays `pending` (NOT auto-resolved) — user reviews after binding completes
  - Pipeline continues (recommendation doesn't block)

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

## Pass criteria

All triggers fire. Blocking gate behaves per binding-contract.md. Deferred-OQ auto-resolution (B6) and propagation (B7) follow bind-codebase §2.5. Implementation-State Classification (IS1-IS5) follows §2.5 per binding-contract.md §Implementation-State Classification. Tech-OQ Auto-Resolution (TQ1-TQ8) follows §2.6-§2.7 per Iter 2 spec. Suggested Unit Hard Rules (SHR1-SHR8) follows §2.8 per Iter 3 spec — DESIGN-OQ-6 gates: `[VERIFIED]` + mechanically detectable → Hard rules; everything else → Anti-patterns. No silent guesses; no fabricated citations; no auto-accepted recommendations. No unguarded auto-resolution under any condition.

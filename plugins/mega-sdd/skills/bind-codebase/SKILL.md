---
name: bind-codebase
version: 1.7.0
description: Validate a vault against `codebase-map.md` (primary ground truth) + `docs/knowledge-base/` (secondary ground truth, v1.1+). Produces `<vault>-bound/` + `binding.md` with CONFIRMED/CONFLICT/OQ verdicts per claim + Implementation State Map (v1.2+, Iter 1) + Tech-OQ auto-resolution (v1.3+, Iter 2) + Suggested Unit Hard Rules (v1.4+, Iter 3 — emits machine-parseable constraints for generate-units to pull into unit body). BLOCKS downstream unit generation on conflicts. Triggers — "bind vault to code", "validate vault against repo", "cek vault vs codebase", "binding gate", or paraphrases.
---

# Bind-Codebase

The brownfield anti-hallucination keystone. Refuses to let unit generation proceed against an ungrounded vault.

**Announce at start:** "I'm using the bind-codebase skill to validate the vault against the codebase map."

## When to use

- After `scan-codebase` produced `codebase-map.md` and the user has a vault
- `orchestrate-flow` auto-routes to this skill for brownfield projects
- User explicit: `/mega-sdd:bind-codebase <vault> [<codebase-map>]`

## Inputs

- Vault path (positional, required) — directory containing the 7-file vault
- Codebase map path (optional, default: `<repo-root>/codebase-map.md` or `./codebase-map.md`)
- Knowledge-base path (optional, v1.1+; auto-probed in `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, `old-reference/knowledge-base/` — first hit wins; override with `--kb=<path>`)
- Flags: `--strict` (block on OQ too, not just CONFLICT), `--auto`, `--kb=<path>` (override KB auto-probe), `--no-kb` (skip KB consultation entirely)

## Outputs

- `binding.md` — always written, even when blocking
- `<vault>-bound/` (sibling of vault dir) — written only when no CONFLICTs (or `--strict` and no OQs)

## Procedure

1. **Load inputs.**
   - Read vault files (00-index, 01-overview, ..., vault.json)
   - Read codebase-map.md
   - If codebase-map missing: halt with message — instruct user to run `scan-codebase` first

2. **Per claim type (per `references/binding-contract.md`), produce verdict.**
   For each vault claim referencing code:
   - **Primary ground truth: search codebase-map for matching evidence.**
   - Apply verdict logic:
     - Exact match (file path + signature) → CONFIRMED
     - Found but contradicts → CONFLICT (NEVER overridden by KB; codebase-map wins for conflicts)
     - Not found → **secondary ground truth: consult KB if present (v1.1+).**

   **KB consultation (v1.1+, when codebase-map verdict is "not found" only):**
   - Skip if `--no-kb` set or no KB detected
   - Locate the domain file in KB matching the claim's domain tag
   - Search for the claim text in the matching domain file (focus on `## 5. Process`, `## 6. Outputs`, `## 7. Business Rules`)
   - Apply marker-aware verdict:
     - KB `[VERIFIED]` match → **CONFIRMED** (note: `via KB §<file>` in binding.md)
     - KB `[INFERRED]` match → **CONFIRMED with note** (binding.md flags `verified via KB inference; downstream may revisit`)
     - KB `[OPEN]` match → **OQ** (propagate KB OQ tag if present)
     - No KB match → **OQ** (fresh — no auto-resolve attempted)
   - **Never override a codebase-map CONFLICT verdict via KB.** KB is consulted only when codebase-map is silent. This preserves the binding gate's primary contract.

2.5. **Implementation-state classification (v1.2+, Iter 1).**

   For each claim now marked CONFIRMED, classify implementation readiness per `references/binding-contract.md` §Implementation-State Classification. Iter 1 emits **binary states only**: `IMPLEMENTED` / `NEW` (with `UNKNOWN` for ambiguous heuristics). PARTIAL is deferred to Iter 2.

   **Endpoint claims** (`POST /api/foo`, `GET /bar`, …):
   - Route found in codebase-map §4 AND handler symbol present in §2 with matching signature → state: `IMPLEMENTED` (confidence: high)
   - Route found, handler present but **signature field set mismatches claim** → state: `PARTIAL_FIELDS_MISSING` or `PARTIAL_FIELDS_SURPLUS` (v1.7+, Iter 8 — see §field-level-diff below)
   - Route found, handler symbol absent in §2 → state: `UNKNOWN` (confidence: low)
   - Route not found AND handler absent → state: `NEW`

   **Entity claims** (User has email + role; Order has line_items):
   - Entity found in §3 AND ALL claimed fields detected (V == C) → state: `IMPLEMENTED` (confidence: high)
   - Entity found but **field set diff detected** (V ⊂ C OR C ⊂ V) → state: `PARTIAL_FIELDS_MISSING` (code missing some claim fields) or `PARTIAL_FIELDS_SURPLUS` (code has fields not in claim)
   - Entity found but disjoint field sets → state: `UNKNOWN`
   - Entity not in §3 → state: `NEW`

   **Method/handler claims** (`sendEmail()`, `processPayment()`):
   - Symbol in §2 with matching signature (param names + types) → state: `IMPLEMENTED` (confidence: high)
   - Symbol in §2 with different signature (V \ C or C \ V non-empty) → state: `PARTIAL_FIELDS_*` per direction
   - Symbol absent disjoint signature → state: `UNKNOWN`
   - Symbol not in §2 → state: `NEW`

### Field-level diff detection (v1.7+, Iter 8 — fills the PARTIAL state DEFERRED in Iter 1 per DESIGN-OQ-1)

For each CONFIRMED claim that specifies fields/params explicitly (entity field list, endpoint request body schema, function signature):

1. **Extract V** = field set asserted by vault claim
2. **Extract C** = field set extracted from codebase-map (tree-sitter signature extraction per Iter 6 precision_tier=ast; regex fallback gives lower confidence)
3. **Compute diff**:
   - `ADD = V \ C` (missing in code; need to add)
   - `KEEP = V ∩ C` (shared)
   - `REMOVE = C \ V` (surplus in code; vault might need update OR code might need cleanup)
4. **Assign state**:
   - V == C → `IMPLEMENTED`
   - C ⊂ V (ADD non-empty, REMOVE empty) → `PARTIAL_FIELDS_MISSING`
   - V ⊂ C (REMOVE non-empty, ADD empty) → `PARTIAL_FIELDS_SURPLUS`
   - Both ADD and REMOVE non-empty → `PARTIAL_FIELDS_BOTH` (rare; signals semantic mismatch)
   - V ∩ C empty but symbol exists → `UNKNOWN`
5. **Record diff** in Implementation State Map's `field_diff` column

### Example — user's login scenario

```
Vault claim C-LOGIN-1: POST /api/login accepts { nip, nama, password }
Codebase-map §4: POST /api/login → LoginController@store
Codebase-map §2: LoginController@store(nip: string, password: string)

Field extraction:
  V = { nip, nama, password }
  C = { nip, password }

Diff:
  ADD    = V \ C = { nama }
  KEEP   = V ∩ C = { nip, password }
  REMOVE = C \ V = { }

State = PARTIAL_FIELDS_MISSING
```

This state propagates to `generate-units`, which assigns `task_type: extend` with Migration notes auto-populated as:
- **ADD**: nama field
- **KEEP**: nip, password
- **REMOVE**: (none)

### Anti-halu rails (Iter 8)

- Field-level diff REQUIRES tree-sitter precision (`precision_tier: ast` in codebase-map). On `precision_tier: regex`, field extraction is unreliable → fall back to v1.6 binary classification (PARTIAL collapsed to UNKNOWN)
- `PARTIAL_FIELDS_SURPLUS` ALWAYS triggers human review prompt in generate-units (code has things spec doesn't mention → ambiguous intent)
- `PARTIAL_FIELDS_BOTH` (both ADD and REMOVE non-empty) is rare AND high-stakes — surfaced with strong warning; user typically needs to update vault OR triage code drift
- Diff calculation is DETERMINISTIC (set operations on extracted token lists); no fuzzy similarity matching

   **KB-confirmed claims**: when CONFIRMED was reached via KB consultation (codebase-map silent, KB had `[VERIFIED]` match), classify as `UNKNOWN` with `low` confidence — KB documents domain knowledge, not necessarily implementation. Iter 2 refines.

   **Conservative default**: when heuristic cannot classify → `UNKNOWN` with confidence `low`. Never silently claim `IMPLEMENTED` without a concrete anchor.

   **Anchor recording**: every state assignment carries an `anchor` field with the source-of-truth citation (e.g., `UserController.php:45 + routes/api.php:12`). For state `NEW`, anchor is `—`.

   Write the result to `binding.md` under a new "## Implementation State Map" section. Schema and template in `references/binding-contract.md`.

   **Anti-halu rails**:
   - Never promote `NEW` to `IMPLEMENTED` based on inference; only direct codebase-map (or KB-VERIFIED) evidence.
   - `UNKNOWN` with low confidence is surfaced in binding.md; downstream `generate-units` defaults to `task_type: create` (safer).
   - Implementation state classification does NOT change blocking rules. CONFLICT still blocks. IMPLEMENTED is still CONFIRMED — just annotated for downstream task_type assignment.

2.6. **Tech-OQ auto-resolution via scan (v1.3+, Iter 2).**

   For each OQ in the vault with `category: tech` AND `resolution_mode: scan` AND `classification_confidence: high` (per DESIGN-OQ-3 gate — only high-conf auto-resolves):

   a. Read the OQ's `scan_query` (codebase-map section reference or grep pattern).
   b. Execute the scan against codebase-map (and KB if present).
   c. Apply outcome:
      - **Single unambiguous match** → set OQ `status: resolved`, `resolution: <found value>`, `resolved_at: <now>`, `scan_citations: [<found at>]`. Update vault.json.
      - **No match** → keep OQ `status: pending`; flip `resolution_mode: scan` → `resolution_mode: blocking`; note "scan returned no match" in the OQ entry. User reviews.
      - **Multiple ambiguous matches** → keep OQ `status: pending`; flip to `blocking`; list candidates in the OQ entry.

   d. Append to `binding.md` under new "## Tech-OQ Auto-Resolved (Scan)" section:
      ```markdown
      | OQ-ID | Category | Question | Scan target | Resolution | Citations |
      |---|---|---|---|---|---|
      | OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |
      ```

   e. **Medium/low confidence tech-scan OQs**: skip auto-resolution (per DESIGN-OQ-3); pass through unchanged to downstream consumption. They appear in `00-index.md` "## Auto-Classification Review" section already.

2.7. **Tech-OQ recommendation surfacing (v1.3+, Iter 2).**

   For each OQ with `category: tech` AND `resolution_mode: recommend` AND `classification_confidence: high`:

   a. **Validate required fields**: `recommendation`, `rationale`, `scan_citations` (≥1), `fallback_if_wrong`. Missing any → halt with `oq_recommend_underspecified` (this should have been caught at generate-intent time; if reaches binding, fix the vault upstream first).

   b. **Verify scan_citations exist in codebase-map / KB**: each citation MUST resolve to an entry in codebase-map (or KB if KB present). Citations that don't resolve indicate fabrication → halt with `oq_recommend_citation_invalid`.

   c. **Surface in `binding.md`** under new "## Tech-OQ Recommendations (review required)" section:
      ```markdown
      ### OQ-AR-7 [P2] [tech / recommend] [conf: high]

      **Question**: What HTTP error envelope shape?

      **Recommendation**: Use RFC 7807 problem+json envelope.

      **Rationale**: Industry standard; integrates with most HTTP clients. Existing pattern at app/Http/Resources/ErrorResource.php uses ad-hoc shape — recommendation moves toward consistency.

      **Citations**:
      - app/Http/Resources/ErrorResource.php:12

      **Fallback if wrong**: If RFC 7807 doesn't fit client expectations, revisit and consider JSON:API error format.

      **User actions**:
      - [ACCEPT] — flip OQ status to `resolved` with this recommendation
      - [OVERRIDE] — provide your own resolution
      - [REJECT] — flip to `blocking`; needs different resolution path
      ```

   d. **Recommendations are NOT auto-resolved**. They appear in binding.md for one-pass user review. The bind-codebase run does NOT block on recommendations (they don't block downstream pipeline). User can ACCEPT later via `resolve-oq --binding` (which gets a new `--accept-recommendations` flag in Iter 2; pre-Iter-2 users edit vault manually).

   e. **Medium/low confidence tech-recommend OQs**: skip surfacing (per DESIGN-OQ-3 gate). They flow through as blocking. Already listed in `00-index.md` "## Auto-Classification Review".

   **Anti-halu rails**:
   - NEVER auto-accept a recommendation. Always user-in-the-loop for `recommend` mode.
   - NEVER pass a recommendation with unverifiable citations downstream. Citation verification is mandatory.
   - `rationale` and `fallback_if_wrong` provide audit trail — if either is missing, the recommendation cannot be trusted; halt.

2.8. **Emit Suggested Unit Hard Rules (v1.4+, Iter 3).**

   Bind-codebase suggests Hard Rules that `generate-units` will pull into per-unit `## Hard rules` sections. These are the bridge from binding intelligence → per-unit pre/post-flight enforcement.

   Per DESIGN-OQ-6 (locked): KB gotchas → Anti-patterns by default; promoted to Hard rules ONLY when KB marker is `[VERIFIED]` AND the gotcha is mechanically detectable.

   Sources for suggestions:

   **a. Binding state-derived suggestions** (per claim with `state: IMPLEMENTED` or `state: UNKNOWN`):
   - Anchor file exists + claim is CONFIRMED → suggest `DO NOT modify <anchor-file>` rule for any unit whose vault_source overlaps this claim, UNLESS the claim is explicitly subject to extension (task_type=extend candidate). The rule is conservative — defaults to "don't touch what's working."

   **b. CONFLICT-derived hard rules** (per CONFLICT after user resolution via resolve-oq):
   - If user resolved CONFLICT with `KEEP_CODE` action → suggest `DO NOT modify <conflicting-file>` rule for any downstream unit that might touch this file.
   - If user resolved with `KEEP_VAULT` → no Hard rule (the conflict is being intentionally rewritten).
   - If user resolved with `DEFER` → no Hard rule (OQ propagates instead).

   **c. KB-derived hard rules** (only when KB present AND marker = `[VERIFIED]`):
   - Domain file `## 9. Edge Cases & Gotchas` entry marked `[VERIFIED]` AND mechanically detectable (file path + signature stable) → suggest `DO NOT modify <gotcha-anchor-file>` rule
   - Domain file `## 8. State Machine` entry marked `[VERIFIED]` for a function with stable signature → suggest `function <name> MUST preserve signature: <sig>` rule
   - KB items marked `[INFERRED]` or `[OPEN]` → DO NOT promote to Hard rule (per DESIGN-OQ-6); they go to Anti-patterns suggestion instead

   **d. KB-derived Anti-pattern suggestions** (informational, NOT machine-validated):
   - Every `## 9. Edge Cases & Gotchas` entry in KB → suggested Anti-pattern with brief description + KB anchor
   - Every "do-not-replicate" critical finding in KB README → suggested Anti-pattern

   Write to `binding.md` under new section "## Suggested Unit Hard Rules" (v1.4+):

   ```markdown
   ## Suggested Unit Hard Rules (v1.4+)

   > These suggestions are picked up by `generate-units` and inserted into each relevant unit's `## Hard rules` (machine-validated at bolt time) or `## Anti-patterns` (informational guidance) sections.

   ### Hard rules (machine-validated at bolt time)
   | Source | Suggested rule | Applies to units derived from |
   |---|---|---|
   | Implementation state | DO NOT modify app/Http/Controllers/UserController.php | 04-flows.md §read-endpoints |
   | KB [VERIFIED] gotcha | DO NOT modify app/Services/MT202Dispatcher.php | 05-decisions.md §IDR-routing |

   ### Anti-patterns (informational guidance)
   | Source | Suggested guidance | Applies to units derived from |
   |---|---|---|
   | KB gotcha G-002 | Don't replicate the IDR MT202 dispatch path — file written but never sent; see knowledge-base/10-domains/30-swift-messaging.md §G-002 | 04-flows.md §payment-settlement |
   | KB critical finding | Don't replicate cfkdhl→CFKDDL silent typo; see knowledge-base/10-domains/10-cif-customer.md §Edge Case 9 | 04-flows.md §customer-edit |
   ```

   **Anti-halu rails**:
   - NEVER promote `[INFERRED]` or `[OPEN]` KB items to Hard rules. Anti-patterns only.
   - NEVER suggest a Hard rule whose anchor file doesn't exist in codebase-map (`hard_rule_unanchored` would fire at bolt time anyway — surface here).
   - Suggestions are RECOMMENDATIONS, not impositions. `generate-units` reviews + filters before inserting into units.

2.5. **Deferred-OQ auto-resolution.**

   For each OQ in the vault with `status: deferred` AND `defer_to: binding`:

   a. **Extract** the OQ text and section context.

   b. **Search codebase-map.md for evidence:**
      - If OQ mentions a specific entity name → search §3 (data models / schemas) for exact match
      - If OQ mentions an endpoint path → search §4 (routes / endpoints) for exact match
      - If OQ mentions a file path or symbol name → search §2 (public interfaces) for exact match
      - Otherwise → string-search across all map sections with conservative fuzzy threshold

   c. **High-confidence match** (single unambiguous hit):
      - Set OQ status: `resolved`
      - Set `resolved_at: <now>`
      - Set `resolution: "Auto-resolved by bind-codebase. Evidence: <codebase-map citation>"`
      - Append entry to `binding.md` under a "## Auto-Resolved Deferred OQs" section:
        ```
        | OQ-ID | Question | Evidence (codebase-map) | Status |
        |---|---|---|---|
        | OQ-DATA-001 | ... | §3 entry: User table line 42 | auto-resolved |
        ```

   d. **No match found OR ambiguous match** (multiple hits or low confidence):
      - Do NOT modify OQ status (remains `deferred`)
      - Propagate to `binding.md` under "## Open Questions" section:
        ```
        | ID | Question | Source vault section | Auto-resolve attempted |
        |---|---|---|---|
        | OQ-DATA-001 | ... | 03-data-model.md | no match found |
        ```
      - These get walked by user via `/mega-sdd:resolve-oq --binding <binding.md>`

   e. **Conservative threshold:** When in doubt, prefer falling back to manual resolution (d). Never silently auto-resolve a deferred OQ that could be wrong. The user trusts the citation in (c); never write an evidence string that doesn't exist in codebase-map.

   Update aggregate counts (claims_total / confirmed / conflict / oq) to include any newly auto-resolved deferred OQs in `confirmed`.

3. **Aggregate counts.** Track `claims_total`, `confirmed`, `conflict`, `oq`.

4. **Write `binding.md`.** Use the template from `references/binding-contract.md`:

```yaml
---
vault: <vault path>
codebase_map: <map path>
bound_at: <ISO timestamp>
strict: <true/false>
---

# Binding Manifest

## Summary
- claims_total: N
- confirmed: N
- conflict: N
- oq: N

## Confirmed Claims (N)
- C-001 | <vault file:line> | <codebase evidence> | <claim text>
...

## Implementation State Map (N, v1.2+; field_diff column v1.7+)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high | (exact match) |
| C-LOGIN-1 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high | ADD: [nama] · KEEP: [nip, password] · REMOVE: [] |
| C-007 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic cannot classify | low | n/a |
| C-012 | OQ | NEW | — | n/a | n/a |
| C-023 | CONFIRMED | PARTIAL_FIELDS_SURPLUS | OrderController.php:88 | medium | ADD: [] · KEEP: [order_id, items] · REMOVE: [legacy_ref] (CAUTION: code has fields vault doesn't mention) |

## Tech-OQ Auto-Resolved (Scan) (N, v1.3+)
| OQ-ID | Category | Question | Scan target | Resolution | Citations |
|---|---|---|---|---|---|
| OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |

## Tech-OQ Recommendations (review required) (N, v1.3+)
> Listed below — each has ACCEPT / OVERRIDE / REJECT action options. Recommendations do NOT block; user reviews one-pass after binding completes.

### OQ-AR-7 [P2] [tech / recommend] [conf: high]
…

## Suggested Unit Hard Rules (v1.4+, Iter 3)
> Picked up by generate-units; inserted into each relevant unit's ## Hard rules (machine-validated) or ## Anti-patterns (informational) sections per DESIGN-OQ-6.

### Hard rules (machine-validated)
| Source | Suggested rule | Applies to units derived from |
|---|---|---|
…

### Anti-patterns (informational)
| Source | Suggested guidance | Applies to units derived from |
|---|---|---|
…

## Conflicts (N) — BLOCKING
| ID | Vault Claim | Codebase Reality | Resolution Needed |
|---|---|---|---|
| X-001 | ... | ... | KEEP_VAULT / KEEP_CODE / DEFER / SPLIT |

## Open Questions (N)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | ... | <vault file:line> | N/A (fresh OQ) |

## Auto-Resolved Deferred OQs (N)
| OQ-ID | Question | Evidence (codebase-map) | Status |
|---|---|---|---|
...
```

5. **Decision gate:**
   - If `conflict == 0` AND (`oq == 0` OR `--strict` not set):
     - **Produce `<vault>-bound/`** — copy vault dir; inject inline binding annotations (HTML comments per binding-contract.md)
     - **Announce:** "Binding clean. Bound-vault written to `<vault>-bound/` (sibling of vault directory). Next: `/mega-sdd:generate-units <vault>-bound/`."
   - If `conflict > 0` OR (`--strict` AND `oq > 0`):
     - **DO NOT** write the <vault>-bound/ sibling directory
     - **Announce blocker:** "Binding BLOCKED. <N> conflicts must be resolved. Run `/mega-sdd:resolve-oq --binding <binding.md>` or edit vault manually, then re-run bind-codebase."
     - Emit blocker YAML per `vault-contract.md` §halt-protocol

**Emit structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: bind_conflict
  emitted_at: <ISO8601 timestamp>
  emitted_by: bind-codebase
  details:
    vault: <vault path>
    conflict_count: N
    conflicts:
      - id: C-001
        vault_claim: <verbatim from binding.md>
        codebase_reality: <verbatim from binding.md>
        suggested_action: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT
      # ... one entry per conflict
  next_action: "Run /mega-sdd:resolve-oq --binding <binding.md>"
```

This YAML is the canonical halt artifact. Prose announcement remains for human readability; the structured form is for orchestrate-flow consumption and automation parsing.

6. **Audit log.** Append entry to `<vault>/vault.json` changelog: `{ "event": "bind", "at": "...", "summary": "N confirmed, N conflict, N oq" }`.

## Anti-hallucination rails

- Never auto-resolve CONFLICTs. Always human-in-the-loop.
- Never write bound-vault while conflicts exist. The gate is non-negotiable.
- When evidence is ambiguous, default to OQ not CONFIRMED.
- Claim text in binding.md is verbatim from vault — no paraphrasing.
- (v1.2+, Iter 1) Implementation state defaults to `UNKNOWN` with low confidence when heuristic cannot decide. Never silently mark `IMPLEMENTED` without a concrete anchor.
- (v1.2+, Iter 1) Implementation state classification annotates CONFIRMED claims; it does NOT relax the binding gate. CONFLICT still blocks.
- (v1.3+, Iter 2) Tech-OQ scan resolution ONLY fires for `classification_confidence: high`. Medium/low confidence skip auto-resolve (per DESIGN-OQ-3 gate).
- (v1.3+, Iter 2) Tech-OQ scan with no/multiple matches → flip to `blocking`, NEVER guess.
- (v1.3+, Iter 2) Tech-OQ recommendations NEVER auto-accept; surfaced for user review.
- (v1.3+, Iter 2) Recommendation `scan_citations` MUST verify against codebase-map / KB. Unverifiable citation → halt `oq_recommend_citation_invalid`.
- (v1.4+, Iter 3) Suggested Hard Rules ONLY promoted from KB `[VERIFIED]` markers (per DESIGN-OQ-6). `[INFERRED]` and `[OPEN]` KB items → Anti-patterns only.
- (v1.4+, Iter 3) Suggested Hard Rules referencing anchors NOT in codebase-map are NOT emitted (would fail `hard_rule_unanchored` at bolt time).

## Halt conditions

- Missing `codebase-map.md`: halt, instruct `scan-codebase` first
- Vault missing required files (00-index, vault.json): halt, instruct vault repair
- `claims_total == 0`: halt, vault has no code-referencing claims (likely greenfield — pipeline should skip binding)
- (v1.3+, Iter 2) Tech-OQ with `resolution_mode: recommend` missing required fields → halt `oq_recommend_underspecified`
- (v1.3+, Iter 2) Tech-OQ recommendation `scan_citations` doesn't resolve in codebase-map / KB → halt `oq_recommend_citation_invalid`

## Hand-off

- Clean binding → suggest `/mega-sdd:generate-units <vault>-bound/`
- Blocked → suggest `/mega-sdd:resolve-oq --binding <binding.md>`

## Handoff emission (v1.5+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: <ISO8601 timestamp>
  status: completed | paused | halted
  artifacts:
    - <absolute path to binding.md>
    - <absolute path to vault-bound/>   # only if no CONFLICTs
  next_action:
    suggested_skill: mega-sdd:generate-units    # status=completed
    # OR
    suggested_skill: mega-sdd:resolve-oq        # status=halted on conflict
    suggested_args: ["--auto"]
    rationale: "<1-sentence>"
  blockers: []   # populated on bind_conflict
  metrics:
    items_processed: <N claims>
    items_blocked: <N CONFLICTs>
```

Status `halted` on `bind_conflict` / `oq_recommend_underspecified` / `oq_recommend_citation_invalid` (Iter 2 halts). Status `paused` when tech-OQ recommendations need user review (informational; downstream still runs). Required ONLY under `--auto`.

## Memory layer (v1.6+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After binding completes | `<vault>/.memory/bind-history.md` | Append run summary: claims_total, confirmed, conflict, oq counts + Implementation State Map summary (IMPLEMENTED / NEW / UNKNOWN distribution) + Tech-OQ resolution counts |
| When new convention detected via codebase-map consultation | `<project>/.mega-sdd-memory/conventions.md` | Append (additive; no overwrite) |

### Reads

| What | Source | How used |
|---|---|---|
| Past CONFLICT resolutions matching current conflict claim pattern | `<project>/.mega-sdd-memory/decisions.md` | When CONFLICT detected, SUGGEST same resolution as past pattern (via blocker YAML `next_action.suggested_resolution` field). User still picks via resolve-oq. |
| Cross-project CONFLICT patterns | `~/.mega-sdd/memory/patterns.md` | When project memory has no match AND user-scope has ≥3 cross-project matches, SUGGEST that resolution |
| Past Hard Rule violation patterns | `<vault>/.memory/bolt-outcomes.json` (passed via handoff `metadata.memory_context.vault_outcomes_relevant`) | When emitting Suggested Unit Hard Rules (Iter 3 §2.8), DOWNGRADE rules that have been violated+reverted ≥3 times to Anti-patterns (per learning-rules.md §2.3) |

### Anti-halu rails

- Memory suggestions surface in `binding.md` "## Past Resolution Suggestions" section AND in halt blocker YAML
- Every suggestion cites source memory entry
- CONFLICT verdict NEVER bypassed by memory; memory only suggests resolution direction
- `--memory-off` disables both reads and writes
- Suggestions never override current codebase-map evidence

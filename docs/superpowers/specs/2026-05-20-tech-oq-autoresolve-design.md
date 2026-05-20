# Tech-OQ Auto-Resolve + Implementation-State + Polished Unit Prompts

**Status**: Approved 2026-05-20 (Iter 1 in execution; Iter 2/3 designed, awaiting separate kick-off)
**Date**: 2026-05-20
**Author**: Farhan Riuzaki (via Claude collaboration)
**Builds on**: `2026-05-20-extract-intelligence-skill-design.md` (KB-as-context)
**Targets**: bind-codebase, generate-units, generate-intent, execute-bolts
**Plugin versions affected**: 1.4.0 → 1.5.0 (iter 1) → 1.6.0 (iter 2) → 1.7.0 (iter 3)

## DESIGN-OQ resolutions (locked at approval)

- **DESIGN-OQ-1**: Iter 1 uses binary states only (IMPLEMENTED / NEW). PARTIAL deferred to Iter 2 where recommend mode handles ambiguity. When scan inconclusive → state UNKNOWN → unit defaults to `create` (conservative).
- **DESIGN-OQ-2**: Dedup promotion (step 12.5) halts with `dedup_ambiguous` blocker when Migration notes can't be inferred. Never silent rewrite.
- **DESIGN-OQ-3**: Iter 2 introduces `classification_confidence: high | medium | low`. Only `high` auto-resolves; medium/low go to `00-index.md` "## Auto-Classification Review" section.
- **DESIGN-OQ-4**: Hard rule grammar (Iter 3) closed v1 — 5 rule types only. Revisit extensibility in v2 if real-world need emerges.
- **DESIGN-OQ-5**: No `--skip-preflight` flag. Pre-flight is the contract; optimize parser if too slow.
- **DESIGN-OQ-6**: KB gotchas → Anti-patterns by default. Promoted to Hard rules only when KB marker is `[VERIFIED]` AND gotcha is mechanically detectable.

---

## 1. Problem Statement (validated from user pain)

Three pain points surfaced in a real brownfield rebuild project. They compound — each one makes the others worse:

### 1.1 Unit generation ignores existing implementations

Symptom: `bind-codebase` confirms `POST /api/users` exists in `codebase-map.md`. `generate-units` still emits `U-007: Build user CRUD endpoint`. Bolt runs, creates a duplicate handler, breaks existing tests.

Root cause: binding verdict (CONFIRMED / CONFLICT / OQ) measures **claim existence**, not **implementation readiness**. There is no signal "this claim is already fully implemented — skip the build, just verify."

### 1.2 OQ list is buried in technical noise

Symptom: vault generation produces 230 OQs. ~180 of them are technical (what test framework, what naming convention, what file location, what HTTP error format). Stakeholder review meeting drowns; team gives up triaging; tech OQs get answered with "use the existing pattern" anyway — i.e., they were deterministically answerable from codebase scan all along.

Root cause: OQ is a single category. Business and technical ambiguities are treated equally. Tech OQs that could be answered by scanning the codebase (or by AI recommendation) clog the human review channel.

### 1.3 Unit body reads like a Jira ticket, not an AI coding prompt

Symptom: user writes manual prompts to AI coding agents (Cursor, Copilot, Cline) when a unit is unclear. The prompt has:
- Anchors ("look at AuthController:45 for the pattern")
- Anti-patterns ("don't bypass the auth middleware")
- Migration notes ("remove old session handler, keep RBAC")
- Directive prose

The current unit schema has `Goal / Context / Implementation steps / Acceptance / Out of scope` — schema-shaped, not prompt-shaped. AI coding agent treats it as bullet points to mechanically tick off, missing the surrounding context that makes the work coherent.

### 1.4 User-stated design direction

> "step nya mirip punya superpower: read > scan > writing plan > execute plan sub agent"
> "OQ hanya terkait business. klo terkait teknis lo bisa suggesting/recomendation atau hard rulesnya ketika bolts jalan akan scaning"

User wants:
- **Business OQ** → stays blocking (stakeholder input)
- **Tech OQ** → auto-resolve via three modes: `scan`, `recommend`, `hard_rule`
- Pipeline shape mirror superpowers: `read → scan → writing-plans → executing-plans (subagent-driven)`

---

## 2. Critical Assessment (per request)

### 2.1 Where the diagnosis is right

- ✅ Implementation-state classification is missing and IS the root of pain 1.1.
- ✅ OQ noise is real and the business/tech split is a clean classifier axis.
- ✅ Tech ambiguities ARE deterministic given codebase context — they should not block humans.
- ✅ Unit schema IS too jira-y; prompt-shape is genuinely better for AI coding consumption.
- ✅ Mega-sdd pipeline already roughly maps to superpowers' `read → scan → plan → exec` — the mapping is sound, but the unit body (`writing-plans` equivalent) is the weakest link.

### 2.2 Where to be careful

- ⚠️ **Anti-halu rails risk**: `recommend` mode introduces AI-generated answers that could fabricate. Mitigation: every recommendation MUST cite scan output OR a labeled fallback ("no scan match; defaulting to convention X with rationale Y"). Recommendations are reviewable in `binding.md`, never silent.
- ⚠️ **Hard-rule validation cost**: `execute-bolts` running pre-flight scans for every unit adds latency. Mitigation: hard rules are opt-in per unit, not blanket.
- ⚠️ **OQ-category misclassification at generation time**: if `generate-intent` mis-tags a business question as tech, it auto-resolves to a wrong answer. Mitigation: default to `business` (safe), require explicit signals to demote to `tech`, AND surface category in a review section before resolution kicks in.
- ⚠️ **Backward compatibility**: existing vaults must keep working. Every new field has a safe default. Existing OQs without `category` → treated as `business`.

### 2.3 What this is NOT

- NOT a pipeline restructure. Mega-sdd's 5-phase shape stays.
- NOT a new skill (the work fits inside `bind-codebase`, `generate-units`, `execute-bolts`, with light extensions to `generate-intent`).
- NOT a weakening of the binding gate. Binding still BLOCKS on `conflict > 0`. Auto-resolve only happens for OQs explicitly tagged `category: tech`.

---

## 3. Unified Mental Model

### 3.1 OQ becomes a first-class object with category + resolution mode

```yaml
- id: OQ-AR-7
  category: business | tech                # NEW: who decides
  resolution_mode: blocking | scan | recommend | hard_rule   # NEW: how it's answered
  priority: P1 | P2 | P3                   # existing
  status: pending | resolved | deferred | out-of-scope   # existing (v1.1+)
  # Mode-specific fields (only populated for the mode in use):
  scan_query: <codebase-map section + grep pattern>      # mode=scan
  recommendation: <Claude's pick>                         # mode=recommend
  rationale: <why this pick>                              # mode=recommend
  scan_citations: [<file:line>, ...]                     # mode=recommend OR scan
  hard_rule: <constraint string validated at bolt time>  # mode=hard_rule
  resolved_at: <ISO8601>                                  # status=resolved
  resolution: <answer text>                               # status=resolved
```

### 3.2 Default behavior preserves anti-halu

- New OQ without `category` → defaults to `business`
- New OQ without `resolution_mode` → defaults to `blocking`
- Existing vaults (v1.0–v1.4 OQs) → all default-mapped to business + blocking on load. Zero behavior change unless user opts in.

### 3.3 Pipeline mapping to superpowers shape

| Superpowers | Mega-SDD | What changes (across iters) |
|---|---|---|
| `read` | `generate-intent` (reads PRD/KB/brief) | Iter 2: tags OQs with category at generation time |
| `scan` | `scan-codebase` + `bind-codebase` | Iter 1: bind-codebase gets implementation-state map; Iter 2: bind-codebase resolves tech OQs via scan; Iter 3: bind-codebase emits hard-rule scan plan for bolts |
| `writing-plans` | `generate-units` | Iter 1: units carry `task_type`; Iter 3: unit body becomes prompt-shape (Anchors + Anti-patterns + Migration notes) |
| `executing-plans` + `subagent-driven-development` | `execute-bolts` | Iter 3: pre-flight hard-rule scan before each bolt; halt on rule violation |

The mapping is preserved. Each iteration sharpens one stage to match its superpowers equivalent.

### 3.4 Implementation-state as the FIRST tech-OQ auto-resolver

The implementation-state question ("is `POST /api/users` already implemented?") is the canonical tech OQ:
- It is deterministic from codebase-map.
- It does not need human input.
- It directly drives unit generation behavior (skip / verify / extend / create).

Iter 1 implements this as a specialized binding feature. Iter 2 generalizes it as one resolution mode (`scan`) among others.

---

## 4. Iteration 1 — Implementation-State Classification + Task-Type Units

**Plugin**: 1.4.0 → 1.5.0
**Skills bumped**: `bind-codebase` 1.1.0 → 1.2.0, `generate-units` 1.1.0 → 1.2.0
**Skills lightly touched**: `generate-intent` 1.2.0 → 1.3.0 (just OQ category tagging defaults)

### 4.1 Goal

Eliminate the "unit recreates existing function" pain. Make every brownfield unit aware of whether the target code already exists.

### 4.2 Schema change: binding-contract.md

Add a new section after `## Verdicts`:

```markdown
## Implementation-State Classification (v1.2+)

For each CONFIRMED claim, additionally classify implementation readiness:

| State | Definition | Codebase signal |
|---|---|---|
| `IMPLEMENTED` | Entity AND its handler/method/function exist AND signature matches claim | route + handler symbol + (if entity claim) all claimed fields detected |
| `PARTIAL` | Entity exists but handler missing OR endpoint route exists but handler symbol absent OR file exists but signature mismatch on claimed params | one half found, the other missing |
| `NEW` | No matching evidence | not in any codebase-map section |
| `UNKNOWN` | Codebase-map silent on this claim type (e.g., dynamic routes, magic methods) | heuristic detection limit |

Recorded per claim in `binding.md` under a new section:

```yaml
## Implementation State Map (v1.2+)
| Claim ID | Verdict | State | Anchor | Confidence |
|---|---|---|---|---|
| C-007 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high |
| C-008 | CONFIRMED | PARTIAL | User.php:12 (entity ok; validation rule missing) | high |
| C-012 | OQ | NEW | — | n/a |
| C-019 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic can't classify | low |
```
```

### 4.3 Schema change: bind-codebase/SKILL.md

In Procedure step 2, add sub-step 2.5 (between current 2 and 3):

```markdown
2.5. **Implementation-state classification (v1.2+).**

For each claim now marked CONFIRMED, determine its implementation_state per `references/binding-contract.md` §Implementation-State Classification:

a. **Endpoint claims** (POST /api/foo, GET /bar, …):
   - Probe codebase-map §4 (routes) — found? → at least PARTIAL
   - Probe codebase-map §2 (public interfaces) for the handler symbol — found AND not flagged as stub? → IMPLEMENTED
   - Found in §4 but handler absent in §2 OR handler is a stub (file size < 200 bytes / `throw new NotImplemented`-pattern detected in scan-codebase output) → PARTIAL
   - Both absent → NEW (downgrade verdict to OQ — no longer CONFIRMED)

b. **Entity claims** (User has email, role; Order has line_items):
   - Probe codebase-map §3 (data models) for entity name → found? → at least PARTIAL
   - Compare claimed fields with detected fields → all claimed fields present? → IMPLEMENTED; subset present? → PARTIAL
   - Not in §3 → NEW

c. **Method/handler claims** (sendEmail(), processPayment()):
   - Probe codebase-map §2 (public interfaces) for symbol → found? → IMPLEMENTED (signature match) OR PARTIAL (symbol exists, signature different)
   - Not in §2 → NEW

d. **Confidence labeling**:
   - `high` — single unambiguous match
   - `medium` — fuzzy match (case-insensitive, partial path)
   - `low` — multiple potential matches OR heuristic could not classify (mark state as UNKNOWN)

e. **Write to `binding.md` Implementation State Map** per template above.

Conservative default: when in doubt, classify as PARTIAL with low confidence. Never silently claim IMPLEMENTED without an anchor.
```

### 4.4 Schema change: unit-schema.md

Add field to frontmatter:

```yaml
task_type: create | extend | verify   # NEW (default: create)
```

Add to "## Required body sections":

```markdown
## Anchors (NEW, v1.2+)

For task_type=extend or task_type=verify: list file:line where existing implementation lives. AI coding agent reads these BEFORE writing.

- src/Http/Controllers/UserController.php:45-67 — existing handler pattern
- src/Models/User.php:12 — entity to extend

For task_type=create: section optional; may cite related pattern anchors.

## Migration notes (NEW, v1.2+; required for task_type=extend, optional otherwise)

Three sub-lists:
- **REMOVE**: <code to delete>
- **KEEP**: <code to preserve, do not touch>
- **ADD**: <new code to write>
```

### 4.5 Generation-time logic: generate-units/SKILL.md

Add procedure step 2.5 (between current 2 and 3):

```markdown
2.5. **Determine task_type per candidate unit (v1.2+).**

If bound-vault has `binding.md` with Implementation State Map:

For each candidate unit, find the binding entries it derives from (via vault claim → binding claim ID mapping). Aggregate states:

| Bound claim states | Unit task_type |
|---|---|
| All NEW or no binding (greenfield) | `create` |
| All IMPLEMENTED with high confidence | `verify` |
| Mix of PARTIAL + IMPLEMENTED, OR any UNKNOWN | `extend` |
| Mix of NEW + IMPLEMENTED | SPLIT — emit one `create` unit for NEW claims, one `verify` unit for IMPLEMENTED claims |

**`verify` unit specifics**:
- `target_files` is empty (or all entries have `operation: none`)
- `acceptance_test` carries the test that proves existing implementation still works
- Body's `## Implementation steps` is one line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
- Estimated complexity: small

**`extend` unit specifics**:
- `target_files` MUST include at least one `operation: modify` entry pointing to the anchor file
- Anchors section MUST list every binding citation
- Migration notes section MUST be filled (REMOVE / KEEP / ADD)
- Acceptance test focuses on the NEW behavior; existing behavior assertions go in `existing_interfaces`

**`create` unit specifics**:
- Current behavior unchanged
- target_files entries all `operation: create`
- Anchors section optional; if filled, cite related-pattern anchors only
```

Plus add deduplication rule at the end of procedure (step 12.5):

```markdown
12.5. **Deduplication check (v1.2+).**

After all units generated, sanity-check:

For each unit where `task_type: create` AND every target_files entry's path already exists in codebase-map §1:
- Promote to `task_type: extend` (downgrade) — the files exist; the unit MUST be additive, not from-scratch
- Re-fill Anchors section with the existing-file references
- Halt with `dedup_promotion` blocker if promotion would require Migration notes that the skill cannot infer; user resolves manually
```

### 4.6 Schema change: vault-contract.md (minimal OQ category default)

Iter 1 adds a single field to the OQ schema, default-safe:

```yaml
- id: OQ-AR-7
  category: business     # NEW field, default `business`. Iter 1 does NOT auto-resolve; tagging only.
  # ... existing fields unchanged
```

This is forward-compat scaffolding for Iter 2. In Iter 1, `category` is recorded but no auto-resolve runs unless the implementation-state classifier explicitly catches the OQ (the special case of pain 1.1).

### 4.7 Iter 1 anti-halu rails

- Binding NEVER promotes `state: NEW` to `IMPLEMENTED` based on inference — only direct codebase-map evidence.
- `state: UNKNOWN` with low confidence is surfaced in binding.md; downstream generate-units defaults to `task_type: create` (safer) with a note.
- `verify` units NEVER generate code; they only run acceptance tests.
- `extend` units MUST have Migration notes filled; missing → halt with `extend_underspecified` blocker.
- Dedup promotion (12.5) does NOT silently rewrite a `create` unit; it requires user confirmation when Migration notes can't be inferred.

### 4.8 Iter 1 backward compatibility

- Existing binding manifests without Implementation State Map → generate-units treats as greenfield path (all `task_type: create`); no auto-skip.
- Existing units without `task_type` → execute-bolts treats as `create` (current behavior).
- Existing OQs without `category` → treated as `business`; no auto-resolve.
- Iter 1 changes work even if user never runs scan-codebase (no binding map → no implementation state → all units are `create`, same as today).

### 4.9 Iter 1 test additions

- `tests/skill-triggering/bind-codebase.test.md` — add cases for IMPLEMENTED/PARTIAL/NEW/UNKNOWN classification
- `tests/skill-triggering/generate-units.test.md` — add cases for verify/extend unit emission + dedup promotion + split-on-mixed-state
- `tests/integration/e2e-impl-state.test.md` (new) — full pipeline on a fixture where `User CRUD` already exists; expect `verify` unit for read+list, `extend` for adding pagination, `create` for new audit-log endpoint

---

## 5. Iteration 2 — OQ Classification + Recommend Mode

**Plugin**: 1.5.0 → 1.6.0
**Skills bumped**: `generate-intent` 1.3.0 → 1.4.0, `bind-codebase` 1.2.0 → 1.3.0

### 5.1 Goal

Eliminate tech-OQ noise from human review channel. Tech OQs auto-resolve via `scan` (deterministic codebase probe) OR `recommend` (AI pick with rationale). Business OQs untouched — still blocking.

### 5.2 Schema change: vault-contract.md OQ schema

Extend §OQ-conventions:

```markdown
### Category (v1.4+)

Every OQ MUST carry `category`:

- `business` — needs stakeholder judgment. Examples: feature scope, edge-case behavior, regulatory threshold, UI copy, pricing logic.
- `tech` — answerable from codebase or convention. Examples: test framework, error code format, naming convention, library version, file location.

Default: `business`. To downgrade to `tech`, the OQ MUST have a `resolution_mode` set.

### Resolution mode (v1.4+, required when category=tech)

- `scan` — answer found by probing codebase-map / KB. Must specify `scan_query`.
- `recommend` — AI picks with rationale. Must populate `recommendation` + `rationale` + `scan_citations` (citing related patterns).
- `hard_rule` — encoded as bolt-time constraint. Must populate `hard_rule`. (Iter 3.)
- `blocking` — explicit "no auto-resolve; still needs human" (rare for tech; used when scan is inconclusive AND no safe default exists).

A tech OQ MUST specify resolution_mode; absence is a generate-intent validation error.

### Auto-classifier heuristics for generate-intent (v1.4+)

`generate-intent` tags new OQs with category + resolution_mode using these heuristics:

| Pattern in OQ text | Likely category | Default resolution_mode |
|---|---|---|
| "what test framework" / "which testing library" | tech | scan |
| "naming convention for X" / "case style for Y" | tech | scan |
| "file location for Z" / "where should X live" | tech | scan |
| "what error code format" / "what response shape" | tech | recommend |
| "which library for X" / "which version of Y" | tech | recommend |
| "should we support X feature" / "does Y count as in-scope" | business | blocking |
| "what is the limit for X" / "how many Y" | business | blocking |
| "is X regulated" / "POJK reference for Y" | business | blocking |
| "edge case: when Z happens" | business | blocking |
| anything mentioning "stakeholder", "PO", "compliance team" | business | blocking |
| anything mentioning "scan codebase", "check existing", "convention" | tech | scan |

When heuristic is ambiguous: default to `business / blocking` (safe). Surface in `00-index.md` "## Auto-Classification Review" section: list every tech-tagged OQ for one-pass user review before binding runs.
```

### 5.3 Schema change: bind-codebase scan resolution

Add procedure step 2.6:

```markdown
2.6. **Tech-OQ auto-resolution via scan (v1.3+).**

For each OQ in the vault with `category: tech` AND `resolution_mode: scan`:

a. Read the OQ's `scan_query` (path + grep pattern OR codebase-map section reference).
b. Execute the scan against codebase-map (and KB if present).
c. Apply outcome:
   - Single unambiguous match → set OQ `status: resolved`, `resolution: <found value>`, `resolved_at: <now>`, `scan_citations: [<found at>]`
   - No match → keep OQ pending; flip `resolution_mode` to `blocking` with note "scan returned no match"
   - Multiple matches → keep OQ pending; flip to `blocking` with note "scan ambiguous — N matches" + list

d. Append to `binding.md` "## Tech-OQ Auto-Resolved (Scan)" section:
   ```
   | OQ-ID | Category | Question | Scan target | Resolution | Citations |
   |---|---|---|---|---|---|
   ```

### 2.7 Tech-OQ recommendation surfacing (v1.3+).

For each OQ with `category: tech` AND `resolution_mode: recommend`:

a. Verify required fields: `recommendation`, `rationale`, `scan_citations` (≥1 citation REQUIRED — even if "no exact match in codebase, defaulting to <convention X>; closest pattern at <citation>").
b. Surface in `binding.md` "## Tech-OQ Recommendations (review required)" section — NOT auto-resolved; flagged for one-pass user review.
c. User has 3 actions per recommendation: ACCEPT (flips to resolved), OVERRIDE (provides own answer; flips to resolved), or REJECT (flips to blocking — needs different resolution).
```

### 5.4 Recommend mode rationale enforcement

Every `recommendation` MUST:
- Cite at least one `scan_citation` (proves the AI saw evidence, not free-form invention)
- Include a `rationale` paragraph naming the trade-off considered
- Include a `fallback_if_wrong` clause: what to revisit if this pick turns out incorrect

This is the anti-halu rail for AI judgment.

### 5.5 Iter 2 backward compatibility

- Vaults without category-tagged OQs → bind-codebase skips tech-OQ resolution entirely; current behavior.
- Existing tech questions can be retro-tagged via `resolve-oq --classify` (new flag) — but this is opt-in.
- Default for new OQs without category → still `business / blocking`. User must explicitly enable auto-classifier.

### 5.6 Iter 2 test additions

- Trigger test for generate-intent's auto-classifier on representative OQ phrasings
- Binding test: scan-mode OQ with single match → resolved; with no match → stays blocking
- Binding test: recommend-mode OQ surfaced in review section; user ACCEPT path tested

---

## 6. Iteration 3 — Hard Rules + Bolt-Time Validation + Polished Unit Prompts

**Plugin**: 1.6.0 → 1.7.0
**Skills bumped**: `execute-bolts` 1.1.0 → 1.2.0, `generate-units` 1.2.0 → 1.3.0, `bind-codebase` 1.3.0 → 1.4.0

### 6.1 Goal

Bring units to "polished AI coding prompt" shape (pain 1.3). Introduce hard-rule constraints that bolts validate at execution time (the last of the three tech-OQ resolution modes).

### 6.2 Unit body restructure (the prompt-shape)

`unit-schema.md` body sections become (target_files + acceptance_test unchanged):

```markdown
## Goal (1-2 sentences)
<unchanged>

## Context (read first)
<which vault sections + which binding entries + KB sections (if KB present) + WHY this scope exists. Conversational prose, not bullets.>

## Anchors (mandatory for task_type=extend|verify; optional for create)
<file:line where existing code lives. AI agent reads these BEFORE writing.>

## Hard rules (NEW v1.3+ — validated at bolt time)
<each rule = one line, machine-parseable. Examples:>
- DO NOT modify src/Models/User.php
- DO NOT add new package.json dependencies
- file:src/api/*.ts MUST follow kebab-case naming
- function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>

## Anti-patterns (NEW v1.3+ — guidance, not validated)
<conversational don'ts. Drawn from binding CONFLICTS + KB gotchas + tech-OQ recommendations.>

## Implementation steps (directive prose; NOT a bullet checklist)
<written like a teammate would brief another teammate. "First, open the AuthController and look at how it handles the existing email/password flow. Then add a new method `signInWithGoogle()` that mirrors that structure but uses Laravel Socialite. The trickier part is the role assignment — see the Anchor at routes/auth.php:34 for how roles are attached after the existing flow.">

## Migration notes (mandatory for task_type=extend; optional otherwise)
- REMOVE: <list of code to delete>
- KEEP: <list of code to preserve>
- ADD: <list of new code>

## Acceptance criteria (unchanged)

## Out of scope (unchanged)
```

### 6.3 Hard-rule grammar (v1.3+)

Hard rules are parsed at bolt time. Supported grammar (v1.3 — extendable):

```
RULE := DO_NOT_MODIFY | DO_NOT_ADD_DEPS | NAMING_RULE | SIGNATURE_RULE | FILE_PRESENCE_RULE

DO_NOT_MODIFY := "DO NOT modify " <path>
DO_NOT_ADD_DEPS := "DO NOT add new " <manifest> " dependencies"
NAMING_RULE := <path-glob> " MUST follow " <case-style> " naming"
SIGNATURE_RULE := "function " <name> " MUST preserve signature: " <type-sig>
FILE_PRESENCE_RULE := "file " <path> " MUST exist after bolt"
```

`execute-bolts` parses each rule into a check function. Unsupported grammar → halt with `hard_rule_unparseable` blocker; user resolves.

### 6.4 execute-bolts pre-flight scan

New procedure step in execute-bolts (before existing bolt execution):

```markdown
0.5. **Pre-flight hard-rule scan (v1.2+).**

Before invoking superpowers to execute the unit:

a. Read all `## Hard rules` entries from the unit body.
b. For each rule, run its scan against the current codebase state:
   - DO_NOT_MODIFY → record file checksum (compare after bolt completes)
   - DO_NOT_ADD_DEPS → record current manifest content (compare after bolt completes)
   - NAMING_RULE → no pre-check (validated on new files only, after bolt)
   - SIGNATURE_RULE → record current signature (compare after bolt completes)
   - FILE_PRESENCE_RULE → no pre-check (validated after bolt)
c. Persist pre-flight snapshot for post-flight comparison.

After bolt completes (in superpowers) — pre-commit hook:

d. Re-run each rule's check against new codebase state.
e. Any violation → halt with `hard_rule_violated` blocker; bolt commit is aborted; user reviews.

Halt YAML:

```yaml
blocker:
  type: hard_rule_violated
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-007
    violated_rule: "DO NOT modify src/Models/User.php"
    evidence: "src/Models/User.php changed; checksum diverged"
  next_action: "Revert the offending change or modify the unit's hard rules + re-run."
```
```

### 6.5 Bind-codebase emits hard rules from KB + binding (v1.4+)

When KB is present AND binding finds CONFLICT or PARTIAL:
- Bind-codebase suggests hard rules for the unit (added to binding.md → generate-units picks up)
- Examples:
  - PARTIAL state on User entity (validation missing) → suggested rule: `file:src/Models/User.php MUST exist after bolt`
  - KB documents typo bug (`cfkdhl → CFKDDL`) → suggested rule: `DO NOT replicate code pattern at <legacy-file:line>` (informational; not auto-validated, but surfaced in Anti-patterns)
  - Binding CONFLICT auto-resolved to KEEP_CODE → suggested rule: `DO NOT modify <conflicting-file>`

These appear in binding.md "## Suggested Unit Hard Rules" section. Generate-units pulls them into the relevant unit's `## Hard rules`.

### 6.6 Polished-prompt rendering pass (generate-units v1.3+)

After all units written, run a final pass:

1. For each unit, verify body sections are written as directive prose (not bullet schema) — heuristic: every `## Implementation steps` section MUST have at least one sentence >15 words. Bullet-only sections trigger a warning.
2. Verify `## Anchors` exists for every `task_type ∈ {extend, verify}` unit.
3. Verify `## Migration notes` filled for every `task_type=extend` unit.
4. Verify `## Hard rules` is parseable grammar.

Failures → halt with `unit_underspecified` blocker; user can either auto-fix (re-render via skill) or edit manually.

### 6.7 Iter 3 backward compatibility

- Units without `## Hard rules` section → execute-bolts skips pre-flight (current behavior).
- Units without `## Anchors` / `## Migration notes` → execute-bolts treats as legacy schema; warning only.
- Unparseable hard rules → halt (better to surface than silently skip).

### 6.8 Iter 3 test additions

- Trigger test for hard-rule violation (modify a file the rule forbids) → execute-bolts halts pre-commit
- Trigger test for prompt-shape validation (unit with bullet-only body) → generate-units warns
- Integration test: KB-suggested hard rules flow through bind-codebase → generate-units → execute-bolts → halt on violation

---

## 7. Pipeline Shape Comparison (post all 3 iters)

```
Superpowers shape:    read           → scan                       → writing-plans            → executing-plans (subagent-driven)
                       |                |                              |                            |
Mega-SDD mapping:     generate-intent → scan-codebase + bind-codebase → generate-units            → execute-bolts
                       |                |                              |                            |
What it does:         Read PRD/KB/      Heuristic codebase map +      Plan per unit, in           Pre-flight scan;
                      brief; classify   per-claim binding;            polished prompt shape       execute via superpowers
                      OQs by category   implementation-state map;     (Anchors + Anti-patterns +  subagent; post-flight
                      + resolution_mode tech-OQ auto-resolve          Migration notes + Hard rules) hard-rule validation;
                                        (scan/recommend);                                          halt on violation
                                        suggested hard rules
```

Iter 1 strengthens `scan` (implementation state) + `writing-plans` (task_type).
Iter 2 strengthens `read` (OQ classification) + `scan` (auto-resolve modes).
Iter 3 strengthens `writing-plans` (prompt shape) + `executing-plans` (hard-rule enforcement).

After all three: mega-sdd's behavior matches the superpowers mental model the user articulated.

---

## 8. Cross-cutting Anti-Halu Invariants (preserved across all iters)

1. Binding NEVER auto-resolves CONFLICTs. Always human-in-the-loop.
2. Recommendation mode requires citation; no free-form AI answers.
3. Default OQ category is `business / blocking`. Tech demotion requires explicit signal.
4. Hard rules are parseable grammar; unparseable → halt, not silently skip.
5. `verify` units NEVER generate code; only run acceptance tests.
6. `extend` units require Migration notes; missing → halt.
7. KB consultation (from Iter 0 / spec 2026-05-20-extract-intelligence) never overrides codebase-map CONFLICT.
8. Pre-flight hard-rule scan is auditable; pre/post snapshots persisted in bolt-report.md.

---

## 9. Backward Compatibility Summary

| Existing artifact | Iter 1 behavior | Iter 2 behavior | Iter 3 behavior |
|---|---|---|---|
| v1.4 vault without category-tagged OQs | All OQs treated as `business/blocking` | Same | Same |
| v1.4 binding.md without Impl State Map | generate-units treats as greenfield (all `create`) | Same | Same |
| v1.4 unit without task_type | Treated as `create` | Same | Treated as `create`; new sections optional |
| v1.4 unit without Hard rules | execute-bolts skips pre-flight | Same | execute-bolts skips pre-flight |
| Existing pipelines invoking `/mega-sdd:*` | Identical output if no opt-in flags | Same | Same |

The KB integration (from `2026-05-20-extract-intelligence-skill-design.md`) layers cleanly on top of this design — KB markers `[VERIFIED]/[INFERRED]/[OPEN]` map onto IMPLEMENTED/PARTIAL/NEW respectively when consulted by bind-codebase.

---

## 10. Open Questions in This Design

These are MY (the designer's) open questions that need user input before Iter 1 execution. Marked with [DESIGN-OQ].

- [DESIGN-OQ-1] **Codebase-map richness**: Iter 1's PARTIAL detection ("endpoint exists but handler stub") needs scan-codebase to detect stub-vs-real handlers. Current scan-codebase doesn't grade handler completeness. Options: (a) extend scan-codebase to do file-size + stub-pattern detection; (b) Iter 1 only distinguishes IMPLEMENTED vs NEW (no PARTIAL) — defer PARTIAL to Iter 2 when recommend mode handles ambiguity; (c) leave PARTIAL as UNKNOWN when scan is shallow. Recommendation: (b) — simpler Iter 1.

- [DESIGN-OQ-2] **Dedup promotion (step 12.5)**: If `create` unit targets a file that already exists, auto-promote to `extend`. But what if the existing file is unrelated to the unit's intent (different module, accidental name collision)? Recommendation: require Migration notes inference; if inference fails → halt with `dedup_ambiguous` blocker.

- [DESIGN-OQ-3] **Auto-classifier accuracy**: Iter 2 heuristics may mis-classify. Should there be a confidence threshold for auto-classification, below which the OQ stays `business`? Recommendation: yes; introduce `classification_confidence: high | medium | low` and only auto-resolve `high` confidence; medium/low go to a review section.

- [DESIGN-OQ-4] **Hard rule grammar evolution**: Iter 3 grammar is initially 5 rule types. Should it be extensible (plugin grammar) or closed (mega-sdd-defined only)? Recommendation: closed for v1; revisit in v2 if real-world use needs extension.

- [DESIGN-OQ-5] **Pre-flight scan cost**: Each unit could have many hard rules. Pre-flight scan adds latency per bolt. Should there be a `--skip-preflight` flag for dev/test runs? Recommendation: no — pre-flight is the whole point; if too slow, optimize the parser.

- [DESIGN-OQ-6] **KB suggested hard rules**: When KB is present, bind-codebase auto-suggests hard rules. But user might not want every KB gotcha to become a hard rule (some are informational). Recommendation: KB-sourced rules go to `## Anti-patterns` by default (informational), promoted to `## Hard rules` only when KB marker is `[VERIFIED]` AND the gotcha is mechanically detectable.

---

## 11. Validation Plan

### 11.1 Iter 1 validation

Fixture: brownfield project where `User CRUD` is already implemented + PRD says "add user audit log endpoint".
- Expect: U-001 = `verify` for read/list (existing); U-002 = `extend` for adding audit field to User; U-003 = `create` for new audit-log endpoint.
- Negative: unit body for U-001 has empty target_files and 1-line implementation steps.

### 11.2 Iter 2 validation

Fixture: PRD with 50 OQs of mixed business/tech phrasing.
- Expect: generate-intent auto-classifies ≥80% correctly; remaining 20% surface in `00-index.md` "## Auto-Classification Review" section.
- bind-codebase scan-resolves ≥90% of tech OQs that have answers in codebase-map.
- Recommend-mode OQs surface in binding.md review section with citations.

### 11.3 Iter 3 validation

Fixture: unit with hard rule "DO NOT modify src/Models/User.php".
- Bolt tries to modify User.php → execute-bolts halts pre-commit with `hard_rule_violated` blocker.
- Unit with bullet-only Implementation steps → generate-units warns "low directive density".

### 11.4 Full-pipeline integration test

End-to-end on the Bank Mega Trade Finance fixture (using `extract-intelligence` output as KB):
- KB → generate-intent (Mode B, --kb) produces vault with category-tagged OQs
- bind-codebase auto-resolves implementation-state + tech OQs via scan; surfaces recommendations
- generate-units emits mixed create/extend/verify units with prompt-shape bodies and KB-suggested hard rules
- execute-bolts runs first 3 units, pre-flight passes; one unit deliberately violates hard rule → halts

---

## 12. References

- `2026-05-20-extract-intelligence-skill-design.md` — KB integration prior spec
- `2026-05-13-mega-sdd-revamp-design.md` — pipeline shape
- `2026-05-13-mega-sdd-v1.1-alignment-oq-deferral-design.md` — OQ status/deferral lineage
- `plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md` — current binding contract
- `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` — current unit schema
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — current OQ-conventions
- Superpowers skills referenced for shape mapping: `read`, `writing-plans`, `executing-plans`, `subagent-driven-development`

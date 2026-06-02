# Binding Contract — vault ↔ codebase

The binding contract specifies how vault claims are validated against `codebase-map.md`, what produces a CONFLICT vs OQ vs CONFIRMED, and the blocking rules for downstream phases.

## Claim categories (validated)

| Vault section | Claim type | Map section consulted |
|---|---|---|
| 01-overview.md | mode (greenfield/existing) | repo signals (`.git`, package.json) |
| 02-architecture.md | components, file paths | top-level structure, public interfaces |
| 03-data-model.md | entities, fields | data models / schemas |
| 04-flows.md | endpoints, handlers | routes / endpoints |
| 05-decisions.md | tech stack | languages, frameworks |
| 06-constraints.md | naming conventions | naming conventions, pattern signatures |

## Verdicts

For each claim:

- **CONFIRMED**: claim has matching evidence in codebase-map (entity exists, endpoint registered, naming matches majority).
- **CONFLICT**: claim contradicts codebase-map evidence (vault says "use bearer auth", code uses sessions).
- **OQ**: claim references a code element NOT in codebase-map (e.g., "the legacy user table" — map shows no `user` table).

## Implementation-State Classification (v1.2+, Iter 1)

For each CONFIRMED claim, additionally classify implementation readiness. This signal drives `generate-units` task_type assignment (create vs verify) so units do not duplicate already-built functionality.

| State | Definition | Codebase signal |
|---|---|---|
| `IMPLEMENTED` | Entity AND its handler/method/function exist AND signature matches claim | route + handler symbol + (if entity claim) all claimed fields detected |
| `NEW` | No matching evidence (verdict downgraded from CONFIRMED to OQ when no anchor at all) | not in any codebase-map section |
| `UNKNOWN` | Codebase-map silent on this claim type (e.g., dynamic routes, magic methods) OR ambiguous match | heuristic detection limit reached |

> **Iter 1 scope (DESIGN-OQ-1 resolved binary)**: only IMPLEMENTED / NEW / UNKNOWN. The PARTIAL state (handler is a stub) is deferred to Iter 2 where `recommend` resolution mode handles the ambiguity properly.

### Classification logic per claim type

**Endpoint claims** (`POST /api/foo`, `GET /bar`, …):
- Probe codebase-map §4 (routes) — if route found AND handler symbol present in §2 → `IMPLEMENTED`
- Route found but handler symbol absent in §2 → `UNKNOWN` (Iter 2 will refine via stub detection)
- Route not found AND handler absent → `NEW` (downgrade verdict to OQ — no longer CONFIRMED)

**Entity claims** (User has email + role; Order has line_items):
- Probe codebase-map §3 (data models) for entity name → found AND all claimed fields detected → `IMPLEMENTED`
- Entity found but subset of fields detected → `UNKNOWN` (deferred PARTIAL case)
- Entity not in §3 → `NEW`

**Method/handler claims** (`sendEmail()`, `processPayment()`):
- Probe codebase-map §2 (public interfaces) for symbol → found AND signature matches → `IMPLEMENTED`
- Symbol found but signature differs → `UNKNOWN`
- Symbol not in §2 → `NEW`

### Confidence labeling

Every classification carries a confidence tag:
- `high` — single unambiguous match in codebase-map
- `medium` — fuzzy match (case-insensitive, partial path)
- `low` — multiple potential matches OR heuristic could not classify (state becomes `UNKNOWN`)

### Conservative default

When in doubt → `UNKNOWN` with low confidence. Never silently claim `IMPLEMENTED` without a concrete anchor.

### Recorded in binding.md

```yaml
## Implementation State Map (v1.2+)
| Claim ID | Verdict | State | Anchor | Confidence |
|---|---|---|---|---|
| C-007 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high |
| C-012 | OQ | NEW | — | n/a |
| C-019 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic can't classify | low |
```

## Blocking rules

| Outcome | Effect |
|---|---|
| All claims CONFIRMED | bound-vault produced; pipeline proceeds |
| ANY claim CONFLICT | bound-vault NOT produced; binding.md written with CONFLICT list; pipeline BLOCKED |
| Claims include OQ but no CONFLICT (default) | bound-vault produced; OQs propagated to unit-level grounding |
| Claims include OQ + `--strict` flag set | bound-vault NOT produced; pipeline BLOCKED until OQs resolved |

Implementation-State Classification (v1.2+) does NOT change blocking rules. It is an annotation on CONFIRMED claims consumed downstream by `generate-units`. A claim that is `IMPLEMENTED` is still CONFIRMED.

### CONFLICT entry format (classification enrichment — Iter-79 X-1)

Every CONFLICT in `binding.md` is written as a markdown detail heading plus a
`## Conflicts (N)` summary row. Each ACTIVE (unresolved) CONFLICT detail heading
MUST carry two enrichment fields so downstream review can triage by kind and
effort. A resolved conflict (marked `✅` / `RESOLVED`) is exempt.

```markdown
### CONFLICT-1 — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: app/Models/Product.php
- **conflict_class**: naming-collision      # naming-collision | signature-drift | semantic | regulatory
- **resolution_complexity**: low            # low | medium | high
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT
```

- `conflict_class` — the *kind* of disagreement:
  - `naming-collision` — same identifier, different entity (class/table name clash).
  - `signature-drift` — same entity, divergent fields/params (field-level set-diff conflict).
  - `semantic` — same shape, different meaning/behavior (enum cases, business rule).
  - `regulatory` — the conflict touches a `[LOCKED]` / compliance constraint.
- `resolution_complexity` — `low` (rename/remove), `medium` (migration + code edit), `high` (data backfill / cross-module / regulatory sign-off).

This enrichment is **advisory** — `validate-conflict-classification.sh` (PostToolUse on binding write) WARNs when an active CONFLICT omits these fields; it does NOT change the CONFLICT-blocking contract (which still blocks on `conflict > 0`, per the table above).

## Tech-OQ Auto-Resolution (v1.3+, Iter 2)

For each OQ in the vault tagged `category: tech` AND `classification_confidence: high`, bind-codebase performs one of two operations based on `resolution_mode`:

### Scan mode (`resolution_mode: scan`)

- Reads `scan_query` from the OQ entry
- Executes scan against codebase-map (and KB if present)
- Apply outcome (per `bind-codebase` Procedure §2.6):
  - **Single unambiguous match** → flip OQ to `status: resolved`; populate `resolution`, `resolved_at`, `scan_citations`
  - **No match** → flip `resolution_mode` to `blocking`; OQ stays `pending` (no silent guess)
  - **Multiple matches** → flip `resolution_mode` to `blocking`; list candidates
- Recorded in `binding.md` "## Tech-OQ Auto-Resolved (Scan)" table

### Recommend mode (`resolution_mode: recommend`)

- Validates required fields: `recommendation`, `rationale`, `scan_citations` (≥1), `fallback_if_wrong`
- Validates that `scan_citations` resolve to entries in codebase-map / KB
- Surfaced in `binding.md` "## Tech-OQ Recommendations (review required)" section with full structure (recommendation + rationale + citations + fallback + ACCEPT/OVERRIDE/REJECT user actions)
- Does NOT block the pipeline — user reviews one-pass after binding completes

### Confidence gate (per DESIGN-OQ-3)

ONLY `classification_confidence: high` tech OQs are processed by `bind-codebase`'s scan/recommend logic. `medium` and `low` confidence:
- Skip auto-resolution
- Pass through unchanged
- Already listed in `00-index.md` "## Auto-Classification Review" for manual user attention before binding runs

### Anti-halu enforcement

- Scan finds no match → flip to `blocking`, NEVER guess
- Recommendation citations unverifiable → halt with `oq_recommend_citation_invalid`
- Missing recommendation fields → halt with `oq_recommend_underspecified`
- Tech-OQ auto-resolution does NOT affect blocking rules — CONFLICT still blocks the binding gate. Tech-OQ resolution operates orthogonally to the verdict layer.

### Blocking rule update

Tech-OQ resolution adds no new BLOCKING outcomes. The binding gate continues to block on `conflict > 0` AND optionally on `oq > 0 + --strict`. Auto-resolved tech OQs reduce the `oq` count (they move to `confirmed` for accounting purposes), making `--strict` mode more practical to use in real projects.

## Resolution paths

When binding blocks:

1. User runs `/mega-sdd:resolve-oq --binding ./binding.md` — interactive walker; updates vault with resolutions
2. Re-run `/mega-sdd:bind-codebase` — if all CONFLICTs now CONFIRMED or downgraded to OQ, bound-vault produced
3. Alternative: user edits vault manually + re-runs binding

## binding.md output structure

See `bind-codebase/SKILL.md` for the file template. Required sections:
- Summary counts (claims_total, confirmed, conflict, oq)
- Confirmed list (cite vault file:line + codebase evidence)
- Conflicts table (id, vault claim, codebase reality, resolution_needed)
- OQ table (id, question, vault source)

## bound-vault structure

`bound-vault/` is a copy of the vault directory with two augmentations:
1. Each markdown file gets inline binding annotations as HTML comments: `<!-- BIND: confirmed | conflict=C-01 | oq=OQ-12 -->`
2. `bound-vault/binding.md` is added (same content as standalone binding.md).

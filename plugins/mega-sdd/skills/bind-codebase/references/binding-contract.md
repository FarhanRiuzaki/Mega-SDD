# Binding Contract — vault ↔ codebase

The binding contract specifies how vault claims are validated against `codebase-map.md`, what produces a CONFLICT vs OQ vs CONFIRMED, and the blocking rules for downstream phases.

## Contents

- Claim categories (validated)
- Verdicts
- Implementation-State Classification
- Implementation State Map (field_diff column when precision_tier: ast)
- Blocking rules
- Tech-OQ Auto-Resolution
- Claim-scoped re-bind (`--paths` — living-vault sync lane)
- Resolution paths
- binding.md output structure
- bound-vault structure

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

## Implementation-State Classification

For each CONFIRMED claim, additionally classify implementation readiness. This signal drives `generate-units` task_type assignment (create vs verify vs extend) so units do not duplicate already-built functionality.

| State | Definition | Codebase signal |
|---|---|---|
| `IMPLEMENTED` | Entity AND its handler/method/function exist AND signature/field-set matches claim exactly (V == C) | route + handler symbol + (if entity claim) all claimed fields detected |
| `PARTIAL_FIELDS_MISSING` | Entity/handler exists but code lacks some claimed fields (C ⊂ V) | field-level set diff at `precision_tier: ast` |
| `PARTIAL_FIELDS_SURPLUS` | Entity/handler exists but code has fields the claim doesn't mention (V ⊂ C) | field-level set diff at `precision_tier: ast` |
| `PARTIAL_FIELDS_BOTH` | Shared fields exist but both sides also diverge (rare; bidirectional drift) | field-level set diff at `precision_tier: ast` |
| `NEW` | No matching evidence (verdict downgraded from CONFIRMED to OQ when no anchor at all) | not in any codebase-map section |
| `UNKNOWN` | Codebase-map silent on this claim type (e.g., dynamic routes, magic methods) OR ambiguous/disjoint match OR `precision_tier: regex` (PARTIAL collapses to UNKNOWN) | heuristic detection limit reached |

The per-claim-type probe rules, the deterministic field-level diff (ADD/KEEP/REMOVE set ops), the disjoint-set check, and the worked example live in the implementation-state reference listed in `bind-codebase/SKILL.md` §Specialist references.

### Confidence labeling

Every classification carries a confidence tag:
- `high` — single unambiguous match in codebase-map
- `medium` — fuzzy match (case-insensitive, partial path)
- `low` — multiple potential matches OR heuristic could not classify (state becomes `UNKNOWN`)

### Conservative default

When in doubt → `UNKNOWN` with low confidence. Never silently claim `IMPLEMENTED` without a concrete anchor.

### Recorded in binding.md

```yaml
## Implementation State Map (field_diff column when precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-007 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high | (exact match) |
| C-012 | OQ | NEW | — | n/a | n/a |
| C-019 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic can't classify | low | n/a |
| C-031 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high | ADD: [nama] · KEEP: [nip, password] · REMOVE: [] |
```

## Blocking rules

| Outcome | Effect |
|---|---|
| All claims CONFIRMED | bound-vault produced; pipeline proceeds |
| ANY claim CONFLICT | bound-vault NOT produced; binding.md written with CONFLICT list; pipeline BLOCKED |
| Claims include OQ but no CONFLICT (default) | bound-vault produced; OQs propagated to unit-level grounding |
| Claims include OQ + `--strict` flag set | bound-vault NOT produced; pipeline BLOCKED until OQs resolved |

Implementation-State Classification does NOT change blocking rules. It is an annotation on CONFIRMED claims consumed downstream by `generate-units`. A claim that is `IMPLEMENTED` (or any `PARTIAL_FIELDS_*` state) is still CONFIRMED.

### CONFLICT entry format (classification enrichment)

Every CONFLICT in `binding.md` is written as a markdown detail heading plus a
`## Conflicts (N)` summary row. Each ACTIVE (unresolved) CONFLICT detail heading
MUST carry two enrichment fields so downstream review can triage by kind and
effort. A resolved conflict (marked `✅` / `RESOLVED`) is exempt.

```markdown
### CONFLICT-1 — `App\Models\Product` name collision
- **Vault doc**: 03-data-model.md §Product
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

## Tech-OQ Auto-Resolution

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

### Confidence gate

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

## Claim-scoped re-bind (`--paths` — living-vault sync lane)

Invoked by `orchestrate-flow --sync` (spec `2026-06-10-living-vault-continuous-sync-design.md` S4). Full re-bind stays the default; `--paths` is the incremental optimization. The CONFLICT-blocking contract is IDENTICAL in both modes.

**Affected-claim selection (anchor reverse-index):**
1. Load the PREVIOUS `binding.md`; build the reverse index: for each claim, the set of files appearing in its evidence/anchor citations (Confirmed list + Implementation State Map `Anchor` column) plus its `vault file:line` source.
2. `affected_claims` = claims whose anchor files intersect the changed-paths set, PLUS claims whose vault source section changed (vault edited), PLUS **every ACTIVE CONFLICT from the previous binding regardless of path intersection** (a suspected hole in the moat is never carried on trust).
3. Claims in the codebase-map whose rows were re-extracted by `scan-codebase --changed-only` but that match no prior claim → candidate NEW evidence; run normal Step 2 verdict logic for any vault claim still OQ/NEW.

**Verdict assembly:**
- `affected_claims` → full Step 2 (+2.5–2.12) verdict logic, fresh citations.
- All other claims → carried forward VERBATIM with `provenance: carried_forward` + the prior bind timestamp on the row. A carried-forward verdict is never silently upgraded or downgraded.
- Counts (`claims_total`/`confirmed`/`conflict`/`oq`) are recomputed over the FULL set (fresh + carried). `binding.md` is rewritten whole — including the canonical `### CONFLICT-N` headings for EVERY active conflict (fresh or re-validated) — so the Step 5 gate, `validate-handoff-binding-units.sh`, and `.validation-blockers.json` see exactly the same surface as a full re-bind.

**Fallback to full re-bind (one-line note, no halt):** previous `binding.md` absent/unparseable; the vault itself was regenerated (version bump since last bind); changed paths exceed 40% of anchored files; or any carried-forward claim's anchor file no longer exists (provenance can't be trusted → full re-run).

**Anti-halu rails:** carried-forward rows keep their original citations untouched (no re-stamping); the phase-advisor pass (Step 2.12) runs over the FRESH verdicts at minimum and may sample carried ones; bound-vault production rules are unchanged (no `bound/` while any conflict — fresh OR carried — is active).

## Resolution paths

When binding blocks:

1. User runs `/mega-sdd:resolve-oq --binding ./binding.md` — interactive walker; updates vault with resolutions
2. Re-run `/mega-sdd:bind-codebase` — if all CONFLICTs now CONFIRMED or downgraded to OQ, bound-vault produced
3. Alternative: user edits vault manually + re-runs binding

## binding.md output structure

The full file template is the binding-md-template reference listed in `bind-codebase/SKILL.md` §Specialist references. Required sections:
- Summary counts (claims_total, confirmed, conflict, oq)
- Confirmed list (cite vault file:line + codebase evidence)
- Conflicts table (id, vault claim, codebase reality, resolution_needed)
- OQ table (id, question, vault source)

## bound-vault structure

`<vault>/bound/` (nested in the vault dir, beside `units/` and `bolts/`) is a copy of the vault's 7 markdown files with two augmentations:
1. Each markdown file gets inline binding annotations as HTML comments: `<!-- BIND: confirmed | conflict=C-01 | oq=OQ-12 -->`
2. `<vault>/bound/binding.md` mirrors the vault-root `<vault>/binding.md` (same content).

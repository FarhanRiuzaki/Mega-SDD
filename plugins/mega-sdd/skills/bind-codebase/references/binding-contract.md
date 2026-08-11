# Binding Contract — vault ↔ codebase

The binding contract specifies how vault claims are validated against `codebase-map.md`, what produces a CONFLICT vs OQ vs CONFIRMED, and the blocking rules for downstream phases.

## Contents

- Claim categories (validated)
- Verdicts
- Implementation-State Classification
- Implementation State Map (6 columns always; Field diff cell = n/a unless precision_tier: ast)
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
| `NEW` | No matching evidence (verdict downgraded from CONFIRMED to OQ when no anchor at all) — UNLESS the claim's map section is listed in the map frontmatter's `truncated_sections` (a 200-per-category extraction cap fired there; absence is NOT evidence) → `UNKNOWN` instead, and never a `create`-type task | not in any codebase-map section |
| `UNKNOWN` | Codebase-map silent on this claim type (e.g., dynamic routes, magic methods) OR ambiguous/disjoint match OR the claim's section is in `truncated_sections` OR `precision_tier: regex` (PARTIAL collapses to UNKNOWN) | heuristic detection limit reached |

The per-claim-type probe rules, the deterministic field-level diff (ADD/KEEP/REMOVE set ops), the disjoint-set check, and the worked example live in the implementation-state reference listed in `bind-codebase/SKILL.md` §Specialist references.

**`--express` provenance variant:** in the express lane there is no map and no `precision_tier` — the ast-tier precondition on the `PARTIAL_FIELDS_*` rows is replaced by **read-evidence**: a field diff is permitted ONLY when the entity's source file was actually Read this run (the ledger supplies the vault field set, the Read supplies the code field set); file unreachable → `UNKNOWN`/low, Field diff `n/a`. Full rules: `express-bind.md §Verdict + state semantics`.

### Confidence labeling

Every classification carries a confidence tag:
- `high` — single unambiguous match in codebase-map
- `medium` — fuzzy match (case-insensitive, partial path)
- `low` — multiple potential matches OR heuristic could not classify (state becomes `UNKNOWN`)

### Conservative default

When in doubt → `UNKNOWN` with low confidence. Never silently claim `IMPLEMENTED` without a concrete anchor.

### Recorded in binding.md

```yaml
## Implementation State Map (N — ALWAYS 6 columns; the Field diff cell is `n/a` unless precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-007 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high | (exact match) |
| C-012 | OQ | NEW | — | n/a | n/a |
| C-019 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic can't classify | low | n/a |
| C-044 | CONFIRMED | UNKNOWN | truncated §4 — absence is not evidence (map capped) | low | n/a |
| C-031 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high | ADD: [nama] · KEEP: [nip, password] · REMOVE: [] |
```

A truncation-sourced `UNKNOWN` row MUST cite the truncation in its Anchor cell (and
set `state_reason: truncated_section` in `binding.json`) — `generate-units` keys its
direct-probe sub-rule on this signal (per the truncation exception above).

## Blocking rules

| Outcome | Effect |
|---|---|
| All claims CONFIRMED | bound-vault produced; pipeline proceeds |
| ANY claim CONFLICT | bound-vault NOT produced; binding.md written with CONFLICT list; pipeline BLOCKED |
| Claims include OQ but no CONFLICT (default) | bound-vault produced; OQs propagated to unit-level grounding |
| Claims include OQ + `--strict` flag set | bound-vault NOT produced; pipeline BLOCKED until OQs resolved |

Implementation-State Classification does NOT change blocking rules. It is an annotation on CONFIRMED claims consumed downstream by `generate-units`. A claim that is `IMPLEMENTED` (or any `PARTIAL_FIELDS_*` state) is still CONFIRMED.

### CONFLICT entry format (classification enrichment)

Every CONFLICT in `binding.md` is written as ONE `### CONFLICT-N` markdown detail
block under `## Conflicts (N) — BLOCKING` — the sole carrier, machine-read AND
human-read (no summary table; P2 grammar per `binding-md-template.md`, the
authoritative template). Each block opens with its `- **Vault claim**:` /
`- **Codebase reality**:` pair (the reality line carries the evidence anchor) and
carries a `- **Claim**: C-NNN` line binding it to the State Map (mandatory on
RESOLVED blocks — `derive-binding-json.sh` exits 2 without it; recommended on
ACTIVE blocks). Each ACTIVE (unresolved) CONFLICT detail block MUST additionally
carry two enrichment fields so downstream review can triage by kind and
effort. A resolved conflict is exempt — resolved means the heading carries `✅` or
the word `RESOLVED` immediately AFTER the conflict ID, or a dedicated
`- **Resolution**:` line whose VALUE starts with the marker (written by
`resolve-oq --binding`); the word "resolved" in a TITLE or in prose, and a
negated `Status: NOT RESOLVED` line, do NOT count (S4 — the validators key on the
structural marker only).

```markdown
### CONFLICT-1 — `App\Models\Product` name collision
- **Vault claim**: <the claim text — verbatim what the vault asserts>
- **Codebase reality**: <what the code shows> (<evidence anchor file:line>)
- **Claim**: C-NNN
- **Vault doc**: 03-data-model.md §Product
- **Codebase artifact**: app/Models/Product.php
- **conflict_class**: naming-collision      # naming-collision | signature-drift | semantic | regulatory
- **resolution_complexity**: low            # low | medium | high
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT — <1-line rationale citing the evidence anchor; the enum never surfaces bare>
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
- Apply outcome (per `bind-codebase` Procedure §2.6 — recorded in the vault MARKDOWN and carried into vault.json by the Step-6 derive, never hand-edited):
  - **Single unambiguous match** → OQ becomes `status: resolved` with `resolution` + script-stamped `resolved_at` + `scan_citations`
  - **No match** → flip `resolution_mode` to `blocking` (md-bracket edit); OQ stays `open` (no silent guess)
  - **Multiple matches** → flip `resolution_mode` to `blocking` (md-bracket edit); list candidates
- Recorded in `binding.md` "## Tech-OQ Auto-Resolved (Scan)" table

### Recommend mode (`resolution_mode: recommend`)

- Validates required fields: `recommendation`, `rationale`, `scan_citations` (≥1), `fallback_if_wrong`
- Validates that `scan_citations` resolve to entries in codebase-map / KB
- Surfaced in `binding.md` "## Tech-OQ Recommendations (review required)" section with full structure (recommendation + rationale + citations + fallback + ACCEPT/OVERRIDE/REJECT user actions)
- Does NOT block the pipeline — user reviews one-pass after binding completes

### Confidence gate

Per mode (S4 — aligned with generate-intent's shipped heuristics, whose recommend
rows emit `classification_confidence: medium`):
- **Scan mode**: ONLY `classification_confidence: high` auto-resolves. `medium`/`low` → skip auto-resolution, pass through unchanged.
- **Recommend mode**: surfaced at `high` AND `medium` (surfacing is advisory and never blocks — restricting to `high` made the entire Recommendations feature dead code). `low` → skip surfacing, pass through unchanged.
- In BOTH modes, a skipped OQ's `resolution_mode` is NEVER mutated (no flip to `blocking` on confidence grounds — only a failed scan flips to blocking, per §Scan mode).
- Medium/low OQs are already listed in `00-index.md` "## Auto-Classification Review" for manual user attention before binding runs.

### Anti-halu enforcement

- Scan finds no match → flip to `blocking`, NEVER guess
- Recommendation citations unverifiable → halt with `oq_recommend_citation_invalid`
- Missing recommendation fields → halt with `oq_recommend_underspecified`
- Tech-OQ auto-resolution does NOT affect blocking rules — CONFLICT still blocks the binding gate. Tech-OQ resolution operates orthogonally to the verdict layer.

### Blocking rule update

Tech-OQ resolution adds no new BLOCKING outcomes. The binding gate continues to block on `conflict > 0` AND optionally on `oq > 0 + --strict`. Auto-resolved tech OQs reduce the `oq` count (they move to `confirmed` for accounting purposes), making `--strict` mode more practical to use in real projects.

## Claim-scoped re-bind (`--paths` — living-vault sync lane)

Invoked by `orchestrate-flow --sync` (spec `2026-06-10-living-vault-continuous-sync-design.md` S4) and by the delta lane (`diff-vault --from-prompt` → `--paths=@<vault>/.delta-changed-paths.txt`, spec `2026-08-11-free-text-delta-lane.md`). Full re-bind stays the default; `--paths` is the incremental optimization. The CONFLICT-blocking contract is IDENTICAL in both modes.

**Affected-claim selection (anchor reverse-index):**
1. Load the PREVIOUS `binding.md`; build the reverse index: for each claim, the set of files appearing in its evidence/anchor citations (Confirmed list + Implementation State Map `Anchor` column) plus its `vault file:line` source.
2. `affected_claims` = claims whose anchor files intersect the changed-paths set, PLUS claims whose vault source section changed (vault edited), PLUS **every ACTIVE CONFLICT from the previous binding regardless of path intersection** (a suspected hole in the moat is never carried on trust).
3. Claims in the codebase-map whose rows were re-extracted by `scan-codebase --changed-only` but that match no prior claim → candidate NEW evidence; run normal Step 2 verdict logic for any vault claim still OQ/NEW.
4. **Vault-section leg, concrete detection:** when `<vault>/VAULT-DIFF.md` exists and is newer than the previous `binding.md` (a diff-vault apply), the "vault source section changed" selection reads ALL its diff-body rows — **Conflicts (PRIORITY-1) and Auto-resolved OQs included, not just Added/Changed/Removed** (a Supersede rewrites `05-decisions.md`; an auto-resolve mutates an OQ section — both are vault edits; every applied row names its target doc per `diff-vault/references/report-format.md §Doc-literal mandate`) — claims whose `vault_source` doc appears there join `affected_claims`. An ADDED vault section has no prior claim: its claims are authored fresh on this run (changed vault source by definition). An AFFECTED claim that cannot be matched to the current vault text keeps the express rule-3 full-re-bind fallback — never a guessed mapping.

**Verdict assembly:**
- `affected_claims` → full Step 2 (+2.5–2.12) verdict logic, fresh citations.
- All other claims → carried forward VERBATIM with `provenance: carried_forward` + the prior bind timestamp on the row. A carried-forward verdict is never silently upgraded or downgraded.
- Counts (`claims_total`/`confirmed`/`conflict`/`oq`) are recomputed over the FULL set (fresh + carried). `binding.md` is rewritten whole — including the canonical `### CONFLICT-N` headings for EVERY active conflict (fresh or re-validated) — so the Step 5 gate, `validate-handoff-binding-units.sh`, and `.validation-blockers.json` see exactly the same surface as a full re-bind.

**Fallback to full re-bind (one-line note, no halt):** previous `binding.md` absent/unparseable; the vault itself was regenerated (version bump since last bind **without a diff-vault patch record** — a bump whose `00-index.md` Changelog entry was written by a diff-vault apply AND whose `VAULT-DIFF.md` is present AND with **no vault doc newer than `VAULT-DIFF.md`** is a PATCH, not a regeneration: its changed claims arrive via the `--paths` set + the vault-section leg above, active CONFLICTs are still ALWAYS re-validated, and carry-forward stays safe because a diff-vault apply preserves untouched IDs/text by contract; a vault doc modified AFTER the diff report re-fires this fallback — the patch record cannot vouch for post-patch edits); changed paths exceed 40% of anchored files; or any carried-forward claim's anchor file no longer exists (provenance can't be trusted → full re-run).

**Anti-halu rails:** carried-forward rows keep their original citations untouched (no re-stamping); the phase-advisor pass (Step 2.12) runs over the FRESH verdicts at minimum and may sample carried ones; bound-vault production rules are unchanged (no `bound/` while any conflict — fresh OR carried — is active).

## Resolution paths

When binding blocks:

1. User runs `resolve-oq --binding ./binding.md` — interactive walker; writes structural ✅ RESOLVED markers into binding.md (+ binding.json `resolution:`), patches the vault for KEEP_CODE/SPLIT
2. KEEP_CODE / SPLIT chosen → re-run `bind-codebase` — the edited claims re-bind cleanly; conflicts=0 produces the bound-vault
3. KEEP_VAULT / DEFER only → NO re-bind (it re-raises the same CONFLICT from the unchanged vault-vs-code contradiction — bind never consumes a prior resolution as evidence). The resolved-marked binding.md passes the handoff validator → proceed to generate-units; bound/ arrives via a re-bind AFTER the code change lands
4. Alternative: user edits vault manually + re-runs binding

## binding.md output structure

The full file template is the binding-md-template reference listed in `bind-codebase/SKILL.md` §Specialist references. Required sections:
- Summary counts (claims_total, confirmed, conflict, oq)
- Confirmed list (cite vault file:line + codebase evidence)
- Conflict detail blocks — one `### CONFLICT-N` heading per conflict carrying **Vault claim** / **Codebase reality** (+ evidence anchor) / **Suggested action** lines; no summary table (the detail heading is the only machine-read AND the only human form)
- OQ table (id, question, vault source)

## bound-vault structure

`<vault>/bound/` (nested in the vault dir, beside `units/` and `bolts/`) is DERIVED by `scripts/make-bound.sh` (bind Step 5) from the vault docs + `binding.json` — never hand-written by the model. It is a copy of the vault's 7 markdown files (the `0[0-6]-*.md` docs; `vault.json` is NOT copied) with two augmentations:

1. **Inline binding annotations** — for each `binding.json` claim whose `vault_source` has the exact `<file>.md:<line>` form, a standalone HTML-comment line is inserted immediately AFTER the cited line: `<!-- BIND: <verdict>=<claim-id> -->`, verdict lowercase from `binding.json` — e.g. `<!-- BIND: confirmed=C-001 -->` / `<!-- BIND: oq=C-012 -->` (OQ rows use the claim-id form, never OQ-NN). Multiple claims citing the same line merge into ONE comment joined with `, ` in `binding.json` claim order (`<!-- BIND: confirmed=C-001, confirmed=C-004 -->`). `conflict=` never appears in practice — bound/ exists only at `conflict == 0`. Claims with a null / section-style (`03-data-model.md §Product`) / out-of-bounds / unmatched-file `vault_source` are SKIPPED and counted in the script's summary line — never guessed. Annotations are ADVISORY reading context only: nothing machine-parses them; `binding.md` / `binding.json` stay the authoritative surfaces. Docs with no annotations are byte-identical copies.
2. `<vault>/bound/binding.md` mirrors the vault-root `<vault>/binding.md` byte-identically.

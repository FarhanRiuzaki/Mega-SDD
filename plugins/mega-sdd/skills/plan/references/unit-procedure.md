# plan — unit procedure (the Step 4 candidate walk)

> Relocated from `skills/generate-units/SKILL.md` + `skills/generate-units/references/auto-and-memory.md` in 9.0 (P1); tuned text kept verbatim.

Loaded by `plan/SKILL.md` Step 4. Sources = the PRD + `context.md`; the plan deltas in `references/plan-procedure.md §Step 4` apply on top. Step numbers below are the unit-walk numbers (2 → 12.7), distinct from plan's Steps 0–7 — validators and the unit schema cite them (e.g. `12.5.d`), so they stay stable.

## Contents
- Unit flags
- Procedure — Steps 2 → 12.7
- Step 10 — Scope propagation into unit frontmatter
- Step 11 — `_index.md` contents
- Anti-hallucination rails
- Halt conditions (index)

## Unit flags

- `--max-complexity=small|medium|large` (split anything bigger; `large` = story-sized units, threshold naik ke <600 LOC / ≤8 files — buat tim yang review-nya per story)
- Granularity resolve (sekali, sebelum Step 3): **flag > config > default** — `--max-complexity` menang; tanpa flag baca `.mega-sdd/config.yaml` `unit_granularity: fine|coarse` (fine→small, coarse→large); absen keduanya → `medium` (default 300 LOC / 5 files, tidak berubah)
- `--adversarial-subagent` — Step 9.5 dispatches a SEPARATE subagent per unit for adversarial test review (stronger blind-spot coverage; auto-set for any unit with `risk: high`/`critical` — the `risk:` frontmatter field is WRITTEN by Step 2.5 per the risk signals in `references/adversarial-test-prompt.md`, defined in `references/unit-schema.md`; absent = low)
- `--no-adversarial-review` — SKIP Step 9.5; sets every unit's `acceptance_test._authored_by: same-pass`. DISCOURAGED (re-opens the same-pass blind-spot risk); debug/regression only
- `--regenerate` — rewrite existing unit files; PRESERVES units with `acceptance_test._authored_by: human`; others rewritten per Step 9 + 9.5
- Dependency-emission flags: `--strict-deps` (default) · `--loose-deps` (legacy over-emit) · `--no-deps` (testing). Collision: `--collision-policy=<extend|verify|skip>` (default `extend`; Step 7.6 — no mid-phase ask).

## Procedure — Steps 2 → 12.7

The step skeleton is below with every gate/rail inline, and **the inline skeleton is authoritative for the unambiguous path**. Heavy detail (full state tables, halt YAML, schemas, templates) lives in the specialist references — each step names its file WITH the condition under which to open it; a pointer without its condition met is not a read command. (`references/unit-schema.md` and `references/templates/unit.md` stay unconditional — they are the authoring contract.)

**2. Identify unit candidates.** Walk the sources (`context.md ## Flows`, `context.md ## Data model`, the PRD requirement headings). Each implementable artifact (component, endpoint, schema migration, etc.) becomes a candidate unit.

**2.2. Flow-step → artifact derivation.** Do NOT decompose flows at module granularity only. For each USER flow (`F-U-*`), enumerate its input-accepting state-transition steps; the set of per-step input-validation artifacts a module unit ships EQUALS the set of input-accepting steps its flow enumerates — no more (drop dead conditional scaffolds with no gating flow step), no fewer (one artifact per step, not one per controller). Enforced by `validate-flow-coverage.sh`; full rule + the tradefinance-proven failure modes in `references/decomposition-rails.md §Flow-step`.

**2.5. Determine `task_type` per candidate (MOAT-CRITICAL — symbol-index typing).** Assignment follows `references/plan-procedure.md §Step 4` (greenfield ⇒ `create`; brownfield ⇒ a symbol-index hit types `verify`/`extend`, a miss types `create`; every expectation becomes a `## Claims` line — never a verdict). `verify` units carry empty/`none` target_files, a MANDATORY `## Anchors` entry citing the symbol-index hit (`file:line`), a one-line Implementation-steps body, and assertions that prove existing code still works. A `verify` unit whose anchor is empty → halt (anchor gap); never silently downgrade. `verify` specifics, `extend` Migration-notes population, and target_files mechanics: `references/task-typing.md` — open it ONLY when a symbol-index hit types a candidate `verify`/`extend` or a 7.6 collision fires; a greenfield walk (every unit `create`) follows the inline Step-2.5 rules.

**3. Group + atomize.** < 300 LOC and ≤ 5 files → single unit; larger → split into N units with an explicit `depends_on` chain. Under resolved granularity `large` the single-unit threshold rises to < 600 LOC and ≤ 8 files (story-sized; semua rail lain tidak berubah — unit tetap atomic, 1 unit = 1 bolt = 1 review panel). A unit needing an OQ resolved → mark "TBD: <OQ-ID>" in body + add to acceptance criteria.

**4. Resolve dependency graph (strict by default — maximize parallelism).** Emit `depends_on: U-X` ONLY with concrete evidence of coupling: file overlap, symbol cross-reference, Migration-notes reference, an explicit vault ordering declaration, or module-level `blocked_by`. Do NOT emit for same-section/same-module conceptual sequencing without target_files evidence. Then build the DAG and:
   - **Reject cycles** → halt `cycle_detected`; user restructures vault sections so deps form a DAG.
   - **Reject cross-squad direct deps** (multi-squad mode, after Step 5): a `depends_on` edge crossing `squad:` boundaries → halt `cross_squad_dep_invalid`; route via interface notes.
   - **Validate interface references:** every `consumes_interfaces` / `produces_interfaces` ID must resolve to an `interfaces/<id>.md` file → else halt `interface_ref_missing`.

   Emission rules + flag behavior: `references/decomposition-rails.md §Dependency-graph`. Halt YAML: `plugins/mega-sdd/references/halt-protocol.md`.

**4.5. Module assignment.** Semantic grouping ABOVE atomic units (units stay atomic). Load `_meta/modules.yaml` (auto-derive `.auto` when absent); match each candidate's `context_source` | `vault_source` to a module; unmatched → `M-unassigned` (warn at ≥10%). Cross-module `depends_on` requires explicit `blocked_by` → else halt `cross_module_dep_invalid`; module DAG cycle → halt `module_cycle_detected`. Detail: `references/decomposition-rails.md §Module assignment`; open `plugins/mega-sdd/references/modules-schema.md` at Step 4.5 whenever auto-deriving `.auto` (`_meta/modules.yaml` absent — §Auto-derivation rules + the `.auto` format live there) or when a present modules.yaml needs schema validation; the no-modules back-compat path (`M-default`) is inline.

**5. Squad assignment.** No `_meta/squads.yaml` or single squad → all units `squad: default`, skip multi-squad validations (`plan` never authors a `squads.yaml`; the multi-squad rules below serve a vault that already carries one, e.g. a migrated vault). ≥2 squads → route by `context_source` | `vault_source` with precedence `owns_components` > `owns_flow_prefixes` > `owns_layers` > `owns_feature_tags`; unrouted → warn + `default`; two squads claim one artifact at the same precedence → halt `cross_squad_ambiguous`. Detail: `references/decomposition-rails.md §Squad assignment`.

**6. Allocate IDs.** Topologically sort candidates; number U-001, U-002, …. **Scale advisory:** >100 candidate units → one warning (suggest module split or multi-vault per scope); >500 → confirm before writing (unit explosion usually means the vault mixes scopes). A re-run (`--regenerate`) preserves IDs of unchanged units by content hash.

**7. Fill `target_files` whitelist.** Greenfield → expected files from the `context.md` / PRD component definitions; brownfield → the Step 2.5 symbol-index hits (specific paths from `query-symbol-index.sh`). Can't determine target_files → halt (vault too vague).

**7.6. Per-unit target_files collision check.** Before writing each unit, for each `operation: create` entry that already exists on disk → resolve by `--collision-policy` (`extend` | `verify` | `skip`; default `extend`, the safest option — rename / force-create are never applied by policy) and list every resolution in the plan Step 7 summary — never a mid-phase ask. Fires ONLY on genuine collision. Detail: `references/task-typing.md §Step 7.6` (single owner).

**8. Fill `existing_interfaces`.** Brownfield → pull from the symbol-index hits for the targeted files (expectations, never verdicts). Greenfield → empty.

**9. Fill `acceptance_test`.** ≥1 `type: test` entry (mandatory); generate a command stub matching the detected test framework; add `type: manual` for user-visible flows. **Render test:** if any target_file matches the active pack's `detail_view_glob`, the unit MUST ALSO carry a `type: render` test (factory-create model, GET detail route, assert 200 + a real field renders) — a route-200 smoke test does NOT satisfy this. Enforced by `validate-unit-spec.sh` (`render_test_missing`). This is the FIRST PASS — adversarial review runs in Step 9.5. Detail: `references/decomposition-rails.md §Render test`. Body §Acceptance criteria: verify units carry the expanded (marker-bearing when HIGH) criteria; create/extend carry the one-line pointer to the structured entries plus only non-restating items (TBD OQs, prose-only constraints); `ears:` only where it adds precision beyond `expects:`.

**9.b. Attach a UI contract to view-bearing units.** When a target_file matches the pack's `view_glob`, attach a `## UI contract` (label_map, fk_display, value_formatting, flow-derived `required_states`) so the bolt renders a production-grade view. Every entry is GROUNDED in the vault — never invented; a missing source becomes an Open Question, never a defaulted value. Detail: `references/decomposition-rails.md §UI contract`.

**9.5. Adversarial test review pass.** acceptance_test authored by the same LLM pass as the unit inherits the same blind spots ("never trust AI to both generate and validate"). For each unit, run the adversarial review (`references/adversarial-test-prompt.md`): default mode re-prompts the main thread as a QA reviewer; `--adversarial-subagent` (or `risk: high`) dispatches a separate subagent; `--no-adversarial-review` skips (sets `_authored_by: same-pass`). Gaps merge into acceptance_test with `_authored_by:` provenance. `--regenerate` PRESERVES `_authored_by: human` units. Detail: `references/decomposition-rails.md §Adversarial`.

**10. Write each unit file** using `references/templates/unit.md` as the body template. When vault.json has a `scope` field, every unit's frontmatter MUST include `scope:` + `scope_name:` sourced verbatim from `scope_metadata` (omit for legacy single-scope). Detail: §Step 10 — Scope propagation below. **Source grammar (spec 2026-09-10 App. F1):** write `prd_source:` (`<prd-file>#<heading-slug>` or `:<line>`, list allowed) for every unit whose requirement has a PRD home; brownfield units carry `## Claims` (expectations about EXISTING code — a contract, never a verdict; grammar in `references/unit-schema.md §Claims`); do NOT write the zero-reader fields `mutability`, `estimated_complexity`, `grounding_evidence`, `superpowers_skills`, `acceptance_test[].ears`. **xs body diet (App. F1e):** a unit you author with 1–2 `acceptance_test` entries AND 1–3 implementation steps is the router's `unit_tier: xs` class (`_lib/unit_tier.py`, one proxy) — write it on the diet: Goal ONE line, Context ≤ 2 sentences, steps ≤ 3, and NO `## Anti-patterns` / `## Out of scope` unless every item cites its source (U-XXX, OQ-, C-, doc anchor, file:line). The implementer reads the body in full, so every extra line is paid on every run (field ratio 17.9:1 instruction:code on a 22-line unit). Step 12's validator lists offenders in `xs_body_advisory` (advisory, never a halt) — trim them before handoff.

**11. Write `_index.md`** — total unit + module counts, units grouped by module (status, priority, DoD, units table), per-module + cross-module dependency DAGs (Mermaid), suggested topological execution order; falls back to a flat list when only `M-default` exists. Detail: §Step 11 — `_index.md` contents below.

**12. Post-write validation + audit.** The 12.x sub-procedures run in declared order (the inline list below is the authoritative order), then plan Step 5 runs the validators, the PRD-coverage census (12.8) and logs `units_generated` (13). Open `references/validation-passes.md` ONLY when a pass fires or an edge is ambiguous (its full procedures + anti-halu rails). Halt YAML: `plugins/mega-sdd/references/halt-protocol.md` (on halt only).
   - **12.3 Per-anchor verification (runs FIRST).** Probe each `## Anchors` entry; missing file / out-of-bounds line → SOFT WARNING in body footer (anchors may be aspirational). Never halts.
   - **12.4 Inject constitution clauses.** Read `<vault>/constitution.md`; inject relevant clauses into `## Hard rules` (severity `error`); surface non-translatable clauses as informational warnings. Constitution drift between gen and bolt → halt `constitution_drift_detected`.
   - **12.4.5 Framework pack provenance citation.** No pack slice reaches the bolt: a pack shapes code only through what `plan` writes into the unit and through the pack-driven gates — this step adds no new pack-derived Hard Rule. A pack-derived Hard Rule a unit already carries (a migrated vault) keeps its explicit `source:` citation to the specific pack file; rules whose `path_glob` doesn't match the unit's target_files are skipped.
   - **12.5 Polished-prompt render pass.** Validate the prompt-shape contract per `references/unit-schema.md`:
     - **(a) Anchors presence — MANDATORY when evidence exists (a symbol-index hit):** `verify`/`extend` MUST have ≥1 `## Anchors` entry; `create` with a `binding_refs` entry pointing to a related pattern MUST cite the closest pattern; fully-greenfield `create` → optional. Missing → halt `unit_underspecified`.
     - **(b) Hard rules grammar parse:** every `## Hard rules` line MUST match one of the 5 mechanical grammar productions OR the directive tier (generic `MUST/MUST NOT/DO NOT/NEVER/ALWAYS` prose — accepted, but non-mechanically-checkable) per `references/unit-schema.md §Hard rule grammar`; a line matching NEITHER → halt `hard_rule_unparseable` (NEVER silently skip).
     - **(c)** Implementation-steps directive-prose check → bullet-only emits a WARNING (not halt).
     - **(d)** `extend` MUST have `## Migration notes` (REMOVE/KEEP/ADD all present); `create`/`verify` MUST NOT → else halt `unit_underspecified`.
     - **(e) Anti-patterns harvesting (suggestion):** auto-populate `## Anti-patterns` from KB `Edge Cases & Gotchas` (PRD-kontrak §5, `plan --kb`) for domains the unit covers — guidance only, no halt.
     - **(g) OQ-ID propagation check (MOAT-CRITICAL — the `context.md ## Open Questions` → units trace):** every implementation-relevant OQ (resolution touches the unit's files/body, or `priority: P1`) MUST appear in the unit's `binding_refs:` frontmatter; any missing → halt `unit_oq_trace_missing`, so the design decision stays traceable to its source OQ.
     - **(h) PBT properties citation check:** every `properties[].cites` must resolve to a real vault section / entity / constitution clause — an uncited property is an INVENTED invariant → reject the unit write (full procedure: `references/validation-passes.md`). The optional `properties:` extension itself is authored per `references/pbt-integration.md` ONLY when a PBT framework is detected.
   - **12.6 Deduplication check.** A `create` unit whose `target_files` ALL already exist → halt `dedup_ambiguous` (NEVER silent-rewrite the task_type).
   - **12.7 Sibling-consistency sweep.** Reason about siblings TOGETHER (grouped by module + scope): every sibling a pack-declared cross-cutting concern applies to MUST declare the SAME mechanism (no fan-out divergence); every FK column MUST declare its derived relation accessor. Enforced by `validate-sibling-consistency.sh`.

## Step 10 — Scope propagation into unit frontmatter

When vault.json contains a `scope` field (multi-scope vault), every unit's frontmatter MUST include:

```yaml
scope: <vault.scope_metadata.id>           # e.g., "BE", "MW", "FE"
scope_name: <vault.scope_metadata.name>    # e.g., "Backend API"
```

This enables downstream skills (execute-bolts, multi-squad routing) to verify they're operating in the correct scope context. Omit both fields when vault has no scope (legacy single-vault back-compat). `scope:` / `scope_name:` MUST be sourced verbatim from vault.json `scope_metadata` — NEVER inferred or invented.

## Step 11 — `_index.md` contents

Write `<vault>/units/_index.md` with:
- Total unit count + module count
- **Grouped by module** — per module section: name, status (X/Y complete), priority, DoD checklist, units table (ID, title, task_type, depends_on, status); `M-unassigned` group rendered if non-empty with warning
- Per-module dependency DAG (Mermaid graph) — units within module
- Cross-module dependency graph — high-level
- Suggested execution order (topological within + across modules)
- Backward compat: when only `M-default` exists → fall back to flat unit list

## Anti-hallucination rails

- Every unit MUST cite its vault source (file:section); no unit may invent functionality absent from the vault; no unit may touch files outside `target_files` (enforced at bolt time across three layers: the plan Global Constraint (rules), the commit step's `git show --stat HEAD` check, and the deterministic B3 whitelist observer (`validate-bolt-artifacts.sh --whitelist-scan`, Stop-hook + gate-time) diffs each bolted unit's COMMITTED paths — escaped paths block the next `execute-bolts` with `whitelist_violation`); no unit may have an empty `acceptance_test` (presence machine-checked by `validate-unit-spec.sh`).
- OQs surface explicitly as "TBD" — never silently fabricated. OQ-IDs propagate from `context.md ## Open Questions` into `binding_refs:` when their resolution is implemented in the unit (Step 12.5.g halts `unit_oq_trace_missing` otherwise). CONFLICT ids do not exist at plan time — the JIT bind writes them per unit into `bolts/U-XXX/binding.json` at dispatch.
- `task_type` is assigned ONLY from the symbol-index hits (Step 2.5) — never inferred from vague heuristics; no hit → conservative `create`. `verify` units MUST have a concrete anchor — the symbol-index hit recorded in `## Anchors` (never a fuzzy hit). A claim with NO anchor from any source types as `create` AT TYPING TIME (that is the probe rule, not a downgrade); a unit ALREADY assigned verify whose anchor is empty halts as an anchor gap (`unit_underspecified`, YAML in halt-protocol). The dedup check halts (`dedup_ambiguous`) — NEVER silent-rewrites a task_type.
- Anchors are MANDATORY when symbol-index evidence exists (per task_type); missing → halt `unit_underspecified`. Hard rules grammar is a closed set — 5 mechanical types + a directive tier (`MUST/DO NOT/NEVER/ALWAYS` prose, accepted, recorded `attested`/`directive_unverified` at post-flight); a line matching neither → halt `hard_rule_unparseable`. Anti-patterns are drawn from KB gotchas (suggestion only, not a halt condition).
- `depends_on` is intra-squad only (cross-squad coupling routes through interface notes); interface references must resolve to existing files. `--strict-deps` (default) emits deps only on concrete coupling evidence.
- Anchor warnings are SOFT (visible, non-halting; anchors can be aspirational for new files). Per-unit collision resolutions (Step 7.6) fire only on genuine collision.
- `extend` Migration notes (REMOVE/KEEP/ADD) are authored from the PRD-vs-code delta (`references/task-typing.md`) so the bolt knows EXACTLY which fields to add/keep/remove. `grounding_confidence: HIGH|MEDIUM|LOW` reflects upstream + anchor + collision verification.
- Module assignment derives from `context_source` | `vault_source` matching `_meta/modules.yaml`; unmatched → `M-unassigned` (warning), never silently grouped. Cross-module deps need explicit `blocked_by`. Module + unit DAGs both validated for cycles.

## Halt conditions (index)

Full blocker YAML for every type → `plugins/mega-sdd/references/halt-protocol.md` (the registry routes each type to its family file).

- **Unresolved CONFLICT → the gate closes in execute-bolts** (invariant #2; the unit is quarantined before it is built): no binding exists at plan time, so this walk never halts on one; an open CONFLICT in `bolts/U-XXX/binding.json` BLOCKS that unit's bolt, and a migrated vault's CONFLICT blocks until the mandatory JIT re-bind re-verdicts it. Units are NEVER dispatched over an unresolved CONFLICT.
- Dependency cycle → `cycle_detected`. Cross-squad direct dep → `cross_squad_dep_invalid`. Missing interface ref → `interface_ref_missing`. Two squads claim one artifact → `cross_squad_ambiguous`. Cross-module dep without `blocked_by` → `cross_module_dep_invalid`; module cycle → `module_cycle_detected`.
- Unit needs target_files but vault too vague → halt. `vault.json` missing → halt (vault corruption).
- `verify` task_type assigned but its anchor is empty → halt (anchor gap). `create` unit whose target_files all exist → `dedup_ambiguous`.
- Missing required `## Anchors` (verify/extend) or `## Migration notes` (extend) → `unit_underspecified`. Unparseable Hard rule → `hard_rule_unparseable`. Implementation-relevant OQ-ID absent from `binding_refs` → `unit_oq_trace_missing`.

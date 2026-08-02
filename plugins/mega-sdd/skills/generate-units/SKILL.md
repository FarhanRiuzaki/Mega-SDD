---
name: generate-units
version: 2.18.0
description: Decomposes a (bound-)vault into atomic PR-sized unit specs — task_type per binding Implementation State Map, OQ-IDs carried, Anchors mandatory when evidence exists, dependency DAG (cycles rejected). Use when the user says "generate units", "vault to units", "bikin units", "pecah vault jadi unit", "dev tasks dari vault", or paraphrases.
---

# Generate-Units — vault → atomic AI-executable unit specs

Turns intent into actionable atomic specs for AI dev execution. Each unit corresponds to one bolt — one PR-sized code commit handed off to `execute-bolts`.

**Announce at start:** "I'm using the generate-units skill to decompose the vault into atomic units."

## When to use

- After `bind-codebase` produced a bound-vault (brownfield) OR directly after `generate-intent` (greenfield)
- `orchestrate-flow` auto-routes here once the vault is ready
- User explicit: `/mega-sdd:generate-units <vault>/` (the vault dir; reads the nested `bound/` + `binding.md` when present)

Do NOT use when the vault has unresolved CONFLICT entries in `binding.md` — that is a hard block (see The hard gate below); re-run binding first.

## Inputs & flags

- Vault path (positional, required) — the vault dir; brownfield runs carry `<vault>/binding.md` + `<vault>/bound/` (units are written to `<vault>/units/`, beside `bound/` and `bolts/`)
- `--refresh` (re-number IDs from scratch) · `--max-complexity=small|medium` (split anything bigger) · `--auto`
- `--adversarial-subagent` — Step 9.5 dispatches a SEPARATE subagent per unit for adversarial test review (stronger blind-spot coverage; auto-set for any unit with `risk: high`/`critical` — the `risk:` frontmatter field is WRITTEN by Step 2.5 per the risk signals in `references/adversarial-test-prompt.md`, defined in `references/unit-schema.md`; absent = low)
- `--no-adversarial-review` — SKIP Step 9.5; sets every unit's `acceptance_test._authored_by: same-pass`. DISCOURAGED (re-opens the D4-006 blind-spot risk); debug/regression only
- `--regenerate` — rewrite existing unit files; PRESERVES units with `acceptance_test._authored_by: human`; others rewritten per Step 9 + 9.5
- `--reconcile` — living-vault sync lane: UPDATE existing unit IDs in place against the refreshed binding (task_type flips per the new Implementation State Map, Migration notes refreshed from the new field_diff, `status` recomputed via `scripts/compute-unit-staleness.sh`; vanished claims → `status: superseded`, kept never deleted; new claims → new units). ID-stability contract holds — never duplicates. Full pass → `references/task-typing.md §Reconcile pass`
- Dependency-emission flags: `--strict-deps` (default) · `--loose-deps` (legacy over-emit) · `--no-deps` (testing). Collision: `--collision-policy=<extend|verify|skip|prompt>`. Other: `--no-defensive`, `--skip-pagerank`, `--memory-off`

## Output

`<vault>/units/U-001.md`, `U-002.md`, … per `references/unit-schema.md`. Also writes `<vault>/units/_index.md` with the dependency graph.

## The hard gate (MOAT-CRITICAL — invariant #2)

> **Unresolved CONFLICT entries in `binding.md` BLOCK unit generation.** If the bound-vault's binding manifest carries any unresolved CONFLICT, this skill REFUSES to generate units and instructs the user to re-run `bind-codebase` to resolve the conflict first. Units are NEVER generated over an unresolved CONFLICT.

This gate is checked before any candidate is atomized. A CONFLICT that somehow survives into the Step 2.5 task_type aggregation (`Mix of CONFIRMED + CONFLICT`) is treated as a bypass of this gate → halt and report the inconsistency rather than emitting a unit. CONFLICTs (and OQ-IDs, per Step 12.5.g) propagate into unit `binding_refs:` so the traceability link is never silently dropped.

## Procedure

The step skeleton is below with every gate/rail inline. Heavy detail (full state tables, halt YAML, schemas, templates) lives in the specialist references — each step names the file to load.

**0.5. Defensive pre-flight check.** Probe upstream artifacts before vault parsing — `codebase-map.md`, `binding.md`, vault.json `implementation_mode` — and act per the decision matrix in `references/defensive-generation.md §Step 0.5`. Both present → proceed (HIGH grounding). Brownfield + missing artifacts → INTERACTIVE prompt offering to auto-run scan-codebase + bind-codebase (recommended). `--no-defensive` skips this step; `--auto` defaults to the safest option (auto-run upstream).

**1. Load vault.** Read the 7 vault files + vault.json. If `<vault>/binding.md` + `<vault>/bound/` exist (brownfield), read them too.

**1.x. THE HARD GATE.** Before anything else: scan `binding.md` for unresolved CONFLICT entries. If any exist → REFUSE; tell the user to re-run `bind-codebase`. Do not proceed. (See The hard gate above.)

**2. Identify unit candidates.** Walk vault sections (02-architecture, 04-flows, 03-data-model). Each implementable artifact (component, endpoint, schema migration, etc.) becomes a candidate unit.

**2.2. Flow-step → artifact derivation.** Do NOT decompose flows at module granularity only. For each USER flow (`F-U-*`), enumerate its input-accepting state-transition steps; the set of per-step input-validation artifacts a module unit ships EQUALS the set of input-accepting steps its flow enumerates — no more (drop dead conditional scaffolds with no gating flow step), no fewer (one artifact per step, not one per controller). Enforced by `validate-flow-coverage.sh`; full rule + the tradefinance-proven failure modes in `references/decomposition-rails.md §Flow-step`.

**2.5. Determine `task_type` per candidate (MOAT-CRITICAL — read binding's Implementation State Map).** If the bound-vault's `binding.md` has an Implementation State Map, assign `task_type` by aggregating the binding-claim states each candidate derives from. If no State Map (greenfield OR pre-State-Map binding) → every candidate is `create`. Core assignment:
   - All NEW / no binding → `create`
   - All IMPLEMENTED (`confidence: high`) → `verify` (medium/low confidence → treat as UNKNOWN — a fuzzy anchor must not mint a verify)
   - `PARTIAL_FIELDS_*` → `extend` with Migration notes auto-populated from binding's `field_diff` (SURPLUS/BOTH fire a HUMAN REVIEW prompt)
   - Mix of NEW + IMPLEMENTED → SPLIT (one `create`, one `verify`; chain so verify runs first)
   - Any UNKNOWN → truncation-sourced UNKNOWN goes through the direct-probe sub-rule FIRST (never `create` straight off a truncated map section); other UNKNOWN → `create` (conservative default) + note in body. Precedence + sub-rule → `references/task-typing.md`
   - Resolved-**KEEP_VAULT** CONFLICT on a claim → `extend` TOWARD THE VAULT CLAIM (the code must change; never `verify`, never dischargeable by a no-code unit) — Migration notes from the conflict delta, body cites CONFLICT-N + the resolution. → `references/task-typing.md`
   - **Mix of CONFIRMED + unresolved CONFLICT → HALT** (the hard gate should already have blocked; report the inconsistency; RESOLVED conflicts do not trigger this)

   `verify` units carry empty/`none` target_files, a MANDATORY `## Anchors` entry citing the binding `anchor`, a one-line Implementation-steps body, and assertions that prove existing code still works. A `verify` unit whose binding `anchor` is empty → halt (binding gap); never silently downgrade. Full state matrix, `extend` Migration-notes population, and `verify`/target_files mechanics: `references/task-typing.md`.

**3. Group + atomize.** < 300 LOC and ≤ 5 files → single unit; larger → split into N units with an explicit `depends_on` chain. A unit needing an OQ resolved → mark "TBD: <OQ-ID>" in body + add to acceptance criteria.

**4. Resolve dependency graph (strict by default — maximize parallelism).** Emit `depends_on: U-X` ONLY with concrete evidence of coupling: file overlap, symbol cross-reference, Migration-notes reference, an explicit vault ordering declaration, or module-level `blocked_by`. Do NOT emit for same-section/same-module conceptual sequencing without target_files evidence. Then build the DAG and:
   - **Reject cycles** → halt `cycle_detected`; user restructures vault sections so deps form a DAG.
   - **Reject cross-squad direct deps** (multi-squad mode, after Step 5): a `depends_on` edge crossing `squad:` boundaries → halt `cross_squad_dep_invalid`; route via interface notes.
   - **Validate interface references:** every `consumes_interfaces` / `produces_interfaces` ID must resolve to an `interfaces/<id>.md` file → else halt `interface_ref_missing`.

   Emission rules + flag behavior: `references/decomposition-rails.md §Dependency-graph`. Halt YAML: `references/halt-protocol.md`.

**4.5. Module assignment.** Semantic grouping ABOVE atomic units (units stay atomic). Load `_meta/modules.yaml` (auto-derive `.auto` when absent); match each candidate's `vault_source` to a module; unmatched → `M-unassigned` (warn at ≥10%). Cross-module `depends_on` requires explicit `blocked_by` → else halt `cross_module_dep_invalid`; module DAG cycle → halt `module_cycle_detected`. Detail: `references/decomposition-rails.md §Module assignment` + `references/modules-schema.md`.

**5. Squad assignment.** No `_meta/squads.yaml` or single squad → all units `squad: default`, skip multi-squad validations. ≥2 squads → route by `vault_source` with precedence `owns_components` > `owns_flow_prefixes` > `owns_layers` > `owns_feature_tags`; unrouted → warn + `default`; two squads claim one artifact at the same precedence → halt `cross_squad_ambiguous`. Detail: `references/decomposition-rails.md §Squad assignment`.

**6. Allocate IDs.** Topologically sort candidates; number U-001, U-002, …. **Scale advisory:** >100 candidate units → one warning (suggest module split or multi-vault per scope); >500 → confirm before writing (unit explosion usually means the vault mixes scopes). `--refresh` re-numbers from scratch; default re-run preserves IDs of unchanged units by content hash.

**7. Fill `target_files` whitelist.** Greenfield → expected files from vault component definitions; brownfield → bound-vault citations (specific paths from binding). Can't determine target_files → halt (vault too vague).

**7.5. PageRank target_files suggestions.** When `codebase-map.md` is `engine: tree-sitter` (the reference captures only the `.scm` queries produce), surface top-K symbol-graph file suggestions in the unit's `## PageRank suggestions` section — informational, NEVER auto-added to target_files (user promotes manually). Skipped on `engine: ast-grep` (tier-2 map — `precision_tier` is still `ast` but there are NO reference captures; recorded like the `--auto` skip) and on regex tier / `--skip-pagerank` — building the tree-sitter graph off an ast-grep map would re-open the per-file clang path the ladder exists to avoid. **Spawn-cost gate first** — `scan-codebase` does NOT persist the `name.reference.*` captures, so building the symbol graph re-runs `tree-sitter query` one process per FILE over the WHOLE source set (every member of `N`, not just the files that changed). At the ~220 ms/spawn measured on Windows-with-EDR a 10,000-source-file repo is ~37 min. Estimate `N x per_spawn` (0.22 s on windows-bash, else 0.02 s) before building and, above 60 s, ASK before proceeding. **`N` is defined in exactly one place — `references/pagerank-targeting.md §Spawn-cost gate` — read it there; do not restate it here.** That section also names its source — never a fresh walk, because sizing the walk must not cost the walk. Tier 1 is `scan-codebase`'s persisted enumeration (`.mega-sdd/codebase/.scan/files.z`, one spawn, EXACT). Only when that file is absent do you fall back to `codebase-map.md` §2 — and then the count **is a FLOOR**, never a ceiling, and `truncated_sections` containing `2` means §2 is capped, so take the >60 s branch REGARDLESS of the count. `--auto` never prompts: above 60 s it takes the safest option — skip the suggestion pass, DECLARE the skip in the unit body and in the closing Hand-off summary line, and never touch `precision_tier` (same section, §`--auto` policy). Detail: `references/task-typing.md §Step 7.5` + `references/pagerank-targeting.md`.

**7.6. Per-unit target_files collision check.** Before writing each unit, for each `operation: create` entry that already exists on disk → INTERACTIVE prompt (convert to `verify`/`extend`, rename, force-create, or skip). Fires ONLY on genuine collision; `--auto` picks the safest default; `--collision-policy` overrides. Detail: `references/task-typing.md §Step 7.6` (single owner).

**7.7. Derive starterkit Anchors + Hard Rules per unit.** After target_files are final and before Step 8: if `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists, compute per-unit starterkit relevance (ui_ux / auth / rbac / libs), append starterkit-specific Anchors + Hard Rules, and set `starterkit_context_consumed` / `starterkit_relevance` frontmatter. EVERY starterkit-derived Hard Rule MUST carry a `Citation: starterkit-context.yaml §<path>` (machine-checked in Step 12.5.f → halt `starterkit_rule_citation_missing` if missing). Absent file → `starterkit_context_consumed: false`, skip. Full derivation: `references/starterkit-derivation.md`.

**8. Fill `existing_interfaces`.** Brownfield → pull from binding-manifest CONFIRMED entries for the targeted files. Greenfield → empty.

**9. Fill `acceptance_test`.** ≥1 `type: test` entry (mandatory); generate a command stub matching the detected test framework; add `type: manual` for user-visible flows. **Render test:** if any target_file matches the active pack's `detail_view_glob`, the unit MUST ALSO carry a `type: render` test (factory-create model, GET detail route, assert 200 + a real field renders) — a route-200 smoke test does NOT satisfy this. Enforced by `validate-unit-spec.sh` (`render_test_missing`). This is the FIRST PASS — adversarial review runs in Step 9.5. Detail: `references/decomposition-rails.md §Render test`. Body §Acceptance criteria: verify units carry the expanded (marker-bearing when HIGH) criteria; create/extend carry the one-line pointer to the structured entries plus only non-restating items (TBD OQs, prose-only constraints); `ears:` only where it adds precision beyond `expects:`.

**9.b. Attach a UI contract to view-bearing units.** When a target_file matches the pack's `view_glob`, attach a `## UI contract` (label_map, fk_display, value_formatting, flow-derived `required_states`) so the bolt renders a production-grade view. Every entry is GROUNDED in the vault — never invented; a missing source becomes an Open Question, never a defaulted value. Detail: `references/decomposition-rails.md §UI contract`.

**9.5. Adversarial test review pass (closes audit D4-006).** acceptance_test authored by the same LLM pass as the unit inherits the same blind spots ("never trust AI to both generate and validate"). For each unit, run the adversarial review (`references/adversarial-test-prompt.md`): default mode re-prompts the main thread as a QA reviewer; `--adversarial-subagent` (or `risk: high`) dispatches a separate subagent; `--no-adversarial-review` skips (sets `_authored_by: same-pass`). Gaps merge into acceptance_test with `_authored_by:` provenance. `--regenerate` PRESERVES `_authored_by: human` units. Detail: `references/decomposition-rails.md §Adversarial`.

**10. Write each unit file** using `references/templates/unit.md` as the body template. When vault.json has a `scope` field, every unit's frontmatter MUST include `scope:` + `scope_name:` sourced verbatim from `scope_metadata` (omit for legacy single-scope). Detail: `references/auto-and-memory.md §Scope propagation`.

**11. Write `_index.md`** — total unit + module counts, units grouped by module (status, priority, DoD, units table), per-module + cross-module dependency DAGs (Mermaid), suggested topological execution order; falls back to a flat list when only `M-default` exists. Detail: `references/auto-and-memory.md §_index.md`.

**12. Post-write validation + audit.** The 12.x sub-procedures run in declared order, then step 13 logs. Full procedures + anti-halu rails: `references/validation-passes.md`. Halt YAML: `references/halt-protocol.md`.
   - **12.3 Per-anchor verification (runs FIRST).** Probe each `## Anchors` entry; missing file / out-of-bounds line → SOFT WARNING in body footer (anchors may be aspirational). Never halts.
   - **12.4 Inject constitution clauses.** Read `<vault>/constitution.md`; inject relevant clauses into `## Hard rules` (severity `error`); surface non-translatable clauses as informational warnings. Constitution drift between gen and bolt → halt `constitution_drift_detected`.
   - **12.4.5 Framework pack provenance citation.** Emit each pack-derived Hard Rule (from binding §Suggested Unit Hard Rules) WITH an explicit `source:` citation to the specific pack file; rules whose `path_glob` doesn't match the unit's target_files are skipped.
   - **12.5 Polished-prompt render pass.** Validate the prompt-shape contract per `references/unit-schema.md`:
     - **(a) Anchors presence — MANDATORY when binding evidence exists:** `verify`/`extend` MUST have ≥1 `## Anchors` entry; `create` with a `binding_refs` entry pointing to a related pattern MUST cite the closest pattern; fully-greenfield `create` → optional. Missing → halt `unit_underspecified`.
     - **(b) Hard rules grammar parse:** every `## Hard rules` line MUST match one of the 5 mechanical grammar productions OR the directive tier (generic `MUST/MUST NOT/DO NOT/NEVER/ALWAYS` prose — accepted, but non-mechanically-checkable) per `references/unit-schema.md §Hard rule grammar`; a line matching NEITHER → halt `hard_rule_unparseable` (NEVER silently skip).
     - **(c)** Implementation-steps directive-prose check → bullet-only emits a WARNING (not halt).
     - **(d)** `extend` MUST have `## Migration notes` (REMOVE/KEEP/ADD all present); `create`/`verify` MUST NOT → else halt `unit_underspecified`.
     - **(e) Anti-patterns harvesting (suggestion):** auto-populate `## Anti-patterns` from binding CONFLICTs + KB `Edge Cases & Gotchas` for domains the unit covers — guidance only, no halt.
     - **(f) Starterkit citation check:** any starterkit-derived Hard Rule missing its `Citation:` → halt `starterkit_rule_citation_missing` (ALWAYS STOP; do not write the unit).
     - **(g) OQ-ID propagation check (MOAT-CRITICAL — the binding→units handoff):** every implementation-relevant OQ (resolution touches the unit's files/body, or `priority: P1`) MUST appear in the unit's `binding_refs:` frontmatter; any missing → halt `unit_oq_trace_missing`. CONFLICTs already propagate this way; this rail extends the discipline to OQs so the design decision stays traceable to its source OQ.
   - **12.6 Deduplication check.** A `create` unit whose `target_files` ALL already exist → halt `dedup_ambiguous` (NEVER silent-rewrite the task_type).
   - **12.7 Sibling-consistency sweep.** Reason about siblings TOGETHER (grouped by module + scope): every sibling a pack-declared cross-cutting concern applies to MUST declare the SAME mechanism (no fan-out divergence); every FK column MUST declare its derived relation accessor. Enforced by `validate-sibling-consistency.sh`.

**13. Audit log.** Append to `vault.json`: `{ "event": "units_generated", "at": "...", "count": N }`. Runs last so the event reflects all post-write validation outcomes.

## Anti-hallucination rails

- Every unit MUST cite its vault source (file:section); no unit may invent functionality absent from the vault; no unit may touch files outside `target_files` (enforced at bolt time across three tiers: the dispatch prompt forbids it (rules), the review panel checks scope (judgment), and the deterministic B3 whitelist observer (`validate-bolt-artifacts.sh --whitelist-scan`, Stop-hook + gate-time) diffs each bolted unit's COMMITTED paths — escaped paths block the next `execute-bolts` with `whitelist_violation`); no unit may have an empty `acceptance_test` (presence machine-checked by `validate-unit-spec.sh`).
- OQs surface explicitly as "TBD" — never silently fabricated. OQ-IDs propagate from the binding Resolution Table into `binding_refs:` when their resolution is implemented in the unit (Step 12.5.g halts `unit_oq_trace_missing` otherwise). CONFLICTs propagate the same way.
- `task_type` is assigned ONLY from the binding's Implementation State Map — never inferred from vague heuristics; UNKNOWN → conservative `create`. `verify` units MUST have a concrete anchor — from the binding State Map OR the Step 2.5 direct-probe result recorded in `## Anchors` (per `references/task-typing.md` UNKNOWN sub-rule). A claim with NO anchor from any source types as `create` AT TYPING TIME (that is the probe rule, not a downgrade); a unit ALREADY assigned verify whose anchor is empty halts as a binding gap (`unit_underspecified`, YAML in halt-protocol). The dedup check halts (`dedup_ambiguous`) — NEVER silent-rewrites a task_type.
- Anchors are MANDATORY when binding evidence exists (per task_type); missing → halt `unit_underspecified`. Hard rules grammar is a closed set — 5 mechanical types + a directive tier (`MUST/DO NOT/NEVER/ALWAYS` prose, accepted, recorded `attested`/`directive_unverified` at post-flight); a line matching neither → halt `hard_rule_unparseable`. Anti-patterns are drawn from binding CONFLICTs + KB gotchas (suggestion only, not a halt condition).
- `depends_on` is intra-squad only (cross-squad coupling routes through interface notes); interface references must resolve to existing files. `--strict-deps` (default) emits deps only on concrete coupling evidence.
- PageRank suggestions are informational, never auto-added to target_files. Anchor warnings are SOFT (visible, non-halting; anchors can be aspirational for new files). Per-unit collision prompts fire only on genuine collision.
- `PARTIAL_FIELDS_*` Migration notes are populated from binding's `field_diff` so the bolt knows EXACTLY which fields to add/keep/remove. `grounding_confidence: HIGH|MEDIUM|LOW` reflects upstream + anchor + collision verification.
- Module assignment derives from `vault_source` matching `_meta/modules.yaml`; unmatched → `M-unassigned` (warning), never silently grouped. Cross-module deps need explicit `blocked_by`. Module + unit DAGs both validated for cycles.
- `starterkit-context.yaml` is consumed read-only (never modified); starterkit-derived Hard Rules MUST cite `starterkit-context.yaml §<path>` (Step 12.5.f → halt). Relevance is computed from target_files paths + body text only — never fabricated; `partial_slices` are skipped, never guessed.

## Halt conditions (index)

Full blocker YAML for every type → `references/halt-protocol.md`.

- **Unresolved CONFLICTs in binding → REFUSE; re-run binding** (the hard gate — invariant #2).
- Dependency cycle → `cycle_detected`. Cross-squad direct dep → `cross_squad_dep_invalid`. Missing interface ref → `interface_ref_missing`. Two squads claim one artifact → `cross_squad_ambiguous`. Cross-module dep without `blocked_by` → `cross_module_dep_invalid`; module cycle → `module_cycle_detected`.
- Unit needs target_files but vault too vague → halt. `vault.json` missing → halt (vault corruption).
- `verify` task_type assigned but binding `anchor` empty → halt (binding gap). `create` unit whose target_files all exist → `dedup_ambiguous`.
- Missing required `## Anchors` (verify/extend) or `## Migration notes` (extend) → `unit_underspecified`. Unparseable Hard rule → `hard_rule_unparseable`. Implementation-relevant OQ-ID absent from `binding_refs` → `unit_oq_trace_missing`. Starterkit Hard Rule missing Citation → `starterkit_rule_citation_missing` (ALWAYS STOP).

## Hand-off

"Generated N units. Suggested next: `/mega-sdd:execute-bolts --all` to execute in order, or `/mega-sdd:execute-bolts U-001` to start with the first."

Under `--auto` (typically from `orchestrate-flow --deep` or `/mega-sdd`), emit the handoff YAML record per your local template in `references/auto-and-memory.md` (operative; `../orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index) — status `halted` on any of the halts above. The `scope:` block is included when vault.json has a `scope` field. Full handoff schema + the memory layer (read-mostly; bolt outcomes written by `execute-bolts`): `references/auto-and-memory.md`.

## Specialist references (load on demand)

- **`references/unit-schema.md`** — the full unit frontmatter + body section schema, the 5-type Hard rule grammar (EBNF + validation table), per-task_type contracts, atomicity / multi-squad / interface-resolution / scope-field rules.
- **`references/task-typing.md`** — SINGLE OWNER of task_type assignment: the full binding-state → task_type table, the six-state Implementation State Map + `field_diff` consumption, `verify` specifics, `extend` Migration-notes auto-population, and Step 7 / 7.5 / 7.6 target_files mechanics (whitelist, PageRank, collision check + prompts).
- **`references/decomposition-rails.md`** — flow-step → artifact derivation, the `depends_on` emission rules + cycle/cross-squad rejection, module + squad assignment, ID allocation, render test + UI contract for view-bearing units, and the adversarial test review pass.
- **`references/validation-passes.md`** — the Step 12.x post-write passes in order (per-anchor verification, constitution inject, framework-pack citation, polished-prompt render pass a–g, dedup, sibling-consistency).
- **`references/halt-protocol.md`** — every blocker's emitted YAML + recovery action, with a "which step fires which halt" index.
- **`references/starterkit-derivation.md`** — Step 7.7 in full: relevance computation, starterkit Anchors + Hard Rules (with the mandatory citation), and frontmatter updates.
- **`references/defensive-generation.md`** — the Step 0.5 pre-flight matrix, grounding_confidence labels (incl. the verify+HIGH per-AC grounding rail), per-anchor verification, and the halt-vs-warning matrix.
- **`references/auto-and-memory.md`** — scope propagation into unit frontmatter, `_index.md` contents, the `--auto` handoff YAML, and the memory layer (reads / writes / anti-halu).
- **`references/pagerank-targeting.md`** — the PageRank symbol-graph algorithm + detection prerequisites for Step 7.5.
- **`references/modules-schema.md`** — the modules layer schema (why modules ≠ bigger units, auto-derivation, modules.yaml format) for Step 4.5.
- **`references/adversarial-test-prompt.md`** — the Step 9.5 adversarial review prompt (default + subagent modes) and the gap-merge logic.
- **`references/pbt-integration.md`** — optional property-based-testing unit extension (`properties:` array; emitted only when a PBT framework is detected).
- **`references/templates/unit.md`** — the unit body template used by Step 10.

## Related skills

Upstream: `bind-codebase` (produces the binding manifest + Implementation State Map this skill reads). OQ conventions + `vault.json` field rules: `../generate-intent/references/vault-contract.md`. The halt-protocol contract: `plugins/mega-sdd/references/halt-protocol.md`. Downstream: `execute-bolts` (consumes units; enforces `target_files`, Hard rules, render tests, sibling-consistency). Orchestration: `orchestrate-flow` (auto-routes here and consumes the handoff YAML).

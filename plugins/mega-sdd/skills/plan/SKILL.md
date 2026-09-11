---
name: plan
version: 1.0.0
description: v8 lite-lane PLAN — ONE model phase turns a PRD into the layout-3 vault (`context.md` flows + DBML + NFR + OQ, `constitution.md`, `vault.json`) AND the atomic units (`units/U-*.md` + `_index.md`) with `prd_source`/`context_source` citations, then raises ONE batched ask for P1 business OQs. Runs only on the lite lane (`--lite`, or config lane=lite; the classic chain keeps generate-intent → bind → generate-units). Use when the chain routes here or the user says "plan PRD ini", "rencanakan dari PRD", "plan this PRD", "PRD langsung ke units", or paraphrases.
---

# Plan — PRD → context.md + units in ONE phase (v8 lite lane)

**Announce at start:** "I'm using the plan skill to turn the PRD into context.md + units (lite lane). `mega-sdd-trace:plan`"

> **Skill instruction language:** this skill reasons in English. **Generated docs match the PRD language**; chat defaults to Indonesian + English technical terms (`plugins/mega-sdd/references/output-language.md`). Tier-1 tokens stay English.

## What this phase is (and is not)

`plan` fuses the three v7 pre-code phases (`generate-intent` → `bind-codebase` → `generate-units`) into ONE model turn (spec `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md` §3 / App. C3): read the PRD once, write `context.md` (layout-3, one file), write the units from PRD + context, derive `vault.json`, run the validators, and ask the human ONCE. Binding does not happen here — **JIT bind runs at dispatch** (execute-bolts pre-flight 3.9 reads each unit's `## Claims`), so a brownfield unit carries claims (a contract), never verdicts.

- **Lane:** only when the run is lite (`--lite` on the front door / chain, or `.mega-sdd/config.yaml` `lane: lite` → `derived.lane`). Off-lane invocation → refuse with one line pointing at `/mega-sdd <prd>` (classic chain). Defaults never change.
- **Input:** a PRD / BRD file (Mode A). A free-text brief (`--from-prompt`) or a knowledge base (`--kb`) is NOT a plan input in P2 — route those to `generate-intent` (classic).
- **Output:** `<vault>/context.md` + `constitution.md` + `_meta/ai-consumer-guide.md` + `vault.json` + `units/U-*.md` + `units/_index.md`. No handoff YAML in this lane — the front door re-derives state from disk (`derive-state.sh`) before the `execute-bolts` hop.

## Anti-hallucination rails (THE MOAT — never relax)

Identical to `generate-intent` + `generate-units`, restated because they are the reason this phase exists:

- **Ground everything in the PRD (+ Figma via MCP).** Not explicit in the source → NOT in the body → an Open Question. No best-practice insertions, no "probably they meant", no defaulted standards (WCAG, palettes, SLO targets), no invented UI when Figma is referenced but unreachable.
- **Every claim cites its source.** Flows/DBML/NFR rows cite `PRD §<X.Y>`; every unit carries `prd_source:` (PRD heading slug or `:line`) AND `context_source: context.md#<anchor>`; a requirement with no unit and no OQ is a `plan_coverage_gap` halt, never silently dropped.
- **Brownfield claims are contracts, not verdicts.** `## Claims` lines say what the unit EXPECTS of existing code (symbol-index query at PLAN); the verdict is written by the JIT bind script into `bolts/U-XXX/binding.json` at dispatch. Never write CONFIRMED/CONFLICT in a unit.
- **`--auto` / lite never bypass the rails.** Autonomy skips logistics only; it never auto-answers a P1 business OQ, never invents field values, never skips the batched ask (an unanswered P1 business OQ stays `blocking` and the units that need it stay blocked at bolts).
- **Units obey the unit contract verbatim** (`../generate-units/references/unit-schema.md`): closed Hard-rule grammar, `target_files` whitelist, ≥1 `acceptance_test`, Anchors when evidence exists, xs body diet.

## Inputs & flags

- `<prd>` (positional, required) — PRD/BRD file (`.md` / `.pdf` / `.docx`; PDF/DOCX via the same readers generate-intent uses). Figma URLs inside the PRD → `ToolSearch query:"figma"`; no MCP and no screenshots → OQ, never invented UI.
- `--vault=<dir>` — output dir; default `.mega-sdd/vaults/<slug>` (slug from `derive-plan-pins.sh`). Existing `context.md` there → refuse unless `--regenerate` (never silently overwrite; `plan --reconcile` is not in P2).
- `--mode=new|existing` — `implementation_mode` pin; the front door passes it from its starterkit/brownfield detection; default `new`.
- `--scope=<id>` — one scope of a multi-scope PRD (`scopes:` block); picker + halts as generate-intent Step 0.9 (`../generate-intent/references/setup-flow.md`).
- `--max-complexity=small|medium|large` · `--strict-deps` (default) · `--collision-policy=` · `--no-constitution` · `--regenerate` · `--auto` — semantics identical to the owning skill (generate-units / generate-intent).
- `--lite` — accepted (the lane marker; the front door forwards it).

## Procedure (inline skeleton = authoritative; detail → `references/plan-procedure.md`)

**0. Pins + setup (script, 0 tokens).** **Run** `bash <plugin-root>/scripts/derive-plan-pins.sh --cwd=<root> --prd=<prd> [--vault=<dir>] [--mode=<mode>]` → `{prd_path, prd_sha256, author, slug, vault, project_scale, implementation_mode, vault_exists}`. `vault_exists` + no `--regenerate` → stop with one line. `project_scale` is the xs switch (`xs` ⇔ 1–3 screens ∧ ≤2 entities ∧ ≤3 flows — structure count, never judgment). `prd_status` = `draft` only when the PRD says so (title/frontmatter/"DRAFT"); else `final`. Nothing here is asked.

**1. Read the source in full** (PRD + Figma frames + attached docs). Multi-scope PRD → Step 0.9 scope rules. Under `prd_status: final` never pause for gaps — every gap becomes an OQ.

**2. Extract before writing** — the internal working table (product, shape, screens, entities, flows, decisions, constraints, gaps, design-system flags `HAS_*` from a SOURCE only). **Rail A1 anti-rot:** write the table's row counts as the contract at the top of your working notes; the Step 6 verdict table must reconcile against it. **Self-slice:** when the PRD exceeds ~40 KB or names ≥3 modules, plan per module (`--scope` / module loop) — one `context.md`, units written module by module, never one giant pass.

**3. Write `context.md`** from `references/templates/context.md` (read the template; four mandatory H2 anchors `## Flows` / `## Data model` / `## Constraints` / `## Open Questions`; `## Decisions` / `## Overview` only when sourced; frontmatter = lock scalars + Step-0 pins + `stakeholders` from the PRD or `["[Pending]"]`). Grammar per section = layout-2 (`../generate-intent/references/generation-guide.md` §Readability + §Mandatory section template; OQ conventions `../generate-intent/references/vault-core.md §OQ-conventions` + §Auto-classifier heuristics). Flows = Mermaid + DoD per flow (Mermaid-flows hard rule). Then `constitution.md` (§A–§F, every clause source-cited — `vault-core.md §constitution`) unless `--no-constitution`, and `mkdir -p <vault>/_meta && cp "<plugin-root>/skills/generate-intent/references/templates/ai-consumer-guide.md" <vault>/_meta/ai-consumer-guide.md`.
   - **OQ classification** on every OQ (business → `blocking`; tech → `scan | recommend | blocking`; conservative default business/blocking/low). **xs:** medium-priority OQs are born `**Deferred (plan)**:` (never asked; resurfaced in the report).
   - **Run** `bash <plugin-root>/scripts/derive-vault-json.sh --vault=<vault> --patch=<patch.json>` ONCE (patch = `source_documents`, `design_system_flags` [+ `design_system`] [+ scope block] + per-OQ classifier records; the pins come from the frontmatter — never hand-write `vault.json`; exit 4 → halt `memory_in_use`).

**4. Write the units** — the candidate walk is generate-units Steps 2–12 with **sources = PRD + context.md** (`../generate-units/SKILL.md` owns the step text; `references/plan-procedure.md §Units` lists the deltas): flow-step → artifact derivation; **task_type**: greenfield (`implementation_mode: new`) ⇒ every unit `create`; brownfield ⇒ query the symbol index per candidate (`bash <plugin-root>/scripts/query-symbol-index.sh --cwd=<root> --name=<symbol>`; hit ⇒ `verify`/`extend` + `## Anchors` + `## Claims` lines; miss ⇒ `create` + a `must-not-exist` claim) — never a CONFIRMED/CONFLICT verdict; group + atomize; strict `depends_on` (cycles → halt `cycle_detected`); modules/squads; IDs; `target_files`; starterkit Anchors + Hard Rules with `Citation:`; `acceptance_test` + render test + UI contract + adversarial pass; **write each unit** from `../generate-units/references/templates/unit.md` with `prd_source:` + `context_source: context.md#<anchor>` (never `vault_source`), the zero-reader fields dropped, the **xs body diet** for the router's xs class; `units/_index.md` (`../generate-units/references/auto-and-memory.md §_index.md`).

**5. Validate (scripts; halts are findings, never patched around).** **Run** in order: `validate-unit-spec.sh --cwd=<root> --vault=<vault>` (halts `unit_underspecified` / `hard_rule_unparseable` / `prd_source_unresolvable`; `xs_body_advisory` = trim); `validate-flow-coverage.sh --cwd=<root>` (BLOCKING gate); `validate-sibling-consistency.sh --cwd=<root> --vault=<vault>`; **`validate-plan-coverage.sh --cwd=<root> --prd=<prd> --vault=<vault>`** → exit 1 = halt `plan_coverage_gap` naming the PRD headings with no unit `prd_source` and no OQ (add a unit, raise an OQ, or an explicit Out-of-scope heading — the gap is the finding). Then `derive-vault-json.sh --vault=<vault> --event='{"event":"units_generated","count":N}'`.

**6. ONE batched ask (W1) — the only interaction point of this phase.** Collect the open **P1 `[business]`** OQs (plus L0 toolchain items the chain handed over). Present ONE `AskUserQuestion` with ≤4 questions, each: the OQ text + its PRD context (side-by-side quote), `[1]` recommended answer (grounded or "no recommendation — needs stakeholder"), `[2]` Defer, `[3]` Out of scope, + "Other" free text; **keterangan mandatory** (question source + per-option explanation, Indonesian for ID users). More than 4 P1 business OQs → ask the 4 with the largest unit blast radius; the rest stay `blocking` (listed in the report; their units stay blocked at bolts). Apply answers to `context.md ## Open Questions` (`→ **Resolved**` / `**Deferred**` / `→ Out of Scope`), re-run `derive-vault-json.sh`, refresh `binding_refs` on the units that cite them. Headless (`AskUserQuestion` unavailable) → the OQs stay open; never self-answer inside the skill.

**7. Self-check + present.** Verdict table vs the Step-2 contract (screens / entities / flows / OQs / units — counts must reconcile; a mismatch is fixed, never explained away); anti-halu + readability checklist (`../generate-intent/references/self-check.md`). Chat summary: vault path, counts, project_scale, top blocker OQs, `NEXT: /mega-sdd --resume` (the front door dispatches `execute-bolts --all --lite`). **Auto-render HTML (0 model tokens):** `bash "<plugin-root>/scripts/render-html.sh" <vault> --index` fail-open. No "I have created…" preamble.

## Halt conditions (index — YAML per type in `plugins/mega-sdd/references/halt-protocol.md`)

`plan_coverage_gap` (Step 5, ALWAYS STOP) · `cycle_detected` · `unit_underspecified` · `hard_rule_unparseable` · `prd_source_unresolvable` · `dedup_ambiguous` · `interface_ref_missing` · `cross_module_dep_invalid` / `module_cycle_detected` · `starterkit_rule_citation_missing` · `scope_not_declared_in_prd` / `prd_no_scopes_block_user_rejected_retrofit` / `prd_retrofit_low_confidence` · `oq_tech_missing_mode` / `oq_recommend_underspecified` / `oq_scan_missing_query` / `oq_recommend_citation_invalid` · `memory_in_use`. Every halt emits the unified `blocker` envelope with keterangan; `emitted_by: plan`.

## Quality bar

Grounded (every non-trivial claim cites PRD §) · honest about gaps (OQs over guesses; the coverage rail is mechanical) · ONE ask, at the end · units executable as-is by `execute-bolts` (contract byte-identical to generate-units) · counts reconcile (A1) · language match.

## Specialist references (load on demand)

- **`references/plan-procedure.md`** — Steps 0–7 in detail: pins, the working table + A1 contract, context.md authoring order, the units delta list vs generate-units, the batched-ask shape (keterangan, >4 overflow rule), the self-check table, headless behavior.
- **`references/templates/context.md`** — the layout-3 template (read before Step 3).
- Owning contracts (unchanged, cross-skill): `../generate-intent/references/vault-core.md` (§OQ-conventions, §Auto-classifier heuristics, §constitution, §id-stability), `../generate-intent/references/generation-guide.md` (§Readability, §Project scale xs, §Mandatory section template), `../generate-intent/references/setup-flow.md` (§Step 0.9 scope), `../generate-intent/references/self-check.md`; `../generate-units/references/unit-schema.md`, `task-typing.md`, `decomposition-rails.md`, `validation-passes.md`, `starterkit-derivation.md`, `adversarial-test-prompt.md`, `templates/unit.md`, `auto-and-memory.md`.

## Related skills

Downstream: `execute-bolts --all --lite` (JIT bind per wave, W2 readiness). Classic equivalents: `generate-intent` → `bind-codebase` → `generate-units` (default lane, untouched). Side lanes: `resolve-oq` (walk the remaining OQs), `analyze`, `emit-*` (DOCS lane reads `context.md` + the PRD directly).

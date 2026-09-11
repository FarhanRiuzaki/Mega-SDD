# plan — procedure detail (Steps 0–7)

Loaded by `plan/SKILL.md` when a step needs more than its inline line. The inline skeleton in SKILL.md is authoritative for the unambiguous path; this file adds the working shapes, the deltas vs the owning skills, and the edge rules. Nothing here loosens a rail.

## Contents
- Step 0 — pins (script) + refusal rules
- Step 2 — the working table + rail A1 (anti-rot contract) + self-slice
- Step 3 — context.md authoring order + OQ classification + patch shape
- Step 4 — units: the delta list vs generate-units Steps 2–12
- Step 5 — validator order + halt mapping
- Step 6 — the single batched ask (shape, keterangan, overflow, apply)
- Step 7 — self-check table + present
- Headless behavior (no `AskUserQuestion`)

## Step 0 — pins (script) + refusal rules

`derive-plan-pins.sh` is the ONLY source of `prd_path_at_generation`, `prd_sha256`, `author`, `slug`, `vault`, `project_scale`, `implementation_mode`. Copy its values into the frontmatter verbatim — never retype a hash, never ask for the author, never ask for stakeholders (PRD-stated names/roles or `["[Pending]"]`).

Refuse (one line, no ask) when: the run is not lite (`--lite` absent AND `derived.lane` ≠ `lite`) → "plan runs on the lite lane only — use `/mega-sdd <prd>` (classic) or `/mega-sdd <prd> --lite`"; `vault_exists` and no `--regenerate` → "context.md already exists at <vault> — `plan --regenerate` rewrites it, `/mega-sdd --resume` continues"; input is a brief / KB → point at `generate-intent`. `prd_status`: `draft` ONLY when the PRD itself says draft (frontmatter `status: draft`, title suffix, a "DRAFT" watermark line); otherwise `final` — under `final` the phase never pauses on gaps (every gap → OQ).

## Step 2 — the working table + rail A1 + self-slice

Before writing any file, build the table (internal — it is not an artifact): screens · entities (name, fields the PRD lists) · flows (id, actor/trigger, PRD §) · decisions the PRD states · constraints/NFR rows with source · gaps (one line each → future OQ) · `HAS_UI_COMPONENTS` / `HAS_TOKENS` / `HAS_A11Y` / `HAS_VOICE_BRAND` (true ONLY from a source). **Rail A1 (anti-rot):** write the contract line `CONTRACT: screens=<n> entities=<n> flows=<n> oq=<n> modules=<n>` first; Step 7's verdict table reconciles against it. A count that drifts mid-phase is a fix, never an explanation.

**Self-slice** (spec C3): PRD > ~40 KB, or ≥ 3 modules / scopes, or `project_scale: standard` with ≥ 6 flows → plan module by module: one `context.md` (written once, sections complete), then units per module in separate passes (`--scope=<id>` when the PRD declares scopes; otherwise the module list from the table). Each pass re-reads only its module's PRD headings + `context.md`. The A1 contract covers the whole PRD; per-module sub-counts are noted under it.

## Step 3 — context.md authoring order + OQ classification + patch

Order (each section complete before the next; the template is `templates/context.md`):
1. Frontmatter — lock scalars + Step-0 pins + `stakeholders` + scope block (multi-scope only, verbatim from the PRD `scopes:` entry).
2. `## Flows` — one `### F-<prefix>-NNN:` per flow; Mermaid diagram (quoted node text) + `**Definition of Done**` checklist + `**Source**: PRD §`. Staged workflows keep the `stages:` block + state diagram. No H2 sub-groups.
3. `## Data model` — DBML with `// Purpose:` per Table; `### <entity>` descriptions (compact-skip); `### Schema constraints` only with a source.
4. `## Constraints` — technical / business / NFR table / conditional design system. A target the PRD does not state → an OQ row in §6, never a default.
5. `## Decisions` / `## Overview` — only when sourced; otherwise the H2 is absent.
6. `## Open Questions` — every gap from the table + every "not stated" from steps 2–4, each with the mandatory category bracket, priority, `[origin: context.md#<anchor>]` when it arose elsewhere. Then classify (`../generate-intent/references/vault-core.md §Auto-classifier heuristics`): business → `blocking`; tech → `scan` (needs `scan_query`) / `recommend` (needs recommendation + rationale + citations + fallback — never fabricated) / `blocking`; no match → business/blocking/low. **xs:** every P2 OQ is written `**Deferred (plan)**: resurfaced after bolts` — born deferred, never asked (W1; `project_scale: xs` only).
7. `constitution.md` (§A–§F, source-cited clauses only; `vault-core.md §constitution`), then the static `_meta/ai-consumer-guide.md` copy.

**Patch shape for `derive-vault-json.sh --patch`** (a scratch JSON file, never `vault.json` itself): `{"source_documents": [...], "design_system_flags": {...}, ["design_system": {...}], ["scope": ..., "scope_metadata": {...}], "open_questions": {"OQ-XX-N": {"scan_query"|"recommendation"|"rationale"|"scan_citations"|"fallback_if_wrong": ...}}}`. Do NOT put `prd_sha256` / `prd_path_at_generation` / `author` / `stakeholders` in the patch — on layout-3 the deriver mirrors them from the frontmatter (md wins). Exit 2 → fix the markdown (the deriver names the section); exit 4 → halt `memory_in_use`.

## Step 4 — units: the delta list vs generate-units Steps 2–12

Run the generate-units candidate walk (`../generate-units/SKILL.md` Steps 2 → 12.7, the step text is owned there) with these deltas:
- **Sources** = the PRD + `context.md` (not vault.md/model.md/flows.md; not binding.md). Candidate sections: `context.md ## Flows` (flow-step → artifact derivation, unchanged rail), `## Data model` (schema/migration units), PRD requirement headings (the plan-coverage census is the checklist).
- **Step 1.x hard gate** (CONFLICT in binding.md) does not apply — there is no binding yet; the CONFLICT gate moves to dispatch (JIT bind, `bolts/U-XXX/binding.json`, hook-guarded).
- **Step 2.5 task_type** — greenfield (`implementation_mode: new`): every unit `create`. Brownfield (`existing`): per candidate, query the symbol index (`query-symbol-index.sh --cwd=<root> --name=<symbol>` / `--file=<path-prefix>`; index absent → treat as greenfield + one WARN line): a hit for the artifact the unit would create → `verify` (unchanged code, MANDATORY `## Anchors` citing `file:line`) or `extend` (the PRD demands a change → `## Migration notes`); no hit → `create`. Every expectation the typing relied on becomes a `## Claims` line (`- C-U<NNN>-<NN> "<verbatim>" — expect: <path>[:<symbol>] | <path> — must-exist | <path> — must-not-exist`). Never `verify` on a fuzzy hit; never a verdict word in the unit.
- **Frontmatter** — `prd_source:` (heading slug of the PRD requirement, or `:line`; list allowed; omit ONLY when the requirement has no PRD home — then it MUST have an OQ) + `context_source: context.md#<anchor>` (`#F-U-001`, `#Data-model`, `#Constraints`); never `vault_source`. `binding_refs:` carries the OQ ids the unit depends on (`TBD: OQ-…` in the body), CONFLICT ids do not exist yet.
- **Not written** (zero readers): `mutability`, `estimated_complexity`, `grounding_evidence`, `superpowers_skills`, `acceptance_test[].ears`. Readers stay tolerant.
- **xs body diet** for the router's xs class (1–2 acceptance entries AND ≤3 steps): Goal ONE line, Context ≤2 sentences, steps ≤3, no Anti-patterns / Out of scope unless every item is sourced. `validate-unit-spec.sh` lists offenders in `xs_body_advisory` — trim before Step 5 ends.
- **Step 12.4 constitution inject**, **12.4.5 pack provenance**, **12.5 render pass a–h**, **12.6 dedup**, **12.7 sibling sweep** — unchanged (the validators run in Step 5). **12.8 plan coverage** — runs in Step 5 as the LAST validator.
- `_index.md` — per `../generate-units/references/auto-and-memory.md §_index.md` (module groups, Mermaid DAGs, topological order).

## Step 5 — validator order + halt mapping

| # | Run | On non-zero |
|---|---|---|
| 1 | `validate-unit-spec.sh --cwd=<root> --vault=<vault>` | `unit_underspecified` / `hard_rule_unparseable` / `prd_source_unresolvable` / `render_test_missing` — fix the unit, re-run; advisories (`xs_body_advisory`, `vault_source_advisory`) = trim |
| 2 | `validate-flow-coverage.sh --cwd=<root>` | BLOCKING gate (state file FAIL blocks execute-bolts): add the missing per-step artifact units |
| 3 | `validate-sibling-consistency.sh --cwd=<root> --vault=<vault>` | fix the divergent sibling |
| 4 | `validate-plan-coverage.sh --cwd=<root> --prd=<prd> --vault=<vault>` | exit 1 → halt `plan_coverage_gap` (the gaps ARE the finding: add a unit / raise an OQ quoting the heading / move it under an explicit Out-of-scope heading — never patch the census) |
| 5 | `derive-vault-json.sh --vault=<vault> --event='{"event":"units_generated","at":"<iso>","count":<n>}'` | exit 2 fix md · exit 4 `memory_in_use` |

Under the lite lane the `execute-bolts` hop is refused by `validate-preflight.sh --predictive` while `.plan-coverage-state.json` is missing or FAIL — so a coverage gap is never "carried into bolts".

## Step 6 — the single batched ask

**Who:** open OQs with `[P1]` + `[business]` (after Step 3.6 classification), plus L0 toolchain items the front door queued for this ask (W1: batched ask absorbs L0). Tech OQs are never asked here (`scan` resolves at bind, `recommend` carries its recommendation, `blocking` tech stays open for `resolve-oq`).

**Shape:** ONE `AskUserQuestion`, ≤4 questions. Per question: header ≤12 chars (the OQ tag), the question = OQ text + the PRD quote it arose from (side by side, ≤3 lines), options `[1] <recommended answer>` (grounded in the PRD/context — when no grounded recommendation exists the label is "No recommendation — needs stakeholder" and the option text says why), `[2] Defer — keep open, units that need it stay blocked at bolts`, `[3] Out of scope — record with reason`, and "Other" (free text = the answer). **Keterangan is mandatory** (`plugins/mega-sdd/references/halt-protocol.md` keterangan rule): every option description explains the consequence in the user's language; never bare codes.

**Overflow:** > 4 P1 business OQs → rank by blast radius (number of units whose `binding_refs` cite the OQ, then P1 flows touched); ask the top 4; the rest stay `blocking` and are listed in the Step-7 summary with their unit ids. Never a second ask in this phase; never auto-answer; never downgrade a P1 to P2 to dodge the ask.

**Apply:** answered → `→ **Resolved (plan)** (<date>): <answer>` on the OQ line (`[x]`), the citing units drop the `TBD:` and keep the id in `binding_refs`; deferred → `**Deferred (plan)**: <reason>`; out of scope → `[~]` + `→ Out of Scope <version>: <reason>`. Re-run `derive-vault-json.sh` (statuses/timestamps are script-stamped). Units whose body still says `TBD: OQ-…` for a blocking OQ stay valid units — execute-bolts blocks their dispatch through `binding_refs` (existing rail), nothing new.

## Step 7 — self-check table + present

Verdict table (chat, ≤8 rows): `screens / entities / flows / OQs (P1 business open / deferred) / units (create / verify / extend) / modules` — each `<contract> → <written>`; a mismatch is fixed before presenting. Then the `../generate-intent/references/self-check.md` checklist (anti-halu, readability, output mode, vault.json integrity) applied to `context.md`, and the unit-level checks (`prd_source` resolves, `context_source` anchors exist, xs diet). Present: vault path, counts, `project_scale`, top blocker OQs (with unit ids), validators' PASS lines, then `NEXT: /mega-sdd --resume` (→ `execute-bolts --all --lite`). Auto-render HTML fail-open.

## Headless behavior

When `AskUserQuestion` is unavailable (a `claude -p` run), Step 6 cannot fire: the P1 business OQs stay `[ ]` + `blocking`, the summary says so, and the units that cite them stay blocked at bolts. The skill never answers an OQ on the user's behalf — a benchmark runner that does so does it OUTSIDE the skill and labels it (`[ASSUMED-BY-RUNNER]`).

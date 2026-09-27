# plan — KB input (`--kb=<kb-dir>`)

> Relocated from `skills/generate-intent/references/kb-submode.md`, `skills/bind-codebase/references/hard-rules-and-packs.md` (§2.9 d–e + Anti-halu rails), `skills/bind-codebase/references/auto-memory-handoff.md` (§Extraction-scorecard preflight) and `skills/generate-intent/SKILL.md` (the KB `project_scale` rule + the `--phase` flag row) in 9.0 (P1); tuned text kept verbatim.

Loaded by `plan/SKILL.md` when the source is an `extract-intelligence` knowledge base instead of a PRD. This file owns how the KB is read and where each claim lands; every other rule of `plan` (the `context.md` grammar, the unit contract, the validators, the single batched ask) applies unchanged. Step map: Step 0 → grammar detection, pins, the two preflights, auto-detection · Steps 1–3 → consumption, tier routing, ERD freedom · Step 4 → KB-derived Hard rules + Anti-patterns · Step 5 → the KB coverage rule · Step 6 → the KB Q&A targets.

## Contents
- What the KB input is
- Grammar detection (PRD-kontrak vs legacy numbered tree)
- KB pins
- KB freshness preflight (advisory, OPT-IN)
- Extraction-scorecard preflight (advisory)
- Consumption — PRD-kontrak grammar
- Consumption — legacy numbered-tree grammar
- Tier-aware routing per claim
- ERD freedom
- KB-derived Hard rules + Anti-patterns
- KB coverage rule (Step 5)
- KB Q&A loop
- KB auto-detection

## What the KB input is

Invocation: `plan --kb=.mega-sdd/knowledge-base/`. Consumes a
`mega-sdd:extract-intelligence` output as the legacy-rebuild brief.

The KB is treated as **ANALYSIS INPUT, not a 1:1 spec.** Vault output
emphasizes REENGINEERING goals + business intent; legacy detail surfaces only
when the `[LOCKED]` tier requires preservation. Per the governing directive:
"code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak
ada ketentuan erd harus 1:1" (code and ERD may change as long as the
reengineering goals are met; ERD need not be 1:1 unless a rule requires it).

The KB input shares the SAME vault contract
(`plugins/mega-sdd/references/vault-core.md` + the layout-3 template `plan/references/templates/context.md`) as a PRD input;
only input parsing differs. `constitution.md` clauses from a KB follow the §A–§F PRD + KB source map in `plugins/mega-sdd/references/vault-core.md §constitution`.

## Grammar detection (PRD-kontrak vs legacy numbered tree)

Two KB grammars exist on disk; detect ONCE, deterministically:

- `<kb>/census.json` present (or `<kb>/modules/*.prd.md` exists) →
  **PRD-kontrak grammar** (census-contracted,
  one PRD per module).
- Otherwise → **legacy numbered-tree grammar** (`00-overview/` …
  `99-rebuild-architecture/`). Pre-existing KBs keep working unchanged.

## KB pins

A KB-born vault pins its source in the `context.md` frontmatter like every Step-0 pin: `prd_path_at_generation` = `<kb>/README.md`; `prd_sha256` = the sha256 of `<kb>/census.json` (the census changes whenever a legacy source or the extraction changes, so the pin tracks both). Computed from the file, never typed. A legacy numbered-tree KB carries no `census.json` → the ordinary PRD pin applies to `<kb>/README.md`. `project_scale` on a KB run is always `standard` (legacy rebuilds are never xs) — the README's structure count is not used.

## KB freshness preflight (advisory, OPT-IN)

- **PRD-kontrak:** `census.json` carries per-file `sha256` for every legacy
  source file. Recompute against the legacy codebase when reachable
  (`legacy_root` in the census): all match → log confirmed; some drifted →
  warn "KB may be stale: N of M source files changed since extraction —
  consider re-running extract-intelligence". **DO NOT halt.** Legacy root
  unreachable → advisory "legacy source not reachable; freshness unchecked".
- **Legacy tree:** check `<kb>/.shared-snapshots/extracted-kb.snapshot.json`
  `source_files_sha256_map` the same way; absent → "no freshness snapshot;
  treating as fresh".

KB consumption correctness is unchanged whether the check confirms/warns/skips.

## Extraction-scorecard preflight (advisory)

When a KB is present (legacy-rebuild lane), run the Extraction Completeness Contract check BEFORE processing KB claims so `plan` builds on extraction whose gaps are visible:

```bash
bash "<plugin-root>/scripts/validate-extract-census.sh" --kb-dir="<kb-dir>" --quiet
# branch on the exit code; read <kb-dir>/.extract-census-state.json ONLY on non-zero
```

Interpret the verdict (per `extract-intelligence/SKILL.md §Step 5`):
- **SKIP** (no `census.json` — a legacy numbered-tree KB) → proceed normally; absence is not a blocker.
- **PASS** → proceed. Carry the KB's `[OPEN]` items through to `context.md ## Open Questions` as OQ candidates (honest gaps, not errors).
- **FAIL** (unclaimed / uncited / phantom census files, missing sections, non-Mermaid flows) → surface prominently as an `Extraction quality (advisory)` line in the Step 7 report and recommend re-running `extract-intelligence` for the owning module. Advisory — does NOT hard-block `plan`.

> A blocking enforcement gate must be a deterministic validator wired to a hook — prose that says "HALT" enforces nothing. Do not add prose claiming to HALT here without a backing validator.

## Consumption — PRD-kontrak grammar

1. **Read `README.md` first** — extract the `Reengineering Opportunities`
   section + the `Mutability Tier Distribution` table + the module
   quick-reference (recommended rebuild ORDER — module is the phasing unit).
   The Reengineering Opportunities seed `context.md ## Overview` (the
   reengineering goals, cited to the README).
2. **Read `<kb>/data-mutation-policy.md`** (KB root) when present — drives ERD
   freedom. Absent = no `[LOCKED]` entities were found → all-`[INTENT]`
   default.
3. **Read every `modules/*.prd.md`** — frontmatter (classification,
   criticality, `depends_on`, counts) + body claims. Confidence is
   default-verified: an UNMARKED cited claim routes as `[VERIFIED]`; only
   `[INFERRED]`/`[OPEN]` are tagged. Mutability tags as written; an untagged
   claim defaults to `[INTENT]`.
4. **`stages:` blocks** in a module PRD's §3 Flow are copied VERBATIM into the
   matching `context.md ## Flows` flow with the back-reference
   `_kb_source: [modules/<domain>.prd.md]` (followed by
   `validate-vault-flow-staging.sh` to prove staging was not dropped), and the
   matching Mermaid `stateDiagram` is emitted — never re-flatten.
5. **Multi-module scoping:** there is no `--phase` lane in this grammar —
   module IS the phasing unit, and the unit of `plan`'s self-slice (Step 2:
   one `context.md`, units written module by module). Consuming ALL modules
   is the default; to scope a vault to a subset, generate per the README's
   recommended order and record out-of-scope modules as explicit
   constraints/OQs, or point `plan` at a single module PRD (positional). A
   `--phase=N` flag against a PRD-kontrak KB → log
   "PRD-kontrak KB has no phase lane (module = phasing unit); flag ignored"
   and proceed (never halt).
6. **README `## ERD` / `## System Flow`** (multi-module) seed
   `context.md ## Data model` + `## Flows` skeletons — the rebuild shape,
   with legacy shape as reference only.
7. **`<kb>/decisions/ADR-*.md` with `Status: accepted`** (architecture
   advisor — `plugins/mega-sdd/references/architecture-advisor.md`): a recorded
   human decision is a legitimate input document (same source class as a PRD) —
   its `## Claims` block flows into the vault with the ADR as the citation, as
   a `context.md ## Decisions` `### D-NNN:` record (`**Source**:
   decisions/ADR-NNN.md`) that carries its target-architecture topology.
   `Status: proposed` is NEVER consumed as a decision — surface it as an OQ
   ("arsitektur target belum diputuskan — ADR-NNN masih proposed"). No
   `decisions/` dir = nothing to do (the advisor is optional).

## Consumption — legacy numbered-tree grammar

1. Read the KB README (`Reengineering Opportunities` + `Mutability Tier
   Distribution`); no tier markers at all (an older KB) → treat all claims as
   `[INTENT]`.
2. Read `99-rebuild-architecture/data-mutation-policy.md` (ERD freedom;
   absent → all-`[INTENT]`).
3. Read the `10-domains` files; extract claims with confidence + mutability
   markers (this grammar writes explicit `[VERIFIED]` tags).
4. `--phase=N` (scope generation to Phase N of `suggested-phasing.md`;
   default `--phase=1`): read `99-rebuild-architecture/suggested-phasing.md`, count
   `## Phase` headings → `phase_total`; out-of-range N → invocation-time
   error; absent/zero headings → single-phase fallback. Persist
   `phase`/`phase_total` to vault.json through the Step-3
   `derive-vault-json.sh --patch` (never hand-written).
5. `99-rebuild-architecture/suggested-system-flow.md` seeds the
   `context.md ## Flows` skeletons (the rebuild shape);
   `module-dependency-graph.md` recorded as the `context.md`
   frontmatter pointer `kb_module_graph: <path>` (seeds the module
   derivation — `plan/references/decomposition-rails.md`);
   `50-integrations/` — every contract becomes a `[LOCKED]` constraint or a
   templated OQ. Never silently dropped: an extraction that found integrations
   MUST surface every one of them as constraint or OQ.

## Tier-aware routing per claim

| Marker pair | Vault treatment | Vault location |
|---|---|---|
| `[VERIFIED][LOCKED]` (PRD-kontrak: unmarked-cited + `[LOCKED]`) | Verbatim — exact legacy field name, type, constraint preserved | `context.md ## Constraints` + Hard Rule emission for execute-bolts; tagged `mutability_source: kb_locked` |
| `[VERIFIED][INTENT]` (unmarked-cited + `[INTENT]`/untagged) | Outcome goal — state transition + business rule preserved; implementation references rebuild proposal | `context.md ## Flows` (outcome); tagged `mutability_source: kb_intent` |
| `[VERIFIED][ARTIFACT]` | Vault `## Open Questions` — default "discard unless preserve required" | `context.md ## Open Questions`; tagged `mutability_source: kb_artifact`, default resolution: discard |
| `[INFERRED][LOCKED]` | Single confirmation question (high stakes); default "keep as LOCKED" pending user veto | OQ until confirmed, then promoted per the `[VERIFIED][LOCKED]` rule |
| `[INFERRED][INTENT]` | Vault body with note "INFERRED — confirm in dev"; outcome already captured | `context.md ## Flows` with `[INFERRED]` annotation |
| `[INFERRED][ARTIFACT]` | Skip the vault entry entirely; log to `_diagnostics/kb-skipped-artifacts.md` | Diagnostic only |
| `[OPEN][?]` | Vault `Open Question` — answering resolves both axes | `context.md ## Open Questions` |
| §6 entry already `[x]`-resolved (KB-stage resolution via resolve-oq KB mode) | Vault OQ born PRE-RESOLVED — the tag, the stakeholder answer, and its `Resolved (stakeholder, <date>)` provenance carried verbatim; the deriver maps `[x]` → `resolved` automatically | `context.md ## Open Questions` as `[x]`; a §6 `[~]` carries over as out-of-scope |

## ERD freedom

- **PRD-kontrak:** the README `## ERD` (multi-module) or the module PRD's §4
  entities (single-module) propose the rebuild shape. `[LOCKED]`
  entities/fields from `<kb>/data-mutation-policy.md` retain the legacy shape
  verbatim (name, type, constraints, validation rules).
- **Legacy tree:** `99-rebuild-architecture/suggested-erd.md` is the proposed
  new shape — NOT the legacy `30-data-model/conceptual-erd.md`; same
  `[LOCKED]` exception via `data-mutation-policy.md`.

## KB-derived Hard rules + Anti-patterns

Step 4 pulls these into each relevant unit's `## Hard rules` (machine-validated at bolt time) or `## Anti-patterns` (informational) — the bridge from KB intelligence → per-unit pre/post-flight enforcement. Governing rule: KB gotchas → Anti-patterns by default; promoted to Hard rules ONLY when the KB marker is `[VERIFIED]` AND the gotcha is mechanically detectable.

- **KB-derived hard rules** (only when KB present AND marker `[VERIFIED]` — PRD-kontrak: an unmarked cited entry): a `## 5. Edge Cases & Gotchas` entry (legacy numbered tree: `## 9. Edge Cases & Gotchas`) `[VERIFIED]` AND mechanically detectable → `DO NOT modify <gotcha-anchor-file>`; a `## 8. State Machine` entry (legacy numbered tree) `[VERIFIED]` for a function with stable signature → `function <name> MUST preserve signature: <sig>`. `[INFERRED]`/`[OPEN]` → NOT promoted (Anti-patterns instead).
- **KB-derived Anti-pattern suggestions** (informational, not machine-validated): every `## 5. Edge Cases & Gotchas` entry (legacy numbered tree: `## 9.`) → suggested Anti-pattern with brief description + KB anchor; every "do-not-replicate" critical finding in the KB README → suggested Anti-pattern.

**Anti-halu rails:** NEVER promote `[INFERRED]`/`[OPEN]` KB items to Hard rules (Anti-patterns only). NEVER suggest a Hard rule whose anchor file isn't in the project's tracked source (probe the symbol index / the file on disk — `hard_rule_unanchored` would fire at bolt time — keep it an Anti-pattern). Suggestions are RECOMMENDATIONS — `plan` reviews + filters them per unit (Step 4) before inserting into units.

## KB coverage rule (Step 5)

A KB run passes `--kb=<kb-dir>` in place of `--prd` to `validate-plan-coverage.sh --cwd=<root> --kb=<kb-dir> --vault=<vault>` (`plan/references/plan-procedure.md` Step 5, row 4). It checks the KB's requirement headings against the units:

- **Censused headings.** PRD-kontrak: every H2/H3 of every `<kb>/modules/*.prd.md` except `1. Purpose` and `6. Open Questions`. Legacy numbered tree (no `modules/`): every H2/H3 of `<kb>/10-domains/**/*.md` except `1. Purpose`, `10. Open Questions` and `11. Source References`. The leading section number is ignored when matching these names. Headings under an explicit Out-of-scope section are not censused.
- **A unit covers a heading** when its `prd_source` names that module or domain file plus the heading slug (`<kb>/modules/<m>.prd.md#<slug>`; numbered tree `<kb>/10-domains/<d>.md#<slug>`), or a `:line` inside the heading's range.
- **An OQ covers a heading only when it quotes the heading AND names the module or domain file** (`<m>.prd.md` / `<d>.md`). Every module carries the same section names, so a quote without the file name covers nothing. The quote is the heading text as written, section number included (case-insensitive). An OQ the AI already decided (`resolved_by: ai`) does not count.
- **Out-of-scope modules** (§Consumption — PRD-kontrak grammar, item 5): a constraint row does not count. Each censused heading of such a module needs an OQ that quotes it and names the module file.
- **Exit 1** → halt `plan_coverage_gap`. Each gap names its file. Fix it with a unit whose `prd_source` names the heading, or an OQ that quotes the heading and names the file. Never patch the census. While the coverage state is missing or FAIL, `validate-preflight.sh --predictive` refuses the `execute-bolts` hop.

## KB Q&A loop

Short because the KB covers most gaps. The targets are `[business]` OQs in
`context.md ## Open Questions`; the P1 ones join `plan`'s single Step-6
batched ask (≤4 questions — overflow stays `blocking`, per the Step-6
overflow rule). Primary targets:

- `[INFERRED][LOCKED]` items (highest stakes — confirm the preservation requirement).
- `[ARTIFACT]` items flagged for discard (confirm with the user before discarding).
- Reengineering Opportunities (confirm the rebuild team accepts the proposal).

## KB auto-detection

Priority order, first hit wins — the same probe `derive-state.sh` runs
(`state_probes.probe_knowledge_base`, `probes.knowledge_base` in state.json):

1. `knowledge_base: <dir>` in `.mega-sdd/config.yaml` — a KB that lives
   OUTSIDE the project tree (monorepo: one KB submodule shared by the FE and
   BE apps, e.g. `../../knowledge/<repo>/.mega-sdd/knowledge-base/`).
   Relative to the project root, absolute allowed, `~` expanded. Configured
   but `README.md` missing → treated as ABSENT (never falls through to an
   in-project copy — a stale local KB silently winning is the bug the key
   prevents); state.json carries `configured_missing` + a note.
2. `.mega-sdd/knowledge-base/README.md` (canonical default) →
   `docs/knowledge-base/README.md` (legacy) →
   `docs/mega-sdd/knowledge-base/README.md` →
   `old-reference/knowledge-base/README.md`.

If detected AND no positional PRD argument → set
`--kb=<detected-dir>` implicitly (for a configured KB that is the configured
path as written, e.g. `--kb=../../knowledge/<repo>/.mega-sdd/knowledge-base`).
Confirm with the user before proceeding — on the chain that is the front
door's one upfront confirmation, never a second ask inside `plan`. An
explicit `--kb=` always wins.

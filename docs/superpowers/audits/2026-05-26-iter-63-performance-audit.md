# Iter 63 Performance Audit — mega-sdd v3.41.0

**Date:** 2026-05-26
**Scope:** Sharpness audit for v4.0.0-candidate refactor — not a bug audit.
**Method:** Static measurement (line counts, structure, reference fan-out) + semantic comparison (skill purpose / trigger overlap / consumer wiring).

---

## TL;DR

- **Total SKILL.md content: 8,174 lines across 15 skills.** Mean 545 / median 561 / max 1,267 (`generate-intent`).
- **Total reference content: ~10,132 lines across ~50 files** under per-skill `references/` + 8 files under top-level `plugins/mega-sdd/references/`.
- **Heaviest SKILL.md (>300 lines):** 9 of 15 skills — `generate-intent` (1,267), `execute-bolts` (1,012), `generate-units` (826), `orchestrate-flow` (764), `detect-drift` (669), `scan-codebase` (607), `bind-codebase` (572), `resolve-oq` (561), `diff-vault` (514), `extract-intelligence` (335).
- **Heaviest references (>200 lines):** 19 of ~50 — top three are `generate-intent/references/vault-contract.md` (838), `orchestrate-flow/references/handoff-contract.md` (715), `memory/references/memory-schema.md` (516).
- **TRIM candidates:** 9 (mostly the heavy SKILL bodies — move historical changelogs + worked examples to `references/<skill>-rationale.md`).
- **CONSOLIDATE candidates:** 4 (auto.md ↔ orchestrate-flow.md command duplication; diff-vault ↔ detect-drift outcome tables; emit-fsd ↔ emit-agents-md as the "interop emitter" family; predictive-checks.md ↔ orchestrate-flow Step 3.5).
- **DEFER candidates (auto-invoke → opt-in):** 3 strong (emit-fsd, list-modules end-of-chain summary, emit-agents-md), 1 borderline (analyze-parallelism — used by execute-bolts but rarely user-read).
- **AMBIGUOUS skill pairs:** 3 (`diff-vault` vs `detect-drift` vs `resolve-oq --binding`; `auto` vs `orchestrate-flow --deep`; `using-mega-sdd` vs `orchestrate-flow`).
- **CHANGELOG:** 5,663 lines, 82 version entries (3.0.0 → 3.41.0). Recent iters average ~70 lines per entry — bordering noise.
- **Halt taxonomy:** ~60+ distinct `type:` values in shipped contracts (handoff_contract + per-skill halt blocks). ~10–12 cold-firing per Iter 56/62 audits' own admission.

---

## Findings

### TRIM (skill body trim — move explanation / changelogs / examples to reference)

**T-001 — `generate-intent/SKILL.md` (1,267 lines) — HEAVIEST in plugin.**
- `plugins/mega-sdd/skills/generate-intent/SKILL.md:13-141` — 130 lines on "Invocation modes" (Mode A / Mode B / KB sub-mode / `--scan=` overlay) intermixed with detection rules. Move §13-117 detection rules into already-existing `references/from-prompt-mode.md` (currently 294 lines but doesn't carry the deterministic detection table).
- `plugins/mega-sdd/skills/generate-intent/SKILL.md:801-877` — `## File-by-file content guide` is essentially a re-statement of what's in `references/templates/00-index.md` through `06-constraints.md`. Replace with a 10-line pointer.
- `plugins/mega-sdd/skills/generate-intent/SKILL.md:368-614` — squad-partition workflow inlined here AND duplicated in `references/squad-partition.md` (65 lines). Either delete the reference (current state is the canonical one) or trim the SKILL body down to a 30-line procedure and push detail into the reference.
- **Estimated trim:** 400–500 lines (32–40%) without behavior change.

**T-002 — `execute-bolts/SKILL.md` (1,012 lines).**
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md:187-275` — "T2 Section Priority + Truncation" + starterkit T2 read/build/inject (§4.5.b-*) sub-procedure. ~90 lines that duplicate `plugins/mega-sdd/references/starterkit-context-schema.md`. Move to a new `references/t2-context-protocol.md`.
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md:438-543` — Hard-rule post-flight + violation handling. ~105 lines that are explanatory; the operational rules are in `references/hard-rule-grammar-v2.md` (172 lines). Trim SKILL body to a short procedural callout.
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md:367-437` — Saga compensating actions (Iter 45). 70 lines on `--rollback` flag — used in ≤5% of runs per CHANGELOG mentions. Move to `references/saga-rollback.md` (new) and reference inline.
- **Estimated trim:** 300–400 lines (30–40%).

**T-003 — `generate-units/SKILL.md` (826 lines).**
- `plugins/mega-sdd/skills/generate-units/SKILL.md:34-688` — 650-line monolithic `## Procedure` with no further `##`-level subdivision (grep returned zero `###` between 34 and 688). This is the symptom of "everything inlined." Cut it with `###` boundaries matching the existing `references/unit-schema.md` (258 lines) sections and refactor body to a 200-line procedural skeleton.
- **Estimated trim:** 350–450 lines (45%).

**T-004 — `orchestrate-flow/SKILL.md` (764 lines).**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md:222-340` — handoff-validation gate (Iter 33 + Iter 40 + Iter 43 + Iter 60). 120 lines describing checks vi/vii/viii/ix that are already encoded in `references/handoff-contract.md`. Replace with a 30-line procedural skeleton referencing the contract.
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md:480-510` — Hybrid drift gate phase (Iter 30). Used in `mode=existing` only — push into `references/drift-gate.md` (new).
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md:514-697` — Convergence loops section (183 lines). Mostly halt taxonomy tables (cycle-eligible / always-stop / soft). This is a contract — belongs in a reference, not skill body.
- **Estimated trim:** 350–450 lines (45–60%).

**T-005 — `detect-drift/SKILL.md` (669 lines) + `diff-vault/SKILL.md` (514 lines) — DUPLICATE PROSE.**
- `plugins/mega-sdd/skills/detect-drift/SKILL.md:7-39` vs `plugins/mega-sdd/skills/diff-vault/SKILL.md:7-37` — opening sections ("Core principle: vault has two ground truths" / "vault has memory") are 32-line + 30-line variants of "compare X vs Y; surface conflicts; user decides." Boilerplate; ~50% overlap.
- Both contain a `## --auto flag (v0.3+)` section with identical 6-row table. Centralize into `references/auto-flag-contract.md` (new), reference from both.
- Both contain a `## Quality bar` and `## When to push back on the user` block (lines 421-440 in diff-vault; lines 459-484 in detect-drift). Move to a shared SKILL author reference.
- **Estimated trim:** 150–200 lines combined.

**T-006 — `bind-codebase/SKILL.md` (572 lines) + `scan-codebase/SKILL.md` (607 lines).**
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md:262-462` — 200 lines on Step 10.5 "Deep-scan stage" sub-steps 10.5.0–10.6. This is a sub-procedure of starterkit detection. Existing reference: `references/deep-scan-prompts.md` (310 lines). Move the orchestration logic there; SKILL body keeps a 30-line procedural skeleton.
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md:97-323` — implementation state map + field-level diff + halt-YAML examples. ~226 lines. References dir already has `binding-contract.md` (145 lines) — extend that and trim SKILL body.
- **Estimated trim:** 250–300 lines combined.

**T-007 — `resolve-oq/SKILL.md` (561 lines).**
- `plugins/mega-sdd/skills/resolve-oq/SKILL.md:262-485` — Changelog template + multiple worked examples + binding-mode + memory + auto-accept (~220 lines). `references/recommendation-context.md` exists (262 lines). Move worked examples + binding-mode walkthrough into the reference.
- **Estimated trim:** 150 lines.

**T-008 — Cross-cutting: every skill body has version-stamped `(v2.6.0+, Iter 30)` / `(v3.4.0+, Iter 53)` parenthetical at section headers.**
- Strict count via grep: ~120+ such version stamps inline. These are useful in CHANGELOG but pollute skill-body reading. Strip when v4.0 ships (one-time delete pass per skill). Reduces visual noise even when total line delta is small (~120 lines × ~10 chars = trivial bytes but every section header gets cleaner).

**T-009 — CHANGELOG.md (5,663 lines, 82 versions).**
- Recent entries (3.36.0 onward) average ~70 lines per minor version with sub-headers `**X-001 (P2) — ...**` for each closed audit item. This is forensic detail useful at the time but rapidly becomes archeology.
- Proposal: rotate >3-month-old entries to `CHANGELOG-ARCHIVE.md`. Keep top of file as "last 10 versions" + summary roll-ups.
- **Estimated trim from main CHANGELOG:** 4,000+ lines.

---

### CONSOLIDATE (merge candidates)

**C-001 — `commands/auto.md` (129 lines) is a thin wrapper around `commands/orchestrate-flow.md` (31 lines).**
- `plugins/mega-sdd/commands/auto.md:6` says: "Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` flags."
- `auto.md` only adds: input shape detection (lines 10-37), starterkit detection mode picker (39-51), multi-scope picker (53-77), and auto-integrated diagnostics table (79-92).
- **Verdict:** `auto.md` is NOT a pure alias — it carries the input-detection logic + scope picker UX. But the SKILL `orchestrate-flow` already documents starterkit detection in `references/routing-rules.md`. The duplication is real: input detection rules in `auto.md:10-37` aren't enforced anywhere else (`orchestrate-flow.md:24` just says "Follow `skills/orchestrate-flow/SKILL.md` procedure"). Either:
  - (a) Merge `auto.md` body into `orchestrate-flow/SKILL.md` Step 1, delete `auto.md`, and add `auto:` as an alias in `.claude-plugin/plugin.json`; OR
  - (b) Make `orchestrate-flow` the lower-level command (no input detection) and `auto` the user-facing entry point that wraps input shape detection — but document the boundary explicitly.
- Recommendation: (a). The "single command users need" doctrine in `auto.md:2` (description "this is the ONE command users need") is contradicted by `orchestrate-flow` having its own command.

**C-002 — `emit-fsd` (246 lines) + `emit-agents-md` (171 lines) + `commands/list-modules.md` (99 lines) form a "post-pipeline interop emitter" family.**
- All three: auto-invoked end-of-chain (per `orchestrate-flow/SKILL.md:359-366`), produce derived artifacts from vault state, no user input needed.
- Consolidate as `emit-interop` skill with sub-modes `--target=fsd|agents-md|modules-summary`. Reduces skill count 3→1 and lowers cognitive load on "which emitter does what."

**C-003 — `diff-vault` (514) and `detect-drift` (669) — should they be one skill with two modes?**
- Both compare "two ground truths" and surface conflicts.
- `diff-vault`: PRD_old vs PRD_new (both are spec documents).
- `detect-drift`: vault vs codebase (one spec, one implementation).
- They share: confidence-rated findings, `--auto` flag contract, "user decides — don't pick a side" principle, identical "outcome categories" table shape.
- Differ: traversal axis (spec/spec vs spec/code), what counts as a finding.
- **Verdict:** core algorithm is the same — `compare(source_A, source_B) → categorized findings + user resolution`. Worth a v4 refactor pass: extract a shared `compare-and-resolve` reference + thin per-mode skills. Or merge as `reconcile --vault-vs-prd | --vault-vs-code`.

**C-004 — `predictive-checks.md` (354 lines) vs `orchestrate-flow/SKILL.md` Step 3.5 invocation.**
- The reference (354 lines) enumerates per-skill preflight checks. The SKILL body (lines 160-200 area, per the grep noise above) describes Step 3.5 read-protocol + halt firing.
- Iter 56 + Iter 62 added many checks (cold-halt anticipation, install-deps preflight, emit-fsd preflight, memory preflight). Several of these are per the audit "deferred — runtime-infeasible (cold-firing halts)" (CHANGELOG line ~84). If they never fire, they bloat both files.
- Consolidate: keep ONLY checks with confirmed firing history. Move uncertain/cold to `references/predictive-checks-experimental.md` (gated by `--enable-experimental-checks`).

---

### DEFER (auto-invoke → opt-in)

**D-001 — `emit-fsd` (Iter 54+) — auto-invoked at chain end. Low user-consumption signal.**
- Produces `<vault>/fsd/FSD.pdf` + FSD.md + citation-map.json. Requires pandoc + LaTeX.
- CHANGELOG mentions (Iter 58, 62) all focus on internal fix-ups (drift callout styling, citation slot extraction, missing_sources population) — NOT external user feedback about FSD value.
- Pre-flight requirements (`plugins/mega-sdd/references/tooling-install.md`) make FSD HIGH-friction for users without pandoc.
- Recommendation: **opt-in via `--fsd` flag, not opt-out via `--no-fsd`.** Add to `references/reading-map.md` as Stage 7 only when user asks "where's my deliverable for stakeholders."

**D-002 — `emit-agents-md` (171 lines) — auto-invoked end-of-chain.**
- Produces `AGENTS.md` (or `.mega-sdd.md` sibling) for tool-agnostic interop.
- Use case: a different agent system (not Claude / mega-sdd) reads the AGENTS.md as a re-hydration.
- For most users running mega-sdd in Claude Code natively, AGENTS.md is dead weight (gets re-emitted at every chain end → noise in git diffs).
- Recommendation: opt-in via `--agents-md` flag. Or: emit only if `~/.mega-sdd/memory/config.yaml` sets `emit_agents_md: true`. (The config flag already exists per `orchestrate-flow/SKILL.md:364`; just flip default to `false`.)

**D-003 — `list-modules` end-of-chain table.**
- Auto-invoked end-of-chain (per `orchestrate-flow/SKILL.md:363`). Produces per-module status table.
- Users running `--deep --auto` see this in chain output. But for single-phase / single-module projects, the table is one row → not informative.
- Recommendation: emit only when `count(modules) >= 2`. Otherwise skip silently.

**D-004 — `analyze-parallelism` pre-execute-bolts (BORDERLINE).**
- Auto-invoked before `execute-bolts` to compute wave plan. The wave plan IS consumed downstream → useful.
- But user rarely reads `analyze-parallelism` output directly (208 lines of command body).
- Recommendation: keep auto-invoke, but suppress chat output entirely in `--auto` mode — pass the plan as in-memory state to `execute-bolts`, only surface "wave plan: 3 waves, 7 bolts, est 2.3x speedup" one-liner in summary.

**D-005 — Memory review prompt at chain end (per `orchestrate-flow/SKILL.md:366`).**
- "N pending learning suggestions → review via `/mega-sdd:memory review`" — surfaces only when N>0. Already gated. Leave as-is.

**D-006 — `vault.json` `oqs[]` Auto-Classification Review section in `00-index.md`.**
- Per `references/vault-contract.md:229`, every vault generation appends an Auto-Classification Review section. For vaults with 0 auto-resolved OQs this is empty ceremony. Skip emission when empty.

---

### OVERLAP (skill boundary issues)

**O-001 — `diff-vault` vs `detect-drift` vs `resolve-oq --binding` — all three "reconcile X vs Y" skills.**
- `diff-vault`: vault vs new PRD.
- `detect-drift`: vault vs codebase.
- `resolve-oq --binding`: walks binding conflicts interactively.
- All three present similar UX: outcome categories, `--auto` flag, halt-on-conflict, user decides.
- See C-003 above. Plus `resolve-oq --binding` mode is essentially "interactive UI for bind-codebase's conflict list" — could be a sub-mode of `bind-codebase` rather than a separate skill.

**O-002 — `auto` command vs `orchestrate-flow` command (per C-001 + AMBIGUOUS A-001 below).**
- Description language in `auto.md:2` claims it's "THE primary mega-sdd command" / "the ONE command users need" — but `orchestrate-flow.md` exists as a parallel command. Documentation says one thing; surface area says another.

**O-003 — `using-mega-sdd/SKILL.md` (179 lines) overlaps with `orchestrate-flow` description.**
- `using-mega-sdd` is the auto-trigger anchor skill (per its own `description:`).
- `orchestrate-flow` is the orchestrator that gets auto-invoked.
- But `using-mega-sdd/SKILL.md:19-50` "Sharper auto-trigger" duplicates `auto.md` input shape detection logic. Three places (`using-mega-sdd`, `auto.md`, `orchestrate-flow/references/routing-rules.md`) tell parts of the same story.
- Recommendation: single source of truth in `references/routing-rules.md`; both `using-mega-sdd` and `auto.md` reference it.

**O-004 — `extract-intelligence` overlaps with `scan-codebase`.**
- `extract-intelligence`: legacy codebase → knowledge-base (tech-agnostic).
- `scan-codebase`: codebase → codebase-map.md (tech-specific).
- Both walk a codebase, both emit structured docs, both can dispatch wave-based subagents (per `extract-intelligence/references/wave-dispatch-templates.md` and `scan-codebase/references/deep-scan-prompts.md`).
- The differentiation (greenfield rebuild vs brownfield bind) is real, but the implementation could share a `walk-codebase` reference. Today both reinvent traversal.
- Consider in v4: shared `codebase-walker` engine, two output adapters.

---

### HEAVY (large skills/refs that limit lazy loading)

**H-001 — Skill bodies > 300 lines (lazy-load failure risk):**

| Skill | Lines | Should be |
|---|---|---|
| `generate-intent` | 1267 | ≤500 |
| `execute-bolts` | 1012 | ≤500 |
| `generate-units` | 826 | ≤400 |
| `orchestrate-flow` | 764 | ≤400 |
| `detect-drift` | 669 | ≤350 |
| `scan-codebase` | 607 | ≤300 |
| `bind-codebase` | 572 | ≤350 |
| `resolve-oq` | 561 | ≤300 |
| `diff-vault` | 514 | ≤300 |
| `extract-intelligence` | 335 | ≤300 |

When the assistant loads a SKILL.md, the whole body counts against context. v3.41.0 is shipping ~8K lines of SKILL bodies before any reference fetch.

**H-002 — Reference files > 200 lines (top 19):**

| File | Lines |
|---|---|
| `generate-intent/references/vault-contract.md` | 838 |
| `orchestrate-flow/references/handoff-contract.md` | 715 |
| `memory/references/memory-schema.md` | 516 |
| `execute-bolts/references/bolt-dispatch-prompt.md` | 399 |
| `extract-intelligence/references/wave-dispatch-templates.md` | 381 |
| `orchestrate-flow/references/predictive-checks.md` | 354 |
| `generate-units/references/defensive-generation.md` | 351 |
| `extract-intelligence/references/knowledge-base-schema.md` | 344 |
| `scan-codebase/references/deep-scan-prompts.md` | 310 |
| `generate-intent/references/from-prompt-mode.md` | 294 |
| `emit-agents-md/references/agents-md-schema.md` | 278 |
| `generate-intent/references/templates/00-index.md` | 275 |
| `resolve-oq/references/recommendation-context.md` | 262 |
| `generate-units/references/unit-schema.md` | 258 |
| `emit-fsd/references/fsd-template.md` | 258 |
| `emit-fsd/references/section-mapping.md` | 241 |
| `generate-units/references/modules-schema.md` | 227 |
| `references/paths.md` | 213 |
| `references/starterkit-context-schema.md` | 186 |

`vault-contract.md` at 838 lines is the heaviest. Sections grep-counted: 37 `###` headers. It's a single large schema doc. Possible split: `vault-contract-schema.md` (vault.json shape) + `vault-contract-oq.md` (OQ rules) + `vault-contract-constitution.md` (constitution.md) + `vault-contract-concurrency.md` (lock contract). Each becomes ~200 lines.

**H-003 — Skills with > 4 reference files:**

| Skill | Reference count | Files |
|---|---|---|
| `generate-intent` | 13 | vault-contract.md, from-prompt-mode.md, legacy-retrofit-prompt.md, scope-picker.md, squad-partition.md, 8 templates |
| `execute-bolts` | 6 | bolt-contract.md, bolt-dispatch-prompt.md, hard-rule-grammar-v2.md, propose-and-confirm-prompt.md, squad-subagent.md, superpowers-bridge.md |
| `generate-units` | 6 (+1 templates) | unit-schema.md, modules-schema.md, pagerank-targeting.md, defensive-generation.md, pbt-integration.md, adversarial-test-prompt.md |
| `orchestrate-flow` | 4 | checkpoint-protocol.md, handoff-contract.md, predictive-checks.md, routing-rules.md |
| `scan-codebase` | 3 (+queries/) | codebase-map-schema.md, deep-scan-prompts.md, tree-sitter-integration.md |

`generate-intent` 13 references is unmanageable. Templates (8 files) are essentially output templates and could move to a `_templates/` subdirectory not loaded under `references/`.

---

### AMBIGUOUS (unclear when to use)

**A-001 — `/mega-sdd:auto` vs `/mega-sdd:orchestrate-flow --deep`.**
- `auto.md:6` says "Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` flags."
- `orchestrate-flow.md:14` says `--deep` "lift the 3-sub-skill chain cap; chain auto-continues to pipeline-end."
- Difference: `auto` adds input-detection wrapper. `orchestrate-flow --deep` assumes the user already knows the entry phase.
- For a new user: which one to invoke first? Both exist as `/commands` — bad UX surface.
- **Fix:** one command, one skill. Either keep `/mega-sdd:auto` (deprecate `/mega-sdd:orchestrate-flow`) or vice versa. Per `using-mega-sdd/SKILL.md:21` the chosen primary is `/mega-sdd:auto`.

**A-002 — `extract-intelligence` vs `scan-codebase` — when?**
- Trigger keywords overlap: "scan codebase", "map this repo", "extract domain knowledge", "reverse engineer this legacy", "siapkan context codebase."
- Mental model: `extract-intelligence` for greenfield-rebuild (the legacy code is going away); `scan-codebase` for brownfield (the codebase stays, vault gets bound to it). But trigger phrases don't make this distinction obvious.
- **Fix:** Make trigger keywords mutually exclusive. `extract-intelligence` keeps "rebuild" / "rewrite in" / "migrate to" verbs; `scan-codebase` keeps "scan" / "map" / "init" / "bind."

**A-003 — `using-mega-sdd` skill is invisible to users.**
- It's an anchor skill (auto-triggered, no `/command`). Users see its effects (auto-routing to orchestrate-flow) but not its existence.
- When orchestration goes wrong (wrong skill auto-picked), users have no entry point to debug "why."
- **Fix:** Either rename `using-mega-sdd` → `mega-sdd-router` to clarify its role, or fold it into `orchestrate-flow`'s preamble (since `orchestrate-flow` is invoked first anyway).

**A-004 — `resolve-oq` and `resolve-oq --binding` — same skill, different audiences.**
- Default `resolve-oq`: stakeholder-facing, walks business OQs.
- `--binding` mode: engineer-facing, walks bind-codebase CONFLICTs.
- These are two different audiences with different UX needs. Default mode auto-triggers from `lanjut`/`proceed`; `--binding` mode auto-triggers from convergence loops.
- **Fix:** Either split into `resolve-oq` + `resolve-binding`, OR document the dual personality at the very top of the SKILL.

---

## Recommendations (ranked by impact / effort)

### High-impact, low-effort (do in v3.42-3.45):

1. **Merge `commands/auto.md` into `commands/orchestrate-flow.md`** (C-001 / A-001) — delete `auto.md`, keep `/mega-sdd:auto` as alias in plugin.json. Eliminates the "which one do I use" question. Effort: ~1 hour. Touches: `commands/auto.md` delete, `commands/orchestrate-flow.md` expand, `using-mega-sdd/SKILL.md:21` update.

2. **Flip `emit-fsd` to opt-in** (D-001). Single flag flip in `orchestrate-flow/SKILL.md:359-366` table + `commands/auto.md:79-92` table. Removes pandoc dependency from the default chain. Effort: ~30 min.

3. **Flip `emit-agents-md` default to `false`** (D-002). Config flag already exists; just flip the default. Effort: ~15 min.

4. **Strip version-stamp parentheticals** from skill body section headers (T-008). One sed pass per skill. Net reduction ~150 lines visual noise, zero behavior change. Effort: ~30 min.

5. **Suppress `analyze-parallelism` chat output in `--auto` mode** (D-004). Reduces per-run chat verbosity. Effort: ~30 min.

6. **Skip Auto-Classification Review section + list-modules table when count==0/1** (D-003 / D-006). Effort: ~30 min.

### High-impact, medium-effort (do in v3.45-3.50):

7. **Split `vault-contract.md` (838 lines) into 4 files** (H-002): schema / OQ / constitution / concurrency. Lazy-loading wins. Effort: ~3 hours.

8. **Trim `generate-intent/SKILL.md` from 1,267 → ~600 lines** (T-001). Move detection rules + worked examples + file-by-file content guide to references. Effort: ~4 hours.

9. **Trim `orchestrate-flow/SKILL.md` handoff-validation gate + convergence loops to references** (T-004). Cuts ~300 lines from SKILL body. Effort: ~3 hours.

10. **Centralize duplicate `--auto` flag contract + Quality bar / push-back sections** (T-005). New shared reference, ~5 skills reference it. Effort: ~2 hours.

11. **Rotate >3-month-old CHANGELOG entries to CHANGELOG-ARCHIVE.md** (T-009). Reduces main CHANGELOG by ~4,000 lines. Effort: ~1 hour.

12. **Move `generate-intent/references/templates/` out of `references/`** (H-003). Templates aren't lazy-loaded; they're output scaffolds. New `output-templates/` dir. Effort: ~1 hour.

### Medium-impact, high-effort (consider for v4.0 major):

13. **Consolidate `emit-fsd` + `emit-agents-md` + `list-modules` end-of-chain emitters into `emit-interop`** (C-002). Effort: ~1 day. Risk: medium (3 commands → 1 command rename).

14. **Consolidate `diff-vault` + `detect-drift` + `resolve-oq --binding` into a `reconcile` skill family** (C-003 / O-001). Effort: ~2 days. Risk: high (3 skill rename + handoff contract changes).

15. **Trim `execute-bolts` from 1,012 → ~500 lines** (T-002). Effort: ~6 hours.

16. **Trim `generate-units` from 826 → ~400 lines, splitting the 650-line monolithic `## Procedure`** (T-003). Effort: ~6 hours.

17. **Audit + cull cold-firing halt types from the ~60-type taxonomy** (predictive-checks deferred items). Effort: ~4 hours.

### Lower priority:

18. **Rename `using-mega-sdd` → `mega-sdd-router`** (A-003).

19. **Disambiguate `extract-intelligence` vs `scan-codebase` trigger keywords** (A-002).

20. **Tighten `resolve-oq` dual-mode UX** (A-004).

---

## Per-skill scorecard

| Skill | SKILL.md lines | Refs count | Auto-invoke? | Trim potential | Consolidate w/ |
|---|---|---|---|---|---|
| `generate-intent` | 1267 | 13 (incl. templates) | No (entry point) | **HIGH** (-500) | — |
| `execute-bolts` | 1012 | 6 | No (terminal) | **HIGH** (-400) | — |
| `generate-units` | 826 | 6 (+1 templates) | No | **HIGH** (-400) | — |
| `orchestrate-flow` | 764 | 4 | Yes (router) | **HIGH** (-350) | A-001: merge auto.md into here |
| `detect-drift` | 669 | 0 | Conditional (drift gate) | **MED** (-200) | C-003: w/ diff-vault, resolve-oq --binding |
| `scan-codebase` | 607 | 3 (+queries) | Yes (chain) | **MED** (-250) | O-004: share walker w/ extract-intelligence |
| `bind-codebase` | 572 | 2 | Yes (chain) | **MED** (-200) | — |
| `resolve-oq` | 561 | 1 | Conditional (convergence) | **MED** (-150) | C-003: --binding mode → bind-codebase? |
| `diff-vault` | 514 | 0 | No (PRD revision) | **MED** (-150) | C-003: w/ detect-drift |
| `extract-intelligence` | 335 | 2 | No (legacy entry) | **LOW** (-50) | O-004: w/ scan-codebase walker |
| `emit-fsd` | 246 | 4 | Yes (chain-end) | LOW | **C-002: w/ emit-agents-md, list-modules** |
| `install-deps` | 240 | 2 | No (pre-pipeline) | LOW | — |
| `memory` | 211 | 3 | Yes (per-phase) | LOW | — |
| `using-mega-sdd` | 179 | 0 | Yes (anchor) | LOW | O-003: into orchestrate-flow |
| `emit-agents-md` | 171 | 1 | Yes (chain-end) | LOW | **C-002: w/ emit-fsd, list-modules** |

---

## Specific things measured (per prompt)

1. **Skill body line counts:** above. 9 of 15 > 300 lines.
2. **Reference file counts per skill:** above. 3 skills > 4 refs: `generate-intent` (13), `execute-bolts` (6), `generate-units` (6).
3. **Auto-invoke chains in orchestrate-flow Step 6:** lint-units, analyze-parallelism, list-modules, emit-agents-md, emit-fsd, memory-review (6 invocations end-of-chain). Per `orchestrate-flow/SKILL.md:359-366`. Recommendations D-001/D-002/D-003/D-004 above narrow this.
4. **`/mega-sdd:auto` vs `/mega-sdd:orchestrate-flow`:** NOT a pure alias. `auto.md` adds input-shape detection + scope picker + diagnostics opt-out flags. But the divergence is undocumented and confusing. Merge recommended (C-001).
5. **Auto-generated artifact consumption:** Vault 7 files = primary consumed; AGENTS.md, FSD, routing-outcomes.md, install-outcomes.md = derivative; only used in specific scenarios. Defer (D-001 / D-002).
6. **CHANGELOG:** 5,663 lines / 82 versions. Trim recommended (T-009 — archive >3 months).
7. **Per-iter spec/plan docs:** Iter-NN audit docs in `docs/superpowers/audits/` are 7-15K each. Useful as historical record; not loaded by skills. Leave as-is, but rotate after milestone.
8. **Predictive checks:** 354 lines in `references/predictive-checks.md`. Iter 56 + Iter 62 added many — CHANGELOG line ~84 admits "remaining 16 findings either runtime-infeasible (cold-firing halts) or scenario-6 sweep bulk." Cull cold ones (Rec 17).
9. **Memory layer 3 scopes:** USER (~5 files), PROJECT (~5 files), VAULT (~3 files). Per chain run, only `~/.mega-sdd/memory/patterns.md` + `<project>/.mega-sdd/memory/decisions.md` + `<project>/.mega-sdd/memory/routing-outcomes.md` are typically touched. Others (`learning-log.md`, `config.yaml`, `install-outcomes.md`) are append-only / read-rarely. Leave as-is — write cost is low.
10. **Halt taxonomy:** ~60+ distinct `type:` values across handoff-contract + per-skill halts. Per CHANGELOG audit closures, several are documented but not test-exercised. Iter 56 audit C-005 (Iter 60 fixed) already showed "ungated ~50 per-skill metric fields" — same shape problem on halt types. Worth a coverage scan: which halt types have ever fired in scenario-N walkthroughs? Recommend audit pass in v4.0 prep.

---

## Anti-recommendations (things NOT to change)

- **`generate-intent/references/vault-contract.md` semantic content** — splitting the file is fine; deleting sections is NOT. It's the spec of the vault.
- **Halt protocol blocking rails** — never downgrade BLOCKING to WARNING per `plugins/mega-sdd/CLAUDE.md` "What we will NOT accept."
- **Vendored superpowers fallback** — `skills/_vendored/` is mandatory per CLAUDE.md "no third-party runtime dependencies." Don't trim.
- **`using-mega-sdd` anchor trigger logic** — it works invisibly; "fix" only via consolidation (Rec 18), not deletion.

---

## File-touch matrix for high-impact recommendations

| Rec | Primary files |
|---|---|
| Rec 1 (merge auto.md) | `plugins/mega-sdd/commands/auto.md` (delete), `plugins/mega-sdd/commands/orchestrate-flow.md`, `plugins/mega-sdd/.claude-plugin/plugin.json`, `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md:21` |
| Rec 2 (emit-fsd opt-in) | `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md:359-366`, `plugins/mega-sdd/commands/auto.md:79-92` |
| Rec 3 (emit-agents-md default off) | `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md:364`, `~/.mega-sdd/memory/config.yaml` default |
| Rec 4 (strip version stamps) | `plugins/mega-sdd/skills/*/SKILL.md` (sed pass) |
| Rec 7 (split vault-contract) | `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (split into 4), all readers |
| Rec 8 (trim generate-intent) | `plugins/mega-sdd/skills/generate-intent/SKILL.md`, `plugins/mega-sdd/skills/generate-intent/references/` (extend existing files) |
| Rec 11 (rotate CHANGELOG) | `CHANGELOG.md`, new `CHANGELOG-ARCHIVE.md` |

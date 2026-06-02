# Orchestrator-Baseline Intelligence Audit — mega-sdd v3.69.2

**Date:** 2026-06-02
**Lane:** baseline machinery + orchestrator/router/convergence + handoff schema + memory layer
**Prior audit verified against:** `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` (v3.24.0, Phase B → Phase C F1–F4)
**Framing:** Fork A vs Fork B per `plugins/mega-sdd/CLAUDE.md §Fork A scope`. SKILL.md *prose* is NOT enforced (model can no-op it; 0-for-4 track record Iter 64/65/66a/67). ONLY Claude Code hooks + deterministic validator scripts enforce behavior. Every finding carries `enforceable: Y/N`.

---

## Baseline: what intelligence machinery exists at v3.69.2

Plugin version confirmed `3.69.2` (`.claude-plugin/plugin.json`). The four Phase-C features and the Iter-34 candidates, verified against current code/hooks/references:

### F1 — Memory-driven routing → **NOT-DONE (prose-only)**

- **Design landed in prose:** `orchestrate-flow/SKILL.md` Step 2.7 (lines 77–94) "Memory-informed routing preflight" + `skills/memory/references/routing-outcomes.md` schema + Step 7.5 end-of-chain write (lines 410–430).
- **Enforcement check — FAILS:** No hook reads `routing-outcomes.md` to *make a routing decision*. The only hook touchpoint is `hooks/session-start` lines 243–283, which is a **corruption self-resolve guard** (renames a non-UTF8 / header-less file to `.corrupt-<ISO8601>`), not the Step 2.7 decision logic. The actual "filter rows by fingerprint → recommend/warn → override default chain" logic exists only as SKILL.md prose → silently no-oppable.
- **Verdict:** the *schema file* and *corruption guard* shipped; the *intelligence* (routing consumes outcomes) did NOT.

### F2 — Predictive halt detection → **NOT-DONE (prose-only)**

- **Design landed in prose:** `orchestrate-flow/SKILL.md` Step 3.5 (lines 169–200) + `skills/orchestrate-flow/references/predictive-checks.md` (354-line catalog).
- **Enforcement check — FAILS:** `ls scripts/ | grep predict` → nothing. `grep -rln predictive hooks/ scripts/` → nothing. Zero deterministic preflight runner; zero hook fires the catalog. Step 3.5 is pure prose the orchestrator may skip.
- **Verdict:** catalog doc exists; the precondition-registry runner does NOT.

### F3 — Schema validation gate → **PARTIAL (real hook path exists; the named Step 6.b gate is still prose)**

- **Shipped + ENFORCED:** `scripts/validate-handoff-yaml.sh` is wired into `hooks/stop` (lines 313–325 run it on the last assistant message when it contains `handoff:`) and `hooks/pre-tool-use` Branch 1a (lines 180–227 *block* any `mega-sdd:*` skill when `.handoff-validation-state.json` status==FAIL, with producer-self-fix allowance). This is a real Fork-A enforcement loop and a direct fix for the 4× prose-failure pattern.
- **Coverage delta (the live gap):** the validator enforces only **required {emitted_by, emitted_at, status, next_action}** (validate-handoff-yaml.sh line 208) + shallow base types (lines 227–245) + artifact-existence (lines 325–361). It does **NOT** enforce: `artifacts`/`blockers` as REQUIRED (handoff-contract.md marks both REQUIRED, lines 107/145); any CONDITIONAL field (scope, constitution, pbt, mutability, cycles, replay); the per-field TYPE table beyond base types; nesting.
- **CAUTION — do not conflate:** the validator is a *parallel Stop-hook path*. The orchestrate-flow **Step 6.b** validation gate it resembles (SKILL.md lines 233–329, with REQUIRED/CONDITIONAL/OPTIONAL + TYPE-table logic) is **still prose** and no-oppable. A reader must not assume Step 6.b is enforced — only the narrower Stop-hook validator is.
- A second slice, `scripts/validate-handoff-binding-units.sh` (Iter 67.6 slice 1), enforces OQ-ID propagation at the binding→units boundary (PostToolUse line 374; execute-bolts pre-tool-use Branch 1b lines 263–292). Narrow but real.

### F4 — Type-checked propagation → **PARTIAL (base types only; confidence/TYPE-table NOT typed)**

- Same validator covers status-enum + string + ISO8601 + list base types (validate-handoff-yaml.sh lines 227–245).
- **Gap:** the handoff-contract.md TYPE table (`array<T>`, `object {...}`, `sha256 hex`, nullable, enum-from-vault) is NOT machine-checked. Critically, **no confidence field is typed**: `grep grounding_confidence|classification_confidence handoff-contract.md` → 0 hits; `grep confidence validate-handoff-yaml.sh` → 0 hits. The Iter-33 dependency "F4 enables confidence-aware branching" therefore has no foundation laid.

### Iter-34 candidates (per prior audit §Iter 34+ candidates)

| # | Candidate | Verdict | Evidence |
|---|---|---|---|
| 8 | Confidence-driven adaptive behavior (orchestrator reads typed `confidence: float`, demotes to pause < threshold) | **NOT-DONE** | Confidence untyped in schema/validator (above). Convergence "≥0.80" is a hardcoded prose string (SKILL.md line 663 "≥0.80 per Iter 7"); no hook/validator reads any confidence value. D5 stays ABSENT. |
| 9 | Mid-chain memory re-read (re-evaluate outcomes slice to gate auto-loop) | **NOT-DONE** | SKILL.md line 744 "Skill reads from in-memory slice — no disk re-read"; §Memory layer is single-read-at-start (MEMORY-OQ-7). Convergence loop (lines 594–623) references no memory field. |
| 1 | generate-units: grounding_confidence consumption | **NOT-DONE (cross-lane)** | `grep grounding_confidence generate-units/SKILL.md` → 0; only a `confidence: HIGH\|MEDIUM\|LOW` frontmatter mention (line 784). No "## Grounding warnings" section. |
| 4 | resolve-oq: bolt-outcomes-aware OQ flagging | **NOT-DONE (cross-lane)** | `grep bolt-outcomes\|hard_rule_violated resolve-oq/SKILL.md` → 0. |
| 2 | detect-drift: convention alias awareness | **NOT-DONE (cross-lane)** | `grep established\|alias detect-drift/SKILL.md` → 0. |
| 3,5,6 | execute-bolts classifier-accuracy warning; diff-vault pre-label; extract-intel gotchas | **cross-lane — defer to per-skill auditor** | Out of orchestrator lane; not graded here to avoid fabrication. |
| 7 | D6 mode_migrate/memory_schema_mismatch exact-command next_action | **PARTIAL** | mode_migrate next_action still vague ("Confirm correct mode then re-run", SKILL.md line 471). |

**Net:** Of the four Phase-C features the prior audit declared as the closure for the three intelligence themes, **F1 and F2 are NOT-DONE (prose-only)** and **F3/F4 are PARTIAL** (a real but narrow Stop-hook validator shipped; the named Step 6.b in-orchestrator gate and the full TYPE/CONDITIONAL/confidence coverage did not). The orchestrator's *own control-flow intelligence* (smart routing, predictive halt, confidence branching, mid-chain memory) remains entirely unenforced prose.

---

## Findings table

| # | phase/area | observed gap | evidence (file:line) | root-cause | proposed output-signature | enforceable | machinery-check |
|---|---|---|---|---|---|---|---|
| O-1 | Predictive halt (F2) | Step 3.5 precondition registry is prose; no runner, no hook. Knowable halts (vault P0/P1 OQ count, repeated-fail bolt, constitution_hash mismatch, missing tree-sitter) fire reactively. | `orchestrate-flow/SKILL.md:169-200`; `references/predictive-checks.md` (whole file); `grep predictive hooks/ scripts/` → ∅ | Catalog written as prose for the model to "consult"; no deterministic preflight script and no PreToolUse branch. | A `scripts/validate-preflight.sh` that, for the proposed chain, runs each catalog check and writes `.preflight-state.json {status, fatal_check_id, warnings[]}`; PreToolUse blocks the next `mega-sdd:*` skill when a `fatal` precondition is unmet. | **Y** | NOT-DONE |
| O-2 | Smart routing (F1) | routing-outcomes consumed only by prose Step 2.7; routing stays CWD-signal-driven. No hook reads the log to recommend/warn. | `orchestrate-flow/SKILL.md:77-94`; `hooks/session-start:243-283` (corruption guard only) | Decision logic lives in skill prose; only the corruption-degradation path was hookified. | `scripts/analyze-routing-outcomes.sh` emits `.routing-recommendation.json {fingerprint, recommended_chain, warn_chains[], n_runs}`; SessionStart surfaces it as an anchor notice (advisory) — OR PreToolUse warns when the about-to-run chain matches a `converged=no` history row. | **Y** (advisory-surface) / partial | NOT-DONE |
| O-3 | Handoff schema completeness (F3) | Stop-hook validator enforces only 4 required + base types; `artifacts`/`blockers` REQUIRED and all CONDITIONAL fields (scope/constitution/pbt/mutability/cycles/replay) + full TYPE table unenforced. Step 6.b in-orchestrator gate is prose. | `scripts/validate-handoff-yaml.sh:208,227-245`; contract REQUIRED at `handoff-contract.md:107,145`; CONDITIONAL at `:153-179`; `SKILL.md:233-329` (prose gate) | Validator shipped as a walking-skeleton slice; contract grew (~50 per-skill fields) without extending the checker. | Extend validator: add `artifacts`/`blockers` to required set; evaluate each CONDITIONAL against vault.json state (scope_metadata/constitution.md presence); table-driven TYPE check (array<T>, object, sha256, enum, nullable). Same `.handoff-validation-state.json` block already gates downstream skills. | **Y** | PARTIAL |
| O-4 | Confidence consumption (D5/F4 + Iter-34 #8) | No confidence field typed; orchestrator branches on a hardcoded "≥0.80" prose string, not a typed field read from handoff/memory. | `grep confidence validate-handoff-yaml.sh` → ∅; `handoff-contract.md` has no `grounding_confidence`/`classification_confidence`; `SKILL.md:663` hardcoded threshold | Confidence never promoted from prose/chat-example to a typed schema field; convergence threshold never read from config/memory. | Add `next_action.confidence: float \| null` (TYPE-annotated) to handoff-contract.md; extend validator to type-check it; emit `.confidence-gate-state.json` when `< floor` so PreToolUse demotes auto-continue to user-review. Floor read from `config.yaml` not hardcoded. | **Y** | NOT-DONE |
| O-5 | Memory as intelligence vs transport | The whole chain-start memory read+slice+propagate is SKILL.md prose; no hook performs it. Even *transport* is unenforced at orchestrator level. Mid-chain re-read explicitly absent. | `SKILL.md:726-768` (§Memory layer prose); `SKILL.md:744` "no disk re-read"; `hooks/session-start` touches memory files only for corruption/model-tier guards (`:252,:538`) | MEMORY-OQ-7 single-read design implemented in prose only; convergence loop consults no memory field. | Lower-priority for hooking (transport, not a halt). At minimum: a Stop-hook breadcrumb asserting `memory_context` was present in emitted handoffs, so absence is observable in telemetry. Routing/auto-loop *consumption* is covered by O-1/O-2. | N (transport) / Y (presence-assert) | NOT-DONE |
| O-6 | Halt-recovery clarity (D6 / Iter-34 #7) | `mode_migrate` next_action stays vague ("Confirm correct mode then re-run"); no exact command. | `SKILL.md:471` | Prose next_action never tightened. | Replace with exact command (e.g., "set vault.json `mode: existing` then `/mega-sdd:orchestrate-flow --resume`"). | N (prose UX; 0-for-4 risk if it must be "enforced") | PARTIAL |

---

## Top 3 enforceable opportunities (ranked by ROI)

1. **O-1 — Predictive preflight runner wired into PreToolUse (F2 closure).** Highest ROI: the machinery pattern *already ships and is proven* — 7 code-delivery validators (`validate-flow-coverage`, `-sibling-consistency`, `-unit-spec`, `-ui-quality`, `-dispatch-prompt`, `-vault-oqs`, `-cross-cutting`) are already wired into `hooks/pre-tool-use` (lines 295–502) writing `.*-state.json` blocks. A `validate-preflight.sh` that pre-checks the catalog and emits a state block PreToolUse can gate on is a near-direct clone (low net-new risk), and it converts the entire predictive-halt theme from prose to enforced. Start with 2–3 highest-signal checks (vault P0/P1 OQ count before bind; constitution_hash mismatch; binary presence).

2. **O-3 — Extend `validate-handoff-yaml.sh` to full contract coverage (F3 closure).** The enforcement loop (Stop validator + PreToolUse block) already exists; this is *additive* to a live script. Add `artifacts`/`blockers` to the required set, CONDITIONAL evaluation against vault.json state, and a table-driven TYPE check. Closes the "~50 ungated per-skill fields" weakness the contract has accreted since Iter 32, with zero new wiring.

3. **O-4 — Type + gate `next_action.confidence` (D5/F4 + Iter-34 #8).** Promote confidence from prose to a TYPE-annotated handoff field, type-check it in the (now-extended, per O-3) validator, and emit a `.confidence-gate-state.json` so PreToolUse demotes auto-continue to user-review below a config floor. This is the first concrete win on the long-ABSENT confidence dimension and removes the hardcoded "≥0.80" prose string. Depends on O-3's validator extension as scaffolding.

**Why F1/O-2 ranks below these:** routing recommendation is best surfaced advisory (SessionStart notice), and an over-eager PreToolUse routing *block* risks false stops; lower enforceable confidence than O-1/O-3/O-4.

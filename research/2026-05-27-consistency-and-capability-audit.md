# Consistency Engineering & Capability Deepening Audit — mega-sdd v3.59.0

**Date:** 2026-05-27
**Baseline:** mega-sdd v3.59.0 (Iter 67.14), real-run artifacts from TF Import project
**Methodology:** Adversarial — per Iter 67 integrity audit discipline. "shipped/doc'd ≠ working." Only hook-enforced or artifact-proven capabilities count as real.
**Scope:** Analysis only — no code changes.

---

# Part 1 — Self-Audit: Consistency Engineering State

## 1.1 Per-Skill Enforcement Inventory

Each skill assessed on four axes: (S) output schema/contract exists, (E) enforcement surface, (H) handoff YAML emitted, (V) validator hook exists.

**Legend — Enforcement surface:**
- **[HOOK]** = Claude Code hook fires deterministically (SessionStart / PreToolUse / PostToolUse / Stop). Model cannot skip.
- **[HOOK-VALIDATE]** = Hook triggers validator script; PreToolUse blocks downstream on FAIL. Model cannot bypass.
- **[VERIFY-STEP]** = Explicit slash command runs deterministic script. User-invoked, not automatic.
- **[SKILL-PROSE]** = Skill body markdown instructs model to do X. Model may or may not execute. **Audit-confirmed unreliable** (0 of 16 telemetry events from prose instructions; Iter 64/66a/67 wire-up failures).
- **[NONE]** = No enforcement mechanism exists.

| # | Skill | Schema/Contract Doc | Enforcement Surface | Handoff YAML | Validator Script |
|---|---|---|---|---|---|
| 1 | `extract-intelligence` | `knowledge-base-schema.md` (11-section template, frontmatter fields) | [SKILL-PROSE] — subagent wave dispatch follows template; no hook validates output | ✅ Defined in handoff-contract.md | None |
| 2 | `generate-intent` | `vault-contract.md` (vault.json schema + 7 markdown file templates) | **[HOOK-VALIDATE]** — `validate-vault-oqs.sh` (PostToolUse Write); `validate-scope-flag.sh` (PreToolUse Skill) | ✅ Defined | `validate-vault-oqs.sh`, `validate-scope-flag.sh` |
| 3 | `scan-codebase` | `codebase-map-schema.md` (7-section markdown + YAML frontmatter) | [SKILL-PROSE] — output follows schema by convention; no validator validates map completeness | ✅ Defined | None (cache corrupt detected by SessionStart guard) |
| 4 | `bind-codebase` | `binding-contract.md` (verdict types, blocking rules, Implementation State Map) | **[HOOK-VALIDATE]** — `validate-vault-binding-coverage.sh` (PostToolUse Write); blocking gate on CONFLICTs is [SKILL-PROSE] enforced in `generate-units` body | ✅ Defined | `validate-vault-binding-coverage.sh`, `validate-handoff-binding-units.sh` |
| 5 | `generate-units` | `unit-schema.md` (required frontmatter, 8 body sections, hard-rule grammar) | **[HOOK-VALIDATE]** — `validate-unit-spec.sh` (PostToolUse Write); `validate-handoff-binding-units.sh` (OQ-ID carry) | ✅ Defined | `validate-unit-spec.sh`, `validate-handoff-binding-units.sh` |
| 6 | `execute-bolts` | `bolt-contract.md` (target_files whitelist, commit format, failure modes); `hard-rule-grammar-v2.md` | **[HOOK-VALIDATE]** — `validate-bolt-artifacts.sh` (PostToolUse Write); PreToolUse blocks on `.validation-blockers.json` FAIL; Hard Rule pre/post-flight via ast-grep | ✅ Defined | `validate-bolt-artifacts.sh` |
| 7 | `orchestrate-flow` | `handoff-contract.md` (full YAML schema with TYPE annotations); `routing-rules.md`; `predictive-checks.md` | **[HOOK-VALIDATE]** — `validate-handoff-yaml.sh` (Stop hook); PreToolUse blocks downstream on handoff-validation FAIL; predictive-checks preflight | ✅ (is the consumer) | `validate-handoff-yaml.sh` |
| 8 | `detect-drift` | DRIFT-REPORT.md structure (per SKILL.md) | [SKILL-PROSE] — no validator checks report completeness | ✅ Defined | None |
| 9 | `resolve-oq` | OQ resolution markers (per vault-contract.md §OQ-conventions) | [SKILL-PROSE] — vault.json regeneration after resolution is prose-instructed | ✅ Defined | `validate-vault-oqs.sh` (fires on vault doc Write) |
| 10 | `diff-vault` | VAULT-DIFF.md + vault.json update | [SKILL-PROSE] | ✅ Defined | None |
| 11 | `emit-fsd` | `fsd-template.md`, `section-mapping.md`, `.citation-map.json` (sha256-stamped) | **[HOOK-VALIDATE]** — `validate-fsd-slots.sh` (PostToolUse Write); `validate-pandoc-render.sh` (PostToolUse Bash pandoc) | ✅ Defined | `validate-fsd-slots.sh`, `validate-pandoc-render.sh` |
| 12 | `emit-agents-md` | `agents-md-schema.md` | [SKILL-PROSE] | ✅ Defined | None |
| 13 | `memory` | `memory-schema.md`, `learning-rules.md` | [HOOK] — SessionStart guard 9 cleans stale locks | ✅ Defined | None (stale-lock cleanup only) |
| 14 | `install-deps` | `os-detection.md`, handoff metrics | [SKILL-PROSE] | ✅ Defined | None |

**Tally:**
- Skills with [HOOK-VALIDATE] enforcement: **6 of 14** (generate-intent, bind-codebase, generate-units, execute-bolts, orchestrate-flow, emit-fsd)
- Skills with [SKILL-PROSE] only: **8 of 14** (extract-intelligence, scan-codebase, detect-drift, resolve-oq, diff-vault, emit-agents-md, memory, install-deps)
- Handoff YAML schema defined: **14 of 14** (all skills have a defined contract)
- Handoff YAML emitted in real runs: **UNVERIFIABLE** — Iter 67 audit found zero handoff validation events in telemetry; Stop hook validator added in v3.53.0 but not yet real-run-verified

## 1.2 Context Consistency Across Phases

What propagates vs. what drops at each handoff boundary, per real-run artifact evidence (TF Import, per Iter 67 audit §F):

| Boundary | Propagates (verified) | Drops (verified) | Unverifiable |
|---|---|---|---|
| extract-intelligence → generate-intent | KB `[VERIFIED]/[INFERRED]/[OPEN]` markers; `[LOCKED]/[INTENT]/[ARTIFACT]` tiers; domain file frontmatter | — | Phase number mapping (KB `suggested-phasing.md` → vault.json `phase` field) |
| generate-intent → scan-codebase | vault.json `scope_metadata` | — | `--scan=<map>` back-reference (scan runs before intent in starterkit-first mode) |
| generate-intent → bind-codebase | vault.json entities, flows, ADRs, OQs (full manifest) | — | OQ `resolution_mode` + `classification_confidence` auto-classifier output |
| scan-codebase → bind-codebase | `codebase-map.md` §2-6 content; `starterkit-context.yaml`; `shared-snapshot` sha256 | — | `precision_tier` (ast vs regex) impact on binding confidence |
| **bind-codebase → generate-units** | **CONFLICT-IDs: YES** (phase-1 verified, CONFLICT-1 in U-009/U-010/U-002); Implementation State Map (IMPLEMENTED/NEW/UNKNOWN) → `task_type` | **OQ-IDs: DROPPED** (27/27 OQs across both phases — systemic, not edge case). Confirmed by `validate-handoff-binding-units.sh` real-run 2026-05-27. | Hard Rules from binding's "Suggested Unit Hard Rules" (v1.4+) — semantic carry YES, formal citation UNKNOWN |
| generate-units → execute-bolts | Unit frontmatter (target_files, acceptance_test, hard rules, binding_refs); unit body (anchors, implementation steps) | — | Starterkit T2 slice injection (v2.7.0+) — defined but no bolts directory exists in TF Import to verify |
| execute-bolts → detect-drift | `shared-snapshot-schema.md` preflight/postflight.json; bolt-report.md | — | **Entire boundary UNVERIFIABLE** — no `bolts/` directory exists in any TF Import vault |

**Critical finding:** The binding→units OQ-ID drop is now **caught by a hook validator** (`validate-handoff-binding-units.sh` + PreToolUse block on `execute-bolts`). This is the only cross-phase consistency invariant that is hook-enforced. All other handoff field propagations rely on skill-body prose.

## 1.3 Enforcement Classification Summary

Extending the Iter 67 integrity audit's Component A-G framework:

| Category | Count | Evidence |
|---|---|---|
| **Hook-enforced (working)** | | |
| SessionStart anchor injection | ✅ Working (v3.48.0+ fixed `.mega-sdd` signal) | Iter 67.5 fix; verified by current hooks/session-start line 17 |
| SessionStart C1 self-resolve guards (9 guards) | ✅ Working | Python block in session-start hook; guards 1-9 implemented |
| PostToolUse ref_loaded telemetry | ✅ Working (under-counts) | 1+ real events in TF Import; Bash branch added Iter 67.5 |
| PostToolUse Write/Edit validators (6 scripts) | ✅ Working (partially real-run-verified) | `validate-handoff-binding-units.sh` real-run-verified; 5 others structurally complete |
| PreToolUse execute-bolts gate | ✅ Working | Reads `.validation-blockers.json`; real-run-verified |
| PreToolUse anti-self-bypass | ✅ Working | Blocks agent rm/mv/sed-i on state files |
| PreToolUse scope flag validation | ✅ Working | `validate-scope-flag.sh`; blocks invalid `--scope` |
| PreToolUse handoff validation gate | ✅ Working | Reads `.handoff-validation-state.json`; blocks downstream on FAIL |
| Stop hook turn_end_marker | ✅ Working (v3.48.0+) | Emits usage data; hook-debug.log diagnostic added |
| Stop hook handoff validation | ✅ Working | `validate-handoff-yaml.sh` at turn end |
| **Prose-described but NOT enforced** | | |
| Classifier output emission | ❌ Script exists, never invoked | `classify-iter.sh` — 0 invocations across all real runs |
| Anti-recursive budget guard | ❌ Script exists, never referenced | `check-recursion-budget.sh` — not in any SKILL.md |
| Plan/Act mode gating | ❌ No state file ever written | `.plan-pending` — 0 hits in any project |
| Skill invocation tracking | ❌ Low reliability | Most activations bypass Skill tool |
| Per-skill telemetry emission (halt_fired, activation_outcome) | ❌ 0 events in real runs | Prose-convention dependency; audit-confirmed failure |
| **Parked (Fork-B-future)** | | |
| Implicit re-plan detection | Parked | Needs mid-reasoning interception |
| Lazy-load tier enforcement | Parked | Needs mid-reasoning skip |
| Mid-turn intervention | Parked | Needs custom runtime |

## 1.4 Schema/Contract Enforcement Mechanisms

| Artifact | Schema doc | Machine-validated? | How? |
|---|---|---|---|
| `vault.json` | vault-contract.md §schema | Partial — vault.json lock discipline enforced by convention; OQ fields validated by `validate-vault-oqs.sh` | PostToolUse Write hook |
| `binding.md` | binding-contract.md | Partial — coverage check by `validate-vault-binding-coverage.sh`; CONFLICT count not independently verified | PostToolUse Write hook |
| `codebase-map.md` | codebase-map-schema.md | **No** — section presence/completeness not validated | — |
| Unit files (`U-*.md`) | unit-schema.md | **Yes** — `validate-unit-spec.sh` checks frontmatter fields + Hard Rules + binding_refs | PostToolUse Write hook |
| `bolt-report.md` | bolt-contract.md | Partial — `validate-bolt-artifacts.sh` checks self-assessment section presence | PostToolUse Write hook |
| Handoff YAML | handoff-contract.md (TYPE annotations) | **Yes** — `validate-handoff-yaml.sh` runs schema check + required field check + artifact existence check | Stop hook |
| `FSD.md` + `.citation-map.json` | fsd-template.md + section-mapping.md | Partial — `validate-fsd-slots.sh` checks template slot fill; citation integrity via sha256 | PostToolUse Write hook |
| `knowledge-base/*.md` | knowledge-base-schema.md (11-section template) | **No** — frontmatter fields + section presence not validated by any hook | — |
| `DRIFT-REPORT.md` | Per detect-drift SKILL.md | **No** | — |
| `starterkit-context.yaml` | starterkit-context-schema.md | Partial — corrupt-detection by SessionStart guard 7; schema compliance not validated | SessionStart hook |

---

# Part 2 — Benchmark Targets

## 2.1 Superpowers (Claude Code Plugin — v5.1.0)

**Source:** Direct filesystem read of `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/`

### Consistency methodology

Superpowers enforces consistency through **prose-based contracts** and **multi-stage review loops**, not JSON schemas:

| Mechanism | Implementation | Enforcement level |
|---|---|---|
| **Plan document format** | Mandatory header structure (Goal, Architecture, Tech Stack); task structure with exact file paths + complete code blocks; no-placeholders rule ("TBD"/"TODO" forbidden) | [SKILL-PROSE] — reviewer subagent validates |
| **Spec document format** | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`; completeness + internal consistency + scope + YAGNI checks | [SKILL-PROSE] — reviewer subagent validates |
| **Spec Review Loop** | Spec → reviewer subagent → issues → fix → re-review → repeat until Approved. Max 5 iterations before human escalation. | [SKILL-PROSE] but structurally enforced (loop in skill body) |
| **Plan Review Loop** | Plan chunks → reviewer subagent per chunk → issues → fix. Malformed output recovery (re-dispatch after 2 failures). | [SKILL-PROSE] with structural loop |
| **Code Quality Reviewer** | Severity-calibrated (Critical/Important/Minor) with file:line refs. "Do Not Trust the Report" — reviewer must read actual code. | [SKILL-PROSE] — subagent prompt template |
| **Iron Laws** | Per-skill non-negotiable rules: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" (TDD); "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" (verification) | [SKILL-PROSE] — model may or may not follow |
| **Red Flags / Rationalization Prevention** | Tables showing common excuses + why they're wrong. Present in every discipline-critical skill. | [SKILL-PROSE] — cognitive guardrail only |
| **Mandatory skill invocation** | `using-superpowers/SKILL.md`: "if even 1% chance a skill applies, you ABSOLUTELY MUST invoke it" | [SKILL-PROSE] — SessionStart anchor injection |
| **Handoff protocol** | brainstorming → writing-plans → {subagent-driven OR inline} → finishing-a-development-branch. Each transition has mandatory skill invocation. | [SKILL-PROSE] — no hook enforcement |
| **PR acceptance gate** | 94% rejection rate; skills are "behavior-shaping code, not prose"; pressure testing required | [HUMAN-PROCESS] — PR review |

### Key consistency patterns

1. **Review-loop convergence**: Spec and plan documents go through iterative review until approved. This is a form of consistency enforcement — outputs must satisfy explicit checklists before proceeding.
2. **No JSON schemas**: Deliberate design choice. Consistency via prose contracts + reviewer validation.
3. **Subagent output contracts**: Each subagent (implementer, code-quality-reviewer, spec-reviewer) has a templated output format (Status + Issues + Recommendations + Assessment). Enforced by prompt template, not by machine validation.
4. **Trust-but-verify**: Code quality reviewer's "Do Not Trust the Report" principle — acknowledge that AI review can hallucinate, require line-by-line comparison.

### Honest assessment for comparison

Superpowers' consistency mechanisms are **entirely [SKILL-PROSE]** with no hook-level enforcement. This is by design — it's a methodology framework, not a spec-decomposition pipeline. Its strength is the review loop pattern (converge-to-quality via iteration). Its weakness is the same as mega-sdd pre-Iter-67: no deterministic validation of outputs.

## 2.2 GitHub Spec Kit (github/spec-kit — 106k★)

**Source:** [github/spec-kit](https://github.com/github/spec-kit) repository, official docs, template files. Open-sourced May 9, 2026. Agent-agnostic (supports 30+ AI agents including Claude Code).

### Architecture

Phase-sequenced pipeline: Constitution → Specify → (Clarify) → Plan → Tasks → (Analyze) → (Checklist) → Implement. Each phase produces a structured Markdown artifact in `.specify/specs/NNN-feature/`. 9 commands total.

### Consistency mechanisms

| Mechanism | Implementation | Enforcement level |
|---|---|---|
| **Template-driven constraints** | `spec-template.md`, `plan-template.md`, `tasks-template.md` — structured sections force AI into specific output shape. `[NEEDS CLARIFICATION]` markers required for uncertain items (no guessing). | [SKILL-PROSE] — template injected into agent context |
| **`/speckit.analyze` (6-pass cross-artifact check)** | Non-destructive read-only analysis across spec.md, plan.md, tasks.md. Six passes: Duplication, Ambiguity, Underspecification, Constitution Alignment, Coverage Gaps, Inconsistency. Severity ladder: CRITICAL > HIGH > MEDIUM > LOW. Max 50 findings. Output: `analysis-report.md`. | **[VERIFY-STEP]** — explicit command, deterministic, strictly read-only |
| **`/speckit.checklist` (requirements quality validation)** | "Unit tests for requirements writing." 9 quality dimensions (Completeness, Clarity, Consistency, Acceptance Criteria Quality, Scenario Coverage, Edge Cases, NFRs, Dependencies, Ambiguities). Output: domain-specific checklists (ux.md, api.md, security.md) with numbered items (CHK001...). | **[VERIFY-STEP]** — deterministic output |
| **Constitution (immutable governance)** | `.specify/memory/constitution.md` — named principles with non-negotiable rules + rationale + amendment procedures. Reference implementation has 9 Articles (Library-First, CLI Interface Mandate, Test-First Imperative, Simplicity, Anti-Abstraction, Integration-First Testing, etc.). Loaded into every command automatically. | [SKILL-PROSE] — injected into all prompts; `/analyze` treats violations as CRITICAL |
| **Phase gates** | Implementation templates contain compile-time-like checks: Simplicity Gate (max 3 projects), Anti-Abstraction Gate (framework-direct usage), Integration-First Gate (contract tests exist). | [SKILL-PROSE] — template instructions |
| **Prerequisite scripts** | `.specify/scripts/bash/check-prerequisites.sh` validates phase ordering. | **[VERIFY-STEP]** — bash script |

### Key patterns for mega-sdd comparison

1. **`/analyze` as unified consistency surface**: Single command, 6 detection passes, cross-document consistency. This is exactly the gap mega-sdd has (10 scattered validators, no unified command).
2. **Constitution as enforced contract**: Constitution violations are always CRITICAL in `/analyze` output. Constitution hash is referenced in plan templates. Amendment requires formal process.
3. **Spec-as-single-source-of-truth**: "Code serves specifications, not the other way around." Specifications are the primary artifact; code is a derived expression.
4. **Template-driven consistency**: No JSON schemas — consistency via structured Markdown templates. Same philosophy as superpowers but with `/analyze` providing machine verification.

### Honest assessment

Spec Kit's enforcement is primarily [SKILL-PROSE] (template injection) + [VERIFY-STEP] (`/analyze`, `/checklist`). It has NO hook-level enforcement — no PreToolUse blocking, no PostToolUse validation, no SessionStart guards. The `/analyze` command is powerful but user-invoked, not automatic. A user who skips `/analyze` gets no consistency check.

## 2.3 GSD (Get Stuff Done — Claude Code Plugin)

**Source:** `~/.claude/skills/gsd-*/SKILL.md`, `~/.claude/get-shit-done/workflows/*.md`, `~/.claude/get-shit-done/templates/`, `~/.claude/get-shit-done/references/gates.md`. Installed locally.

### Architecture

Phase-based pipeline: discuss → plan → execute → verify → validate. Each phase produces a named artifact (CONTEXT.md, PLAN.md, SUMMARY.md, UAT.md, VALIDATION.md). Orchestrated by `gsd-autonomous` which chains all phases per milestone.

### Consistency mechanisms

| Mechanism | Implementation | Enforcement level |
|---|---|---|
| **4 canonical gate types** | Pre-flight (blocks entry on precondition miss), Revision (loops output to producer, max 3 iterations with stall detection), Escalation (surfaces to human), Abort (terminates to prevent damage). Gate Matrix maps every workflow to its gates + artifacts checked + failure behavior. | [SKILL-PROSE] — subagent + stall detection |
| **Nyquist validation** | `gsd-validate-phase` audits test coverage per requirement: COVERED / PARTIAL / MISSING classification. Spawns `gsd-nyquist-auditor` subagent to fill gaps. Per-Task Verification Map (task_id, plan, wave, requirement, test type, status). | [SKILL-PROSE] — subagent-driven |
| **VALIDATION.md structure** | Template with frontmatter (`phase`, `slug`, `status`, `nyquist_compliant`, `wave_0_complete`). Test Infrastructure table, Sampling Rate rules, Per-Task Verification Map, Wave 0 Requirements, Sign-Off checklist. Sign-off requires: all tasks have automated verify, no 3 consecutive tasks without it. | [SKILL-PROSE] — template-enforced |
| **Artifact-as-handoff** | Phase artifacts ARE the handoff contract. CONTEXT.md → PLAN.md → SUMMARY.md. Each phase reads prior phase's artifact. | [SKILL-PROSE] — implicit via file convention |
| **SDK CLI deterministic init** | `gsd-sdk query` provides deterministic JSON for every workflow. Agent subtype system with model resolution per agent. | [VERIFY-STEP] — CLI tool |

### Key patterns for mega-sdd comparison

1. **Nyquist validation**: Structured coverage analysis (COVERED/PARTIAL/MISSING per requirement) is a strong reproducibility mechanism. mega-sdd's binding does something analogous (CONFIRMED/CONFLICT/OQ per claim) but at the spec-vs-code level, not the test-vs-requirement level.
2. **4 gate types**: Pre-flight / Revision / Escalation / Abort taxonomy maps roughly to mega-sdd's C1/C2/C3 halt classification but is applied at the workflow level, not the artifact level.
3. **Stall detection**: Revision gate caps at 3 iterations with stall detection — prevents infinite review loops. mega-sdd's `check-recursion-budget.sh` script was designed for this but is not wired (audit §D).

### Honest assessment

GSD's consistency mechanisms are entirely [SKILL-PROSE] with no hook-level enforcement. Its strength is the structured gate taxonomy and Nyquist validation pattern. Its weakness is the same as superpowers: no deterministic validation at the tool boundary.

## 2.4 Additional References

### 2.4.1 BMAD-METHOD (Breakthrough Method for Agile AI-Driven Development)

**Source:** GitHub repo `bmad-code-org/BMAD-METHOD`, blog posts, DeepWiki analysis.

**Architecture:** Multi-persona agent system (Analyst, PM, Architect, Developer, QA) with YAML-based workflows. `bmad-core/` contains agents, tasks, templates, checklists, data.

**Key consistency pattern — CI-integrated skill validator:**

BMAD has a **19-rule deterministic validator across 6 categories**, integrated into CI via `npm run validate:skills`. This is a hard CI gate — skills that fail validation cannot merge. Rules documented in `tools/skill-validator.md`.

This is the strongest CI-enforcement pattern in the benchmark. mega-sdd has no CI integration — all validation is runtime (hook-based) or user-invoked.

**Other mechanisms:** YAML workflow files define deterministic task sequences. Quality checklists serve as document-level validation gates. TOML-based per-project customization. "Party Mode" multi-persona sessions.

### 2.4.2 Kiro (AWS)

**Source:** `kiro.dev/docs/`, official blog.

**Architecture:** Three primitives: **Specs** (define intent), **Steering** (encode norms), **Hooks** (automate enforcement). Built on Claude via Amazon Bedrock.

**Key consistency patterns:**

| Mechanism | Implementation | Enforcement level |
|---|---|---|
| **Steering Rules** | `.kiro/steering/` directory with `product.md`, `api-standards.md`, `testing-standards.md`, `code-conventions.md`. Loaded into every agent prompt automatically. Workspace steering overrides global. | [SKILL-PROSE] — injected into all prompts |
| **Agent Hooks** | Fire on IDE events (file save, pattern match). Two action types: "agent prompt" (sends prompt to Claude) and "shell command" (runs CLI). Developer cannot bypass without modifying hook config. | **[HOOK]** — IDE-level, deterministic |
| **Continuous spec sync** | Hooks keep spec in sync with code: "The spec doesn't go stale because hooks keep it in sync." | **[HOOK]** — continuous, not one-time |
| **`.kiro/` in repo** | Entire team gets same steering + hooks + spec structure via version control. | [HUMAN-PROCESS] — git-committed config |

**Honest assessment:** Kiro's hooks are the closest external analog to mega-sdd's Claude Code hooks. Both fire at tool boundaries. Key difference: Kiro hooks fire on IDE events (file save); mega-sdd hooks fire on Claude Code tool calls (PreToolUse/PostToolUse). Both are deterministic and model-proof within their respective platforms.

### 2.4.3 Cline

**Source:** `docs.cline.bot`, GitHub repo.

**Key patterns:** Plan/Act mode toggle (Plan = read-only exploration; Act = execution). Checkpoints after every tool call (full state rollback). `.clinerules` files in repo (toggleable per session). Native subagents (v3.58+) for parallel work.

**Honest assessment:** Weak on structured consistency. No schemas, no validators, no formal handoffs. Strength is rollback capability (checkpoints) and the Plan/Act cognitive separation.

### 2.4.4 Aider

**Source:** `aider.chat/docs/`, GitHub repo.

**Key patterns:** Architect/Editor mode split (expensive planner → cheap editor). `.aider.conf.yml` for team-wide conventions. Atomic git commit per change. Lint + test feedback loops (auto-runs linter after edit; feeds test failures back).

**Honest assessment:** Single-session pair programmer, not a multi-phase pipeline. Consistency via immediate feedback loops (lint/test), not pre-flight validation. No structured artifacts beyond git commits.

---

# Part 3 — Consistency Comparison Matrix

## 3.1 Output Standardization

*How does each framework enforce schema/template/contract per output?*

| Framework | Schema mechanism | Enforcement | Validator type | Evidence |
|---|---|---|---|---|
| **mega-sdd** | Per-artifact contract docs (vault-contract.md, binding-contract.md, unit-schema.md, bolt-contract.md, handoff-contract.md). 10 deterministic bash validator scripts. | **[HOOK-VALIDATE]** for 6 of 14 skills; [SKILL-PROSE] for remaining 8. PreToolUse blocks downstream on validation failure. | Bash+Python scripts; exit 0=PASS, 1=FAIL; state files overwrite-not-append. | 10 `validate-*.sh` scripts in `plugins/mega-sdd/scripts/`; hooks.json matchers for Read\|Skill\|Bash\|Write\|Edit\|Agent |
| **superpowers** | Plan/spec document format rules in SKILL.md prose. Subagent output contracts (Status + Issues + Recommendations + Assessment). No-placeholders rule. | [SKILL-PROSE] — reviewer subagent validates output; Iron Laws as cognitive guardrails. No machine validation. | Subagent review loops (spec-reviewer, plan-reviewer, code-quality-reviewer). Converge via iteration, not schema check. | `writing-plans/SKILL.md` task structure contract; `brainstorming/spec-document-reviewer-prompt.md` |
| **Spec Kit** | Markdown templates (`spec-template.md`, `plan-template.md`, `tasks-template.md`). `[NEEDS CLARIFICATION]` markers for uncertain items. `/checklist` generates quality validation against 9 dimensions. | [SKILL-PROSE] — templates injected into context. **[VERIFY-STEP]** — `/analyze` checks post-hoc. No hook-level enforcement. | `/speckit.analyze` (6-pass cross-artifact analysis). `/speckit.checklist` (9-dimension requirements quality). `check-prerequisites.sh` for phase ordering. | `templates/commands/analyze.md`; `templates/commands/checklist.md` |
| **GSD** | Templates with YAML frontmatter (VALIDATION.md). Structured task format in PLAN.md. Gate Matrix maps workflows to checks. | [SKILL-PROSE] — subagent-driven validation. Revision gate loops max 3 iterations. | `gsd-plan-checker` subagent for plan review. `gsd-nyquist-auditor` for coverage analysis. Stall detection on revision loops. | `references/gates.md`; `templates/VALIDATION.md` |
| **BMAD** | YAML workflow files + quality checklists. | **[CI-GATE]** — 19-rule deterministic validator in CI pipeline (`npm run validate:skills`). Skills cannot merge on failure. | `tools/skill-validator.md` — 19 rules across 6 categories. CI-integrated. | `bmad-core/` structure |
| **Kiro** | Structured spec artifacts (IDE-enforced). Steering rules in `.kiro/steering/`. | **[HOOK]** — IDE-level hooks fire on file save, run shell commands or agent prompts. Cannot be bypassed. | Shell command or agent prompt triggered by IDE events. | `kiro.dev/docs/` hooks documentation |
| **Cline** | `.clinerules` (markdown, toggleable). | [SKILL-PROSE] — rules influence generation but no machine check. | None. Checkpoints for rollback, not validation. | `docs.cline.bot` |
| **Aider** | `.aider.conf.yml` for conventions. | [SKILL-PROSE] — config influence. Lint/test feedback loops. | Linter auto-run after edit; test failure feed-back. Feedback loops, not pre-validation. | `aider.chat/docs/` |

**Verdict:** mega-sdd has the **strongest runtime enforcement** (hook-level blocking + deterministic validators). BMAD has the **strongest CI enforcement** (validator gate at merge time). Spec Kit has the **strongest cross-artifact analysis** (`/analyze` — 6 passes). Kiro has the **strongest IDE-level enforcement** (file-save hooks).

## 3.2 Context Consistency

*Single-source-of-truth? Artifact-as-truth? How is drift between steps prevented?*

| Framework | Single source of truth | Drift prevention | Cross-step validation |
|---|---|---|---|
| **mega-sdd** | vault.json = derived structural index from 7 markdown files (markdown is canonical). binding.md = ground truth for vault↔code alignment. SHA256 snapshot chain across phases. | [HOOK-VALIDATE]: binding→units OQ-ID carry validated. `validate-vault-binding-coverage.sh` checks vault→binding coverage. Constitution hash in handoff YAML (but not enforced). | **Partial**: 6 of 14 skills have hook-validated output. No unified cross-artifact command. Per Iter 67 audit §F: OQ-IDs drop at binding→units boundary (now caught by validator). |
| **superpowers** | Plan document is truth for execution. Spec document is truth for plan. Chain: spec → plan → code. | [SKILL-PROSE]: spec-reviewer validates spec; plan-reviewer validates plan. Code-quality reviewer validates code. Each loop converges independently. | **Weak**: No cross-document consistency check. Spec and plan reviewed separately. No spec↔code grounding. |
| **Spec Kit** | spec.md = primary artifact. "Code serves specifications." Bidirectional feedback loop (production metrics → spec → code). | **[VERIFY-STEP]**: `/speckit.analyze` Coverage Gaps pass checks that every requirement has tasks and every task maps to a requirement. Inconsistency pass detects terminology drift. | **Strong**: `/analyze` runs 6 cross-document passes. Constitution alignment check. But user-invoked, not automatic. |
| **GSD** | Phase artifacts (CONTEXT.md → PLAN.md → SUMMARY.md) are the truth. Each phase reads prior artifact. | [SKILL-PROSE]: plan-checker reviews PLAN.md against CONTEXT.md. Nyquist validation audits test↔requirement coverage. | **Moderate**: Nyquist validation provides requirement↔test traceability. Plan-checker provides context↔plan alignment. But no vault↔code grounding. |
| **Kiro** | Spec is truth. Hooks keep spec in sync with code continuously. | **[HOOK]**: file-save hooks detect spec↔code drift automatically. Continuous, not one-time. | **Strong in-IDE**: Hooks fire on every save. But limited to IDE context — CI/CD drift not covered. |
| **BMAD** | YAML workflows are the blueprint. Persona dependency lists define handoff scope. | [CI-GATE]: 19-rule validator catches skill drift at merge. Quality checklists for document review. | **CI-level**: Catches skill-definition inconsistencies. No runtime spec↔code grounding. |

**Verdict:** Spec Kit has the **best cross-document analysis** (`/analyze`). Kiro has the **best continuous sync** (hooks on every file save). mega-sdd has the **deepest spec↔code grounding** (binding phase with claim-by-claim traceability) but **lacks unified cross-artifact analysis**.

## 3.3 Integration / Orchestration

*How do steps connect seamlessly? Handoff contract? State machine? Command chaining?*

| Framework | Orchestration model | Handoff contract | Chain enforcement |
|---|---|---|---|
| **mega-sdd** | `orchestrate-flow --deep`: CWD-state-driven routing. Handoff YAML parsed between phases. Stateless resume (CWD signals, not persisted state file). | **Formal**: `handoff-contract.md` with TYPE annotations, required fields, per-skill expected emissions. `validate-handoff-yaml.sh` verifies at Stop hook. | **[HOOK-VALIDATE]**: handoff validation + PreToolUse blocking + anti-self-bypass. But 8/14 skills rely on [SKILL-PROSE] for handoff emission. |
| **superpowers** | Mandatory skill invocation chain: brainstorm → plan → execute → finish. Each transition requires explicit skill invocation. | **Informal**: Skill body instructions specify "invoke writing-plans next" / "invoke finishing-a-development-branch." No structured YAML contract. | [SKILL-PROSE] — "if even 1% chance a skill applies, you ABSOLUTELY MUST invoke it." No machine enforcement of ordering. |
| **Spec Kit** | Phase-sequenced: constitution → specify → plan → tasks → implement. `check-prerequisites.sh` validates ordering. | **Template-driven**: Each template includes references to prior-phase artifacts. `/analyze` checks cross-phase coverage. | **[VERIFY-STEP]**: prerequisite script + `/analyze`. No automatic chain execution. |
| **GSD** | `gsd-autonomous` chains all phases per milestone. Gate Matrix maps workflows to gates. | **Artifact-as-handoff**: Phase reads prior phase's file. No structured contract beyond file format. | [SKILL-PROSE] — autonomous workflow chains phases. Gates cap iterations. |
| **Kiro** | Specs → Code → Hooks loop. Agent hooks fire on IDE events. | **Continuous**: Hooks maintain spec↔code sync. No discrete handoff — continuous validation. | **[HOOK]** — IDE-level hooks. Strongest continuous enforcement. |
| **BMAD** | YAML workflow files define deterministic task sequences. | **YAML-defined**: Persona dependency lists in YAML headers. | [CI-GATE] — workflow definitions validated at CI. |

**Verdict:** mega-sdd has the **most formalized handoff contract** (typed YAML schema with machine validation). Kiro has the **most seamless integration** (continuous hooks, no discrete handoffs needed). GSD and superpowers rely entirely on [SKILL-PROSE] for orchestration.

## 3.4 Reproducibility

*What makes output consistent and repeatable?*

| Framework | Determinism mechanisms | Validation before proceed | Consistency guarantees |
|---|---|---|---|
| **mega-sdd** | SHA256 snapshot chain (preflight/postflight/codebase-map/extracted-kb). State files overwrite-not-append (current truth). CWD-driven routing (stateless resume). ast-grep Hard Rule validation (deterministic AST checks). | **[HOOK-VALIDATE]** for 6 skills: validator fires on artifact write; blocks downstream on FAIL. Predictive-checks preflight catalog (31 checks across 10 skills). | Strong for validated artifacts. Weak for prose-only skills (no guarantee of format compliance). |
| **superpowers** | Review loops converge to quality (spec/plan reviewed iteratively). Iron Laws as behavioral anchors. | [SKILL-PROSE] — review loop convergence. Max 5 iterations before human escalation. "Do Not Trust the Report" principle. | Moderate — depends on review loop quality. No deterministic checks. |
| **Spec Kit** | Templates enforce consistent structure. `/checklist` generates deterministic quality checks. `/analyze` produces deterministic findings. | **[VERIFY-STEP]** — `/analyze` + `/checklist` + prerequisite scripts. | Strong for analyzed artifacts. User must invoke commands — no automatic enforcement. |
| **GSD** | SDK CLI deterministic init JSON. Versioned workflow files. Agent subtype system with model resolution. | [SKILL-PROSE] — Nyquist validation + plan-checker. Stall detection on loops. | Moderate — Nyquist provides coverage measurement but no deterministic output validation. |
| **Kiro** | `.kiro/` committed to repo — team-wide consistency. Hooks fire deterministically on file save. | **[HOOK]** — continuous IDE-level enforcement. | Strong within IDE context. No CI/CD-level guarantees. |
| **BMAD** | YAML workflows deterministic. TOML overrides version-controlled. | **[CI-GATE]** — 19-rule validator blocks bad skills at merge. | Strong for skill definitions (CI-gated). No runtime output validation. |

**Verdict:** mega-sdd has the **strongest runtime reproducibility** (SHA256 chains + deterministic validators). BMAD has the **strongest CI reproducibility** (merge-time validation). Spec Kit has the **strongest user-invoked reproducibility** (`/analyze` + `/checklist`).

---

# Part 4 — Output Consistency Assessment (Honest)

## 4.1 Where mega-sdd is BEHIND (consistency engineering gaps)

### Gap 1: No unified `/analyze` command [CRITICAL]

mega-sdd has **10 validator scripts** across **5 different hook surfaces** — but no single command that runs all validators and produces a unified cross-artifact consistency report. Each validator fires reactively (PostToolUse on specific file writes) and writes its own state file. A user wanting to know "is my pipeline state consistent?" must check 10+ state files or trigger writes to each artifact.

**Evidence:** `fork-a-recovery-map.md` line 39 already identifies this: "Cross-artifact `/analyze` command — [VERIFY-STEP] — Not implemented — slice 6+ after individual validators prove."

**Impact:** Consistency is reactive (catch errors as they happen) but never proactive (verify everything is consistent before proceeding). Spec Kit's `/analyze` pattern fills exactly this gap.

### Gap 2: No enforced constitution contract

`handoff-contract.md` defines a `constitution:` block (sha256 hash + clauses_referenced) in the handoff YAML schema. `constitution.md` is referenced in predictive-checks.md (`constitution_file_check`). But:

- **No validator script** checks constitution clause satisfaction against actual artifacts
- **No skill body** systematically validates that vault decisions honor constitution clauses
- Constitution hash is carried in handoff YAML but never verified by any consumer
- bind-codebase has `bind_conflict_constitution_violation` halt type, but detection is [SKILL-PROSE]

**Evidence:** grep for `constitution` across all 10 validate-*.sh scripts → 0 hits. Constitution enforcement is schema-defined but not machine-validated.

### Gap 3: Schema completeness validation gaps

Three key artifacts have no machine validation of schema compliance:
- `codebase-map.md` — no check that all 7 required sections exist or are populated
- `knowledge-base/*.md` — no check that 11-section template is followed or frontmatter fields are present
- `DRIFT-REPORT.md` — no structural validation

These are foundational artifacts consumed by downstream skills. If they're malformed, downstream skills silently consume garbage input.

### Gap 4: Reproducibility not measured

No mechanism tracks whether the same input (PRD + codebase) produces semantically equivalent output across runs. This is inherent to LLM-based generation, but other frameworks (GSD's verification step, superpowers' spec review loop) at least verify output meets explicit criteria before proceeding.

## 4.2 Where mega-sdd LEADS (moat — defensible differentiation)

### Moat 1: [HOOK-VALIDATE] + PreToolUse anti-self-bypass — UNIQUE

The combination of:
1. PostToolUse validator fires on artifact write → writes state file
2. PreToolUse blocks downstream skill when state=FAIL
3. PreToolUse anti-self-bypass prevents agent from `rm`/`mv`/`sed -i` state files
4. Human user retains manual override (by design — "user is not the adversary")

**This pattern does not exist in any benchmark framework.** Kiro's IDE-event hooks are the closest analog but operate on file-save events, not tool calls — mega-sdd's PreToolUse blocking on agent tool dispatch is structurally distinct (it constrains the AI agent's tool calls, not the developer's file saves). Superpowers has no hook-level enforcement. GSD has no PreToolUse blocking. The anti-self-bypass layer (blocking agent attempts to delete guard files) is a novel contribution to the Claude Code ecosystem.

**Evidence:** `pre-tool-use` lines 221-264 (anti-bypass regex); `fork-a-recovery-map.md` §Pattern reference: [HOOK-VALIDATE].

### Moat 2: Grounding/binding traceability — vault claims cite codebase evidence

The bind-codebase phase produces a claim-by-claim audit trail:
- Every vault claim → CONFIRMED (with codebase-map anchor) / CONFLICT (with contradicting evidence) / OQ (with missing evidence note)
- Implementation State Map: IMPLEMENTED (file:line anchor) / NEW / UNKNOWN (with confidence tag)
- Suggested Unit Hard Rules derived from binding evidence (v1.4+)
- SHA256 snapshot chains across phases (`shared-snapshot-schema.md`)

No benchmark framework produces this level of spec↔code traceability. Most operate purely at the spec level (generating plans/tasks from requirements) without grounding against actual codebase state.

**Evidence:** `binding-contract.md`; TF Import `binding.md` (45KB, 87 claims validated); `shared-snapshot-schema.md` (sha256 chain).

### Moat 3: Mutability tiers in knowledge extraction — NOVEL

`[LOCKED]/[INTENT]/[ARTIFACT]` classification (Iter 22) is orthogonal to confidence markers. It answers: "in a rebuild, what MUST be preserved identically (LOCKED — regulatory field names), what must achieve the same outcome differently (INTENT — workflow behavior), and what can be discarded (ARTIFACT — implementation detail)?"

This drives `unit-schema.md` `mutability.rebuild_freedom` matrix, which constrains what execute-bolts can change per unit. A unit with `mutability.tier: LOCKED, field_names: no, field_types: no` prevents the bolt from renaming regulated fields — a compliance constraint that propagates from KB extraction through vault generation through unit spec to bolt execution.

**Evidence:** `knowledge-base-schema.md` frontmatter `locked_count/intent_count/artifact_count`; `unit-schema.md` `mutability:` block; `handoff-contract.md` `mutability:` section.

### Moat 4: FSD citation discipline — sha256-stamped traceability

`emit-fsd` produces `.citation-map.json` with sha256 stamps per cited artifact. Every FSD section traces to a source artifact; missing sources emit `[Pending — X]` placeholder, never fabrication. This is the strongest anti-hallucination mechanism in the documentation layer.

**Evidence:** `emit-fsd/references/fsd-template.md`; `emit-fsd/references/section-mapping.md`; handoff-contract.md `emit-fsd` block with `citations_count` metric.

### Moat 5: Halt escalation discipline (C1/C2/C3 classification)

63 halt types classified into three categories with explicit escalation rules:
- C1 (self-resolve): 22 types — skill fixes own output, continues. [HOOK] or [HOOK-VALIDATE] enforced for 9 SessionStart guards.
- C2 (business gate): 15 types — halt + propose recommendation + ask sign-off. Human decision needed.
- C3 (grounding gate): 8 types — halt, no fabrication allowed. [HOOK-VALIDATE] enforced.

This is a structured halt taxonomy with enforcement surface classification. No benchmark has anything comparable.

**Evidence:** `halt-escalation-classification.md`; `fork-a-recovery-map.md`.

## 4.3 Where the landscape is CONVERGING (moat narrowing)

### Convergence 1: Structured artifact pipelines

The pattern of "spec → plan → tasks → code" is now universal:
- Spec Kit: constitution → specify → plan → tasks → implement (9 commands)
- GSD: discuss → plan → execute → verify → validate (5 phases)
- Superpowers: brainstorm → plan → implement → finish (4 phases)
- Kiro: specs → code → hooks (continuous loop)
- BMAD: analyst → PM → architect → developer → QA (5 personas)

The pipeline SHAPE is no longer differentiating. What differentiates is the DEPTH of each phase's output (mega-sdd's 7-file vault vs. Spec Kit's single spec.md) and the ENFORCEMENT between phases (hook-validated handoffs vs. template-driven).

### Convergence 2: Hook-based enforcement

Claude Code's hook system is available to ALL plugins. Kiro already has IDE-level hooks with the same model: "fire on event → run shell command → block or proceed." As the ecosystem matures, any plugin can adopt [HOOK-VALIDATE]. The MECHANISM is not defensible — the DOMAIN KNOWLEDGE encoded in the validators (what to check, what constitutes a violation, what the halt means for the pipeline) is the moat.

### Convergence 3: Cross-artifact consistency analysis

Spec Kit's `/analyze` (6 detection passes, cross-document) is the gold standard for this capability. BMAD has CI-integrated validation (19 rules). GSD has Nyquist validation. mega-sdd has 10 scattered validators but no unified `/analyze` equivalent. This is the most concrete convergence pressure — other frameworks are ahead on this dimension.

### Convergence 4: Review loops / quality gates

Superpowers' spec/plan review loops, GSD's revision gates with stall detection, BMAD's quality checklists, Spec Kit's `/checklist` — all converging on "iterate until quality criteria met." mega-sdd's `resolve-oq` interactive walk is a domain-specific instance.

### Convergence 5: LLM-driven codebase analysis

Multiple tools offer codebase scanning: GSD's `gsd-map-codebase`, Kiro's built-in analysis, Aider's repo-map. The raw capability of "scan a repo and produce context" is table-stakes. mega-sdd's advantage is NOT the scan itself — it's HOW the scan output is consumed (binding against vault claims to produce CONFIRMED/CONFLICT/OQ verdicts + Implementation State Map). No other framework grounds specs against live codebase state at this level.

### Convergence 6: Constitution/steering as governance

Spec Kit has `constitution.md` (9 Articles, immutable principles, amendment procedures). Kiro has `steering/` directory (product.md, api-standards.md, etc.). Cline has `.clinerules`. The concept of "project-level rules that constrain AI behavior" is universal. mega-sdd has constitution support in schema but no enforcement validator — it's behind on this converging dimension.

---

# Part 5 — Per-Skill Capability Deepening

Per user directive: "JANGAN ratain ke semua 14 skill." Only skills with a named concrete gap and a named enforcement surface are included. MOAT-FIRST prioritization.

## 5.1 MOAT-FIRST: Grounding & Anti-Hallucination

### 5.1.1 `extract-intelligence` — KB output validation gap

**Gap:** Knowledge-base output (`.mega-sdd/knowledge-base/*.md`) follows an 11-section template with mandatory frontmatter fields (`verified_count`, `inferred_count`, `open_count`, `locked_count`, `intent_count`, `artifact_count`, `source_files_cited`). But NO validator checks:
- Section presence/order
- Frontmatter field completeness
- Confidence marker distribution consistency (e.g., `verified_count` in frontmatter matches actual `[VERIFIED]` markers in body)
- Cross-file dependency graph validity (`depends_on` field references exist)

**Benchmark reference:** Superpowers' spec review loop validates completeness/consistency/scope before proceeding. Spec Kit's `/checklist` generates quality validation against 9 dimensions (Completeness, Clarity, Consistency...). BMAD's 19-rule CI validator catches structural issues at merge. mega-sdd's KB extraction has no equivalent gate — the only check is SessionStart guard 7 which catches YAML corruption in `starterkit-context.yaml`, not KB content quality.

**Proposed mechanism:** `validate-kb-output.sh` — deterministic script checking:
1. Every `10-domains/*.md` file has all 11 sections in order
2. Frontmatter `verified_count` matches `grep -c '\[VERIFIED\]'` in body
3. `depends_on` references resolve to existing domain files
4. `README.md` nav index matches actual file listing

**Enforcement surface:** [HOOK-VALIDATE] — PostToolUse Write on `*.mega-sdd/knowledge-base/*.md` files → validator → state file `.mega-sdd/.kb-output-state.json`. Generate-intent `--kb` preflight check reads state; blocks on FAIL.

**Value:** Strengthens moat — KB quality directly impacts vault quality. A malformed KB domain file with wrong `[LOCKED]` count silently propagates bad mutability tiers through the entire pipeline.

### 5.1.2 `generate-intent` — citation-bypass closure

**Gap:** Vault documents cite source (PRD, KB) but citation validity is only partially validated. `validate-vault-oqs.sh` checks OQ structure, but:
- No validator checks that `vault.json` `entities[]` / `flows[]` / `adrs[]` counts match actual markdown content
- No validator checks that `source_documents[].path` files actually exist
- No cross-reference check between vault docs (e.g., entity referenced in `04-flows.md` exists in `03-data-model.md`)

**Benchmark reference:** Spec Kit's `/speckit.analyze` performs exactly this: 6 detection passes (Duplication, Ambiguity, Underspecification, Constitution Alignment, Coverage Gaps, Inconsistency) across spec/plan/tasks. Produces `analysis-report.md` with severity-rated findings. Fork-a-recovery-map.md already identifies this as a [VERIFY-STEP] gap at line 39.

**Proposed mechanism:** Extend existing `/mega-sdd:validate-handoff` into a broader `/mega-sdd:analyze` command that:
1. Runs all 10 existing validators
2. Adds vault internal consistency checks (entity/flow/ADR cross-refs)
3. Adds vault.json ↔ markdown sync check
4. Produces a single `CONSISTENCY-REPORT.md`

**Enforcement surface:** [VERIFY-STEP] — slash command invoked explicitly or auto-invoked by orchestrate-flow before chain proceed. Not hook-reactive (too expensive to run on every Write); user-triggered or chain-boundary-triggered.

### 5.1.3 `bind-codebase` — conflict classes beyond OVERLAP

**Gap:** Current conflict detection is binary: vault claim matches codebase evidence (CONFIRMED) or contradicts it (CONFLICT). The CONFLICT category conflates several distinct failure modes:
- **SEMANTIC CONFLICT**: vault says "use bearer auth", code uses sessions (truly conflicting intent)
- **NAMING CONFLICT**: vault says `user_role`, code has `userRole` (naming convention mismatch, likely resolvable)
- **VERSION CONFLICT**: vault specifies Laravel 11.x API, code uses Laravel 10.x patterns (upgradeable)
- **ARCHITECTURE CONFLICT**: vault proposes microservices, code is monolith (fundamental disagreement)

**Benchmark reference:** No framework currently differentiates conflict types at this granularity. Spec Kit's `/analyze` Inconsistency pass detects "conflicting tech choices" but doesn't classify by resolution complexity. GSD's Nyquist validation classifies COVERED/PARTIAL/MISSING but that's coverage, not conflict type. This would be a moat-deepening innovation unique to mega-sdd.

**Proposed mechanism:** Extend `binding-contract.md` conflict classification:
```
conflict_class: semantic | naming | version | architecture
resolution_complexity: trivial (auto-fixable) | moderate (unit scope) | significant (cross-unit)
```

Validator: `validate-vault-binding-coverage.sh` already runs on Write of binding.md. Extend it to verify conflict_class field is present on every CONFLICT entry.

**Enforcement surface:** [HOOK-VALIDATE] — extends existing validator. PostToolUse Write on binding.md.

## 5.2 MOAT-FIRST: Domain-Rule GAP Detector (Crown Jewel Assessment)

**User flagged:** "deteksi aturan domain/compliance/security yang HILANG (bukan cuma validasi yang ada) — paling diferensiasi, paling jarang dipunya orang."

### Feasibility analysis

**What it needs:**
1. A "what rules SHOULD exist" expectations file — per-domain, per-regulation, per-industry
2. A scanner that compares expectations against vault decisions + KB business-rules
3. A report of "rules you're missing" with confidence + source citation

**Where the expectations live (already):**
- `knowledge-base/40-business-rules/regulatory-rules.md` — extracted from legacy code, tagged `[LOCKED]`
- `knowledge-base/40-business-rules/operational-rules.md` — extracted operational constraints
- `knowledge-base/40-business-rules/hidden-gotchas.md` — edge cases

These are project-specific, not universal. A domain-agnostic gap detector would need:
- A library of "expected rule patterns" per domain (banking compliance → KYC check, transaction limits, audit trail)
- This is a **maintenance commitment**: new domains, new regulations, evolving standards

**False-positive risk:**
- HIGH for greenfield projects (no KB → no expectations → detector either silent or speculative)
- MEDIUM for rebuild projects (KB exists → expectations grounded in actual legacy behavior)
- LOW for existing-mode projects with constitution.md (explicit rules to check against)

**Enforcement surface:**
- [VERIFY-STEP]: `/mega-sdd:audit-rules` command that runs after vault generation, compares vault decisions + constraints against KB business-rules + optional domain-expectations library
- NOT [HOOK-VALIDATE]: too expensive and too speculative for automatic triggering

**Verdict: CONDITIONAL PROCEED — scope to rebuild-with-KB scenarios only**

For Mode B (KB-driven) pipelines where `knowledge-base/40-business-rules/` exists: a gap detector that compares vault `06-constraints.md` against KB regulatory/operational rules is feasible and high-value. The expectations base is already extracted (it's the KB itself). No external library needed.

For greenfield/Mode A: NOT feasible without an external expectations library. Mark as Fork-B-future with maintenance-cost disclaimer.

**Proposed walking-skeleton:**
1. Parse `06-constraints.md` constraint entries
2. Parse `knowledge-base/40-business-rules/regulatory-rules.md` entries with `[LOCKED]` tier
3. For each `[LOCKED]` regulatory rule in KB: check if vault constraints reference it
4. Report missing rules as `RULE-GAP-{N}` entries
5. No auto-fix — surface gaps for human review (C2 business gate)

## 5.3 TABLE-STAKES: Catch-up items

### 5.3.1 `scan-codebase` — codebase-map completeness validation

**Gap:** `codebase-map.md` schema defines 7 required sections. No validator checks section presence or minimum content.

**Proposed:** `validate-codebase-map.sh` — check sections 1-7 exist, §2 has ≥1 row, §3 has ≥1 row (if any routes detected), frontmatter has all required fields.

**Enforcement surface:** [HOOK-VALIDATE] — PostToolUse Write on codebase-map.md.

### 5.3.2 `generate-units` — dependency graph depth analysis

**Gap:** Units have `depends_on` fields forming a DAG. Predictive-checks.md has `units_depends_on_dag_acyclic` check, but:
- No analysis of critical path depth (longest dependency chain affects parallelism)
- No detection of bottleneck units (many dependents → deployment risk)

**Benchmark reference:** GSD's `gsd-analyze-dependencies` skill provides dependency analysis as a standalone capability. Spec Kit's `tasks-template.md` includes parallelization markers on tasks.

**Proposed:** Add `_index.md` §Dependency Analysis section emitted by generate-units with:
- Critical path: longest chain
- Bottleneck units: units with >3 dependents
- Parallelism waves: units executable per wave

**Enforcement surface:** [SKILL-PROSE] — enhancement to generate-units output. Not hook-worthy (analysis metadata, not correctness invariant).

---

# Part 6 — Synthesized Roadmap

## Priority tier 1: Consistency infrastructure (highest ROI — lifts consistency AND capability at moat simultaneously)

### R1. `/mega-sdd:analyze` — Unified cross-artifact consistency command
**Surface:** [VERIFY-STEP] — new slash command
**What:** Single command that runs all 10 existing validators + new vault internal consistency checks + produces `CONSISTENCY-REPORT.md`
**Why first:** Closes the biggest consistency gap (no proactive cross-artifact check); reuses existing validators (no new detection logic needed, just orchestration); directly referenced in fork-a-recovery-map.md as slice 6+
**Moat impact:** Catches the class of errors that currently propagate silently (malformed KB → bad vault → wrong units)
**Enforcement:** [VERIFY-STEP]; auto-invoked by orchestrate-flow at chain start + between phases
**Walking-skeleton:** Run all 10 validate-*.sh scripts → aggregate state files → produce markdown report with PASS/FAIL per boundary + per artifact

### R2. KB output validation hook
**Surface:** [HOOK-VALIDATE] — new `validate-kb-output.sh`
**What:** Validate knowledge-base output completeness (11-section template, frontmatter field consistency, dependency graph validity, confidence marker count accuracy)
**Why second:** KB quality is the foundation of Mode B pipelines. Invalid KB silently corrupts vault generation.
**Moat impact:** Deepens grounding moat — validated KB → more trustworthy vault
**Enforcement:** PostToolUse Write on `.mega-sdd/knowledge-base/*.md` → state file → generate-intent preflight check
**Walking-skeleton:** Validate 1 frontmatter field (`verified_count` matches body grep) for 1 domain file

## Priority tier 2: Moat deepening (defensible differentiation)

### R3. Conflict classification enrichment (bind-codebase)
**Surface:** [HOOK-VALIDATE] — extends existing `validate-vault-binding-coverage.sh`
**What:** Classify CONFLICTs into `semantic | naming | version | architecture` with `resolution_complexity` tag
**Moat impact:** Only framework that tells you WHAT KIND of conflict you have and how hard it is to fix
**Enforcement:** PostToolUse Write on binding.md; validator checks field presence
**Walking-skeleton:** Classify 1 CONFLICT from TF Import binding.md

### R4. Domain-rule gap detector (Mode B rebuild only)
**Surface:** [VERIFY-STEP] — new `/mega-sdd:audit-rules` command
**What:** Compare vault `06-constraints.md` against KB `40-business-rules/regulatory-rules.md` [LOCKED] entries; report missing rules
**Moat impact:** Crown jewel — no framework detects MISSING compliance rules
**Enforcement:** User-invoked post-vault-generation; C2 business gate for gaps found
**Walking-skeleton:** Compare 1 `[LOCKED]` KB rule against vault constraints; report if absent
**Maintenance cost:** LOW for KB-sourced expectations (already extracted); HIGH for external domain library (NOT proposed in walking-skeleton)
**Scope limit:** Mode B (KB present) only. Greenfield → Fork-B-future.

### R5. Constitution enforcement validator
**Surface:** [HOOK-VALIDATE] — new `validate-constitution.sh`
**What:** Parse `constitution.md` clauses; verify referenced clauses in handoff YAML are satisfied by vault decisions
**Moat impact:** Constitution concept already in schema but unenforced; enforcement closes the gap
**Enforcement:** PostToolUse Write on binding.md or vault docs; check constitution hash consistency
**Walking-skeleton:** Verify constitution.md sha256 in handoff YAML matches actual file hash

## Priority tier 3: Table-stakes catch-up

### R6. Codebase-map schema validation
**Surface:** [HOOK-VALIDATE] — new `validate-codebase-map.sh`
**Enforcement:** PostToolUse Write on codebase-map.md

### R7. Vault internal consistency check (part of R1)
**Surface:** [VERIFY-STEP] — part of `/mega-sdd:analyze`
**What:** vault.json entities/flows/ADRs match markdown content; cross-doc entity references resolve

## Fork-B-future (explicitly parked)

| Item | Why parked | Prerequisite |
|---|---|---|
| Domain-rule gap detector for greenfield (external expectations library) | Maintenance cost for per-domain/per-regulation library exceeds single-plugin scope | Industry-specific rule packs (banking, healthcare, etc.) — community-contributed |
| Implicit re-plan detection | Needs mid-reasoning interception | Agent SDK / custom runtime |
| Lazy-load tier enforcement | Needs mid-reasoning skip | Agent SDK / custom runtime |
| Output reproducibility measurement | LLM-inherent non-determinism; would need statistical comparison across runs | Eval framework (temperature=0 + diff-based semantic comparison) |
| Mid-chain telemetry emission (skill-body prose events) | Audit-confirmed 0% reliability for prose-convention emission | Agent SDK / tool-use-level emission API |

---

## Roadmap summary

```
Tier 1 (consistency infrastructure — do first):
  R1. /mega-sdd:analyze command          [VERIFY-STEP]      ← closes biggest gap
  R2. KB output validation hook          [HOOK-VALIDATE]     ← deepens foundation

Tier 2 (moat deepening — do second):
  R3. Conflict classification            [HOOK-VALIDATE]     ← enriches binding
  R4. Domain-rule gap detector (Mode B)  [VERIFY-STEP]       ← crown jewel (scoped)
  R5. Constitution enforcement           [HOOK-VALIDATE]     ← closes schema→enforcement gap

Tier 3 (table-stakes — do third):
  R6. Codebase-map validation            [HOOK-VALIDATE]
  R7. Vault internal consistency         [VERIFY-STEP]       ← part of R1

Fork-B-future (parked):
  - Greenfield domain-rule detection, implicit re-plan, lazy-load enforcement,
    reproducibility measurement, mid-chain prose telemetry
```

Each item: walking-skeleton-first, real-run-proven before expansion, enforcement surface specified. No prose-fake.

---

## Appendix A — Benchmark Source Index

| Framework | Version | Source type | Key evidence files |
|---|---|---|---|
| mega-sdd | v3.59.0 | Local plugin (`~/.claude/plugins/marketplaces/grand-design-spec/plugins/mega-sdd/`) | hooks/*.json, scripts/validate-*.sh, skills/*/SKILL.md, references/*.md |
| superpowers | v5.1.0 | Local plugin (`~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/`) | skills/*/SKILL.md, docs/superpowers/specs/*.md |
| Spec Kit | latest (106k★) | GitHub (`github/spec-kit`), web docs | templates/commands/{analyze,checklist,constitution}.md, spec-driven.md |
| GSD | latest | Local plugin (`~/.claude/skills/gsd-*/`) | references/gates.md, templates/VALIDATION.md, workflows/*.md |
| BMAD | latest | GitHub (`bmad-code-org/BMAD-METHOD`) | tools/skill-validator.md, bmad-core/ |
| Kiro | latest | Web docs (`kiro.dev/docs/`) | Hooks, Steering, Specs documentation |
| Cline | v3.58+ | Web docs (`docs.cline.bot`) | Plan/Act mode, checkpoints, .clinerules |
| Aider | latest | Web docs (`aider.chat/docs/`) | Architect mode, .aider.conf.yml, lint integration |
| Iter 67 integrity audit | 2026-05-27 | Local (`docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md`) | Components A-G, telemetry coverage, handoff trace |

## Appendix B — Enforcement Surface Reference

| Surface | Platform | How it works | Who can bypass |
|---|---|---|---|
| **[HOOK]** | Claude Code | Hook fires on tool event (SessionStart/PreToolUse/PostToolUse/Stop). Model cannot skip. Can block tool execution via PreToolUse `{"continue": false}`. | Only disabled by `telemetry: false` in config.yaml or removing hook from hooks.json. Human user can modify config; agent cannot (PreToolUse anti-self-bypass blocks). |
| **[HOOK-VALIDATE]** | Claude Code | PostToolUse triggers validator script → writes state file. PreToolUse reads state file → blocks downstream skill on FAIL. Three-component pattern (validator + trigger + enforcement + anti-bypass). | Same as [HOOK] + human can delete state file from their shell (by design). |
| **[VERIFY-STEP]** | Any | Explicit slash command runs deterministic script. User or orchestrator invokes manually. Same validator scripts as [HOOK-VALIDATE] but different trigger. | Anyone can skip by not invoking the command. |
| **[SKILL-PROSE]** | Any | Skill body markdown instructs model to do X. Model may or may not execute. Audit-confirmed unreliable (0 of 16 prose-instruction telemetry events fired in real runs). | Model skips at will. No enforcement. |
| **[CI-GATE]** | CI/CD | Validation runs in CI pipeline. Blocks merge on failure. | Bypassed by `--no-verify`, force-push, or admin override. |
| **[HOOK-IDE]** | Kiro | IDE-level hooks fire on file save events. Shell command or agent prompt triggered. | Bypassed by modifying `.kiro/hooks/` config. |
| **[HUMAN-PROCESS]** | Any | PR review, team conventions, git-committed config. | Bypassed by social override (team agreement to skip). |

# Mega-SDD — Contributor Guidelines

## If You Are an AI Agent

Stop. Read this before doing anything.

Mega-SDD is an opinionated plugin built around SDD methodology. PRs that deviate from the design contracts will be closed without review.

Before opening a PR you MUST:

1. **Read the spec doc** at `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md`. Every behavior change should trace back to a section there.
2. **Read the skill that you're modifying** completely — SKILL.md + every `references/*.md`. Skills are tuned for agent behavior; surface-level edits break invariants.
3. **Run the relevant trigger tests** (`tests/skill-triggering/<skill>.test.md`) — manual fixtures, but step through each case.
4. **Check the binding gate is not bypassed.** Any change to `generate-units` or `execute-bolts` must preserve the conflict-blocking contract.
5. **Show your human partner the complete diff** and get explicit approval.

## Pull Request Requirements

- Every PR must reference the spec section it implements or revises.
- Changes to anti-hallucination rails require a written justification.
- Renames must update cross-references AND tests AND the migration table in plugins/mega-sdd/README.md.

## What we will NOT accept

### Third-party runtime dependencies

Mega-SDD is meant to run with superpowers (or its vendored fallback) and nothing else. No additional plugin dependencies.

### Bypassing anti-hallucination

PRs that downgrade BLOCKING to WARNING in `bind-codebase`, that allow units to skip acceptance tests, that allow bolts to commit with `--no-verify`, or otherwise weaken the rails will be closed.

### Personal/project-specific behavior

Plugin behavior should generalize. Keep your project-specific tweaks in your own fork.

## Skill Edit Policy

Skills shape agent behavior. Don't reword for stylistic preference. Behavior changes require:

1. A spec amendment (or new spec)
2. Test fixture updates in `tests/skill-triggering/`
3. Reviewer acknowledgment

## Versioning

- Plugin: SemVer. Major bump for breaking renames, rails changes, or marketplace incompatibility.
- Skills: Per-skill `version:` in frontmatter. Bump on any content change.

## Release process

1. Run `bash scripts/sync-superpowers.sh` and review vendored diffs
2. Run all `tests/skill-triggering/*.test.md` manually
3. Update CHANGELOG.md
4. Bump versions in `plugin.json` and skill SKILL.md frontmatter
5. Tag commit; push

---

## Iter Ceremony Classifier (v3.42.0+ rule doc; v3.45.0+ Iter 65 RUNTIME ACTIVE)

Per Iter 63 SP1 spec §3.4: each iter has type PATCH/MINOR/MAJOR determined by deterministic git/filesystem inputs — NO LLM self-judgment. Same enum evaluated at TWO points (dual EP per spec meta-tune #1):

### Evaluation Point 1 (EP1) — Ceremony gating, PRE-work

Determines what artifacts to emit (CHANGELOG / spec / plan / audit). Inputs:

- `est_files_changed` = `git diff --stat HEAD | wc -l` (working tree vs HEAD)
- `est_halt_enum_diff` = grep working tree diff of vault-contract.md halt enum
- `est_new_skill_dir` = check working tree for new `plugins/mega-sdd/skills/<new>/` directories
- `breaking_marker` = user explicit flag `--iter-type=<>` OR scope-statement in brainstorming session
- Fallback (no working-tree changes yet): user's stated iter-type from brainstorming intent; default PATCH

### Evaluation Point 2 (EP2) — Version-bump labeling, POST-work

Determines plugin.json version bump (PATCH/MINOR/MAJOR) + CHANGELOG label. Inputs:

- `files_changed` = `git diff --name-only HEAD~1 HEAD | wc -l`
- halt-enum diff = `git diff HEAD~1 HEAD -- plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | grep -c "^[+-].*type:.*|"`
- new skill dir = `git diff HEAD~1 HEAD --name-status | grep "^A.*plugins/mega-sdd/skills/.*/SKILL.md"`
- handoff-contract field diff = same pattern on `handoff-contract.md`
- breaking change marker = `git log -1 --pretty=%B | grep -c "BREAKING CHANGE:"`

### Classifier criteria (same enum, both EPs)

| Iter type | Criteria (machine-checkable) | Required artifacts | Optional |
|---|---|---|---|
| **PATCH** | `files_changed ≤ 5` AND no halt-enum diff AND no new skill dir AND no `BREAKING CHANGE:` marker | CHANGELOG entry only | (nothing) |
| **MINOR** | `files_changed 5-15` OR new halt-enum entry OR new field in handoff-contract OR existing skill body modified | CHANGELOG entry | Spec (only if brainstorming skill invoked) |
| **MAJOR** | new skill dir OR `BREAKING CHANGE:` commit marker OR `files_changed > 15` | CHANGELOG + spec + plan | Audit (only if explicitly requested) |

### Precedence rule (uniform across plugin)

```
explicit user flag (--iter-type=major) > classifier output > default (PATCH)
```

### EP1 vs EP2 drift handling

If EP1 classified PATCH but EP2 reveals MAJOR criteria met (scope grew during work): emit drift warning + retroactively generate missing artifacts (spec/plan) under accelerated rules (compressed prose; not full ceremony). Log to telemetry as `ceremony_classifier_drift` event for Iter 68 analysis.

**Runtime impl SHIPPED in Iter 65 v3.45.0+:** `plugins/mega-sdd/scripts/classify-iter.sh` (deterministic bash wrapping git/grep). Invoked from orchestrate-flow Step 2.9 (EP1) + Step 6.9 (EP2). Emits `iter_classifier_output` + `iter_classifier_drift` telemetry events.

**Usage example:**
```bash
plugins/mega-sdd/scripts/classify-iter.sh --ep=EP1 \
  --explicit-flag=minor \
  --emit-telemetry=<project>/.mega-sdd/memory/telemetry.jsonl
# Output: JSON {iter_type, evaluation_point, criteria_matched, explicit_flag, inputs}
# Exit 0 = clean; 1 = invalid args; 2 = not in git repo
```

---

## Anti-Recursive Guard (v3.42.0+ rule doc; v3.45.0+ Iter 65 RUNTIME ACTIVE)

Per Iter 63 SP1 spec §7. Prevents validating-the-validation recursion + caps re-plan loops.

### RULE 1 — Re-plan triggers (CLOSED ENUM, no LLM judgment)

```
re-plan triggered by ONE of:
  execution_failed    | commit failed / test failed / halt fired
  ambiguity_increased | new contract mismatch detected POST-plan
  contract_mismatch   | handoff field TYPE drift caught at Iter 33 F4 validation gate
                      | (strictly TYPE drift — see RULE 1.5)
```

### RULE 1.5 — Explicit exclusion (binding CONFLICT NOT a re-plan trigger)

`bind-codebase` CONFLICT hard-gate stays human-halt (user resolves via `resolve-oq` OR vault edit). Guard MUST NOT loop binding gate into re-plan cycles. Scope of `contract_mismatch` is **HANDOFF FIELD TYPE DRIFT ONLY** — not broader semantic disagreement.

### RULE 2 — Hard caps per task (CONFIGURABLE DEFAULTS, tune post-Iter 68)

```
max_replan_count:    2  (DEFAULT — magic number; tune post-Iter 68 telemetry)
max_revalidate_count: 3  (DEFAULT — same caveat)
```

Exceeded → halt (NAMING DEFERRED to Iter 65 implementation per spec meta-tune #5). Iter 65 evaluates reuse-first options BEFORE creating new halt enum entry: (a) generalize `bolt_repeated_partial_failure` semantic, (b) add `quality_gate_failed` subtype, (c) LAST RESORT only — new halt enum entry.

### RULE 3 — No validating-the-validation

Validators are LEAF NODES in execution graph, not internal nodes. If validation step itself fails, halt directly — DO NOT spawn meta-validation. "Plan to validate the validation plan" is recursion → prohibited.

**Runtime impl SHIPPED in Iter 65 v3.45.0+:** `plugins/mega-sdd/scripts/check-recursion-budget.sh` + ephemeral state file `<project>/.mega-sdd/.replan-budget`. Halt naming decision (per meta-tune #5 reuse-first): `quality_gate_failed` with subtype `replan_budget_exceeded | revalidate_budget_exceeded` (Iter 58 pattern reused — NOT new halt enum entry).

**Day-0 telemetry instrumentation (per user mandate for tune #2 feasibility):**

Guard emits 4 new event_types from day-0 of soak window:
- `replan_triggered` — every re-plan increment (with trigger, before/after count)
- `revalidate_triggered` — every re-validate increment
- `replan_budget_exceeded` — when cap hit (with full trigger_history + halt details)
- `revalidate_budget_exceeded` — when cap hit

Without these events, tune #2 (revisit max_replan=2 / max_revalidate=3 defaults post-Iter-68) is impossible — Iter 68 cannot analyze distribution of re-plans without per-trigger logs.

**Usage example:**
```bash
plugins/mega-sdd/scripts/check-recursion-budget.sh \
  --action=increment-replan \
  --task-id=<task-uuid> \
  --trigger=execution_failed \
  --emit-telemetry=<project>/.mega-sdd/memory/telemetry.jsonl
# Output: JSON {status, replan_count, remaining_budget} OR {status: REPLAN_BUDGET_EXCEEDED, halt_to_emit}
# Exit 0 = within budget; 3 = REPLAN_BUDGET_EXCEEDED; 4 = REVALIDATE_BUDGET_EXCEEDED; 1 = invalid args
```

**RULE 1.5 enforcement verified:** script REJECTS `--trigger=bind_conflict` (or any non-closed-enum trigger) with exit 1 + helpful error citing RULE 1.5 binding CONFLICT exclusion. Tested at Iter 65 ship.

---

---

## 3-Tier Context Model (v3.44.0+, Iter 64 — declarations only; enforcement Iter 66)

Per spec §4.0 (Iter 63 SP1) + §4.3 (Iter 66 reframe). Iter 64 ships:

- **`plugins/mega-sdd/references/3-tier-context-model.md`** — HOT/SPECIALIST/COLD definitions + decision tree
- **`plugins/mega-sdd/references/skill-tier-manifest.yaml`** — per-skill ref classifications (LOCKED for soak window)

**Iter 64 does NOT enforce lazy-loading.** Skill bodies continue to load all refs unconditionally as before. The manifest is DATA COLLECTION only — telemetry validates tiers; Iter 66 enforces lazy-loading based on empirical data.

**No hot-context win claims pre-Iter-66.** Iter 64 = foundation only.

## Telemetry Collection (v3.44.0+, Iter 64 — LOCKED schema)

Per spec §4.1. Iter 64 ships:

- **`plugins/mega-sdd/references/telemetry-schema.md`** — LOCKED event schema (cannot evolve mid-soak; cannot backfill)
- Append-only `<project>/.mega-sdd/memory/telemetry.jsonl` writes by skills that emit telemetry events
- Opt-out via `--no-telemetry` flag on `/mega-sdd:auto` and `/mega-sdd:orchestrate-flow` OR `defaults.telemetry: false` in `<project>/.mega-sdd/config.yaml`

**When to log (per event_type):**

| event_type | Emitted by | Trigger |
|---|---|---|
| `skill_invoked` | Each skill | Start of skill body execution |
| `ref_loaded` | Each skill | When skill body loads a reference file |
| `halt_fired` | Each skill | When skill emits a halt |
| `tier_classification_decision` | Memory skill | When a ref is loaded; logs declared_tier from manifest + loaded_this_session |
| `iter_classifier_output` | Orchestrate-flow (Iter 65 runtime) | EP1 (chain start) + EP2 (chain end) |
| `iter_classifier_drift` | Orchestrate-flow (Iter 65 runtime) | When EP1 output != EP2 output |
| `activation_outcome` | Each skill | End of skill body execution (success / halted / aborted / downstream_failure) |
| `turn_loaded_summary` | Memory skill | Once per agent turn — aggregate of all ref_loaded events |

**Skill responsibility (markdown-driven convention):** every skill body MUST include telemetry-emit step at appropriate procedure points. Skills shipped pre-Iter-64 are exempt from retroactive update — Iter 66 will revisit instrumentation gaps as part of lazy-loading enforcement.

**Soak gates** (Iter 68 analysis prerequisite):
- ≥ 14 calendar days elapsed since Iter 64 ship
- ≥ 10 real chain runs logged
- Insufficient data → Iter 68 emits "DATA INSUFFICIENT" report; SP3 gate stays closed

---

## Plan/Act Mode (v3.46.0+, Iter 67 — COMPLEXITY-GATED via Iter 65 classifier)

Per spec §4.4. Cline-pattern dual-mode adopted but **NOT universal default** — gated by complexity classifier output. Economics: cheap iters skip plan ceremony; expensive iters require explicit two-phase.

### Mode definitions

**Plan mode (cheap, read-only):**
- Skill body LOADS but does NOT execute writes
- Outputs proposed actions list + acceptance criteria + estimated scope
- NO file writes, NO commits, NO git ops, NO Bash with side effects
- User reviews proposed actions before transition to Act
- Equivalent to Cline's Plan mode: "non-destructive reasoning phase where you refine the approach before any code is written"

**Act mode (expensive, write-enabled):**
- Skill body executes per its procedure
- File writes, commits, git ops, Bash with side effects allowed
- Equivalent to Cline's Act mode: "execute that plan asking for approval before tool use considered irreversible"

### Complexity gating (per `classify-iter.sh` output)

| Iter type (classifier output) | Plan/Act behavior |
|---|---|
| **PATCH** | Direct Act mode. NO Plan phase. (Economics: PATCH iters are by definition small + non-breaking; planning overhead exceeds value.) |
| **MINOR** | Act mode default. User can opt-in to Plan-first via `--plan` flag. (Most MINOR iters have known scope; Plan-first is helpful for unfamiliar territory.) |
| **MAJOR** | **Plan mode FIRST, mandatory.** User reviews proposed actions. Transition to Act requires explicit user gesture: `--act` flag OR `/mega-sdd:act` continuation command OR explicit text acknowledgment. NO direct-Act path for MAJOR. |

**Precedence (uniform across plugin, same as classifier):**
```
explicit user flag (--plan / --act) > classifier-determined default > PATCH default
```

User can force Plan mode on PATCH with `--plan`. User can force direct Act on MAJOR with `--act` BUT requires confirmation prompt (single AskUserQuestion warning: "MAJOR iter without Plan phase — proceed? [Y/N]") — this is an explicit safety gate, not a free pass.

### Plan-to-Act transition protocol

When Plan mode completes:

1. Plan output emits to chat: structured list of proposed actions + acceptance criteria + classifier inputs.
2. Plan output APPENDED to ephemeral `<project>/.mega-sdd/.plan-pending` file (JSON):
   ```json
   {
     "session_id": "<UUID>",
     "task_id": "<UUID>",
     "plan_emitted_at": "<ISO8601>",
     "iter_type": "MAJOR",
     "proposed_actions": ["..."],
     "acceptance_criteria": ["..."]
   }
   ```
3. User reviews; transitions via:
   - `--act` flag on next invocation, OR
   - `/mega-sdd:act` continuation command (reads `.plan-pending` and proceeds), OR
   - Explicit text in next message: "act on the plan" / "execute" / "approved"
4. Act mode reads `.plan-pending`, executes proposed actions, deletes `.plan-pending` on success.

If `.plan-pending` exists from prior session AND user invokes new skill: orchestrate-flow Step 2.95 checks for stale plan → warns "stale plan from <ts>; rerun /mega-sdd:plan or delete `.plan-pending`".

### Anti-recursion interaction (RULE 1.5 reaffirmed)

Plan mode is NOT a validator. Validators are leaf nodes per Anti-Recursive Guard RULE 3. Plan mode is a PHASE (reasoning before execution), not a validation step. Plan output does NOT trigger `validate-the-validation` recursion; if user rejects Plan output and asks for re-plan, that counts as ONE `replan_triggered` event (via check-recursion-budget.sh) with trigger `ambiguity_increased` — subject to max_replan_count cap.

### Process integration

`/mega-sdd:auto` and `/mega-sdd:orchestrate-flow` flags:
- `--plan` — force Plan mode regardless of classifier output (opt-in)
- `--act` — force direct Act mode regardless of classifier output (requires confirmation prompt for MAJOR)
- `--plan-then-act` — explicit two-phase for any iter type (overrides both PATCH-direct-act and MAJOR-mandatory-plan)

Default behavior (no flags): follow classifier output → PATCH=direct-act / MINOR=act / MAJOR=plan-first.

**Runtime status (v3.46.0+, Iter 67):** orchestrate-flow Step 2.95 (NEW) gates the mode decision; reads Iter 65 EP1 classifier output → branches to Plan or Act. Implementation: markdown-driven procedural logic; no new bash scripts (the `.plan-pending` state file is JSON managed by skill bodies).

## Soak Shakedown Protocol (v3.46.0+, Iter 67 — last runtime change before soak freeze)

Per user mandate at Iter 67 ship: **first 1-2 real chain runs after Iter 67 don't count toward soak threshold until verified.**

**Why:** Iter 65 (classifier + guard runtime) + Iter 67 (Plan/Act gating) both active same-day, zero wild-history. Verify interaction doesn't bug-fail real chain runs BEFORE accumulating ≥10 runs on potentially-broken stack.

### Shakedown rules

1. **First 1-2 real chain runs after Iter 67 ship = SHAKEDOWN.**
2. Telemetry events from shakedown runs MARKED with `payload.shakedown: true` (skill bodies emit this flag when run is among first 2 post-Iter-67).
3. Iter 68 analysis EXCLUDES shakedown-marked runs from soak count.
4. If shakedown runs reveal interaction bugs between Iter 65 + Iter 67 + 64 telemetry: **fix-forward day-0/1 while window still homogeneous**. Schema additions allowed per LOCKED schema rules.
5. After 2 shakedown runs complete cleanly → freeze runtime changes; soak window starts counting toward ≥10 real runs.

### What "real chain run" means for soak counting

- User invokes `/mega-sdd:auto` (or `/mega-sdd:orchestrate-flow`) on a real project
- Chain produces at least one skill invocation event with handoff completed
- NOT a test run (`payload.is_test_run: true` excluded)
- NOT a shakedown run (`payload.shakedown: true` excluded for first 2)
- Skill chain involves writes (vault generation, binding, units, bolts, etc.) — read-only diagnostic runs don't count

### Freeze period

After Iter 67 ships + 1-2 shakedown runs verified: **NO runtime changes until Iter 66 (post-soak)**. This includes:
- No new skills
- No new halt enum entries
- No new event_types in telemetry schema (additions ALLOWED per mid-soak rules but discouraged unless necessary)
- Doc-only / cosmetic edits are OK (PATCH-classified per Iter 65 classifier)

Iter 66 ships ONLY when:
- ≥ 14 calendar days elapsed since Iter 64 ship
- ≥ 10 non-shakedown real chain runs logged
- Iter 68 analysis completed → manifest tuning recommendations available

If freeze period reveals critical bug requiring runtime change: emergency fix-forward allowed, but RESTARTS the shakedown clock (next 2 runs after fix-forward = shakedown again).

## Co-author attribution

Mega-SDD acknowledges the [superpowers](https://github.com/obra/superpowers) project by Jesse Vincent as the design inspiration for plugin patterns (anchor skill, hook injection, skill content structure). See `skills/_vendored/ATTRIBUTION.md`.

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

---

## Fork A scope (CURRENT) vs Fork B (FUTURE)

Added Iter 67.5 (v3.48.0) after audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md` revealed Iter 64-67 shipped multiple "runtime active" claims that were never artifact-verified. The honest reset:

**Fork A (CURRENT — what is actually shipped):**
- Skill bodies + references as design vocabulary and AI-coding-prompt scaffolding
- Claude Code **hooks** — observe AND block:
  - SessionStart: anchor injection (Iter 67.5 fix)
  - PostToolUse: ref_loaded / skill_invoked telemetry (Iter 66a/67.5); Write/Edit auto-revalidate trigger (Iter 67.6)
  - PreToolUse: tool blocking via `{"continue": false, "stopReason": "..."}` — both for content gating (`mega-sdd:execute-bolts` blocked if validator FAIL) AND anti-self-bypass (agent attempts to `rm` state files blocked) (Iter 67.6)
  - Stop: turn_end_marker with real harness usage (Iter 66a/67.5)
- **[HOOK-VALIDATE] artifact integrity validators** — deterministic scripts + state files (OVERWRITE-NOT-APPEND, current truth). Iter 67.6 ships slice 1 (binding→units OQ-IDs). **Iter 78 (v3.69.0) adds 7 code-delivery quality validators** — `validate-flow-coverage` (PreToolUse Branch 5), `validate-sibling-consistency` (Branch 7), `validate-cross-cutting-registration` (Branch 11), render-test via `validate-unit-spec` (Branch 6), `validate-ui-quality` (Branch 8), `validate-dispatch-prompt` (Branch 9), and operator-UX via `validate-vault-oqs` (Branch 10) — all tech-agnostic (signatures from the framework-convention pack via `scripts/_lib/resolve-framework-pack.sh`; SKIP when a pack omits a section) and fixture-verified against the `new-tradefinance-import` git history (`tests/fixtures/code-delivery/**`). See `plugins/mega-sdd/references/fork-a-recovery-map.md` for the full classification + slice roadmap and `docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md` for the design. **Iter-78.1 invariants (do NOT regress — `docs/superpowers/audits/2026-06-02-e2e-integration-audit.md`):** (1) the two EXTENSION gates (render-test via `validate-unit-spec`, operator-UX via `validate-vault-oqs`) MUST gate on a precise `halt_type` COUNT, never `status==FAIL` — else their pre-existing checks would spuriously block bolts; any new issue type on them is non-blocking until a PreToolUse branch opts it into the filter. (2) `_universal.md` intentionally backstops only the reasoning PRINCIPLE (prose-only bodies, no machine-parseable signatures) — adding concrete signatures there would silently convert graceful SKIPs into runs on every stack. (3) Every code-delivery validator reads ALL stack-specifics from the pack via `_lib/resolve-framework-pack.sh` and uses `errors="replace"` on reads (a crash = silent fail-open).
- Advisory bash scripts in `plugins/mega-sdd/scripts/` that humans can run by hand
- Markdown-driven anti-hallucination rails inside skill bodies — model compliance is best-effort and NOT enforced; superseded by [HOOK-VALIDATE] where applicable (e.g., generate-units Step 12.5.g is now defense-in-depth alongside the validator)

**Fork B (FUTURE — explicitly parked, 4 items only after Iter 67.6 reclassification):**
- Implicit re-plan detection (model loops without explicit gesture or observable failure signal)
- Lazy-loading tier enforcement (mid-reasoning skip of refs)
- Tamper-proof state against the human user (intentionally NOT in Fork B scope — user is not the adversary)
- Mid-turn intervention (force Y before X mid-reasoning)

**What WAS parked at Iter 67.5 and got reclassified at 67.6:**
- Classifier output emission / drift / ceremony gating → [HOOK] (Stop + PreToolUse)
- Anti-recursive guard budget cap → [HOOK] (explicit-trigger + failure-driven via PostToolUse halt detection — per Call #2 ACK)
- Plan/Act explicit toggle + auto-gating per classifier → [HOOK] (SessionStart + state file + PreToolUse)
- Tier classification observation event → [HOOK] (PostToolUse enrichment)
- Handoff integrity (binding↔units↔bolts) → [HOOK-VALIDATE] (one slice shipped 67.6; others are pattern-clones)

These are slice candidates, not committed work. Slice discipline: prove each in real-run before expanding.

**Why the original retraction was correct, AND why reclassification works:** the failure mode was "prose tells the model to invoke a script; model may or may not." The fix is moving the trigger out of prose: hooks fire deterministically; validators run deterministically; the model can't no-op them. That's not "Fork B" — that's correct Fork A engineering. The audit was right that prose-enforcement fails; Iter 67.6 just sharpens the response from "park it all" to "park only what truly needs runtime control."

**Operational consequence for AI agents reading this doc:**
- Treat any "Runtime ACTIVE" or "Runtime SHIPPED" claim from Iter 64-67 as RETRACTED unless explicitly re-validated by Iter 68+
- Treat the criteria tables, halt enums, and rule documents below as DESIGN VOCABULARY — they describe how the system *should* work; they do not enforce it in Fork A
- Hook-emitted telemetry events ARE reliable (PostToolUse + Stop) — those are the only artifacts you can trust to mean what they say

---

## Iter Ceremony Classifier (v3.42.0+ rule doc; Iter 65 runtime RETRACTED at Iter 67.5)

> **Status (Iter 67.5 honesty/cleanup, v3.48.0):** The Iter 65 claim that `classify-iter.sh` is invoked at orchestrate-flow Step 2.9 (EP1) + Step 6.9 (EP2) is RETRACTED. Audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md` §C verified: zero skill bodies Bash-invoke the script in any real chain run, and no `iter_classifier_output` event has ever appeared in telemetry. The wire-up was prose only.
>
> **Status going forward:** the script remains in `plugins/mega-sdd/scripts/classify-iter.sh` as an ADVISORY tool — a developer can run it by hand (`bash classify-iter.sh --ep=EP1`) to see what an iter would be classified as. It is NOT enforced. Classifier-driven ceremony gating is parked as Fork-B-future (requires a control plane the model can't no-op).
>
> The criteria table below is kept as the *intent* of how iters should be classified; treat it as guidance for the human-in-the-loop deciding what artifacts to write, NOT as runtime-enforced behavior.

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

**Runtime status (RETRACTED at Iter 67.5):** the script `plugins/mega-sdd/scripts/classify-iter.sh` exists and works correctly when invoked directly. Iter 65 claimed it was wired into orchestrate-flow Step 2.9 / 6.9 and emits telemetry events automatically — that claim was prose-only and is now retracted. Use as an advisory tool only.

**Advisory usage example (for humans / explicit invocation):**
```bash
plugins/mega-sdd/scripts/classify-iter.sh --ep=EP1 \
  --explicit-flag=minor \
  --emit-telemetry=<project>/.mega-sdd/memory/telemetry.jsonl
# Output: JSON {iter_type, evaluation_point, criteria_matched, explicit_flag, inputs}
# Exit 0 = clean; 1 = invalid args; 2 = not in git repo
```
The `--emit-telemetry` flag works when the script is invoked, but nothing invokes it automatically in Fork A.

---

## Anti-Recursive Guard (v3.42.0+ rule doc; Iter 65 runtime RETRACTED at Iter 67.5)

> **Status (Iter 67.5):** the Iter 65 claim that `check-recursion-budget.sh` is invoked automatically on re-plan / re-validate is RETRACTED. Audit §D verified: the script is referenced by ZERO skill bodies (not even `orchestrate-flow/SKILL.md`). No `.replan-budget` state file has ever been created in any real run. The rules below remain as design intent for the eventual Fork-B control plane; they are NOT enforced in Fork A.



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

**Runtime status (RETRACTED at Iter 67.5):** the script `plugins/mega-sdd/scripts/check-recursion-budget.sh` exists and works correctly when invoked directly. Iter 65 claimed it was wired automatically into re-plan / re-validate trigger points — that claim was prose-only (no skill body references the script) and is now retracted. The four event types (`replan_triggered`, `revalidate_triggered`, `replan_budget_exceeded`, `revalidate_budget_exceeded`) are PARKED in the telemetry schema as Fork-B-future per `plugins/mega-sdd/references/telemetry-schema.md`. No `.replan-budget` state file is created in Fork A.

**Advisory usage example (for humans / explicit invocation only):**
```bash
plugins/mega-sdd/scripts/check-recursion-budget.sh \
  --action=increment-replan \
  --task-id=<task-uuid> \
  --trigger=execution_failed \
  --emit-telemetry=<project>/.mega-sdd/memory/telemetry.jsonl
# Output: JSON {status, replan_count, remaining_budget} OR {status: REPLAN_BUDGET_EXCEEDED, halt_to_emit}
# Exit 0 = within budget; 3 = REPLAN_BUDGET_EXCEEDED; 4 = REVALIDATE_BUDGET_EXCEEDED; 1 = invalid args
```

**RULE 1.5 enforcement verified at Iter 65 ship:** script REJECTS `--trigger=bind_conflict` (or any non-closed-enum trigger) with exit 1 + helpful error citing RULE 1.5 binding CONFLICT exclusion. This is a script-side property — it still holds, but the script being correct in isolation doesn't enforce anything in Fork A since no chain invokes it.

---

---

## 3-Tier Context Model (v3.44.0+ docs; enforcement parked Fork-B-future at Iter 67.5)

Per spec §4.0 (Iter 63 SP1). Iter 64 shipped:

- **`plugins/mega-sdd/references/3-tier-context-model.md`** — HOT/SPECIALIST/COLD definitions + decision tree
- **`plugins/mega-sdd/references/skill-tier-manifest.yaml`** — per-skill ref classifications

**Status (Iter 67.5):** these documents remain as a design vocabulary for talking about which refs should be loaded when. Iter 64 explicitly did NOT enforce lazy-loading; that was always Iter 66's job. Iter 66 lazy-load enforcement is now PARKED as Fork-B-future — model-driven lazy-load decisions are exactly the kind of thing the model can no-op on. Reliable lazy-loading requires the Fork-B control plane.

## Telemetry Collection (v3.48.0+, Iter 67.5 — Fork A scope lock)

Per spec §4.1. Iter 64 → 66a → 67.5 evolution (audit-corrected):

- **Iter 64:** locked an aspirational 16-event schema; assumed skill bodies would emit per markdown convention.
- **Iter 66a:** discovered (via grep) that ZERO skill bodies emit; rewired emission via Claude Code hooks.
- **Iter 67.5 (this version):** Iter 66a real-run audit confirmed 1 of 16 event types was emitting; 11 control-layer events have NO working emitter and depend on Iter 65/67 runtime claims which are themselves retracted. Schema shrunk to live events only. Control-layer events parked Fork-B-future. See `plugins/mega-sdd/references/telemetry-schema.md` for the live schema.

**Live emitters (Fork A — what is actually collected):**

| Source | Events | Reliability |
|---|---|---|
| `plugins/mega-sdd/hooks/post-tool-use` (PostToolUse, matcher `Read\|Skill\|Bash`) | `ref_loaded` (Read OR Bash-derived), `skill_invoked` (rare — most activations bypass Skill tool) | HIGH for parent-thread Read+Bash; subagent-internal reads INVISIBLE (Fork A limitation) |
| `plugins/mega-sdd/hooks/stop` (Stop) | `turn_end_marker` with real harness-reported `usage` (input_tokens, cache_read_input_tokens, etc.) from transcript_path | HIGH if harness invokes Stop for project CWD — verify via `hook-debug.log` |

**Diagnostic side-channel (Iter 67.5):** the Stop hook also writes one JSON line per fire to `<project>/.mega-sdd/memory/hook-debug.log`, regardless of telemetry-exists gate (but still honoring opt-out). If this file doesn't grow during a real turn, the Stop hook is NOT being invoked — that's a Claude Code harness / installation problem, not a hook bug.

**Parked events (PARKED — Fork-B-future, NOT emitted in Fork A):** `iter_classifier_output`, `iter_classifier_drift`, `replan_triggered`, `revalidate_triggered`, `replan_budget_exceeded`, `revalidate_budget_exceeded`, `plan_mode_entered`, `act_mode_entered`, `plan_act_transition`, `tier_classification_decision`, `turn_loaded_summary` (derived offline). See telemetry-schema.md §Fork-B-future for rationale per event.

**Best-effort events (skill-body markdown emission — UNRELIABLE):** `halt_fired`, `activation_outcome`. Schema documents these as supplementary; Iter 68 analysis cannot rely on them being present.

**Opt-out:** `telemetry: false` in `<project>/.mega-sdd/config.yaml` suppresses ALL hook writes (including diagnostic log). `--no-telemetry` flag on slash commands is advisory only (hooks don't see slash-command flags).

**Soak gates (REVISED Iter 67.5):**
- ≥ 14 calendar days elapsed since **Iter 67.5 verified-write date** (clock starts on first real run that produces ≥1 `ref_loaded` AND ≥1 `turn_end_marker` in the same session)
- ≥ 10 real chain runs with non-empty `turn_end_marker` events
- `hook-debug.log` confirms Stop hook fires for the project CWD (a sanity check before counting any session toward the 10-run threshold)

Iter 68 cannot analyze classifier accuracy / recursion budget distribution / Plan/Act behavior — those are Fork-B-future. Iter 68 in Fork A is limited to: ref-load distribution per skill, per-turn token cost from harness numbers, Bash-vs-Read coverage estimate.

---

## Plan/Act Mode (v3.46.0+ docs; Iter 67 runtime RETRACTED at Iter 67.5)

> **Status (Iter 67.5):** the Iter 67 claim that orchestrate-flow Step 2.95 gates Plan vs Act mode per classifier output is RETRACTED. Audit §E verified: no `.plan-pending` state file has ever been written, zero `plan_mode_entered` / `act_mode_entered` / `plan_act_transition` events in real-run telemetry, no skill body actually reads the classifier output (which itself isn't produced — see §Iter Ceremony Classifier retraction). The entire dependency chain (classifier → output → branch → state file → telemetry) was prose.
>
> Plan/Act gating is PARKED as Fork-B-future. The Cline-pattern semantic below is preserved as design intent for the eventual control plane; it is NOT enforced in Fork A. Users can still explicitly request "plan first" or "act directly" in their prompts — that's a manual instruction, not a runtime gate.



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

**Runtime status (RETRACTED Iter 67.5):** Iter 67 claimed orchestrate-flow Step 2.95 gates mode based on classifier output. Audit verified zero gating ever executed (cascade from broken classifier wire-up). Step 2.95 in SKILL.md is markdown prose with no enforcement layer; treat as advisory intent for the human reader, not runtime behavior. Real Plan-vs-Act decisions are human-driven via explicit user direction.

## Soak Shakedown Protocol (v3.48.0+, Iter 67.5 — Fork A scope)

> **Iter 67.5 revision:** the original shakedown protocol assumed Iter 65 + 67 runtime were active. Both are now retracted. Shakedown discipline still applies — but only to the Fork A telemetry surfaces (hooks). Re-stated below.

**First 1-2 real chain runs after Iter 67.5 ship don't count toward soak threshold until verified.**

**Why:** Iter 67.5 changes hook semantics (added Bash matcher, instrumented Stop hook, transcript-usage extraction). Want one or two real runs to confirm the hooks emit cleanly + `hook-debug.log` shows the harness invokes Stop.

### Shakedown rules (Fork A — Iter 67.5)

1. **First 1-2 real chain runs after Iter 67.5 ship = SHAKEDOWN.** Operationally identified by the user (no `payload.shakedown` marker — skill-body convention is unreliable; the user just remembers).
2. Iter 68 analysis EXCLUDES the first 1-2 sessions from the ≥10 threshold.
3. If shakedown reveals hook bugs (e.g., Stop hook still not firing, `hook-debug.log` empty, transcript usage extraction broken): fix-forward immediately; shakedown clock resets.
4. After 2 shakedown runs complete cleanly + `hook-debug.log` has lines + `turn_end_marker` events appear with non-empty `usage` payload → freeze hooks; soak window starts counting toward ≥10 real runs.

### What "real chain run" means for soak counting (Fork A)

- User invokes a mega-sdd skill (auto, orchestrate-flow, generate-intent, etc.) on a real project (`.mega-sdd/` exists in CWD)
- Chain produces ≥1 `ref_loaded` AND ≥1 `turn_end_marker` event in the same `session_id`
- Skill chain involves writes (vault generation, binding, units, bolts) — read-only diagnostic runs don't count
- First 1-2 such sessions = shakedown; remaining count toward the ≥10 threshold

### Freeze period (Fork A)

After Iter 67.5 ships + 1-2 shakedown sessions verified: **NO hook changes until Iter 68 analyze ships**. This includes:
- No new hooks
- No matcher changes
- No new event_types (hooks-emitted)
- Doc-only / cosmetic edits are OK

Iter 68 ships ONLY when:
- ≥ 14 calendar days elapsed since Iter 67.5 verified-write date
- ≥ 10 non-shakedown real chain runs logged
- `hook-debug.log` confirms Stop hook fires reliably

If freeze period reveals critical hook bug: emergency fix-forward allowed, but RESTARTS the shakedown clock (next 2 sessions after fix-forward = shakedown again).

## Co-author attribution

Mega-SDD acknowledges the [superpowers](https://github.com/obra/superpowers) project by Jesse Vincent as the design inspiration for plugin patterns (anchor skill, hook injection, skill content structure). See `skills/_vendored/ATTRIBUTION.md`.

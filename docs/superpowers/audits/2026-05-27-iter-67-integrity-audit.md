# Iter 67 Integrity Audit — 2026-05-27

## Methodology

Adversarial stance per user mandate: every component is presumed broken until proven working by real-run artifacts. SKILL.md / CLAUDE.md / spec wording is treated as a CLAIM, never as evidence of execution. Valid evidence is restricted to (a) `telemetry.jsonl` events actually written to disk, (b) state files (`.replan-budget`, `.plan-pending`, `.citation-map.json`), (c) vault artifacts (intent / Open-Questions / binding / units / bolts), (d) file timestamps + git log. Invalid evidence: "the skill body says it runs at Step X" / "the script exists and is +x" / "smoke test in isolation passed." Cross-cutting wire-up was verified by grepping skill bodies for actual script invocations. Two recent ships (Iter 64 telemetry collection, Iter 66a turn_end_marker) failed in real orchestration after passing doc-layer review; this audit operates at the artifact layer only.

## Baseline: real-run artifacts inventory

Real-run target: `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import/.mega-sdd/`

Artifacts present (timestamped):

| Path | Size | Mtime |
|---|---:|---|
| `memory/telemetry.jsonl` | 351 B | 2026-05-27 00:28 local |
| `vaults/binding.md` (phase-1) | 45,358 B | 2026-05-23 12:11 |
| `vaults/binding-phase-2.md` | ~30 KB | (May 23-26 window) |
| `vaults/DRIFT-REPORT-phase2.md` | ~34.6 KB | (May 23-26 window) |
| `vaults/tradefinance-phase-1-foundation-bound/units/U-001…U-027 + _index.md` | 5K avg | 2026-05-23 → 2026-05-26 |
| `vaults/tradefinance-phase-2-workflows-bound/units/U-001…U-027.md` | 4-6K avg | 2026-05-26 16:43 |
| `vaults/tradefinance-phase-1-foundation-bound/fsd/.citation-map.json` | 6.3 KB | (FSD-emit Iter; not a runtime state file) |
| `vaults/tradefinance-phase-2-workflows/{00-index, 01..06, vault.json}` | full vault | present |
| `knowledge-base/{00..50}/*.md` | KB present | present |
| `codebase/codebase-map.md` + `starterkit-context.yaml` | present | present |

Artifacts **ABSENT** that the design promises should exist after multiple chain runs:

- No `Open-Questions/` directory in any vault (OQs live inline in `00-index.md` / per-doc files instead)
- No `bolts/` directories under any bound vault
- No `bolt-report.md` files anywhere
- No `.replan-budget` state file anywhere in TF Import
- No `.plan-pending` state file anywhere in TF Import
- No top-level `.citation-map.json` (only one exists scoped to the phase-1 FSD emission)

Telemetry contents (full file):

```
{"ts":"2026-05-26T17:28:15Z","skill":"orchestrate-flow","event_type":"ref_loaded",
 "session_id":"7795a3cc-71c0-4ea5-8d47-7b50c49274e8","hook_source":"PostToolUse",
 "payload":{"file_path":"/Users/.../tradefinance-import/.mega-sdd/vaults/DRIFT-REPORT-phase2.md",
            "lines":366,"bytes":35471,"estimated_tokens":8867}}
```

**One event. Total.** Timestamp UTC `2026-05-26T17:28:15Z` reconciles to local `2026-05-27 00:28` (PDT/-0700) — emitted during a prior real chain run, not by this audit session.

Hook executables + scripts:

| File | Mode | Exists |
|---|---|---|
| `plugins/mega-sdd/hooks/hooks.json` | 644 | yes |
| `plugins/mega-sdd/hooks/post-tool-use` | 755 | yes |
| `plugins/mega-sdd/hooks/stop` | 755 | yes |
| `plugins/mega-sdd/hooks/session-start` | 755 | yes |
| `plugins/mega-sdd/scripts/classify-iter.sh` | 755 | yes |
| `plugins/mega-sdd/scripts/check-recursion-budget.sh` | 755 | yes |

---

## Component A. Hooks fire in real Claude Code orchestration

**Claim:** SessionStart injects `using-mega-sdd` anchor on session start when SDD signals exist in CWD; PostToolUse fires for `Read|Skill` matcher; Stop fires at agent turn end emitting `turn_end_marker`.

**Evidence found (real-run artifacts):**

- PostToolUse: **fired exactly once** in TF Import history — the lone `ref_loaded` event in telemetry.jsonl. This proves the hook chain mechanically works (Claude Code harness invokes `run-hook.cmd post-tool-use`, the script parses stdin, filters, appends a line). Hook IS firing — the question is coverage.
- Stop hook: **zero `turn_end_marker` events** in telemetry.jsonl across the entire history of TF Import work (≥1 multi-turn chain runs based on existing units / binding / DRIFT-REPORT artifacts). The Stop hook's only condition gate is "telemetry.jsonl exists" (line 60 of `hooks/stop`); telemetry.jsonl HAS existed since May 26 17:28, yet no Stop event has appended. **Stop hook is not firing OR not finding the right CWD.**
- SessionStart: SessionStart signal detection (lines 14-19 of `hooks/session-start`) probes `${cwd}/docs/mega-sdd | vaults | bound-vault | units | binding.md | codebase-map.md`. TF Import root contains ONLY `.mega-sdd/` (the v3.4+ canonical layout) — `vaults/`, `binding.md`, and `codebase-map.md` exist nested INSIDE `.mega-sdd/`, never at cwd root. **None of the 6 probed signals match in the canonical layout.** The anchor cannot be injected for any v3.4+ project.

**Verdict:**
- SessionStart: **BROKEN** (one-line regression introduced by v3.4 path migration; signal list never updated).
- PostToolUse: **WORKING-BUT-NARROW**. Hook IS firing, but matcher is `Read|Skill` — most real-chain reference loading happens via Bash (`cat`, `grep`, `find`, `head`) inside subagent threads, which the matcher cannot capture. One real chain run produced a single ref_loaded event, suggesting the vast majority of mega-sdd reference loads bypass the Read tool.
- Stop: **BROKEN** (executable, condition gate met, but zero emissions across multiple real turns/sessions).

**Gap:** 
- SessionStart signal probe assumes pre-v3.4 layout. Add `.mega-sdd` to signal list.
- PostToolUse hook's only telemetry surface is `Read` tool calls — under-counts true reference loading by an unknown but likely large factor (1 event recorded across multiple real chain runs that produced binding + units + drift reports = obvious under-count).
- Stop hook silently fails. No telemetry on why (it's an async hook; failure is invisible). Needs instrumented self-test on a real CWD-active turn.

**Recommended fix:**
1. `hooks/session-start` line 14: append `.mega-sdd` to the signal list (single-line fix).
2. `hooks/post-tool-use` line 17 (the `hooks.json` matcher): broaden matcher to `Read|Skill|Bash` AND in the script, detect `Bash` invocations whose first argument matches `cat|grep|head|find` on mega-sdd paths. OR accept the gap and document that ref_loaded under-counts subagent Bash-driven loads.
3. Instrument `hooks/stop`: add a one-time debug emit on any invocation, regardless of telemetry-exists gate, to confirm whether Claude Code's harness is even invoking the hook for this project's CWD. Once verified, restore the gate.

---

## Component B. Skill invocation tracking

**Claim:** PostToolUse with matcher `Skill` emits `skill_invoked` for `mega-sdd:*` or `using-mega-sdd` Skill-tool invocations.

**Evidence found:** `grep "skill_invoked" telemetry.jsonl` → 0 hits in TF Import.

**Verdict:** **UNVERIFIABLE-AS-DESIGNED** (effectively BROKEN by design choice).

**Gap:** Most mega-sdd skill activation does NOT happen via the Skill tool. Skills auto-activate from SessionStart anchor injection, from in-thread CLAUDE.md context, and from inline orchestration text — none of which use the Skill tool. The hook matcher `Skill` only captures the explicit `/skill-name` invocation path, which is rare in real chain runs (mega-sdd skills typically chain via internal orchestrate-flow logic, not Skill-tool dispatch). 

Even if SessionStart worked (Component A), it injects the anchor WITHOUT calling the Skill tool, so `skill_invoked` would still be 0.

**Recommended fix:** Either (a) accept that `skill_invoked` is meaningful only for explicit user `/mega-sdd:*` invocations and rescope the schema; or (b) emit `skill_invoked` from skill bodies themselves at activation (which CLAUDE.md §Telemetry Collection explicitly admits is unreliable: "best-effort per-skill emission via markdown convention; depends on the model executing emit-step instructions").

---

## Component C. Classifier consumers (Iter 65 — classify-iter.sh)

**Claim:** `plugins/mega-sdd/scripts/classify-iter.sh` invoked from orchestrate-flow Step 2.9 (EP1) + Step 6.9 (EP2). Output consumed by ceremony / Plan-Act / budget decisions. Emits `iter_classifier_output` + `iter_classifier_drift` telemetry events.

**Evidence found (real-run artifacts):**
- `grep "iter_classifier_output\|iter_classifier_drift" telemetry.jsonl` → 0 hits.
- `grep -rl "classify-iter.sh" plugins/mega-sdd/skills/` → ONE file: `skills/orchestrate-flow/SKILL.md` (Step 2.9 textual description only — markdown instruction, not a Bash invocation in a skill code path).
- No skill body anywhere in `plugins/mega-sdd/skills/` contains a Bash invocation of `classify-iter.sh`.

**Verdict:** **BROKEN — wire-up is fictional.**

**Gap:** The script exists, is executable, and the orchestrate-flow SKILL.md tells the agent "invoke `classify-iter.sh` at Step 2.9" — but there is no enforcement that the agent actually runs that command. Across all TF Import real chain runs that produced binding.md, units, bolts (none), and drift reports, ZERO classifier outputs are recorded. Either (a) the agent never reached Step 2.9 in any run (unlikely — Step 2.9 is between routing and chain build, which units/binding evidence requires having passed), or (b) the agent read the instruction but did not execute the Bash call. This is exactly the failure mode of Iter 64 telemetry: "convention was a fiction."

Even IF the classifier emitted, no consumer reads its JSON output: Step 2.95 (Plan/Act gating) refers to "Step 2.9 EP1 classifier output" but does not read a file — it reads what was presumably emitted to chat. Persistence + consumer wiring both absent.

**Recommended fix:**
1. Move classifier invocation OUT of skill-body markdown instructions and INTO the orchestrate-flow hook chain (e.g., a pre-step shell script the harness executes deterministically, or an inline `bash -c` in the SKILL.md that uses fenced-code-with-required-execution semantics).
2. Persist classifier output to `<project>/.mega-sdd/.iter-classifier.json` so downstream consumers (Step 2.95) have a state-file to read instead of relying on transient chat output.

---

## Component D. Anti-recursive guard (Iter 65 — check-recursion-budget.sh)

**Claim:** Script invoked on re-plan / re-validate. Maintains `.replan-budget` state file. Emits `replan_triggered | revalidate_triggered | *_budget_exceeded` events.

**Evidence found:**
- `grep "replan_triggered\|revalidate_triggered\|*_budget_exceeded" telemetry.jsonl` → 0 hits.
- `find tradefinance-import -name ".replan-budget"` → 0 hits. State file does NOT exist.
- `grep -rl "check-recursion-budget.sh" plugins/mega-sdd/skills/` → 0 hits. **Not referenced by any skill body** (not even orchestrate-flow's SKILL.md mentions the script).

**Verdict:** **BROKEN — wire-up is fictional, worse than C.**

**Gap:** Component C's classifier is at least mentioned in orchestrate-flow SKILL.md. The recursion-budget script is mentioned NOWHERE in any skill body. It exists as an executable script in `plugins/mega-sdd/scripts/`, but there is no skill that calls it. Re-plan and re-validate events have no surface that emits these telemetry events; the day-0 instrumentation mandate from CLAUDE.md ("Without these events, tune #2 is impossible") is unmet.

**Recommended fix:**
1. Locate the actual re-plan / re-validate trigger sites (`executing-plans` skill body? `bolt-failure` handlers?) and inject `bash plugins/mega-sdd/scripts/check-recursion-budget.sh ...` calls there.
2. Until step 1: declare the anti-recursive guard runtime as NOT shipped. CLAUDE.md currently claims "Runtime impl SHIPPED in Iter 65 v3.45.0+" — that claim is false; only the script binary shipped.

---

## Component E. Plan/Act gating (Iter 67)

**Claim:** orchestrate-flow Step 2.95 reads classifier EP1 output, branches to Plan mode for MAJOR / Act for PATCH-MINOR. Persists Plan-mode state to `.plan-pending`. Emits `plan_mode_entered | act_mode_entered | plan_act_transition` events.

**Evidence found:**
- `find tradefinance-import -name ".plan-pending"` → 0 hits.
- `grep "plan_mode_entered\|act_mode_entered\|plan_act_transition" telemetry.jsonl` → 0 hits.
- `grep -rl ".plan-pending" plugins/mega-sdd/skills/` → ONE file: `skills/orchestrate-flow/SKILL.md` (Step 2.95 textual description only).
- `grep -rl "plan_mode_entered\|act_mode_entered" plugins/mega-sdd/skills/` → 0 hits. No emission instruction exists in any skill body.

**Verdict:** **BROKEN — depends entirely on Component C (classifier) which is itself broken.**

**Gap:** Step 2.95 reads "Step 2.9 EP1 classifier output," but Component C never produces persisted output. The Plan/Act decision tree therefore has no actual input to branch on; the agent presumably defaults silently. No `.plan-pending` has ever been written. None of the three Plan/Act telemetry event types have ever been emitted. The "Plan/Act COMPLEXITY-GATED" runtime claim in commit `dcf8d61` (Iter 67 release) is false at the artifact level.

**Recommended fix:** Cannot be fixed in isolation — depends on Component C being wired correctly first. After C ships real, add explicit Bash blocks in orchestrate-flow that (a) read the classifier state file, (b) write `.plan-pending` JSON when MAJOR-branch is taken, (c) emit the three Plan/Act telemetry events from explicit bash → telemetry.jsonl appends.

---

## Component F. Handoff carry-over (vault → binding → units → bolts)

**Claim:** OQ-IDs, CONFLICT-IDs, Hard Rules propagate field-perfect across handoff boundaries.

**Evidence found (traced OQ-DM-P2-1):**

- **Origin:** vault `tradefinance-phase-2-workflows/00-index.md:84` — `**OQ-DM-P2-1** [P2] [business]: **RESOLVED** -- Keep both lc_amount and goods_total`
- **Origin doc:** `tradefinance-phase-2-workflows/03-data-model.md:435` — same resolution echoed.
- **Vault JSON manifest:** `vault.json:101` lists `"OQ-DM-P2-1", "doc": "03-data-model.md", "priority": "P2", "category": "business"` (correct).
- **Binding:** `binding-phase-2.md:304` — `| OQ-DM-P2-1 (lc_amount vs goods_total) | Keep both separate | -- |` (correct ID + resolution carried forward).
- **Units:** `grep "OQ-DM-P2-1" units/*.md` → **0 hits.** The OQ ID does NOT appear in any unit body in `tradefinance-phase-2-workflows-bound/units/`.
- **Semantic carry:** Fields `lc_amount` + `goods_total` DO appear in unit U-005 (line 61) and U-014 — so the resolution semantics propagated, but the **traceability ID was dropped** at the binding→unit boundary.
- **Bolts:** `bolts/` directory does not exist in either bound vault. End-to-end OQ→bolt trace is impossible — bolts have not been generated.

**CONFLICT-1 trace (phase-1, second-best-data item):**

- **Origin:** `binding.md` Section 1 — `CONFLICT-1: group ↔ Spatie roles`, recommendation A (reuse Spatie), resolved en bloc 2026-05-21 by stakeholder.
- **Units:** `grep "CONFLICT-1" phase-1-foundation-bound/units/` → multiple hits in U-009 (frontmatter `decisions: CONFLICT-1 → A`), U-010 (anti-pattern reference), U-002 (reference for related D-013), `_index.md` Wave-3 ribbon. Traceability ID PRESERVED at unit boundary for the phase-1 binding.
- **Bolts:** no bolts/ → trace stops at units (same gap as OQ trace).

**Verdict:** **PARTIAL.**

**Gap:** 
- Phase-1 binding→unit handoff preserves CONFLICT-IDs (verified for CONFLICT-1).
- Phase-2 binding→unit handoff **drops OQ-IDs** (OQ-DM-P2-1 present in binding-phase-2.md, absent from any unit body). The resolution content carries (lc_amount + goods_total appear in U-005/U-014) but the citation linking unit code back to the resolved OQ is lost. This is the silent-drift failure mode: a future reader reviewing U-005 cannot know which OQ resolution justified the `lc_amount vs goods_total` design — they must dive back into binding-phase-2.md and infer the link.
- No bolts exist anywhere → unit→bolt handoff is UNVERIFIABLE_WITHOUT_FRESH_RUN.

**Recommended fix:**
1. Update `generate-units` SKILL.md to emit `decisions:` frontmatter entries for every OQ that influenced the unit, not just CONFLICTs. The phase-1 pattern is correct; phase-2 generation lost the ID-propagation step.
2. Audit `generate-units/references/unit-schema.md` for OQ-trace requirement; codify "every unit body must cite every OQ from `binding.md`/`binding-<phase>.md` resolution table whose resolution is implemented in this unit."

---

## Component G. Telemetry event coverage (cross-cutting)

Schema declares 15 event_types (per `plugins/mega-sdd/references/telemetry-schema.md` + CLAUDE.md §Telemetry Collection). Real-run presence:

| event_type | Present in TF Import telemetry.jsonl? | Emitter wired? |
|---|---|---|
| `ref_loaded` | YES (1 event) | YES (PostToolUse hook, narrow Read-only) |
| `skill_invoked` | NO (0 events) | YES wired in hook, but Skill tool rarely used → effectively dead |
| `halt_fired` | NO (0 events) | NO emitter in any skill body |
| `tier_classification_decision` | NO (0 events) | NO emitter |
| `iter_classifier_output` | NO (0 events) | Script exists; not invoked anywhere |
| `iter_classifier_drift` | NO (0 events) | Same as above |
| `activation_outcome` | NO (0 events) | NO emitter |
| `turn_loaded_summary` | NO (intentional — derived offline by Iter 68) | N/A per design |
| `turn_end_marker` | NO (0 events) | YES wired (Stop hook) but not firing |
| `replan_triggered` | NO (0 events) | Script exists; NOT referenced by any skill |
| `revalidate_triggered` | NO (0 events) | Same |
| `replan_budget_exceeded` | NO (0 events) | Same |
| `revalidate_budget_exceeded` | NO (0 events) | Same |
| `plan_mode_entered` | NO (0 events) | NO emitter |
| `act_mode_entered` | NO (0 events) | NO emitter |
| `plan_act_transition` | NO (0 events) | NO emitter |

**Result:** 1 of 16 declared event types has real data. 11 of 16 have ZERO emitters anywhere in the codebase. CLAUDE.md self-admits the gap ("other event types... are best-effort per-skill emission via markdown convention... reliability is lower than hook-emitted events") — this audit confirms reliability is not "lower," it is **zero**.

**Verdict:** **BROKEN at the schema-vs-emission gap.** Schema claims coverage; emission delivers ~6%.

---

## Summary punch list

| Component | Verdict | Gap |
|---|---|---|
| A. Hooks fire in real orchestration | SessionStart BROKEN; PostToolUse WORKING-BUT-NARROW; Stop BROKEN | SessionStart probes pre-v3.4 paths; PostToolUse can't see Bash-driven reads; Stop silently never fires |
| B. Skill invocation tracking | UNVERIFIABLE-AS-DESIGNED (effectively BROKEN) | Most skill activations bypass the Skill tool entirely |
| C. Classifier (classify-iter.sh) | BROKEN — fictional wire-up | Script never invoked by any skill body; only mentioned in markdown |
| D. Anti-recursive guard (check-recursion-budget.sh) | BROKEN — worse than C | Script not referenced by ANY skill body, including orchestrate-flow |
| E. Plan/Act gating (Iter 67) | BROKEN — cascade from C | No `.plan-pending` written; no plan_mode events; depends on broken C |
| F. Handoff carry-over | PARTIAL | Phase-1 preserves CONFLICT-IDs; phase-2 DROPS OQ-IDs at unit boundary; bolts non-existent |
| G. Telemetry event coverage | BROKEN at schema-vs-emission gap | 1 of 16 event types has data; 11 of 16 have zero emitters anywhere |

## Soak gate status

**BLOCKED.** Soak preconditions per CLAUDE.md §Telemetry Collection require: "PRE-CONDITION for soak activation: Iter 66a hooks verified writing telemetry.jsonl in at least ONE real chain run on a real project. Until then, soak window is NOT counting."

Only PostToolUse meets that bar (1 event). Stop hook does not. SessionStart does not. The Iter 65 + Iter 67 runtime claims (classifier + guard + Plan/Act) are all unsupported by artifacts — they are documented but not executed. Shakedown runs cannot proceed on this stack because there is no hook-emitted ground truth to shake down against.

Iter 68 analysis is impossible with current data — `turn_loaded_summary` aggregation requires `turn_end_marker` boundaries (zero exist) AND a non-trivial population of `ref_loaded` events between them (one exists, total).

## Recommended fixes (ordered)

1. **One-line fix — restore SessionStart anchor injection:** add `.mega-sdd` to the signal list in `plugins/mega-sdd/hooks/session-start` line 14. Without this, the anchor never injects for any v3.4+ canonical-layout project. This alone explains why mega-sdd skills feel "loose" in real sessions — the agent never sees the using-mega-sdd anchor at session start.

2. **Instrument and verify Stop hook:** add a debug-mode emit that bypasses the `telemetry.jsonl exists` gate one time, log to a separate `.mega-sdd/memory/hook-debug.log`, and re-run TF Import to confirm the harness even invokes `hooks/stop` for that CWD. If it does, the bug is in the gate or the JSON parse. If it doesn't, the bug is in matcher / Claude Code harness assumptions.

3. **Wire the scripts to skill bodies (Components C + D):** add explicit Bash invocations of `classify-iter.sh` and `check-recursion-budget.sh` to orchestrate-flow, execute-bolts, and wherever re-plan/re-validate is triggered. Persist outputs to state files (`.iter-classifier.json`, `.replan-budget`) so downstream consumers have something to read. Remove the markdown-convention assumption that the agent will run scripts based on prose instruction — Iter 64 already proved this fails.

4. **Broaden PostToolUse matcher OR accept the gap:** either add `Bash` to the `Read|Skill` matcher (with grep-based filtering on first-arg path) OR explicitly document that `ref_loaded` undercounts subagent Bash-driven loads. Current state of "1 event for an entire phase-1+phase-2 vault generation" makes ref_loaded data unusable for tier-tuning.

5. **Fix phase-2 OQ-ID handoff drop:** update `generate-units` to emit `decisions:` frontmatter for every OQ that influenced a unit, not just CONFLICTs. Audit `unit-schema.md` for an OQ-trace requirement.

6. **Schema reality check:** either ship real emitters for the 11 currently-unemitted event types, or shrink the schema to what's actually wired. The current state ("schema declares 16 events, emits 1") is the same documentation-vs-execution gap that caused the two recent failed ships.

7. **Hold the freeze.** Per CLAUDE.md §Soak Shakedown Protocol, "After 2 shakedown runs complete cleanly → freeze runtime changes." Zero clean shakedown runs have been completed (artifact evidence: no fresh post-Iter-67 hook-emitted events beyond the one prior run). Freeze cannot start; soak clock cannot start. Fixes 1-5 are prerequisites.

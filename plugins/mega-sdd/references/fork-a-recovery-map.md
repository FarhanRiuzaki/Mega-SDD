# Fork A Recovery Map — Iter 67.5 → 67.6

Audit 2026-05-27 classified runtime control as "Fork-B-future." Research + ACK 2026-05-27 revised that: most parked items are recoverable in Fork A via four mechanism classes. This doc is the canonical mapping. Implementation status updates as slices land.

## Mechanism classes

| Class | What it means | Fork A availability |
|---|---|---|
| **[HOOK]** | Enforced via Claude Code hook (SessionStart / PreToolUse / PostToolUse / Stop). Hook can BLOCK tool calls (`{"continue": false, "stopReason": "..."}`), not just observe. | ✅ Available |
| **[HOOK-VALIDATE]** | Can't generate deterministically but CAN validate deterministically. Hook reads artifact files vs schema/expectations, halts on drift. | ✅ Available — proven Iter 67.6 slice 1 |
| **[VERIFY-STEP]** | Spec Kit pattern: explicit slash command + deterministic script that cross-checks artifacts. Run by user/agent between phases. | ✅ Available |
| **[FORK-B-ONLY]** | Needs to intercept the model's reasoning loop mid-turn (not at tool boundary). Genuinely needs custom runtime. | ❌ Parked |

## Audit-§F bug context

Audit traced ONE OQ-ID drop (OQ-DM-P2-1 absent from U-005's binding_refs despite being in binding-phase-2.md Resolution Table). Real-run inventory (validator first run) revealed the actual scope: **27 of 27** OQs across phase-1 + phase-2 are dropped at the binding→units boundary. The audit saw the tip; the iceberg was systemic skill-body prose failure.

## Item classification (current status)

| Item | Mechanism | Iter 67.6 status | Notes |
|---|---|---|---|
| Classifier output emission (`iter_classifier_output`) | [HOOK] | Not implemented | Stop hook runs `classify-iter.sh --ep=EP2`, emits event. Trivial wire-up; deferred to slice 6. |
| Classifier drift (`iter_classifier_drift`) | [HOOK] | Not implemented | Same Stop hook diffs current EP2 vs saved EP1. |
| Ceremony gating (block commit if MAJOR no spec) | [HOOK] | Not implemented | PreToolUse on Bash matching `git commit` + reads `.iter-classifier.json`. |
| Anti-recursive — explicit budget cap | [HOOK] | Not implemented | `/mega-sdd:replan` slash command + PreToolUse cap check. |
| Anti-recursive — failure-driven auto-increment | [HOOK] | Not implemented | PostToolUse detects `halt_fired` / test-fail patterns → auto-increment via state file. Per ACK 2026-05-27 Call #2: this is the high-value tier (observable failures dominate runaway loops). |
| Anti-recursive — implicit re-plan detection | [FORK-B-ONLY] | Parked | Genuinely needs runtime introspection. |
| Plan/Act explicit toggle | [HOOK] | Not implemented | `/mega-sdd:plan` + state file + PreToolUse on Write/Edit blocks in Plan mode. |
| Plan/Act auto-gating per classifier | [HOOK] | Not implemented | SessionStart reads classifier output, writes state file when MAJOR. |
| Plan/Act tamper-proof against agent | [HOOK] (part of slice 1 anti-self-bypass) | ✅ Implemented (general pattern) | PreToolUse blocks agent `rm`/`mv`/`>` etc. on state files. User can still override via shell. Per Call #1 ACK: user is not the adversary. |
| Lazy-load tier — enforcement (skip ref load) | [FORK-B-ONLY] | Parked | Can't intercept reasoning. |
| Lazy-load tier — observation (`tier_classification_decision`) | [HOOK] | Not implemented | PostToolUse Read enriches with manifest lookup. |
| `turn_loaded_summary` | derived offline | N/A | Iter 68 aggregation, not live. |
| **Handoff binding→units (OQ-IDs)** | **[HOOK-VALIDATE]** | **✅ Implemented Iter 67.6 slice 1** | Validator: `scripts/validate-handoff-binding-units.sh`. Trigger: PostToolUse on Write/Edit of units. Enforcement: PreToolUse on `mega-sdd:execute-bolts`. Anti-self-bypass: PreToolUse on Bash state-file mutations. **Real-run-verified against TF Import 2026-05-27: 27/27 drops correctly detected; add/remove/restore cycle clean; bolt-gen blocks; state file overwrite-not-append.** |
| Handoff binding→units (CONFLICT-IDs) | [HOOK-VALIDATE] | Slice 2 candidate | Identical pattern, different field-set. |
| Handoff binding→units (Hard Rules) | [HOOK-VALIDATE] | Slice 3 candidate | Same pattern; Hard Rule citations trace to source. |
| Handoff vault→binding (coverage) | [HOOK-VALIDATE] | Slice 4 candidate | Every vault section produces ≥1 binding entry. |
| Handoff units→bolts (traceability) | [HOOK-VALIDATE] | Slice 5 candidate | Every unit's acceptance test maps to bolt step. |
| Cross-artifact `/analyze` command | [VERIFY-STEP] | Not implemented | Spec Kit-style. Combines all validators into one report. Slice 6+ after individual validators prove. |
| Implicit re-plan detection | [FORK-B-ONLY] | Parked | |
| Lazy-load mid-reasoning skip | [FORK-B-ONLY] | Parked | |
| Tamper-proof state vs human user | [FORK-B-ONLY] | Parked (intentional) | Per ACK Call #1: this is the wrong bar. User is not the adversary; manual override is a feature. |
| Mid-turn intervention | [FORK-B-ONLY] | Parked | |

## Walking-skeleton discipline

Audit pattern (4 consecutive failed ships) forced explicit discipline:

1. **Pick the smallest vertical slice.** One mechanism + one boundary + one field-class. Iter 67.6 slice 1 = [HOOK-VALIDATE] + binding→units + OQ-IDs.
2. **Prove with real-run artifacts.** Real project, real files modified, real validator execution. Smoke tests in isolation do not count.
3. **Only after the slice proves**, expand to the next slice. Iter 67.6 ships ONE slice. Slices 2-6 follow only after slice 1 verified in production.
4. **Honest classification of residual.** Items that truly need runtime introspection stay [FORK-B-ONLY]. Don't optimistically reclassify just because the residual feels small.

## Residual [FORK-B-ONLY] (4 items, accurate)

1. **Implicit re-plan detection** — model loops back to planning without explicit gesture or observable failure signal. Hooks can't see reasoning.
2. **Lazy-load tier enforcement** — mid-reasoning skip of refs the model "would" load. Hooks fire at tool boundaries, not during reasoning.
3. **Tamper-proof state vs the human user** — user can `rm` state files in their shell. By design, this is fine in Fork A (user is on our side); Fork B would store state in agent-managed memory.
4. **Mid-turn intervention** — "the model is about to do X, force Y first." Hooks fire pre/post tool, not mid-reasoning.

These 4 items genuinely need Fork B (Agent SDK / custom runtime). Everything else has a Fork A path; some implemented, most slice candidates.

## Pattern reference: [HOOK-VALIDATE]

The canonical Fork A pattern for deterministic artifact integrity. Three components:

**(1) Validator script** — deterministic bash + python. Reads N artifact files, computes a structured report, writes a state file (`.mega-sdd/.<name>-blockers.json`) as OVERWRITE-NOT-APPEND (current truth, never history). Exit 0 = PASS, 1 = FAIL.

**(2) PostToolUse trigger** — fires when a relevant artifact is written/edited. Invokes validator silently. State file auto-updates.

**(3) PreToolUse enforcement** — fires before downstream operations (the ones whose correctness depends on the validated invariant). Reads state file, blocks with `{"continue": false, "stopReason": "..."}` if status=FAIL.

**(4) Anti-self-bypass** — PreToolUse on Bash detects agent attempts to `rm`/`>`/`sed -i`/`mv`/`cp`/`tee` the state file. Blocks. Human shell override remains by design.

Spec Kit's `/analyze` command is the [VERIFY-STEP] complement: same validator logic, but invoked explicitly by user/agent via slash command. Same script, different trigger.

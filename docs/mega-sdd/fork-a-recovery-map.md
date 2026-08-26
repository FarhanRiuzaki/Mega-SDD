# Fork A Recovery Map — Iter 67.5 → 67.6

Audit 2026-05-27 classified runtime control as "Fork-B-future." Research + ACK 2026-05-27 revised that: most parked items are recoverable in Fork A via four mechanism classes. This doc is the canonical mapping. Implementation status updates as slices land.

## Mechanism classes

| Class | What it means | Fork A availability |
|---|---|---|
| **[HOOK]** | Enforced via Claude Code hook (SessionStart / PreToolUse / PostToolUse / Stop / UserPromptExpansion / UserPromptSubmit — 6 events since v7.3.1). Hook can BLOCK tool calls (PreToolUse: `hookSpecificOutput.permissionDecision: "deny"`; `continue:false` halts the whole session and is NOT a per-call block), not just observe. | ✅ Available |
| **[HOOK-VALIDATE]** | Can't generate deterministically but CAN validate deterministically. Hook reads artifact files vs schema/expectations, halts on drift. | ✅ Available — proven Iter 67.6 slice 1 |
| **[VERIFY-STEP]** | Spec Kit pattern: explicit slash command + deterministic script that cross-checks artifacts. Run by user/agent between phases. | ✅ Available |
| **[FORK-B-ONLY]** | Needs to intercept the model's reasoning loop mid-turn (not at tool boundary). Genuinely needs custom runtime. | ❌ Parked |

## Audit-§F bug context

Audit traced ONE OQ-ID drop (OQ-DM-P2-1 absent from U-005's binding_refs despite being in binding-phase-2.md Resolution Table). Real-run inventory (validator first run) revealed the actual scope: **27 of 27** OQs across phase-1 + phase-2 are dropped at the binding→units boundary. The audit saw the tip; the iceberg was systemic skill-body prose failure.

## Item classification (current status)

| Item | Mechanism | Iter 67.6 status | Notes |
|---|---|---|---|
| Classifier output emission (`iter_classifier_output`) | [HOOK] | Not implemented (classifier script deleted v7) | A future Fork-B control plane would re-introduce a classifier; nothing to wire today. |
| Classifier drift (`iter_classifier_drift`) | [HOOK] | Not implemented | Same Stop hook diffs current EP2 vs saved EP1. |
| Ceremony gating (block commit if MAJOR no spec) | [HOOK] | Not implemented | PreToolUse on Bash matching `git commit` + reads `.iter-classifier.json`. |
| Anti-recursive — explicit budget cap | [HOOK] | Not implemented | a replan verb (hypothetical — never implemented) + PreToolUse cap check. |
| Anti-recursive — failure-driven auto-increment | [HOOK] | Not implemented | PostToolUse detects `halt_fired` / test-fail patterns → auto-increment via state file. Per ACK 2026-05-27 Call #2: this is the high-value tier (observable failures dominate runaway loops). |
| Anti-recursive — implicit re-plan detection | [FORK-B-ONLY] | Parked | Genuinely needs runtime introspection. |
| Plan/Act explicit toggle | [HOOK] | Not implemented | a plan-mode toggle (hypothetical — never implemented) + state file + PreToolUse on Write/Edit blocks in Plan mode. |
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
| **Staged-input non-loss (KB→vault)** | **[HOOK-VALIDATE]** | **✅ Implemented v3.71.0 (semantic-depth)** | Validators: `scripts/validate-vault-flow-staging.sh` (ADVISORY in v4 Hybrid — was BLOCKING; follows each `flows.md` flow's `_kb_source` back-reference — `modules/<domain>.prd.md` for PRD-kontrak KBs, whose §Flow carries the `stages:` block; legacy KBs cite `20-workflows/<f>.md` — cited KB flow has a `stages:` block but the vault flow dropped it → `vault_flow_staging_drop`, `status==FAIL`; dedicated single-purpose so the status gate is precise per Iter-79 #4) + the kb flows surface (`validate-kb.sh --surface=flows`) ADVISORY `kb_flow_staging_missing` (non-blocking; separate `advisories[]` channel; never flips status). Trigger: PostToolUse Validator 6b (vault, project-wide) + the existing KB-write dispatch. Enforcement: **advisory** via `analyze` (v4 Hybrid — was PreToolUse Branch 14 on `mega-sdd:execute-bolts`). Remediation: re-run `extract-intelligence` on the affected module (the dedicated `enrich-workflows-staging.sh` retro-fit script was removed in v7 — advisory consumer is the analyze report). Backward-compatible by construction (no KB / no `_kb_source` / KB had no stages → SKIP). Fixture: `tests/fixtures/iter77-semantic-depth/` — 16/16 Fork-A incl. the Branch-14 hook-fire gate. Walking-skeleton: staged-input dimension only; conditional / role-matrix / transition-guard dimensions are later-iter. |
| **Extraction completeness contract (census gate)** | **[HOOK-VALIDATE]** (blocking) | **✅ Implemented (census-contracted extraction, since v7.6)** | Validator: `scripts/validate-extract-census.sh` — closes the extraction against `census.json` (code files + sha256 + stacks + module claims): unclaimed / double-claimed / phantom files, uncited claims, missing PRD-kontrak sections, missing OQ section, flow-not-Mermaid, Mermaid syntax errors → FAIL. Runs as the completeness gate at synthesis — blocking, not advisory. Legacy numbered-tree KBs (no `census.json`) are not gated retroactively; `certify-artifact`'s kb rung treats the census gate as the certification when `census.json` is present. |
| **Deep extraction disciplines (P1–P4)** | [SKILL-PROSE] wired to dispatch | **✅ Wiring shipped v3.72.0; reasoning Fork-B real-run** | P1 writer↔reader provenance + clone-inheritance, P2 enumerate-all-sites + entry-points, P3 behaviour-as-executed, P4 structural classification — placed in `agents/domain-extractor.md` §Deep disciplines (the extractor's system prompt — received by every per-module extractor agent by construction; agents dispatch only when the census proposes >1 module, one per module; a single-module extraction runs on the main thread). WIRING presence is fixture-asserted; the LLM actually performing the reasoning is best-effort Fork-B (real-run-only). |
| Pipeline handshake B1 hard-block + B2/B3/E1/E2/E3 | [HOOK-VALIDATE] | B1 ✅ (census gate); rest scoped Fork-B-future | B1 = discharged since v7.6: `validate-extract-census.sh` blocks incomplete extractions at synthesis (see the census-gate row above). B2/B3 = verify the *business outcome* survives (not legacy status values, per the v3.72 reframe). E1/E2/E3 = execute-bolts post-flight provenance/anchor/FE scans. Each remaining item needs its own `validate-*.sh` + fixtures before wiring. |
| Cross-artifact analyze | [VERIFY-STEP] | ✅ Implemented as the `analyze` SKILL (phrase-routed "cek konsistensi" / the front door), not a slash command | Runs the validators via `run-analyze.sh`, emits `CONSISTENCY-REPORT.md`; the Stop hook carries an aggregate-only auto mode. |
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

**(3) PreToolUse enforcement** — fires before downstream operations (the ones whose correctness depends on the validated invariant). Reads state file, blocks with `hookSpecificOutput.permissionDecision: "deny"` if status=FAIL.

**(4) Anti-self-bypass** — PreToolUse on Bash detects agent attempts to `rm`/`>`/`sed -i`/`mv`/`cp`/`tee` the state file. Blocks. Human shell override remains by design.

Spec Kit's `/analyze` command is the [VERIFY-STEP] complement: same validator logic, but invoked explicitly by user/agent via slash command. Same script, different trigger.

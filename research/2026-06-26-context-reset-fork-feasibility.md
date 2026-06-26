# Context-reset / `context: fork` feasibility — verified decision record

**Date:** 2026-06-26
**Trigger:** User opted into the *aggressive* token-reduction path (design + pilot per-phase context reset + scoped subagents + OQ-pass collapse), with a full-pipeline field audit (kept local) as the `CLAUDE.md:69` un-gating justification.
**Method:** `design-context-reset` workflow (4 mappers → synthesis → 3 adversarial verifiers) → advisor caught a mechanism conflation → **official-doc verification** (claude-code-guide against code.claude.com skills + sub-agents + hooks docs) → primary-source confirmation of the hook matcher.
**Verdict:** **A real structural token win IS available** — fork `detect-drift` + `bind-codebase` + `scan-codebase` via skill `context: fork` (gates preserved, anti-hallucination passes preserved), reject the *Agent-tool offload* mechanism (it bypasses gates), and leave the interactive phases unforked. The earlier "mostly infeasible" framing was based on a conflation — corrected below.

---

## Two mechanisms — do not conflate them (this was the key error)

| Mechanism | What it is | Gates? | Depth-2 sub-dispatch? | Verdict |
|---|---|---|---|---|
| **Agent-tool offload** | orchestrator dispatches a phase BODY via the `Agent` tool | **BYPASSED** — PreToolUse matcher is `Skill|Bash|Edit|Write`, no `Agent`; the gates are keyed on `SKILL_NAME` in the `Skill)` branch | yes | **REJECT** — silently bypasses backward Factory-Line + preflight gates; "controller re-checks at seam" = forbidden enforcement-by-prose |
| **`context: fork` skill** | skill frontmatter; still **invoked via the Skill tool**, body then runs forked | **PRESERVED** — PreToolUse fires on the Skill call (with `SKILL_NAME`) *before* the body forks; ledger/preflight read disk state, fork-independent | **yes** (default `general-purpose`, depth limit 5; "a fork can spawn other subagent types, just not another fork") | **VIABLE** for non-interactive phases |

The `design-context-reset` workflow chose Agent-offload for bind/scan/units *because it believed a fork couldn't do depth-2 dispatch* — that belief was wrong (`CLAUDE.md:57`'s "no `Agent` tool" governs **plugin agents** in `agents/*.md`, not a `context: fork` skill). With the correct mechanism (`context: fork`, Skill-invoked), the moat-safety breach the verifier found **does not apply**, and bind/scan keep their advisor/deep-scan passes.

## Official-doc findings (claude-code-guide, citation-backed)

1. **PreToolUse fires on the fork-triggering Skill call** (skills.md ~529–559) — skills are invoked via the `Skill` tool; the hook sees `tool_name=Skill` + the skill name *before* execution. Ordering is grounded inference (not explicitly documented) → **de-risk empirically with the detect-drift pilot.**
2. **Depth-2 from a fork is allowed** (sub-agents.md ~790,796): depth limit **5, non-configurable**; a fork "cannot spawn another fork [but] can spawn other subagent types." `AskUserQuestion` is **never** available in any subagent/fork (sub-agents.md ~314).
3. **PreToolUse + PostToolUse fire inside forks/subagents** (hooks-guide.md ~458–462); only `Stop` is converted to `SubagentStop` — which is exactly why a forked phase emits **zero `turn_end_marker`** (the telemetry blind spot).
4. **A fork starts with only its rendered body** (`$ARGUMENTS`/`$N`/named-args/`` !`cmd` `` substitution) **+ CLAUDE.md**, no conversation history, **no separate metadata channel** (skills.md ~484–500, sub-agents.md ~800–814).

## The hook matcher (primary-source, confirmed)

```
PreToolUse   matcher = 'Skill|Bash|Edit|Write'              ← no Agent
PostToolUse  matcher = 'Read|Skill|Bash|Write|Edit|Agent'   ← has Agent
```
Blocking gates all sit in `case TOOL_NAME → Skill)` keyed on `SKILL_NAME`: backward Factory-Line ledger `pre-tool-use:213`, predictive preflight `:263`, handoff-validation `:299`, execute-bolts forward CONFLICT gate `:355`, bind gate `:451`. Since `context: fork` keeps the phase a **Skill** invocation, these still fire (finding Q1). **Agent-offload would move them off the matcher → reject.**

## Per-phase forkability (corrected)

| Phase | Interactive (AskUserQuestion under `--auto`)? | Fork verdict | Notes |
|---|---|---|---|
| **detect-drift** | no (defers to PENDING-SYNC.md) | **FORK (clean)** — pilot first | side-lane, non-moat. Fixes: persist drift-history via `Bash >>` even when forked (`SKILL.md:64`); seed must carry explicit resolved `CODE_DIR`/`VAULT_DIR`. |
| **bind-codebase** | no (it HALTS, never asks) | **FORK (viable)** | depth-2 phase-advisor runs *inside* the fork (Q2); entry gates fire (Q1); hooks fire inside (Q3). Work: serialize `memory_context` into `$ARGUMENTS` (Q4), harvest `memory_writes`/handoff from return, synthetic `turn_end_marker`, verify the binding.md→`validate-vault-binding-coverage.sh` async producer lands before teardown. |
| **scan-codebase (full)** | no | **FORK (viable)** | deep-scan slice subagents run *inside* the fork (Q2). Same seeding/harvest/telemetry work. |
| **generate-units** | **yes** — brownfield `PARTIAL_FIELDS_SURPLUS/BOTH` mandatory HUMAN REVIEW, NOT suppressed by `--auto` | **NO** | the `--auto` suppression covers the Step-7.6 collision axis only, not the task-typing axis. Subagent can't prompt → would hang/fabricate (breaks #5). |
| **generate-intent** | yes (Mode B Q&A, PROJECT_SHAPE confirm, squad/scope pickers) | **NO** (Mode-A-only would be degraded) | |
| **execute-bolts** | yes (OQ-in-unit prompts, propose-and-confirm) | **NO** | terminal moat gate; keep as main-thread Skill so the forward CONFLICT gate fires. Fan-out already maximally subagent-driven. |
| **resolve-oq** | yes (per-OQ A/B/C/D menu) | **NO** | the contract's named counter-example; not even token-heavy. Optimize via OQ-collapse, not fork. |
| **extract-intelligence** | per-wave confirm only (`--auto` skips) | borderline / **defer** | fan-out already off main thread; Wave-5 synthesis needs holistic context a fork lacks. Win is lean Wave-0/5 + glossary pre-parse, not forking the orchestration. |
| **diff-vault** | yes (conflict resolution HALTS) | hybrid (report half only) | low priority. |

## Residual risks (de-risk before full bind/scan rollout)

- **Q1 ordering is grounded inference, not explicit doc.** → The `detect-drift` pilot empirically proves PreToolUse fires on a `context: fork` Skill call before committing any moat-touching fork.
- **Producer-timing race:** moat-state files written by backgrounded async PostToolUse validators may not land before a short-lived fork tears down → could leave a stale/absent gate file (`absent ⇒ allow`, `pre-tool-use:370`). Mitigation: controller runs the producer **synchronously** at the seam as a backstop; keep artifact emission as real on-disk Write|Edit so PostToolUse stays the primary producer (it fires in subagents, Q3).
- **`memory_context` round-trip:** must be serialized into `$ARGUMENTS` IN and harvested from the structured return OUT (no metadata channel, Q4). Pin with a test that forked behavior == in-thread behavior.
- **Telemetry blindness:** SubagentStop is Stop-blind (Q3) → controller must emit a **synthetic `turn_end_marker`** per fork from the return's `usage`, else the reduction is unmeasurable (and could be a phantom win — cost relocated, not deleted).
- **Interactivity hard-stop:** `AskUserQuestion` never available in a fork (Q2) → only the non-interactive phases above are candidates; this is load-bearing and must be a tested invariant.

## Plan (strangler, reversible, measured)

1. **Ship-now safe subset** (no fork dependency): OQ-pass collapse (resolve-oq P1+P2 → one `all-priorities` walk, keep both phase-advisor passes); synthetic per-subagent/per-bolt `turn_end_marker`; cost-weighted reporting in `analyze` (input×1, cache_creation×1.25, cache_read×0.1, output×5 → 176M raw ≈ ~37M cost-equiv + per-phase attribution); + the audit's contained correctness fixes (full-suite gate, postflight→hook, per-AC grounding, drift/sync freshness, validator precision).
2. **detect-drift fork** — the empirical pilot: proves the fork mechanism + the synthetic-telemetry harness with **zero moat risk** (side-lane), and settles the Q1 ordering question on real telemetry.
3. **bind-codebase fork**, then **scan-codebase fork** — gated behind the pilot succeeding + the seam-producer + memory round-trip tests passing. The genuine structural win on the two heaviest brownfield phases, **keeping** the advisor/deep-scan rails.
4. **Amend `CLAUDE.md:69` + spec** to record: `context: fork` ADOPTED for detect-drift/bind/scan (non-interactive, gates-via-Skill-invocation preserved, depth-2 allowed); Agent-tool offload of moat phases REJECTED (bypasses Skill-keyed gates); interactive phases non-forkable (`AskUserQuestion` unavailable). Field-audit + this record as rationale.

Measurement gate (per the user's "MEASURED" requirement): same pipeline on the field-audit fixture, main vs branch, sum cost-weighted tokens across parent telemetry + every synthetic per-fork marker; branch total must be < baseline.

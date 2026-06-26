# mega-sdd Factory Line — Queryable Checkpoints + State-Driven Routing — Design

**Date:** 2026-06-25
**Status:** Approved (brainstorm) — pending writing-plans
**Scope:** A derived, queryable checkpoint ledger over existing per-phase handoffs, plus a state-driven router extension to `orchestrate-flow` that can route the pipeline *backward* to re-run an unresolved phase, looping until convergence under a bounded retry cap.

---

## 1. Problem & framing

mega-sdd's pipeline (`extract → intent → scan → bind → units → bolts`) communicates **forward-only**. A phase emits a handoff YAML; the orchestrator reads the *last* handoff and routes to the next phase. There is no way for a downstream phase to look *back* and ask an upstream phase "what exactly did you do, and what's still unresolved?" — and no way for the router to send the line backward to re-run a phase whose work turned out incomplete.

The user's framing is a **factory line**: each process has a checkpoint, any process can query what a prior process did, and a loop uses that state to decide which process to run next — including re-running an earlier one.

**Goal:** make the pipeline's between-phase communication **queryable and state-driven** — a downstream phase reads the relevant upstream checkpoints; a router reads the *whole* ledger to pick the next action (forward OR backward); the loop converges or escalates. All as a *derived* layer on existing artifacts, not a new source of truth.

**This is a vertical concern only.** The *horizontal* blind reviewer panel (`execute-bolts`) stays blind — independence is the source of precision there and is untouched. Vertical (phase ↔ upstream checkpoint) and horizontal (blind lenses) do not mix.

## 2. Key insight that shapes the architecture

**The ledger is derived and therefore cheap + safe.** Every field the router needs already exists or is a thin addition to the handoff each phase already emits (`emitted_by`, `status`, `artifacts`, `next_action.confidence`, `blockers`). The ledger is an append-only aggregation of those records. If the ledger is lost or corrupt, it **rebuilds** from the per-phase handoffs/artifacts — no single point of failure, no second source of truth.

The genuinely new surface is narrow: (a) an **introspectable checkpoint schema** (`did` / `unresolved` / `consumed`), (b) the **ledger file + its validator**, (c) the **router reads the whole ledger** instead of just the last handoff.

## 3. Design decisions (locked in brainstorm)

| # | Decision | Choice |
|---|---|---|
| D1 | Query mechanism | **Hybrid** — read upstream checkpoint first; live re-dispatch only as a *bounded, rare* fallback when a checkpoint is genuinely ambiguous/missing. Checkpoint-read is the default path. |
| D2 | Routing model | **State-driven** — router reads the full ledger and can route forward OR backward (re-run an unresolved phase). |
| D3 | Loop termination | **Convergence + retry cap + escalation** — loop until all checkpoints green; per-phase re-run cap (default 3) → halt to human; reuse halt-taxonomy + convergence-loops. |
| D4 | Scope | A **mega-sdd feature** extending `orchestrate-flow`, not a standalone system. |

## 4. Architecture

```
        ┌──────────────────────────────────────────────┐
        │  FACTORY ROUTER  (extends orchestrate-flow)    │
        │  1. read WHOLE ledger → status map             │
        │  2. pick next action from state (fwd OR back)  │
        │  3. convergence / cap / halt checks            │
        └───────────────┬────────────────────────────────┘
                        │ dispatch (forward OR backward)
                        ▼
 extract → intent → scan → bind → units → bolts   (the line)
    │        │       │      │      │       │
    └────────┴───────┴──────┴──────┴───────┘
        each phase writes a checkpoint record ──▶ .mega-sdd/factory-ledger.json
                                                       ▲
        the next phase READS relevant upstream  ◀──────┘
        checkpoints; if ambiguous → router re-dispatches (bounded live-escalation)
```

### 4.1 Storage — `.mega-sdd/factory-ledger.json`

- **Project-scope** (alongside `project.md`), append-only array of checkpoint records (one per phase-attempt).
- **Derived** — rebuildable from per-phase handoffs/artifacts. Git-ignored as runtime state via an **explicit** entry `**/.mega-sdd/factory-ledger.json` (the name has no leading dot, so it does NOT ride the existing `.*-state.json` glob).
- Never authored by hand; never a source of truth.
- **Two distinct files** (do not conflate): `factory-ledger.json` is the *ledger data* (the checkpoint records, written by phases); `.factory-ledger-state.json` is the *validator verdict* (PASS/FAIL, written by `validate-factory-ledger.sh`, read by the gate). The latter rides the existing `.*-state.json` glob automatically.

### 4.2 Checkpoint record schema

```yaml
- phase: bind-codebase           # = handoff.emitted_by  (reuse)
  attempt: 1                      # NEW — increments per re-run; basis of retry cap
  emitted_at: 2026-06-25T...      # reuse
  status: unresolved              # completed | unresolved | halted  (maps to handoff.status)
  confidence: 0.72                # reuse handoff.next_action.confidence (overall)

  did:                            # NEW — concise "what I did" (for downstream to read)
    - "Validated 14 claims: 11 CONFIRMED, 3 CONFLICT"
    - "Built Implementation State Map"

  unresolved:                     # NEW — drives backward routing
    - id: CONFLICT-003
      kind: conflict              # conflict | oq | low_confidence | missing_input
      blocks: [generate-units]    # which downstream phase this blocks
      note: "auth model mismatch vs codebase-map"

  artifacts: [".mega-sdd/.../binding.md"]          # reuse handoff.artifacts
  consumed: [scan-codebase@1, generate-intent@1]   # NEW — which upstream checkpoints this phase read (query trail)
```

**Anti-hallucination constraint:** every `unresolved[]` entry MUST carry an anchor (`CONFLICT-NNN`, `OQ-NNN`, or `file:line`). No anchor → not a valid unresolved item (mirrors the panel's evidence-or-drop rule). This is enforced by the ledger validator, not prose.

### 4.3 Router decision loop

One iteration of `orchestrate-flow` (deterministic: read ledger, decide one action, repeat):

```
LOOP:
  1. read whole ledger → status map of all phases
  2. collect all unresolved[] across all checkpoints

  3. pick next action (priority order):
     a. an unresolved item that blocks a downstream phase?
        → target = the OWNING phase (the phase whose checkpoint the item lives in re-runs to clear it;
          a human-only underlying OQ/CONFLICT is resolved first, then the owning phase re-runs), route BACKWARD.
     b. no blocker, but a downstream phase hasn't run?
        → target = next downstream phase, route FORWARD
          (dispatch fed the relevant upstream checkpoints; ambiguous → bounded live-escalation).
     c. all phases completed & all unresolved empty?
        → CONVERGED ✅ → done, emit summary.

  4. safety checks before dispatching target:
     - attempt(target) >= CAP (default 3)?         → HALT: phase_stuck → escalate to human
     - identical unresolved recurs w/o progress?    → HALT (anti-spin, reuse halt-taxonomy)
     - item is 'always-pause' (business OQ P1, constitution drift)? → PAUSE → ask human
  5. dispatch target → phase writes new checkpoint (attempt+1) → back to step 1
```

### 4.4 Termination (three ways the loop stops)

- **Converged** — all green → `status: done`.
- **Cap hit** — a phase fails to go green 3× → `halt: phase_stuck` + a concrete human question; resume via `--resume`.
- **Always-pause** — human-only decisions (business OQ P1, constitution drift) → pause, never force-looped.

**Anti-spin guarantee:** a re-run is only issued when there is a *progress signal*. If an identical `unresolved` item (same id + same content) recurs, the iteration counts as a failure (not another wasted re-run). `consumed` + `attempt` are logged each iteration for replay/audit.

## 5. Enforcement (gates > rules > hooks — minimal surface)

| Piece | Mechanism | Why this level |
|---|---|---|
| Routing decision (fwd/back) | **Procedural gate** in `orchestrate-flow` (prose) | Needs contextual reasoning; not a binary invariant |
| **Anti-spin cap** (3× fail / identical unresolved recurs) | **Deterministic validator** (`validate-factory-ledger.sh` → exit code), wired to the EXISTING PreToolUse aggregator | "Never loop forever" is critical + un-promptable → must be a hook, not a prose promise |
| Ledger schema (structure + `unresolved` must be anchored) | Same validator | Anti-hallucination; mirrors evidence-or-drop |

**No new hot-path hook** — the validator attaches to the PreToolUse aggregator that already runs. Useful, not extra load.

## 6. Error handling

- **Ledger corrupt/missing** → rebuild from per-phase handoffs/artifacts (derived; no SPOF).
- **Upstream checkpoint missing when needed** → legitimate trigger for bounded live-escalation (re-dispatch that phase), not a crash.
- **Phase stuck** → `halt: phase_stuck` + concrete question; resume `--resume`.
- **Live-escalation budget** → at most 1× per (phase, attempt); still ambiguous → halt to human. This is what keeps the token multiplier bounded.

## 7. Testing (fixture-based, deterministic)

1. **Backward re-run** — fixture where a downstream checkpoint has `unresolved.blocks` → assert router re-runs the upstream phase, not forward.
2. **Convergence** — all green → assert loop stops `done`, zero excess re-runs.
3. **Cap** — phase forced to fail 3× → assert `halt: phase_stuck`, no 4th loop.
4. **Anti-spin** — identical `unresolved` recurs → assert halt (not a wasted re-run).
5. **Rebuild** — delete ledger → assert it rebuilds from artifacts.
6. **Trigger test** — `tests/skill-triggering/` for the factory-loop trigger phrases.

## 8. Explicitly rejected (gimmick / load without payoff)

- ❌ **Live peer-chat between phases by default** — 3–15× token multiplier, non-deterministic, telephone-game. Bounded escalation only.
- ❌ **Ledger as a new source of truth** — kept *derived*; source stays the existing artifacts.
- ❌ **A separate new hot-path hook** — attaches to the existing aggregator.
- ❌ **Free-form queries** — all routed through the structured `consumed` field + checkpoint records (replayable + auditable).
- ❌ **Touching the blind reviewer panel** — horizontal independence is precision there; out of scope.

## 9. Reused machinery (delta, not reinvention)

`handoff-contract` (record fields), `checkpoint-protocol` (intra-phase checkpoints), `convergence-loops` (loop mechanics), `routing-rules` (route selection), halt-taxonomy (`phase_stuck`, always-pause classes), the `sync` never-ending loop (precedent for state-driven re-entry), and the PreToolUse aggregator (validator wiring).

**Net-new surface:** the introspectable checkpoint fields (`did` / `unresolved` / `consumed`), `.mega-sdd/factory-ledger.json`, `validate-factory-ledger.sh`, and the router's read-whole-ledger logic.

## 10. Versioning & release

Minor bump (new feature, additive): `plugin.json` + `marketplace.json` in sync; `orchestrate-flow` SKILL.md version bump; `CHANGELOG.md` entry. No breaking changes to existing handoff consumers (ledger is additive; forward-only chains still work).

---

## 11. Amendment (2026-06-26, v4.39.0) — backward-dispatch enforcement gate (Round-3 audit R3-1)

**Status:** Approved — implemented.

**Gap found.** §4.3 step 4 designs the loop to HALT re-dispatch of a phase already in `phase_stuck` / `anti_spin`, and §5 states the anti-spin cap is "wired to the EXISTING PreToolUse aggregator." But that aggregator gates **only `execute-bolts`** — the *forward / downstream* side. Nothing read the ledger when an upstream phase (`extract → intent → scan → bind → units`) was **re-dispatched backward**. So the §4.3 cap was, for the backward direction, **prose-only** — the router could re-run a stuck phase indefinitely if the prose loop was skipped. `factory-routing.md` even asserted the PreToolUse gate enforced this; it did not. This violates the enforcement doctrine ("prose that says HALT enforces nothing").

**Fix.** A second, narrow PreToolUse gate (Branch 0-pre in `hooks/pre-tool-use`) on the upstream phase skills `mega-sdd:{extract-intelligence,generate-intent,scan-codebase,bind-codebase,generate-units}`:

1. **Recompute, don't trust derived state.** The gate runs `validate-factory-ledger.sh --cwd --quiet` fresh (mirroring the preflight + scope-flag gates), then reads the just-written `.factory-ledger-state.json`. This is the critical correctness property: resetting the *rebuildable* raw `factory-ledger.json` (the documented recovery) makes the validator emit `SKIP` → the gate self-clears. Reading the derived file blindly would deadlock (a ledger reset would leave a stale `FAIL`).
2. **Per-phase precision.** Block **only** when the dispatched skill's short-name is in `cap_breaches[].phase` or `spin_breaches[].phase`. A sibling phase (e.g. a re-`scan` to FIX a stuck `bind`) stays allowed. A schema/unparseable `FAIL` carries no phase breaches → never matches → never blocks here (the forward gate still handles those for `execute-bolts`).
3. **Recovery = resolve + RESET the rebuildable ledger, then `--resume`.** This is a deliberate, documented change to the `phase_stuck` recovery UX. Because the validator's cap test inspects the *latest* attempt and the per-phase attempt count, a bare `--resume` that re-dispatches the still-capped phase is (correctly) blocked — otherwise the gate would be trivially bypassable. The recovery is to reset the **rebuildable** `factory-ledger.json` (`rm` it; the router rebuilds it from phase handoffs, which clears the stale attempt history → `max_attempt < cap` → no breach → the recovered phase runs). `orchestrate-flow` / `auto` themselves are NOT gated, and `factory-ledger.json` is NOT in the anti-self-bypass protected set, so the reset is permitted. The block's deny message states this recovery verbatim; `factory-routing.md` §Termination documents it. The gate is **breach-scoped, not a permanent phase ban**: the moment the ledger shows the phase's latest attempt `completed` (or attempt count below cap), the gate releases.
4. **Placed before preflight** so a stuck preflight-gated phase reports the more-specific Factory halt.

**Enforcement-table correction to §5:** the row "Anti-spin cap … wired to the EXISTING PreToolUse aggregator" covers the **forward** block (`execute-bolts`) only. Backward re-dispatch of a stuck upstream phase is enforced by **this** dedicated gate. The "always-pause / human-only" class (business OQ P1, constitution drift) remains prose-only — a human-judgment class the hook cannot adjudicate (now labelled as such in `factory-routing.md`).

**Tests:** `tests/round3/test-factory-backward-gate.sh` — phase_stuck blocks; anti_spin blocks; per-phase precision (sibling allowed); PASS/absent never block; **recovery self-clear after ledger reset (the deadlock guard)**; ordering (Factory halt before preflight). The forward aggregator + moat suites remain green (the change is additive).

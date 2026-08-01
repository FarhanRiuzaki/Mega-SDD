# Phase Advisor — adversarial second-opinion on upstream interpretation

**Status:** Design approved 2026-06-09
**Plugin target:** v4.4.0 → v4.5.0 (sequencing vs starterkit-reuse-awareness decided at planning; independent feature)
**Type:** Feature (new plugin agent + two consumer skills, in-iter)
**Related:** execute-bolts already ships a two-stage code review (`spec-reviewer` + `code-quality-reviewer`). This design closes the *upstream* review gap, not the code-delivery one.

---

## Background and motivation

Mega-SDD concentrates adversarial review at the **end** of the pipeline: `execute-bolts` dispatches `spec-reviewer` then `code-quality-reviewer` over each bolt's code. But the most expensive errors are born at the **start** — in the phases that turn ambiguous inputs into the artifacts everything downstream trusts:

- `generate-intent` turns a PRD/brief/KB into the vault — the root source of truth. A fabricated claim, a missed Open Question, or a mis-classified OQ (business vs tech) here poisons binding, units, and bolts alike.
- `bind-codebase` produces the CONFIRMED / CONFLICT / OQ verdicts that *are* the moat. The worst failure is a **false CONFIRMED** — a verdict asserting "this already exists in the code" backed by hallucinated or unrelated evidence — because it silently lets a real conflict through the gate that exists to stop exactly that.

Neither phase has any second opinion today. The asymmetry is backwards: the cheapest place to make a cascading error has the least review.

This design adds a **dedicated advisor subagent** that runs at the end of each of these two phases, before the artifact is finalized — an adversarial reviewer that reads the artifact *and its sources* and hunts for the specific failure modes above. Critically, it is **non-blocking itself** but **feeds its findings into the existing artifacts** so the existing deterministic machinery (the binding CONFLICT gate; the vault OQ roll-up) decides what blocks. Advisor = soft detector; existing gate = hard enforcer. This fits the plugin's *rule → gate → hook* doctrine without growing the hot-path PreToolUse surface.

Scope was deliberately bounded to `bind-codebase` + `generate-intent` (the two upstream interpretation gates with no existing reviewer). `execute-bolts` is already covered; `scan-codebase` is mechanical; `generate-units` is structural (a future checker, not an advisor).

---

## §1 Architecture overview

One new plugin subagent, `phase-advisor`, parametrized per phase via its dispatch prompt (not two specialized agents — the core job is identical; only the focus checklist differs, and a single agent keeps it DRY and extensible to a third phase later).

- `generate-intent` dispatches `phase-advisor` (intent focus) after drafting the vault, before finalize. Findings become new OQs / flagged claims in the vault, surfaced to the user.
- `bind-codebase` dispatches `phase-advisor` (binding focus) after drafting verdicts, before the final gate computation. Findings become **candidate CONFLICT / OQ entries in `binding.md`**, which the existing CONFLICT gate then enforces.

The advisor is read-only, default-on, and skippable via `--no-advisor` (and honored in `--auto` chains). It writes a structured `advisor-findings.md` beside the phase artifact and surfaces a summary inline.

### File version bumps

- New: `plugins/mega-sdd/agents/phase-advisor.md`
- New: `plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md`
- New: `plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md`
- `generate-intent` — minor bump (advisor dispatch step + findings materialization)
- `bind-codebase` — minor bump (advisor dispatch step + findings → candidate verdicts)
- Plugin — v4.4.0 → v4.5.0 (`plugin.json` + `marketplace.json` in sync)

---

## §2 Components

### 2.1 The phase-advisor agent

`agents/phase-advisor.md`. Frontmatter per the plugin contract: `name` + `description` only — **no** `hooks` / `mcpServers` / `permissionMode` (silently ignored for plugin agents). `tools`: `Read, Grep, Glob, Bash` (read-only; the advisor never writes code or artifacts — it returns findings, the dispatching skill materializes them). `tools` excludes `Agent` and `AskUserQuestion` (subagent-unavailable).

**Model: `opus`.** This is a deliberate exception to "cheapest capable model per role": an advisor weaker than the work it reviews adds no signal. The whole value of a second opinion is that it is at least as sharp as the first pass.

The agent body (system prompt) establishes the invariant discipline, phase-agnostic:
1. You are an adversarial reviewer. Your job is to find what is *wrong* before it is committed — not to praise what is right.
2. Read the artifact AND its cited sources. Every finding must cite source evidence (file:line / PRD section / codebase-map entry). No finding without evidence — you do not get to fabricate problems any more than the producer gets to fabricate claims.
3. Return structured findings only (the schema in §2.3). Your final message IS the data; the dispatching skill acts on it.
4. Default to surfacing uncertainty as a finding, not swallowing it — but mark confidence.

The phase-specific *focus* arrives in the dispatch prompt (§2.2), not the system prompt.

### 2.2 Phase focus checklists (dispatch-injected)

**Binding focus** (`bind-codebase/references/advisor-checklist.md`) — reads `binding.md`, `codebase-map.md`, the vault, and the KB:
- For every **CONFIRMED** verdict: is the cited codebase evidence real and does it actually match the vault claim? Hunt **false CONFIRMED** (hallucinated/unrelated anchor). This is the priority finding type.
- For every **"not found → OQ/NEW"**: is it actually present in the codebase under a different name/path (a missed match that should be CONFIRMED or CONFLICT)?
- For every **CONFLICT**: is it a real contradiction or a false alarm (would wrongly block)?
- Implementation State Map sanity (IMPLEMENTED vs NEW mis-label).

**Intent focus** (`generate-intent/references/advisor-checklist.md`) — reads the vault (7 files) and the source (PRD/brief/KB):
- **Fabrication:** any claim/entity/flow with no traceable source → should be an OQ, not an assertion.
- **Missed OQ:** a genuine gap in the source that was silently filled instead of surfaced.
- **Mis-classification:** OQ tagged business vs tech incorrectly (drives resolution_mode downstream).
- **Source-coverage:** a material source section with no representation in the vault.

### 2.3 Findings schema

The advisor returns (and the skill writes to `advisor-findings.md`):

```yaml
phase: bind | intent
advisor_model: opus
findings:
  - id: ADV-001
    type: false_confirmed | missed_match | false_conflict | fabrication | missed_oq | misclassification | coverage_gap | state_map_error
    severity: high | medium | low
    target: "<verdict-id | claim ref | OQ-id | vault file:section>"
    issue: "<one-line statement of what is wrong>"
    evidence: "<source cite — codebase-map entry / PRD §X / file:line>"
    suggested_action: "<reclassify to CONFLICT | raise OQ | drop fabricated claim | retag business→tech | ...>"
    confidence: high | medium | low
summary: { high: N, medium: N, low: N }
```

No finding may omit `evidence` (anti-fabrication symmetry). Empty `findings` is a valid, expected outcome (clean pass).

---

## §3 Data flow + materialization

```
generate-intent
  draft vault (7 files + vault.json)
        │  dispatch phase-advisor (intent focus) ── reads vault + source
        ▼
  advisor-findings.md  (fabrication / missed_oq / misclassification / coverage_gap)
        │  MATERIALIZE:
        │   - fabrication      → demote claim to OQ (or flag) + Changelog note
        │   - missed_oq        → add OQ to the roll-up
        │   - misclassification→ retag OQ category
        │  surface summary inline → user
        ▼
  finalize vault (advisor pass recorded in vault.json provenance)

bind-codebase
  Step 2.x  draft per-claim verdicts (CONFIRMED / CONFLICT / OQ) + Implementation State Map
        │
        │  Step 2.12 (NEW — ordered BEFORE Step 3): dispatch phase-advisor (binding focus)
        │            reads binding draft + codebase-map + vault + KB → advisor-findings.md
        │  MATERIALIZE findings into binding.md (confidence-gated):
        │   - false_confirmed / missed_match, confidence HIGH
        │        → write a canonical `### CONFLICT-NNN` heading (form the gate + validator
        │          recognize, see CONFLICT_RE in validate-handoff-binding-units.sh), tagged
        │          `source: advisor` / `ADV-`. This is a real, blocking conflict (fail-safe).
        │   - false_confirmed / missed_match, confidence MED/LOW → raise an OQ (non-blocking, surfaced)
        │   - false_conflict / state_map_error → FLAG ONLY for human review; NEVER auto-applied
        ▼
  Step 3  aggregate counts  (now includes advisor-added CONFLICT-NNN)
  Step 5  decision gate: conflict > 0 ⇒ DO NOT write <vault>/bound/  (bind-level block)
        ▼
  handoff → validate-handoff-binding-units.sh reads `### CONFLICT-NNN` headings
        → writes <cwd>/.mega-sdd/.validation-blockers.json
        → execute-bolts PreToolUse hook reads it, FAILS CLOSED on unresolved CONFLICT
```

**Channel correctness (the load-bearing wiring):** the advisor's materialization MUST run as a new **Step 2.12, before Step 3 (aggregate counts) and Step 5 (decision gate)**, and MUST emit conflicts as canonical `### CONFLICT-NNN` headings — because that is the exact token both enforcement surfaces read: Step 5's count-based bind-level gate, and `validate-handoff-binding-units.sh` (which emits `.validation-blockers.json`, the file the execute-bolts PreToolUse hook fails closed on, per `plugins/mega-sdd/CLAUDE.md`). If the advisor ran after Step 3, or wrote prose instead of a `CONFLICT-NNN` heading, the finding would land in `binding.md` but never reach either gate — the moat-hardening would silently no-op. The advisor itself never writes `.validation-blockers.json` (that file is hook/script-managed and agent-protected); it only adds the `CONFLICT-NNN` source heading that the existing emitter consumes.

The advisor never blocks via a *new* mechanism. In binding it adds a canonical conflict that the *existing* gate blocks on; in intent it feeds the OQ roll-up the user already walks (`resolve-oq`). Existing enforcement is the only thing that halts.

### 3.1 Provenance

A `phase-advisor` pass is recorded in the artifact provenance (vault.json for intent; binding.md header for binding): model, finding counts, and whether `--no-advisor` was used. So a downstream consumer can tell whether a vault/binding was advisor-reviewed.

---

## §4 Halt protocol + error handling

No new blocking halt is introduced by the advisor itself.

| Condition | Behavior |
|---|---|
| `--no-advisor` | advisor skipped; provenance records `advisor: skipped`; phase proceeds |
| advisor returns empty findings | clean pass; provenance records 0 findings; phase proceeds |
| advisor agent errors / times out | `log_and_continue` — advisory step is non-critical; phase proceeds with a recorded "advisor unavailable" note (NEVER silently treated as a clean pass) |
| advisor finding has no evidence | the finding is dropped at materialization (anti-fabrication rail), logged |
| binding advisor raises a candidate CONFLICT | written to binding.md → existing gate handles it (may block units — this is the intended moat-hardening) |

### Anti-halu rails (new)

1. No advisor finding without source evidence (symmetry with producer rails).
2. Advisor is read-only — it proposes, the skill materializes; the advisor cannot itself rewrite a verdict or invent a vault claim.
3. Advisor-unavailable is recorded distinctly from advisor-clean — a skipped/failed advisor is never reported as "reviewed, no issues."
4. Materialized findings carry an `ADV-` provenance tag so a human can trace which CONFLICT/OQ originated from the advisor vs the producer.

### Moat-asymmetry rail (protects invariant #2 — the gate must never be weakened)

The advisor may **ADD** a blocker autonomously: a high-confidence `false_confirmed`/`missed_match` becomes a real `### CONFLICT-NNN` that the existing gate blocks on (fail-safe — a suspected hole in the moat closes the gate until a human clears it). The advisor may **NEVER auto-remove or auto-downgrade** an existing CONFLICT. A `false_conflict` finding is *flagged only*; downgrading a CONFLICT to WARNING/OK is **human-only** (via `resolve-oq`). This asymmetry is non-negotiable: per `plugins/mega-sdd/CLAUDE.md` "what we will not accept", downgrading a blocking gate is prohibited — so the advisor's adding-direction is autonomous, its removing-direction is human-mediated. A planner must not implement `false_conflict` materialization as symmetric with `false_confirmed`.

---

## §5 Testing

### 5.1 Trigger / dispatch tests
- `generate-intent.test.md`: advisor dispatched before finalize unless `--no-advisor`.
- `bind-codebase.test.md`: advisor dispatched before gate computation unless `--no-advisor`.

### 5.2 Scenario tests (materialization)
- **Binding false-CONFIRMED:** a fixture where a vault claim is marked CONFIRMED against a codebase anchor that does not actually match. Assert the advisor emits a `false_confirmed` finding and a candidate CONFLICT lands in `binding.md` and the existing gate blocks units.
- **Intent fabrication:** a brief with a deliberate gap that a naive pass would fill. Assert the advisor emits `fabrication`/`missed_oq` and the vault gains an OQ instead of an asserted claim.

### 5.3 Anti-halu fixtures
- Advisor finding with no evidence → dropped, not materialized.
- Advisor agent failure → provenance shows "unavailable", NOT "clean".
- `--no-advisor` → provenance shows "skipped", phase output otherwise identical.

### 5.4 Field test
The user's real PRD + starterkit: run generate-intent and bind-codebase, confirm the advisor surfaces at least the known weak spots and that a planted false-CONFIRMED is caught and routed to the gate.

---

## Acceptance criteria

1. `phase-advisor` agent exists, frontmatter-compliant (name + description only; read-only tools; model opus), dispatched by both skills before finalize.
2. Advisor is default-on and skippable via `--no-advisor`; honored in `--auto`.
3. Binding advisor runs as **Step 2.12 — before Step 3 counts + Step 5 gate** — and materializes high-confidence findings as canonical `### CONFLICT-NNN` headings, so they reach BOTH the bind-level decision gate AND `.validation-blockers.json` (verified against `validate-handoff-binding-units.sh`'s `CONFLICT_RE` + the execute-bolts PreToolUse hook). The advisor never writes `.validation-blockers.json` itself.
4. The advisor may add a blocking CONFLICT autonomously but may NEVER auto-downgrade/remove a CONFLICT (`false_conflict` is flag-only, human-resolved); confidence-gated: HIGH → CONFLICT, MED/LOW → OQ.
5. Intent advisor findings materialize as OQs / flagged claims in the vault.
6. Every advisor finding carries source evidence; evidenceless findings are dropped.
7. Advisor-skipped, advisor-clean, and advisor-unavailable are three distinct recorded provenance states.
8. No new blocking hook; hot-path PreToolUse surface unchanged.
9. A planted false-CONFIRMED in a fixture is caught and routed to the blocking gate.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Advisor cost/latency on every phase | default-on but `--no-advisor`; single dispatch per phase; opus justified by leverage at the two highest-stakes gates only |
| Advisor produces noisy false findings | evidence-required rail; severity + confidence fields; binding findings are *candidate* entries a human resolves, not auto-applied blocks |
| Advisor failure silently passes a bad artifact | distinct "unavailable" provenance state; never reported as clean |
| Advisor weaker than producer adds no signal | model pinned to opus |
| Scope creep to all phases | explicitly bounded to bind + intent; others deferred / already covered |

---

## Out of scope (deferred)

- Advisor on `execute-bolts` (already has two-stage code review).
- Advisor on `scan-codebase` (mechanical extraction, low judgment).
- A structural checker on `generate-units` (DAG/atomicity) — separate future iter, "checker" not "advisor".
- Auto-applying advisor findings without human/gate mediation (explicitly chosen against).
- A blocking advisor hook (the advisor feeds existing gates; it is never itself a hard hook).

---

## Spec self-review checklist

- [x] No placeholders / TBDs remain.
- [x] Findings schema (§2.3) matches the materialization flow (§3) and acceptance.
- [x] Enforcement is consistent: advisor non-blocking, feeds existing binding gate + OQ roll-up; no new hook (§1, §3, §4, acceptance).
- [x] Scope bounded to bind + intent; others explicitly deferred.
- [x] Anti-halu rails symmetric with producer rails (evidence-required; read-only; distinct unavailable state).
- [x] Channel verified against the codebase: advisor materializes canonical `### CONFLICT-NNN` at Step 2.12 (before counts/gate) → reaches Step 5 gate + `.validation-blockers.json` (`validate-handoff-binding-units.sh`) → execute-bolts PreToolUse hook.
- [x] Moat-asymmetry rail present: advisor adds blockers autonomously, never auto-downgrades (invariant #2 protected).

> **Superseded (2026-08-01, tranche 5c of `2026-07-30-token-and-latency-optimization.md`):** the intent-leg dispatch in this design ("reads vault + source" as pasted content) is superseded — Step 3.7 now dispatches PATHS + a compact seed under the seed-not-horizon contract; see spec §5c and `generate-intent/references/advisor-checklist.md`.

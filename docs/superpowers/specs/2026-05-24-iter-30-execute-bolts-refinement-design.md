# Iter 30 Design — execute-bolts Refinement (Tiered Context + Seamless Pipeline)

**Status**: Design approved 2026-05-24
**Spec author**: Claude Opus 4.7 (via `superpowers:brainstorming` skill)
**User**: Farhan Riuzaki
**Plugin target**: mega-sdd v3.22.0 (next after v3.21.0 Iter 29)

## 1. Problem statement

User flagged execute-bolts as the MOST CRUCIAL skill (it's where AI actually writes code), and identified pain points in the post-Iter-29 audit:

1. Bolt-level halts require manual `--resume` with no visual progress
2. No aggregate post-bolt summary (just N scattered `bolt-report.md` files)
3. detect-drift trigger ambiguous — should auto-fire post-bolt
4. Drift findings don't auto-handoff to resolution
5. execute-bolts Hard Rule check + detect-drift overlap don't share machinery
6. Convergence loops + bolt-level halts not bridged

**Critical reframe (user's mid-brainstorm clarification)**: the deepest issue is that bolt subagents are dispatched with insufficient context. They re-discover what binding/units/KB already know, hallucinate where grounding exists, and don't carry forward the intelligence built up in earlier phases. Iter 30 must make bolts **SHARP via context-awareness**, not just smoother UX around dumb dispatch.

User directive (carried over from Iter 29 closure): "propagation work belongs WITHIN feature iter, not deferred to audit closure".

## 2. Goals

1. **Sharp bolts** — bolt subagent dispatched with tiered, filtered, grounded context (not raw unit text + general project context)
2. **Seamless pipeline** — `/mega-sdd:auto` flows end-to-end with zero manual invocations between phases; halts surface with structured proposed fixes
3. **Auto-drift gate (default-on)** — `detect-drift` fires automatically after every `execute-bolts` batch; CRITICAL drift on LOCKED entities blocks chain
4. **Propose-and-confirm halt UX** — on bolt halt, AI proposes specific fix; user single-clicks approve/reject; no manual `--resume` dance for common halt types
5. **Compact streaming visibility** — per-bolt progress in 1 line, updated in-place; halts surface inline with full context; aggregate summary at end
6. **Compose with all prior iters** — Iter 22 (mutability), Iter 23 (framework packs), Iter 27 (starterkit-first), Iter 28 (multi-scope), Iter 19 (convergence) all carry forward into bolt dispatch + drift gate
7. **Anti-halu preserved** — every AI-proposed fix requires user approval before apply; propose-and-confirm is the floor, never auto-apply

## 3. Non-goals

- ❌ Cross-vault drift detection (different scopes' bolts → cross-scope drift) — defer to Iter 31+
- ❌ Browser-based dashboard — terminal-only UX preserved
- ❌ Self-healing without user confirm — propose-and-confirm is the floor
- ❌ Multi-bolt parallel dispatch from single user input (already exists via `--parallel`; not the focus)
- ❌ New skills (no `bolts-summary` / `auto-fix-coach` extraction; keep consolidated per anti-sprawl directive)

## 4. The 10 AI-executor principles (foundation for §10 design)

User reframed brainstorm by asking me to imagine myself as the executing AI. These 10 principles emerged:

| # | Principle | Why it matters |
|---|---|---|
| 1 | **Context budget discipline** — tiered context (T1 always, T2 conditional, T3 reference-on-demand); ≤5-7KB sharp prompt vs 50KB scatter | Less is sharper; large prompts dilute attention |
| 2 | **Anti-context** — what NOT to do as crucial as what TO do; DO NOT MODIFY / REPLICATE / WRITE / COMMIT IF blocks | Negative space frees + protects |
| 3 | **Confidence-aware per claim** — HIGH/MEDIUM/LOW labels with source citation | Bolt spends reasoning tokens on LOW areas, sails through HIGH |
| 4 | **Past-failure intelligence** — memory.outcomes.md filtered for patterns matching this unit | Don't repeat known burns |
| 5 | **Self-assessment vocabulary** — structured language to express certain_decisions + uncertain_decisions + fallback_if_wrong | Downstream traceability of judgment calls |
| 6 | **Halt vocabulary in prompt** — 5 halt types + YAML templates pre-loaded | Clean structured halts vs hand-wavy "I think there's a problem" |
| 7 | **Validation hints, not "run tests"** — specific commands + expected output patterns + failure interpretation | No guessing about what "pass" means |
| 8 | **Atomic discipline reinforced** — target_files whitelist + scope-creep halt + commit format scaffolded | Prevents temptation to do unrelated work |
| 9 | **Provenance chain** — every artifact cites unit ID, vault claim, anchors, active Hard Rules | Decision traceability for audit + next bolt |
| 10 | **Graceful partial-state preservation** — uncommitted work survives crashes; partial-state.json captures resumption context | Crash mid-bolt isn't a full restart |

These principles drive §10 (the core design section).

## 5. Architecture overview

Iter 30 changes span THREE skills + shared snapshot machinery:

```
execute-bolts v2.4.2 → v2.6.0          (major minor bump — new dispatch model)
  - NEW Step 4.5: Tiered context enrichment (§10)
  - NEW post-batch aggregate summary (§2)
  - NEW compact streaming format (§1)
  - NEW propose-and-confirm halt UX (§3)
  - NEW per-bolt lightweight drift check (§4)
  - NEW partial-state preservation (principle 10)
  - NEW self-assessment vocabulary in dispatch + bolt-report.md (principle 5)
  - NEW provenance trailers (principle 9)

orchestrate-flow v2.4.1 → v2.5.0        (minor bump)
  - NEW hybrid drift gate phase (default-on; §4)
  - NEW convergence bridge for propose-and-confirm halts (§7)
  - UPDATED chain summary format

detect-drift v1.2.2 → v1.4.0            (minor bump — new auto-trigger mode)
  - NEW auto-trigger handoff from execute-bolts (§4)
  - NEW Suggested next actions block in DRIFT-REPORT.md (§5)
  - NEW bolt snapshot reuse (§6)
  - NEW per-bolt incremental scan mode (lightweight)

SHARED:
  - Bolt preflight/postflight JSON schema aligned with detect-drift scan format (§6)
```

## 6. Design sections

### §1 — Compact streaming progress UX

Per-bolt status as single line, updated in-place:

```
▶ Bolt 7/20: U-007 "Create User model" (scope: BE)
  └─ Context: 6 upstream loaded, 3 anti-patterns flagged, confidence HIGH
  └─ Pre-flight: Hard Rules ✓ | PBT ready ✓ | Anchors verified 3/3 ✓
  └─ Execution: TDD red ✓ → green ✓ (45s)
  └─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
  └─ Commit: 8a3f2e1 "feat(U-007): create User model"
✓ Bolt 7/20: U-007 → done in 1m23s, 0 retries, confidence 0.92
```

Halt cases get fuller treatment inline (see §3).

After batch:

```
══════════════════════════════════════════════════════════
✓ execute-bolts batch complete: 18/20 done, 2 halted, 1 auto-resolved
══════════════════════════════════════════════════════════
  Scope: BE | Duration: 24m11s | Retries: 3 total | Avg confidence: 0.87
  Halts open: U-012 (test_fail awaiting user), U-015 (hard_rule_violated)
  See <vault>/bolts/_summary.md for full table
  Next: detect-drift (auto-gate, hybrid mode)
```

### §2 — Aggregate summary `<vault>/bolts/_summary.md`

Auto-generated after every batch (overwrite-safe, idempotent regen):

```markdown
# Bolts Summary — Order Management BE
**Generated**: 2026-05-24T15:30:00Z (mega-sdd execute-bolts v2.6.0+)
**Scope**: BE — Backend API
**Batch**: --all (20 units)
**Duration**: 24m11s
**Avg AI confidence**: 0.87

## Status table
| Unit | Title | Status | Duration | Retries | Confidence | Halt type | Commit |
|---|---|---|---|---|---|---|---|
| U-001 | User model | ✓ done | 45s | 0 | 0.95 | — | 8a3f2e1 |
| U-002 | Auth middleware | ✓ done | 1m12s | 1 | 0.88 | — | 4b9c7d2 |
| ... | ... | ... | ... | ... | ... | ... | ... |
| U-012 | Refund endpoint | ⛔ halted | 8m44s | 3 | 0.62 | test_fail | (uncommitted) |
| U-015 | Order cancellation | ⛔ halted | 2m11s | 0 | 0.71 | hard_rule_violated | (uncommitted) |

## Halts open (2)
- U-012: test_fail after 3 retries. AI proposed fix available — see `<vault>/bolts/U-012/proposed-fix.md`. Resume: `/mega-sdd:auto --resume`.
- U-015: hard_rule_violated (framework pack rule `migrations-snake-case`). AI proposed fix available — see `<vault>/bolts/U-015/proposed-fix.md`.

## Hard rule violations across batch (by rule)
| Rule | Source | Violations | Resolution |
|---|---|---|---|
| migrations-snake-case | framework-conventions/laravel.md §Hard Rules-001 | 1 (U-015) | Pending |
| constitution-A-001 | constitution.md §A | 0 | — |

## Mutability tier coverage (when scope-tagged vault)
| Tier | Units touched | Status |
|---|---|---|
| LOCKED | 3 (U-002, U-005, U-018) | All ✓ — 1:1 preserved |
| INTENT | 14 | 12 ✓ / 2 halted |
| ARTIFACT | 3 | 3 ✓ discarded as planned |

## Self-assessment summary (uncertain decisions across batch)
- U-002: "Picked bcrypt cost factor 12" — fallback: drop to 10 if perf issue
- U-007: "Used HasUuid trait per project convention" — fallback: none, this is right
- U-011: "Validated refund_amount ≤ order.total via Form Request rule" — fallback: server-side enforcement also added

## Next steps
- Resolve 2 halts: `/mega-sdd:auto --resume`
- After all green: detect-drift will auto-run (hybrid gate; --no-drift-check opt-out)
```

### §3 — Propose-and-confirm halt UX

When bolt halts with eligible halt type (test_fail / hard_rule_violated / pbt_property_violated), AI subagent analyzes + proposes fix. Surfaced via AskUserQuestion:

```
⛔ U-012 halted: test_fail after 3 retries
   Test: tests/Feature/RefundEndpointTest.php::test_refund_full_amount
   Failure: Expected 200, got 422 Unprocessable Entity (validation error)
   Bolt confidence: 0.62 (LOW — bolt flagged uncertainty)
   
   AI proposed fix (review evidence below):
   ┌─────────────────────────────────────────────────────────────
   │ Root cause: bolt subagent missed validation rule
   │             `refund_amount` must be ≤ `order.total_amount`
   │ 
   │ Fix: add to app/Http/Requests/RefundRequest.php:
   │   'refund_amount' => 'required|numeric|max:' . $order->total_amount
   │ 
   │ Re-run test after applying: ./vendor/bin/phpunit
   │   tests/Feature/RefundEndpointTest.php::test_refund_full_amount
   │ 
   │ Evidence trace:
   │ - Test asserts 200 status (line 47)
   │ - Bolt's preflight Hard Rules included max-validation requirement
   │ - bolt-report.md uncertain_decisions[0] flagged this area
   └─────────────────────────────────────────────────────────────
   
❓ How to proceed?
   [1] Apply proposed fix + re-execute (recommended)
   [2] Show alternative fix options (AI proposes 2-3 alternatives)
   [3] Reject — I'll fix manually then /mega-sdd:auto --resume
   [4] Cancel chain — pause everything for review
   [5] Override halt — accept current state as "good enough" (logs to memory)
```

User picks → mega-sdd applies fix → re-runs single bolt → continues batch.

**Eligible halt types for propose-and-confirm (default ON)**:
- `test_fail` (after default 3 retries)
- `hard_rule_violated` (with framework pack provenance evidence)
- `pbt_property_violated` (counterexample preserved)

**Halt types NEVER auto-propose (always pure pause)**:
- `oq_business_p1_unresolved` (needs human business decision)
- `dedup_ambiguous` (needs human judgment)
- `quality_gate_failed` (broader investigation needed)
- `constitution_drift_detected` (audit-significant)
- `bolt_repeated_partial_failure` (structural problem; not a fix)

**Configuration override** (`~/.mega-sdd/memory/config.yaml`):

```yaml
halt_auto_propose:
  test_fail: propose          # always propose; never silent auto
  hard_rule_violated: propose
  pbt_property_violated: propose
  oq_business_p1_unresolved: pause   # never propose
  dedup_ambiguous: pause
  quality_gate_failed: pause
  constitution_drift_detected: pause
```

### §4 — Hybrid drift gate (auto-trigger from execute-bolts → detect-drift)

**Default-on**: after `execute-bolts --all` batch completes, `orchestrate-flow` AUTO-invokes `detect-drift` as gate phase.

```
✓ execute-bolts: 20/20 done
▶ Phase 5.5/6: detect-drift (auto-gate, hybrid mode — DEFAULT-ON)
  Scope: BE — scope-filtered scan
  Comparing: bolt postflight snapshots vs vault (shared snapshot machinery per §6)
  Speed: 4s (vs 28s full re-scan; snapshot reuse saves 6x)
  
⚠️ Drift findings: 3 (1 CRITICAL, 2 LOW)
  CRITICAL: U-018 modified order.amount type (decimal→int) — LOCKED entity per data-mutation-policy.md
  LOW: U-012 added unused import to RefundRequest.php (style only)
  LOW: U-020 audit log field naming slight drift
  
❓ Continue chain? (CRITICAL drift on LOCKED entity blocks default per Iter 22)
   [1] Investigate CRITICAL via resolve-oq → /mega-sdd:resolve-oq --drift D-001
   [2] Override (mark as accepted; log to memory; audit-significant)
   [3] Cancel chain — review manually
```

**Drift severity → chain action** (per Iter 25 severity classification):
- **CRITICAL** drift (LOCKED entity changed) → halt chain; user MUST resolve
- **HIGH** drift (CONFIRMED claim changed) → pause + surface; user can override
- **MEDIUM** drift (INTENT claim implementation changed) → log + continue; surface in summary
- **LOW** drift (style / cosmetic) → log only; no chain interruption

**Opt-out via explicit `--no-drift-check`** flag in execute-bolts or orchestrate-flow (escape hatch, not default).

**On-demand drift still works**: `/mega-sdd:detect-drift` standalone (no chain context).

**Per-bolt incremental drift check** (lightweight, within execute-bolts each commit): after each bolt commit, quick scope-filtered diff against vault → surface drift introduced in compact streaming line:

```
✓ Bolt 18/20: U-018 → done in 2m11s
  ⚠️ Drift introduced: order.amount type changed (LOCKED entity)
  Surface at end-of-batch gate; chain will pause for resolve-oq
```

### §5 — Drift → resolution handoff

`DRIFT-REPORT.md` gains `## Suggested next actions` block per finding:

```markdown
## Suggested next actions

### Finding D-001 (CRITICAL — drift on LOCKED entity)
- Entity: `orders` table, field `amount`
- Drift: vault says `decimal(15,2)`, code is `int` after U-018
- Source claim mutability: kb_locked (BI Reg 23/2/2021 §4)
- **Suggested action**: `/mega-sdd:resolve-oq --drift D-001` — choose:
  - (a) Revert code to vault spec (preserve LOCKED contract)
  - (b) Document deviation in 05-decisions.md with ADR (audit-significant)
- **Auto-handoff command**: `/mega-sdd:resolve-oq --drift D-001 --auto`

### Finding D-002 (LOW — style drift)
- File: `app/Http/Requests/RefundRequest.php` line 12
- Drift: unused import `use App\Models\User;`
- **Suggested action**: No action needed; style fixers (Pint) catch in next cycle.
- **Auto-handoff**: chain continues automatically (no halt for LOW)
```

User clicks suggested action → handoff to appropriate skill with right flags pre-filled.

### §6 — Shared bolt/drift snapshot machinery

**Current state**: execute-bolts writes `<vault>/bolts/U-XXX/preflight.json` + `postflight.json` per Iter 3 + Iter 6. detect-drift currently scans codebase fresh.

**Iter 30 change**: detect-drift reads bolt postflight snapshots when present (CHEAPER + more accurate than full re-scan); falls back to full scan if no bolt context (standalone drift run).

**Schema alignment**: both use same JSON schema (file path + sha256 + structural extracts via tree-sitter / ast-grep). Snapshot format documented at `plugins/mega-sdd/references/shared-snapshot-schema.md` (NEW reference file).

```json
{
  "snapshot_schema_version": "1.0",
  "snapshot_type": "preflight | postflight | drift-baseline",
  "generated_by": "execute-bolts v2.6.0 | detect-drift v1.4.0",
  "generated_at": "<ISO8601>",
  "scope": "BE",
  "files": [
    {
      "path": "app/Models/User.php",
      "sha256": "abc...",
      "ast_signatures": {
        "class_definitions": ["User"],
        "method_signatures": [{"name": "authenticate", "params": "string $email, string $password", "return": "User|null"}],
        "trait_uses": ["HasUuid", "HasUserStamps"]
      }
    }
  ],
  "rules_validated": [...],
  "context": {
    "unit_id": "U-007",  // when bolt-emitted
    "binding_state_at_capture": "CONFIRMED"
  }
}
```

**Performance**: drift gate on 20-bolt batch drops from ~28s (full re-scan) to ~4s (snapshot reuse for files bolts touched + spot-scan for unchanged files).

### §7 — Convergence + bolt halt bridge

Iter 19 convergence loops handle: `bind_conflict`, `module_blocked_by`, `cross_squad_interface_draft`, `oq_recommend_underspecified`.

Iter 30 adds **propose-and-confirm bridge** for bolt halts:
- `test_fail` (after default 3 retries) → AI propose-and-confirm
- `hard_rule_violated` → AI propose-and-confirm
- `pbt_property_violated` → AI propose-and-confirm

Cycle counter respects `--max-cycles` from convergence flag. Cycle = 1 propose + 1 user decision + 1 re-execute attempt.

**Cycle escalation**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop; structural problem). User reviews manually.

### §8 — End-to-end flow narrative (seamless pipeline)

```
$ /mega-sdd:auto ./prd.md

▶ Phase 0: PRD scope picker (Iter 28)
  Scope: BE locked in

▶ Phase 1: scan-codebase (Iter 27 starterkit-first)
  ✓ Framework: laravel-base-26 detected; pack loaded
  ✓ codebase-map.md written
  ✓ Drift snapshot baseline captured (Iter 30 §6)

▶ Phase 2: generate-intent --scope=BE --scan ./prd.md
  ✓ Vault BE generated; scope-tagged; pack-aware dual-citation

▶ Phase 3: bind-codebase
  ✓ 87 claims: 85 CONFIRMED, 0 CONFLICT, 2 OQ (deferred)
  ✓ Suggested Unit Hard Rules emitted

▶ Phase 4: generate-units
  ✓ 20 units emitted with scope/scope_name/depends_on/anchors
  ✓ Wave plan: 3 waves (parallel-safe units)

▶ Phase 5: execute-bolts --all (Iter 30 enrichment)
  ═══════════════════════════════════════════════════════
  ▶ Bolt 1/20: U-001 "DB migrations setup" (scope: BE)
    Context: T1 (2KB) + T2 conditional (none — greenfield) = 2KB sharp
    └─ Pre-flight ✓ | TDD ✓ | Post-flight ✓ | Per-bolt drift ✓
  ✓ Bolt 1/20: U-001 → done in 38s, conf 0.93, commit 4b9c7d2

  ▶ Bolt 7/20: U-007 "User model" (scope: BE)
    Context: T1 + T2 (6 upstream summaries, 3 pack rules, 2 anti-patterns) = 5KB
    └─ Pre-flight ✓ | TDD ✓ | Post-flight ✓ | Per-bolt drift ✓
  ✓ Bolt 7/20: U-007 → done in 1m23s, conf 0.92, commit 8a3f2e1

  ▶ Bolt 12/20: U-012 "Refund endpoint" (scope: BE)
    Context: T1 + T2 (11 upstream, 5 pack rules, 4 anti-patterns flagged HIGH-RISK from memory) = 7KB
    └─ Pre-flight ✓ | TDD red... retry 1... retry 2... retry 3 ⛔
  ⛔ Bolt 12/20: U-012 → test_fail after 3 retries, conf 0.62
  
  💡 AI proposed fix (propose-and-confirm mode):
     Add validation: 'refund_amount' must be ≤ order.total_amount
     Evidence: test output, RefundRequest.php, OrderModel.php anchor
     Bolt's uncertain_decisions[0] already flagged this area
  ❓ Apply fix + re-execute? [1] Yes [2] Alternative [3] Manual [4] Cancel [5] Override
  > User: 1
  
  ✓ Bolt 12/20: U-012 (after AI-proposed fix) → done in 8m44s, 1 fix applied
  
  ▶ Bolt 13/20 ... 20/20 → all ✓
  ═══════════════════════════════════════════════════════
  ✓ execute-bolts batch complete: 20/20 done, 1 halt resolved via propose-and-confirm
  ✓ Summary: <vault>/bolts/_summary.md
  ✓ Avg confidence: 0.87

▶ Phase 5.5: detect-drift (auto-gate, hybrid mode — DEFAULT-ON)
  Snapshot reuse from bolt postflights (4s vs 28s full scan)
  ✓ Drift findings: 1 LOW (style only — no action needed)
  Continue chain.

▶ Phase 6: emit-agents-md
  ✓ AGENTS.md written with scope BE + pack laravel-base-26

══════════════════════════════════════════════════════════════
✓ Pipeline complete: PRD → scope BE vault → 20 units → 20 bolts
══════════════════════════════════════════════════════════════
  Duration: 32m44s (PRD→committed)
  Auto-resolved halts: 1 (test_fail via propose-and-confirm)
  Manual interventions: 1 (scope picker)
  Avg bolt confidence: 0.87
```

ZERO manual invocations between phases. ONE user click for halt resolution. Pipeline flows.

### §9 — Skill version bumps + new reference

| Skill | Version | Justification |
|---|---|---|
| execute-bolts | v2.4.2 → v2.6.0 | Major new capability: tiered context enrichment + propose-and-confirm + summary + per-bolt drift + partial-state |
| orchestrate-flow | v2.4.1 → v2.5.0 | Hybrid drift gate phase + convergence bridge for bolt halts |
| detect-drift | v1.2.2 → v1.4.0 | Auto-trigger handoff + snapshot reuse + suggested actions + per-bolt incremental mode |

**New reference file**: `plugins/mega-sdd/references/shared-snapshot-schema.md` — canonical schema for bolt preflight/postflight + drift baseline snapshots (consumed by both execute-bolts and detect-drift).

**New reference file**: `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — the canonical T1/T2/T3 tiered context enrichment template.

**New reference file**: `plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md` — AI fix proposer subagent prompt template.

### §10 — Tiered context enrichment (THE core change — driven by 10 AI-executor principles)

This is the centerpiece. Driven by §4's 10 principles. Replaces "dump raw unit + run superpowers" with structured enrichment per bolt.

#### 10.1 Dispatch procedure (NEW Step 4.5 in execute-bolts)

```
4.5. **Tiered context enrichment per bolt (v2.6.0+, Iter 30)**

Before dispatching to superpowers `executing-plans`, ASSEMBLE the enriched prompt per `references/bolt-dispatch-prompt.md`:

a. **Load TIER 1 (always included, target ≤2KB)**:
   - Unit body (frontmatter + body sections)
   - Halt vocabulary block (5 halt types + YAML templates)
   - Self-assessment vocabulary template
   - Atomic commit discipline reminder
   - Anti-context block (DO NOT MODIFY / DO NOT REPLICATE / DO NOT WRITE / DO NOT COMMIT IF)
   - Provenance trailer template

b. **Load TIER 2 (conditional, target ≤5KB total)**:
   - depends_on chain: 1-line summary per upstream bolt (read from each bolt-report.md)
   - Framework pack rules: filter pack.md by `path_glob` match against this unit's `target_files`
   - Constitution clauses: ONLY clauses referenced in this unit's `vault_source` sections
   - KB anti-patterns: filter KB by this unit's domain tags
   - Historical memory: filter `<project>/.mega-sdd/memory/outcomes.md` for "bolts touching similar files OR similar pattern" — last 5 only
   - Confidence labels: per claim, with source citation (HIGH from binding, MEDIUM from KB inference, LOW from heuristic)

c. **TIER 3 (NOT embedded; reference-on-demand)**:
   - Full upstream bolt-reports → bolt subagent reads via Read tool if needed
   - Full constitution → reference link only
   - Full KB domain files → reference link only

d. **Always include in EVERY tier**:
   - Validation hints (specific commands + expected output patterns + failure interpretation)
   - Halt vocabulary (5 types + templates)
   - Self-assessment vocabulary

e. **Dispatch**:
   - Log final assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` (provenance + auditability)
   - Dispatch via superpowers.executing-plans

f. **Partial-state contract**:
   - If bolt subagent crashes mid-execution, write `<vault>/bolts/U-XXX/partial-state.json` capturing:
     - files modified (with current sha256)
     - last test result (if any)
     - last AI action / current step
   - Resume reads partial-state, doesn't start from zero
   - After 3 partial-state attempts → halt `bolt_repeated_partial_failure`
```

#### 10.2 Prompt template (per `bolt-dispatch-prompt.md`)

```markdown
═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-XXX
═══════════════════════════════════════════

UNIT: <id> "<title>"
SCOPE: <scope_id> (<scope_name>) — framework: <framework_pack>

═══════════════════════════════════════════
TIER 1 — Always read
═══════════════════════════════════════════

## Unit body (verbatim)
<full unit frontmatter + body>

## Halt vocabulary
IF YOU CAN'T PROCEED, HALT WITH ONE OF:
  type: test_fail              (after 3 retries; include test name + output)
  type: hard_rule_violated     (cite rule + file:line evidence)
  type: ambiguous_spec         (cite ambiguity + 2 interpretations + your default)
  type: missing_dependency     (cite what's missing + where you looked)
  type: scope_creep_detected   (asked to touch files outside target_files)

Halt YAML template:
```yaml
blocker:
  type: <halt_type>
  emitted_at: <ISO8601>
  emitted_by: bolt-subagent-U-XXX
  unit_id: U-XXX
  details:
    <halt-type-specific fields>
  next_action: "<suggested user action>"
```

## Self-assessment vocabulary (REQUIRED in bolt-report.md)
```yaml
bolt_self_report:
  confidence: <0.0-1.0>
  certain_decisions: [<list of decisions with HIGH confidence>]
  uncertain_decisions:
    - decision: "<what you did>"
      rationale: "<why>"
      fallback_if_wrong: "<safer alternative>"
  retry_history: [<list of attempt: N + failure + fix>]
```

## Atomic discipline
- THIS BOLT = ONE COMMIT
- target_files whitelist: <list> — DO NOT touch outside
- Commit message format: "feat(U-XXX): <imperative phrase from unit title>"
- DO NOT bundle unrelated concerns

## Anti-context
DO NOT MODIFY: <LOCKED files from data-mutation-policy>
DO NOT REPLICATE: <KB anti-patterns relevant to this unit>
DO NOT WRITE: <forbidden patterns from framework pack — e.g., $(document).ready()>
DO NOT COMMIT IF: <preconditions — e.g., test failures, hard rule violations>

## Provenance trailer (for every modified file)
Add at top of file (language-appropriate comment):
```
Generated by mega-sdd execute-bolts v2.6.0
Unit: U-XXX (vault sha256: <hash>)
Implements claim: C-NNN "<claim text>"
Anchors consulted: <list>
Hard Rules active: <list of rule IDs>
```

═══════════════════════════════════════════
TIER 2 — Conditional context
═══════════════════════════════════════════

## Upstream bolts (depends_on chain summary)
- U-001 "DB migrations setup" → committed at 4b9c7d2
  └─ Base migration structure exists; build on it
- U-005 "Auth contract definitions" → committed at 1a8c5d3
  └─ User model MUST conform to App\Contracts\Authenticatable

## Framework pack rules (filtered by your target_files glob)
- migrations-snake-case (from laravel-base-26.md §Hard Rules-001)
  └─ Columns in Schema::create blocks MUST use snake_case
- models-pascal-case (from laravel-base-26.md §Hard Rules-002)
  └─ app/Models/*.php MUST follow PascalCase
- has-uuid-trait (from laravel-base-26.md §Idioms)
  └─ Domain entity models SHOULD use HasUuid trait

## Constitution clauses (referenced by your vault_source)
- §B-002: Password hashing MUST use bcrypt (cost factor ≥ 10)

## KB anti-patterns (filtered by your domain)
- KB gotcha G-007: legacy cfkdhl typo (DO NOT REPLICATE per constitution §D-001)
- KB note D-003: User model in legacy carried 47 fields; rebuild scope says 8

## Historical memory (last 5 relevant patterns)
- Pattern "models without HasUuid" → 2 prior reverts in this project; use trait
- Pattern "raw query in controller" → 1 prior revert; use Eloquent

## Confidence labels per claim
- [HIGH] User has email field, type string, max 255 (verified: binding.md C-003 + app/Models/BaseModel.php:42)
- [HIGH] Password field hashed via bcrypt (verified: constitution §B-002)
- [MEDIUM] Email validation rule (KB inference; default to RFC 5322)
- [LOW] Error message wording (your judgment; cite reasoning)

## Validation hints
After implementation, run:
```bash
./vendor/bin/phpunit tests/Unit/UserModelTest.php
```
Expected output pattern: "OK (3 tests, X assertions)"
On fail: failing test name encodes scenario (e.g., test_user_must_have_unique_email → check email uniqueness)

Also run static analysis:
```bash
./vendor/bin/phpstan analyse app/Models/User.php
```
Must pass at PHPStan level 5 (project default).

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (use Read tool when needed)
═══════════════════════════════════════════

- Full upstream bolt-reports: `<vault>/bolts/U-001/bolt-report.md`, `<vault>/bolts/U-005/bolt-report.md`
- Full constitution: `<vault>/constitution.md`
- Full KB domain files: `.mega-sdd/knowledge-base/10-domains/`
- Full memory tables: `<project>/.mega-sdd/memory/`

═══════════════════════════════════════════
GENERATE CODE THAT:
═══════════════════════════════════════════
- Uses target framework conventions per pack
- Respects all [HIGH] claims 1:1
- Cites anchors when extending existing patterns
- NEVER replicates anti-patterns
- Emits provenance trailer in every modified file
- Halts cleanly (per halt vocabulary) if stuck
- Self-reports via bolt_self_report YAML at end
```

#### 10.3 Outputs per bolt (post-execution)

- `<vault>/bolts/U-XXX/dispatch-prompt.md` — the enriched prompt sent (auditability)
- `<vault>/bolts/U-XXX/bolt-report.md` — bolt's self-assessment + result (existing, enhanced with self-assessment block)
- `<vault>/bolts/U-XXX/preflight.json` + `postflight.json` — existing snapshots
- `<vault>/bolts/U-XXX/partial-state.json` — ONLY if crash mid-execution
- `<vault>/bolts/U-XXX/proposed-fix.md` — ONLY if halt + AI proposed fix

#### 10.4 Anti-halu rails

- Tier filtering MUST cite source for inclusion (e.g., "framework pack rule X loaded because target_files matched glob Y")
- Anti-context block populated from actual data sources (data-mutation-policy.md, KB, framework pack) — not invented
- Self-assessment confidence MUST be 0.0-1.0; halt if bolt-subagent omits
- Provenance trailer MANDATORY in every modified file — post-flight scan verifies presence; missing → halt `provenance_missing`
- Partial-state.json MUST be append-only JSONL; no overwrites during resume

## 7. Acceptance criteria

Iter 30 ships when:

1. ✅ execute-bolts v2.6.0 dispatches with tiered context enrichment per §10
2. ✅ Bolt subagent receives ≤7KB prompt vs current "unit body + raw context"
3. ✅ Compact streaming format (§1) renders correctly
4. ✅ Aggregate `<vault>/bolts/_summary.md` auto-generated post-batch
5. ✅ Propose-and-confirm halt UX fires for test_fail / hard_rule_violated / pbt_property_violated
6. ✅ User can configure halt_auto_propose per type via `~/.mega-sdd/memory/config.yaml`
7. ✅ orchestrate-flow auto-invokes detect-drift after execute-bolts batch (default-on)
8. ✅ Drift severity → chain action: CRITICAL halts, HIGH pauses, MEDIUM/LOW logs
9. ✅ `--no-drift-check` flag works as escape hatch
10. ✅ DRIFT-REPORT.md gains `## Suggested next actions` block with auto-handoff commands
11. ✅ detect-drift reuses bolt postflight snapshots when present (performance: ≤5s for 20-bolt batch drift gate)
12. ✅ Shared snapshot schema at `references/shared-snapshot-schema.md`
13. ✅ Bolt dispatch prompt template at `execute-bolts/references/bolt-dispatch-prompt.md`
14. ✅ Propose-and-confirm prompt template at `execute-bolts/references/propose-and-confirm-prompt.md`
15. ✅ Convergence loops bridge bolt halts (propose-and-confirm respects `--max-cycles`)
16. ✅ Partial-state preservation works (crash mid-bolt → resume from partial-state.json)
17. ✅ Provenance trailer in every modified file (post-flight verified; halt `provenance_missing` if absent)
18. ✅ Self-assessment YAML in every bolt-report.md (halt if bolt subagent omits)
19. ✅ Composition with Iter 22 (mutability), Iter 23 (framework packs), Iter 27 (starterkit), Iter 28 (multi-scope), Iter 19 (convergence) preserved
20. ✅ Plugin version bumped 3.21.0 → 3.22.0; CHANGELOG entry; README updated

## 8. Composition with prior iters

- **Iter 19 (convergence loops)**: Iter 30 propose-and-confirm becomes the bolt-side bridge to existing chain-level convergence
- **Iter 22 (mutability tiers)**: drift severity classification uses LOCKED/INTENT/ARTIFACT tiers; CRITICAL = drift on LOCKED
- **Iter 23 (framework packs)**: Tier 2 context loads filtered pack rules per unit target_files
- **Iter 27 (starterkit-first)**: scan-codebase pre-loads pack into context before generate-intent → execute-bolts gets pack via codebase-map.md §7
- **Iter 28 (multi-scope)**: bolt dispatch includes scope context; scope filtering applies to drift scan; cross-scope coordination remains human-driven
- **Iter 29 (audit closure scope propagation)**: scope: handoff block carries through execute-bolts → detect-drift handoff

## 9. Rollout

After v3.22.0 ships:

1. User field-tests Iter 30 on tradefinance project (the long-deferred field-test now becomes the Iter 30 validation)
2. First-run friction expected: enrichment template needs tuning; halt UX needs UX iteration
3. Memory `outcomes.md` accumulates bolt halt patterns → propose-and-confirm gets sharper over time
4. After 10+ batch runs: review halt_auto_propose config defaults; adjust per-halt-type if patterns emerge
5. Future iters can add more halt types to propose-and-confirm eligibility as confidence grows

## 10. Out of scope (deferred)

- Cross-vault drift detection (different scopes' bolts → cross-scope drift) → Iter 31+
- AI-proposed fixes for `oq_business_p1_unresolved` (always-human by design)
- Browser-based progress dashboard
- Self-healing without user confirm
- Parallel propose-and-confirm UX (only one halt at a time surfaced)
- Skill extraction (no new `bolts-summary` or `auto-fix-coach` skill — keep consolidated)

---

## Appendix A — Example dispatch prompt size budget

Empirical target for sharp dispatch:

| Tier | Content | Target size | Hard cap |
|---|---|---|---|
| T1 (always) | Unit body, halt vocab, self-assess, atomic, anti-context, provenance | 1.5-2.5KB | 3KB |
| T2 (conditional) | Upstream summaries, pack rules, constitution, KB anti-patterns, memory, confidence labels, validation hints | 3-5KB | 7KB |
| T3 (reference-only) | Links to full files | <0.5KB | 1KB |
| **Total dispatch** | | **5-7KB** | **10KB hard cap** |

Above 10KB → halt `dispatch_prompt_too_large` (re-tier or escalate to chain orchestrator for splitting).

## Appendix B — Halt YAML examples

### test_fail (eligible for propose-and-confirm)
```yaml
blocker:
  type: test_fail
  emitted_at: 2026-05-24T15:30:00Z
  emitted_by: execute-bolts-U-012
  unit_id: U-012
  details:
    retries: 3
    failing_test: "tests/Feature/RefundEndpointTest.php::test_refund_full_amount"
    failure_output: |
      Expected status 200, got 422 Unprocessable Entity
      ValidationException: refund_amount exceeds order total
    target_files_modified: ["app/Http/Controllers/RefundController.php", "app/Http/Requests/RefundRequest.php"]
  next_action: "propose-and-confirm fix dispatch OR /mega-sdd:auto --resume after manual fix"
  proposed_fix_path: "<vault>/bolts/U-012/proposed-fix.md"
```

### hard_rule_violated (eligible for propose-and-confirm)
```yaml
blocker:
  type: hard_rule_violated
  emitted_at: 2026-05-24T15:30:00Z
  emitted_by: execute-bolts-U-015
  unit_id: U-015
  details:
    violated_rule: "migrations-snake-case"
    rule_source: "framework-conventions/laravel-base-26.md §Hard Rules-001"
    violation_evidence:
      file: "database/migrations/2026_05_24_153000_create_orders_table.php"
      line: 12
      offending_code: "$table->string('orderTotal')"
      expected: "$table->string('order_total')"
  next_action: "propose-and-confirm fix dispatch"
  proposed_fix_path: "<vault>/bolts/U-015/proposed-fix.md"
```

### provenance_missing (always pause; new halt type)
```yaml
blocker:
  type: provenance_missing
  emitted_at: 2026-05-24T15:30:00Z
  emitted_by: execute-bolts-U-XXX
  unit_id: U-XXX
  details:
    missing_in_files: ["app/Models/User.php"]
    expected_trailer: "Generated by mega-sdd execute-bolts v2.6.0..."
  next_action: "Add provenance trailer + re-commit OR halt for review"
```

### bolt_repeated_partial_failure (always pause; structural problem)
```yaml
blocker:
  type: bolt_repeated_partial_failure
  emitted_at: 2026-05-24T15:30:00Z
  emitted_by: execute-bolts-U-XXX
  unit_id: U-XXX
  details:
    partial_attempts: 3
    last_failure: "<from partial-state.json>"
    consistent_failure_pattern: "<inferred pattern>"
  next_action: "Manual review required. Possible causes: corrupted unit spec, environment issue, hidden circular dependency"
```

---

**End of design spec.**

Approved by user: 2026-05-24
Spec author: Claude Opus 4.7 via `superpowers:brainstorming` skill
Next step: invoke `superpowers:writing-plans` to create implementation plan from this spec.

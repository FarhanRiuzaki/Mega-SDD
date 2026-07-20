# Field Audit — MSmile-Pegadaian full-pipeline run (intent → bolts)

**Audited:** `/Users/farhanriuzaki/Development/KANTOR/02_Projects/MSmile-Pegadaian/.mega-sdd`
**Feature:** `beli-emas-pegadaian` (buy gold at Pegadaian) — Next.js 16 / React 19 / TypeScript / Biome / Yarn brownfield WebView + BFF.
**Plugin version that ran:** ≈ 4.38.0 (the cached marketplace copy). Findings predate 4.39.0.
**Method:** recompute-not-trust-stale — git timeline reconstructed; the four failing validators re-run fresh against *current* state; `yarn install && yarn build && yarn test` run empirically; transcript token usage measured from ground truth (not ccusage estimate); 5 parallel deep finders + 9 adversarial verifications (7 confirmed, 2 overstated, 0 refuted).
**Date:** 2026-06-26

---

## 0. Headline

> **The moat held. The quality/propagation rails and the cost story did not — and the token alarm is ~4.8× smaller than the raw count suggests.**

Run produced 11 units + 11 bolts (14 test files + a type extension) for a brownfield repo whose product code largely pre-existed. The CONFLICT gate behaved exactly as designed (0 conflicts → correctly non-blocking), the anti-hallucination discipline held *at execution* (no fabricated anchors, honest `it.todo()` deferrals), and the drift lane caught real constitution violations. But: the committed test suite ends **RED**, the one bolt that contractually required a post-flight gate left no trace, the unit generator stamped `verify/HIGH` on units certifying behavior that does not exist in source, and three artifacts (`binding.json`, `bound/`, `DRIFT-REPORT.md`, `codebase-map.md`) are silently stale.

**On tokens:** the user measured ~80M (intent→unit) + ~96M (bolts) = ~176M via ccusage. Ground-truth transcript decomposition shows **91.9% of that is `cache_read`**, which bills at ~0.1×. Cost-weighted, 176M raw ≈ **~37M cost-equivalent** — the raw count overstates cost **~4.8×**. The real cost driver is *standing-context re-read per turn* (the in-thread context grew 16.5K → 325K tokens, monotonic, over ~250 turns), **not** the ref-reloads (0.16%) or artifact sizes. The plugin's own telemetry is **blind to ~all of it**.

---

## 1. What the pipeline got RIGHT (state plainly)

| ✓ | Finding | Evidence |
|---|---|---|
| Moat held | binding.md `conflict: 0` → gate OPEN, correctly non-blocking; no spurious halt | `binding.md:21`; `.validation-blockers.json conflicts_unresolved=0` |
| Anchors real | All ~13 sampled unit code-anchors resolve to real symbols in `src/`; zero fabricated files/symbols | `gold-calculator.ts:13`, `mega-mapper.ts:37/69`, `getAdapter()` `adapter.ts:17`, … |
| Bolts honest | U-004/U-007/U-011 bolt-reports' "files changed" match their git diffs **exactly**; no inflation; unverifiable PRD copy parked as `it.todo()` not faked-green | `git show bd42600/11caa50/cabcd7a` |
| Deferred OQs safe | 9 of 10 "dropped" OQs are benign — no bolt back-filled an unknown numeric code, host, fee tier, lockout count, or design token | `vault.json` + `src/` greps (BFF only handles known 98/99/00; no lockout logic invented) |
| Drift lane works | detect-drift caught real CRITICAL constitution violations the bolts shipped: §A-003 (Biome lint not clean, masked by a broken schema) + §D-002/§D-004 (wrong M-PIN / failure copy) | `DRIFT-REPORT.md` §A-003/§D-002 |
| No fabricated resolutions | §A-003 honestly **not** marked fixed (`yarn lint` still exits 1); drift-history logs "all findings triage-pending" | `DRIFT-REPORT.md`; `yarn lint` exit 1 |
| Dispatch budget | The per-bolt dispatch-prompt cap (9KB target / 12KB hard, priority-tiered truncation, constitution clauses never dropped) is well-designed and is **not** a bloat source | `execute-bolts/references/context-enrichment.md:3` |
| Verify-path & dir rails | All 11 bolt dirs created; U-002…U-010 are canonically `task_type=verify` and the verify-path legitimately skips post-flight — contract-compliant, not a gate miss | `units/U-00*.md`; `execute-bolts/SKILL.md:92` |

The constitution itself is high quality — real grounded governance (A coding / B security / C architecture / D anti-patterns / E·F), each clause citing a PRD § or codebase-map §. Not boilerplate.

---

## 2. Verified defects → plugin levers

Severity is **post-adversarial-verification**. Each row names the mega-sdd skill/script/hook to change.

### A. Unit generation — false grounding signal

**A1 · `generate-units` stamped `verify` / `HIGH` / `anchors_verified=N/N` on units certifying behavior absent from source** — **HIGH** (confirmed)
The verify units U-006/007/008/009/010 carry LOCKED-verbatim acceptance copy (`Minimal pembelian Rp 10.000`, daily-limit, source-of-fund, account-state, pending-state) that exists **only** in the test stubs and the PRD — never in production `src/`. Yet each is frontmatter `task_type:verify, grounding_confidence:HIGH, anchors_verified:N/N`. The bolts caught it (66 `it.todo()` entries); the generator should have.
Root cause: `unit-schema.md:41/47` defines `HIGH`/`anchors_verified` purely as *"file exists + line valid"* — symbol existence, never per-acceptance-criterion source grounding. The prose hedge in U-007's body ("only MIN_GRAM is code-anchored") never reaches the structured metadata downstream tooling/humans trust → a `verify/HIGH` unit certifying unbuilt behavior = structurally false-green.
**Lever:** `generate-units` — for each LOCKED-verbatim AC in a verify unit, grep the asserted string against the unit's non-test target files; if absent, down-grade `grounding_confidence` and/or split into `verify[built path] + create[unbuilt copy]` (the existing Mix-NEW+IMPLEMENTED row). Add a `lint-units` check that fails any verify unit whose `acceptance_test` maps to an `it.todo()` stub.

**A2 · `OQ-FL-5` resolved-but-unpropagated → PriceChart still renders** — **MEDIUM** (confirmed via GF-05)
`vault.json` marks OQ-FL-5 `status:resolved` ("hide historical chart for MVP via feature flag, follow-up unit"), but no unit implements it and `src/app/page.tsx:101` still renders `<PriceChart>` gated only on error.
**Lever:** `resolve-oq` — when a resolution references a "follow-up implementation unit", auto-emit a stub unit into the backlog **or** mark `status: resolved_pending_unit` so handoff/freshness validators flag the un-propagated decision instead of treating it as closed.

**A3 · `handoff-binding-units` "10 orphaned OQ-IDs" FAIL is semantically inflated** — **MEDIUM** (confirmed via GF-06)
`binding.md:196` explicitly enumerates 7 purely-business OQs *to declare them out of binding's scope* — but the validator extracts every OQ-ID token in binding.md and demands each appear in a unit, over-counting deliberately-excluded IDs. Of the 10 flagged, only FL-5 is a real "should-have-governed" miss. This validator-precision defect also feeds the 97-event detection-only re-emission noise (§D3).
**Lever:** `validate-handoff-binding-units.sh` — skip OQ-IDs the binding's own "out of scope" paragraph enumerates, and skip OQs whose `vault.json status ∈ {resolved, out_of_scope, deferred}`. Report only OQs that are code-referencing **and** unresolved **and** absent from every unit.

### B. Bolt execution — missing enforcement & no full-suite gate

**B1 · The one bolt that required post-flight (U-011, `extend`) committed with no `postflight.json`; the gate is prose-only** — **HIGH** (confirmed)
`units/U-011.md` is `task_type=extend` with non-empty Hard rules; `bolts/U-011/` has no `postflight.json`; `bolt-report.md status:completed`. On the cached 4.38.0 copy, `grep -rc postflight hooks/ scripts/` = **0** — the post-flight Hard-rule scan exists only as SKILL.md prose; the Stop-hook (`validate-bolt-artifacts.sh`) checks bolt-report presence, never postflight. Textbook "prose that says HALT enforces nothing." (The hard rules would have *passed* had the scan run — an absent safety net, not a masked violation.)
**Lever:** `scripts/validate-bolt-artifacts.sh` — for a committed `create`/`extend`/`modify` bolt with non-empty `## Hard rules`, missing `postflight.json` (with all rule verdicts `pass`) → halt (`postflight_evidence_missing`). Move the gate from prose to hook.

**B2 · The committed suite ends RED — a cross-bolt regression with no final full-suite gate** — **HIGH** (confirmed)
`yarn vitest run` at HEAD = **1 failed / 128 passed / 32 todo**. `src/test/mega-mapper.test.ts:178` fails because `fromMegaBillResponse` now emits `adminFee/komisiBankMega/totalKewajiban`. Proximate cause: an **out-of-band post-bolt edit `2b283d5` (CLEANUP-002)** added the fee-field emission with no bolt dir / no `SDD-PROVENANCE` trailer — it bypassed pre/post-flight, panel, and provenance. (U-004 was 12/12 green at its own commit `bd42600`.) Systemic cause: each verify bolt's acceptance command is **scoped** (`yarn test mega-mapper`, not full `yarn test`), and `execute-bolts` has **no final full-suite gate** — so a later bolt/edit silently breaks an earlier bolt's contract with nothing re-running it.
**Lever:** `execute-bolts` post-batch step (SKILL.md ~:123) — add a final **full-suite** test gate after the last unit that HALTS the batch RED. Add a provenance/bypass guard flagging commits that touch a unit's `target_files` without an `SDD-PROVENANCE` trailer; the sync lane must re-run the full suite after reconciling any out-of-band edit.

**B3 · 32 live `it.todo()` placeholders shipped as `status:completed` verify units** — **MEDIUM** (confirmed)
Verify units U-007/U-008/U-010 committed test files whose limit/copy assertions are `it.todo()` — titles read like tested limits (`saldo-mengendap 0.05 gram floor with verbatim "…"`) but assert nothing. Verify units are meant to *lock* existing behavior; 32 hollow stubs overstate coverage.
**Lever:** a verify unit's acceptance must require its named Hard-rule/limit assertions be **live**, not `it.todo`. `validate-unit-spec`/`lint-units` fails a verify unit whose acceptance maps to a stub; `execute-bolts` downgrades to `status:partial (coverage_deferred)` when committed test files contain todos tied to the unit's Hard rules. Surface a todo-count in `bolts/_summary.md`.

**B4 · Review panel never ran on any bolt; firewall-blocked dispatch fell back to silent self-implementation** — **MEDIUM** (confirmed)
Zero blind-lens evidence across 11 bolt-reports despite SKILL.md mandating the risk-tiered panel. `bolts/U-008/preflight.json` records the subagent dispatch was blocked (HTTP 407 corporate firewall) → "implemented inline in the controller thread" → still `status:completed`. An unverifiable rail is an absent rail. Separately, `preflight.json` schemas drift per-bolt (LLM-authored free-form: U-002 vs U-004 vs U-011 have disjoint key sets), violating the plugin's own "deterministic logic belongs in `scripts/`."
**Lever:** `execute-bolts` — a `review_panel:` block (tier, `lenses_run[]`, verdicts, or `skipped_reason: firewall_407`) that a Stop-hook validates; infra-blocked panel → `status:needs_review`, never silent `completed`. Generate `preflight.json`/`postflight.json` from a deterministic script with one fixed schema.

**B5 · `CLEANUP-001` bundled a `biome --unsafe` behavior-changing sweep into a "mechanical cleanup" commit** — **LOW** (confirmed)
Good news first: the "verbatim copy" in CLEANUP-001 is **UI string literals copied verbatim from the constitution** (the correct anti-paraphrase discipline) — *not* code copied from a reference. But the same commit ran `biome check --write --unsafe` (which rewrote React hook deps in 6 components — a runtime behavior change) plus mass test-file reformatting, all outside any bolt gate, labeled "mechanical."
**Lever:** the sync/CLEANUP path must split substantive `--unsafe` auto-fixes from mechanical formatting into separate commits and route behavior-changing sweeps through the `execute-bolts` gate (full-suite re-run + provenance). Never label a `--unsafe` auto-fix "mechanical."

### C. Drift & binding desync — stale artifacts shipped silently

**C1 · `DRIFT-REPORT.md` is frozen 2 commits behind HEAD — reports already-fixed violations as live CRITICAL** — **HIGH** (confirmed)
Header `HEAD 56835cd / Generated 18:45 / v1.3`; current HEAD `2b283d5`. §D-002 + §D-004 were **fixed** by `128fe9f` (CLEANUP-001) — current code is constitution-verbatim — yet the report still presents them as live CRITICAL drift, mixed with genuinely-live §D-003/§A-003 and **no marker to tell them apart**. The sync run's chained detect-drift step never regenerated the report (`git log 56835cd..HEAD -- DRIFT-REPORT.md` = untouched).
**Lever:** `detect-drift` — stamp a `report_head` + on session-start/sync compare to HEAD; if advanced, banner the report STALE and per-finding re-check (resolved findings flip to `RESOLVED since <sha>` instead of re-printing). `sync` (Mode D) must actually re-run/overwrite the report.

**C2 · No `SYNC-REPORT.md` produced; the sync's closing staleness verification never ran** — **MEDIUM** (confirmed via DBD-04)
`commands/sync.md:26` mandates a terminal `SYNC-REPORT.md` with a `compute-unit-staleness.sh` re-run; both `SYNC-REPORT.md` and `PENDING-SYNC.md` are absent though two sync-lane commits exist. The skipped closing gate is *exactly* what would have caught C3 + C4.
**Lever:** make `SYNC-REPORT.md` emission + the closing staleness verification a non-optional terminal step (Stop-hook/PostToolUse check that a sync-lane binding/map write without a `SYNC-REPORT.md` surfaces a warning); cover `binding.json` + `bound/` + codebase-map provenance, not only unit staleness.

**C3 · `codebase-map` stale again immediately after sync-v1.4 "refreshed to HEAD"** — **MEDIUM** (confirmed via DBD-03)
`last_scanned_commit 516bb1d`; current HEAD `2b283d5` — 51 files / +503/−529 changed since, including real source moves (`confirm/page.tsx` 154→166 lines). The freshness gate ("the spine") reported GREEN while already behind, because it checks at write-time and is never re-evaluated as later commits land.
**Lever:** `scan-codebase`/`sync` — re-evaluate `snapshot-verified` lazily (session-start/pre-bind); if HEAD ≠ `last_scanned_commit`, downgrade binding `precision_tier` from `ast` and surface "map stale, N commits behind."

**C4 · `binding.json` + `bound/` are stale pre-bolt snapshots — single-claim desync, latent** — **MEDIUM** (overstated→corrected from HIGH)
The sync lane re-verdicted `binding.md` only (C-DM-06 → `IMPLEMENTED_OPTIONAL_DRIFT`) and skipped re-emitting `binding.json` and mirroring `bound/binding.md` (both still `PARTIAL_FIELDS_MISSING`). **Correction from verification:** this is a *one-claim* desync (44/45 claim rows byte-identical — *not* "entire claim list diverged"), `binding.json` is **not** consumed on the re-units path (near-cosmetic), and a re-bind self-heals. The single load-bearing risk is latent: a future re-`generate-units` reads `bound/binding.md` and would spawn an `extend` unit to ADD fee fields that already exist.
**Lever:** `bind-codebase` `--paths`/sync branch must re-emit `binding.json` **and** re-mirror `bound/binding.md` in lockstep when it re-verdicts `binding.md`; promote `scripts/validate-binding-json.sh` from in-skill prose to a real hook (currently 0 `hooks/` references).

### D. Token economics — the user's core concern

**D1 · Plugin telemetry is structurally blind to the bolt phase (and ~all 176M)** — **CRITICAL** (confirmed)
`hook-debug.log` has 4 Stop fires, all ending 14:49 local — **before** bolts ran (16:51–18:34). `telemetry.jsonl` has 4 `turn_end_marker`s, all in the SDD session. The bolts ran inside **workflow subagents**, and **subagent turn-ends never fire the Stop hook** — verified: even the plugin-repo's own `.mega-sdd/memory` captured 0 markers for the bolt window. The Stop hook also gates emission on `telemetry.jsonl` already existing. Net: the heaviest phase generated zero telemetry. Direct token savings ≈ 0, but this is the **#1 lever by value** — without per-phase capture, none of the optimization below is measurable from inside the plugin.
**Lever:** `hooks/` — add a `SubagentStop` capture path, **or** have the `execute-bolts` controller extract per-bolt `usage.*` from each dispatched subagent transcript and append a per-bolt telemetry event (mirror `hooks/stop:240-262` controller-side). Seed `telemetry.jsonl` at chain start so the existence-gate never suppresses a fresh session.

**D2 · Token-count framing overstates cost ~4.8×; the real driver is standing-context re-read per turn** — **CRITICAL** (confirmed, weights validated against real Opus pricing)
Ground-truth decomposition of the SDD session + its 12 subagents: 100.7M raw = input 1.2% + cache_creation 6.4% + **cache_read 91.9%** + output 0.5%. Cost-weighted (cr 0.1× / cc 1.25× / out 5×, the exact Opus price ratios) = ~21.1M cost-units → raw overstates cost **4.76×** ($317 actual vs $1,510 naive). Standing context grew 16.5K → 325K `cache_read` (median 209K), strictly monotonic over ~250 turns, as the vault/binding/units accumulated in-thread and re-billed at 0.1× every turn. The 279K ref-reloads = **0.16%** (red herring).
**Lever:** drive phases as fresh sub-sessions so the standing context **resets** between extract→intent→scan→bind→units rather than ballooning to 325K (un-gate `context: fork` for the non-interactive diagnostic phases first); emit leaner per-turn handoff slices instead of whole-vault context; **report cost-weighted tokens** (not raw) in any analyze/telemetry summary so users right-size alarm.

**D3 · The 12 SDD subagents are half the intent→unit spend (50.3M of 100.7M)** — **HIGH** (confirmed; note: ground-truth SDD total is 100.7M, 1.26× the cited 80M)
The 12 subagents each re-create a large cache (~380K `cache_creation` each) and re-read it. Top drivers: "Fold flow PDF into vault" (8.6M, largest), "Land P2 OQ resolutions" (8.2M), intent-gen — each re-reads the *full* vault. Three separate OQ/fix passes ("Land OQ" + "Land P2 OQ" + "Apply phase-advisor fixes") = 15.6M combined.
**Lever:** the fix is not "spin fewer subagents" generically — it's (a) **scope** per-subagent context instead of folding the whole vault into each dispatch, and (b) **collapse** the redundant multi-pass OQ-resolution subagents. Apply the existing dispatch-budget discipline (D-positive below) to the SDD-phase analysis subagents, not just bolts.

**D4 · 184 detection-only halt re-emissions** — **MEDIUM** (corrected: integrity/noise, ~0 tokens — *not* a token lever)
97 `vault_binding_coverage_gap` + 87 `hard_rule_trace_missing` (78× on U-001.md alone) re-detected, `logged_at_chat=False`, `fix="detection-only… manual review required"`. They fire from PostToolUse validators, inject ~0 tokens — so **not** a token-savings lever (corrects the first-pass hypothesis). The real defect: the same unresolved gap (the live non-moat FAILs) is re-detected forever with no resolution path.
**Lever:** PostToolUse validators — debounce/dedupe re-emission per gap-hash until the underlying file changes; wire these detections to a real resolution surface (`analyze`) instead of detection-only.

**D5 · `bound/` is a 113KB generated copy nothing downstream reads; `00-index.md` (23KB) re-states the other docs** — **LOW** (overstated→corrected from HIGH)
**Correction from verification:** `bound/` appears **0 times** in telemetry — no phase reads it; `00-index.md` is re-billed 13× (not "hundreds"). Deflated cost ≈ 0.04%, not high. Still a genuine "generated waste nothing consumes" defect (and sync left `bound/` frozen at v1.0/v1.1 while the vault hit v1.4).
**Lever:** `bind-codebase` should stop materializing a full `bound/` copy (keep `binding.md` verdicts + per-doc annotations as references); `generate-intent`'s `00-index.md` template should stop duplicating the OQ roll-up + per-doc sections that live in 01/05/06.

**D6 · Review panel as a latent cost multiplier with no skip-when-trivial tier** — **MEDIUM** (confirmed)
It didn't run this time (saving a 5-lens × 11-bolt multiplier) but its silent absence is *why* no review caught B2. Make it cheap-and-conditional, not silently off.
**Lever:** `review-panel.md` — a risk-tier that runs the panel only for code-bearing/high-risk bolts (skip/single-lens for `verify` test-only bolts) so it is affordable enough to run by default; **plus** the final full-suite gate from B2.

**D-positive · the per-bolt dispatch-prompt budget cap is the pattern to generalize upward** — reuse `context-enrichment.md`'s budget-tracker as a shared `scripts/_lib` helper for the orchestrate-flow controller's standing context and the SDD subagent seeding.

---

## 3. Corrections to first-pass assumptions (intellectual honesty)

The deep pass overturned several plausible-but-wrong first reads — recorded so they are not repeated:

1. **"U-011 broke U-004's test."** Wrong attribution. U-011 (`cabcd7a`) added only optional *interface* fields; the mapper *emission* that broke `toEqual` came from the out-of-band `2b283d5` (CLEANUP-002). Systemic cause is the missing full-suite gate, not a specific bolt.
2. **"10/11 bolts skipped post-flight = gate failure."** Mostly wrong. U-002…U-010 are canonically `verify`, which contractually skips post-flight. Only U-011 (`extend`) is a true gate gap.
3. **"194 halts + 279K ref-reloads = token waste."** Both ~0 token cost. The cost is standing-context monotonic growth × cache_read at 0.1×.
4. **"`yarn build` is red (bolt defect)."** Environmental only — deps were correctly declared; `node_modules` was stale. Green after `yarn install`.
5. **"10 OQ drops = fabrication risk."** 9/10 benign; the validator FAIL is semantically inflated (A3). The lone real miss is OQ-FL-5 (A2).

---

## 4. Prioritized plugin-improvement backlog

Ranked by (impact × how load-bearing the rail is). All are **new** levers surfaced by this real run — 4.39.0 does not address them.

| # | Lever | Skill / file | Sev |
|---|---|---|---|
| 1 | Final **full-suite** test gate at batch end (HALT on RED) | `execute-bolts` SKILL.md ~:123 | HIGH (B2) |
| 2 | Post-flight gate → hook for `create/extend/modify` bolts | `scripts/validate-bolt-artifacts.sh` | HIGH (B1) |
| 3 | Per-AC source grounding before `verify/HIGH`; lint `it.todo` acceptance | `generate-units` + `lint-units` | HIGH (A1, B3) |
| 4 | Per-phase / per-subagent token capture (SubagentStop or controller-side) | `hooks/` + `execute-bolts` | CRITICAL-by-value (D1) |
| 5 | Report **cost-weighted** tokens; context-reset between phases | `analyze` + `orchestrate-flow` (`context: fork`) | CRITICAL-framing (D2) |
| 6 | Scope subagent context; collapse redundant OQ-resolution passes | `orchestrate-flow` / `resolve-oq` / `generate-intent` | HIGH (D3) |
| 7 | DRIFT-REPORT HEAD-staleness invalidation; sync must regenerate it | `detect-drift` + `commands/sync.md` | HIGH (C1) |
| 8 | Sync `SYNC-REPORT.md` + closing staleness verification = non-optional terminal step | `orchestrate-flow` Mode D / `commands/sync.md` | MED (C2) |
| 9 | Lazy re-eval of codebase-map `snapshot-verified` vs HEAD | `scan-codebase` / `sync` | MED (C3) |
| 10 | `--paths` re-bind re-emits `binding.json` + mirrors `bound/`; parity guard → hook | `bind-codebase` | MED (C4) |
| 11 | Review-panel risk-tier (skip for verify test-only); panel skip must be recorded | `execute-bolts/review-panel.md` | MED (B4, D6) |
| 12 | Validator precision: exclude out-of-scope/resolved OQs from handoff FAIL | `validate-handoff-binding-units.sh` | MED (A3) |
| 13 | resolve-oq: follow-up-unit resolutions → backlog stub or `resolved_pending_unit` | `resolve-oq` | MED (A2) |
| 14 | Deterministic preflight/postflight schema; debounce detection-only re-emits | `execute-bolts` + PostToolUse validators | MED (B4, D4) |
| 15 | Stop materializing unread `bound/`; thin `00-index` template | `bind-codebase` / `generate-intent` | LOW (D5) |
| 16 | Split `--unsafe` auto-fixes from mechanical formatting; route through gate | sync / CLEANUP path | LOW (B5) |

---

*Generated by a mega-sdd field audit (5 parallel finders + 9 adversarial verifications; 14 subagents, ~0.92M audit tokens). Token figures are transcript ground-truth; severities are post-verification.*

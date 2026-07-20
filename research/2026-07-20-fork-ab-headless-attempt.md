# Fork A/B — the headless attempt: two hard walls, three real findings

**Date:** 2026-07-20 · **Operator:** dev-session (full-auto attempt per user request) · **Target:** MSmile-Pegadaian, vault `beli-emas-pegadaian`, cache 5.1.1 · **Verdict: A/B NOT COMPLETED — blocked by a platform limitation + a legitimate scenario halt. Nothing was faked; state fully restored.**

## What was attempted

Per `~/.mega-sdd/fork-ab-runbook.md`, adapted to full-auto: fresh sessions driven headless via `claude -p "/mega-sdd:detect-drift"` (4 runs: 2 fork-stripped "baseline", 2 fork-intact "fork"), telemetry markers written via the **canonical hook scripts invoked manually with real transcript stdin** (Stop hooks don't fire in `-p`), captures guarded by `measure-fork-ab.sh`.

## Wall 1 (platform): `context: fork` silently NO-OPS in headless `-p` mode

Structural proof: both fork-intact runs show the skill executing **inline in the main context** — 0 `isSidechain` records, 0 Task spawns, no `<session>/subagents/` dir. Compare the older interactive session `bbfeea27-…` which has real `subagents/agent-*.jsonl`. **The fork pilot's token win does not materialize in scripted/CI/`-p` usage** — the skill still works (detect-drift is non-interactive by design), it just runs inline. The driver's `subagent_turns==0` guard caught this exactly as designed (a phantom fork capture was refused).

Implication for the capability notes: the fork A/B **requires interactive sessions** — the runbook's "BUKA SESSION CLAUDE CODE BARU" was load-bearing, not convenience. No flag known to enable forked skills under `-p` (Claude Code 2.1.215).

### The complete `-p` hook matrix (probed, 2026-07-20)

| Surface | Under `claude -p`? | Evidence |
|---|---|---|
| **PreToolUse gates (THE MOAT)** | ✅ **FIRES** | live probe: a `>`-redirect onto `.validation-blockers.json` in a scratch playground was **BLOCKED** by the anti-self-bypass guard with the full keterangan |
| SessionStart | ✅ fires | hook-debug.log: 4/4 headless runs logged `session-start` |
| Stop / SubagentStop | ❌ does NOT fire | hook-debug.log: zero natural `stop` entries across 4 runs (the one entry is the manual canonical invocation) |
| `context: fork` | ❌ NO-OP (runs inline) | 0 sidechains, no `subagents/` dir in either fork-intact run |

**Net: headless `-p` is GATE-SAFE but MEASUREMENT-DARK and FORK-LESS.** The moat holds in scripted/CI usage; what degrades is telemetry (no turn/subagent markers → `report-token-cost.sh` sees no turns) and the fork pilot's token win. Safe to script *gated* skills headless; never *measure* headless, and never expect a fork.

## Wall 2 (scenario): a legitimate `constitution_drift_detected` halt now sits in front of the full scan

The fork arm's forensics (attempt B#2) settled what arm A#1 mis-diagnosed: `binding.md`'s `constitution_hash becd9c3c…` = hash of **constitution v1.0** (verified: `bound/constitution.md` minus BIND annotations reproduces it exactly), while the live `constitution.md` is **v1.1** (`d22feac6…`) — §F-002 changed substantively (source-of-fund "CA/SA PROVISIONAL" → **Savings-only**, per resolved OQ-FL-6). The 2026-06-25 21:48 `refresh_mode: incremental` re-bind carried the stale hash forward. So the halt is REAL: the binding validated claims against superseded constitution text; C-CN-\* verdicts + §F-002 Hard Rules were never re-bound under v1.1. **A full-scan A/B on this vault is only comparable after `/mega-sdd:sync` (or `bind-codebase`) refreshes the binding** — which also consumes the old drift scenario, so the post-sync A/B measures a fresh one.

## Finding 3 (doctrine, the accidental gem): prose-halt bulldoze rate ≈ 1 in 4

The constitution gate is a **prose gate** (skill-body rule, no hook). Across 4 fresh sterile headless runs of the same scenario: **3 honored the halt, 1 bulldozed it** (A#1 — did the full 25-finding scan over the stale binding, recording 3 × `halt_self_resolved` telemetry events, and mis-diagnosed the hash mismatch as "mis-derived at bind"). This is a rare *measured* confirmation of the enforcement doctrine: **"prose that says HALT enforces nothing" — empirically, ~25% of runs pushed through.** (n=4, same model/config, fresh sessions; small sample, directionally strong.)

Corollary recorded for a future hardening pass: the constitution-hash check is deterministic (two sha256s compared) — it is *hookable* if field data shows bulldozing matters. Advisory-first per doctrine; not shipped now.

## What was measured (raw, non-comparable — kept for reference only)

| run | arm | behavior | cost_weighted | note |
|---|---|---|---|---|
| A#1 | fork-stripped | **bulldozed** halt → full scan (25 findings) | 27,689 (cache_read 176,621 = 63.8%) | captured then **discarded** — non-canonical run cannot be a baseline |
| B#1 | fork-intact (no-op) | honored halt | — | inline despite fork (Wall 1) |
| B#2 | fork-intact (no-op) | honored halt + git forensics (v1.0-vs-v1.1 proof) | — | inline despite fork |
| A#2 | fork-stripped | honored halt | — | confirms halt is modal |

All four runs' full outputs live in the session transcripts under `~/.claude/projects/-Users-farhanriuzaki-Development-KANTOR-02-Projects-MSmile-Pegadaian/` (`31db8c4e`, `2ce09b33`, `0391b1cc`, `90bfb842`).

## State restoration (verified)

Cache 5.1.1 `detect-drift/SKILL.md`: `context: fork` **restored**. Drift artifacts (`DRIFT-REPORT.md`, `00-index.md`, `drift-history.md`): byte-identical to pre-A/B; `PENDING-SYNC.md` absent as before. Telemetry: original 157,888-byte history restored. `.fork-ab/`: tainted baseline capture cleared via `measure-fork-ab.sh reset`.

## The remaining path to a valid A/B (user, ~15 menit interaktif)

1. **Di MSmile:** buka session, jalankan `/mega-sdd:sync` — membetulkan constitution binding (v1.1) + codebase-map stale sekaligus. (Ini perlu dilakukan APAPUN nasib A/B — binding stale adalah temuan nyata.)
2. **Arm fork:** session BARU → `/mega-sdd:detect-drift` sampai selesai → di dev repo: `bash plugins/mega-sdd/scripts/measure-fork-ab.sh capture fork --cwd=<PROJ>` (telemetry di-reset dulu per runbook).
3. **Arm baseline:** strip fork di cache (runbook §ARM A, path cache = versi **terbaru** di `~/.claude/plugins/cache/mega-sdd/mega-sdd/`), session BARU → run → `capture baseline` → restore fork → `compare`.

Interactive sessions fire the hooks natively — no manual marker work needed. The runbook file has been updated with the cache-version note and the sync precondition.

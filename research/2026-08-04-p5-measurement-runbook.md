# P5 — measurement runbook (A7 protocol) + baseline arm results

**Date:** 2026-08-04
**Status:** COMPLETE — both arms measured; published in the repo README §"Measured: classic vs express spine" (2026-08-10). Convention AMENDMENT (2026-08-10, applied to BOTH arms identically): the extractor gained an idle rule — any inter-record gap > 10 min counts as wait regardless of the next record's type (the machine cannot work without appending records; the first cut missed a ~21h overnight gap whose next record was a resume record, and an ASK-open interval is never double-billed as USER/IDLE). Classic ep2 net moved 3h30m21s → 3h09m53s under the amended rule; classic ep1 unchanged.
**Protocol source:** spec `2026-08-03-v6-express-spine-design.md` §P5 + amendment A7 (`2026-08-03-v6-express-spine-best-practices.md`): endpoint = acceptance-VERIFIED bolt (never first diff); human-wait explicitly in or out of the clock; speed paired with a quality counterweight; same repo, comparable task class; **never self-reported** (METR RCT: devs 19% slower while believing +20% faster — perception is inadmissible; every number below comes from transcript timestamps, transcript `usage` fields, and git commit timestamps — deterministic channels the model cannot narrate into existence).

## Arms

| | Arm A — classic (BEFORE) | Arm B — express (AFTER) |
|---|---|---|
| Plugin | v5.9.0-era classic spine | v6.0.1 express spine (default) |
| Repo state | training-nextjs @ `c6821ad` ("PRD", 2026-07-29) — plain Next.js app + `PRD/prd-simkredit.md` | SAME commit, fresh clone (`p5-express-arm/`) |
| Task | PRD → units → bolts (SimKredit monorepo conversion + build-out) | same PRD, same start state |
| Model | claude-opus-5 (697/697 API calls — measured) | MUST run on Opus 5 (`/model opus`) — model parity is the largest controllable confound |
| Session | `14ace6bc` (2026-07-30, already run) | fresh interactive session in the clone |

## Clock + channel definitions (identical for both arms — pinned)

- **Start:** first record timestamp of the session (the session begins with the run request; PRD already on disk in both arms).
- **Primary endpoint:** timestamp of the **first `type(U-XXX):` commit** (execute-bolts commits only after the unit's acceptance test passes, so the first unit commit is the first acceptance-backed delivery; Arm A's per-bolt reports were destroyed by the 2026-08-03 vault regeneration, so the commit timestamp is the surviving objective marker — disclosed). Secondary endpoint: last unit commit of the run.
- **Human-wait (reported separately, subtracted for the net number):** (a) AskUserQuestion open → tool_result gap; (b) any gap > 30 s between an assistant record and the next human text input. The 30 s threshold is disclosed; below it is treated as conversational flow.
- **Token cost:** sum of transcript `usage` fields over the session's main lane, cost-weighted with the `report-token-cost.sh` Opus ratios (input ×1, cache_creation ×1.25 @5m / ×2.0 @1h, cache_read ×0.1, output ×5). Main-transcript channel only (sidechain records = 0 in Arm A); subagent lanes billed outside this channel are excluded from BOTH arms — internally consistent A/B, not an absolute bill.
- **Extraction:** `research/2026-08-04-p5-extract.py <transcript.jsonl> <first-unit-commit-iso> [last-unit-commit-iso]` — the same script must produce both arms' rows.

## Quality counterweight (A7 — a speed number without this is meaningless)

1. Acceptance test passing at the endpoint (already required by the commit contract).
2. `/mega-sdd:analyze` full-gate result at end of run (Arm B; Arm A's equivalent evidence: the run's gates were live throughout).
3. Rework: count of revert/fix commits touching the run's files within the run window (Arm A: 0 reverts; the `chore(U-XXX): sync pnpm-lock` pairs are contract-mandated sync commits, not rework).

## Arm A — BASELINE (measured 2026-08-04 from session `14ace6bc` + git)

| Metric | → first U-001 commit (`96890d0`, 10:00:29Z) | → all 7 bolts (`3cec603`, 12:13:53Z) |
|---|---|---|
| Gross wall-clock | **3h 09m 49s** | 5h 23m 13s |
| Human-wait | 76.5 min (31 events: 13 ASKs + idle gaps) | 112.9 min (33 events) |
| **Net machine time** | **1h 53m 17s** | 3h 30m 21s |
| Raw tokens | 188.0M | 219.0M |
| **Cost-weighted tokens** | **28.2M** | 32.5M |

Reproduce: `python3 research/2026-08-04-p5-extract.py <14ace6bc transcript> 2026-07-30T10:00:29+00:00 2026-07-30T12:13:53+00:00`

Phase timeline (UTC): scan 06:53 → generate-intent 07:22 → resolve-oq 07:56–08:44 (13 interactive ASKs — the express spine's batched-P0 + auto-defer targets exactly this band) → bind 08:47 → CONFLICT resolution 08:55 → generate-units 09:17 → first bolt commit 10:00.

**Known Arm A caveats (disclosed):** one `/compact` at 09:07 (context re-establishment cost included in the clock — it is part of the classic spine's real cost); the 23.6 min and 12.7 min idle gaps during the autonomous bolt band are counted as human-wait (machine was idle awaiting "continue").

## Arm B — express run procedure (the user runs this; the model never self-reports)

1. Update the plugin to **6.0.1** (`/plugin marketplace update mega-sdd`, restart).
2. Open a FRESH Claude Code session in the prepared clone `Project/TRAINING/p5-express-arm/` (repo reset to `c6821ad`, `npm install` already done OUTSIDE the clock — Arm A also started with deps installed).
3. `/model opus` (model parity with Arm A).
4. Start the run with a plain request to build from `PRD/prd-simkredit.md` (e.g. "jalankan mega-sdd dari PRD/prd-simkredit.md sampai bolt pertama"). Answer OQs as they come — answer time is measured as human-wait, so answer at natural pace.
5. Stop condition: at minimum the FIRST unit commit (primary endpoint); continuing to all bolts gives the secondary number.
6. Afterwards: run `/mega-sdd:analyze` (counterweight), then hand the session back for extraction — the transcript filename + `git log --format="%h %cI %s"` are the only inputs needed.

## Arm B — EXPRESS (measured 2026-08-10 from sessions `23cdaf7b` + `15315fdd` + git; run 2026-08-04 → 2026-08-06, plugin 6.0.1, claude-opus-5 100% both sessions)

Two sequential sessions (gap 59s, counted as wait). Session A active span 4h38m03s, wait 218.3 min → net 59m46s; session B to each endpoint per the extractor. Combined:

| Metric | → first `feat(U-001)` commit (`7e6f49b`, 2026-08-05T04:11:38Z) | → all 10 units (`f60ca04`, 2026-08-06T09:25:19Z) |
|---|---|---|
| Gross wall-clock | 20h 50m (2 overnights) | 50h 04m |
| Human-wait + idle | 19h 05m | 42h 16m |
| **Net machine time** | **1h 44m 52s** | 7h 47m 55s |
| Raw tokens | 99.8M | 251.1M |
| **Cost-weighted tokens** | **18.6M** | 39.7M |
| Rework | 0 fix commits in window | 8 `fix(U-*)` commits (incl. 1 panel-caught Critical: fail-open DTI) |

**Comparability ruling (A7):** the PRIMARY endpoint is task-class comparable (scaffolding-class first unit on the same repo/commit/PRD/model) — express: net −7%, cost-weighted −34%. The FULL-RUN figures are NOT task-class comparable (7 chore units vs 10 feature units incl. an engine with 23→55 tests) and are published with that statement, never normalized into a per-unit claim. The express run predates v6.1.0 — its measured attempt-loop churn (3 attempts on U-001/U-002, full re-panels, 8 fix rounds) is exactly what v6.1.0 redesigned; the 6.1.0 effect is to be measured by this same procedure on a post-6.1.0 run.

**Verdict on the target:** "<10 minutes PRD → first bolt" **FAILED** (floor ≈ 1h45m net with all gates live). Published as such in the README.

## Publication

After Arm B: before/after lands in the repo README (speed + cost-weighted tokens + counterweight, with the human-wait convention stated), and the spec §P5 gets stamped. The <10-minute claim is judged against **net machine time to first acceptance-backed commit**; if the claim fails, the README publishes the real number — the protocol exists to find the truth, not to defend the target.

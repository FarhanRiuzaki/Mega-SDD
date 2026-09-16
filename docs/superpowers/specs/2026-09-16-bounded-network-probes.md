# Bounded network probes in bolts — design spec (8.2.1)

**Status:** built same day (leftover (3) of `research/2026-09-15-v8-p3-report.md §3` lanjutan 13). Field patches require a spec — this is it.
**Field evidence (MEASURED):** run `xs-lite-8.0.0-commentdiet` (F.4, sid `879dde0b`): implementer U-004 ran

```
curl -s -o /tmp/u004-kontak.html -w 'HTTP %{http_code}\n' --retry 40 --retry-delay 3 --retry-connrefused --max-time 120 http://localhost:3457/kontak
```

against a dev server that was never started — worst case 40 × 120 s ≈ 80 min; the bolt stalled 12:08→13:20Z (72 min) and the wall of that run became NOT DATA. The unit's own `acceptance_test` entries were `pnpm test:run …` + a `type: manual` desc; the probe was the implementer's ad-hoc attempt to "verify" the manual entry. `run-acceptance-tests.sh` already bounds every acceptance command (default 120 s, one bounded retry) — the gap is the implementer's OWN Bash calls, which nothing bounded.

## Decision (gates > rules > hooks)

- **Rule (agent-carried):** `bolt-implementer.md` Workflow step 5 — every network/HTTP probe the implementer runs itself is bounded: `--max-time ≤ 60` and `--retry ≤ 3` (wget `--tries ≤ 3`); a server that is not running is a `NEEDS_CONTEXT` report naming the command/port, never a wait loop; a `type: manual` acceptance entry is recorded as pending, never "verified" by polling.
- **Hook (mechanical, same tier and shape as the wave commit rail F-16):** the PreToolUse parse interpreter classifies a Bash command as a **probe hazard** when any `;`/`&&`/`||`/newline segment carries `curl … --retry N` with N ≥ 4 (or `wget … --tries N` / `-t N` with N ≥ 4), after blanking quoted strings and cutting heredoc bodies (a commit message saying "--retry 40" never trips it). Zero extra spawn on innocent commands (`PROBE_HAZARD` is emitted by the interpreter that already runs). A hazardous shape pays ONE python to read the in-flight set — the same `vault_layouts.inflight_units` the wave rail reads, computed once for both rails — and is **denied only while a bolt is in flight**; plugin-dev trees are exempt like every other guard. The deny names the in-flight units and the remediation (`--retry ≤ 3 --max-time ≤ 60`, or report `NEEDS_CONTEXT`), with keterangan in Indonesian.
- **Not a gate on unit specs:** the acceptance runner is already bounded; no new `validate-unit-spec.sh` issue (no evidence a unit ever carried an unbounded command — grep of every P3 vault snapshot: 0 hits for `--retry`).

## Pins

`tests/wave-rail/test-bounded-probe-rail.sh`: `--retry 40` / `--retry 4` / `--retry-connrefused --retry 10` / `wget --tries 20` DENIED naming U-007 while in flight; `--retry 3`, `--max-time 30` without retry, a commit message containing "--retry 40", `curl` with no retry, non-curl commands PASS; rail off once postflight lands and in plugin-dev mode; both rails read the one in-flight helper. `tests/comment-diet`-style grep pin on the implementer rule.

## Deliberately not done

A `while … sleep` poll classifier (no field evidence; a bounded loop is legitimate); a global (non-in-flight) deny — the user's own shell and non-bolt sessions are not the adversary; caps on `--retry-delay` (irrelevant once `--retry ≤ 3`).

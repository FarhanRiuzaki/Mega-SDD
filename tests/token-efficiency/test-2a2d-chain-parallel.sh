#!/usr/bin/env bash
# test-2a2d-chain-parallel.sh — tranches 2a + 2d (spec 2026-07-30 §2a/§2d).
# PROSE-CONTRACT PINS (the surfaces are routing/handoff prose — the same tier
# as the behavior they drive):
#   2a  the --agents dispatch path runs --all as waves (the chain proposes the
#       default --all --lite, §8.5 below); the wave plan channel is the in-context
#       analyze-parallelism JSON; the overlap rail + failure-halt semantics
#       stay with the dispatcher (batch-and-fanout).
#   2d  extract-intelligence --max-parallel default is 5 everywhere it is
#       stated; the superseded "empirical optimum is 3" claim is gone; the
#       soft-warn >5 + hard cap 8 rails are intact.
#
# 9.0 §8.5 (2026-09-28): execute-bolts runs inline by default (one context, plan order), so the
# engine's units_pending_bolts proposal is `execute-bolts --all --lite` too; `--parallel` and
# `--per-squad` shape only the `--agents` dispatch path, whose `--all` is wave-parallel by default.
# The 2a rails below (waves, overlap, in-flight cap) are that path's and stay pinned.
#
# 9.0 (spec 2026-09-27 §2/§7): generate-units and the classic chain are gone;
# the one pipeline is plan → execute-bolts --all --lite. The plan→bolts hop
# carries `--all --lite`, not `--parallel`: wave execution is the DEFAULT on
# `--all` (pinned below from batch-and-fanout), so `--all` alone is the
# wave-parallel form and `--parallel` stays on the units_pending_bolts rows the
# engine proposes. The generate-units pins (its handoff suggested_args, its
# standalone suggestion) moved to the surviving units producer `plan` and to the
# orchestrator's lite-lane exemption (plan emits no handoff YAML by contract).
# The default-lane "Wave boundary = review boundary" barrier is retired — the
# lite-only execute-bolts replaced it with unit-level readiness; that rail is
# pinned in its place.
#
# Run: bash tests/token-efficiency/test-2a2d-chain-parallel.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RR="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md"
CE="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
HN="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md"
OF="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md"
PL="${ROOT}/plugins/mega-sdd/skills/plan/SKILL.md"
BF="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md"
EB="${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
EX="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
XC="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
PC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md"
TT="${ROOT}/tests/skill-triggering/orchestrate-flow.test.md"
for f in "$RR" "$CE" "$HC" "$HN" "$OF" "$PL" "$BF" "$EB" "$EX" "$XC" "$PC" "$TT"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 2a: every chain routing surface proposes the default --all --lite; --parallel/--per-squad only with --agents =="
n=$(grep -c -- 'execute-bolts --all --parallel' "$RR")
[ "$n" -eq 0 ] && ok "routing-rules proposes no --all --parallel (the default run is inline, one context)" || fail "routing-rules still proposes --all --parallel on $n rows"
[ "$(grep -cE '^\| (`units_pending_bolts`|Units exist, some not in bolts) .*`execute-bolts --all --lite`' "$RR")" -ge 3 ] \
  && ok "routing-rules: the state row, the decision matrix and the 1-phase chain propose execute-bolts --all --lite" || fail "routing-rules units-pending rows do not propose --all --lite"
grep -q -- 'already parallel by procedure' "$RR" && grep -F 'already parallel by procedure' "$RR" | grep -qF -- '`--agents`' \
  && ok "the --per-squad leg is documented as --agents only, parallel by procedure (no flag needed)" || fail "per-squad --agents note missing"
# 9.0: the classic example row ('execute-bolts --all --parallel → bolts/') left
# with the classic chain; the one pipeline's example is the wave-default --all
# batch and must not opt out of waves.
EXL=$(grep -E -- '^ +2\. execute-bolts --all --lite +→ bolts/' "$OF")
[ -n "$EXL" ] && ! printf '%s\n' "$EXL" | grep -q -- '--sequential' \
  && ok "orchestrate-flow pipeline example dispatches the wave-default --all batch (execute-bolts --all --lite → bolts/, no --sequential)" \
  || fail "SKILL.md pipeline example lost the --all batch hop (or opts out of waves)"
# 9.0: the units producer row is `plan` (generate-units deleted).
grep -E -- '^\| `plan` \|' "$HC" | grep -qF -- '→ `mega-sdd:execute-bolts --all --lite`' \
  && ok "handoff routing index: the plan producer row dispatches mega-sdd:execute-bolts --all --lite" \
  || fail "handoff-contract plan row does not route to execute-bolts --all --lite"
# 9.0: plan emits no handoff YAML (no suggested_args to pin); the chain's
# bolts-hop args live in the orchestrator's lite-lane exemption instead.
grep -qF -- '(3) dispatch `execute-bolts --all --lite`' "$HN" \
  && ok "handoff-consumption lite-lane exemption dispatches the bolts hop as execute-bolts --all --lite" \
  || fail "handoff-consumption lite exemption lost the execute-bolts --all dispatch step"

note "== 2a: the DETERMINISTIC proposer emits the flag (the engine, not just its docs) =="
SP="${ROOT}/plugins/mega-sdd/scripts/_lib/state_probes.py"
DT="${ROOT}/plugins/mega-sdd/tests/state/test-derive-state.sh"
! grep -qE '"execute-bolts (--all --parallel|--per-squad)"' "$SP" && grep -qF '"execute-bolts --all --lite"' "$SP" \
  && ok "state_probes.py units_pending_bolts proposes --all --lite (routing-rules row units_pending_bolts documents THIS script's output)" || fail "state_probes.py still proposes an --agents-only dispatch flag"
grep -qF "execute-bolts --all --lite']\" ] && ok \"f6l3" "$DT" && ok "derive-state fixture f6l3 pins the default proposal" || fail "test-derive-state.sh f6l3 still pins --parallel"

note "== 2a: the wave-plan channel is named, not asserted =="
grep -qF -- '--format=json' "$CE" && ok "chain auto-run names the JSON form" || fail "chain-execution row does not name --format=json"
grep -qF -- '`waves` array' "$CE" && ok "chain-execution names the waves array as the layering (anchored phrase, not a loose keyword)" || fail "waves channel unnamed in the diagnostics row"
if grep -qF 'passed to execute-bolts to drive `--parallel` batch dispatch' "$CE"; then fail "the old unspecified 'passed to execute-bolts' claim survives"; else ok "the old unspecified 'passed' claim is gone (channel now explicit)"; fi
grep -q 'Wave plan consumption' "$BF" && ok "batch-and-fanout: wave-plan consumption is part of the --all procedure" || fail "wave-plan consumption missing from batch-and-fanout"
grep -qF 'overlap rail above is applied HERE regardless' "$BF" && ok "overlap rail applied by the dispatcher, never carried by the plan" || fail "overlap-rail-stays-here rail missing"
grep -q 'STALE — discard it and re-derive' "$BF" && ok "a plan disagreeing with units/ is discarded, never dispatched from" || fail "stale-plan discard rail missing"

note "== 2a: same-tree wave concurrency is SPECIFIED, not hand-waved (review-round rails) =="
grep -qF 'bounded by an in-flight cap (`config.yaml parallel_max:`, default **4**' "$BF" && ok "--all wave dispatch carries a concrete in-flight cap (parallel_max, default 4 — v8 P3 re-pin: the old 'default 5' was doc drift vs SKILL.md/project-config.md)" || fail "in-flight cap missing from --all"
grep -qF 'default **4** concurrent' "${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md" && ok "--per-squad cap made concrete (same bound, both procedures)" || fail "squad-subagent cap still 'sensible' (no number)"
grep -qF -- '--base=<its-commit>^ --head=<its-commit>' "$BF" && ok "per-unit gate range under a wave = the unit's OWN commit (identity-anchored, never wave-base..wave-head)" || fail "per-unit gate range rule missing"
grep -qF 'dispatch only units not yet completed' "$BF" && ok "consumed waves skip completed units (resume-safe)" || fail "completed-skip rule missing from wave consumption"
grep -qF 'index.lock' "${ROOT}/plugins/mega-sdd/agents/bolt-implementer.md" && ok "implementer contract: transient index.lock is retried, never BLOCKED" || fail "index.lock retry contract missing from the implementer body"
grep -qF 'run the batch with `--worktree`' "$BF" && ok "shared-test-state valve named (--worktree or drop the flag) — never a silent hazard" || fail "test-state valve missing"
AP="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md"
grep -qF 'never suggest the halting form' "$AP" && ok "analyze-parallelism suggestion is squad-count-conditional (--per-squad halts on single-squad)" || fail "analyze-parallelism still suggests the halting --per-squad form unconditionally"

note "== 2a: failure semantics at the wave boundary =="
# 9.0: 'Wave boundary = review boundary' (the default-lane barrier) is retired —
# execute-bolts runs the lite lane only, where unit-level readiness replaces the
# barrier. The rail that survives at that boundary: a dependent dispatches only
# on its upstream's written green evidence, never on missing/red evidence.
grep -qF 'Unit-level readiness replaces the wave barrier' "$BF" \
  && grep -qF 'never pipeline against missing/red evidence' "$BF" \
  && ok "dependents wait for upstream acceptance+postflight evidence (never pipelined against missing/red evidence)" \
  || fail "unit-level readiness rail (the barrier's replacement) missing"
grep -qF 'complete the detect-after pipeline for every unit already dispatched in that wave' "$BF" && ok "in-flight units complete their verdict trail on failure (commits already landed)" || fail "in-flight completion semantics missing"
grep -qF 'remediation of started work, not new work' "$BF" && ok "a sibling's fix re-dispatch is remediation within its cap, unambiguous" || fail "sibling re-dispatch ambiguity unresolved"
grep -qF 'dispatch no further unit and no further wave' "$BF" && ok "no skip-ahead preserved: never START new work past a failure" || fail "no-further-wave rule missing"
grep -qF 'On any failure: halt the entire `--all` run (no skip-ahead)' "$BF" && ok "the original halt-entire-run sentence intact" || fail "original halt sentence lost"

note "== 2a: --all defaults to waves (v7.7); standalone non---all default stays off =="
grep -qF 'the flag DEFAULT stays off for standalone non-`--all` invocations' "$EB" && ok "execute-bolts SKILL: chain passes the flag; standalone non---all default unchanged" || fail "standalone-default line missing"
# v7.7 (spec 2026-08-29 Fase 2): --all now defaults to SPRINT/wave execution and
# --sequential is the explicit opt-out. The old pin asserted the inverse sentence
# ('Execute in order (default sequential)'); it is updated, not dropped — the
# contract still has to be stated somewhere deterministic.
grep -qF 'wave execution is the DEFAULT' "$BF" && ok "batch-and-fanout: --all wave-default sentence present" || fail "wave-default sentence lost"
grep -qF -- '--sequential' "$BF" && ok "batch-and-fanout: --sequential opt-out documented" || fail "--sequential opt-out missing"
# 9.0: generate-units (and its standalone 'Suggested next') is deleted; the
# surviving units producer is plan, whose standalone NEXT hands to the front
# door, which dispatches the plain wave-default --all form (no --parallel flag).
grep -qF '`NEXT: /mega-sdd --resume` (the front door dispatches `execute-bolts --all --lite`)' "$PL" \
  && ok "plan standalone NEXT hands off to the front door's plain execute-bolts --all --lite" || fail "plan standalone NEXT suggestion drifted"

note "== 2a: trigger fixtures updated with the routing =="
! grep -q -- 'execute-bolts --all --parallel' "$TT" && grep -q -- 'Propose `execute-bolts --all --lite`' "$TT" && ok "orchestrate-flow trigger fixtures expect --all --lite" || fail "trigger fixtures not updated"

note "== 2d: --max-parallel default is 5, supersession clean =="
grep -qF 'default 5' "$EX" && ok "extract SKILL.md states default 5" || fail "SKILL.md default not 5"
grep -qF 'soft warn at >5; hard cap 8' "$XC" && ok "the skill (the surviving home post-6.0.0-cull) states default 5 with both rails" || fail "max-parallel rails lost their home"
if grep -q 'empirical optimum is 3' "$PC"; then fail "predictive-checks still claims optimum 3"; else ok "superseded optimum-3 claim removed from predictive-checks"; fi
if grep -qF '(the default).0+' "$PC"; then fail "garbled '.0+ per audit' fragment survives"; else ok "garbled on_fail fragment cleaned"; fi
grep -qF 'max-parallel ≤ 5' "$PC" && ok "soft-warn threshold 5 intact" || fail "soft-warn threshold drifted"
grep -qF -- '`--max-parallel` > 8 → halt' "$EX" && ok "hard cap 8 halt intact" || fail "hard cap halt lost"
# Sweep the RUNTIME-LOADED surfaces (skills/ + commands/ + top-level references/).
# The dated audit RECORD (now archived at
# docs/superpowers/audits/2026-06-05-audit-md-rounds-1-3-ARCHIVED.md) is point-in-time
# by design, never retro-edited when behavior changes (specs get amendments; records stand).
if grep -rn 'max-parallel' "${ROOT}/plugins/mega-sdd/skills" "${ROOT}/plugins/mega-sdd/commands" "${ROOT}/plugins/mega-sdd/references" --include='*.md' 2>/dev/null | grep -q 'default 3'; then
  fail "a 'default 3' max-parallel mention survives on a runtime surface"
else
  ok "no 'default 3' max-parallel mention left on any runtime surface (skills/commands/references)"
fi

note "== SPEC: designs recorded =="
SPEC="${ROOT}/docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md"
grep -qF 'DESIGN 2026-08-01 (tranche 2a/2c/2d)' "$SPEC" && ok "spec carries the tranche designs" || fail "spec designs missing"

if [ "$FAILED" -eq 0 ]; then note "ALL 2A/2D CHAIN-PARALLEL PINS OK"; else note "2a/2d pins FAILED"; fi
exit $FAILED

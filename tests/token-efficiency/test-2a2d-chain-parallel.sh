#!/usr/bin/env bash
# test-2a2d-chain-parallel.sh — tranches 2a + 2d (spec 2026-07-30 §2a/§2d).
# PROSE-CONTRACT PINS (the surfaces are routing/handoff prose — the same tier
# as the behavior they drive):
#   2a  the orchestrated chain dispatches execute-bolts --all --parallel on
#       every routing surface; the wave plan channel is the in-context
#       analyze-parallelism JSON; the overlap rail + failure-halt semantics
#       stay with the dispatcher (batch-and-fanout).
#   2d  extract-intelligence --max-parallel default is 5 everywhere it is
#       stated; the superseded "empirical optimum is 3" claim is gone; the
#       soft-warn >5 + hard cap 8 rails are intact.
#
# Run: bash tests/token-efficiency/test-2a2d-chain-parallel.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RR="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md"
CE="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
OF="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md"
AM="${ROOT}/plugins/mega-sdd/skills/generate-units/references/auto-and-memory.md"
BF="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md"
EB="${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
EX="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
XC="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
PC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md"
TT="${ROOT}/tests/skill-triggering/orchestrate-flow.test.md"
for f in "$RR" "$CE" "$HC" "$OF" "$AM" "$BF" "$EB" "$EX" "$XC" "$PC" "$TT"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 2a: every chain routing surface dispatches --all --parallel =="
n=$(grep -c -- 'execute-bolts --all --parallel' "$RR")
[ "$n" -ge 3 ] && ok "routing-rules carries --all --parallel on $n rows (state row + decision matrix + 1-phase chain)" || fail "routing-rules rows missing --parallel (found $n, want >=3)"
grep -q -- 'already parallel by procedure' "$RR" && ok "the --per-squad leg is documented as parallel by procedure (no flag needed)" || fail "per-squad parallel note missing"
grep -q -- 'execute-bolts --all --parallel → bolts/' "$OF" && ok "orchestrate-flow pipeline example carries --parallel" || fail "SKILL.md example missing --parallel"
grep -qF -- 'mega-sdd:execute-bolts --all --parallel --auto' "$HC" && ok "handoff routing index dispatches --all --parallel --auto" || fail "handoff-contract row missing --parallel"
grep -qF -- '"--all", "--parallel", "--auto"' "$AM" && ok "generate-units emission suggested_args carries --parallel" || fail "auto-and-memory suggested_args missing --parallel"

note "== 2a: the DETERMINISTIC proposer emits the flag (the engine, not just its docs) =="
SP="${ROOT}/plugins/mega-sdd/scripts/_lib/state_probes.py"
DT="${ROOT}/plugins/mega-sdd/tests/state/test-derive-state.sh"
grep -qF 'execute-bolts --all --parallel' "$SP" && ok "state_probes.py units_pending_bolts proposes --all --parallel (routing-rules row :56 documents THIS script's output)" || fail "state_probes.py still proposes sequential --all — the front-door path dispatches sequential while the docs claim parallel"
grep -qF "execute-bolts --all --parallel']" "$DT" && ok "derive-state fixture f6 pins the parallel proposal" || fail "test-derive-state.sh f6 still pins the sequential form"

note "== 2a: the wave-plan channel is named, not asserted =="
grep -qF -- '--format=json' "$CE" && ok "chain auto-run names the JSON form" || fail "chain-execution row does not name --format=json"
grep -qF -- '`waves` array' "$CE" && ok "chain-execution names the waves array as the layering (anchored phrase, not a loose keyword)" || fail "waves channel unnamed in the diagnostics row"
if grep -qF 'passed to execute-bolts to drive `--parallel` batch dispatch' "$CE"; then fail "the old unspecified 'passed to execute-bolts' claim survives"; else ok "the old unspecified 'passed' claim is gone (channel now explicit)"; fi
grep -q 'Wave plan consumption' "$BF" && ok "batch-and-fanout: wave-plan consumption is part of the --all procedure" || fail "wave-plan consumption missing from batch-and-fanout"
grep -qF 'overlap rail above is applied HERE regardless' "$BF" && ok "overlap rail applied by the dispatcher, never carried by the plan" || fail "overlap-rail-stays-here rail missing"
grep -q 'STALE — discard it and re-derive' "$BF" && ok "a plan disagreeing with units/ is discarded, never dispatched from" || fail "stale-plan discard rail missing"

note "== 2a: same-tree wave concurrency is SPECIFIED, not hand-waved (review-round rails) =="
grep -qF 'bounded by an in-flight cap (default **5**' "$BF" && ok "--all wave dispatch carries a concrete in-flight cap (default 5)" || fail "in-flight cap missing from --all"
grep -qF 'default **5** concurrent' "${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md" && ok "--per-squad cap made concrete (same bound, both procedures)" || fail "squad-subagent cap still 'sensible' (no number)"
grep -qF -- '--base=<its-commit>^ --head=<its-commit>' "$BF" && ok "per-unit gate range under a wave = the unit's OWN commit (identity-anchored, never wave-base..wave-head)" || fail "per-unit gate range rule missing"
grep -qF 'dispatch only units not yet completed' "$BF" && ok "consumed waves skip completed units (resume-safe)" || fail "completed-skip rule missing from wave consumption"
grep -qF 'index.lock' "${ROOT}/plugins/mega-sdd/agents/bolt-implementer.md" && ok "implementer contract: transient index.lock is retried, never BLOCKED" || fail "index.lock retry contract missing from the implementer body"
grep -qF 'run the batch with `--worktree`' "$BF" && ok "shared-test-state valve named (--worktree or drop the flag) — never a silent hazard" || fail "test-state valve missing"
AP="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md"
grep -qF 'never suggest the halting form' "$AP" && ok "analyze-parallelism suggestion is squad-count-conditional (--per-squad halts on single-squad)" || fail "analyze-parallelism still suggests the halting --per-squad form unconditionally"

note "== 2a: failure semantics at the wave boundary =="
grep -qF 'Wave boundary = review boundary' "$BF" && ok "next wave waits for the current wave's panels (never pipelined against a review tail)" || fail "wave-boundary review rule missing"
grep -qF 'complete the detect-after pipeline for every unit already dispatched in that wave' "$BF" && ok "in-flight units complete their verdict trail on failure (commits already landed)" || fail "in-flight completion semantics missing"
grep -qF 'remediation of started work, not new work' "$BF" && ok "a sibling's fix re-dispatch is remediation within its cap, unambiguous" || fail "sibling re-dispatch ambiguity unresolved"
grep -qF 'dispatch no further unit and no further wave' "$BF" && ok "no skip-ahead preserved: never START new work past a failure" || fail "no-further-wave rule missing"
grep -qF 'On any failure: halt the entire `--all` run (no skip-ahead)' "$BF" && ok "the original halt-entire-run sentence intact" || fail "original halt sentence lost"

note "== 2a: the flag default stays off for standalone runs =="
grep -qF 'the flag DEFAULT stays off for standalone invocations' "$EB" && ok "execute-bolts SKILL: chain passes the flag; standalone default unchanged" || fail "standalone-default line missing"
grep -qF 'Execute in order (default sequential)' "$BF" && ok "batch-and-fanout: sequential default sentence intact" || fail "sequential default sentence lost"
grep -qF 'Suggested next: `execute-bolts --all` to execute in order' "${ROOT}/plugins/mega-sdd/skills/generate-units/SKILL.md" \
  && ok "generate-units standalone suggestion deliberately stays plain --all" || fail "standalone suggestion drifted"

note "== 2a: trigger fixtures updated with the routing =="
grep -q -- 'execute-bolts --all --parallel' "$TT" && ok "orchestrate-flow trigger fixtures expect --parallel" || fail "trigger fixtures not updated"

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

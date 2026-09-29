#!/usr/bin/env bash
# test-2a2d-chain-parallel.sh — tranches 2a + 2d (spec 2026-07-30 §2a/§2d).
# PROSE-CONTRACT PINS (the surfaces are routing/handoff prose — the same tier
# as the behavior they drive):
#   2a  every chain routing surface proposes the default --all --lite; none proposes
#       a fan-out flag (retired P3b: the run is inline, one context, plan order).
#       The analyze-parallelism JSON is named as the chain's DAG facts and the
#       `execute-bolts --sprint=<n>` numbering, never as a dispatch plan.
#   2d  extract-intelligence --max-parallel default is 5 everywhere it is
#       stated; the superseded "empirical optimum is 3" claim is gone; the
#       soft-warn >5 + hard cap 8 rails are intact.
#
# 9.0 (spec 2026-09-27 §2/§7): generate-units and the classic chain are gone;
# the one pipeline is plan → execute-bolts --all --lite. The generate-units pins
# (its handoff suggested_args, its standalone suggestion) moved to the surviving
# units producer `plan` and to the orchestrator's lite-lane exemption (plan
# emits no handoff YAML by contract).
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
EX="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
XC="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
PC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md"
TT="${ROOT}/tests/skill-triggering/orchestrate-flow.test.md"
for f in "$RR" "$CE" "$HC" "$HN" "$OF" "$PL" "$EX" "$XC" "$PC" "$TT"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 2a: every chain routing surface proposes the default --all --lite; none proposes --parallel/--per-squad =="
n=$(grep -c -- 'execute-bolts --all --parallel' "$RR")
[ "$n" -eq 0 ] && ok "routing-rules proposes no --all --parallel (the default run is inline, one context)" || fail "routing-rules still proposes --all --parallel on $n rows"
[ "$(grep -cE '^\| (`units_pending_bolts`|Units exist, some not in bolts) .*`execute-bolts --all --lite`' "$RR")" -ge 3 ] \
  && ok "routing-rules: the state row, the decision matrix and the 1-phase chain propose execute-bolts --all --lite" || fail "routing-rules units-pending rows do not propose --all --lite"
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
  && ok "state_probes.py units_pending_bolts proposes --all --lite (routing-rules row units_pending_bolts documents THIS script's output)" || fail "state_probes.py still proposes a retired fan-out dispatch flag"
grep -qF "execute-bolts --all --lite']\" ] && ok \"f6l3" "$DT" && ok "derive-state fixture f6l3 pins the default proposal" || fail "test-derive-state.sh f6l3 still pins --parallel"

note "== 2a: the wave-plan channel is named, not asserted =="
grep -qF -- '--format=json' "$CE" && ok "chain auto-run names the JSON form" || fail "chain-execution row does not name --format=json"
grep -qF -- '`waves` array' "$CE" && ok "chain-execution names the waves array as the layering (anchored phrase, not a loose keyword)" || fail "waves channel unnamed in the diagnostics row"
if grep -qF 'passed to execute-bolts to drive `--parallel` batch dispatch' "$CE"; then fail "the old unspecified 'passed to execute-bolts' claim survives"; else ok "the old unspecified 'passed' claim is gone (channel now explicit)"; fi

AP="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md"
grep -qF 'execute-bolts --sprint=<n>' "$AP" && ! grep -qF -- '--agents' "$AP" && ! grep -qF -- '--per-squad --agents' "$RR" \
  && ok "analyze-parallelism suggests execute-bolts --sprint=<n>; no --agents in diagnostics-procedures or routing-rules" || fail "analyze-parallelism suggestion lost --sprint=<n>, or --agents survives"

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

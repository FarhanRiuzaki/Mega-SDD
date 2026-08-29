#!/usr/bin/env bash
# Contract test for the sprint lane (spec 2026-08-29 Fase 2).
#
# What this pins:
#   a) execute-bolts documents --sequential / --sprint=<n> / --sprint-checkpoint
#   b) wave execution is the DEFAULT on --all, and --sequential is the opt-OUT
#      (the pre-v7.7 shape was "default sequential, --parallel opts in" — a
#      regression to that wording is what this test exists to catch)
#   c) batch-and-fanout carries the --sprint procedure + a sprint_blocked_by
#      YAML with the fields the halt registry advertises
#   d) NO second sprint-plan producer exists — analyze-parallelism.sh is the
#      single producer (a derive-sprint-plan.sh was specced then REJECTED)
#   e) sprint_blocked_by is registered in the canonical registry + its family
#   f) the derived plan is consumed, not hand-numbered
# No git, no network — pure file contract.
set -u
err=0
ok()   { echo "  ok: $*"; }
bad()  { echo "  FAIL: $*"; err=1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
BATCH="$ROOT/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md"
PROTO="$ROOT/plugins/mega-sdd/references/halt-protocol.md"
FAM="$ROOT/plugins/mega-sdd/references/halt-families/bolts.md"
SCRIPTS="$ROOT/plugins/mega-sdd/scripts"
for f in "$SKILL" "$BATCH" "$PROTO" "$FAM"; do
  [ -f "$f" ] || { echo "FATAL: missing $f"; exit 1; }
done

echo "── a: the three flags are documented in the skill's Inputs ──"
for flag in -- '--sequential' '--sprint=<n>' '--sprint-checkpoint'; do
  [ "$flag" = "--" ] && continue
  grep -qF -- "\`$flag\`" "$SKILL" && ok "a: $flag documented" || bad "a: $flag not documented in SKILL.md"
done

echo "── b: wave execution is the DEFAULT on --all (not opt-in) ──"
grep -qiE 'wave execution is the (DEFAULT|default)' "$BATCH" \
  && ok "b1 batch-and-fanout states wave execution is the default" \
  || bad "b1 batch-and-fanout no longer states wave execution is the default"
grep -qiE '\-\-sequential.*opt' "$BATCH" \
  && ok "b2 --sequential is described as the opt-out" \
  || bad "b2 --sequential opt-out wording missing"
# the regression tripwire: the old "Execute in order (default sequential)" step
grep -qiE '^\s*2\.\s*Execute in order \(default sequential\)' "$BATCH" \
  && bad "b3 REGRESSION: batch-and-fanout is back to 'default sequential'" \
  || ok "b3 no 'default sequential' step remains"
# b4 is the BEHAVIOUR tripwire, not a sentence pin: the wave-dispatch step must be
# reachable with NO --parallel flag. The pre-v7.7 form opened it with "On
# `--parallel`:" — a controller reading that runs one unit at a time however many
# times the file says "default" elsewhere. Prose that says DEFAULT enforces nothing.
grep -qE '^\s*3\.\s*On `--parallel`:' "$BATCH" \
  && bad "b4 REGRESSION: the wave step is gated behind --parallel again — the --all default cannot reach it" \
  || ok "b4 wave dispatch step is not gated behind --parallel"
grep -qF 'Wave dispatch (the default on `--all`' "$BATCH" \
  && ok "b5 wave step states it is the --all default at the point of dispatch" \
  || bad "b5 the dispatch step no longer says it is the --all default"

echo "── c: --sprint procedure + sprint_blocked_by payload ──"
grep -qF '## `--sprint=<n>`' "$BATCH" && ok "c1 --sprint section present" || bad "c1 --sprint section missing"
grep -qF 'type: sprint_blocked_by' "$BATCH" && ok "c2 halt YAML present" || bad "c2 halt YAML missing"
for field in requested_sprint incomplete_prerequisites next_action; do
  grep -qF "$field" "$BATCH" && ok "c3 payload carries $field" || bad "c3 payload missing $field"
done
# 1-indexed and never silently clamped — the off-by-one that would skip a sprint
grep -qiE '1-indexed' "$BATCH" && ok "c4 sprint numbering declared 1-indexed" || bad "c4 sprint indexing base not declared"
grep -qiE 'never a silent clamp|usage error' "$BATCH" && ok "c5 out-of-range is an error, not a clamp" || bad "c5 out-of-range behavior unspecified"

echo "── d: exactly ONE sprint-plan producer ──"
if [ -e "$SCRIPTS/derive-sprint-plan.sh" ]; then
  bad "d1 derive-sprint-plan.sh exists — the spec REJECTED a second producer (reuse analyze-parallelism.sh)"
else
  ok "d1 no derive-sprint-plan.sh (single producer preserved)"
fi
[ -f "$SCRIPTS/analyze-parallelism.sh" ] && ok "d2 analyze-parallelism.sh present" || bad "d2 analyze-parallelism.sh missing"
grep -qF 'analyze-parallelism.sh' "$BATCH" \
  && ok "d3 batch-and-fanout names the producer" \
  || bad "d3 batch-and-fanout does not name analyze-parallelism.sh"
grep -qiE '(never|do not|don.t) hand-(deriv|number)' "$BATCH" \
  && ok "d4 hand-derivation explicitly forbidden" \
  || bad "d4 nothing forbids hand-deriving the layering"

echo "── e: sprint_blocked_by registered ──"
grep -qF 'sprint_blocked_by' "$PROTO" && ok "e1 in halt-protocol registry" || bad "e1 absent from halt-protocol"
grep -qF '### sprint_blocked_by' "$FAM" && ok "e2 has a family entry" || bad "e2 no family entry in halt-families/bolts.md"
grep -qF 'ALWAYS STOP' "$FAM" && ok "e3 family file keeps the stop-class floor" || bad "e3 stop class missing"

echo "── f: the derived plan is what gets executed ──"
grep -qiE 'waves\[\]? (array )?IS the sprint sequence|`waves\[\]` array IS' "$BATCH" \
  && ok "f1 waves[] declared as the sprint sequence" \
  || bad "f1 waves[]→sprint mapping not stated"
grep -qiE 'STALE' "$BATCH" && ok "f2 stale-plan rule retained" || bad "f2 stale-plan rule lost"
# Mermaid, per the project-wide hard rule that every generated flow is Mermaid
grep -qiE 'format=mermaid' "$BATCH" && ok "f3 sprint plan renders as Mermaid" || bad "f3 no Mermaid render for the sprint plan"

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "sprint lane: ALL PASS" || echo "sprint lane: FAILED"
exit $err

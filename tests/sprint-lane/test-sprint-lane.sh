#!/usr/bin/env bash
# Contract test for the sprint lane (spec 2026-08-29 Fase 2). The run is inline (one context, plan
# order); `--sprint=<n>` stays a prose gate at the rules tier, stated in execute-bolts SKILL.md, the
# inline-run flag table and the halt registry. The per-dispatch wave procedure (`--agents` only) was
# removed in P3b, and with it the wave-default / Mermaid-plan pins.
#
# What this pins:
#   a) execute-bolts documents --sprint=<n> as a live flag; --sequential / --sprint-checkpoint stay documented
#   c) the --sprint rule: 1-indexed, out of range = usage error, the sprint_blocked_by payload fields
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
INLINE="$ROOT/plugins/mega-sdd/skills/execute-bolts/references/inline-run.md"
PROTO="$ROOT/plugins/mega-sdd/references/halt-protocol.md"
FAM="$ROOT/plugins/mega-sdd/references/halt-families/bolts.md"
SCRIPTS="$ROOT/plugins/mega-sdd/scripts"
for f in "$SKILL" "$INLINE" "$PROTO" "$FAM"; do
  [ -f "$f" ] || { echo "FATAL: missing $f"; exit 1; }
done

echo "── a: the flags are documented in the skill's Inputs ──"
grep -qE '^  - `--sprint=<n>` — ' "$SKILL" && ok "a: --sprint=<n> is a live Inputs bullet" || bad "a: --sprint=<n> is not a live bullet in SKILL.md"
for flag in '--sequential' '--sprint-checkpoint'; do
  grep -qF -- "\`$flag\`" "$SKILL" && ok "a: $flag documented" || bad "a: $flag not documented in SKILL.md"
done

echo "── c: the --sprint rule + sprint_blocked_by payload ──"
grep -qF '`--sprint=<n>`' "$SKILL" && ok "c1 SKILL.md carries --sprint=<n>" || bad "c1 --sprint=<n> missing from SKILL.md"
grep -qF 'sprint_blocked_by' "$FAM" && ok "c2 family names sprint_blocked_by" || bad "c2 sprint_blocked_by missing from the family"
for field in requested_sprint incomplete_prerequisites; do
  grep -qF "$field" "$FAM" && ok "c3 payload carries $field" || bad "c3 payload missing $field"
done
# 1-indexed and never silently clamped — the off-by-one that would skip a sprint
grep -qiE '1-indexed' "$SKILL" && ok "c4 sprint numbering declared 1-indexed" || bad "c4 sprint indexing base not declared"
grep -qiE 'usage error' "$INLINE" && ok "c5 out-of-range is an error, not a clamp" || bad "c5 out-of-range behavior unspecified"

echo "── d: exactly ONE sprint-plan producer ──"
if [ -e "$SCRIPTS/derive-sprint-plan.sh" ]; then
  bad "d1 derive-sprint-plan.sh exists — the spec REJECTED a second producer (reuse analyze-parallelism.sh)"
else
  ok "d1 no derive-sprint-plan.sh (single producer preserved)"
fi
[ -f "$SCRIPTS/analyze-parallelism.sh" ] && ok "d2 analyze-parallelism.sh present" || bad "d2 analyze-parallelism.sh missing"
grep -qF 'analyze-parallelism.sh' "$SKILL" \
  && ok "d3 SKILL.md names the producer" \
  || bad "d3 SKILL.md does not name analyze-parallelism.sh"
grep -qiE '(never|do not|don.t) hand-(deriv|number)' "$SKILL" \
  && ok "d4 hand-derivation explicitly forbidden" \
  || bad "d4 nothing forbids hand-deriving the layering"

echo "── e: sprint_blocked_by registered ──"
grep -qF 'sprint_blocked_by' "$PROTO" && ok "e1 in halt-protocol registry" || bad "e1 absent from halt-protocol"
grep -qF '### sprint_blocked_by' "$FAM" && ok "e2 has a family entry" || bad "e2 no family entry in halt-families/bolts.md"
grep -qF 'ALWAYS STOP' "$FAM" && ok "e3 family file keeps the stop-class floor" || bad "e3 stop class missing"

echo "── f: the derived plan is what gets executed ──"
grep -qF '`waves[]`' "$SKILL" && ok "f1 waves[] declared as the sprint sequence" || bad "f1 waves[]→sprint mapping not stated"

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "sprint lane: ALL PASS" || echo "sprint lane: FAILED"
exit $err

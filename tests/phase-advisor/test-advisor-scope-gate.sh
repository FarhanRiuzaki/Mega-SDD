#!/usr/bin/env bash
# test-advisor-scope-gate.sh — pins spec 2026-08-17-advisor-scope-gate.md (P3,
# USER-DECIDED): bind Step 2.12 runs the phase-advisor ONLY when there is
# something to falsify (KB lane / draft CONFLICT / non-NEW claim); all-NEW
# greenfield binds skip with an auditable counted provenance line. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugins/mega-sdd/skills/bind-codebase/SKILL.md"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "── a: the scope gate exists with all three run-triggers ──"
grep -qi 'scope gate' "$S" && ok "a1 scope gate named at Step 2.12" || fail "a1 no scope gate"
grep -qi 'knowledge base was resolved\|KB lane' "$S" && ok "a2 trigger 1: KB lane" || fail "a2 KB trigger missing"
grep -qiE 'draft CONFLICT|≥1 (draft )?CONFLICT' "$S" && ok "a3 trigger 2: draft CONFLICT" || fail "a3 CONFLICT trigger missing"
grep -qF 'non-NEW draft claim' "$S" && ok "a4 trigger 3: non-NEW claim (gate-paragraph literal)" || fail "a4 non-NEW trigger missing"

echo "── b: the skip is counted + auditable, never a bare skip ──"
grep -q 'advisor: skipped (scoped' "$S" && ok "b1 scoped-skip provenance literal" || fail "b1 scoped-skip provenance missing"
grep -q 'conflicts=' "$S" && grep -q 'non_new_claims=' "$S" && grep -q 'kb=' "$S" \
  && ok "b2 skip line carries REAL counts" || fail "b2 counted-skip shape missing"

echo "── c: fail-safe wording — ONE non-NEW claim is enough to run ──"
grep -qF 'even one such claim is enough' "$S" && ok "c1 fail-safe wording (gate literal)" || fail "c1 fail-safe wording missing"
grep -qiE 'all-NEW' "$S" && ok "c2 skip scoped to ALL-NEW binds only" || fail "c2 all-NEW scope missing"

echo "── d: force flag + contradiction refusal ──"
grep -qE '\-\-advisor\b' "$S" && ok "d1 --advisor force flag documented" || fail "d1 force flag missing"
grep -qF 'flag_contradiction' "$S" && ok "d2 contradiction refused with a typed blocker" || fail "d2 contradiction blocker missing"

echo "── b3: gate input is the FULL set on a --paths re-bind (round M3) ──"
grep -qF 'fresh AND carried-forward' "$S" && ok "b3 full-set gate input pinned" || fail "b3 carried-forward rule missing"
grep -qF 'scoped —' "$S" && grep -q 'advisor: skipped (scoped' "$S" \
  && ok "b4 scoped-skip form distinct from bare skipped (round M6)" || fail "b4 scoped form not distinct"

echo "── e: untouched contracts still pinned (existing suites must stay green) ──"
( cd "$ROOT" && bash tests/phase-advisor/test-bind-advisor-wired.sh </dev/null >/dev/null 2>&1 ) \
  && ok "e1 bind-advisor-wired still green" || fail "e1 wired test broke"
( cd "$ROOT" && bash tests/phase-advisor/test-provenance-states.sh </dev/null >/dev/null 2>&1 ) \
  && ok "e2 provenance-states still green" || fail "e2 provenance test broke"

echo
echo "advisor scope gate: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]

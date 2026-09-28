#!/usr/bin/env bash
# Audit Phase 2b (spec 2026-08-11-audit-phase2b-scripts-and-owners.md) —
# S4 sync short-circuit wiring, S5 owner outcomes, S6 hand-synchronized
# contract parity pins (v1: presence-pair pins — each pair member must keep
# its half of the contract; a deleted half fails here before it drifts).
# Run: bash tests/surface/test-p11-owner-parity.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# ── S4 — sync claim-intersection short-circuit wired at all three surfaces ──
[ -x "$P/scripts/sync-intersect.sh" ] \
  && pass "S4: sync-intersect.sh present + executable" || fail "S4: script missing"
grep -qF 'sync-intersect.sh' "$P/commands/sync.md" \
  && grep -qF 'fail-closed' "$P/commands/sync.md" \
  && pass "S4b: sync.md names the gate with its fail-closed contract" \
  || fail "S4b: sync.md wiring missing"
# 9.0 P1 repoint: the classic lane is retired, so the owner bullet no longer
# says "BOTH lanes" — one sync chain, gate named in the Mode D row + owned by
# the §Mode D detail bullet (script + exit-code / fail-closed contract).
RR="$P/skills/orchestrate-flow/references/routing-rules.md"
grep -qF 'changed-set derivation → short-circuit gate → scoped `detect-drift`' "$RR" \
  && grep -qF 'Short-circuit gate (after the changed set exists): `scripts/sync-intersect.sh' "$RR" \
  && grep -qF 'exit 2 or ANY other unexpected exit → fail-closed, full chain' "$RR" \
  && pass "S4c: Mode D row carries the gate" || fail "S4c: Mode D wiring missing"
grep -qF 'sync-intersect.sh' "$P/skills/orchestrate-flow/SKILL.md" \
  && pass "S4d: --sync flag row names the gate" || fail "S4d: flag-row wiring missing"

# ── S5 — UAT step-row single owner ──
UO="$P/skills/emit-uat/references/uat-sections.md"
grep -qF 'OWNED by `references/uat-sections.md §Section 2`' "$P/skills/emit-uat/SKILL.md" \
  && grep -qF 'adds no rules of its own' "$P/skills/emit-uat/references/uat-template.md" \
  && grep -qF '| 1 | <Aksi> | <Expected Result> |' "$UO" \
  && grep -qF 'Pending — flow' "$UO" \
  && pass "S5a: UAT step-row grammar single-owned at uat-sections §Section 2" \
  || fail "S5a: UAT owner relocation incomplete"

# (S5b retired in 9.0 P1: it pinned the spawn-cost gate restatement in the
# deleted scan-codebase skill + its scan-procedure owner — skill removed by
# design, spec 2026-09-27 §2 "scan-codebase REMOVE (P1)"; nothing relocated.)

# ── S6 — parity pairs (presence-pair pins) ──
# 9.0 P1 repoint: the template half (bind-codebase/references/binding-md-template.md)
# was deleted with bind-codebase; the layout-2 marker grammar is now owned by the
# code, scripts/_lib/binding_md.py (spec 2026-09-27 §7 P1 decision 10), which the
# writer names as its grammar owner. The pair is therefore writer ↔ parser, and
# it is checked by EXECUTION: the writer's documented marker lines, instantiated,
# must parse to the right ACTION through the owner's parse_conflict_resolutions.
BM="$P/skills/resolve-oq/references/binding-mode.md"
BP="$P/scripts/_lib/binding_md.py"
s6a_ok=0
if grep -qF '### ✅ CONFLICT-' "$BM" && grep -qF '**Resolution**: ✅ RESOLVED (' "$BM" \
   && grep -qF 'grammar owner: `scripts/_lib/binding_md.py`' "$BM" && [ -f "$BP" ]; then
  hdr_t=$(grep -oE '`### ✅ CONFLICT-N RESOLVED \(<ACTION>\)[^`]*`' "$BM" | head -1 | tr -d '`')
  res_t=$(grep -oE '`- \*\*Resolution\*\*: ✅ RESOLVED \(<ACTION>\)[^`]*`' "$BM" | head -1 | tr -d '`')
  if [ -n "$hdr_t" ] && [ -n "$res_t" ]; then
    HDR_T="$hdr_t" RES_T="$res_t" LIBDIR="$P/scripts/_lib" python3 - <<'PY' && s6a_ok=1
import os, sys
sys.path.insert(0, os.environ["LIBDIR"])
from binding_md import parse_conflict_resolutions
def inst(t, n, action):
    return (t.replace("CONFLICT-N", f"CONFLICT-{n}").replace("<ACTION>", action)
             .replace("<original title>", "t").replace("<ISO date>", "2026-01-01")
             .replace("<one-line rationale>", "r"))
hdr, res = os.environ["HDR_T"], os.environ["RES_T"]
md = "\n".join([
    "## Conflicts (2) — BLOCKING",
    # half 1: the writer's resolved-heading marker alone
    inst(hdr, 1, "KEEP_CODE"), "- **Claim**: C-001",
    # half 2: an unmarked heading + the writer's dedicated Resolution line alone
    "### CONFLICT-2 — t", "- **Claim**: C-002", inst(res, 2, "SPLIT"),
    "## Open Questions (0)", ""])
errs = []
got = parse_conflict_resolutions(md, errs)
sys.exit(0 if (not errs and got == {"C-001": "KEEP_CODE", "C-002": "SPLIT"}) else 1)
PY
  fi
fi
if [ "$s6a_ok" -eq 1 ]; then
  pass "S6a: ✅ RESOLVED marker shape present at the writer (binding-mode) AND parsed by the grammar owner (binding_md.py)"
else fail "S6a: marker-grammar pair broken (writer/parser drift or deletion)"; fi
# P3 C6b: the agent copy went with agents/bolt-implementer.md (spec v9 §8.6); the home stays until C7.
grep -qF 'canonical taxonomy' "$P/skills/execute-bolts/references/partial-state-and-saga.md" \
  && pass "S6d: step_type canonical taxonomy home present" \
  || fail "S6d: step_type taxonomy home missing"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

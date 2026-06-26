#!/usr/bin/env bash
# test-oq-collapse.sh — Batch 2 (token), lever S2: collapse the P1+P2 resolve-oq passes.
#
# The field audit saw ~3 OQ passes ("Land OQ" P1, "Land P2 OQ" P2, "Apply phase-advisor
# fixes"). The first two are the SAME skill (resolve-oq) split across two invocations by
# RESOLUTION_SCOPE, each re-reading the whole vault. Collapse: Step 0.6 now recommends
# `all-priorities` — ONE priority-ordered walk (P1->P2->P3) that enters the vault once.
#
# This is a skill-prose behavior change, so the pin is a doc-contract regression:
#   1. Step 0.6 recommends all-priorities (the collapse).
#   2. The no-fabrication rail survives — P1 stays interactive / no auto-resolve.
#   3. p1-only is STILL offered (unblock-fast path not removed).
#   4. Frontmatter is valid YAML and the version was bumped.
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/resolve-oq/SKILL.md"

[ -f "$SKILL" ] || { echo "FAIL: resolve-oq/SKILL.md not found"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

STEP06="$(grep -n 'Step 0.6' "$SKILL" | head -1)"
LINE="$(grep -A0 'Step 0.6 — Resolution scope' "$SKILL" | head -1)"

# 1. all-priorities is now the recommended scope.
if grep -qE '`all-priorities` \(\*\*recommended' "$SKILL"; then
  pass "Step 0.6 recommends all-priorities (collapse — one vault entry)"
else
  fail "Step 0.6 no longer recommends all-priorities"
fi

# 2. The no-fabrication / interactive rail survives the collapse.
if grep -qiE 'does NOT auto-resolve|interactive on EVERY OQ|no-fabrication' "$SKILL"; then
  pass "no-fabrication rail preserved (P1 stays interactive, no auto-resolve)"
else
  fail "collapse dropped the no-auto-resolve / interactive guarantee"
fi

# 3. p1-only is still offered (unblock-fast path not removed — regression guard).
if grep -qE '`p1-only`' "$SKILL"; then
  pass "p1-only still offered (unblock-fast path intact)"
else
  fail "p1-only scope was removed"
fi

# 4. Frontmatter valid YAML + version bumped past 2.1.0.
VER="$(python3 - "$SKILL" <<'PY'
import sys
fm=open(sys.argv[1]).read().split('---',2)[1]
try:
    import yaml; d=yaml.safe_load(fm); print(d.get('version','?')) if isinstance(d,dict) else print('NOTMAP')
except ImportError:
    for ln in fm.splitlines():
        if ln.strip().startswith('version:'): print(ln.split(':',1)[1].strip())
PY
)"
echo "  (resolve-oq version = $VER)"
case "$VER" in
  2.1.0|2.0.*|1.*|"?"|NOTMAP|"") fail "version not bumped past 2.1.0 (got $VER)" ;;
  *) pass "version bumped (got $VER)" ;;
esac

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-oq-collapse)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi

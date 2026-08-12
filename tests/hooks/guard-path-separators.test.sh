#!/usr/bin/env bash
# guard-path-separators.test.sh
#
# Pins D3 (2026-07-29): hook guards matched forward-slash patterns against
# os.path.relpath output, which is OS-NATIVE. On Windows every one of them
# silently matched nothing.
#
# Two guards, both in hooks/pre-tool-use:
#
#   1. anti-self-bypass Write/Edit — denies a direct write of a gate STATE file
#      (.validation-blockers.json, the quality-gate states) or a B1/B2/B4 EVIDENCE
#      artifact. `rel == ".mega-sdd/" + g`, `.endswith("/.mega-sdd/" + g)` and the
#      evidence regex are all written with "/". On Windows `rel` is
#      `.mega-sdd\.validation-blockers.json` -> NO MATCH -> a forged gate verdict
#      goes through. That is invariant #2, on the team's actual platform.
#
#   2. LOCKED-index guard — looks a path up in `.mega-sdd/.locked-index.json`,
#      a COMMITTED, team-shared artifact whose keys were also OS-native. An index
#      built on macOS never matched a Windows teammate's lookup, and vice versa.
#
# HOW THIS IS TESTED WITHOUT WINDOWS: `ntpath` is Python's Windows path module and
# is importable on every platform, so ntpath.abspath/relpath give EXACT Windows
# semantics here. `posixpath` gives the contrast case. The guard logic below is a
# transcription of the two hook blocks; check C asserts the transcription still
# matches the shipped source, so it cannot silently drift out of sync.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
HOOK="$ROOT/plugins/mega-sdd/hooks/pre-tool-use"
BUILDER="$ROOT/plugins/mega-sdd/scripts/build-locked-index.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

cat > "$TMP/guards.py" <<'PYEOF'
"""Transcription of the two pre-tool-use guards, parameterised by path module."""
import ntpath, posixpath, re, sys

_GUARDED = (
    ".validation-blockers.json", ".unit-spec-state.json", ".flow-coverage-state.json",
    ".sibling-consistency-state.json", ".ui-quality-blockers.json",
    ".cross-cutting-state.json", ".bolt-orphans-state.json",
    ".batch-suite-gate-state.json", ".bolt-postflight-state.json",
    ".factory-ledger-state.json", ".bolt-whitelist-state.json",
    ".bolt-acceptance-state.json",
)
EVID = re.compile(
    r"(?:^|/)(?:\.mega-sdd/vaults/[^/]+|docs/mega-sdd/vaults/[^/]+|[^/]+-bound)"
    r"/bolts/(?:[^/]+/(?:(?:pre|post)flight|acceptance)\.json|_batch-suite\.json)$")
UAT_EVID = re.compile(
    r"(?:^|/)(?:\.mega-sdd/vaults/[^/]+|docs/mega-sdd/vaults/[^/]+|[^/]+-bound)"
    r"/uat/evidence/(?:[^/]+/)*result\.json$")


def _rel(mod, fp, root, normalize):
    p = mod.abspath(fp) if mod.isabs(fp) else mod.abspath(mod.join(root, fp))
    rel = mod.relpath(p, root) if root else p
    # `mod.sep` stands in for os.sep — that is exactly the shipped condition
    # evaluated under the platform being simulated.
    if normalize and mod.sep != "/":
        rel = rel.replace(mod.sep, "/")
    return rel


def bypass_guard(mod, fp, root, normalize):
    """-> 'protected' | 'evidence' | '' (inert)."""
    rel = _rel(mod, fp, root, normalize)
    if re.search(r"(?:^|/)(?:tests|examples|fixtures)/", rel):
        return "exempt"
    if any(rel == ".mega-sdd/" + g or rel.endswith("/.mega-sdd/" + g) for g in _GUARDED):
        return "protected"
    if EVID.search(rel):
        return "evidence"
    if UAT_EVID.search(rel):
        return "evidence"
    return ""


def locked_guard(mod, fp, root, index_keys, normalize):
    """-> True if the LOCKED guard fires for this path."""
    return _rel(mod, fp, root, normalize) in index_keys


MODS = {"posix": posixpath, "windows": ntpath}
PYEOF

echo "── A. anti-self-bypass guard fires on BOTH platforms (fixed) ──"
"$PY" - "$TMP" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[1])
from guards import bypass_guard, MODS

CASES = [
    # label,                     posix path,                                          windows path,                                        want
    ("forged moat state",        "/proj/.mega-sdd/.validation-blockers.json",         r"C:\proj\.mega-sdd\.validation-blockers.json",      "protected"),
    ("forged quality state",     "/proj/.mega-sdd/.unit-spec-state.json",             r"C:\proj\.mega-sdd\.unit-spec-state.json",          "protected"),
    ("forged B1 postflight",     "/proj/.mega-sdd/vaults/v1/bolts/U-001/postflight.json", r"C:\proj\.mega-sdd\vaults\v1\bolts\U-001\postflight.json", "evidence"),
    ("forged B2 batch-suite",    "/proj/.mega-sdd/vaults/v1/bolts/_batch-suite.json", r"C:\proj\.mega-sdd\vaults\v1\bolts\_batch-suite.json", "evidence"),
    ("forged B4 acceptance",     "/proj/.mega-sdd/vaults/v1/bolts/U-002/acceptance.json", r"C:\proj\.mega-sdd\vaults\v1\bolts\U-002\acceptance.json", "evidence"),
    ("legacy -bound evidence",   "/proj/v1-bound/bolts/U-003/postflight.json",        r"C:\proj\v1-bound\bolts\U-003\postflight.json",     "evidence"),
    ("forged UAT evidence",      "/proj/.mega-sdd/vaults/v1/uat/evidence/UAT-001/20260812T100000Z/result.json", r"C:\proj\.mega-sdd\vaults\v1\uat\evidence\UAT-001\20260812T100000Z\result.json", "evidence"),
    ("unrelated uat evidence",   "/proj/myapp/uat/evidence/UAT-001/x/result.json",    r"C:\proj\myapp\uat\evidence\UAT-001\x\result.json", ""),
    ("ordinary source file",     "/proj/src/app/Foo.php",                             r"C:\proj\src\app\Foo.php",                          ""),
    ("unrelated bolts json",     "/proj/other/bolts/x/postflight.json",               r"C:\proj\other\bolts\x\postflight.json",            ""),
    ("tests/ exemption",         "/proj/tests/fx/.mega-sdd/.validation-blockers.json", r"C:\proj\tests\fx\.mega-sdd\.validation-blockers.json", "exempt"),
]
ROOTS = {"posix": "/proj", "windows": "C:\\proj"}
bad = 0
for label, pp, wp, want in CASES:
    for plat, fp in (("posix", pp), ("windows", wp)):
        got = bypass_guard(MODS[plat], fp, ROOTS[plat], normalize=True)
        if got != want:
            print("   %-24s %-8s got=%-10r want=%r" % (label, plat, got, want)); bad += 1
sys.exit(1 if bad else 0)
PYEOF
[ $? -eq 0 ] && pass "9 cases x {posix,windows} agree, incl. the tests/ exemption" \
             || fail "bypass guard verdict differs by platform"

echo "── B. CONTROL: without the normalization the guard is INERT on Windows ──"
"$PY" - "$TMP" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[1])
from guards import bypass_guard, MODS

BLOCKERS = [
    r"C:\proj\.mega-sdd\.validation-blockers.json",
    r"C:\proj\.mega-sdd\.unit-spec-state.json",
    r"C:\proj\.mega-sdd\vaults\v1\bolts\U-001\postflight.json",
    r"C:\proj\.mega-sdd\vaults\v1\bolts\_batch-suite.json",
]
# Every one of these MUST be blocked, and pre-fix every one of them was inert.
leaked = [fp for fp in BLOCKERS
          if bypass_guard(MODS["windows"], fp, "C:\\proj", normalize=False) == ""]
# ...and a forward-slash path from the model does not rescue it: ntpath.abspath
# normalizes to backslashes regardless, so there is NO input shape that worked.
fwd = bypass_guard(MODS["windows"], "C:/proj/.mega-sdd/.validation-blockers.json",
                   "C:\\proj", normalize=False)
print("   pre-fix: %d/%d forged artifacts UNBLOCKED on Windows" % (len(leaked), len(BLOCKERS)))
print("   pre-fix: forward-slash input -> %r (ntpath.abspath re-normalizes)" % (fwd,))
sys.exit(0 if (len(leaked) == len(BLOCKERS) and fwd == "") else 1)
PYEOF
[ $? -eq 0 ] && pass "control: all 4 leaked pre-fix, and no input shape rescued it (A is not vacuous)" \
             || fail "control: pre-fix guard was not inert — A no longer pins a real defect"

echo "── C. the transcription still matches the shipped guard ──"
# A test that drifts from the source silently stops testing it. These are the exact
# tokens the guards depend on; if they change, this test must be revisited.
for tok in 'os.sep != "/"' 'rel = rel.replace(os.sep, "/")' 'rel == ".mega-sdd/" + g'; do
  if grep -qF "$tok" "$HOOK"; then pass "hook still carries: $tok"
  else fail "hook no longer carries [$tok] — transcription in this test is stale"; fi
done
n=$(grep -cF 'rel = rel.replace(os.sep, "/")' "$HOOK")
if [ "$n" -eq 2 ]; then pass "both guards normalize (found $n sites)"
else fail "expected 2 normalization sites in the hook, found $n"; fi

echo "── D. LOCKED-index keys are platform-neutral end to end ──"
if grep -qF 'rel_src = rel_src.replace(os.sep, "/")' "$BUILDER"; then
  pass "build-locked-index.sh POSIX-normalizes its keys"
else
  fail "build-locked-index.sh still writes OS-native keys — a macOS-built index cannot match a Windows lookup"
fi
"$PY" - "$TMP" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[1])
from guards import locked_guard, MODS
# An index COMMITTED from a POSIX machine (the normal case: keys use "/").
INDEX = {"src/app/Legacy.php": [12]}
ok  = locked_guard(MODS["windows"], r"C:\proj\src\app\Legacy.php", "C:\\proj", INDEX, normalize=True)
bad = locked_guard(MODS["windows"], r"C:\proj\src\app\Legacy.php", "C:\\proj", INDEX, normalize=False)
print("   windows lookup vs POSIX-built index: fixed=%s  pre-fix=%s" % (ok, bad))
sys.exit(0 if (ok and not bad) else 1)
PYEOF
[ $? -eq 0 ] && pass "Windows lookup hits a POSIX-built index (pre-fix it missed → guard inert)" \
             || fail "LOCKED-index lookup is still platform-dependent"

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc

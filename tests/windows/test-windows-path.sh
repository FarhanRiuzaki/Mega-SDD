#!/usr/bin/env bash
# test-windows-path.sh
#
# Pins scripts/_lib/windows_path.py — the ONLY code in mega-sdd that writes the
# Windows registry. It exists because an installer writes HKCU\Environment\Path
# while an already-running bash keeps its stale copy, so `verify_cmd` false-fails
# on a tool that installed perfectly.
#
# HOW THIS IS TESTED WITHOUT WINDOWS: `winreg` is a Windows-only stdlib module, so
# windows_path.py imports it guarded and the test injects a FAKE winreg that
# records every read and write. That makes the safety contract mechanically
# checkable on any host — and the safety contract is the whole point, because each
# rule in it corresponds to a real incident:
#
#   * REG_EXPAND_SZ must be preserved (writing REG_SZ expands %USERPROFILE% to a
#     literal and breaks the value for every other profile);
#   * the operation must be idempotent and must NOT write when nothing changed
#     (an unnecessary registry write is an unnecessary chance to corrupt);
#   * a write that does not round-trip must RAISE, not be assumed good — silent
#     truncation is exactly how a hand-written .reg once cut a 798-char USER PATH
#     down to 92.
#
# Every assertion below is followed by, or paired with, a control proving the fake
# registry actually observes the thing being asserted — a green run against an
# inert fake would be worthless.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
LIB="$ROOT/plugins/mega-sdd/scripts/_lib"
SH="$ROOT/plugins/mega-sdd/scripts/fix-windows-path.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

# ── the fake registry ────────────────────────────────────────────────────────
cat > "$TMP/fakewinreg.py" <<'PYEOF'
"""Minimal winreg stand-in that RECORDS what happened, so assertions are checkable."""
HKEY_CURRENT_USER = 1
HKEY_LOCAL_MACHINE = 2
KEY_READ = 0x20019
KEY_WRITE = 0x20006
REG_SZ = 1
REG_EXPAND_SZ = 2
REG_BINARY = 3

STORE = {}     # (hive, subkey, name) -> (value, type)
WRITES = []    # [(hive, subkey, name, value, type)]


class _Key:
    def __init__(self, hive, sub):
        self.hive, self.sub = hive, sub
    def Close(self):
        pass


def OpenKey(hive, sub, reserved=0, access=0):
    return _Key(hive, sub)


def QueryValueEx(key, name):
    try:
        return STORE[(key.hive, key.sub, name)]
    except KeyError:
        raise FileNotFoundError(name)


def SetValueEx(key, name, reserved, regtype, value):
    STORE[(key.hive, key.sub, name)] = (value, regtype)
    WRITES.append((key.hive, key.sub, name, value, regtype))


def ExpandEnvironmentStrings(s):
    # Deliberately NOT a real expander: the tests assert that stored values keep
    # their %VAR% form, and a real expansion here would hide that.
    return s.replace("%SYSTEMROOT%", "C:\\Windows")
PYEOF

run_py() { "$PY" - "$LIB" "$TMP" "$@"; }

echo "── A. idempotence + no-write-when-unchanged ──"
run_py <<'PYEOF'
import sys, os
lib, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, tmp); sys.path.insert(0, lib)
import fakewinreg
sys.modules["winreg"] = fakewinreg
import windows_path as wp
wp.winreg = fakewinreg

K = (fakewinreg.HKEY_CURRENT_USER, "Environment", "Path")
fakewinreg.STORE[K] = ("%USERPROFILE%\\bin;C:\\tools", fakewinreg.REG_EXPAND_SZ)

changed, before, after = wp.ensure_user_path_dirs(["C:\\Users\\me\\.local\\bin"])
assert changed is True, "first call must change"
assert len(fakewinreg.WRITES) == 1, "expected exactly 1 write, got %d" % len(fakewinreg.WRITES)
assert after.startswith("C:\\Users\\me\\.local\\bin;"), "new dir must be PREPENDED: %r" % after

n_before = len(fakewinreg.WRITES)
changed2, b2, a2 = wp.ensure_user_path_dirs(["C:\\Users\\me\\.local\\bin"])
assert changed2 is False, "second call must be a no-op"
assert len(fakewinreg.WRITES) == n_before, "no-op call MUST NOT write the registry"
assert a2 == after, "value drifted on a no-op call"

# trailing-separator / case variants must dedupe too, or repeated runs grow PATH
changed3, _, a3 = wp.ensure_user_path_dirs(["C:\\Users\\me\\.local\\bin\\"])
assert changed3 is False, "trailing-separator variant must dedupe"
print("OK")
PYEOF
[ $? -eq 0 ] && pass "idempotent, prepends, and never writes on a no-op" || fail "idempotence/no-op contract broken"

echo "── B. REG_EXPAND_SZ preserved and %VAR% left unexpanded ──"
run_py <<'PYEOF'
import sys
lib, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, tmp); sys.path.insert(0, lib)
import fakewinreg
sys.modules["winreg"] = fakewinreg
import windows_path as wp
wp.winreg = fakewinreg

K = (fakewinreg.HKEY_CURRENT_USER, "Environment", "Path")
fakewinreg.STORE[K] = ("%USERPROFILE%\\AppData\\Local\\bin;C:\\tools", fakewinreg.REG_EXPAND_SZ)
wp.ensure_user_path_dirs(["C:\\new"])

value, regtype = fakewinreg.STORE[K]
assert regtype == fakewinreg.REG_EXPAND_SZ, "type must stay REG_EXPAND_SZ, got %r" % regtype
assert "%USERPROFILE%" in value, "%%USERPROFILE%% was expanded away: %r" % value
_, _, _, wrote_val, wrote_type = fakewinreg.WRITES[-1]
assert wrote_type == fakewinreg.REG_EXPAND_SZ
assert "%USERPROFILE%" in wrote_val
print("OK")
PYEOF
[ $? -eq 0 ] && pass "REG_EXPAND_SZ preserved; %USERPROFILE% survives unexpanded" || fail "registry type or %VAR% not preserved"

echo "── C. a write that does not round-trip RAISES (silent truncation guard) ──"
run_py <<'PYEOF'
import sys
lib, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, tmp); sys.path.insert(0, lib)
import fakewinreg
sys.modules["winreg"] = fakewinreg
import windows_path as wp
wp.winreg = fakewinreg

K = (fakewinreg.HKEY_CURRENT_USER, "Environment", "Path")
fakewinreg.STORE[K] = ("C:\\a" * 60, fakewinreg.REG_EXPAND_SZ)

# Simulate the real destructive failure: the write "succeeds" but stores a
# TRUNCATED value (this is what a bad .reg import did — 798 chars -> 92).
_orig = fakewinreg.SetValueEx
def truncating(key, name, reserved, regtype, value):
    _orig(key, name, reserved, regtype, value[:92])
fakewinreg.SetValueEx = truncating

try:
    wp.ensure_user_path_dirs(["C:\\new"])
except wp.WindowsPathError as e:
    assert "round-trip" in str(e), "wrong error: %s" % e
    print("OK")
else:
    raise SystemExit("ensure_user_path_dirs accepted a TRUNCATED write — the guard is absent")
PYEOF
[ $? -eq 0 ] && pass "truncated write is detected and raises" || fail "silent truncation was accepted"

echo "── D. CONTROL: the fake registry actually records writes ──"
# Without this, every 'no write happened' assertion above could pass vacuously.
run_py <<'PYEOF'
import sys
lib, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, tmp); sys.path.insert(0, lib)
import fakewinreg
sys.modules["winreg"] = fakewinreg
import windows_path as wp
wp.winreg = fakewinreg
K = (fakewinreg.HKEY_CURRENT_USER, "Environment", "Path")
fakewinreg.STORE[K] = ("C:\\tools", fakewinreg.REG_EXPAND_SZ)
assert len(fakewinreg.WRITES) == 0
wp.ensure_user_path_dirs(["C:\\definitely-new"])
assert len(fakewinreg.WRITES) == 1, "the fake never recorded a write — assertions A/B would be vacuous"
print("OK")
PYEOF
[ $? -eq 0 ] && pass "control: fake registry is live (A/B are not vacuous)" || fail "control: fake never records writes"

echo "── E. effective new-process PATH is system-then-user; probe uses it ──"
run_py <<'PYEOF'
import sys, os
lib, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, tmp); sys.path.insert(0, lib)
import fakewinreg
sys.modules["winreg"] = fakewinreg
import windows_path as wp
wp.winreg = fakewinreg

fakewinreg.STORE[(fakewinreg.HKEY_LOCAL_MACHINE, wp.SYSTEM_ENV_SUBKEY, "Path")] = ("C:\\sys", fakewinreg.REG_EXPAND_SZ)
fakewinreg.STORE[(fakewinreg.HKEY_CURRENT_USER, "Environment", "Path")] = ("C:\\usr", fakewinreg.REG_EXPAND_SZ)
got = wp.effective_new_process_path()
assert got == ["C:\\sys", "C:\\usr"], "wrong order/content: %r" % got

# probe against a REAL directory so isfile() is meaningful
d = os.path.join(tmp, "bindir"); os.makedirs(d, exist_ok=True)
open(os.path.join(d, "jd.exe"), "w").close()
assert wp.resolves_in_new_shell("jd", dirs=[d]), "should resolve jd.exe"
assert wp.resolves_in_new_shell("nope", dirs=[d]) is None, "must not invent a hit"
print("OK")
PYEOF
[ $? -eq 0 ] && pass "system-then-user order; probe hits real files only" || fail "effective PATH or probe is wrong"

echo "── F. the shell entry point refuses unsafe/invalid invocations ──"
out=$(bash "$SH" --probe=jd 2>&1); st=$?
if [ "$st" -eq 6 ]; then pass "exits 6 on a non-Windows host instead of touching anything"
else fail "expected rc 6 off-Windows, got $st ($out)"; fi

out=$(OSTYPE=msys bash "$SH" --ensure-dirs 2>&1); st=$?
if [ "$st" -eq 2 ] && printf '%s' "$out" | grep -q 'backup-to'; then
  pass "refuses --ensure-dirs without --backup-to (no repair without a restore point)"
else fail "missing backup gate: rc=$st out=$out"; fi

out=$(bash "$SH" 2>&1); st=$?
if [ "$st" -eq 2 ]; then pass "usage error without a mode"; else fail "expected rc 2, got $st"; fi

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc

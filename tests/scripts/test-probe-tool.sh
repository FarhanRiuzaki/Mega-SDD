#!/usr/bin/env bash
# S2 (spec 2026-08-11-audit-phase2b-scripts-and-owners.md) — probe-tool.sh
# contract: one-line `<verdict> bound=<N>s rc=<rc>` output, exit 0 always,
# verdict map per install-deps SKILL Steps 2/6 + rails 12-13.
# Run: bash tests/scripts/test-probe-tool.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
S="plugins/mega-sdd/scripts/probe-tool.sh"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

[ -x "$S" ] && pass "script is executable" || fail "script not executable (chmod +x needed)"

# helper: run + capture line and exit code
run() { OUT=$(bash "$S" "$@" </dev/null); SRC=$?; }

BOUNDED=0
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then BOUNDED=1; fi

# ── contract: one line, shape, exit 0 always ──
run --verify-cmd='true'
[ "$SRC" -eq 0 ] && pass "exit 0 on present" || fail "exit $SRC on present (must be 0 always)"
n=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
[ "$n" -eq 1 ] && pass "exactly ONE output line" || fail "$n output lines: $OUT"
printf '%s' "$OUT" | grep -Eq '^(present|missing|slow-verify|probe-inconclusive) bound=[0-9]+s rc=[0-9]+$' \
  && pass "line matches '<verdict> bound=<N>s rc=<rc>'" || fail "line shape wrong: $OUT"
printf '%s' "$OUT" | grep -q '^present .* rc=0$' \
  && pass "rc 0 -> present" || fail "rc 0 not present: $OUT"

# ── rc 127 past the pre-filter -> probe-inconclusive UNCONDITIONALLY (the
# install-deps SKILL Step-2 verdict table + rail 12 are the source of truth:
# "127 NEVER means missing" — command -v already proved the name resolves
# before the probe ran, so 127 here is the probe LAYER, never the tool) ──
run --verify-cmd='exit 127'
[ "$SRC" -eq 0 ] && pass "exit 0 on rc-127 probe" || fail "exit $SRC on rc-127 probe"
printf '%s' "$OUT" | grep -q '^probe-inconclusive .* rc=127$' \
  && pass "verify-cmd 'exit 127' -> probe-inconclusive (SKILL table: 127 never means missing once the pre-filter resolved the name)" \
  || fail "'exit 127' verdict wrong: $OUT"

# ── pre-filter: tool absent from PATH -> missing WITHOUT exec probe ──
run --tool=mega-sdd-no-such-tool-xyz --verify-cmd='mega-sdd-no-such-tool-xyz --version'
printf '%s' "$OUT" | grep -q '^missing .* rc=127$' \
  && pass "command -v pre-filter: absent name -> missing rc=127" \
  || fail "pre-filter verdict wrong: $OUT"

# ── SKILL nuance: --tool proves identity, then 127 = probe layer, never missing ──
run --tool=sh --verify-cmd='exit 127'
printf '%s' "$OUT" | grep -q '^probe-inconclusive .* rc=127$' \
  && pass "--tool + rc 127 -> probe-inconclusive (127 never means missing once presence proven)" \
  || fail "--tool + 127 verdict wrong: $OUT"

# ── other nonzero rc -> missing (WindowsApps stub exit-49 class) ──
# `||` forces the bounded `sh -c` wrap: `exit` is a shell BUILTIN, and real GNU
# timeout (bounded hosts, e.g. ubuntu CI) cannot exec a builtin directly (rc 127).
run --tool=sh --verify-cmd='exit 49 || exit 49'
printf '%s' "$OUT" | grep -q '^missing .* rc=49$' \
  && pass "rc 49 (stub class) -> missing" || fail "rc 49 verdict wrong: $OUT"
run --verify-cmd='false'
printf '%s' "$OUT" | grep -q '^missing .* rc=1$' \
  && pass "rc 1 -> missing" || fail "rc 1 verdict wrong: $OUT"

# ── slow-verify: sleep exceeding a small bound -> 124/137, never missing ──
# When the host ships neither timeout nor gtimeout (stock macOS — the exact
# machine class SKILL rail 13 describes), inject a minimal GNU-timeout
# stand-in so the bounded ladder is still exercised, and separately pin the
# unbounded (bound=0s) contract.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BP=""
if [ "$BOUNDED" -eq 0 ]; then
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/timeout" <<'EOF'
#!/usr/bin/env bash
# test-only GNU-timeout stand-in: timeout -k K N CMD... -> 124 on expiry
if [ "$1" = "-k" ]; then shift 2; fi
dur=$1; shift
"$@" & pid=$!
( sleep "$dur"; kill -TERM "$pid" 2>/dev/null ) & watcher=$!
wait "$pid"; rcx=$?
kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
[ "$rcx" -ge 128 ] && rcx=124
exit "$rcx"
EOF
  chmod +x "$TMP/bin/timeout"
  BP="$TMP/bin:"
  run --verify-cmd='sleep 1 || true'
  printf '%s' "$OUT" | grep -q '^present bound=0s rc=0$' \
    && pass "unbounded host reports bound=0s and never converts absence of the bound into a verdict" \
    || fail "unbounded-host contract wrong: $OUT"
fi
runb() { OUT=$(PATH="$BP$PATH" bash "$S" "$@" </dev/null); SRC=$?; }

runb --bound=1 --verify-cmd='sleep 5'
printf '%s' "$OUT" | grep -Eq '^slow-verify bound=1s rc=(124|137)$' \
  && pass "sleep past the bound -> slow-verify (124/137)" \
  || fail "slow-verify verdict wrong: $OUT"

# operator wrap: unwrapped, `timeout 1 sleep 3 || true` lets `||` escape the
# bound AND swallow the 124 -> present. Wrapped in one bounded sh -c the
# bound covers the whole compound -> slow-verify. Proves the sh -c wrap.
runb --bound=1 --verify-cmd='sleep 3 || true'
printf '%s' "$OUT" | grep -Eq '^slow-verify bound=1s rc=(124|137)$' \
  && pass "operator-bearing cmd wrapped in one bounded shell (|| cannot escape/swallow)" \
  || fail "operator wrap broken (|| escaped the bound): $OUT"

# ── m3: non-numeric --bound integer-validated -> default 10 ──
runb --bound=abc --verify-cmd='true'
printf '%s' "$OUT" | grep -q '^present bound=10s rc=0$' \
  && pass "--bound=abc integer-validated -> default bound=10s" \
  || fail "--bound=abc not defaulted to 10: $OUT"

# ── m2: a signal-killed probe leaks NO bash job-control line — ONE line on
# stdout+stderr combined. The `; :` routes through the sh -c wrap, so the
# wrap shell itself takes the SEGV (the `sh -c 'kill -SEGV $$'` probe shape:
# the crashed process is the top of the probe compound, which bash
# exec-optimizes — unsilenced, THIS script's shell would print
# "Segmentation fault" to its own stderr, outside the probe redirection). ──
OUT=$(bash "$S" --verify-cmd='kill -SEGV $$; :' </dev/null 2>&1); SRC=$?
[ "$SRC" -eq 0 ] || fail "segfault probe: exit $SRC (must be 0 always)"
n=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
if [ "$n" -eq 1 ] && printf '%s' "$OUT" | grep -Eq '^(present|missing|slow-verify|probe-inconclusive) bound=[0-9]+s rc=[0-9]+$'; then
  pass "segfaulting probe -> exactly ONE line on stdout+stderr (no job-control leak)"
else fail "segfault probe broke the ONE-line contract ($n lines): $OUT"; fi

# ── resolve-python carve-out: python verify cmd routes through the resolver ──
run --tool=python3 --verify-cmd='python3 -V'
printf '%s' "$OUT" | grep -Eq '^(present|slow-verify) ' \
  && pass "python carve-out resolves a usable interpreter on this host" \
  || fail "python carve-out verdict: $OUT (host has python3 — expected present/slow-verify)"

# ── degenerate input: empty verify-cmd -> inconclusive, still exit 0 ──
run --verify-cmd=''
[ "$SRC" -eq 0 ] && printf '%s' "$OUT" | grep -q '^probe-inconclusive ' \
  && pass "empty verify-cmd -> probe-inconclusive, exit 0" \
  || fail "empty verify-cmd handling wrong: rc=$SRC out=$OUT"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

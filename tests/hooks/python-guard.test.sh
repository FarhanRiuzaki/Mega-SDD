#!/usr/bin/env bash
# python-guard.test.sh
#
# Integration pin for the 2026-07-28 "moat dies silently without python3" fix.
#
# On a Windows machine whose only `python3` is the App Execution Alias stub,
# every hook's JSON parse returned EMPTY while `command -v python3` SUCCEEDED —
# so the python3-absent fail-closed branch never ran and PreToolUse exited 0
# with the binding→units gate, the CONFLICT gate and the quality gates all
# unevaluated. No diagnostic was emitted anywhere.
#
# Pins:
#   1. PreToolUse FAILS CLOSED (denies execute-bolts) when no usable interpreter
#      exists and .validation-blockers.json does not attest PASS.
#   2. PreToolUse does NOT deny when the blockers file attests PASS.
#   3. SessionStart surfaces the missing-interpreter notice, so the degradation
#      is never silent.
#   4. With a real python3, neither behaviour changes (no false alarm).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$HERE/../../plugins/mega-sdd/hooks"
BASH_BIN="$(command -v bash)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

# ── a PATH carrying every tool the hooks need EXCEPT any python ─────────────
BIN="$TMP/bin"; mkdir -p "$BIN"
for c in bash sh cat dirname basename find grep egrep sed awk date wc tr head tail \
         sort uniq cut git mkdir rm ls stat sleep env expr printf touch cp mv; do
  r="$(command -v "$c" 2>/dev/null)" || continue
  case "$r" in /*) ln -sf "$r" "$BIN/$c" 2>/dev/null ;; esac
done
if [ ! -x "$BIN/grep" ] || [ ! -x "$BIN/bash" ]; then
  echo "FAIL (fixture: could not build a python-free PATH)"; exit 1
fi
# and the Windows alias stub, shaped like the real one
ALIAS="$TMP/AppData/Local/Microsoft/WindowsApps"; mkdir -p "$ALIAS"
printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store" >&2\nexit 49\n' > "$ALIAS/python3"
chmod +x "$ALIAS/python3"
cp "$ALIAS/python3" "$ALIAS/python"
NOPY="$ALIAS:$BIN"

# sanity: the fixture must reproduce the ORIGINAL bug, else every pass is vacuous
if PATH="$NOPY" "$BASH_BIN" -c 'command -v python3 >/dev/null 2>&1'; then
  pass "fixture: 'command -v python3' succeeds against the stub (bug reproduced)"
else
  fail "fixture does not reproduce the original bug"; exit 1
fi
if PATH="$NOPY" "$BASH_BIN" -c 'python3 -c "print(1)" 2>/dev/null' | grep -q 1; then
  fail "fixture: stub actually produced output"
else
  pass "fixture: stub yields empty stdout (parse returns nothing)"
fi

# ── project with an unresolved blocker ──────────────────────────────────────
P="$TMP/proj"; mkdir -p "$P/.mega-sdd"
printf 'telemetry: true\n' > "$P/.mega-sdd/config.yaml"
printf '{"status":"FAIL","blockers":[{"id":"B1"}]}\n' > "$P/.mega-sdd/.validation-blockers.json"

EB_JSON="{\"session_id\":\"s\",\"cwd\":\"$P\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\"}}"

# 1. no usable interpreter + blockers not PASS -> MUST DENY
out="$(printf '%s' "$EB_JSON" | PATH="$NOPY" "$BASH_BIN" "$HOOKS/pre-tool-use" 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"deny"'; then
  pass "no usable python3 + FAIL blockers -> execute-bolts DENIED (fails closed)"
else
  fail "no usable python3 + FAIL blockers -> NOT denied (moat silently open) out=[$out]"
fi

# the deny reason must actually tell the human what to do
if printf '%s' "$out" | grep -q 'install-deps'; then
  pass "deny reason carries the remedy (/mega-sdd:install-deps)"
else
  fail "deny reason has no remedy line"
fi

# 2. blockers attest PASS -> must NOT deny
printf '{"status":"PASS","blockers":[]}\n' > "$P/.mega-sdd/.validation-blockers.json"
out="$(printf '%s' "$EB_JSON" | PATH="$NOPY" "$BASH_BIN" "$HOOKS/pre-tool-use" 2>/dev/null)"
if printf '%s' "$out" | grep -q '"permissionDecision": *"deny"'; then
  fail "PASS blockers were denied anyway (over-blocking)"
else
  pass "PASS blockers -> not denied"
fi

# 3. SessionStart surfaces the degradation
# NOTE: session-start reads the PROCESS cwd (`cwd="$(pwd)"`), not the JSON field —
# it must be invoked from inside the project for the SDD signal to fire at all.
SS_JSON="{\"session_id\":\"s\",\"cwd\":\"$P\",\"source\":\"startup\"}"
out="$(cd "$P" && printf '%s' "$SS_JSON" | PATH="$NOPY" "$BASH_BIN" "$HOOKS/session-start" 2>/dev/null)"
if printf '%s' "$out" | grep -q 'python3 yang bisa dipakai'; then
  pass "SessionStart emits the missing-interpreter notice"
else
  fail "SessionStart stayed silent about the missing interpreter"
fi
if printf '%s' "$out" | grep -q 'install-deps'; then
  pass "SessionStart notice carries the remedy"
else
  fail "SessionStart notice has no remedy"
fi

# 4. with a REAL python3 nothing changes — no false alarm
if command -v python3 >/dev/null 2>&1 && python3 -c 'print(1)' >/dev/null 2>&1; then
  out="$(cd "$P" && printf '%s' "$SS_JSON" | "$BASH_BIN" "$HOOKS/session-start" 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'python3 yang bisa dipakai'; then
    fail "false alarm: notice fired with a working python3"
  else
    pass "real python3 -> no notice (no false alarm)"
  fi
else
  echo "SKIP (no real python3 on this host to test the negative case)"
fi

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc

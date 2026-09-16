#!/usr/bin/env bash
# doc-audit v8 debt gate (spec 2026-09-16 §1 #12) — dead mechanism names must not be
# offered as advice by live code: `enrich-semantics` (no such command), `generate-intent
# --refresh` (no such flag), `run-hook.sh` (dispatcher gone) in scripts/*.sh, scripts/_lib/*.py,
# hooks/*; and the blackbox playground must not tell the user to type `/mega-sdd:auto`
# (typed legacy forms no longer register — the front door is `/mega-sdd`).
# A line that only records the removal (contains deleted / removed / retired / gone) is a
# history note, not advice, and is allowed. Every offender is printed as file:line.
#   a  enrich-semantics           absent from scripts + _lib + hooks
#   b  generate-intent --refresh  absent from scripts + _lib + hooks
#   c  run-hook.sh                absent from scripts + _lib + hooks
#   d  /mega-sdd:auto             absent from tests/blackbox/seed-playground.sh
# Run: bash tests/surface/test-dead-mechanism-names.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"
HISTORY='deleted|removed|retired|gone'

# every regular file in the three live-code sets (hooks/* is extensionless)
FILES=()
for f in "$P"/scripts/*.sh "$P"/scripts/_lib/*.py "$P"/hooks/*; do
  [ -f "$f" ] && FILES+=("$f")
done

# hits for one literal, minus history notes; prints offenders relative to the repo root
offenders() {
  grep -nHE -- "$1" "${FILES[@]}" 2>/dev/null | grep -viE -- "$HISTORY" | sed "s#^$ROOT/##" || true
}

check() {  # $1 = case letter, $2 = literal (ERE), $3 = human name
  local out; out="$(offenders "$2")"
  if [ -z "$out" ]; then
    pass "$1: \`$3\` absent from scripts/*.sh + scripts/_lib/*.py + hooks/* (history notes excepted)"
  else
    fail "$1: \`$3\` still offered by live code:"; printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

check a 'enrich-semantics' 'enrich-semantics'
check b 'generate-intent --refresh' 'generate-intent --refresh'
check c 'run-hook\.sh' 'run-hook.sh'

# d: the playground's next-step banner names the live front door, never the retired typed verb
SEED="$ROOT/tests/blackbox/seed-playground.sh"
out="$(grep -nH -- '/mega-sdd:auto' "$SEED" 2>/dev/null | sed "s#^$ROOT/##" || true)"
if [ -z "$out" ]; then
  pass "d: \`/mega-sdd:auto\` absent from tests/blackbox/seed-playground.sh"
else
  fail "d: \`/mega-sdd:auto\` still printed by seed-playground.sh:"; printf '%s\n' "$out" | sed 's/^/    /'
fi

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc

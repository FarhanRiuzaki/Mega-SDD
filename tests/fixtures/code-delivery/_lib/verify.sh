#!/usr/bin/env bash
# verify.sh — fixture verification for resolve-framework-pack.sh (Task 0).
#
# This is an INFRA helper (a resolver, not a defect-flagging validator), so the
# bad-FLAGS / good-PASSES contract is reinterpreted as:
#   good/ : a project whose starterkit-context.yaml declares framework_pack:
#           laravel-base-26.md (nested + .md-suffixed, mirroring production shape)
#           => resolver MUST print the real extends chain
#           "laravel-base-26.md laravel.md _universal.md" AND --section=naming
#           MUST return non-empty.
#   bad/  : a project with a .mega-sdd/ but NO manifest at all
#           => resolver MUST gracefully fall back to "_universal.md" (NOT error),
#           AND --section=<nonexistent> MUST print nothing + exit 3.
#
# Run: bash tests/fixtures/code-delivery/_lib/verify.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
RESOLVER="${REPO_ROOT}/plugins/mega-sdd/scripts/_lib/resolve-framework-pack.sh"
GOOD="$(cd "$(dirname "$0")/good" && pwd)"
BAD="$(cd "$(dirname "$0")/bad" && pwd)"

pass=0
fail=0
note() { echo "  $1"; }
ok()   { echo "PASS: $1"; pass=$((pass+1)); }
bad()  { echo "FAIL: $1"; fail=$((fail+1)); }

# --- Pre-flight: resolver must exist (Step 2 expects this to be absent first) ---
if [ ! -f "$RESOLVER" ]; then
  echo "FAIL: resolve-framework-pack.sh not found at $RESOLVER"
  exit 1
fi

# === GOOD case: full chain resolves ===
echo "=== GOOD fixture ($GOOD) ==="
chain="$(bash "$RESOLVER" --cwd="$GOOD" --quiet 2>/dev/null)"
chain_exit=$?
note "chain output: [$chain] (exit $chain_exit)"
if [ "$chain" = "laravel-base-26.md laravel.md _universal.md" ]; then
  ok "good: resolves chain most-specific-first"
else
  bad "good: expected 'laravel-base-26.md laravel.md _universal.md', got '$chain'"
fi
[ "$chain_exit" -eq 0 ] && ok "good: exit 0 on resolvable chain" || bad "good: expected exit 0, got $chain_exit"

# --section=naming must be non-empty (matches '## Naming standards' across chain)
naming="$(bash "$RESOLVER" --cwd="$GOOD" --section=naming 2>/dev/null)"
naming_exit=$?
note "naming section bytes: ${#naming} (exit $naming_exit)"
if [ -n "$naming" ] && [ "$naming_exit" -eq 0 ]; then
  ok "good: --section=naming returns non-empty (exit 0)"
else
  bad "good: --section=naming expected non-empty + exit 0, got ${#naming} bytes / exit $naming_exit"
fi

# Lock the MERGE contract: 'naming' is the one section present in all three
# packs, so it is the only probe that can verify "merged across chain, most-
# specific-first". Assert a laravel-base-26-unique token appears BEFORE a
# _universal-unique token => proves presence of both + most-specific-first order.
base26_line="$(printf '%s\n' "$naming" | grep -n 'make:controller-acl' | head -1 | cut -d: -f1)"
univ_line="$(printf '%s\n' "$naming" | grep -n 'is_active' | head -1 | cut -d: -f1)"
note "base26 marker @line ${base26_line:-none}, universal marker @line ${univ_line:-none}"
if [ -n "$base26_line" ] && [ -n "$univ_line" ] && [ "$base26_line" -lt "$univ_line" ]; then
  ok "good: --section merges all packs, most-specific-first (base26 before _universal)"
else
  bad "good: merge order broken — expected base26 marker before _universal marker (got ${base26_line:-none} vs ${univ_line:-none})"
fi

# === BAD case: no manifest => graceful _universal fallback, NOT an error ===
echo "=== BAD fixture ($BAD) ==="
fb="$(bash "$RESOLVER" --cwd="$BAD" --quiet 2>/dev/null)"
fb_exit=$?
note "fallback output: [$fb] (exit $fb_exit)"
if [ "$fb" = "_universal.md" ] && [ "$fb_exit" -eq 0 ]; then
  ok "bad: no manifest => falls back to _universal.md (exit 0, graceful)"
else
  bad "bad: expected '_universal.md' exit 0, got '$fb' exit $fb_exit"
fi

# --section=<nonexistent> => empty stdout + exit 3 (callers treat as SKIP)
absent="$(bash "$RESOLVER" --cwd="$GOOD" --section=no-such-section-xyz 2>/dev/null)"
absent_exit=$?
note "absent-section bytes: ${#absent} (exit $absent_exit)"
if [ -z "$absent" ] && [ "$absent_exit" -eq 3 ]; then
  ok "absent section => empty stdout + exit 3 (SKIP signal)"
else
  bad "absent section expected empty + exit 3, got ${#absent} bytes / exit $absent_exit"
fi

# --- strict arg parse: unknown arg => exit 2 ---
bash "$RESOLVER" --cwd="$GOOD" --bogus >/dev/null 2>&1
strict_exit=$?
[ "$strict_exit" -eq 2 ] && ok "unknown arg => exit 2 (strict parse)" \
  || bad "unknown arg expected exit 2, got $strict_exit"

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "SOME FAILED"; exit 1; }

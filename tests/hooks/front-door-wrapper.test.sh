#!/usr/bin/env bash
# front-door-wrapper.test.sh — scripts/install-front-door.sh contract (v5.2.5).
#
# The bare /mega-sdd verb can only exist as a standalone user-level command
# (Claude Code namespaces plugin commands as /mega-sdd:<command>), so the
# SessionStart hook ships ~/.claude/commands/mega-sdd.md via this installer.
# Contract under test:
#   1. fresh HOME → wrapper created with the version marker
#   2. re-run → no rewrite (idempotent; mtime stable)
#   3. user-authored file (no marker) → NEVER overwritten
#   4. --force → overwrites regardless
#   5. resolution is VERSION-AWARE (team feedback 2026-08, rec №2): the wrapper
#      must instruct picking the scope:"user" entry with the HIGHEST version —
#      never a blind [0] index (on machines with dormant installs, [0] resolved
#      to a stale 6.6.0 and the bare verb ran an old plugin)
#   6. an older-marker wrapper (v1) on disk → refreshed to the current version
#   7. PRODUCTION PATH (the standing lesson — pin the dispatch path, not the
#      body): the session-start hook's builtin debounce literal must match the
#      installer's WRAPPER_VERSION. Regression class: v7.5.1 bumped the
#      installer to v2 but left the hook checking "v1", so a v1 wrapper was
#      never upgraded through the debounced path. Proven by RUNNING the hook:
#      v1 wrapper → upgraded to current; current wrapper → untouched.
# All runs use a sandbox HOME — the real user HOME is never touched.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="${SCRIPT_DIR}/../../plugins/mega-sdd/scripts/install-front-door.sh"
[ -f "$INSTALLER" ] || { echo "FAIL: installer not found at $INSTALLER"; exit 1; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX"
TARGET="${HOME}/.claude/commands/mega-sdd.md"

fail() { echo "FAIL: $1"; exit 1; }

# 1 — fresh install
bash "$INSTALLER"
[ -f "$TARGET" ] || fail "fresh run did not create the wrapper"
grep -q "mega-sdd-front-door-wrapper v" "$TARGET" || fail "wrapper missing version marker"
grep -q '\$ARGUMENTS' "$TARGET" || fail "wrapper does not forward \$ARGUMENTS"

# 2 — idempotent re-run (mtime must not change)
if stat -f %m "$TARGET" >/dev/null 2>&1; then MTIME='stat -f %m'; else MTIME='stat -c %Y'; fi
m1=$($MTIME "$TARGET"); sleep 1; bash "$INSTALLER"; m2=$($MTIME "$TARGET")
[ "$m1" = "$m2" ] || fail "second run rewrote an up-to-date wrapper"

# 3 — user-authored file respected
echo "my own custom command" > "$TARGET"
bash "$INSTALLER"
[ "$(cat "$TARGET")" = "my own custom command" ] || fail "user-authored wrapper was overwritten"

# 4 — --force overwrites
bash "$INSTALLER" --force
grep -q "mega-sdd-front-door-wrapper v" "$TARGET" || fail "--force did not reinstall the managed wrapper"

# 5 — version-aware resolution instruction (never a blind [0] index)
grep -q 'scope: "user"' "$TARGET" \
  || fail "wrapper does not instruct scope:\"user\" selection"
grep -qi "version.*HIGHEST\|HIGHEST.*version" "$TARGET" \
  || fail "wrapper does not instruct highest-version selection"
grep -q "lastUpdated" "$TARGET" \
  || fail "wrapper has no tie-breaker instruction (lastUpdated)"
# Negative pin: the old buggy form — [0].installPath as THE resolution step.
grep -q '\[0\]\.installPath' "$TARGET" \
  && fail "wrapper still resolves via blind [0].installPath (stale-install bug)"

# 6 — an older-marker wrapper is refreshed to the current version
printf 'old body\n<!-- mega-sdd-front-door-wrapper v1 — managed -->\n' > "$TARGET"
bash "$INSTALLER"
grep -q "mega-sdd-front-door-wrapper v1" "$TARGET" \
  && fail "v1 wrapper was not refreshed"
grep -q "mega-sdd-front-door-wrapper v" "$TARGET" \
  || fail "refresh removed the managed marker entirely"

# 7 — production path: session-start's debounce upgrades a v1 wrapper
HOOK="${SCRIPT_DIR}/../../plugins/mega-sdd/hooks/session-start"
# 7a: static parity — the hook's literal names the installer's current version
WV=$(grep -m1 '^WRAPPER_VERSION=' "$INSTALLER" | tr -dc '0-9')
grep -q "mega-sdd-front-door-wrapper v${WV}\"\*) : ;;" "$HOOK" \
  || fail "session-start debounce literal is not v${WV} (drifted from WRAPPER_VERSION)"
# 7b: behavioral — run the HOOK (not the installer) against a v1 wrapper
printf 'old body\n<!-- mega-sdd-front-door-wrapper v1 — managed -->\n' > "$TARGET"
printf '{"session_id":"fdw","cwd":"%s","source":"startup"}' "$SANDBOX" \
  | bash "$HOOK" >/dev/null 2>&1 || true
grep -q "mega-sdd-front-door-wrapper v${WV}" "$TARGET" \
  || fail "session-start did not upgrade a v1 wrapper to v${WV} (production-path regression)"
# 7c: a current wrapper stays untouched (mtime stable through the hook)
m1=$($MTIME "$TARGET"); sleep 1
printf '{"session_id":"fdw","cwd":"%s","source":"startup"}' "$SANDBOX" \
  | bash "$HOOK" >/dev/null 2>&1 || true
m2=$($MTIME "$TARGET")
[ "$m1" = "$m2" ] || fail "session-start rewrote an up-to-date v${WV} wrapper (debounce broken)"

echo "OK: front-door wrapper installer honors create / idempotent / respect-user / force / version-aware / refresh / production-path parity"

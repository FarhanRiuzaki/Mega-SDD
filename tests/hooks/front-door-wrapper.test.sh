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

echo "OK: front-door wrapper installer honors create / idempotent / respect-user / force"

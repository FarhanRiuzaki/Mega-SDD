#!/usr/bin/env bash
# tests/blackbox/seed-playground.sh — instantiate a disposable mega-sdd playground.
#
# Seeds the blackbox fixture (leave-request mini-app: legacy PHP src + PRD) into
# a fresh git repo so a LIVE Claude Code session can exercise the real skills
# end-to-end (/mega-sdd:auto, scan-codebase, generate-intent, bind, bolts, ...).
#
# Usage: seed-playground.sh [target-dir] [--force]
#   target-dir  default /tmp/mega-sdd-playground
#   --force     wipe + reseed if the target already exists
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/fixture"
TARGET="${1:-/tmp/mega-sdd-playground}"
FORCE="no"
for a in "$@"; do [ "$a" = "--force" ] && FORCE="yes"; done
case "$TARGET" in --force) TARGET="/tmp/mega-sdd-playground";; esac

if [ -e "$TARGET" ]; then
  if [ "$FORCE" = "yes" ]; then
    rm -rf "$TARGET"
  else
    echo "FAIL: $TARGET already exists — pass --force to wipe + reseed." >&2
    exit 2
  fi
fi

mkdir -p "$TARGET"
cp -R "$FIX/src" "$TARGET/src"
cp -R "$FIX/docs" "$TARGET/docs"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.email=playground@mega-sdd -c user.name=playground commit -qm "chore: legacy baseline (mega-sdd playground seed)"

echo "PASS: playground seeded at $TARGET"
echo
echo "Next steps (live session):"
echo "  cd $TARGET"
echo "  # brownfield lane: /mega-sdd:auto  (detects legacy code, no PRD parse needed)"
echo "  # PRD lane:        /mega-sdd:auto docs/PRD-leave.md"
echo "  # disposable — rm -rf $TARGET when done, or reseed with --force"

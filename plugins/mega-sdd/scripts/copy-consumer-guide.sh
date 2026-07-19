#!/usr/bin/env bash
# copy-consumer-guide.sh — install the static AI consumer guide into a vault
# (P2a, spec 2026-07-19-batch2-derive-and-diet.md): <vault>/_meta/ai-consumer-guide.md
# is a SCRIPT-COPIED static artifact — the model never renders it (zero output
# tokens; identical across vaults; byte-identical to the shipped template).
#
# Source resolution uses the resolve-plugin-root.sh pattern (stale-cache
# hazard: a stale-version path leaked into a session must not serve an old
# guide). If the resolved root predates the guide (older cached version), fall
# back to THIS script's own plugin root — never fail on a lagging cache.
#
# Usage: copy-consumer-guide.sh --vault <dir>
# Exit: 0 = installed (idempotent — re-run overwrites with the same bytes);
#       2 = shipped guide not found under any root; 3 = usage / bad vault dir.
set -u

VAULT=""
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="${2:-}"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: copy-consumer-guide.sh --vault <dir>" >&2; exit 3; }
[ -d "$VAULT" ] || { echo "copy-consumer-guide: vault dir not found: $VAULT" >&2; exit 3; }

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
DERIVED_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REL="skills/generate-intent/references/templates/ai-consumer-guide.md"

PLUGIN_ROOT="$(bash "$SCRIPT_DIR/resolve-plugin-root.sh" "$DERIVED_ROOT" 2>/dev/null || true)"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED_ROOT"

SRC="$PLUGIN_ROOT/$REL"
# Lagging cache (resolved version predates the guide) → this script's own root.
[ -f "$SRC" ] || SRC="$DERIVED_ROOT/$REL"
[ -f "$SRC" ] || { echo "copy-consumer-guide: shipped guide missing: $REL" >&2; exit 2; }

DEST_DIR="$VAULT/_meta"
DEST="$DEST_DIR/ai-consumer-guide.md"
mkdir -p "$DEST_DIR" || { echo "copy-consumer-guide: cannot create $DEST_DIR" >&2; exit 3; }

# Atomic install (tmp + rename) — a crash never leaves a truncated guide.
TMP="$DEST.tmp.$$"
cp "$SRC" "$TMP" && mv -f "$TMP" "$DEST" || { rm -f "$TMP"; echo "copy-consumer-guide: copy failed" >&2; exit 3; }

echo "PASS: installed $DEST (static copy, byte-identical to shipped guide)"
exit 0

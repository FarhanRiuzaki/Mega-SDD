#!/usr/bin/env bash
# ground.sh — the v6 GROUND step: zero model tokens, seconds.
#   1. derive-state.sh   — probes (manifest sniff incl. the P2 pack matcher,
#                          spine, symbol-index freshness) -> .mega-sdd/state.json
#   2. build-symbol-index.sh — the retrieval substrate for bind --express
# GROUND deliberately does NOT: write starterkit-context.yaml (cache-keyed
# deep-scan artifact — a script stub would read as a false warm cache), or
# produce a codebase-map (scan-codebase stays the on-demand map seam).
# Exit 0 = grounded (index may still be honestly absent — see INDEX=);
# 2 = usage; derive-state failures pass through (read-only surface, never blocks).
set -u
CWD="."
while [ $# -gt 0 ]; do case "$1" in
  --cwd) CWD="$2"; shift 2;;
  --cwd=*) CWD="${1#*=}"; shift;;
  *) echo "usage: ground.sh [--cwd=<project-root>]" >&2; exit 2;;
esac; done
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

bash "$SCRIPT_DIR/derive-state.sh" --cwd="$CWD"
STATE_RC=$?

bash "$SCRIPT_DIR/build-symbol-index.sh" --cwd="$CWD"
IDX_RC=$?
case "$IDX_RC" in
  0) INDEX="built" ;;
  3) INDEX="absent (ast-grep not installed — bind --express will fall back to the standard lane)" ;;
  *) INDEX="absent (build failed rc=$IDX_RC — bind --express will fall back to the standard lane)" ;;
esac
echo "GROUND: state rc=$STATE_RC · index: $INDEX"
exit 0

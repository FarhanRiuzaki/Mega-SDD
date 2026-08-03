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

# Pre-init CWD: probes only, never mint .mega-sdd/ from a status view (the
# EB-GATE-6 phantom-root doctrine; round F10 — build-symbol-index would
# otherwise makedirs .mega-sdd/codebase/ and arm the dirty journal on a
# repo the user never adopted).
if [ ! -d "${CWD}/.mega-sdd" ]; then
  echo "GROUND: pre-init (no .mega-sdd/) — probes only, no artifacts minted"
  exit 0
fi

# Sync-pending guard (round F1 — REPRODUCED false 'in sync'): rebuilding the
# index HERE re-stamps head_commit to HEAD BEFORE derive-changed-paths.sh
# consumes the old stamp as its diff baseline — the changed set would derive
# empty and the sync would reconcile nothing. Defer; bind --express E0
# rebuilds AFTER the re-verdict, advancing the stamp at the correct point.
POSITION=$(python3 -c "
import json
try:
    print(json.load(open('${CWD}/.mega-sdd/state.json')).get('derived', {}).get('position', ''))
except Exception:
    print('')
" 2>/dev/null)
if [ "$POSITION" = "maintenance_sync" ]; then
  echo "GROUND: state rc=$STATE_RC · index: rebuild DEFERRED (sync pending — the stale stamp IS the changed-set baseline; bind --express E0 rebuilds after the re-verdict)"
  exit 0
fi

bash "$SCRIPT_DIR/build-symbol-index.sh" --cwd="$CWD"
IDX_RC=$?
case "$IDX_RC" in
  0) INDEX="built" ;;
  3) INDEX="absent (ast-grep not installed — the chain renders CLASSIC; /mega-sdd:install-deps adds ast-grep)" ;;
  *) INDEX="absent (build failed rc=$IDX_RC — the chain renders CLASSIC)" ;;
esac
echo "GROUND: state rc=$STATE_RC · index: $INDEX"
exit 0

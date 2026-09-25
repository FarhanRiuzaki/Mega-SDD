#!/usr/bin/env bash
# check-freshness.sh — the state-anchor freshness check, on demand (spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §5). Thin CLI over
# scripts/_lib/freshness.py: resolves the project root, runs the engine with the
# resolved interpreter, rewrites the per-worktree view cache in the git dir and
# prints the state block (HEAD sha + branch, FRESH/STALE per vault scope, the rule
# line). GROUND runs the same engine in its own python exec; this CLI is for a
# human or a skill that wants the view NOW.
#
#   check-freshness.sh [--cwd=<dir>]
#
# Always exits 0 (the view is advisory — the BOLTS gate is where freshness blocks).
set -u
CWD="."
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;;
  *) echo "usage: check-freshness.sh [--cwd=<dir>]" >&2; exit 0 ;;
esac; done
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CWD="$(cd "$CWD" 2>/dev/null && pwd)" || { echo "check-freshness: no such dir" >&2; exit 0; }
. "$SCRIPT_DIR/_lib/resolve-project-root.sh"
resolve_project_root "$CWD" >/dev/null
ROOT="${RPR_ROOT:-$CWD}"
. "$SCRIPT_DIR/_lib/resolve-python.sh"
if ! mega_sdd_python >/dev/null 2>&1; then
  echo "mega-sdd state · per-vault freshness unavailable on this machine (no usable python)."
  exit 0
fi
REL="${CWD#"$ROOT"}"; REL="${REL#/}"
# shellcheck disable=SC2086
PYTHONIOENCODING=utf-8 $MEGA_SDD_PY "$SCRIPT_DIR/_lib/freshness.py" --cwd="$ROOT" --print --cwd-rel="$REL" || true
exit 0

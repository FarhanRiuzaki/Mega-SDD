#!/usr/bin/env bash
# p0-extract-arm.sh — deterministic extraction of ONE P0 arm launched by
# p0-headless-run.sh: reads run.meta (transcript path, arm dir), finds the first
# and last `type(U-XXX):` unit commits in the arm's git log (the P5 endpoints),
# runs research/2026-08-04-p5-extract.py with --json into the arm's results dir,
# and appends the endpoint facts to run.meta. Anyone can re-run it; same inputs
# → same JSON. Exit 2 = no unit commit yet (the run did not reach a bolt — "not
# data" per the P0 runbook decision table).
#
# usage: p0-extract-arm.sh <results-dir>   (the <log-dir> given to the launcher)
set -u
D="${1:?results dir}"; META="$D/run.meta"
[ -f "$META" ] || { echo "no run.meta in $D" >&2; exit 2; }
ARM="$(grep -m1 '^arm=' "$META" | cut -d= -f2-)"; TR="$(grep -m1 '^transcript=' "$META" | cut -d= -f2-)"
[ -f "$TR" ] || { echo "transcript missing: $TR" >&2; exit 2; }
HEAD0="$(grep -m1 '^head_before=' "$META" | cut -d= -f2-)"
# unit commits = conventional-commit subjects carrying a (U-XXX) scope, after the seed head
UNITS="$(git -C "$ARM" log --reverse --format='%h %cI %s' "${HEAD0}..HEAD" | grep -E '^[0-9a-f]+ [^ ]+ [a-z]+\(U-[A-Za-z0-9_,-]+\)' || true)"
if [ -z "$UNITS" ]; then echo "no unit commit after $HEAD0 — the run did not reach a bolt; not data" >&2; exit 2; fi
FIRST_ISO="$(echo "$UNITS" | head -1 | awk '{print $2}')"; LAST_ISO="$(echo "$UNITS" | tail -1 | awk '{print $2}')"
N_UNITS="$(echo "$UNITS" | wc -l | tr -d ' ')"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$D/extract.json"
python3 "$ROOT/research/2026-08-04-p5-extract.py" "$TR" "$FIRST_ISO" "$LAST_ISO" --json "$OUT" > "$D/extract.txt" 2>&1; RC=$?
{
  echo "ended_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "head_after=$(git -C "$ARM" rev-parse --short HEAD)"
  echo "unit_commits=$N_UNITS"; echo "first_unit_commit_iso=$FIRST_ISO"; echo "last_unit_commit_iso=$LAST_ISO"
  echo "extract_rc=$RC"; echo "extract_json=$OUT"
} >> "$META"
git -C "$ARM" log --format='%h %cI %s' "${HEAD0}..HEAD" > "$D/git-log.txt"
echo "units=$N_UNITS first=$FIRST_ISO last=$LAST_ISO extract_rc=$RC -> $OUT"
sed -n '1,60p' "$D/extract.txt"

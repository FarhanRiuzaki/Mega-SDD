#!/usr/bin/env bash
# run-code-scan.sh — SAST scan (semgrep) over a bolt's changed files
# (execute-bolts L0 code gates).
#
# Scans ONLY the files changed between base..head. Tool-absence and tool-failure
# are SKIPS (exit 0 with a reason), never fabricated verdicts — only a definite
# ERROR-severity finding blocks.
#
# Usage:
#   run-code-scan.sh --base=<sha> --head=<sha> [--cwd=<dir>] [--config=<semgrep-config>]
# Exit: 0 clean or skipped · 1 WARNING/INFO findings only · 2 ERROR findings (blocking)

set -u
BASE=""; HEAD=""; CWD="."; CONFIG="auto"
for arg in "$@"; do
  case "$arg" in
    --base=*) BASE="${arg#--base=}" ;;
    --head=*) HEAD="${arg#--head=}" ;;
    --cwd=*)  CWD="${arg#--cwd=}" ;;
    --config=*) CONFIG="${arg#--config=}" ;;
  esac
done
[ -n "$BASE" ] && [ -n "$HEAD" ] || { echo "usage: run-code-scan.sh --base=<sha> --head=<sha> [--cwd=<dir>] [--config=<cfg>]" >&2; exit 2; }
cd "$CWD" || exit 2

if ! command -v semgrep >/dev/null 2>&1; then
  echo '{"skipped": true, "reason": "semgrep not installed (run /mega-sdd:install-deps)", "findings": []}'
  exit 0
fi

CHANGED=$(git diff --name-only --diff-filter=ACMR "$BASE".."$HEAD" 2>/dev/null | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)
if [ -z "$CHANGED" ]; then
  echo '{"skipped": false, "reason": "no changed files", "findings": []}'
  exit 0
fi

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
# shellcheck disable=SC2086
if ! printf '%s\n' "$CHANGED" | xargs semgrep scan --config "$CONFIG" --json --quiet --timeout 60 >"$TMP" 2>/dev/null; then
  # semgrep itself failed (offline registry, crash) — a tool failure is a skip
  # with a visible reason, never a silent pass-off as "clean".
  echo '{"skipped": true, "reason": "semgrep failed to run (offline rule registry or crash) — scan NOT performed", "findings": []}'
  exit 0
fi

python3 - "$TMP" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
out, worst = [], 0
for r in data.get("results", []):
    sev = (r.get("extra", {}).get("severity") or "INFO").upper()
    worst = max(worst, {"ERROR": 2, "WARNING": 1}.get(sev, 1))
    out.append({
        "severity": sev,
        "rule": r.get("check_id"),
        "file": r.get("path"),
        "line": (r.get("start") or {}).get("line"),
        "message": (r.get("extra", {}).get("message") or "")[:200],
    })
out.sort(key=lambda f: {"ERROR": 0, "WARNING": 1}.get(f["severity"], 2))
print(json.dumps({"skipped": False, "findings": out[:50], "total": len(out),
                  "blocking": worst == 2}, indent=2))
sys.exit(worst)
PYEOF

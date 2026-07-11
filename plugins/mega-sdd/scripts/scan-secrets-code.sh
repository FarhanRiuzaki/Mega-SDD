#!/usr/bin/env bash
# scan-secrets-code.sh — secret scan over a bolt's changed CODE
# (execute-bolts L0 code gates; complements secret-scan.sh, which scrubs
# scan ARTIFACTS — this one scans the diff the bolt is about to commit).
#
# Prefers gitleaks (offline, fast); falls back to the plugin's own
# provider-shaped regex set when gitleaks is absent — secrets are too critical
# for tool-absence to mean no scan at all.
#
# Usage:
#   scan-secrets-code.sh --base=<sha> --head=<sha> [--cwd=<dir>]
# Exit: 0 clean · 1 findings (blocking — a leaked secret never ships) · 2 bad invocation
# Output: JSON; secret values are NEVER echoed (6-char excerpt max).

set -u
BASE=""; HEAD=""; CWD="."
for arg in "$@"; do
  case "$arg" in
    --base=*) BASE="${arg#--base=}" ;;
    --head=*) HEAD="${arg#--head=}" ;;
    --cwd=*)  CWD="${arg#--cwd=}" ;;
  esac
done
[ -n "$BASE" ] && [ -n "$HEAD" ] || { echo "usage: scan-secrets-code.sh --base=<sha> --head=<sha> [--cwd=<dir>]" >&2; exit 2; }
cd "$CWD" || exit 2

GITLEAKS_RC=""
if command -v gitleaks >/dev/null 2>&1; then
  TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
  gitleaks detect --no-banner --redact --log-opts="$BASE..$HEAD" \
    --report-format json --report-path "$TMP" >/dev/null 2>&1
  rc=$?
  # S7-GATES-1: gitleaks exit semantics are 0 = clean, 1 = leaks, >=2 = RUNTIME
  # FAILURE (crash, incompatible CLI, bad log-opts on a shallow clone). The old
  # code dropped rc entirely: a crashed scanner left an empty report, which read
  # as findings=[] → exit 0 = "clean" — at the one gate that always runs and has
  # no override. A runtime failure now falls back to the plugin regex set (same
  # as gitleaks-absent: secrets are too critical for tool failure to mean no scan).
  if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
    python3 - "$TMP" "$rc" <<'PYEOF'
import json, sys
path, rc = sys.argv[1], int(sys.argv[2])
try:
    raw = json.load(open(path))
except Exception:
    raw = None
finds = [{"engine": "gitleaks", "rule": f.get("RuleID"), "file": f.get("File"),
          "line": f.get("StartLine")} for f in (raw or [])]
if rc == 1 and not finds:
    # gitleaks says leaks exist but the report is unreadable — never report clean
    finds = [{"engine": "gitleaks", "rule": "report-unreadable", "file": None, "line": None,
              "note": "gitleaks exited 1 (leaks found) but the report could not be parsed"}]
print(json.dumps({"engine": "gitleaks", "findings": finds, "total": len(finds)}, indent=2))
sys.exit(1 if finds else 0)
PYEOF
    exit $?
  fi
  GITLEAKS_RC="$rc"
  echo "WARN: gitleaks runtime failure (exit ${rc}) — falling back to the plugin regex secret scan" >&2
fi

# Fallback: plugin regex set over the changed files' HEAD content.
CHANGED=$(git diff --name-only --diff-filter=ACMR "$BASE".."$HEAD" 2>/dev/null | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)
GITLEAKS_RC="$GITLEAKS_RC" python3 - $CHANGED <<'PYEOF'
import json, os, re, sys

PATTERNS = [
    ("aws-access-key",      re.compile(r"AKIA[0-9A-Z]{16}")),
    ("private-key-block",   re.compile(r"-----BEGIN (?:RSA |EC |DSA |ED25519 |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY(?: BLOCK)?-----")),  # detection-only: header presence blocks; kind list matches secret-scan.sh
    ("github-token",        re.compile(r"gh[pousr]_[A-Za-z0-9]{36,}")),
    ("openai-style-key",    re.compile(r"sk-[A-Za-z0-9_-]{20,}")),
    ("slack-token",         re.compile(r"xox[bpoas]-[0-9A-Za-z-]{10,}")),
    ("jwt-shaped",          re.compile(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}")),
    ("generic-assignment",  re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*['\"]([^'\"]{8,})['\"]")),
]
findings = []
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for name, rx in PATTERNS:
        for m in rx.finditer(text):
            findings.append({"engine": "fallback-regex", "rule": name, "file": path,
                             "line": text.count("\n", 0, m.start()) + 1})
glrc = os.environ.get("GITLEAKS_RC", "")
note = ("gitleaks runtime failure (exit %s) — plugin regex fallback used; fix the gitleaks install for full coverage" % glrc) if glrc \
       else "gitleaks not installed — plugin regex fallback used (run /mega-sdd:install-deps for full coverage)"
print(json.dumps({"engine": "fallback-regex", "note": note,
                  "findings": findings, "total": len(findings)}, indent=2))
sys.exit(1 if findings else 0)
PYEOF

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

if command -v gitleaks >/dev/null 2>&1; then
  TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
  gitleaks detect --no-banner --redact --log-opts="$BASE..$HEAD" \
    --report-format json --report-path "$TMP" >/dev/null 2>&1
  rc=$?
  python3 - "$TMP" "$rc" <<'PYEOF'
import json, sys
path, rc = sys.argv[1], int(sys.argv[2])
try:
    raw = json.load(open(path))
except Exception:
    raw = []
finds = [{"engine": "gitleaks", "rule": f.get("RuleID"), "file": f.get("File"),
          "line": f.get("StartLine")} for f in (raw or [])]
print(json.dumps({"engine": "gitleaks", "findings": finds, "total": len(finds)}, indent=2))
sys.exit(1 if finds else 0)
PYEOF
  exit $?
fi

# Fallback: plugin regex set over the changed files' HEAD content.
CHANGED=$(git diff --name-only --diff-filter=ACMR "$BASE".."$HEAD" 2>/dev/null | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)
python3 - $CHANGED <<'PYEOF'
import json, re, sys

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
print(json.dumps({"engine": "fallback-regex",
                  "note": "gitleaks not installed — plugin regex fallback used (run /mega-sdd:install-deps for full coverage)",
                  "findings": findings, "total": len(findings)}, indent=2))
sys.exit(1 if findings else 0)
PYEOF

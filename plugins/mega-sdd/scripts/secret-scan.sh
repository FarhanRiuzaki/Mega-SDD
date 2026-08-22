#!/usr/bin/env bash
# secret-scan.sh — the ONE deterministic secrets script, two surfaces
# (v7 Fase 2 merge group 5 folded the former scan-secrets-code.sh in here):
#
#   ARTIFACT scrub (scan-codebase Step 10a gate): scans a file ABOUT TO BE
#   WRITTEN as a scan artifact (codebase-map.md, starterkit-context.yaml) for
#   credential-shaped values and redacts the VALUE in place as
#   [REDACTED-SECRET], keeping the surrounding row/line intact. It never
#   touches repo source files — only the artifact passed to it.
#
#   CODE-DIFF scan (execute-bolts L0 gate 3, --code): scans the diff a bolt is
#   about to commit — gitleaks preferred (offline, fast), plugin
#   provider-shaped regex fallback when gitleaks is absent or crashes (secrets
#   are too critical for tool absence/failure to mean no scan).
#
# Usage:
#   secret-scan.sh --check  <file>   # report matches as JSON lines; exit 0 = clean, 1 = matches
#   secret-scan.sh --redact <file>   # redact in place + print JSON report; exit 0 always (redaction applied)
#   secret-scan.sh --code --base=<sha> --head=<sha> [--cwd=<dir>]
#                                    # code-diff scan; exit 0 clean · 1 findings (BLOCKING) · 2 bad invocation
#   exit 2 on bad invocation. Secret values are NEVER echoed (6-char excerpt max).

set -u

MODE=""; TARGET=""; BASE=""; HEAD=""; CWD="."
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --redact) MODE="redact" ;;
    --code) MODE="code" ;;
    --base=*) BASE="${arg#--base=}" ;;
    --head=*) HEAD="${arg#--head=}" ;;
    --cwd=*)  CWD="${arg#--cwd=}" ;;
    *) TARGET="$arg" ;;
  esac
done

# ─── --code: bolt code-diff scan (merged verbatim from scan-secrets-code.sh) ─
if [ "$MODE" = "code" ]; then
[ -n "$BASE" ] && [ -n "$HEAD" ] || { echo "usage: secret-scan.sh --code --base=<sha> --head=<sha> [--cwd=<dir>]" >&2; exit 2; }
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
# S7-GATES-9: paths arrive via env (newline-separated), never argv — an unquoted
# $CHANGED word-split paths with spaces, and each half failed open() → the file
# was SILENTLY unscanned at the gate that promises "never unscanned".
# core.quotepath=off: git C-quotes non-ASCII names ("na\303\257ve.py") and the
# quoted literal fails isfile → silently skipped (review r2-2). A failed git diff
# (shallow clone, bad range — the same states that crash gitleaks into this
# fallback) must be a VISIBLE error, never a zero-file "clean" scan (review r1-5).
if ! CHANGED=$(git -c core.quotepath=off diff --name-only --diff-filter=ACMR "$BASE".."$HEAD" 2>&1); then
  echo "ERROR: git diff failed for ${BASE}..${HEAD} — the secret scan CANNOT run (${CHANGED})" >&2
  printf '{"engine": "fallback-regex", "skipped": true, "error": "git diff failed - revision range unresolvable", "findings": [], "total": 0}\n'
  exit 2
fi
CHANGED="$CHANGED" GITLEAKS_RC="$GITLEAKS_RC" python3 - <<'PYEOF'
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
for path in os.environ.get("CHANGED", "").split("\n"):
    # no strip(): a legit leading/trailing-space filename must stay scannable
    if not path or not os.path.isfile(path):
        continue
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
exit $?
fi

[ -n "$MODE" ] && [ -n "$TARGET" ] && [ -f "$TARGET" ] || { echo "usage: secret-scan.sh --check|--redact <file>" >&2; exit 2; }

python3 - "$MODE" "$TARGET" <<'PYEOF'
import json, os, stat, re, sys

mode, target = sys.argv[1], sys.argv[2]

# S3 AH-1: the private-key pattern must span the WHOLE block — the previous
# header-shaped regex ([^-]* self-terminates at the header's own dashes) redacted
# only the BEGIN line and shipped the base64 key body while reporting
# redacted:true. Whole-block first: the END kind must MATCH the BEGIN kind (\1)
# and the body may not cross into another BEGIN (a truncated block followed by a
# complete one must not swallow the innocent text between them). The header
# fallback catches a truncated block AND consumes its contiguous base64 body
# lines — a truncated key must not ship its body either.
_PK_KINDS = r"(?:RSA |EC |DSA |ED25519 |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY(?: BLOCK)?"
_PK_BODY_RUN = r"(?:\n[ \t\"',\\]*[A-Za-z0-9+/=]{16,}[ \t\"',\\]*)*"
PATTERNS = [
    ("aws-access-key",      re.compile(r"AKIA[0-9A-Z]{16}")),
    ("private-key-block",   re.compile(r"-----BEGIN (" + _PK_KINDS + r")-----(?:(?!-----BEGIN)[\s\S])*?-----END \1-----")),
    ("private-key-header",  re.compile(r"-----BEGIN " + _PK_KINDS + r"-----" + _PK_BODY_RUN)),
    ("github-token",        re.compile(r"gh[pousr]_[A-Za-z0-9]{36,}")),
    ("openai-style-key",    re.compile(r"sk-[A-Za-z0-9_-]{20,}")),
    ("slack-token",         re.compile(r"xox[bpoas]-[0-9A-Za-z-]{10,}")),
    ("jwt-shaped",          re.compile(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}")),
    ("generic-assignment",  re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*['\"]([^'\"]{8,})['\"]")),
]

text = open(target, encoding="utf-8", errors="replace").read()
findings, redacted = [], text
_pk_spans = []  # whole-block spans; a header inside one is already covered

for name, rx in PATTERNS:
    for m in rx.finditer(text):
        if name == "private-key-header" and any(s <= m.start() < e for s, e in _pk_spans):
            continue
        if name == "private-key-block":
            _pk_spans.append((m.start(), m.end()))
        line_no = text.count("\n", 0, m.start()) + 1
        secret = m.group(2) if name == "generic-assignment" and m.lastindex and m.lastindex >= 2 else m.group(0)
        findings.append({
            "pattern": name,
            "line": line_no,
            "excerpt": (secret[:6] + "…") if len(secret) > 6 else "…",  # never echo the full value
        })
        if mode == "redact":
            redacted = redacted.replace(secret, "[REDACTED-SECRET]")

if mode == "redact" and findings:
    _mode = stat.S_IMODE(os.stat(target).st_mode)
    open(target, "w", encoding="utf-8").write(redacted)
    os.chmod(target, _mode)  # redaction must not widen permissions (0600 stays 0600)

print(json.dumps({"file": target, "mode": mode, "findings": findings, "redacted": mode == "redact" and bool(findings)}, indent=2))
sys.exit(0 if (mode == "redact" or not findings) else 1)
PYEOF

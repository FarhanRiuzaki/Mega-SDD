#!/usr/bin/env bash
# secret-scan.sh — deterministic credential scrub for scan outputs
# (scan-codebase Step 10a gate; tech-agnostic — patterns are provider-shaped,
# not framework-shaped).
#
# Scans a file ABOUT TO BE WRITTEN as a scan artifact (codebase-map.md,
# starterkit-context.yaml) for credential-shaped values and redacts the VALUE
# in place as [REDACTED-SECRET], keeping the surrounding row/line intact.
# It never touches repo source files — only the artifact passed to it.
#
# Usage:
#   secret-scan.sh --check  <file>   # report matches as JSON lines; exit 0 = clean, 1 = matches
#   secret-scan.sh --redact <file>   # redact in place + print JSON report; exit 0 always (redaction applied)
#   exit 2 on bad invocation

set -u

MODE=""; TARGET=""
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --redact) MODE="redact" ;;
    *) TARGET="$arg" ;;
  esac
done
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

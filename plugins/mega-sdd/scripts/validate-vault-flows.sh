#!/usr/bin/env bash
# validate-vault-flows.sh — [HOOK-VALIDATE] Mermaid-mandate for vault 04-flows.md.
#
# Mermaid-flows hard rule (docs/superpowers/specs/2026-07-01-mermaid-flows-hard-rule.md):
# every generated flow is a Mermaid diagram. In a vault's 04-flows.md each
# `### F-<prefix>-NNN` flow entry MUST carry a ```mermaid fence (the flow body),
# not a prose numbered `Steps:` list. A prose-only flow → FAIL vault_flow_not_mermaid.
#
# Reuses the SAME syntax tokenizer + diagram-type check as validate-kb-flows.sh
# via _lib/mermaid_syntax.py (never fork the checker per surface). Emits the same
# JSON contract. Metadata lines (Actor/Trigger, DoD, Source) are flow attributes,
# not the flow — untouched.
#
# Usage: validate-vault-flows.sh --cwd=<project> --file-path=<04-flows.md> [--quiet]
# Output: <cwd>/.mega-sdd/.vault-flows-state.json
# Exit: 0=PASS/SKIP, 1=FAIL, 2=error
set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --file-path=*) FILE_PATH="${arg#--file-path=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.vault-flows-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"
RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$FILE_PATH" "$_LIB_DIR" <<'PYEOF'
import json, os, re, sys
cwd, file_path = sys.argv[1], sys.argv[2]
sys.path.insert(0, sys.argv[3])
try:
    from mermaid_syntax import (FENCE, extract_mermaid_blocks,
                                check_mermaid_syntax, check_diagram_type)
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": "cannot load mermaid_syntax lib: " + str(e)}))
    sys.exit(0)

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    sys.exit(0)

lines = content.split("\n")
checks = []
issues = []

# Locate each flow entry. Canonical headings are `### F-<prefix>-NNN`, but a flow
# heading that OMITS the F-prefix (`### User Login`) must NOT escape the Mermaid
# mandate — the pre-fix F-prefix-only regex silently skipped it, and a 04-flows.md
# whose headings ALL lack the prefix SKIP-PASSed wholesale (every flow escaped). In a
# 04-flows.md, EVERY level-3 `###` heading is a flow entry (structural sections are
# level-2 `##`), minus a small denylist. Non-flows files keep the strict F-prefix rule
# (defensive — callers only ever pass 04-flows.md).
_NON_FLOW_HEAD = re.compile(
    r"^(sources?|out[\s-]of[\s-]scope|open\s+questions?|notes?|legend|glossary|"
    r"definition\s+of\s+done|dod|changelog|references?|see\s+also|assumptions?|"
    r"non[\s-]goals?)\b", re.IGNORECASE)
if os.path.basename(file_path).endswith("04-flows.md"):
    _HEAD_RE = re.compile(r"^###\s+(.+?)\s*$", re.MULTILINE)
    heads = []
    for m in _HEAD_RE.finditer(content):
        label = m.group(1).strip()
        if _NON_FLOW_HEAD.match(label):
            continue
        fm = re.match(r"(F-[A-Za-z]+-\d+)\b", label)
        heads.append((fm.group(1) if fm else label[:48],
                      m.start(), content[:m.start()].count("\n") + 1))
else:
    FLOW_HEAD = re.compile(r"^###\s+(F-[A-Za-z]+-\d+)\b", re.MULTILINE)
    heads = [(m.group(1), m.start(), content[:m.start()].count("\n") + 1)
             for m in FLOW_HEAD.finditer(content)]

if not heads:
    checks.append({"check": "vault_flow_entries", "status": "SKIP",
                   "detail": "no flow entries found"})
    result = {"status": "PASS", "checked_file": os.path.relpath(file_path, cwd),
              "checks": checks, "issues": issues,
              "summary": "no vault flow entries to check"}
    print(json.dumps(result))
    sys.exit(0)

# Each flow body ends at the NEXT heading of level <= 3 (another `### F-`, a `###`
# subsection, a `## Section`, or a `# Title`) — NOT at EOF. Bounding only on the
# next `### F-` head let the LAST flow swallow the template's trailing
# `## Out of Scope` / `## Sources` sections (and any mermaid or N/A token in them).
HEADING = re.compile(r"^#{1,3}[ \t]", re.MULTILINE)

# N/A escape: a STANDALONE marker line (optionally prefixed `**Flow**:` / `Diagram:`)
# that explicitly declares no diagram — never a body-wide substring (which matched
# a prose sentence or a bled-in `## Out of Scope` heading). "out of scope" alone is
# NOT an escape: an out-of-scope flow must still say so on its own line.
NA_LINE = re.compile(
    r"^\s*(?:\*{0,2}(?:flow|diagram)\*{0,2}\s*:\s*)?"
    r"_?(?:n/?a|none(?:\s+detected)?|no\s+(?:flow\s+)?diagram(?:\s+for\s+this\s+flow)?)_?\s*$",
    re.IGNORECASE)

bounds = []
for fid, start, line_no in heads:
    head_line_end = content.find("\n", start)
    if head_line_end < 0:
        head_line_end = len(content)
    nxt = HEADING.search(content, head_line_end + 1)
    end = nxt.start() if nxt else len(content)
    bounds.append((fid, start, end, line_no))

flow_count = 0
mermaid_count = 0
for fid, start, end, line_no in bounds:
    flow_count += 1
    body = content[start:end]
    body_line_offset = content[:start].count("\n")
    # has_mermaid is derived from ACTUAL extracted blocks, not a substring — an
    # info-string / unterminated fence yields 0 blocks and must NOT count as a diagram.
    blocks_local = extract_mermaid_blocks(body)
    if blocks_local:
        mermaid_count += 1
        blocks = []
        for bs, be, blk in blocks_local:
            adj = [(ln + body_line_offset, l) for ln, l in blk]
            blocks.append((bs + body_line_offset, be + body_line_offset, adj))
        flow_issues = check_diagram_type(blocks, fid) + check_mermaid_syntax(blocks, fid)
        for it in flow_issues:
            it.setdefault("flow_id", fid)
        issues.extend(flow_issues)
    elif any(NA_LINE.match(ln) for ln in body.splitlines()):
        # explicit non-diagram flow — allowed
        continue
    else:
        issues.append({
            "halt_type": "vault_flow_not_mermaid",
            "flow_id": fid,
            "line_number": line_no,
            "detail": (f"flow {fid} has no {FENCE}mermaid diagram — the flow body must be a "
                       "Mermaid diagram, not a prose Steps list (Mermaid-flows hard rule)"),
            "suggested_fix": (f"replace {fid}'s numbered Steps with a {FENCE}mermaid flowchart "
                              "(keep Actor/DoD/Source); see references/mermaid-emission-rules.md"),
        })

has_fail = bool(issues)
checks.append({
    "check": "vault_flow_mermaid_mandate",
    "status": "FAIL" if has_fail else "PASS",
    "detail": f"{mermaid_count}/{flow_count} flow entries carry a Mermaid diagram",
})
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "checks": checks,
    "issues": issues,
    "summary": (f"{len(issues)} vault-flow issue(s) — see issues[] for flow_id + line + fix"
                if issues else f"all {flow_count} vault flow(s) are Mermaid; syntax checks pass"),
}
print(json.dumps(result))
PYEOF
)

echo "$RESULT" > "$STATE_FILE" 2>/dev/null || true
[ "$QUIET" -eq 0 ] && echo "$RESULT"

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac

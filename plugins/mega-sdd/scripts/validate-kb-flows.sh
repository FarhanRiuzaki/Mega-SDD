#!/usr/bin/env bash
# validate-kb-flows.sh — [HOOK-VALIDATE] Mermaid-consistency + syntax for KB flow sections.
#
# Checks §3 Flow and §8 State Machine:
#   v1 (Iter 67/68): mermaid fence present
#   v2 (Iter 72+):    heuristic Mermaid SYNTAX checks per
#                     plugins/mega-sdd/references/mermaid-emission-rules.md
#
# v2 anti-pattern detection (heuristic, no extra deps):
#   - Unquoted node text containing comma/paren/colon/pipe inside shape brackets
#   - Literal `\n` inside node text (should be `<br/>`)
#   - Actual newline inside `[...]` / `(...)` shape (multi-line node spec)
#
# Not detected (Fork-B-future, deferred to Iter 73+):
#   - Full Mermaid parser via `mmdc` (npx @mermaid-js/mermaid-cli) — adds node/npx dep
#
# Failure verdicts: tier C2 (producer must rewrite); NEVER auto-rewrites Mermaid
# content (semantic-change risk per mermaid-emission-rules.md).
#
# Usage: validate-kb-flows.sh --cwd=<project> --file-path=<kb-file.md> [--quiet]
# Output: <cwd>/.mega-sdd/.kb-flows-state.json
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
# Resolve project root (Iter 71 — class-bug fix: if invoked from a sub-folder
# like .mega-sdd/knowledge-base/, walk UP to the outermost .mega-sdd/ parent
# so state files land in the canonical location, not nested .mega-sdd/.mega-sdd/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi


if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.kb-flows-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

# Run validator as a standalone Python script to avoid heredoc backtick issues.
# The Mermaid Rule 1-3 syntax tokenizer lives in _lib/mermaid_syntax.py — the
# single source of truth shared with validate-vault-flows.sh (never fork it).
_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"
RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$FILE_PATH" "$_LIB_DIR" <<'PYEOF'
import json, os, re, sys

cwd = sys.argv[1]
file_path = sys.argv[2]
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

checks = []
issues = []
advisories = []   # v3.71.0+ semantic-depth: non-blocking signals (never flip status)
lines = content.split("\n")

# ──────────────────────────────────────────────────────────────────────────
# §3 Flow section
# ──────────────────────────────────────────────────────────────────────────
sec3_match = re.search(r"^## 3\.\s", content, re.MULTILINE)
if sec3_match:
    sec3_end_m = re.search(r"^## [4-9]\.", content[sec3_match.end():], re.MULTILINE)
    sec3_text = content[sec3_match.start():sec3_match.end() + sec3_end_m.start()] if sec3_end_m else content[sec3_match.start():]
    # Compute line offset (1-based) of sec3 within full content
    sec3_line_offset = content[:sec3_match.start()].count("\n")  # 0-based offset of sec3 start

    mermaid_fence = FENCE + "mermaid"
    has_mermaid = mermaid_fence.lower() in sec3_text.lower()
    has_none = bool(re.search(r"_None detected|N/A", sec3_text))

    if has_mermaid:
        checks.append({"check": "sec3_flow_mermaid_fence", "status": "PASS", "detail": "has Mermaid fence"})
        # Now run v2 syntax check on the section
        sec3_blocks_local = extract_mermaid_blocks(sec3_text)
        # Adjust line numbers to be relative to whole file
        sec3_blocks = []
        for bs, be, body in sec3_blocks_local:
            adj_body = [(ln + sec3_line_offset, line) for ln, line in body]
            sec3_blocks.append((bs + sec3_line_offset, be + sec3_line_offset, adj_body))
        sec3_syntax_issues = (check_diagram_type(sec3_blocks, "3")
                              + check_mermaid_syntax(sec3_blocks, "3"))
        if sec3_syntax_issues:
            checks.append({"check": "sec3_mermaid_syntax", "status": "FAIL",
                          "detail": f"{len(sec3_syntax_issues)} heuristic syntax issue(s) per mermaid-emission-rules.md"})
            issues.extend(sec3_syntax_issues)
        else:
            checks.append({"check": "sec3_mermaid_syntax", "status": "PASS",
                          "detail": "no heuristic syntax issues detected"})
    elif has_none:
        checks.append({"check": "sec3_flow_mermaid_fence", "status": "SKIP", "detail": "marked N/A"})
    else:
        has_ascii = bool(re.search(r"-->|->|flowchart|graph\s", sec3_text))
        if has_ascii:
            issues.append({"halt_type": "kb_flow_not_mermaid", "section": "3",
                          "detail": "flow content not in " + FENCE + "mermaid fence"})
            checks.append({"check": "sec3_flow_mermaid_fence", "status": "FAIL",
                          "detail": "has flow arrows but not in mermaid fence"})
        else:
            issues.append({"halt_type": "kb_flow_missing", "section": "3",
                          "detail": "no diagram found"})
            checks.append({"check": "sec3_flow_mermaid_fence", "status": "FAIL", "detail": "no flow diagram"})
else:
    checks.append({"check": "sec3_flow_mermaid_fence", "status": "SKIP", "detail": "no section 3"})

# ──────────────────────────────────────────────────────────────────────────
# §8 State Machine section
# ──────────────────────────────────────────────────────────────────────────
sec8_match = re.search(r"^## 8\.\s", content, re.MULTILINE)
if sec8_match:
    sec8_end_m = re.search(r"^## 9\.", content[sec8_match.end():], re.MULTILINE)
    sec8_text = content[sec8_match.start():sec8_match.end() + sec8_end_m.start()] if sec8_end_m else content[sec8_match.start():]
    sec8_line_offset = content[:sec8_match.start()].count("\n")

    has_na = bool(re.search(r"N/A|not a workflow|_N/A", sec8_text, re.IGNORECASE))
    mermaid_fence = FENCE + "mermaid"
    has_mermaid = mermaid_fence.lower() in sec8_text.lower()
    has_transitions = bool(re.search(r"--.*-->|--.*->", sec8_text))

    # Check has_mermaid FIRST (mirror §3): a valid mermaid stateDiagram whose node
    # text happens to contain an "N/A" / "not a workflow" token must be syntax-checked,
    # not SKIP'd. Only fall to the N/A SKIP when there is no fence.
    if has_mermaid:
        checks.append({"check": "sec8_state_machine_fence", "status": "PASS", "detail": "has Mermaid state diagram"})
        sec8_blocks_local = extract_mermaid_blocks(sec8_text)
        sec8_blocks = []
        for bs, be, body in sec8_blocks_local:
            adj_body = [(ln + sec8_line_offset, line) for ln, line in body]
            sec8_blocks.append((bs + sec8_line_offset, be + sec8_line_offset, adj_body))
        sec8_syntax_issues = (check_diagram_type(sec8_blocks, "8")
                              + check_mermaid_syntax(sec8_blocks, "8"))
        if sec8_syntax_issues:
            checks.append({"check": "sec8_mermaid_syntax", "status": "FAIL",
                          "detail": f"{len(sec8_syntax_issues)} heuristic syntax issue(s) per mermaid-emission-rules.md"})
            issues.extend(sec8_syntax_issues)
        else:
            checks.append({"check": "sec8_mermaid_syntax", "status": "PASS",
                          "detail": "no heuristic syntax issues detected"})
    elif has_na:
        checks.append({"check": "sec8_state_machine_fence", "status": "SKIP", "detail": "N/A"})
    elif has_transitions:
        # Mermaid-flows hard rule (2026-07-01 spec; subsumes god-review L7):
        # a non-N/A §8 with transition arrows but no ```mermaid fence is a
        # prose/ASCII flow — FAIL like §3, not the old silent "consider a fence" PASS.
        issues.append({"halt_type": "kb_flow_not_mermaid", "section": "8",
                       "detail": "state transitions not in " + FENCE + "mermaid fence"})
        checks.append({"check": "sec8_state_machine_fence", "status": "FAIL",
                       "detail": "has state transitions but not in mermaid fence"})
    else:
        issues.append({"halt_type": "kb_state_machine_missing", "section": "8",
                       "detail": "non-N/A but no state diagram"})
        checks.append({"check": "sec8_state_machine_fence", "status": "FAIL", "detail": "no state diagram"})
else:
    checks.append({"check": "sec8_state_machine_fence", "status": "SKIP", "detail": "no section 8"})

# ──────────────────────────────────────────────────────────────────────────
# Staged-input advisory (v3.71.0+, semantic-depth) — ADVISORY ONLY.
# Flags a workflow KB file that looks multi-step (workflow flow signal OR
# >5 inputs) but carries no `## 3a` stages: block. NEVER flips status (rides a
# separate advisories[] channel per the Iter-78.1 invariant). Pairs with the
# extract-intelligence §3a staged-input detection guidance; points the user to
# enrich-semantics. See knowledge-base-schema.md §3a.
# ──────────────────────────────────────────────────────────────────────────
def _frontmatter(text):
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    return m.group(1) if m else ""

_fm = _frontmatter(content)
_classification = ""
_mfm = re.search(r"^classification:\s*([A-Za-z_-]+)", _fm, re.MULTILINE)
if _mfm:
    _classification = _mfm.group(1).strip().lower()

# §8 present and non-N/A is itself a workflow signal when frontmatter is silent
_sec8_is_workflow = False
if sec8_match:
    _sec8_head = content[sec8_match.start():sec8_match.start() + 400]
    _sec8_is_workflow = not bool(re.search(r"N/A|not a workflow", _sec8_head, re.IGNORECASE))
_is_workflow = (_classification == "workflow") or _sec8_is_workflow

# stages: block present? require BOTH the `stages:` line AND a `stage_id:` token
# (robust vs prose that merely mentions the word "stages").
_has_stages_block = bool(re.search(r"^\s*stages:\s*$", content, re.MULTILINE)) and ("stage_id:" in content)

# multi-step signal — reuse the operator-surface closed grammar (decision verbs)
_decision_re = re.compile(r"\b(approve|reject|review|confirm|verify|authorize|endorse)\b", re.IGNORECASE)
_transition_lines = [ln for ln in lines if ("-->" in ln or "->" in ln)]
_decision_transitions = sum(1 for ln in _transition_lines if _decision_re.search(ln))
_maker_checker = bool(re.search(r"\bmaker\b.{0,80}\b(checker|approver|reviewer|confirmer)\b",
                                content, re.IGNORECASE | re.DOTALL))

# §4 Inputs list-item count
_input_field_count = 0
_sec4_m = re.search(r"^## 4\.\s", content, re.MULTILINE)
if _sec4_m:
    _sec4_end = re.search(r"^## 5\.", content[_sec4_m.end():], re.MULTILINE)
    _sec4_text = (content[_sec4_m.start(): _sec4_m.end() + _sec4_end.start()]
                  if _sec4_end else content[_sec4_m.start():])
    _input_field_count = (len(re.findall(r"^\s*[-*]\s+\S", _sec4_text, re.MULTILINE))
                          + len(re.findall(r"^\s*\d+\.\s+\S", _sec4_text, re.MULTILINE)))

_multistep = _is_workflow and (_decision_transitions >= 2 or _maker_checker or _input_field_count > 5)

if _multistep and not _has_stages_block:
    _reasons = []
    if _decision_transitions >= 2:
        _reasons.append(f"{_decision_transitions} decision transitions")
    if _maker_checker:
        _reasons.append("maker->checker hand-off")
    if _input_field_count > 5:
        _reasons.append(f"{_input_field_count} input fields")
    advisories.append({
        "halt_type": "kb_flow_staging_missing",
        "severity": "advisory",
        "section": "3a",
        "detail": ("workflow looks multi-step (" + "; ".join(_reasons) +
                   ") but carries no `## 3a` stages: block — staging may be lost downstream "
                   "(single-form bolt instead of multi-step wizard)"),
        "suggested_fix": ("author the `## 3a. Staged inputs` stages: block (knowledge-base-schema.md §3a), "
                          "or retro-fit via `enrich-semantics --vault=<vault> "
                          "--legacy-root=<legacy> --semantic=staged-input`"),
    })

has_fail = any(c["status"] == "FAIL" for c in checks)
_summary = (
    f"{len(issues)} flow format/syntax issue(s) — see issues[] for line numbers + suggested fixes"
    if issues else "all flows use Mermaid; heuristic syntax checks pass"
)
if advisories:
    _summary += f" | {len(advisories)} staging advisory(ies) — run enrich-semantics"
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "checks": checks,
    "issues": issues,
    "advisories": advisories,   # v3.71.0+ semantic-depth — non-blocking
    "summary": _summary,
    "next_action": (
        "Advisory: workflow looks multi-step but has no stages: block. Run enrich-semantics to retro-fit staging."
        if advisories else None
    ),
}
print(json.dumps(result))
PYEOF
)

echo "$RESULT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null

if [ "$QUIET" -eq 0 ]; then echo "$RESULT"; fi

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac

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

# Run validator as a standalone Python script to avoid heredoc backtick issues
RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$FILE_PATH" <<'PYEOF'
import json, os, re, sys

cwd = sys.argv[1]
file_path = sys.argv[2]
FENCE = chr(96) * 3  # triple backtick — avoid literal in bash $() heredoc

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    sys.exit(0)

checks = []
issues = []
lines = content.split("\n")

# ──────────────────────────────────────────────────────────────────────────
# Helper: extract all ```mermaid ... ``` blocks with their starting line numbers
# ──────────────────────────────────────────────────────────────────────────
def extract_mermaid_blocks(text):
    """Returns list of (start_line_1based, end_line_1based, body_lines)."""
    blocks = []
    in_block = False
    block_start = None
    block_lines = []
    for i, line in enumerate(text.split("\n"), start=1):
        stripped = line.strip()
        if not in_block:
            # Match ```mermaid (with possible leading whitespace), case-insensitive
            if re.match(r"^" + re.escape(FENCE) + r"\s*mermaid\s*$", stripped, re.IGNORECASE):
                in_block = True
                block_start = i
                block_lines = []
        else:
            if stripped.startswith(FENCE):
                blocks.append((block_start, i, block_lines))
                in_block = False
                block_start = None
                block_lines = []
            else:
                block_lines.append((i, line))
    return blocks

# ──────────────────────────────────────────────────────────────────────────
# Heuristic Mermaid syntax checker (v2 — Iter 72+)
# Returns list of issue dicts.
#
# Strategy: stateful tokenizer that respects quoted strings — naive regex
# fails on cases like PRE(["text with (parens, commas)"]) because the
# inner ) terminates a `[^)]*` content class. Tokenizer walks each line
# char-by-char, tracks in-quote state, only matches shape-close when not
# in a quote.
# ──────────────────────────────────────────────────────────────────────────
def check_mermaid_syntax(blocks, section):
    section_issues = []

    # Lines we IGNORE inside mermaid blocks (declarations, styling, control)
    SKIP_LINE_PREFIXES = (
        "flowchart", "graph", "stateDiagram", "sequenceDiagram",
        "classDiagram", "erDiagram", "gantt", "journey", "pie", "gitGraph",
        "style ", "classDef ", "linkStyle ", "subgraph ", "end",
        "direction ", "%%",  # comment
    )

    # Shape pairs — two-char tried before one-char (longest-first)
    TWO_CHAR_SHAPES = [
        ("[(", ")]"),    # cylinder
        ("([", "])"),    # stadium
        ("((", "))"),    # circle
        ("[[", "]]"),    # subroutine
        ("{{", "}}"),    # hexagon
        ("[/", "/]"),    # parallelogram
        ("[\\", "\\]"),  # parallelogram_alt
    ]
    ONE_CHAR_SHAPES = [
        ("(", ")"),
        ("[", "]"),
        ("{", "}"),
        (">", "]"),      # flag — asymmetric: open `>`, close `]`
    ]
    ALL_SHAPES = TWO_CHAR_SHAPES + ONE_CHAR_SHAPES

    DANGEROUS_CHARS = set(",():|")  # require quoting inside node text

    def is_quoted_strictly(s):
        s = s.strip()
        return len(s) >= 2 and s.startswith('"') and s.endswith('"')

    def is_simple_identifier(s):
        """No special chars beyond letters/digits/space/dash/underscore."""
        return bool(re.match(r"^[A-Za-z0-9_\-\s]+$", s.strip()))

    def find_node_specs(line):
        """Walk the line, return list of (node_id, shape_open, content_raw,
        shape_close, span_start, span_end) tuples — respects quoted strings."""
        results = []
        i = 0
        n = len(line)
        while i < n:
            # Find next identifier candidate
            m = re.match(r"[A-Za-z][A-Za-z0-9_]*", line[i:])
            if not m:
                i += 1
                continue
            node_id = m.group(0)
            id_end = i + len(node_id)
            # Identifier must be followed by a shape-open. Try longest first.
            rest = line[id_end:]
            shape_open = None
            shape_close = None
            for so, sc in ALL_SHAPES:
                if rest.startswith(so):
                    shape_open = so
                    shape_close = sc
                    break
            if not shape_open:
                i = id_end
                continue
            content_start = id_end + len(shape_open)
            # Walk content respecting quoted strings until we hit shape_close
            j = content_start
            in_quote = False
            content_end = -1
            while j < n:
                c = line[j]
                if c == "\\" and j + 1 < n:
                    j += 2
                    continue
                if c == '"':
                    in_quote = not in_quote
                    j += 1
                    continue
                if not in_quote and line[j:j + len(shape_close)] == shape_close:
                    content_end = j
                    break
                j += 1
            if content_end < 0:
                # No matching close on this line — skip this candidate
                i = id_end
                continue
            content_raw = line[content_start:content_end]
            span_end = content_end + len(shape_close)
            results.append((node_id, shape_open, content_raw, shape_close,
                            i, span_end))
            i = span_end
        return results

    for block_start, block_end, body in blocks:
        for line_num, line in body:
            stripped = line.strip()
            if not stripped:
                continue
            if any(stripped.lower().startswith(p.lower()) for p in SKIP_LINE_PREFIXES):
                continue

            # Rule 2: literal \n inside any quoted segment on the line
            # Find all `"..."` segments and check each for backslash-n.
            for qm in re.finditer(r'"([^"\\]|\\.)*"', line):
                segment = qm.group(0)
                if "\\n" in segment:
                    section_issues.append({
                        "halt_type": "mermaid_syntax_invalid",
                        "section": section,
                        "line_number": line_num,
                        "rule_violated": "Rule 2 — literal \\n in node text",
                        "excerpt": stripped[:120],
                        "suggested_fix": "replace literal `\\n` with `<br/>` (HTML line break)",
                    })

            # Rule 1+2+3: walk node specs found on this line
            for node_id, so, content_raw, sc, _, _ in find_node_specs(line):
                content = content_raw
                if not content.strip():
                    continue
                # Fully quoted → producer-compliant; skip Rule 1 check
                # (still check Rule 2 inside the quoted segment loop above)
                if is_quoted_strictly(content):
                    continue
                # Simple identifier → Mermaid accepts without quoting (Rule 1
                # recommends quoting always, but we don't fail on plain words)
                if is_simple_identifier(content):
                    continue
                # Rule 2 in unquoted content: literal `\n` anywhere
                if "\\n" in content:
                    suggested_2 = f'{node_id}{so}"{content.replace(chr(92) + "n", "<br/>").strip()}"{sc}'
                    section_issues.append({
                        "halt_type": "mermaid_syntax_invalid",
                        "section": section,
                        "line_number": line_num,
                        "node_id": node_id,
                        "rule_violated": "Rule 2 — literal \\n in unquoted node text",
                        "excerpt": stripped[:120],
                        "suggested_fix": f"replace `\\n` with `<br/>` and wrap in quotes: {suggested_2[:150]}",
                    })
                # Rule 1: has dangerous chars in unquoted text → FAIL
                hits = sorted(set(c for c in content if c in DANGEROUS_CHARS))
                if hits:
                    suggested = f'{node_id}{so}"{content.strip()}"{sc}'
                    section_issues.append({
                        "halt_type": "mermaid_syntax_invalid",
                        "section": section,
                        "line_number": line_num,
                        "node_id": node_id,
                        "rule_violated": "Rule 1 — unquoted text with special chars (" + "".join(hits) + ")",
                        "excerpt": stripped[:120],
                        "suggested_fix": f"wrap node text in double quotes: {suggested[:150]}",
                    })
                # Rule 3: embedded unescaped " (when not fully quoted)
                inner_quotes = [k for k, ch in enumerate(content) if ch == '"']
                if len(inner_quotes) >= 2 and not is_quoted_strictly(content):
                    section_issues.append({
                        "halt_type": "mermaid_syntax_invalid",
                        "section": section,
                        "line_number": line_num,
                        "node_id": node_id,
                        "rule_violated": "Rule 3 — multiple unescaped \" in node text",
                        "excerpt": stripped[:120],
                        "suggested_fix": 'escape embedded quotes with &quot; or #quot;',
                    })

    return section_issues

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
        sec3_syntax_issues = check_mermaid_syntax(sec3_blocks, "3")
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

    if has_na:
        checks.append({"check": "sec8_state_machine_fence", "status": "SKIP", "detail": "N/A"})
    elif has_mermaid:
        checks.append({"check": "sec8_state_machine_fence", "status": "PASS", "detail": "has Mermaid state diagram"})
        sec8_blocks_local = extract_mermaid_blocks(sec8_text)
        sec8_blocks = []
        for bs, be, body in sec8_blocks_local:
            adj_body = [(ln + sec8_line_offset, line) for ln, line in body]
            sec8_blocks.append((bs + sec8_line_offset, be + sec8_line_offset, adj_body))
        sec8_syntax_issues = check_mermaid_syntax(sec8_blocks, "8")
        if sec8_syntax_issues:
            checks.append({"check": "sec8_mermaid_syntax", "status": "FAIL",
                          "detail": f"{len(sec8_syntax_issues)} heuristic syntax issue(s) per mermaid-emission-rules.md"})
            issues.extend(sec8_syntax_issues)
        else:
            checks.append({"check": "sec8_mermaid_syntax", "status": "PASS",
                          "detail": "no heuristic syntax issues detected"})
    elif has_transitions:
        checks.append({"check": "sec8_state_machine_fence", "status": "PASS",
                       "detail": "has state transitions (consider mermaid fence for consistency)"})
    else:
        issues.append({"halt_type": "kb_state_machine_missing", "section": "8",
                       "detail": "non-N/A but no state diagram"})
        checks.append({"check": "sec8_state_machine_fence", "status": "FAIL", "detail": "no state diagram"})
else:
    checks.append({"check": "sec8_state_machine_fence", "status": "SKIP", "detail": "no section 8"})

has_fail = any(c["status"] == "FAIL" for c in checks)
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "checks": checks,
    "issues": issues,
    "summary": (
        f"{len(issues)} flow format/syntax issue(s) — see issues[] for line numbers + suggested fixes"
        if issues else "all flows use Mermaid; heuristic syntax checks pass"
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

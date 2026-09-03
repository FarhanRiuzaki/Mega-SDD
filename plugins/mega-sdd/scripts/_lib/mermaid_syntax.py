"""Shared Mermaid Rule 1-3 syntax tokenizer for flow validators.

Single source of truth for the heuristic Mermaid syntax checks enforced by
plugins/mega-sdd/references/mermaid-emission-rules.md (Rule 1 quote node text,
Rule 2 <br/> not literal backslash-n, Rule 3 escape embedded quotes). No
external deps. Imported by:
  - validate-kb.sh --surface=flows       (KB §3 Flow + §8 State Machine)
  - validate-kb.sh --surface=vault-flows (vault 04-flows.md F-xxx flows)

Extracted verbatim from the KB flows validator so both KB and vault flow gates
apply IDENTICAL syntax rules — never fork the tokenizer per surface (that is the
one-codebase-divergence class the god-review repeatedly flags).

Public API:
  FENCE                                 -> triple-backtick string
  extract_mermaid_blocks(text)          -> [(start_line, end_line, [(lineno, line)...])]
  check_mermaid_syntax(blocks, section) -> [issue dict, ...]   (Rule 1-3 node-text)
  check_diagram_type(blocks, section)   -> [issue dict, ...]   (Rule 0 structural)
"""
import re

FENCE = chr(96) * 3  # triple backtick — avoid literal in bash $() heredoc

# Mermaid diagram-type declarations. A ```mermaid block whose first meaningful
# line is not one of these does not render — mermaid raises "No diagram type
# detected". Ground-truthed against mermaid.parse(); this is the single most
# common render-breaker the Rule 1-3 tokenizer alone does NOT catch (a header-less
# edge fragment or a `[placeholder]` passes the quoting checks but never renders).
# CASE-SENSITIVE: mermaid's grammar rejects `Flowchart`/`FLOWCHART` ("No diagram
# type detected") — only the exact casing renders. Ground-truthed via mermaid.parse().
RECOGNIZED_DIAGRAM_TYPES = (
    "flowchart", "flowchart-elk", "graph", "sequenceDiagram", "classDiagram",
    "classDiagram-v2", "stateDiagram-v2", "stateDiagram", "erDiagram",
    "journey", "gantt", "pie", "gitGraph", "mindmap", "timeline",
    "quadrantChart", "requirementDiagram", "requirement", "sankey-beta",
    "sankey", "xychart-beta", "block-beta", "block", "packet-beta", "packet",
    "architecture-beta", "architecture", "C4Context", "C4Container",
    "C4Component", "C4Dynamic", "C4Deployment", "zenuml", "kanban",
    "radar-beta", "treemap-beta",
)
_RECOGNIZED = set(RECOGNIZED_DIAGRAM_TYPES)


def _first_meaningful_line(body):
    """First non-empty, non-directive line of a block body — skipping %% comments
    and an optional ---...--- frontmatter config fence. Returns (line_num, text)
    or (None, None) if the block has no content line."""
    in_cfg = False
    for line_num, line in body:
        s = line.strip()
        if not s:
            continue
        if s.startswith("%%"):          # %%{init:...}%% directive / %% comment
            continue
        if s == "---":                  # frontmatter config fence (open/close)
            in_cfg = not in_cfg
            continue
        if in_cfg:
            continue
        return line_num, s
    return None, None


def check_diagram_type(blocks, section):
    """Rule 0 (structural): each mermaid block must open with a recognized
    diagram-type declaration, else it does not render. Returns issue dicts.
    Complements check_mermaid_syntax (which validates node text WITHIN a block
    but never asserts the block declares a diagram type)."""
    issues = []
    for block_start, block_end, body in blocks:
        line_num, first = _first_meaningful_line(body)
        if first is None:
            issues.append({
                "halt_type": "mermaid_empty_block",
                "section": section,
                "line_number": block_start,
                "rule_violated": "Rule 0 — empty mermaid block (nothing to render)",
                "excerpt": "",
                "suggested_fix": "remove the empty fence or author a real diagram",
            })
            continue
        token = first.split()[0]
        if token.endswith(":"):     # `gitGraph:` renders — the colon is optional
            token = token[:-1]
        if token not in _RECOGNIZED:    # case-sensitive: mermaid grammar is
            issues.append({
                "halt_type": "mermaid_no_diagram_type",
                "section": section,
                "line_number": line_num,
                "rule_violated": "Rule 0 — first line must declare a diagram type (exact case)",
                "excerpt": first[:120],
                "suggested_fix": ("start the block with a diagram-type line, e.g. "
                                  "flowchart TD or stateDiagram-v2 (exact case; a "
                                  "header-less edge fragment does not render)"),
            })
    return issues


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


def check_mermaid_syntax(blocks, section):
    """Heuristic Mermaid syntax checker (Rule 1-3). Returns list of issue dicts.

    Strategy: stateful tokenizer that respects quoted strings — naive regex
    fails on cases like PRE(["text with (parens, commas)"]) because the
    inner ) terminates a `[^)]*` content class. Tokenizer walks each line
    char-by-char, tracks in-quote state, only matches shape-close when not
    in a quote.
    """
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

    # Rule 7 (stateDiagram only): a transition label may NEVER contain ':' or
    # ';' — quoting does NOT rescue either (ground-truthed against
    # mermaid.parse(); ';' terminates the statement mid-label). '"' alone is
    # FINE there (also ground-truthed — do not over-flag it). The field
    # failure shapes: "guard: ...", a "file.cs:112-134" citation,
    # "...='A'; next clause". `[*]` endpoints included.
    _STATE_TRANSITION = re.compile(r"^\s*(\[\*\]|[A-Za-z][\w]*)\s*-->\s*(\[\*\]|[A-Za-z][\w]*)\s*:(.*)$")
    _STATE_LABEL_KILLERS = set(":;")

    for block_start, block_end, body in blocks:
        _, first_line = _first_meaningful_line(body)
        is_state = bool(first_line and first_line.split()[0].startswith("stateDiagram"))
        for line_num, line in body:
            stripped = line.strip()
            if not stripped:
                continue
            if is_state:
                tm = _STATE_TRANSITION.match(line)
                hits = sorted(_STATE_LABEL_KILLERS & set(tm.group(3))) if tm else []
                if hits:
                    section_issues.append({
                        "halt_type": "mermaid_syntax_invalid",
                        "section": section,
                        "line_number": line_num,
                        "rule_violated": "Rule 7 — " + "".join(hits) + " inside a stateDiagram transition label",
                        "excerpt": stripped[:120],
                        "suggested_fix": ("a state transition label may not contain ':' or ';' "
                                          "(use '—'/space/· instead: 'guard — x', 'file.cs 112-134', "
                                          "'…=A · next') or move the detail into a `note` block; "
                                          "quoting does NOT fix either"),
                    })
                # NO continue — Rule 1-3 node-text checks below keep their
                # pre-Rule-7 behavior on state bodies (locked by the syntax-lock test)
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
                # Fully quoted → producer-compliant for Rule 1 — but INNER
                # unescaped quotes still break the parse (field: J["...GLLink("a,b")..."]
                # — the inner '"' ends the text early). Rule 3, quoted variant.
                if is_quoted_strictly(content):
                    inner = content.strip()[1:-1]
                    if re.search(r'(?<!\\)"', inner):
                        section_issues.append({
                            "halt_type": "mermaid_syntax_invalid",
                            "section": section,
                            "line_number": line_num,
                            "node_id": node_id,
                            "rule_violated": "Rule 3 — unescaped \" INSIDE quoted node text",
                            "excerpt": stripped[:120],
                            "suggested_fix": "replace inner double quotes with ' or &quot;",
                        })
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

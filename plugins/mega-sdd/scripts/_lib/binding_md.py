"""binding_md.py — the ONE binding.md parsing grammar (W2, spec 2026-07-19-w-batch-script-derive.md).

Shared by BOTH `validate-binding-json.sh` (parity gate) and
`derive-binding-json.sh` (deterministic generator) via the MEGA_SDD_LIB_DIR
sys.path pattern — the B1 shared-engine precedent (`postflight_rules.py`)
applied to the binding surface: md-parsing can never fork between the
validator and the generator.

Pure parsing. No __main__; no side effects.
"""

import re

# Closed enum for the trailing `[reason: <enum>]` Anchor-cell token
# (binding-md-template.md grammar; binding-json-schema.md `state_reason`).
STATE_REASON_ENUM = (
    "truncated_section",
    "ambiguous_match",
    "dynamic",
    "regex_tier",
    "kb_confirmed",
)

# Trailing token on a State Map Anchor cell: `... [reason: truncated_section]`
REASON_TOKEN_RE = re.compile(r"\[reason:\s*([a-z_]+)\]\s*$")

# Resolution action enum (binding-json-schema.md `resolution`).
RESOLUTION_ACTIONS = ("KEEP_VAULT", "KEEP_CODE", "DEFER", "SPLIT")

# `### CONFLICT-N` / `### ✅ CONFLICT-ADV-N …` detail headings inside the
# `## Conflicts` region (the canonical forms the gate validators read).
CONFLICT_HEADING_RE = re.compile(r"^###\s*(?:✅\s*)?(CONFLICT(?:-ADV)?-\d+)\b(.*)$")

# `- **Claim**: C-NNN` line inside a conflict detail block.
CLAIM_LINE_RE = re.compile(r"(?m)^\s*[-*]\s*\*\*Claim\*\*\s*:\s*(C-[A-Za-z0-9_-]+)")

# `- **Resolution**: ✅ RESOLVED (<ACTION>) …` dedicated line whose VALUE
# STARTS with the marker (S4 structural grammar — prose "resolved" never counts).
RESOLUTION_LINE_RE = re.compile(
    r"(?m)^\s*(?:[-*>]\s*)?\*\*Resolution\*\*\s*:\s*(?:✅\s*)*RESOLVED\b(.*)$"
)

# ACTION = first token of the closed set inside the parens after RESOLVED.
_ACTION_IN_PARENS_RE = re.compile(
    r"RESOLVED\s*\(\s*(KEEP_VAULT|KEEP_CODE|DEFER|SPLIT)\b"
)


def parse_state_map(md, errors, full=False):
    """Parse the `## Implementation State Map` table.

    full=False — the parity validator's exact historical contract: ordered
    {id: {"id", "verdict", "state"}} rows with byte-identical error strings.
    full=True — the generator variant: rows additionally carry
    "anchor_cell" / "confidence" / "field_diff" (verbatim cells), duplicate
    claim ids are errors, and a missing State Map heading is an error.
    """
    rows = {}
    in_tbl = False
    seen_heading = False
    for line in md.splitlines():
        if line.strip().startswith("## Implementation State Map"):
            in_tbl = True
            seen_heading = True
            continue
        if in_tbl:
            if line.startswith("## "):
                break
            if not line.strip().startswith("|"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            # S4 BC-PARITY-5COL: aligned separators (|:---:|) are separator rows,
            # not claim rows (they used to phantom-FAIL as ':---' claims).
            if cells[0] in ("Claim ID", "---") or (cells[0] and set(cells[0]) <= set("-:")):
                continue
            if len(cells) < 6:
                # S4 BC-PARITY-5COL: a short row inside the table region is a
                # MALFORMED row — silently skipping it let a divergent md/json
                # pair pass parity cleanly. Template pins 6 columns always
                # (Field diff cell = n/a at non-ast tiers).
                errors.append(
                    f"malformed State Map row ({len(cells)} cells, need 6): {line.strip()[:120]}"
                )
                continue
            if full and cells[0] in rows:
                errors.append(f"duplicate claim id in State Map: {cells[0]}")
                continue
            row = {"id": cells[0], "verdict": cells[1], "state": cells[2]}
            if full:
                row["anchor_cell"] = cells[3]
                row["confidence"] = cells[4]
                row["field_diff"] = cells[5]
            rows[cells[0]] = row
    if full and not seen_heading:
        errors.append(
            "missing '## Implementation State Map' heading in binding.md "
            "(broken Step-4 write — the template always emits the section)"
        )
    return rows


def _frontmatter_block(md):
    """The leading `---` … `---` frontmatter block, or '' when absent."""
    if not md.startswith("---"):
        return ""
    end = md.find("\n---", 3)
    if end == -1:
        return ""
    return md[: end + 1]


def _scalar(value):
    """Normalize a frontmatter scalar: strip inline comment, quotes, null."""
    value = value.split(" #", 1)[0].strip()
    if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
        value = value[1:-1].strip()
    if value in ("", "null", "~", "None"):
        return None
    return value


def parse_frontmatter_metadata(md):
    """Extract binding_metadata.codebase_map_provenance + binding_metadata.head
    from the leading frontmatter. Absent (either key or the whole block) → None
    (None-safe; the caller decides whether to warn)."""
    meta = {"codebase_map_provenance": None, "head": None}
    block = _frontmatter_block(md)
    if not block:
        return meta
    m = re.search(r"(?m)^\s*codebase_map_provenance:\s*(.+)$", block)
    if m:
        meta["codebase_map_provenance"] = _scalar(m.group(1))
    m = re.search(r"(?m)^\s+head:\s*(.+)$", block)
    if m:
        meta["head"] = _scalar(m.group(1))
    return meta


def parse_confirmed_sources(md):
    """{claim_id: vault_source} side-index from the `## Confirmed Claims`
    list (`- C-001 | <vault file:line> | <codebase evidence> | <claim text>`).
    Region: from the heading until the next `## `."""
    sources = {}
    in_sec = False
    for line in md.splitlines():
        if line.strip().startswith("## Confirmed Claims"):
            in_sec = True
            continue
        if in_sec:
            if line.startswith("## "):
                break
            m = re.match(r"^-\s*(\S+)\s*\|\s*([^|]+)\|", line)
            if m:
                sources[m.group(1)] = m.group(2).strip()
    return sources


def parse_conflict_resolutions(md, errors):
    """{claim_id: ACTION} from RESOLVED `### CONFLICT-N` detail blocks in the
    `## Conflicts` region, applying the S4 structural-marker grammar
    (binding-md-template.md): a block is RESOLVED when the heading carries ✅
    or the word RESOLVED immediately after the conflict ID, OR a dedicated
    `- **Resolution**:` line whose value starts with ✅ RESOLVED. ACTION =
    first closed-enum token inside the parens after RESOLVED on whichever
    surface matched. Rules enforced here:
      - RESOLVED with no parsable ACTION → error.
      - RESOLVED block without a parsable `- **Claim**: C-NNN` line → error.
      - ACTIVE blocks: Claim line optional; no resolution recorded.
    (Claim-id-present-in-State-Map is the caller's check — it needs the rows.)
    """
    resolutions = {}
    lines = md.splitlines()
    # Locate the `## Conflicts` region (until the next `## ` heading).
    start = end = None
    for i, line in enumerate(lines):
        if start is None and line.strip().startswith("## Conflicts"):
            start = i + 1
            continue
        if start is not None and line.startswith("## "):
            end = i
            break
    if start is None:
        return resolutions
    if end is None:
        end = len(lines)

    # Collect detail-heading blocks (heading → next ###/## heading).
    blocks = []
    for i in range(start, end):
        m = CONFLICT_HEADING_RE.match(lines[i])
        if m:
            blocks.append((i, m.group(1)))
    for n, (i, conflict_id) in enumerate(blocks):
        j = blocks[n + 1][0] if n + 1 < len(blocks) else end
        heading = lines[i]
        body = "\n".join(lines[i + 1 : j])

        head_resolved = ("✅" in heading) or re.search(
            rf"{re.escape(conflict_id)}\s+RESOLVED\b", heading
        )
        line_m = RESOLUTION_LINE_RE.search(body)
        if not head_resolved and not line_m:
            continue  # ACTIVE block — Claim line optional, resolution stays null

        action = None
        if head_resolved:
            am = _ACTION_IN_PARENS_RE.search(heading)
            if am:
                action = am.group(1)
        if action is None and line_m:
            am = _ACTION_IN_PARENS_RE.search("RESOLVED" + line_m.group(1))
            if am:
                action = am.group(1)
        if action is None:
            errors.append(
                f"{conflict_id}: RESOLVED marker without a parsable ACTION — "
                f"use 'RESOLVED (<KEEP_VAULT|KEEP_CODE|DEFER|SPLIT> …)' on the "
                f"heading or the '- **Resolution**:' line"
            )
            continue

        cm = CLAIM_LINE_RE.search(body)
        if not cm:
            errors.append(
                f"{conflict_id}: RESOLVED block has no '- **Claim**: C-NNN' line — "
                f"add the Claim line naming the State Map claim id and re-run"
            )
            continue
        resolutions[cm.group(1)] = action
    return resolutions

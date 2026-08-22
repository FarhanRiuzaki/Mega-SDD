"""vault_md.py — the ONE vault-markdown parsing grammar (W5, spec
2026-07-19-batch2-derive-and-diet.md).

Shared by BOTH `validate-vault-oqs.sh` (PostToolUse rail) and
`derive-vault-json.sh` (deterministic generator) via the MEGA_SDD_LIB_DIR
sys.path pattern — the W2 `binding_md.py` precedent applied to the vault
surface: OQ-tag / category-bracket parsing can never fork between the
validator and the generator (two-validators-one-grammar).

Pure parsing. No __main__; no side effects. Parsers collect problems into a
caller-supplied `errors` list (the exit-2 lane) and NEVER fabricate a value
that is not in the markdown — absent purpose/source_acs/resolver_owner stay
None/omitted (vault-contract.md §Field rules; anti-halu invariant 5).
"""

import os
import re

# ── Shared with validate-vault-oqs.sh (constant-only refactor) ──────────────
# OQ_TAG_RE is byte-identical to the inline `oq_pattern` the validator
# compiled pre-refactor (validate-vault-oqs.sh:118 — incl. the S4 BC-HANDOFF-1
# numeric OQ-001 form). Pinned by test-derive-vault-json-vault.sh.
OQ_TAG_RE = re.compile(r"\bOQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+\b")

# Category-detection regex the validator compiles per category (byte-identical
# to validate-vault-oqs.sh:191/:192 pre-refactor — the md bracket half + the
# vault.json quoted half). Pinned by the same test.
CATEGORY_BRACKET_PATTERN = '\\[\\s*{cat}\\b|"category"\\s*:\\s*"{cat}"'
CATEGORY_BRACKET_RE = re.compile(
    CATEGORY_BRACKET_PATTERN.format(cat="tech"), re.IGNORECASE
)
CATEGORY_BRACKET_BUSINESS_RE = re.compile(
    CATEGORY_BRACKET_PATTERN.format(cat="business"), re.IGNORECASE
)

# ── Deriver grammar (G1–G3 obligations; vault-contract.md §schema mirrors) ──
# OQ checkbox line. Tag capture is ALIGNED with the loose OQ_TAG_RE (amendment
# §3) so a numeric `OQ-001` tag parses instead of tripping the cross-count
# guard. Group 1 = checkbox state, group 2 = tag, group 3 = remainder
# (priority/category/conf brackets + `:` + question text).
OQ_LINE_RE = re.compile(
    r"^-\s*\[( |x|~)\]\s*\*\*(OQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+)\*\*\s*(.*)$"
)

# `[P1]` / `[P2]` / `[P3]` priority bracket.
OQ_PRIORITY_RE = re.compile(r"\[\s*(P[123])\s*\]")

# v7 Fase 3 (gate 2026-08-22, tambahan 1): with OQs centralized in
# constraints.md they lose the per-doc placement that used to carry locality
# for free — every OQ line may carry an `[origin: <file>#<anchor>]` token
# (e.g. `[origin: flows.md#F-U-002]`) naming where the question arose.
# Parsed to the `origin` field (flows through to vault.json; consumed by
# resolve-oq / bind for grounding locality). Absent token = absent field.
OQ_ORIGIN_RE = re.compile(r"\[\s*origin:\s*([^\]]+?)\s*\]")

# `[tech / scan]` / `[business]` classification bracket (vault-contract.md
# §Updated OQ schema in markdown body). Closed enums.
OQ_META_BRACKET_RE = re.compile(
    r"\[\s*(tech|business)\s*(?:/\s*(scan|recommend|hard_rule|blocking)\s*)?\]",
    re.IGNORECASE,
)

# `[conf: high]` classification-confidence bracket.
OQ_CONF_BRACKET_RE = re.compile(
    r"\[\s*conf:\s*(high|medium|low)\s*\]", re.IGNORECASE
)

# `→ **Resolved v1.1** (date): answer` / `→ Resolved v1.1: answer`
# re.M: the annotation line may sit anywhere inside the OQ's multi-line block
# (a resolved OQ is NOT always the last line of its doc — without re.M the `$`
# only matched at block end and mid-doc annotations were silently dropped,
# DELETING a prior resolution on re-derive since it is a DERIVED_OQ key).
OQ_RESOLUTION_RE = re.compile(
    r"→\s*\*{0,2}Resolved v[\d.]+\*{0,2}[^:\n]*:\s*(.+)$", re.M
)

# `→ Out of Scope v1.1: reason`
OQ_OOS_REASON_RE = re.compile(r"→\s*Out of Scope v[\d.]+\s*:\s*(.+)$", re.M)

# `**Deferred (v1.1)**: reason` annotation (marks status deferred while the
# checkbox stays `[ ]` — vault-contract.md §Status markers). Position-anchored
# to the FULL annotation shape — bold-closed marker + `:` + a non-empty reason
# (symmetric with the Resolved annotation, which requires its full
# `→ … Resolved vX.Y …:` shape) — so ordinary bold `**Deferred**` wording
# inside a question text can never fabricate the status or truncate the text.
OQ_DEFERRED_RE = re.compile(r"\*\*Deferred\b[^*\n]*\*\*\s*:\s*\S")
OQ_DEFERRED_REASON_RE = re.compile(r"\*\*Deferred[^*\n]*\*\*\s*:\s*(.+)$", re.M)

# `— resolve: <PIC/source>` hint (resolver_owner is best-effort — None when
# absent, never fabricated).
OQ_RESOLVE_HINT_RE = re.compile(r"—\s*resolve:\s*(.+)$")

# `### F-U-001: title` flow heading (04-flows.md; §id-stability prefixes).
FLOW_HEADING_RE = re.compile(r"^###\s+(F-(?:[A-Z]-)?\d+)\s*:\s*(.+)$")

# `### D-001: title` ADR heading (05-decisions.md).
ADR_HEADING_RE = re.compile(r"^###\s+(D-\d+)\s*:\s*(.+)$")

# ADR `**Status**:` line (Tier-1 pinned label; bare `Status:` tolerated).
ADR_STATUS_LINE_RE = re.compile(
    r"^\s*(?:[-*>]\s*)?(?:\*\*)?Status(?:\*\*)?\s*:\s*(.+)$"
)

# DBML `Table <name> {` opener inside a ```dbml fence (03-data-model.md).
DBML_TABLE_RE = re.compile(r"^\s*[Tt]able\s+([A-Za-z0-9_]+)\s*\{")

# G1: `// Purpose: <1 line>` comment immediately above a Table block.
PURPOSE_COMMENT_RE = re.compile(r"//\s*Purpose:\s*(.+)$")

# Full-mode fallback: `### <entity>` heading + `- **Purpose**: <1 line>`.
ENTITY_HEADING_RE = re.compile(r"^###\s+`?([A-Za-z0-9_]+)`?\s*$")
ENTITY_PURPOSE_LINE_RE = re.compile(r"^\s*-\s*\*\*Purpose\*\*\s*:\s*(.+)$")

# `AC1-2` Source-AC tokens on a flow's `**Source**:` line.
AC_TOKEN_RE = re.compile(r"\bAC\d+-\d+\b")

# Flow structural labels (Tier-1 pinned — output-language.md G2).
FLOW_DOD_LABEL_RE = re.compile(r"^\*\*Definition of Done\*\*\s*:")
FLOW_SOURCE_LABEL_RE = re.compile(r"^\*\*Source\*\*\s*:\s*(.+)$")
FLOW_KB_SOURCE_RE = re.compile(r"^\*\*_kb_source\*\*\s*:\s*\[([^\]]*)\]")
DOD_ITEM_RE = re.compile(r"^- \[[ xX]\]\s+\S")

# 00-index Vault Lock Status bullet labels (Tier-1 pinned — G2; the P4
# `**History**` bullet is deliberately NOT machine-read and NOT pinned).
VAULT_LOCK_KEYS = {
    "Vault version": "vault_version",
    "Project shape": "project_shape",
    "Implementation mode": "implementation_mode",
    "Mode migration trigger": "mode_migrate_after",
    "PRD status": "prd_status",
    "Output mode": "output_mode",
}
_LOCK_BULLET_RE = re.compile(r"^-\s*\*\*([^*]+)\*\*\s*:\s*(.+)$")

# v7 Fase 3 layout-2 (vault.md): the six lock values live as YAML-frontmatter
# scalars. Frontmatter is read ONLY when it carries `vault_layout: 2` — the
# LEGACY 00-index.md frontmatter also has a `vault_version:` line, so an
# ungated frontmatter-first read would silently re-source that one key on
# every old vault (the zero-behavior-change rule for the dual-layout cycle).
_VAULT_FM_RE = re.compile(r"\A---\n(.*?)\n---", re.DOTALL)
_FM_LOCK_KEYS = {
    "vault_version": "vault_version",
    "project_shape": "project_shape",
    "implementation_mode": "implementation_mode",
    "mode_migration_trigger": "mode_migrate_after",
    "prd_status": "prd_status",
    "output_mode": "output_mode",
}

_FLOW_TYPE_BY_PREFIX = {
    "U": "user",
    "S": "system",
    "C": "cross-cutting",
    "P": "pipeline",
    "X": "custom",
}


def _norm_lock_value(key, value):
    """Normalize a Vault Lock bullet value: strip backticks/whitespace,
    `null` → None, and (vault_version only) `v1.2` → `1.2`."""
    value = value.strip().strip("`").strip()
    if value.lower() in ("", "null", "~", "none"):
        return None
    if key == "vault_version" and re.fullmatch(r"v\d+(?:\.\d+)*", value):
        value = value[1:]
    return value


def _fm_scalar_value(fm, label):
    """One top-level `label: value` scalar out of a frontmatter body, or None
    when the line is absent. Strips a trailing `  #` comment and wrapping
    quotes (the same tolerance as the sibling fm parsers)."""
    m = re.search(r"(?m)^%s:[ \t]*(.*)$" % re.escape(label), fm)
    if not m:
        return None
    v = m.group(1).strip()
    if v.startswith("#"):
        return None
    v = v.split("  #", 1)[0].strip()
    return v.strip("'\"")


def vault_layout(md):
    """2 when the doc's YAML frontmatter carries `vault_layout: 2`
    (layout-2 vault.md), else 1 (legacy 00-index.md / no frontmatter)."""
    m = _VAULT_FM_RE.match(md or "")
    if m and (_fm_scalar_value(m.group(1), "vault_layout") or "") == "2":
        return 2
    return 1


# ── v7 Fase 3 layout-2 shared surface (ONE mapping — consumers must not fork) ─
# 4-file layout: vault.md (00 residue as frontmatter + Overview/Architecture/
# Decisions) / model.md (03) / flows.md (04) / constraints.md (06 + ALL OQs).
V2_DOC_OF = {
    "00-index.md": "vault.md",
    "01-overview.md": "vault.md",
    "02-architecture.md": "vault.md",
    "03-data-model.md": "model.md",
    "04-flows.md": "flows.md",
    "05-decisions.md": "vault.md",
    "06-constraints.md": "constraints.md",
}

# Hard section-header contract (gate addition 2): DOC_CODE re-keys from
# filename to SECTION on layout-2, so these three H2 strings are a CONTRACT,
# not a convention — consumers FAIL loud (exit != 0, naming the missing
# header) instead of silently producing an empty ledger. `## Glossary` is
# optional. An UNKNOWN H2 does NOT end a section (merged source docs keep
# their own H2s verbatim — e.g. `## §<id>` component headings, `## Goals`);
# only the anchor set switches sections.
V2_SECTION_ANCHORS = {
    "overview": "OV",
    "architecture": "AR",
    "decisions": "DC",
    "glossary": None,        # optional; ends the Decisions section
    "open questions": None,  # OQs are constraints.md-owned; treated as a fence
    # 00-index residue sections migrate-paths moves VERBATIM into vault.md —
    # fences, so their content never inherits a claim DOC_CODE:
    "changelog": None,
    "source documents": None,
    "auto-classification review": None,
}
V2_REQUIRED_HEADERS = ("## Overview", "## Architecture", "## Decisions")


def is_layout2_vault(vault_dir):
    """Layout-2 probe used by every dual-layout consumer: vault.md exists."""
    return os.path.isfile(os.path.join(vault_dir, "vault.md"))


def resolve_doc(vault_dir, legacy_name):
    """Dual-layout doc read-resolution (one minor cycle, floor v5.9.0):
    on a layout-2 vault return the layout-2 file that carries the legacy
    doc's content; else the legacy path. Callers that need the doc NAME for
    a citation should use os.path.basename() of this return value so
    emitted citations always name the file that was actually read."""
    if is_layout2_vault(vault_dir):
        v2 = V2_DOC_OF.get(legacy_name)
        if v2:
            return os.path.join(vault_dir, v2)
    return os.path.join(vault_dir, legacy_name)


def v2_section_codes(lines):
    """Per-line DOC_CODE attribution for layout-2 vault.md: {line_no: code}.
    Lines before the first anchor and lines inside Glossary/Open Questions
    map to None. Unknown H2s keep the current section (see V2_SECTION_ANCHORS
    note)."""
    codes = {}
    cur = None
    for i, line in enumerate(lines, 1):
        if line.startswith("## ") and not line.startswith("### "):
            head = line[3:].strip().lower()
            if head in V2_SECTION_ANCHORS:
                cur = V2_SECTION_ANCHORS[head]
        codes[i] = cur
    return codes


def v2_missing_headers(md):
    """The V2_REQUIRED_HEADERS absent from a layout-2 vault.md body, in
    contract order — [] when the hard-header contract is satisfied."""
    heads = set()
    for line in (md or "").splitlines():
        if line.startswith("## "):
            heads.add(line[3:].strip().lower())
    return [h for h in V2_REQUIRED_HEADERS if h[3:].strip().lower() not in heads]


def parse_vault_lock(md):
    """The six Vault Lock metadata values.

    Layout-2 (frontmatter carries `vault_layout: 2`): the values are read
    FRONTMATTER-FIRST from the vault.md scalars; any key absent there still
    falls back to a `## Vault Lock Status` bullet section if one exists
    (dual-layout read, one minor cycle). Legacy layout: bullets inside the
    `## Vault Lock Status` section only — byte-identical to the pre-Fase-3
    behavior. Returns a dict containing ONLY the labels that were found (an
    explicit `null` value is present with value None — distinct from a
    missing label). A missing section/label is simply absent from the dict —
    the CALLER carries the prior vault.json value forward and WARNs (never a
    fabricated enum)."""
    fm_vals = {}
    if vault_layout(md) == 2:
        fm = _VAULT_FM_RE.match(md).group(1)
        for label, key in _FM_LOCK_KEYS.items():
            raw = _fm_scalar_value(fm, label)
            if raw is not None:
                fm_vals[key] = _norm_lock_value(key, raw)
    out = {}
    in_sec = False
    for line in md.splitlines():
        if line.strip().startswith("## Vault Lock Status"):
            in_sec = True
            continue
        if in_sec:
            if line.startswith("## "):
                break
            m = _LOCK_BULLET_RE.match(line.strip()) or _LOCK_BULLET_RE.match(line)
            if not m:
                continue
            label = m.group(1).strip()
            if label in VAULT_LOCK_KEYS:
                key = VAULT_LOCK_KEYS[label]
                out[key] = _norm_lock_value(key, m.group(2))
    # frontmatter WINS over any residual bullet section (fm_vals is empty on
    # legacy input, so this is a no-op there — zero-behavior-change rule).
    out.update(fm_vals)
    return out


def parse_data_model(md, errors, doc_name="03-data-model.md"):
    """entities[] mirror rows from the data-model doc's ```dbml fences
    (legacy 03-data-model.md; layout-2 callers pass doc_name="model.md").

    Per entity: name (Table token), fields_count (depth-1 field lines,
    excluding comments / blanks / Note / indexes / nested-block regions),
    purpose (G1 `// Purpose:` comment immediately above the Table; fallback
    full-mode `### <entity>` + `- **Purpose**:`; else None — never invented).
    Duplicate table name → error."""
    # Full-mode purpose fallback index (Entity descriptions section).
    full_mode_purpose = {}
    cur_entity = None
    for line in md.splitlines():
        hm = ENTITY_HEADING_RE.match(line)
        if hm and not FLOW_HEADING_RE.match(line) and not ADR_HEADING_RE.match(line):
            cur_entity = hm.group(1)
            continue
        if cur_entity:
            pm = ENTITY_PURPOSE_LINE_RE.match(line)
            if pm:
                full_mode_purpose[cur_entity] = pm.group(1).strip()
                cur_entity = None

    entities = []
    seen = set()
    in_fence = False
    depth = 0
    pending_purpose = None
    current = None  # the entity dict whose braces we are inside
    for line in md.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            if not in_fence and stripped.lower().startswith("```dbml"):
                in_fence = True
            elif in_fence:
                in_fence = False
                depth = 0
                current = None
                pending_purpose = None
            continue
        if not in_fence:
            continue
        if depth == 0:
            pc = PURPOSE_COMMENT_RE.search(line)
            if pc and stripped.startswith("//"):
                pending_purpose = pc.group(1).strip()
                continue
            tm = DBML_TABLE_RE.match(line)
            if tm:
                name = tm.group(1)
                if name in seen:
                    errors.append(
                        f"duplicate DBML table name in {doc_name}: {name}"
                    )
                else:
                    seen.add(name)
                    current = {
                        "name": name,
                        "purpose": pending_purpose
                        or full_mode_purpose.get(name),
                        "doc": doc_name,
                        "fields_count": 0,
                    }
                    entities.append(current)
                pending_purpose = None
                depth = 1
            continue
        # inside a Table body (depth >= 1)
        opens = line.count("{")
        closes = line.count("}")
        if depth == 1 and current is not None:
            first = stripped.split(None, 1)[0] if stripped else ""
            is_field = (
                bool(re.match(r"^\s+\S+\s+\S+", line))
                and not stripped.startswith("//")
                and first.lower() not in ("note", "note:", "indexes")
                and "{" not in line
            )
            if is_field:
                current["fields_count"] += 1
        depth += opens - closes
        if depth <= 0:
            depth = 0
            current = None
    return entities


def parse_flows(md, errors, doc_name="04-flows.md"):
    """flows[] mirror rows from the flows doc's `### F-*-NNN:` headings
    (legacy 04-flows.md; layout-2 callers pass doc_name="flows.md").

    Per flow: id, title, type (prefix letter map; prefix-less → user), doc,
    dod_count (col-0 checkbox items under `**Definition of Done**:`),
    source_acs (ordered unique ACn-m tokens on the `**Source**:` line — key
    omitted when none), _kb_source (list — omitted when absent).
    Duplicate flow id → error."""
    lines = md.splitlines()
    heads = []
    for i, line in enumerate(lines):
        m = FLOW_HEADING_RE.match(line)
        if m:
            heads.append((i, m.group(1), m.group(2).strip()))
    flows = []
    seen = set()
    for n, (i, fid, title) in enumerate(heads):
        j = heads[n + 1][0] if n + 1 < len(heads) else len(lines)
        # block also ends at the next ##/### heading of any kind
        for k in range(i + 1, j):
            if lines[k].startswith("## ") or lines[k].startswith("### "):
                j = k
                break
        if fid in seen:
            errors.append(f"duplicate flow id in {doc_name}: {fid}")
            continue
        seen.add(fid)
        pm = re.match(r"^F-([A-Z])-", fid)
        ftype = _FLOW_TYPE_BY_PREFIX.get(pm.group(1), "custom") if pm else "user"
        flow = {
            "id": fid,
            "title": title,
            "type": ftype,
            "doc": doc_name,
        }
        dod_count = 0
        in_dod = False
        source_acs = []
        kb_source = None
        for k in range(i + 1, j):
            line = lines[k]
            if FLOW_DOD_LABEL_RE.match(line):
                in_dod = True
                continue
            if in_dod:
                if DOD_ITEM_RE.match(line):
                    dod_count += 1
                    continue
                if line.startswith("**") or line.startswith("#"):
                    in_dod = False
            sm = FLOW_SOURCE_LABEL_RE.match(line)
            if sm:
                for tok in AC_TOKEN_RE.findall(sm.group(1)):
                    if tok not in source_acs:
                        source_acs.append(tok)
            km = FLOW_KB_SOURCE_RE.match(line)
            if km:
                kb_source = [
                    p.strip() for p in km.group(1).split(",") if p.strip()
                ]
        flow["dod_count"] = dod_count
        if source_acs:
            flow["source_acs"] = source_acs
        if kb_source:
            flow["_kb_source"] = kb_source
        flows.append(flow)
    return flows


def parse_adrs(md, errors, doc_name="05-decisions.md"):
    """adrs[] mirror rows from the decisions doc's `### D-NNN:` headings
    (legacy 05-decisions.md; layout-2 callers pass doc_name="vault.md").

    status from a `Status:`/`**Status**:` line in the block (token starting
    'supersed' → superseded, 'propos' → proposed, 'accept' → accepted);
    absent/unrecognized → 'accepted' (the diff-procedure default).
    Duplicate id → error."""
    lines = md.splitlines()
    heads = []
    for i, line in enumerate(lines):
        m = ADR_HEADING_RE.match(line)
        if m:
            heads.append((i, m.group(1), m.group(2).strip()))
    adrs = []
    seen = set()
    for n, (i, did, title) in enumerate(heads):
        j = heads[n + 1][0] if n + 1 < len(heads) else len(lines)
        for k in range(i + 1, j):
            if lines[k].startswith("## ") or lines[k].startswith("### "):
                j = k
                break
        if did in seen:
            errors.append(f"duplicate ADR id in {doc_name}: {did}")
            continue
        seen.add(did)
        status = "accepted"
        for k in range(i + 1, j):
            sm = ADR_STATUS_LINE_RE.match(lines[k])
            if sm:
                tok = sm.group(1).strip().split(None, 1)[0].lower() if sm.group(1).strip() else ""
                if tok.startswith("supersed"):
                    status = "superseded"
                elif tok.startswith("propos"):
                    status = "proposed"
                elif tok.startswith("accept"):
                    status = "accepted"
                break
        adrs.append(
            {"id": did, "title": title, "doc": doc_name, "status": status}
        )
    return adrs


def parse_rollup_categories(index_md):
    """{tag: category} legacy fallback from the 00-index.md
    `## Open Questions roll-up` section headers (`### <Category> (PRIORITY-N)`).
    Used ONLY when an OQ line carries no `[tech|business]` bracket
    (bracket-first precedence — vault-contract.md §Field rules)."""
    out = {}
    in_sec = False
    cur_cat = None
    # both heading spellings: the template emits `## Open Questions (roll-up)`,
    # older vaults `## Open Questions roll-up` (P4 latent-defect fix — the
    # template form never matched, so the category fallback was dead on
    # template-shaped vaults)
    _sec_re = re.compile(r"^##\s+Open Questions\s*(?:\(roll-up\)|roll-up|\(roll-?up\))", re.I)
    for line in index_md.splitlines():
        if _sec_re.match(line.strip()):
            in_sec = True
            continue
        if in_sec:
            if line.startswith("## "):
                break
            hm = re.match(r"^###\s+(.+?)\s*(?:\(PRIORITY-\d+\))?\s*$", line)
            if hm:
                # roll-up categories are FREE-TEXT groupings by contract (the
                # derive fixture pins "PRD inconsistencies" flowing through) —
                # never enum-normalized here. Note the deliberate downstream
                # join: validate-vault-oqs reads startswith("tech") on the
                # lowered value BY DESIGN, so a "Technical*" heading's
                # bracketless OQs are checked for resolution_mode — with the
                # (roll-up) spelling now matching, that advisory check newly
                # reaches template-shaped vaults (P4 disclosure).
                cur_cat = hm.group(1).strip().strip("{}").strip()
                continue
            if cur_cat:
                for tag in OQ_TAG_RE.findall(line):
                    out.setdefault(tag, cur_cat)
    return out


def parse_open_questions(doc_name, md, errors):
    """open_questions[] skeleton rows from ONE numbered doc (01–06).

    Each `- [ ]`/`- [x]`/`- [~]` checkbox OQ line yields an entry:
    tag / priority / doc / status (open|resolved|out_of_scope; deferred when
    the entry block carries a `**Deferred**` annotation) / category +
    resolution_mode + classification_confidence + origin (brackets,
    bracket-first; origin = `[origin: <file>#<anchor>]`, v7 Fase 3) /
    text / resolution / out_of_scope_reason / deferred_reason /
    resolver_owner. None values are OMITTED by the caller — absence is honest,
    never fabricated. Duplicate tags ACROSS docs are the caller's check."""
    lines = md.splitlines()
    anchors = []
    for i, line in enumerate(lines):
        m = OQ_LINE_RE.match(line)
        if m:
            anchors.append((i, m))
    oqs = []
    for n, (i, m) in enumerate(anchors):
        j = anchors[n + 1][0] if n + 1 < len(anchors) else len(lines)
        # the block also ends at the next ##/### heading of any kind (the
        # parse_flows/parse_adrs precedent): a later section's content must
        # never feed this OQ's annotations — e.g. an unrelated `**Deferred**:`
        # line under `## Notes` would fabricate status deferred + steal the
        # reason for the doc's last OQ.
        for k in range(i + 1, j):
            if lines[k].startswith("## ") or lines[k].startswith("### "):
                j = k
                break
        block = "\n".join(lines[i:j])
        box, tag, rest = m.group(1), m.group(2), m.group(3)
        status = {" ": "open", "x": "resolved", "~": "out_of_scope"}[box]
        if status == "open" and OQ_DEFERRED_RE.search(block):
            status = "deferred"
        entry = {"tag": tag, "priority": None, "doc": doc_name, "status": status}
        pr = OQ_PRIORITY_RE.search(rest)
        if pr:
            entry["priority"] = pr.group(1)
        cm = OQ_META_BRACKET_RE.search(rest)
        if cm:
            entry["category"] = cm.group(1).lower()
            if cm.group(2):
                entry["resolution_mode"] = cm.group(2).lower()
        cf = OQ_CONF_BRACKET_RE.search(rest)
        if cf:
            entry["classification_confidence"] = cf.group(1).lower()
        og = OQ_ORIGIN_RE.search(rest)
        if og:
            entry["origin"] = og.group(1).strip()
        # question text: after the marker-bracket prefix's colon, up to the
        # `— resolve:` hint or the `→` outcome marker.
        tm = re.match(r"^(?:\s*\[[^\]]*\])*\s*:?\s*(.*)$", rest)
        text = tm.group(1).strip() if tm else rest.strip()
        hint = None
        hm = OQ_RESOLVE_HINT_RE.search(text)
        if hm:
            hint = hm.group(1).strip()
            text = text[: hm.start()].strip()
        arrow = text.find("→")
        if arrow != -1:
            text = text[:arrow].strip()
        dm = OQ_DEFERRED_RE.search(text)
        if dm:
            text = text[: dm.start()].strip()
        if text:
            entry["text"] = text
        rm = OQ_RESOLUTION_RE.search(block)
        if rm:
            entry["resolution"] = rm.group(1).strip()
        om = OQ_OOS_REASON_RE.search(block)
        if om:
            entry["out_of_scope_reason"] = om.group(1).strip()
        dm = OQ_DEFERRED_REASON_RE.search(block)
        if dm:
            entry["deferred_reason"] = dm.group(1).strip()
        if hint:
            # strip a trailing outcome marker that rode the hint
            arrow = hint.find("→")
            if arrow != -1:
                hint = hint[:arrow].strip()
            if hint:
                entry["resolver_owner"] = hint
        oqs.append(entry)
    return oqs


# 6.0.1 F5 (field-test hardening spec): the five patch-lane OQ fields, when
# they appear as hint lines INSIDE an OQ's markdown block (backticked or bare
# `field: value`). Parsed as the LOWEST-precedence source — the deriver applies
# them via setdefault AFTER prior carry-forward and the authored patch, so a
# patched/carried value always wins and the anti-laundering lanes are
# untouched. scan_citations splits on commas into the schema's array shape.
# Anchored to line start (only whitespace/blockquote/bullet + an optional
# backtick may precede the field name) — round fold: unanchored, the word
# "recommendation:" inside a QUESTION TEXT was captured as an authored field.
OQ_FIELD_HINT_RE = re.compile(
    r"^[ \t>]*(?:[-*][ \t]+)?`?"
    r"(scan_query|recommendation|rationale|scan_citations|fallback_if_wrong)"
    r"`?\s*:\s*(.+)$", re.M
)


def parse_oq_field_hints(md):
    """{tag: {field: value}} for the five JSON-only OQ fields found inside
    each OQ's markdown block (same block boundaries as parse_open_questions —
    next OQ anchor or next ##/### heading). Values are stripped of wrapping
    backticks/quotes; empty values are omitted (absence stays honest)."""
    lines = md.splitlines()
    anchors = []
    for i, line in enumerate(lines):
        if OQ_LINE_RE.match(line):
            anchors.append(i)
    out = {}
    for n, i in enumerate(anchors):
        j = anchors[n + 1] if n + 1 < len(anchors) else len(lines)
        for k in range(i + 1, j):
            if lines[k].startswith("## ") or lines[k].startswith("### "):
                j = k
                break
        m = OQ_LINE_RE.match(lines[i])
        tag = m.group(2)
        # code-fence tracking (round fold: a ```-fenced EXAMPLE inside the
        # block beat the real hint) — fenced lines never carry hints
        block_lines = []
        in_fence = False
        for bl in lines[i:j]:
            if bl.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if not in_fence:
                block_lines.append(bl)
        block = "\n".join(block_lines)
        fields = {}
        for fm in OQ_FIELD_HINT_RE.finditer(block):
            val = fm.group(2).strip().strip("`").strip().strip('"').strip("'").strip()
            if not val:
                continue
            if fm.group(1) == "scan_citations":
                parts = [p.strip().strip("`") for p in val.split(",")]
                parts = [p for p in parts if p]
                if parts:
                    fields.setdefault("scan_citations", parts)
            else:
                fields.setdefault(fm.group(1), val)
        if fields:
            out[tag] = fields
    return out


def summarize_oqs(oqs):
    """open_questions_summary recompute: total, by_priority (P1/P2/P3),
    by_status over the unified vocabulary open/resolved/deferred/out_of_scope
    (G3 — 'pending'/'out-of-scope' variants retired; a missing status counts
    as open per the back-compat rule)."""
    by_priority = {"P1": 0, "P2": 0, "P3": 0}
    by_status = {"open": 0, "resolved": 0, "deferred": 0, "out_of_scope": 0}
    for oq in oqs:
        p = oq.get("priority")
        if p in by_priority:
            by_priority[p] += 1
        s = oq.get("status") or "open"
        if s == "pending":
            s = "open"
        if s == "out-of-scope":
            s = "out_of_scope"
        if s in by_status:
            by_status[s] += 1
        else:
            by_status["open"] += 1
    return {
        "total": len(oqs),
        "by_priority": by_priority,
        "by_status": by_status,
    }

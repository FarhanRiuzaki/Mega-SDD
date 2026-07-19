#!/usr/bin/env bash
# validate-vault-oqs.sh — Phase B slice B.4 [PostToolUse-validate]
#   + Task G (code-delivery sharpening): operator-workflow-UX capture rails.
#
# Per-OQ scope (B.4):
#   - oq_recommend_citation_invalid (recommendation cites nonexistent KB section)
#   - oq_tech_missing_mode / oq_recommend_underspecified / oq_scan_missing_query
#
# Vault-WIDE rails (Task G — docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md
# §3 Slice G; plan §Task G). Operate on the WHOLE active vault, not just the
# written file:
#   - operator_surface_missing — 04-flows declares a multi-stage approval
#     (maker-checker) workflow but the vault models NO operator-facing surface
#     (worklist/inbox, decision affordance, human state labels, audit timeline)
#     AND carries NO Design-Source OQ.
#   - design_source_oq_missing — HAS_UI_COMPONENTS true but HAS_TOKENS/HAS_A11Y/
#     HAS_VOICE_BRAND all false AND no Design-Source OQ (anti-hallucination: the
#     fix is an OQ, never a defaulted WCAG/Material/token value).
#
# TECH-AGNOSTIC: the Task G rails are a PRE-stack capture-stage check (vault has
# no stack bound yet) operating on mega-sdd VAULT-FORMAT conventions (workflow
# ceremony nouns + the design_system_flags block generate-intent emits for EVERY
# vault). NO framework pack is needed by design — a new stack does not change
# these vault conventions. Documented in generate-intent/references/vault-contract.md.
#
# Per attestation risk-flag #2: KB cross-check gracefully SKIPS when KB absent
# (not all projects have KB). NEVER halt on missing KB.
#
# Inputs: --cwd, --file-path (the vault doc written)
# Outputs: writes .mega-sdd/.vault-oqs-state.json (OVERWRITE-not-append, current truth)
# Exit: 0=PASS or no-op, 1=FAIL.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg" >&2; exit 2 ;;
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

[ -z "$CWD" ] && { echo "ERROR: --cwd" >&2; exit 2; }
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

# Only validate vault doc files
case "$FILE_PATH" in
  *.mega-sdd/vaults/*/0[1-6]-*.md|*.mega-sdd/vaults/*/vault.json) ;;
  *) exit 0 ;;
esac

STATE_FILE="${CWD}/.mega-sdd/.vault-oqs-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

# W5 two-validators-one-grammar: the OQ-tag + category-bracket regexes are
# imported from _lib/vault_md.py (shared with derive-vault-json.sh) —
# byte-identical to the strings previously inlined here (pinned by
# tests/graph/test-derive-vault-json-vault.sh). Constant-only refactor: NO
# behavior change to windows, rails, or exit codes.
export MEGA_SDD_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, glob, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel = os.path.relpath(file_path, cwd)

try:
    body = open(file_path, errors="replace").read()
except Exception:
    sys.exit(0)

# Build KB inventory (graceful skip if KB absent — risk-flag #2)
kb_dir = os.path.join(cwd, ".mega-sdd", "knowledge-base")
kb_sections = set()
kb_present = os.path.isdir(kb_dir)
if kb_present:
    for kb_file in glob.glob(os.path.join(kb_dir, "**", "*.md"), recursive=True):
        # Section reference format: <kb-file>.md§<section-anchor> OR <kb-file>.md#<section>
        rel_kb = os.path.relpath(kb_file, cwd)
        kb_sections.add(rel_kb)
        # Extract headers from file for section-level matching
        try:
            for line in open(kb_file, errors="replace"):
                m = re.match(r"^#{1,6}\s+(.+?)$", line.rstrip())
                if m:
                    section_id = m.group(1).strip().lower().replace(" ", "-")
                    kb_sections.add(f"{rel_kb}§{section_id}")
                    kb_sections.add(f"{rel_kb}#{section_id}")
        except Exception:
            pass

issues = []

# Walk OQ entries with recommendations → check citations
# Pattern: in markdown OQ blocks, look for "citations:" or "Citation:" lines
# Format: "Citation: knowledge-base/10-domains/foo.md §section-name"
# Or: "citations: - knowledge-base/10-domains/foo.md§section"

# Conservative scope: only check citations that point to knowledge-base/ paths
citation_pattern = re.compile(
    r"(?:Citation|citation|cite|cites)s?:\s*(?:-\s*)?[\"']?(knowledge-base/[^\s\"'\]\,]+)[\"']?",
    re.IGNORECASE,
)
# S4 BC-HANDOFF-1 (mirror of validate-handoff-binding-units.sh): also match
# bind's numeric fresh-OQ form (OQ-001 / OQ-12), not just lettered vault IDs.
# W5: the pattern lives in _lib/vault_md.py (shared with derive-vault-json.sh).
oq_pattern = vault_md.OQ_TAG_RE

# Iter-79 U-GI: independently re-apply the deterministic Auto-classifier heuristic
# text-pattern table (vault-contract.md §Auto-classifier heuristics) to detect an OQ
# whose TEXT clearly reads as `tech` but is tagged `business`/untagged — the lazy-default
# blind spot the prior validator missed (it only checked OQs ALREADY tagged [tech]).
# These are the literal tech patterns from that table; matching is a text-pattern test,
# never LLM judgment.
TECH_TEXT_RE = re.compile(
    r"\btest\s+framework\b|\btesting\s+library\b|\btest\s+runner\b"
    r"|\bnaming\s+convention\b|\bcase\s+style\b|\bfile\s+naming\b"
    r"|\bfile\s+location\b|\bwhere\s+should\b.{0,30}\blive\b|\bdirectory\s+structure\b"
    r"|\berror\s+code\s+format\b|\bresponse\s+shape\b|\bapi\s+envelope\b"
    r"|\bwhich\s+library\b|\bwhich\s+version\b|\bdependency\s+choice\b"
    r"|\bframework\s+standard\b",
    re.IGNORECASE,
)

# Walk the body. Build per-OQ blocks: text from OQ mention up to (but excluding)
# the next OQ mention. This avoids the bug where OQ-A's metadata window catches
# OQ-B's `mode:` line (15-line proximity false-positives).
lines = body.split("\n")

# First pass: find all OQ-line indices
oq_anchors = []  # list of (line_idx, [oq_ids_in_line])
for i, line in enumerate(lines):
    found = oq_pattern.findall(line)
    if found:
        oq_anchors.append((i, found))

# Build per-OQ blocks
oq_blocks = []  # list of (oq_id, block_text)
for idx, (line_i, oqs) in enumerate(oq_anchors):
    # Block ends at next OQ anchor OR 30 lines later (whichever first)
    if idx + 1 < len(oq_anchors):
        block_end = min(oq_anchors[idx + 1][0], line_i + 30)
    else:
        block_end = min(line_i + 30, len(lines))
    block = "\n".join(lines[line_i:block_end])
    for oq in oqs:
        oq_blocks.append((oq, block))

processed_oqs = set()
for oq, window in oq_blocks:
        # ─── Check oq_recommend_citation_invalid (original) ─────────────────
        citations = citation_pattern.findall(window)
        for cit in citations:
            cit_clean = cit.strip().rstrip(",;)")
            if not kb_present:
                continue  # graceful skip (risk-flag #2)
            full_cit = os.path.join(cwd, ".mega-sdd", cit_clean.split("§")[0].split("#")[0])
            if not os.path.exists(full_cit):
                issues.append({
                    "halt_type": "oq_recommend_citation_invalid",
                    "detail": f"OQ {oq} cites KB path that does not exist: {cit_clean}",
                    "oq_id": oq,
                    "citation": cit_clean,
                    "resolved_to": full_cit,
                })

        # Skip schema checks if we already processed this OQ
        if oq in processed_oqs:
            continue
        processed_oqs.add(oq)

        # ─── B.4-followup: detect OQ category for the advisory mis-tag check ──
        # Category indicator keyed on the EMITTED grammar (vault-contract.md
        # §Updated OQ schema): markdown inline bracket `[tech / scan]` / `[business]`,
        # or a quoted `"category": "tech"` when the window is vault.json. The pre-fix
        # regex required a bare `[tech]` / `category: tech` the vault NEVER emits, so
        # it read False on every real OQ → the mis-tag check cry-wolfed on a correctly
        # tagged `[tech / scan]` OQ. The resolution_mode-dependent halts moved to the
        # structured vault.json pass below (their fields are JSON-only).
        # W5: patterns imported from _lib/vault_md.py — byte-identical to the
        # strings previously compiled inline here (two-validators-one-grammar).
        has_tech_category = bool(vault_md.CATEGORY_BRACKET_RE.search(window))
        has_business_category = bool(vault_md.CATEGORY_BRACKET_BUSINESS_RE.search(window))

        # ─── Iter-79 U-GI: oq_misclassified_tech (advisory) ──────────────────
        # OQ text reads tech (matches the heuristic table) but is NOT tagged tech —
        # the lazy-default-to-business blind spot. Advisory (not in the Branch-10
        # blocking filter): surfaces a tag the classifier should have caught.
        if not has_tech_category and TECH_TEXT_RE.search(window):
            mt = TECH_TEXT_RE.search(window)
            issues.append({
                "halt_type": "oq_misclassified_tech",
                "detail": (
                    f"OQ {oq} text matches a tech heuristic pattern (\"{mt.group(0)}\") but is "
                    f"tagged {'[business]' if has_business_category else 'untagged'} — likely a "
                    f"mis-classification (should be category: tech with a resolution_mode)."
                ),
                "oq_id": oq,
                "matched_pattern": mt.group(0),
                "current_tag": "business" if has_business_category else "untagged",
            })

# ─── Structured OQ authority: co-located vault.json open_questions[] ──────────
# The resolution_mode-dependent invariants (§Validation rules, vault-contract.md)
# live in vault.json — the markdown carries the mode inline in the `[tech / scan]`
# bracket, and scan_query / scan_citations / fallback_if_wrong are JSON-only. Read
# the vault.json co-located with the written file as the structured authority, using
# the field grammar the skill actually emits (resolution_mode / scan_query /
# scan_citations / fallback_if_wrong — English schema keys, language-invariant).
# Absent → skip these checks (advisory, graceful). This replaces the pre-fix markdown
# `mode:` / `scan_target:` line regexes, which matched a grammar the vault never wrote
# (dead detection + false-positive on every real vault).
vjson_path = os.path.join(os.path.dirname(file_path), "vault.json")
vj_oqs = []
if os.path.isfile(vjson_path):
    try:
        vj = json.load(open(vjson_path, errors="replace"))
        vj_oqs = vj.get("open_questions") or []
    except Exception:
        vj_oqs = []
for oqe in vj_oqs:
    if not isinstance(oqe, dict):
        continue
    tag = str(oqe.get("tag") or oqe.get("id") or "OQ-?")
    # startswith("tech") tolerates a roll-up-header form (e.g. "Technical") that a vault
    # may mirror into vault.json — a `tech`/`Tech`/`technical` category still gets checked;
    # `business` never starts with "tech" so it is untouched.
    category = str(oqe.get("category") or "").strip().lower()
    rmode = str(oqe.get("resolution_mode") or "").strip().lower()
    # tech OQ MUST declare a resolution_mode.
    if category.startswith("tech") and not rmode:
        issues.append({
            "halt_type": "oq_tech_missing_mode",
            "detail": f"OQ {tag} has category: tech but no resolution_mode (expected scan / recommend / hard_rule / blocking)",
            "oq_id": tag,
            "category": "tech",
        })
        continue
    # resolution_mode: scan MUST populate scan_query.
    if rmode == "scan" and not str(oqe.get("scan_query") or "").strip():
        issues.append({
            "halt_type": "oq_scan_missing_query",
            "detail": f"OQ {tag} has resolution_mode: scan but scan_query is empty",
            "oq_id": tag,
            "resolution_mode": "scan",
        })
    # resolution_mode: recommend MUST carry recommendation + rationale + >=1
    # scan_citations + fallback_if_wrong (vault-contract.md §Validation rules).
    if rmode == "recommend":
        missing_fields = [f for f in ("recommendation", "rationale", "fallback_if_wrong")
                          if not str(oqe.get(f) or "").strip()]
        cites = oqe.get("scan_citations")
        if not (isinstance(cites, list) and len(cites) >= 1):
            missing_fields.append("scan_citations")
        if missing_fields:
            issues.append({
                "halt_type": "oq_recommend_underspecified",
                "detail": f"OQ {tag} has resolution_mode: recommend but missing required field(s): {missing_fields}",
                "oq_id": tag,
                "resolution_mode": "recommend",
                "missing_fields": missing_fields,
            })

# ═══════════════════════════════════════════════════════════════════════════
# Task G — Operator-workflow-UX capture + Design-Source OQ (two vault-WIDE rails)
#
# These rails operate on the WHOLE vault (04-flows + 02-architecture + vault.json),
# not just the single written file — a workflow flow lives in 04-flows while its
# operator-surface requirement lives in 02-architecture and its Design-Source OQ
# lives in vault.json. We locate the active vault from --cwd and read all three.
#
# TECH-AGNOSTIC: this is a PRE-stack capture-stage check (the vault has no stack
# bound yet), so there is NO framework pack here by design. The vocabulary below
# is mega-sdd VAULT-FORMAT convention (the workflow ceremony nouns + the
# `design_system_flags` block that generate-intent emits for EVERY vault
# regardless of target stack) — exactly like the F-U-/F-S- flow taxonomy that
# flow-coverage hardcodes. A NEW STACK does not change these vault conventions, so
# no pack section is needed. Documented in generate-intent/references/vault-contract.md.
#
# ANTI-HALLUCINATION: both rails demand an Open Question (operator surface req OR a
# Design-Source OQ), NEVER a defaulted WCAG/Material/token value. The rails only
# assert that the maker-checker miss was CAPTURED, not that a value was invented.
# ═══════════════════════════════════════════════════════════════════════════

# Closed VAULT-FORMAT flow taxonomy (generate-intent/references/vault-contract.md
# §Flow ID prefixes): F-U- user-facing; F-S- system; F-C- cross-cutting; F-X-
# custom. A multi-stage approval (maker-checker) surface is user-facing, so we
# scope to F-U-/prefix-less flows and EXCLUDE the internal classes.
SYSTEM_FLOW_RE = re.compile(r"\bF-[SCX]-?\d+\b", re.IGNORECASE)

# A workflow / maker-checker / multi-stage-approval flow signal (closed vocabulary
# of stack-neutral ceremony nouns). A flow qualifies when EITHER its actor/title
# line shows a maker->checker hand-off chain OR its step body carries >= 2 distinct
# decision (approve/reject/review/confirm) transition steps. One decision step alone
# is a simple submit; two or more is a multi-stage approval needing an operator surface.
DECISION_STEP_RE = re.compile(
    # ADV-03: inflection-tolerant — bare lemmas missed `approves`/`reviews`/`confirms`/`rejected`
    r"\b(approv(?:e|es|ed|al|ing)|reject(?:s|ed|ing|ion)?|review(?:s|ed|ing)?|"
    r"confirm(?:s|ed|ing|ation)?|countersign(?:s|ed|ing|ature)?|"
    r"second\s*approval|dual[\s-]?key|four[\s-]?eyes|maker[\s-]?checker)\b",
    re.IGNORECASE,
)
MAKER_CHECKER_CHAIN_RE = re.compile(
    r"\b(maker)\b.*?\b(checker|approver|confirm|reviewer)\b",
    re.IGNORECASE,
)
STAGE_ARROW_RE = re.compile(r"(->|→|=>|»)")  # actor-chain hand-off arrows


_NUMBERED_STEP_RE = re.compile(r"^\s*\d+[.)]\s+\S")            # N. | N) (any indent)
_TOPLEVEL_BULLET_RE = re.compile(r"^[-*+]\s+\S")              # top-level bullet (col 0)
_MERMAID_EDGE_RE = re.compile(r"--+>|==+>|-\.->|→")            # mermaid/flowchart edges


def _split_flow_steps(body):
    """Split a flow body into per-step blocks, FORMAT-AWARE (ADV-02), mirroring flow-coverage:
    numbered `N.`/`N)` if present (top-level bullets are then post-conditions/sub-notes, not
    steps); else top-level `-`/`*`/`+` bullets; else mermaid edge lines. A numbered-only parser
    silently PASSed mermaid/bullet maker-checker flows — leaving both operator-UX rails inert."""
    lines = body.splitlines()
    if any(_NUMBERED_STEP_RE.match(ln) for ln in lines):
        step_re = _NUMBERED_STEP_RE
    elif any(_TOPLEVEL_BULLET_RE.match(ln) for ln in lines):
        step_re = _TOPLEVEL_BULLET_RE
    elif any(_MERMAID_EDGE_RE.search(ln) for ln in lines):
        return [ln for ln in lines if _MERMAID_EDGE_RE.search(ln)]
    else:
        return []
    blocks, cur = [], None
    for line in lines:
        if step_re.match(line):
            if cur is not None:
                blocks.append("\n".join(cur))
            cur = [line]
        elif cur is not None:
            if line.strip() == "" or re.match(r"^\s+\S", line):
                cur.append(line)
            elif line.strip().startswith("**"):
                blocks.append("\n".join(cur))
                cur = None
            else:
                cur.append(line)
    if cur is not None:
        blocks.append("\n".join(cur))
    return blocks


# ── Language-invariant multi-stage markers (vault-contract.md §stages-propagation) ──
# A maker→checker / multi-step-APPROVAL flow is emitted with a `stages:` YAML block whose
# per-stage `actor_role:` keys name the acting role, a Mermaid `stateDiagram`, and a
# `_kb_source` stamp. The keys + diagram-type name are Tier-1 frozen (output-language.md
# §do-not-translate) — English regardless of the vault's prose language. The target is a
# MULTI-ACTOR approval (≥2 distinct actor_role values = maker + checker), NOT any staged
# flow: a single-actor wizard has a stages: block too but needs no operator worklist, so
# a bare stages: block is NOT sufficient — count DISTINCT actor_role values.
ACTOR_ROLE_RE    = re.compile(r"\bactor_role\s*:\s*[\"']?([^\"'\n]+)", re.IGNORECASE)
STATE_DIAGRAM_RE = re.compile(r"\bstateDiagram(?:-v2)?\b")


def _flow_workflow_verdict(header, fbody):
    """Per-flow tristate: 'yes' (a user-facing multi-ACTOR approval workflow),
    'unverifiable' (a Mermaid stateDiagram whose approval-ness cannot be judged because
    its labels are non-English — escalate to an advisory, NEVER silent-PASS), or 'no'."""
    if SYSTEM_FLOW_RE.search(header):
        return "no"  # system / cross-cutting / custom — no operator boundary
    # ── Language-invariant structural signal: ≥2 DISTINCT actor_role values ──
    roles = set(m.group(1).strip().lower() for m in ACTOR_ROLE_RE.finditer(fbody))
    if len(roles) >= 2:
        return "yes"
    # ── English prose signals (backward-compat for non-staged English flows) ──
    hdr_line = header.splitlines()[0] if header else ""
    head_window = hdr_line + "\n" + "\n".join(fbody.splitlines()[:6])
    if MAKER_CHECKER_CHAIN_RE.search(head_window) and STAGE_ARROW_RE.search(head_window):
        return "yes"
    if sum(1 for blk in _split_flow_steps(fbody) if DECISION_STEP_RE.search(blk)) >= 2:
        return "yes"
    # ── Residual: a stateDiagram whose approval-ness can't be judged BECAUSE the labels are
    # non-English (the English decision heuristic can't run). An ENGLISH state machine with
    # no approval signal is NOT an approval workflow → 'no' (avoids crying wolf on benign
    # session/order/payment lifecycle flows). Only non-English → 'unverifiable' advisory.
    if STATE_DIAGRAM_RE.search(fbody) and not vault_looks_english(fbody):
        return "unverifiable"
    return "no"


def vault_workflow_verdict(flows_text):
    """Vault-level rollup of per-flow verdicts: 'yes' > 'unverifiable' > 'no'."""
    parts = re.split(r"^(###\s+.*)$", flows_text, flags=re.MULTILINE)
    verdicts = []
    i = 1
    while i < len(parts):
        header = parts[i].strip()
        fbody = parts[i + 1] if i + 1 < len(parts) else ""
        i += 2
        verdicts.append(_flow_workflow_verdict(header, fbody))
    if "yes" in verdicts:
        return "yes"
    if "unverifiable" in verdicts:
        return "unverifiable"
    return "no"


# Operator-facing surface vocabulary (stack-neutral VAULT-FORMAT tells). Presence
# of ANY in the vault's prose docs (02-architecture, 01-overview, 04-flows) OR
# vault.json counts the operator surface as MODELED. These are the four surfaces
# generate-intent must capture: worklist/inbox, decision affordance, human state
# labels, audit timeline.
OPERATOR_SURFACE_RE = re.compile(
    r"\b(work[\s-]?list|inbox|task[\s-]?list|pending[\s-]?(?:queue|items|approvals?)|"
    r"availableactions|decision[\s-]?(?:affordance|card|panel)|approve\s*/\s*reject|"
    r"state[\s-]?label|status[\s-]?label|human[\s-]?readable[\s-]?(?:state|status)|"
    r"audit[\s-]?(?:timeline|trail|history)|workflow[\s-]?transitions?[\s-]?(?:audit|history|timeline))\b",
    re.IGNORECASE,
)

# Design-Source OQ shape: an Open Question that captures the missing design source
# (tokens / a11y / voice-brand). Matches a tag like OQ-DESIGN... OR OQ text that
# names a design-system source concern. Mirrors the grep used to confirm TF state:
#   OQ-.*(DESIGN|UI|UX|TOKEN|A11Y|VOICE|BRAND) | design-source
DESIGN_SOURCE_OQ_RE = re.compile(
    r"(OQ-[A-Z0-9-]*(?:DESIGN|TOKEN|A11Y|VOICE|BRAND)[A-Z0-9-]*)|"
    r"design[\s-]?source|design[\s-]?system\s+source|"
    r"(?:design\s+tokens?|accessibility|voice\s*/?\s*brand)\b[^\n]{0,80}\b(?:source|provide|missing|absent|open\s+question)\b",
    re.IGNORECASE,
)


def _read(path):
    try:
        return open(path, errors="replace").read()
    except Exception:
        return ""


# PURE English function words only — deliberately NO tech nouns (user/system/service/…):
# those survive as loanwords in an Indonesian-mix vault and would falsely inflate the
# ratio (an ID-mix vault crossing the bar then cry-wolfs operator_surface_missing).
# Pure function words (the/and/is/to/…) are near-absent in Indonesian prose (dan/adalah/
# ke/untuk/…), so they cleanly separate an English vault (~15-40%) from ID / ID-mix (~0-3%).
_EN_FUNC_RE = re.compile(
    r"\b(the|and|is|are|a|an|to|of|for|with|in|on|by|as|at|from|when|then|if|this|that|"
    r"all|be|been|being|has|have|had|via|not|no|but|or|which|must|should|will|can|each|any)\b",
    re.IGNORECASE,
)


def vault_looks_english(text):
    """Cheap heuristic gating the operator-surface PRESENCE check (an English prose
    regex, OPERATOR_SURFACE_RE). Enough common English function words → the check is
    reliable; almost none (an Indonesian / other-language / bilingual vault) → it is NOT,
    so the caller escalates to an advisory 'uncheckable' rather than a FALSE
    'operator_surface_missing'. Defaults to True (run the check) on sparse text so terse
    English vaults stay backward-compatible."""
    words = re.findall(r"[A-Za-z]{2,}", text)
    if len(words) < 25:
        return True
    return (len(_EN_FUNC_RE.findall(text)) / len(words)) >= 0.08


# Locate the active vault under --cwd that holds 04-flows.md (the workflow source).
vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
active_vault_dir = None
if os.path.isdir(vault_root):
    cands = []
    for d in sorted(glob.glob(os.path.join(vault_root, "*"))):
        if os.path.isdir(d) and os.path.isfile(os.path.join(d, "04-flows.md")):
            # prefer the vault the written file belongs to; else most-recent flows
            cands.append(d)
    if cands:
        # Prefer the vault dir that contains the written file_path, if any.
        active_vault_dir = next(
            (d for d in cands if os.path.abspath(file_path).startswith(os.path.abspath(d) + os.sep)),
            None,
        )
        if active_vault_dir is None:
            # Fallback: the vault with the largest 04-flows (the phase under work).
            active_vault_dir = max(
                cands, key=lambda d: os.path.getsize(os.path.join(d, "04-flows.md"))
            )

if active_vault_dir:
    flows_text = _read(os.path.join(active_vault_dir, "04-flows.md"))
    if flows_text:
        # Gather the surfaces-evidence corpus + design_system_flags ONCE. Rail 2
        # (design_source) reads only language-invariant inputs (design_system_flags JSON
        # + frozen OQ-DESIGN tokens), so it runs unconditionally (H4 — it was wrongly
        # gated behind the English workflow detector, so an Indonesian vault could never
        # reach it). Rail 1 (operator_surface) needs the workflow verdict.
        prose_corpus = flows_text
        for fn in ("02-architecture.md", "01-overview.md", "03-data-model.md"):
            prose_corpus += "\n" + _read(os.path.join(active_vault_dir, fn))
        vault_json_text = _read(os.path.join(active_vault_dir, "vault.json"))
        # H2 (defaulted-standard scan) + the Design-Source-OQ escape hatch must ALSO see
        # 05-decisions.md (design-system ADOPTION decisions) and 06-constraints.md (the
        # canonical a11y / NFR home) — the natural place a WCAG/Material/token value lands.
        # prose_corpus stays 04/02/01/03 (Rail 1 operator-surface + vault_looks_english keep
        # their original scope, unperturbed); design_corpus adds 05/06 for H2 + escape hatch.
        design_corpus = (prose_corpus
                         + "\n" + _read(os.path.join(active_vault_dir, "05-decisions.md"))
                         + "\n" + _read(os.path.join(active_vault_dir, "06-constraints.md")))
        full_corpus = design_corpus + "\n" + vault_json_text
        vault_name = os.path.basename(active_vault_dir)
        has_design_source_oq = bool(DESIGN_SOURCE_OQ_RE.search(full_corpus))

        # ── Rail 2: design_source_oq_missing (language-invariant — UNCONDITIONAL) ──
        # UI components exist but HAS_TOKENS & HAS_A11Y & HAS_VOICE_BRAND are ALL false
        # AND no Design-Source OQ. Anti-hallucination: the fix is an OQ, never a defaulted
        # WCAG/Material/token value. Inputs (design_system_flags + OQ-DESIGN tokens) are
        # language-invariant, so this holds on any-language vault.
        dsf = {}
        m_dsf = re.search(r'"design_system_flags"\s*:\s*\{(.*?)\}', vault_json_text, re.DOTALL)
        if m_dsf:
            for fm in re.finditer(r'"(HAS_[A-Z0-9_]+)"\s*:\s*(true|false)', m_dsf.group(1)):
                dsf[fm.group(1)] = (fm.group(2) == "true")
        has_ui_components = dsf.get("HAS_UI_COMPONENTS", False)
        all_design_false = (
            dsf.get("HAS_TOKENS") is False
            and dsf.get("HAS_A11Y") is False
            and dsf.get("HAS_VOICE_BRAND") is False
            and ("HAS_TOKENS" in dsf)  # the block exists & declares them
        )
        if has_ui_components and all_design_false and not has_design_source_oq:
            issues.append({
                "halt_type": "design_source_oq_missing",
                "detail": (
                    "design_system_flags shows HAS_UI_COMPONENTS=true but "
                    "HAS_TOKENS / HAS_A11Y / HAS_VOICE_BRAND are ALL false, and no "
                    "Design-Source Open Question was emitted. UI exists with no "
                    "design-system source captured."
                ),
                "vault": vault_name,
                "remedy": (
                    "Emit a high-priority Design-Source OQ requesting the design "
                    "tokens / accessibility target / voice-brand source. DO NOT "
                    "default WCAG/Material values — capture the gap as an OQ only."
                ),
            })

        # ── Rail 1: operator_surface_missing (needs the workflow verdict) ──
        # tristate: 'yes' run the check; 'unverifiable' escalate to an advisory (a
        # stateDiagram workflow whose stage/role labels could not be parsed — likely
        # non-English); 'no' skip. When a workflow IS present but the operator-surface
        # PRESENCE regex (English prose) is unreliable (non-English vault), emit the
        # SKIP-advisory 'operator_surface_uncheckable' instead of a FALSE
        # operator_surface_missing — never silent-PASS, never cry-wolf.
        _uncheckable = {
            "halt_type": "operator_surface_uncheckable",
            "detail": (
                "04-flows declares a workflow-shaped flow (Mermaid stateDiagram / "
                "multi-stage) but its operator surface could not be verified — the "
                "surface-presence check is English-prose and the vault reads non-English "
                "(or the stage/role labels are non-English). The operator-surface rail "
                "was SKIPPED, not passed."
            ),
            "vault": vault_name,
            "severity": "advisory",
            "remedy": (
                "Add a `stages:` block (`stage_id` + `actor_role`) to the flow so the "
                "maker→checker surface can be verified, OR confirm an operator surface "
                "(worklist/inbox, decision affordance, state labels, audit timeline) or a "
                "Design-Source OQ exists."
            ),
        }
        wf_verdict = vault_workflow_verdict(flows_text)
        if wf_verdict == "yes":
            has_operator_surface = bool(OPERATOR_SURFACE_RE.search(prose_corpus))
            if has_operator_surface or has_design_source_oq:
                pass  # operator surface modeled (or Design-Source OQ escape hatch) — captured
            elif vault_looks_english(prose_corpus):
                issues.append({
                    "halt_type": "operator_surface_missing",
                    "detail": (
                        "04-flows declares a multi-stage approval (maker-checker) "
                        "workflow but the vault models NO operator-facing surface "
                        "(worklist/inbox, decision affordance, human-readable state "
                        "labels, audit timeline) and carries NO Design-Source OQ. The "
                        "operators have nowhere to act on items awaiting their decision."
                    ),
                    "vault": vault_name,
                    "remedy": (
                        "In generate-intent, model the operator surface as FIRST-CLASS "
                        "requirements GROUNDED in the flows (never invented), OR emit a "
                        "high-priority Design-Source Open Question if the surface design "
                        "is genuinely undecided."
                    ),
                })
            else:
                issues.append(_uncheckable)
        elif wf_verdict == "unverifiable":
            issues.append(_uncheckable)

        # ── H2: no-defaulted-standards positive detection (advisory) ──────────
        # The moat forbids a DEFAULTED design standard: a WCAG level / Material design
        # system / specific palette-token value may appear ONLY if a source supplies it
        # (SKILL.md §No defaulted standards). Rail 2 checks only the INVERSE (a
        # Design-Source OQ present) — it never catches a branded standard VALUE shipped
        # with no citation. A defaulted-standard token whose own line carries no source
        # anchor, in a vault with no Design-Source OQ, is likely fabricated → advisory.
        # Brand/token names are language-neutral, so this holds on any-language vault.
        DEFAULTED_STD_RE = re.compile(
            # WCAG: version OPTIONAL — the canonical phrasing is the bare level "WCAG AA"
            # (the plugin's own product-style-map emits `a11y_baseline: "WCAG AA"`); longest
            # level first. "WCAG accessibility"/"WCAG conformance" do NOT match (word boundary).
            r"\bWCAG\s*(?:[\d.]+\s*)?(?:AAA|AA|A)\b|"
            # Material DESIGN system only — NOT a bare "Material 3" (which collides with
            # ERP/warehouse material-numbering; domain-agnosticism). Requires the design word.
            r"\bMaterial\s*Design(?:\s*3)?\b|\bMaterial\s*You\b|\bMD3\b|"
            # full Tailwind palette scale (the half-list let bg-purple-600/text-teal-600 slip);
            # a semantic token like bg-primary-600 is NOT a defaulted palette color → excluded.
            r"\b(?:bg|text|border|ring)-(?:gray|slate|zinc|neutral|stone|red|orange|amber|"
            r"yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|"
            r"pink|rose)-\d{2,3}\b",
            re.IGNORECASE,
        )
        _SRC_ON_LINE = re.compile(
            r"§|\(\s*(?:source|see|per|ref|from)\b|\bhttps?://|\[\[|\bPRD\b|\bBRD\b|"
            r"\bKB\b|knowledge-base|codebase-map|binding|figma",
            re.IGNORECASE,
        )
        uncited_std = []
        for ln in design_corpus.splitlines():
            mm = DEFAULTED_STD_RE.search(ln)
            if mm and not _SRC_ON_LINE.search(ln):
                uncited_std.append(mm.group(0).strip())
        if uncited_std and not has_design_source_oq:
            issues.append({
                "halt_type": "defaulted_standard_uncited",
                "detail": (
                    "a branded design standard (" + ", ".join(sorted(set(uncited_std))[:5]) +
                    ") appears with no source citation on its line and the vault carries no "
                    "Design-Source OQ — a defaulted / fabricated standard the anti-halu rail "
                    "forbids."
                ),
                "vault": vault_name,
                "severity": "advisory",
                "remedy": (
                    "Cite the source that supplied the value (PRD §, Figma frame, "
                    "codebase-map, KB), or capture the gap as a Design-Source OQ — never "
                    "default a WCAG/Material/token value."
                ),
            })

# Soft advisories (a "couldn't verify" or low-confidence signal) surface as WARN, not
# FAIL, so they contribute WARN-at-most to the /mega-sdd:analyze rollup — vault_oqs sits
# in the non-advisory bucket, where a FAIL flips the overall report status. Hard issues
# (missing mode/query, an unmodeled operator surface, a mis-tagged OQ, a bad citation)
# stay FAIL. This keeps an Indonesian "uncheckable" or a lone defaulted-standard hint
# from reading as loud as a real gap.
_SOFT_ADVISORY = {"operator_surface_uncheckable", "defaulted_standard_uncited"}
_hard_issues = [i for i in issues if i.get("halt_type") not in _SOFT_ADVISORY]
status = "FAIL" if _hard_issues else ("WARN" if issues else "PASS")
state = {
    "ts": ts,
    "checked_file": rel,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "kb_present": kb_present,
    "next_action": (
        "Vault OQ citations valid, operator surface captured (or N/A), Design-Source OQ present where needed (or N/A)."
        if status == "PASS"
        else (
            f"{len(issues)} vault-OQ issue(s) detected (OQ-citation integrity and/or "
            "operator_surface_missing / design_source_oq_missing). Re-run "
            "/mega-sdd:generate-intent to model the operator surface grounded in the "
            "flows, emit a Design-Source OQ where UI exists but design source is "
            "missing (never default WCAG/Material values), or fix OQ citations via "
            "/mega-sdd:resolve-oq."
        )
    ),
}
try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception:
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status in ("PASS", "WARN") else 1)
PYEOF

exit $?

#!/usr/bin/env bash
# validate-unit-spec.sh — Phase B slice B.3 [PostToolUse-validate].
#
# Validates 3 unit-spec integrity halts on Write|Edit of unit files:
#   - unit_underspecified         (required frontmatter fields missing)
#   - hard_rule_unparseable       (Hard Rule v1 grammar line unparseable)
#   - starterkit_rule_citation_missing (starterkit-derived rule lacks citation)
#
# Per attestation:
#   #12 unit_underspecified: target_files re-derive C1; acceptance_test C2 escalate
#       (this validator detects target_files presence; acceptance_test missing for
#        non-trivial units flagged as escalate)
#   #13 hard_rule_unparseable: re-emit C1; DROP C2 escalate after 2 attempts
#       (this validator detects first attempt; retry tracking via state file)
#
# Detection-only at hook layer; auto-fix is generate-units's responsibility.
#
# Inputs: --cwd=<project> --file-path=<unit-file>
# Outputs: JSON report stdout; writes .mega-sdd/.unit-spec-state.json
# Exit: 0=PASS, 1=FAIL, 2=error.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
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


if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd required" >&2; exit 2
fi
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Quick path filter: only validate unit files. Accept the bound layout
# (*-bound/units/...) AND the plain vault layout (*/vaults/*/units/U-*.md) so the
# render-test check (slice D) reaches non-bound vaults too — consistent with the
# PostToolUse dispatch broadening in commit e945991 (Task A).
case "$FILE_PATH" in
  *-bound/units/U-*.md|*-bound/units/U-*/unit.md) ;;
  *.mega-sdd/vaults/*/units/U-*.md|*.mega-sdd/vaults/*/units/U-*/unit.md) ;;
  *) exit 0 ;;
esac

STATE_FILE="${CWD}/.mega-sdd/.unit-spec-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: state dir" >&2; exit 2; }

# ── Pack-driven render-test signatures (code-delivery slice D, tech-agnostic) ──
# The detail-view glob is read from the active framework pack `## Test patterns`
# section via the shared resolver — NEVER hardcoded. A pack that omits the section
# (or omits detail_view_glob) → the render check SKIPs gracefully; the other
# unit-spec checks still run. Adding a stack = adding a pack, never editing this.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
TEST_PATTERNS_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  TEST_PATTERNS_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Test patterns" --quiet 2>/dev/null) || TEST_PATTERNS_SECTION=""
fi

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" \
TEST_PATTERNS_SECTION="$TEST_PATTERNS_SECTION" python3 <<'PYEOF'
import json
import os
import re
import sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
test_patterns_section = os.environ.get("TEST_PATTERNS_SECTION", "")
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel_path = os.path.relpath(file_path, cwd)

try:
    body = open(file_path).read()
except Exception as e:
    print(f"ERROR: cannot read {file_path}: {e}", file=sys.stderr)
    sys.exit(2)

issues = []

# Extract frontmatter
fm_match = re.match(r"^---\n(.*?)\n---\n?", body, re.DOTALL)
if not fm_match:
    issues.append({
        "halt_type": "unit_underspecified",
        "detail": "unit has no frontmatter YAML block (--- ... ---)",
        "missing_fields": ["entire_frontmatter"],
    })
    state = {
        "ts": ts, "checked_file": rel_path, "status": "FAIL",
        "issues_count": len(issues), "issues": issues,
    }
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state, indent=2))
    sys.exit(1)

fm = fm_match.group(1)
body_after_fm = body[fm_match.end():]

# ─── Check 1: unit_underspecified — required frontmatter fields ──────────────
# Accept either Layout A (unit_id) or Layout B (id) for unit identifier.
field_present = {}
for f in ["unit_id", "id", "title", "task_type", "target_files", "vault_source", "vault_anchors"]:
    if re.search(rf"^{f}:", fm, re.MULTILINE):
        field_present[f] = True

unit_id = None
m = re.search(r"^(?:unit_id|id):\s*(\S+)", fm, re.MULTILINE)
if m: unit_id = m.group(1)
if not unit_id:
    if os.path.basename(file_path) == "unit.md":
        unit_id = os.path.basename(os.path.dirname(file_path))
    else:
        unit_id = os.path.basename(file_path).replace(".md", "")

task_type_match = re.search(r"^task_type:\s*(\w+)", fm, re.MULTILINE)
task_type = task_type_match.group(1) if task_type_match else None

# Required fields (lenient: accept unit_id OR id)
missing_fields = []
if "unit_id" not in field_present and "id" not in field_present:
    missing_fields.append("unit_id|id")
if "title" not in field_present:
    missing_fields.append("title")
if "task_type" not in field_present:
    missing_fields.append("task_type")
# vault_source OR vault_anchors (layout B uses vault_anchors)
if "vault_source" not in field_present and "vault_anchors" not in field_present:
    missing_fields.append("vault_source|vault_anchors")
# target_files presence (for verify, may be empty list; for create/extend, must have entries)
if "target_files" not in field_present:
    missing_fields.append("target_files")

if missing_fields:
    issues.append({
        "halt_type": "unit_underspecified",
        "detail": f"unit {unit_id} frontmatter missing required field(s): {missing_fields}",
        "unit_id": unit_id,
        "task_type": task_type,
        "missing_fields": missing_fields,
    })

# Anchors check per task_type (only when task_type known + body has frontmatter)
if task_type in ("verify", "extend"):
    if not re.search(r"^##\s+Anchors?", body_after_fm, re.MULTILINE | re.IGNORECASE):
        issues.append({
            "halt_type": "unit_underspecified",
            "detail": f"unit {unit_id} task_type={task_type} requires `## Anchors` section",
            "unit_id": unit_id,
            "task_type": task_type,
            "missing_sections": ["Anchors"],
        })

# Migration notes check for extend
if task_type == "extend":
    if not re.search(r"^##\s+Migration\s+notes?", body_after_fm, re.MULTILINE | re.IGNORECASE):
        issues.append({
            "halt_type": "unit_underspecified",
            "detail": f"unit {unit_id} task_type=extend requires `## Migration notes` section",
            "unit_id": unit_id,
            "task_type": task_type,
            "missing_sections": ["Migration notes"],
        })

# ─── Check 2: hard_rule_unparseable (v1 grammar — 5-types) ───────────────────
# Extract `## Hard rules` section
hr_match = re.search(r"^##\s+Hard\s+rules?\s*\n(.*?)(?=\n##\s|\Z)", body_after_fm, re.MULTILINE | re.IGNORECASE | re.DOTALL)
if hr_match:
    hr_block = hr_match.group(1)
    # v1 grammar: each non-blank, non-comment line MUST match one of 5 productions:
    #   1. "DO NOT modify <path>"
    #   2. "DO NOT add new <manifest> dependencies"
    #   3. "<path-glob> MUST follow <case-style> naming"
    #   4. "function <name> MUST preserve signature: <type-sig>"
    #   5. "file <path> MUST exist after bolt"
    grammar_patterns = [
        re.compile(r"^-\s*DO NOT modify\s+\S+"),
        re.compile(r"^-\s*DO NOT add new\s+\S+\s+dependencies"),
        re.compile(r"^-\s*\S+\s+MUST follow\s+(?:kebab-case|camelCase|snake_case|PascalCase)\s+naming"),
        re.compile(r"^-\s*function\s+\S+\s+MUST preserve signature:\s+.*"),
        re.compile(r"^-\s*file\s+\S+\s+MUST exist after bolt"),
        re.compile(r"^-\s*MUST\b.*"),  # Looser fallback for general MUST-style rules (Iter 1+)
        re.compile(r"^-\s*MUST NOT\b.*"),
        re.compile(r"^-\s*DO NOT\b.*"),  # Generic DO NOT (anti-pattern style)
    ]
    unparseable_lines = []
    for ln in hr_block.split("\n"):
        s = ln.strip()
        if not s:
            continue
        if s.startswith("#") or s.startswith("```") or s.startswith("<"):
            continue  # comment / code-fence / HTML marker — skip
        if not s.startswith("- "):
            continue  # not a rule item (could be prose)
        # Try each grammar pattern
        if not any(p.match(s) for p in grammar_patterns):
            # Check if it's ast-grep YAML (multi-line block; can't parse fully here)
            # For walking-skeleton: any line starting with `- ` that doesn't match v1 OR
            # contain ast-grep YAML keywords (rule:, language:) is unparseable.
            if not re.search(r"(rule|language|pattern):", s):
                unparseable_lines.append(s)
    if unparseable_lines:
        issues.append({
            "halt_type": "hard_rule_unparseable",
            "detail": f"unit {unit_id} has {len(unparseable_lines)} unparseable Hard Rule line(s)",
            "unit_id": unit_id,
            "unparseable_lines": unparseable_lines[:5],  # cap at 5 for readability
        })

# ─── Check 3: starterkit_rule_citation_missing ──────────────────────────────
# A Hard Rule line referencing starterkit-context.yaml MUST have a "Citation:" sub-line.
# Pattern: rule mentions "starterkit" or references starterkit_relevance fields.
sk_consumed_match = re.search(r"^starterkit_context_consumed:\s*(true|false)", fm, re.MULTILINE | re.IGNORECASE)
if sk_consumed_match and sk_consumed_match.group(1).lower() == "true" and hr_match:
    hr_block = hr_match.group(1)
    # Look for any rule line, then check if next non-blank lines contain Citation: starterkit-context
    # Walking-skeleton heuristic: any rule with "starterkit" hint should have "Citation: starterkit-context.yaml"
    # following within 5 lines.
    lines = hr_block.split("\n")
    missing_citations = []
    i = 0
    while i < len(lines):
        ln = lines[i].strip()
        if ln.startswith("- ") and "starterkit" in ln.lower():
            # Check next 5 lines for Citation: starterkit-context
            found_citation = False
            for j in range(i, min(i + 6, len(lines))):
                if "Citation: starterkit-context" in lines[j]:
                    found_citation = True
                    break
            if not found_citation:
                missing_citations.append(ln[:100])
        i += 1
    if missing_citations:
        issues.append({
            "halt_type": "starterkit_rule_citation_missing",
            "detail": f"unit {unit_id} has starterkit-derived Hard Rule(s) without `Citation: starterkit-context.yaml §<path>` annotation",
            "unit_id": unit_id,
            "missing_citations_excerpts": missing_citations[:5],
        })

# ─── Check 4 (slice 3 v3.58.0+): Hard Rule citation trace ────────────────────
# Every Hard Rule SHOULD have a traceable source: starterkit-context.yaml (already
# checked above), OR binding.md "## Suggested Unit Hard Rules" section, OR KB
# anti-pattern reference. This check is advisory — Hard Rules without citation
# get a "trace_missing" flag for review.
if hr_match:
    hr_block = hr_match.group(1)
    untraced_rules = []
    lines = hr_block.split("\n")
    i = 0
    while i < len(lines):
        ln = lines[i].strip()
        if ln.startswith("- ") and not ln.startswith("- #"):
            # Check next 5 lines for ANY Citation: or Source: or Ref: annotation
            found_trace = False
            for j in range(i, min(i + 6, len(lines))):
                ck = lines[j]
                if re.search(r"(?:Citation|Source|Ref(?:erence)?|From):", ck, re.IGNORECASE):
                    found_trace = True
                    break
                # Inline mention of binding/KB/starterkit/constitution = also count as trace
                if re.search(r"\b(?:binding\.md|knowledge-base|starterkit-context|constitution\.md|D-\d+|C-\d+|CONFLICT-)", ck, re.IGNORECASE):
                    found_trace = True
                    break
            if not found_trace:
                untraced_rules.append(ln[:120])
        i += 1
    if untraced_rules:
        # Advisory-level — NOT a hard halt. Flag with low severity.
        issues.append({
            "halt_type": "hard_rule_trace_missing",
            "detail": f"unit {unit_id} has {len(untraced_rules)} Hard Rule(s) without traceable source (advisory; rules should cite binding/KB/starterkit/constitution)",
            "unit_id": unit_id,
            "untraced_rules": untraced_rules[:5],
            "severity": "advisory",
        })

# ─── Check 5 (code-delivery slice D): render_test_missing ────────────────────
# Any unit whose target_files include a DETAIL/SHOW view (matching the active
# framework pack `## Test patterns` -> detail_view_glob) MUST carry a structured
# acceptance_test entry of type/kind `render`. Detection is STRUCTURED, never a
# fuzzy grep-for-"render": a prose `## Tests` bullet named "...renders..." does NOT
# satisfy this (that was the false-negative trap). The detail-view glob is
# PACK-DECLARED — no `## Test patterns` section / no detail_view_glob => this check
# SKIPs (the stack declared no detail-view convention); the checks above still run.
def _glob_to_regex(pat):
    """Translate a pack glob (with `**` = any-depth) into a compiled regex. Mirrors
    validate-flow-coverage.sh so the same `resources/views/**/show.blade.php` shape
    matches both nested and direct paths."""
    i, out, n = 0, ["(?s:"], len(pat)
    while i < n:
        c = pat[i]
        if c == "*":
            if pat[i:i + 3] == "**/":
                out.append("(?:.*/)?"); i += 3; continue
            if pat[i:i + 2] == "**":
                out.append(".*"); i += 2; continue
            out.append("[^/]*"); i += 1; continue
        if c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append(r")\Z")
    return re.compile("".join(out))


def _glob_match(path, rx):
    if rx.match(path):
        return True
    # also try suffix match (a target path may carry leading dirs the glob omits)
    return rx.match(path.split("/", 1)[-1]) is not None if "/" in path else False


def _parse_detail_view_glob(section_text):
    """Pull `detail_view_glob:` from the FIRST yaml fence of the resolver section dump
    (most-specific pack wins). Returns the glob string or None. We ONLY parse inside a
    real ```yaml fence — a pack that declares the §Test patterns PRINCIPLE in prose but
    no concrete yaml (e.g. _universal) yields None => the render check SKIPs (the stack
    declared no detail-view convention)."""
    if not section_text or not section_text.strip():
        return None
    m = re.search(r"```ya?ml\s*\n(.*?)```", section_text, re.DOTALL)
    if not m:
        return None
    gm = re.search(r"^\s*detail_view_glob\s*:\s*(.+?)\s*$", m.group(1), re.MULTILINE)
    if not gm:
        return None
    return gm.group(1).strip().strip('"').strip("'") or None


def _expand_braces(p):
    """Expand a single {a,b} brace group (e.g. views/x/{index,show}.blade.php)."""
    m = re.search(r"\{([^{}]*)\}", p)
    if not m:
        return [p]
    pre, post = p[:m.start()], p[m.end():]
    out = []
    for opt in m.group(1).split(","):
        out.extend(_expand_braces(pre + opt.strip() + post))
    return out


def _collect_target_files(frontmatter, body_text):
    """Union of target-file paths from BOTH the frontmatter `target_files:` list AND
    the `## Target files` body block. TF units carry paths ONLY in the body block
    (with ` (edit)`/` (new)` annotations), so reading frontmatter alone misses them."""
    paths = []
    # (a) frontmatter list: `target_files:` followed by `- path` items, or inline []
    fm_tf = re.search(r"^target_files\s*:\s*(.*)$", frontmatter, re.MULTILINE)
    if fm_tf:
        inline = fm_tf.group(1).strip()
        if inline.startswith("["):
            for item in re.findall(r"[^\[\],\s'\"][^\[\],]*", inline):
                paths.append(item.strip().strip('"').strip("'"))
        # indented `- path` / `- path: x` items after the key
        after = frontmatter[fm_tf.end():]
        for ln in after.splitlines():
            if re.match(r"^[A-Za-z_]", ln):  # next top-level key ends the list
                break
            mm = re.match(r"^\s*-\s*(?:path\s*:\s*)?(.+?)\s*$", ln)
            if mm:
                paths.append(mm.group(1).strip().strip('"').strip("'"))
    # (b) `## Target files` body block (fenced or raw)
    tm = re.search(r"^##\s+Target files\s*\n(.*?)(?:\n##\s|\Z)", body_text, re.DOTALL | re.MULTILINE)
    if tm:
        block = tm.group(1)
        fence = re.search(r"```[^\n]*\n(.*?)```", block, re.DOTALL)
        blk = fence.group(1) if fence else block
        for ln in blk.splitlines():
            ln = ln.strip().lstrip("-").strip()
            if not ln:
                continue
            path_only = re.split(r"\s+\(", ln, maxsplit=1)[0].strip()
            if path_only:
                paths.append(path_only)
    # expand brace groups; drop empties
    expanded = []
    for p in paths:
        if p:
            expanded.extend(_expand_braces(p))
    return expanded


def _has_render_acceptance_test(full_text):
    """True iff the unit has a STRUCTURED acceptance_test entry whose type/kind is
    literally `render`. Only inspects the `acceptance_test:` YAML region (frontmatter
    or a body `acceptance_test:` block) — never a prose `## Tests` bullet."""
    at = re.search(r"^acceptance_test\s*:\s*\n(.*?)(?:^\S|\Z)", full_text, re.DOTALL | re.MULTILINE)
    if not at:
        return False
    return re.search(r"^\s*-?\s*(?:type|kind)\s*:\s*[\"']?render[\"']?\s*$",
                     at.group(1), re.MULTILINE) is not None


detail_glob = _parse_detail_view_glob(test_patterns_section)
if detail_glob:
    targets = _collect_target_files(fm, body_after_fm)
    rx = _glob_to_regex(detail_glob)
    detail_views = [t for t in targets if _glob_match(t, rx)]
    if detail_views and not _has_render_acceptance_test(body):
        issues.append({
            "halt_type": "render_test_missing",
            "detail": (
                f"unit {unit_id} ships detail view(s) {detail_views[:3]} but has no "
                f"acceptance_test of type `render` (pack detail_view_glob={detail_glob}). "
                f"A route-200 smoke test misses empty-model / null-field render crashes."
            ),
            "unit_id": unit_id,
            "detail_views": detail_views[:5],
            "detail_view_glob": detail_glob,
            "expected": "one acceptance_test entry with `type: render` (or `kind: render`), per pack `## Test patterns` -> detail_view_render template",
        })

# ─── Build state file ───────────────────────────────────────────────────────
status = "PASS" if not issues else "FAIL"
state = {
    "ts": ts,
    "checked_file": rel_path,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "next_action": (
        "Unit spec passes integrity checks."
        if status == "PASS"
        else f"{len(issues)} unit-spec issue(s) detected. Detection-only at hook layer; re-emit unit via /mega-sdd:generate-units --regenerate or amend manually."
    ),
}

try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"ERROR: state write: {e}", file=sys.stderr)
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?

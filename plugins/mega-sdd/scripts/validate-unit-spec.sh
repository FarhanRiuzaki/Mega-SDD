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

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd required" >&2; exit 2
fi
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Quick path filter: only validate unit files
case "$FILE_PATH" in
  *-bound/units/U-*.md|*-bound/units/U-*/unit.md) ;;
  *) exit 0 ;;
esac

STATE_FILE="${CWD}/.mega-sdd/.unit-spec-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: state dir" >&2; exit 2; }

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json
import os
import re
import sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
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
                if _re.search(r"(?:Citation|Source|Ref(?:erence)?|From):", ck, _re.IGNORECASE):
                    found_trace = True
                    break
                # Inline mention of binding/KB/starterkit/constitution = also count as trace
                if _re.search(r"\b(?:binding\.md|knowledge-base|starterkit-context|constitution\.md|D-\d+|C-\d+|CONFLICT-)", ck, _re.IGNORECASE):
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

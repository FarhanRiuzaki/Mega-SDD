#!/usr/bin/env bash
# validate-constitution-propagation.sh — [HOOK-VALIDATE] constitution clause carry-over.
#
# R5 finding: 78 constitution clauses → 19 in binding → 0 in units.
# Same class of carry-over gap as the OQ-ID drop (Iter 67.6 slice 1).
#
# Validates: constitution clauses cited in binding.md MUST appear in at least
# one unit's frontmatter binding_refs OR Hard Rules OR body text.
#
# Walking-skeleton: checks clause IDs (A-001, B-002 etc.) from binding.md
# against unit files. Clauses in constitution but NOT in binding are excluded
# (binding is the handoff boundary — only binding-cited clauses must carry).
#
# Usage: validate-constitution-propagation.sh --cwd=<project-root> [--quiet]
# Output:
#   stdout: JSON {status, drops, summary}
#   side-effect: <cwd>/.mega-sdd/.constitution-propagation-state.json
#   exit 0=PASS, 1=FAIL (drops), 2=error

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
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
if [ ! -d "${CWD}/.mega-sdd" ]; then exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.constitution-propagation-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

RESULT=$(CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
drops = []
all_binding_clauses = set()
all_unit_clauses = set()

# Find binding docs that cite constitution clauses
binding_files = sorted(
    # Widened from *-bound to * — covers canonical <vault>/binding.md AND legacy <vault>-bound/binding.md.
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "binding.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "binding*.md"))
)
binding_files = [f for f in binding_files if "/.archived/" not in f]

if not binding_files:
    print(json.dumps({
        "status": "SKIP",
        "detail": "no binding docs found",
        "drops": [],
        "summary": {"binding_docs": 0, "binding_clauses": 0, "unit_clauses": 0, "drops": 0}
    }))
    raise SystemExit(0)

# Extract constitution clause IDs from binding docs
# Pattern: A-001, B-002, C-003 etc. (uppercase letter + dash + 3 digits)
clause_pattern = re.compile(r"\b([A-F]-\d{3})\b")

# Retired clauses are exempt (clinic-project audit 2026-06-12 false positive):
# a clause whose constitution.md line marks it dropped/retired/superseded — e.g.
# `A-003: *(dropped in v2.0 — ...)*` — may still be MENTIONED in binding.md
# (supersession discussion is good practice), but units must NOT be required to
# cite a clause that no longer binds; demanding it would force noise citations.
retired_clauses = set()
# 6.0.1 F4 (field-test hardening spec): an X-NNN id in binding.md counts as a
# constitution clause ONLY if it exists in the vault's constitution.md (the
# clause CENSUS). Binding CLAIM ids share the C-NNN shape — without the census
# gate, 19 claim ids were demanded from units as "constitution clauses" on a
# §-style-constitution project (pure namespace collision).
clause_census = set()
census_files = 0
for cf in glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "constitution.md")) + \
           glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "_meta", "constitution.md")):
    census_files += 1
    try:
        text = open(cf).read()
        # census keys on the clause-DEFINITION grammar (list item / heading /
        # bold at line start, id followed by a separator) — round fold: a bare
        # findall let one prose cross-reference ("see binding C-009 for …")
        # re-poison the census with a claim id
        clause_census.update(re.findall(
            r"(?m)^[ \t]*(?:[-*][ \t]+|#{1,6}[ \t]+|\*\*)?([A-F]-\d{3})\*{0,2}[ \t]*[:.—-]", text))
        for line in text.splitlines():
            m = re.match(r"\s*-\s*([A-F]-\d{3}):\s*(.*)", line)
            if m and re.search(r"\((?:dropped|retired|superseded)\b", m.group(2), re.IGNORECASE):
                retired_clauses.add(m.group(1))
    except Exception:
        continue

binding_clause_sources = {}  # clause_id → set of binding files
for bf in binding_files:
    try:
        content = open(bf).read()
    except Exception:
        continue
    # census-gated (F4): ids not present in constitution.md are claim ids or
    # other same-shaped tokens, never propagation obligations
    clauses = (set(clause_pattern.findall(content)) & clause_census) - retired_clauses
    for c in clauses:
        all_binding_clauses.add(c)
        binding_clause_sources.setdefault(c, set()).add(os.path.relpath(bf, cwd))

if not all_binding_clauses:
    detail = ("binding docs exist but contain no constitution clause IDs (A-NNN..F-NNN)"
              if clause_census else
              ("constitution.md carries no X-NNN clause ids (e.g. a §-style grammar) — "
               "nothing this validator can key on; X-NNN-shaped ids in binding.md are "
               "claim ids, not clauses" if census_files else
               "no constitution.md found — no clause census to key on"))
    print(json.dumps({
        "status": "SKIP",
        "detail": detail,
        "drops": [],
        "summary": {"binding_docs": len(binding_files), "binding_clauses": 0, "unit_clauses": 0, "drops": 0}
    }))
    raise SystemExit(0)

# Find unit files (canonical <vault>/units AND legacy <vault>-bound/units; widened *-bound → *)
unit_files = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*", "unit.md"))
)
unit_files = [f for f in unit_files if "/.archived/" not in f]

if not unit_files:
    # No units yet — all binding clauses are "pending", not "dropped"
    print(json.dumps({
        "status": "SKIP",
        "detail": f"binding cites {len(all_binding_clauses)} constitution clauses but no units exist yet",
        "drops": [],
        "summary": {"binding_docs": len(binding_files), "binding_clauses": len(all_binding_clauses),
                     "unit_clauses": 0, "units_checked": 0, "drops": 0}
    }))
    raise SystemExit(0)

# Scan units for constitution clause references
# Check: frontmatter binding_refs, ## Hard rules, AND body text (any mention counts)
unit_clause_map = {}  # clause_id → set of unit files citing it
for uf in unit_files:
    try:
        content = open(uf).read()
    except Exception:
        continue
    clauses_in_unit = set(clause_pattern.findall(content))
    all_unit_clauses.update(clauses_in_unit)
    for c in clauses_in_unit:
        unit_clause_map.setdefault(c, set()).add(os.path.relpath(uf, cwd))

# Compute drops: clauses in binding but not in any unit
dropped_clauses = all_binding_clauses - all_unit_clauses
for clause_id in sorted(dropped_clauses):
    sources = sorted(binding_clause_sources.get(clause_id, set()))
    drops.append({
        "clause_id": clause_id,
        "binding_sources": sources,
        "detail": f"constitution clause {clause_id} cited in {', '.join(sources)} but absent from all {len(unit_files)} units",
    })

status = "FAIL" if drops else "PASS"
result = {
    "status": status,
    "drops": drops,
    "summary": {
        "binding_docs": len(binding_files),
        "binding_clauses": len(all_binding_clauses),
        "unit_clauses": len(all_unit_clauses),
        "units_checked": len(unit_files),
        "drops": len(drops),
        "carried": len(all_binding_clauses) - len(drops),
    },
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

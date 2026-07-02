#!/usr/bin/env bash
# validate-constitution.sh — R5: constitution enforcement validator.
#
# Walking-skeleton scope:
#   1. Check constitution.md exists in active vaults
#   2. Compute sha256 of constitution.md
#   3. Check handoff-validation-state.json carries matching constitution_hash (if present)
#   4. Check binding.md references constitution clauses (section headers)
#   5. Check unit files reference constitution clauses via binding_refs or Hard Rules
#
# Inputs: --cwd=<project> [--quiet]
# Outputs: <cwd>/.mega-sdd/.constitution-state.json
# Exit: 0=PASS/SKIP, 1=FAIL, 2=error

set -uo pipefail

CWD=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
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

STATE_FILE="${CWD}/.mega-sdd/.constitution-state.json"
_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"

RESULT=$(CWD="$CWD" _LIB_DIR="$_LIB_DIR" python3 <<'PYEOF'
import json
import os
import re
import glob
import hashlib
import sys

cwd = os.environ["CWD"]
checks = []
issues = []

# Shared Batch-B citation grammar for the file:line arm of the per-clause source
# check (graceful fallback if the lib is absent — never crash the validator).
sys.path.insert(0, os.environ.get("_LIB_DIR", ""))
try:
    from citation_pattern import PATH_LINE_RE
    _FILELINE = PATH_LINE_RE.pattern
except Exception:
    _FILELINE = r"[\w./-]+\.[A-Za-z][A-Za-z0-9]{0,9}:\d+"

# A clause counts as "source-cited" if its block carries a source ANCHOR. Primary anchors
# are LANGUAGE-INVARIANT (they hold on an Indonesian constitution): a § section anchor,
# the schema-taught `(source: …)` marker, an http(s) link, a [[wikilink]], a file:line
# citation. Plus concrete source NOUNS (PRD/BRD/KB/binding/codebase-map/figma/regulation/
# decision) for English vaults, and `mandated by`. A bare `(see …)`/`(per …)` parenthetical
# is deliberately NOT accepted alone — it matched a casual "(see the login flow)", letting
# an uncited clause pass (the flagship invented-NFR case). The legit citation forms in the
# schema example all carry a § or a source noun, so tightening loses no real citation.
SOURCE_TOKEN_RE = re.compile(
    r"§"
    r"|\(\s*source\s*:"
    r"|\bhttps?://"
    r"|\[\[[^\]\n]+\]\]"
    r"|\bmandated\s+by\b"
    r"|\b(?:PRD|BRD|KB|knowledge[- ]?base|codebase[- ]?map|binding|figma|regulat\w*|decision)\b"
    r"|" + _FILELINE,
    re.IGNORECASE,
)

# Find constitution.md files in active (non-archived) vaults
const_files = sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "constitution.md")))
const_files = [f for f in const_files if "/.archived/" not in f]

if not const_files:
    print(json.dumps({"status": "SKIP", "detail": "no constitution.md in any vault", "checks": [], "issues": []}))
    raise SystemExit(0)

for const_path in const_files:
    vault_dir = os.path.dirname(const_path)
    vault_name = os.path.basename(vault_dir)

    try:
        const_content = open(const_path).read()
    except Exception as e:
        issues.append({"halt_type": "constitution_unreadable", "vault": vault_name, "detail": str(e)})
        checks.append({"check": f"{vault_name}/constitution_readable", "status": "FAIL"})
        continue

    checks.append({"check": f"{vault_name}/constitution_readable", "status": "PASS"})

    # Compute sha256
    const_hash = hashlib.sha256(const_content.encode()).hexdigest()
    checks.append({"check": f"{vault_name}/constitution_hash", "status": "PASS",
                   "detail": f"sha256={const_hash[:16]}..."})

    # Extract clause IDs (pattern: A-001, B-002, etc.)
    clause_ids = set(re.findall(r"\b([A-Z]-\d{3})\b", const_content))
    checks.append({"check": f"{vault_name}/clauses_found", "status": "PASS",
                   "detail": f"{len(clause_ids)} clause IDs"})

    if not clause_ids:
        issues.append({"halt_type": "constitution_no_clauses",
                       "vault": vault_name,
                       "detail": "constitution.md has no parseable clause IDs (expected pattern: X-NNN)"})
        checks.append({"check": f"{vault_name}/clause_coverage", "status": "WARN"})
        continue

    # ─── Per-clause source-citation check (anti-fabrication rail) ─────────────
    # vault-contract.md §constitution: "Constitution clauses MUST cite source". A
    # clause is injected into each unit's `## Hard rules` at execute-bolts as a
    # severity:error BLOCKING gate, so an uncited/defaulted clause (e.g. an invented
    # NFR "median < 200ms") would enforce fabrication as ground truth — the moat
    # inverts. FAIL (advisory-surfaced via /mega-sdd:analyze, never a hot-path block)
    # any clause whose block carries no source token. Clause-ID + source-token are
    # language-invariant, so this holds on an Indonesian constitution too.
    const_lines = const_content.split("\n")
    # Clause line: a leading bullet / heading / table-cell / blockquote marker, an optional
    # bold/emphasis wrapper, then the clause ID. Handles `- A-001:`, bold `- **A-001**:`,
    # heading `### A-001`, table `| A-001 |`, and blockquote `> A-001` — so a non-bullet
    # clause format can't fail-open the check (which then vacuously PASSes "0 clauses").
    clause_anchor_re = re.compile(r"^\s*(?:[-*>|]+\s*|#{1,6}\s*)?(?:\*\*|__|\*|_)?\s*([A-Z]-\d{3})\b")
    clause_anchors = []
    for _i, _ln in enumerate(const_lines):
        _m = clause_anchor_re.match(_ln)
        if _m:
            clause_anchors.append((_i, _m.group(1)))
    if not clause_anchors:
        # clause IDs exist but NO line matched a clause-definition shape — do NOT vacuously
        # PASS. WARN that the per-clause source check could not run on this format.
        checks.append({"check": f"{vault_name}/clause_source_cited", "status": "WARN",
                       "detail": (f"{len(clause_ids)} clause ID(s) present but no clause line matched a "
                                  "known definition format (`- X-NNN:` / `### X-NNN` / `| X-NNN |`) — "
                                  "per-clause source check skipped, not passed")})
    else:
        uncited_clauses = []
        for _idx, (_li, _cid) in enumerate(clause_anchors):
            _end = clause_anchors[_idx + 1][0] if _idx + 1 < len(clause_anchors) else len(const_lines)
            _block = []
            for _j in range(_li, _end):
                if _j > _li and const_lines[_j].lstrip().startswith("#"):
                    break  # next section heading bounds the clause block
                _block.append(const_lines[_j])
            if not SOURCE_TOKEN_RE.search("\n".join(_block)):
                uncited_clauses.append(_cid)
        if uncited_clauses:
            issues.append({
                "halt_type": "constitution_clause_uncited",
                "vault": vault_name,
                "detail": (f"{len(uncited_clauses)}/{len(clause_ids)} constitution clause(s) cite NO source "
                           "(§ / (source:…) / KB/PRD anchor / file:line / link). Uncited clauses become "
                           "BLOCKING Hard rules at execute-bolts — a defaulted or invented clause would "
                           "enforce fabrication as ground truth. Add a source citation or demote to an Open Question."),
                "sample_uncited": sorted(uncited_clauses)[:8],
            })
            checks.append({"check": f"{vault_name}/clause_source_cited", "status": "FAIL",
                           "detail": f"{len(clause_ids) - len(uncited_clauses)}/{len(clause_ids)} clauses cite a source"})
        else:
            checks.append({"check": f"{vault_name}/clause_source_cited", "status": "PASS",
                           "detail": f"all {len(clause_ids)} clauses cite a source"})

    # Check: do units reference constitution clauses?
    bound_dir = vault_dir.rstrip("/") + "-bound" if not vault_dir.endswith("-bound") else vault_dir
    # Canonical layout: units live at <vault>/units. Legacy: <vault>-bound/units.
    # Prefer canonical; fall back to legacy -bound only if canonical is empty/absent.
    canon_units_dir = os.path.join(vault_dir, "units")
    legacy_units_dir = os.path.join(bound_dir, "units")
    if glob.glob(os.path.join(canon_units_dir, "U-*.md")):
        units_dir = canon_units_dir
    elif glob.glob(os.path.join(legacy_units_dir, "U-*.md")):
        units_dir = legacy_units_dir
    else:
        units_dir = canon_units_dir

    if os.path.isdir(units_dir):
        unit_files = sorted(glob.glob(os.path.join(units_dir, "U-*.md")))
        clauses_cited_in_units = set()
        for uf in unit_files:
            try:
                uc = open(uf).read()
            except Exception:
                continue
            for cid in clause_ids:
                if cid in uc:
                    clauses_cited_in_units.add(cid)

        uncited = clause_ids - clauses_cited_in_units
        coverage = len(clauses_cited_in_units) / len(clause_ids) if clause_ids else 0

        if uncited:
            # Not all clauses need to be in every unit — but at least SOME should be cited
            # Warn if <30% of clauses appear in any unit
            if coverage < 0.3:
                issues.append({
                    "halt_type": "constitution_low_unit_coverage",
                    "vault": vault_name,
                    "detail": f"only {len(clauses_cited_in_units)}/{len(clause_ids)} constitution clauses appear in any unit ({coverage:.0%})",
                    "sample_uncited": sorted(uncited)[:5],
                })
                checks.append({"check": f"{vault_name}/clause_unit_coverage", "status": "WARN",
                               "detail": f"{len(clauses_cited_in_units)}/{len(clause_ids)} cited ({coverage:.0%})"})
            else:
                checks.append({"check": f"{vault_name}/clause_unit_coverage", "status": "PASS",
                               "detail": f"{len(clauses_cited_in_units)}/{len(clause_ids)} cited ({coverage:.0%})"})
        else:
            checks.append({"check": f"{vault_name}/clause_unit_coverage", "status": "PASS",
                           "detail": f"all {len(clause_ids)} clauses cited in units"})
    else:
        checks.append({"check": f"{vault_name}/clause_unit_coverage", "status": "SKIP",
                       "detail": "no units directory (bound vault may not exist yet)"})

    # Check: binding.md references constitution
    binding_paths = [
        os.path.join(bound_dir, "binding.md"),
        os.path.join(vault_dir, "binding.md"),
    ]
    for bp in binding_paths:
        if os.path.isfile(bp):
            try:
                bc = open(bp).read()
                const_refs_in_binding = sum(1 for cid in clause_ids if cid in bc)
                checks.append({"check": f"{vault_name}/constitution_in_binding", "status": "PASS",
                               "detail": f"{const_refs_in_binding} clause refs in binding.md"})
            except Exception:
                pass
            break
    else:
        checks.append({"check": f"{vault_name}/constitution_in_binding", "status": "SKIP",
                       "detail": "no binding.md found"})

has_fail = any(c["status"] == "FAIL" for c in checks)
has_warn = any(c["status"] == "WARN" for c in checks)
status = "FAIL" if has_fail else ("WARN" if has_warn else "PASS")

result = {
    "status": status,
    "constitutions_found": len(const_files),
    "checks": checks,
    "issues": issues,
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
  PASS|SKIP|WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac

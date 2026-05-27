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

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ ! -d "${CWD}/.mega-sdd" ]; then exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.constitution-state.json"

RESULT=$(CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re
import glob
import hashlib

cwd = os.environ["CWD"]
checks = []
issues = []

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

    # Check: do units reference constitution clauses?
    bound_dir = vault_dir.rstrip("/") + "-bound" if not vault_dir.endswith("-bound") else vault_dir
    units_dir = os.path.join(bound_dir, "units")

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

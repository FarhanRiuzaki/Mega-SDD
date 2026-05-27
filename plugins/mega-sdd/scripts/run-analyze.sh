#!/usr/bin/env bash
# run-analyze.sh — R1: unified cross-artifact consistency analyzer.
#
# Invokes each existing validate-*.sh script against the CWD project,
# reads their state files, runs vault internal consistency checks,
# aggregates into .analyze-state.json + CONSISTENCY-REPORT.md.
#
# Inputs: --cwd=<project-root> [--quiet]
# Outputs:
#   <cwd>/.mega-sdd/.analyze-state.json (machine-readable aggregate)
#   <cwd>/.mega-sdd/CONSISTENCY-REPORT.md (human-readable report)
# Exit: 0 = all PASS/WARN, 1 = any FAIL, 2 = error.

set -uo pipefail

CWD=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi

if [ ! -d "${CWD}/.mega-sdd" ]; then
  echo "ERROR: no .mega-sdd/ directory in ${CWD}" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown-ts")

# --- Phase 1: Run existing validators ---
# Each validator writes its own state file under <cwd>/.mega-sdd/
# We invoke each with --cwd and --quiet, capturing exit codes.
# Validators excluded:
#   validate-scope-flag.sh    — needs user-message stdin (not batch-able)
#   validate-pandoc-render.sh — needs specific bash command context
#   validate-starterkit-metrics.sh — needs transcript context
#   validate-handoff-yaml.sh  — needs chat output text (Stop-hook context)

run_validator() {
  local script="$1"
  local script_path="${SCRIPT_DIR}/${script}"
  shift
  if [ ! -x "$script_path" ]; then
    echo "SKIP"
    return 0
  fi
  bash "$script_path" "$@" >/dev/null 2>&1
  echo $?
}

# 1a. Project-wide validators (no --file-path needed)
V1_RC=$(run_validator "validate-handoff-binding-units.sh" --cwd="$CWD" --quiet)
V6_RC=$(run_validator "validate-vault-binding-coverage.sh" --cwd="$CWD" --quiet)

# 1b. Per-unit-file validator
V2_WORST=0
for uf in $(find "${CWD}/.mega-sdd/vaults" -path "*-bound/units/U-*.md" -not -path "*/.archived/*" 2>/dev/null); do
  rc=$(run_validator "validate-unit-spec.sh" --cwd="$CWD" --file-path="$uf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V2_WORST" ] && V2_WORST=$rc
done
V2_RC=$V2_WORST
if ! find "${CWD}/.mega-sdd/vaults" -path "*-bound/units/U-*.md" -not -path "*/.archived/*" 2>/dev/null | grep -q .; then
  V2_RC="SKIP"
fi

# 1c. Per-bolt-report validator
V3_WORST=0
V3_HAS_FILES=0
for bf in $(find "${CWD}/.mega-sdd/vaults" -path "*/bolts/U-*/bolt-report.md" -not -path "*/.archived/*" 2>/dev/null); do
  V3_HAS_FILES=1
  rc=$(run_validator "validate-bolt-artifacts.sh" --cwd="$CWD" --file-path="$bf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V3_WORST" ] && V3_WORST=$rc
done
V3_RC=$( [ "$V3_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V3_WORST" )

# 1d. Per-vault-doc OQ validator
V4_WORST=0
for vf in $(find "${CWD}/.mega-sdd/vaults" -name "0[0-6]-*.md" -not -path "*-bound/*" -not -path "*/.archived/*" 2>/dev/null); do
  rc=$(run_validator "validate-vault-oqs.sh" --cwd="$CWD" --file-path="$vf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V4_WORST" ] && V4_WORST=$rc
done
V4_RC=$V4_WORST

# 1e. Per-FSD-file slot validator
V5_WORST=0
V5_HAS_FILES=0
for ff in $(find "${CWD}/.mega-sdd/vaults" -name "FSD.md" -not -path "*/.archived/*" 2>/dev/null); do
  V5_HAS_FILES=1
  rc=$(run_validator "validate-fsd-slots.sh" --cwd="$CWD" --file-path="$ff" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V5_WORST" ] && V5_WORST=$rc
done
V5_RC=$( [ "$V5_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V5_WORST" )

# 1f. Per-KB-domain-file validator (R2)
V7_WORST=0
V7_HAS_FILES=0
for kf in $(find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; \
            find "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; \
            find "${CWD}/.mega-sdd/knowledge-base/40-business-rules" -name "*.md" -not -path "*/.archived/*" 2>/dev/null); do
  V7_HAS_FILES=1
  rc=$(run_validator "validate-kb-output.sh" --cwd="$CWD" --file-path="$kf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V7_WORST" ] && V7_WORST=$rc
done
V7_RC=$( [ "$V7_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V7_WORST" )

# 1g. Conflict classification validator (R3)
V8_RC=$(run_validator "validate-conflict-classification.sh" --cwd="$CWD" --quiet)

# 1h. Domain-rule gap detector (R4 — runs only when KB exists)
V9_RC=$(run_validator "audit-domain-rules.sh" --cwd="$CWD" --quiet)

# 1i. Constitution enforcement validator (R5)
V10_RC=$(run_validator "validate-constitution.sh" --cwd="$CWD" --quiet)

# 1j. Codebase-map schema validation (R6)
V11_RC=$(run_validator "validate-codebase-map.sh" --cwd="$CWD" --quiet)

# --- Phase 2: Vault internal consistency checks (NEW — R7 folded into R1) ---
VAULT_CONSISTENCY=$(CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
results = []

for vj_path in sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "vault.json"))):
    if "/.archived/" in vj_path:
        continue
    vault_dir = os.path.dirname(vj_path)
    vault_name = os.path.basename(vault_dir)

    try:
        with open(vj_path) as f:
            vj = json.load(f)
    except Exception as e:
        results.append({"vault": vault_name, "checks": [
            {"check": "vault_json_parse", "status": "FAIL", "detail": str(e)}
        ]})
        continue

    checks = []

    # Check 1: vault.json entities count vs 03-data-model.md entity blocks
    dm_path = os.path.join(vault_dir, "03-data-model.md")
    if os.path.isfile(dm_path):
        dm_content = open(dm_path).read()
        entity_patterns = len(re.findall(
            r"^(?:Table|table)\s+\w|^##\s+(?:Entity|entity):?\s+\w",
            dm_content, re.MULTILINE
        ))
        vj_entities = len(vj.get("entities", []))
        if entity_patterns > 0 and abs(vj_entities - entity_patterns) > 2:
            checks.append({"check": "entities_count_sync", "status": "WARN",
                          "detail": f"vault.json={vj_entities} entities; 03-data-model.md~={entity_patterns} (delta>{2})"})
        else:
            checks.append({"check": "entities_count_sync", "status": "PASS",
                          "detail": f"vault.json={vj_entities}, md~={entity_patterns}"})
    else:
        checks.append({"check": "entities_count_sync", "status": "SKIP",
                       "detail": "03-data-model.md not found"})

    # Check 2: OQ count in vault.json vs 00-index.md OQ tag count
    idx_path = os.path.join(vault_dir, "00-index.md")
    if os.path.isfile(idx_path):
        idx_content = open(idx_path).read()
        oq_tags = set(re.findall(r"\bOQ-[A-Z]+-(?:P\d+-)?(?:\d+)\b", idx_content))
        vj_oqs = len(vj.get("open_questions", []))
        if len(oq_tags) > 0 and abs(vj_oqs - len(oq_tags)) > 3:
            checks.append({"check": "oq_count_sync", "status": "WARN",
                          "detail": f"vault.json={vj_oqs} OQs; 00-index.md={len(oq_tags)} unique tags (delta>{3})"})
        else:
            checks.append({"check": "oq_count_sync", "status": "PASS",
                          "detail": f"vault.json={vj_oqs}, idx_tags={len(oq_tags)}"})

    # Check 3: 7+1 required vault files present
    expected_files = ["00-index.md", "01-overview.md", "02-architecture.md",
                      "03-data-model.md", "04-flows.md", "05-decisions.md",
                      "06-constraints.md", "vault.json"]
    missing = [ef for ef in expected_files if not os.path.isfile(os.path.join(vault_dir, ef))]
    if missing:
        checks.append({"check": "vault_files_complete", "status": "FAIL",
                       "detail": f"missing: {', '.join(missing)}"})
    else:
        checks.append({"check": "vault_files_complete", "status": "PASS",
                       "detail": f"all {len(expected_files)} files present"})

    # Check 4: source_documents paths exist (WARN only — paths may be relative to project root)
    for sd in vj.get("source_documents", []):
        sd_path = sd.get("path", "")
        if sd_path:
            abs1 = os.path.join(cwd, sd_path)
            if not os.path.exists(abs1) and not os.path.exists(sd_path):
                checks.append({"check": "source_doc_exists", "status": "WARN",
                               "detail": f"source_documents path not found: {sd_path}"})

    # Check 5: flows count sync
    flows_path = os.path.join(vault_dir, "04-flows.md")
    if os.path.isfile(flows_path):
        flows_content = open(flows_path).read()
        flow_ids = set(re.findall(r"\bF-[A-Z]-\d{3}\b", flows_content))
        vj_flows = len(vj.get("flows", []))
        if len(flow_ids) > 0 and abs(vj_flows - len(flow_ids)) > 2:
            checks.append({"check": "flows_count_sync", "status": "WARN",
                          "detail": f"vault.json={vj_flows} flows; 04-flows.md={len(flow_ids)} flow IDs"})
        else:
            checks.append({"check": "flows_count_sync", "status": "PASS",
                          "detail": f"vault.json={vj_flows}, md_ids={len(flow_ids)}"})

    results.append({"vault": vault_name, "checks": checks})

print(json.dumps(results))
PYEOF
)

# --- Phase 3: Aggregate and write report ---
ANALYZE_OUTPUT=$(CWD="$CWD" TS="$TS" VAULT_CONSISTENCY="$VAULT_CONSISTENCY" \
  V1_RC="$V1_RC" V2_RC="$V2_RC" V3_RC="$V3_RC" V4_RC="$V4_RC" V5_RC="$V5_RC" V6_RC="$V6_RC" V7_RC="$V7_RC" \
  V8_RC="$V8_RC" V9_RC="$V9_RC" V10_RC="$V10_RC" V11_RC="$V11_RC" \
  python3 <<'PYEOF'
import json
import os

cwd = os.environ["CWD"]
ts = os.environ["TS"]

try:
    vault_consistency = json.loads(os.environ.get("VAULT_CONSISTENCY", "[]"))
except Exception:
    vault_consistency = []

# Map validator results
validator_results = {
    "binding_units_handoff": {"rc": os.environ["V1_RC"], "state_file": ".validation-blockers.json"},
    "unit_spec": {"rc": os.environ["V2_RC"], "state_file": ".unit-spec-state.json"},
    "bolt_artifacts": {"rc": os.environ["V3_RC"], "state_file": ".bolt-artifacts-state.json"},
    "vault_oqs": {"rc": os.environ["V4_RC"], "state_file": ".vault-oqs-state.json"},
    "fsd_slots": {"rc": os.environ["V5_RC"], "state_file": ".fsd-slots-state.json"},
    "vault_binding_coverage": {"rc": os.environ["V6_RC"], "state_file": ".vault-binding-coverage-state.json"},
    "kb_output": {"rc": os.environ["V7_RC"], "state_file": ".kb-output-state.json"},
    "conflict_classification": {"rc": os.environ["V8_RC"], "state_file": ".conflict-classification-state.json"},
    "domain_rules": {"rc": os.environ["V9_RC"], "state_file": ".domain-rules-state.json"},
    "constitution": {"rc": os.environ["V10_RC"], "state_file": ".constitution-state.json"},
    "codebase_map": {"rc": os.environ["V11_RC"], "state_file": ".codebase-map-state.json"},
}

# Read state files for detail
boundaries = {}
for name, vr in validator_results.items():
    rc = vr["rc"]
    sf = vr["state_file"]
    sf_path = os.path.join(cwd, ".mega-sdd", sf)

    if rc == "SKIP":
        boundaries[name] = {"status": "SKIP", "state_file": sf, "detail": "no applicable files found"}
        continue

    status = "PASS" if int(rc) == 0 else "FAIL"

    detail = ""
    if os.path.isfile(sf_path):
        try:
            with open(sf_path) as f:
                data = json.load(f)
            sf_status = data.get("status", status)
            status = sf_status
            summary = data.get("summary", {})
            if isinstance(summary, dict):
                detail = "; ".join(f"{k}={v}" for k, v in list(summary.items())[:4])
            elif isinstance(summary, str):
                detail = summary[:120]
            else:
                detail = str(data.get("halt_type", ""))[:120]
        except Exception as e:
            detail = f"state file parse error: {e}"
    else:
        detail = f"validator ran (exit={rc}) but no state file written"

    boundaries[name] = {"status": status, "state_file": sf, "detail": detail}

# Compute overall
all_statuses = [b["status"] for b in boundaries.values() if b["status"] != "SKIP"]
vault_statuses = []
for vc in vault_consistency:
    for chk in vc.get("checks", []):
        if chk["status"] != "SKIP":
            vault_statuses.append(chk["status"])

has_fail = "FAIL" in all_statuses or "FAIL" in vault_statuses
has_warn = "WARN" in vault_statuses
overall = "FAIL" if has_fail else ("WARN" if has_warn else "PASS")

# Write .analyze-state.json
state = {
    "status": overall,
    "analyzed_at": ts,
    "boundaries": boundaries,
    "vault_consistency": vault_consistency,
    "validators_run": len([s for s in all_statuses]),
    "validators_total": len(validator_results),
    "validators_pass": all_statuses.count("PASS"),
    "validators_fail": all_statuses.count("FAIL"),
    "validators_skip": len([b for b in boundaries.values() if b["status"] == "SKIP"]),
}

state_path = os.path.join(cwd, ".mega-sdd", ".analyze-state.json")
with open(state_path, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

# Write CONSISTENCY-REPORT.md
lines = []
lines.append(f"# Consistency Report — {ts}")
lines.append("")
lines.append(f"**Overall: {overall}**")
lines.append(f"**Validators: {state['validators_pass']} PASS / {state['validators_fail']} FAIL / {state['validators_skip']} SKIP of {state['validators_total']}**")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Boundary Checks (existing validators)")
lines.append("")
lines.append("| Boundary | Status | State File | Detail |")
lines.append("|---|---|---|---|")
for name, b in sorted(boundaries.items()):
    lines.append(f"| {name} | **{b['status']}** | `{b['state_file']}` | {b['detail']} |")
lines.append("")
lines.append("## Vault Internal Consistency")
lines.append("")
for vc in vault_consistency:
    vault_name = vc.get("vault", "unknown")
    lines.append(f"### Vault: `{vault_name}`")
    lines.append("")
    checks = vc.get("checks", [])
    if checks:
        lines.append("| Check | Status | Detail |")
        lines.append("|---|---|---|")
        for chk in checks:
            lines.append(f"| {chk['check']} | **{chk['status']}** | {chk['detail']} |")
    lines.append("")

lines.append("---")
lines.append("")
lines.append(f"*Generated by `/mega-sdd:analyze` at {ts}*")

report_path = os.path.join(cwd, ".mega-sdd", "CONSISTENCY-REPORT.md")
with open(report_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(json.dumps({"state_path": state_path, "report_path": report_path, "overall": overall}))
PYEOF
)

if [ "$QUIET" -eq 0 ]; then
  echo "$ANALYZE_OUTPUT"
fi

OVERALL=$(echo "$ANALYZE_OUTPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('overall','ERROR'))" 2>/dev/null)
case "$OVERALL" in
  PASS|WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac

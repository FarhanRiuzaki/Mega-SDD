#!/usr/bin/env bash
# run-analyze.sh — R1: unified cross-artifact consistency analyzer.
#
# TWO modes:
#   FULL (default / manual): re-run all validators + vault checks → aggregate → report.
#   AGGREGATE-ONLY (--aggregate-only): read existing state files written by PostToolUse
#     validators during the chain → aggregate → report. Cheap; no re-run. Used by
#     Stop hook for auto-chain reporting.
#
# Inputs: --cwd=<project-root> [--quiet] [--aggregate-only]
# Outputs:
#   <cwd>/.mega-sdd/.analyze-state.json (machine-readable aggregate)
#   <cwd>/.mega-sdd/CONSISTENCY-REPORT.md (human-readable report)
# Exit: 0 = all PASS/WARN, 1 = any FAIL, 2 = error.

set -uo pipefail

CWD=""
QUIET=0
AGGREGATE_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --quiet) QUIET=1 ;;
    --aggregate-only) AGGREGATE_ONLY=1 ;;
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


if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi

if [ ! -d "${CWD}/.mega-sdd" ]; then
  echo "ERROR: no .mega-sdd/ directory in ${CWD}" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown-ts")

if [ "$AGGREGATE_ONLY" -eq 1 ]; then
  # ─── AGGREGATE-ONLY MODE ──────────────────────────────────────────────
  # Skip Phase 1 (validator invocation) and Phase 2 (vault internal checks).
  # Read existing state files written by PostToolUse validators during chain.
  # Jump to Phase 3 aggregation. Each V*_RC defaults to the "STATE_FILE" sentinel
  # (aggregator reads the state file status directly instead of an exit code).
  #
  # R3-11: the discovery-gated validators (unit_spec, bolt_artifacts, fsd_slots, the KB
  # validators) are reported SKIP by FULL mode when no in-scope files exist. Reading their
  # state file blindly here would surface a STALE FAIL — left by a prior chain whose source
  # files are now gone/archived — as a live FAIL, contradicting what FULL reports (SKIP) on
  # the SAME tree. So we replicate FULL's existence check and force SKIP when there are no
  # files; the on-disk status is trusted only when files actually exist. This path is
  # REPORT-ONLY (the moat reads .validation-blockers.json directly, never this aggregate),
  # so computing SKIP here cannot weaken any gate. vault_oqs (V4) has NO existence-SKIP in
  # FULL — it defaults to PASS — so it stays STATE_FILE here too; do NOT add a SKIP for it.

  # find-any helper: 0 if at least one path matches, 1 otherwise (missing dir => no match).
  _has() { find "$@" 2>/dev/null | grep -q .; }

  # Validators FULL runs unconditionally (no file-existence SKIP) → always read from disk.
  V1_RC="STATE_FILE"; V4_RC="STATE_FILE"; V6_RC="STATE_FILE"; V3B_RC="STATE_FILE"
  V7S_RC="STATE_FILE"; V8_RC="STATE_FILE"; V9_RC="STATE_FILE"; V10_RC="STATE_FILE"
  V11_RC="STATE_FILE"; V12_RC="STATE_FILE"

  # Discovery-gated validators — mirror FULL's SKIP-when-no-files (globs match FULL exactly).
  _has "${CWD}/.mega-sdd/vaults" -path "*/units/U-*.md" -not -path "*/.archived/*" \
    && V2_RC="STATE_FILE" || V2_RC="SKIP"
  _has "${CWD}/.mega-sdd/vaults" -path "*/bolts/U-*/bolt-report.md" -not -path "*/.archived/*" \
    && V3_RC="STATE_FILE" || V3_RC="SKIP"
  _has "${CWD}/.mega-sdd/vaults" -name "FSD.md" -not -path "*/.archived/*" \
    && V5_RC="STATE_FILE" || V5_RC="SKIP"
  { _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    || _has "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*" \
    || _has "${CWD}/.mega-sdd/knowledge-base/40-business-rules" -name "*.md" -not -path "*/.archived/*"; } \
    && V7_RC="STATE_FILE" || V7_RC="SKIP"
  _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    && V7M_RC="STATE_FILE" || V7M_RC="SKIP"
  { _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    || _has "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*"; } \
    && V7F_RC="STATE_FILE" || V7F_RC="SKIP"
  _has "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" \
    && V7C_RC="STATE_FILE" || V7C_RC="SKIP"

  # Advisory checks not re-run in aggregate-only mode
  REUSE_DUP_OUTPUT=""

  # Vault internal consistency: run inline (cheap, pure reads, no validators)
  VAULT_CONSISTENCY="[]"

  # Skip directly to Phase 3
else
  # ─── FULL MODE (default) ──────────────────────────────────────────────

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
for uf in $(find "${CWD}/.mega-sdd/vaults" -path "*/units/U-*.md" -not -path "*/.archived/*" 2>/dev/null); do
  rc=$(run_validator "validate-unit-spec.sh" --cwd="$CWD" --file-path="$uf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V2_WORST" ] && V2_WORST=$rc
done
V2_RC=$V2_WORST
if ! find "${CWD}/.mega-sdd/vaults" -path "*/units/U-*.md" -not -path "*/.archived/*" 2>/dev/null | grep -q .; then
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

# 1c2. Orphan-bolt-commit scan (repo-wide; catches bolt commits whose
# bolt-report.md was never written — the per-file loop above cannot see a
# file that does not exist). Writes .bolt-orphans-state.json.
V3B_RC=$(run_validator "validate-bolt-artifacts.sh" --cwd="$CWD" --orphan-scan --quiet)

# 1c3. Regenerate the project index (multi-PRD lifecycle — derived manifest of
# every vault; cheap pure-read scan). Never blocks; advisory artifact only.
bash "${SCRIPT_DIR}/build-project-index.sh" --cwd="$CWD" >/dev/null 2>&1 || true

# 1d. Per-vault-doc OQ validator
V4_WORST=0
for vf in $(find "${CWD}/.mega-sdd/vaults" -name "0[0-6]-*.md" -not -path "*/bound/*" -not -path "*/.archived/*" 2>/dev/null); do
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

# 1f2. Per-KB-domain-file marker-accuracy validator (Track 1)
V7M_WORST=0
V7M_HAS_FILES=0
for kf in $(find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null); do
  V7M_HAS_FILES=1
  rc=$(run_validator "validate-kb-markers.sh" --cwd="$CWD" --file-path="$kf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V7M_WORST" ] && V7M_WORST=$rc
done
V7M_RC=$( [ "$V7M_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V7M_WORST" )

# 1f3. Per-KB-domain-file flow format validator (Mermaid consistency)
V7F_WORST=0
V7F_HAS_FILES=0
for kf in $(find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null; \
            find "${CWD}/.mega-sdd/knowledge-base/20-workflows" -name "*.md" -not -path "*/.archived/*" 2>/dev/null); do
  V7F_HAS_FILES=1
  rc=$(run_validator "validate-kb-flows.sh" --cwd="$CWD" --file-path="$kf" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V7F_WORST" ] && V7F_WORST=$rc
done
V7F_RC=$( [ "$V7F_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V7F_WORST" )

# 1f4. Starterkit pattern conformance validator
V7S_RC=$(run_validator "validate-starterkit-conformance.sh" --cwd="$CWD" --quiet)

# 1f5. Per-KB-domain-file citation resolution validator (Track 1 expansion)
V7C_WORST=0
V7C_HAS_FILES=0
# Auto-detect legacy root
LEGACY_ROOT=""
for candidate in "${CWD}" "$(dirname "$CWD")/$(basename "$CWD" | sed 's/-import$//' | sed 's/-rebuild$//')"; do
  if [ -d "$candidate" ] && { [ -f "$candidate/index.php" ] || [ -f "$candidate/composer.json" ] || [ -f "$candidate/package.json" ]; }; then
    LEGACY_ROOT="$candidate"
    break
  fi
done
for kf in $(find "${CWD}/.mega-sdd/knowledge-base/10-domains" -name "*.md" -not -path "*/.archived/*" 2>/dev/null); do
  V7C_HAS_FILES=1
  rc=$(run_validator "validate-kb-citations.sh" --cwd="$CWD" --file-path="$kf" --legacy-root="${LEGACY_ROOT:-$CWD}" --quiet)
  [ "$rc" != "SKIP" ] && [ "$rc" -gt "$V7C_WORST" ] && V7C_WORST=$rc
done
V7C_RC=$( [ "$V7C_HAS_FILES" -eq 0 ] && echo "SKIP" || echo "$V7C_WORST" )

# 1g. Conflict classification validator (R3)
V8_RC=$(run_validator "validate-conflict-classification.sh" --cwd="$CWD" --quiet)

# 1h. Domain-rule gap detector (R4 — runs only when KB exists)
V9_RC=$(run_validator "audit-domain-rules.sh" --cwd="$CWD" --quiet)

# 1i. Constitution enforcement validator (R5)
V10_RC=$(run_validator "validate-constitution.sh" --cwd="$CWD" --quiet)

# 1j. Constitution clause propagation (C — finding-driven enforcement)
V11_RC=$(run_validator "validate-constitution-propagation.sh" --cwd="$CWD" --quiet)

# 1k. Codebase-map schema validation (R6)
V12_RC=$(run_validator "validate-codebase-map.sh" --cwd="$CWD" --quiet)

# 1l. Reuse-duplication advisory heuristic (R8 — ADVISORY; never blocks; NOT in PreToolUse)
REUSE_DUP_OUTPUT=""
if [ -x "${SCRIPT_DIR}/validate-reuse-duplication.sh" ]; then
  REUSE_DUP_OUTPUT=$(bash "${SCRIPT_DIR}/validate-reuse-duplication.sh" "$CWD" 2>&1 || true)
fi

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

fi  # end of FULL vs AGGREGATE_ONLY branch

# --- Phase 3: Aggregate and write report ---
ANALYZE_OUTPUT=$(CWD="$CWD" TS="$TS" VAULT_CONSISTENCY="$VAULT_CONSISTENCY" REUSE_DUP_OUTPUT="$REUSE_DUP_OUTPUT" \
  V1_RC="$V1_RC" V2_RC="$V2_RC" V3_RC="$V3_RC" V3B_RC="$V3B_RC" V4_RC="$V4_RC" V5_RC="$V5_RC" V6_RC="$V6_RC" V7_RC="$V7_RC" \
  V7M_RC="$V7M_RC" V7F_RC="$V7F_RC" V7S_RC="$V7S_RC" V7C_RC="$V7C_RC" V8_RC="$V8_RC" V9_RC="$V9_RC" V10_RC="$V10_RC" V11_RC="$V11_RC" V12_RC="$V12_RC" \
  python3 <<'PYEOF'
import json
import os

cwd = os.environ["CWD"]
ts = os.environ["TS"]

try:
    vault_consistency = json.loads(os.environ.get("VAULT_CONSISTENCY", "[]"))
except Exception:
    vault_consistency = []

# Advisory: reuse-duplication heuristic output (plain text; never flips overall)
reuse_dup_output = os.environ.get("REUSE_DUP_OUTPUT", "").strip()

# Map validator results
validator_results = {
    "binding_units_handoff": {"rc": os.environ["V1_RC"], "state_file": ".validation-blockers.json"},
    "unit_spec": {"rc": os.environ["V2_RC"], "state_file": ".unit-spec-state.json"},
    "bolt_artifacts": {"rc": os.environ["V3_RC"], "state_file": ".bolt-artifacts-state.json"},
    "bolt_orphans": {"rc": os.environ.get("V3B_RC", "STATE_FILE"), "state_file": ".bolt-orphans-state.json"},
    "vault_oqs": {"rc": os.environ["V4_RC"], "state_file": ".vault-oqs-state.json"},
    "fsd_slots": {"rc": os.environ["V5_RC"], "state_file": ".fsd-slots-state.json"},
    "vault_binding_coverage": {"rc": os.environ["V6_RC"], "state_file": ".vault-binding-coverage-state.json"},
    "kb_output": {"rc": os.environ["V7_RC"], "state_file": ".kb-output-state.json"},
    "kb_markers": {"rc": os.environ["V7M_RC"], "state_file": ".kb-markers-state.json"},
    "kb_flows": {"rc": os.environ["V7F_RC"], "state_file": ".kb-flows-state.json"},
    "starterkit_conformance": {"rc": os.environ["V7S_RC"], "state_file": ".starterkit-conformance-state.json"},
    "kb_citations": {"rc": os.environ["V7C_RC"], "state_file": ".kb-citations-state.json"},
    "conflict_classification": {"rc": os.environ["V8_RC"], "state_file": ".conflict-classification-state.json"},
    "domain_rules": {"rc": os.environ["V9_RC"], "state_file": ".domain-rules-state.json"},
    "constitution": {"rc": os.environ["V10_RC"], "state_file": ".constitution-state.json"},
    "constitution_propagation": {"rc": os.environ["V11_RC"], "state_file": ".constitution-propagation-state.json"},
    "codebase_map": {"rc": os.environ["V12_RC"], "state_file": ".codebase-map-state.json"},
    # v4 — KEPT hard-block code-delivery gates (enforced at PreToolUse on execute-bolts);
    # surfaced here read-only from their PostToolUse state files so /analyze is a true
    # pre-flight of what WILL block bolts (a FAIL here flips overall, as it should).
    "flow_coverage": {"rc": "STATE_FILE", "state_file": ".flow-coverage-state.json"},
    "sibling_consistency": {"rc": "STATE_FILE", "state_file": ".sibling-consistency-state.json"},
    "cross_cutting_registration": {"rc": "STATE_FILE", "state_file": ".cross-cutting-state.json"},
    "ui_quality": {"rc": "STATE_FILE", "state_file": ".ui-quality-blockers.json"},
    # v4 Phase 2 (Hybrid) — code-delivery checks DEMOTED from PreToolUse hard-block to
    # advisory. Surfaced here read-only from their PostToolUse-written state files (no
    # re-run); "NOT_RUN" until a real chain writes them. They no longer block execute-bolts.
    "dispatch_prompt (advisory)": {"rc": "STATE_FILE", "state_file": ".dispatch-prompt-state.json"},
    "fanout_parity (advisory)": {"rc": "STATE_FILE", "state_file": ".fanout-parity-state.json"},
    "ui_deferral (advisory)": {"rc": "STATE_FILE", "state_file": ".ui-deferral-state.json"},
    "vault_flow_staging (advisory)": {"rc": "STATE_FILE", "state_file": ".vault-flow-staging-state.json"},
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

    # AGGREGATE-ONLY mode: rc == "STATE_FILE" → read status from state file, not exit code
    if rc == "STATE_FILE":
        if not os.path.isfile(sf_path):
            boundaries[name] = {"status": "NOT_RUN", "state_file": sf, "detail": "no state file (validator not yet run this chain)"}
            continue
        try:
            with open(sf_path) as f:
                data = json.load(f)
            status = data.get("status", "UNKNOWN")
            summary = data.get("summary", {})
            detail = ("; ".join(f"{k}={v}" for k, v in list(summary.items())[:4])
                      if isinstance(summary, dict) else str(summary)[:120] if isinstance(summary, str)
                      else str(data.get("halt_type", ""))[:120])
        except Exception as e:
            status = "ERROR"
            detail = f"state file parse error: {e}"
        boundaries[name] = {"status": status, "state_file": sf, "detail": detail}
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

# Compute overall. Advisory (v4 Phase 2 Hybrid) boundaries are surfaced in the report
# but never flip overall to a blocking FAIL — an advisory FAIL contributes WARN at most.
all_statuses = [b["status"] for name, b in boundaries.items() if b["status"] != "SKIP" and "(advisory)" not in name]
advisory_statuses = [b["status"] for name, b in boundaries.items() if "(advisory)" in name and b["status"] not in ("SKIP", "NOT_RUN")]
vault_statuses = []
for vc in vault_consistency:
    for chk in vc.get("checks", []):
        if chk["status"] != "SKIP":
            vault_statuses.append(chk["status"])

has_fail = "FAIL" in all_statuses or "FAIL" in vault_statuses
has_warn = ("WARN" in vault_statuses) or ("FAIL" in advisory_statuses) or ("WARN" in advisory_statuses)
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

lines.append("## Advisory: Reuse-Duplication Heuristic")
lines.append("")
lines.append("*Non-blocking. Surfaced for review only — does not affect overall status.*")
lines.append("")
if reuse_dup_output:
    for dup_line in reuse_dup_output.splitlines():
        lines.append(f"    {dup_line}")
else:
    lines.append("    [reuse-dup] not run (aggregate-only mode or validator absent)")
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

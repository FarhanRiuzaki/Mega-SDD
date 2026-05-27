# R1: `/mega-sdd:analyze` — Unified Cross-Artifact Consistency Command

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `/mega-sdd:analyze` command that runs all existing validators + new vault internal consistency checks, aggregates results, and produces `CONSISTENCY-REPORT.md` with PASS/FAIL per boundary and per artifact.

**Architecture:** New skill (`analyze/SKILL.md`) + new command (`commands/analyze.md`) + new orchestrator script (`scripts/run-analyze.sh`). The script invokes each existing `validate-*.sh` script against the CWD project, reads their state files, adds new vault-internal checks (vault.json ↔ markdown sync), and writes a single report. NO auto-trigger via prose in orchestrate-flow — manual command only (auto-trigger is a separate [HOOK] slice deferred until manual proves).

**Tech Stack:** Bash orchestrator script + Python for JSON aggregation + existing validator scripts (unchanged).

**Enforcement Surface:** [VERIFY-STEP] — user runs `/mega-sdd:analyze` explicitly. State file: `<cwd>/.mega-sdd/.analyze-state.json`.

---

### Task 1: Create the `run-analyze.sh` orchestrator script (walking-skeleton)

**Files:**
- Create: `plugins/mega-sdd/scripts/run-analyze.sh`

Walking-skeleton scope: invoke the 9 existing validator scripts (skipping `validate-scope-flag.sh` which needs user-message context), collect their state files, aggregate into a single JSON summary.

- [ ] **Step 1: Create the orchestrator script**

```bash
#!/usr/bin/env bash
# run-analyze.sh — R1 walking-skeleton: unified cross-artifact consistency analyzer.
#
# Invokes each existing validate-*.sh script against the CWD project,
# reads their state files, aggregates into .analyze-state.json + CONSISTENCY-REPORT.md.
#
# Inputs: --cwd=<project-root> [--quiet]
# Outputs:
#   <cwd>/.mega-sdd/.analyze-state.json (machine-readable aggregate)
#   <cwd>/.mega-sdd/CONSISTENCY-REPORT.md (human-readable report)
# Exit: 0 = all PASS, 1 = any FAIL, 2 = error.

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

declare -A VALIDATOR_EXIT
declare -A VALIDATOR_STATE_FILE

# Validator registry: script_name → state_file_name
# validate-scope-flag.sh excluded (needs user-message stdin, not applicable to batch)
# validate-pandoc-render.sh excluded (needs specific bash command context)
# validate-starterkit-metrics.sh excluded (needs transcript context)
VALIDATORS=(
  "validate-handoff-binding-units.sh:.validation-blockers.json"
  "validate-unit-spec.sh:.unit-spec-state.json"
  "validate-bolt-artifacts.sh:.bolt-artifacts-state.json"
  "validate-vault-oqs.sh:.vault-oqs-state.json"
  "validate-fsd-slots.sh:.fsd-slots-state.json"
  "validate-vault-binding-coverage.sh:.vault-binding-coverage-state.json"
)

for entry in "${VALIDATORS[@]}"; do
  IFS=':' read -r script state_file <<< "$entry"
  script_path="${SCRIPT_DIR}/${script}"
  if [ ! -x "$script_path" ]; then
    VALIDATOR_EXIT["$script"]="SKIP"
    continue
  fi

  # Some validators need --file-path; binding-units and vault-binding-coverage
  # are project-wide (no --file-path needed). Others need a specific file.
  # For analyze: run project-wide validators directly; file-specific validators
  # are iterated over relevant files.
  case "$script" in
    validate-handoff-binding-units.sh|validate-vault-binding-coverage.sh)
      bash "$script_path" --cwd="$CWD" --quiet >/dev/null 2>&1
      VALIDATOR_EXIT["$script"]=$?
      ;;
    validate-unit-spec.sh)
      # Run on each unit file; aggregate worst result
      worst=0
      for uf in $(find "${CWD}/.mega-sdd/vaults" -path "*-bound/units/U-*.md" 2>/dev/null); do
        bash "$script_path" --cwd="$CWD" --file-path="$uf" --quiet >/dev/null 2>&1
        rc=$?
        [ "$rc" -gt "$worst" ] && worst=$rc
      done
      VALIDATOR_EXIT["$script"]=$worst
      ;;
    validate-bolt-artifacts.sh)
      worst=0
      for bf in $(find "${CWD}/.mega-sdd/vaults" -path "*/bolts/U-*/bolt-report.md" 2>/dev/null); do
        bash "$script_path" --cwd="$CWD" --file-path="$bf" --quiet >/dev/null 2>&1
        rc=$?
        [ "$rc" -gt "$worst" ] && worst=$rc
      done
      # No bolt files = skip (not fail)
      if [ "$worst" -eq 0 ] && ! find "${CWD}/.mega-sdd/vaults" -path "*/bolts/U-*/bolt-report.md" 2>/dev/null | grep -q .; then
        VALIDATOR_EXIT["$script"]="SKIP"
      else
        VALIDATOR_EXIT["$script"]=$worst
      fi
      ;;
    validate-vault-oqs.sh)
      worst=0
      for vf in $(find "${CWD}/.mega-sdd/vaults" -name "0[0-6]-*.md" -not -path "*-bound/*" -not -path "*/.archived/*" 2>/dev/null); do
        bash "$script_path" --cwd="$CWD" --file-path="$vf" --quiet >/dev/null 2>&1
        rc=$?
        [ "$rc" -gt "$worst" ] && worst=$rc
      done
      VALIDATOR_EXIT["$script"]=$worst
      ;;
    validate-fsd-slots.sh)
      worst=0
      for ff in $(find "${CWD}/.mega-sdd/vaults" -name "FSD.md" 2>/dev/null); do
        bash "$script_path" --cwd="$CWD" --file-path="$ff" --quiet >/dev/null 2>&1
        rc=$?
        [ "$rc" -gt "$worst" ] && worst=$rc
      done
      if [ "$worst" -eq 0 ] && ! find "${CWD}/.mega-sdd/vaults" -name "FSD.md" 2>/dev/null | grep -q .; then
        VALIDATOR_EXIT["$script"]="SKIP"
      else
        VALIDATOR_EXIT["$script"]=$worst
      fi
      ;;
    *)
      bash "$script_path" --cwd="$CWD" --quiet >/dev/null 2>&1
      VALIDATOR_EXIT["$script"]=$?
      ;;
  esac
  VALIDATOR_STATE_FILE["$script"]="${CWD}/.mega-sdd/${state_file}"
done

# --- Phase 2: Vault internal consistency checks (NEW) ---
# Check vault.json entities/flows/adrs counts match markdown content.

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
        results.append({"vault": vault_name, "check": "vault_json_parse", "status": "FAIL", "detail": str(e)})
        continue

    checks = []

    # Check 1: entities count vs 03-data-model.md
    dm_path = os.path.join(vault_dir, "03-data-model.md")
    if os.path.isfile(dm_path):
        dm_content = open(dm_path).read()
        # Count entity blocks (table definitions in DBML or markdown entity headers)
        entity_patterns = len(re.findall(r"^(?:Table|table|##\s+Entity:?\s+)", dm_content, re.MULTILINE))
        vj_entities = len(vj.get("entities", []))
        if entity_patterns > 0 and abs(vj_entities - entity_patterns) > 2:
            checks.append({"check": "entities_count_sync", "status": "WARN",
                          "detail": f"vault.json has {vj_entities} entities; 03-data-model.md has ~{entity_patterns} entity blocks (delta > 2)"})
        else:
            checks.append({"check": "entities_count_sync", "status": "PASS", "detail": f"vault.json={vj_entities}, md~={entity_patterns}"})
    else:
        checks.append({"check": "entities_count_sync", "status": "SKIP", "detail": "03-data-model.md not found"})

    # Check 2: OQ count in vault.json vs 00-index.md
    idx_path = os.path.join(vault_dir, "00-index.md")
    if os.path.isfile(idx_path):
        idx_content = open(idx_path).read()
        oq_in_idx = len(re.findall(r"\bOQ-[A-Z]+-\d+", idx_content))
        vj_oqs = len(vj.get("open_questions", []))
        if oq_in_idx > 0 and abs(vj_oqs - oq_in_idx) > 3:
            checks.append({"check": "oq_count_sync", "status": "WARN",
                          "detail": f"vault.json has {vj_oqs} OQs; 00-index.md references {oq_in_idx} OQ tags (delta > 3)"})
        else:
            checks.append({"check": "oq_count_sync", "status": "PASS", "detail": f"vault.json={vj_oqs}, idx={oq_in_idx}"})

    # Check 3: source_documents paths exist
    for sd in vj.get("source_documents", []):
        sd_path = sd.get("path", "")
        if sd_path and not os.path.isfile(os.path.join(cwd, sd_path)) and not os.path.isfile(sd_path):
            checks.append({"check": "source_doc_exists", "status": "WARN",
                          "detail": f"source_documents[].path '{sd_path}' not found on disk"})

    # Check 4: 7 vault files present (00-index through 06-constraints + vault.json)
    expected_files = ["00-index.md", "01-overview.md", "02-architecture.md",
                      "03-data-model.md", "04-flows.md", "05-decisions.md",
                      "06-constraints.md", "vault.json"]
    for ef in expected_files:
        if not os.path.isfile(os.path.join(vault_dir, ef)):
            checks.append({"check": "vault_files_complete", "status": "FAIL",
                          "detail": f"missing required vault file: {ef}"})

    results.append({"vault": vault_name, "checks": checks})

print(json.dumps(results, indent=2))
PYEOF
)

# --- Phase 3: Aggregate and write report ---
ANALYZE_OUTPUT=$(CWD="$CWD" TS="$TS" VAULT_CONSISTENCY="$VAULT_CONSISTENCY" python3 <<'PYEOF'
import json
import os
import sys
from datetime import datetime

cwd = os.environ["CWD"]
ts = os.environ["TS"]
vault_consistency_raw = os.environ.get("VAULT_CONSISTENCY", "[]")

try:
    vault_consistency = json.loads(vault_consistency_raw)
except Exception:
    vault_consistency = []

# Read existing validator state files
state_files = {
    "binding_units_handoff": ".validation-blockers.json",
    "unit_spec": ".unit-spec-state.json",
    "bolt_artifacts": ".bolt-artifacts-state.json",
    "vault_oqs": ".vault-oqs-state.json",
    "fsd_slots": ".fsd-slots-state.json",
    "vault_binding_coverage": ".vault-binding-coverage-state.json",
    "handoff_yaml": ".handoff-validation-state.json",
}

boundaries = {}
for name, sf in state_files.items():
    path = os.path.join(cwd, ".mega-sdd", sf)
    if os.path.isfile(path):
        try:
            with open(path) as f:
                data = json.load(f)
            boundaries[name] = {
                "status": data.get("status", "UNKNOWN"),
                "state_file": sf,
                "detail": data.get("summary", data.get("halt_type", "(see state file)"))
            }
        except Exception as e:
            boundaries[name] = {"status": "ERROR", "state_file": sf, "detail": str(e)}
    else:
        boundaries[name] = {"status": "NOT_RUN", "state_file": sf, "detail": "state file absent (validator not yet run for this project)"}

# Overall status
all_statuses = [b["status"] for b in boundaries.values()]
vault_statuses = []
for vc in vault_consistency:
    for chk in vc.get("checks", []):
        vault_statuses.append(chk["status"])

has_fail = "FAIL" in all_statuses or "FAIL" in vault_statuses
has_warn = "WARN" in vault_statuses
overall = "FAIL" if has_fail else ("WARN" if has_warn else "PASS")

# Build analyze-state.json
state = {
    "status": overall,
    "analyzed_at": ts,
    "boundaries": boundaries,
    "vault_consistency": vault_consistency,
    "validators_run": len([s for s in all_statuses if s not in ("NOT_RUN",)]),
    "validators_total": len(state_files),
    "validators_pass": all_statuses.count("PASS"),
    "validators_fail": all_statuses.count("FAIL"),
    "validators_not_run": all_statuses.count("NOT_RUN"),
}

state_path = os.path.join(cwd, ".mega-sdd", ".analyze-state.json")
with open(state_path, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

# Build CONSISTENCY-REPORT.md
lines = []
lines.append(f"# Consistency Report — {ts}")
lines.append("")
lines.append(f"**Overall: {overall}**")
lines.append(f"**Validators: {state['validators_pass']} PASS / {state['validators_fail']} FAIL / {state['validators_not_run']} NOT_RUN of {state['validators_total']}**")
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
lines.append("## Vault Internal Consistency (new)")
lines.append("")
for vc in vault_consistency:
    lines.append(f"### Vault: `{vc['vault']}`")
    lines.append("")
    if "checks" in vc:
        lines.append("| Check | Status | Detail |")
        lines.append("|---|---|---|")
        for chk in vc["checks"]:
            lines.append(f"| {chk['check']} | **{chk['status']}** | {chk['detail']} |")
    elif "check" in vc:
        lines.append(f"**{vc['check']}**: {vc['status']} — {vc['detail']}")
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

# Exit code mirrors overall status
OVERALL=$(echo "$ANALYZE_OUTPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('overall','ERROR'))" 2>/dev/null)
case "$OVERALL" in
  PASS) exit 0 ;;
  WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x plugins/mega-sdd/scripts/run-analyze.sh`

- [ ] **Step 3: Proof — run on TF Import (real artifacts)**

Run:
```bash
bash plugins/mega-sdd/scripts/run-analyze.sh \
  --cwd=/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import
```

Expected: JSON output with `overall` status + `CONSISTENCY-REPORT.md` written to TF Import's `.mega-sdd/`. The report should show:
- `binding_units_handoff`: state from existing validator
- `vault_consistency`: entity/OQ counts for all 4 vaults
- At least one NOT_RUN (bolt_artifacts — no bolts exist)

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/scripts/run-analyze.sh
git commit -m "feat(R1): add run-analyze.sh — unified cross-artifact consistency orchestrator"
```

---

### Task 2: Create the `/mega-sdd:analyze` command registration

**Files:**
- Create: `plugins/mega-sdd/commands/analyze.md`

- [ ] **Step 1: Write the command file**

The command file is a markdown doc that tells Claude Code what to do when user types `/mega-sdd:analyze`. It must invoke `run-analyze.sh` and display results.

- [ ] **Step 2: Commit**

```bash
git add plugins/mega-sdd/commands/analyze.md
git commit -m "feat(R1): add /mega-sdd:analyze command registration"
```

---

### Task 3: Create the `analyze` skill (SKILL.md)

**Files:**
- Create: `plugins/mega-sdd/skills/analyze/SKILL.md`

The skill body invokes `run-analyze.sh`, reads the report, and presents it in chat. This is the [VERIFY-STEP] surface — user or orchestrator invokes explicitly.

- [ ] **Step 1: Write the skill file**
- [ ] **Step 2: Commit**

---

### Task 4: Real-run proof on TF Import

**Files:**
- None created (validation run only)

- [ ] **Step 1: Run the script directly against TF Import**

Run: `bash plugins/mega-sdd/scripts/run-analyze.sh --cwd=/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import`

Expected output: JSON with state_path + report_path + overall status.

- [ ] **Step 2: Read the CONSISTENCY-REPORT.md and verify contents**

Run: `cat /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import/.mega-sdd/CONSISTENCY-REPORT.md`

Expected: Markdown table with boundary checks + vault internal consistency checks. At least 4 vaults analyzed. `binding_units_handoff` should have a state. `bolt_artifacts` should be SKIP or NOT_RUN.

- [ ] **Step 3: Read the .analyze-state.json and verify structure**

Run: `cat /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import/.mega-sdd/.analyze-state.json`

Expected: JSON with `status`, `analyzed_at`, `boundaries` dict, `vault_consistency` array.

---

### Task 5: HONESTY distinction — what's proven vs what's deferred

**Logic-proven on real data (THIS iteration):**
- `run-analyze.sh` invoked directly → validators fire → state files written → report aggregated
- All 6 project-wide validators invoked against TF Import
- Vault internal consistency (vault.json ↔ markdown sync) checked

**Hook-firing DEFERRED (NOT claimed as production-verified):**
- `/mega-sdd:analyze` as a Skill-tool invocation (requires plugin cache rebuild + fresh session)
- Auto-trigger at phase boundary in orchestrate-flow (explicitly NOT implemented — manual only per user directive)
- PostToolUse/Stop hook integration (deferred — analyze is [VERIFY-STEP], not [HOOK-VALIDATE])

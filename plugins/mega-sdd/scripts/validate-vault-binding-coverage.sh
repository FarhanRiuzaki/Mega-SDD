#!/usr/bin/env bash
# validate-vault-binding-coverage.sh — Phase C slices 4 + 5 [HOOK-VALIDATE].
#
# Slice 4: vault → binding coverage
#   Every vault doc section (typically `## §<id>` or `## <id>` headings in
#   02-architecture.md / 03-data-model.md / 04-flows.md) SHOULD produce ≥1
#   entry in binding.md's Implementation State Map.
#   Drops indicate orphaned vault sections (vault declares X but binding
#   doesn't track its impl state).
#
# Slice 5: units → bolts traceability
#   Every COMPLETED unit (has unit_id frontmatter, in *-bound/units/) should
#   have a corresponding bolts/U-XXX/bolt-report.md after execution. If bolts/
#   dir exists but a unit has no matching bolt-report, advisory.
#   Pre-execution state (no bolts/ dir at all) → graceful skip (correct state).
#
# Inputs: --cwd
# Outputs: writes .mega-sdd/.vault-binding-coverage-state.json
# Exit: 0=PASS (advisory only), 1=FAIL (drops found), 2=error

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

[ -z "$CWD" ] && exit 2
[ ! -d "$CWD/.mega-sdd/vaults" ] && exit 0

STATE_FILE="${CWD}/.mega-sdd/.vault-binding-coverage-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys, glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

issues = []
slice4_summary = {}
slice5_summary = {}

# ─── Slice 4: vault → binding coverage ──────────────────────────────────────
# For each vault, find sections in vault docs + check binding entries.
vault_dirs = sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*")))
vault_dirs = [d for d in vault_dirs if os.path.isdir(d) and not d.endswith("-bound") and "/.archived/" not in d]

for vault_dir in vault_dirs:
    vault_name = os.path.basename(vault_dir)
    # Find binding doc (might be at vault root OR in a parallel -bound dir)
    binding_candidates = [
        os.path.join(cwd, ".mega-sdd", "vaults", "binding.md"),
        os.path.join(cwd, ".mega-sdd", "vaults", f"binding-{vault_name}.md"),
        os.path.join(cwd, ".mega-sdd", "vaults", f"{vault_name}-bound", "binding.md"),
    ]
    # Glob for binding-phase-*.md too
    binding_candidates.extend(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "binding-*.md")))
    binding_path = next((b for b in binding_candidates if os.path.isfile(b)), None)
    if not binding_path:
        continue  # no binding doc — graceful skip (greenfield vault, not bound yet)

    try:
        binding_content = open(binding_path).read()
    except Exception:
        continue

    # Extract section IDs from vault docs
    # Pattern: `## §<id>` (e.g., `## §lc-issuance`), `## <id>` (h2 heading), or `### F-<flow-id>:` etc.
    section_ids = set()
    for doc in sorted(glob.glob(os.path.join(vault_dir, "0[1-6]-*.md"))):
        try:
            content = open(doc).read()
        except Exception:
            continue
        # Match `## §<id>` (Vault convention)
        for m in re.finditer(r"^##\s+§([\w-]+)", content, re.MULTILINE):
            section_ids.add(m.group(1))
        # Match F-<prefix>-<NN>: flow identifiers
        for m in re.finditer(r"\bF-[A-Z]+-\d+\b", content):
            section_ids.add(m.group(0))

    # For each section_id, check if it appears anywhere in binding content
    orphaned_sections = []
    for sid in sorted(section_ids):
        if sid not in binding_content:
            orphaned_sections.append(sid)

    slice4_summary[vault_name] = {
        "vault_sections_found": len(section_ids),
        "orphaned_in_binding": len(orphaned_sections),
        "binding_doc": os.path.relpath(binding_path, cwd),
    }
    if orphaned_sections:
        issues.append({
            "halt_type": "vault_binding_coverage_gap",
            "vault": vault_name,
            "detail": f"vault {vault_name} has {len(orphaned_sections)} section(s) not tracked in {os.path.basename(binding_path)}",
            "orphaned_sections": orphaned_sections[:10],
            "binding_doc": os.path.relpath(binding_path, cwd),
            "severity": "advisory",
        })

# ─── Slice 5: units → bolts traceability ────────────────────────────────────
# For each bound vault, check if bolts/ directory exists. If yes, each unit
# should have matching bolts/U-XXX/bolt-report.md.
# If bolts/ doesn't exist at all → pre-execution state, graceful skip (PASS).
bound_dirs = sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound")))
for bound_dir in bound_dirs:
    bound_name = os.path.basename(bound_dir)
    bolts_dir = os.path.join(bound_dir, "bolts")
    units_dir = os.path.join(bound_dir, "units")
    if not os.path.isdir(units_dir):
        continue
    if not os.path.isdir(bolts_dir):
        # Pre-execution — correct state, skip
        slice5_summary[bound_name] = {"bolts_dir": "absent (pre-execution)", "skipped": True}
        continue

    # Collect unit IDs from both layouts
    unit_ids = set()
    for u in glob.glob(os.path.join(units_dir, "U-*.md")):
        base = os.path.basename(u).replace(".md", "")
        # Extract U-XXX prefix if name is U-XXX-foo-bar
        m = re.match(r"(U-[A-Z0-9-]*\d+)", base)
        if m:
            unit_ids.add(m.group(1))
    for u in glob.glob(os.path.join(units_dir, "U-*", "unit.md")):
        dirname = os.path.basename(os.path.dirname(u))
        m = re.match(r"(U-[A-Z0-9-]*\d+)", dirname)
        if m:
            unit_ids.add(m.group(1))

    # Check bolt-report existence per unit
    units_without_bolt = []
    for uid in sorted(unit_ids):
        bolt_report = os.path.join(bolts_dir, uid, "bolt-report.md")
        if not os.path.isfile(bolt_report):
            units_without_bolt.append(uid)

    slice5_summary[bound_name] = {
        "units_count": len(unit_ids),
        "units_without_bolt_report": len(units_without_bolt),
    }
    # Advisory — execution might be partial; only flag if a significant fraction lack bolts
    if units_without_bolt and len(units_without_bolt) < len(unit_ids):
        # Partial execution — some bolts done, some not
        issues.append({
            "halt_type": "units_bolts_partial_execution",
            "bound_vault": bound_name,
            "detail": f"{len(units_without_bolt)} of {len(unit_ids)} units lack bolt-report.md (partial execution)",
            "units_without_bolt": units_without_bolt[:20],
            "severity": "advisory",
        })

status = "PASS" if not issues else "FAIL"
report = {
    "ts": ts,
    "status": status,
    "validator": "validate-vault-binding-coverage.sh",
    "slice4_summary": slice4_summary,
    "slice5_summary": slice5_summary,
    "issues_count": len(issues),
    "issues": issues,
    "next_action": (
        "Vault→binding coverage clean and units→bolts traceability consistent."
        if status == "PASS"
        else "Advisory: vault sections may need binding entries; partial bolt execution detected. Review listed issues."
    ),
}

try:
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
except Exception:
    sys.exit(2)

if not quiet:
    print(json.dumps(report, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF
exit $?

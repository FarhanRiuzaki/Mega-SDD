#!/usr/bin/env bash
# Fixture test for plugins/mega-sdd/scripts/list-modules.sh (audit batch E).
# Builds a throwaway vault with a real modules.yaml (dod as a YAML list mixing a
# [x]-marked item and a plain canonical string), units carrying `module:`
# frontmatter, and a bolt-outcomes.json — then asserts the read-only rollup:
#   A  table rollup: per-module unit + DoD counts, status label, blocked-by
#   B  --format=json structured output
#   C  DoD both-forms (blocker #2): [x] counted, plain string NOT, no crash
#   D  positional [vault-path] (blocker #1 — parity with the command)
#   E  M-unassigned surfaced for a unit whose module isn't defined
#   F  PyYAML fallback parser (MEGA_SDD_FORCE_YAML_FALLBACK=1) gives identical math
#   G  usage/refusal exit codes (unknown flag/format/module → 2; no vault → 1)
set -u
err=0

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/plugins/mega-sdd/scripts/list-modules.sh"
[ -f "$SCRIPT" ] || { echo "FATAL: script not found at $SCRIPT"; exit 1; }

# mk_vault DIR — populate DIR with a vault under .mega-sdd/vaults/leave-management.
mk_vault() {
  local d="$1" v="$1/.mega-sdd/vaults/leave-management"
  mkdir -p "$v/_meta" "$v/units" "$v/.memory"
  cat > "$v/vault.json" <<'JSON'
{ "title": "leave-management", "version": "v3" }
JSON
  # dod: MIXES a [x]-marked item (done) with a plain scalar string (the canonical
  # fresh-from-generate-units form → NOT done). This is the blocker-#2 guard.
  cat > "$v/_meta/modules.yaml" <<'YAML'
mega_sdd_schema: 1
modules:
  - id: M-auth
    name: "Authentication & Authorization"
    dod:
      - "[x] Sanctum middleware applied to /api/* routes"
      - "All auth flows return RFC 7807 errors"
    priority: P0
    blocks:
      - M-leave
    blocked_by: []
  - id: M-leave
    name: "Leave Management"
    dod:
      - "End-to-end leave request UAT passes"
    priority: P1
    blocked_by:
      - M-auth
YAML
  _unit "$v" U-001 M-auth
  _unit "$v" U-002 M-auth
  _unit "$v" U-003 M-auth
  _unit "$v" U-010 M-leave
  _unit "$v" U-011 M-leave
  _unit "$v" U-099 M-ghost            # module not in modules.yaml → M-unassigned
  cat > "$v/.memory/bolt-outcomes.json" <<'JSON'
{ "memory_schema": 1, "vault_id": "leave-management", "bolts": [
  { "unit_id": "U-001", "status": "completed" },
  { "unit_id": "U-002", "status": "completed" },
  { "unit_id": "U-011", "status": "halted_postflight" }
] }
JSON
}

_unit() {   # _unit VAULTDIR ID MODULE
  cat > "$1/units/$2.md" <<EOF
---
id: $2
title: $2 work
module: $3
task_type: create
---
body
EOF
}

# Expected derived state:
#   M-auth : 3 units, U-001+U-002 completed → 2/3, in-progress; DoD 1/2 (one [x]);
#            no blockers → actionable.
#   M-leave: 2 units, U-011 halted (in-progress), U-010 pending → 0/2 completed,
#            not-started; blocked-by M-auth (pending, M-auth not completed).
#   U-099  : M-unassigned.

# ---- Scenario A: table rollup ----
A=$(mktemp -d); trap 'rm -rf "$A"' EXIT
mk_vault "$A"
outA=$(bash "$SCRIPT" --cwd="$A" 2>&1); rcA=$?
[ $rcA -eq 0 ] || { echo "A: expected exit 0, got $rcA"; err=1; }
echo "$outA" | grep -E '^M-auth' | grep -q '2/3'            || { echo "A: M-auth units != 2/3"; err=1; }
echo "$outA" | grep -E '^M-auth' | grep -q 'in-progress'    || { echo "A: M-auth not in-progress"; err=1; }
echo "$outA" | grep -E '^M-auth' | grep -q '1/2'            || { echo "A: M-auth DoD != 1/2 (blocker #2)"; err=1; }
echo "$outA" | grep -E '^M-leave'| grep -q '0/2'            || { echo "A: M-leave units != 0/2"; err=1; }
echo "$outA" | grep -E '^M-leave'| grep -q 'M-auth (pending)' || { echo "A: M-leave blocked-by not resolved"; err=1; }
echo "$outA" | grep -qi 'M-unassigned'                      || { echo "A: M-unassigned not surfaced"; err=1; }
echo "$outA" | grep -qi 'actionable: .*M-auth'              || { echo "A: M-auth not flagged actionable"; err=1; }
[ $err -eq 0 ] && echo "A PASS (table rollup: units/DoD/status/blocked-by/unassigned/actionable)" || { echo "---- A ----"; echo "$outA"; }

# ---- Scenario B: --format=json ----
B=$(mktemp -d); trap 'rm -rf "$A" "$B"' EXIT
mk_vault "$B"
outB=$(bash "$SCRIPT" --cwd="$B" --format=json 2>&1); rcB=$?
[ $rcB -eq 0 ] || { echo "B: json expected exit 0, got $rcB"; err=1; }
OUT_JSON="$outB" python3 <<'PY' || err=1
import json, os, sys
d = json.loads(os.environ["OUT_JSON"])
m = {x["id"]: x for x in d["modules"]}
ok = True
def chk(c, label):
    global ok
    if not c: print("B: FAIL", label); ok = False
chk(m["M-auth"]["units"]["completed"] == 2, "M-auth completed==2")
chk(m["M-auth"]["units"]["total"] == 3, "M-auth total==3")
chk(m["M-auth"]["dod"] == {"done":1,"total":2}, "M-auth dod 1/2")
chk(m["M-auth"]["status"] == "in-progress", "M-auth status")
chk(m["M-leave"]["status"] == "not-started", "M-leave status")
chk(any(b["id"]=="M-auth" and b["satisfied"] is False for b in m["M-leave"]["blocked_by_resolved"]), "M-leave blocker unsatisfied")
chk("M-auth" in d["actionable"], "M-auth actionable")
chk("M-leave" not in d["actionable"], "M-leave not actionable")
chk(d["total_units"] == 6, "total_units==6")
sys.exit(0 if ok else 1)
PY
[ $err -eq 0 ] && echo "B PASS (json: structured counts/status/blocked_by/actionable)"

# ---- Scenario C: DoD both-forms regression (blocker #2) ----
# Already asserted M-auth=1/2 in A/B; restate as a named guard against the
# draft's `^\s*\[[xX]\]` regex that matched NEITHER canonical form.
echo "$outA" | grep -E '^M-auth' | grep -q '1/2' \
  && echo "C PASS (DoD counts [x]=done, plain scalar=not-done, no crash)" \
  || { echo "C: DoD both-forms handling regressed"; err=1; }

# ---- Scenario D: positional [vault-path] (blocker #1 — parity) ----
D=$(mktemp -d); trap 'rm -rf "$A" "$B" "$D"' EXIT
mk_vault "$D"
outD=$(bash "$SCRIPT" "$D/.mega-sdd/vaults/leave-management" 2>&1); rcD=$?
[ $rcD -eq 0 ] || { echo "D: positional path expected exit 0, got $rcD"; err=1; }
echo "$outD" | grep -E '^M-auth' | grep -q '2/3' || { echo "D: positional vault-path not honored"; err=1; }
[ $rcD -eq 0 ] && echo "D PASS (positional vault-path honored — command argument-hint parity)"

# ---- Scenario E: M-unassigned detail ----
echo "$outA" | grep -i 'M-unassigned' | grep -q 'U-099' \
  && echo "E PASS (unit with undefined module → M-unassigned, names the unit)" \
  || { echo "E: M-unassigned did not name U-099"; err=1; }

# ---- Scenario F: PyYAML fallback parser ----
outF=$(MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$SCRIPT" --cwd="$A" 2>&1); rcF=$?
[ $rcF -eq 0 ] || { echo "F: fallback expected exit 0, got $rcF"; err=1; }
echo "$outF" | grep -E '^M-auth' | grep -q '2/3' || { echo "F: fallback unit count wrong"; err=1; }
echo "$outF" | grep -E '^M-auth' | grep -q '1/2' || { echo "F: fallback DoD count wrong"; err=1; }
echo "$outF" | grep -E '^M-leave'| grep -q 'M-auth (pending)' || { echo "F: fallback blocked-by wrong"; err=1; }
[ $rcF -eq 0 ] && echo "F PASS (hand-rolled YAML fallback gives identical rollup)"

# ---- Scenario G: usage / refusal exit codes ----
errG=0
bash "$SCRIPT" --cwd="$A" --bogus        >/dev/null 2>&1; [ $? -eq 2 ] || { echo "G: --bogus should exit 2"; errG=1; }
bash "$SCRIPT" --cwd="$A" --format=xml   >/dev/null 2>&1; [ $? -eq 2 ] || { echo "G: bad --format should exit 2"; errG=1; }
bash "$SCRIPT" --cwd="$A" --module=M-nope >/dev/null 2>&1; [ $? -eq 2 ] || { echo "G: unknown --module should exit 2"; errG=1; }
EMPTY=$(mktemp -d); bash "$SCRIPT" --cwd="$EMPTY" >/dev/null 2>&1; [ $? -eq 1 ] || { echo "G: no vault should exit 1"; errG=1; }
rm -rf "$EMPTY"
[ $errG -eq 0 ] && echo "G PASS (unknown flag/format/module → 2; no vault → 1)" || err=1

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "ALL PASS" || echo "FAILED"
exit $err

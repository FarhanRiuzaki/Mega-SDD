#!/usr/bin/env bash
# Fixture test for plugins/mega-sdd/scripts/analyze-parallelism.sh (audit batch E / F4).
# Builds a throwaway vault with a KNOWN dependency DAG and asserts the deterministic
# DAG math: depth, max parallel width, topological waves, critical path, speedup
# (total_units / depth), forks/joins, per-squad + per-module sub-DAGs, cross-edge
# counts, and the over-coupling CANDIDATE basis. Plus: cycle → exit 1, unknown flag
# → exit 2, vault-not-found → exit 1, and json/mermaid/--depth-only don't crash.
# No git needed (pure file read).
set -u
err=0

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/plugins/mega-sdd/scripts/analyze-parallelism.sh"
[ -f "$SCRIPT" ] || { echo "FATAL: script not found at $SCRIPT"; exit 1; }

# mk_vault DIR — known DAG (7 units, depth 3, max_width 4):
#   Wave 1 (no deps):     U-001 U-010 U-020 U-030   (4 parallel)
#   Wave 2:               U-002 (dep U-001)  U-011 (dep U-010)
#   Wave 3:               U-008 (dep U-002)
#   speedup = 7 units / depth 3 = 2.33x
#   U-001 forks to U-002 + U-007? -> keep U-001 out-degree 1 here; add a fork below.
# Make U-001 a fork: U-002 and a second dependent so out-degree>=2.
mk_vault() {
  local d="$1"
  local U="$d/.mega-sdd/vaults/demo/units"
  mkdir -p "$U"
  # Wave 1 roots
  cat > "$U/U-001.md" <<'MD'
---
id: U-001
module: M-auth
squad: squad-be
depends_on: []
target_files:
  - path: src/auth/login.ts
    operation: create
---
# U-001 keystone
MD
  cat > "$U/U-010.md" <<'MD'
---
id: U-010
module: M-auth
squad: squad-be
depends_on: []
target_files:
  - path: src/auth/session.ts
    operation: create
---
# U-010
MD
  cat > "$U/U-020.md" <<'MD'
---
id: U-020
module: M-leave
squad: squad-fe
depends_on: []
---
# U-020
MD
  cat > "$U/U-030.md" <<'MD'
---
id: U-030
module: M-leave
squad: squad-fe
depends_on: []
---
# U-030
MD
  # Wave 2 — block-style depends_on; U-002 shares NO target_files with U-001 (over-coupling candidate)
  cat > "$U/U-002.md" <<'MD'
---
id: U-002
module: M-auth
squad: squad-be
depends_on:
  - U-001
target_files:
  - path: src/auth/refresh.ts
    operation: create
---
# U-002
MD
  # U-007 — inline-list depends_on, cross-module dep on U-001 (M-leave depends on M-auth)
  cat > "$U/U-007.md" <<'MD'
---
id: U-007
module: M-leave
squad: squad-be
depends_on: [U-001]
---
# U-007 cross-module dependent of the keystone
MD
  # Wave 3 — depends on a wave-2 unit -> depth 3
  cat > "$U/U-008.md" <<'MD'
---
id: U-008
module: M-auth
squad: squad-be
depends_on: [U-002]
---
# U-008 deepest
MD
}

# mk_cycle DIR — a 2-cycle the script must refuse.
mk_cycle() {
  local d="$1"
  local U="$d/.mega-sdd/vaults/demo/units"
  mkdir -p "$U"
  cat > "$U/U-001.md" <<'MD'
---
id: U-001
depends_on: [U-002]
---
# U-001
MD
  cat > "$U/U-002.md" <<'MD'
---
id: U-002
depends_on: [U-001]
---
# U-002
MD
}

# ---- Scenario A: known-graph metrics (JSON) ----
A=$(mktemp -d); trap 'rm -rf "$A"' EXIT
mk_vault "$A"
errA=0
jsonA=$(bash "$SCRIPT" --cwd="$A" --format=json 2>&1); rcA=$?
[ $rcA -eq 0 ] || { echo "A: expected exit 0, got $rcA"; errA=1; }
# Pull metrics out with python (no jq dependency assumed).
read -r TU DEPTH MW WAVES SPEED < <(printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(d["total_units"], d["depth"], d["max_width"], d["total_waves"], d["parallelism_speedup"])
' 2>/dev/null)
[ "$TU" = "7" ]     || { echo "A: total_units expected 7, got $TU"; errA=1; }
[ "$DEPTH" = "3" ]  || { echo "A: depth expected 3, got $DEPTH"; errA=1; }
[ "$MW" = "4" ]     || { echo "A: max_width expected 4, got $MW"; errA=1; }
[ "$WAVES" = "3" ]  || { echo "A: total_waves expected 3, got $WAVES"; errA=1; }
# speedup = 7/3 = 2.33
[ "$SPEED" = "2.33" ] || { echo "A: speedup expected 2.33 (7/3), got $SPEED"; errA=1; }
# U-001 is a fork (out-degree 2: U-002 + U-007)
printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
forks={f["unit"]:f["dependents"] for f in d["forks"]}
sys.exit(0 if forks.get("U-001")==2 else 1)
' || { echo "A: U-001 should be a fork with 2 dependents"; errA=1; }
# Critical path length 3 (U-001 -> U-002 -> U-008)
printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if d["critical_path_len"]==3 and d["critical_path"][0]=="U-001" and d["critical_path"][-1]=="U-008" else 1)
' || { echo "A: critical path expected U-001..U-008 len 3"; errA=1; }
# Over-coupling: U-002 depends_on U-001 with zero target overlap; U-007 cross-module
printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
oc={(c["unit"],c["depends_on"]):c for c in d["suspected_over_coupling"]}
ok = (("U-002","U-001") in oc and oc[("U-002","U-001")]["zero_target_overlap"]
      and ("U-007","U-001") in oc and oc[("U-007","U-001")]["cross_module"])
sys.exit(0 if ok else 1)
' || { echo "A: over-coupling candidates (U-002 disjoint, U-007 cross-module) missing"; errA=1; }
# Per-squad present (squad-be, squad-fe)
printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if "squad-be" in d["per_squad"] and "squad-fe" in d["per_squad"] else 1)
' || { echo "A: per_squad missing squad-be/squad-fe"; errA=1; }
[ $errA -eq 0 ] && echo "A PASS (known-graph metrics: depth/width/waves/speedup/fork/critical-path/over-coupling/per-squad)"
[ $errA -ne 0 ] && { err=1; echo "---- A json ----"; echo "$jsonA"; }

# ---- Scenario B: table format renders + is human-readable ----
B=$(mktemp -d); trap 'rm -rf "$A" "$B"' EXIT
mk_vault "$B"
outB=$(bash "$SCRIPT" --cwd="$B" 2>&1); rcB=$?
errB=0
[ $rcB -eq 0 ] || { echo "B: table expected exit 0, got $rcB"; errB=1; }
echo "$outB" | grep -q 'Max parallel width: 4' || { echo "B: table lacks 'Max parallel width: 4'"; errB=1; }
echo "$outB" | grep -q 'Parallelism speedup: 2.33x' || { echo "B: table lacks speedup line"; errB=1; }
echo "$outB" | grep -q 'Topological waves:' || { echo "B: table lacks wave plan"; errB=1; }
[ $errB -eq 0 ] && echo "B PASS (table format human-readable; width+speedup+waves)" || { err=1; echo "---- B ----"; echo "$outB"; }

# ---- Scenario C: cycle → exit 1 ----
C=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C"' EXIT
mk_cycle "$C"
outC=$(bash "$SCRIPT" --cwd="$C" 2>&1); rcC=$?
[ $rcC -eq 1 ] || { echo "C: cycle expected exit 1, got $rcC"; err=1; }
echo "$outC" | grep -qi 'cycle' || { echo "C: refusal message lacks 'cycle'"; err=1; }
[ $rcC -eq 1 ] && echo "C PASS (cycle refused with exit 1)"

# ---- Scenario D: unknown flag → exit 2 ----
D=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$D"' EXIT
mk_vault "$D"
bash "$SCRIPT" --cwd="$D" --bogus >/dev/null 2>&1; rcD=$?
[ $rcD -eq 2 ] || { echo "D: unknown flag expected exit 2, got $rcD"; err=1; }
[ $rcD -eq 2 ] && echo "D PASS (unknown flag rejected with exit 2)"

# ---- Scenario E: advertised flags don't crash (json/mermaid/--per/--depth-only/--module/--squad) ----
E=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$D" "$E"' EXIT
mk_vault "$E"
errE=0
bash "$SCRIPT" --cwd="$E" --format=mermaid   >/dev/null 2>&1 || { echo "E: --format=mermaid crashed ($?)"; errE=1; }
bash "$SCRIPT" --cwd="$E" --per=module       >/dev/null 2>&1 || { echo "E: --per=module crashed ($?)"; errE=1; }
bash "$SCRIPT" --cwd="$E" --per=squad        >/dev/null 2>&1 || { echo "E: --per=squad crashed ($?)"; errE=1; }
bash "$SCRIPT" --cwd="$E" --depth-only       >/dev/null 2>&1 || { echo "E: --depth-only crashed ($?)"; errE=1; }
bash "$SCRIPT" --cwd="$E" --module=M-auth    >/dev/null 2>&1 || { echo "E: --module=M-auth crashed ($?)"; errE=1; }
bash "$SCRIPT" --cwd="$E" --squad=squad-be   >/dev/null 2>&1 || { echo "E: --squad=squad-be crashed ($?)"; errE=1; }
# mermaid output sanity
bash "$SCRIPT" --cwd="$E" --format=mermaid 2>&1 | grep -q 'graph LR' || { echo "E: mermaid lacks 'graph LR'"; errE=1; }
# --depth-only suppresses waves
bash "$SCRIPT" --cwd="$E" --depth-only 2>&1 | grep -q 'Topological waves:' && { echo "E: --depth-only should suppress waves"; errE=1; }
# bad --per value → exit 2
bash "$SCRIPT" --cwd="$E" --per=nonsense >/dev/null 2>&1; [ $? -eq 2 ] || { echo "E: bad --per value should exit 2"; errE=1; }
[ $errE -eq 0 ] && echo "E PASS (all advertised flags accepted; bad --per rejected)" || err=1

# ---- Scenario F: vault-not-found → exit 1 ----
F=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$D" "$E" "$F"' EXIT
# empty project, no .mega-sdd/
bash "$SCRIPT" --cwd="$F" >/dev/null 2>&1; rcF=$?
[ $rcF -eq 1 ] || { echo "F: no-vault expected exit 1, got $rcF"; err=1; }
[ $rcF -eq 1 ] && echo "F PASS (no vault → exit 1)"

# ---- Scenario G: transitive `blocks` closure (spec 2026-08-29 Fase 2) ----
# The discriminating case: U-001's DIRECT dependents are 2 (U-002, U-007) but it
# transitively blocks 3 (U-008 sits behind U-002). A test that only asserted
# blocks(U-001)>0 would pass against `out_degree` and prove nothing — this one
# fails unless the closure is actually transitive.
errG=0
printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
b=d.get("blocks")
if not isinstance(b,dict): print("blocks missing or not an object"); sys.exit(1)
exp={"U-001":3,"U-002":1,"U-007":0,"U-008":0,"U-010":0,"U-020":0,"U-030":0}
bad={k:(b.get(k),v) for k,v in exp.items() if b.get(k)!=v}
if bad: print("blocks mismatch (got,expected):",bad); sys.exit(1)
# transitive, not direct: forks says U-001 has 2 DIRECT dependents, blocks says 3
direct={f["unit"]:f["dependents"] for f in d["forks"]}
if direct.get("U-001") != 2: print("fixture drift: direct dependents of U-001 !=2"); sys.exit(1)
if b["U-001"] == direct["U-001"]: print("blocks equals direct dependents — closure is not transitive"); sys.exit(1)
sys.exit(0)
' || errG=1
# every unit is keyed, leaves included (a missing leaf key would break consumers)
printf '%s' "$jsonA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if len(d["blocks"])==d["total_units"] else 1)
' || { echo "G: blocks must key every unit ($(printf '%s' "$jsonA" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["blocks"]))'))"; errG=1; }
[ $errG -eq 0 ] && echo "G PASS (transitive blocks closure; distinct from out_degree; keys every unit)" || err=1

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "ALL PASS" || echo "FAILED"
exit $err

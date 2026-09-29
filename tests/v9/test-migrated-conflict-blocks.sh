#!/usr/bin/env bash
# test-migrated-conflict-blocks.sh — invariant #2 on a MIGRATED vault (spec
# docs/superpowers/specs/2026-09-27-v9-simplification-design.md §7 #9: "a migrated vault
# with an unresolved CONFLICT still blocks until the mandatory JIT re-bind re-verdicts
# it"; plugins/mega-sdd/CLAUDE.md invariant #2).
#
# Regression pinned (9.0 verifier finding V4): a layout-2 vault whose binding.md carries an
# unresolved `### CONFLICT-1`, migrated with `migrate-paths --vault-layout=3 --apply`, then
# re-bound with the mandatory `rebind-units.sh --units=all`. The re-bind verdicts only the
# unit's own claims (target_files / ## Anchors / ## Claims) — none of them covers CONFLICT-1
# — yet 9.0 downgraded the conflict to the advisory `conflict_migrated_rebound` and the gate
# PASSED. 8.8.1 kept blocking (binding_missing). A re-bind that does not re-verdict the
# conflict must not open the gate.
#
#   a  migrated + re-bound, no claim re-verdicts CONFLICT-1 → FAIL binding_missing naming
#      CONFLICT-1 (no --units, --units=U-001, --units=all); rebind-units gate FAIL
#   b  migrated, never re-bound → FAIL binding_missing (unchanged)
#   c  the owning unit drops CONFLICT-1 from binding_refs after the migration → still FAIL
#      (bolts/U-001/binding-migrated.json owns it)
#   d  an unresolved CONFLICT no unit cited survives only in the archived binding.md → FAIL
#   e  human resolution recorded before the migration (✅ RESOLVED (KEEP_CODE)) → PASS
#   f  genuinely re-verdicted: a `## Claims` line naming CONFLICT-1 gets a fresh CONFIRMED
#      verdict from the sole writer → PASS (advisory conflict_migrated_reverdicted)
#   g  re-verdicted as CONFLICT → the per-unit leg blocks the unit (--units=U-001 FAIL
#      conflict_unresolved); a human resolution via write-unit-binding --resolve opens it
#   h  a linked claim that is still OQ (text claim, no ladder E3 verdict) is NOT a
#      re-verdict → FAIL binding_missing
#   i  a binding.json that is not the unit's own unit-binding/2 stamp is NOT a re-verdict
#   k  a ✅ written into binding-migrated.json after the migration while the archived
#      binding.md still records the block open is NOT a human resolution → FAIL
#   j  layout-3 happy path (plan-born, no migration, no CONFLICT) → PASS
# Run: bash tests/v9/test-migrated-conflict-blocks.sh </dev/null
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; PLUGIN="$ROOT/plugins/mega-sdd"; S="$PLUGIN/scripts"
VAL="$S/validate-handoff-binding-units.sh"
FIX="$PLUGIN/tests/graph/fixtures/derive-vault-v2"
[ -f "$FIX/vault.md" ] || { echo "fixture missing: $FIX" >&2; exit 2; }
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
G() { git -C "$1" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "${@:2}"; }

# drops/extras summary of the CURRENT blocker file: "status|drop:type:ids;...|extra:type:ids;..."
summ() { python3 - "$1/.mega-sdd/.validation-blockers.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
def ids(x):
    v = x.get("conflict_ids_cited") or ([x["conflict_id"]] if x.get("conflict_id") else [])
    return ",".join(sorted(str(i) for i in v))
print("%s|%s|%s" % (d.get("status"),
    ";".join("%s:%s" % (x.get("type"), ids(x)) for x in d.get("drops", [])),
    ";".join("%s:%s" % (x.get("type"), ids(x)) for x in d.get("extras", []))))
PY
}
val() { bash "$VAL" --cwd="$1" --quiet ${2:+--units=$2} >/dev/null 2>&1; echo $?; }

# layout-2 project: vault `leave` (the derive-vault-v2 four-file fixture) + binding.md + U-001
# citing CONFLICT-1 — the verifier's V4 fixture. $2 = the CONFLICT-1 detail block.
mkproj() { # <dir> <conflict-block> [extra binding.md text]
  local P="$1" V="$1/.mega-sdd/vaults/leave"
  mkdir -p "$P/.mega-sdd/vaults" "$P/app/Models"
  cp -R "$FIX" "$V"; mkdir -p "$V/units"
  printf '<?php\nclass Product {}\n' > "$P/app/Models/Product.php"
  printf '# Binding — leave\n\n## Conflicts (1)\n\n%s\n%s' "$2" "${3:-}" > "$V/binding.md"
  cat > "$V/units/U-001.md" <<'U'
---
id: U-001
title: Product model
task_type: extend
binding_refs: [CONFLICT-1]
target_files:
  - path: app/Models/Product.php
    operation: modify
acceptance_test:
  - type: test
    command: php -l app/Models/Product.php
    expects: "No syntax errors"
---
# U-001
U
  ( cd "$P" && git init -q . ) && G "$P" add -A && G "$P" commit -qm seed
}
migrate() { # <dir>
  ( cd "$1" && bash "$S/migrate-paths.sh" --vault-layout=3 --apply >/dev/null 2>&1 ) || { bad "precondition: migrate-paths --vault-layout=3 --apply failed in $1"; return 1; }
  [ -f "$1/.mega-sdd/vaults/leave/context.md" ] && [ -f "$1/.mega-sdd/vaults/leave/_meta/archive/layout2/binding.md" ] \
    || { bad "precondition: $1 not migrated to layout-3"; return 1; }
  G "$1" add -A && G "$1" commit -qm migrated
}
rebind() { # <dir> -> prints the rebind-units JSON line
  bash "$S/rebind-units.sh" --cwd="$1" --vault="$1/.mega-sdd/vaults/leave" --units=all 2>/dev/null | tail -1
}
UNRESOLVED='### CONFLICT-1 — `App\Models\Product` name collision
- **Vault doc**: model.md §Product
- **Codebase artifact**: app/Models/Product.php
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT'
RESOLVED='### ✅ CONFLICT-1 RESOLVED (KEEP_CODE) — `App\Models\Product` name collision
- **Claim**: C-001
- **Verdict**: CONFLICT (BLOCKING)
- **Resolution**: ✅ RESOLVED (KEEP_CODE) — owner 2026-09-01'

# ── a: the V4 regression — migrated, re-bound, CONFLICT-1 never re-verdicted ──
A="$T/a"; mkproj "$A" "$UNRESOLVED"; migrate "$A"
BM="$A/.mega-sdd/vaults/leave/bolts/U-001/binding-migrated.json"
grep -q 'CONFLICT (BLOCKING)' "$BM" 2>/dev/null && ok "a0: binding-migrated.json carries the unresolved CONFLICT-1 block" || bad "a0: $(head -c 300 "$BM" 2>/dev/null)"
RB="$(rebind "$A")"
[ -f "$A/.mega-sdd/vaults/leave/bolts/U-001/binding.json" ] && ok "a1: rebind-units --units=all wrote bolts/U-001/binding.json (the mandatory full JIT re-bind ran)" || bad "a1: no binding.json after re-bind: $RB"
echo "$RB" | grep -q '"gate": "FAIL"' && ok "a2: the re-bind hop's own gate is FAIL" || bad "a2: rebind-units gate not FAIL: $RB"
for U in "" U-001 all; do
  R="$(val "$A" "$U")"; SM="$(summ "$A")"
  case "$R|$SM" in
    "1|FAIL|"*"binding_missing:"*"CONFLICT-1"*) ok "a3${U:+ --units=$U}: migrated CONFLICT-1 the re-bind did not re-verdict still BLOCKS (binding_missing) — $SM" ;;
    *) bad "a3${U:+ --units=$U}: rc=$R $SM (expected FAIL binding_missing CONFLICT-1)" ;;
  esac
done
val "$A" >/dev/null; case "$(summ "$A")" in *conflict_migrated_rebound*) bad "a4: the advisory downgrade conflict_migrated_rebound is still emitted" ;; *) ok "a4: no advisory downgrade (conflict_migrated_rebound) — the block stays a drop" ;; esac
# a5: the enforcement point itself — the PreToolUse hook denies the execute-bolts Skill entry (the
# per-unit Agent leg was removed in P3, spec v9 §8.6); the gate re-derives the blocker file (removed first) naming CONFLICT-1
rm -f "$A/.mega-sdd/.validation-blockers.json"
O="$(printf '{"session_id":"sess-mig-0001","cwd":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:execute-bolts","args":"--all --lite"}}' "$A" | ( cd "$A" && bash "$PLUGIN/hooks/pre-tool-use" 2>/dev/null ))"
case "$O|$(summ "$A")" in *'"permissionDecision": "deny"'*binding_missing*"|FAIL|"*"binding_missing:"*"CONFLICT-1"*) ok "a5: the PreToolUse hook DENIES the execute-bolts Skill entry (binding_missing, CONFLICT-1)" ;; *) bad "a5: hook did not deny on binding_missing: $(echo "$O" | head -c 400) | $(summ "$A")" ;; esac

# ── b: migrated, never re-bound ──
B="$T/b"; mkproj "$B" "$UNRESOLVED"; migrate "$B"
R="$(val "$B")"; SM="$(summ "$B")"
case "$R|$SM" in "1|FAIL|"*"binding_missing:"*"CONFLICT-1"*) ok "b: migrated, not re-bound → FAIL binding_missing" ;; *) bad "b: rc=$R $SM" ;; esac

# ── c: the owning unit drops the citation after the migration ──
C="$T/c"; mkproj "$C" "$UNRESOLVED"; migrate "$C"
sed -i.bak 's/^binding_refs: \[CONFLICT-1\]$/binding_refs: []/' "$C/.mega-sdd/vaults/leave/units/U-001.md" && rm -f "$C/.mega-sdd/vaults/leave/units/U-001.md.bak"
G "$C" add -A && G "$C" commit -qm "drop the citation"
rebind "$C" >/dev/null
R="$(val "$C" U-001)"; SM="$(summ "$C")"
case "$R|$SM" in "1|FAIL|"*"CONFLICT-1"*) ok "c: citation dropped after migration → the owned CONFLICT-1 (binding-migrated.json) still blocks — $SM" ;; *) bad "c: rc=$R $SM" ;; esac

# ── d: an unresolved CONFLICT no unit cited — only the archived binding.md carries it ──
D="$T/d"; mkproj "$D" "$RESOLVED" '
### CONFLICT-7 — leave balance rounding differs
- **Vault doc**: model.md §LeaveBalance
- **Verdict**: CONFLICT (BLOCKING)
'
migrate "$D"; rebind "$D" >/dev/null
R="$(val "$D")"; SM="$(summ "$D")"
case "$R|$SM" in "1|FAIL|"*"CONFLICT-7"*) ok "d: an uncited unresolved CONFLICT-7 in the archived binding.md still blocks after migration — $SM" ;; *) bad "d: rc=$R $SM" ;; esac
case "$(echo "$SM" | cut -d'|' -f2)" in *"CONFLICT-1"*) bad "d2: the human-resolved CONFLICT-1 is reported as a drop: $SM" ;; *) ok "d2: the human-resolved CONFLICT-1 is not a drop" ;; esac

# ── e: human resolution recorded before the migration → opens ──
E="$T/e"; mkproj "$E" "$RESOLVED"; migrate "$E"; RB="$(rebind "$E")"
R="$(val "$E")"; SM="$(summ "$E")"
[ "$R" = 0 ] && case "$SM" in PASS*) true ;; *) false ;; esac && ok "e: pre-migration human resolution (✅ RESOLVED (KEEP_CODE)) → PASS" || bad "e: rc=$R $SM"
R="$(val "$E" U-001)"; [ "$R" = 0 ] && ok "e2: …and --units=U-001 → PASS" || bad "e2: rc=$R $(summ "$E")"

# ── f: genuinely re-verdicted (fresh CONFIRMED on a claim naming CONFLICT-1) → opens ──
F="$T/f"; mkproj "$F" "$UNRESOLVED"; migrate "$F"
printf '\n## Claims\n- C-U001-R1 "Product stays in app/Models as the code has it (re-verdicts CONFLICT-1)" — expect: app/Models/Product.php — must-exist\n' >> "$F/.mega-sdd/vaults/leave/units/U-001.md"
G "$F" add -A && G "$F" commit -qm "U-001 claim re-verdicts CONFLICT-1"
RB="$(rebind "$F")"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); c=[x for x in d["claims"] if x["id"]=="C-U001-R1"]; sys.exit(0 if c and c[0]["verdict"]=="CONFIRMED" else 1)' "$F/.mega-sdd/vaults/leave/bolts/U-001/binding.json" \
  && ok "f0: the writer verdicted the linked claim C-U001-R1 CONFIRMED" || bad "f0: $(head -c 400 "$F/.mega-sdd/vaults/leave/bolts/U-001/binding.json")"
for U in "" U-001; do
  R="$(val "$F" "$U")"; SM="$(summ "$F")"
  case "$R|$SM" in "0|PASS|"*"conflict_migrated_reverdicted:CONFLICT-1"*) ok "f${U:+ --units=$U}: re-verdicted by a fresh CONFIRMED → PASS, visible as the advisory conflict_migrated_reverdicted" ;; *) bad "f${U:+ --units=$U}: rc=$R $SM" ;; esac
done

# ── g: re-verdicted as CONFLICT → the per-unit gate blocks; the human resolution opens ──
Gd="$T/g"; mkproj "$Gd" "$UNRESOLVED"; migrate "$Gd"
printf '\n## Claims\n- C-U001-R1 "Product is a NEW model, no class may exist yet (CONFLICT-1)" — expect: app/Models/Product.php — must-not-exist\n' >> "$Gd/.mega-sdd/vaults/leave/units/U-001.md"
G "$Gd" add -A && G "$Gd" commit -qm "U-001 claim re-verdicts CONFLICT-1"
rebind "$Gd" >/dev/null
R="$(val "$Gd" U-001)"; SM="$(summ "$Gd")"
case "$R|$SM" in "1|FAIL|"*"conflict_unresolved:C-U001-R1"*) ok "g1: re-verdicted as CONFLICT → --units=U-001 FAIL conflict_unresolved C-U001-R1" ;; *) bad "g1: rc=$R $SM" ;; esac
case "$SM" in *binding_missing*) bad "g2: a re-verdicted conflict is still reported binding_missing: $SM" ;; *) ok "g2: once re-verdicted, the unit's own verdict gates it (no binding_missing)" ;; esac
bash "$S/write-unit-binding.sh" --cwd="$Gd" --vault="$Gd/.mega-sdd/vaults/leave" --unit=U-001 --resolve=C-U001-R1=KEEP_CODE --by=user >/dev/null 2>&1 || bad "g3: write-unit-binding --resolve failed"
R="$(val "$Gd" U-001)"; [ "$R" = 0 ] && ok "g3: human resolution of the re-verdicted claim (write-unit-binding --resolve --by=user) → PASS" || bad "g3: rc=$R $(summ "$Gd")"

# ── h: a linked claim that is still OQ is not a re-verdict ──
H="$T/h"; mkproj "$H" "$UNRESOLVED"; migrate "$H"
printf '\n## Claims\n- C-U001-R1 "the vault Product entity and the code Product class are the same concept (CONFLICT-1)" — expect: the App Models Product class is the vault Product entity\n' >> "$H/.mega-sdd/vaults/leave/units/U-001.md"
G "$H" add -A && G "$H" commit -qm "U-001 text claim"
rebind "$H" >/dev/null
R="$(val "$H" U-001)"; SM="$(summ "$H")"
case "$R|$SM" in "1|FAIL|"*"binding_missing:"*"CONFLICT-1"*) ok "h: linked claim still OQ (no ladder E3 verdict) → still FAIL binding_missing" ;; *) bad "h: rc=$R $SM" ;; esac

# ── i: a binding.json that is not the unit's own unit-binding/2 stamp is not a re-verdict ──
I="$T/i"; mkproj "$I" "$UNRESOLVED"; migrate "$I"
mkdir -p "$I/.mega-sdd/vaults/leave/bolts/U-001"
printf '{"schema":"unit-binding/2","unit":"U-009","claims":[{"id":"C-U001-R1","text":"CONFLICT-1","verdict":"CONFIRMED","anchor":"app/Models/Product.php"}]}\n' > "$I/.mega-sdd/vaults/leave/bolts/U-001/binding.json"
R="$(val "$I" U-001)"; SM="$(summ "$I")"
case "$R|$SM" in "1|FAIL|"*"binding_missing:"*"CONFLICT-1"*) ok "i: a binding.json stamped for another unit does not re-verdict U-001's CONFLICT-1" ;; *) bad "i: rc=$R $SM" ;; esac

# ── k: a ✅ added to binding-migrated.json AFTER the migration (its verbatim archived original
#       still records CONFLICT-1 open) is not a pre-migration human resolution ──
K="$T/k"; mkproj "$K" "$UNRESOLVED"; migrate "$K"; rebind "$K" >/dev/null
python3 - "$K/.mega-sdd/vaults/leave/bolts/U-001/binding-migrated.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
b = d["conflicts"][0]["block"]
d["conflicts"][0]["block"] = b.replace("### CONFLICT-1", "### ✅ CONFLICT-1 RESOLVED (KEEP_CODE)", 1) + "\n- **Resolution**: ✅ RESOLVED (KEEP_CODE)"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False)
PY
R="$(val "$K" U-001)"; SM="$(summ "$K")"
case "$R|$SM" in "1|FAIL|"*"binding_missing:"*"CONFLICT-1"*) ok "k: a ✅ only in the migrated copy (archived binding.md still open) does not open the gate" ;; *) bad "k: rc=$R $SM" ;; esac

# ── j: layout-3 happy path (plan-born, nothing migrated) ──
J="$T/j"; V="$J/.mega-sdd/vaults/web"; mkdir -p "$V/units" "$J/src"
printf 'export function Login() {}\n' > "$J/src/Login.tsx"
printf -- '---\nvault_layout: 3\n---\n# ctx\n\n## Flows\n\n## Data model\n\n## Constraints\n\n## Open Questions\n' > "$V/context.md"
printf -- '---\nid: U-001\ntitle: login\ntask_type: extend\ntarget_files:\n  - path: src/Login.tsx\n    operation: modify\nacceptance_test:\n  - type: test\n    command: npm test\n    expects: "ok"\n---\n# U-001\n' > "$V/units/U-001.md"
( cd "$J" && git init -q . ) && G "$J" add -A && G "$J" commit -qm seed
bash "$S/rebind-units.sh" --cwd="$J" --vault="$V" --units=all >/dev/null 2>&1
R="$(val "$J" U-001)"; SM="$(summ "$J")"
case "$R|$SM" in "0|PASS|"*) ok "j: layout-3 plan-born vault, re-bound, no CONFLICT → PASS" ;; *) bad "j: rc=$R $SM" ;; esac

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc

#!/usr/bin/env bash
# test-4f-recompute-batch.sh — tranche 4f (spec §Phase 4 "DESIGN 2026-08-01 (tranche 4f")
# The L3-5 memo was REJECTED; what shipped is BATCHING inside the B1 recompute:
#   4f-i  SIGNATURE decl lookups -> <=4 alternation greps per firing
#   4f-ii unit_text + DEPS blob reads + parent probes -> ONE cat-file --batch
# BEHAVIORAL proofs:
#   PARITY  gate-recomputed verdicts byte-identical to the solo writer engine
#           (same rules[], incl. SIGNATURE + manifest-touching DEPS), also in a
#           MONOREPO SUBDIR (PREFIX non-empty — the :./ vs explicit-path seam).
#   EXECS   recompute marginal cost is O(1) subprocesses, not O(rules): worst-v1
#           fixture delta <= 5 git (was ~4/unit).
#   MOAT    recompute_unit still runs UNCONDITIONALLY — a forged postflight.json
#           is overwritten on EVERY firing (no memo/skip path exists), and the
#           source carries no conditional around the recompute call.
# Run: bash tests/token-efficiency/test-4f-recompute-batch.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VBA="${ROOT}/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
PRE="${ROOT}/plugins/mega-sdd/scripts/run-preflight-scan.sh"
POST="${ROOT}/plugins/mega-sdd/scripts/run-postflight-scan.sh"
for f in "$VBA" "$PRE" "$POST"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkfix() { # dir n_units -> repo with SIGNATURE + manifest-touching DEPS + LOCK rules
  local R="$1" N="$2"
  mkdir -p "$R/.mega-sdd/vaults/v1/units" "$R/src"
  ( cd "$R" && git init -q . && git config user.email t@t && git config user.name t \
    && git config commit.gpgsign false )
  printf '{ "dependencies": { "a": "1" } }\n' > "$R/package.json"
  local i
  for i in $(seq 1 "$N"); do
    printf 'function fn%d(a,b){return a+b;}\n' "$i" > "$R/src/sig$i.js"
    printf 'lock-%d\n' "$i" > "$R/src/locked$i.js"
  done
  ( cd "$R" && git add -A && git commit -qm seed )
  for i in $(seq 1 "$N"); do
    local uid=U-$(printf %03d $i)
    { printf -- '---\nunit_id: %s\ntask_type: create\n---\n# %s\n\n## Hard rules\n\n' "$uid" "$uid"
      printf -- '- DO NOT modify src/locked%d.js\n- DO NOT add new package.json dependencies\n- function fn%d MUST preserve signature: (a,b)\n' "$i" "$i"
      printf '\n## Acceptance\n'; } > "$R/.mega-sdd/vaults/v1/units/$uid.md"
  done
  ( cd "$R" && git add -A && git commit -qm units )
  for i in $(seq 1 "$N"); do
    local uid=U-$(printf %03d $i)
    bash "$PRE" --cwd="$R" --unit="$uid" --quiet </dev/null >/dev/null 2>&1
    printf 'impl-%d\n' "$i" > "$R/src/impl$i.js"
    printf '{ "dependencies": { "a": "1" }, "x%d": 1 }\n' "$i" > "$R/package.json"
    ( cd "$R" && git add -A && git commit -qm "feat($uid): bolt" )
  done
}

rules_of() { # artifact -> stable JSON of rules[] (order + content)
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d["rules"],sort_keys=True))' "$1"
}

note "== PARITY: gate recompute (batched) == solo writer engine, per unit =="
R1="$WORK/p1"; mkfix "$R1" 3
# Round-1 ADV-006: cover pattern rounds 2/4, a prefix-pair (fn3/fn3Extra), and a
# name with NO declaration anywhere (must get the solo second opinion, ADV-003).
printf 'const fnArrow = (a,b) => a+b;\n' > "$R1/src/arrow.js"
printf 'class K { fn3Extra(a,b) { return a; } }\n' > "$R1/src/method.js"
( cd "$R1" && git add -A && git commit -qm decls )
{ printf -- '---\nunit_id: U-004\ntask_type: create\n---\n# U-004\n\n## Hard rules\n\n'
  printf -- '- function fnArrow MUST preserve signature: (a,b)\n- function fn3Extra MUST preserve signature: (a,b)\n- function fnGhost MUST preserve signature: (a,b)\n'
  printf '\n## Acceptance\n'; } > "$R1/.mega-sdd/vaults/v1/units/U-004.md"
( cd "$R1" && git add -A && git commit -qm u4 )
bash "$PRE" --cwd="$R1" --unit=U-004 --quiet </dev/null >/dev/null 2>&1 || true
printf 'i4\n' > "$R1/src/impl4.js"
( cd "$R1" && git add -A && git commit -qm "feat(U-004): bolt" )
# solo writer artifacts first (scan_unit with NO prefetch)
for i in 1 2 3 4; do bash "$POST" --cwd="$R1" --unit=U-$(printf %03d $i) --quiet </dev/null >/dev/null 2>&1; done
declare -a SOLO=()
for i in 1 2 3 4; do SOLO[$i]=$(rules_of "$R1/.mega-sdd/vaults/v1/bolts/U-$(printf %03d $i)/postflight.json"); done
# gate recompute OVERWRITES them via the batched prefetch path
bash "$VBA" --cwd="$R1" --postflight-scan --recompute --quiet </dev/null >/dev/null 2>&1
PAR=0
for i in 1 2 3 4; do
  G=$(rules_of "$R1/.mega-sdd/vaults/v1/bolts/U-$(printf %03d $i)/postflight.json")
  W=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["written_by"])' "$R1/.mega-sdd/vaults/v1/bolts/U-$(printf %03d $i)/postflight.json")
  [ "$W" = "validate-bolt-artifacts.sh --recompute" ] || { fail "U-00$i not overwritten by the gate (written_by=$W)"; PAR=1; }
  [ "${SOLO[$i]}" = "$G" ] || { fail "U-00$i rules[] diverged batched vs solo"; PAR=1; }
done
[ "$PAR" = "0" ] && ok "4 units (SIGNATURE incl. arrow/method rounds + prefix pair + ghost name, touched-DEPS, LOCK): batched recompute rules[] byte-identical to the solo writer engine, artifacts provably overwritten"
printf '%s' "${SOLO[4]}" | grep -q 'fnGhost' && printf '%s' "${SOLO[4]}" | grep -q 'not found in tracked source' \
  && ok "ghost SIGNATURE name verdicts identically on both engines (solo second opinion exercised)" || fail "ghost-name arm not exercised: ${SOLO[4]}"

note "== PARITY: monorepo subdir (PREFIX non-empty) — the :./ vs explicit-path seam =="
M="$WORK/mono"; mkdir -p "$M"
( cd "$M" && git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false && printf 'root\n' > root.txt && git add -A && git commit -qm root )
SUB="$M/apps/svc"; mkfix2() { :; }
mkdir -p "$SUB/.mega-sdd/vaults/v1/units" "$SUB/src"
printf '{ "dependencies": { "a": "1" } }\n' > "$SUB/package.json"
printf 'function subfn(a,b){return a;}\n' > "$SUB/src/sig.js"
( cd "$M" && git add -A && git commit -qm subseed )
{ printf -- '---\nunit_id: U-001\ntask_type: create\n---\n# U-001\n\n## Hard rules\n\n'
  printf -- '- DO NOT add new package.json dependencies\n- function subfn MUST preserve signature: (a,b)\n'
  printf '\n## Acceptance\n'; } > "$SUB/.mega-sdd/vaults/v1/units/U-001.md"
( cd "$M" && git add -A && git commit -qm units )
bash "$PRE" --cwd="$SUB" --unit=U-001 --quiet </dev/null >/dev/null 2>&1
printf '{ "dependencies": { "a": "1", "evil": "2" } }\n' > "$SUB/package.json"   # dep ADDED by the bolt
( cd "$M" && git add -A && git commit -qm "feat(U-001): bolt" )
bash "$POST" --cwd="$SUB" --unit=U-001 --quiet </dev/null >/dev/null 2>&1
SOLO_M=$(rules_of "$SUB/.mega-sdd/vaults/v1/bolts/U-001/postflight.json")
bash "$VBA" --cwd="$SUB" --postflight-scan --recompute --quiet </dev/null >/dev/null 2>&1
GATE_M=$(rules_of "$SUB/.mega-sdd/vaults/v1/bolts/U-001/postflight.json")
[ "$SOLO_M" = "$GATE_M" ] && ok "monorepo: batched recompute == solo engine (explicit PREFIX path resolved the same blob as :./)" || fail "monorepo parity diverged"
printf '%s' "$GATE_M" | grep -q 'NEW dependencies: evil' && printf '%s' "$GATE_M" | grep -q '"verdict": "fail"' \
  && ok "the added dep is still CAUGHT through the batched read (NEW dependency -> fail)" || fail "batched DEPS read missed the added dependency: $GATE_M"

note "== EXECS: recompute marginal cost is O(1), not O(rules) =="
R2="$WORK/e1"; mkfix "$R2" 10
SHIM="$WORK/shim"; CNT="$WORK/cnt"; mkdir -p "$SHIM" "$CNT"
REALGIT=$(command -v git)
printf '#!/bin/sh\necho g >> "%s/g"\nexec "%s" "$@"\n' "$CNT" "$REALGIT" > "$SHIM/git"
chmod +x "$SHIM/git"
: > "$CNT/g"; PATH="$SHIM:$PATH" bash "$VBA" --cwd="$R2" --postflight-scan --recompute --quiet </dev/null >/dev/null 2>&1
W=$(wc -l < "$CNT/g" | tr -d ' ')
: > "$CNT/g"; PATH="$SHIM:$PATH" bash "$VBA" --cwd="$R2" --postflight-scan --quiet </dev/null >/dev/null 2>&1
WO=$(wc -l < "$CNT/g" | tr -d ' ')
D=$((W - WO))
[ "$D" -le 5 ] && ok "10-unit worst-v1 fixture: recompute delta = $D git exec(s) (<=5; was ~4/unit pre-4f)" || fail "recompute delta $D git execs (want <=5) — batching regressed"

note "== MOAT: no memo — a forged artifact is overwritten on EVERY firing =="
FORGED="$R2/.mega-sdd/vaults/v1/bolts/U-001/postflight.json"
python3 -c 'import json,sys; json.dump({"unit_id":"U-001","status":"pass","written_by":"forged","rules":[{"type":"directive","rule":"x","verdict":"attested"}]}, open(sys.argv[1],"w"))' "$FORGED"
bash "$VBA" --cwd="$R2" --postflight-scan --recompute --quiet </dev/null >/dev/null 2>&1
W1=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["written_by"])' "$FORGED")
[ "$W1" = "validate-bolt-artifacts.sh --recompute" ] && ok "forged artifact overwritten from ground truth (firing 1)" || fail "forged artifact SURVIVED (written_by=$W1)"
python3 -c 'import json,sys; json.dump({"unit_id":"U-001","status":"pass","written_by":"forged2","rules":[]}, open(sys.argv[1],"w"))' "$FORGED"
bash "$VBA" --cwd="$R2" --postflight-scan --recompute --quiet </dev/null >/dev/null 2>&1
W2=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["written_by"])' "$FORGED")
[ "$W2" = "validate-bolt-artifacts.sh --recompute" ] && ok "re-forged artifact overwritten AGAIN on the very next firing (nothing carries across firings)" || fail "second forge survived a repeat firing"
# source pin: the recompute call is unconditional inside the obligated-unit branch
grep -q 'recompute_unit(uid, text)  # overwrite forged/stale evidence with ground truth' "$VBA" \
  && ok "source pin: recompute_unit call unchanged and unconditional" || fail "recompute_unit call site changed — verify no skip path was introduced"
# BEHAVIORAL kill-switch (round-1 ADV-007): with cat-file broken, the gate must
# still overwrite a forged artifact via the solo fallbacks — slower, never open.
KS="$WORK/ks"; mkdir -p "$KS"
REALGIT2=$(command -v git)
cat > "$KS/git" <<KSEOF
#!/bin/sh
for a in "\$@"; do [ "\$a" = "cat-file" ] && exit 128; done
exec "$REALGIT2" "\$@"
KSEOF
chmod +x "$KS/git"
python3 -c 'import json,sys; json.dump({"unit_id":"U-001","status":"pass","written_by":"forged3","rules":[{"type":"directive","rule":"x","verdict":"attested"}]}, open(sys.argv[1],"w"))' "$FORGED"
PATH="$KS:$PATH" bash "$VBA" --cwd="$R2" --postflight-scan --recompute --quiet </dev/null >/dev/null 2>&1
W3=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["written_by"])' "$FORGED")
[ "$W3" = "validate-bolt-artifacts.sh --recompute" ] && ok "cat-file kill-switch: forged artifact STILL overwritten via solo fallbacks (batch failure degrades, never opens)" || fail "forge survived under a broken cat-file (written_by=$W3)"
if grep -qE 'memo_(hit|valid)|skip_recompute|RECOMPUTE_MEMO' "$VBA"; then
  fail "memo/skip machinery detected in the validator — the L3-5 memo was REJECTED"
else
  ok "no memo/skip machinery in the validator (batching only)"
fi

if [ "$FAILED" -eq 0 ]; then note "ALL 4F RECOMPUTE-BATCH PROOFS OK"; else note "4f proofs FAILED"; fi
exit $FAILED

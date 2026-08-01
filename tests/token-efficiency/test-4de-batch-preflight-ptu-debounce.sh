#!/usr/bin/env bash
# test-4de-batch-preflight-ptu-debounce.sh — tranche 4, second release
# (spec 2026-07-30 §4d/§4e DESIGN 2026-08-01).
# BEHAVIORAL proofs:
#   4d-anchor   check-anchor-freshness.sh --units= batch: one call, every unit
#               verdicted, blocking units ALL listed, self-skip units pass
#               through, unknown unit fail-fast rc 2, --unit back-compat.
#   4d-preflight run-preflight-scan.sh --units= batch: N baselines from one
#               call (rule-set parity vs single-unit), FATAL fail-fast mid-
#               batch with the remainder named, exit-7 refusals collected
#               NON-fatally, re-batch idempotent.
#   4d-wiring   SKILL.md checks 3.7 + 4 instruct the batched form; the
#               postflight/acceptance writers did NOT gain a batch flag
#               (the L3-6 boundary).
#   4e          PostToolUse debounce: 4 project-wide scanners skipped on a
#               source-write firing with unchanged inputs (state-mtime proof);
#               re-run on a .mega-sdd write AND on HEAD move; the file-scoped
#               validators still fire on skipped firings; the dirty-journal
#               append + the Stop stamp do NOT defeat the skip; the debounce
#               does NOT defeat the 4c Stop skip (mutual-prune, both ways);
#               non-adopted project never mints .mega-sdd; absent stamp scans.
#
# Run: bash tests/token-efficiency/test-4de-batch-preflight-ptu-debounce.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ANC="${ROOT}/plugins/mega-sdd/scripts/check-anchor-freshness.sh"
PRE="${ROOT}/plugins/mega-sdd/scripts/run-preflight-scan.sh"
PTU="${ROOT}/plugins/mega-sdd/hooks/post-tool-use"
STP="${ROOT}/plugins/mega-sdd/hooks/stop"
SKILL="${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
for f in "$ANC" "$PRE" "$PTU" "$STP" "$SKILL"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkrepo() { # dir — seeded git repo with one vault
  mkdir -p "$1/.mega-sdd/vaults/v1/units" "$1/src"
  printf 'l1\nl2\nl3\n' > "$1/src/a.js"
  printf 'x\n' > "$1/src/locked.js"
  ( cd "$1" && git init -q . && git config user.email t@t && git config user.name t \
    && git config commit.gpgsign false && git add -A && git commit -qm seed ) >/dev/null 2>&1
}
mkunit() { # repo uid extra-md...
  local r="$1" uid="$2"; shift 2
  { printf -- '---\nunit_id: %s\ntask_type: create\n---\n# %s\n' "$uid" "$uid"
    printf '%s\n' "$@"; printf '\n## Acceptance\n'; } > "$r/.mega-sdd/vaults/v1/units/$uid.md"
}

note "== 4d-anchor. batch: every unit verdicted in ONE call =="
RA="$WORK/ra"; mkrepo "$RA"
mkunit "$RA" U-001 '' '## Anchors' '- src/a.js:2' '' '## Hard rules' '' '- DO NOT modify src/locked.js'
mkunit "$RA" U-002 ''   # no anchors, no rules
mkunit "$RA" U-003 '' '## Anchors' '- src/gone.js:9'
mkunit "$RA" U-004 '' '## Anchors' '- src/a.js:99'
OUT=$(bash "$ANC" --cwd="$RA" --units=U-001,U-002,U-003,U-004 </dev/null 2>&1); RC=$?
[ "$RC" = "1" ] && ok "batch with stale units exits 1" || fail "batch rc=$RC (want 1)"
printf '%s' "$OUT" | grep -q 'U-003' && printf '%s' "$OUT" | grep -q 'U-004' \
  && ok "BOTH blocking units listed in one output" || fail "not all blocking units listed"
printf '%s' "$OUT" | grep -q 'anchor-freshness U-001: 1 anchor(s) fresh' \
  && ok "fresh unit verdicted in the same call" || fail "fresh unit verdict missing"
printf '%s' "$OUT" | grep -q 'U-002: no ## Anchors' \
  && ok "anchor-less unit self-skips (controller passes the list unfiltered)" || fail "self-skip missing"
bash "$ANC" --cwd="$RA" --units=U-001,U-002 </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && ok "all-clean batch exits 0" || fail "clean batch rc=$RC"
bash "$ANC" --cwd="$RA" --units=U-001,U-999 </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "unknown unit in batch -> fail-fast rc 2 (controller bug, not a verdict)" || fail "unknown-unit rc=$RC"
bash "$ANC" --cwd="$RA" --unit=U-003 </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "1" ] && ok "--unit single form back-compatible (rc 1 on stale)" || fail "--unit back-compat rc=$RC"

note "== 4d-preflight. batch: N baselines, one call, parity vs single =="
RP="$WORK/rp"; mkrepo "$RP"
mkunit "$RP" U-001 '' '## Hard rules' '' '- DO NOT modify src/locked.js'
mkunit "$RP" U-002 ''   # no rules
mkunit "$RP" U-003 '' '## Hard rules' '' '- DO NOT modify src/a.js'
bash "$PRE" --cwd="$RP" --units=U-001,U-002,U-003 </dev/null >/dev/null 2>&1; RC=$?
B1="$RP/.mega-sdd/vaults/v1/bolts/U-001/preflight.json"
B3="$RP/.mega-sdd/vaults/v1/bolts/U-003/preflight.json"
[ "$RC" = "0" ] && [ -f "$B1" ] && [ -f "$B3" ] \
  && ok "one call wrote both Hard-rule baselines (rc 0)" || fail "batch write rc=$RC B1=$([ -f "$B1" ] && echo y || echo n) B3=$([ -f "$B3" ] && echo y || echo n)"
[ ! -e "$RP/.mega-sdd/vaults/v1/bolts/U-002/preflight.json" ] \
  && ok "no-rules unit produced NO artifact (never an empty baseline)" || fail "U-002 got an artifact"
# rule-set parity: batch-written baseline == single-unit rewrite (minus timestamp)
RULES_BATCH=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps({k:d[k] for k in ("unit_id","written_by","grammar","rules")},sort_keys=True))' "$B1")
bash "$PRE" --cwd="$RP" --unit=U-001 </dev/null >/dev/null 2>&1   # pre-commit re-capture (overwrite)
RULES_SINGLE=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps({k:d[k] for k in ("unit_id","written_by","grammar","rules")},sort_keys=True))' "$B1")
[ "$RULES_BATCH" = "$RULES_SINGLE" ] && ok "batch baseline rule-set byte-equal to the single-unit writer's" || fail "batch/single baseline diverged"

note "== 4d-preflight. FATAL fail-fast mid-batch + exit-7 collection =="
mkunit "$RP" U-004 '' '## Hard rules' '' '- frobnicate the wibble sideways'
OUT=$(bash "$PRE" --cwd="$RP" --units=U-001,U-004,U-003 </dev/null 2>&1); RC=$?
[ "$RC" = "3" ] && ok "unparseable unit mid-batch -> rc 3 (fail-fast)" || fail "fatal rc=$RC (want 3)"
printf '%s' "$OUT" | grep -q 'BATCH STOPPED at U-004' && printf '%s' "$OUT" | grep -q 'unprocessed unit(s): U-003' \
  && ok "offending unit + unprocessed remainder named (half-processed batch is visible)" || fail "remainder disclosure missing"
# exit-7: bolt U-001, drop its baseline, batch continues past the refusal
( cd "$RP" && git add .mega-sdd && git commit -qm 'feat(U-001): bolt' ) >/dev/null 2>&1
rm "$B1"; ( cd "$RP" && git add -u .mega-sdd && git commit -qm drop ) >/dev/null 2>&1
OUT=$(bash "$PRE" --cwd="$RP" --units=U-001,U-003 </dev/null 2>&1); RC=$?
[ "$RC" = "7" ] && ok "post-hoc refusal in batch -> final rc 7 (non-fatal contract kept)" || fail "refusal rc=$RC (want 7)"
printf '%s' "$OUT" | grep -q 'REFUSED (post-hoc): bolt commits already exist for U-001' \
  && ok "refused unit named on stderr" || fail "refusal not named"
printf '%s' "$OUT" | grep -q 'preflight U-003' && ok "batch CONTINUED past the refusal (U-003 processed)" || fail "batch stopped at the refusal"
OUT2=$(bash "$PRE" --cwd="$RP" --units=U-001,U-003 </dev/null 2>&1); RC2=$?
[ "$RC2" = "7" ] && ok "re-batching the same list is idempotent (same rc, no new writes forced)" || fail "re-batch rc=$RC2"

note "== 4d-wiring. controller + boundary pins =="
grep -q 'check-anchor-freshness.sh --cwd=<root> --units=' "$SKILL" \
  && ok "SKILL.md check 3.7 instructs the batched anchor call" || fail "3.7 not batched"
grep -q 'run-preflight-scan.sh --cwd=<root> --units=' "$SKILL" \
  && ok "SKILL.md check 4 instructs the batched preflight call" || fail "check 4 not batched"
if grep -qE -- '--units=' "${ROOT}/plugins/mega-sdd/scripts/run-postflight-scan.sh" "${ROOT}/plugins/mega-sdd/scripts/run-acceptance-tests.sh" 2>/dev/null; then
  fail "postflight/acceptance writer gained a batch flag (L3-6 forbids — defers the in-run STOP)"
else
  ok "postflight/acceptance writers stay single-unit (the L3-6 boundary)"
fi

note "== 4e. PostToolUse debounce: skip on source writes, rescan on real input change =="
PE="$WORK/pe"; mkrepo "$PE"
mkunit "$PE" U-001 ''
mkdir -p "$PE/.mega-sdd/codebase"
printf 'framework: laravel\n' > "$PE/.mega-sdd/codebase/codebase-map.md"   # mapped repo: dirty-journal active
( cd "$PE" && git add -A && git commit -qm map ) >/dev/null 2>&1
wfire() { # repo file — fire the hook as a Write PostToolUse
  python3 -c 'import json,sys; print(json.dumps({"session_id":"s4de","cwd":sys.argv[1],"tool_name":"Write","tool_input":{"file_path":sys.argv[2]}}))' "$1" "$2" \
    | bash "$PTU" >/dev/null 2>&1
}
mt() { python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns if os.path.exists(sys.argv[1]) else "absent")' "$1"; }
printf 'code\n' > "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"                      # firing 1: cold — scans + stamp
STAMP="$PE/.mega-sdd/.ptu-scan-stamp"
DSTATE="$PE/.mega-sdd/.bolt-artifacts-state.json"       # debounced scanner's state
FSTATE="$PE/.mega-sdd/.unit-spec-state.json"            # file-scoped (NOT debounced)
[ -f "$STAMP" ] && ok "stamp written after the cold firing (holds HEAD sha)" || fail "stamp missing after cold firing"
[ -f "$DSTATE" ] || note "  (note: bolt-artifacts state absent on this fixture — stamp mtime carries the skip proof)"
# The stamp is rewritten ONLY when the four scans ran — it is the ran/skip proof.
ST1=$(mt "$STAMP"); D1=$(mt "$DSTATE"); F1=$(mt "$FSTATE")
sleep 1
printf 'more\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"                      # firing 2: source write, inputs unchanged
ST2=$(mt "$STAMP"); D2=$(mt "$DSTATE"); F2=$(mt "$FSTATE")
[ "$ST1" = "$ST2" ] && [ "$D1" = "$D2" ] && ok "source-write firing SKIPPED the project-wide scanners (stamp + scanner state unchanged — dirty-journal append did not defeat it)" || fail "source write re-scanned (ST $ST1->$ST2, D $D1->$D2)"
if [ "$F1" != "absent" ]; then
  [ "$F1" != "$F2" ] && ok "file-scoped validator still fired on the skipped firing (unit-spec state refreshed)" || fail "file-scoped validator was debounced too"
fi
sleep 1
printf -- '- extra line\n' >> "$PE/.mega-sdd/vaults/v1/units/U-001.md"
wfire "$PE" "$PE/.mega-sdd/vaults/v1/units/U-001.md"    # firing 3: write INTO .mega-sdd
ST3=$(mt "$STAMP")
[ "$ST3" != "$ST2" ] && ok "write INTO .mega-sdd -> scans re-ran (stamp refreshed)" || fail "mega-sdd write did not re-scan"
sleep 1
( cd "$PE" && printf 'y\n' >> f2 && git add f2 && git commit -qm c2 ) >/dev/null 2>&1
printf 'z\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"                      # firing 4: HEAD moved
ST4=$(mt "$STAMP")
[ "$ST4" != "$ST3" ] && ok "HEAD moved -> scans re-ran on the next firing" || fail "HEAD move did not re-scan"
sleep 1
rm -f "$STAMP"
printf 'w\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"                      # firing 5: stamp absent
[ -f "$STAMP" ] && ok "absent stamp -> scanned and re-stamped (fail toward scanning)" || fail "absent stamp did not re-scan"

note "== 4e. mutual-prune: neither lane's outputs defeat the other =="
mkstdin_stop() { python3 -c 'import json,sys; print(json.dumps({"session_id":"s4de","cwd":sys.argv[1],"transcript_path":"","hook_event_name":"Stop","stop_hook_active":False}))' "$1"; }
mkstdin_stop "$PE" | bash "$STP" >/dev/null 2>&1        # Stop 1: scans + stop-stamp
SSTAMP="$PE/.mega-sdd/.stop-scan-stamp"
[ -f "$SSTAMP" ] || fail "stop stamp missing"
S1=$(mt "$SSTAMP")
sleep 1
# Direction 1 must be NON-vacuous (round-1 static finding 5): force the four
# project-wide scanners to genuinely RUN and rewrite their states, WITHOUT
# touching any real Stop-scan input — delete the ptu-stamp (fail toward
# scanning) and fire a plain source write.
rm -f "$STAMP"
D_PRE=$(mt "$DSTATE")
printf 'v\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"                      # PTU firing: scanners RUN (stamp absent)
D_POST=$(mt "$DSTATE")
if [ "$D_PRE" != "absent" ]; then
  [ "$D_PRE" != "$D_POST" ] && ok "forced PTU firing genuinely re-ran the project-wide scanners (state rewritten — direction-1 proof is live, not vacuous)" || fail "forced PTU firing did not rewrite the scanner state (direction-1 arm vacuous)"
fi
mkstdin_stop "$PE" | bash "$STP" >/dev/null 2>&1        # Stop 2: must STILL skip
S2=$(mt "$SSTAMP")
[ "$S1" = "$S2" ] && ok "PTU scanner-state rewrites + ptu-stamp do NOT defeat the 4c Stop skip (mutual prune, direction 1)" || fail "Stop re-scanned after a PTU scan firing"
sleep 1
P_BEFORE=$(mt "$STAMP")
printf 'u\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"                      # PTU firing after Stop wrote its stamp
P_AFTER=$(mt "$STAMP")
[ "$P_BEFORE" = "$P_AFTER" ] && ok "Stop stamp write does NOT defeat the PTU skip (mutual prune, direction 2)" || fail "PTU re-scanned after a Stop firing"

note "== 4e. legacy trees are probed (docs/mega-sdd + root *-bound) =="
sleep 1
mkdir -p "$PE/docs/mega-sdd/vaults/lv-bound/units"
printf 'legacy unit\n' > "$PE/docs/mega-sdd/vaults/lv-bound/units/U-900.md"
printf 't\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"
L1=$(mt "$STAMP")
[ "$L1" != "$P_AFTER" ] && ok "shell write under docs/mega-sdd -> next firing re-scanned" || fail "docs/mega-sdd change missed by the probe"
sleep 1
mkdir -p "$PE/x-bound/units"
printf 'legacy bound\n' > "$PE/x-bound/units/U-901.md"
printf 's\n' >> "$PE/src/b.js"
wfire "$PE" "$PE/src/b.js"
L2=$(mt "$STAMP")
[ "$L2" != "$L1" ] && ok "shell write under a root *-bound tree -> next firing re-scanned" || fail "root *-bound change missed by the probe"

note "== 4d/anchor-regex parity: builder copy pinned byte-identical =="
RE1=$(python3 -c 'import re,sys; s=open(sys.argv[1]).read(); m=re.search(r"TOKEN = re\.compile\(r\"([^\"]+)\"\)", s); print(m.group(1) if m else "MISS1")' "$ANC")
RE2=$(python3 -c 'import re,sys; s=open(sys.argv[1]).read(); m=re.search(r"ANCHOR_TOKEN_RE = re\.compile\(\s*r\"([^\"]+)\"", s); print(m.group(1) if m else "MISS2")' "${ROOT}/plugins/mega-sdd/scripts/build-dispatch-prompt.sh")
[ "$RE1" = "$RE2" ] && [ "$RE1" != "MISS1" ] \
  && ok "check-anchor-freshness TOKEN regex == build-dispatch-prompt ANCHOR_TOKEN_RE (the 'can never disagree' claim is now pinned, not prose)" || fail "anchor regex literals diverged (RE1=$RE1 RE2=$RE2)"

note "== 4e. non-adopted project: nothing minted =="
PN="$WORK/pn"; mkdir -p "$PN/src"
( cd "$PN" && git init -q . && git config user.email t@t && git config user.name t \
  && printf 'x\n' > src/a.js && git add -A && git commit -qm i ) >/dev/null 2>&1
wfire "$PN" "$PN/src/a.js"
[ ! -e "$PN/.mega-sdd" ] && ok "no .mega-sdd minted in a non-adopted project (EB-GATE-6 lesson holds)" || fail ".mega-sdd minted"

note "== 4e. guard surfaces: stamp registered everywhere =="
grep -q '"\.ptu-scan-stamp"' "${ROOT}/plugins/mega-sdd/hooks/pre-tool-use" \
  || grep -q '\.ptu-scan-stamp' "${ROOT}/plugins/mega-sdd/hooks/pre-tool-use" \
  && ok "pre-tool-use deny surfaces carry .ptu-scan-stamp" || fail "deny surface missing"
N_PROT=$(grep -c 'ptu-scan-stamp' "${ROOT}/plugins/mega-sdd/hooks/pre-tool-use")
[ "$N_PROT" -ge 3 ] && ok "Write/Edit tuple + both Bash PROTECTED regexes cover the stamp ($N_PROT sites)" || fail "only $N_PROT pre-tool-use sites"
grep -q '\.mega-sdd/\.ptu-scan-stamp' "${ROOT}/.gitignore" && ok ".gitignore covers the stamp" || fail ".gitignore missing"
grep -q 'ptu-scan-stamp' "${ROOT}/plugins/mega-sdd/references/paths.md" && ok "paths.md documents the stamp" || fail "paths.md missing"

if [ "$FAILED" -eq 0 ]; then note "ALL 4D/4E PROOFS OK"; else note "4d/4e proofs FAILED"; fi
exit $FAILED

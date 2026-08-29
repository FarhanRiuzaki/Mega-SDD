#!/usr/bin/env bash
# test-4abc-spawn-tax.sh — tranche 4, first release (spec 2026-07-30 §4a/4b/4c).
# BEHAVIORAL proofs:
#   4a-i  resolver cache: byte-parity cold→hit, ZERO python spawns on a hit
#         (PATH-shim proof), invalidation on every input class, existence-parity.
#   4a-ii composable scans: single-vs-multi rc parity on a real vault fixture,
#         all five state files from ONE invocation, call sites collapsed.
#   4c    Stop turn-gate: scans skipped when nothing changed (state mtime
#         proof), re-run on HEAD move AND on evidence-tree writes; the hook's
#         own debug-log append never defeats the skip (memory/ prune).
#   4b    the builtin cwd extraction matches the historical sed|head on a
#         hazard corpus (incl. Windows-escaped paths + embedded "cwd" decoys).
#
# Run: bash tests/token-efficiency/test-4abc-spawn-tax.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RES="${ROOT}/plugins/mega-sdd/scripts/_lib/resolve-framework-pack.sh"
VBA="${ROOT}/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
PTU="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
STP="${ROOT}/plugins/mega-sdd/hooks/stop"
for f in "$RES" "$VBA" "$PTU" "$STP"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

note "== 4a-i. resolver cache: cold->hit byte parity + zero-exec hit =="
P1="$WORK/p1"; mkdir -p "$P1/.mega-sdd/codebase"
printf 'framework: laravel\n' > "$P1/.mega-sdd/codebase/codebase-map.md"
# Cross a second boundary between the input write and the first (cold) resolve:
# bash -nt compares whole seconds, so a cache written in the input's own second
# never validates (the resolver's documented safe-direction miss) — the
# zero-exec-hit proof below needs cache strictly newer than the input.
sleep 1
A=$(bash "$RES" --cwd="$P1" --quiet); RA=$?
B=$(bash "$RES" --cwd="$P1" --quiet); RB=$?
[ "$A" = "$B" ] && [ "$RA" = "$RB" ] && [ "$RA" = "0" ] && ok "chain hit byte-identical (rc parity)" || fail "chain hit diverged"
S1=$(bash "$RES" --cwd="$P1" --section=naming --quiet); RS1=$?
S2=$(bash "$RES" --cwd="$P1" --section=naming --quiet); RS2=$?
[ "$S1" = "$S2" ] && [ "$RS1" = "$RS2" ] && ok "section hit byte-identical" || fail "section hit diverged"
bash "$RES" --cwd="$P1" --section=zzz-no-such-section --quiet >/dev/null 2>&1; RN1=$?
bash "$RES" --cwd="$P1" --section=zzz-no-such-section --quiet >/dev/null 2>&1; RN2=$?
[ "$RN1" = "3" ] && [ "$RN2" = "3" ] && ok "negative (rc 3) cached with rc parity" || fail "rc-3 negative cache broken ($RN1/$RN2)"
# ZERO python spawns on a hit — PATH shim spy
SHIM="$WORK/shim"; CNT="$WORK/cnt"; mkdir -p "$SHIM" "$CNT"
REALPY="$(command -v python3)"
printf '#!/bin/sh\necho 1 >> "%s/py"\nexec "%s" "$@"\n' "$CNT" "$REALPY" > "$SHIM/python3"
chmod +x "$SHIM/python3"
: > "$CNT/py"
OUTH=$(PATH="$SHIM:$PATH" bash "$RES" --cwd="$P1" --quiet); RH=$?
NPY=$(wc -l < "$CNT/py" | tr -d ' ')
[ "$NPY" = "0" ] && ok "hit path spawns ZERO pythons (spy shim untouched)" || fail "hit path spawned $NPY python(s)"
[ "$OUTH" = "$A" ] && [ "$RH" = "0" ] && ok "shimmed hit output still byte-identical" || fail "shimmed hit output diverged"

note "== 4a-i. invalidation: every input class busts the cache =="
sleep 1; touch "$P1/.mega-sdd/codebase/codebase-map.md"
: > "$CNT/py"
PATH="$SHIM:$PATH" bash "$RES" --cwd="$P1" --quiet >/dev/null 2>&1
NPY=$(wc -l < "$CNT/py" | tr -d ' ')
[ "$NPY" -ge 1 ] && ok "codebase-map touch -> cold re-resolve (python ran)" || fail "map touch did not invalidate"
sleep 1; touch "${ROOT}/plugins/mega-sdd/references/framework-conventions/laravel.md"
: > "$CNT/py"
PATH="$SHIM:$PATH" bash "$RES" --cwd="$P1" --quiet >/dev/null 2>&1
NPY=$(wc -l < "$CNT/py" | tr -d ' ')
[ "$NPY" -ge 1 ] && ok "chain pack-file touch -> cold re-resolve" || fail "pack touch did not invalidate"
C_BEFORE=$(bash "$RES" --cwd="$P1" --quiet)
rm "$P1/.mega-sdd/codebase/codebase-map.md"
C_AFTER=$(bash "$RES" --cwd="$P1" --quiet)
[ "$C_AFTER" = "_universal.md" ] && ok "input DELETION busts the cache (existence parity — resolution fell to _universal)" || fail "deleted input still served '$C_AFTER' (was '$C_BEFORE')"

note "== 4a-ii. composable scans: parity + one-call full state set =="
PV="$WORK/pv"; mkdir -p "$PV/.mega-sdd/vaults/v1/units" "$PV/.mega-sdd/vaults/v1/bolts"
printf -- '---\nid: U-001\n---\nx\n' > "$PV/.mega-sdd/vaults/v1/units/U-001.md"
(cd "$PV" && git init -q . && git config user.email t@t && git config user.name t \
  && git add -A && git commit -qm 'feat(U-001): bolt with no report (orphan bait)') >/dev/null 2>&1
# singles — the bolt-identity commit with NO bolt-report makes the orphan scan
# write a real FAIL state, so the parity below is proven on a NON-trivial verdict
declare -a RCS=()
for f in --orphan-scan --batch-suite-gate --postflight-scan --whitelist-scan --acceptance-scan; do
  bash "$VBA" --cwd="$PV" $f --quiet >/dev/null 2>&1; RCS+=($?)
done
MAXRC=0; for r in "${RCS[@]}"; do [ "$r" -gt "$MAXRC" ] && MAXRC=$r; done
S_STATES=$(ls -A "$PV/.mega-sdd/" | grep -c 'state.json' || true)
rm -f "$PV/.mega-sdd/".*-state.json 2>/dev/null
bash "$VBA" --cwd="$PV" --orphan-scan --batch-suite-gate --postflight-scan --whitelist-scan --acceptance-scan --quiet >/dev/null 2>&1; MRC=$?
M_STATES=$(ls -A "$PV/.mega-sdd/" | grep -c 'state.json' || true)
[ "$MRC" = "$MAXRC" ] && ok "multi rc ($MRC) == max of single rcs ($MAXRC)" || fail "multi rc $MRC != singles max $MAXRC"
[ "$M_STATES" = "$S_STATES" ] && [ "$M_STATES" -ge 1 ] && ok "one multi call writes the same state-file set as five singles ($M_STATES, non-empty)" || fail "state sets differ or empty: multi=$M_STATES singles=$S_STATES"

note "== 4a-ii. call sites collapsed =="
N_PTU=$(grep -c 'validate-bolt-artifacts.sh' "$PTU")
[ "$N_PTU" = "1" ] && ok "pre-tool-use: exactly ONE validate-bolt-artifacts invocation" || fail "pre-tool-use has $N_PTU invocations"
grep -q -- '--orphan-scan --batch-suite-gate --postflight-scan --recompute --whitelist-scan --acceptance-scan' "$PTU" \
  && ok "gate call carries all five scans + --recompute (B1 recompute-at-gate preserved)" || fail "gate flags wrong"
N_STP=$(grep -c 'bash "$VALIDATOR_OS"' "$STP")
[ "$N_STP" = "1" ] && ok "stop: exactly ONE validator invocation" || fail "stop has $N_STP invocations"
# 7.11.0: --panel-scan (F-07) joins both lanes — detection on Stop, gate at PreToolUse.
grep -q -- '--orphan-scan --batch-suite-gate --postflight-scan --whitelist-scan --acceptance-scan --panel-scan --quiet' "$STP" \
  && ok "stop call carries the six scans WITHOUT --recompute (read-only lane unchanged)" || fail "stop flags wrong"
if grep -q -- '--postflight-scan --recompute' "$STP"; then fail "stop gained --recompute (forbidden lane)"; else ok "no recompute on the Stop lane"; fi

note "== 4c. Stop turn-gate: skip/rescan semantics (state-mtime proof) =="
mkstdin() { python3 -c 'import json,sys; print(json.dumps({"session_id":"s4","cwd":sys.argv[1],"transcript_path":"","hook_event_name":"Stop","stop_hook_active":False}))' "$1"; }
PS="$WORK/ps"; mkdir -p "$PS/.mega-sdd/vaults/v1/units"
printf -- '---\nid: U-001\n---\nx\n' > "$PS/.mega-sdd/vaults/v1/units/U-001.md"
(cd "$PS" && git init -q . && git config user.email t@t && git config user.name t \
  && git add -A && git commit -qm i) >/dev/null 2>&1
mkstdin "$PS" | bash "$STP" >/dev/null 2>&1
STAMP="$PS/.mega-sdd/.stop-scan-stamp"
STATE="$PS/.mega-sdd/.bolt-orphans-state.json"
[ -f "$STAMP" ] && ok "stamp written after first Stop (holds HEAD sha)" || fail "stamp missing after first Stop"
[ -f "$STATE" ] || note "  (note: orphan state absent on this fixture — using stamp mtime for the skip proof)"
PROOF_FILE="$STATE"; [ -f "$PROOF_FILE" ] || PROOF_FILE="$STAMP"
T1=$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$PROOF_FILE")
sleep 1
mkstdin "$PS" | bash "$STP" >/dev/null 2>&1
T2=$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$PROOF_FILE")
[ "$T1" = "$T2" ] && ok "second Stop with NO changes: scans skipped (mtime unchanged — the hook's own debug-log append did not defeat the skip)" || fail "no-change turn re-scanned (T1=$T1 T2=$T2)"
sleep 1
(cd "$PS" && printf 'y\n' >> f2 && git add f2 && git commit -qm c2) >/dev/null 2>&1
mkstdin "$PS" | bash "$STP" >/dev/null 2>&1
T3=$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$PROOF_FILE")
[ "$T3" != "$T2" ] && ok "HEAD moved -> scans re-ran (stamp/state refreshed)" || fail "HEAD move did not re-scan"
sleep 1
printf 'evidence\n' > "$PS/.mega-sdd/vaults/v1/bolts-evidence.txt"
mkstdin "$PS" | bash "$STP" >/dev/null 2>&1
T4=$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$PROOF_FILE")
[ "$T4" != "$T3" ] && ok "evidence-tree write (no commit) -> scans re-ran (find -newer probe)" || fail "evidence write did not re-scan"

note "== 4c. telemetry-active project: auto-analyze outputs must NOT defeat the skip (round-1 F1) =="
PT="$WORK/pt"; mkdir -p "$PT/.mega-sdd/vaults/v1/units" "$PT/.mega-sdd/memory"
printf -- '---\nid: U-001\n---\nx\n' > "$PT/.mega-sdd/vaults/v1/units/U-001.md"
: > "$PT/.mega-sdd/memory/telemetry.jsonl"
(cd "$PT" && git init -q . && git config user.email t@t && git config user.name t \
  && git add -A && git commit -qm i) >/dev/null 2>&1
mkstdin2() { python3 -c 'import json,sys; print(json.dumps({"session_id":"s5","cwd":sys.argv[1],"transcript_path":"","hook_event_name":"Stop","stop_hook_active":False}))' "$1"; }
mkstdin2 "$PT" | bash "$STP" >/dev/null 2>&1   # run 1: scans + stamp + auto-analyze rewrites reports
STAMP2="$PT/.mega-sdd/.stop-scan-stamp"
[ -f "$STAMP2" ] || fail "telemetry fixture: stamp missing"
PROOF2="$STAMP2"
TT1=$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$PROOF2")
sleep 1
mkstdin2 "$PT" | bash "$STP" >/dev/null 2>&1   # run 2: analyze outputs newer than stamp — must STILL skip
TT2=$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$PROOF2")
[ "$TT1" = "$TT2" ] && ok "auto-analyze report rewrites are pruned from the probe — telemetry projects DO skip (the headline saving is real where it was claimed)" || fail "telemetry project never skips (analyze outputs defeat the gate)"

note "== 4b. builtin cwd extraction == historical sed|head on the hazard corpus =="
extract_sed() { printf '%s' "$1" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1; }
extract_builtin() {
  local rest="$1" out=""
  while [[ "$rest" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"(.*) ]]; do
    out="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
  done
  printf '%s' "$out"
}
CORPUS=(
  '{"session_id":"s","cwd":"/Users/me/proj","tool_name":"Bash"}'
  '{"session_id":"s","cwd":"C:\\Users\\me\\proj","tool_name":"Write"}'
  '{"cwd":"/a/b","tool_input":{"command":"grep \"cwd\": \"/decoy\" file"}}'
  '{"tool_input":{"command":"x"},"cwd":"/late/position"}'
  '{"cwd" :  "/spaced/form"}'
  '{"no_cwd_here":true}'
)
CP=0
for c in "${CORPUS[@]}"; do
  E1=$(extract_sed "$c"); E2=$(extract_builtin "$c")
  [ "$E1" = "$E2" ] || { fail "extractor divergence on: $c (sed='$E1' builtin='$E2')"; CP=1; }
done
[ "$CP" = "0" ] && ok "builtin last-match extraction == sed|head across the corpus (incl. Windows escapes + decoys)"
grep -q 'while \[\[ "\$SC_REST" =~' "$PTU" && ok "pre-tool-use ships the builtin loop extractor" || fail "builtin extractor not shipped"
grep -q "IFS= read -r -d '' STDIN_JSON" "$PTU" && grep -q "IFS= read -r -d '' STDIN_JSON" "$STP" \
  && ok "stdin read is a builtin in pre-tool-use + stop" || fail "builtin stdin read missing"

note "== SPEC: tranche-4 design + split rationale recorded =="
SPEC="${ROOT}/docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md"
grep -qF 'DESIGN 2026-08-01 (tranche 4, first release: 4a+4b+4c only)' "$SPEC" && ok "spec carries the design + the 4d/4e/4f deferral rationale" || fail "spec design missing"

if [ "$FAILED" -eq 0 ]; then note "ALL 4A/4B/4C SPAWN-TAX PROOFS OK"; else note "4abc proofs FAILED"; fi
exit $FAILED

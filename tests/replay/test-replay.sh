#!/usr/bin/env bash
# Fixture test for plugins/mega-sdd/scripts/replay.sh (audit batch E / finding F4).
# Builds a throwaway vault with bolt artifacts (bolt-report.md + postflight.json +
# preflight.json + a target file) and asserts the extracted replay logic:
#   A  first run = baseline (no prior) → exit 0
#   B  rerun on IDENTICAL state → no HIGH divergence → exit 0  (the honesty proof:
#      cosmetic timestamps are excluded, so two snapshots don't falsely diverge)
#   C  target-file content changed between runs → HIGH (live sha) → exit 1
#   D  --capture-only skips diff → exit 0 even when a prior exists
#   E  unknown unit → exit 2 ; unknown flag → exit 2
set -u
err=0

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/plugins/mega-sdd/scripts/replay.sh"
[ -f "$SCRIPT" ] || { echo "FATAL: script not found at $SCRIPT"; exit 1; }

# mk_fixture DIR — a project with one canonical vault + bolt artifacts for U-001,
# whose target_hashes match the seeded target file's real sha256.
mk_fixture() {
  local d="$1"
  local vault="$d/.mega-sdd/vaults/demo"
  local bolt="$vault/bolts/U-001"
  mkdir -p "$bolt" "$d/src"
  echo '{"vault_id":"demo"}' > "$vault/vault.json"
  printf 'original line\n' > "$d/src/Thing.php"
  local sha
  sha="$( (sha256sum "$d/src/Thing.php" 2>/dev/null || shasum -a 256 "$d/src/Thing.php") | awk '{print $1}')"
  cat > "$bolt/bolt-report.md" <<EOF
---
status: completed
target_hashes:
  src/Thing.php: $sha
---
# Bolt report U-001
EOF
  cat > "$bolt/postflight.json" <<'JSON'
{
  "unit_id": "U-001",
  "scanned_at": "2026-05-20T10:05:00Z",
  "status": "pass",
  "rules": [
    {"type": "DO_NOT_MODIFY", "path": "src/Thing.php", "verdict": "pass", "evidence": "sha256 unchanged"}
  ]
}
JSON
  cat > "$bolt/preflight.json" <<'JSON'
{ "unit_id": "U-001", "snapshot_at": "2026-05-20T10:00:00Z",
  "rules": [ {"type": "DO_NOT_MODIFY", "path": "src/Thing.php", "sha256": "seed"} ] }
JSON
}

# ---- Scenario A: first run = baseline (no prior) → exit 0 ----
A=$(mktemp -d); trap 'rm -rf "$A"' EXIT
mk_fixture "$A"
outA=$(bash "$SCRIPT" U-001 --cwd="$A" 2>&1); rcA=$?
[ $rcA -eq 0 ] || { echo "A: first run expected exit 0, got $rcA"; err=1; }
echo "$outA" | grep -qi 'baseline\|no prior' || { echo "A: first run not reported as baseline"; err=1; }
[ -n "$(find "$A/.mega-sdd/vaults/demo/.internal/replays" -name 'U-001-*.json' 2>/dev/null)" ] \
  || { echo "A: snapshot file not written"; err=1; }
[ $rcA -eq 0 ] && echo "A PASS (first run = baseline, exit 0)"

# ---- Scenario B: rerun on identical state → no HIGH divergence → exit 0 ----
# (different PID/timestamp per run; cosmetic captured_at must be excluded so the
#  two snapshots do NOT falsely diverge — the C6-style honesty proof.)
B=$(mktemp -d); trap 'rm -rf "$A" "$B"' EXIT
mk_fixture "$B"
bash "$SCRIPT" U-001 --cwd="$B" >/dev/null 2>&1            # baseline
outB=$(bash "$SCRIPT" U-001 --cwd="$B" 2>&1); rcB=$?       # second run, identical state
[ $rcB -eq 0 ] || { echo "B: identical rerun expected exit 0, got $rcB"; err=1; }
echo "$outB" | grep -qi 'REPRODUCIBLE' || { echo "B: identical rerun not REPRODUCIBLE"; err=1; }
echo "$outB" | grep -q '\[HIGH\] none' || { echo "B: identical rerun reported HIGH divergence (cosmetic leak?)"; err=1; }
[ $rcB -eq 0 ] && echo "B PASS (identical rerun → REPRODUCIBLE, exit 0)"

# ---- Scenario C: target file content changed → HIGH (live sha) → exit 1 ----
C=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C"' EXIT
mk_fixture "$C"
bash "$SCRIPT" U-001 --cwd="$C" >/dev/null 2>&1            # baseline
printf 'MUTATED line\n' > "$C/src/Thing.php"              # diverge the live file
outC=$(bash "$SCRIPT" U-001 --cwd="$C" 2>&1); rcC=$?
[ $rcC -eq 1 ] || { echo "C: changed target expected exit 1, got $rcC"; err=1; }
echo "$outC" | grep -qi 'REGRESSION' || { echo "C: changed target not flagged REGRESSION"; err=1; }
echo "$outC" | grep -q 'target_files.src/Thing.php' || { echo "C: HIGH entry missing the changed path"; err=1; }
echo "$outC" | grep -qi 'REGRESSION' && \
  [ -f "$C/.mega-sdd/vaults/demo/.internal/replays/U-001-divergence.json" ] \
  || { echo "C: divergence.json artifact (hand-off target) not written"; err=1; }
[ $rcC -eq 1 ] && echo "C PASS (changed target → HIGH/REGRESSION, exit 1; divergence.json written)"

# ---- Scenario C2: artifact-driven HIGH — postflight flip, live file UNCHANGED ----
# Isolates the artifact-reading path (vs C, which rides the live-file sha). The
# target file is untouched; only postflight.json status flips pass→fail.
C2=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$C2"' EXIT
mk_fixture "$C2"
bash "$SCRIPT" U-001 --cwd="$C2" >/dev/null 2>&1            # baseline (postflight pass)
pf="$C2/.mega-sdd/vaults/demo/bolts/U-001/postflight.json"
cat > "$pf" <<'JSON'
{ "unit_id": "U-001", "status": "fail",
  "rules": [ {"type":"DO_NOT_MODIFY","path":"src/Thing.php","verdict":"fail","evidence":"sha256 mismatch"} ] }
JSON
outC2=$(bash "$SCRIPT" U-001 --cwd="$C2" 2>&1); rcC2=$?
[ $rcC2 -eq 1 ] || { echo "C2: postflight flip expected exit 1, got $rcC2"; err=1; }
echo "$outC2" | grep -q 'postflight_status: pass -> fail' || { echo "C2: postflight flip not classified HIGH"; err=1; }
echo "$outC2" | grep -q 'hard_rule\[src/Thing.php\].verdict: pass -> fail' || { echo "C2: hard-rule verdict flip not classified HIGH"; err=1; }
[ $rcC2 -eq 1 ] && echo "C2 PASS (postflight/hard-rule flip → HIGH via artifact read, exit 1)"

# ---- Scenario D: --capture-only skips diff even when a prior exists → exit 0 ----
D=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$C2" "$D"' EXIT
mk_fixture "$D"
bash "$SCRIPT" U-001 --cwd="$D" >/dev/null 2>&1            # baseline
printf 'MUTATED\n' > "$D/src/Thing.php"                   # would be HIGH if diffed
outD=$(bash "$SCRIPT" U-001 --capture-only --cwd="$D" 2>&1); rcD=$?
[ $rcD -eq 0 ] || { echo "D: --capture-only expected exit 0, got $rcD"; err=1; }
echo "$outD" | grep -qi 'capture-only\|diff skipped' || { echo "D: --capture-only did not report skip"; err=1; }
echo "$outD" | grep -qi 'REGRESSION' && { echo "D: --capture-only ran the diff (should not)"; err=1; }
[ $rcD -eq 0 ] && echo "D PASS (--capture-only skips diff, exit 0)"

# ---- Scenario F: divergence.json must NOT be picked as a prior snapshot ----
# After a REGRESSION writes <unit>-divergence.json into the replays dir, the next
# run's prior-selection must still pick the latest real SNAPSHOT (not the diff
# artifact). The live file is unchanged between the regression run and this one,
# so it must classify REPRODUCIBLE — proving divergence.json was excluded.
F=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$C2" "$D" "$F"' EXIT
mk_fixture "$F"
bash "$SCRIPT" U-001 --cwd="$F" >/dev/null 2>&1            # baseline (live=original)
printf 'MUTATED line\n' > "$F/src/Thing.php"             # diverge
bash "$SCRIPT" U-001 --cwd="$F" >/dev/null 2>&1           # REGRESSION → writes divergence.json
[ -f "$F/.mega-sdd/vaults/demo/.internal/replays/U-001-divergence.json" ] \
  || { echo "F: setup — divergence.json not written by the regression run"; err=1; }
outF=$(bash "$SCRIPT" U-001 --cwd="$F" 2>&1); rcF=$?      # live UNCHANGED vs prior snapshot
[ $rcF -eq 0 ] || { echo "F: re-run after divergence expected exit 0 (got $rcF — divergence.json mis-selected as prior?)"; err=1; }
echo "$outF" | grep -qi 'REPRODUCIBLE' || { echo "F: re-run not REPRODUCIBLE (prior-selection swept in divergence.json)"; err=1; }
[ $rcF -eq 0 ] && echo "F PASS (divergence.json excluded from prior-snapshot selection)"

# ---- Scenario E: bad invocations → exit 2 ----
E=$(mktemp -d); trap 'rm -rf "$A" "$B" "$C" "$C2" "$D" "$F" "$E"' EXIT
mk_fixture "$E"
errE=0
bash "$SCRIPT" U-999 --cwd="$E" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "E: unknown unit expected exit 2"; errE=1; }
bash "$SCRIPT" U-001 --bogus --cwd="$E" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "E: unknown flag expected exit 2"; errE=1; }
bash "$SCRIPT" --cwd="$E" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "E: missing unit-id expected exit 2"; errE=1; }
[ $errE -eq 0 ] && echo "E PASS (unknown unit / unknown flag / missing positional → exit 2)" || err=1

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "ALL PASS" || echo "FAILED"
exit $err

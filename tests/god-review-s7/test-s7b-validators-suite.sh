#!/usr/bin/env bash
# test-s7b-validators-suite.sh — God-review S7 Batch B: validators + suite + secret-scan.
#
# Empirical fixtures reproducing the audit probes (archive ~/.mega-sdd/god-review-s7/
# scripts.md + panel.md §S7-GATES-1):
#   S7-B3-1 (HIGH)  whitelist suffix rules sanctioned DIFFERENT files → anchored match
#   S7-B3-2 (HIGH)  raw fnmatch * ate '/' (src/*.py blessed the subtree) → _glob_match
#   S7-SUITE-1 (HIGH) suite tested the TREE, artifact certified HEAD → dirty/moved refusal
#   S7-SUITE-2  --vault=<any-dir> wrote where the B2 reader never globs → substantive check
#   S7-SUITE-3  a code dir named *-bound was adopted as a vault (+ empty-repo green)
#   S7-SUITE-4  a stale RED in a secondary vault blocked B2 forever → freshness + all-vault write
#   S7-SUITE-5  --runner laundered any exit-0 command into suite evidence → override disclosed
#   S7-VAL-1    all gate modes dormant on legacy-layout projects (no .mega-sdd/)
#   S7-GATES-1 (HIGH) gitleaks runtime failure reported as a CLEAN secret scan
#   S7-SUITE-6/B1-1/VAL-2 (Lows, same files): write-fail exit contract, no-op Hard-rules
#   phrasing false-obligation, orphan walk window parity
#
# Run: bash tests/god-review-s7/test-s7b-validators-suite.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VBA="${ROOT}/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
RFS="${ROOT}/plugins/mega-sdd/scripts/run-full-suite.sh"
SSC="${ROOT}/plugins/mega-sdd/scripts/secret-scan.sh"
FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d 2>/dev/null || mktemp -d -t s7b)"
trap 'rm -rf "$W"' EXIT

echo "== S7-B: validators + suite + secret-scan =="

mkrepo() { # $1=dir
  mkdir -p "$1"
  ( cd "$1" && git init -q . && git config user.email t@t && git config user.name t )
}
unit() { # $1=repo $2=uid $3=target-path-lines (already "  - path: x" formatted)
  mkdir -p "$1/.mega-sdd/vaults/v1/units"
  printf -- '---\nunit_id: %s\ntask_type: create\ntarget_files:\n%s\n---\n# %s\n' "$2" "$3" "$2" \
    > "$1/.mega-sdd/vaults/v1/units/$2.md"
}

# ── B3: whitelist observer ──
R1="$W/b3"; mkrepo "$R1"
unit "$R1" U-001 '  - path: app/config.py'
unit "$R1" U-002 '  - path: src/*.py'
unit "$R1" U-003 '  - path: src/ok.py'
mkdir -p "$R1/app" "$R1/legacy/app" "$R1/src/a/b"
echo x > "$R1/app/config.py"
( cd "$R1" && git add -A && git commit -qm "chore: base" )

( cd "$R1" && echo y > legacy/app/config.py && git add -A && git commit -qm "feat(U-001): bolt" )
bash "$VBA" --cwd="$R1" --whitelist-scan --quiet </dev/null; RC=$?
grep -q 'legacy/app/config.py' "$R1/.mega-sdd/.bolt-whitelist-state.json" && [ "$RC" -ne 0 ] \
  && ok "B3-1: suffix escape legacy/app/config.py vs target app/config.py now FAILS" \
  || fail "B3-1: cross-path suffix escape still sanctioned (rc=$RC)"

( cd "$R1" && echo z > src/a/b/evil.py && git add -A && git commit -qm "feat(U-002): bolt" )
bash "$VBA" --cwd="$R1" --whitelist-scan --quiet </dev/null; RC=$?
grep -q 'src/a/b/evil.py' "$R1/.mega-sdd/.bolt-whitelist-state.json" && [ "$RC" -ne 0 ] \
  && ok "B3-2: src/*.py no longer sanctions the whole subtree (fnmatch '/'-eating closed)" \
  || fail "B3-2: subtree escape still sanctioned (rc=$RC)"

# in-scope commits still pass: exact target + segment-scoped glob
R2="$W/b3ok"; mkrepo "$R2"
unit "$R2" U-004 '  - path: app/config.py'
unit "$R2" U-005 '  - path: src/*.py'
mkdir -p "$R2/app" "$R2/src"
( cd "$R2" && git add -A && git commit -qm "chore: base" )
( cd "$R2" && echo a > app/config.py && git add -A && git commit -qm "feat(U-004): bolt" )
( cd "$R2" && echo b > src/ok.py && git add -A && git commit -qm "feat(U-005): bolt" )
bash "$VBA" --cwd="$R2" --whitelist-scan --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "B3: exact target + one-segment glob still PASS (no false-positives)" \
  || fail "B3: in-scope commits now false-fail: $(grep -o '"escaped_files[^]]*' "$R2/.mega-sdd/.bolt-whitelist-state.json" | head -1)"

# ── run-full-suite ──
R3="$W/suite"; mkrepo "$R3"
mkdir -p "$R3/.mega-sdd/vaults/v1/units" "$R3/.mega-sdd/vaults/v2/units" "$R3/src"
echo u > "$R3/.mega-sdd/vaults/v1/units/.keep"; echo u > "$R3/.mega-sdd/vaults/v2/units/.keep"
echo c > "$R3/src/app.py"
( cd "$R3" && git add -A && git commit -qm "chore: base" )

# SUITE-1: dirty CODE tree → refuse, nothing written
echo dirty >> "$R3/src/app.py"
bash "$RFS" --cwd="$R3" --runner=true --quiet </dev/null 2>"$W/.e1"; RC=$?
[ "$RC" -eq 2 ] && [ ! -f "$R3/.mega-sdd/vaults/v1/bolts/_batch-suite.json" ] && grep -q 'uncommitted code' "$W/.e1" \
  && ok "SUITE-1: dirty code tree REFUSED (rc=2, nothing written)" \
  || fail "SUITE-1: dirty tree still green-stamps HEAD (rc=$RC)"
( cd "$R3" && git checkout -q -- src/app.py )

# SUITE-1b: docs/state dirt is exempt (does not affect test outcomes)
echo note > "$R3/README.md"
bash "$RFS" --cwd="$R3" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "SUITE-1: pure-docs dirt exempt from the dirty check" \
  || fail "SUITE-1: docs dirt false-refuses the suite (rc=$RC)"
rm -f "$R3/README.md"

# multi-vault write (SUITE-4 remediation half)
[ -f "$R3/.mega-sdd/vaults/v1/bolts/_batch-suite.json" ] && [ -f "$R3/.mega-sdd/vaults/v2/bolts/_batch-suite.json" ] \
  && ok "SUITE-4: artifact written to EVERY discoverable vault (was: first only)" \
  || fail "SUITE-4: secondary vault not refreshed"

# SUITE-2: --vault=<existing non-vault dir> → exit 2, no litter
mkdir -p "$R3/lib"
bash "$RFS" --cwd="$R3" --vault=lib --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 2 ] && [ ! -d "$R3/lib/bolts" ] \
  && ok "SUITE-2: --vault=<non-vault dir> refused (was: exit 0 'recorded' where the reader never looks)" \
  || fail "SUITE-2: non-vault --vault still accepted (rc=$RC)"

# SUITE-3: a code dir named *-bound is NOT a vault; no vault at all → exit 2
R4="$W/cpubound"; mkrepo "$R4"
mkdir -p "$R4/cpu-bound"; echo c > "$R4/cpu-bound/calc.py"
( cd "$R4" && git add -A && git commit -qm "chore: base" )
bash "$RFS" --cwd="$R4" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 2 ] && [ ! -d "$R4/cpu-bound/bolts" ] \
  && ok "SUITE-3: cpu-bound/ code dir not adopted as a vault (no bolts/ litter, exit 2)" \
  || fail "SUITE-3: *-bound code dir still minted litter (rc=$RC)"

# SUITE-3b: empty repo (no commits) → exit 2, never a green artifact with empty head_sha
R5="$W/empty"; mkrepo "$R5"
mkdir -p "$R5/.mega-sdd/vaults/v1/units"
bash "$RFS" --cwd="$R5" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 2 ] && [ ! -f "$R5/.mega-sdd/vaults/v1/bolts/_batch-suite.json" ] \
  && ok "SUITE-3/6: unresolvable HEAD (empty repo) → exit 2, nothing written" \
  || fail "SUITE-3/6: empty repo still records a suite result (rc=$RC)"

# SUITE-5: explicit --runner differing from the detected runner → disclosed
R6="$W/override"; mkrepo "$R6"
mkdir -p "$R6/.mega-sdd/vaults/v1/units"
printf '{\n "scripts": {"test": "node test.js"}\n}\n' > "$R6/package.json"
( cd "$R6" && git add -A && git commit -qm "chore: base" )
bash "$RFS" --cwd="$R6" --runner=true --quiet </dev/null 2>"$W/.e5"; RC=$?
A6="$R6/.mega-sdd/vaults/v1/bolts/_batch-suite.json"
grep -q '"runner_overridden": true' "$A6" && grep -q 'detected_runner' "$A6" && grep -q 'WARN' "$W/.e5" \
  && ok "SUITE-5: --runner override recorded (runner_overridden + detected_runner) + WARNed" \
  || fail "SUITE-5: laundered runner still silent: $(head -c150 "$A6" 2>/dev/null)"

# SUITE-4: stale RED in a secondary vault must not block; a FRESH red must
R7="$W/red"; mkrepo "$R7"
mkdir -p "$R7/.mega-sdd/vaults/app/units" "$R7/.mega-sdd/vaults/old/units" "$R7/src"
echo c > "$R7/src/m.py"
( cd "$R7" && git add -A && git commit -qm "feat(U-010): bolt" )
OLD_SHA=$(git -C "$R7" rev-parse HEAD)
( cd "$R7" && echo c2 >> src/m.py && git add -A && git commit -qm "feat(U-011): bolt" )
NEW_SHA=$(git -C "$R7" rev-parse HEAD)
mkdir -p "$R7/.mega-sdd/vaults/app/bolts" "$R7/.mega-sdd/vaults/old/bolts"
printf '{"status":"green","head_sha":"%s","runner":"pytest","written_by":"run-full-suite.sh"}\n' "$NEW_SHA" > "$R7/.mega-sdd/vaults/app/bolts/_batch-suite.json"
printf '{"status":"red","head_sha":"%s","runner":"pytest","written_by":"run-full-suite.sh"}\n' "$OLD_SHA" > "$R7/.mega-sdd/vaults/old/bolts/_batch-suite.json"
bash "$VBA" --cwd="$R7" --batch-suite-gate --quiet </dev/null; RC=$?
if [ "$RC" -eq 0 ] && grep -q 'stale_reds' "$R7/.mega-sdd/.batch-suite-gate-state.json"; then
  ok "SUITE-4: stale red (old sha, secondary vault) superseded by fresh green — recorded, not blocking"
else
  fail "SUITE-4: stale red still permanently blocks (rc=$RC)"
fi
printf '{"status":"red","head_sha":"%s","runner":"pytest","written_by":"run-full-suite.sh"}\n' "$NEW_SHA" > "$R7/.mega-sdd/vaults/old/bolts/_batch-suite.json"
bash "$VBA" --cwd="$R7" --batch-suite-gate --quiet </dev/null; RC=$?
[ "$RC" -ne 0 ] && grep -q 'batch_suite_red' "$R7/.mega-sdd/.batch-suite-gate-state.json" \
  && ok "SUITE-4: a FRESH red (covers newest code) still blocks (fail-closed preserved)" \
  || fail "SUITE-4: fresh red no longer blocks (rc=$RC)"

# ── VAL-1: legacy layout (no .mega-sdd/) activates the gates ──
R8="$W/legacy"; mkrepo "$R8"
mkdir -p "$R8/docs/mega-sdd/vaults/v1/units" "$R8/src"
printf -- '---\nunit_id: U-101\ntask_type: create\n---\n# U-101\n' > "$R8/docs/mega-sdd/vaults/v1/units/U-101.md"
echo c > "$R8/src/x.py"
( cd "$R8" && git add -A && git commit -qm "feat(U-101): bolt" )
bash "$VBA" --cwd="$R8" --orphan-scan --quiet </dev/null; RC=$?
[ "$RC" -ne 0 ] && grep -q 'bolt_artifacts_missing' "$R8/.mega-sdd/.bolt-orphans-state.json" 2>/dev/null \
  && ok "VAL-1: legacy-layout project (no .mega-sdd/) now B-gated (orphan FAIL recorded)" \
  || fail "VAL-1: legacy layout still fails OPEN (rc=$RC, state: $(ls "$R8/.mega-sdd" 2>/dev/null | tr '\n' ' '))"
# and a plain non-mega-sdd repo still exits 0 with NO root minted (EB-GATE-6)
R9="$W/plain"; mkrepo "$R9"
echo c > "$R9/main.py"; ( cd "$R9" && git add -A && git commit -qm "feat: x" )
bash "$VBA" --cwd="$R9" --orphan-scan --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && [ ! -d "$R9/.mega-sdd" ] \
  && ok "VAL-1: non-mega-sdd repo untouched (no phantom .mega-sdd/ minted)" \
  || fail "VAL-1: root minted on a plain repo (rc=$RC)"

# ── B1-1: no-op Hard-rules phrasing incurs NO obligation ──
R10="$W/b11"; mkrepo "$R10"
mkdir -p "$R10/.mega-sdd/vaults/v1/units" "$R10/src"
printf -- '---\nunit_id: U-201\ntask_type: create\n---\n# U-201\n## Hard rules\nNone for this unit.\n' \
  > "$R10/.mega-sdd/vaults/v1/units/U-201.md"
echo c > "$R10/src/y.py"
( cd "$R10" && git add -A && git commit -qm "feat(U-201): bolt" )
bash "$VBA" --cwd="$R10" --postflight-scan --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "B1-1: 'None for this unit.' phrasing no longer mints a bogus B1 obligation" \
  || fail "B1-1: no-op phrasing still demands postflight evidence (rc=$RC)"

# ── GATES-1: gitleaks runtime failure falls back, never silent-clean ──
STUB="$W/stub"; mkdir -p "$STUB"
printf '#!/bin/sh\nexit 3\n' > "$STUB/gitleaks"; chmod +x "$STUB/gitleaks"
R11="$W/sec"; mkrepo "$R11"
echo "clean = 1" > "$R11/app.py"
( cd "$R11" && git add -A && git commit -qm "chore: base" )
B=$(git -C "$R11" rev-parse HEAD)
printf 'aws_key = "AKIAIOSFODNN7EXAMPLE"\n' >> "$R11/app.py"
( cd "$R11" && git add -A && git commit -qm "feat: leak" )
H=$(git -C "$R11" rev-parse HEAD)
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --code --base="$B" --head="$H" --cwd="$R11" 2>"$W/.e11"); RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'aws-access-key' && grep -q 'WARN: gitleaks runtime failure' "$W/.e11"; then
  ok "GATES-1: gitleaks crash (exit 3) → WARN + regex fallback CATCHES the planted key (was: silent clean)"
else
  fail "GATES-1: crashed gitleaks still reads as clean (rc=$RC): $(printf '%s' "$OUT" | head -c150)"
fi
# clean diff under a crashed gitleaks → exit 0 but the note discloses the fallback
( cd "$R11" && printf 'more = 2\n' > extra.py && git add -A && git commit -qm "feat: clean" )
H2=$(git -C "$R11" rev-parse HEAD)
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --code --base="$H" --head="$H2" --cwd="$R11" 2>/dev/null); RC=$?
[ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'runtime failure' \
  && ok "GATES-1: clean result under a crashed gitleaks DISCLOSES the fallback in the JSON note" \
  || fail "GATES-1: fallback not disclosed on the clean path (rc=$RC)"

# ── S7-B review round (r1/r2) probes ──

# r-1: monorepo — own .mega-sdd state litter + sibling dirt must NOT refuse the suite
RM="$W/mono"; mkrepo "$RM"
mkdir -p "$RM/sub/.mega-sdd/vaults/v1/units" "$RM/sub/src" "$RM/sibling"
echo c > "$RM/sub/src/app.py"; echo s > "$RM/sibling/other.py"
( cd "$RM" && git add -A && git commit -qm "chore: base" )
echo '{"x":1}' > "$RM/sub/.mega-sdd/.some-state.json"   # untracked hook-style state
echo dirt >> "$RM/sibling/other.py"                      # sibling-project dirt
bash "$RFS" --cwd="$RM/sub" --runner=true --quiet </dev/null 2>"$W/.em"; RC=$?
[ "$RC" -eq 0 ] && ok "r-1: monorepo — own state litter + sibling dirt exempt (no B2 deadlock)" \
  || fail "r-1: monorepo still refused (rc=$RC): $(tail -2 "$W/.em" | head -1)"
# but the subproject's OWN dirty code still refuses
echo dirt >> "$RM/sub/src/app.py"
bash "$RFS" --cwd="$RM/sub" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 2 ] && ok "r-1: the subproject's own dirty code still refuses" \
  || fail "r-1: prefix-strip over-exempts the project's own code (rc=$RC)"
( cd "$RM" && git checkout -q -- sub/src/app.py )

# r-2: dirty code in a dir merely NAMED *-bound must refuse (blanket exemption closed)
RB="$W/boundcode"; mkrepo "$RB"
mkdir -p "$RB/.mega-sdd/vaults/v1/units" "$RB/cpu-bound"
echo c > "$RB/cpu-bound/calc.py"
( cd "$RB" && git add -A && git commit -qm "chore: base" )
echo dirt >> "$RB/cpu-bound/calc.py"
bash "$RFS" --cwd="$RB" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 2 ] && ok "r-2: dirty cpu-bound/ CODE refuses (was: blanket *-bound exemption fail-open)" \
  || fail "r-2: *-bound code dirt still green-stamps HEAD (rc=$RC)"
( cd "$RB" && git checkout -q -- cpu-bound/calc.py )

# r-2: staged rename code→docs must refuse (both sides must be exempt)
mkdir -p "$RB/src"; echo m > "$RB/src/mod.py"
( cd "$RB" && git add -A && git commit -qm "chore: add mod" )
( cd "$RB" && git mv src/mod.py notes.md )
bash "$RFS" --cwd="$RB" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 2 ] && ok "r-2: staged rename src/mod.py -> notes.md refuses (rename dodge closed)" \
  || fail "r-2: rename-into-docs slips the dirty filter (rc=$RC)"
( cd "$RB" && git mv notes.md src/mod.py 2>/dev/null || true )

# r-3: untracked junk (.DS_Store, __pycache__) never refuses
touch "$RB/.DS_Store"; mkdir -p "$RB/__pycache__"; echo b > "$RB/__pycache__/m.pyc"
bash "$RFS" --cwd="$RB" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "r-3: untracked tool junk exempt (no permanent refusal loop)" \
  || fail "r-3: .DS_Store/__pycache__ still refuse the suite (rc=$RC)"

# r-4: default discovery also writes the NESTED */*-bound vault (reader parity)
RN="$W/nested"; mkrepo "$RN"
mkdir -p "$RN/.mega-sdd/vaults/v1/units" "$RN/backend/api-bound/units"
( cd "$RN" && git add -A && git commit -qm "chore: base" --allow-empty )
bash "$RFS" --cwd="$RN" --runner=true --quiet </dev/null 2>/dev/null; RC=$?
[ "$RC" -eq 0 ] && [ -f "$RN/backend/api-bound/bolts/_batch-suite.json" ] \
  && ok "r-4: nested */*-bound vault refreshed too (SUITE-4 loop closed for nested layouts)" \
  || fail "r-4: nested vault still unrefreshable (rc=$RC)"

# r-5: a ./-prefixed target declares the SAME file — must not false-block B3
RD="$W/dotslash"; mkrepo "$RD"
unit "$RD" U-006 '  - path: ./src/ok2.py'
mkdir -p "$RD/src"
( cd "$RD" && git add -A && git commit -qm "chore: base" )
( cd "$RD" && echo d > src/ok2.py && git add -A && git commit -qm "feat(U-006): bolt" )
bash "$VBA" --cwd="$RD" --whitelist-scan --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "r-5: ./-prefixed target sanctions the same file (no new false-block)" \
  || fail "r-5: ./src/ok2.py declaration false-blocks its own commit (rc=$RC)"

# r-6: node_modules/*-bound must not activate gates / mint .mega-sdd on a foreign repo
RF="$W/foreign"; mkrepo "$RF"
mkdir -p "$RF/node_modules/data-bound/bolts"
echo j > "$RF/index.js"
( cd "$RF" && git add -A && git commit -qm "feat: js" )
bash "$VBA" --cwd="$RF" --orphan-scan --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && [ ! -d "$RF/.mega-sdd" ] \
  && ok "r-6: node_modules/*-bound does not mint .mega-sdd on a foreign repo" \
  || fail "r-6: foreign repo minted (rc=$RC)"

# r-7: stale-red-only state is honest (no green anywhere)
RS="$W/staleonly"; mkrepo "$RS"
mkdir -p "$RS/.mega-sdd/vaults/v1/units" "$RS/src"
echo c > "$RS/src/m.py"
( cd "$RS" && git add -A && git commit -qm "feat(U-020): bolt" )
OLD2=$(git -C "$RS" rev-parse HEAD)
( cd "$RS" && echo c2 >> src/m.py && git add -A && git commit -qm "feat(U-021): bolt" )
mkdir -p "$RS/.mega-sdd/vaults/v1/bolts"
printf '{"status":"red","head_sha":"%s","written_by":"run-full-suite.sh"}\n' "$OLD2" > "$RS/.mega-sdd/vaults/v1/bolts/_batch-suite.json"
bash "$VBA" --cwd="$RS" --batch-suite-gate --quiet </dev/null; RC=$?
python3 -c "
import json; d=json.load(open('$RS/.mega-sdd/.batch-suite-gate-state.json'))
assert d['halt_type']=='batch_suite_gate_missing', d.get('halt_type')
assert d['stale_reds'], 'stale_reds missing'
assert 'STALE RED' in d['detail'], d['detail']
" && ok "r-7: stale-red-only case fails closed with HONEST detail + stale_reds recorded" \
  || fail "r-7: stale-red-only state still claims no artifact exists (rc=$RC)"

# ── pins ──
if grep -q 'walk_log(200)' "$VBA"; then fail "VAL-2: orphan scan still walks 200 while B1/B2/B3 walk 300"; else ok "VAL-2: one walk window (300) across all gate modes"; fi
if grep -qE 'p\.endswith\("/" \+ t\)|t\.endswith\("/" \+ p\)' "$VBA"; then fail "B3-1: suffix tolerances survive"; else ok "B3-1: suffix tolerances purged from the whitelist match"; fi
if grep -q 'fnmatch.fnmatch' "$VBA"; then fail "B3-2: raw fnmatch survives in B3"; else ok "B3-2: B3 uses the shared segment-scoped _glob_match"; fi

if [ "$FAILED" -eq 0 ]; then echo "ALL S7-B OK"; else echo "S7-B had failures"; fi
exit $FAILED

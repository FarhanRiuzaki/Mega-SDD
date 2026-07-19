#!/usr/bin/env bash
# test-certify-artifact.sh — P2 adoption gates (v4.94.0, spec
# 2026-07-19-v5-execution-spec.md P2 row + decision 7; research §3).
#
# Pins the adoption-certifier contract:
#   1. Per-rung fixture matrix — every rung answers with ONE verdict from the
#      closed vocabulary (CERTIFIED / CERTIFIED_DEGRADED / DEMOTE / REJECTED),
#      a keterangan block, and the contract exit code (0 / 0 / 3 / 4).
#   2. THE MIGRATION SWEEP — every v4-authored fixture artifact in the repo
#      test trees (sample-project vault+units+map+KB, graph fixtures, blackbox
#      fixture PRD) dropped through certify: NONE may return REJECTED
#      (binding migration guarantee; CERTIFIED_DEGRADED is the floor).
#   3. certify writes NOTHING into the artifact's project except the vault.json
#      that derive-vault-json legitimately derives (vault rung only).
#   4. Runtime: each rung completes < 2s.
#
# Run: bash plugins/mega-sdd/tests/state/test-certify-artifact.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
CA="${PLUGIN_ROOT}/scripts/certify-artifact.sh"
[ -f "$CA" ] || { echo "missing $CA"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p2cert)"
trap 'rm -rf "$WORK"' EXIT

# run_ca <rung> <path> [cwd] — captures OUT + RC + VERDICT word
run_ca() {
  local rung="$1" path="$2" cwd="${3:-$WORK}"
  OUT=$(bash "$CA" --cwd="$cwd" --rung="$rung" --path="$path" </dev/null 2>&1)
  RC=$?
  VERDICT=$(printf '%s\n' "$OUT" | sed -n 's/^VERDICT: \([A-Z_]*\) .*/\1/p' | head -n 1)
}

expect() { # $1=label $2=want_verdict $3=want_rc
  if [ "$VERDICT" = "$2" ] && [ "$RC" = "$3" ]; then
    ok "$1: $2 (rc=$3)"
  else
    fail "$1: expected $2/rc=$3, got '${VERDICT:-none}'/rc=$RC — $(printf '%s' "$OUT" | head -n 2 | tr '\n' ' ')"
  fi
}

expect_keterangan() { # $1=label $2=grep-F needle
  if printf '%s\n' "$OUT" | grep -q '^KETERANGAN:' && printf '%s\n' "$OUT" | grep -qF "$2"; then
    ok "$1: keterangan carries '$2'"
  else
    fail "$1: keterangan missing/lacks '$2'"
  fi
}

# ── fixtures ─────────────────────────────────────────────────────────────────
mkdir -p "$WORK"

# prd: real-PRD-shaped md (headings + AC patterns + length floor)
cat > "$WORK/real-prd.md" <<'MD'
# PRD — Appointment Booking

## 1. Goals
The clinic must let patients book, reschedule, and cancel appointments online.
The system shall enforce doctor availability windows and must prevent
double-booking of the same slot. Requirements below are scoped to phase one.

## 2. Requirements
- AC-1: a patient can book an open slot; the slot becomes reserved.
- AC-2: booking a reserved slot must fail with a clear message.
- AC-3: a patient should receive a confirmation with the booking reference.
- AC-4: staff can cancel a booking; the slot returns to open.
- As a patient I want reminders so that I do not miss my appointment.

## 3. Acceptance criteria
Every requirement above carries its acceptance criteria inline; user stories
must trace to a flow. Kebutuhan notifikasi (email vs SMS) masih open question
dan harus diputuskan stakeholder sebelum sprint dua dimulai. Scope catatan:
fitur pembayaran wajib keluar dari phase one.
MD

# prd: arbitrary md (no headings / no requirement signals)
printf 'catatan rapat kemarin.\nbeli kopi, follow up vendor.\n' > "$WORK/arbitrary.md"

# prd: binary file
printf 'PK\x03\x04\x00\x00BINARY\x00PAYLOAD\x01\x02' > "$WORK/blob.bin"

# map: external (7 sections, NO frontmatter) + degenerate
{ printf '# External Map\n'; for i in 1 2 3 4 5 6 7; do printf '## %d. Section %d\nrow content\n' "$i" "$i"; done; } > "$WORK/map-external.md"
printf '# my map\njust some notes, no sections\n' > "$WORK/map-degenerate.md"

# vault: graph derive-vault fixture (v4 grammar) copied — certify derives vault.json
cp -R "$PLUGIN_ROOT/tests/graph/fixtures/derive-vault" "$WORK/vault-v4"
rm -f "$WORK/vault-v4/vault.json"

# vault: foreign grammar (loose F- headings the shared grammar cannot parse →
# derive-vault-json exit 2, the adoption DEMOTE lane)
mkdir -p "$WORK/vault-foreign"
printf '# index\n' > "$WORK/vault-foreign/00-index.md"
printf '# Flows\n### F-001 checkout\nprose steps\n### F-002 refund\nprose\n### F-003 cancel\nprose\n' \
  > "$WORK/vault-foreign/04-flows.md"

# kb: foreign dir (markdown present, no mega-sdd KB structure)
mkdir -p "$WORK/kb-foreign/topics"
printf '# Payments domain\nnotes about payments\n' > "$WORK/kb-foreign/topics/payments.md"

# units: non-unit file
printf 'just prose, not a unit spec\n' > "$WORK/notunit.md"

SAMPLE="$ROOT/tests/fixtures/sample-project"

# ── 1. per-rung fixture matrix ───────────────────────────────────────────────
note "== 1. prd rung (shape sniffer — classifies, gates nothing) =="
run_ca prd "$WORK/real-prd.md"
expect "real-PRD-shaped md" CERTIFIED 0
expect_keterangan "real-PRD" "generate-intent"
run_ca prd "$WORK/arbitrary.md"
expect "arbitrary md (honest verdict)" CERTIFIED_DEGRADED 0
expect_keterangan "arbitrary md" "TIDAK berbentuk PRD"
run_ca prd "$WORK/blob.bin"
expect "binary file" REJECTED 4
expect_keterangan "binary" "biner"

note "== 2. map rung (validate-codebase-map outcomes) =="
run_ca map "$SAMPLE/.mega-sdd/codebase/codebase-map.md"
expect "mega-sdd-authored fixture map" CERTIFIED 0
run_ca map "$WORK/map-external.md"
expect "external map w/ sections, no FM" CERTIFIED_DEGRADED 0
expect_keterangan "external map" "unverified-external"
run_ca map "$WORK/map-degenerate.md"
expect "degenerate map" REJECTED 4
expect_keterangan "degenerate map" "scan-codebase"
printf '%s\n' "$OUT" | grep -qF 'DEMOTE' && ok "degenerate map: keterangan carries the DEMOTE offer" \
  || fail "degenerate map: DEMOTE offer missing"

note "== 3. vault rung (derive-vault-json outcomes) =="
run_ca vault "$WORK/vault-v4"
expect "graph fixture derive-vault vault" CERTIFIED 0
[ -f "$WORK/vault-v4/vault.json" ] && ok "vault.json now exists (the ONE legitimate write)" \
  || fail "vault.json not derived"
run_ca vault "$WORK/vault-foreign"
expect "foreign-grammar vault dir" DEMOTE 3
expect_keterangan "foreign vault" "grammar"
printf '%s\n' "$OUT" | grep -qF 'RE-INGEST' && ok "foreign vault: PRD-rung re-ingest offered" \
  || fail "foreign vault: re-ingest offer missing"
printf '%s\n' "$OUT" | grep -qF 'adoption_demote_confirm' && ok "foreign vault: names the C2 confirm halt (decision 7)" \
  || fail "foreign vault: C2 confirm not named"
[ -f "$WORK/vault-foreign/vault.json" ] && fail "foreign vault: vault.json written on DEMOTE (must not)" \
  || ok "foreign vault: nothing written on DEMOTE"

note "== 4. kb rung =="
run_ca kb "$WORK/kb-foreign"
expect "foreign-structure kb dir" DEMOTE 3
expect_keterangan "foreign kb" "RE-INGEST"

note "== 5. units rung (validate-unit-spec outcomes) =="
run_ca units "$SAMPLE/.mega-sdd/vaults/sample-vault-bound/units/U-002.md" "$SAMPLE"
expect "valid fixture unit" CERTIFIED 0
run_ca units "$WORK/notunit.md"
expect "non-unit file" REJECTED 4
expect_keterangan "non-unit" "frontmatter"

# ── 2. writes-nothing pin (reused validators land in scratch, not the project) ──
note "== 6. certify writes nothing into the artifact's project =="
STATE_BEFORE=$(cat "$SAMPLE/.mega-sdd/.unit-spec-state.json" 2>/dev/null | shasum | cut -d' ' -f1)
run_ca units "$SAMPLE/.mega-sdd/vaults/sample-vault-bound/units/U-001.md" "$SAMPLE"
STATE_AFTER=$(cat "$SAMPLE/.mega-sdd/.unit-spec-state.json" 2>/dev/null | shasum | cut -d' ' -f1)
[ "$STATE_BEFORE" = "$STATE_AFTER" ] && ok "project-wide .unit-spec-state.json untouched (gate state never clobbered)" \
  || fail "certify clobbered the project's .unit-spec-state.json"
MAP_STATE_BEFORE=$(cat "$SAMPLE/.mega-sdd/.codebase-map-state.json" 2>/dev/null | shasum | cut -d' ' -f1)
run_ca map "$SAMPLE/.mega-sdd/codebase/codebase-map.md" "$SAMPLE"
MAP_STATE_AFTER=$(cat "$SAMPLE/.mega-sdd/.codebase-map-state.json" 2>/dev/null | shasum | cut -d' ' -f1)
[ "$MAP_STATE_BEFORE" = "$MAP_STATE_AFTER" ] && ok ".codebase-map-state.json untouched" \
  || fail "certify clobbered the project's .codebase-map-state.json"

# ── 3. THE MIGRATION SWEEP: v4-authored fixtures are NEVER REJECTED ─────────
note "== 7. migration sweep (v4-authored artifacts: REJECTED forbidden) =="
sweep() { # $1=rung $2=path $3=label $4=cwd(optional)
  run_ca "$1" "$2" "${4:-$WORK}"
  if [ "$VERDICT" = "REJECTED" ] || [ "$RC" = "4" ] || [ "$RC" = "2" ]; then
    fail "sweep $3 ($1): got '${VERDICT:-none}'/rc=$RC — migration guarantee broken"
  else
    ok "sweep $3 ($1): $VERDICT (rc=$RC)"
  fi
}

# vault rung — copies (the vault rung legitimately derives vault.json)
cp -R "$PLUGIN_ROOT/tests/graph/fixtures/derive-vault" "$WORK/sweep-dv"
sweep vault "$WORK/sweep-dv" "graph derive-vault fixture"
cp -R "$SAMPLE/.mega-sdd/vaults/sample-vault" "$WORK/sweep-sv"
sweep vault "$WORK/sweep-sv" "sample-project sample-vault"

# map rung
sweep map "$SAMPLE/.mega-sdd/codebase/codebase-map.md" "sample-project codebase-map"

# units rung — every checked-in fixture unit
for u in "$SAMPLE"/.mega-sdd/vaults/sample-vault-bound/units/U-*.md \
         "$PLUGIN_ROOT"/tests/graph/fixtures/project/.mega-sdd/vaults/sample-vault/units/U-*.md; do
  [ -f "$u" ] || continue
  sweep units "$u" "$(basename "$(dirname "$(dirname "$u")")")/$(basename "$u")"
done

# kb rung
sweep kb "$SAMPLE/.mega-sdd/knowledge-base" "sample-project KB"
sweep kb "$PLUGIN_ROOT/tests/graph/fixtures/project/.mega-sdd/knowledge-base" "graph project KB"

# prd rung — blackbox fixture PRD (the checked-in blackbox input artifact)
sweep prd "$ROOT/tests/blackbox/fixture/docs/PRD-leave.md" "blackbox PRD-leave"

# ── 4. runtime bound ────────────────────────────────────────────────────────
note "== 8. runtime (<2s per rung) =="
for probe in "prd $WORK/real-prd.md" "map $SAMPLE/.mega-sdd/codebase/codebase-map.md" \
             "vault $WORK/sweep-dv" "kb $SAMPLE/.mega-sdd/knowledge-base" \
             "units $SAMPLE/.mega-sdd/vaults/sample-vault-bound/units/U-002.md"; do
  rung="${probe%% *}"; path="${probe#* }"
  start_ns=$(python3 -c 'import time; print(time.time_ns())')
  bash "$CA" --cwd="$WORK" --rung="$rung" --path="$path" </dev/null >/dev/null 2>&1
  end_ns=$(python3 -c 'import time; print(time.time_ns())')
  ms=$(( (end_ns - start_ns) / 1000000 ))
  [ "$ms" -lt 2000 ] && ok "rung $rung: ${ms}ms < 2000ms" || fail "rung $rung too slow: ${ms}ms"
done

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL P2 certify-artifact assertions PASS"; else note "P2 certify-artifact FAILURES"; fi
exit $FAILED

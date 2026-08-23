#!/usr/bin/env bash
# test-e-lean-profile.sh — tranche E (spec §Phase E "DESIGN 2026-08-02 (tranche E").
# The --lean profile is configuration over EXISTING levers:
#   ENGINE  profile probe (config.yaml) only — the --no-advisor hop transform
#           DIED with the phase-advisor's removal (v7.4.0) and must stay dead.
#   HOOK    Stop auto-analyze aggregate skipped under lean, runs otherwise.
#   MOAT    no gate/validator/deny path reads the profile (grep census); the
#           never-touch list is stated at the chain loop.
# Run: bash tests/token-efficiency/test-e-lean-profile.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
SP="${ROOT}/plugins/mega-sdd/scripts/_lib/state_probes.py"
STP="${ROOT}/plugins/mega-sdd/hooks/stop"
[ -f "$SP" ] && [ -f "$STP" ] || { echo "missing engine/hook"; exit 1; }
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkproj() { # dir profile-line
  local D="$1"; mkdir -p "$D/.mega-sdd/vaults/v1" "$D/src"
  ( cd "$D" && git init -q . && git config user.email t@t && git config user.name t )
  printf '{"project_name":"p"}\n' > "$D/.mega-sdd/vaults/v1/vault.json"
  printf '# O\n\n## Product\n\nX.\n' > "$D/.mega-sdd/vaults/v1/01-overview.md"
  [ -n "$2" ] && printf '%s\n' "$2" > "$D/.mega-sdd/config.yaml"
  ( cd "$D" && git add -A && git commit -qm i ) >/dev/null 2>&1
}

echo "== ENGINE: profile probe only — no hop transform (v7.4.0) =="
P1="$W/full"; mkproj "$P1" ""
P2="$W/lean"; mkproj "$P2" "profile: lean"
chain() { PYTHONPATH="${ROOT}/plugins/mega-sdd/scripts/_lib" python3 -c "
import json, sys, state_probes
pr = state_probes.collect_probes(sys.argv[1])
d = state_probes.derive(pr)
print(json.dumps({'profile': d.get('profile'), 'chain': d['proposed_next']}))
" "$1"; }
CF=$(chain "$P1"); CL=$(chain "$P2")
printf '%s' "$CF" | grep -q '"profile": "full"' && ok "full profile derived by default" || fail "default profile wrong: $CF"
printf '%s' "$CL" | grep -q '"profile": "lean"' && ok "lean profile read from config.yaml" || fail "lean not read: $CL"
if printf '%s' "$CF" | grep -q -- '--no-advisor'; then fail "full chain carries --no-advisor (the dead transform came back)"; else ok "full chain carries no --no-advisor"; fi
if printf '%s' "$CL" | grep -q -- '--no-advisor'; then fail "lean chain carries --no-advisor — the v7.4.0-removed transform regressed back in"; else ok "lean chain carries no --no-advisor (transform stays dead)"; fi

echo "== HOOK: Stop auto-analyze skipped under lean, runs otherwise =="
mkstop() { python3 -c 'import json,sys; print(json.dumps({"session_id":"sl","cwd":sys.argv[1],"transcript_path":"","hook_event_name":"Stop","stop_hook_active":False}))' "$1"; }
# a validator state file is the aggregate's trigger; fixture repos are foreign
# trees so this write is test-fixture state, not this repo's
seed_state() { printf '{"ts":"t","status":"PASS"}\n' > "$1/.mega-sdd/.unit-spec-state.json"; }
seed_state "$P1"; seed_state "$P2"
mkstop "$P1" | bash "$STP" >/dev/null 2>&1
mkstop "$P2" | bash "$STP" >/dev/null 2>&1
# P3 lean-by-default: ABSENT config = express spine = aggregate SKIPS (the
# opt-in is spine: classic | profile: full — proven in the P3 arms below).
if [ -f "$P1/.mega-sdd/.analyze-state.json" ] || [ -f "$P1/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  fail "P3: absent config fired the aggregate (lean-by-default regressed)"; else
  ok "P3: absent config skips the aggregate (lean-by-default)"; fi
if [ -f "$P2/.mega-sdd/.analyze-state.json" ] || [ -f "$P2/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  fail "lean: aggregate ran anyway"; else ok "lean: aggregate skipped"; fi

echo "== MOAT: no enforcement path reads the profile =="
if grep -qE "profile.*lean|lean.*profile" "${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"; then
  fail "pre-tool-use reads the profile"; else ok "pre-tool-use (every gate + deny surface) never reads the profile"; fi
if grep -lE "profile: *lean" "${ROOT}/plugins/mega-sdd/scripts/"validate-*.sh >/dev/null 2>&1; then
  fail "a validator reads the profile"; else ok "no validator reads the profile"; fi
grep -q 'Lean NEVER touches' "${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md" \
  && ok "never-touch list stated at the chain loop" || fail "never-touch list missing"
grep -qF 'review-panel risk tiering' "${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md" \
  && ok "panel tiering named in the never-touch list" || fail "tiering not named"
grep -qF 'hop transform died with the phase-advisor' "${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md" \
  && ok "routing-rules records the transform's death (one contract)" || fail "routing-rules death note missing"
grep -qF 'ADVISORY rows below' "${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md" \
  && ok "chain-execution scopes the diagnostic skip to advisory rows" || fail "chain-execution note missing"
grep -qF 'chain summary MUST name the profile' "${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md" \
  && ok "F5: summary-naming rule pinned in the SKILL prose" || fail "F5: summary-naming rule missing"
DIG=$(bash "${ROOT}/plugins/mega-sdd/scripts/derive-state.sh" --cwd="$P2" 2>/dev/null | head -1)
printf '%s' "$DIG" | grep -q 'profile=lean' && ok "F5: derive digest NAMES the lean profile" || fail "F5: digest missing profile ($DIG)"
DIGF=$(bash "${ROOT}/plugins/mega-sdd/scripts/derive-state.sh" --cwd="$P1" 2>/dev/null | head -1)
if printf '%s' "$DIGF" | grep -q 'profile='; then fail "F5: full digest carries a profile token (byte-stability broken)"; else ok "F5: full digest byte-stable (no profile token)"; fi
# F1: engine/hook config-parse PARITY on hostile spellings
PH="$W/hostile"; mkproj "$PH" "profile: leanish"
CH=$(chain "$PH")
printf '%s' "$CH" | grep -q '"profile": "full"' && ok "F1: 'leanish' rejected by the engine" || fail "F1 engine: $CH"
seed_state "$PH"
mkstop "$PH" | bash "$STP" >/dev/null 2>&1
# P3 lean-by-default: the aggregate is OPT-IN (spine: classic | profile: full).
# 'leanish' is neither — it behaves like ABSENT (skip), while the ENGINE still
# rejects it (profile stays full). The parity now proven: hostile spellings
# are never read as an explicit opt-in OR as lean.
if [ -f "$PH/.mega-sdd/.analyze-state.json" ] || [ -f "$PH/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  fail "F1/P3: 'leanish' fired the aggregate (must read as absent -> skip)"; else
  ok "F1/P3: hook — 'leanish' = absent = skip (aggregate is classic|full opt-in)"; fi
PF3="$W/optin-full"; mkproj "$PF3" "profile: full"
seed_state "$PF3"
mkstop "$PF3" | bash "$STP" >/dev/null 2>&1
if [ -f "$PF3/.mega-sdd/.analyze-state.json" ] || [ -f "$PF3/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  ok "P3: explicit profile: full fires the aggregate"; else fail "P3: profile: full did not fire"; fi
PC3="$W/optin-classic"; mkproj "$PC3" "spine: classic"
seed_state "$PC3"
mkstop "$PC3" | bash "$STP" >/dev/null 2>&1
if [ -f "$PC3/.mega-sdd/.analyze-state.json" ] || [ -f "$PC3/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  ok "P3: spine: classic fires the aggregate (classic keeps today's behavior)"; else fail "P3: classic did not fire"; fi
PCL="$W/classic-lean"; mkproj "$PCL" "$(printf 'spine: classic\nprofile: lean')"
seed_state "$PCL"
mkstop "$PCL" | bash "$STP" >/dev/null 2>&1
if [ -f "$PCL/.mega-sdd/.analyze-state.json" ] || [ -f "$PCL/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  fail "P3: classic+lean fired (lean must always win)"; else
  ok "P3: classic+lean skips (lean always wins)"; fi
PD="$W/dup"; mkproj "$PD" "$(printf 'profile: full\nprofile: lean')"
CD2=$(chain "$PD")
printf '%s' "$CD2" | grep -q '"profile": "full"' && ok "F1: duplicate keys — engine first-match wins (full)" || fail "F1 dup engine: $CD2"
seed_state "$PD"
mkstop "$PD" | bash "$STP" >/dev/null 2>&1
# duplicate keys: first line `profile: full` wins for the opt-in grep (-m1) —
# aggregate fires; the second `profile: lean` line is never reached.
if [ -f "$PD/.mega-sdd/.analyze-state.json" ] || [ -f "$PD/.mega-sdd/CONSISTENCY-REPORT.md" ]; then
  ok "F1: hook parity on duplicate keys — first profile line wins (full -> aggregate ran)"; else fail "F1 dup: hook read the SECOND profile line"; fi

[ "$FAILED" = "0" ] && echo "ALL E-LEAN PROOFS OK" || echo "E-lean proofs FAILED"
exit $FAILED

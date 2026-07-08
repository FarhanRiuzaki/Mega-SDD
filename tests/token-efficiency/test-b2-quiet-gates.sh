#!/usr/bin/env bash
# test-b2-quiet-gates.sh — token-efficiency Batch B2 (M-04 + M-05 + M-07).
# Pins the quiet-gates diet WITHOUT weakening any gate:
#
#   M-05a  run-postflight-scan.sh prints ONE line on pass; full artifact on fail;
#          artifact write + exit codes unchanged.
#   M-05b  per-bolt streaming is 2 lines (doc pin); stage detail → _summary.md.
#   M-05c  parent-thread re-scan + scorecard preflight invoke validators --quiet.
#   M-07a  GateGuard dedup is session-LIFETIME (an entry hours old still dedups
#          within the same session; a different session re-gates).
#   M-07b  a multi-gate failure deny carries EVERY gate's remediation.
#   M-04   per-hop handoff validation is ONE validate-handoff-yaml.sh call; the
#          orchestrator no longer loads handoff-contract.md to validate; the
#          contract's duplicated consumption loop is gone.
#
# Run: bash tests/token-efficiency/test-b2-quiet-gates.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
PF="${ROOT}/plugins/mega-sdd/scripts/run-postflight-scan.sh"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md"
HCON="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
HH="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/halts-and-handoff.md"
HRS="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/hard-rule-scan.md"
AMH="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md"
for f in "$PRE" "$PF" "$HC" "$HCON" "$HH" "$HRS" "$AMH"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t b2q)"
trap 'rm -rf "$WORK"' EXIT

drive_pre() { # $1=fixture $2=tool_name $3=tool_input-json
  HOOK="$PRE" FIX="$1" TOOL="$2" TI="$3" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "b2-session"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
'
}

note "== B2: quiet gates (M-04/M-05/M-07) =="

# ── M-05a: postflight one-line pass / full-dump fail (empirical) ──
F1="$WORK/pf"; mkdir -p "$F1/.mega-sdd/vaults/v1/units" "$F1/src"
( cd "$F1" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$F1/.mega-sdd/vaults/v1/units/U-001.md" <<'MD'
---
unit_id: U-001
task_type: create
---
# U-001
## Hard rules
- MUST keep src/a.txt ASCII-only
MD
echo hi > "$F1/src/a.txt"
( cd "$F1" && git add -A && git commit -qm "feat(U-001): bolt" )
OUT=$(cd "$F1" && bash "$PF" --cwd="$F1" --unit=U-001 --attest-directives="panel reviewed" 2>/dev/null); RC=$?
N_LINES=$(printf '%s\n' "$OUT" | grep -c .)
if [ "$RC" -eq 0 ] && [ "$N_LINES" -le 2 ] && echo "$OUT" | grep -q "postflight U-001: pass"; then
  ok "M-05a: PASS prints one line (rc=0), not the full rules[] dump"
else
  fail "M-05a: pass-path output wrong (rc=$RC lines=$N_LINES): $(echo "$OUT" | head -2)"
fi
[ -f "$F1/.mega-sdd/vaults/v1/bolts/U-001/postflight.json" ] && ok "M-05a: artifact still written on pass" || fail "M-05a: artifact missing"
# fail path: unattested directive → directive_unverified (non-pass)
OUT=$(cd "$F1" && bash "$PF" --cwd="$F1" --unit=U-001 2>/dev/null); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q '"rules"'; then
  ok "M-05a: FAIL still prints the full artifact (rules[] visible) + non-zero exit"
else
  fail "M-05a: fail-path regressed (rc=$RC): $(echo "$OUT" | head -2)"
fi

# ── M-07b: multi-gate deny carries every remediation (empirical, real hook) ──
F2="$WORK/multi"; mkdir -p "$F2/.mega-sdd/vaults/v1/units"
printf -- '---\nunit_id: U-001\n---\nbody\n' > "$F2/.mega-sdd/vaults/v1/units/U-001.md"
printf '%s' '{"status":"FAIL","issues_count":1,"issues":[{"unit_id":"U-001"}]}' > "$F2/.mega-sdd/.bolt-orphans-state.json"
printf '%s' '{"status":"FAIL","halt_type":"batch_suite_red","detail":"2 tests red"}' > "$F2/.mega-sdd/.batch-suite-gate-state.json"
OUT=$(drive_pre "$F2" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' || fail "M-07b: expected a deny"
echo "$OUT" | grep -q "(bolt-orphans)" && echo "$OUT" | grep -q "(batch-suite-gate)" \
  && ok "M-07b: ONE deny carries BOTH failing gates' remediations" \
  || fail "M-07b: deny missing a gate's remediation: ${OUT:0:200}"
echo "$OUT" | grep -q "2 execute-bolts gates are failing" && ok "M-07b: multi-fail prefix intact" || fail "M-07b: prefix lost"
# single-fail path unchanged
rm "$F2/.mega-sdd/.batch-suite-gate-state.json"
OUT=$(drive_pre "$F2" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ! echo "$OUT" | grep -q "|||" \
  && ok "M-07b: single-fail deny unchanged (no join separator)" || fail "M-07b: single-fail regressed"

# ── M-07a: GateGuard session-lifetime dedup (empirical) ──
F3="$WORK/gg"; mkdir -p "$F3/.mega-sdd/vaults/v1"
printf '%s' '# b' > "$F3/.mega-sdd/vaults/v1/binding.md"
printf '%s' '{"files": {"src/locked.php": ["binding.md C-001"]}}' > "$F3/.mega-sdd/.locked-files-index.json"
touch "$F3/.mega-sdd/.locked-files-index.json"
# entry investigated 3 HOURS ago in the SAME session → must still dedup (allow)
python3 - "$F3" <<'PY'
import json, sys, time
json.dump({"session_id": "b2-session", "entries": {"src/locked.php": time.time() - 10800}},
          open(sys.argv[1] + "/.mega-sdd/.gateguard-state.json", "w"))
PY
# keep the index older than binding? GateGuard lazily rebuilds if binding newer; make index newest
touch "$F3/.mega-sdd/.locked-files-index.json"
OUT=$(drive_pre "$F3" "Edit" "{\"file_path\": \"$F3/src/locked.php\"}")
echo "$OUT" | grep -q "GateGuard" && fail "M-07a: 3-hour-old same-session entry re-denied (expiry survives)" || ok "M-07a: same-session dedup is session-lifetime (no 30-min re-deny)"
# different session → first touch → deny once
python3 - "$F3" <<'PY'
import json, sys, time
json.dump({"session_id": "OTHER-session", "entries": {"src/locked.php": time.time() - 10800}},
          open(sys.argv[1] + "/.mega-sdd/.gateguard-state.json", "w"))
PY
OUT=$(drive_pre "$F3" "Edit" "{\"file_path\": \"$F3/src/locked.php\"}")
echo "$OUT" | grep -q "GateGuard" && ok "M-07a: a NEW session still gets the first-touch deny + prescription" || fail "M-07a: cross-session re-gate lost"

# ── M-07b: 3+ gate deny that overflows 2500 chars stays truncated + keeps the pointer ──
F4="$WORK/trunc"; mkdir -p "$F4/.mega-sdd/vaults/v1/units"; S4="$F4/.mega-sdd"
printf -- '---\nunit_id: U-001\n---\nbody\n' > "$F4/.mega-sdd/vaults/v1/units/U-001.md"
_orphan_issues() { python3 -c 'import json,sys; json.dump({"status":"FAIL","issues_count":8,"issues":[{"unit_id":"U-%s%02d"%(sys.argv[2],i)} for i in range(1,9)]}, open(sys.argv[1],"w"))' "$1" "$2"; }
_orphan_issues "$S4/.bolt-orphans-state.json" 1
_orphan_issues "$S4/.bolt-postflight-state.json" 2
_orphan_issues "$S4/.bolt-whitelist-state.json" 3
# batch-suite detail is inserted verbatim into the deny — pad it to force overflow
python3 -c 'import json,sys; json.dump({"status":"FAIL","halt_type":"batch_suite_red","detail":"tests red: "+"; ".join("suite_%02d::case_%02d failed with assertion mismatch"%(i,i) for i in range(18))}, open(sys.argv[1],"w"))' "$S4/.batch-suite-gate-state.json"
OUT=$(drive_pre "$F4" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
MSG=$(printf '%s' "$OUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("hookSpecificOutput",{}).get("permissionDecisionReason","") or d.get("permissionDecisionReason",""))')
if echo "$MSG" | grep -q "truncated" && echo "$MSG" | grep -qF "/mega-sdd:analyze" && echo "$MSG" | grep -q "gates are failing"; then
  ok "M-07b: overflow deny (>2500) stays truncated + keeps prefix + /mega-sdd:analyze pointer (len=${#MSG})"
else
  fail "M-07b: overflow deny lost truncation/pointer/prefix (len=${#MSG}): ${MSG:0:160}"
fi

# ── M-04: validate-handoff-yaml empirical cases (the B2 review High + the items_processed gap) ──
V="${ROOT}/plugins/mega-sdd/scripts/validate-handoff-yaml.sh"
VW="$WORK/vh"; mkdir -p "$VW/.mega-sdd"
_hstate() { python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print(s["status"], s["halt_type"], s["details"].get("conflicting_emitted_by"))' "$VW/.mega-sdd/.handoff-validation-state.json"; }
# (a) two handoff blocks with CONFLICTING emitted_by → FAIL handoff_missing (D3-001 re-close)
cat > "$VW/dual.md" <<'MD'
Quoting the upstream producer's handoff:
```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-07-07T09:00:00Z
  status: completed
  next_action: {type: proceed, hint: go}
```
My own emission:
```yaml
handoff:
  emitted_by: generate-units
  emitted_at: 2026-07-07T10:00:00Z
  status: completed
  next_action: {type: proceed, hint: go}
```
MD
bash "$V" --cwd="$VW" --response-file="$VW/dual.md" --skill-name=generate-units --quiet; RC=$?
read -r ST HT CF < <(_hstate)
if [ "$RC" -ne 0 ] && [ "$ST" = "FAIL" ] && [ "$HT" = "handoff_missing" ] && echo "$CF" | grep -q "bind-codebase"; then
  ok "M-04: dual CONFLICTING-emitter blocks FAIL handoff_missing (not a silent first-block PASS)"
else
  fail "M-04: conflicting dual-block not failed (rc=$RC status=$ST halt=$HT conflict=$CF)"
fi
# (b) two same-emitter blocks (quoted stale + corrected) → validate the LAST → PASS
cat > "$VW/dup.md" <<'MD'
```yaml
handoff:
  emitted_by: generate-units
  emitted_at: 2026-07-07T09:00:00Z
  status: halted
  next_action: {type: user_review, hint: stale}
```
Corrected re-emission:
```yaml
handoff:
  emitted_by: generate-units
  emitted_at: 2026-07-07T10:00:00Z
  status: completed
  next_action: {type: proceed, hint: go}
```
MD
bash "$V" --cwd="$VW" --response-file="$VW/dup.md" --skill-name=generate-units --quiet
[ $? -eq 0 ] && ok "M-04: same-emitter duplicate validates the producer's LAST block (PASS)" || fail "M-04: same-emitter dup wrongly failed"
# (c) metrics.items_processed non-int → handoff_type_mismatch (gates bolt_artifacts_missing)
cat > "$VW/ip.md" <<'MD'
```yaml
handoff:
  emitted_by: generate-units
  emitted_at: 2026-07-07T10:00:00Z
  status: completed
  next_action: {type: proceed, hint: go}
  metrics:
    items_processed: many
```
MD
bash "$V" --cwd="$VW" --response-file="$VW/ip.md" --skill-name=generate-units --quiet; RC=$?
read -r ST HT _ < <(_hstate)
if [ "$RC" -ne 0 ] && [ "$HT" = "handoff_type_mismatch" ]; then
  ok "M-04: metrics.items_processed non-int → handoff_type_mismatch (nested sub-field TYPE now checked)"
else
  fail "M-04: items_processed non-int not caught (rc=$RC halt=$HT)"
fi
# (d) items_processed with an inline "# comment" the no-deps parser leaves attached must
# NOT type-fail — the guard mirrors the downstream _items_processed() regex tolerance
cat > "$VW/ipc.md" <<'MD'
```yaml
handoff:
  emitted_by: generate-units
  emitted_at: 2026-07-07T10:00:00Z
  status: completed
  next_action: {type: proceed, hint: go}
  metrics:
    items_processed: 12    # units executed
```
MD
bash "$V" --cwd="$VW" --response-file="$VW/ipc.md" --skill-name=generate-units --quiet
[ $? -eq 0 ] && ok "M-04: items_processed with an inline # comment still parses (no false type-fail)" || fail "M-04: commented items_processed wrongly type-failed"

# ── M-04 + M-05b/c doc pins ──
grep -qF 'b.script — Deterministic per-hop gate (one call)' "$HC" && ok "M-04: per-hop gate is ONE validator call" || fail "M-04: b.script section missing"
grep -qF 'validate-handoff-yaml.sh' "$HC" && grep -qF 'ONLY on failure' "$HC" && ok "M-04: exit-code branch + state-read-on-FAIL pinned" || fail "M-04: invocation contract missing"
grep -qF 'does NOT load the handoff-contract reference to validate' "$HC" && ok "M-04: per-hop contract load retired" || fail "M-04: contract-load retirement missing"
if grep -qF 'Lookup TYPE annotation in handoff-contract.md' "$HC"; then fail "M-04: prose per-field TYPE lookup survives"; else ok "M-04: prose type-check loop gone"; fi
grep -qF 'lives ONCE in `references/handoff-consumption.md' "$HCON" && ok "M-04: contract's duplicated consumption loop collapsed to a pointer" || fail "M-04: contract loop dup survives"
grep -qiF 'confidence-aware auto-continue' "$HC" && ok "M-04: confidence floor survives in the operative loop" || fail "M-04: confidence floor lost"
grep -qF '## b.iv — Conditional fields (prose)' "$HC" && ok "M-04: b.iv conditional-presence check survives as prose (script gap)" || fail "M-04: b.iv lost"
grep -qF 'Per-bolt status is TWO lines' "$HH" && ok "M-05b: 2-line streaming pinned" || fail "M-05b: streaming diet missing"
if grep -qF 'Pre-flight: Hard Rules' "$HH"; then fail "M-05b: old 7-line block survives"; else ok "M-05b: old └─ block gone (detail → _summary.md)"; fi
grep -qF 'Never print a verified' "$HH" && ok "M-05b: anchors-honesty rail survives" || fail "M-05b: honesty rail lost"
grep -qF 'with `--quiet`, branching on the exit code' "$HRS" && ok "M-05c: parent-thread re-scan quieted" || fail "M-05c: re-scan still unquieted"
grep -qF -- '--quiet' "$AMH" && ok "M-05c: scorecard preflight quieted" || fail "M-05c: scorecard preflight still unquieted"

if [ "$FAILED" -eq 0 ]; then note "ALL B2 OK"; else note "B2 had failures"; fi
exit $FAILED

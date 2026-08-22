#!/usr/bin/env bash
# tests/blackbox/test-blackbox-pipeline.sh — BLACKBOX end-to-end proof.
#
# Drives the REAL shipped scripts in their real pipeline order against a
# synthetic leave-request mini-app, from empty legacy repo to READY TO SHIP.
# Model-written artifacts are SIMULATED per the current authoritative grammars
# (vault fixture = plugins/mega-sdd/tests/graph/fixtures/derive-vault, binding
# adapted from fixtures/derive-full). The proof is two-sided:
#   happy path  — every deriver/validator produces the real artifact chain;
#   gate firing — make-bound refuses on CONFLICT, preflight refuses a
#                 tamper-then-mint (exit 8), postflight catches a committed
#                 violation (MISMATCH), citation-map halts on a fabricated
#                 path, drift is detected on source change.
# Runs entirely in a mktemp workspace; never touches the repo.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PLG="$ROOT/plugins/mega-sdd"
SCR="$PLG/scripts"
FIX="$HERE/fixture"
GFIX="$PLG/tests/graph/fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()   { echo "  ok: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
stage(){ echo; echo "===== $1 ====="; }

PROJ="$WORK/leave-app"
VAULT="$PROJ/.mega-sdd/vaults/leave"

# ── S1 seed ──────────────────────────────────────────────────────────────────
stage "S1 seed: legacy repo"
mkdir -p "$PROJ"
cp -R "$FIX/src" "$PROJ/src"
cp -R "$FIX/docs" "$PROJ/docs"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email blackbox@test && git -C "$PROJ" config user.name blackbox
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "chore: legacy baseline"
[ -f "$PROJ/src/config/limits.php" ] && ok "legacy baseline committed" || bad "seed failed"

# ── S2 vault (model-sim) + real validators ───────────────────────────────────
stage "S2 vault write + validate-vault-flows/oqs"
mkdir -p "$VAULT"
cp "$GFIX/derive-vault/"*.md "$VAULT/"
OUT="$(bash "$SCR/validate-kb.sh" --surface=vault-flows --cwd="$PROJ" --file-path="$VAULT/04-flows.md" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "validate-vault-flows PASS" || bad "validate-vault-flows rc=$RC: $OUT"
OUT="$(bash "$SCR/validate-vault-oqs.sh" --cwd="$PROJ" --file-path="$VAULT/04-flows.md" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "validate-vault-oqs PASS" || bad "validate-vault-oqs rc=$RC: $OUT"

# ── S3 derive vault.json (+ idempotency) ─────────────────────────────────────
stage "S3 derive-vault-json (--patch) + idempotency"
cp "$GFIX/derive-vault/authored-patch.json" "$WORK/patch.json"
OUT="$(bash "$SCR/derive-vault-json.sh" --vault "$VAULT" --patch "$WORK/patch.json" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "derive rc=0: $OUT" || bad "derive rc=$RC: $OUT"
python3 - "$VAULT/vault.json" "$GFIX/derive-vault/expected-vault.json" <<'PY' && ok "structural counts match expected fixture" || bad "vault.json counts mismatch"
import json,sys
got=json.load(open(sys.argv[1])); exp=json.load(open(sys.argv[2]))
assert len(got["entities"])==len(exp["entities"]), (len(got["entities"]),len(exp["entities"]))
assert len(got["flows"])==len(exp["flows"])
assert len(got["open_questions"])==len(exp["open_questions"])
assert got["flows"][0]["id"].startswith("F-")
PY
cp "$VAULT/vault.json" "$WORK/v1.json"
bash "$SCR/derive-vault-json.sh" --vault "$VAULT" --patch "$WORK/patch.json" </dev/null >/dev/null 2>&1
cmp -s "$VAULT/vault.json" "$WORK/v1.json" && ok "re-derive byte-identical (generated_at preserved)" || bad "re-derive not idempotent"

# ── S4 consumer guide (v7: script demoted to the documented cp one-liner) ────
stage "S4 consumer guide cp"
SHIPPED="$PLG/skills/generate-intent/references/templates/ai-consumer-guide.md"
mkdir -p "$VAULT/_meta" && cp "$SHIPPED" "$VAULT/_meta/ai-consumer-guide.md"
if [ -f "$VAULT/_meta/ai-consumer-guide.md" ] \
   && [ "$(cksum < "$VAULT/_meta/ai-consumer-guide.md")" = "$(cksum < "$SHIPPED")" ]; then
  ok "guide installed via cp, cksum-identical to shipped template"
else bad "consumer guide cp failed"; fi

# ── S5 binding (model-sim, ACTIVE CONFLICT) + stamp + derive + parity ────────
stage "S5 binding write -> stamp -> derive -> parity"
write_binding() { # $1 = act (1: active conflict, 2: resolved/clean)
  local C050_VERDICT="CONFLICT" C050_HEAD="### CONFLICT-1 — product name collision"
  local RESLINE=""
  if [ "$1" = "2" ]; then
    C050_VERDICT="CONFIRMED"
    C050_HEAD="### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT — code update pending) — product name collision"
    RESLINE="- **Resolution**: ✅ RESOLVED (KEEP_VAULT) 2026-07-19 — vault correct; code change lands via U-001"
  fi
  cat > "$VAULT/binding.md" <<EOF
---
vault: leave
codebase_map: .mega-sdd/codebase/codebase-map.md
bound_at: 2026-07-19T00:00:00Z
strict: false
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: $(git -C "$PROJ" rev-parse HEAD)
---

# Binding Manifest

## Summary
- claims_total: 4
- confirmed: 2
- conflict: $([ "$1" = "1" ] && echo 1 || echo 0)
- oq: 1

## Confirmed Claims (2)
- C-001 | 03-data-model.md:7 | src/models/LeaveRequest.php:3 | LeaveRequest entity exists
- C-044 | 04-flows.md:12 | src/services/ApprovalService.php:9 | approval flow exists

## Implementation State Map (4 — ALWAYS 6 columns; the Field diff cell is \`n/a\` unless precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | src/models/LeaveRequest.php:3 | high | (exact match) |
| C-012 | OQ | NEW | — | n/a | n/a |
| C-044 | CONFIRMED | UNKNOWN | truncated §4 — absence is not evidence (map capped) [reason: truncated_section] | low | n/a |
| C-050 | $C050_VERDICT | UNKNOWN | src/models/Employee.php:3 | medium | n/a |

## Conflicts ($([ "$1" = "1" ] && echo "1) — BLOCKING" || echo "0)"))

$C050_HEAD
- **Claim**: C-050
- **Vault claim**: vault Employee entity owns the role enum (03-data-model.md §Employee)
- **Codebase reality**: pre-existing Employee model already defines role (src/models/Employee.php:3)
- **conflict_class**: naming-collision
- **resolution_complexity**: low
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT — vault Employee is the target entity (src/models/Employee.php:3)
$RESLINE

## Open Questions (1)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | which notification channel? | 04-flows.md:39 | N/A (fresh OQ) |
EOF
}
write_binding 1
OUT="$(bash "$SCR/derive-binding-json.sh" --vault "$VAULT" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "derive (phase-0 stamp) rc=0" || bad "derive/stamp rc=$RC: $OUT"
grep -q "REGENERATED by bind-codebase" "$VAULT/binding.md" && ok "banner stamped" || bad "banner missing"
G=0; for g in KEEP_VAULT KEEP_CODE DEFER SPLIT; do grep -q "$g = " "$VAULT/binding.md" && G=$((G+1)); done
[ $G -eq 4 ] && ok "all 4 keterangan glosses present in artifact" || bad "glosses missing ($G/4)"
OUT="$(bash "$SCR/derive-binding-json.sh" --vault "$VAULT" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "derive-binding-json re-run rc=0 (stamp idempotent)" || bad "derive-binding-json rc=$RC: $OUT"
OUT="$(bash "$SCR/validate-binding-json.sh" --vault "$VAULT" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "parity gate PASS" || bad "parity rc=$RC: $OUT"

# ── S6 CONFLICT gate LIVE: refuse, resolve, produce ──────────────────────────
stage "S6 make-bound: refusal on CONFLICT, then clean production"
OUT="$(bash "$SCR/make-bound.sh" --vault "$VAULT" </dev/null 2>&1)"; RC=$?
if [ $RC -eq 2 ] && [ ! -d "$VAULT/bound" ]; then
  ok "GATE FIRED: make-bound refused (exit 2), no bound/ — $(echo "$OUT" | head -1)"
else bad "expected refusal, rc=$RC bound=$([ -d "$VAULT/bound" ] && echo yes || echo no): $OUT"; fi
write_binding 2
bash "$SCR/derive-binding-json.sh" --vault "$VAULT" </dev/null >/dev/null 2>&1
OUT="$(bash "$SCR/make-bound.sh" --vault "$VAULT" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && [ -d "$VAULT/bound" ] && ok "clean re-bind produced bound/: $OUT" || bad "make-bound rc=$RC: $OUT"
cmp -s "$VAULT/binding.md" "$VAULT/bound/binding.md" && ok "bound/binding.md mirror byte-identical" || bad "mirror differs"
grep -q "<!-- BIND: " "$VAULT/bound/04-flows.md" && ok "BIND annotations injected from binding.json" || bad "annotations missing"

# ── S7 bind event into vault.json ────────────────────────────────────────────
stage "S7 derive-vault-json --event bind"
OUT="$(bash "$SCR/derive-vault-json.sh" --vault "$VAULT" --event '{"event":"bind","summary":"blackbox clean bind"}' </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "event derive rc=0" || bad "event rc=$RC: $OUT"
python3 -c "import json,sys; v=json.load(open(sys.argv[1])); assert any('bind' in json.dumps(e) for e in v.get('changelog',[])), v.get('changelog')" "$VAULT/vault.json" \
  && ok "changelog carries the bind event" || bad "changelog event missing"

# ── S8 unit (model-sim, post-P3 schema) ──────────────────────────────────────
stage "S8 unit write + validate-unit-spec"
mkdir -p "$VAULT/units"
cat > "$VAULT/units/U-001.md" <<'EOF'
---
id: U-001
title: Approval endpoint wiring
vault_source: 04-flows.md:F-U-001
task_type: extend
binding_refs:
  - C-044
target_files:
  - path: src/services/ApprovalService.php
    operation: edit
  - path: src/routes.php
    operation: create
acceptance_test:
  - type: test
    command: "php -l src/routes.php"
    expects: "No syntax errors"
mutability: "INTENT — approval flow shape follows PRD §3.2 (maker-checker)"
---

## Goal
Wire the approval flow route to ApprovalService per vault 04-flows.md F-U-001.

## Context (read first)
Per binding C-044 the approval flow exists in ApprovalService; this unit adds the route wiring only.

## Anchors
- src/services/ApprovalService.php:9 — approveRequest (binding C-044)

## Hard rules
- DO NOT modify src/config/limits.php
  Source: binding C-044 — policy constants frozen per PRD §3.2
- function approveRequest MUST preserve signature: public function approveRequest(int $requestId, int $approverId, string $note): bool
  Source: binding C-044 anchor src/services/ApprovalService.php:9

## Anti-patterns
- Don't bypass the maker-checker role check.

## Implementation steps
Create src/routes.php exposing POST /leave/approve calling ApprovalService::approveRequest. Do not touch policy limits.

## Migration notes
- ADD: src/routes.php exposing POST /leave/approve (new file, this unit).
- KEEP: ApprovalService::approveRequest contract as-is (src/services/ApprovalService.php:9, binding C-044); src/config/limits.php untouched.
- REMOVE: nothing — routing is additive.

## Acceptance criteria
See frontmatter `acceptance_test` (structured authority).
EOF
OUT="$(bash "$SCR/validate-unit-spec.sh" --cwd="$PROJ" --file-path="$VAULT/units/U-001.md" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "validate-unit-spec PASS" || bad "unit spec rc=$RC: $OUT"

# ── S9 B1 baseline + tamper-then-mint refusal ────────────────────────────────
stage "S9 preflight baseline + GATE: tamper-then-mint refused"
OUT="$(bash "$SCR/run-preflight-scan.sh" --cwd="$PROJ" --unit=U-001 </dev/null 2>&1)"; RC=$?
PF="$VAULT/bolts/U-001/preflight.json"
[ $RC -eq 0 ] && [ -f "$PF" ] && ok "baseline minted: $OUT" || bad "preflight rc=$RC: $OUT"
python3 -c "
import json,sys; p=json.load(open(sys.argv[1]))
types={r['type'] for r in p['rules']}
assert 'DO_NOT_MODIFY' in types and 'SIGNATURE_RULE' in types, types
assert p.get('written_by')" "$PF" && ok "baseline carries DO_NOT_MODIFY sha + signature snapshot" || bad "baseline schema wrong"
sed -i.bak "s/'max_carryover_days'   => 5/'max_carryover_days'   => 99/" "$PROJ/src/config/limits.php"
cp "$VAULT/units/U-001.md" "$VAULT/units/U-002.md"
sed -i.bak 's/id: U-001/id: U-002/; s/Approval endpoint wiring/Second unit/' "$VAULT/units/U-002.md"; rm -f "$VAULT/units/U-002.md.bak"
OUT="$(bash "$SCR/run-preflight-scan.sh" --cwd="$PROJ" --unit=U-002 </dev/null 2>&1)"; RC=$?
if [ $RC -eq 8 ] && [ ! -f "$VAULT/bolts/U-002/preflight.json" ]; then
  ok "GATE FIRED: tamper-then-mint refused (exit 8, no artifact) — $(echo "$OUT" | tail -1)"
else bad "expected exit 8, rc=$RC: $OUT"; fi
mv "$PROJ/src/config/limits.php.bak" "$PROJ/src/config/limits.php"

# ── S10 bolt sim: honest pass, violation caught ──────────────────────────────
stage "S10 postflight: honest bolt passes, committed violation caught"
printf '<?php\n// POST /leave/approve -> ApprovalService::approveRequest\n' > "$PROJ/src/routes.php"
echo "// route wired by U-001" >> "$PROJ/src/services/ApprovalService.php"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "feat(U-001): wire approval route"
OUT="$(bash "$SCR/run-postflight-scan.sh" --cwd="$PROJ" --unit=U-001 </dev/null 2>&1)"; RC=$?
EV="$(grep -o 'sha256 unchanged[^"]*' "$VAULT/bolts/U-001/postflight.json" 2>/dev/null | head -1)"
[ $RC -eq 0 ] && ok "honest bolt: postflight PASS (${EV:-verdicts recorded})" || bad "postflight rc=$RC: $OUT"
sed -i.bak "s/'approver_levels'      => 2/'approver_levels'      => 1/" "$PROJ/src/config/limits.php"; rm -f "$PROJ/src/config/limits.php.bak"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "feat(U-001): sneak policy change"
OUT="$(bash "$SCR/run-postflight-scan.sh" --cwd="$PROJ" --unit=U-001 </dev/null 2>&1)"; RC=$?
if [ $RC -ne 0 ] && echo "$OUT" | grep -qi "MISMATCH\|violation\|fail"; then
  EV2="$(grep -o 'MISMATCH[^"]*' "$VAULT/bolts/U-001/postflight.json" 2>/dev/null | head -1)"
  ok "GATE FIRED: committed violation caught — ${EV2:-status fail recorded}"
else bad "violation NOT caught rc=$RC: $OUT"; fi
git -C "$PROJ" reset -q --hard HEAD~1

# ── S10.5 B4 acceptance evidence (P4): the unit's own acceptance test is
# re-executed against the committed tree and leaves hook-guarded evidence.
# U-001's acceptance_test is `php -l src/routes.php` (the file the S10 bolt
# created) — PASS when php exists; the whole stage SKIPs gracefully on a
# runner without php (detect-never-impose). Negative: break routes.php syntax
# → the L0 syntax rung + the acceptance entry both fail (build_broken lane),
# then restore.
stage "S10.5 acceptance evidence: php -l re-executed, syntax negative"
if command -v php >/dev/null 2>&1; then
  OUT="$(bash "$SCR/run-acceptance-tests.sh" --cwd="$PROJ" --unit=U-001 </dev/null 2>&1)"; RC=$?
  if [ $RC -eq 0 ] && grep -q '"status": "pass"' "$VAULT/bolts/U-001/acceptance.json" \
     && grep -q '"written_by": "run-acceptance-tests.sh"' "$VAULT/bolts/U-001/acceptance.json"; then
    ok "acceptance evidence recorded: U-001 php -l PASS — $OUT"
  else bad "acceptance rc=$RC: $OUT"; fi
  printf '<?php\nthis is not php {{{\n' > "$PROJ/src/routes.php"
  OUT="$(bash "$SCR/run-acceptance-tests.sh" --cwd="$PROJ" --unit=U-001 </dev/null 2>&1)"; RC=$?
  if [ $RC -eq 1 ] && grep -q '"type": "syntax"' "$VAULT/bolts/U-001/acceptance.json" \
     && grep -q '"status": "fail"' "$VAULT/bolts/U-001/acceptance.json"; then
    ok "GATE FIRED: broken routes.php caught by the L0 syntax floor (exit 1, fail recorded)"
  else bad "syntax break not caught rc=$RC: $OUT"; fi
  git -C "$PROJ" checkout -q -- src/routes.php
  bash "$SCR/run-acceptance-tests.sh" --cwd="$PROJ" --unit=U-001 </dev/null >/dev/null 2>&1 \
    && ok "restored tree re-records green acceptance evidence" \
    || bad "post-restore acceptance run failed"
else
  echo "  skip: php not on this runner — S10.5 acceptance asserts skipped gracefully"
fi

# ── S11 graph ────────────────────────────────────────────────────────────────
stage "S11 build-graph"
OUT="$(bash "$SCR/build-graph.sh" --root "$PROJ" </dev/null 2>&1)"; RC=$?
GJ="$PROJ/.mega-sdd/graph.json"
if [ $RC -eq 0 ] && [ -f "$GJ" ] && grep -q "F-U-001" "$GJ" && grep -q "C-001" "$GJ"; then
  ok "graph derived: flow + claim nodes present"
else bad "graph rc=$RC: $OUT"; fi

# ── S12 FSD citation moat LIVE ───────────────────────────────────────────────
stage "S12 citation-map: fabricated path halts, real hashes stamp, drift detected"
mkdir -p "$VAULT/fsd"
cat > "$VAULT/fsd/FSD.md" <<'EOF'
# FSD — Leave Mini-App

## 1. Overview
Approval flow per vault. [Source: vault/01-overview.md (sha256: pending)]

**Sources for this section:**
- [¹] `docs/nope.md:L1-L2` (sha256: `pending`)
EOF
OUT="$(bash "$SCR/build-citation-map.sh" --vault="$VAULT" --cwd="$PROJ" --mode=pre </dev/null 2>&1)"; RC=$?
if [ $RC -eq 1 ] && echo "$OUT" | grep -q "UNRESOLVED.*nope.md"; then
  ok "GATE FIRED: fabricated citation halts (exit 1) — $(echo "$OUT" | grep -m1 UNRESOLVED)"
else bad "expected exit 1 UNRESOLVED, rc=$RC: $OUT"; fi
sed -i.bak 's|docs/nope.md:L1-L2|docs/PRD-leave.md:L1-L4|' "$VAULT/fsd/FSD.md"; rm -f "$VAULT/fsd/FSD.md.bak"
OUT="$(bash "$SCR/build-citation-map.sh" --vault="$VAULT" --cwd="$PROJ" --mode=pre </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "clean map: $OUT" || bad "citation-map rc=$RC: $OUT"
if grep -qE '\(sha256: `?[0-9a-f]{12}' "$VAULT/fsd/FSD.md" && ! grep -q "sha256: pending" "$VAULT/fsd/FSD.md"; then
  ok "all stamps are real 12-hex (model wrote zero hash chars)"
else bad "pending stamps remain or no real hashes"; fi
echo "" >> "$PROJ/docs/PRD-leave.md"; echo "- Amendment: in-app notification chosen." >> "$PROJ/docs/PRD-leave.md"
OUT="$(bash "$SCR/build-citation-map.sh" --check-drift --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1)"; RC=$?
if [ $RC -eq 0 ] && echo "$OUT" | grep -q "^DRIFT "; then
  ok "GATE FIRED: source drift detected — $(echo "$OUT" | grep -m1 '^DRIFT ')"
else bad "drift not detected rc=$RC: $OUT"; fi

# ── S12.5 SIT evidence (P5): the SIT §1–§5 fragment is script-derived from the
# REAL artifacts this pipeline produced (flows + units + acceptance/postflight);
# absent evidence stays [Pending], sign-off rows are placeholder literals.
stage "S12.5 build-sit-evidence: script-derived SIT tables, Pending honest, sign-off literal"
OUT="$(bash "$SCR/build-sit-evidence.sh" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1)"; RC=$?
SITFRAG="$VAULT/sit/.sit-evidence.md"
[ $RC -eq 0 ] && [ -f "$SITFRAG" ] && ok "fragment written: $OUT" || bad "build-sit-evidence rc=$RC: $OUT"
grep -q '^### TS-001 — Submit leave request (F-U-001)$' "$SITFRAG" \
  && grep -qF 'A["Fill form"] --> B["Validate dates"]' "$SITFRAG" \
  && ok "TS-001 scenario carries the flow's Mermaid VERBATIM" \
  || bad "TS scaffold wrong"
grep -q '\[Pending — bolt U-002 belum dieksekusi\]' "$SITFRAG" \
  && ok "U-002 without evidence stays [Pending] — never invented" \
  || bad "U-002 Pending row missing"
if command -v php >/dev/null 2>&1; then
  echo "$OUT" | grep -q 'maturity=partial' && ok "maturity=partial (U-001 evidence real, U-002 pending)" \
    || bad "maturity wrong: $OUT"
  grep -qE '\| U-001 \| [0-9]+ \(test\) \| `php -l src/routes.php` \| pass \|' "$SITFRAG" \
    && ok "§4.1 acceptance row mirrors the real acceptance.json (L0 syntax rows precede it)" || bad "acceptance row wrong"
else
  echo "$OUT" | grep -q 'maturity=planned' && ok "maturity=planned (no php on runner — no evidence)" \
    || bad "maturity wrong: $OUT"
fi
grep -q '| QA Lead | __________ | __________ | __________ | \[ \] Diterima · \[ \] Ditolak |' "$SITFRAG" \
  && ok "sign-off body rows are placeholder LITERALS (paper-out)" || bad "sign-off placeholders wrong"

# ── S12.7 advisor seed bundle (P7 5.1.1) — measure-seeds itself was deleted in
# v7 Fase 2 (one-shot measurement instrument; its verdicts are recorded in the
# optimization spec). The advisor-bundle producer is live pipeline surface and
# stays exercised on the real vault, with the map materialized as before.
stage "S12.7 advisor bundle: seed producer on the live vault"
MAPDIR="$PROJ/.mega-sdd/codebase"; mkdir -p "$MAPDIR"
{
  echo "# Codebase Map"; echo "last_scanned_commit: $(git -C "$PROJ" rev-parse HEAD 2>/dev/null)"; echo
  for f in $(find "$PROJ/src" -name '*.php' 2>/dev/null | sort); do
    echo "## ${f#$PROJ/}"
    grep -nE 'class |function |const ' "$f" 2>/dev/null | sed 's/^/    /'; echo
  done
} > "$MAPDIR/codebase-map.md"
# P7 5.1.1: build the advisor SEED bundle (replaces the whole-map paste into the
# FRESH advisor subagent) — the top real-dollar lever. It is a strict subset that
# points at the on-disk map; the advisor greps past it.
BOUT="$(bash "$SCR/build-advisor-bundle.sh" --vault "$VAULT" 2>&1)"; BRC=$?
[ $BRC -eq 0 ] && [ -f "$VAULT/.advisor-bundle.md" ] && ok "advisor bundle built (seed, not whole-map paste)" || bad "build-advisor-bundle rc=$BRC: $BOUT"
grep -qE 'codebase_map_sha256: [0-9a-f]{64}' "$VAULT/.advisor-bundle.md" && ok "bundle sha-stamps the map it points at" || bad "bundle sha missing"
grep -qiF "autoApprove" "$VAULT/.advisor-bundle.md" 2>/dev/null && bad "bundle leaked whole-map content" || ok "bundle is a strict subset (no whole-map paste)"
# (measure-seeds arms removed v7 Fase 2 — instrument deleted with _lib/seeding_budget.py.)

# ── S13 verdict ──────────────────────────────────────────────────────────────
stage "S13 verdict"
echo "  artifacts: $(cd "$PROJ" && find .mega-sdd -type f | wc -l | tr -d ' ') files under .mega-sdd/ ($(du -sh "$PROJ/.mega-sdd" 2>/dev/null | cut -f1))"
echo
echo "blackbox: $PASS ok, $FAIL failed"
if [ $FAIL -eq 0 ]; then echo "VERDICT: READY TO SHIP"; exit 0; else echo "VERDICT: NOT READY"; exit 1; fi

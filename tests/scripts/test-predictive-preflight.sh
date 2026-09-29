#!/usr/bin/env bash
# S1 (audit Phase-2b spec, commit 83e0b624) —
# validate-preflight.sh --predictive contract (former predictive-preflight.sh): JSON line per catalog check + PREFLIGHT
# summary; exit 0 when fatal==0, exit 3 when fatal>0; unknown skills skipped
# silently; cold-halt checks ride execute-bolts membership; fail-open per
# check. Catalog: skills/orchestrate-flow/references/predictive-checks.md.
# 9.0 P1 (spec 2026-09-27-v9-simplification-design.md §2/§3): the classic skills
# (generate-intent, scan-codebase, bind-codebase, generate-units) are removed and
# plan -> execute-bolts is the one pipeline. Their catalog probes were repointed to
# the surviving skills; a stale chain naming one of them FATALs skill_removed_in_9.
# Run: bash tests/scripts/test-predictive-preflight.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
S="plugins/mega-sdd/scripts/validate-preflight.sh"
SFLAGS="--predictive"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

[ -x "$S" ] && pass "script is executable" || fail "script not executable (chmod +x needed)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

json_ok() {  # every non-summary line is valid JSON with the 4 contract keys
  printf '%s\n' "$1" | grep -v '^PREFLIGHT:' | python3 -c '
import json, sys
for ln in sys.stdin:
    ln = ln.strip()
    if not ln:
        continue
    d = json.loads(ln)
    assert set(["skill", "check", "status", "hint"]) <= set(d), d
    assert d["status"] in ("ok", "warn", "fatal"), d
print("ok")' 2>/dev/null
}

# ── 1. warn-only chain on an empty mktemp cwd: runs, no crash, valid JSON ──
# 9.0 P1 repoint: scan-codebase (the old warn-only chain) was removed; plan is the
# surviving catalog skill whose checks are all fatal:no (ast_engine_present).
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
out=$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain=plan </dev/null); src=$?
[ "$src" -eq 0 ] && printf '%s\n' "$out" | grep -q '"skill": "plan", "check": "ast_engine_present"' \
  && pass "warn-only chain (plan, empty cwd) exits 0 and runs its catalog check" \
  || fail "plan chain exit $src (expected 0, ast_engine_present line): $out"
[ "$(json_ok "$out")" = "ok" ] && pass "every check line is valid JSON with skill/check/status/hint" \
  || fail "invalid JSON in output: $out"
printf '%s\n' "$out" | grep -Eq '^PREFLIGHT: [0-9]+ ok, [0-9]+ warn, [0-9]+ fatal$' \
  && pass "summary line matches 'PREFLIGHT: <n> ok, <n> warn, <n> fatal'" \
  || fail "summary line missing/malformed: $out"

# ── 2. unknown skills skipped silently (forward-compat) ──
out=$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain=no-such-skill,also-fabricated </dev/null); src=$?
[ "$src" -eq 0 ] && printf '%s\n' "$out" | grep -q '^PREFLIGHT: 0 ok, 0 warn, 0 fatal$' \
  && pass "unknown skills -> 0 checks, exit 0 (silent skip)" \
  || fail "unknown-skill handling wrong (rc=$src): $out"

# ── 2b. chain-aware inputs (v8 P0 live finding 2026-09-10): a WHOLE greenfield chain
# on an empty cwd must NOT report fatal for inputs an earlier hop produces — the xs
# baseline arm hit exactly this false fatal. 9.0 P1 repoint: the one pipeline is
# plan -> execute-bolts, and plan produces BOTH units/ and .plan-coverage-state.json.
# (The classic vault->bind leg — bind-codebase's binding_input_complete satisfied by
# generate-intent — is retired with those skills.) The single-hop fatal is 3. below.
out="$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain=plan,execute-bolts </dev/null 2>/dev/null)"; src=$?
[ "$src" -eq 0 ] && printf '%s\n' "$out" | grep -q '"check": "units_directory_present", "status": "ok", "hint": "chain-aware: units produced by an earlier hop of this chain (plan)' \
  && printf '%s\n' "$out" | grep -q '"check": "lite_plan_coverage_pass", "status": "ok", "hint": "chain-aware: plan_coverage produced by an earlier hop of this chain (plan)' \
  && printf '%s\n' "$out" | grep -Eq '^PREFLIGHT: [0-9]+ ok, 0 warn, 0 fatal$' \
  && pass "whole greenfield chain on empty cwd: inputs produced by earlier hops are chain-aware ok, exit 0" \
  || fail "chain-aware skip missing (rc=$src): $(printf '%s\n' "$out" | grep -e units_directory -e lite_plan_coverage -e PREFLIGHT)"

# ── 3. fatal path: execute-bolts ALONE on empty cwd -> units_directory_present fatal, exit 3 ──
# The counterpart of 2b: no earlier hop produces units, so the input stays fatal.
# 9.0 P1 repoint: the old single-hop probe was bind-codebase's binding_input_complete.
out=$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 3 ] && pass "fatal mismatch -> exit 3" || fail "execute-bolts on empty cwd exited $src (expected 3)"
printf '%s\n' "$out" | grep '"check": "units_directory_present"' \
  | grep -qF '"status": "fatal", "hint": "execute-bolts requires generated units. Run `plan <prd>` first' \
  && pass "units_directory_present emitted as fatal with catalog hint" \
  || fail "fatal check line missing: $out"

# ── 3b. stale chain naming a skill removed in 9.0 (e.g. a paused 8.x --resume) ──
# One skill_removed_in_9 fatal line per removed skill, hint names the plan
# replacement, exit 3; none of the removed skill's old catalog probes run.
for rs in generate-intent bind-codebase generate-units scan-codebase; do
  out=$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain="$rs" </dev/null); src=$?
  line=$(printf '%s\n' "$out" | grep '"skill": ')
  [ "$src" -eq 3 ] && [ "$(printf '%s\n' "$line" | grep -c .)" -eq 1 ] \
    && printf '%s' "$line" | grep -q "\"skill\": \"$rs\", \"check\": \"skill_removed_in_9\", \"status\": \"fatal\", \"hint\": \"$rs was removed in 9.0" \
    && printf '%s' "$line" | grep -q 'use plan' \
    && printf '%s\n' "$out" | grep -q '^PREFLIGHT: 0 ok, 0 warn, 1 fatal$' \
    && pass "removed skill $rs -> one skill_removed_in_9 fatal naming plan, exit 3" \
    || fail "removed skill $rs not refused as skill_removed_in_9 (rc=$src): $out"
done

# ── 4. vault fixture: clean execute-bolts chain passes all cold-halt checks ──
V="$TMP/proj/.mega-sdd/vaults/main"
mkdir -p "$V/units"
printf '{"vault_version": "1.0", "open_questions": [{"id": "OQ-1", "status": "open"}]}\n' > "$V/vault.json"
printf '# OQs\n' > "$V/03-open-questions.md"
cat > "$V/units/U-001.md" <<'EOF'
---
id: U-001
task_type: build
depends_on: []
target_files: [src/a.js]
acceptance_test: tests/a.test.js
---
# U-001
EOF
cat > "$V/units/U-002.md" <<'EOF'
---
id: U-002
task_type: verify
depends_on: [U-001]
target_files: []
acceptance_test: tests/b.test.js
---
# U-002
EOF
# 9.0 P1: lite is the one pipeline, so the plan-coverage rail (lite_plan_coverage_pass)
# runs on EVERY execute-bolts hop with no `lane: lite` key. Without plan Step 5's
# census the otherwise-clean fixture is fatal; with a PASS census it is clean.
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 3 ] && printf '%s\n' "$out" | grep -q '"check": "lite_plan_coverage_pass", "status": "fatal"' \
  && printf '%s\n' "$out" | grep -q '^PREFLIGHT: [0-9]* ok, 0 warn, 1 fatal$' \
  && pass "no .plan-coverage-state.json (no lane key) -> only lite_plan_coverage_pass fatal, exit 3" \
  || fail "plan-coverage rail not on by default (rc=$src): $out"
printf '{"status": "PASS", "gaps": []}\n' > "$TMP/proj/.mega-sdd/.plan-coverage-state.json"
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 0 ] && pass "well-formed units + PASS coverage census -> execute-bolts chain exits 0" \
  || fail "clean fixture exited $src: $out"
for c in units_directory_present units_depends_on_dag_acyclic units_have_acceptance_tests verify_units_have_no_target_files lite_plan_coverage_pass; do
  printf '%s\n' "$out" | grep -q "\"check\": \"$c\"" \
    && pass "cold-halt/membership check $c ran under execute-bolts" \
    || fail "check $c missing from execute-bolts chain"
done

# ── 5. mutation: strip acceptance_test -> units_have_acceptance_tests fatal ──
sed 's/^acceptance_test:.*$//' "$V/units/U-001.md" > "$V/units/U-001.md.tmp" \
  && mv "$V/units/U-001.md.tmp" "$V/units/U-001.md"
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 3 ] && printf '%s\n' "$out" | grep -q '"check": "units_have_acceptance_tests", "status": "fatal"' \
  && pass "mutation: missing acceptance_test -> fatal, exit 3" \
  || fail "acceptance_test mutation not caught (rc=$src): $out"
printf 'acceptance_test: tests/a.test.js\n' >> "$V/units/U-001.md"   # restore-ish (frontmatter order irrelevant to grep)

# ── 6. mutation: dependency cycle -> units_depends_on_dag_acyclic fatal ──
cat > "$V/units/U-001.md" <<'EOF'
---
id: U-001
task_type: build
depends_on: [U-002]
target_files: [src/a.js]
acceptance_test: tests/a.test.js
---
EOF
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 3 ] && printf '%s\n' "$out" | grep -q '"check": "units_depends_on_dag_acyclic", "status": "fatal"' \
  && pass "mutation: U-001<->U-002 cycle -> fatal, exit 3" \
  || fail "depends_on cycle not caught (rc=$src): $out"

# ── 7. mutation: verify unit with target_files -> verify_unit_writable anticipated ──
cat > "$V/units/U-001.md" <<'EOF'
---
id: U-001
task_type: build
depends_on: []
target_files: [src/a.js]
acceptance_test: tests/a.test.js
---
EOF
cat > "$V/units/U-003.md" <<'EOF'
---
id: U-003
task_type: verify
depends_on: []
target_files: [src/c.js]
acceptance_test: tests/c.test.js
---
EOF
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 3 ] && printf '%s\n' "$out" | grep -q '"check": "verify_units_have_no_target_files", "status": "fatal"' \
  && pass "mutation: verify unit with target_files -> fatal, exit 3" \
  || fail "verify-unit target_files not caught (rc=$src): $out"
rm -f "$V/units/U-003.md"

# ── 8. detect-drift on unbound vault -> binding_present_for_drift fatal ──
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=detect-drift </dev/null); src=$?
[ "$src" -eq 3 ] && printf '%s\n' "$out" | grep -q '"check": "binding_present_for_drift", "status": "fatal"' \
  && pass "detect-drift without binding.md -> fatal (chain-order error anticipated)" \
  || fail "unbound-vault drift preflight wrong (rc=$src): $out"
printf '%s\n' "$out" | grep -q '"check": "vault_present_for_drift", "status": "ok"' \
  && pass "vault_present_for_drift ok on the fixture vault" \
  || fail "vault_present_for_drift should pass on fixture"

# ── 8b. layout-3 (plan-born) vault: binding_present_for_drift reads bolts/U-*/binding.json ──
# A lite vault keeps ONE context.md and per-unit verdicts — there is never a whole-vault
# binding.md, so the binding.md-only check FATALed every lite hop of detect-drift.
# Separate project so the layout-2 fixture above stays untouched.
L3="$TMP/l3proj/.mega-sdd/vaults/leave"
mkdir -p "$L3"
printf '{"vault_version": "1.0", "open_questions": []}\n' > "$L3/vault.json"
printf '# Context\n\n## Flows\n' > "$L3/context.md"
out=$(bash "$S" $SFLAGS --cwd="$TMP/l3proj" --chain=detect-drift </dev/null); src=$?
line=$(printf '%s\n' "$out" | grep '"check": "binding_present_for_drift"')
[ "$src" -eq 3 ] && printf '%s' "$line" | grep -q '"status": "fatal"' \
  && printf '%s' "$line" | grep -q -- '--lite' \
  && pass "layout-3 vault with no bolts/U-*/binding.json -> binding_present_for_drift fatal, hint names --lite" \
  || fail "layout-3 unbound drift preflight wrong (rc=$src): $out"
mkdir -p "$L3/bolts/U-001"
printf '{"unit_id": "U-001", "verdicts": []}\n' > "$L3/bolts/U-001/binding.json"
out=$(bash "$S" $SFLAGS --cwd="$TMP/l3proj" --chain=detect-drift </dev/null); src=$?
[ "$src" -eq 0 ] && printf '%s\n' "$out" | grep -q '"check": "binding_present_for_drift", "status": "ok"' \
  && pass "layout-3 vault with bolts/U-001/binding.json -> binding_present_for_drift ok, exit 0" \
  || fail "layout-3 per-unit binding.json not honored (rc=$src): $out"

# ── 9. wide chain: summary counts equal per-line status counts; JSON stays valid ──
# generate-intent / scan-codebase are removed in 9.0 (3b.) and stay in the chain on
# purpose: their skill_removed_in_9 lines must count like any other; plan added as the
# surviving producer.
CHAIN=plan,generate-intent,detect-drift,resolve-oq,emit-fsd,emit-agents-md,execute-bolts,diff-vault,extract-intelligence,memory,scan-codebase
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain="$CHAIN" </dev/null); src=$?
[ "$(json_ok "$out")" = "ok" ] && pass "wide chain: every line valid JSON" || fail "wide chain invalid JSON"
n_ok=$(printf '%s\n' "$out" | grep -c '"status": "ok"')
n_warn=$(printf '%s\n' "$out" | grep -c '"status": "warn"')
n_fatal=$(printf '%s\n' "$out" | grep -c '"status": "fatal"')
printf '%s\n' "$out" | grep -q "^PREFLIGHT: $n_ok ok, $n_warn warn, $n_fatal fatal$" \
  && pass "summary counts match per-line statuses ($n_ok/$n_warn/$n_fatal)" \
  || fail "summary counts diverge from lines: $(printf '%s\n' "$out" | tail -1)"
if [ "$n_fatal" -gt 0 ]; then
  [ "$src" -eq 3 ] && pass "wide chain exit code follows fatal count (3)" || fail "fatal>0 but exit $src"
else
  [ "$src" -eq 0 ] && pass "wide chain exit code follows fatal count (0)" || fail "fatal==0 but exit $src"
fi

# ── 10. read-only: no file may appear in the probed cwd ──
before=$(find "$EMPTY" | sort)
bash "$S" $SFLAGS --cwd="$EMPTY" --chain=memory,extract-intelligence >/dev/null 2>&1 </dev/null
after=$(find "$EMPTY" | sort)
[ "$before" = "$after" ] && pass "probes are read-only (no writes into the probed cwd)" \
  || fail "preflight wrote into the probed cwd: $(diff <(printf '%s' "$before") <(printf '%s' "$after") | head -3)"

# ── 10b. a malformed coverage census is not a PASS (fail-closed, both modes) ──
# A probe exception used to downgrade lite_plan_coverage_pass to a fail-open warn.
printf '{not json' > "$TMP/proj/.mega-sdd/.plan-coverage-state.json"
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 3 ] && printf '%s\n' "$out" | grep -q '"check": "lite_plan_coverage_pass", "status": "fatal"' \
  && pass "malformed .plan-coverage-state.json -> lite_plan_coverage_pass fatal (not a fail-open warn)" \
  || fail "malformed coverage census not refused (rc=$src): $(printf '%s\n' "$out" | grep -e lite_plan_coverage -e PREFLIGHT)"
printf '{"status": "PASS", "gaps": []}\n' > "$TMP/proj/.mega-sdd/.plan-coverage-state.json"

# ══ 11. DISPATCH mode (--skill=, no --predictive) — what the PreToolUse hook runs ══
# V6 (2026-09-27 falsification audit): the coverage rail lived only in --predictive,
# which the MODEL runs; the hook runs --skill= mode, which checked only that units
# exist, so a direct execute-bolts dispatch on a vault whose census was missing/FAIL
# passed. The dispatch mode now reads the same state for a PLAN-BORN vault
# (layout-3: context.md, no _meta/archive/layout2/). Exempt: a migrated vault
# (spec §7 #12) and a layout-2/legacy vault (no context.md — never plan-born, so no
# census can exist; it is migrated first, which makes it exempt anyway).
dpf() { # $1=cwd $2=skill [$3=args] → "rc STATUS check_id | on_fail" from stdout JSON
  local b64="" o r; [ -n "${3:-}" ] && b64="$(printf '%s' "$3" | base64 | tr -d '\n')"
  o=$(bash "$S" --cwd="$1" --skill="mega-sdd:$2" ${b64:+--args-b64="$b64"} </dev/null 2>/dev/null); r=$?
  printf '%s' "$o" | python3 -c "import json,sys; d=json.load(sys.stdin); print('$r', d.get('status'), d.get('fatal_check_id') or '-', '|', d.get('fatal_on_fail') or '')" 2>/dev/null \
    || echo "$r NO_JSON - | $o"; }
mk_unit() { mkdir -p "$1/units"; printf -- '---\nid: U-001\ntask_type: create\nacceptance_test: t\n---\n# U-001\n' > "$1/units/U-001.md"; }
mk_l3() { mkdir -p "$1"; printf -- '---\ntype: context\nvault_layout: 3\n---\n# Context\n' > "$1/context.md"
  printf '{"vault_version": "1.0", "open_questions": []}\n' > "$1/vault.json"; mk_unit "$1"; }
mk_l2() { mkdir -p "$1"; printf '# vault\n' > "$1/vault.md"; printf '{"vault_version": "1.0", "open_questions": []}\n' > "$1/vault.json"; mk_unit "$1"; }
# the census is the REAL gate's state: one entry per vault, bound to its PRD / exclusions / OQs / units by a digest
# (a hand-written {"status": "PASS"} names no vault, so it passes no plan-born vault)
cov_prd() { printf '# PRD\n\n## Contact Form\nA form: name, email, message.\n' > "$1/PRD.md"; }
cov_decl() { printf '\n## Coverage exclusions\n- "Contact Form" — fixture: coverage is not under test here\n' >> "$1/context.md"; }
cov_run() { bash plugins/mega-sdd/scripts/validate-plan-coverage.sh --cwd="$1" --prd="$1/PRD.md" --vault="$2" --quiet >/dev/null 2>&1; }

# 11a. removed skill in a dir with NO .mega-sdd/ → FATAL, never the no-project PASS;
# and it writes nothing (no .mega-sdd/ is created in a non-project).
NOP="$TMP/noproj"; mkdir -p "$NOP"
for rs in generate-intent bind-codebase generate-units scan-codebase; do
  R="$(dpf "$NOP" "$rs")"
  printf '%s' "$R" | grep -q "^1 FATAL skill_removed_in_9 | $rs was removed in 9.0" \
    && pass "11a dispatch --skill=mega-sdd:$rs, no .mega-sdd/ -> FATAL skill_removed_in_9 rc=1" \
    || fail "11a $rs with no .mega-sdd/ fell through: $R"
done
[ ! -e "$NOP/.mega-sdd" ] && pass "11a no-project removed-skill FATAL writes nothing (no .mega-sdd/ created)" \
  || fail "11a removed-skill FATAL created $NOP/.mega-sdd"
out=$(bash "$S" --cwd="$NOP" --skill=mega-sdd:execute-bolts </dev/null 2>/dev/null); src=$?
[ "$src" -eq 0 ] && [ "$out" = '{"status":"PASS","reason":"no .mega-sdd/ project"}' ] \
  && pass "11a a surviving skill with no .mega-sdd/ keeps the byte-identical no-project PASS" \
  || fail "11a no-project PASS changed (rc=$src): $out"
# the hook's gated names stay 0-python on the no-project path (hook cost doctrine)
PYSHIM="$TMP/pyshim"; mkdir -p "$PYSHIM"; PYCNT="$TMP/pycount"
printf '#!/bin/bash\necho 1 >> "%s"\nexec "%s" "$@"\n' "$PYCNT" "$(command -v python3)" > "$PYSHIM/python3"; chmod +x "$PYSHIM/python3"
rm -f "$PYCNT"
PATH="$PYSHIM:$PATH" bash "$S" --cwd="$NOP" --skill=mega-sdd:execute-bolts --quiet </dev/null >/dev/null 2>&1
PATH="$PYSHIM:$PATH" bash "$S" --cwd="$NOP" --skill=mega-sdd:plan --quiet </dev/null >/dev/null 2>&1
[ ! -f "$PYCNT" ] && pass "11a no-project plan/execute-bolts dispatch preflight spawns 0 python" \
  || fail "11a no-project dispatch preflight spawned python ($(wc -l < "$PYCNT" | tr -d ' '))"

# 11b. plan-born layout-3 vault: missing / FAIL / malformed census → FATAL; PASS → PASS
D="$TMP/disp"; DV="$D/.mega-sdd/vaults/app"; mk_l3 "$DV"
R="$(dpf "$D" execute-bolts '--all --lite')"
printf '%s' "$R" | grep -q '^1 FATAL lite_plan_coverage_pass | ' && printf '%s' "$R" | grep -q 'plan_coverage_gap' \
  && printf '%s' "$R" | grep -q 'validate-plan-coverage.sh' && printf '%s' "$R" | grep -q 'missing' \
  && pass "11b layout-3 vault, no census -> dispatch FATAL lite_plan_coverage_pass (plan_coverage_gap, remedy named)" \
  || fail "11b missing census not refused at dispatch: $R"
cov_prd "$D"; cov_run "$D" "$DV"  # 'Contact Form' has no decision → the vault's entry is FAIL
R="$(dpf "$D" execute-bolts)"
printf '%s' "$R" | grep -q '^1 FATAL lite_plan_coverage_pass | ' && printf '%s' "$R" | grep -q 'Contact Form' \
  && pass "11b layout-3 vault, FAIL census -> dispatch FATAL naming the gap heading" \
  || fail "11b FAIL census not refused at dispatch: $R"
printf '[1, 2' > "$D/.mega-sdd/.plan-coverage-state.json"
R="$(dpf "$D" execute-bolts)"
printf '%s' "$R" | grep -q '^1 FATAL lite_plan_coverage_pass | ' \
  && pass "11b layout-3 vault, malformed census -> dispatch FATAL (fail-closed)" \
  || fail "11b malformed census not refused at dispatch: $R"
printf '{"status": "PASS", "gaps": []}\n' > "$D/.mega-sdd/.plan-coverage-state.json"
R="$(dpf "$D" execute-bolts '--all --lite')"
printf '%s' "$R" | grep -q '^1 FATAL lite_plan_coverage_pass | .*missing for .mega-sdd/vaults/app' \
  && pass "11b a hand-written {\"status\": \"PASS\"} names no vault → the plan-born vault's entry is missing → FATAL" \
  || fail "11b a vault-less PASS census opened the rail: $R"
cov_decl "$DV"; cov_run "$D" "$DV"
R="$(dpf "$D" execute-bolts '--all --lite')"
printf '%s' "$R" | grep -q '^0 PASS - ' && pass "11b layout-3 vault, PASS census -> dispatch PASS rc=0" \
  || fail "11b PASS census refused: $R"
python3 -c "import json,sys; d=json.load(open('$D/.mega-sdd/.preflight-state.json')); sys.exit(0 if {'check':'lite_plan_coverage_pass','status':'PASS'} in d['checks'] else 1)" 2>/dev/null \
  && pass "11b the dispatch state records the lite_plan_coverage_pass check" \
  || fail "11b lite_plan_coverage_pass missing from the dispatch state checks"
rm -f "$D/.mega-sdd/.plan-coverage-state.json"

# 11c. exemptions (no census anywhere): migrated vault, layout-2 vault
M="$TMP/migr"; MV="$M/.mega-sdd/vaults/app"; mk_l3 "$MV"; mkdir -p "$MV/_meta/archive/layout2"
R="$(dpf "$M" execute-bolts)"
printf '%s' "$R" | grep -q '^0 PASS - ' && pass "11c migrated vault (_meta/archive/layout2/) -> exempt, dispatch PASS" \
  || fail "11c migrated vault not exempt: $R"
L2="$TMP/l2d"; mk_l2 "$L2/.mega-sdd/vaults/app"
R="$(dpf "$L2" execute-bolts)"
printf '%s' "$R" | grep -q '^0 PASS - ' && pass "11c layout-2 vault (no context.md) -> exempt, dispatch PASS" \
  || fail "11c layout-2 vault not exempt: $R"

# 11d. mixed project: every plan-born vault CARRYING UNITS counts (a unit-less one
# never blocks). A dispatch arg never narrows the rail: execute-bolts has no --vault
# flag, so a `--vault=<x>` the skill ignores must not exempt the Skill entry
# (review 2026-09-27: `--vault=src`,
# `--vault=/tmp`, or a vault named like a project dir such as app/, passed a FAIL census).
X="$TMP/mixed"; mk_l2 "$X/.mega-sdd/vaults/old"; mk_l3 "$X/.mega-sdd/vaults/new"; mkdir -p "$X/src" "$X/new"
R="$(dpf "$X" execute-bolts '--all')"
printf '%s' "$R" | grep -q '^1 FATAL lite_plan_coverage_pass | ' && printf '%s' "$R" | grep -q 'new' \
  && pass "11d mixed, no --vault= -> the plan-born vault's missing census blocks (names it)" \
  || fail "11d mixed without target not refused: $R"
for va in '--vault=old --all' '--all --vault=src' '--all --vault=new' '--all --vault=/tmp' '--vault .mega-sdd/vaults/new'; do
  R="$(dpf "$X" execute-bolts "$va")"
  printf '%s' "$R" | grep -q '^1 FATAL lite_plan_coverage_pass | ' \
    && pass "11d mixed, dispatch args [$va] do not narrow the rail -> FATAL" \
    || fail "11d dispatch args [$va] exempted a missing census: $R"
done
# the predictive twin: a MIGRATED vault that sorts first never exempts a plan-born sibling
PM="$TMP/predmix"; mk_l3 "$PM/.mega-sdd/vaults/aaa-old"; mkdir -p "$PM/.mega-sdd/vaults/aaa-old/_meta/archive/layout2"
mk_l3 "$PM/.mega-sdd/vaults/zzz-new"
out=$(bash "$S" $SFLAGS --cwd="$PM" --chain=execute-bolts </dev/null)
printf '%s\n' "$out" | grep -q '"check": "lite_plan_coverage_pass", "status": "fatal"' \
  && pass "11d predictive: migrated vault sorting first does not exempt the plan-born zzz-new (missing census fatal)" \
  || fail "11d predictive exempted a plan-born vault behind a migrated one: $(printf '%s\n' "$out" | grep -e lite_plan_coverage -e PREFLIGHT)"
rm -rf "$PM/.mega-sdd/vaults/zzz-new/units"
out=$(bash "$S" $SFLAGS --cwd="$PM" --chain=execute-bolts </dev/null)
printf '%s\n' "$out" | grep -q '"check": "lite_plan_coverage_pass"' \
  && fail "11d predictive: a unit-less plan-born sibling revoked the migrated exemption: $(printf '%s\n' "$out" | grep lite_plan_coverage)" \
  || pass "11d predictive: migrated vault + unit-less plan-born sibling -> still exempt"
rm -rf "$X/.mega-sdd/vaults/new/units"
R="$(dpf "$X" execute-bolts)"
printf '%s' "$R" | grep -q '^0 PASS - ' && pass "11d a plan-born vault with no units does not block another vault's bolts" \
  || fail "11d unit-less plan-born vault blocked: $R"

# 11e. no units at all: bolts_units_missing keeps precedence (one fatal, not two)
NU="$TMP/nounits"; mkdir -p "$NU/.mega-sdd/vaults/app"; printf '# c\n' > "$NU/.mega-sdd/vaults/app/context.md"
R="$(dpf "$NU" execute-bolts)"
printf '%s' "$R" | grep -q '^1 FATAL bolts_units_missing | ' && pass "11e no units -> bolts_units_missing stays the fatal" \
  || fail "11e: $R"

# ══ 12. the REAL PreToolUse hook: the Skill entry (the Agent leg was removed in P3, spec v9 §8.6) ══
HOOK="plugins/mega-sdd/hooks/pre-tool-use"
H="$TMP/hookproj"; HV="$H/.mega-sdd/vaults/app"; mk_l3 "$HV"; printf '# Constitution\n' > "$HV/constitution.md"; cov_prd "$H"; cov_decl "$HV"
( cd "$H" && git init -q . && git -c user.email=t@t -c user.name=t add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m seed ) >/dev/null 2>&1
hook_skill() { printf '{"session_id":"cov-rail","cwd":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:execute-bolts","args":"--all --lite"}}' "$H" \
  | bash "$HOOK" 2>/dev/null; }
cp "$HV/context.md" "$TMP/hctx.bak"; grep -v 'Contact Form' "$TMP/hctx.bak" > "$HV/context.md"
cov_run "$H" "$HV"; cp "$TMP/hctx.bak" "$HV/context.md"  # a FAIL entry (the tree is back to the committed context.md)
OUT=$(hook_skill)
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' && printf '%s' "$OUT" | grep -q 'plan_coverage_gap' \
  && pass "12 real hook: Skill mega-sdd:execute-bolts on a FAIL census is DENIED (plan_coverage_gap)" \
  || fail "12 real hook allowed execute-bolts on a FAIL census: ${OUT:0:300}"
mkdir -p "$H/src"
OUT=$(printf '{"session_id":"cov-rail","cwd":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:execute-bolts","args":"--all --vault=src"}}' "$H" \
  | bash "$HOOK" 2>/dev/null)
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' && printf '%s' "$OUT" | grep -q 'plan_coverage_gap' \
  && pass "12 real hook: an ignored --vault=src arg does not exempt the Skill entry from a FAIL census" \
  || fail "12 real hook: --vault=src bypassed the coverage rail: ${OUT:0:300}"
rm -f "$H/.mega-sdd/.plan-coverage-state.json"
OUT=$(hook_skill)
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' && printf '%s' "$OUT" | grep -q 'plan_coverage_gap' \
  && pass "12 real hook: a MISSING census (skipped plan Step 5) is DENIED too" \
  || fail "12 real hook allowed execute-bolts with no census: ${OUT:0:300}"
cov_run "$H" "$HV"
OUT=$(hook_skill)
printf '%s' "$OUT" | grep -q 'plan_coverage_gap' \
  && fail "12 real hook still cites plan_coverage_gap on a PASS census: ${OUT:0:300}" \
  || pass "12 real hook: a PASS census clears the coverage deny (self-clears, no stale state)"

# 12b. the census the gate READS is anti-self-bypass guarded like every other gate
# state: the gate cannot re-derive it (no --prd at dispatch, no spawn budget), so a
# forged {"status":"PASS"} would otherwise open the rail. Its writer runs as
# `bash validate-plan-coverage.sh …`, which never NAMES the file, so it stays allowed.
hook_tool() { H="$H" T="$1" TI="$2" python3 -c '
import json, os, subprocess
p = {"session_id": "cov-rail", "cwd": os.environ["H"], "tool_name": os.environ["T"], "tool_input": json.loads(os.environ["TI"])}
print(subprocess.run(["bash", "plugins/mega-sdd/hooks/pre-tool-use"], input=json.dumps(p), capture_output=True, text=True, timeout=180).stdout, end="")'; }
CS="$H/.mega-sdd/.plan-coverage-state.json"
OUT=$(hook_tool Write "$(python3 -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1], "content": "{\"status\": \"PASS\"}"}))' "$CS")")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && pass "12b a Write of .plan-coverage-state.json (forged PASS) is DENIED" \
  || fail "12b Write of the coverage census allowed: ${OUT:0:300}"
for cmd in "echo '{\"status\":\"PASS\"}' > .mega-sdd/.plan-coverage-state.json" \
           "python3 -c \"open('.mega-sdd/.plan-coverage-state.json','w').write('{}')\"" \
           "cp /tmp/pass.json $CS"; do
  OUT=$(hook_tool Bash "$(python3 -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$cmd")")
  printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
    && pass "12b Bash forge [${cmd:0:40}…] of the coverage census is DENIED" \
    || fail "12b Bash forge [${cmd:0:40}…] allowed: ${OUT:0:300}"
done
OUT=$(hook_tool Bash '{"command": "bash plugins/mega-sdd/scripts/validate-plan-coverage.sh --cwd=. --prd=PRD.md --vault=.mega-sdd/vaults/app --quiet"}')
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && fail "12b the sanctioned census writer was denied: ${OUT:0:300}" \
  || pass "12b the sanctioned writer (bash validate-plan-coverage.sh …) stays allowed"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

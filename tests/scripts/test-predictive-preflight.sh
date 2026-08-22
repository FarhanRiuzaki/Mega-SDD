#!/usr/bin/env bash
# S1 (spec 2026-08-11-audit-phase2b-scripts-and-owners.md) —
# validate-preflight.sh --predictive contract (former predictive-preflight.sh): JSON line per catalog check + PREFLIGHT
# summary; exit 0 when fatal==0, exit 3 when fatal>0; unknown skills skipped
# silently; cold-halt checks ride execute-bolts membership; fail-open per
# check. Catalog: skills/orchestrate-flow/references/predictive-checks.md.
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

# ── 1. fabricated chain on an empty mktemp cwd: runs, no crash, valid JSON ──
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
out=$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain=scan-codebase </dev/null); src=$?
[ "$src" -eq 0 ] && pass "warn-only chain (scan-codebase, empty cwd) exits 0" \
  || fail "scan-codebase chain exit $src (expected 0): $out"
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

# ── 3. fatal path: bind-codebase on empty cwd -> binding_input_complete fatal, exit 3 ──
out=$(bash "$S" $SFLAGS --cwd="$EMPTY" --chain=bind-codebase </dev/null); src=$?
[ "$src" -eq 3 ] && pass "fatal mismatch -> exit 3" || fail "bind-codebase on empty cwd exited $src (expected 3)"
printf '%s\n' "$out" | grep -q '"check": "binding_input_complete"' \
  && printf '%s\n' "$out" | grep -q '"status": "fatal"' \
  && pass "binding_input_complete emitted as fatal with catalog hint" \
  || fail "fatal check line missing: $out"

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
out=$(bash "$S" $SFLAGS --cwd="$TMP/proj" --chain=execute-bolts </dev/null); src=$?
[ "$src" -eq 0 ] && pass "well-formed units -> execute-bolts chain exits 0" \
  || fail "clean fixture exited $src: $out"
for c in units_directory_present units_depends_on_dag_acyclic units_have_acceptance_tests verify_units_have_no_target_files partial_state_loads_cleanly; do
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

# ── 9. wide chain: summary counts equal per-line status counts; JSON stays valid ──
CHAIN=generate-intent,detect-drift,resolve-oq,emit-fsd,emit-agents-md,execute-bolts,diff-vault,extract-intelligence,memory,scan-codebase
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

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

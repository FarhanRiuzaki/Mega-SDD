#!/usr/bin/env bash
# test-advisor-bundle.sh — the P7 (5.1.1) SEED-NOT-BOUNDARY gate.
#
# The advisor bundle replaces the whole-map paste (a fresh 1.0x subagent seed)
# with a compact pointer. The moat risk if that pointer became a BOUNDARY: a
# contradiction living outside the bundle would be invisible → a false CONFIRMED
# no downstream gate catches (the input shrank, not the gate). This test is the
# gate for the change — it proves, mechanically, that the bundle is a strict
# SUBSET that still POINTS at the full search space, and that the advisor is both
# tooled and instructed to expand past it. (A live-model behavioral test is not
# constructible in CI; the mechanism guarantees are the honest ceiling.)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../plugins/mega-sdd"
BUILD="$PLUGIN/scripts/build-advisor-bundle.sh"
rc=0
ok()  { echo "PASS ($1)"; }
bad() { echo "FAIL ($1)"; rc=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t advbundle)"
trap 'rm -rf "$WORK"' EXIT

# ── a mini project: a vault + a codebase-map that HIDES a contradiction ───────
# C-001 is drafted CONFIRMED against src/Employee.php. The map ALSO contains an
# auto-approve implementation at src/LegacyApprover.php that CONTRADICTS the
# maker-checker claim — under a DIFFERENT name, referenced by NO verdict. If the
# bundle were the advisor's horizon, this contradiction would be invisible.
ROOT="$WORK/proj"; V="$ROOT/.mega-sdd/vaults/leave"
mkdir -p "$V" "$ROOT/.mega-sdd/codebase"
CONTRADICTION="function autoApprove() { return true; // NO maker-checker }"
cat > "$ROOT/.mega-sdd/codebase/codebase-map.md" <<EOF
# Codebase Map
last_scanned_commit: deadbeef

## src/Employee.php
    class Employee
    public function leaveBalance()

## src/LegacyApprover.php
    class LegacyApprover
    $CONTRADICTION
EOF
cat > "$V/binding.md" <<'EOF'
---
vault: leave
codebase_map: .mega-sdd/codebase/codebase-map.md
binding_metadata:
  head: deadbeef
---
# Binding Manifest
## Confirmed Claims
- C-001 | 03-data-model.md:2 | src/Employee.php:1 | approval requires maker-checker
EOF
cat > "$V/binding.json" <<'EOF'
{"claims":[{"id":"C-001","verdict":"CONFIRMED","vault_source":"03-data-model.md:2","anchor":"src/Employee.php:1"}]}
EOF

OUT="$(bash "$BUILD" --vault "$V" 2>&1)"; BRC=$?
BUNDLE="$V/.advisor-bundle.md"
[ $BRC -eq 0 ] && [ -f "$BUNDLE" ] && ok "bundle built (exit 0)" || bad "build rc=$BRC: $OUT"

# ── 1. the bundle POINTS at the full search space (path + sha, not a dead end) ─
grep -q "codebase_map_path: .mega-sdd/codebase/codebase-map.md" "$BUNDLE" && ok "bundle carries the map PATH (advisor can reach the full map)" || bad "map path missing from bundle"
grep -qE "codebase_map_sha256: [0-9a-f]{64}" "$BUNDLE" && ok "bundle carries the map sha256 (freshness/integrity linkage)" || bad "map sha missing"

# ── 2. the bundle is a strict SUBSET — the contradiction is NOT in it ─────────
grep -qF "autoApprove" "$BUNDLE" && bad "LEAK: contradiction pasted into bundle (not a subset)" || ok "contradiction is NOT in the bundle (strict subset — no whole-map paste)"
grep -qF "LegacyApprover" "$BUNDLE" && bad "LEAK: hidden impl pasted into bundle" || ok "hidden impl absent from bundle (seed, not corpus)"

# ── 3. the contradiction IS reachable via the path the bundle names ──────────
grep -qF "autoApprove" "$ROOT/.mega-sdd/codebase/codebase-map.md" && ok "contradiction lives in the on-disk map the bundle points at (reachable by grep)" || bad "fixture broken: contradiction not in map"

# ── 4. the bundle MANDATES expansion past itself ─────────────────────────────
grep -qiE "Grep this WHOLE file|Grep the FULL codebase-map" "$BUNDLE" && ok "bundle instructs grep-the-whole-map" || bad "expansion instruction missing"
grep -qiE "IN SCOPE|not your horizon|SEED, not" "$BUNDLE" && ok "bundle states evidence outside it is in scope" || bad "seed-not-boundary framing missing"

# ── 5. the checklist + skill + agent make expansion MECHANICAL, not a wish ────
grep -qiE "Grep the WHOLE codebase-map|expand past the bundle|IN SCOPE" "$PLUGIN/skills/bind-codebase/references/advisor-checklist.md" && ok "advisor-checklist mandates grep-beyond-seed" || bad "checklist lacks expansion mandate"
grep -qiE "NOT.*pasted|paths.*NOT the pasted|bundle path" "$PLUGIN/skills/bind-codebase/SKILL.md" && ok "bind SKILL dispatches by path, not pasted contents" || bad "SKILL still implies whole-map paste"
grep -qiF "build-advisor-bundle.sh" "$PLUGIN/skills/bind-codebase/SKILL.md" && ok "bind SKILL runs build-advisor-bundle.sh at Step 2.12" || bad "SKILL does not build the bundle"
grep -qE "^tools:.*Grep" "$PLUGIN/agents/phase-advisor.md" && ok "phase-advisor is TOOLED to grep (mechanism enabler)" || bad "phase-advisor lacks Grep — expansion impossible"

# ── 6. missing-map degrades honestly (no fabricated sha) ─────────────────────
V2="$WORK/proj2/.mega-sdd/vaults/x"; mkdir -p "$V2"
printf '%s\n' '---' 'vault: x' 'codebase_map: .mega-sdd/codebase/codebase-map.md' '---' '# B' > "$V2/binding.md"
printf '%s\n' '{"claims":[]}' > "$V2/binding.json"
bash "$BUILD" --vault "$V2" >/dev/null 2>&1
grep -q "codebase_map_present: false" "$V2/.advisor-bundle.md" && ok "missing map -> present:false (honest)" || bad "missing map not surfaced"
grep -q "codebase_map_sha256: null" "$V2/.advisor-bundle.md" && ok "missing map -> sha null, never fabricated" || bad "fabricated sha for missing map"

echo "== test-advisor-bundle: $([ $rc -eq 0 ] && echo ALL-PASS || echo HAS-FAIL) =="
exit $rc

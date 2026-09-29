#!/usr/bin/env bash
# Audit Phase 4 (spec 2026-08-11-audit-phase4-platform-hygiene.md §E3) —
# STANDING teacher↔template parity harness: the permanent answer to the
# teacher/template drift class (the 6.1.1 field-defect lineage — "the template
# still stamped the poison"). Pins the KNOWN teacher↔template pairs so
# re-drift fails CI. New pairs get ADDED here; pins are never weakened.
# Overlap with test-p11-owner-parity.sh S5a/S6a is deliberate: p11 pins the
# 2b release outcome; p12 is the standing class harness.
# Run: bash tests/surface/test-p12-teacher-template-parity.sh </dev/null
# Mutation-proof: P12_ROOT=<scratch tree> overrides the repo root.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="${P12_ROOT:-$here/../..}"
cd "$ROOT" || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# ── (a) unit required-frontmatter keys: schema teaches, template carries ──
# 9.0 P1: generate-units was removed; its unit schema + template were relocated
# (git mv) into plan, the only unit producer (design 2026-09-27 §3). Same pair.
US="$P/skills/plan/references/unit-schema.md"
UT="$P/skills/plan/references/templates/unit.md"
ok_a=1
for key in task_type grounding_confidence module; do
  grep -qF "$key" "$US" || { fail "a: unit-schema.md lost required key '$key'"; ok_a=0; }
  grep -q "^${key}:" "$UT" || { fail "a: templates/unit.md frontmatter lost required key '$key:'"; ok_a=0; }
done
[ $ok_a -eq 1 ] && pass "a: required frontmatter keys (task_type/grounding_confidence/module) at BOTH schema and template"

# ── (b) the 6.1.1 expects contract at BOTH teachers ──
if grep -qF 'substring the runner LITERALLY prints' "$UT" \
   && grep -qF 'SUBSTRING MATCHER' "$US"; then
  pass "b: expects substring contract present at BOTH template ('LITERALLY prints') and schema ('SUBSTRING MATCHER')"
else fail "b: expects contract pair broken (6.1.1 poison class can re-enter)"; fi

# ── (c) staging-drop severity: ONE owner (vault-core) says advisory; the flow template
#    points at the owner; NEITHER claims a halt ──
# 9.0 P1: generate-intent (and its layout-2 04-flows template) was removed. The
# surviving flow template is plan's layout-3 context.md `## Flows`, which no longer
# restates the severity — it carries an owner pointer to vault-core §stages-propagation
# (relocated to plugin references/). Parity now = template points at the owner (c1),
# owner says advisory + "no longer blocks" (c2/c4), neither claims a halt (c3/c5).
FT="$P/skills/plan/references/templates/context.md"
VC="$P/references/vault-core.md"
grep -qF 'vault-core.md §stages-propagation' "$FT" \
  && grep -qF 'validate-vault-flow-staging.sh' "$FT" \
  && pass "c1: context.md flow template carries the owner pointer (vault-core §stages-propagation + validator)" \
  || fail "c1: context.md flow template lost its pointer to the staging owner (A3 re-drift)"
grep -F 'vault_flow_staging_drop' "$VC" | grep -q 'advisory' \
  && pass "c2: vault-contract says advisory for vault_flow_staging_drop" \
  || fail "c2: vault-contract severity drifted"
# Negative pin: neither file's vault_flow_staging_drop lines may claim a halt.
# ("block" appears at the teacher ONLY inside the demotion negation "demoted this
# from a hard-block — it no longer blocks execute-bolts" — pinned positively below.)
if grep -F 'vault_flow_staging_drop' "$FT" "$VC" | grep -qi 'halt'; then
  fail "c3: a vault_flow_staging_drop line claims a halt (severity fork reopened)"
else pass "c3: neither file's vault_flow_staging_drop lines claim a halt"; fi
grep -F 'vault_flow_staging_drop' "$VC" | grep -qF 'no longer blocks' \
  && pass "c4: teacher keeps the demotion negation ('no longer blocks')" \
  || fail "c4: teacher lost the it-does-NOT-block statement"
# Negative pin on the template's staged-only pointer comment (it names no finding id,
# so c3 alone cannot see it): the pointer must not re-grow a halt/block severity.
if sed -n '/staged-only:/,/-->/p' "$FT" | grep -qiE 'halt|block(s|ed)? (execute|bolt)|hard-block'; then
  fail "c5: context.md staged-only pointer claims a halt/block (severity fork reopened)"
else pass "c5: context.md staged-only pointer claims no halt/block"; fi

# ── (d) UAT step-row owner: uat-sections §Section 2 owns; SKILL + template point ──
UO="$P/skills/emit-uat/references/uat-sections.md"
USK="$P/skills/emit-uat/SKILL.md"
UTM="$P/skills/emit-uat/references/uat-template.md"
ROW7='| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |'
ROWLIT='| 1 | <Aksi> | <Expected Result> |'
grep -qF "$ROW7" "$UO" && grep -qF '(7 cells' "$UO" \
  && grep -qF "$ROWLIT" "$UO" && grep -qF 'Pending — flow' "$UO" \
  && pass "d1: uat-sections §Section 2 carries the 7-cell row shape + row literal + Pending-row literal" \
  || fail "d1: UAT step-row owner lost part of its grammar"
grep -qF 'OWNED by `references/uat-sections.md §Section 2`' "$USK" \
  && grep -qF 'adds no rules of its own' "$UTM" \
  && pass "d2: SKILL + uat-template carry owner pointers" \
  || fail "d2: a pointer home lost its OWNED-by pointer"
if grep -qF "$ROWLIT" "$USK" || grep -qF "$ROWLIT" "$UTM"; then
  fail "d3: a killed row-literal enumeration re-grew in SKILL or uat-template (negative pin)"
else pass "d3: neither SKILL nor uat-template re-enumerates the step-row literal"; fi

# ── (f) §5 annex pair (6.10.0): teacher owns the grammar; template + SKILL point ──
ANNEX_SLOT='{{annex_eksekusi_otomatis}}'
ANNEX_PH='_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._'
ANNEX_HD='## 5. Lampiran — Eksekusi Otomatis (pre-UAT)'
grep -qF "$ANNEX_SLOT" "$UO" && grep -qF "$ANNEX_PH" "$UO" && grep -qF 'byte-compare' "$UO" \
  && pass "f1: uat-sections §Section 5 owns the annex grammar (slot + placeholder + byte-compare rule)" \
  || fail "f1: teacher lost part of the §5 annex grammar"
grep -qF "$ANNEX_SLOT" "$UTM" && grep -qF "$ANNEX_PH" "$UTM" && grep -qF "$ANNEX_HD" "$UTM" \
  && grep -qF 'OWNED by `references/uat-sections.md §Section 5`' "$UTM" \
  && pass "f2: uat-template carries the §5 block + slot + placeholder + owner pointer" \
  || fail "f2: template lost part of the §5 annex pair"
grep -qF "$ANNEX_PH" "$USK" && grep -qF 'ANNEX_FORGED' "$USK" \
  && pass "f3: SKILL carries the placeholder literal + ANNEX_FORGED wiring" \
  || fail "f3: SKILL lost the §5 wiring"

# ── (e) binding marker pair: grammar owner + the ONLY writer (binding-mode) ──
# 9.0 P1: bind-codebase (and binding-md-template.md) was removed. Per design
# 2026-09-27 §7 decision #10 the layout-2 binding grammar is owned by the code,
# scripts/_lib/binding_md.py (shared by the gate validator + derive-binding-json),
# and the template is NOT relocated. The pair is therefore owner(code) + writer(doc).
BT="$P/scripts/_lib/binding_md.py"
BM="$P/skills/resolve-oq/references/binding-mode.md"
if grep -qF '### ✅ CONFLICT-' "$BT" && grep -qF '### ✅ CONFLICT-' "$BM" \
   && grep -qF '**Resolution**: ✅ RESOLVED (' "$BT" && grep -qF '**Resolution**: ✅ RESOLVED (' "$BM"; then
  pass "e1: '### ✅ CONFLICT-' + '**Resolution**: ✅ RESOLVED (' present at BOTH grammar owner and writer"
else fail "e1: binding marker pair broken (owner/writer drift or deletion)"; fi
# Behavioural half (the owner is code, so check it, not just its comments): the
# owner's regexes must accept the writer's exact write-back forms.
if MEGA_SDD_LIB_DIR="$P/scripts/_lib" python3 - <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import binding_md as b
h = "### ✅ CONFLICT-1 RESOLVED (KEEP_CODE) — original title"
r = "- **Resolution**: ✅ RESOLVED (KEEP_CODE) 2026-09-27 — rationale"
m = b.CONFLICT_HEADING_RE.match(h)
ok = bool(m) and m.group(1) == "CONFLICT-1"
ok = ok and bool(b.RESOLUTION_LINE_RE.search(r))
ok = ok and all((b._ACTION_IN_PARENS_RE.search(x) or [None, None])[1] == "KEEP_CODE" for x in (h, r))
sys.exit(0 if ok else 1)
PYEOF
then pass "e2: binding_md.py grammar accepts the writer's heading + Resolution-line forms"
else fail "e2: binding_md.py grammar no longer accepts the writer's write-back forms"; fi

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

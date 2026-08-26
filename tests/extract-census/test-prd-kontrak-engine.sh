#!/usr/bin/env bash
# PRD-kontrak engine pins (spec 2026-08-26-extract-revamp-contract-design.md,
# step 2+3): the census-contracted extraction engine + its consumer repoints.
# Successor of the retired wave-era pins (test-b1-wave-dispatch-diet /
# test-extract-dispatch-static / iter80 verify) — the guarantees that SURVIVE
# the restructure are re-pinned here against their new homes:
#   DIET   disciplines + REPORT BACK ride the domain-extractor agent body
#          (load on every dispatch by construction); the controller types only
#          the variable core; the idiom table lives ONCE in the grammar ref.
#   MOAT   secret-scan gate phrase, trace announce, mutability axis, language
#          carrier survive the SKILL rewrite.
#   RETIRE the wave machinery stays dead (zero-phantom sweep) and the catalog
#          + halt registry moved with the code.
# Run: bash tests/extract-census/test-prd-kontrak-engine.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
SKILL="$P/skills/extract-intelligence/SKILL.md"
TPL="$P/skills/extract-intelligence/references/prd-kontrak-template.md"
AG="$P/agents/domain-extractor.md"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# ── MOAT survivals in the rewritten SKILL ────────────────────────────────────
grep -qF 'secret-scan.sh" --redact' "$SKILL" \
  && pass "secret-scan gate phrase survives the rewrite (fmea U1 sibling)" \
  || fail "secret-scan gate phrase lost from SKILL.md"
grep -qF '`mega-sdd-trace:extract-intelligence`' "$SKILL" \
  && pass "trace announce line survives" || fail "trace announce lost"
grep -qF 'Indonesian + English technical terms' "$SKILL" \
  && grep -q 'precedence' "$SKILL" && grep -qF 'output-language.md' "$SKILL" \
  && pass "output-language carrier block survives" || fail "language carrier lost"
grep -qF 'derive-extract-census.sh' "$SKILL" && grep -qF 'validate-extract-census.sh' "$SKILL" \
  && pass "SKILL runs census derive + completeness gate" || fail "census scripts not commanded"
grep -qF 'module_quality_threshold_unmet' "$SKILL" \
  && pass "twice-failed module gate halts quality_gate_failed(module_quality_threshold_unmet)" \
  || fail "module halt subtype missing from SKILL"
grep -qF 'references/prd-kontrak-template.md' "$SKILL" \
  && pass "SKILL routes to the grammar reference" || fail "grammar ref not routed"
n_lines=$(wc -l < "$SKILL" | tr -d ' ')
[ "$n_lines" -le 500 ] && pass "SKILL.md within the 500-line budget ($n_lines)" \
  || fail "SKILL.md over budget: $n_lines lines"

# ── DIET guarantees re-pinned at their new homes ─────────────────────────────
for d in "P1 — State & data provenance" "P2 — Enumerate ALL sites" "P3 — Behaviour-as-EXECUTED" "P4 — Classify files by structure" "P6 — Dynamic dispatch"; do
  grep -qF "$d" "$AG" && pass "agent body carries discipline: ${d%% —*}" \
    || fail "agent body lost discipline: $d"
done
grep -qF 'gate_self_check: pass | fail' "$AG" \
  && pass "agent REPORT BACK machine block survives" || fail "REPORT BACK block lost"
grep -qF 'MASTER STACK IDIOM TABLE' "$TPL" \
  && pass "idiom table lives ONCE in the grammar reference" || fail "idiom table missing from template"
n_idiom=$(grep -rl "MASTER STACK IDIOM TABLE" "$P" --include="*.md" --include="*.sh" | wc -l | tr -d ' ')
[ "$n_idiom" -le 2 ] && pass "idiom table not duplicated (referenced from $n_idiom files)" \
  || fail "idiom table duplicated across $n_idiom files"
grep -qF 'READ FIRST' "$TPL" && grep -qF 'mega-sdd-trace:extract-intelligence' "$TPL" \
  && pass "dispatch core = variable core + read-first + trace tag" || fail "dispatch core weakened"
grep -q 'dispatch-static\|GLOSSARY INDEX\|Wave [0-9]' "$AG" \
  && fail "agent body still carries wave-era machinery" \
  || pass "agent body free of wave-era machinery"

# ── grammar contract pieces the gate + consumers depend on ───────────────────
grep -qF 'modules/<domain>.prd.md' "$TPL" && grep -qF 'source_files:' "$TPL" \
  && pass "template pins modules/<domain>.prd.md + source_files claim contract" \
  || fail "template output contract incomplete"
grep -qF '## Reengineering Opportunities' "$TPL" && grep -qF '## Mutability Tier Distribution' "$TPL" \
  && pass "README keeps the two generate-intent-read headings verbatim" \
  || fail "README heading contract broken"
grep -qF '## Per-locked-field policy' "$TPL" && grep -qF '## Entity-level summary' "$TPL" \
  && pass "data-mutation-policy consumer headings preserved (build-dispatch-prompt contract)" \
  || fail "data-mutation-policy headings broken"
grep -qF '[LOCKED]' "$TPL" && grep -qF '[INTENT]' "$TPL" && grep -qF '[ARTIFACT]' "$TPL" \
  && pass "mutability axis (invariant #4) carried in the template" || fail "mutability axis lost"
grep -qF '_Tidak terdeteksi._' "$TPL" \
  && pass "explicit-absence line mandated (never silent omission)" || fail "explicit absence missing"

# ── consumers repointed ──────────────────────────────────────────────────────
grep -qF 'census.json' "$P/skills/generate-intent/references/kb-submode.md" \
  && grep -qF 'modules/*.prd.md' "$P/skills/generate-intent/references/kb-submode.md" \
  && pass "kb-submode consumes the PRD-kontrak grammar" || fail "kb-submode not repointed"
grep -qF 'legacy numbered-tree' "$P/skills/generate-intent/references/kb-submode.md" \
  && pass "kb-submode keeps the legacy-tree back-compat lane" || fail "legacy lane dropped"
grep -qF 'validate-extract-census.sh' "$P/skills/bind-codebase/references/auto-memory-handoff.md" \
  && pass "bind preflight = census gate (scorecard retired)" || fail "bind preflight not repointed"
grep -qF 'validate-extract-census.sh' "$P/scripts/certify-artifact.sh" \
  && pass "certify kb rung certifies PRD-kontrak via the census gate" || fail "certify kb rung not repointed"
grep -qF 'census.json' "$P/scripts/build-prd-core.sh" \
  && pass "emit-prd reverse mode refuses a PRD-kontrak KB with a pointer" \
  || fail "build-prd-core reverse not guarded"
grep -qF '"data-mutation-policy.md"' "$P/scripts/build-dispatch-prompt.sh" \
  && grep -qF '99-rebuild-architecture' "$P/scripts/build-dispatch-prompt.sh" \
  && pass "dispatch builder probes dmp at KB root AND legacy 99- path" \
  || fail "dmp dual-probe missing"
grep -qF 'extract-intelligence-module' "$P/references/model-tiers.md" \
  && pass "model-tiers carries the extract-intelligence-module role" || fail "module role row missing"

# ── ground.sh catalog regex parses ROLE names (piggyback bug fix) ────────────
roles=$(python3 - <<'PY'
import re
content = open("plugins/mega-sdd/references/model-tiers.md").read()
roles = set(re.findall(r"^\|\s*\d+[a-z]?\s*\|\s*`?([\w-]+)`?\s*\|", content, re.MULTILINE))
print(",".join(sorted(roles)))
PY
)
echo "$roles" | grep -q "extract-intelligence-module" \
  && echo "$roles" | grep -q "bolt-implementer" \
  && pass "catalog regex (as fixed in ground.sh) captures role names incl. 21b row" \
  || fail "catalog regex capture wrong: $roles"
grep -qF 'catalog_roles = set(_re_mt.findall(' plugins/mega-sdd/scripts/ground.sh \
  && grep -qF 'd+[a-z]?' plugins/mega-sdd/scripts/ground.sh \
  && pass "ground.sh guard 8 uses the role-cell regex" || fail "ground.sh regex not fixed"

# ── zero-phantom sweep: the wave machinery stays dead ────────────────────────
for gone in plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md \
            plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md \
            plugins/mega-sdd/scripts/build-extract-static.sh \
            plugins/mega-sdd/scripts/validate-extraction-scorecard.sh; do
  [ -e "$gone" ] && fail "retired file resurrected: $gone" || pass "stays deleted: $(basename "$gone")"
done
phantoms=$(grep -rln "wave-dispatch-templates\.md\|knowledge-base-schema\.md\|build-extract-static\.sh\|validate-extraction-scorecard\.sh" \
  plugins/mega-sdd/skills plugins/mega-sdd/scripts plugins/mega-sdd/references \
  plugins/mega-sdd/agents plugins/mega-sdd/hooks plugins/mega-sdd/commands 2>/dev/null | wc -l | tr -d ' ')
[ "$phantoms" -eq 0 ] \
  && pass "zero phantom references to retired files on live surfaces" \
  || fail "$phantoms live file(s) still reference retired artifacts: $(grep -rln 'wave-dispatch-templates\.md\|knowledge-base-schema\.md\|build-extract-static\.sh\|validate-extraction-scorecard\.sh' plugins/mega-sdd/skills plugins/mega-sdd/scripts plugins/mega-sdd/references plugins/mega-sdd/agents plugins/mega-sdd/hooks plugins/mega-sdd/commands 2>/dev/null | tr '\n' ' ')"
grep -rqn "extract-intelligence-wave" plugins/mega-sdd/references/model-tiers.md \
  && fail "wave rows still in model-tiers" || pass "wave rows gone from model-tiers"
grep -qF 'module_quality_threshold_unmet' "$P/references/halt-families/extract.md" \
  && pass "halt family retargeted to the module gate" || fail "halt family not retargeted"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

#!/usr/bin/env bash
# test-6d-doc-pins.sh — god-review stage 6, Batch 6C doc-coherence pins.
#   EB-GATE-3   ONE commit topology: no execute-bolts surface claims the post-flight
#               scan halts BEFORE commit / leaves the violation uncommitted.
#   EB-GATE-2   the canonical commit identity + trailers appear on every producer surface.
#   EB-DOC-5    the canonical bolt-halt enum has ONE home (halts-and-handoff.md);
#               handoff-contract points at it and carries NO inline copy (M-02).
#   PHANTOMS    --strict-provenance gone; `ast-grep test --validate` only ever mentioned
#               as NOT existing; missing_dependency retired from the dispatch vocabulary.
#   EB-DOC-4/HONEST-4  spec-reviewer body is blind-era (no implementer-report trust);
#               all five lenses carry a read-only rail.
#   EB-DOC-7    stale create/extend/modify enum phrase eliminated.
#   LOCKED-DRIFT one eligibility (override-only) — no surface still says propose-eligible.
#   EB-PHANTOM-1 review-panel no longer claims a per-lens model_tiers override.
# Run: bash tests/god-review-s6/test-6d-doc-pins.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
EB="${P}/skills/execute-bolts"

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

echo "── EB-GATE-3: one commit topology ──"
BAD=0
# Broadened net (a stage-6 miss let "code stays in working tree" / "re-validate BEFORE
# commit" survive on grammar-v2 + the trigger fixture). The pattern targets the DEFECT
# signature — a post-flight/violation surface claiming the code is uncommitted / halts
# before the commit — while leaving legitimate detect-after negations ("never a claim
# that the code is uncommitted") and pre-flight timing ("HALT before any code is written",
# "halt before the panel") untouched.
# NB: the hyphenated "halts pre-commit" form is the phrasing this defect recurred in
# most (e2e-iter6, auto.test.md header, both dated specs) — it MUST be in the net, not
# just the "before commit" wording. Scanned case-insensitively (grep -i).
# "code in working tree" (not just stays/remains/preserved) is also a detect-after
# residue — the broadened `code[^.]{0,20}working tree` catches it (a prior narrow
# pattern let it survive in vault-contract.md + halt-taxonomy.md).
TOPO_BAD='halts?[[:space:]]+pre-commit|pre-commit[[:space:]]+halts?|halts? before commit|re-validate[^.]*before commit|code[^.]{0,20}working tree|preserved in (the )?working tree|remains? in[^.]{0,20}\(not committed\)'
for f in "$EB/SKILL.md" "$EB/references/hard-rule-scan.md" "$EB/references/hard-rule-grammar-v2.md" \
         "$EB/references/code-gates.md" "$EB/references/review-panel.md" "$EB/references/batch-and-fanout.md" \
         "$EB/references/halts-and-handoff.md" "${ROOT}/tests/skill-triggering/execute-bolts.test.md" \
         "${ROOT}/tests/skill-triggering/auto.test.md" "${ROOT}/tests/scenarios/scenario-2-prd-driven-feature.md" \
         "${ROOT}/tests/scenarios/scenario-6-recovery-from-halt.md" \
         "${ROOT}/tests/integration/e2e-iter6.test.md" \
         "${P}/skills/generate-intent/references/vault-contract.md" \
         "${P}/skills/generate-intent/references/vault-core.md" \
         "${P}/references/halt-protocol.md" \
         "${P}/skills/orchestrate-flow/references/halt-taxonomy.md"; do
  [ -f "$f" ] || { fail "EB-GATE-3 scan target missing: $f"; BAD=1; continue; }
  if grep -qiE "$TOPO_BAD" "$f"; then
    fail "pre-commit-halt / uncommitted-code claim survives in $(basename "$f")"; BAD=1
  fi
done
[ "$BAD" = "0" ] && ok "no execute-bolts surface (incl. grammar-v2, halts-and-handoff, the trigger fixture) claims the post-flight halt precedes the commit"
grep -qiE "detect-after" "${ROOT}/tests/skill-triggering/execute-bolts.test.md" \
  && ok "trigger fixture states the detect-after topology" || fail "trigger fixture missing detect-after statement"
grep -q "detect-after" "$EB/SKILL.md" && grep -q "detect-after" "$EB/references/hard-rule-scan.md" \
  && ok "detect-after topology stated in SKILL.md + hard-rule-scan" || fail "detect-after topology statement missing"
grep -q "rotate it NOW" "$EB/references/code-gates.md" && grep -q "purge it from history" "$EB/references/code-gates.md" \
  && ok "secret_in_code remediation is committed-state honest (rotate + history purge)" || fail "secret_in_code remediation still claims uncommitted"

echo "── EB-GATE-2: commit identity on every producer surface ──"
grep -q "SDD-PROVENANCE: mega-sdd/execute-bolts" "$EB/references/bolt-contract.md" \
  && grep -q "Unit: U-XXX" "$EB/references/bolt-contract.md" \
  && ok "bolt-contract carries both trailers" || fail "bolt-contract trailers missing"
grep -q "SDD-PROVENANCE" "$P/agents/bolt-implementer.md" && ok "bolt-implementer instructs the trailers" || fail "bolt-implementer trailer instruction missing"
grep -q "SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-XXX" "$P/agents/bolt-implementer.md" \
  && ok "bolt-implementer (the dispatch system prompt) scaffolds the full trailer — sole prompt-side copy (M-09)" || fail "bolt-implementer full trailer scaffold missing"
grep -q 'UNIT_SCOPE' "$P/scripts/validate-bolt-artifacts.sh" && grep -q 'trailers:key=Unit' "$P/scripts/validate-bolt-artifacts.sh" \
  && ok "validator accepts scope + trailer identity channels" || fail "validator identity channels missing"

echo "── EB-DOC-5: halt-enum sync ──"
python3 - "$EB/references/halts-and-handoff.md" "$P/skills/orchestrate-flow/references/handoff-contract.md" "$P/skills/orchestrate-flow/references/halt-taxonomy.md" <<'PYEOF'
import re, sys
hh, hc, ht = open(sys.argv[1]).read(), open(sys.argv[2]).read(), open(sys.argv[3]).read()
m = re.search(r"CANONICAL bolt-halt enum.*?\n\n(`.*?`)\n", hh, re.DOTALL)
assert m, "canonical enum block missing from halts-and-handoff"
canon = set(re.findall(r"`([a-z_]+)`", m.group(1)))
for required in ("whitelist_violation", "review_critical_unresolved", "batch_suite_red",
                 "postflight_evidence_missing", "hard_rule_mixed_grammar", "commit_rejected_by_hook",
                 "memory_in_use"):
    assert required in canon, "canonical enum missing %s" % required
# M-02 ownership flip: handoff-contract carries NO inline copy of the enum any more —
# a single pointer names the canonical owner (halts-and-handoff.md), so copy-drift is
# impossible by construction. Assert BOTH directions: the pointer exists AND no inline
# copy survives (enum-only tokens must not appear anywhere in the contract).
assert "halts-and-handoff.md" in hc, "handoff-contract must point at the canonical enum owner halts-and-handoff.md"
for tok in ("hard_rule_unanchored", "bolt_repeated_partial_failure", "pbt_property_violated",
            "partial_state_corrupt", "self_assessment_missing"):
    assert tok not in hc, "handoff-contract still carries an inline enum copy (%s found)" % tok
# halt-taxonomy.md must classify EVERY canonical bolt-halt (makes the halts-and-handoff
# line-400 "halt-taxonomy classifies every entry" claim enforceable — no silent gap).
ht_set = set(re.findall(r"`([a-z_]+)`", ht))
tax_missing = canon - ht_set
assert not tax_missing, "halt-taxonomy.md missing classification for: %s" % sorted(tax_missing)
print("  ✓ canonical enum complete (incl. memory_in_use); handoff-contract carries the owner pointer + NO inline copy; halt-taxonomy classifies every entry")
PYEOF
[ $? -eq 0 ] || fail "halt-enum sync"

echo "── phantoms ──"
if grep -rn "strict-provenance" "$P/scripts" "$P/skills" "$P/commands" >/dev/null 2>&1; then
  fail "--strict-provenance phantom survives"
else
  ok "--strict-provenance phantom gone"
fi
BAD=0
while IFS= read -r line; do
  echo "$line" | grep -qiE "does not exist|does NOT exist" || { fail "ast-grep test --validate presented as real: $line"; BAD=1; }
done < <(grep -rn "ast-grep test --validate" "$P/skills" "$P/commands" 2>/dev/null | grep -v Binary)
[ "$BAD" = "0" ] && ok "ast-grep test --validate only ever mentioned as nonexistent"
# P2d moved the halt vocabulary into the agent system prompt — the canonical
# dep_missing pin must cover BOTH the dispatch template AND its new home.
BAD=0
for f in "$EB/references/bolt-dispatch-prompt.md" "$P/agents/bolt-implementer.md"; do
  grep -q "missing_dependency" "$f" && { fail "missing_dependency alias survives in $(basename "$f")"; BAD=1; }
done
[ "$BAD" = "0" ] && ok "halt vocabulary uses canonical dep_missing (dispatch template + bolt-implementer agent)"
grep -q "dep_missing" "$P/agents/bolt-implementer.md" \
  && ok "bolt-implementer carries the canonical dep_missing halt type" \
  || fail "bolt-implementer missing the dep_missing halt type (vocabulary did not land in the agent)"

echo "── panel agents ──"
grep -q "implementer claims" "$P/agents/spec-reviewer.md" \
  && fail "spec-reviewer still describes the implementer's report as its input" \
  || ok "spec-reviewer body is blind-era (no report in prompt)"
grep -q "base/head commit SHAs" "$P/agents/spec-reviewer.md" && grep -q "git diff" "$P/agents/spec-reviewer.md" \
  && ok "spec-reviewer derives the change set from the diff" || fail "spec-reviewer lacks the diff instruction"
for a in code-quality-reviewer security-reviewer standards-reviewer design-reviewer; do
  grep -q "Read-only discipline" "$P/agents/$a.md" || fail "$a missing the read-only rail"
done
grep -q "never modify anything" "$P/agents/design-reviewer.md" && ok "all four sibling lenses carry the read-only rail"
grep -q "never run a Bash command that mutates" "$P/agents/spec-reviewer.md" && ok "spec-reviewer carries the read-only rail inline" || fail "spec-reviewer read-only rail missing"

echo "── enum + eligibility coherence ──"
grep -rqE "create/extend/modify" "$EB" && fail "stale create/extend/modify enum phrase survives" || ok "task_type enum phrases honest ({create,verify,extend})"
grep -rq "propose-and-confirm OR override" "$EB" && fail "locked-drift dual-eligibility survives" || ok "bolt_introduces_locked_drift is override-only everywhere"
grep -q "Models are NEVER hardcoded" "$EB/references/review-panel.md" && fail "phantom per-lens model override claim survives" || ok "panel model pinning documented honestly"
grep -q "risk: high" "$EB/references/review-panel.md" && ok "unit risk: frontmatter consumed as panel signal 6" || fail "risk: signal missing from tier selection"

echo "── whitelist observer documented where it exists ──"
grep -q "whitelist-scan" "$EB/SKILL.md" && grep -q "whitelist_violation" "$EB/SKILL.md" \
  && ok "SKILL.md documents the B3 observer" || fail "SKILL.md whitelist wording stale"
# (6.0.0 cull: the execute-bolts command alias is gone — the SKILL.md leg above
# is the surviving doc plane for the B3 observer.)
grep -q "B3" "$P/CLAUDE.md" && grep -q "whitelist_violation" "$P/CLAUDE.md" \
  && ok "CLAUDE.md enforcement inventory carries B3" || fail "CLAUDE.md inventory stale"

echo
[ "$FAILED" -eq 0 ] && { echo "test-6d-doc-pins: ALL PASS"; exit 0; } || { echo "test-6d-doc-pins: FAILURES"; exit 1; }

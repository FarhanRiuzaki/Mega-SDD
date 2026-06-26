#!/usr/bin/env bash
# Pin: the A1 per-AC grounding gate is wired end-to-end — validate-unit-spec.sh
# (run PostToolUse on unit writes) emits verify_grounding_untrusted into
# .unit-spec-state.json, and the PreToolUse aggregator blocks the next
# execute-bolts on it (alongside render_test_missing). Enforcement, not prose.
set -u
err=0
pt=plugins/mega-sdd/hooks/pre-tool-use
V=plugins/mega-sdd/scripts/validate-unit-spec.sh
SCHEMA=plugins/mega-sdd/skills/generate-units/references/unit-schema.md

grep -q 'verify_grounding_untrusted' "$V" || { echo "validator: verify_grounding_untrusted halt missing"; err=1; }
grep -q '\[grounded:' "$V" || { echo "validator: grounded marker parse missing"; err=1; }
grep -q 'verify_grounding_untrusted' "$pt" || { echo "pre-tool-use: halt_type read missing"; err=1; }
grep -q 'verify-grounding' "$pt" || { echo "pre-tool-use: verify-grounding fail name missing"; err=1; }
grep -q '.unit-spec-state.json' "$pt" || { echo "pre-tool-use: unit-spec state read missing"; err=1; }
grep -q 'grounded: path:line' "$SCHEMA" || { echo "unit-schema: [grounded:] marker convention undocumented"; err=1; }

bash -n "$pt" || { echo "pre-tool-use: syntax error"; err=1; }
bash -n "$V"  || { echo "validator: syntax error"; err=1; }

[ $err -eq 0 ] && echo "ALL PASS (test-verify-grounding-wired)" || echo "FAILED"
exit $err

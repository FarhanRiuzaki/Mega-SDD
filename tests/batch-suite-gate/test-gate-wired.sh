#!/usr/bin/env bash
# Pin: the B2 batch-suite gate is wired end-to-end — Stop hook writes the state,
# PreToolUse blocks the next execute-bolts on FAIL. Enforcement, not prose.
set -u
err=0
st=plugins/mega-sdd/hooks/stop
pt=plugins/mega-sdd/hooks/pre-tool-use
V=plugins/mega-sdd/scripts/validate-bolt-artifacts.sh

# Stop hook invokes the gate scan (unconditional, alongside orphan-scan)
grep -q -- '--batch-suite-gate' "$st" || { echo "stop hook: batch-suite-gate scan missing"; err=1; }
# PreToolUse reads the state file and appends to the execute-bolts fails aggregator
grep -q '.batch-suite-gate-state.json' "$pt" || { echo "pre-tool-use: batch-suite-gate state read missing"; err=1; }
grep -q 'batch-suite-gate' "$pt" || { echo "pre-tool-use: batch-suite-gate fail name missing"; err=1; }
grep -q 'batch_suite_red' "$pt" || { echo "pre-tool-use: batch_suite_red branch missing"; err=1; }
# the gate block lives under the execute-bolts SKILL_NAME guard (so it blocks the right tool)
grep -q 'mega-sdd:execute-bolts' "$pt" || { echo "pre-tool-use: execute-bolts guard missing"; err=1; }
# validator advertises the mode
grep -q -- '--batch-suite-gate) BATCH_SUITE_GATE=1' "$V" || { echo "validator: --batch-suite-gate arg missing"; err=1; }
grep -q 'batch_suite_gate_missing' "$V" || { echo "validator: batch_suite_gate_missing halt missing"; err=1; }

# syntax of every edited surface
bash -n "$st" || { echo "stop: syntax error"; err=1; }
bash -n "$pt" || { echo "pre-tool-use: syntax error"; err=1; }
bash -n "$V"  || { echo "validator: syntax error"; err=1; }

[ $err -eq 0 ] && echo "ALL PASS (test-gate-wired)" || echo "FAILED"
exit $err

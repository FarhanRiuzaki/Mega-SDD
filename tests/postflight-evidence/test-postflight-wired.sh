#!/usr/bin/env bash
# Pin: the B1 postflight-evidence gate is wired end-to-end — Stop hook writes the
# state, PreToolUse blocks the next execute-bolts on FAIL. Enforcement, not prose.
set -u
err=0
st=plugins/mega-sdd/hooks/stop
pt=plugins/mega-sdd/hooks/pre-tool-use
V=plugins/mega-sdd/scripts/validate-bolt-artifacts.sh

grep -q -- '--postflight-scan' "$st" || { echo "stop hook: postflight-scan call missing"; err=1; }
grep -q '.bolt-postflight-state.json' "$pt" || { echo "pre-tool-use: postflight state read missing"; err=1; }
grep -q 'postflight-evidence' "$pt" || { echo "pre-tool-use: postflight-evidence fail name missing"; err=1; }
grep -q 'mega-sdd:execute-bolts' "$pt" || { echo "pre-tool-use: execute-bolts guard missing"; err=1; }
grep -q -- '--postflight-scan) POSTFLIGHT_SCAN=1' "$V" || { echo "validator: --postflight-scan arg missing"; err=1; }
grep -q 'postflight_evidence_missing' "$V" || { echo "validator: postflight_evidence_missing halt missing"; err=1; }

bash -n "$st" || { echo "stop: syntax error"; err=1; }
bash -n "$pt" || { echo "pre-tool-use: syntax error"; err=1; }
bash -n "$V"  || { echo "validator: syntax error"; err=1; }

[ $err -eq 0 ] && echo "ALL PASS (test-postflight-wired)" || echo "FAILED"
exit $err

#!/usr/bin/env bash
# Pin: the orphan scan is wired into hooks and analyze. (The pre-tool-use
# bind-codebase degenerate-map gate was pruned in 9.0 P1b with its skill; the map
# validator's codebase_map_sections_incomplete halt stays pinned by
# tests/god-review-s3/test-3a-validator-gate.sh V5.)
set -u
err=0
pt=plugins/mega-sdd/hooks/pre-tool-use
st=plugins/mega-sdd/hooks/stop
ra=plugins/mega-sdd/scripts/run-analyze.sh

# pre-tool-use: execute-bolts aggregator reads the orphan state
grep -q '.bolt-orphans-state.json' "$pt" || { echo "pre-tool-use: orphan gate missing"; err=1; }
grep -q 'bolt-orphans' "$pt" || { echo "pre-tool-use: orphan gate name missing"; err=1; }
# stop hook: unconditional orphan scan (not gated on a handoff marker)
grep -q -- '--orphan-scan' "$st" || { echo "stop hook: orphan scan call missing"; err=1; }
# run-analyze: bolt_orphans boundary in the report
grep -q 'bolt_orphans' "$ra" || { echo "run-analyze: bolt_orphans boundary missing"; err=1; }
grep -q -- '--orphan-scan' "$ra" || { echo "run-analyze: orphan scan invocation missing"; err=1; }
# shell syntax of every edited surface
bash -n "$pt" || { echo "pre-tool-use: syntax error"; err=1; }
bash -n "$st" || { echo "stop: syntax error"; err=1; }
bash -n "$ra" || { echo "run-analyze: syntax error"; err=1; }
bash -n plugins/mega-sdd/scripts/validate-bolt-artifacts.sh || { echo "validator: syntax error"; err=1; }
exit $err

#!/usr/bin/env bash
set -u
err=0
ce="plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
bi="plugins/mega-sdd/agents/bolt-implementer.md"
grep -qE 'reuse-index\.yaml' "$ce" || { echo "context-enrichment does not inject reuse-index path"; err=1; }
grep -qiE 'reuse_candidates' "$ce" || { echo "context-enrichment does not carry reuse_candidates"; err=1; }
grep -qiE 'reuse-first|reuse first' "$bi" || { echo "bolt-implementer missing reuse-first protocol"; err=1; }
grep -qF 'reuse_decisions' "$bi" || { echo "bolt-implementer missing reuse_decisions"; err=1; }
grep -qiE 'scan the full reuse-index|full reuse-index|read the full index|not just the' "$bi" || { echo "bolt-implementer does not make the full index the primary surface"; err=1; }
exit $err

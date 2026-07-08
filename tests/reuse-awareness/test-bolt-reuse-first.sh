#!/usr/bin/env bash
set -u
err=0
ce="plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
bi="plugins/mega-sdd/agents/bolt-implementer.md"
grep -qE 'reuse-index\.yaml' "$ce" || { echo "context-enrichment does not inject reuse-index path"; err=1; }
grep -qiE 'reuse_candidates' "$ce" || { echo "context-enrichment does not carry reuse_candidates"; err=1; }
grep -qiE 'reuse-first|reuse first' "$bi" || { echo "bolt-implementer missing reuse-first protocol"; err=1; }
grep -qF 'reuse_decisions' "$bi" || { echo "bolt-implementer missing reuse_decisions"; err=1; }
# M-13/B3: the full-index-primacy statement lives in Iron Rule #4 (canonical), not
# the self-review echo (de-dup'd away). Pin the canonical phrasing.
grep -qiE 'scan the full .?reuse-index|present only in the full index|absent from the per-unit hint|read the full index|not just the' "$bi" || { echo "bolt-implementer does not make the full index the primary surface"; err=1; }
exit $err

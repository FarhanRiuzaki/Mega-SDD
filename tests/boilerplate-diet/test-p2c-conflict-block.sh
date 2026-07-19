#!/usr/bin/env bash
# test-p2c-conflict-block.sh — batch2 P2c (spec 2026-07-19-batch2-derive-and-diet.md):
# the Conflicts summary table is DROPPED — the claim/reality pair lives in the
# `### CONFLICT-N` detail block (the machine-read form is the sole carrier).
#
#   1  template: `- **Vault claim**:` / `- **Codebase reality**:` in the detail-block
#      grammar; NO summary-table header row
#   2  binding-mode walks detail blocks (menu from the headings); summary-table
#      write-back gone; legacy-table fallback documented
#   3  binding-contract required-sections entry updated
#   4  EMPIRICAL: CLAIM_LINE_RE does NOT match the new pair lines (regex-collision
#      guard) AND a fixture binding.md carrying the pair lines parses correctly
#      (resolution maps to the right claim id, zero errors)
#
# Run: bash tests/boilerplate-diet/test-p2c-conflict-block.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
BMT="$P/skills/bind-codebase/references/binding-md-template.md"
BC="$P/skills/bind-codebase/references/binding-contract.md"
BM="$P/skills/resolve-oq/references/binding-mode.md"
RSK="$P/skills/resolve-oq/SKILL.md"
BSK="$P/skills/bind-codebase/SKILL.md"
LIB="$P/scripts/_lib"

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }

echo "== P2c: the CONFLICT detail block is the sole conflict carrier =="

# ── 1: template grammar ──
grep -qF -- '- **Vault claim**:' "$BMT" && ok "1: detail block carries the Vault-claim line" || fail "1: Vault-claim line missing"
grep -qF -- '- **Codebase reality**:' "$BMT" && ok "1: detail block carries the Codebase-reality line (+ anchor)" || fail "1: Codebase-reality line missing"
if grep -qF '| ID | Vault Claim | Codebase Reality |' "$BMT"; then fail "1: summary-table header row survives in the template"; else ok "1: summary table gone from the template"; fi
grep -qF -- '- **Claim**:' "$BMT" && ok "1: the machine-read Claim line survives (W2 grammar intact)" || fail "1: Claim line lost"
grep -qF 'evidence anchor file:line' "$BMT" && ok "1: reality line mandates the evidence anchor" || fail "1: evidence-anchor mandate missing"
grep -qF 'no summary table' "$BSK" && ok "1: bind SKILL Step 4 states the sole-carrier rule" || fail "1: SKILL sole-carrier note missing"

# ── 2: binding-mode walk ──
grep -qF 'detail block' "$BM" && ok "2: binding-mode walks the detail blocks" || fail "2: detail-block walk missing"
if grep -qF 'Walk Conflicts table' "$BM"; then fail "2: 'Walk Conflicts table' survives"; else ok "2: table-walk phrasing gone"; fi
if grep -qF 'summary-table `Resolution Needed` cell' "$BM"; then fail "2: summary-table write-back survives"; else ok "2: summary-table write-back gone"; fi
grep -qF 'pre-P2 bindings' "$BM" && grep -qF 'never update it' "$BM" \
  && ok "2: legacy-table fallback documented (ignore, never update — the gate never read it)" || fail "2: legacy fallback missing"
grep -qF 'State Map' "$BM" && ok "2: legacy anchor fallback via the State Map Anchor column" || fail "2: legacy anchor fallback missing"
grep -qF 'CONFLICT detail-block walk' "$RSK" && ok "2: resolve-oq SKILL router line updated" || fail "2: SKILL router still says table walk"

# ── 3: binding-contract ──
grep -qF 'Conflict detail blocks' "$BC" && grep -qF 'no summary table' "$BC" \
  && ok "3: binding-contract required-sections entry updated" || fail "3: binding-contract still lists the Conflicts table"

# ── 4: EMPIRICAL — CLAIM_LINE_RE non-collision + correct parse with pair lines ──
MEGA_SDD_LIB_DIR="$LIB" python3 <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import binding_md

# (a) collision guard: the new pair lines must NOT match CLAIM_LINE_RE
for line in ("- **Vault claim**: Order.total is integer cents",
             "- **Codebase reality**: Order.total is a float column (app/Models/Order.php:5)"):
    assert not binding_md.CLAIM_LINE_RE.search(line), "CLAIM_LINE_RE collides with: " + line
print("  \N{CHECK MARK} 4: CLAIM_LINE_RE does not match the new pair lines (no collision)")

# (b) a RESOLVED block carrying the pair lines still parses to the RIGHT claim id
md = "\n".join([
    "## Conflicts (1) — BLOCKING",
    "",
    "### ✅ CONFLICT-1 RESOLVED (KEEP_CODE) — order total type drift",
    "- **Vault claim**: Order.total is integer cents",
    "- **Codebase reality**: Order.total is a float column (app/Models/Order.php:5)",
    "- **Claim**: C-002",
    "- **Resolution**: ✅ RESOLVED (KEEP_CODE) 2026-07-19 — code reality wins",
    "",
    "## Open Questions (0)",
])
errors = []
res = binding_md.parse_conflict_resolutions(md, errors)
assert errors == [], "unexpected parse errors: %r" % errors
assert res == {"C-002": "KEEP_CODE"}, "wrong resolution map: %r" % res
print("  \N{CHECK MARK} 4: RESOLVED block with pair lines parses to C-002/KEEP_CODE, zero errors")

# (c) ACTIVE block with pair lines but no Claim line stays ACTIVE, zero errors
md2 = "\n".join([
    "## Conflicts (1) — BLOCKING",
    "",
    "### CONFLICT-2 — naming drift",
    "- **Vault claim**: entity is named Customer",
    "- **Codebase reality**: table is clients (migrations/001.php:9)",
    "",
    "## Open Questions (0)",
])
errors2 = []
res2 = binding_md.parse_conflict_resolutions(md2, errors2)
assert errors2 == [] and res2 == {}, "ACTIVE block misparsed: %r %r" % (errors2, res2)
print("  \N{CHECK MARK} 4: ACTIVE block with pair lines stays ACTIVE (no phantom resolution)")
PYEOF
[ $? -eq 0 ] || fail "4: empirical parser checks failed"

if [ "$FAILED" -eq 0 ]; then echo "ALL P2C PINS OK"; exit 0; else echo "P2C pins FAILED"; exit 1; fi

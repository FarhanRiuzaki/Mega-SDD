#!/usr/bin/env bash
# Delta lane (spec 2026-08-11-free-text-delta-lane.md) — contract pins.
# Run: bash tests/delta-lane/test-delta-lane-contracts.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$here/../.."
P="$ROOT/plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

DV="$P/skills/diff-vault/SKILL.md"
DP="$P/skills/diff-vault/references/diff-procedure.md"
AC="$P/skills/diff-vault/references/auto-and-chain.md"
BC="$P/skills/bind-codebase/references/binding-contract.md"
RR="$P/skills/orchestrate-flow/references/routing-rules.md"
HP="$P/references/halt-protocol.md"
HT="$P/skills/orchestrate-flow/references/halt-taxonomy.md"
HC="$P/skills/orchestrate-flow/references/handoff-contract.md"
FD="$P/commands/mega-sdd.md"
MP="$P/references/multi-prd-lifecycle.md"
UM="$P/skills/using-mega-sdd/SKILL.md"

# ── 1. front door: vault-presence branch + greenfield unchanged + ASK keterangan ──
grep -qF 'YES, and NO vault exists in CWD' "$FD" \
  && grep -qF 'generate-intent --from-prompt <input>` (greenfield brief — unchanged)' "$FD" \
  && pass "1a: front door keeps the greenfield Mode B branch unchanged" \
  || fail "1a: greenfield Mode B branch lost/reworded"
grep -qF 'diff-vault --from-prompt <input>' "$FD" \
  && grep -qF '.delta-changed-paths.txt' "$FD" \
  && pass "1b: front door delta branch proposes diff-vault --from-prompt + the delta scope file" \
  || fail "1b: delta branch missing at the front door"
grep -qF 'Delta ke vault' "$FD" && grep -qF 'Epic baru' "$FD" \
  && pass "1c: ownership-unsure ASK carries keterangan options" \
  || fail "1c: ASK options lost keterangan"

# ── 2. multi-prd contract: row 4 + prompt-scale signal + amended free-text clause ──
grep -qF 'ticket-scale chat requirement' "$MP" && grep -qF 'diff-vault --from-prompt' "$MP" \
  && pass "2a: multi-prd-lifecycle carries the delta row" \
  || fail "2a: delta row missing from multi-prd-lifecycle"
grep -qF 'Prompt-scale signal' "$MP" \
  && pass "2b: prompt-scale ownership signal defined beside the doc-title signal" \
  || fail "2b: prompt-scale signal missing"
grep -qF 'EPIC-SCALE brief' "$MP" && grep -qF 'TICKET-SCALE brief' "$MP" \
  && pass "2c: the free-text clause distinguishes epic-scale vs ticket-scale" \
  || fail "2c: doc-type-agnosticism clause still routes ALL free-text to a new vault (prose-asserts-closed breach)"

# ── 3. routing-rules: delta row overlay-only + precedence + fail-closed edges ──
grep -qF 'Delta lane — ticket-scale quoted free-text + owned vault' "$RR" \
  && grep -qF 'NEVER fired from derived state alone' "$RR" \
  && pass "3a: delta decision-matrix row exists and is overlay-only" \
  || fail "3a: delta row missing or not overlay-scoped"
grep -qF 'OUTRANKS this row' "$RR" \
  && pass "3b: prd_revision outranks the delta row (precedence declared)" \
  || fail "3b: precedence vs prd_revision undeclared"
grep -qF 'exit 3 (no `binding.json`' "$RR" \
  && grep -qF 'Exit 2 (ANY parse failure)' "$RR" \
  && pass "3c: both derive-delta-paths fail-closed edges routed (3 -> normal chain, 2 -> FULL re-bind)" \
  || fail "3c: a fail-closed edge is unrouted"
grep -qF 'never `.sync-changed-paths.txt`' "$RR" \
  && pass "3d: delta lane declares its own scope file, not the sync discriminator" \
  || fail "3d: scope-file separation undeclared"

# ── 4. cap: numbers at their single owner (diff-procedure) + SKILL points ──
grep -qF 'new entities + new flows **> 2**' "$DP" \
  && grep -qF '**> 12**' "$DP" \
  && grep -qF 'ANY new scope/squad surface' "$DP" \
  && pass "4a: cap numbers (>2 entities+flows, >12 rows, new scope) at diff-procedure (single owner)" \
  || fail "4a: cap numbers moved/lost"
grep -qF 'delta_too_large' "$DV" \
  && pass "4b: SKILL Step 3 carries the cap guard" \
  || fail "4b: SKILL lost the cap guard"

# ── 5. provenance: no-rebaseline under from-prompt ──
grep -qF 'are NOT re-baselined' "$DV" \
  && grep -qF 'NOT re-baselined' "$DP" \
  && grep -qF 'APPENDS a `source_documents[]` entry' "$DP" \
  && pass "5: from-prompt never re-baselines prd_sha256 and appends (not replaces) source_documents" \
  || fail "5: no-rebaseline provenance contract lost"

# ── 6. halt registration at all 3 homes + keterangan options ──
grep -qF '| delta_too_large' "$HP" \
  && grep -qF '`delta_too_large` — diff-vault' "$HP" \
  && grep -qF '# delta_too_large only' "$HP" \
  && pass "6a: halt-protocol carries enum + registry one-liner + type-specific fields" \
  || fail "6a: halt-protocol registration incomplete"
grep -qF 'full_lane' "$HP" && grep -qF 'split_ticket' "$HP" \
  && pass "6b: registry entry carries the {code, keterangan}-style options (full_lane/split_ticket/cancel)" \
  || fail "6b: options/keterangan missing from the registry entry"
grep -qF '`delta_too_large`' "$HT" \
  && pass "6c: halt-taxonomy Always-stop roster carries delta_too_large" \
  || fail "6c: taxonomy classification missing"
grep -E '^\| `diff-vault` \|' "$HC" | grep -qF 'delta_too_large' \
  && pass "6d: handoff-contract diff-vault row halted enum gains delta_too_large" \
  || fail "6d: handoff row enum not updated"

# ── 7. handoff row stays routing-clean (the conflict-route assertions, local mirror) ──
DVROW="$(grep -E '^\| `diff-vault` \|' "$HC")"
echo "$DVROW" | grep -qF 'mega-sdd:diff-vault' \
  && echo "$DVROW" | grep -qF 'mega-sdd:orchestrate-flow' \
  && pass "7a: row still routes diff-vault (interactive re-invoke) + orchestrate-flow (clean apply)" \
  || fail "7a: row lost a mandatory route"
echo "$DVROW" | grep -qF 'mega-sdd:bind-codebase' \
  && fail "7b: row names bind-codebase directly (forbidden — the router owns the re-bind hop)" \
  || pass "7b: row never names bind-codebase (delta re-bind goes through the router)"

# ── 8. binding-contract: vault-section leg concrete + patch-bump narrowing + moat sentences verbatim ──
grep -qF 'Vault-section leg, concrete detection' "$BC" \
  && pass "8a: the vault-section selection leg is concrete (reads VAULT-DIFF.md)" \
  || fail "8a: vault-section leg still unspecified"
grep -qF 'without a diff-vault patch record' "$BC" \
  && pass "8b: patch-bump != regeneration narrowing present" \
  || fail "8b: a diff-vault apply still degrades every scoped re-bind to full"
grep -qF 'every ACTIVE CONFLICT from the previous binding regardless of path intersection' "$BC" \
  && grep -qF 'A carried-forward verdict is never silently upgraded or downgraded' "$BC" \
  && pass "8c: the moat-pinned selection/carry-forward sentences stay VERBATIM" \
  || fail "8c: a moat-pinned sentence was reworded"

# ── 9. scope-cut on record: NO census keywords added to ANY always-loaded description ──
head -5 "$UM" | grep -qiF 'tambah kolom' \
  && fail "9a: delta trigger phrases leaked into the anchor-budgeted description census" \
  || pass "9a: using-mega-sdd description census unchanged (propose-first lane; anchor budget protected)"
head -5 "$DV" | grep -qiF 'tambah kolom' \
  && fail "9b: delta trigger phrase in diff-vault's always-loaded description (poison moved to an unwatched surface)" \
  || pass "9b: diff-vault description carries no bare-sentence trigger (round M2 pin)"
head -5 "$DV" | grep -qF 'never auto-triggers' \
  && pass "9c: diff-vault description states the propose-first contract" \
  || fail "9c: propose-first statement lost from the description"

# ── 10. auto-and-chain: cap stays interactive + handoff tail never names bind ──
grep -qF 'delta_too_large' "$AC" \
  && pass "10a: --auto behavior table/interactive list carries the cap halt" \
  || fail "10a: cap halt missing from auto-and-chain"
grep -qF 'this handoff never names the bind hop directly' "$AC" \
  && pass "10b: from-prompt handoff tail documented as router-mediated" \
  || fail "10b: handoff tail contract missing"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

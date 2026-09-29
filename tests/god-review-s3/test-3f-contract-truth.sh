#!/usr/bin/env bash
# test-3f-contract-truth.sh — god-review stage 3, Batch 3F.
# Pins the contract & prose-truth alignment: docs must not claim mechanisms,
# fields, numbers, or enforcement that don't exist; cross-doc contracts agree.
#
#   INT-3  the sync lane's scoped Mode D detect-drift branch is carried by the
#          handoff-contract routing index (detect-drift row).
#   INT-6  symbol-graph attribution: pagerank-targeting.md stays removed; paths.md
#          registers no symbol-graph artifact; task-typing never re-attributes to scan.
#   V4     no inverted §3(routes)/§4(data models) reference anywhere in the plugin.
#   AH-4   libs slice carries _source under a manifest grammar (schema surface).
#   DS-3   vault-core carries the canonical lock spec (§Concurrency contract).
#   DS-5   dead snapshot claims removed (no ~30-50%); source_files_sha256_map is
#          documented for its one live type and its named consumer reads it.
#
# 9.0 P1 (classic removal): scan-codebase / bind-codebase / generate-units /
# generate-intent are deleted. Arms that pinned their own references are RETIRED
# (scan handoff CWD-conditional next_action + artifacts list, deep-scan gate /
# dispatch / prompts [INT-4, V3, AH-3, DS-4, DS-5 scan arms, DS-7, DS-8],
# scan-procedure reference captures, bind-codebase implementation-state /
# oq-resolution / binding-contract [V4 instance arms, AH-3 binder side], the
# codebase-map snapshot type in shared-snapshot-schema). Surviving arms are
# repointed: vault-core → references/vault-core.md, task-typing →
# plan/references/task-typing.md, INT-3 mirror → the detect-drift row.
#
# Run: bash tests/god-review-s3/test-3f-contract-truth.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
HC="$P/skills/orchestrate-flow/references/handoff-contract.md"
SSS="$P/references/shared-snapshot-schema.md"
SCS="$P/references/starterkit-context-schema.md"
PTH="$P/references/paths.md"
VCORE="$P/references/vault-core.md"                    # relocated from generate-intent/references/ (9.0 P1)
TT="$P/skills/plan/references/task-typing.md"           # relocated from generate-units/references/ (9.0 P1)
KBI="$P/skills/plan/references/kb-input.md"             # plan --kb input contract (9.0 P1)
for f in "$HC" "$SSS" "$SCS" "$PTH" "$VCORE" "$TT" "$KBI"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 3F: contract & prose-truth =="

# ── INT-3 ── (9.0 P1: scan-codebase — the Mode D producer that handed off
#   `detect-drift ... --scope=@<vault>/.sync-changed-paths.txt --auto` — is deleted;
#   its operative halts-flags-handoff.md + SKILL.md arms are RETIRED. The scoped
#   Mode D branch itself survives: orchestrate-flow --sync passes the changed set to
#   detect-drift. Repointed ROW-ANCHORED to the detect-drift routing row — the old
#   file-wide grep would pass vacuously off the generic `mega-sdd:detect-drift`
#   schema example.)
DDROW=$(grep -E '^\| `detect-drift` \|' "$HC")
printf '%s' "$DDROW" | grep -qF 'sync lane (SCOPE_DIRS resolved from `--scope=@<vault>/.sync-changed-paths.txt`, passed by orchestrate-flow --sync)' \
  && ok "INT-3: handoff-contract detect-drift row carries the scoped Mode D (sync-lane) branch" || fail "INT-3: contract detect-drift row missing the scoped Mode D branch"

# ── INT-6 ──
# (scan-procedure `name.reference.*` arm RETIRED 9.0 P1 — scan-codebase deleted.)
# pagerank-targeting.md removed 5.29.0 (D1); generate-units' references now live in
# plan/references/ — guard the WHOLE plugin tree so it cannot resurrect anywhere.
PRT_HIT=$(find "$P" -name 'pagerank-targeting.md' 2>/dev/null | head -1)
if [ -n "$PRT_HIT" ]; then fail "INT-6: pagerank-targeting.md resurrected at $PRT_HIT (removed 5.29.0 §D1)"; else ok "INT-6: pagerank-targeting.md removed — the build-attribution question is moot"; fi
if grep -v 'inert' "$PTH" | grep -q 'symbol-graph'; then fail "INT-6: paths.md still registers the removed symbol-graph artifact"; else ok "INT-6: paths.md symbol-graph registration removed (only the inert-cache note remains)"; fi
# round-2: sibling unit-generation surface (task-typing, now plan/references/) must
# not re-attribute to scan (file existence asserted above — no vacuous pass).
if grep -qF 'per scan-codebase run' "$TT"; then
  fail "r2: task-typing.md still says 'per scan-codebase run'"
else
  ok "r2: task-typing.md attribution corrected"
fi

# ── V4: §3=Routes / §4=Data models everywhere ──
# (implementation-state.md + oq-resolution.md instance arms RETIRED 9.0 P1 —
#  bind-codebase deleted; the class-wide negative grep below still covers the plugin.)
# round-2: NO inverted reference anywhere in the plugin (the class, not the instances)
if rtk proxy grep -rn --include="*.md" -e '§4 (routes)' -e '§3 (data models)' "$P" >/dev/null 2>&1 || \
   grep -rn --include="*.md" -e '§4 (routes)' -e '§3 (data models)' "$P" >/dev/null 2>&1; then
  fail "r2: an inverted §3/§4 reference survives somewhere in the plugin"
else
  ok "r2: plugin-wide negative grep — no inverted §3/§4 reference remains"
fi

# ── AH-3 ── RETIRED 9.0 P1: the truncated_sections marker + UNKNOWN consumer rule
#   lived in scan-codebase (codebase-map-schema.md, halts-flags-handoff.md) and
#   bind-codebase (implementation-state.md, binding-contract.md), all deleted. The
#   surviving JIT bind has no capped map (execute-bolts
#   jit-bind-and-quarantine.md: "`truncated_section` cannot occur").

# ── AH-4 ── (deep-scan-prompts.md OUTPUT FORMAT arm RETIRED 9.0 P1 — scan-codebase deleted.)
grep -qF '_source: ["composer.json"]' "$SCS" && ok "AH-4: schema §libs carries _source" || fail "AH-4: schema §libs _source missing"
grep -qF 'names the MANIFEST whose ecosystem block produced the entry' "$SCS" && ok "AH-4: citation rail defines the libs _source grammar" || fail "AH-4: rail grammar missing"

# ── DS-3 (v7.3.0: the memory skill is REMOVED; the canonical lock spec is
# vault-core §Concurrency contract, and its deterministic implementation is
# derive-vault-json.sh's script-held lock; 9.0 P1: vault-core relocated to
# plugins/mega-sdd/references/vault-core.md) ──
grep -qF '### Concurrency contract' "$VCORE" && ok "DS-3: vault-core carries the canonical lock spec" || fail "DS-3: lock spec anchor dangling"
grep -qF 'derive-vault-json.sh' "$VCORE" && ok "DS-3: lock spec points at the deterministic implementation" || fail "DS-3: lock spec lacks the script pointer"
grep -qF 'single advisory-lock pattern' "$VCORE" && ok "DS-3: vault-core declares itself the canonical spec (post-memory-skill)" || fail "DS-3: canonical-spec declaration missing"

# ── DS-4 ── RETIRED 9.0 P1: the untrusted-data fence / MANIFEST_FACTS data fence
#   pinned deep-scan-prompts.md + deep-scan-dispatch.md (scan-codebase, deleted).

# ── DS-5 ──
# (SKILL.md / deep-scan-gate.md / deep-scan-dispatch.md arms RETIRED 9.0 P1 —
#  scan-codebase deleted; the codebase-map snapshot type, whose `EMPTY for this
#  type` sha map the old arm pinned, was removed from the schema with its producer.)
if grep -q '30-50%' "$SSS"; then fail "DS-5: fabricated ~30-50% figure survives in $(basename "$SSS")"; else ok "DS-5: fabricated perf figure absent from the snapshot schema"; fi
# Repointed schema-field-doc truth: the map is documented for its ONE live type
# and the consumer it names (plan --kb) actually reads it (cross-doc agreement).
grep -qF '`source_files_sha256_map` — populated for the `extracted-kb` type ONLY (the `plan --kb` freshness check reads it' "$SSS" \
  && grep -qF '`source_files_sha256_map` the same way' "$KBI" \
  && ok "DS-5: schema scopes source_files_sha256_map to extracted-kb and plan --kb reads it" \
  || fail "DS-5: schema field doc / plan --kb consumer disagree on source_files_sha256_map"

# ── DS-7 / DS-8 ── RETIRED 9.0 P1: <FILE_HINTS> and the deep-scan trigger enum
#   pinned deep-scan-prompts.md / deep-scan-gate.md / scan SKILL.md (deleted).

if [ "$FAILED" -eq 0 ]; then note "ALL 3F OK"; else note "3F had failures"; fi
exit $FAILED

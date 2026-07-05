#!/usr/bin/env bash
# test-3f-contract-truth.sh — god-review stage 3, Batch 3F.
# Pins the contract & prose-truth alignment: docs must not claim mechanisms,
# fields, numbers, or enforcement that don't exist; cross-doc contracts agree.
#
#   INT-3  handoff next_action is CWD-conditional in the OPERATIVE copy (incl.
#          the Mode D detect-drift branch); SKILL.md hand-off aligned.
#   INT-4  reuse-index.yaml + shared snapshot listed in handoff artifacts.
#   INT-6  symbol-graph attribution: scan does NOT persist reference captures;
#          generate-units owns the build + the paths.md cache row.
#   V3     "read-only enforced at dispatch" fiction → honest rules-tier wording.
#   V4     §3(routes)/§4(data models) numbering agrees across schema, validator,
#          implementation-state.md, oq-resolution.md, tree-sitter-integration.md.
#   AH-3   truncation gets a schema marker + absence-in-truncated-section→UNKNOWN;
#          the ghost "file scan log" pointer is gone.
#   AH-4   libs slice carries _source under a manifest grammar on all surfaces.
#   DS-3   "§file-lock" anchor exists in memory/SKILL.md (heals ~6 citations).
#   DS-4   4th cross-cutting rail: untrusted-data fence + MANIFEST_FACTS data fence.
#   DS-5   dead snapshot claims removed (no re-tokenization shortcut, no ~30-50%);
#          source_files_sha256_map written empty for codebase-map type.
#   DS-7   no bare <FILE_HINTS> ghost variable in the prompt templates.
#   DS-8   deep-scan trigger specified in the string-enum domain, naming fallback.
#
# Run: bash tests/god-review-s3/test-3f-contract-truth.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
SK="$P/skills/scan-codebase/SKILL.md"
SP="$P/skills/scan-codebase/references/scan-procedure.md"
HFH="$P/skills/scan-codebase/references/halts-flags-handoff.md"
DSS="$P/skills/scan-codebase/references/deep-scan-stage.md"
DSP="$P/skills/scan-codebase/references/deep-scan-prompts.md"
CMS="$P/skills/scan-codebase/references/codebase-map-schema.md"
TSI="$P/skills/scan-codebase/references/tree-sitter-integration.md"
IMS="$P/skills/bind-codebase/references/implementation-state.md"
OQR="$P/skills/bind-codebase/references/oq-resolution.md"
HC="$P/skills/orchestrate-flow/references/handoff-contract.md"
SSS="$P/references/shared-snapshot-schema.md"
SCS="$P/references/starterkit-context-schema.md"
PTH="$P/references/paths.md"
PRT="$P/skills/generate-units/references/pagerank-targeting.md"
MEM="$P/skills/memory/SKILL.md"
for f in "$SK" "$SP" "$HFH" "$DSS" "$DSP" "$CMS" "$TSI" "$IMS" "$OQR" "$HC" "$SSS" "$SCS" "$PTH" "$PRT" "$MEM"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 3F: contract & prose-truth =="

# ── INT-3 ── (Mode D detect-drift handoff is now the canonical SCOPED branch —
#   scan hands off `detect-drift ... --scope=@<vault>/.sync-changed-paths.txt --auto`;
#   the pre-sync-lane bare `mega-sdd:detect-drift --auto` was superseded by B4/B5/B6.)
grep -qF 'CWD-CONDITIONAL' "$HFH" && grep -qF 'mega-sdd:detect-drift' "$HFH" && grep -qF '.sync-changed-paths.txt' "$HFH" \
  && ok "INT-3: operative handoff next_action is CWD-conditional incl. scoped Mode D detect-drift branch" || fail "INT-3: operative copy still unconditional / missing scoped Mode D branch"
grep -qF 'CWD-conditional' "$SK" && ok "INT-3: SKILL.md next-step suggestion aligned" || fail "INT-3: SKILL.md still unconditional"
grep -qF 'mega-sdd:detect-drift' "$HC" && grep -qF '.sync-changed-paths.txt' "$HC" \
  && ok "INT-3: handoff-contract mirror carries the scoped Mode D detect-drift branch" || fail "INT-3: contract mirror missing scoped Mode D branch"

# ── INT-4 ──
grep -qF 'reuse-index.yaml>          # only when deep-scan ran' "$HFH" \
  && grep -qF 'codebase-map.snapshot.json>  # only when Step 10.6 wrote it' "$HFH" \
  && ok "INT-4: reuse-index + snapshot listed in handoff artifacts (conditional)" || fail "INT-4: artifacts list incomplete"
if grep -qF 'reuse_index: { path:' "$DSS"; then fail "INT-4: phantom reuse_index handoff field survives"; else ok "INT-4: phantom reuse_index handoff field removed"; fi

# ── INT-6 ──
grep -qF 'NOT persisted by scan-codebase' "$SP" && ok "INT-6: scan-procedure — reference captures not persisted" || fail "INT-6: scan-procedure still claims a symbol-graph channel"
grep -qF 'built by `generate-units` itself' "$PRT" && ok "INT-6: pagerank-targeting — generate-units owns the build" || fail "INT-6: pagerank cache still scan-attributed"
grep -qE '^\| .generate-units. \| symbol-graph \|' "$PTH" && ok "INT-6: paths.md symbol-graph owner → generate-units" || fail "INT-6: paths.md owner not fixed"
# round-2: sibling generate-units surface (task-typing) must not re-attribute to scan
if grep -qF 'per scan-codebase run' "$P/skills/generate-units/references/task-typing.md"; then
  fail "r2: task-typing.md still says 'per scan-codebase run'"
else
  ok "r2: task-typing.md attribution corrected"
fi

# ── V3 ──
if grep -qF 'Read-only enforced at dispatch' "$HFH"; then fail "V3: enforcement fiction survives"; else ok "V3: 'enforced at dispatch' fiction removed"; fi
grep -qF 'not a dispatch-level tool restriction' "$HFH" && ok "V3: honest rules-tier wording present" || fail "V3: honest wording missing"

# ── V4: §3=Routes / §4=Data models everywhere ──
grep -qF 'Route in codebase-map §3' "$IMS" && grep -qF 'Entity in §4' "$IMS" && grep -qF 'Entity not in §4' "$IMS" \
  && grep -qF 'Codebase-map §3: POST /api/login' "$IMS" \
  && ok "V4: implementation-state.md un-inverted (routes=§3, entities=§4)" || fail "V4: implementation-state still inverted"
grep -qF 'entity name → §4 (data models); endpoint path → §3 (routes)' "$OQR" && grep -qF '§4 entry: User table line 42' "$OQR" \
  && ok "V4: oq-resolution.md un-inverted" || fail "V4: oq-resolution still inverted"
grep -qF '§3 (routes) + §4 (data models)' "$TSI" && ok "V4: tree-sitter-integration.md un-inverted" || fail "V4: tree-sitter ref still inverted"
# round-2: NO inverted reference anywhere in the plugin (the class, not the instances)
if rtk proxy grep -rn --include="*.md" -e '§4 (routes)' -e '§3 (data models)' "$P" >/dev/null 2>&1 || \
   grep -rn --include="*.md" -e '§4 (routes)' -e '§3 (data models)' "$P" >/dev/null 2>&1; then
  fail "r2: an inverted §3/§4 reference survives somewhere in the plugin"
else
  ok "r2: plugin-wide negative grep — no inverted §3/§4 reference remains"
fi

# ── AH-3 ──
grep -qF 'truncated_sections' "$CMS" && grep -qF 'classify UNKNOWN' "$CMS" \
  && ok "AH-3: schema carries truncated_sections + UNKNOWN consumer rule" || fail "AH-3: truncation marker/rule missing from schema"
if grep -qF 'file scan log' "$HFH"; then fail "AH-3: ghost 'file scan log' pointer survives"; else ok "AH-3: ghost scan-log pointer removed"; fi
grep -qF 'truncated_sections' "$HFH" && ok "AH-3: cap-200 rail stamps the marker" || fail "AH-3: rail not tied to the marker"
# round-2: the consumer rule must live on the BINDER side too (bind-codebase loads
# its own references, not scan-codebase's schema doc — a one-sided contract is dead).
grep -qF 'truncated_sections' "$P/skills/bind-codebase/references/implementation-state.md" \
  && grep -qF 'truncated_sections' "$P/skills/bind-codebase/references/binding-contract.md" \
  && ok "r2: truncated_sections→UNKNOWN rule present in bind-codebase's own references" \
  || fail "r2: AH-3 rule still one-sided (missing on the binder side)"

# ── AH-4 ──
grep -qF '_source: ["<manifest filename of the ecosystem block' "$DSP" && ok "AH-4: libs prompt OUTPUT FORMAT carries _source" || fail "AH-4: libs prompt _source missing"
grep -qF '_source: ["composer.json"]' "$SCS" && ok "AH-4: schema §libs carries _source" || fail "AH-4: schema §libs _source missing"
grep -qF 'names the MANIFEST whose ecosystem block produced the entry' "$SCS" && ok "AH-4: citation rail defines the libs _source grammar" || fail "AH-4: rail grammar missing"

# ── DS-3 ──
grep -qF '### file-lock' "$MEM" && ok "DS-3: memory/SKILL.md now has the §file-lock anchor" || fail "DS-3: §file-lock anchor still dangling"
grep -qF 'memory-write.sh' "$MEM" && ok "DS-3: anchor points at the deterministic implementation" || fail "DS-3: anchor lacks the script pointer"

# ── DS-4 ──
grep -qF 'the same 4 rails verbatim' "$DSP" && grep -qF 'Untrusted-data fence' "$DSP" \
  && ok "DS-4: 4th cross-cutting rail (untrusted-data fence) present" || fail "DS-4: untrusted-data rail missing"
grep -qF 'DATA FENCE' "$DSP" && ok "DS-4: MANIFEST_FACTS injection block is data-fenced" || fail "DS-4: injection block not fenced"
# round-2 (fix-review): the fence must be INSIDE each of the 5 prompt templates —
# a rails-section claim alone never reaches a dispatched subagent.
FENCE_N=$(grep -cF 'UNTRUSTED-DATA FENCE' "$DSP")
[ "$FENCE_N" -ge 5 ] && ok "r2: fence line present in all 5 templates ($FENCE_N occurrences)" \
  || fail "r2: fence in only $FENCE_N template(s) — '4 rails verbatim' is false again"
grep -qF 'DATA-FENCE comment' "$DSS" && ok "r2: dispatcher-side build step emits the fence with manifest_facts" || fail "r2: dispatcher build step not fenced"

# ── DS-5 ──
for f in "$SK" "$DSS" "$SSS"; do
  if grep -q '30-50%' "$f"; then fail "DS-5: fabricated ~30-50% figure survives in $(basename "$f")"; fi
done
grep -q '30-50%' "$SK" "$DSS" "$SSS" || ok "DS-5: fabricated perf figure removed from all 3 surfaces"
if grep -qF 'skip re-tokenization' "$SK"; then fail "DS-5: SKILL.md still claims the re-tokenization skip"; else ok "DS-5: SKILL.md snapshot claim is freshness-attestation"; fi
grep -qF '"source_files_sha256_map": {}' "$DSS" && ok "DS-5: codebase-map snapshot writes source_files_sha256_map EMPTY" || fail "DS-5: write-only sha map still built"
grep -qF 'EMPTY for this type' "$SSS" && ok "DS-5: schema documents the empty map for codebase-map type" || fail "DS-5: schema field doc stale"

# ── DS-7 ──
if grep -qE '<FILE_HINTS>' "$DSP"; then fail "DS-7: bare <FILE_HINTS> ghost variable survives"; else ok "DS-7: no bare <FILE_HINTS> token (only domain-prefixed hint vars)"; fi

# ── DS-8 ──
if grep -qF '≥ 0.5' "$DSS" || grep -qF '≥ 0.5' "$SK"; then fail "DS-8: numeric ≥0.5 trigger grammar survives"; else ok "DS-8: numeric trigger grammar removed"; fi
grep -qF 'in {high, medium}' "$DSS" && grep -qF 'low OR fallback' "$DSS" && ok "DS-8: trigger in the string-enum domain, fallback named" || fail "DS-8: enum trigger incomplete"
grep -qF '`low`/`fallback` → skip' "$SK" && ok "DS-8: SKILL.md trigger line enum-domain" || fail "DS-8: SKILL.md trigger stale"

if [ "$FAILED" -eq 0 ]; then note "ALL 3F OK"; else note "3F had failures"; fi
exit $FAILED

#!/usr/bin/env bash
# test-p2a-consumer-guide.sh — batch2 P2a (spec 2026-07-19-batch2-derive-and-diet.md):
# the 00-index generic consumer spine ships as a STATIC guide installed by script —
# zero model output tokens, byte-identical across vaults.
#
#   1  shipped guide exists + carries the moved content (halt YAML, parallel-work,
#      companion skills, standard terms) — moved, not lost
#   2  templates/00-index.md no longer carries the moved blocks (negative pins) but
#      keeps Anti-hallucination rules + the Implementation Notes heading + the
#      _meta/ai-consumer-guide.md pointer
#   3  SKILL.md carries the Step-3 cp one-liner (v7: script demoted); self-check pins
#      rewritten (all three spine pins → guide-existence + pointer checks)
#   4  EMPIRICAL: the Step-3 cp installs a cksum-identical copy; second
#      run idempotent (byte-identical); exit 0
#
# Run: bash tests/boilerplate-diet/test-p2a-consumer-guide.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
GUIDE="$P/skills/generate-intent/references/templates/ai-consumer-guide.md"
IDX="$P/skills/generate-intent/references/templates/vault.md"   # v7 Fase 3 layout-2
SKILL="$P/skills/generate-intent/SKILL.md"
GG="$P/skills/generate-intent/references/generation-guide.md"
SC="$P/skills/generate-intent/references/self-check.md"

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p2a)"
trap 'rm -rf "$WORK"' EXIT

echo "== P2a: consumer guide is shipped static, script-installed =="

# ── 1: shipped guide carries the moved content ──
[ -f "$GUIDE" ] && ok "1: shipped guide exists" || { fail "1: shipped guide missing"; }
grep -qF 'blocker:' "$GUIDE" && grep -qF 'resolver_route' "$GUIDE" \
  && ok "1: halt-YAML examples moved into the guide" || fail "1: halt-YAML examples lost"
grep -qF 'blockers:' "$GUIDE" && ok "1: multi-blocker array example present" || fail "1: array example lost"
grep -qF 'oq_blocker' "$GUIDE" && grep -qiF 'backward compat' "$GUIDE" \
  && ok "1: backward-compat note moved" || fail "1: backward-compat note lost"
grep -qF 'Parallel-work' "$GUIDE" && ok "1: parallel-work guidance moved" || fail "1: parallel-work guidance lost"
grep -qF 'resolve-oq' "$GUIDE" && grep -qF 'diff-vault' "$GUIDE" && grep -qF 'detect-drift' "$GUIDE" \
  && ok "1: companion-skills routing moved" || fail "1: companion-skills routing lost"
grep -qF 'MANDATORY before writing/modifying any code' "$GUIDE" \
  && ok "1: mode cross-check checklists moved" || fail "1: cross-check checklists lost"
grep -qF '| ADR |' "$GUIDE" && grep -qF '| DBML |' "$GUIDE" && grep -qF '| SLO |' "$GUIDE" \
  && ok "1: standard-terms generic rows moved" || fail "1: standard-terms rows lost"
grep -qF 'do not hand-edit' "$GUIDE" && ok "1: static-copy header note present" || fail "1: static header note missing"

# ── 2: vault.md template diet landed (v7 layout-2: the 00-index ceremony —
#      incl. the generic anti-halu restatement — lives ONLY in the guide now) ──
if grep -qF 'resolver_route' "$IDX"; then fail "2: vault.md template still carries the halt-YAML spine (resolver_route)"; else ok "2: halt-YAML spine gone from vault.md template"; fi
if grep -qF 'blockers:' "$IDX"; then fail "2: blockers: fence survives in vault.md template"; else ok "2: no blockers: fence in vault.md template"; fi
if grep -qF 'Parallel-work guidance while P1s are unresolved' "$IDX"; then fail "2: parallel-work section survives in template"; else ok "2: parallel-work section gone from template"; fi
if grep -qF 'Companion skills for vault evolution' "$IDX"; then fail "2: companion-skills section survives in template"; else ok "2: companion-skills section gone from template"; fi
grep -qF 'Do not inject requirements' "$GUIDE" && ok "2: anti-halu consumer rules live in the guide (template restatement retired v7)" || fail "2: anti-halu rules missing from the guide"
grep -qF 'vault_layout: 2' "$IDX" && ok "2: template is layout-2 (frontmatter marker)" || fail "2: vault.md template missing the layout marker"
grep -qF '_meta/ai-consumer-guide.md' "$IDX" && ok "2: guide pointer present in template" || fail "2: guide pointer missing from template"
grep -qF 'kb_module_graph' "$IDX" && ok "2: kb_module_graph slot survives" || fail "2: kb_module_graph slot lost"
if grep -qF '| ADR |' "$IDX"; then fail "2: generic glossary rows survive in template"; else ok "2: generic glossary rows gone (guide pointer instead)"; fi

# ── 3: workflow + self-check wiring ──
grep -qF 'cp "$PLUGIN_ROOT/skills/generate-intent/references/templates/ai-consumer-guide.md"' "$SKILL" && ok "3: SKILL Step 3 carries the cp one-liner (script demoted v7)" || fail "3: SKILL cp one-liner missing"
grep -qF 'the Step-3 `cp` of the shipped template' "$GG" && ok "3: generation-guide names the Step-3 cp" || fail "3: generation-guide cp note missing"
grep -qF 'ai-consumer-guide.md' "$SKILL" && ok "3: SKILL output contract shows _meta/ai-consumer-guide.md" || fail "3: output contract missing the guide"
grep -qF '_meta/ai-consumer-guide.md' "$SC" && ok "3: self-check pins guide existence" || fail "3: self-check guide-existence pin missing"
grep -qF 'resolver_route' "$SC" && ok "3: self-check carries the no-halt-YAML-in-00-index regression check" || fail "3: self-check regression check missing"
# all three legacy spine pins rewritten (the old sub-section-presence checks are gone)
LEGACY=0
grep -qF 'contains "Halt protocol for autonomous runs"' "$SC" && { fail "3: legacy Halt-protocol spine pin survives in self-check"; LEGACY=1; }
grep -qF 'contains "Parallel-work guidance' "$SC" && { fail "3: legacy Parallel-work spine pin survives in self-check"; LEGACY=1; }
grep -qF 'contains "Companion skills for vault evolution"' "$SC" && { fail "3: legacy Companion-skills spine pin survives in self-check"; LEGACY=1; }
[ "$LEGACY" = "0" ] && ok "3: all three spine pins rewritten to guide-existence + pointer checks"
# generation-guide no longer mandates the generic glossary rows per-vault
if grep -qE 'MUST have a \*\*Glossary\*\* for cross-doc terms: DBML' "$GG"; then fail "3: generation-guide still mandates generic rows in 00-index"; else ok "3: generation-guide glossary policy rewritten (no re-emitted generic rows)"; fi

# ── 4: EMPIRICAL — the SKILL's cp one-liner installs a byte-identical copy ──
# (v7: copy-consumer-guide.sh demoted to this cp; run the documented command.)
V="$WORK/vault"; mkdir -p "$V/_meta"
cp "$GUIDE" "$V/_meta/ai-consumer-guide.md" && ok "4: cp install exit 0" || fail "4: cp failed"
S1="$(cksum < "$GUIDE")"; S2="$(cksum < "$V/_meta/ai-consumer-guide.md" 2>/dev/null || echo differ)"
[ "$S1" = "$S2" ] && ok "4: installed copy cksum-identical to shipped guide" || fail "4: copy differs from shipped guide"
cp "$GUIDE" "$V/_meta/ai-consumer-guide.md" && [ "$S1" = "$(cksum < "$V/_meta/ai-consumer-guide.md")" ] \
  && ok "4: second run idempotent (byte-identical)" || fail "4: re-run not idempotent"

if [ "$FAILED" -eq 0 ]; then echo "ALL P2A PINS OK"; exit 0; else echo "P2A pins FAILED"; exit 1; fi

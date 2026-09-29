#!/usr/bin/env bash
# test-p2a-consumer-guide.sh — batch2 P2a (batch2 spec, commit a950422c):
# the 00-index generic consumer spine ships as a STATIC guide installed by script —
# zero model output tokens, byte-identical across vaults.
#
#   1  shipped guide exists + carries the moved content (halt YAML, parallel-work,
#      companion skills, standard terms) — moved, not lost
#   2  the per-vault template no longer carries the moved blocks (negative pins) —
#      9.0: the per-vault template is plan's layout-3 `context.md` (the layout-2
#      `vault.md` template died with generate-intent)
#   3  plan SKILL.md carries the Step-3 cp one-liner + lists the guide in its Output
#      contract; the Step-7 self-check pins guide existence + the no-halt-YAML
#      regression (legacy sub-section-presence spine pins stay gone)
#   4  EMPIRICAL: the source path the SKILL's cp names resolves to the shipped
#      guide; the cp installs a cksum-identical copy; second run idempotent; exit 0
#
# 9.0 P1 (spec 2026-09-27 §2/§7): generate-intent was deleted; the guide, the
# Step-3 cp, the generation-guide glossary policy and the self-check were relocated
# into skills/plan/ (templates/ai-consumer-guide.md, SKILL.md Step 3,
# references/context-authoring.md) — pins repointed there. Retired with the
# layout-2 vault.md template: its in-template `_meta/ai-consumer-guide.md` pointer
# line (layout-3 context.md never carried one; the guide is wired via plan's Output
# contract + Step-3 cp + Step-7 self-check, all pinned in §3). Repointed: the layout
# marker (`vault_layout: 2` -> the context.md template's `vault_layout: 3`) and the
# `kb_module_graph` slot (the pointer contract now lives in plan/references/kb-input.md).
#
# Run: bash tests/boilerplate-diet/test-p2a-consumer-guide.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
GUIDE="$P/skills/plan/references/templates/ai-consumer-guide.md"
IDX="$P/skills/plan/references/templates/context.md"   # 9.0: layout-3 per-vault template (was generate-intent vault.md)
SKILL="$P/skills/plan/SKILL.md"
GG="$P/skills/plan/references/context-authoring.md"    # generation-guide authoring rules relocated here
SC="$P/skills/plan/references/context-authoring.md"    # self-check relocated here (§Step 7)
KBI="$P/skills/plan/references/kb-input.md"
# the Step-7 self-check section of context-authoring.md (pins scoped to it, not the whole file)
SC_STEP7="$(awk '/^## Step 7/{f=1} f' "$SC" 2>/dev/null)"

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

# ── 2: per-vault template diet holds (9.0: plan's layout-3 context.md template;
#      the generic consumer ceremony lives ONLY in the guide) ──
[ -f "$IDX" ] && ok "2: per-vault template (plan context.md) exists" || fail "2: per-vault template missing"
if grep -qF 'resolver_route' "$IDX"; then fail "2: context.md template carries the halt-YAML spine (resolver_route)"; else ok "2: halt-YAML spine absent from context.md template"; fi
if grep -qF 'blockers:' "$IDX"; then fail "2: blockers: fence in context.md template"; else ok "2: no blockers: fence in context.md template"; fi
if grep -qF 'Parallel-work guidance while P1s are unresolved' "$IDX"; then fail "2: parallel-work section in template"; else ok "2: parallel-work section absent from template"; fi
if grep -qF 'Companion skills for vault evolution' "$IDX"; then fail "2: companion-skills section in template"; else ok "2: companion-skills section absent from template"; fi
grep -qF 'Do not inject requirements' "$GUIDE" && ok "2: anti-halu consumer rules live in the guide (template restatement retired v7)" || fail "2: anti-halu rules missing from the guide"
grep -qF 'vault_layout: 3' "$IDX" && ok "2: template is layout-3 (frontmatter marker)" || fail "2: context.md template missing the layout-3 marker"
# kb_module_graph: the layout-2 template's commented slot is retired with it; the surviving
# contract is plan --kb recording the pointer in context.md frontmatter (kb-input.md).
grep -qF 'frontmatter pointer `kb_module_graph: <path>`' "$KBI" \
  && ok "2: kb_module_graph context.md frontmatter pointer survives (plan kb-input)" || fail "2: kb_module_graph pointer contract lost"
if grep -qF '| ADR |' "$IDX"; then fail "2: generic glossary rows in template"; else ok "2: generic glossary rows absent (guide carries them)"; fi

# ── 3: workflow + self-check wiring ──
grep -qF 'cp "<plugin-root>/skills/plan/references/templates/ai-consumer-guide.md" <vault>/_meta/ai-consumer-guide.md' "$SKILL" && ok "3: plan SKILL Step 3 carries the cp one-liner" || fail "3: plan SKILL cp one-liner missing"
grep -qF 'the Step-3 `cp` of the shipped template' "$GG" && ok "3: authoring rules (context-authoring) name the Step-3 cp" || fail "3: context-authoring cp note missing"
grep -qE '^- \*\*Output:\*\*.*_meta/ai-consumer-guide\.md' "$SKILL" && ok "3: plan SKILL output contract shows _meta/ai-consumer-guide.md" || fail "3: output contract missing the guide"
printf '%s\n' "$SC_STEP7" | grep -qF '<vault>/_meta/ai-consumer-guide.md` exists' && ok "3: self-check (Step 7) pins guide existence" || fail "3: self-check guide-existence pin missing"
printf '%s\n' "$SC_STEP7" | grep -qF 'resolver_route' && ok "3: self-check (Step 7) carries the no-halt-YAML regression check" || fail "3: self-check regression check missing"
# all three legacy spine pins rewritten (the old sub-section-presence checks are gone)
LEGACY=0
grep -qF 'contains "Halt protocol for autonomous runs"' "$SC" && { fail "3: legacy Halt-protocol spine pin survives in self-check"; LEGACY=1; }
grep -qF 'contains "Parallel-work guidance' "$SC" && { fail "3: legacy Parallel-work spine pin survives in self-check"; LEGACY=1; }
grep -qF 'contains "Companion skills for vault evolution"' "$SC" && { fail "3: legacy Companion-skills spine pin survives in self-check"; LEGACY=1; }
[ "$LEGACY" = "0" ] && ok "3: all three spine pins rewritten to guide-existence + pointer checks"
# the authoring rules (ex-generation-guide) no longer mandate the generic glossary rows per-vault
if grep -qE 'MUST have a \*\*Glossary\*\* for cross-doc terms: DBML' "$GG"; then fail "3: authoring rules still mandate generic glossary rows"; else ok "3: glossary policy rewritten (no re-emitted generic rows)"; fi

# ── 4: EMPIRICAL — the SKILL's documented cp installs a byte-identical copy ──
# (v7: copy-consumer-guide.sh demoted to this cp; resolve the source path the SKILL
#  names against the plugin root and run the documented copy.)
V="$WORK/vault"; mkdir -p "$V/_meta"
SRC_REL="$(grep -oE 'cp "<plugin-root>/[^"]+" <vault>/_meta/ai-consumer-guide\.md' "$SKILL" | head -1 | sed -E 's#^cp "<plugin-root>/([^"]+)".*#\1#')"
[ -n "$SRC_REL" ] && [ "$P/$SRC_REL" = "$GUIDE" ] && [ -f "$P/$SRC_REL" ] \
  && ok "4: SKILL cp source resolves to the shipped guide ($SRC_REL)" || fail "4: SKILL cp source does not resolve to the shipped guide (got: '${SRC_REL}')"
cp "$GUIDE" "$V/_meta/ai-consumer-guide.md" && ok "4: cp install exit 0" || fail "4: cp failed"
S1="$(cksum < "$GUIDE")"; S2="$(cksum < "$V/_meta/ai-consumer-guide.md" 2>/dev/null || echo differ)"
[ "$S1" = "$S2" ] && ok "4: installed copy cksum-identical to shipped guide" || fail "4: copy differs from shipped guide"
cp "$GUIDE" "$V/_meta/ai-consumer-guide.md" && [ "$S1" = "$(cksum < "$V/_meta/ai-consumer-guide.md")" ] \
  && ok "4: second run idempotent (byte-identical)" || fail "4: re-run not idempotent"

if [ "$FAILED" -eq 0 ]; then echo "ALL P2A PINS OK"; exit 0; else echo "P2A pins FAILED"; exit 1; fi

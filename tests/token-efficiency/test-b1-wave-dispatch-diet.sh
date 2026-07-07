#!/usr/bin/env bash
# test-b1-wave-dispatch-diet.sh — token-efficiency Batch B1 (finding M-01).
# Pins the wave-dispatch prompt diet WITHOUT losing any guarantee:
#
#   SLICE   the skeleton injects <STACK_IDIOM_ROWS> (dispatcher-sliced) instead of
#           the full 8-stack table; the MASTER table survives dispatcher-side as
#           the single authoritative copy (all 9 principle rows, all 8 stacks);
#           slicing rules pinned: UNION of detected stacks, full-table fallback,
#           mapped-columns-only for partially-unmapped mixes, never-empty.
#   GLOSS   glossary_index is one-line-per-term with an ~80-char short_def cap;
#           citation format + spot-read discipline unchanged; the usage
#           instruction appears ONCE per prompt (duplicate blockquote gone).
#   DELTA   the skeleton DISCIPLINE block carries only the deltas the
#           domain-extractor agent body lacks (same-line citation + §11,
#           [INTENT]-default + positive-evidence tiers, .bak-vs-live) plus a
#           hedge naming the agent-body rails; the rails themselves survive
#           verbatim in agents/domain-extractor.md (loads on every dispatch).
#   SPEC    the emission change is amended into the tech-agnostic spec.
#
# Run: bash tests/token-efficiency/test-b1-wave-dispatch-diet.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WDT="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md"
AG="${ROOT}/plugins/mega-sdd/agents/domain-extractor.md"
SK="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
SPEC="${ROOT}/docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md"
for f in "$WDT" "$AG" "$SK" "$SPEC"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== B1: wave-dispatch prompt diet (M-01) =="

# ── SLICE: placeholder in the skeleton; master table dispatcher-side ──
grep -qF '<STACK_IDIOM_ROWS>' "$WDT" && ok "SLICE: <STACK_IDIOM_ROWS> placeholder present" || fail "SLICE: placeholder missing"
grep -qF 'reason by analogy from the closest idiom' "$WDT" && ok "SLICE: reason-by-analogy line retained in the skeleton" || fail "SLICE: analogy fallback line lost"
N_HDR=$(grep -cF '| Principle | PHP | JS / TS | Python | C# / .NET | Java | Go | Ruby | Rust |' "$WDT")
[ "$N_HDR" = "1" ] && ok "SLICE: full 8-stack table appears exactly ONCE (dispatcher-side master)" || fail "SLICE: expected exactly 1 master table, found $N_HDR"
grep -qF 'MASTER STACK IDIOM TABLE' "$WDT" && ok "SLICE: master table labeled dispatcher-side" || fail "SLICE: master table label missing"
N_ROWS=$(grep -cE '^\| \*\*P[1-6]\*\*' "$WDT")
[ "$N_ROWS" = "9" ] && ok "SLICE: all 9 principle rows survive in the master (P1×2, P2, P3×2, P6×4)" || fail "SLICE: expected 9 principle rows, found $N_ROWS"
# the master must come AFTER the skeleton's closing fence (not inside the prompt)
python3 - "$WDT" <<'PY' && ok "SLICE: master table sits OUTSIDE the generic prompt skeleton" || fail "SLICE: master table still inside the skeleton fence"
import sys
doc = open(sys.argv[1]).read()
skeleton_start = doc.find("Every wave's subagent prompt MUST follow this skeleton")
fence_open = doc.find("```", skeleton_start)
fence_close = doc.find("```", fence_open + 3)
master = doc.find("MASTER STACK IDIOM TABLE")
assert skeleton_start > 0 and fence_close > 0 and master > 0
sys.exit(0 if master > fence_close else 1)
PY
# review round: the SUBSTITUTABLE placeholder line must sit INSIDE the fence and be
# the token's ONLY in-skeleton occurrence — delete it and every subagent loses its
# idiom rows (the exact guarantee-loss this diet risks); a second in-fence mention
# would garble a mechanical find-replace.
python3 - "$WDT" <<'PY' && ok "SLICE: standalone placeholder line INSIDE the fence, exactly once (mechanical substitution safe)" || fail "SLICE: in-skeleton placeholder missing/duplicated"
import sys
doc = open(sys.argv[1]).read()
skeleton_start = doc.find("Every wave's subagent prompt MUST follow this skeleton")
fence_open = doc.find("```", skeleton_start)
fence_close = doc.find("```", fence_open + 3)
fence = doc[fence_open:fence_close]
standalone = [ln for ln in fence.splitlines() if ln.strip() == "<STACK_IDIOM_ROWS>"]
mentions = fence.count("<STACK_IDIOM_ROWS>")
sys.exit(0 if (len(standalone) == 1 and mentions == 1) else 1)
PY
grep -qF 'replace exactly that line' "$WDT" && ok "SLICE: substitution-target rule pinned (standalone line only)" || fail "SLICE: substitution-target rule missing"
grep -qF 'SAME alias convention as `scripts/kb-leak-scan.sh` `LANG_MAP`' "$WDT" && ok "SLICE: language aliases anchored to the canonical LANG_MAP (kotlin→Java, node→JS/TS, …)" || fail "SLICE: alias mapping not anchored to LANG_MAP"
grep -qF '"vb.net": "csharp"' "${ROOT}/plugins/mega-sdd/scripts/kb-leak-scan.sh" && ok "SLICE: kb-leak-scan LANG_MAP covers VB.NET (two consumers aligned)" || fail "SLICE: LANG_MAP missing vb.net"
if grep -qF 'see the STACK IDIOM TABLE below' "$WDT"; then fail "SLICE: P1 dangling reference to the renamed table survives"; else ok "SLICE: P1 pointer follows the rename (STACK IDIOMS rows)"; fi
grep -qF 'UNION of languages in the Wave 0 enumeration' "$WDT" && ok "SLICE: UNION-of-detected-stacks rule pinned (multi-stack gets every column)" || fail "SLICE: UNION rule missing"
grep -qF 'Fallback — inject the FULL table' "$WDT" && ok "SLICE: full-table fallback on empty/unmapped detection" || fail "SLICE: fallback rule missing"
grep -qF 'Never dispatch with an empty `<STACK_IDIOM_ROWS>`' "$WDT" && ok "SLICE: never-empty guarantee pinned" || fail "SLICE: never-empty rule missing"
grep -qF 'inject the mapped columns' "$WDT" && ok "SLICE: partially-unmapped mix injects mapped columns (no needless full-table)" || fail "SLICE: mixed-case rule missing"
grep -qF 'typescript/ts → `JS / TS`' "$WDT" && ok "SLICE: language→column mapping documented (JS/TS shared, aliases enumerated)" || fail "SLICE: column mapping missing"
grep -qF 'map to no column and are ignored' "$WDT" && ok "SLICE: markup/data-only languages (HTML/CSS/SQL) excluded from slicing" || fail "SLICE: non-code-language rule missing"

# ── GLOSS: one-line index + single instruction ──
grep -qF 'glossary_index (term: short_def (L<start>-<end>))' "$WDT" && ok "GLOSS: one-line-per-term index format" || fail "GLOSS: compact format missing"
grep -qF '~80 chars' "$WDT" && ok "GLOSS: short_def cap (~80 chars) pinned" || fail "GLOSS: cap missing"
if grep -qF 'short_def: "' "$WDT"; then fail "GLOSS: old YAML-verbose index format survives"; else ok "GLOSS: YAML-verbose form removed"; fi
grep -qF 'glossary.md §customer-onboarding:42-58' "$WDT" && ok "GLOSS: citation format unchanged (spot-read line ranges)" || fail "GLOSS: citation format lost"
if grep -qF 'Subagent instruction (appended to Wave 2/3/4 prompts)' "$WDT"; then fail "GLOSS: duplicated usage instruction survives (stated twice per prompt)"; else ok "GLOSS: usage instruction appears once (skeleton block is the single copy)"; fi
grep -qF 'ONLY spot-read glossary.md' "$WDT" && ok "GLOSS: spot-read discipline retained in the skeleton block" || fail "GLOSS: spot-read discipline lost"

# ── DELTA: skeleton keeps only what the agent body lacks; rails live in the agent ──
grep -qF 'DISCIPLINE DELTAS' "$WDT" && ok "DELTA: skeleton block renamed to deltas" || fail "DELTA: deltas block missing"
grep -qF 'ON THE SAME LINE as the marker' "$WDT" && ok "DELTA: same-line citation + §11 rule retained (agent body lacks it)" || fail "DELTA: same-line citation rule lost"
grep -qF 'uncertain → [INTENT]' "$WDT" && ok "DELTA: [INTENT]-default + positive-evidence tiers retained" || fail "DELTA: INTENT-default lost"
grep -qF 'Compare .bak / dated files' "$WDT" && ok "DELTA: .bak-vs-live comparison retained" || fail "DELTA: .bak rule lost"
grep -qF 'your agent body already carries the core rails' "$WDT" && ok "DELTA: hedge names the agent-body rails explicitly" || fail "DELTA: hedge line missing"
# rails must survive in the agent system prompt (loads on every dispatch)
grep -qF 'Cite every claim' "$AG" && grep -qF '[VERIFIED]' "$AG" && grep -qF '[INTENT]' "$AG" \
  && grep -qF 'never a guess' "$AG" && grep -qF 'Tech-agnostic vocabulary' "$AG" \
  && ok "DELTA: core rails verbatim in agents/domain-extractor.md (per-dispatch system prompt)" \
  || fail "DELTA: a core rail is missing from the agent body — the cut is unsafe"
# the deleted generic rails must NOT silently vanish from the prompt path entirely:
# tech-agnostic scoping still reaches the prompt via the CONTEXT block
grep -qF 'Output MUST BE TECH-AGNOSTIC — no legacy stack terms outside §11' "$WDT" && ok "DELTA: tech-agnostic §11/50-integrations scoping survives in the CONTEXT block" || fail "DELTA: tech-agnostic scoping lost from the prompt"

# ── SPEC + SKILL prose ──
grep -qF 'Amendment (2026-07-06, token-efficiency Batch B1' "$SPEC" && ok "SPEC: emission-change amendment recorded" || fail "SPEC: amendment missing"
grep -qF 'the dispatcher SLICES it to the detected stack column(s) per prompt' "$SK" && ok "SKILL: §Tech-agnostic prose describes the slicing" || fail "SKILL: prose stale"
if grep -qF 'The agent-facing copy carries a **STACK IDIOM TABLE**' "$SK"; then fail "SKILL: old full-table attestation survives"; else ok "SKILL: old attestation replaced"; fi

# ── iter80 pins still green (P1–P6 disciplines + REPORT BACK untouched) ──
bash "$ROOT/tests/fixtures/iter80-extract-deepening/verify.sh" >/dev/null 2>&1 \
  && ok "iter80 verify.sh still green (disciplines + scorecard machinery untouched)" \
  || fail "iter80 verify.sh broke — the diet touched a pinned guarantee"

if [ "$FAILED" -eq 0 ]; then note "ALL B1 OK"; else note "B1 had failures"; fi
exit $FAILED

#!/usr/bin/env bash
# test-b1-wave-dispatch-diet.sh — token-efficiency Batch B1 (finding M-01),
# UPDATED IN PLACE by tranche 5d (spec 2026-07-30 §5d): the diet's guarantees
# survive, but the homes moved — the invariant contract now rides the
# domain-extractor AGENT BODY (system prompt, loads on every dispatch by
# construction) and the mechanical injections ride the script-built
# .dispatch-static.md. Pins, per guarantee:
#
#   SLICE   the MASTER table survives in wave-dispatch-templates.md as the
#           single authoritative copy (script PARSES it — no duplicate);
#           slicing rules pinned: UNION, full-table fallback, mapped-columns-
#           only mixes, never-empty (builder-guaranteed), LANG_MAP alias
#           parity. Functional slice behavior: test-extract-dispatch-static.sh.
#   GLOSS   index format + ~80-char cap + citation discipline unchanged; the
#           usage instruction lives ONCE — in the agent body.
#   HOME    the skeleton fence carries ONLY the variable core (no disciplines,
#           no REPORT BACK, no placeholders); every relocated block is present in
#           agents/domain-extractor.md. These are PHRASE-LEVEL presence pins —
#           byte-fidelity of the relocation was hand-verified against the 5.16.0
#           baseline at ship time; the pins guard presence, not byte-equality.
#   SPEC    the emission changes are amended into the tech-agnostic spec
#           (B1 2026-07-06 + 5d 2026-08-01).
#
# Run: bash tests/token-efficiency/test-b1-wave-dispatch-diet.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WDT="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md"
AG="${ROOT}/plugins/mega-sdd/agents/domain-extractor.md"
SK="${ROOT}/plugins/mega-sdd/skills/extract-intelligence/SKILL.md"
SPEC="${ROOT}/docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md"
BUILDER="${ROOT}/plugins/mega-sdd/scripts/build-extract-static.sh"
for f in "$WDT" "$AG" "$SK" "$SPEC" "$BUILDER"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== B1/5d: wave-dispatch prompt diet =="

# ── SLICE: master table single-copy, dispatcher-side; script parses it ──
N_HDR=$(grep -cF '| Principle | PHP | JS / TS | Python | C# / .NET | Java | Go | Ruby | Rust |' "$WDT")
[ "$N_HDR" = "1" ] && ok "SLICE: full 8-stack table appears exactly ONCE (single authoritative copy)" || fail "SLICE: expected exactly 1 master table, found $N_HDR"
grep -qF 'MASTER STACK IDIOM TABLE' "$WDT" && ok "SLICE: master table labeled" || fail "SLICE: master table label missing"
N_ROWS=$(grep -cE '^\| \*\*P[1-6]\*\*' "$WDT")
[ "$N_ROWS" = "9" ] && ok "SLICE: all 9 principle rows survive in the master (P1×2, P2, P3×2, P6×4)" || fail "SLICE: expected 9 principle rows, found $N_ROWS"
grep -qF 'PARSES this table at run time' "$WDT" && ok "SLICE: script-parses-the-master rule pinned (no duplicate copy possible)" || fail "SLICE: parse-at-run-time rule missing"
# the master must sit OUTSIDE the skeleton fence (never typed into a prompt)
python3 - "$WDT" <<'PY' && ok "SLICE: master table sits OUTSIDE the generic prompt skeleton" || fail "SLICE: master table inside the skeleton fence"
import sys
doc = open(sys.argv[1]).read()
skeleton_start = doc.find("Every wave's subagent prompt MUST follow this skeleton")
fence_open = doc.find("```", skeleton_start)
fence_close = doc.find("```", fence_open + 3)
master = doc.find("MASTER STACK IDIOM TABLE")
assert skeleton_start > 0 and fence_close > 0 and master > 0
sys.exit(0 if master > fence_close else 1)
PY
grep -qF 'SAME alias convention as `scripts/kb-leak-scan.sh` `LANG_MAP`' "$WDT" && ok "SLICE: language aliases anchored to the canonical LANG_MAP (kotlin→Java, node→JS/TS, …)" || fail "SLICE: alias mapping not anchored to LANG_MAP"
grep -qF '"vb.net": "csharp"' "${ROOT}/plugins/mega-sdd/scripts/kb-leak-scan.sh" && ok "SLICE: kb-leak-scan LANG_MAP covers VB.NET (consumers aligned)" || fail "SLICE: LANG_MAP missing vb.net"
grep -qF 'UNION of languages in the Wave 0 enumeration' "$WDT" && ok "SLICE: UNION-of-detected-stacks rule pinned (multi-stack gets every column)" || fail "SLICE: UNION rule missing"
grep -qF 'Fallback — emit the FULL table' "$WDT" && ok "SLICE: full-table fallback on empty/unmapped detection" || fail "SLICE: fallback rule missing"
grep -qF 'never writes an empty §STACK IDIOMS' "$WDT" && ok "SLICE: never-empty guarantee pinned (builder-enforced)" || fail "SLICE: never-empty rule missing"
grep -qF 'emit the mapped columns' "$WDT" && ok "SLICE: partially-unmapped mix emits mapped columns (no needless full-table)" || fail "SLICE: mixed-case rule missing"
grep -qF 'typescript/ts → `JS / TS`' "$WDT" && ok "SLICE: language→column mapping documented (JS/TS shared, aliases enumerated)" || fail "SLICE: column mapping missing"
grep -qF 'map to no column and are ignored' "$WDT" && ok "SLICE: markup/data-only languages (HTML/CSS/SQL) excluded from slicing" || fail "SLICE: non-code-language rule missing"

# ── GLOSS: format + cap + citation discipline; usage instruction ONCE (agent body) ──
grep -qF 'glossary_index (term: short_def (L<start>-<end>))' "$WDT" && ok "GLOSS: one-line-per-term index format documented" || fail "GLOSS: compact format missing"
grep -qF '~80 chars' "$WDT" && ok "GLOSS: short_def cap (~80 chars) pinned" || fail "GLOSS: cap missing"
if grep -qF 'short_def: "' "$WDT"; then fail "GLOSS: old YAML-verbose index format survives"; else ok "GLOSS: YAML-verbose form removed"; fi
grep -qF 'glossary.md §customer-onboarding:42-58' "$WDT" && grep -qF 'glossary.md §customer-onboarding:42-58' "$AG" \
  && ok "GLOSS: citation format unchanged in BOTH the doc and the agent body" || fail "GLOSS: citation format lost"
if grep -qF 'Subagent instruction (appended to Wave 2/3/4 prompts)' "$WDT"; then fail "GLOSS: duplicated usage instruction survives"; else ok "GLOSS: usage instruction not duplicated in the templates"; fi
grep -qF 'ONLY spot-read glossary.md' "$AG" && ok "GLOSS: spot-read discipline lives in the agent body (system prompt)" || fail "GLOSS: spot-read discipline lost from the agent body"
grep -qF 'VERBATIM prefix' "$WDT" && ok "GLOSS: script truncation = verbatim prefix (paraphrase surface removed)" || fail "GLOSS: verbatim-prefix rule missing"

# ── HOME: the skeleton fence is the variable core ONLY; relocations are 1:1 ──
python3 - "$WDT" <<'PY' && ok "HOME: skeleton fence carries the variable core only (no disciplines / REPORT BACK / placeholders; READ FIRST pointer exactly once)" || fail "HOME: skeleton fence still carries invariant content or lost its READ FIRST pointer"
import sys
doc = open(sys.argv[1]).read()
skeleton_start = doc.find("Every wave's subagent prompt MUST follow this skeleton")
fence_open = doc.find("```", skeleton_start)
fence_close = doc.find("```", fence_open + 3)
fence = doc[fence_open:fence_close]
bad = ["DEEP DISCIPLINES", "REPORT BACK", "DISCIPLINE DELTAS", "EXTRACTION DEPTH",
       "<STACK_IDIOM_ROWS>", "<GLOSSARY_INDEX>"]
assert not any(b in fence for b in bad), "invariant content still in fence"
assert fence.count(".dispatch-static.md") == 1, "READ FIRST pointer missing/duplicated"
sys.exit(0)
PY
grep -qF 'READ FIRST: <kb-dir>/.dispatch-static.md' "$WDT" && ok "HOME: dispatch carries the static-file Read-first pointer" || fail "HOME: Read-first pointer missing"
if grep -qF 'your agent body already carries the core rails' "$WDT"; then fail "HOME: obsolete delta-hedge survives in the templates"; else ok "HOME: delta-hedge gone (the body now carries everything invariant)"; fi
# every relocated block present in the agent body
grep -qF 'ON THE SAME LINE as the marker' "$AG" && ok "HOME: same-line citation + §11 rule in the agent body" || fail "HOME: same-line citation rule lost"
grep -qF 'uncertain → `[INTENT]`' "$AG" && ok "HOME: [INTENT]-default + positive-evidence tiers in the agent body" || fail "HOME: INTENT-default lost"
grep -qF 'Compare `.bak` / dated files' "$AG" && ok "HOME: .bak-vs-live comparison in the agent body" || fail "HOME: .bak rule lost"
grep -qF 'Output MUST BE TECH-AGNOSTIC — no legacy stack terms outside §11 Source References + 50-integrations/' "$AG" \
  && ok "HOME: tech-agnostic output scoping in the agent body" || fail "HOME: tech-agnostic scoping lost"
grep -qF 'Hidden state machines' "$AG" && ok "HOME: EXTRACTION DEPTH block in the agent body" || fail "HOME: extraction depth lost"
for p in 'P1 — State & data provenance' 'P2 — Enumerate ALL sites' 'P3 — Behaviour-as-EXECUTED' 'P4 — Classify files by structure' 'P6 — Dynamic dispatch & runtime wiring'; do
  grep -qF "$p" "$AG" && ok "HOME: deep discipline '$p' in the agent body" || fail "HOME: discipline missing: $p"
done
grep -qF 'reason by analogy from the closest idiom' "$AG" && ok "HOME: reason-by-analogy rule in the agent body" || fail "HOME: analogy rule lost"
if grep -qE 'STACK IDIOMS rows below|table row P[1-6]' "$AG"; then fail "HOME: dangling positional reference survives in the agent body"; else ok "HOME: positional references reworded to the dispatch-static file"; fi
if grep -qF 'DEEP DISCIPLINES in the generic prompt' "$WDT"; then fail "HOME: stale in-the-generic-prompt pointer survives in the templates (Wave-3 depth block)"; else ok "HOME: no stale pointer at a deleted skeleton block anywhere in the templates"; fi
for f in provenance_pairs_checked provenance_anomalies rule_sites_multi dynamic_seams_found dynamic_seams_resolved dynamic_seams_open gate_self_check; do
  grep -qF "$f" "$AG" && ok "HOME: REPORT BACK field '$f' in the agent body" || fail "HOME: REPORT BACK field lost: $f"
done
grep -qF 'P1 self-check rail' "$AG" && grep -qF 'P6 self-check rail' "$AG" && ok "HOME: both self-check rails in the agent body" || fail "HOME: a self-check rail is missing"
grep -qF 'What used to be typed here, and where it lives now' "$WDT" && ok "HOME: relocation table documents every move (1:1, nothing dropped)" || fail "HOME: relocation table missing"
# wave protocol: builder runs at Wave 0 AND after the Wave 1 gate
grep -qF 'build-extract-static.sh' "$WDT" && ok "HOME: builder invocation documented in the wave protocol" || fail "HOME: builder invocation missing"
grep -qF "grep -q '^## GLOSSARY INDEX'" "$WDT" && ok "HOME: post-Wave-1 rebuild gated (no Wave 2 dispatch without the glossary index)" || fail "HOME: post-Wave-1 gate missing"
grep -qF '`.dispatch-static.md` exists' "$WDT" && ok "HOME: Wave-0 gate requires the static file" || fail "HOME: Wave-0 gate missing the static file"

# ── SPEC + SKILL prose ──
grep -qF 'Amendment (2026-07-06, token-efficiency Batch B1' "$SPEC" && ok "SPEC: B1 emission-change amendment still recorded" || fail "SPEC: B1 amendment missing"
grep -qF 'Amendment (2026-08-01, tranche 5d' "$SPEC" && ok "SPEC: 5d relocation amendment recorded" || fail "SPEC: 5d amendment missing"
grep -qF 'agents/domain-extractor.md` §Deep disciplines' "$SK" && ok "SKILL: authoritative agent-facing copy = the agent body" || fail "SKILL: disciplines pointer stale"
grep -qF 'build-extract-static.sh` SLICES it' "$SK" && ok "SKILL: §Tech-agnostic prose names the script as the slicer" || fail "SKILL: slicing prose stale"
if grep -qF 'the dispatcher SLICES it to the detected stack column(s) per prompt' "$SK"; then fail "SKILL: old model-slicing attestation survives"; else ok "SKILL: old model-slicing attestation replaced"; fi

# ── iter80 pins still green (disciplines + scorecard machinery reachable) ──
bash "$ROOT/tests/fixtures/iter80-extract-deepening/verify.sh" >/dev/null 2>&1 \
  && ok "iter80 verify.sh still green (disciplines + scorecard machinery intact)" \
  || fail "iter80 verify.sh broke — the relocation touched a pinned guarantee"

if [ "$FAILED" -eq 0 ]; then note "ALL B1 OK"; else note "B1 had failures"; fi
exit $FAILED

#!/usr/bin/env bash
# test-p7-bolt-loop-efficiency.sh — v6.1.0 bolt-loop efficiency proof
# (spec docs/superpowers/specs/2026-08-06-v6.1-bolt-loop-efficiency.md)
# Pins: D1 attempt rounds + resolution-verifier, D2 finding ledger, D3 pointer
# re-dispatch, D4 findings-only lens returns, D5 l0-results file, D6 citation
# rulings, D7 evidence-commit batching — AND the moat guards (gate condition +
# L0 full re-run unchanged).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
FAIL=0
note() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

RP="$P/skills/execute-bolts/references/review-panel.md"
SK="$P/skills/execute-bolts/SKILL.md"
BI="$P/agents/bolt-implementer.md"
RV="$P/agents/resolution-verifier.md"
HH="$P/skills/execute-bolts/references/halts-and-handoff.md"
SB="$P/skills/execute-bolts/references/superpowers-bridge.md"

# ── A. resolution-verifier agent ─────────────────────────────────────────────
[ -f "$RV" ] || note "A1 resolution-verifier.md missing"
if [ -f "$RV" ]; then
  grep -q "^name: resolution-verifier" "$RV" || note "A2 agent name frontmatter"
  grep -q "^tools: Read, Grep, Glob, Bash" "$RV" || note "A3 read-only tool set"
  grep -Eq "^(hooks|mcpServers|permissionMode):" "$RV" && note "A4 forbidden frontmatter key present"
  grep -q "RESOLUTIONS:" "$RV" || note "A5 RESOLUTIONS return schema"
  grep -q "NEW-FINDINGS:" "$RV" || note "A6 NEW-FINDINGS return schema"
  grep -q "never mutate" "$RV" || note "A7 read-only discipline"
  grep -qi "one hop" "$RV" || note "A8 delta one-hop scope"
  grep -q "REQUIRES .*file:line.* evidence\|REQUIRES \`file:line\` evidence" "$RV" || note "A9 evidence-gated resolved"
fi

# ── B. lens return contract (D4) ─────────────────────────────────────────────
for a in spec-reviewer code-quality-reviewer security-reviewer standards-reviewer design-reviewer; do
  f="$P/agents/$a.md"
  grep -q "findings only, no narrative" "$f" || note "B1 $a return contract heading"
  grep -q "FINDINGS:" "$f" || note "B2 $a FINDINGS schema"
  grep -q "SUMMARY:" "$f" || note "B3 $a SUMMARY line"
  grep -q '^\- \*\*Strengths\*\*' "$f" && note "B4 $a still returns a Strengths section"
  grep -q '^\- \*\*Assessment\*\*' "$f" && note "B5 $a still returns an Assessment section"
done
grep -q "VERDICT: pass|fail" "$P/agents/spec-reviewer.md" || note "B6 spec lens VERDICT line"

# ── C. review-panel round policy + ledger (D1/D2/D5) ─────────────────────────
grep -q "## Attempt rounds + the finding ledger" "$RP" || note "C1 §Attempt rounds missing"
grep -q "findings.json" "$RP" || note "C2 ledger named"
grep -q "never from the implementer" "$RP" || note "C3 evidence-gated resolved rule (resolution never implementer-asserted)"
grep -q 'verified_by: "re-panel round N"' "$RP" || note "C3b escape-hatch ledger closure rule"
grep -q "Escape hatch" "$RP" || note "C4 escape hatch present"
grep -q "l0-results.json" "$RP" || note "C5 L0 lens-input file"
grep -q "never re-types findings into the prompt" "$RP" || note "C6 pointer re-dispatch rule"
grep -q "anti-churn rule" "$RP" || note "C7 advisory suppression rule"
# ledger schema example must parse as JSON (target the block carrying "findings",
# not blocks[0] — an unrelated earlier json block must not retarget this check)
python3 - "$RP" <<'EOF' || note "C8 findings.json schema example does not parse"
import json, re, sys
md = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"```json\n(.*?)```", md, re.S) if '"findings"' in b]
assert blocks, "no findings json block"
d = json.loads(blocks[0])
assert d.get("schema") == 1 and isinstance(d.get("findings"), list)
EOF

# ── moat guards: gate strength + deterministic full-head re-runs unchanged ──
grep -q "review_critical_unresolved" "$RP" || note "M1 halt name dropped from review-panel"
grep -q "RE-ENTERS the per-unit flow at the L0 code gates" "$RP" || note "M2 L0 re-entry wording dropped"
grep -qF "ORIGINAL bolt base..new head" "$RP" || note "M3 full-range L0 rescan wording dropped"
grep -q "review_critical_unresolved" "$SK" || note "M4 halt name dropped from SKILL"
# D5 negative pins: the OLD paste-per-lens channel must be GONE from the operative surfaces
grep -q "paste the stdout JSON verbatim" "$SK" && note "M5 SKILL step 3 still teaches paste-per-lens"
CG="$P/skills/execute-bolts/references/code-gates.md"
grep -q "appended verbatim to each review-panel lens prompt" "$CG" && note "M6 code-gates.md still teaches paste-per-lens"
grep -q "l0-results.json" "$CG" || note "M7 code-gates.md missing the l0 file channel"
# D6 negative pin: the emitted consumer-guide template must not teach comment citations
TPL="$P/skills/generate-intent/references/templates/ai-consumer-guide.md"
grep -q "commit messages or code comments" "$TPL" && note "M8 ai-consumer-guide template still teaches comment citations"

# ── D. SKILL step 4 wiring ───────────────────────────────────────────────────
grep -q "resolution-verifier" "$SK" || note "D1 SKILL names the verifier"
grep -q "findings.json" "$SK" || note "D2 SKILL names the ledger"
grep -q "l0-results.json" "$SK" || note "D3 SKILL names the L0 file"

# ── E. implementer contract (D3 fix rounds + D6 citations) ───────────────────
grep -q "FIX ROUND" "$BI" || note "E1 fix-round ledger paragraph"
grep -q "Code comments carry no claim citations" "$BI" || note "E2 comment-citation iron rule"
grep -q "never a dedicated fix commit" "$BI" || note "E3 fold-non-behavioral-fix rule"

# ── F. evidence-commit batching (D7) ─────────────────────────────────────────
grep -q "Evidence-commit batching" "$HH" || note "F1 batching section"
grep -q "refresh gate state.* is never emitted\|standalone gate-state-refresh commit" "$HH" || note "F2 no standalone refresh commits"

# ── G. bridge flow + catalog + roster ────────────────────────────────────────
grep -q "BY POINTER" "$SB" || note "G1 bridge flow pointer re-dispatch"
grep -q "resolution-verifier" "$SB" || note "G2 bridge flow names the verifier"
grep -q "resolution-verifier" "$P/references/model-tiers.md" || note "G3 model-tiers catalog row"
grep -q "resolution-verifier" "$P/CLAUDE.md" || note "G4 CLAUDE.md agent roster"
# catalog↔frontmatter parity for the new agent
cat_model=$(grep "\`resolution-verifier\`" "$P/references/model-tiers.md" | head -1 | awk -F'|' '{print $4}' | tr -d ' *')
fm_model=$(grep "^model:" "$RV" | awk '{print $2}')
[ "$cat_model" = "$fm_model" ] || note "G5 catalog model ($cat_model) != frontmatter model ($fm_model)"

if [ "$FAIL" -eq 0 ]; then echo "PASS: p7 bolt-loop efficiency (v6.1.0)"; exit 0; fi
echo "FAILURES: $FAIL"; exit 1

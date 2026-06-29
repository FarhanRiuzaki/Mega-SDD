#!/usr/bin/env bash
# Pin test for the output-language feature (default Indonesian-mix, extensible).
#
# The feature has no string catalog — it is a POLICY carried by (1) the always-
# injected anchor block, (2) the standalone reference census, and (3) the
# greenfield entry-point directives. Without a test, the default can silently
# revert (a reworded anchor) and the Tier-1 do-not-translate census can drift
# (an enum dropped from the census → free to be translated → a silent gate
# break at the artifact validators). This test pins all three.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS="$ROOT/plugins/mega-sdd/skills"
REF="$ROOT/plugins/mega-sdd/references/output-language.md"
ANCHOR="$SKILLS/using-mega-sdd/SKILL.md"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

has() { grep -qiF "$2" "$1"; }   # case-insensitive fixed-string in file

# ---- (a) anchor block: names Indonesian + states the precedence order -------
# The anchor must live in the injected CORE (above the ANCHOR-CORE marker) so it
# survives every session start + compaction.
extract_core() {
  awk 'BEGIN{dash=0;body=0}
       /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
       body==0{next}
       /ANCHOR-CORE ends/{exit}
       {print}' "$1"
}
[ -f "$ANCHOR" ] || { echo "FAIL anchor SKILL.md missing: $ANCHOR"; exit 1; }
CORE="$(extract_core "$ANCHOR")"
core_has() { printf '%s' "$CORE" | grep -qiF "$1"; }

if core_has "## Output language"; then ok "anchor: Output language block is in the injected CORE"
else bad "anchor: Output language block NOT in core (missing or below ANCHOR-CORE marker → won't reinject)"; fi
if core_has "Indonesian"; then ok "anchor: names Indonesian (the default)"
else bad "anchor: does not name Indonesian"; fi
# precedence order present (explicit request > input language > Indonesian)
if core_has "precedence" && core_has "explicit request"; then ok "anchor: states precedence order"
else bad "anchor: precedence order (explicit request > input language > Indonesian) missing"; fi
if core_has "output-language.md"; then ok "anchor: points to the reference census"
else bad "anchor: no pointer to plugins/mega-sdd/references/output-language.md"; fi

# ---- (b) reference: full Tier-1 enum families present -----------------------
[ -f "$REF" ] || { echo "FAIL reference missing: $REF"; exit 1; }
# Each token is a machine-parsed Tier-1 literal that MUST stay English. If one
# falls out of the census it loses its do-not-translate protection.
TIER1=(
  "CONFIRMED" "CONFLICT" "OQ"
  "IMPLEMENTED" "NEW" "UNKNOWN"
  "create|extend|verify"
  "[VERIFIED]" "[INFERRED]" "[OPEN]"
  "KEEP_VAULT" "KEEP_CODE" "DEFER" "SPLIT"
  "PASS" "FAIL"
  "COVERED" "MISSING" "PARTIAL"
  "[LOCKED]" "[INTENT]" "[ARTIFACT]"
  "sha256:"
)
for tok in "${TIER1[@]}"; do
  if has "$REF" "$tok"; then ok "census keeps Tier-1: $tok"
  else bad "Tier-1 token DROPPED from census (now translatable → gate-break risk): $tok"; fi
done
# the reference must itself state the precedence + the per-artifact (Tier-3) table
if has "$REF" "Precedence" && has "$REF" "Tier-3"; then ok "census carries precedence + Tier-3 table"
else bad "census missing precedence section or Tier-3 per-artifact table"; fi

# ---- (c) canonical default clause in the greenfield-reachable carriers -------
# Anchorless entry points (no .mega-sdd/ signal → no session-start injection)
# must carry the default themselves. Each must name the default AND precedence
# AND point to the census.
CARRIERS=(
  "generate-intent/SKILL.md"
  "generate-intent/references/from-prompt-mode.md"
  "generate-intent/references/vault-contract.md"
  "orchestrate-flow/SKILL.md"
  "extract-intelligence/SKILL.md"
  "scan-codebase/SKILL.md"
  "install-deps/SKILL.md"
)
for c in "${CARRIERS[@]}"; do
  f="$SKILLS/$c"
  if [ ! -f "$f" ]; then bad "carrier missing: $c"; continue; fi
  if has "$f" "Indonesian + English technical terms" \
     && has "$f" "precedence" \
     && has "$f" "output-language.md"; then
    ok "carrier states default+precedence+census pointer: $c"
  else
    bad "carrier missing default/precedence/census pointer: $c"
  fi
done

# ---- (d) L3 Tier-3 pointers: plugin-authored report emitters ----------------
# Only emit-fsd + analyze author standalone plugin-owned artifacts, so they (and
# ONLY they) carry an artifact-language pointer. emit-fsd additionally carries
# the quoted-content fidelity note — the moat-critical guard that a flattened
# source excerpt / [Source: …] citation is NEVER translated (invariant #3). If
# that note regresses, FSDs could silently mistranslate a cited PRD clause.
FSD="$SKILLS/emit-fsd/SKILL.md"
if has "$FSD" "output-language.md" && has "$FSD" "never translated" && has "$FSD" "[Source:"; then
  ok "emit-fsd carries Tier-3 pointer + quoted-content fidelity note"
else
  bad "emit-fsd missing Tier-3 pointer or the never-translate-citation fidelity note"
fi
ANALYZE="$SKILLS/analyze/SKILL.md"
if has "$ANALYZE" "output-language.md" && has "$ANALYZE" "CONSISTENCY-REPORT"; then
  ok "analyze carries Tier-3 report-prose pointer"
else
  bad "analyze missing Tier-3 report-prose pointer"
fi

# ---- guard: the bound-session artifact-content skills are deliberately NOT touched ----
# These run only AFTER a vault exists (.mega-sdd/ present → anchor injected), and
# their "recorded in the vault's existing language" clause is the correct Tier-3
# behavior. If a future edit bolts the chat-default onto them it would spend
# hot-path tokens for no gain — flag it so the deliberate scope decision stays
# visible (advisory, never fails the suite). NOTE: scan-codebase + install-deps
# are NOT here — they are greenfield-reachable (anchorless) and MUST carry the
# clause; they are pinned positively in CARRIERS above.
for s in detect-drift bind-codebase resolve-oq diff-vault; do
  if grep -qiF "Indonesian + English technical terms" "$SKILLS/$s/SKILL.md" 2>/dev/null; then
    printf '  note: %s now carries the chat-default clause — confirm intended (bound-session skill, anchor already covers it)\n' "$s"
  fi
done

echo
if [ "$fail" -eq 0 ]; then echo "PASS output-language pins"; exit 0
else echo "output-language pins FAILED"; exit 1; fi

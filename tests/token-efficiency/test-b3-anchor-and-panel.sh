#!/usr/bin/env bash
# test-b3-anchor-and-panel.sh — token-efficiency Batch B3 (M-11 + M-13).
#
#   M-11  review-panel sizes the unit-body payload per lens: spec lens FULL,
#         other lenses DROP the Implementation-steps narrative; agent bodies
#         single-source the floor/ceiling doctrine + Iron Rules.
#   M-13a anchor routing core is slimmed (keyword bullets → pointer at the
#         always-loaded descriptions); the unioned keywords live in descriptions.
#   M-13b the SessionStart hook is SOURCE-AWARE: resume skips the anchor, compact
#         injects the slim core, startup/clear/unknown inject the full core
#         (fail-open). Empirical against the REAL hook.
#
# Run: bash tests/token-efficiency/test-b3-anchor-and-panel.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
HOOK="${ROOT}/plugins/mega-sdd/hooks/session-start"
ANCHOR="${ROOT}/plugins/mega-sdd/skills/using-mega-sdd/SKILL.md"
RP="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
DR="${ROOT}/plugins/mega-sdd/agents/design-reviewer.md"
BI="${ROOT}/plugins/mega-sdd/agents/bolt-implementer.md"
for f in "$HOOK" "$ANCHOR" "$RP" "$DR" "$BI"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t b3)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.mega-sdd"

drive() { # $1=source → hook stdout
  printf '{"session_id":"s","source":"%s","cwd":"%s"}' "$1" "$WORK" \
    | (cd "$WORK" && bash "$HOOK" 2>/dev/null)
}

note "== B3: source-aware anchor + per-lens panel (M-11/M-13) =="

# ── M-13b: source matrix (empirical, real hook) ──
FULL=$(drive startup); LFULL=${#FULL}
RES=$(drive resume);   LRES=${#RES}
CMP=$(drive compact);  LCMP=${#CMP}
CLR=$(drive clear);    LCLR=${#CLR}
UNK=$(drive weird);    LUNK=${#UNK}

echo "$FULL" | grep -q "When this applies" && ok "M-13b: startup injects the FULL routing core" || fail "M-13b: startup missing full core"
# resume injects ZERO anchor: neither the FULL core marker ("When this applies")
# nor the SLIM core marker ("Hard gate"). Its length is env-dependent — dynamic
# notices (dep_missing, superpowers WARN) fire regardless of source and legitimately
# inflate it (CI has no tree-sitter/ast-grep/superpowers), so we check CONTENT, not
# an absolute byte threshold. The dynamic notices are the intended "keep on resume".
if ! echo "$RES" | grep -q "When this applies" && ! echo "$RES" | grep -q "Hard gate"; then
  ok "M-13b: resume SKIPS the anchor entirely (no full core, no slim core — already in transcript; len=$LRES incl. dynamic notices)"
else
  fail "M-13b: resume injected anchor content (len=$LRES)"
fi
if ! echo "$CMP" | grep -q "When this applies" && echo "$CMP" | grep -q "Hard gate" && echo "$CMP" | grep -q "Output language"; then
  ok "M-13b: compact injects the SLIM core (Hard rule + Output language, no keyword bullets; len=$LCMP)"
else
  fail "M-13b: compact core wrong (len=$LCMP)"
fi
[ "$LCMP" -lt "$LFULL" ] && [ "$LCMP" -gt "$LRES" ] && ok "M-13b: slim < full and slim > resume (size ordering holds)" || fail "M-13b: size ordering wrong (full=$LFULL slim=$LCMP resume=$LRES)"
echo "$CLR" | grep -q "When this applies" && ok "M-13b: clear injects the FULL core" || fail "M-13b: clear missing full core"
echo "$UNK" | grep -q "When this applies" && ok "M-13b: unknown source FAILS OPEN to the full core" || fail "M-13b: unknown source did not fail open"
# compact still carries the dynamic COMPACT_RESUME notice when a snapshot exists
printf '{"phase":{"guess":"execute-bolts","units_total":3,"bolts_done":1}}' > "$WORK/.mega-sdd/.compaction-snapshot.json"
CMP2=$(drive compact)
echo "$CMP2" | grep -qi "resumed after a compaction" && ok "M-13b: compact still emits the dynamic COMPACT_RESUME notice" || fail "M-13b: compact lost COMPACT_RESUME"
rm -f "$WORK/.mega-sdd/.compaction-snapshot.json"

# ── M-13b: hook source-parse + fail-open guard present in source ──
grep -qF 'HOOK_SOURCE' "$HOOK" && ok "M-13b: hook parses HOOK_SOURCE from stdin" || fail "M-13b: HOOK_SOURCE parse missing"
grep -qF 'HOOK_SOURCE" != "resume"' "$HOOK" && ok "M-13b: fail-open excludes resume (empty anchor on resume is intentional)" || fail "M-13b: resume-aware fail-open guard missing"

# ── M-13a: anchor-core slim, Hard rule + Output language kept ──
CORE_CHARS=$(awk 'BEGIN{d=0;b=0} /^---[[:space:]]*$/{d++; if(d==2)b=1; next} b==0{next} /ANCHOR-CORE ends/{exit} {print}' "$ANCHOR" | wc -c | tr -d ' ')
[ "$CORE_CHARS" -lt 3600 ] && ok "M-13a: injected core slimmed (<3600 chars, was 3886; now $CORE_CHARS)" || fail "M-13a: core not slimmed ($CORE_CHARS)"
# the unioned keywords must live in the always-loaded description (not the core)
DESC=$(awk 'BEGIN{d=0} /^---[[:space:]]*$/{d++; next} d==1 && /^description:/{print} d>=2{exit}' "$ANCHOR")
for kw in "bound-vault" "legacy intelligence" "source of truth dari legacy"; do
  echo "$DESC" | grep -qiF "$kw" && ok "M-13a: unioned keyword in description: $kw" || fail "M-13a: keyword lost from description: $kw"
done

# ── M-11: per-lens payload contract in review-panel.md ──
grep -qiF 'spec lens gets the full unit body verbatim' "$RP" && ok "M-11: spec lens keeps the FULL unit body (moat checks intact)" || fail "M-11: spec-lens-full contract missing"
grep -qiF 'NOT the Implementation-steps NARRATIVE' "$RP" && ok "M-11: other lenses DROP the Implementation-steps narrative" || fail "M-11: narrative-drop contract missing"
# review-round fix: Migration notes (the KEEP/preserve list) must NOT be stripped —
# the security lens's bypass-detection needs it on extend units (pre-existing
# controls are absent from binding_refs). Only the step narrative is trimmed.
grep -qiF 'Migration notes STAYS in every lens' "$RP" && ok "M-11: Migration notes RETAINED for all lenses (security bypass-detection intact)" || fail "M-11: Migration notes wrongly stripped (security moat risk)"
grep -qiF 'sized to the lens' "$ROOT/plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md" && ok "M-11: superpowers-bridge flow diagram matches the sized-per-lens contract (no inert-savings contradiction)" || fail "M-11: superpowers-bridge flow still says full unit body to every lens"
grep -qiF 'blind' "$RP" && ok "M-11: blind-dispatch rail still present (unit-body SIZING changed, not sharing)" || fail "M-11: blindness rail lost"
# ── M-11: agent-body de-dup ──
grep -qiF 'ceiling moves named in §Floor vs ceiling' "$DR" && ok "M-11: design-reviewer check #0 points at §Floor vs ceiling (single-sourced)" || fail "M-11: design-reviewer still re-enumerates the ceiling list"
grep -qiF 'honor every Iron Rule above' "$BI" && ok "M-11: bolt-implementer self-review references the Iron Rules (no re-list)" || fail "M-11: bolt-implementer still re-lists Iron Rules"

if [ "$FAILED" -eq 0 ]; then note "ALL B3 OK"; else note "B3 had failures"; fi
exit $FAILED

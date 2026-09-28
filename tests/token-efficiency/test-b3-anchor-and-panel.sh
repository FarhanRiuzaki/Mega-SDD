#!/usr/bin/env bash
# test-b3-anchor-and-panel.sh — token-efficiency Batch B3 (M-11 + M-13).
#
#   M-11  (retired in P3 C3 with review-panel.md and the lens agents.)
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
for f in "$HOOK" "$ANCHOR"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

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

echo "$FULL" | grep -q "Task weight" && ok "M-13b: startup injects the FULL routing core" || fail "M-13b: startup missing full core"
# resume injects ZERO anchor: neither the FULL core marker ("Task weight")
# nor the SLIM core marker ("Hard gate"). Its length is env-dependent — dynamic
# notices (dep_missing, superpowers WARN) fire regardless of source and legitimately
# inflate it (CI has no tree-sitter/ast-grep/superpowers), so we check CONTENT, not
# an absolute byte threshold. The dynamic notices are the intended "keep on resume".
if ! echo "$RES" | grep -q "Task weight" && ! echo "$RES" | grep -q "Hard gate"; then
  ok "M-13b: resume SKIPS the anchor entirely (no full core, no slim core — already in transcript; len=$LRES incl. dynamic notices)"
else
  fail "M-13b: resume injected anchor content (len=$LRES)"
fi
if ! echo "$CMP" | grep -q "Task weight" && echo "$CMP" | grep -q "Hard gate" && echo "$CMP" | grep -q "Output language"; then
  ok "M-13b: compact injects the SLIM core (Hard rule + Output language, no keyword bullets; len=$LCMP)"
else
  fail "M-13b: compact core wrong (len=$LCMP)"
fi
[ "$LCMP" -lt "$LFULL" ] && [ "$LCMP" -gt "$LRES" ] && ok "M-13b: slim < full and slim > resume (size ordering holds)" || fail "M-13b: size ordering wrong (full=$LFULL slim=$LCMP resume=$LRES)"
echo "$CLR" | grep -q "Task weight" && ok "M-13b: clear injects the FULL core" || fail "M-13b: clear missing full core"
echo "$UNK" | grep -q "Task weight" && ok "M-13b: unknown source FAILS OPEN to the full core" || fail "M-13b: unknown source did not fail open"
# v7.3.0: the COMPACT_RESUME notice (PreCompact snapshot) is REMOVED with
# observability — a compact source must NOT emit it even when a stale snapshot
# file exists on disk.
printf '{"phase":{"guess":"execute-bolts","units_total":3,"bolts_done":1}}' > "$WORK/.mega-sdd/.compaction-snapshot.json"
CMP2=$(drive compact)
echo "$CMP2" | grep -qi "resumed after a compaction" && fail "M-13b: COMPACT_RESUME survived the v7.3.0 removal" || ok "M-13b: compact no longer emits COMPACT_RESUME (v7.3.0)"
rm -f "$WORK/.mega-sdd/.compaction-snapshot.json"

# ── M-13b: hook source-parse + fail-open guard present in source ──
grep -qF 'HOOK_SOURCE' "$HOOK" && ok "M-13b: hook parses HOOK_SOURCE from stdin" || fail "M-13b: HOOK_SOURCE parse missing"
grep -qF 'HOOK_SOURCE" != "resume"' "$HOOK" && ok "M-13b: fail-open excludes resume (empty anchor on resume is intentional)" || fail "M-13b: resume-aware fail-open guard missing"

# ── M-13a: anchor-core slim, Hard rule + Output language kept ──
CORE_CHARS=$(awk 'BEGIN{d=0;b=0} /^---[[:space:]]*$/{d++; if(d==2)b=1; next} b==0{next} /ANCHOR-CORE ends/{exit} {print}' "$ANCHOR" | wc -c | tr -d ' ')
# v7.0.0: cap raised 3450→4000 — the S/M/L weight table joined the core (gate-1
# approved growth, spec 2026-08-21 §2.1; measured 3918). Still a hard ceiling.
[ "$CORE_CHARS" -lt 4000 ] && ok "M-13a: injected core within the v7 cap (<4000 chars; now $CORE_CHARS)" || fail "M-13a: core over the v7 cap ($CORE_CHARS)"
# the unioned keywords must live in the always-loaded description (not the core)
DESC=$(awk 'BEGIN{d=0} /^---[[:space:]]*$/{d++; next} d==1 && /^description:/{print} d>=2{exit}' "$ANCHOR")
for kw in "bound-vault" "legacy intelligence" "source of truth dari legacy"; do
  echo "$DESC" | grep -qiF "$kw" && ok "M-13a: unioned keyword in description: $kw" || fail "M-13a: keyword lost from description: $kw"
done


if [ "$FAILED" -eq 0 ]; then note "ALL B3 OK"; else note "B3 had failures"; fi
exit $FAILED

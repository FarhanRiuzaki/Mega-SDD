#!/usr/bin/env bash
# Platform-assumption pins — from the 2026-06-11 docs-verification sweep
# (the AGENTS.md/worktree bug class: stale assumptions about Claude Code itself).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

# P1 — PreToolUse deny format (current contract + legacy rider)
grep -q '"permissionDecision": "deny"' "$P/hooks/pre-tool-use" \
  && grep -q '"decision": "block"' "$P/hooks/pre-tool-use" \
  && pass "P1: PreToolUse dual deny format" || fail "P1: deny format wrong"
! grep -v '^[[:space:]]*#' "$P/hooks/pre-tool-use" | grep -q '"continue": false' \
  && pass "P1b: no continue:false EMITTED by PreToolUse (comments exempt)" || fail "P1b: continue:false still emitted"

# P2 — UPE gate wired + functional (FAIL→block, PASS→silent)
grep -q 'UserPromptExpansion' "$P/hooks/hooks.json" \
  && [ -x "$P/hooks/user-prompt-expansion" ] \
  && pass "P2: UserPromptExpansion gate wired" || fail "P2: UPE gate missing"
T=$(mktemp -d); mkdir -p "$T/.mega-sdd"
printf '{"status": "FAIL"}' > "$T/.mega-sdd/.validation-blockers.json"
O1=$(printf '{"cwd":"%s"}' "$T" | bash "$P/hooks/user-prompt-expansion" 2>/dev/null)
printf '{"status": "PASS"}' > "$T/.mega-sdd/.validation-blockers.json"
O2=$(printf '{"cwd":"%s"}' "$T" | bash "$P/hooks/user-prompt-expansion" 2>/dev/null)
rm -rf "$T"
case "$O1" in *'"decision": "block"'*) pass "P2a: UPE FAIL→block";; *) fail "P2a: expected block, got ${O1:0:50}";; esac
[ -z "$O2" ] && pass "P2b: UPE PASS→silent" || fail "P2b: expected silent"

# P3 — v7 Fase 2: the pandoc render-failure rung is DELETED (validator gone,
# md2pdf's own HTML fallback covers the mode) and its PostToolUseFailure wiring
# must be gone from hooks.json with it (zero-phantom).
! grep -q 'PostToolUseFailure' "$P/hooks/hooks.json" \
  && ! grep -q 'validate-pandoc-render.sh' "$P/hooks/post-tool-use" \
  && pass "P3: pandoc rung + PostToolUseFailure wiring removed cleanly" \
  || fail "P3: pandoc rung or its event wiring still present"

# P4 — v7 Fase 2: the Stop handoff-validation leg is REMOVED; the verdict is
# derived at gate time (PreToolUse Branch 1a, every guarded dispatch). Stop must
# no longer INVOKE the validator (the tombstone comment may name it).
! grep -q 'VALIDATOR_HV' "$P/hooks/stop" \
  && ! grep -q 'LAST_ASSISTANT_TEXT' "$P/hooks/stop" \
  && grep -q 'FULL gate-time recompute' "$P/hooks/pre-tool-use" \
  && grep -q 'Removed 2026-06-11' "$P/hooks/stop" \
  && pass "P4: stop leg removed; gate-time recompute is the sole handoff writer" \
  || fail "P4: stop still carries the handoff leg (or gate-time recompute missing)"

# P5 — SessionStart matcher includes resume
grep -q 'startup|resume|clear|compact' "$P/hooks/hooks.json" \
  && pass "P5: SessionStart re-fires on resume" || fail "P5: resume matcher missing"

# P6 — no ${CLAUDE_PLUGIN_ROOT} left in references/ (not substituted there)
! grep -r 'CLAUDE_PLUGIN_ROOT' "$P"/skills/*/references/*.md | grep -v 'is NOT substituted' | grep -q . \
  && pass "P6: no runnable PLUGIN_ROOT in reference files (explanatory notes exempt)" || fail "P6: runnable PLUGIN_ROOT still in refs"

# P7 — prose corrections hold
grep -q 'permissionDecision: "deny"' "$P/references/fork-a-recovery-map.md" \
  && pass "P7: fork-map block format corrected" || fail "P7: fork-map stale"
grep -q '4 options — the platform caps options at 4' "$P/skills/execute-bolts/references/halt-recovery.md" \
  && pass "P7b: AskUserQuestion ≤4 options" || fail "P7b: 5-option dispatch remains"
# P7b2 — the propose-and-confirm menu template ALSO respects the 4-option cap
# (regression guard: Override must be [4], Cancel rides Other/Esc, no [5] dispatch)
if ! grep -q '\[5\] Override halt' "$P/skills/execute-bolts/references/propose-and-confirm-prompt.md" \
   && grep -q '\[4\] Override halt' "$P/skills/execute-bolts/references/propose-and-confirm-prompt.md"; then
  pass "P7b2: propose-and-confirm menu ≤4 options (Override=[4], Cancel via Other/Esc)"
else
  fail "P7b2: propose-and-confirm 5-option menu remains"
fi
grep -q 'https://aaif.io' "$P/skills/emit-agents-md/SKILL.md" \
  && pass "P7c: AAIF live URL" || fail "P7c: dead AAIF URL"
grep -q '/reload-plugins' "$P/README.md" \
  && pass "P7d: /reload-plugins named" || fail "P7d: reload missing"
! grep -rq 'superpowers:reverse-engineering-legacy-codebase' "$P/skills/" \
  && pass "P7e: ghost superpowers skill ref removed" || fail "P7e: ghost ref remains"

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

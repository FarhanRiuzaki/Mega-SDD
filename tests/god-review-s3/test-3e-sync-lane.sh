#!/usr/bin/env bash
# test-3e-sync-lane.sh — god-review stage 3, Batch 3E.
# Pins the incremental/sync-lane correctness fixes:
#
#   SP-3  full scan whenever the git delta channel is unavailable, REGARDLESS of
#         journal state (pre-fix: stamp-missing + any journaled AI write →
#         incremental proceeded blind to manual/pulled changes, then the restamp
#         laundered the staleness permanently). Journal-only incremental survives
#         ONLY for not-a-git-repo, with an explicit stale-risk warning.
#   SP-4  the staleness stamp uses `git rev-parse --verify 'HEAD^{commit}'` (a
#         zero-commit repo would stamp the literal string "HEAD"); consumers
#         treat a literal-HEAD stamp as missing.
#   SP-6  the broken RG_OPTS block (quoting fails on bash AND zsh) is gone.
#   SP-7  grammar smoke test: binary presence no longer stamps precision_tier ast;
#         grammars_used lists only languages that passed a real query.
#   SP-8  "truncate the journal" wording eliminated — the operative protocol is
#         rotate-and-delete (truncate-in-place loses concurrent-session appends).
#   SP-9  the flag catalog documents BOTH --shallow-scan semantics.
#
# Run: bash tests/god-review-s3/test-3e-sync-lane.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SP="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md"
SK="${ROOT}/plugins/mega-sdd/skills/scan-codebase/SKILL.md"
HFH="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/halts-flags-handoff.md"
TSI="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/tree-sitter-integration.md"
SY="${ROOT}/plugins/mega-sdd/commands/sync.md"
for f in "$SP" "$SK" "$HFH" "$TSI" "$SY"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 3E: incremental/sync lane =="

# ── SP-3 ──
grep -qF 'the git delta channel is unavailable — regardless of journal state' "$SP" \
  && ok "SP-3: fallback keyed to git-channel availability, journal-independent" || fail "SP-3: fallback still journal-ANDed"
if grep -qF 'lacks `last_scanned_commit` AND the journal is empty' "$SP"; then
  fail "SP-3: old fail-open AND-join survives"
else
  ok "SP-3: old stamp-missing-AND-journal-empty join removed"
fi
grep -qF 'Not-a-git-repo exception' "$SP" && grep -qF 'incremental merge covers in-session writes only' "$SP" \
  && ok "SP-3: journal-only incremental reserved for not-a-git-repo, with stale-risk warning" || fail "SP-3: not-a-git-repo exception/warning missing"

# ── SP-4 ──
grep -qF "git rev-parse --verify 'HEAD^{commit}'" "$SP" && ok "SP-4: stamp uses --verify HEAD^{commit}" || fail "SP-4: stamp guard missing"
grep -qF 'stamp equal to the literal `HEAD` as missing' "$SP" && ok "SP-4: literal-HEAD stamp treated as missing (consumer rule)" || fail "SP-4: literal-HEAD rule missing"
grep -qF 'the stamp is the literal string `HEAD`' "$SP" && ok "SP-4: incremental fallback names the literal-HEAD case" || fail "SP-4: incremental side missing literal-HEAD"
# empirical: the guard behaves as documented in a zero-commit repo
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t sp4)"; trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && git init -q . )
if ( cd "$WORK" && git rev-parse --verify 'HEAD^{commit}' >/dev/null 2>&1 ); then
  fail "SP-4: --verify unexpectedly succeeded in a zero-commit repo"
else
  ok "SP-4: --verify fails (→ omit stamp) in a zero-commit repo — empirical"
fi

# ── SP-6 ──
if grep -qF 'RG_OPTS' "$SP"; then fail "SP-6: broken RG_OPTS block survives"; else ok "SP-6: RG_OPTS block removed"; fi
if grep -qF -- "--type-add" "$SP"; then fail "SP-6: needless --type-add survives"; else ok "SP-6: no --type-add (rg types are built-in)"; fi

# ── SP-7 ──
grep -qF 'grammar smoke test' "$SP" && ok "SP-7: Step 0 carries the grammar smoke test" || fail "SP-7: smoke test missing from Step 0"
grep -qF 'grammar smoke test' "$SK" && ok "SP-7: SKILL.md skeleton names the smoke test" || fail "SP-7: SKILL.md skeleton stale"
grep -qF 'binary presence ≠ working grammars' "$SP" && ok "SP-7: rationale states binary ≠ grammars" || fail "SP-7: rationale missing"
grep -qF 'verified' "$TSI" && grep -qF 'never from binary presence alone' "$TSI" \
  && ok "SP-7: integration ref — precision_tier ast is a verified claim" || fail "SP-7: integration ref not updated"

# ── SP-8 ──
SP8_BAD=0
for f in "$SK" "$HFH" "$SY"; do
  if grep -qi 'truncate[d]* the journal\|Journal truncated' "$f"; then SP8_BAD=1; fi
done
[ "$SP8_BAD" -eq 0 ] && ok "SP-8: 'truncate the journal' wording eliminated from all 3 surfaces" || fail "SP-8: truncate wording survives"
grep -qF 'rotate-and-delete' "$SK" && grep -qF 'rotate-and-delete' "$HFH" && grep -qF 'rotate-and-delete' "$SY" \
  && ok "SP-8: all 3 surfaces name the rotate-and-delete consume protocol" || fail "SP-8: rotate wording missing somewhere"

# ── SP-9 ──
grep -qF 'two coupled fast-path semantics' "$HFH" && grep -qF 'per-file invalidation gate' "$HFH" \
  && ok "SP-9: flag catalog documents both --shallow-scan semantics" || fail "SP-9: catalog still one-semantic"

if [ "$FAILED" -eq 0 ]; then note "ALL 3E OK"; else note "3E had failures"; fi
exit $FAILED

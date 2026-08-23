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
SY="${ROOT}/plugins/mega-sdd/commands/sync.md"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
RR="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md"
SPEC="${ROOT}/docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md"
for f in "$SP" "$SK" "$HFH" "$SY" "$HC" "$RR" "$SPEC"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

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

# ── SP-7 (v7.4.0 form): the grammar-smoke-test lane stays removed ──
if grep -qF 'grammar smoke test' "$SP" || grep -qF 'grammar smoke test' "$SK"; then
  fail "SP-7: grammar smoke test prose is back (the tree-sitter lane was removed v7.4.0)"
else
  ok "SP-7: no grammar-smoke-test prose (tree-sitter lane stays removed)"
fi

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

# ── B6 (confirmed bug): sync-lane full-scan fallback must continue Mode D to a FULL
#   re-bind, not hand off a scope-less detect-drift. detect-drift infers sync-lane
#   membership ONLY from a --scope=@file, so with no scope it self-classifies as
#   STANDALONE, emits next_action: null, and the chain truncates BEFORE the re-bind —
#   leaving binding/units/bolts stale in exactly the highest-divergence case. ──
note "-- B6: full-scan fallback continues to a full re-bind (no truncation) --"
if grep -qF 'so downstream full-scans consistently' "$SP"; then
  fail "B6: SP fallback still hands off a scope-less detect-drift (chain null-terminates before re-bind)"
else
  ok "B6: buggy scope-less-detect-drift fallback wording removed from scan-procedure"
fi
# Tightened 2026-07-30 (fork-safety audit): the render must carry <vault>. On this
# branch no .sync-changed-paths.txt is written, so the vault path is the ONLY signal
# the non-interactive downstream bind receives. See tests/scan/test-sync-lane-vault-signal.sh.
grep -qF 'continues the forced Mode D chain straight to a FULL re-bind' "$SP" \
  && grep -qF 'next_action: mega-sdd:bind-codebase <vault> --auto' "$SP" \
  && ok "B6: SP fallback hands off bind-codebase <vault> --auto (full re-bind)" || fail "B6: SP fallback missing bind-codebase <vault> --auto continuation"
grep -qF 'SKIP detect-drift, hand off mega-sdd:bind-codebase' "$HFH" \
  && ok "B6: HFH handoff comment names the bind-codebase fallback continuation" || fail "B6: HFH fallback comment not updated"
grep -qF 'SKIP detect-drift, hand off mega-sdd:bind-codebase' "$HC" \
  && ok "B6: handoff-contract mirror names the bind-codebase fallback continuation" || fail "B6: HC mirror fallback branch not updated"
grep -qF 'on the full-scan fallback' "$RR" && grep -qF 'hands off `bind-codebase <vault> --auto` DIRECTLY' "$RR" \
  && ok "B6: routing-rules Mode D row carries the fallback sub-branch (with <vault>)" || fail "B6: routing-rules Mode D row missing fallback sub-branch"
grep -qF 'continues the forced Mode D chain straight to a FULL re-bind' "$SPEC" \
  && ok "B6: spec §3.8(b)(1) amended off the buggy 'drop --scope' call" || fail "B6: spec §3.8(b)(1) still says drop --scope"
# secondary cleanup: generate-units --reconcile is NOT a scope-channel consumer
grep -qF 'takes NO path arg' "$SP" \
  && ok "B6: SP no longer overclaims generate-units --reconcile as a scope-channel consumer" || fail "B6: generate-units --reconcile scope-channel overclaim survives"

if [ "$FAILED" -eq 0 ]; then note "ALL 3E OK"; else note "3E had failures"; fi
exit $FAILED

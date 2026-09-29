#!/usr/bin/env bash
# test-3e-sync-lane.sh — god-review stage 3, Batch 3E.
# Pins the incremental/sync-lane correctness fixes:
#
#   SP-3  full fallback whenever the git delta channel is unavailable, REGARDLESS
#         of journal state (pre-fix: stamp-missing + any journaled AI write →
#         incremental proceeded blind to manual/pulled changes, then the restamp
#         laundered the staleness permanently).
#   SP-4  the staleness stamp uses `git rev-parse --verify 'HEAD^{commit}'` (a
#         zero-commit repo would stamp the literal string "HEAD"); consumers
#         treat a literal-HEAD stamp as missing.
#   SP-8  "truncate the journal" wording eliminated — the operative protocol is
#         rotate-and-delete (truncate-in-place loses concurrent-session appends).
#   B6    the no-baseline fallback continues to a FULL re-bind, never a scope-less
#         detect-drift (which self-classifies STANDALONE → next_action: null →
#         the chain truncates before the re-bind).
#
# 9.0 P1 (scan-codebase + bind-codebase + generate-units removed, spec
# docs/superpowers/specs/2026-09-27-v9-simplification-design.md §2/§3):
#   The sync lane's changed-set producer is now `scripts/derive-changed-paths.sh`
#   (baseline = the GROUND symbol-index `head_commit`, built by
#   `scripts/build-symbol-index.sh`), its fallback is the full JIT re-bind
#   `scripts/rebind-units.sh --units=all`, and the reconcile hop is
#   `plan --reconcile`. SP-3 / SP-4 / SP-8 / B6 are REPOINTED to those surviving
#   surfaces (commands/sync.md, orchestrate-flow routing-rules §Mode D, the
#   scripts themselves — empirically where the rule is code, not prose).
#   RETIRED with the deleted scan-codebase skill (its scan-procedure.md /
#   SKILL.md / halts-flags-handoff.md no longer exist by design):
#     - SP-3 not-a-git-repo journal-only incremental exception (the successor has
#       no journal-only mode: git unavailable → exit 3 → full re-bind, stricter)
#     - SP-6 RG_OPTS / --type-add block (scan-procedure only)
#     - SP-7 grammar-smoke-test absence (scan-procedure / scan SKILL.md only)
#     - SP-9 --shallow-scan two-semantics flag catalog (a scan-codebase flag)
#     - B6 scan-procedure "so downstream full-scans consistently" negative,
#       halts-flags-handoff + handoff-contract scan-codebase-row fallback comments
#       (no scan-codebase handoff row survives; the fallback is engine-run, not a
#       skill handoff), and the 2026-06-10 spec §3.8(b)(1) mirror (historical
#       spec text describing `scan-codebase --changed-only`).
#
# Run: bash tests/god-review-s3/test-3e-sync-lane.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PL="${ROOT}/plugins/mega-sdd"
SY="${PL}/commands/sync.md"
RR="${PL}/skills/orchestrate-flow/references/routing-rules.md"
HC="${PL}/skills/orchestrate-flow/references/handoff-contract.md"
DCP="${PL}/scripts/derive-changed-paths.sh"
BSI="${PL}/scripts/build-symbol-index.sh"
STP="${PL}/scripts/_lib/state_probes.py"
for f in "$SY" "$RR" "$HC" "$DCP" "$BSI" "$STP"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t sp3e)"; trap 'rm -rf "$WORK"' EXIT
HEX40="0123456789abcdef0123456789abcdef01234567"

note "== 3E: incremental/sync lane =="

# ── SP-3 (repointed: derive-changed-paths.sh is the changed-set producer) ──
grep -qF '(`derive-changed-paths.sh` exit 3 — no baseline stamp / git unavailable / write failed) → full JIT re-bind fallback' "$SY" \
  && ok "SP-3: sync.md keys the full fallback to baseline/git-channel availability" || fail "SP-3: sync.md fallback (exit 3 → full JIT re-bind) missing"
SP3_BAD=0
for f in "$SY" "$RR" "$DCP"; do
  if grep -qF 'AND the journal is empty' "$f"; then SP3_BAD=1; fi
done
[ "$SP3_BAD" -eq 0 ] && ok "SP-3: no stamp-missing-AND-journal-empty join on any sync surface" || fail "SP-3: old fail-open AND-join survives"
# empirical: git channel unavailable (not a repo) + a valid stamp + journaled
# writes → exit 3 (full re-bind), journal left un-consumed — journal-independent.
NG="$WORK/nogit"; mkdir -p "$NG/.mega-sdd/codebase" "$NG/v"
printf '{"head_commit": "%s", "symbols": []}\n' "$HEX40" > "$NG/.mega-sdd/codebase/symbol-index.json"
printf '{"path": "src/a.py"}\n' > "$NG/.mega-sdd/codebase/.dirty-paths.jsonl"
GIT_CEILING_DIRECTORIES="$WORK" bash "$DCP" --cwd="$NG" --vault "$NG/v" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 3 ] && [ -s "$NG/.mega-sdd/codebase/.dirty-paths.jsonl" ] \
   && ! ls "$NG/.mega-sdd/codebase/".dirty-paths.consumed-* >/dev/null 2>&1 \
   && [ ! -e "$NG/v/.sync-changed-paths.txt" ]; then
  ok "SP-3: no git channel + journaled writes → exit 3, journal NOT consumed — empirical"
else
  fail "SP-3: no-git derive-changed-paths rc=$RC (want 3) or the journal was consumed / a changed set written"
fi

# ── SP-4 (repointed: the GROUND symbol-index head_commit is the freshness stamp) ──
grep -qF '"rev-parse", "--verify", "HEAD^{commit}"' "$BSI" \
  && ok "SP-4: symbol-index stamp uses --verify HEAD^{commit}" || fail "SP-4: stamp guard missing from build-symbol-index.sh"
# empirical: the guard behaves as documented in a zero-commit repo
( cd "$WORK" && mkdir zc && cd zc && git init -q . )
if ( cd "$WORK/zc" && git rev-parse --verify 'HEAD^{commit}' >/dev/null 2>&1 ); then
  fail "SP-4: --verify unexpectedly succeeded in a zero-commit repo"
else
  ok "SP-4: --verify fails (→ omit stamp) in a zero-commit repo — empirical"
fi
# empirical consumer rule: a literal-HEAD stamp reads as MISSING in the state probe
LH="$WORK/lithead"; mkdir -p "$LH/.mega-sdd/codebase" "$LH/v"
printf '{"head_commit": "HEAD", "symbols": []}\n' > "$LH/.mega-sdd/codebase/symbol-index.json"
if python3 - "$PL/scripts/_lib" "$LH" <<'PY' >/dev/null 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import state_probes
r = state_probes.probe_symbol_index(sys.argv[2], head="HEAD")
sys.exit(0 if r.get("present") and r.get("head_commit") is None else 1)
PY
then ok "SP-4: literal-HEAD stamp treated as missing (state probe consumer) — empirical"
else fail "SP-4: state_probes.probe_symbol_index accepted a literal-HEAD stamp"
fi
# empirical: the changed-set producer treats a literal-HEAD stamp as no baseline
( cd "$LH" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init ) >/dev/null 2>&1
bash "$DCP" --cwd="$LH" --vault "$LH/v" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "SP-4: derive-changed-paths treats a literal-HEAD stamp as no baseline (exit 3) — empirical" \
  || fail "SP-4: derive-changed-paths rc=$RC on a literal-HEAD stamp (want 3)"

# ── SP-8 (sync.md is the surviving journal-consume surface; scan SKILL.md and
#    halts-flags-handoff.md were deleted with scan-codebase) ──
if grep -qi 'truncate[d]* the journal\|Journal truncated' "$SY"; then
  fail "SP-8: truncate wording survives in sync.md"
else
  ok "SP-8: 'truncate the journal' wording absent from sync.md"
fi
grep -qF 'rotate-and-delete' "$SY" \
  && ok "SP-8: sync.md names the rotate-and-delete consume protocol" || fail "SP-8: rotate wording missing from sync.md"

# ── B6: the no-baseline fallback must continue to a FULL re-bind, not hand off a
#   scope-less detect-drift. detect-drift infers sync-lane membership ONLY from a
#   --scope=@file, so with no scope it self-classifies as STANDALONE, emits
#   next_action: null, and the chain truncates BEFORE the re-bind — leaving
#   binding/units/bolts stale in exactly the highest-divergence case. ──
note "-- B6: no-baseline fallback continues to a full re-bind (no truncation) --"
# The render must carry <vault>: with no .sync-changed-paths.txt written, the
# vault path is the ONLY signal the non-interactive downstream re-bind receives.
grep -qF 'full JIT re-bind fallback (`scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=all`' "$SY" \
  && grep -qF 'detect-drift skipped' "$SY" \
  && ok "B6: sync.md fallback = rebind-units.sh --vault=<vault> --units=all, detect-drift skipped" \
  || fail "B6: sync.md fallback missing the full rebind-units.sh <vault> --units=all continuation"
grep -qF 'a scope-less detect-drift would null-terminate the chain before the re-bind' "$RR" \
  && grep -qF 'run the FULL re-bind `scripts/rebind-units.sh --cwd=. --vault=<vault> --units=all`' "$RR" \
  && ok "B6: routing-rules Mode D no-baseline branch skips detect-drift → full re-bind (with <vault>)" \
  || fail "B6: routing-rules Mode D no-baseline fallback branch missing"
# the reconcile hop is NOT a scope-channel consumer (it reads per-unit binding.json)
grep -qF 'the SAME consumer contract detect-drift --scope=@,' "$DCP" \
  && grep -qF 'sync-intersect.sh --paths=@ and rebind-units.sh --paths=@ read.' "$DCP" \
  && ok "B6: changed-set consumer contract = detect-drift / sync-intersect / rebind-units only" \
  || fail "B6: derive-changed-paths.sh consumer contract line changed"
RC_BAD=0
for f in "$SY" "$RR" "$HC"; do
  if grep -qE -- '--reconcile[^`]*(--paths=@|--scope=@)' "$f"; then RC_BAD=1; fi
done
[ "$RC_BAD" -eq 0 ] && ok "B6: no surface overclaims plan --reconcile as a scope-channel consumer" \
  || fail "B6: plan --reconcile scope-channel overclaim"

if [ "$FAILED" -eq 0 ]; then note "ALL 3E OK"; else note "3E had failures"; fi
exit $FAILED

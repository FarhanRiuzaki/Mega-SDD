#!/usr/bin/env bash
# test-b3b-memory-pointers.sh — token-efficiency Batch B3b (M-16).
#
# Memory row content transits chat ONCE (the chain-start read), not 2-3x:
#   - metadata.memory_context = POINTER slices ({file, rows, digest}), never row text
#   - skills append their own rows via scripts/memory-write.sh at emission time
#   - metadata.memory_writes = a write RECEIPT ({files_written: [paths], rows_appended})
#   - the secret-scan rail MOVES INTO memory-write.sh (one deterministic site) —
#     empirically verified here, not just doc-pinned
#
# Run: bash tests/token-efficiency/test-b3b-memory-pointers.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MW="${ROOT}/plugins/mega-sdd/scripts/memory-write.sh"
ML="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
MS="${ROOT}/plugins/mega-sdd/skills/memory/references/memory-schema.md"
RO="${ROOT}/plugins/mega-sdd/skills/resolve-oq/references/auto-memory-handoff.md"
BC="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md"
GU="${ROOT}/plugins/mega-sdd/skills/generate-units/references/auto-and-memory.md"
OF="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md"
CE="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md"
DD="${ROOT}/plugins/mega-sdd/skills/detect-drift/SKILL.md"
SPEC="${ROOT}/docs/superpowers/specs/2026-05-21-memory-self-learning-design.md"
for f in "$MW" "$ML" "$HC" "$MS" "$RO" "$BC" "$GU" "$OF" "$CE" "$DD" "$SPEC"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t b3b)"
trap 'rm -rf "$WORK"' EXIT

note "== B3b: memory pointers-not-content (M-16) =="

# ── memory-write.sh: the relocated secret-scan rail (empirical) ──
bash "$MW" --file="$WORK/decisions.md" --scope=project --cwd="$WORK" \
  --content='| 2026-07-08 | OQ-3 | auth | password: "hunter2secret42" | run-1 |' </dev/null
RC=$?
if [ "$RC" -eq 0 ] && grep -q 'REDACTED-SECRET' "$WORK/decisions.md" && ! grep -q 'hunter2secret42' "$WORK/decisions.md"; then
  ok "M-16: memory-write.sh redacts secret-shaped values itself ([REDACTED-SECRET], secret absent, rc=0)"
else
  fail "M-16: writer-side secret scan missing (rc=$RC): $(cat "$WORK/decisions.md" 2>/dev/null | head -1)"
fi
# clean row appended intact + prior content preserved
bash "$MW" --file="$WORK/decisions.md" --scope=project --cwd="$WORK" \
  --content='| 2026-07-08 | OQ-4 | ui | KEEP_CODE (8/10) | run-2 |' </dev/null
if [ "$(grep -c '^|' "$WORK/decisions.md")" -eq 2 ] && grep -qF 'KEEP_CODE (8/10)' "$WORK/decisions.md"; then
  ok "M-16: clean row appended byte-intact; append preserves prior rows"
else
  fail "M-16: append regressed: $(cat "$WORK/decisions.md")"
fi
# stdin path (multi-line block)
printf '\n## Run #1\n- claims: 3\n' | bash "$MW" --file="$WORK/bind-history.md" --scope=vault --cwd="$WORK"
grep -q 'claims: 3' "$WORK/bind-history.md" && ok "M-16: stdin (heredoc) path works for multi-line blocks" || fail "M-16: stdin path broken"
# contract preserved: empty content exit 2, missing --file exit 2, no lock residue
bash "$MW" --file="$WORK/x.md" --cwd="$WORK" --content='' </dev/null; [ $? -eq 2 ] && ok "M-16: empty content still exit 2" || fail "M-16: empty-content contract changed"
bash "$MW" --cwd="$WORK" --content='y' </dev/null 2>/dev/null; [ $? -eq 2 ] && ok "M-16: missing --file still exit 2" || fail "M-16: missing-file contract changed"
if ls "$WORK" | grep -q '\.lock'; then fail "M-16: lock residue leaked"; else ok "M-16: no lock residue after writes"; fi
# the scan is wired in the script source (deterministic pin)
grep -qF 'secret-scan.sh' "$MW" && ok "M-16: secret-scan wired inside memory-write.sh (one enforcement site)" || fail "M-16: scan call missing from writer"

# ── memory-layer.md: pointer + receipt protocol ──
grep -qF 'Build per-skill **pointer slices**' "$ML" && ok "M-16: chain-start builds POINTER slices (no row text)" || fail "M-16: pointer-slice build missing"
grep -qF 'targeted Read' "$ML" && ok "M-16: targeted-read fallback mandated (fresh session / fork)" || fail "M-16: targeted-read fallback missing"
grep -qF 'files_written: [<paths>]' "$ML" || grep -qF 'files_written' "$ML" && ok "M-16: write receipt (files_written) in the protocol" || fail "M-16: receipt missing"
grep -qiF 'path LIST' "$ML" && ok "M-16: files_written pinned as a path LIST (chain-end pass depends on it)" || fail "M-16: path-list requirement missing"
grep -qF 'memory-write.sh' "$ML" && ok "M-16: skills append via memory-write.sh at emission time" || fail "M-16: emission-time write missing"
if grep -qF 'Per-phase write batching' "$ML"; then fail "M-16: old batched-write section survives in memory-layer.md"; else ok "M-16: orchestrator write-batching retired"; fi

# ── handoff-contract.md: schema flipped ──
grep -qF 'POINTER slice (M-16)' "$HC" && ok "M-16: memory_context schema = pointer slice" || fail "M-16: contract memory_context not flipped"
grep -qF 'write RECEIPT (M-16)' "$HC" && ok "M-16: memory_writes schema = write receipt" || fail "M-16: contract memory_writes not flipped"
grep -qF 'rows_appended: int' "$HC" && ok "M-16: metadata TYPE annotation updated to the receipt shape" || fail "M-16: TYPE annotation stale"
grep -qF 'omits this block entirely' "$HC" && ok "M-16: --memory-off optionality preserved" || fail "M-16: memory-off optionality lost"
if grep -qF 'OUT — skill emits writes for orchestrator to persist' "$HC"; then fail "M-16: old orchestrator-persist comment survives"; else ok "M-16: old persist-via-orchestrator comment gone"; fi

# ── memory-schema.md: canonical writer + relocated scan ──
grep -qF 'canonical writer for every memory file' "$MS" && ok "M-16: memory-write.sh declared the canonical writer (write canons reconciled)" || fail "M-16: canonical-writer declaration missing"
grep -qF 'runs the scan itself' "$MS" && ok "M-16: §8.5 secret-scan site restated as inside the writer" || fail "M-16: §8.5 scan site stale"
grep -qF 'write receipt' "$MS" && ok "M-16: §8 consumption steps rewritten (receipt)" || fail "M-16: §8 stale"

# ── consumers: targeted-read mandates + emission-time writes ──
grep -qF 'targeted Read of the pointed file' "$RO" && ok "M-16: resolve-oq mandates the targeted read (fresh-session resume case)" || fail "M-16: resolve-oq targeted read missing"
grep -qF 'memory-write.sh' "$RO" && ok "M-16: resolve-oq writes at emission time via the script" || fail "M-16: resolve-oq write path stale"
grep -qF 'actual per-rule violated+reverted counts' "$GU" && ok "M-16: generate-units targeted read pinned (>=3 threshold needs real counts)" || fail "M-16: generate-units threshold read missing"
grep -qF 'memory-write.sh' "$BC" && ok "M-16: bind-codebase writes at emission time via the script" || fail "M-16: bind-codebase write path stale"

# ── orchestrate-flow SKILL.md + chain-execution consolidation ──
grep -qF 'POINTER slice' "$OF" && ok "M-16: dispatch instruction passes the pointer slice" || fail "M-16: SKILL.md dispatch stale"
grep -qF 'write receipt' "$OF" && ok "M-16: SKILL.md memory-layer summary carries the receipt contract" || fail "M-16: SKILL.md summary stale"
grep -qF 'memory-write.sh' "$CE" && ok "M-16: routing-outcomes write consolidated onto memory-write.sh" || fail "M-16: chain-execution manual lock survives"

# ── review-round fixes (2 reviewers, 3 Important + 8 Minor) ──
# observable fail-open: unwritable scratch → WARN on stderr, original content written, rc=0
RO_DIR="$WORK/ro"; mkdir -p "$RO_DIR"; chmod 500 "$RO_DIR"
TMPDIR="$RO_DIR" bash "$MW" --file="$WORK/ro-target.md" --cwd="$WORK" \
  --content='password: "hunter2secret42"' </dev/null 2>"$WORK/ro-err"; RC=$?
if [ "$RC" -eq 0 ] && grep -q 'WARN' "$WORK/ro-err" && grep -q 'hunter2secret42' "$WORK/ro-target.md"; then
  ok "M-16 fix: scan bypass is fail-open BUT observable (WARN on stderr, rc=0, original bytes)"
else
  fail "M-16 fix: silent fail-open regressed (rc=$RC warn=$(cat "$WORK/ro-err" 2>/dev/null | head -1))"
fi
chmod 700 "$RO_DIR"
# a contender's lock must survive our exit-1 (early trap must not double-release)
mkdir "$WORK/held.md.lock"
bash "$MW" --file="$WORK/held.md" --cwd="$WORK" --content='x' </dev/null 2>/dev/null; RC=$?
if [ "$RC" -eq 1 ] && [ -d "$WORK/held.md.lock" ]; then
  ok "M-16 fix: lock-acquisition failure exits 1 WITHOUT releasing the contender's lock"
else
  fail "M-16 fix: contender lock handling wrong (rc=$RC, lock present: $([ -d "$WORK/held.md.lock" ] && echo yes || echo NO))"
fi
rmdir "$WORK/held.md.lock" 2>/dev/null
# ENOSPC guard + single-trap discipline pinned structurally
grep -qF 'scratch file unavailable' "$MW" && ok "M-16 fix: guarded scratch write (partial write cannot truncate the row)" || fail "M-16 fix: scratch write-guard missing"
grep -qF 'do NOT add a second' "$MW" && ok "M-16 fix: single-trap discipline pinned (scan scratch covered on interrupt)" || fail "M-16 fix: trap consolidation comment missing"
# the two-sided flip reaches ALL writer skills (review Important-2)
for pair in "scan-codebase:skills/scan-codebase/references/halts-flags-handoff.md" \
            "generate-intent:skills/generate-intent/references/auto-and-handoff.md" \
            "execute-bolts:skills/execute-bolts/references/halts-and-handoff.md" \
            "install-deps:skills/install-deps/SKILL.md"; do
  nm="${pair%%:*}"; fp="${ROOT}/plugins/mega-sdd/${pair#*:}"
  grep -qF 'memory-write.sh' "$fp" && ok "M-16 fix: $nm writes via the script (rider present)" || fail "M-16 fix: $nm still appends with no mechanism"
done
# routing-outcomes protocol consolidated + halt retired (review Important-1)
ROU="${ROOT}/plugins/mega-sdd/skills/memory/references/routing-outcomes.md"
grep -qF 'memory-write.sh' "$ROU" && ! grep -qF 'Acquire file lock on routing-outcomes.md' "$ROU" \
  && grep -qiF 'NEVER a chain halt' "$ROU" \
  && ok "M-16 fix: routing-outcomes write protocol consolidated (no hand-rolled lock, no memory_in_use halt)" \
  || fail "M-16 fix: routing-outcomes still carries the retired protocol"
grep -qF 'canonical writer' "${ROOT}/plugins/mega-sdd/skills/memory/SKILL.md" && ok "M-16 fix: memory SKILL.md registry points at the canonical writer" || fail "M-16 fix: memory SKILL.md registry stale"
grep -qF 'receipt-touched scopes' "$MS" && ok "M-16 fix: _index.md inventory row re-anchored to chain end" || fail "M-16 fix: batched-write point survives in the inventory"
grep -qF 'secret-scan.sh' "$DD" && ok "M-16 fix: detect-drift's tolerated raw-append states scan-first (fork can't reach §6)" || fail "M-16 fix: detect-drift scan clause missing"
grep -qF 'never the digest alone' "$BC" && ok "M-16 fix: bind-codebase targeted-read mandate (both >=3 thresholds)" || fail "M-16 fix: bind-codebase digest-prohibition missing"

# ── the untouchables ──
if grep -qF 'emit via handoff \`metadata.memory_writes\` instead' "$DD"; then
  fail "M-16: detect-drift regained a memory_writes routing sentence (fork test will fail)"
else
  ok "M-16: detect-drift untouched (already the direct-write target pattern)"
fi
grep -qF 'B3b/M-16' "$SPEC" && ok "M-16: spec amendment recorded (memory-self-learning §14 + OQ-7)" || fail "M-16: spec amendment missing"

if [ "$FAILED" -eq 0 ]; then note "ALL B3b OK"; else note "B3b had failures"; fi
exit $FAILED

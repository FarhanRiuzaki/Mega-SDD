#!/usr/bin/env bash
# test-sync-lane-vault-signal.sh — the Mode-D full-scan-fallback handoff must carry <vault>.
#
# WHY (fork-safety audit 2026-07-30, research/2026-07-30-fork-safety-audit-scan-bind.md):
# on the Mode-D sync lane, scan-codebase's full-scan fallback writes NO
# .sync-changed-paths.txt and hands straight to a FULL re-bind. On that branch the
# vault path is the ONLY signal the downstream bind receives — and bind is
# non-interactive there, so it cannot ask for it. Two of the three surfaces that
# render this handoff had drifted to a bare `bind-codebase --auto`, which hands a
# non-interactive (and, once Phase 5a lands, FORKED) bind nothing to resolve from.
#
# Also pins the fork-attribution: the docs described bind-codebase as already
# `context: fork` while its frontmatter carried no `context:` key at all. A doc that
# claims a skill is forked when it is not is how the real flip gets skipped.
#
# CI-safe: bash + python3 only. No network, no fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROC="$PLUGIN_ROOT/skills/scan-codebase/references/scan-procedure.md"
HFH="$PLUGIN_ROOT/skills/scan-codebase/references/halts-flags-handoff.md"
ROUT="$PLUGIN_ROOT/skills/orchestrate-flow/references/routing-rules.md"
BIND="$PLUGIN_ROOT/skills/bind-codebase/SKILL.md"
# The design spec is the SOURCE the operative refs implement — its shorthand was the
# drift that let three downstream surfaces drop the vault. Pin it too, or the same
# drift re-enters from the authority.
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SPEC="$REPO_ROOT/docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md"

for f in "$PROC" "$HFH" "$ROUT" "$BIND" "$SPEC"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# ── 1. No surface may render the bind handoff WITHOUT a vault ────────────────
# `bind-codebase --auto` with nothing between the verb and the flag is the defect.
# `bind-codebase <vault> --auto` and `bind-codebase --paths=@…` are both fine.
for f in "$PROC" "$HFH" "$ROUT" "$SPEC"; do
  base="$(basename "$f")"
  if grep -qE 'bind-codebase --auto' "$f"; then
    fail "$base renders a vault-less \`bind-codebase --auto\` (forked bind gets no vault signal)"
    grep -nE 'bind-codebase --auto' "$f" | head -2 | sed 's/^/        /'
  else
    pass "$base carries no vault-less bind handoff"
  fi
done

# ── 2. The full-scan fallback branch must name the vault explicitly ──────────
grep -qE 'bind-codebase <vault> --auto' "$PROC" \
  && pass "scan-procedure renders the fallback as \`bind-codebase <vault> --auto\`" \
  || fail "scan-procedure lost the <vault> in the full-scan fallback handoff"
grep -qE 'bind-codebase <vault> --auto' "$HFH" \
  && pass "halts-flags-handoff keeps the authoritative <vault>-carrying shape" \
  || fail "halts-flags-handoff lost the authoritative <vault> shape"
grep -qE 'bind-codebase <vault> --auto' "$ROUT" \
  && pass "routing-rules renders the fallback with <vault>" \
  || fail "routing-rules lost the <vault> in the Mode-D fallback"

# ── 3. Fork attribution must match bind-codebase's ACTUAL frontmatter ────────
# Until Phase 5a flips it, no surface may assert bind-codebase is already forked.
HAS_FORK="$(python3 - "$BIND" <<'PY'
import sys
try:
    fm = open(sys.argv[1]).read().split('---', 2)[1]
except Exception:
    print("ERR"); raise SystemExit
print("yes" if any(l.strip().startswith('context:') and 'fork' in l for l in fm.splitlines()) else "no")
PY
)"
echo "  (bind-codebase context: fork = $HAS_FORK)"

if [ "$HAS_FORK" = "no" ]; then
  BAD=0
  for f in "$PROC" "$HFH" "$ROUT"; do
    # "two forked ... downstream phases" lumps bind in with detect-drift.
    if grep -qiE 'two forked[^.]*downstream|forked downstream phases' "$f"; then
      fail "$(basename "$f") calls bind-codebase forked, but its frontmatter has no context: fork"
      BAD=1
    fi
  done
  [ "$BAD" -eq 0 ] && pass "no surface claims bind-codebase is forked while it is not"
elif [ "$HAS_FORK" = "yes" ]; then
  # Phase 5a landed — the audit's Group C/D contract must have landed with it.
  grep -qiE 'NEVER calls .?AskUserQuestion|non-interactive \(forked' "$BIND" \
    && pass "forked bind carries the non-interactive declaration" \
    || fail "bind-codebase is context: fork but carries no never-AskUserQuestion rail"
  grep -qE 'bind_inputs_missing' "$BIND" \
    && pass "forked bind defines the deterministic-input blocker" \
    || fail "bind-codebase is context: fork with no bind_inputs_missing blocker (it would have to guess a vault)"
else
  fail "could not parse bind-codebase frontmatter"
fi

# ── 4. detect-drift IS forked — the attribution must stay TRUE for it ────────
DD="$PLUGIN_ROOT/skills/detect-drift/SKILL.md"
if [ -f "$DD" ]; then
  grep -qE '^context:[[:space:]]*fork' "$DD" \
    && pass "detect-drift still carries context: fork (the live precedent)" \
    || fail "detect-drift lost context: fork — the fork precedent is gone"
fi

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-sync-lane-vault-signal)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi

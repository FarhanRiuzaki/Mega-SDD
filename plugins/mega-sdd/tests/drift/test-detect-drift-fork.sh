#!/usr/bin/env bash
# test-detect-drift-fork.sh — Batch 2 (token), detect-drift context:fork pilot.
#
# detect-drift is the one clean context:fork candidate (side-lane, non-moat) — but
# context:fork is UNCONDITIONAL frontmatter, so the skill must be non-interactive on
# EVERY path (a fork cannot AskUserQuestion). This pins the deterministic fork-safety
# contract (the live fork-firing + token saving is validated on a real run):
#   1. frontmatter: context: fork + version >= 3.0.0 + valid YAML
#   2. non-interactive: the old interactive walkthrough menu is GONE; Step 5 queues to
#      PENDING-SYNC.md; Hard rules carry the "never AskUserQuestion" rail
#   3. inputs deterministic: drift_inputs_missing blocker defined (never-ask Step 0)
#   4. drift-history persists to DISK even when forked (the metadata.memory_writes
#      hand-off branch — which a fork can't harvest — is removed)
#   5. report-format.md marks the interactive walkthrough / DRIFT-ACTIONS deprecated
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DD="$PLUGIN_ROOT/skills/detect-drift"
SKILL="$DD/SKILL.md"
AUTO="$DD/references/auto-and-chain.md"
RPT="$DD/references/report-format.md"

for f in "$SKILL" "$AUTO" "$RPT"; do [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }; done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# 1. Frontmatter: context: fork + version + valid YAML.
FM="$(python3 - "$SKILL" <<'PY'
import sys
try:
    import yaml
    d=yaml.safe_load(open(sys.argv[1]).read().split('---',2)[1])
    print(f"{d.get('context')}|{d.get('version')}|{isinstance(d.get('description'),str)}")
except ImportError:
    fm=open(sys.argv[1]).read().split('---',2)[1]
    ctx=ver='?'
    for ln in fm.splitlines():
        s=ln.strip()
        if s.startswith('context:'): ctx=s.split(':',1)[1].strip()
        if s.startswith('version:'): ver=s.split(':',1)[1].strip()
    print(f"{ctx}|{ver}|True")
PY
)"
CTX="${FM%%|*}"; REST="${FM#*|}"; VER="${REST%%|*}"; DSTR="${REST##*|}"
echo "  (context=$CTX version=$VER desc_is_str=$DSTR)"
[ "$CTX" = "fork" ] && pass "frontmatter context: fork" || fail "context != fork ($CTX)"
case "$VER" in 3.*|4.*|5.*) pass "version >= 3.0.0 ($VER)" ;; *) fail "version not bumped to >=3.0.0 ($VER)";; esac
[ "$DSTR" = "True" ] && pass "description is a valid YAML scalar" || fail "description not a scalar (colon-space bug)"

# 2. Non-interactive.
grep -qiE 'walk now / save report only / cancel|Interactive walkthrough \(optional' "$SKILL" \
  && fail "old interactive walkthrough menu still present" \
  || pass "interactive walkthrough menu removed"
grep -qE 'Queue direction calls to `PENDING-SYNC.md` \(ALWAYS' "$SKILL" \
  && pass "Step 5 always queues to PENDING-SYNC.md" || fail "Step 5 not queue-always"
grep -qiE 'Non-interactive \(forked|NEVER calls `AskUserQuestion`|never.*AskUserQuestion' "$SKILL" \
  && pass "Hard-rule: never AskUserQuestion (forked)" || fail "missing non-interactive Hard rule"

# 3. Deterministic inputs: blocker defined.
grep -qE 'drift_inputs_missing' "$SKILL" && grep -qE 'type: drift_inputs_missing' "$AUTO" \
  && pass "drift_inputs_missing blocker referenced + defined" || fail "drift_inputs_missing not wired"

# 4. drift-history persists to disk even forked (no metadata.memory_writes hand-off branch).
grep -qE 'orchestrated chains: emit via handoff `metadata.memory_writes` instead' "$SKILL" \
  && fail "drift-history still routes via metadata.memory_writes (a fork can't harvest it)" \
  || pass "drift-history hand-off branch removed (fork-safe)"
grep -qiE 'always a direct on-disk write, even when forked' "$SKILL" \
  && pass "drift-history is an unconditional on-disk write" || fail "drift-history not unconditional disk write"

# 5. report-format deprecation note.
grep -qiE 'deprecated \(v3.0.0\)|deprecated \*\*\(v3.0.0\)' "$RPT" \
  && pass "report-format marks walkthrough/DRIFT-ACTIONS deprecated" || fail "report-format not updated"

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-detect-drift-fork)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi

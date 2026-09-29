#!/usr/bin/env bash
# test-sync-lane-vault-signal.sh — the Mode-D no-baseline fallback re-bind must carry <vault>.
#
# WHY (fork-safety audit 2026-07-30, commit 2b3f6574):
# on the Mode-D sync lane, the changed-set fallback writes NO .sync-changed-paths.txt
# and goes straight to a FULL re-bind. On that branch the vault path is the ONLY signal
# the downstream re-bind receives — the chain is non-interactive there, so it cannot
# ask for it. The audit found surfaces that had drifted to a vault-less re-bind handoff.
#
# 9.0 (P1, design docs/superpowers/specs/2026-09-27-v9-simplification-design.md §2/§3):
# the classic scan → whole-vault-bind spine was removed. The fallback's PRODUCER is now
# `scripts/derive-changed-paths.sh` exit 3 (no symbol-index baseline / git unavailable /
# write failed) and the re-bind hop is the per-unit JIT writer
# `scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=all`. Same invariant,
# repointed: every surface that renders the fallback must render it WITH the vault.
# Retired with the classic skills: the scan-procedure / halts-flags-handoff pins, the
# 2026-06-10 living-vault spec's whole-vault-bind shorthand pin, and the whole-vault
# bind's fork-attribution pin (that skill no longer exists).
#
# Also pins the fork attribution that survives: detect-drift is the ONE forked Mode-D
# hop. A doc that claims a skill is forked when its frontmatter says otherwise is how a
# real flip gets skipped (or an interactive phase gets run as if it could not ask).
#
# CI-safe: bash + python3 only. No network, no fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# The three surfaces that render the Mode-D no-baseline fallback in 9.0:
#   ROUT — the router's authoritative Mode-D detail (was one of the three pre-9.0 surfaces)
#   SYNC — the /mega-sdd:sync command's hard rails
#   DCP  — the fallback's producer: derive-changed-paths.sh's exit-3 message is the
#          handoff the non-interactive chain reads (replaces the scan fallback handoff)
ROUT="$PLUGIN_ROOT/skills/orchestrate-flow/references/routing-rules.md"
SYNC="$PLUGIN_ROOT/commands/sync.md"
DCP="$PLUGIN_ROOT/scripts/derive-changed-paths.sh"
REBIND="$PLUGIN_ROOT/scripts/rebind-units.sh"

for f in "$ROUT" "$SYNC" "$DCP" "$REBIND"; do
  [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }
done

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# ── 0. The re-bind hop itself refuses a vault-less call (fail-closed, never a guess) ──
# The doc pins below matter because the script cannot resolve a vault on its own: a
# missing --vault is a usage error (exit 2), not a discovered default.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
bash "$REBIND" --cwd="$tmp" --units=all >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] \
  && pass "rebind-units.sh exits 2 (usage) when --vault is absent — it never guesses a vault" \
  || fail "rebind-units.sh without --vault exited $rc (expected 2: usage, fail-closed)"

# ── 1. No surface may render a full re-bind invocation WITHOUT a vault ──────────────
# `rebind-units.sh --cwd=<x> --units=…` / `--paths=…` with nothing between --cwd and the
# scope flag is the defect (the vault was dropped from a full command form).
for f in "$ROUT" "$SYNC" "$DCP"; do
  base="$(basename "$f")"
  if grep -qE 'rebind-units\.sh --cwd[= ][^ `)]+ --(units|paths)' "$f"; then
    fail "$base renders a vault-less \`rebind-units.sh --cwd=… --units/--paths\` (the re-bind gets no vault signal)"
    grep -nE 'rebind-units\.sh --cwd[= ][^ `)]+ --(units|paths)' "$f" | head -2 | sed 's/^/        /'
  else
    pass "$base carries no vault-less re-bind handoff"
  fi
done

# ── 2. The no-baseline fallback branch must name the vault explicitly ───────────────
FALLBACK_SHAPE='rebind-units\.sh --cwd=[^ `]+ --vault=<vault> --units=all'
# ROUT + SYNC: the vault-carrying full re-bind must sit ON the fallback line itself
# (the line naming the no-baseline / exit-3 branch), not merely somewhere in the file.
grep -E '[Nn]o baseline|exit 3' "$ROUT" | grep -qE "$FALLBACK_SHAPE" \
  && pass "routing-rules renders the Mode-D no-baseline fallback as \`rebind-units.sh --cwd=. --vault=<vault> --units=all\`" \
  || fail "routing-rules lost the <vault> in the Mode-D no-baseline fallback"
grep -E '[Nn]o baseline|exit 3' "$SYNC" | grep -qE "$FALLBACK_SHAPE" \
  && pass "sync.md renders the changed-set-failure fallback with <vault>" \
  || fail "sync.md lost the <vault> in the changed-set-failure (exit 3) fallback"
# DCP: the producer's exit-3 message must hand off the vault-carrying shape, and that
# message must be the exit-3 branch (the message spans lines, so check the block).
python3 - "$DCP" "$FALLBACK_SHAPE" <<'PY' \
  && pass "derive-changed-paths.sh's exit-3 handoff names the vault-carrying full re-bind" \
  || fail "derive-changed-paths.sh's exit-3 (no baseline) handoff lost the <vault>"
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'if not stamp:(.*?)sys\.exit\(3\)', src, re.S)
sys.exit(0 if m and re.search(sys.argv[2], m.group(1)) else 1)
PY

# ── 3. Fork attribution must match the downstream hops' ACTUAL frontmatter ──────────
# After the drift hop, Mode D runs a SCRIPT (rebind-units.sh) then the skills
# plan --reconcile → execute-bolts. While neither carries context: fork, no Mode-D
# surface may lump them in with detect-drift as forked downstream phases.
FORKED_DOWNSTREAM="$(python3 - "$PLUGIN_ROOT/skills/plan/SKILL.md" "$PLUGIN_ROOT/skills/execute-bolts/SKILL.md" <<'PY'
import os, sys
out = []
for p in sys.argv[1:]:
    try:
        fm = open(p, encoding="utf-8").read().split('---', 2)[1]
    except Exception:
        print("ERR"); raise SystemExit
    if any(l.strip().startswith('context:') and 'fork' in l for l in fm.splitlines()):
        out.append(os.path.basename(os.path.dirname(p)))
print(",".join(out) if out else "none")
PY
)"
echo "  (forked Mode-D downstream skills = $FORKED_DOWNSTREAM)"

if [ "$FORKED_DOWNSTREAM" = "none" ]; then
  BAD=0
  for f in "$ROUT" "$SYNC"; do
    if grep -qiE 'two forked[^.]*downstream|forked downstream phases' "$f"; then
      fail "$(basename "$f") calls the Mode-D downstream phases forked, but plan/execute-bolts carry no context: fork"
      BAD=1
    fi
  done
  [ "$BAD" -eq 0 ] && pass "no Mode-D surface claims a downstream phase is forked while it is not"
elif [ "$FORKED_DOWNSTREAM" = "ERR" ]; then
  fail "could not parse plan / execute-bolts frontmatter"
else
  # A downstream hop flipped to context: fork — it can no longer ask, so it must carry
  # the non-interactive rail (the same contract detect-drift carries).
  for s in ${FORKED_DOWNSTREAM//,/ }; do
    grep -qiE 'NEVER calls .?AskUserQuestion' "$PLUGIN_ROOT/skills/$s/SKILL.md" \
      && pass "forked $s carries the non-interactive declaration" \
      || fail "$s is context: fork but carries no never-AskUserQuestion rail"
  done
fi

# ── 4. detect-drift IS forked — the attribution must stay TRUE for it ───────────────
DD="$PLUGIN_ROOT/skills/detect-drift/SKILL.md"
if [ -f "$DD" ]; then
  grep -qE '^context:[[:space:]]*fork' "$DD" \
    && pass "detect-drift still carries context: fork (the live precedent)" \
    || fail "detect-drift lost context: fork — the fork precedent is gone"
else
  fail "missing $DD (detect-drift is a kept 9.0 skill)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-sync-lane-vault-signal)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi

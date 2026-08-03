#!/usr/bin/env bash
# test-front-door-flag-parity.sh — v5.33.1 field findings (training-nextjs):
#
#   1. `--step-after` / `--stop-after` were ADVERTISED by the front door's
#      argument-hint but implemented nowhere — orchestrate-flow only knows
#      `--to=`. Forwarded verbatim they are silently dropped, and a `--deep`
#      chain the user asked to stop at bind runs on to execute-bolts (writing
#      code). Pins: both flags carry explicit "renders as --to=" translation
#      lines; the translation LAW sentence exists; orchestrate-flow documents
#      the aliases from its side.
#   2. Ghost-flag guard: every `--flag` token in the argument-hint must appear
#      in the mega-sdd.md BODY too (a hint-only flag is an undefined promise).
#   3. The generate-intent preflight check honors a POSITIONAL input (the
#      root-only probe false-failed on PRD/prd-simkredit.md).
#
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FD="$REPO_ROOT/plugins/mega-sdd/commands/mega-sdd.md"
OF="$REPO_ROOT/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md"
PC="$REPO_ROOT/plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md"

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# ── 1. translation lines + law ───────────────────────────────────────────────
grep -qF -- 'renders to orchestrate-flow as `--to=<phase>`' "$FD" \
  && pass "--step-after carries the --to render line" \
  || fail "--step-after translation line missing"
grep -qF -- 'renders as `--to=<phase>`' "$FD" \
  && pass "--stop-after carries the --to render line" \
  || fail "--stop-after translation line missing"
grep -qF "Translation law:" "$FD" \
  && pass "the translation law is stated (unknown flags are silently dropped by the router)" \
  || fail "translation law sentence missing"
grep -qF -- 'renders as omitting `--auto`' "$FD" \
  && pass "--manual carries its render line" \
  || fail "--manual translation line missing"
grep -qF -- '`--step-after=<phase>` / `--stop-after=<phase>` are ALIASES' "$OF" \
  && pass "orchestrate-flow documents the front-door aliases on --to" \
  || fail "orchestrate-flow missing the alias note"

# ── 1b. the flag is dead INSIDE the router too (round F2 — the auto-continue
# loop itself keyed chain-stop on `--stop-after`, which post-translation never
# arrives; that pseudocode is where the field bug would silently reopen) ─────
HC="$REPO_ROOT/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md"
grep -qF -- 'current phase != the `--to=` bound' "$HC" \
  && pass "handoff-consumption auto-continue keys on --to (not the dead flag)" \
  || fail "handoff-consumption still keys on --stop-after"
if grep -n -- "--stop-after" "$HC" | grep -v "renders\|render\|front door" | grep -qv "never sees"; then
  fail "handoff-consumption carries an un-annotated --stop-after reference"
else
  pass "no un-annotated --stop-after left in handoff-consumption"
fi
HK="$REPO_ROOT/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
grep -qF "FRONT-DOOR" "$HK" && grep -qF "rendered to --to=" "$HK" \
  && pass "handoff-contract flag surface carries the render note" \
  || fail "handoff-contract §flag surface missing the render note"
# 6.0.0 cull: auto.md removed — the render exception's typed-surface home is the
# front door itself (its §Flag handling rows), asserted here.
grep -qF -- 'renders as `--to=<phase>`' "$FD" \
  && pass "front door carries the --stop-after → --to render exception" \
  || fail "front door lost the --stop-after render exception"

# ── 2. ghost-flag guard ──────────────────────────────────────────────────────
GHOSTS=$(FD="$FD" python3 - <<'PY'
import os, re
text = open(os.environ["FD"], encoding="utf-8").read()
lines = text.split("\n")
hint = next((l for l in lines if l.startswith("argument-hint:")), "")
body = "\n".join(l for l in lines if not l.startswith("argument-hint:"))
flags = set(re.findall(r"--[a-z][a-z0-9-]*", hint))
ghosts = sorted(f for f in flags if f not in body)
print("GHOSTS:%s" % ",".join(ghosts))
PY
)
echo "$GHOSTS" | grep -q "^GHOSTS:$" \
  && pass "no ghost flags: every argument-hint flag is defined in the body" \
  || fail "hint-only ghost flags: $(echo "$GHOSTS" | grep GHOSTS)"

# ── 3. positional-aware preflight check ──────────────────────────────────────
grep -qF "POSITIONAL input" "$PC" && grep -qF "generate-intent Rule 2" "$PC" \
  && pass "prd_or_kb_input_present honors a positional input (Rule 2 precedence)" \
  || fail "preflight check still root-only (positional PRD false-fails)"
grep -qF "probes.prd.present" "$PC" \
  && pass "preflight check consults the widened probes.prd" \
  || fail "preflight check not wired to probes.prd"

echo
if [ "$fails" -eq 0 ]; then
  echo "test-front-door-flag-parity: ALL PASS"
  exit 0
else
  echo "test-front-door-flag-parity: $fails FAILURE(S)"
  exit 1
fi

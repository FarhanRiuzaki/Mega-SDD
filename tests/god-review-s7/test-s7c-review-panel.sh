#!/usr/bin/env bash
# test-s7c-review-panel.sh — God-review S7 Batch C: review panel + L0 gate contracts.
#
# Findings (archive ~/.mega-sdd/god-review-s7/panel.md):
#   S7-GATES-2 (HIGH) re-dispatch never re-ran L0 gates; re-reviews got STALE scans
#   S7-PANEL-4 (re-verified live) retries exhausted + spec ❌ + no Critical → fell to mergeable
#   S7-PANEL-3  model_tiers self-contradiction (docs taught a silently-ignored config)
#   S7-TIER-5   risk signal 4 EN-only + no authz vocabulary (Indonesian units unseen)
#   S7-AGENT-6  security-reviewer pre-detect-after framing ("safe to commit")
#   S7-PANEL-7  fabricated unit-frontmatter preview_url source
#   S7-BRIDGE-8 bridge lens-slice line dropped Anti-patterns
#   S7-GATES-9  fallback secret scan word-split argv → spaced filenames unscanned
#
# The panel loop is prose-tier by design (gates > rules > hooks) — the contract
# pins here are the enforcement seam for GATES-2/PANEL-4; GATES-9 is behavioral.
#
# Run: bash tests/god-review-s7/test-s7c-review-panel.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
RP="${P}/skills/execute-bolts/references/review-panel.md"
SK="${P}/skills/execute-bolts/SKILL.md"
BR="${P}/skills/execute-bolts/references/superpowers-bridge.md"
HR="${P}/skills/execute-bolts/references/halt-recovery.md"
MT="${P}/references/model-tiers.md"
SEC="${P}/agents/security-reviewer.md"
SSC="${P}/scripts/scan-secrets-code.sh"
FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d 2>/dev/null || mktemp -d -t s7c)"
trap 'rm -rf "$W"' EXIT

echo "== S7-C: review panel + L0 gate contracts =="

# ── S7-GATES-9 (behavioral): a planted key in a SPACED filename is caught by the fallback ──
STUB="$W/stub"; mkdir -p "$STUB"
printf '#!/bin/sh\nexit 3\n' > "$STUB/gitleaks"; chmod +x "$STUB/gitleaks"  # force the fallback
R="$W/sec"; mkdir -p "$R"
( cd "$R" && git init -q . && git config user.email t@t && git config user.name t )
echo "clean" > "$R/app.py"
( cd "$R" && git add -A && git commit -qm "chore: base" )
B=$(git -C "$R" rev-parse HEAD)
mkdir -p "$R/config files"
printf 'aws_key = "AKIAIOSFODNN7EXAMPLE"\n' > "$R/config files/prod settings.py"
( cd "$R" && git add -A && git commit -qm "feat: leak in spaced path" )
H=$(git -C "$R" rev-parse HEAD)
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --base="$B" --head="$H" --cwd="$R" 2>/dev/null); RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'prod settings.py'; then
  ok "GATES-9: spaced filename SCANNED and the planted key caught (was: word-split → silently unscanned)"
else
  fail "GATES-9: spaced filename still unscanned (rc=$RC): $(printf '%s' "$OUT" | head -c200)"
fi

# ── review r2-2: non-ASCII (git-C-quoted) filename must still be scanned ──
printf 'aws2 = "AKIAIOSFODNN7EXAMPLE"\n' > "$R/naïve-config.py"
( cd "$R" && git add -A && git commit -qm "feat: leak in quoted path" )
H2=$(git -C "$R" rev-parse HEAD)
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --base="$H" --head="$H2" --cwd="$R" 2>/dev/null); RC=$?
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'na.*ve-config.py' \
  && ok "r2-2: git-C-quoted (non-ASCII) filename SCANNED (core.quotepath=off)" \
  || fail "r2-2: quoted filename still silently unscanned (rc=$RC)"

# ── review r1-5: a failed git diff in the fallback is a VISIBLE error, never clean ──
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --base=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --head="$H2" --cwd="$R" 2>"$W/.e12"); RC=$?
[ "$RC" -eq 2 ] && grep -q 'CANNOT run' "$W/.e12" && printf '%s' "$OUT" | grep -q '"skipped": true' \
  && ok "r1-5: unresolvable revision range → exit 2 + skipped:true (was: zero-file clean scan)" \
  || fail "r1-5: dead range still reads as clean (rc=$RC)"

# ── S7-GATES-2: re-dispatch re-enters at the L0 gates (all three contract surfaces) ──
grep -qF 'RE-ENTERS the per-unit flow at the L0 code gates' "$RP" && ok "GATES-2: review-panel.md — re-dispatch re-enters at L0" || fail "GATES-2: review-panel.md missing the re-entry contract"
grep -qF 're-enters at step 3: the L0 gates re-run against the new head' "$SK" && ok "GATES-2: SKILL.md step 4 — re-entry wired" || fail "GATES-2: SKILL.md step 4 missing re-entry"
grep -qF 'RE-ENTERS at "RUN L0 code gates"' "$BR" && ok "GATES-2: bridge diagram routes re-dispatch back through L0" || fail "GATES-2: bridge diagram still skips L0 on re-dispatch"
grep -qF 'FRESH L0 results' "$RP" && ok "GATES-2: re-review prompts pinned to FRESH L0 results (never attempt-1 scans)" || fail "GATES-2: stale-L0 injection not forbidden"
grep -qF 'keeps the ORIGINAL bolt base' "$RP" && ok "GATES-2: re-review diff range pinned to the original bolt base" || fail "GATES-2: re-review diff range still ambiguous"

# ── S7-PANEL-4: spec ❌ at cap exhaustion is terminal, never mergeable ──
grep -qF 'OR the spec lens still ❌' "$RP" && ok "PANEL-4: retries-exhausted halt fires on spec ❌ too (mergeable fall-through closed)" || fail "PANEL-4: spec-❌-at-exhaustion still undefined in review-panel.md"
grep -qF 'OR the spec lens still ❌' "$HR" && ok "PANEL-4: halt-recovery.md condition matches" || fail "PANEL-4: halt-recovery.md still Critical-only"
grep -qF 'OR spec still ❌' "$SK" && grep -qF 'OR spec still ❌' "$BR" && ok "PANEL-4: SKILL.md + bridge carry the same terminal condition" || fail "PANEL-4: SKILL/bridge terminal condition drifted"

# ── S7-PANEL-3: model_tiers contradiction resolved everywhere ──
if grep -qF 'per-lens model tiers via `model_tiers:`' "$RP"; then fail "PANEL-3: cost notes still teach the ignored override"; else ok "PANEL-3: cost notes no longer teach the silently-ignored model_tiers override"; fi
grep -qF 'Do not configure panel lenses here' "$MT" && ok "PANEL-3: model-tiers.md scopes the override chain away from panel lenses" || fail "PANEL-3: model-tiers.md missing the scope note"
if grep -qE '^\s*(- )?`?code-quality-reviewer`?: sonnet' "$MT"; then fail "PANEL-3: model-tiers.md still shows a panel lens as the flagship override example"; else ok "PANEL-3: override examples use non-panel roles"; fi

# ── S7-TIER-5: risk signal 4 carries authz + Indonesian vocabulary ──
grep -qF 'role, permission, access, admin, acl, approv-' "$RP" && grep -qF 'hak akses' "$RP" && grep -qF 'pembayaran' "$RP" && grep -qF 'persetujuan' "$RP" \
  && grep -qF 'matched as WHOLE words' "$RP" \
  && ok "TIER-5: signal 4 covers the authz class + Indonesian equivalents, word-boundary matched" \
  || fail "TIER-5: signal 4 still EN-only / authz-blind / substring-noisy"

# ── S7-AGENT-6: security-reviewer speaks detect-after ──
if grep -qF 'must fix before commit' "$SEC" || grep -qF 'safe to commit' "$SEC"; then
  fail "AGENT-6: security-reviewer still speaks pre-commit"
else
  grep -qF 'mergeable as-is' "$SEC" && grep -qF 'fix-forward or revert' "$SEC" \
    && ok "AGENT-6: security-reviewer verdicts are detect-after (mergeable/fix-forward)" \
    || fail "AGENT-6: detect-after wording missing"
fi

# ── S7-PANEL-7 / S7-BRIDGE-8: doc truth ──
if grep -qF 'unit frontmatter `preview_url`' "$RP"; then fail "PANEL-7: fabricated unit-frontmatter preview_url survives"; else ok "PANEL-7: preview_url sources are real (config or operator only)"; fi
grep -qF 'Anchors/Anti-patterns + Migration notes' "$BR" && ok "BRIDGE-8: bridge lens slice includes Anti-patterns (matches review-panel.md)" || fail "BRIDGE-8: bridge still drops Anti-patterns"

if [ "$FAILED" -eq 0 ]; then echo "ALL S7-C OK"; else echo "S7-C had failures"; fi
exit $FAILED

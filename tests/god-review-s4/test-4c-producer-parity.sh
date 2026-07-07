#!/usr/bin/env bash
# test-4c-producer-parity.sh — god-review stage 4, Batch 4C.
# Pins producer→consumer parity between scan-codebase's map, bind-codebase, and
# generate-units:
#
#   BC-PREFLIGHT-LEGACY  predictive preflight accepts the legacy <root>/codebase-map.md
#                        location bind-codebase's own probe order supports.
#   BC-MAPARG-1          an explicit second-positional map path is validated by the
#                        DEGENERATE-MAP gate (--file-path): a degenerate custom map
#                        BLOCKS bind; a valid custom map is NOT blocked by an
#                        unrelated degenerate canonical shell.
#   BC-TRUNC-1           doc-pinned: bind carries state_reason: truncated_section;
#                        generate-units routes truncation-UNKNOWN through the
#                        direct-probe sub-rule (never straight `create`).
#   BC-STATE-2           doc-pinned: IMPLEMENTED at medium/low confidence never mints
#                        a verify; row precedence is defined; PARTIAL_FIELDS_BOTH
#                        assigns `extend`.
#   BC-STALE-1           doc-pinned: snapshot-verified requires stamp==HEAD; the map
#                        schema no longer attests a comparison bind doesn't do.
#
# Run: bash tests/god-review-s4/test-4c-producer-parity.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
VPF="${ROOT}/plugins/mega-sdd/scripts/validate-preflight.sh"
VCM="${ROOT}/plugins/mega-sdd/scripts/validate-codebase-map.sh"
TT="${ROOT}/plugins/mega-sdd/skills/generate-units/references/task-typing.md"
DG="${ROOT}/plugins/mega-sdd/skills/generate-units/references/defensive-generation.md"
GUS="${ROOT}/plugins/mega-sdd/skills/generate-units/SKILL.md"
IS="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md"
BC="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md"
BJS="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md"
BSK="${ROOT}/plugins/mega-sdd/skills/bind-codebase/SKILL.md"
AMH="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md"
CMS="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/codebase-map-schema.md"
for f in "$PRE" "$VPF" "$VCM" "$TT" "$DG" "$GUS" "$IS" "$BC" "$BJS" "$BSK" "$AMH" "$CMS"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t par4c)"
trap 'rm -rf "$WORK"' EXIT

VALID_MAP='---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-02T10:00:00Z
repo_root: ./
languages_detected: ["typescript"]
engine: tree-sitter
precision_tier: ast
last_scanned_commit: 0123456789abcdef0123456789abcdef01234567
---
## 1. Top-level structure
- src/

## 2. Public interfaces
| File | Type | Symbol | Signature | Last_Scanned_Sha256 |
|---|---|---|---|---|
| src/auth.ts:42 | function | login | login(user: string, pass: string) | abc123 |

## 3. Routes / Endpoints
| Method | Path | Handler |
|---|---|---|

## 4. Data models / Schemas
None detected

## 5. Naming conventions
- Case style: camelCase

## 6. Pattern signatures
- Auth pattern: jwt

## 7. Framework
framework:
  name: express'

DEGEN_MAP='---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-02T10:00:00Z
repo_root: ./
languages_detected: []
engine: regex
precision_tier: regex
---
# codebase map (empty shell)'

mkvault() { mkdir -p "$1/.mega-sdd/vaults/v1"; printf '{"vault":"v1"}\n' > "$1/.mega-sdd/vaults/v1/vault.json"; }

note "== 4C: producer parity + preflight =="

# ── BC-PREFLIGHT-LEGACY ──
F1="$WORK/legacy"; mkvault "$F1"
printf '%s\n' "$VALID_MAP" > "$F1/codebase-map.md"
bash "$VPF" --cwd="$F1" --skill="mega-sdd:bind-codebase" --quiet >/dev/null 2>&1
S=$(python3 -c "import json; print(json.load(open('$F1/.mega-sdd/.preflight-state.json')).get('status'))" 2>/dev/null)
[ "$S" != "FATAL" ] && ok "BC-PREFLIGHT-LEGACY: legacy <root>/codebase-map.md accepted (status=$S)" || fail "BC-PREFLIGHT-LEGACY: legacy map still FATAL-blocks bind"
F2="$WORK/nomap"; mkvault "$F2"
bash "$VPF" --cwd="$F2" --skill="mega-sdd:bind-codebase" --quiet >/dev/null 2>&1
S=$(python3 -c "import json; print(json.load(open('$F2/.mega-sdd/.preflight-state.json')).get('status'))" 2>/dev/null)
[ "$S" = "FATAL" ] && ok "BC-PREFLIGHT-LEGACY: NO map anywhere still FATAL (guard intact)" || fail "BC-PREFLIGHT-LEGACY: no-map case regressed (status=$S)"

# ── BC-MAPARG-1: explicit map positional is gated ──
F3="$WORK/customdegen"; mkvault "$F3"; mkdir -p "$F3/maps" "$F3/.git"
printf '%s\n' "$DEGEN_MAP" > "$F3/maps/custom-map.md"
# preflight needs SOME map; the custom arg is the bind input — put a valid map at legacy root
printf '%s\n' "$VALID_MAP" > "$F3/codebase-map.md"
OUT=$(HOOK="$PRE" FIX="$F3" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1 maps/custom-map.md"}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
')
echo "$OUT" | grep -q "structurally DEGENERATE" && ok "BC-MAPARG-1: degenerate CUSTOM-path map blocks bind (was ungated)" || fail "BC-MAPARG-1: custom degenerate map escapes the gate (out: ${OUT:0:160})"

F4="$WORK/customok"; mkvault "$F4"; mkdir -p "$F4/maps" "$F4/.mega-sdd/codebase" "$F4/.git"
printf '%s\n' "$DEGEN_MAP" > "$F4/.mega-sdd/codebase/codebase-map.md"   # stale degenerate canonical shell
printf '%s\n' "$VALID_MAP" > "$F4/maps/custom-map.md"                    # the ACTUAL bind input, valid
OUT=$(HOOK="$PRE" FIX="$F4" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1 maps/custom-map.md"}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
')
echo "$OUT" | grep -q "structurally DEGENERATE" && fail "BC-MAPARG-1: valid custom map falsely blocked by the unrelated canonical shell" || ok "BC-MAPARG-1: valid custom map not blocked by a degenerate canonical shell"

# round-2 POISON-A: the custom-map run must NOT leave its verdict in the shared
# state — a subsequent PLAIN bind against the degenerate canonical map must still block.
OUT=$(HOOK="$PRE" FIX="$F4" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1"}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
')
echo "$OUT" | grep -q "structurally DEGENERATE" && ok "r2 POISON-A: plain bind after a valid-custom bind still blocks on the degenerate canonical (no PASS poisoning)" || fail "r2 POISON-A: custom-run PASS poisoned the shared state — degenerate canonical bind allowed"

# round-2 POISON-B: a degenerate custom arg must not false-block the NEXT plain
# bind against a VALID canonical map.
F5="$WORK/poisonb"; mkvault "$F5"; mkdir -p "$F5/maps" "$F5/.mega-sdd/codebase" "$F5/.git"
printf '%s\n' "$VALID_MAP" > "$F5/.mega-sdd/codebase/codebase-map.md"
printf '%s\n' "$DEGEN_MAP" > "$F5/maps/custom-map.md"
HOOK="$PRE" FIX="$F5" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1 maps/custom-map.md"}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload), capture_output=True, text=True, timeout=120)
' >/dev/null
OUT=$(HOOK="$PRE" FIX="$F5" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1"}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
')
echo "$OUT" | grep -q "structurally DEGENERATE" && fail "r2 POISON-B: degenerate-custom FAIL poisoned the state — valid canonical bind falsely blocked" || ok "r2 POISON-B: plain bind against the valid canonical map unaffected by a prior degenerate-custom deny"

# round-2 SPACES: quoted custom map path with spaces is still gated
F6="$WORK/spaces"; mkvault "$F6"; mkdir -p "$F6/my docs" "$F6/.git"
printf '%s\n' "$DEGEN_MAP" > "$F6/my docs/map file.md"
printf '%s\n' "$VALID_MAP" > "$F6/codebase-map.md"
OUT=$(HOOK="$PRE" FIX="$F6" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1 \"my docs/map file.md\""}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
')
echo "$OUT" | grep -q "structurally DEGENERATE" && ok "r2 SPACES: quoted space-containing degenerate custom map is gated (shlex tokenizing)" || fail "r2 SPACES: space-path custom map escapes the gate"

# round-2 S4R-1: a vault doc named positionally is NEVER validated as the map
F7="$WORK/vaultdoc"; mkvault "$F7"; mkdir -p "$F7/.mega-sdd/codebase" "$F7/.git"
printf '%s\n' '# vault index (not a map)' > "$F7/.mega-sdd/vaults/v1/00-index.md"
printf '%s\n' "$VALID_MAP" > "$F7/.mega-sdd/codebase/codebase-map.md"
OUT=$(HOOK="$PRE" FIX="$F7" TI='{"skill": "mega-sdd:bind-codebase", "args": ".mega-sdd/vaults/v1/00-index.md"}' python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
')
echo "$OUT" | grep -q "structurally DEGENERATE" && fail "r2 S4R-1: vault doc positional was validated as the map (false block)" || ok "r2 S4R-1: vault-doc positional excluded from map candidates (canonical map used)"

# ── BC-TRUNC-1: doc pins (truncation signal end-to-end) ──
grep -qF 'state_reason: truncated_section' "$IS" && ok "BC-TRUNC-1: implementation-state mandates the binding-surface truncation signal" || fail "BC-TRUNC-1: producer signal rule missing (implementation-state.md)"
grep -qF '"state_reason"' "$BJS" && ok "BC-TRUNC-1: binding.json schema carries state_reason" || fail "BC-TRUNC-1: state_reason absent from binding-json-schema.md"
grep -qF 'truncated §4 — absence is not evidence' "$BC" && ok "BC-TRUNC-1: contract shows the truncation Anchor-cell convention" || fail "BC-TRUNC-1: contract example row missing"
grep -qF 'Probe the repo directly' "$TT" && ok "BC-TRUNC-1: task-typing routes truncation-UNKNOWN through the direct probe" || fail "BC-TRUNC-1: probe sub-rule missing (task-typing.md)"
grep -qF 'never a create-type task from a truncated section' "$TT" && ok "BC-TRUNC-1: task-typing cites the producer promise it now delivers" || fail "BC-TRUNC-1: producer-promise citation missing"
if grep -qE '\| Any UNKNOWN \(regardless of confidence\) \| `create`' "$TT"; then fail "BC-TRUNC-1: old unconditional UNKNOWN→create row survives"; else ok "BC-TRUNC-1: unconditional UNKNOWN→create row removed"; fi
grep -qF 'truncation-sourced UNKNOWN goes through the direct-probe sub-rule FIRST' "$GUS" && ok "BC-TRUNC-1: generate-units SKILL routes the sub-rule" || fail "BC-TRUNC-1: SKILL.md core assignment stale"

# ── BC-STATE-2: doc pins (unmapped inputs + precedence) ──
grep -qF 'All IMPLEMENTED with `confidence: medium` or `low`' "$TT" && ok "BC-STATE-2: IMPLEMENTED medium/low row exists (treated as UNKNOWN)" || fail "BC-STATE-2: medium/low IMPLEMENTED unmapped"
grep -qF '**Row precedence**' "$TT" && ok "BC-STATE-2: row precedence defined" || fail "BC-STATE-2: precedence rule missing"
grep -qE '\*\*PARTIAL_FIELDS_BOTH\*\*[^|]*\| `extend` with HUMAN REVIEW' "$TT" && ok "BC-STATE-2: PARTIAL_FIELDS_BOTH row assigns extend explicitly" || fail "BC-STATE-2: BOTH row still assigns no task_type"
# v4.73.0 (Batch A3): task-typing.md became the SINGLE OWNER of task_type assignment —
# the defensive-generation copy of the table (the contradiction's host) was deleted.
# Pin the guarantee at its operative home + pin that no contradicting unconditional
# IMPLEMENTED→verify table row re-grows in defensive-generation.
grep -qF 'ONLY at `confidence: high`; medium/low' "$TT" && ok "BC-STATE-2: single-owner IMPLEMENTED row carries the high-only qualifier (task-typing.md)" || fail "BC-STATE-2: high-only qualifier lost from the single owner"
if grep -qE '^\| *`?IMPLEMENTED`? *(\(V == C\))? *\| *`verify`' "$DG"; then fail "BC-STATE-2: defensive-generation re-grew a contradicting IMPLEMENTED→verify table row"; else ok "BC-STATE-2: defensive-generation carries no competing task_type row (single-owner holds)"; fi

# ── BC-STALE-1: doc pins (staleness truth) ──
grep -qF 'REGARDLESS of the sha256 match' "$AMH" && ok "BC-STALE-1: bind Step 1 currency check (stamp vs HEAD) specified" || fail "BC-STALE-1: currency check missing from auto-memory-handoff"
grep -qF 'last_scanned_commit` == current HEAD' "$BSK" && ok "BC-STALE-1: bind SKILL Step 1 states the snapshot-verified condition" || fail "BC-STALE-1: SKILL Step 1 stale"
grep -qF 'bind-codebase` Step 1 (S4) reads the stamp' "$CMS" && ok "BC-STALE-1: map schema attestation now matches bind behavior" || fail "BC-STALE-1: map schema still attests an unimplemented comparison"
if grep -qF '`detect-drift` / `bind-codebase` compare it to current HEAD' "$CMS"; then fail "BC-STALE-1: old joint attestation survives"; else ok "BC-STALE-1: old joint attestation removed"; fi

if [ "$FAILED" -eq 0 ]; then note "ALL 4C OK"; else note "4C had failures"; fi
exit $FAILED

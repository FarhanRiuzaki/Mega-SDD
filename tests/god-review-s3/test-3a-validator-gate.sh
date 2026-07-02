#!/usr/bin/env bash
# test-3a-validator-gate.sh — god-review stage 3, Batch 3A.
# Pins validate-codebase-map.sh determinism: the validator must judge the map
# grammar the scan procedure actually emits, on the paths bind-codebase actually
# binds against, without fenced-block/citation false-satisfaction.
#
#   INT-1  the state file self-heals at gate time (validator is re-runnable and
#          correct on both directions: fresh degenerate map after mv; valid map
#          replacing a stale FAIL state).
#   V5     headings/frontmatter quoted inside a fenced code block do NOT satisfy
#          the presence checks (the schema's own fenced skeleton is the bypass shape).
#   V1     interface-depth heuristics run on the Signature CELL only — a file:line
#          citation in the File column no longer counts as a signature.
#   V6     `engine` is required frontmatter; missing last_scanned_commit in a git
#          repo → WARN codebase_map_staleness_stamp_missing (advisory).
#   V7     legacy <root>/codebase-map.md is probed and validated; --file-path wins.
#
# Run: bash tests/god-review-s3/test-3a-validator-gate.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
V="${ROOT}/plugins/mega-sdd/scripts/validate-codebase-map.sh"
[ -f "$V" ] || { echo "missing $V"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t val3a)"
trap 'rm -rf "$WORK"' EXIT

FM_OK='---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-02T10:00:00Z
repo_root: ./
languages_detected: ["typescript"]
engine: tree-sitter
precision_tier: ast
last_scanned_commit: 0123456789abcdef0123456789abcdef01234567
---'

SECTIONS_OK='## 1. Top-level structure
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

mkproj() { # $1=subdir $2=map-content $3=map-relpath (default canonical)
  local d="$WORK/$1"; local rel="${3:-.mega-sdd/codebase/codebase-map.md}"
  mkdir -p "$d/$(dirname "$rel")" "$d/.mega-sdd" "$d/.git"
  printf '%s\n' "$2" > "$d/$rel"
}
run() { bash "$V" --cwd="$WORK/$1" ${2:+--file-path="$2"} 2>/dev/null; }
field() { OUT="$1" python3 -c "import json,os;d=json.loads(os.environ['OUT']);print($2)" 2>/dev/null; }

note "== 3A: validate-codebase-map determinism =="

# ── baseline: conformant map → PASS ──
mkproj good "$FM_OK
$SECTIONS_OK"
J="$(run good)"
[ "$(field "$J" "d.get('status')")" = "PASS" ] && ok "conformant map → PASS" || fail "conformant map should PASS: $J"

# ── V5: headings ONLY inside a fenced block → all 7 sections missing → FAIL ──
mkproj fenced "$FM_OK

The scan produced the template below.

\`\`\`markdown
$SECTIONS_OK
\`\`\`"
J="$(run fenced)"
[ "$(field "$J" "d.get('status')")" = "FAIL" ] && ok "V5: fenced-skeleton map → FAIL (no substring bypass)" || fail "V5: fenced skeleton should FAIL: $(field "$J" "d.get('status')")"
[ "$(field "$J" "any(i.get('halt_type')=='codebase_map_sections_incomplete' and len(i.get('missing',[]))>=7 for i in d.get('issues',[]))")" = "True" ] \
  && ok "V5: all 7 sections reported missing (DEGENERATE shape visible to the gate)" || fail "V5: gate-shape issue absent"

# ── V1: rows whose ONLY ':'-token is the File-column citation → depth WARN ──
mkproj bare "$FM_OK
## 1. Top-level structure
- src/

## 2. Public interfaces
| File | Type | Symbol | Signature | Last_Scanned_Sha256 |
|---|---|---|---|---|
| src/auth.ts:42 | function | login |  | abc123 |
| src/user.ts:7 | class | User |  | def456 |

## 3. Routes / Endpoints
None detected

## 4. Data models / Schemas
None detected

## 5. Naming conventions
- Case style: camelCase

## 6. Pattern signatures
- Auth pattern: jwt

## 7. Framework
framework:
  name: express"
J="$(run bare)"
[ "$(field "$J" "next((c.get('status') for c in d.get('checks',[]) if c.get('check')=='interface_depth'),'')")" = "WARN" ] \
  && ok "V1: ast + citation-bearing rows with EMPTY Signature cells → depth WARN (was dead PASS)" \
  || fail "V1: empty-signature rows should WARN interface_depth: $J"
J="$(run good)"
[ "$(field "$J" "next((c.get('status') for c in d.get('checks',[]) if c.get('check')=='interface_depth'),'')")" = "PASS" ] \
  && ok "V1: real signature in the Signature cell still → depth PASS" || fail "V1: real signature should PASS depth"

# ── V6: engine missing → FAIL; stamp missing in a git repo → WARN ──
mkproj noeng "---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-02T10:00:00Z
repo_root: ./
languages_detected: [\"typescript\"]
---
$SECTIONS_OK"
J="$(run noeng)"
[ "$(field "$J" "d.get('status')")" = "FAIL" ] && ok "V6: missing engine → FAIL (fm required)" || fail "V6: missing engine should FAIL"
mkproj nostamp "---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-02T10:00:00Z
repo_root: ./
languages_detected: [\"typescript\"]
engine: regex
precision_tier: regex
---
$SECTIONS_OK"
# the stamp WARN keys on a RESOLVABLE HEAD (zero-commit repos legitimately omit the
# stamp) — make the fixture a real git repo with one commit
rm -rf "$WORK/nostamp/.git"
( cd "$WORK/nostamp" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m x )
J="$(run nostamp)"
[ "$(field "$J" "d.get('status')")" = "WARN" ] && ok "V6: git repo + no last_scanned_commit → WARN (not PASS, not FAIL)" || fail "V6: missing stamp should WARN: $(field "$J" "d.get('status')")"
[ "$(field "$J" "any(i.get('halt_type')=='codebase_map_staleness_stamp_missing' for i in d.get('issues',[]))")" = "True" ] \
  && ok "V6: codebase_map_staleness_stamp_missing named" || fail "V6: stamp issue not named"

# ── V7: legacy <root>/codebase-map.md is probed when canonical absent ──
mkproj legacy "$FM_OK
$SECTIONS_OK" "codebase-map.md"
J="$(run legacy)"
[ "$(field "$J" "d.get('status')")" = "PASS" ] && ok "V7: legacy root map probed + validated (PASS)" || fail "V7: legacy map should be found: $J"
[ "$(field "$J" "d.get('checked_file')")" = "codebase-map.md" ] && ok "V7: checked_file reports the legacy path" || fail "V7: wrong checked_file: $(field "$J" "d.get('checked_file')")"

# ── V7: --file-path wins over probing ──
mkdir -p "$WORK/fp/.mega-sdd"; mkdir -p "$WORK/fp/.git"
printf '%s\n' "$FM_OK" "$SECTIONS_OK" > "$WORK/fp/other-map.md"
J="$(run fp "$WORK/fp/other-map.md")"
[ "$(field "$J" "d.get('status')")" = "PASS" ] && ok "V7: explicit --file-path validated" || fail "V7: --file-path should be validated: $J"

# ── INT-1: state self-heal semantics — validator is authoritative on re-run ──
# Direction 1 (fail-open): degenerate map lands via mv (no hook) → a direct
# validator run (what the PreToolUse self-heal executes) must write FAIL state.
mkproj heal "$FM_OK
$SECTIONS_OK"
ST="$WORK/heal/.mega-sdd/.codebase-map-state.json"
run heal >/dev/null
mv "$WORK/heal/.mega-sdd/codebase/codebase-map.md" "$WORK/heal/.mega-sdd/codebase/.tmp-map"
printf '%s\n' "$FM_OK" "" "empty shell" > "$WORK/heal/.mega-sdd/codebase/codebase-map.md"
run heal >/dev/null
[ "$(field "$(cat "$ST")" "d.get('status')")" = "FAIL" ] && ok "INT-1: re-validation after mv-degenerate → state FAIL (gate sees it)" || fail "INT-1: degenerate state not refreshed"
# Direction 2 (false-block): valid map restored via mv → re-run must clear FAIL.
mv "$WORK/heal/.mega-sdd/codebase/.tmp-map" "$WORK/heal/.mega-sdd/codebase/codebase-map.md"
run heal >/dev/null
[ "$(field "$(cat "$ST")" "d.get('status')")" = "PASS" ] && ok "INT-1: re-validation after valid re-scan → state clears to PASS (no permanent block)" || fail "INT-1: stale FAIL state not cleared"
# The hook wiring itself: pre-tool-use contains the lazy re-validate block.
grep -q "codebase-map-state.json" "$ROOT/plugins/mega-sdd/hooks/pre-tool-use" \
  && grep -q '! "$CM_STATE" -nt "$CM_MAP"' "$ROOT/plugins/mega-sdd/hooks/pre-tool-use" \
  && ok "INT-1: pre-tool-use lazy re-validate — state must be STRICTLY newer (tie re-validates)" \
  || fail "INT-1: pre-tool-use self-heal wiring missing/weakened"
grep -q '\*/codebase-map.md|codebase-map.md' "$ROOT/plugins/mega-sdd/hooks/post-tool-use" \
  && ok "V7: post-tool-use dispatch widened to the legacy root path" \
  || fail "V7: post-tool-use legacy dispatch missing"

# ── round-2 (fix-review): TRUE legacy layout — root map, NO .mega-sdd/ dir yet ──
# Pre-fix: every state write failed silently (ENOENT swallowed) → gate read nothing.
mkdir -p "$WORK/rawlegacy/.git"
printf '%s\n' "$FM_OK" "" "empty shell, no sections" > "$WORK/rawlegacy/codebase-map.md"
J="$(run rawlegacy)"
[ -f "$WORK/rawlegacy/.mega-sdd/.codebase-map-state.json" ] \
  && ok "r2: state dir auto-created — legacy layout WITHOUT .mega-sdd/ gets a state file" \
  || fail "r2: state file still not written for raw legacy layout"
[ "$(field "$(cat "$WORK/rawlegacy/.mega-sdd/.codebase-map-state.json" 2>/dev/null)" "d.get('status')")" = "FAIL" ] \
  && ok "r2: raw-legacy degenerate map → state FAIL (gate sees it)" || fail "r2: raw-legacy state not FAIL"

# ── round-2: explicit --file-path that doesn't exist → exit 2, never a probed PASS ──
run good >/dev/null   # ensure a valid canonical state exists to tempt the fallback
bash "$V" --cwd="$WORK/good" --file-path="$WORK/good/does-not-exist.md" >/dev/null 2>&1
RC=$?
[ "$RC" -eq 2 ] && ok "r2: missing --file-path → exit 2 (no silent substitution of a probed map)" \
  || fail "r2: missing --file-path should exit 2, got $RC"
[ "$(field "$(cat "$WORK/good/.mega-sdd/.codebase-map-state.json")" "d.get('status')")" = "PASS" ] \
  && ok "r2: prior state untouched by the failed explicit call" || fail "r2: state clobbered by usage error"

# ── round-2: literal-HEAD stamp (zero-commit-era poison) → WARN, not PASS ──
mkproj headstamp "---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-07-02T10:00:00Z
repo_root: ./
languages_detected: [\"typescript\"]
engine: regex
precision_tier: regex
last_scanned_commit: HEAD
---
$SECTIONS_OK"
J="$(run headstamp)"
[ "$(field "$J" "d.get('status')")" = "WARN" ] \
  && [ "$(field "$J" "any('literal' in (i.get('detail') or '') for i in d.get('issues',[]))")" = "True" ] \
  && ok "r2: last_scanned_commit: HEAD → WARN (consumers treat literal HEAD as missing)" \
  || fail "r2: literal-HEAD stamp should WARN: $J"

if [ "$FAILED" -eq 0 ]; then note "ALL 3A OK"; else note "3A had failures"; fi
exit $FAILED

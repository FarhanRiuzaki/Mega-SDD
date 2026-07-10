#!/usr/bin/env bash
# test-s7a-hardrule-engine.sh — God-review S7 Batch A: the Hard-rule engine holes.
#
# Empirical fixture reproducing the audit probes (archive ~/.mega-sdd/god-review-s7/hardrules.md):
#   HR-1 (CRITICAL) v2 relative files: glob was INERT under ast-grep → normalized **/
#   HR-3 SIGNATURE_RULE token-subset passed ADDED params → paren-list equality
#   HR-4 '*' bullets silently dropped → all bullet forms lex; non-bullets fail unparseable
#   HR-5 DO_NOT_ADD_DEPS diffed to HEAD → bounded to the unit's own commit range
#   HR-6 rename dodge (git mv locked) → old path recorded as deletion
#   HR-7 'MUST NOT modify' was attestable → mechanical synonym, cannot be attested past
#   HR-9 writer warns PROVISIONAL when working-tree unit text ≠ bolt-commit text
# Plus doc pins (grammar-v2 **/-glob + stays-v1 mapping; hard-rule-scan recompute truth,
# blanket-attest disclosure, commit-the-rule-edit remediation).
#
# Run: bash tests/god-review-s7/test-s7a-hardrule-engine.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PF="${ROOT}/plugins/mega-sdd/scripts/run-postflight-scan.sh"
GR="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/hard-rule-grammar-v2.md"
HS="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/hard-rule-scan.md"
FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d 2>/dev/null || mktemp -d -t s7a)"
trap 'rm -rf "$W"' EXIT

echo "== S7-A: Hard-rule engine =="

# ── fixture repo ──
mkdir -p "$W/.mega-sdd/vaults/v1/units" "$W/src"
unit() { # $1=id $2=rule-lines (already formatted)
  printf -- '---\nunit_id: %s\ntask_type: create\n---\n# %s\n## Hard rules\n%s\n' "$1" "$1" "$2" \
    > "$W/.mega-sdd/vaults/v1/units/$1.md"
}
( cd "$W" && git init -q . && git config user.email t@t && git config user.name t )
echo "<?php // l1" > "$W/src/l1.php"; echo "<?php // l2" > "$W/src/l2.php"
echo "<?php // l3" > "$W/src/l3.php"
printf 'function f(a: string, b: string, c?: string): Promise<X> {\n  return x;\n}\n' > "$W/src/f.ts"
printf '{\n "dependencies": {}\n}\n' > "$W/package.json"
unit U-101 '* DO NOT modify src/l1.php'
unit U-102 '- DO NOT modify src/l2.php'
unit U-103 '- MUST NOT modify src/l3.php'
unit U-104 '- DO NOT add new package.json dependencies'
unit U-105 '- function f MUST preserve signature: (a: string, b: string) => Promise<X>'
( cd "$W" && git add -A && git commit -qm "chore: base" )

run() { ( cd "$W" && bash "$PF" --cwd="$W" "$@" </dev/null 2>"$W/.err" ); }

# HR-4: star-bullet rule must be LEXED and enforced
( cd "$W" && echo "// edit" >> src/l1.php && git add -A && git commit -qm "feat(U-101): bolt" )
run --unit=U-101; RC=$?
ART="$W/.mega-sdd/vaults/v1/bolts/U-101/postflight.json"
if [ "$RC" -ne 0 ] && grep -q '"DO_NOT_MODIFY"' "$ART" && ! grep -q 'section empty' "$ART"; then
  ok "HR-4: '*' bullet lock lexed + violation FAILS (was: silently dropped, placeholder pass)"
else
  fail "HR-4: star bullet still dropped (rc=$RC): $(head -c200 "$ART" 2>/dev/null)"
fi

# HR-6: rename of the locked file must fail
( cd "$W" && git mv src/l2.php src/l2b.php && git commit -qm "feat(U-102): bolt" )
run --unit=U-102; RC=$?
[ "$RC" -ne 0 ] && ok "HR-6: git mv of the locked path FAILS (rename dodge closed)" \
  || fail "HR-6: rename still passes"

# HR-7: MUST NOT modify is mechanical — attest cannot wave it through
( cd "$W" && echo "// edit" >> src/l3.php && git add -A && git commit -qm "feat(U-103): bolt" )
run --unit=U-103 --attest-directives="panel reviewed"; RC=$?
if [ "$RC" -ne 0 ] && grep -q '"DO_NOT_MODIFY"' "$W/.mega-sdd/vaults/v1/bolts/U-103/postflight.json"; then
  ok "HR-7: 'MUST NOT modify' classified MECHANICAL; violation fails even with --attest-directives"
else
  fail "HR-7: modal synonym still attestable (rc=$RC)"
fi

# HR-5: a LATER unrelated dep commit must not flip U-104's verdict
( cd "$W" && echo "u4" > src/u4.txt && git add -A && git commit -qm "feat(U-104): bolt" )
( cd "$W" && printf '{\n "dependencies": {"left-pad": "^1.0"}\n}\n' > package.json && git add -A && git commit -qm "chore: unrelated dep" )
run --unit=U-104; RC=$?
[ "$RC" -eq 0 ] && ok "HR-5: dep diff bounded to the unit's own range (later dep commit no longer false-fails)" \
  || fail "HR-5: cross-commit false-fail persists: $(grep -o '"evidence[^}]*' "$W/.mega-sdd/vaults/v1/bolts/U-104/postflight.json" | head -1)"

# HR-3: ADDED parameter must fail (no preflight snapshot)
run --unit=U-105; RC=$?
[ "$RC" -ne 0 ] && grep -q 'parameter list differs' "$W/.mega-sdd/vaults/v1/bolts/U-105/postflight.json" \
  && ok "HR-3: added parameter FAILS via paren-list equality (token-subset hole closed)" \
  || fail "HR-3: added param still passes (rc=$RC)"

# HR-9: provisional WARN when tree unit-text ≠ bolt-commit text
( cd "$W" && printf -- '---\nunit_id: U-101\ntask_type: create\n---\n# U-101\n## Hard rules\n- MUST document the edit\n' > .mega-sdd/vaults/v1/units/U-101.md )
run --unit=U-101 --attest-directives="x" >/dev/null; true
grep -q 'PROVISIONAL' "$W/.err" && ok "HR-9: writer warns PROVISIONAL on tree-vs-commit unit-text drift" \
  || fail "HR-9: no provisional warning: $(head -1 "$W/.err" 2>/dev/null)"

# ── S7-A review round (r1/r2) probes ──

# r2-2: modal synonym with a PROSE object stays a DIRECTIVE (needs attest), never
# a vacuous mechanical pass on the path "existing"
unit U-107 '- MUST NOT modify existing API response contracts'
( cd "$W" && echo "u7" > src/u7.txt && git add -A && git commit -qm "feat(U-107): bolt" )
run --unit=U-107; RC=$?
if [ "$RC" -ne 0 ] && grep -q 'directive_unverified' "$W/.mega-sdd/vaults/v1/bolts/U-107/postflight.json"; then
  run --unit=U-107 --attest-directives="panel reviewed"; RC2=$?
  [ "$RC2" -eq 0 ] && ok "r2-2: prose-object modal stays directive (unverified w/o attest, attested with)" \
    || fail "r2-2: attest no longer clears the prose directive (rc=$RC2)"
else
  fail "r2-2: prose modal auto-greened as mechanical (rc=$RC): $(grep -o '"verdict[^,]*' "$W/.mega-sdd/vaults/v1/bolts/U-107/postflight.json" | head -1)"
fi

# HR-5 true-positive: a dep added by the unit's OWN bolt commit must still FAIL
unit U-108 '- DO NOT add new package.json dependencies'
( cd "$W" && printf '{\n "dependencies": {"left-pad": "^1.0", "evil-pkg": "^2.0"}\n}\n' > package.json \
  && git add -A && git commit -qm "feat(U-108): bolt" )
run --unit=U-108; RC=$?
[ "$RC" -ne 0 ] && grep -q 'evil-pkg' "$W/.mega-sdd/vaults/v1/bolts/U-108/postflight.json" \
  && ok "r1-3/r2-6: dep added in the unit's OWN commit FAILS (true-positive preserved)" \
  || fail "r1-3: own-commit dep addition passes (rc=$RC)"

# r1-3: the sanctioned fix(U-XXX) remediation commit must NOT re-widen U-104's
# range across the interleaved unrelated dep commit
( cd "$W" && printf 'note\n' >> .mega-sdd/vaults/v1/units/U-104.md \
  && git add .mega-sdd/vaults/v1/units/U-104.md && git commit -qm "fix(U-104): correct hard rule" )
run --unit=U-104; RC=$?
[ "$RC" -eq 0 ] && ok "r1-3: fix(U-XXX) remediation commit does not re-widen the dep range" \
  || fail "r1-3: fix-commit re-widened the span — interleaved dep false-fails again (rc=$RC)"

# r1-4: prose tolerance parity with validate-unit-spec — intro prose, bold labels,
# decorative non-dash bullets are tolerated; the dash rule still executes
unit U-109 'These rules are validated at bolt time:
**Machine-checkable:**
- DO NOT modify src/l1.php
* see also docs/naming.md'
( cd "$W" && echo "u9" > src/u9.txt && git add -A && git commit -qm "feat(U-109): bolt" )
run --unit=U-109; RC=$?
if [ "$RC" -eq 0 ] && ! grep -q 'unparseable' "$W/.mega-sdd/vaults/v1/bolts/U-109/postflight.json" \
  && grep -q '"DO_NOT_MODIFY"' "$W/.mega-sdd/vaults/v1/bolts/U-109/postflight.json"; then
  ok "r1-4: non-rule prose tolerated (lint parity) while the dash rule still executes"
else
  fail "r1-4: prose false-fails or rule dropped (rc=$RC): $(head -c200 "$W/.mega-sdd/vaults/v1/bolts/U-109/postflight.json" 2>/dev/null)"
fi

# r1-4 (other direction): a keyword-LEADING non-bullet line is NEVER silently
# dropped — it lexes and lands in the directive tier (non-pass without attest)
unit U-111 'NEVER commit secrets to the repo'
( cd "$W" && echo "u11" > src/u11.txt && git add -A && git commit -qm "feat(U-111): bolt" )
run --unit=U-111; RC=$?
[ "$RC" -ne 0 ] && grep -q 'directive_unverified' "$W/.mega-sdd/vaults/v1/bolts/U-111/postflight.json" \
  && ok "r1-4: keyword-leading non-bullet line still lexes (bullet-evasion net intact)" \
  || fail "r1-4: bullet-evasion line silently dropped (rc=$RC)"

# r2-1: monorepo subproject — cwd-relative manifest reads; a dep added by the
# unit's own commit in the PROJECT manifest must fail even when the repo ROOT
# has a same-named manifest (git show sha:path resolves at the root)
W2="$W/../$(basename "$W")-mono"; mkdir -p "$W2/sub/.mega-sdd/vaults/v1/units" "$W2/sub/src"
( cd "$W2" && git init -q . && git config user.email t@t && git config user.name t )
printf '{\n "dependencies": {}\n}\n' > "$W2/package.json"
printf '{\n "dependencies": {}\n}\n' > "$W2/sub/package.json"
printf -- '---\nunit_id: U-201\ntask_type: create\n---\n# U-201\n## Hard rules\n- DO NOT add new package.json dependencies\n' \
  > "$W2/sub/.mega-sdd/vaults/v1/units/U-201.md"
( cd "$W2" && git add -A && git commit -qm "chore: base" )
( cd "$W2" && printf '{\n "dependencies": {"evil": "^1.0"}\n}\n' > sub/package.json \
  && git add -A && git commit -qm "feat(U-201): bolt" )
( cd "$W2/sub" && bash "$PF" --cwd="$W2/sub" --unit=U-201 </dev/null 2>/dev/null ); RC=$?
[ "$RC" -ne 0 ] && grep -q '"evil"\|evil' "$W2/sub/.mega-sdd/vaults/v1/bolts/U-201/postflight.json" \
  && ok "r2-1: monorepo subproject dep addition FAILS (cwd-relative rev-paths)" \
  || fail "r2-1: root manifest read at both edges — monorepo dep addition passed (rc=$RC)"
rm -rf "$W2"

# r1-1/r1-6/r1-7: normalize_v2_files edge cases (pure python — no ast-grep needed)
python3 - "$ROOT" <<'PYEOF' && ok "r1-1/6/7: normalize_v2_files preserves brace globs, hidden dots, message text" \
  || fail "r1-1/6/7: normalize_v2_files corrupts an edge case"
import sys, os
sys.path.insert(0, os.path.join(sys.argv[1], "plugins/mega-sdd/scripts/_lib"))
import postflight_rules as pr
y, g = pr.normalize_v2_files('files: ["app/{Models,Entities}/User.php"]\n')
assert g == ["**/app/{Models,Entities}/User.php"], g          # brace glob NOT comma-split
y, g = pr.normalize_v2_files('files: ["**/already/x.php", "/abs/y.php"]\n')
assert g == ["**/already/x.php", "/abs/y.php"], g              # already-correct pass through
y, g = pr.normalize_v2_files('files: ["./src/x.php", ".env"]\n')
assert g == ["**/src/x.php", "**/.env"], g                     # ./ stripped, hidden dot kept
y, g = pr.normalize_v2_files('message: |\n  files: ["src/x.php"] is locked\n')
assert g == [] and 'files: ["src/x.php"] is locked' in y, (g, y)  # block-scalar untouched
PYEOF

# r1-2: sha-defense removed — a bolt that FIXES a pre-bolt v2 violation can pass
# (under the deleted defense the fix itself changed the file → permanent MISMATCH)
if command -v ast-grep >/dev/null 2>&1; then
  mkdir -p "$W/app2"
  printf '<?php\n$db->query("raw");\n' > "$W/app2/Fix.php"
  unit U-110 '```yaml
id: no-raw-query-2
language: php
severity: error
rule:
  pattern: $DB->query($$$A)
files: ["**/app2/**"]
message: locked
```'
  ( cd "$W" && git add -A && git commit -qm "chore: pre-bolt violation present" )
  PRE_SHA=$(python3 -c "import hashlib;print(hashlib.sha256(open('$W/app2/Fix.php','rb').read()).hexdigest())")
  mkdir -p "$W/.mega-sdd/vaults/v1/bolts/U-110"
  printf '{"unit_id":"U-110","rules":[{"type":"v2_snapshot","path":"app2/Fix.php","sha256":"%s"}]}\n' "$PRE_SHA" \
    > "$W/.mega-sdd/vaults/v1/bolts/U-110/preflight.json"
  ( cd "$W" && printf '<?php\n// fixed\n' > app2/Fix.php && git add -A && git commit -qm "feat(U-110): bolt fixes the violation" )
  run --unit=U-110; RC=$?
  [ "$RC" -eq 0 ] && ok "r1-2: fixing a pre-bolt v2 violation PASSES (sha-defense removed — remediation reachable)" \
    || fail "r1-2: honest fix still blocked (rc=$RC): $(grep -o '"evidence[^}]*' "$W/.mega-sdd/vaults/v1/bolts/U-110/postflight.json" | head -1)"
else
  ok "r1-2: SKIPPED empirical probe (ast-grep not installed)"
fi

# HR-1: v2 relative files: glob must be normalized (needs ast-grep)
if command -v ast-grep >/dev/null 2>&1; then
  mkdir -p "$W/app"
  printf '<?php\n$db->query("raw");\n' > "$W/app/Bad.php"
  unit U-106 '```yaml
id: no-raw-query
language: php
severity: error
rule:
  pattern: $DB->query($$$A)
files: ["app/Bad.php"]
message: locked
```'
  ( cd "$W" && git add -A && git commit -qm "feat(U-106): bolt" )
  run --unit=U-106; RC=$?
  if [ "$RC" -ne 0 ] && grep -q 'match' "$W/.mega-sdd/vaults/v1/bolts/U-106/postflight.json"; then
    ok "HR-1 (CRITICAL): relative files: glob normalized — the lock actually executes and FAILS on violation"
  else
    fail "HR-1: relative glob still inert (rc=$RC): $(grep -o '"evidence[^}]*' "$W/.mega-sdd/vaults/v1/bolts/U-106/postflight.json" | head -1)"
  fi
else
  ok "HR-1: SKIPPED empirical probe (ast-grep not installed) — doc + normalization pinned below"
fi

# ── doc pins ──
SK="${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
UP="${ROOT}/plugins/mega-sdd/references/upgrade-from-old-version.md"
US="${ROOT}/plugins/mega-sdd/skills/generate-units/references/unit-schema.md"
grep -qF 'files:` globs MUST be `**/`-prefixed' "$GR" && ok "HR-1: grammar doc mandates **/-prefixed globs" || fail "HR-1: grammar doc still shows the inert form"
grep -qF 'NONE — stays v1.' "$GR" && ok "HR-2: mapping routes stateless-impossible types back to v1" || fail "HR-2: mapping still claims impossible v2 equivalents"
if grep -qF 'pattern: $$$, inside: { kind: program }' "$GR"; then fail "HR-2: invalid flagship rule shape survives in migrate template"; else ok "HR-2: invalid rule shape purged from migrate template"; fi
grep -qF 'RECOMPUTED at the gate' "$HS" && ok "HR-8: recompute-at-gate truth restored (no more 'backlog')" || fail "HR-8: stale backlog claim survives"
grep -qF 'blanket per run' "$HS" && ok "HR-7: blanket-attest semantics disclosed" || fail "HR-7: attest disclosure missing"
grep -qF 'COMMIT the edit' "$HS" && ok "HR-9: remediation instructs committing the rule edit" || fail "HR-9: remediation still omits the commit requirement"
# review-round doc pins
if grep -qF 'recompute-the-scan-at-gate is the durable hardening (backlog)' "$SK"; then fail "r2-3: SKILL.md still calls recompute 'backlog'"; else ok "r2-3: SKILL.md stale backlog claim purged"; fi
grep -qF 'OVERWRITES the artifact' "$SK" && ok "r2-3: SKILL.md B1 note states gate recompute truth" || fail "r2-3: SKILL.md missing recompute truth"
if grep -qF 'all 5 are AST-or-simpler' "$GR"; then fail "r2-4: grammar still claims all 5 types are v2-expressible"; else ok "r2-4: grammar syntax-only section agrees with the mapping table"; fi
if grep -qF 'compare the current sha256 to the preflight snapshot' "$HS"; then fail "r1-2: scan doc still mandates the deleted sha-defense"; else ok "r1-2: sha-defense purged from the scan doc"; fi
grep -qF 'path-shaped' "$HS" && grep -qF 'PATH-SHAPED' "$US" && ok "r2-2: path-shaped modal carve-out documented (scan doc + unit schema)" || fail "r2-2: path-shaped carve-out missing from docs"
grep -q 'postflight_evidence_missing.*hard_rule_violated.*PREVIOUSLY-GREEN\|PREVIOUSLY-GREEN' "$UP" && ok "r2-5: upgrade blast radius disclosed in the upgrade guide" || fail "r2-5: upgrade guide missing the recompute-flip disclosure"
python3 -c "import ast; ast.parse(open('$ROOT/plugins/mega-sdd/scripts/_lib/postflight_rules.py').read())" && ok "engine parses" || fail "engine syntax error"

if [ "$FAILED" -eq 0 ]; then echo "ALL S7-A OK"; else echo "S7-A had failures"; fi
exit $FAILED

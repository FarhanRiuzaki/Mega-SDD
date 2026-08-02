#!/usr/bin/env bash
# test-dup-sweep-hardening.sh — R3 (spec 2026-08-02-reuse-first-grounding-index.md).
# The duplication sweep matches against the FULL symbol index with four classes
# (exact / case-shape / same-suffix-root / verb-synonym), guards the self-match, keeps the advisory
# rc-0 contract on every path, keeps the pre-R3 positional-cwd + human-line
# contract for run-analyze, and feeds --json evidence rows to the quality lens.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
V="${ROOT}/plugins/mega-sdd/scripts/validate-reuse-duplication.sh"
[ -f "$V" ] || { echo "missing validator"; exit 1; }
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

P="$W/p"; mkdir -p "$P/.mega-sdd/codebase" "$P/app" "$P/lib"
( cd "$P" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '<?php\nfunction getUserBalance($u) { return 0; }\n' > "$P/lib/Bal.php"
( cd "$P" && git add -A && git commit -qm base ) >/dev/null 2>&1
cat > "$P/.mega-sdd/codebase/symbol-index.json" <<'EOF'
{"generated_by":"mega-sdd:build-symbol-index","head_commit":"x","symbols":[{"name":"getUserBalance","kind":"php-function","file":"lib/Bal.php","line":2,"signature":"function getUserBalance($u)"},{"name":"formatCurrency","kind":"php-function","file":"lib/Money.php","line":3,"signature":"function formatCurrency(int $c)"},{"name":"selfSame","kind":"php-function","file":"app/New.php","line":2,"signature":"function selfSame()"}]}
EOF
cat > "$P/app/New.php" <<'EOF'
<?php
function selfSame() { return 1; }
function fetchUserBalance($u) { return 0; }
function format_currency($c) { return ""; }
function getUserBalance($u) { return 9; }
EOF
( cd "$P" && git add -A && git commit -qm add ) >/dev/null 2>&1

echo "== matcher classes against the FULL index =="
OUT=$(bash "$V" "$P"); RC=$?
[ "$RC" = "0" ] && ok "positional-cwd human mode rc 0 (run-analyze contract)" || fail "rc=$RC"
printf '%s' "$OUT" | grep -q "\[verb-synonym\]" && ok "verb-synonym: fetchUserBalance -> getUserBalance" || fail "verb-synonym missing: $OUT"
printf '%s' "$OUT" | grep -q "\[case-shape\]"   && ok "case-shape: format_currency -> formatCurrency" || fail "case-shape missing"
printf '%s' "$OUT" | grep -q "\[exact\]"        && ok "exact cross-file: getUserBalance duplicated" || fail "exact missing"
if printf '%s' "$OUT" | grep -q "selfSame"; then
  fail "self-match reported (the added definition itself)"
else
  ok "self-match guarded (same file + same name never reported)"
fi
printf '%s' "$OUT" | grep -qF "[reuse-dup] advisory scan complete" \
  && ok "pre-R3 human line contract intact" || fail "human summary line changed"

echo "== --json evidence mode (quality lens rows) =="
J=$(bash "$V" --cwd="$P" --json); RC=$?
[ "$RC" = "0" ] && ok "--json rc 0" || fail "json rc=$RC"
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin)
rows=d['rows']; cls={r['match_class'] for r in rows}
assert d['count']==len(rows)==3, rows
assert cls=={'exact','case-shape','verb-synonym'}, cls
assert all(r['source']=='symbol-index' for r in rows)
assert all(r['match_file'] and r['new_file'] for r in rows)
print('ok')" >/dev/null 2>&1 && ok "3 structured rows, classes + files + source attributed" || fail "json shape wrong: $J"

echo "== honest degradation paths (rc 0 on every one) =="
rm "$P/.mega-sdd/codebase/symbol-index.json"
printf 'helpers:\n  - name: formatCurrency\n    _source: x\n' > "$P/.mega-sdd/codebase/reuse-index.yaml"
OUT=$(bash "$V" "$P"); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q "reuse-index.yaml names only" \
  && printf '%s' "$OUT" | grep -q "case-shape" \
  && ok "index absent -> yaml fallback with honest slice-coverage note (still matches)" \
  || fail "fallback lane: rc=$RC out=$OUT"
rm "$P/.mega-sdd/codebase/reuse-index.yaml"
OUT=$(bash "$V" "$P"); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q "skipping (advisory)" \
  && ok "both sources absent -> recorded skip, rc 0" || fail "skip lane: rc=$RC"
bash "$V" "$W/does-not-exist" >/dev/null 2>&1; [ "$?" = "0" ] \
  && ok "bad cwd -> rc 0 (advisory never blocks a pipeline)" || fail "bad-cwd rc"
# restore a corpus first — the corpus check runs before the diff, so a bad
# range is only reachable with a readable index
printf '{"symbols":[{"name":"x","file":"lib/X.php","line":1,"signature":"function x()"}]}\n' > "$P/.mega-sdd/codebase/symbol-index.json"
OUT=$(bash "$V" --cwd="$P" --range=deadbeef..HEAD); [ "$?" = "0" ] \
  && printf '%s' "$OUT" | grep -q "failed — skipping" \
  && ok "bad range -> recorded skip, rc 0" || fail "bad-range lane"

echo "== round regression arms (dual-blind 2026-08-02, all folded) =="
# A1: same-suffix-root BOTH directions
P2="$W/ssr"; mkdir -p "$P2/.mega-sdd/codebase" "$P2/app"
( cd "$P2" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '<?php // base\n' > "$P2/app/base.php"; ( cd "$P2" && git add -A && git commit -qm b ) >/dev/null 2>&1
cat > "$P2/.mega-sdd/codebase/symbol-index.json" <<'EOF'
{"symbols":[{"name":"userBalance","file":"lib/A.php","line":1,"signature":"function userBalance()"},{"name":"getAccountTotal","file":"lib/B.php","line":1,"signature":"function getAccountTotal()"}]}
EOF
printf '<?php\nfunction getUserBalance($u) { return 0; }\nfunction accountTotal() { return 0; }\n' > "$P2/app/n.php"
( cd "$P2" && git add -A && git commit -qm n ) >/dev/null 2>&1
J=$(bash "$V" --cwd="$P2" --json)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin)
pairs={(r['new_name'],r['match_name'],r['match_class']) for r in d['rows']}
assert ('getUserBalance','userBalance','same-suffix-root') in pairs, pairs
assert ('accountTotal','getAccountTotal','same-suffix-root') in pairs, pairs
print('ok')" >/dev/null 2>&1 \
  && ok "A1: same-suffix-root fires BOTH directions (bare<->verb-prefixed)" \
  || fail "A1: same-suffix-root missing: $J"
# I1: cap 40 + truncated count (realistic __init__ flood fixture)
python3 - "$P2/.mega-sdd/codebase/symbol-index.json" <<'PY'
import json, sys
rows=[{"name":"__init__","file":"m%03d.py" % i,"line":1,"signature":"def __init__(self):"} for i in range(90)]
json.dump({"symbols":rows}, open(sys.argv[1],"w"))
PY
printf 'class Q:\n    def __init__(self):\n        pass\n' > "$P2/app/q.py"
( cd "$P2" && git add -A && git commit -qm q ) >/dev/null 2>&1
J=$(bash "$V" --cwd="$P2" --range=HEAD~1..HEAD --json)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['count'] <= 40, d['count']
assert d['truncated'] >= 1, d
print('ok')" >/dev/null 2>&1 \
  && ok "I1: rows capped at 40 with truncated count (lens prompt never flooded)" \
  || fail "I1: cap missing: $(printf '%s' "$J" | head -c 160)"
# I3: a markdown fence never mints an added symbol
printf '# doc\n\n```js\nfunction docFence() {}\n```\n' > "$P2/app/doc.md"
( cd "$P2" && git add -A && git commit -qm d ) >/dev/null 2>&1
J=$(bash "$V" --cwd="$P2" --range=HEAD~1..HEAD --json)
printf '%s' "$J" | grep -q "docFence" && fail "I3: doc fence minted a symbol" \
  || ok "I3: non-code diffs (.md fence) never mint added symbols"
# I2: diff.noprefix cannot defeat the self-guard (config-pinned diff)
( cd "$P2" && git config diff.noprefix true )
J=$(bash "$V" --cwd="$P2" --range=HEAD~2..HEAD~1 --json)
printf '%s' "$J" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert all(r['new_file'] for r in d['rows']), d['rows']
print('ok')" >/dev/null 2>&1 \
  && ok "I2: noprefix config pinned away (file attribution never empty)" \
  || fail "I2: attribution lost under diff.noprefix"
( cd "$P2" && git config --unset diff.noprefix )
# A3: mis-shaped index -> recorded skip envelope, no traceback
printf '[1,2,3]' > "$P2/.mega-sdd/codebase/symbol-index.json"
J=$(bash "$V" --cwd="$P2" --json 2>&1)
printf '%s' "$J" | python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1 \
  && ok "A3: array-shaped index -> valid JSON skip envelope (no traceback)" \
  || fail "A3: mis-shaped index broke the envelope: $(printf '%s' "$J" | head -c 120)"
# A5: unknown flag honors --json
J=$(bash "$V" --cwd="$P2" --json --bogus)
printf '%s' "$J" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['rows']==[]" >/dev/null 2>&1 \
  && ok "A5: unknown flag in --json mode -> JSON envelope, not a human line" \
  || fail "A5: envelope broken on unknown flag"
# M2: short verb roots are not matched (getId vs findId)
cat > "$P2/.mega-sdd/codebase/symbol-index.json" <<'EOF'
{"symbols":[{"name":"findId","file":"lib/C.php","line":1,"signature":"function findId()"}]}
EOF
printf '<?php\nfunction getId() { return 1; }\n' > "$P2/app/id.php"
( cd "$P2" && git add -A && git commit -qm i ) >/dev/null 2>&1
J=$(bash "$V" --cwd="$P2" --range=HEAD~1..HEAD --json)
printf '%s' "$J" | grep -q "findId" && fail "M2: 2-char root matched (noise class returned)" \
  || ok "M2: short verb roots (<3 chars) never match"

echo "== wiring pins =="
PLUG="${ROOT}/plugins/mega-sdd"
grep -qF "Reuse-duplication evidence (mechanical, advisory)" "$PLUG/skills/execute-bolts/references/review-panel.md" \
  && ok "review-panel: quality lens carries the evidence heading contract" || fail "review-panel wiring missing"
grep -qF "OMITTED, never emitted empty" "$PLUG/skills/execute-bolts/references/review-panel.md" \
  || grep -qF "the heading is OMITTED" "$PLUG/skills/execute-bolts/references/review-panel.md" \
  && ok "zero-rows -> heading omitted rule stated" || fail "empty-heading rule missing"
grep -qF "Reuse-duplication evidence (mechanical, advisory)" "$PLUG/agents/code-quality-reviewer.md" \
  && ok "quality agent instructed: verify each row, lead not verdict" || fail "agent instruction missing"
grep -qF "validate-reuse-duplication.sh --cwd=<root> --range=" "$PLUG/skills/execute-bolts/SKILL.md" \
  && ok "SKILL panel step names the evidence run" || fail "SKILL pointer missing"
if grep -q "validate-reuse-duplication" "$PLUG/hooks/pre-tool-use"; then
  fail "sweep wired into PreToolUse (must stay advisory — never a hook)"
else
  ok "still NEVER a hook (doctrine held)"
fi

[ "$FAILED" = "0" ] && echo "ALL DUP-SWEEP-HARDENING PROOFS OK" || echo "dup-sweep proofs FAILED"
exit $FAILED

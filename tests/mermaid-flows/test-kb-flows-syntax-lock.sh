#!/usr/bin/env bash
# test-kb-flows-syntax-lock.sh — behavior lock for the Mermaid Rule 1-3 syntax
# tokenizer in the kb flows surface (validate-kb.sh), so the shared-lib extraction (Inc-2 of the
# Mermaid-flows hard rule) cannot silently change what the KB flow validator
# detects. Pins the committed kb-flows-mermaid fixtures:
#   01-bad-mermaid.md  → FAIL, sec3_mermaid_syntax FAIL, >=1 mermaid_syntax_invalid
#   02-good-mermaid.md → PASS, zero issues
#
# Run: bash tests/mermaid-flows/test-kb-flows-syntax-lock.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VALIDATOR="${ROOT}/plugins/mega-sdd/scripts/validate-kb.sh"
VFLAGS="--surface=flows"
FXROOT="${ROOT}/tests/fixtures/kb-flows-mermaid"
FX="${FXROOT}/.mega-sdd/knowledge-base/10-domains"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

for f in "$VALIDATOR" "$FX/01-bad-mermaid.md" "$FX/02-good-mermaid.md"; do
  [ -f "$f" ] || { fail "missing: $f"; exit 1; }
done

# Fixtures write .kb-flows-state.json; run against a scratch copy to keep them clean.
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t kbflock)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$FXROOT"/. "$WORK"/
WFX="$WORK/.mega-sdd/knowledge-base/10-domains"

jrun() { bash "$VALIDATOR" $VFLAGS --cwd="$WORK" --file-path="$1" 2>/dev/null; }

note "=== 01-bad-mermaid.md -> FAIL with sec3 syntax issues (tokenizer lock) ==="
BAD=$(jrun "$WFX/01-bad-mermaid.md")
B_STATUS=$(echo "$BAD" | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])" 2>/dev/null)
B_SEC3SYN=$(echo "$BAD" | python3 -c "import json,sys;d=json.load(sys.stdin);print(next((c['status'] for c in d['checks'] if c['check']=='sec3_mermaid_syntax'),'NONE'))" 2>/dev/null)
B_SYNCNT=$(echo "$BAD" | python3 -c "import json,sys;d=json.load(sys.stdin);print(sum(1 for i in d['issues'] if i.get('halt_type')=='mermaid_syntax_invalid'))" 2>/dev/null)
# EXACT per-rule set, not just a count: 01-bad §3 carries exactly two Rule
# violations — Rule 1 (unquoted `(2.2, 4)`) and Rule 2 (literal \n) — so dropping
# either detection is caught (a count>=1 smoke test would miss it).
B_RULES=$(echo "$BAD" | python3 -c "import json,sys,re;d=json.load(sys.stdin);print(','.join(sorted({re.match(r'Rule [0-9]',i.get('rule_violated','')).group(0) for i in d['issues'] if i.get('halt_type')=='mermaid_syntax_invalid' and re.match(r'Rule [0-9]',i.get('rule_violated',''))})))" 2>/dev/null)
note "  status=$B_STATUS sec3_mermaid_syntax=$B_SEC3SYN syntax_issues=$B_SYNCNT rules=[$B_RULES]"
[ "$B_STATUS" = "FAIL" ] && ok "overall FAIL" || fail "expected FAIL, got '$B_STATUS'"
[ "$B_SEC3SYN" = "FAIL" ] && ok "sec3_mermaid_syntax FAIL" || fail "expected sec3 syntax FAIL, got '$B_SEC3SYN'"
[ "${B_SYNCNT:-0}" = "2" ] && ok "exactly 2 mermaid_syntax_invalid issues" || fail "expected EXACTLY 2 syntax issues, got '$B_SYNCNT'"
[ "$B_RULES" = "Rule 1,Rule 2" ] && ok "both Rule 1 + Rule 2 detected (per-rule lock)" || fail "expected Rule 1,Rule 2; got '[$B_RULES]'"

note ""
note "=== 02-good-mermaid.md -> PASS, zero issues (tokenizer lock) ==="
GOOD=$(jrun "$WFX/02-good-mermaid.md")
G_STATUS=$(echo "$GOOD" | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])" 2>/dev/null)
G_CNT=$(echo "$GOOD" | python3 -c "import json,sys;print(len(json.load(sys.stdin)['issues']))" 2>/dev/null)
note "  status=$G_STATUS issues=$G_CNT"
[ "$G_STATUS" = "PASS" ] && ok "overall PASS" || fail "expected PASS, got '$G_STATUS'"
[ "$G_CNT" = "0" ] && ok "zero issues on compliant Mermaid" || fail "expected 0 issues, got '$G_CNT'"

note ""
[ "$FAILED" -eq 0 ] && note "tokenizer behavior lock: all assertions passed." || note "tokenizer lock BROKEN (see failures)."
exit $FAILED

#!/usr/bin/env bash
# test-extract-dispatch-static.sh — tranche 5d (spec 2026-07-30 §5d).
# Pins scripts/build-extract-static.sh — the deterministic builder for
# <kb-dir>/.dispatch-static.md (stack-idiom slice + glossary index), which
# replaced the model-typed <STACK_IDIOM_ROWS> / <GLOSSARY_INDEX> injections:
#
#   PARSE   the script parses the MASTER STACK IDIOM TABLE out of
#           wave-dispatch-templates.md at run time (single copy — no duplicate
#           table inside the script), and FAILS CLOSED (exit 2, nothing
#           renamed) when the table cannot be parsed.
#   SLICE   slicing rules hold end-to-end: UNION of detected stacks in master
#           order; markup-only detection → full table; missing/unmapped
#           scan-meta → full table; alias convention (kotlin→Java,
#           vb.net→C#/.NET, ts→JS/TS) in parity with kb-leak-scan LANG_MAP.
#   GLOSS   glossary index emitted ONLY when glossary.md has ≥1 `## ` term;
#           format `- term: short_def (Lx-y)`; short_def is a VERBATIM prefix,
#           word-boundary-truncated at ~80 chars; ranges are 1-based heading
#           line through the line before the next heading.
#   SAFE    temp+rename atomicity (a failed run never clobbers the previous
#           file); idempotent re-run; the file sits at the KB ROOT where
#           kb-leak-scan's SCAN_DIRS never enumerate it (raw idiom tokens must
#           never count as KB tech-leaks).
#
# Run: bash tests/token-efficiency/test-extract-dispatch-static.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PLUGIN="${ROOT}/plugins/mega-sdd"
BUILDER="${PLUGIN}/scripts/build-extract-static.sh"
[ -f "$BUILDER" ] || { echo "missing $BUILDER"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t exds)"
trap 'rm -rf "$WORK"' EXIT

run_builder() { bash "$BUILDER" --kb-dir="$1" --plugin-root="$PLUGIN"; }
jkey() { python3 -c "import json,sys;print(json.loads(sys.stdin.read())['$1'])"; }

note "== 1. PARSE: master table from the templates ref; fail-closed on a broken source =="
KB="$WORK/kb-a"; mkdir -p "$KB/00-overview"
OUT=$(run_builder "$KB") || fail "builder exited non-zero on a bare kb"
[ "$(printf '%s' "$OUT" | jkey status)" = "ok" ] && ok "status ok on bare kb" || fail "status not ok: $OUT"
N_ROWS=$(grep -cE '^\| \*\*P[1-6]\*\*' "$KB/.dispatch-static.md")
[ "$N_ROWS" = "9" ] && ok "all 9 principle rows emitted (parsed from the single master copy)" || fail "expected 9 rows, got $N_ROWS"
if grep -qE 'P1.*state write.*UPDATE' "$BUILDER"; then fail "script embeds its own idiom table (duplicate copy — doc/script drift possible)"; else ok "script carries NO duplicate idiom table (parses wave-dispatch-templates.md)"; fi
cp "$KB/.dispatch-static.md" "$KB/.before"
bash "$BUILDER" --kb-dir="$KB" --plugin-root="$WORK/nonexistent" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "unparseable master source → exit 2" || fail "expected exit 2, got $RC"
cmp -s "$KB/.dispatch-static.md" "$KB/.before" && ok "fail-closed: previous file untouched on failure (temp+rename)" || fail "failed run clobbered the previous file"
LEFTOVER=$(find "$KB" -name '.dispatch-static.md.tmp.*' | wc -l | tr -d ' ')
[ "$LEFTOVER" = "0" ] && ok "no temp file left behind on the failure path" || fail "$LEFTOVER orphaned temp file(s) after a failed run"

note "== 2. SLICE: detection, union, master order, fallbacks, alias parity =="
KB="$WORK/kb-b"; mkdir -p "$KB"
printf '{"languages": {"PHP": 412, "JavaScript": 88, "HTML": 40, "SQL": 12}}\n' > "$KB/.scan-meta.json"
OUT=$(run_builder "$KB")
[ "$(printf '%s' "$OUT" | jkey stack_source)" = "scan-meta" ] && ok "detection source = scan-meta" || fail "wrong stack_source"
grep -qF '| Principle | PHP | JS / TS |' "$KB/.dispatch-static.md" && ok "PHP+JS slice in master order; HTML/SQL ignored (markup maps to no column)" || fail "slice header wrong"
if grep -qF '| Python |' "$KB/.dispatch-static.md"; then fail "undetected column leaked into the slice"; else ok "undetected columns excluded"; fi
printf '{"languages": {"HTML": 40, "CSS": 10, "SQL": 12}}\n' > "$KB/.scan-meta.json"
OUT=$(run_builder "$KB")
[ "$(printf '%s' "$OUT" | jkey columns)" = "8" ] && ok "markup-only detection → FULL table fallback" || fail "markup-only did not fall back to full table"
rm "$KB/.scan-meta.json"
OUT=$(run_builder "$KB")
printf '%s' "$OUT" | jkey stack_source | grep -q 'fallback-all' && ok "missing scan-meta → FULL table fallback (never an empty idioms section)" || fail "missing scan-meta fallback broken"
printf '{"languages": {"Kotlin": 9, "VB.NET": 3, "Brainfuck": 1}}\n' > "$KB/.scan-meta.json"
OUT=$(run_builder "$KB")
[ "$(printf '%s' "$OUT" | jkey stacks)" = "['C# / .NET', 'Java']" ] && ok "aliases kotlin→Java, vb.net→C#/.NET (LANG_MAP parity); unknown language ignored, mapped columns only" || fail "alias mapping wrong: $OUT"
# alias parity anchor: both consumers must recognize the same alias set
grep -qF '"vb.net": "csharp"' "${PLUGIN}/scripts/kb-leak-scan.sh" && grep -qF '"vb.net"' "$BUILDER" \
  && ok "vb.net alias present in BOTH kb-leak-scan LANG_MAP and the builder" || fail "alias parity broken (vb.net)"
grep -qF '"kotlin": "java"' "${PLUGIN}/scripts/kb-leak-scan.sh" && grep -qF '"kotlin"' "$BUILDER" \
  && ok "kotlin alias present in BOTH consumers" || fail "alias parity broken (kotlin)"
# FULL alias-set parity — the map is hand-duplicated in the two consumers, so pin the
# entire key set, not two sampled aliases (a divergence in any of the other ~20 would
# otherwise ship silently).
python3 - "$BUILDER" "${PLUGIN}/scripts/kb-leak-scan.sh" <<'PY' \
  && ok "FULL alias key-set identical across builder and kb-leak-scan (hand-duplicated map in step)" \
  || fail "alias key sets diverge between the two consumers"
import re, sys
builder = open(sys.argv[1]).read()
leak = open(sys.argv[2]).read()
m = re.search(r"for aliases, col in \[(.*?)\]:", builder, re.S)
assert m, "builder alias table not found"
b_aliases = set(re.findall(r'"([^"]+)"', re.sub(r'\],\s*"[^"]*"\)', ']', m.group(1))))
b_aliases -= {"PHP", "JS / TS", "Python", "C# / .NET", "Java", "Go", "Ruby", "Rust"}
m2 = re.search(r"LANG_MAP = \{(.*?)\}", leak, re.S)
assert m2, "kb-leak-scan LANG_MAP not found"
l_aliases = set(re.findall(r'"([^"]+)":', m2.group(1)))
sys.exit(0 if b_aliases == l_aliases else 1)
PY

note "== 3. GLOSS: emitted only with ≥1 term; format; verbatim-prefix truncation; ranges =="
KB="$WORK/kb-c"; mkdir -p "$KB/00-overview"
OUT=$(run_builder "$KB")
grep -q '^## GLOSSARY INDEX' "$KB/.dispatch-static.md" && fail "glossary section emitted with NO glossary (Wave-0 shape broken)" || ok "no glossary.md → no GLOSSARY INDEX section (Wave-0 shape)"
printf '# Glossary\n\n## customer-onboarding\nEnd-to-end signup flow incl. KYC, tier assignment, document upload and the very long tail that should get truncated at a word boundary for sure\nMore prose.\n\n## short-term\nOne-liner def.\n' > "$KB/00-overview/glossary.md"
OUT=$(run_builder "$KB")
[ "$(printf '%s' "$OUT" | jkey glossary_terms)" = "2" ] && ok "re-run after Wave 1 picks up the glossary (idempotent build-from-disk)" || fail "glossary_terms wrong"
grep -q '^glossary_index (term: short_def (L<start>-<end>)):' "$KB/.dispatch-static.md" && ok "index header format preserved" || fail "index header format lost"
grep -q '^- customer-onboarding: End-to-end signup flow' "$KB/.dispatch-static.md" && ok "one-line-per-term format" || fail "per-term line format wrong"
grep -q 'document upload and the very… (L3-6)' "$KB/.dispatch-static.md" && ok "~80-char word-boundary truncation + heading-to-next-heading range (L3-6)" || fail "truncation/range wrong: $(grep 'customer-onboarding' "$KB/.dispatch-static.md")"
grep -qF -- '- short-term: One-liner def. (L7-8)' "$KB/.dispatch-static.md" && ok "short defs pass through verbatim (no paraphrase surface)" || fail "short-def line wrong"
# --no-glossary (the Wave-0 form): glossary EXISTS but must be skipped, so a re-run
# into an existing KB can never hand Wave-1 subagents a stale prior-run index
OUT=$(bash "$BUILDER" --kb-dir="$KB" --plugin-root="$PLUGIN" --no-glossary)
grep -q '^## GLOSSARY INDEX' "$KB/.dispatch-static.md" && fail "--no-glossary still emitted the index (stale-index mirror open)" || ok "--no-glossary: index skipped even though glossary.md exists (Wave-0 re-run shape)"
[ "$(printf '%s' "$OUT" | jkey glossary_skipped)" = "True" ] && ok "stdout reports glossary_skipped" || fail "glossary_skipped not reported"
# glossary present but ZERO '## <term>' headings → named warning (the Wave-1 gate is
# the enforcement point; the builder names the state instead of a bare failing grep)
KB="$WORK/kb-c2"; mkdir -p "$KB/00-overview"
printf '# Glossary\n\n### wrong-heading-level\nA def.\n' > "$KB/00-overview/glossary.md"
OUT=$(run_builder "$KB")
printf '%s' "$OUT" | jkey warnings | grep -q 'glossary_no_terms' && ok "0-heading glossary → warnings:[glossary_no_terms] named on stdout" || fail "glossary_no_terms warning missing: $OUT"
grep -q '^## GLOSSARY INDEX' "$KB/.dispatch-static.md" && fail "0-term glossary still emitted an index section" || ok "0-term glossary → no index section (Wave-1 gate must catch the format, not this file)"
# fenced-code '## ' is NOT a heading and must not truncate the previous term's range
KB="$WORK/kb-c3"; mkdir -p "$KB/00-overview"
printf '# G\n\n## real-term\nDef line.\n```\n## not-a-term\n```\nMore prose.\n\n## next-term\nDef2.\n' > "$KB/00-overview/glossary.md"
OUT=$(run_builder "$KB")
[ "$(printf '%s' "$OUT" | jkey glossary_terms)" = "2" ] && ok "fenced '## ' not counted as a term" || fail "fence tracking broken (terms=$(printf '%s' "$OUT" | jkey glossary_terms))"
grep -qF -- '- real-term: Def line. (L3-9)' "$KB/.dispatch-static.md" && ok "previous term's range spans PAST the fenced pseudo-heading (L3-9)" || fail "range truncated at fenced '## ': $(grep 'real-term' "$KB/.dispatch-static.md")"

note "== 4. SAFE: root placement is outside kb-leak-scan's SCAN_DIRS =="
KB="$WORK/kb-d"; mkdir -p "$KB/10-domains"
printf '# domain\nA clean tech-agnostic claim. [VERIFIED] (see §11)\n' > "$KB/10-domains/10-clean.md"
run_builder "$KB" >/dev/null
# NOT a vacuous check: assert the scan actually RAN and scanned the fixture (rc 0 +
# its own "across N domain file(s)" line), then that the clean KB reports 0 hits —
# so a hit could only come from the dispatch-static file, and there is none.
SCAN_OUT=$(bash "${PLUGIN}/scripts/kb-leak-scan.sh" --kb-dir="$KB" --stack=all 2>/dev/null); SCAN_RC=$?
[ "$SCAN_RC" = "0" ] && ok "kb-leak-scan ran (rc=0)" || fail "kb-leak-scan did not run cleanly (rc=$SCAN_RC)"
printf '%s' "$SCAN_OUT" | grep -qE 'across [1-9][0-9]* domain file' && ok "scan enumerated ≥1 domain file (not a no-op)" || fail "scan saw no files — assertion would be vacuous"
printf '%s' "$SCAN_OUT" | grep -q '0 tech-leak hit(s)' && ok "0 hits on a clean KB with .dispatch-static.md at the root (raw idiom tokens exempt)" || fail "unexpected hits: $SCAN_OUT"
printf '%s' "$SCAN_OUT" | grep -q 'dispatch-static' && fail "scan output mentions the dispatch-static file" || ok "no hit attributed to .dispatch-static.md"

note "== 5. contract: stdout JSON keys + --quiet =="
OUT=$(run_builder "$KB")
for k in status static_path stacks stack_source columns glossary_present glossary_skipped glossary_terms warnings bytes; do
  printf '%s' "$OUT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); sys.exit(0 if '$k' in d else 1)" \
    && ok "stdout key: $k" || fail "stdout key missing: $k"
done
Q=$(bash "$BUILDER" --kb-dir="$KB" --plugin-root="$PLUGIN" --quiet)
[ -z "$Q" ] && ok "--quiet suppresses stdout" || fail "--quiet leaked stdout"
bash "$BUILDER" --kb-dir="$WORK/does-not-exist" --plugin-root="$PLUGIN" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "missing --kb-dir target → exit 2" || fail "expected exit 2 on missing kb-dir, got $RC"
bash "$BUILDER" --bogus-flag >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "unknown arg → exit 2" || fail "expected exit 2 on unknown arg, got $RC"

note "== 6. PARSE branches: doctored master tables (real fail-closed pins, not just missing-file) =="
# fake plugin-root shape: <root>/skills/extract-intelligence/references/wave-dispatch-templates.md
mk_fake() { # $1=root  $2=body
  mkdir -p "$1/skills/extract-intelligence/references"
  printf '%s\n' "$2" > "$1/skills/extract-intelligence/references/wave-dispatch-templates.md"
}
KB="$WORK/kb-f"; mkdir -p "$KB"
run_builder "$KB" >/dev/null   # seed a good file so untouched-on-failure is provable
cp "$KB/.dispatch-static.md" "$KB/.before"

FR="$WORK/fake-no-marker"; mk_fake "$FR" '| Principle | PHP |
|---|---|
| **P1** state write | x |'
bash "$BUILDER" --kb-dir="$KB" --plugin-root="$FR" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "marker absent → exit 2 (header alone is NOT enough — hijack anchor enforced)" || fail "marker-absent expected 2, got $RC"

FR="$WORK/fake-ragged"; mk_fake "$FR" '**MASTER STACK IDIOM TABLE**
| Principle | PHP | Java |
|---|---|---|
| **P1** state write | x |'
bash "$BUILDER" --kb-dir="$KB" --plugin-root="$FR" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "ragged row → exit 2" || fail "ragged-row expected 2, got $RC"

FR="$WORK/fake-reword"; mk_fake "$FR" '**MASTER STACK IDIOM TABLE**
| Principle | PHP | JS / TS | Python | C#/.NET | Java | Go | Ruby | Rust |
|---|---|---|---|---|---|---|---|---|
| **P1** state write | a | b | c | d | e | f | g | h |'
bash "$BUILDER" --kb-dir="$KB" --plugin-root="$FR" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "reworded column header → DRIFT die exit 2 (never a silent full-table labelled scan-meta)" || fail "column-drift expected 2, got $RC"
cmp -s "$KB/.dispatch-static.md" "$KB/.before" && ok "all three parse failures left the previous file untouched" || fail "a parse failure clobbered the file"

TEN_ROWS='**MASTER STACK IDIOM TABLE**
| Principle | PHP | JS / TS | Python | C# / .NET | Java | Go | Ruby | Rust |
|---|---|---|---|---|---|---|---|---|'
for i in 1 2 3 4 5 6 7 8 9 10; do TEN_ROWS="$TEN_ROWS
| **P1** row$i | a | b | c | d | e | f | g | h |"; done
FR="$WORK/fake-ten"; mk_fake "$FR" "$TEN_ROWS"
bash "$BUILDER" --kb-dir="$KB" --plugin-root="$FR" >/dev/null 2>&1; RC=$?
N=$(grep -cE '^\| \*\*P' "$KB/.dispatch-static.md")
[ "$RC" = "0" ] && [ "$N" = "10" ] && ok "10-row master → exit 0, 10 rows emitted (no magic-9 brick; the shipped 9-row shape is b1's pin, visible in CI)" || fail "10-row master expected 0/10, got rc=$RC rows=$N"

FR="$WORK/fake-hijack"; mk_fake "$FR" 'Example of an emitted slice:
| Principle | PHP |
|---|---|
| **P1** state write | example |
**MASTER STACK IDIOM TABLE**
| Principle | PHP | JS / TS | Python | C# / .NET | Java | Go | Ruby | Rust |
|---|---|---|---|---|---|---|---|---|
| **P1** state write | real | b | c | d | e | f | g | h |'
bash "$BUILDER" --kb-dir="$KB" --plugin-root="$FR" >/dev/null 2>&1; RC=$?
grep -qF '| **P1** state write | real |' "$KB/.dispatch-static.md" && ok "pre-marker slice example ignored — the MASTER after the marker wins (hijack immune)" || fail "locator hijacked by a pre-marker example table"

if [ "$FAILED" -eq 0 ]; then note "ALL EXTRACT-DISPATCH-STATIC PINS OK"; else note "extract-dispatch-static pins FAILED"; fi
exit $FAILED

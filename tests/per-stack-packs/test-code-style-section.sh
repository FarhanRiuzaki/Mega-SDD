#!/usr/bin/env bash
# Code style playbook — authoring-shape pin (docs/superpowers/specs/2026-09-16-code-style-playbook-design.md §5).
# Every pack that carries `## Code style (self-documenting)` has the 4-slot shape (Doc-comment tool +
# read by / Skip / Write / Names carry the meaning), 4–6 bullets, ≤ 1 600 bytes of bullets (T2 cost),
# and still lints clean; spring.md MUST carry it (R1, the Java-run feedback); _template.md carries the
# skeleton; _universal.md MUST NOT carry it (the generic rule is agent-carried — Iron Rule 6).
# A STYLE rule, never a gate: this pins the AUTHORING shape only, never generated code.
# Run: bash tests/per-stack-packs/test-code-style-section.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONV="$ROOT/plugins/mega-sdd/references/framework-conventions"
VP="$ROOT/plugins/mega-sdd/scripts/validate-pack.sh"
section() { awk '/^## Code style/{f=1; next} f&&/^## /{exit} f' "$1"; }

grep -q '^## Code style (self-documenting)' "$CONV/spring.md" && pass "spring.md carries ## Code style (self-documenting)" || fail "spring.md lacks the section"
grep -q '^## Code style (self-documenting)' "$CONV/_template.md" && grep -q 'T2 `code_style_slice`' "$CONV/_template.md" \
  && pass "_template.md carries the skeleton + names the T2 consumer" || fail "_template.md skeleton missing"
! grep -q '^## Code style' "$CONV/_universal.md" && pass "_universal.md carries NO section (generic rule is agent-carried)" || fail "_universal.md must not carry ## Code style"
grep -q 'Code style|' "$VP" && pass "validate-pack.sh recognizes the header (Check 3b known set)" || fail "validate-pack.sh _known_headers lacks Code style"

n=0
for f in "$CONV"/*.md; do
  b="$(basename "$f")"
  case "$b" in _*|README.md) continue ;; esac
  grep -q '^## Code style' "$f" || { fail "$b: MISSING ## Code style (required since 8.2.0)"; continue; }
  n=$((n + 1)); body="$(section "$f")"
  for lbl in 'Doc-comment tool' 'read by' 'Skip' 'Write' 'Names carry the meaning'; do
    printf '%s\n' "$body" | grep -q -- "\*\*$lbl\*\*" || fail "$b: slot **$lbl** missing"
  done
  bullets=$(printf '%s\n' "$body" | grep -c '^- ')
  { [ "$bullets" -ge 4 ] && [ "$bullets" -le 6 ]; } || fail "$b: $bullets bullets (want 4–6)"
  bytes=$(printf '%s\n' "$body" | grep '^- ' | wc -c | tr -d ' ')
  [ "$bytes" -le 1600 ] || fail "$b: bullets = $bytes bytes (cap 1600 — T2 cost)"
  # unfilled template placeholder = `<` at a word start with spaces/pipes inside (`<the CONCRETE …>`, `<tool>`);
  # generics glued to an identifier (`array<int, User>`, `Vec<T>`) and backticked XML tags (`<summary>`) are legitimate
  printf '%s\n' "$body" | grep -qE -- '(^|[ :(])<([A-Za-z][^>]*[ |][^>]*|[a-z]+)>' && fail "$b: unfilled <placeholder> left in the section"
  # tier-aware like `validate-pack.sh --all` / test-all-full-ready: only a `pack_tier: full` pack must lint clean;
  # an untiered project pack (laravel-base-26, 5 pre-existing missing-section violations) is shape-checked only
  tier=$(awk '/^---/{n++; if(n==1)next; if(n==2)exit} n==1' "$f" | grep -m1 '^pack_tier:' | sed 's/pack_tier:[[:space:]]*//' | tr -d '"'"'"'"' | tr -d '[:space:]')
  if [ "$tier" = "full" ]; then
    bash "$VP" "$f" >/dev/null 2>&1 && pass "$b: 4-slot shape ($bullets bullets, $bytes B) + validate-pack clean" || fail "$b: validate-pack.sh reports violations"
  else
    pass "$b: 4-slot shape ($bullets bullets, $bytes B) (untiered pack — lint not required)"
  fi
done
[ "$n" -ge 25 ] && pass "$n pack(s) carry the section (all non-underscore packs)" || fail "only $n pack(s) carry the section (25 expected)"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc

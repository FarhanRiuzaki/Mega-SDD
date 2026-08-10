#!/usr/bin/env bash
# test-emit-ladder-parity.sh — maturity-ladder drift guard (audit Phase-3 spec
# 2026-08-11-audit-phase3-reference-diet.md §D4): the four maturity ladders
# hardcoded in commands/emit.md's no-arg listing must stay in lockstep with
# their doc-pack OWNER files. The check extracts each owner's OWN ladder
# declaration and SET-COMPARES rungs in BOTH directions — a rung renamed at
# the owner to a word that merely appears elsewhere in the file must FAIL
# (the grep -qw hole), and an owner-side rung emit.md does not advertise
# must FAIL too. An empty extraction is a FAIL, never a skip (fail-closed).
# Run: bash tests/surface/test-emit-ladder-parity.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

EMIT="$P/commands/emit.md"
[ -f "$EMIT" ] || { echo "FAIL: $EMIT missing"; exit 1; }

# Extract the <a|b|c> ladder for one doc row of the no-arg maturity listing.
ladder_of() { # $1 = doc label (PRD|FSD|SIT|UAT)
  sed -n "s/.*- $1 .*maturity: <\([^>]*\)>.*/\1/p" "$EMIT" | head -1
}

# Owner-side ladder extraction — each owner declares its OWN ladder exactly
# once; the extractor targets that declaration, never a bag-of-words grep
# over the whole file (that is the hole this test exists to close).
owner_ladder() { # $1 = doc label, $2 = owner file
  case "$1" in
    PRD) # prd-sections.md §Maturity ladder: `a → b → c` (engine registry)
      sed -n 's/^`\([^`]*\)` (engine registry).*/\1/p' "$2" | head -1 ;;
    FSD) # emission-engine.md registry row: … | FSD `a → b` (…)
      sed -n 's/.*FSD `\([^`]*\)`.*/\1/p' "$2" | head -1 ;;
    SIT) # sit-sections.md §Maturity determination fence: "rung  — meaning"
      grep -E '^[a-z-]+[[:space:]]+—' "$2" | sed 's/[[:space:]].*//' | tr '\n' '|' ;;
    UAT) # uat-sections.md: "The UAT maturity ladder is `a → b → c`."
      sed -n 's/.*maturity ladder is `\([^`]*\)`.*/\1/p' "$2" | head -1 ;;
  esac
}

# Normalize a ladder string ("a|b|c" or "a → b → c") to sorted rung-per-line.
# Rung vocabulary is lowercase-hyphen; every other byte is a separator.
norm() { printf '%s' "$1" | tr -c 'a-z-' '\n' | grep -v '^$' | sort -u; }

check_doc() { # $1 = doc label, $2 = owner file
  local lad own extra_emit extra_owner
  lad="$(ladder_of "$1")"
  if [ -z "$lad" ]; then
    fail "$1: no maturity ladder found in emit.md's no-arg listing"
    return
  fi
  [ -f "$2" ] || { fail "$1: owner file $2 missing"; return; }
  own="$(owner_ladder "$1" "$2")"
  if [ -z "$own" ]; then
    fail "$1: owner ladder declaration not found in $(basename "$2") (extractor empty — fail-closed)"
    return
  fi
  extra_emit="$(comm -23 <(norm "$lad") <(norm "$own"))"   # emit.md rungs the owner lacks
  extra_owner="$(comm -13 <(norm "$lad") <(norm "$own"))"  # owner rungs emit.md lacks
  if [ -z "$extra_emit" ] && [ -z "$extra_owner" ]; then
    pass "$1: ladder <$lad> set-matches owner $(basename "$2")"
  else
    [ -n "$extra_emit" ]  && fail "$1: rung(s) hardcoded in emit.md missing from owner ladder in $(basename "$2"): $(echo $extra_emit)"
    [ -n "$extra_owner" ] && fail "$1: owner-side rung(s) in $(basename "$2") absent from emit.md's listing: $(echo $extra_owner)"
  fi
}

# The four doc-pack owners of each ladder's vocabulary.
check_doc "PRD" "$P/skills/emit-prd/references/prd-sections.md"
check_doc "FSD" "$P/references/emission-engine.md"
check_doc "SIT" "$P/skills/emit-sit/references/sit-sections.md"
check_doc "UAT" "$P/skills/emit-uat/references/uat-sections.md"

# Structural guard: the listing still carries exactly four ladder rows.
n="$(grep -c 'maturity: <' "$EMIT")"
[ "$n" -eq 4 ] && pass "emit.md listing carries exactly 4 ladder rows" \
  || fail "emit.md listing has $n 'maturity: <' rows (expected 4)"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

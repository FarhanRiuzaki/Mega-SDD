#!/usr/bin/env bash
# A1 behavioral — per-AC source grounding gate (verify_grounding_untrusted).
#
# The field incident: a verify unit stamped grounding_confidence: HIGH whose
# acceptance criteria existed only in test stubs / PRD. The unit had ONE real
# non-test anchor (MIN_GRAM) PLUS several ungrounded LOCKED criteria — so an
# "all anchors are test files" check MISSES it. The unit of measurement is the
# acceptance CRITERION, not the anchor-set: each LOCKED criterion of a verify+HIGH
# unit must cite a resolvable NON-TEST source anchor `[grounded: path:line]`.
#
# THE DISCRIMINATOR (case 1): a verify+HIGH unit with one grounded criterion AND
# one ungrounded criterion MUST flag. A test that only contains the all-test or
# all-grounded fixtures would go green against the wrong implementation.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
V="$ROOT/plugins/mega-sdd/scripts/validate-unit-spec.sh"
err=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a throwaway project with a real source file + a real test file so anchors
# can resolve (file exists + line valid) deterministically.
mkproj() {
  local p="$TMP/$1"; rm -rf "$p"
  mkdir -p "$p/src" "$p/tests" "$p/.mega-sdd/vaults/v1/units"
  printf 'a\nb\nc\nd\ne\n' > "$p/src/limits.ts"          # 5 lines → :3 valid
  printf 'a\nb\nc\nd\ne\n' > "$p/tests/limits.test.ts"   # a TEST file
  echo "$p"
}

# Write a verify unit. $1=proj $2=unit_id $3=grounding $4=AC-block(body)
mkunit() {
  local proj="$1" uid="$2" gc="$3" ac="$4"
  local f="$proj/.mega-sdd/vaults/v1/units/$uid.md"
  {
    echo "---"
    echo "unit_id: $uid"
    echo "title: $uid verify"
    echo "task_type: verify"
    echo "target_files: []"
    echo "vault_source: v1"
    echo "grounding_confidence: $gc"
    echo "---"
    echo
    echo "## Anchors"
    echo "- src/limits.ts:3"
    echo
    echo "## Acceptance criteria"
    printf '%s\n' "$ac"
    echo
    echo "## Out of scope"
    echo "- nothing"
  } > "$f"
  echo "$f"
}

# Run validator; return 0 if verify_grounding_untrusted present in state, 1 if not.
flagged() {
  local proj="$1" f="$2"
  bash "$V" --cwd="$proj" --file-path="$f" --quiet >/dev/null 2>&1
  grep -q 'verify_grounding_untrusted' "$proj/.mega-sdd/.unit-spec-state.json" 2>/dev/null
}

assert_flag() {   # $1=label $2=proj $3=unitfile
  if flagged "$2" "$3"; then echo "ok   - $1 (flagged)"; else echo "FAIL - $1 (expected flag, got none)"; err=1; fi
}
assert_clean() {  # $1=label $2=proj $3=unitfile
  if flagged "$2" "$3"; then echo "FAIL - $1 (expected clean, got flag)"; err=1; else echo "ok   - $1 (clean)"; fi
}

# ── Case 1: THE DISCRIMINATOR — partial grounding (one grounded + one ungrounded) ──
P=$(mkproj partial)
U=$(mkunit "$P" U-PARTIAL HIGH "- [grounded: src/limits.ts:3] minimal purchase enforced
- [ungrounded] daily limit blocks the 4th purchase")
assert_flag "partial grounding (1 grounded + 1 ungrounded)" "$P" "$U"

# ── Case 2: fully grounded → clean ──
P=$(mkproj good)
U=$(mkunit "$P" U-GOOD HIGH "- [grounded: src/limits.ts:3] minimal purchase enforced
- [grounded: src/limits.ts:4] daily limit enforced")
assert_clean "all criteria grounded in non-test source" "$P" "$U"

# ── Case 3: grounded only in a TEST file → flag (test-path is not real grounding) ──
P=$(mkproj testanchor)
U=$(mkunit "$P" U-TESTANCHOR HIGH "- [grounded: tests/limits.test.ts:3] behavior covered by a test stub")
assert_flag "grounding cites a test file only" "$P" "$U"

# ── Case 4: legacy unit (NO grounding markers at all) → clean (not retro-blocked) ──
P=$(mkproj legacy)
U=$(mkunit "$P" U-LEGACY HIGH "- minimal purchase enforced
- daily limit enforced")
assert_clean "legacy unit without per-AC markers tolerated" "$P" "$U"

# ── Case 5: grounding_confidence MEDIUM with an ungrounded AC → clean (block-on-HIGH-only) ──
P=$(mkproj medium)
U=$(mkunit "$P" U-MEDIUM MEDIUM "- [ungrounded] daily limit enforced")
assert_clean "MEDIUM verify unit not blocked on grounding" "$P" "$U"

# ── Case 6: grounded anchor does not resolve (file absent) → flag ──
P=$(mkproj nonresolve)
U=$(mkunit "$P" U-NONRESOLVE HIGH "- [grounded: src/nope.ts:3] points at a file that does not exist")
assert_flag "grounded anchor does not resolve" "$P" "$U"

# ── Case 7: grounded anchor line out of range → flag ──
P=$(mkproj badline)
U=$(mkunit "$P" U-BADLINE HIGH "- [grounded: src/limits.ts:999] line beyond EOF")
assert_flag "grounded anchor line out of range" "$P" "$U"

# helper: full unit with a CUSTOM acceptance heading + AC body (for fail-closed cases)
mkunit_full() { # proj uid gc heading acbody
  local proj="$1" uid="$2" gc="$3" heading="$4" ac="$5"
  local f="$proj/.mega-sdd/vaults/v1/units/$uid.md"
  {
    echo "---"; echo "unit_id: $uid"; echo "title: $uid verify"; echo "task_type: verify"
    echo "target_files: []"; echo "vault_source: v1"; echo "grounding_confidence: $gc"; echo "---"
    echo; echo "## Anchors"; echo "- src/limits.ts:3"; echo
    printf '%s\n' "$heading"
    printf '%s\n' "$ac"; echo
    echo "## Out of scope"; echo "- nothing"
  } > "$f"
  echo "$f"
}

# ── Case 8 (#6): an UNMARKED top-level bullet alongside a grounded one (adopting unit) → flag ──
P=$(mkproj unmarked)
U=$(mkunit "$P" U-UNMARKED HIGH "- [grounded: src/limits.ts:3] minimal purchase enforced
- daily limit blocks the 4th purchase")
assert_flag "unmarked top-level criterion in an adopting unit" "$P" "$U"

# ── Case 9 (#2b): a grounded bullet + ungrounded PROSE criteria (no bullet) → flag (fail closed) ──
P=$(mkproj prose)
U=$(mkunit_full "$P" U-PROSE HIGH "## Acceptance criteria" "- [grounded: src/limits.ts:3] minimal purchase enforced
Daily limit blocks the 4th purchase.
Source-of-fund validation is enforced.")
assert_flag "ungrounded prose criteria alongside a grounded bullet" "$P" "$U"

# ── Case 10 (#2a): heading drift — trailing colon → still enforced ──
P=$(mkproj colon)
U=$(mkunit_full "$P" U-COLON HIGH "## Acceptance criteria:" "- [grounded: src/limits.ts:3] grounded one
- [ungrounded] daily limit")
assert_flag "heading drift (trailing colon) still enforced" "$P" "$U"

# ── Case 11 (#2a): heading drift — h3 + 'tests' synonym → still enforced ──
P=$(mkproj h3)
U=$(mkunit_full "$P" U-H3 HIGH "### Acceptance tests" "- [grounded: src/limits.ts:3] grounded one
- [ungrounded] daily limit")
assert_flag "heading drift (h3 + tests synonym) still enforced" "$P" "$U"

# ── Case 12 (#2a): adopts (has markers) but NO recognised acceptance heading → flag (fail closed) ──
P=$(mkproj noheading)
U=$(mkunit_full "$P" U-NOHEAD HIGH "## Success criteria" "- [grounded: src/limits.ts:3] grounded one
- [ungrounded] daily limit")
assert_flag "adopts but no recognised acceptance heading (fail closed)" "$P" "$U"

# ── Case 13 (#3): sub-bullets are detail of the parent, not separate criteria → clean (no over-count) ──
P=$(mkproj subbullets)
U=$(mkunit_full "$P" U-SUB HIGH "## Acceptance criteria" "- [grounded: src/limits.ts:3] minimal purchase enforced
  - rejects below Rp 10.000
  - returns a 422 with a message
- [grounded: src/limits.ts:4] daily limit enforced
  - the 4th purchase is blocked")
assert_clean "sub-bullets not over-counted as ungrounded criteria" "$P" "$U"

# ── Case 14: intro line ending with ':' followed by grounded bullets → clean (no false positive) ──
P=$(mkproj intro)
U=$(mkunit_full "$P" U-INTRO HIGH "## Acceptance criteria" "All of the following hold:
- [grounded: src/limits.ts:3] minimal purchase enforced
- [grounded: src/limits.ts:4] daily limit enforced")
assert_clean "intro line ending in colon is not a criterion" "$P" "$U"

# ── Case 15 (#10): PascalCase test class (UserTest.php) is a test path → flag ──
# Create the file so it RESOLVES — the ONLY reason to flag must be test-path classification.
P=$(mkproj pascal)
printf 'a\nb\nc\nd\n' > "$P/src/UserTest.php"
U=$(mkunit "$P" U-PASCAL HIGH "- [grounded: src/UserTest.php:3] behavior covered only by a PascalCase test class")
assert_flag "PascalCase test class is not real grounding" "$P" "$U"

echo
[ $err -eq 0 ] && echo "ALL PASS (test-verify-grounding)" || echo "FAILED"
exit $err

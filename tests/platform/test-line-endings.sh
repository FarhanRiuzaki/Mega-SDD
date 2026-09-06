#!/usr/bin/env bash
# test-line-endings.sh
#
# One invariant: **every file this plugin ships must reach a Windows checkout
# with LF line endings.**
#
# Why this is a moat concern and not a tidiness one. Claude Code installs the
# plugin by `git clone` into the marketplace cache, and that clone inherits the
# machine's `core.autocrlf`. The DEFAULT Git for Windows installer option is
# `core.autocrlf=true`. Without a `.gitattributes` that opts out, every shipped
# script is checked out CRLF and any hook body's `set -uo pipefail` line
# parses as `set -e -u -o $'pipefail\r'` -> `set: pipefail: invalid option name`,
# RC=2, dispatching NOTHING. Blocking hooks kill the session; async hooks fail
# INVISIBLY and the whole moat evaporates while the model still believes it is
# gated. (2026-07-29 Windows portability audit, finding `crlf-no-gitattributes`.)
#
# The check that matters is NOT "does a .gitattributes exist" — it is "does Git
# itself apply eol=lf to the EXTENSIONLESS hook entry points". A `*.sh` rule
# looks reasonable and misses all six of them. So the authoritative assertion
# here is `git check-attr`, asked about those exact paths, with a synthetic
# `*.sh`-only repo as the control proving the assertion can fail.
#
# Deliberately python-free: the target machine has no usable python3.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

CR=$'\r'

# The six hook entry points have NO extension — this is the exact set a `*.sh`
# rule would miss, so it is the exact set we interrogate.
HOOK_ENTRIES="pre-tool-use post-tool-use session-start stop user-prompt-submit user-prompt-expansion"

# One more real path beyond the hooks, so a future narrowing to something like
# `**/hooks/* text eol=lf` cannot keep this test green while re-opening the
# hazard: resolve-project-root.sh is the audit's SECOND, independent hard-failure
# site under CRLF (`_rpr_has_bound_vault() {` -> syntax error ->
# resolve_project_root undefined for every script that sources it).
# (run-hook.sh — the audit's literal evidence line — was DELETED in v7.5.0 №A:
# hooks.json dispatches each extensionless body directly.)
EXTRA_PATHS="$P/scripts/_lib/resolve-project-root.sh"

# A path that does NOT exist. `git check-attr` answers for it anyway, so it
# asserts the rule is a CATCH-ALL and not an enumeration of today's files —
# every file added tomorrow must be covered too.
FUTURE_PATH="$P/scripts/zz-future-file-that-does-not-exist.sh"

# 6 hooks + 1 extra + 1 future = the vacuity floor for L2.
EXPECT_CHECKED=8  # v7.5.0: 6 hook entry points + resolve-project-root.sh + the future-file probe (run-hook.sh deleted, direct dispatch)

have_git=0
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  have_git=1
fi

# ── L1 — .gitattributes exists at the repo root ────────────────────────────────
if [ -f .gitattributes ]; then
  pass "L1: .gitattributes present at repo root"
else
  fail "L1: no .gitattributes at repo root — a default Git-for-Windows clone will check out CRLF"
fi

# ── L2 — Git itself applies eol=lf to every extensionless hook entry point ─────
# Authoritative: `git check-attr` is the same resolver the checkout uses.
checked=0
assert_eol_lf() { # $1 = path
  local p="$1" out t_attr e_attr
  out="$(git check-attr text eol -- "$p" 2>/dev/null)"
  checked=$((checked + 1))
  t_attr="$(printf '%s\n' "$out" | grep ' text: ' | sed 's/.* text: //')"
  e_attr="$(printf '%s\n' "$out" | grep ' eol: ' | sed 's/.* eol: //')"
  if [ "$e_attr" = "lf" ] && [ "$t_attr" != "unspecified" ] && [ "$t_attr" != "unset" ]; then
    return 0
  fi
  fail "L2: $p -> text: ${t_attr:-?}, eol: ${e_attr:-?} (want text set/auto + eol: lf; a '*.sh' rule misses extensionless files)"
  return 1
}
if [ "$have_git" -eq 1 ]; then
  for h in $HOOK_ENTRIES; do
    p="$P/hooks/$h"
    if [ ! -f "$p" ]; then
      fail "L2: hook entry point missing from working tree: $p"
      continue
    fi
    assert_eol_lf "$p"
  done
  for p in $EXTRA_PATHS; do
    if [ ! -f "$p" ]; then
      fail "L2: expected file missing from working tree: $p"
      continue
    fi
    assert_eol_lf "$p"
  done
  # Catch-all assertion: a not-yet-existing file must already be covered.
  assert_eol_lf "$FUTURE_PATH"
  if [ "$checked" -eq 0 ]; then
    fail "L2: VACUOUS — inspected 0 paths"
  elif [ "$checked" -ne "$EXPECT_CHECKED" ]; then
    fail "L2: VACUOUS-ish — inspected $checked of $EXPECT_CHECKED paths"
  elif [ "$rc" -eq 0 ]; then
    pass "L2: git check-attr reports eol=lf for all $EXPECT_CHECKED paths (6 extensionless hooks + resolve-project-root.sh + a future file)"
  fi
else
  # Fallback: reason over the rules when git is unavailable. Weaker than
  # check-attr (approximate glob semantics), so it is the fallback, not the path.
  cover=1
  if [ -f .gitattributes ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$CR}"
      case "$line" in ''|'#'*) continue ;; esac
      pat="${line%%[[:space:]]*}"
      attrs="${line#"$pat"}"
      case "$attrs" in *eol=lf*) ;; *) continue ;; esac
      # shellcheck disable=SC2254
      if [[ "pre-tool-use" == $pat ]]; then cover=0; break; fi
    done < .gitattributes
  fi
  checked=1
  if [ "$cover" -eq 0 ]; then
    pass "L2 (no-git fallback): a .gitattributes rule with eol=lf matches an extensionless path"
  else
    fail "L2 (no-git fallback): no eol=lf rule matches extensionless 'pre-tool-use'"
  fi
fi

# ── L2-CONTROL — prove the L2 assertion can FAIL ───────────────────────────────
# A synthetic repo whose .gitattributes lists ONLY `*.sh` must report
# `eol: unspecified` for an extensionless file; flipping it to the catch-all must
# report `eol: lf`. If this control does not discriminate, L2 proves nothing.
if [ "$have_git" -eq 1 ]; then
  CT="$(mktemp -d)"
  if git -C "$CT" init -q >/dev/null 2>&1; then
    mkdir -p "$CT/hooks" "$CT/scripts/_lib"
    : > "$CT/hooks/pre-tool-use"
    : > "$CT/scripts/_lib/resolve-project-root.sh"
    # neg1 — the extension trap: `*.sh` misses every extensionless entry point.
    printf '*.sh text eol=lf\n' > "$CT/.gitattributes"
    neg1="$(git -C "$CT" check-attr eol -- hooks/pre-tool-use 2>/dev/null | sed 's/.* eol: //')"
    # neg2 — the scope trap: a hooks-only rule leaves the script lane exposed.
    printf 'hooks/* text eol=lf\n' > "$CT/.gitattributes"
    neg2="$(git -C "$CT" check-attr eol -- scripts/_lib/resolve-project-root.sh 2>/dev/null | sed 's/.* eol: //')"
    # pos — the catch-all covers both.
    printf '* text=auto eol=lf\n' > "$CT/.gitattributes"
    pos1="$(git -C "$CT" check-attr eol -- hooks/pre-tool-use 2>/dev/null | sed 's/.* eol: //')"
    pos2="$(git -C "$CT" check-attr eol -- scripts/_lib/resolve-project-root.sh 2>/dev/null | sed 's/.* eol: //')"
    if [ "$neg1" = "unspecified" ] && [ "$neg2" = "unspecified" ] && [ "$pos1" = "lf" ] && [ "$pos2" = "lf" ]; then
      pass "L2-CONTROL: check-attr discriminates ('*.sh'-only and 'hooks/*'-only -> unspecified, '*' -> lf)"
    else
      fail "L2-CONTROL: matcher does not discriminate (neg1=$neg1, neg2=$neg2, pos1=$pos1, pos2=$pos2) — L2 is not trustworthy"
    fi
  else
    fail "L2-CONTROL: could not create synthetic repo — control not executed"
  fi
  rm -rf "$CT"
else
  fail "L2-CONTROL: git unavailable — the authoritative check and its control were both skipped"
fi

# ── L3 — no tracked file under plugins/mega-sdd/ carries a CR byte ─────────────
# One batched matcher (xargs+grep) rather than a fork per file: the target
# machine pays ~220 ms per process spawn.
cr_hits() { LC_ALL=C xargs -0 grep -l -I -e "$CR" -- 2>/dev/null; }

TMPL="$(mktemp -d)"
if [ "$have_git" -eq 1 ]; then
  git ls-files -z -- "$P" > "$TMPL/list.z" 2>/dev/null
else
  find "$P" -type f -print0 > "$TMPL/list.z" 2>/dev/null
fi
# Count entries without a fork per file.
n_files=$(tr -dc '\0' < "$TMPL/list.z" | wc -c | tr -d ' ')
if [ "${n_files:-0}" -eq 0 ]; then
  fail "L3: VACUOUS — scanned 0 files under $P/ (matcher found nothing to inspect)"
else
  offenders="$(cr_hits < "$TMPL/list.z")"
  if [ -z "$offenders" ]; then
    pass "L3: 0 of $n_files tracked files under $P/ contain a CR byte"
  else
    # A stale pre-.gitattributes CRLF clone lights up EVERY file, so cap the list:
    # the count is the signal ("re-clone the plugin cache"), not the enumeration.
    n_bad="$(printf '%s\n' "$offenders" | wc -l | tr -d ' ')"
    fail "L3: CR byte(s) in $n_bad of $n_files tracked files under $P/ — if this is a clone made before .gitattributes existed, RE-CLONE (adding it does not renormalize an existing checkout). First offenders:"
    printf '%s\n' "$offenders" | head -8 | sed 's/^/        /'
    [ "$n_bad" -gt 8 ] && echo "        … and $((n_bad - 8)) more"
  fi
fi

# ── L3-CONTROL — the same matcher must detect a synthetic CRLF file ────────────
# NOTE: the two fixture names must not be substrings of one another, or the
# `case` below silently self-confirms (that bug bit this test during authoring).
printf 'set -euo pipefail\r\necho hi\r\n' > "$TMPL/dos-fixture.sh"
printf 'set -euo pipefail\necho hi\n'     > "$TMPL/unix-fixture.sh"
printf '%s\0%s\0' "$TMPL/dos-fixture.sh" "$TMPL/unix-fixture.sh" > "$TMPL/ctrl.z"
ctrl="$(cr_hits < "$TMPL/ctrl.z")"
case "$ctrl" in
  *dos-fixture.sh*)
    case "$ctrl" in
      *unix-fixture.sh*) fail "L3-CONTROL: matcher flagged the LF fixture too — it is not discriminating" ;;
      *) pass "L3-CONTROL: matcher detects a synthetic CRLF file and ignores the LF twin" ;;
    esac
    ;;
  *) fail "L3-CONTROL: matcher did NOT detect a synthetic CRLF file — L3 proves nothing" ;;
esac
rm -rf "$TMPL"

# ── L4 — the WHY comment survives ──────────────────────────────────────────────
# A bare dotfile invites deletion; the rationale is load-bearing documentation.
if [ -f .gitattributes ] && grep -q 'hooks/pre-tool-use' .gitattributes; then
  pass "L4: .gitattributes carries the extensionless-hook CRLF rationale"
else
  fail "L4: .gitattributes has no rationale comment naming an extensionless hook — it will get deleted as noise"
fi

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

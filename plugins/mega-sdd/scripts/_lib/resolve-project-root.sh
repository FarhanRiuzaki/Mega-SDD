#!/usr/bin/env bash
# resolve-project-root.sh — shared helper for hooks + scripts (Iter 71).
#
# Walks UP from a given path to find the project root containing .mega-sdd/.
# Required because: the model can change CWD (e.g., cd into .mega-sdd/knowledge-base/
# during extract-intelligence), and harness-provided CWD then points to a SUBFOLDER
# of the project — naively writing to ${CWD}/.mega-sdd/... creates nested
# .mega-sdd/knowledge-base/.mega-sdd/ paths. Walking up corrects this.
#
# Source this file then call resolve_project_root "$CWD".
#
# Resolution rule (S6 EB-GATE-6):
#   1. Walk up from the passed-in path. The FIRST ancestor whose .mega-sdd/ is
#      SUBSTANTIVE (carries vaults/, knowledge-base/, codebase/, or config.yaml)
#      wins — that is the real project root.
#   2. A candidate whose .mega-sdd/ holds only validator state litter (a phantom
#      root minted by a past state write from the wrong cwd) is REMEMBERED but
#      skipped: it must never shadow a substantive root above it. If no
#      substantive root exists anywhere up the chain, the nearest plain
#      candidate is returned (greenfield: .mega-sdd/ exists but is still empty).
#   3. If no candidate at all → return original input (init scenario; caller's
#      existence checks still no-op correctly).
#
# Why: the old nearest-match rule let a litter .mega-sdd/ (e.g. one a validator
# mkdir'd relative to a session sub-cwd) fork gate truth — a recorded FAIL at
# the true root became invisible one directory deeper, and the gate then
# populated the phantom root with its own PASS states (self-perpetuating).
#
# Note the basename != ".mega-sdd" guard: prevents matching a hypothetical
# .mega-sdd/.mega-sdd/ nested layout (defensive — Iter 71 bug showed this CAN
# happen when prior runs created the nested dir).

# True if $1 has a legacy `<name>-bound/` (root or one level deep) that is a REAL vault
# (holds units/ or bolts/) — a code dir merely named *-bound (io-bound) does NOT count.
# Mirrors vault_layouts.py so the resolver and the layout enumerator never disagree.
_rpr_has_bound_vault() {
  local root="$1" b
  for b in "$root"/*-bound "$root"/*/*-bound "$root"/docs/mega-sdd/vaults/*-bound; do
    if [ -d "$b/units" ] || [ -d "$b/bolts" ]; then return 0; fi
  done
  return 1
}

resolve_project_root() {
  local d="${1:-$PWD}"
  # ── Windows separator normalization (MUST precede any suffix arithmetic) ───
  # Claude Code hands hooks a NATIVE cwd on Windows (C:\Users\me\proj). Without
  # this, `${d%/*}` finds no '/' to strip and the walk cannot make progress.
  # Guarded by $OSTYPE (a bash builtin variable — no fork) so a POSIX path that
  # legitimately CONTAINS a backslash is never rewritten.
  case "${OSTYPE:-}" in
    msys*|cygwin*|win32*) d="${d//\\//}" ;;
  esac
  local orig="$d"
  local first_match=""
  local prev="" guard=0
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    # Backstop: never spin, whatever the input. 64 is far deeper than any real
    # tree (Windows MAX_PATH bottoms out long before this).
    guard=$((guard + 1))
    if [ "$guard" -gt 64 ]; then break; fi
    if [ -d "$d/.mega-sdd" ] && [ "${d##*/}" != ".mega-sdd" ]; then
      if [ -z "$first_match" ]; then first_match="$d"; fi
      # Substantive = canonical .mega-sdd content OR a live Factory Line / memory layer
      # OR a LEGACY vault layout (docs/mega-sdd/vaults, *-bound sibling) — the same set
      # vault_layouts.py accepts (S6 EB-VAL/aux fix: legacy roots were misread as litter
      # and a nested legacy project got hijacked by a canonical parent → gate fail-open).
      if [ -d "$d/.mega-sdd/vaults" ] || [ -d "$d/.mega-sdd/knowledge-base" ] \
         || [ -d "$d/.mega-sdd/codebase" ] || [ -f "$d/.mega-sdd/config.yaml" ] \
         || [ -f "$d/.mega-sdd/factory-ledger.json" ] || [ -d "$d/.mega-sdd/memory" ] \
         || [ -d "$d/docs/mega-sdd/vaults" ] || _rpr_has_bound_vault "$d"; then
        echo "$d"
        return 0
      fi
    fi
    # ── Windows drive root ends the walk (AFTER evaluating it above) ─────────
    # `dirname C:` returns `C:` on Git Bash — a FIXED POINT. The pre-fix loop
    # condition (`[ "$d" != "/" ]`) could never be satisfied from a Windows path,
    # so this spun forever, forking one `dirname` per iteration (measured 220 ms
    # each on a Windows 11 + CrowdStrike laptop) INSIDE the BLOCKING PreToolUse
    # hook. That was the Windows 100%-CPU hang, 2026-07-28.
    case "$d" in [A-Za-z]:|[A-Za-z]:/) break ;; esac
    # Pure parameter expansion — ZERO forks. The old `d=$(dirname "$d")` cost a
    # subshell fork + an exec PER LEVEL; on Git Bash that is a real bash.exe
    # CreateProcess, and every one of them is scanned by a kernel EDR.
    prev="$d"
    d="${d%/*}"
    # No separator left to strip (bare relative name, or a form the cases above
    # did not catch) → the walk cannot progress. Stop instead of spinning.
    if [ "$d" = "$prev" ]; then break; fi
  done
  # No substantive root anywhere: nearest plain candidate (greenfield), else
  # the original input (no .mega-sdd ancestor at all).
  if [ -n "$first_match" ]; then
    echo "$first_match"
    return 0
  fi
  echo "$orig"
}

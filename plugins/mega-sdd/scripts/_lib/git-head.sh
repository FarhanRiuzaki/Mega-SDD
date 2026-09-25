#!/usr/bin/env bash
# git-head.sh — builtin git position reader (state anchor, spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §5 (a), §7).
#
# Source this file, then:
#   mega_git_dir <start-dir>   walk UP from <start-dir> to the first `.git` (a dir, or a
#                              worktree/submodule `.git` FILE carrying `gitdir:`). Sets
#                              GH_TOP (worktree top), GH_GITDIR (per-worktree git dir),
#                              GH_COMMONDIR (shared refs/objects dir). rc 1 = no `.git`
#                              anywhere up the chain (NOT a git repo — the only place that
#                              decision is made; a git error elsewhere is never "no repo").
#   mega_git_head [packed]     read HEAD with builtins after mega_git_dir. Sets GH_HEAD
#                              (full hex sha), GH_BRANCH (branch name, or `detached`),
#                              GH_REF (the symbolic ref, or empty). `packed` also scans
#                              packed-refs (linear; SessionStart only — never per prompt,
#                              its cost grows with the repo). rc 1 = not resolvable by
#                              builtins (reftable, unborn branch, ref only in packed-refs
#                              without `packed`, unreadable file) → the caller falls back
#                              to ONE `git rev-parse HEAD`.
#   mega_seen_ring_put <gitdir> <sid> <sha> <branch>
#                              the per-worktree seen ring (`<gitdir>/mega-sdd-seen`):
#                              which HEAD each session last saw — ≤8 sessions,
#                              `<session_id> <sha> <branch>` only. Best-effort write.
#
# Zero forks on every path: bash builtins only (read, case, parameter expansion).
# The walk stops at a fixed point, like resolve-project-root.sh (`dirname C:` is a
# fixed point on Git Bash — windows-hook-hang lesson).

_gh_hex() {  # rc 0 when $1 is a full sha1 (40) or sha256 (64) hex id
  case "$1" in
    *[!0-9a-f]*|"") return 1 ;;
  esac
  [ "${#1}" -eq 40 ] || [ "${#1}" -eq 64 ]
}

_gh_read1() {  # first line of file $1 into _GH_LINE, trailing CR stripped; rc 1 when unreadable
  _GH_LINE=""
  [ -f "$1" ] || return 1
  { IFS= read -r _GH_LINE < "$1"; } 2>/dev/null || [ -n "$_GH_LINE" ] || return 1
  _GH_LINE="${_GH_LINE%$'\r'}"
  return 0
}

mega_git_dir() {
  GH_TOP=""; GH_GITDIR=""; GH_COMMONDIR=""
  local d="${1:-$PWD}" prev="" guard=0 gd cd
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) d="${d//\\//}" ;; esac
  while [ -n "$d" ]; do
    guard=$((guard + 1)); [ "$guard" -gt 64 ] && return 1
    if [ -d "$d/.git" ]; then
      GH_TOP="$d"; GH_GITDIR="$d/.git"
      break
    elif [ -f "$d/.git" ]; then
      _gh_read1 "$d/.git" || return 1
      case "$_GH_LINE" in
        gitdir:*) gd="${_GH_LINE#gitdir:}"; gd="${gd# }"; gd="${gd//\\//}" ;;
        *) return 1 ;;
      esac
      case "$gd" in
        /*|[A-Za-z]:/*) ;;
        *) gd="$d/$gd" ;;
      esac
      [ -d "$gd" ] || return 1
      GH_TOP="$d"; GH_GITDIR="$gd"
      break
    fi
    [ "$d" = "/" ] && return 1
    case "$d" in [A-Za-z]:|[A-Za-z]:/) return 1 ;; esac
    prev="$d"; d="${d%/*}"
    [ -z "$d" ] && d="/"
    [ "$d" = "$prev" ] && return 1
  done
  [ -n "$GH_GITDIR" ] || return 1
  GH_COMMONDIR="$GH_GITDIR"
  if _gh_read1 "$GH_GITDIR/commondir"; then
    cd="${_GH_LINE//\\//}"
    case "$cd" in
      /*|[A-Za-z]:/*) ;;
      *) cd="$GH_GITDIR/$cd" ;;
    esac
    [ -d "$cd" ] && GH_COMMONDIR="$cd"
  fi
  return 0
}

mega_git_head() {
  GH_HEAD=""; GH_BRANCH=""; GH_REF=""
  [ -n "${GH_GITDIR:-}" ] || return 1
  [ -d "$GH_COMMONDIR/reftable" ] && return 1
  _gh_read1 "$GH_GITDIR/HEAD" || return 1
  case "$_GH_LINE" in
    "ref: "*)
      GH_REF="${_GH_LINE#ref: }"
      GH_BRANCH="${GH_REF#refs/heads/}"
      local f
      for f in "$GH_GITDIR/$GH_REF" "$GH_COMMONDIR/$GH_REF"; do
        if _gh_read1 "$f" && _gh_hex "$_GH_LINE"; then GH_HEAD="$_GH_LINE"; return 0; fi
      done
      if [ "${1:-}" = "packed" ] && [ -f "$GH_COMMONDIR/packed-refs" ]; then
        local line
        while IFS= read -r line || [ -n "$line" ]; do
          line="${line%$'\r'}"
          case "$line" in
            *" $GH_REF")
              line="${line%% *}"
              if _gh_hex "$line"; then GH_HEAD="$line"; return 0; fi
              return 1 ;;
          esac
        done < "$GH_COMMONDIR/packed-refs" 2>/dev/null
      fi
      return 1
      ;;
    *)
      _gh_hex "$_GH_LINE" || return 1
      GH_HEAD="$_GH_LINE"; GH_BRANCH="detached"
      return 0
      ;;
  esac
}

# mega_seen_ring_put <gitdir> <sid> <sha> <branch> — ≤8 sessions, this one last.
# No timestamps, counters or prompt data: `<session_id> <sha> <branch>` only.
mega_seen_ring_put() {
  local f="$1/mega-sdd-seen" l out="" n=0 keep=()
  if [ -f "$f" ]; then
    while IFS= read -r l || [ -n "$l" ]; do
      [ -n "$l" ] || continue
      [ "${l%% *}" = "$2" ] && continue
      keep[${#keep[@]}]="$l"
    done < "$f" 2>/dev/null || true
  fi
  local start=0
  [ "${#keep[@]}" -gt 7 ] && start=$(( ${#keep[@]} - 7 ))
  n="$start"
  while [ "$n" -lt "${#keep[@]}" ]; do out="${out}${keep[$n]}"$'\n'; n=$((n + 1)); done
  out="${out}$2 $3 $4"$'\n'
  { printf '%s' "$out" > "$f"; } 2>/dev/null || :
  return 0
}

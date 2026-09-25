#!/usr/bin/env bash
# state-block.sh — the session-start state block (state anchor, spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §6). Sourced by
# hooks/session-start; requires git-head.sh sourced first.
#
#   mega_state_block <project_root> <cwd> <session_id> <source> <python_ok 0|1> <notice_on 0|1>
#     → sets STATE_BLOCK (the text, or "" when a resume already saw this HEAD)
#   mega_state_seen_write     (call AFTER the block is printed) records this session
#                             at HEAD in the per-worktree seen ring — best-effort
#
# Cost: HIT (cache checked == HEAD and strictly newer than every input) = 0 exec;
# MISS = exactly ONE `git diff` process; no cache = 0 exec. Reads only the view
# cache the engine (scripts/_lib/freshness.py) wrote into the git dir — never
# state.json, never the vaults[0] digest, never the dirty journal. Every write is
# best-effort and happens after the block is printed. Safe under set -euo pipefail:
# every function ends in `return 0`, empty arrays are guarded (bash 3.2).

MEGA_RULE_LINE="Rule: code at HEAD decides what the code IS (files, symbols, lines, what is built). Memory, CLAUDE.md and vault/unit/bolt-report claims about what the code IS are derived: no SHA = hint, contradicts HEAD = STALE; say so, never use them silently. What the code SHOULD do stays with the vault: a spec-vs-code mismatch is a CONFLICT for a human."
MEGA_SEP=$'\x1f'
MEGA_BLOCK_MAX=1200
MEGA_MAX_LINES=6
MEGA_MISS_MAX=200   # changed paths the miss path matches in bash; beyond → "later moves UNVERIFIED"

_mb_san() {  # sanitize $1 (and cut to $2 chars) into _MB_S
  _MB_S="${1//[^A-Za-z0-9._\/:()#@+ -]/_}"
  if [ -n "${2:-}" ] && [ "${#_MB_S}" -gt "$2" ]; then _MB_S="${_MB_S:0:$(( $2 - 1 ))}…"; fi
  return 0
}

_mb_field() {  # _mb_field <string> <index 0..> → _MB_F (fields split on \x1f)
  local s="$1" i="$2"
  while [ "$i" -gt 0 ]; do
    case "$s" in *"$MEGA_SEP"*) s="${s#*"$MEGA_SEP"}" ;; *) s="" ;; esac
    i=$((i - 1))
  done
  _MB_F="${s%%"$MEGA_SEP"*}"
  return 0
}

# Parse the view cache into globals. MB_OK=1 only for a complete file (v=1 first,
# end=<checked> last) — a torn or foreign file is treated as absent.
_mb_parse_cache() {
  MB_OK=0; MB_CHECKED=""; MB_BRANCH=""; MB_HDR=""; MB_TOP=""; MB_PREFIX=""; MB_UP=""
  MB_VAULTS=(); MB_XLINES=(); MB_VDIRS=(); MB_WATCH=()
  local f="$1" line first=1 end=""
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [ "$first" -eq 1 ]; then
      [ "$line" = "v=1" ] || return 0
      first=0; continue
    fi
    case "$line" in
      checked=*) MB_CHECKED="${line#checked=}" ;;
      branch=*) MB_BRANCH="${line#branch=}" ;;
      hdr=*) MB_HDR="${line#hdr=}" ;;
      top=*) MB_TOP="${line#top=}" ;;
      prefix=*) MB_PREFIX="${line#prefix=}" ;;
      vdir=*) MB_VDIRS[${#MB_VDIRS[@]}]="${line#vdir=}" ;;
      watch=*) MB_WATCH[${#MB_WATCH[@]}]="${line#watch=}" ;;
      vault=*) MB_VAULTS[${#MB_VAULTS[@]}]="${line#vault=}" ;;
      xline=*) MB_XLINES[${#MB_XLINES[@]}]="${line#xline=}" ;;
      up=*) MB_UP="${line#up=}" ;;
      end=*) end="${line#end=}" ;;
    esac
  done < "$f" 2>/dev/null || true
  # checked= reaches git's argv on the miss path: a full hex sha or the cache is void
  if [ -n "$MB_CHECKED" ] && [ "$end" = "$MB_CHECKED" ] && _gh_hex "$MB_CHECKED"; then MB_OK=1; fi
  return 0
}

# HIT only when the cache is STRICTLY newer than every input (bash compares whole
# seconds on 3.2: an input written in the same second is a miss — the safe side).
_mb_cache_newer() {
  MB_NEWER=1
  local c="$1" d f
  local restore_ng=0
  shopt -q nullglob || { shopt -s nullglob; restore_ng=1; }
  for d in ${MB_WATCH[@]+"${MB_WATCH[@]}"}; do
    if [ -e "$d" ] && ! [ "$c" -nt "$d" ]; then MB_NEWER=0; break; fi
  done
  if [ "$MB_NEWER" -eq 1 ]; then
    for d in ${MB_VDIRS[@]+"${MB_VDIRS[@]}"}; do
      if [ ! -d "$d" ]; then MB_NEWER=0; break; fi
      for f in "$d" "$d/bolts" "$d/units" "$d/binding.json" "$d"/bolts/U-* "$d"/bolts/U-*/binding.json \
               "$d"/units/U-*.md "$d"/units/U-*/unit.md; do
        if [ -e "$f" ] && ! [ "$c" -nt "$f" ]; then MB_NEWER=0; break; fi
      done
      [ "$MB_NEWER" -eq 1 ] || break
    done
  fi
  [ "$restore_ng" -eq 1 ] && shopt -u nullglob
  return 0
}

# Is vault record $1 the cwd's vault? (its prefixes contain the cwd sub-path)
_mb_mine() {
  MB_MINE=0
  local rel="$2" p
  [ -n "$rel" ] || return 0
  _mb_field "$1" 3
  for p in $_MB_F; do
    case "$rel" in "$p"|"$p"/*) MB_MINE=1; return 0 ;; esac
  done
  return 0
}

_mb_order() {  # MB_ORDER = MB_VAULTS indices, the cwd's vault(s) first
  MB_ORDER=()
  local i pass
  for pass in 1 0; do
    i=0
    while [ "$i" -lt "${#MB_VAULTS[@]}" ]; do
      _mb_mine "${MB_VAULTS[$i]}" "$1"
      [ "$MB_MINE" -eq "$pass" ] && MB_ORDER[${#MB_ORDER[@]}]="$i"
      i=$((i + 1))
    done
  done
  return 0
}

_mb_push() { MB_LINES[${#MB_LINES[@]}]="$1"; return 0; }

_mb_finish() {  # cap the lines, assemble header + lines + rule, apply the byte cap
  local hdr="$1" out n i
  n="${#MB_LINES[@]}"
  if [ "$n" -gt "$MEGA_MAX_LINES" ]; then
    local keep=$((MEGA_MAX_LINES - 1)) more=$(( n - MEGA_MAX_LINES + 1 ))
    local tmp=() ; i=0
    while [ "$i" -lt "$keep" ]; do tmp[$i]="${MB_LINES[$i]}"; i=$((i + 1)); done
    tmp[$keep]="+${more} more line(s) — details at M/L entry"
    MB_LINES=("${tmp[@]}")
  fi
  out="$hdr"
  i=0
  while [ "$i" -lt "${#MB_LINES[@]}" ]; do out="${out}"$'\n'"- ${MB_LINES[$i]}"; i=$((i + 1)); done
  out="${out}"$'\n'"${MEGA_RULE_LINE}"
  local LC_ALL=C
  if [ "${#out}" -gt "$MEGA_BLOCK_MAX" ]; then
    out="$hdr"; i=0
    while [ "$i" -lt "${#MB_ORDER[@]}" ] && [ "$i" -lt "$MEGA_MAX_LINES" ]; do
      local rec="${MB_VAULTS[${MB_ORDER[$i]}]}" nm
      _mb_field "$rec" 0; nm="$_MB_F"; _mb_field "$rec" 1
      [ -n "$_MB_F" ] && out="${out}"$'\n'"- ${nm}: ${_MB_F}"
      i=$((i + 1))
    done
    out="${out}"$'\n'"${MEGA_RULE_LINE}"
  fi
  STATE_BLOCK="$out"
  return 0
}

_mb_render_hit() {
  MB_LINES=()
  local fresh="" i rec nm x
  i=0
  while [ "$i" -lt "${#MB_ORDER[@]}" ]; do
    rec="${MB_VAULTS[${MB_ORDER[$i]}]}"
    _mb_field "$rec" 2
    if [ "$_MB_F" = "1" ]; then
      _mb_field "$rec" 0
      fresh="${fresh:+$fresh, }$_MB_F"
    fi
    i=$((i + 1))
  done
  [ -n "$fresh" ] && _mb_push "FRESH: $fresh"
  i=0
  while [ "$i" -lt "${#MB_ORDER[@]}" ]; do
    rec="${MB_VAULTS[${MB_ORDER[$i]}]}"
    _mb_field "$rec" 0; nm="$_MB_F"
    _mb_field "$rec" 2
    if [ "$_MB_F" != "1" ]; then
      _mb_field "$rec" 4
      [ -n "$_MB_F" ] && _mb_push "$_MB_F"
      for x in ${MB_XLINES[@]+"${MB_XLINES[@]}"}; do
        _mb_field "$x" 0
        if [ "$_MB_F" = "$nm" ]; then _mb_field "$x" 1; _mb_push "$_MB_F"; fi
      done
    fi
    i=$((i + 1))
  done
  [ -n "$MB_UP" ] && _mb_push "$MB_UP"
  # the verdict tail is the engine's; the sha/branch are live (a branch switch at the
  # same commit must never be shown the old branch)
  local tail="${MB_HDR#* · }"
  [ "$tail" = "$MB_HDR" ] && tail="${MB_HDR#*) }"
  _mb_finish "mega-sdd state @ ${MEGA_HEAD:0:12} (${MEGA_BR}) · ${tail}"
  return 0
}

# MISS: HEAD moved since the engine's check. Exactly ONE `git diff` (or 0 when the
# overlay already reaches HEAD); every vault keeps its cached status word and gets
# a content-only delta. The hook writes the overlay, NEVER `checked`.
# The changed paths (CH) under vault $1's scope: first 3 into `hits`, total into `nhit`.
# Linear: the vault's exact specs become one newline-delimited set string, each path is
# checked with its ancestors against it; the basename lane likewise; a wildcard spec (a
# glob-shaped target) uses a case pattern. Never O(vaults x paths x all specs).
_mb_vault_hits() {
  local nm="$1" vex=$'\n' vgl=$'\n' vwd=() j=0 p a hit w
  while [ "$j" -lt "${#sspec[@]}" ]; do
    if [ "${svault[$j]}" = "$nm" ]; then
      case "${sspec[$j]}" in
        ":(glob)**/"*) vgl="${vgl}${sspec[$j]#:(glob)\*\*/}"$'\n' ;;
        *"*"*|*"?"*) vwd[${#vwd[@]}]="${sspec[$j]}" ;;
        *) vex="${vex}${sspec[$j]}"$'\n' ;;
      esac
    fi
    j=$((j + 1))
  done
  for p in ${CH[@]+"${CH[@]}"}; do
    [ -n "$p" ] || continue
    hit=0; a="$p"
    case "$vex" in *$'\n.\n'*) hit=1 ;; esac   # a scope coarsened to "." = everything
    while [ "$hit" -eq 0 ]; do
      case "$vex" in *$'\n'"$a"$'\n'*) hit=1; break ;; esac
      case "$a" in */*) a="${a%/*}" ;; *) break ;; esac
    done
    if [ "$hit" -eq 0 ] && [ "$vgl" != $'\n' ]; then
      case "$vgl" in *$'\n'"${p##*/}"$'\n'*) hit=1 ;; esac
    fi
    if [ "$hit" -eq 0 ]; then
      for w in ${vwd[@]+"${vwd[@]}"}; do
        # shellcheck disable=SC2254
        case "$p" in $w) hit=1; break ;; esac
      done
    fi
    if [ "$hit" -eq 1 ]; then
      nhit=$((nhit + 1))
      [ "${#hits[@]}" -lt 3 ] && hits[${#hits[@]}]="$p"
    fi
  done
  return 0
}

_mb_render_miss() {
  local head="$1" gitdir="$2" cache="$3"
  local ov="${cache}.overlay" sc="${cache}.scope" line base="" through="" rc=0 x=""
  local specs=() svault=() sspec=() ov_c=() ov_n=() unver=0 k
  # scope file: s=<vault>\x1f<top-relative pathspec>
  local sc_first="" sc_end="" sc_ok=0
  if [ -f "$sc" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      [ -z "$sc_first" ] && sc_first="$line"
      case "$line" in
        s=*) line="${line#s=}"
             svault[${#svault[@]}]="${line%%"$MEGA_SEP"*}"
             sspec[${#sspec[@]}]="${line#*"$MEGA_SEP"}" ;;
        end=*) sc_end="${line#end=}" ;;
      esac
    done < "$sc" 2>/dev/null || true
  fi
  # the same reader rule as the main cache: a torn / foreign / other-run .scope proves nothing
  [ "$sc_first" = "v=1" ] && [ "$sc_end" = "$MB_CHECKED" ] && sc_ok=1
  if [ "$sc_ok" -ne 1 ]; then svault=(); sspec=(); fi
  # overlay: valid only while its base is the cache's checked
  if [ -f "$ov" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      case "$line" in
        base=*) base="${line#base=}" ;;
        through=*) through="${line#through=}" ;;
        c=*) ov_c[${#ov_c[@]}]="${line#c=}" ;;
        n=*) ov_n[${#ov_n[@]}]="${line#n=}" ;;
        unverified=1) unver=1 ;;
      esac
    done < "$ov" 2>/dev/null || true
    if [ "$base" != "$MB_CHECKED" ] || ! _gh_hex "$through"; then through=""; ov_c=(); ov_n=(); unver=0; fi
    [ "$through" = "$head" ] || unver=0   # an overlay that does not reach HEAD is recomputed
  fi
  # ONE diff from `checked` (not incremental from the overlay): exact, same single
  # process; the overlay only saves the diff when it already reaches HEAD. Linear in
  # the diff size and CAPPED at MEGA_MISS_MAX paths — a bigger move renders
  # "later moves UNVERIFIED" (bash string matching is the cost, not git).
  local CH=()
  [ "$sc_ok" -eq 1 ] || unver=1   # no trustworthy scope → never "no further scope change"
  if [ "$through" = "$head" ] && [ "$unver" -eq 0 ]; then
    for k in ${ov_c[@]+"${ov_c[@]}"}; do CH[${#CH[@]}]="${k#*"$MEGA_SEP"}"; done
  elif [ "$unver" -eq 0 ]; then
    specs=(${sspec[@]+"${sspec[@]}"})   # repeated pathspecs are harmless to git
    if [ "${#specs[@]}" -gt 0 ]; then
      # the LIVE worktree top (the builtin walk), never the cached one: a copied or moved
      # checkout still carries the old absolute top= in its git dir
      x=$(MSYS_NO_PATHCONV=1 GIT_OPTIONAL_LOCKS=0 exec git -C "$GH_TOP" -c core.quotepath=false -c core.fsmonitor=false \
            diff --name-only --no-renames --no-relative "$MB_CHECKED" "$head" -- "${specs[@]}" 2>/dev/null) || rc=$?
      if [ "$rc" -ne 0 ]; then
        unver=1
      else
        # newline split into an array, no here-string (bash 3.2 writes those to $TMPDIR,
        # and a failed redirection under set -e would kill the whole hook)
        local oifs="$IFS"
        set -f; IFS=$'\n'
        CH=($x)
        IFS="$oifs"; set +f
        [ "${#CH[@]}" -gt "$MEGA_MISS_MAX" ] && { unver=1; CH=(); }
      fi
    fi
  fi
  # per vault: the first 3 changed paths under its specs + the total
  MB_LINES=()
  local ovw="" i rec nm word
  i=0
  while [ "$i" -lt "${#MB_ORDER[@]}" ]; do
    rec="${MB_VAULTS[${MB_ORDER[$i]}]}"
    _mb_field "$rec" 0; nm="$_MB_F"; _mb_field "$rec" 1; word="$_MB_F"
    local hits=() nhit=0 p j hit
    if [ "$through" = "$head" ] && [ "$unver" -eq 0 ]; then
      for k in ${ov_c[@]+"${ov_c[@]}"}; do
        if [ "${k%%"$MEGA_SEP"*}" = "$nm" ]; then hits[${#hits[@]}]="${k#*"$MEGA_SEP"}"; fi
      done
      nhit="${#hits[@]}"
      for k in ${ov_n[@]+"${ov_n[@]}"}; do
        if [ "${k%%"$MEGA_SEP"*}" = "$nm" ]; then nhit="${k#*"$MEGA_SEP"}"; fi
      done
    else
      _mb_vault_hits "$nm"
    fi
    for p in ${hits[@]+"${hits[@]}"}; do ovw="${ovw}c=${nm}${MEGA_SEP}${p}"$'\n'; done
    ovw="${ovw}n=${nm}${MEGA_SEP}${nhit}"$'\n'
    if [ -n "$word" ]; then
      if [ "$unver" -eq 1 ]; then
        _mb_push "${nm}: ${word} (as of ${MB_CHECKED:0:8}) · later moves UNVERIFIED (large move / git error)"
      elif [ "$nhit" -gt 0 ]; then
        local shown=""
        for p in "${hits[@]}"; do
          case "$p" in "$MB_PREFIX"/*) p="${p#"$MB_PREFIX"/}" ;; esac
          _mb_san "$p" 80; shown="${shown:+$shown, }$_MB_S"
        done
        [ "$nhit" -gt "${#hits[@]}" ] && shown="${shown} +$(( nhit - ${#hits[@]} ))"
        _mb_push "${nm}: ${word} (as of ${MB_CHECKED:0:8}) · changed since: ${shown}"
      else
        _mb_push "${nm}: ${word} (as of ${MB_CHECKED:0:8}) · no further scope change"
      fi
    fi
    for x in ${MB_XLINES[@]+"${MB_XLINES[@]}"}; do
      _mb_field "$x" 0
      if [ "$_MB_F" = "$nm" ]; then _mb_field "$x" 1; _mb_push "$_MB_F"; fi
    done
    i=$((i + 1))
  done
  _mb_finish "mega-sdd state @ ${head:0:12} (${MEGA_BR}) · as of check ${MB_CHECKED:0:8}; later moves checked by content only:"
  # the overlay is written by mega_state_seen_write, after the block is printed
  MB_OVERLAY="base=${MB_CHECKED}"$'\n'"through=${head}"$'\n'"${ovw}"
  [ "$unver" -eq 1 ] && MB_OVERLAY="${MB_OVERLAY}unverified=1"$'\n'
  return 0
}

mega_state_block() {
  local root="$1" cwd="$2" sid="$3" src="$4" py_ok="$5" notice_on="$6"
  STATE_BLOCK=""; MB_OVERLAY=""; MB_SEEN_SKIP=0; MEGA_HEAD=""; MEGA_BR=""; MEGA_BR_RAW=""
  MB_SID=""; MB_GITDIR=""
  if ! mega_git_dir "$root"; then
    STATE_BLOCK="mega-sdd state · no git repository at this project root:"$'\n'"${MEGA_RULE_LINE}"
    return 0
  fi
  MB_GITDIR="$GH_GITDIR"
  local rc=0 x=""
  if mega_git_head packed; then
    MEGA_HEAD="$GH_HEAD"; MEGA_BR="$GH_BRANCH"; MEGA_BR_RAW="$GH_BRANCH"
  else
    # reftable / unborn / a ref the builtins cannot read: ONE git process gives the sha
    # and the branch (no MSYS_NO_PATHCONV: -C needs the MSYS path converted on Git Bash)
    x=$(GIT_OPTIONAL_LOCKS=0 exec git -C "$GH_TOP" rev-parse HEAD --abbrev-ref HEAD 2>/dev/null) || rc=$?
    if [ "$rc" -eq 0 ] && _gh_hex "${x%%$'\n'*}"; then
      MEGA_HEAD="${x%%$'\n'*}"; MEGA_BR="${x#*$'\n'}"
      [ "$MEGA_BR" = "HEAD" ] && MEGA_BR="detached"
    else
      MEGA_BR="${GH_BRANCH:-detached}"
    fi
    MEGA_BR_RAW="$MEGA_BR"
  fi
  _mb_san "$MEGA_BR" 60; MEGA_BR="$_MB_S"
  if [ -z "$MEGA_HEAD" ]; then
    STATE_BLOCK="mega-sdd state @ (no commits yet) (${MEGA_BR}):"$'\n'"${MEGA_RULE_LINE}"
    return 0
  fi
  # session id: validated, never eval'd; an odd id just skips the ring
  case "$sid" in *[!A-Za-z0-9-]*|"") sid="" ;; esac
  if [ -n "$sid" ] && { [ "${#sid}" -lt 8 ] || [ "${#sid}" -gt 64 ]; }; then sid=""; fi
  MB_SID="$sid"
  if [ "$src" = "resume" ] && [ -n "$sid" ] && [ -f "$MB_GITDIR/mega-sdd-seen" ]; then
    local l
    while IFS= read -r l || [ -n "$l" ]; do
      if [ "${l%% *}" = "$sid" ]; then
        l="${l#* }"
        [ "$l" = "$MEGA_HEAD $MEGA_BR_RAW" ] && { MB_SEEN_SKIP=1; return 0; }
      fi
    done < "$MB_GITDIR/mega-sdd-seen" 2>/dev/null || true
  fi
  if [ "$notice_on" -eq 0 ]; then
    STATE_BLOCK="mega-sdd state @ ${MEGA_HEAD:0:12} (${MEGA_BR}):"$'\n'"${MEGA_RULE_LINE}"
    return 0
  fi
  local cache="$MB_GITDIR/mega-sdd-freshness"
  _mb_parse_cache "$cache"
  if [ "$MB_OK" -ne 1 ]; then
    if [ "$py_ok" -eq 1 ]; then
      STATE_BLOCK="mega-sdd state @ ${MEGA_HEAD:0:12} (${MEGA_BR}) · per-vault freshness not computed yet:"
    else
      STATE_BLOCK="mega-sdd state @ ${MEGA_HEAD:0:12} (${MEGA_BR}) · per-vault freshness unavailable on this machine (no usable python):"
    fi
    STATE_BLOCK="${STATE_BLOCK}"$'\n'"${MEGA_RULE_LINE}"
    return 0
  fi
  local rel=""
  case "$cwd" in "$root"/*) rel="${cwd#"$root"/}" ;; esac
  _mb_order "$rel"
  _mb_cache_newer "$cache"
  if [ "$MB_CHECKED" = "$MEGA_HEAD" ] && [ "$MB_NEWER" -eq 1 ]; then
    _mb_render_hit
  else
    _mb_render_miss "$MEGA_HEAD" "$MB_GITDIR" "$cache"
  fi
  return 0
}

# After the block is printed: the overlay (miss path) and this session's ring entry.
mega_state_seen_write() {
  [ -n "${MB_GITDIR:-}" ] || return 0
  if [ -n "${MB_OVERLAY:-}" ]; then
    { printf '%s' "$MB_OVERLAY" > "$MB_GITDIR/mega-sdd-freshness.overlay"; } 2>/dev/null || :
  fi
  [ -n "${MB_SID:-}" ] && [ -n "${MEGA_HEAD:-}" ] || return 0
  mega_seen_ring_put "$MB_GITDIR" "$MB_SID" "$MEGA_HEAD" "$MEGA_BR_RAW"
  return 0
}

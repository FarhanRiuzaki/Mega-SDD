#!/usr/bin/env bash
# State anchor — the session-start state block (spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §6, §13). Runs the REAL
# hook body (hooks/session-start) the way hooks.json dispatches it, on a git fixture
# whose view cache the engine wrote; counts git processes through a PATH shim.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
HOOK="$PLUGIN/hooks/session-start"
LIB="$PLUGIN/scripts/_lib"
WORK="$(mktemp -d)"; trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1
SSHOME="$WORK/home"; mkdir -p "$SSHOME/.claude/plugins/cache/x/superpowers" "$SSHOME/.claude/commands"
_FDWV=$(grep -m1 '^WRAPPER_VERSION=' "$PLUGIN/scripts/install-front-door.sh" | tr -dc '0-9')
printf '%s\n' "<!-- mega-sdd-front-door-wrapper v${_FDWV} — managed by the mega-sdd plugin -->" > "$SSHOME/.claude/commands/mega-sdd.md"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }
G() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
RULE="Rule: code at HEAD decides what the code IS (files, symbols, lines, what is built). Memory, CLAUDE.md and vault/unit/bolt-report claims about what the code IS are derived: no SHA = hint, contradicts HEAD = STALE; say so, never use them silently. What the code SHOULD do stays with the vault: a spec-vs-code mismatch is a CONFLICT for a human."

# git-process counting shim
CNT="$WORK/gitcount"; SH="$WORK/shim"; mkdir -p "$SH"
printf '#!/bin/sh\necho "$*" >> "%s"\nexec "%s" "$@"\n' "$CNT" "$(command -v git)" > "$SH/git"; chmod +x "$SH/git"
BASH_BIN="${BASH_UNDER_TEST:-bash}"

ss() { # <dir> <source> [sid] [extra env…] — stdout of the hook
  local d="$1" src="$2" sid="${3:-sess-block-0001}"
  ( cd "$d" && printf '{"session_id":"%s","source":"%s"}' "$sid" "$src" \
      | HOME="$SSHOME" PATH="$SH:$PATH" "$BASH_BIN" "$HOOK" )
}
block() { printf '%s\n' "$1" | sed -n '/^mega-sdd state/,/^Rule: /p'; }
ngit() { if [ -f "$CNT" ]; then grep -c . "$CNT" | tr -d ' '; else echo 0; fi; }

mk() { # <dir> — two vaults, script stamps at HEAD, engine cache written
  local d="$1"
  mkdir -p "$d/apps/web/src" "$d/apps/api/src" "$d/.mega-sdd/vaults/web/units" "$d/.mega-sdd/vaults/api/units"
  printf 'a\nb\n' > "$d/apps/web/src/client.ts"; printf 'x\n' > "$d/apps/api/src/Svc.php"
  printf -- '---\nid: U-001\ntarget_files:\n  - path: apps/web/src/client.ts\n    operation: modify\n---\n' > "$d/.mega-sdd/vaults/web/units/U-001.md"
  printf -- '---\nid: U-010\ntarget_files:\n  - path: apps/api/src/Svc.php\n    operation: modify\n---\n' > "$d/.mega-sdd/vaults/api/units/U-010.md"
  ( cd "$d" && git init -q -b main . && G add -A && G commit -qm seed )
  local s; s=$(git -C "$d" rev-parse HEAD)
  for vu in web/U-001 api/U-010; do
    mkdir -p "$d/.mega-sdd/vaults/${vu%/*}/bolts/${vu#*/}"
    printf '{"schema":"unit-binding/2","based_on_sha":"%s","claims":[]}\n' "$s" > "$d/.mega-sdd/vaults/${vu%/*}/bolts/${vu#*/}/binding.json"
  done
  sleep 1
  python3 "$LIB/freshness.py" --cwd="$d" >/dev/null
  sleep 1
}

F="$WORK/fx"; mk "$F"

# 1. HIT: 0 git processes, verified header, FRESH collapse, rule line verbatim
: > "$CNT"; O=$(ss "$F" startup); B=$(block "$O")
[ "$(ngit)" -eq 0 ] && has "$B" "verified at this HEAD" && has "$B" "- FRESH: api, web" && has "$B" "$RULE" \
  && ok "HIT: 0 git, verified header, FRESH collapse, rule line" || bad "HIT git=$(ngit) [$B]"
LC_ALL=C; [ "${#B}" -le 1200 ] && ok "block ≤1200 B (${#B})" || bad "block size ${#B}"; unset LC_ALL
{ has "$B" "/mega-sdd" || has "$B" "sync"; } && bad "block carries a /mega-sdd or sync imperative" || ok "no /mega-sdd or sync imperative in the block"

# 2. the seen ring records this session at HEAD; resume at the same HEAD skips the block
grep -q "^sess-block-0001 $(git -C "$F" rev-parse HEAD) main$" "$F/.git/mega-sdd-seen" \
  && ok "seen ring: <sid> <sha> <branch>, nothing else" || bad "ring: $(cat "$F/.git/mega-sdd-seen" 2>/dev/null)"
O=$(ss "$F" resume)
! has "$O" "mega-sdd state @" && ok "resume at an unchanged HEAD: block skipped" || bad "resume printed the block"

# 3. MISS: exactly one git process, cached status kept, delta appended, `checked` never rewritten
( cd "$F" && echo c >> apps/web/src/client.ts && G commit -qam "feat(web): c" )
CK_BEFORE=$(grep '^checked=' "$F/.git/mega-sdd-freshness")
: > "$CNT"; O=$(ss "$F" compact); B=$(block "$O")
[ "$(ngit)" -eq 1 ] && has "$B" "as of check" && has "$B" "web: FRESH (as of" && has "$B" "changed since: apps/web/src/client.ts" \
  && has "$B" "api: FRESH (as of" && has "$B" "no further scope change" \
  && ok "MISS: 1 git process, status words kept + content delta" || bad "MISS git=$(ngit) [$B]"
[ "$(grep '^checked=' "$F/.git/mega-sdd-freshness")" = "$CK_BEFORE" ] && ok "miss path never rewrites checked=" || bad "checked rewritten"
# overlay already reaches HEAD → 0 git
: > "$CNT"; O=$(ss "$F" clear sess-block-0002)
[ "$(ngit)" -eq 0 ] && has "$O" "changed since: apps/web/src/client.ts" && ok "overlay through == HEAD: re-render at 0 git" || bad "overlay reuse git=$(ngit)"

# 4. git rc≠0 on the miss path (cache checked= points at a vanished object) → UNVERIFIED, hook survives
F4="$WORK/fx4"; cp -a "$F" "$F4"
sed -i.bak 's/^checked=.*/checked=0123456789abcdef0123456789abcdef01234567/; s/^end=.*/end=0123456789abcdef0123456789abcdef01234567/' "$F4/.git/mega-sdd-freshness"
rm -f "$F4/.git/mega-sdd-freshness.overlay"
O=$(ss "$F4" startup); rc=$?
[ "$rc" -eq 0 ] && has "$O" "later moves UNVERIFIED" && has "$O" "<</EXTREMELY_IMPORTANT>>" \
  && ok "git rc 128 on the miss diff: statuses kept + 'later moves UNVERIFIED', anchor intact (set -euo pipefail)" || bad "rc128 miss rc=$rc [$O]"

# 5. read-only git dir: block + anchor still print, writes silently skipped
F5="$WORK/fx5"; cp -a "$F" "$F5"; chmod a-w "$F5/.git"
O=$(ss "$F5" startup sess-block-0005); rc=$?
chmod u+w "$F5/.git"
[ "$rc" -eq 0 ] && has "$O" "mega-sdd state @" && has "$O" "<</EXTREMELY_IMPORTANT>>" \
  && ok "read-only git dir: block + anchor printed, hook rc 0" || bad "read-only rc=$rc"

# 6. torn cache → treated as absent; CRLF cache still parses
F6="$WORK/fx6"; cp -a "$F" "$F6"; sed -i.bak '$d' "$F6/.git/mega-sdd-freshness"
O=$(ss "$F6" startup)
has "$O" "per-vault freshness not computed yet" && ok "torn cache (no end=): treated as absent" || bad "torn [$O]"
F7="$WORK/fx7"; mk "$F7"; sed -i.bak 's/$/\r/' "$F7/.git/mega-sdd-freshness"
O=$(ss "$F7" startup)
has "$O" "- FRESH: api, web" && ok "CRLF-terminated cache lines parse" || bad "crlf [$O]"

# 7. an input written in the same second as (or after) the cache → MISS, never a stale HIT
F8="$WORK/fx8"; mk "$F8"; touch "$F8/.mega-sdd/vaults/web/bolts/U-001/binding.json"
: > "$CNT"; O=$(ss "$F8" startup)
has "$O" "as of check" && ok "binding newer than the cache: not a HIT" || bad "same-second [$O]"

# 8. no cache yet / no usable python / staleness_notice false
F9="$WORK/fx9"; mk "$F9"; rm -f "$F9/.git/mega-sdd-freshness"*
O=$(ss "$F9" startup); B=$(block "$O")
has "$B" "per-vault freshness not computed yet:" && has "$B" "$RULE" \
  && ok "no cache: header + rule line" || bad "no cache [$B]"
NOPY="$WORK/nopy"; mkdir -p "$NOPY"
for t in git bash sh sed grep cat dirname uname; do p=$(command -v "$t") && ln -sf "$p" "$NOPY/$t"; done
O=$( cd "$F9" && printf '{"session_id":"sess-nopy-0001","source":"startup"}' | HOME="$SSHOME" PATH="$NOPY" "$(command -v bash)" "$HOOK" )
has "$O" "per-vault freshness unavailable on this machine (no usable python):" && has "$O" "$RULE" && has "$O" "tidak ada interpreter python3" \
  && ok "no usable python: 'unavailable' header + rule line on the early-exit path" || bad "no-python [$O]"
printf 'staleness_notice: false\n' > "$F/.mega-sdd/config.yaml"
O=$(ss "$F" startup sess-block-0009); B=$(block "$O")
has "$B" "mega-sdd state @" && has "$B" "$RULE" && ! has "$B" "FRESH" && ! has "$B" "- " \
  && ok "staleness_notice: false → header + rule line only" || bad "notice off [$B]"
rm -f "$F/.mega-sdd/config.yaml"

# 9. nothing without .mega-sdd; nested .mega-sdd resolves; linked worktree resolves
P="$WORK/plain"; mkdir -p "$P"; ( cd "$P" && git init -q . )
O=$(ss "$P" startup); [ -z "$O" ] && ok "no SDD signal: silent" || bad "plain printed [$O]"
mkdir -p "$F/apps/web/sub"; O=$(ss "$F/apps/web/sub" startup sess-block-0010)
has "$O" "mega-sdd state @" && ok "subdir cwd resolves the project root" || bad "subdir [$O]"
( cd "$F" && git worktree add -q "$WORK/wt" -b wtb 2>/dev/null )
O=$(ss "$WORK/wt" startup sess-block-0011)
has "$O" "mega-sdd state @" && has "$O" "(wtb)" && ok "linked worktree: per-worktree git dir + branch" || bad "worktree [$O]"

# 10. injected strings are sanitized (hostile commit subject in the cache path)
F10="$WORK/fx10"; mk "$F10"
( cd "$F10" && echo z >> apps/web/src/client.ts && G commit -qam 'feat: $(touch /tmp/pwn) `x` <script>' )
python3 "$LIB/freshness.py" --cwd="$F10" >/dev/null; sleep 1
O=$(ss "$F10" startup)
! has "$O" '$(touch' && ! has "$O" '<script>' && ! has "$O" '`x`' && has "$O" "feat: _(touch /tmp/pwn) _x_ _script_" \
  && ok "commit subjects sanitized in the block (and actually rendered)" || bad "sanitize [$O]"

# 11. printf output is byte-identical to the old heredoc (anchor + no notice)
OLD="$WORK/oldplugin"; mkdir -p "$OLD"; cp -a "$PLUGIN/." "$OLD/"
git -C "$REPO" show e15465f3:plugins/mega-sdd/hooks/session-start > "$OLD/hooks/session-start"
N="$WORK/noidx"; mkdir -p "$N/.mega-sdd/vaults/v/units"
( cd "$N" && printf '{"session_id":"x","source":"startup"}' | HOME="$SSHOME" bash "$OLD/hooks/session-start" ) > "$WORK/old.out"
( cd "$N" && printf '{"session_id":"x","source":"startup"}' | HOME="$SSHOME" bash "$HOOK" ) > "$WORK/new.out"
python3 - "$WORK/old.out" "$WORK/new.out" <<'PY' && ok "printf framing byte-identical to the old heredoc (modulo the state block)" || bad "framing differs"
import re, sys
old = open(sys.argv[1], encoding="utf-8").read()
new = open(sys.argv[2], encoding="utf-8").read()
new = re.sub(r"\n\nmega-sdd state [^\n]*\n(?:[^\n]*\n)*?Rule: [^\n]*", "", new)
sys.exit(0 if old == new else 1)
PY

# 12. six vaults with long paths, all STALE: the block stays ≤1200 B with every status word;
#     the multi-vault MISS path stays fast (linear matching, one git process)
M6="$WORK/six"; mkdir -p "$M6"
for i in 1 2 3 4 5 6; do
  d="$M6/packages/a-rather-long-team-package-name-number-$i/src/components/feature"; mkdir -p "$d" "$M6/.mega-sdd/vaults/team$i/units"
  echo x > "$d/Widget$i.tsx"
  printf -- '---\nid: U-001\ntarget_files:\n  - path: packages/a-rather-long-team-package-name-number-%s/src/components/feature/Widget%s.tsx\n    operation: modify\n---\n' "$i" "$i" > "$M6/.mega-sdd/vaults/team$i/units/U-001.md"
done
( cd "$M6" && git init -q -b main . && G add -A && G commit -qm seed )
for i in 1 2 3 4 5 6; do
  mkdir -p "$M6/.mega-sdd/vaults/team$i/bolts/U-001"
  printf '{"schema":"unit-binding/2","based_on_sha":"%s","claims":[]}\n' "$(git -C "$M6" rev-parse HEAD)" > "$M6/.mega-sdd/vaults/team$i/bolts/U-001/binding.json"
done
( cd "$M6" && for i in 1 2 3 4 5 6; do echo y >> packages/a-rather-long-team-package-name-number-$i/src/components/feature/Widget$i.tsx; done && G commit -qam "feat: every team moved at once with a long subject line here" )
sleep 1; python3 "$LIB/freshness.py" --cwd="$M6" >/dev/null; sleep 1
O=$(ss "$M6" startup sess-block-0012); B=$(block "$O"); LC_ALL=C; n=${#B}; unset LC_ALL
[ "$n" -le 1200 ] && has "$B" "team1: STALE" && has "$B" "$RULE" && ok "6 long-path STALE vaults: block ≤1200 B ($n), status words + rule kept" || bad "six vaults: $n B [$B]"
( cd "$M6" && for i in 1 2 3 4 5 6; do echo z >> packages/a-rather-long-team-package-name-number-$i/src/components/feature/Widget$i.tsx; done && G commit -qam more )
: > "$CNT"; a=$(python3 -c 'import time;print(time.time())'); O=$(ss "$M6" startup sess-block-0013); b=$(python3 -c 'import time;print(time.time())')
ms=$(python3 -c "print(int(($b-$a)*1000))")
B=$(block "$O"); LC_ALL=C; n=${#B}; unset LC_ALL
[ "$(ngit)" -eq 1 ] && [ "$ms" -lt 3000 ] && [ "$n" -le 1200 ] && has "$B" "team6: STALE since" && has "$B" "as of check" \
  && ok "6-vault MISS: 1 git process, ${ms} ms, ≤1200 B ($n) with every status word" || bad "six-vault miss: git=$(ngit) ${ms}ms ${n}B"

[ "$fail" -eq 0 ] && { echo "PASS state-anchor session block"; exit 0; }
echo "state-anchor session block FAILED"; exit 1

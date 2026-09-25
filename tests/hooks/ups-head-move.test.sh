#!/usr/bin/env bash
# UserPromptSubmit — the state-anchor "HEAD moved this session" line (spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §7, D11/D12).
# Contract: line 1 stays `mega-sdd-trace:turn` byte-verbatim; the optional HEAD line
# comes after the census line; 0 external processes and 0 forks per prompt; one line
# per HEAD move per session (the seen ring is keyed by session id, so two sessions
# on one worktree each see the move once); packed refs after gc are not a move.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
HOOK="$PLUGIN/hooks/user-prompt-submit"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_NOSYSTEM=1
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
G() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
MOVED="mega-sdd: HEAD moved this session ("

F="$WORK/p"; mkdir -p "$F/.mega-sdd/vaults/v/units" "$F/src"
( cd "$F" && git init -q -b main . && echo a > src/a.ts && G add -A && G commit -qm seed )
ups() { # <sid> [prompt] [extra PATH prefix]
  printf '{"session_id":"%s","cwd":"%s","prompt":"%s"}' "$1" "$F/src" "${2:-hi}" \
    | PATH="${3:+$3:}$PATH" bash "$HOOK"
}
seed_ring() { printf '%s %s %s\n' "$1" "$(git -C "$F" rev-parse HEAD)" "$(git -C "$F" rev-parse --abbrev-ref HEAD)" >> "$F/.git/mega-sdd-seen"; }

# 1. static fork pin: no command substitution / backticks in the hook or the libs it sources
python3 - "$HOOK" "$PLUGIN/scripts/_lib/git-head.sh" "$PLUGIN/scripts/_lib/resolve-project-root.sh" <<'PY' \
  && ok "no \$( / backtick / pipeline in the UPS hot path (hook + git-head.sh + resolver)" || bad "fork construct in the UPS hot path"
import re, sys
bad = []
for f in sys.argv[1:]:
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        code = line.split("#", 1)[0] if not line.lstrip().startswith("#") else ""
        c = re.sub(r"'[^']*'", "''", code)
        c = c.replace("$((", "")
        if "$(" in c or "`" in c:
            bad.append("%s:%d %s" % (f.rsplit("/", 1)[1], n, line.strip()))
        # a pipeline outside case patterns / [[ =~ ]] regex literals
        if re.search(r"[^|]\|[^|]", c) and not re.search(r"\)\s*$|^\s*[^)]*\|[^)]*\)\s", c) and "=~" not in c and "case" not in c:
            if not re.match(r"^\s*[\w\"'*.:/\\-]+(\|[\w\"'*.:/\\-]+)+\)", c.strip()):
                bad.append("%s:%d pipe: %s" % (f.rsplit("/", 1)[1], n, line.strip()))
for b in bad:
    print("   ", b)
sys.exit(1 if bad else 0)
PY

# 2. 0 external processes through a PATH shim (every common tool counted)
SH="$WORK/shim"; CNT="$WORK/cnt"; mkdir -p "$SH"
for t in git python3 python cat sed grep awk tr head tail wc dirname basename uname date mktemp; do
  real=$(command -v "$t" 2>/dev/null) || continue
  printf '#!/bin/sh\necho %s >> "%s"\nexec "%s" "$@"\n' "$t" "$CNT" "$real" > "$SH/$t"; chmod +x "$SH/$t"
done
seed_ring sess-aaaa-0001
( cd "$F" && G commit -q --allow-empty -m bump )
: > "$CNT"; O=$(ups sess-aaaa-0001 hi "$SH")
N=$(grep -c . "$CNT" | tr -d ' ')
[ "$N" -eq 0 ] && ok "HEAD-moved path: 0 external processes" || bad "externals: $(tr '\n' ' ' < "$CNT")"
[ "$(printf '%s\n' "$O" | head -1)" = "mega-sdd-trace:turn" ] && ok "line 1 is the gateway tag, byte-verbatim" || bad "line 1 [$O]"
case "$O" in *"$MOVED"*"-> "*", main) — the session-start state block is outdated; re-check memory/vault claims against code at HEAD."*) ok "HEAD-moved line printed once, verbatim shape" ;; *) bad "moved line [$O]" ;; esac

# 3. same session again: silent; another session on the same worktree sees it once
O=$(ups sess-aaaa-0001); [ "$O" = "mega-sdd-trace:turn" ] && ok "same session, same HEAD: silent" || bad "repeat [$O]"
seed_ring sess-bbbb-0002
( cd "$F" && G commit -q --allow-empty -m bump2 )
OA=$(ups sess-aaaa-0001); OB=$(ups sess-bbbb-0002); OB2=$(ups sess-bbbb-0002)
case "$OA$OB" in *"$MOVED"*"$MOVED"*) ok "two sessions on one worktree: each gets the line" ;; *) bad "A/B [$OA][$OB]" ;; esac
[ "$OB2" = "mega-sdd-trace:turn" ] && ok "…and only once" || bad "B twice [$OB2]"

# 4. unknown session: silent append; gc/pack-refs is not a move; a branch switch is
O=$(ups sess-cccc-0003); [ "$O" = "mega-sdd-trace:turn" ] && grep -q '^sess-cccc-0003 ' "$F/.git/mega-sdd-seen" \
  && ok "unknown session: silent, recorded in the ring" || bad "unknown sid [$O]"
( cd "$F" && git pack-refs --all )
O=$(ups sess-cccc-0003); [ "$O" = "mega-sdd-trace:turn" ] && ok "refs packed by gc (loose ref gone, same branch): silent" || bad "gc fired [$O]"
( cd "$F" && G checkout -q -b feat && G commit -q --allow-empty -m f )
O=$(ups sess-cccc-0003); case "$O" in *"$MOVED"*", feat)"*) ok "branch switch + new commit: fires" ;; *) bad "branch [$O]" ;; esac

# 5. invalid session ids: silent, nothing eval'd, ring untouched
before=$(cat "$F/.git/mega-sdd-seen")
for sid in 'x;rm -rf /' 'short' '$(id)' "$(printf 'a%.0s' $(seq 1 70))"; do
  O=$(ups "$sid"); [ "$O" = "mega-sdd-trace:turn" ] || bad "invalid sid printed [$O]"
done
[ "$(cat "$F/.git/mega-sdd-seen")" = "$before" ] && ok "invalid session ids: silent, ring untouched" || bad "ring changed by invalid sid"

# 6. the ring holds ≤8 sessions, three fields, no timestamps / counters / prompt text
for i in 1 2 3 4 5 6 7 8 9 10; do ups "sess-ring-$(printf '%04d' "$i")" "secret prompt $i" >/dev/null; done
L=$(grep -c . "$F/.git/mega-sdd-seen" | tr -d ' ')
[ "$L" -le 8 ] && ! grep -q secret "$F/.git/mega-sdd-seen" && awk 'NF!=3{e=1} END{exit e}' "$F/.git/mega-sdd-seen" \
  && ok "ring: ≤8 lines, <sid> <sha> <branch> only ($L)" || bad "ring shape ($L lines)"

# 7. ordering: census line (line 2) before the HEAD line (line 3)
mkdir -p "$F/.mega-sdd/codebase"; printf '{"path":"src/a.ts"}\n' > "$F/.mega-sdd/codebase/.dirty-paths.jsonl"
ups sess-cccc-0003 >/dev/null   # re-record (step 6 pushed it out of the ≤8 ring)
( cd "$F" && G commit -q --allow-empty -m again )
O=$(ups sess-cccc-0003 "udah selesai")
L2=$(printf '%s\n' "$O" | sed -n 2p); L3=$(printf '%s\n' "$O" | sed -n 3p)
case "$L2" in "mega-sdd: user menyiratkan"*) case "$L3" in "$MOVED"*) ok "census line 2, HEAD line 3" ;; *) bad "L3 [$L3]" ;; esac ;; *) bad "L2 [$L2]" ;; esac

# 8. staleness_notice: false silences the line
printf 'staleness_notice: false\n' > "$F/.mega-sdd/config.yaml"
( cd "$F" && G commit -q --allow-empty -m quiet )
O=$(ups sess-cccc-0003); case "$O" in *"$MOVED"*) bad "notice off still printed" ;; *) ok "staleness_notice: false → no HEAD line" ;; esac
rm -f "$F/.mega-sdd/config.yaml"

# 9. non-SDD cwd: silent (the contract), no ring written
P="$WORK/plain"; mkdir -p "$P"; ( cd "$P" && git init -q . )
O=$(printf '{"session_id":"sess-plain-0001","cwd":"%s"}' "$P" | bash "$HOOK")
[ -z "$O" ] && [ ! -f "$P/.git/mega-sdd-seen" ] && ok "non-SDD cwd: silent, no ring" || bad "plain [$O]"

[ "$fail" -eq 0 ] && { echo "PASS ups-head-move"; exit 0; }
echo "ups-head-move FAILED"; exit 1

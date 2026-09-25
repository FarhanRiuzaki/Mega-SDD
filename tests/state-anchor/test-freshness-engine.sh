#!/usr/bin/env bash
# State anchor — the freshness engine (spec docs/superpowers/specs/2026-09-25-state-anchor-design.md
# §5, §11, §13). Verdicts per scenario on a two-team monorepo fixture:
#   apps/web  = FE vault `web`  (per-unit bindings, unit-binding/2 or pre-honest /1)
#   apps/api  = BE vault `api`  (classic whole-vault binding.json, model-typed head)
# plus attribution built from the VERBATIM field bolt-commit layout (SDD lines,
# blank line, Co-Authored-By paragraph) — git's trailer parser misses that layout.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO/plugins/mega-sdd/scripts/_lib"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1 HOME="$WORK/home"
mkdir -p "$HOME"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
G() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
run() { python3 "$LIB/freshness.py" --cwd="$1" --print ${2:+--cwd-rel="$2"} 2>&1; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

FIELD_MSG() { # <uid> <subject> — the verbatim field layout
  printf '%s\n\nUnit: %s\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=%s\nSDD-Acceptance: v5\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' "$2" "$1" "$1"
}

stamp_v2() { # <repo> <vault> <uid> <sha>
  mkdir -p "$1/.mega-sdd/vaults/$2/bolts/$3"
  printf '{"schema":"unit-binding/2","based_on_sha":"%s","head":"%s","unit":"%s","claims":[]}\n' "$4" "${4:0:8}" "$3" \
    > "$1/.mega-sdd/vaults/$2/bolts/$3/binding.json"
}
stamp_v1() {
  mkdir -p "$1/.mega-sdd/vaults/$2/bolts/$3"
  printf '{"schema":"unit-binding/1","head":"%s","unit":"%s","claims":[]}\n' "${4:0:8}" "$3" \
    > "$1/.mega-sdd/vaults/$2/bolts/$3/binding.json"
}

mkrepo() { # <dir> [with_api 1|0]
  local d="$1" api="${2:-1}"
  mkdir -p "$d/apps/web/src" "$d/apps/api/src" "$d/.mega-sdd/vaults/web/units"
  printf 'export const a = 1\nexport const b = 2\nexport const c = 3\n' > "$d/apps/web/src/client.ts"
  printf 'export function Login() {}\n' > "$d/apps/web/src/Login.tsx"
  printf '<?php class Svc {}\n' > "$d/apps/api/src/Svc.php"
  printf '<?php class Model {}\n' > "$d/apps/api/src/Model.php"
  printf 'readme\n' > "$d/README.md"
  printf 'node_modules/\n' > "$d/.gitignore"
  cat > "$d/.mega-sdd/vaults/web/units/U-001.md" <<'U'
---
id: U-001
target_files:
  - path: apps/web/src/Login.tsx
    operation: modify
---
# U-001
## Anchors
- `apps/web/src/client.ts:1-3` api client
U
  cat > "$d/.mega-sdd/vaults/web/units/U-002.md" <<'U'
---
id: U-002
target_files:
  - path: apps/web/src/New.tsx
    operation: create
---
# U-002
## Anchors
- `apps/web/src/client.ts:2` the b export
- `Widget.tsx:1` slash-less anchor (basename lane)
U
  if [ "$api" = "1" ]; then
    mkdir -p "$d/.mega-sdd/vaults/api/units"
    cat > "$d/.mega-sdd/vaults/api/units/U-010.md" <<'U'
---
id: U-010
target_files:
  - path: apps/api/src/Svc.php
    operation: modify
---
# U-010
U
  fi
  ( cd "$d" && git init -q -b main . && G add -A && G commit -q -m "seed" )
  local s; s=$(git -C "$d" rev-parse HEAD)
  stamp_v2 "$d" web U-001 "$s"; stamp_v2 "$d" web U-002 "$s"
  if [ "$api" = "1" ]; then
    printf '{"head":"%s","claims":[{"id":"C-1","anchor":"apps/api/src/Model.php:1"}]}\n' "$s" > "$d/.mega-sdd/vaults/api/binding.json"
  fi
  ( cd "$d" && G add -A && G commit -q -m "chore: bind" )
}

BASE="$WORK/base"; mkrepo "$BASE" 1
NOAPI="$WORK/noapi"; mkrepo "$NOAPI" 0
fresh() { rm -rf "$WORK/$1"; cp -a "$2" "$WORK/$1"; printf '%s' "$WORK/$1"; }

# 1. same SHA, script stamps only → verified header + FRESH collapse
D=$(fresh t1 "$NOAPI"); s=$(git -C "$D" rev-parse HEAD)
stamp_v2 "$D" web U-001 "$s"; stamp_v2 "$D" web U-002 "$s"
O=$(run "$D")
has "$O" "verified at this HEAD" && has "$O" "- FRESH: web" \
  && ok "same SHA (unit-binding/2): verified header + FRESH collapse" || bad "same SHA: [$O]"

# 2. classic model-typed head → hint tier, never FRESH, header says checked
O=$(run "$BASE")
has "$O" "api: no scope change since" && has "$O" "(stamp model-typed: hint)" && has "$O" "checked at this HEAD (hint-tier stamps marked)" \
  && ! has "$O" "verified at this HEAD" \
  && ok "classic model-typed head renders as hint, header not 'verified'" || bad "classic hint: [$O]"

# 3. pre-honest /1 stamp at HEAD → hint, no FRESH token (the ctl-C2-green class)
D=$(fresh t3 "$NOAPI"); s=$(git -C "$D" rev-parse HEAD)
stamp_v1 "$D" web U-001 "$s"; stamp_v1 "$D" web U-002 "$s"
O=$(run "$D")
has "$O" "(pre-honest stamp: hint)" && ! has "$O" "FRESH" && ! has "$O" "verified at this HEAD" \
  && ok "pre-honest short-8 stamp: hint only, never FRESH / verified" || bad "pre-honest: [$O]"

# 4. commit outside every scope → no scope change (FE stays FRESH)
D=$(fresh t4 "$NOAPI")
( cd "$D" && echo more >> README.md && G commit -qam "docs: readme" )
O=$(run "$D")
has "$O" "- FRESH: web" && ok "commit outside scope: web stays FRESH" || bad "outside scope: [$O]"

# 5. BE commit, FE untouched (the field report) → api STALE, web unchanged
D=$(fresh t5 "$BASE")
( cd "$D" && echo '// x' >> apps/api/src/Model.php && G commit -qam "feat(api): model change" )
O=$(run "$D" apps/web)
has "$O" "- FRESH: web" && has "$O" "api: STALE since" && has "$O" "apps/api/src/Model.php" && has "$O" "feat(api): model change" \
  && ok "BE commit: api STALE with file + commit, web FRESH" || bad "BE commit: [$O]"

# 6. teammate commit to FE read scope → web STALE, both pending units named
D=$(fresh t6 "$NOAPI")
( cd "$D" && echo 'export const d = 4' >> apps/web/src/client.ts && G commit -qam "feat(web): client d" )
O=$(run "$D")
has "$O" "web: STALE since" && has "$O" "apps/web/src/client.ts" && has "$O" "pending: U-001,U-002" \
  && ok "in-scope teammate commit: STALE + file + pending units" || bad "in-scope: [$O]"

# 7. own bolt commit, field layout, + an unlisted test file (B3 sanctioned) → dropped
D=$(fresh t7 "$NOAPI")
mkdir -p "$D/apps/web/src/__tests__"
( cd "$D" && echo '// impl' >> apps/web/src/Login.tsx && echo 't' > apps/web/src/__tests__/Login.test.tsx \
  && G add -A && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): login form") )
printf 'report\n' > "$D/.mega-sdd/vaults/web/bolts/U-001/bolt-report.md"
O=$(run "$D")
has "$O" "- FRESH: web" && ! has "$O" "STALE since" \
  && ok "own bolt commit (field layout, Co-Authored-By paragraph) + sanctioned test file: dropped" || bad "own bolt: [$O]"

# 8. teammate commit with only a feat(U-001) SUBJECT on U-001's target → STALE
D=$(fresh t8 "$NOAPI")
( cd "$D" && echo '// tm' >> apps/web/src/Login.tsx && G commit -qam "feat(U-001): teammate tweak" )
O=$(run "$D")
has "$O" "web: STALE since" && has "$O" "apps/web/src/Login.tsx" \
  && ok "subject-only feat(U-001) commit is NOT an own commit" || bad "subject-only: [$O]"

# 9. PROVENANCE line only → STALE
D=$(fresh t9 "$NOAPI")
( cd "$D" && echo '// p' >> apps/web/src/Login.tsx \
  && G commit -qa -F <(printf 'fix: x\n\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001\n') )
O=$(run "$D")
has "$O" "web: STALE since" && ok "PROVENANCE-only commit is NOT an own commit" || bad "provenance-only: [$O]"

# 10. squash quoting the lines, touching an out-of-scope AND an out-of-project path → STALE
D=$(fresh t10 "$NOAPI")
( cd "$D" && echo '// s' >> apps/web/src/Login.tsx && echo '// s' >> apps/api/src/Svc.php \
  && G commit -qa -F <(FIELD_MSG U-001 "Squash PR #12 (#12)") )
O=$(run "$D")
has "$O" "web: STALE since" && ok "squash quoting the SDD lines with foreign paths: NOT own (full-diff subset)" || bad "squash: [$O]"

# 11. two units' lines in one message (multi-bolt squash) → NOT own
D=$(fresh t11 "$NOAPI")
( cd "$D" && echo '// m' >> apps/web/src/Login.tsx \
  && G commit -qa -F <(printf 'squash\n\nUnit: U-001\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001\nSDD-Acceptance: v5\nUnit: U-002\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002\n') )
O=$(run "$D")
has "$O" "web: STALE since" && ok "message naming two units: NOT own (exactly-one rule)" || bad "two units: [$O]"

# 12. stamp on a divergent branch → STALE diverged, whole scope
D=$(fresh t12 "$NOAPI")
( cd "$D" && G checkout -q -b side && echo x >> README.md && G commit -qam side && G checkout -q main )
side=$(git -C "$D" rev-parse side); stamp_v2 "$D" web U-001 "$side"; stamp_v2 "$D" web U-002 "$side"
O=$(run "$D")
has "$O" "HEAD does not descend from stamp ${side:0:8}" && has "$O" "whole scope" \
  && ok "rebase / branch switch: STALE diverged, whole scope" || bad "diverged: [$O]"

# 13. stamp object gone (history rewrite + gc) → STALE unreachable
D=$(fresh t13 "$NOAPI")
stamp_v2 "$D" web U-001 0123456789abcdef0123456789abcdef01234567; stamp_v2 "$D" web U-002 0123456789abcdef0123456789abcdef01234567
O=$(run "$D")
has "$O" "stamp unreachable" && ok "unreachable stamp: STALE, whole scope" || bad "unreachable: [$O]"

# 14. dirty in-scope edit → flagged, never in the FRESH collapse
D=$(fresh t14 "$NOAPI"); echo '// dirty' >> "$D/apps/web/src/client.ts"
O=$(run "$D")
has "$O" "web: FRESH · dirty 1 (as of check)" && ! has "$O" "- FRESH: web" \
  && ok "dirty tree in scope: 'dirty 1', not collapsed" || bad "dirty: [$O]"

# 15. assume-unchanged hides an edit from status → still dirty
D=$(fresh t15 "$NOAPI")
( cd "$D" && git update-index --assume-unchanged apps/web/src/client.ts && echo '// hidden' >> apps/web/src/client.ts )
O=$(run "$D")
has "$O" "dirty 1" && ok "assume-unchanged in scope counts as dirty" || bad "assume-unchanged: [$O]"

# 16. an ignored node_modules copy of a basename-lane file is NOT dirt
D=$(fresh t16 "$NOAPI"); mkdir -p "$D/node_modules/x"; echo x > "$D/node_modules/x/Widget.tsx"
O=$(run "$D")
has "$O" "- FRESH: web" && ! has "$O" "dirty" && ok "ignored node_modules/…/Widget.tsx (basename lane): dirty 0" || bad "ignored dir: [$O]"

# 17. an untracked create target (exact scope path) → dirty
D=$(fresh t17 "$NOAPI"); echo 'new' > "$D/apps/web/src/New.tsx"
O=$(run "$D")
has "$O" "dirty 1" && ok "untracked exact scope path counts as dirty" || bad "untracked: [$O]"

# 18. behind the last-fetched upstream → warning line; no upstream → none
D=$(fresh t18 "$NOAPI")
git init -q --bare -b main "$WORK/origin.git"
( cd "$D" && git remote add origin "$WORK/origin.git" && git push -q -u origin main 2>/dev/null )
git clone -q "$WORK/origin.git" "$WORK/clone"
( cd "$WORK/clone" && echo '// up' >> apps/web/src/client.ts && G commit -qam "feat(web): upstream change" && git push -q origin main 2>/dev/null )
( cd "$D" && git fetch -q origin )
O=$(run "$D")
has "$O" "upstream origin/main" && has "$O" "1 commit(s) touching web not pulled" \
  && ok "behind upstream: warning line (no fetch done by the engine)" || bad "upstream: [$O]"
O=$(run "$WORK/t4")
! has "$O" "upstream" && ok "no upstream: no line" || bad "no-upstream: [$O]"

# 19. merge resolving an in-scope file to a STALE side version → STALE (tree diff, never --cc)
D=$(fresh t19 "$NOAPI")
( cd "$D" && G checkout -q -b side && echo x >> README.md && G commit -qam side-readme && G checkout -q main \
  && echo 'export const e = 5' >> apps/web/src/client.ts && G commit -qam "feat(web): e" )
A=$(git -C "$D" rev-parse HEAD); stamp_v2 "$D" web U-001 "$A"; stamp_v2 "$D" web U-002 "$A"
( cd "$D" && G commit -qam "chore: rebind" && G merge -q --no-ff --no-commit side 2>/dev/null; git checkout side -- apps/web/src/client.ts && G commit -qm "merge side" )
O=$(run "$D")
has "$O" "web: STALE since" && has "$O" "apps/web/src/client.ts" \
  && ok "merge to a stale side: STALE (tree diff sees what --cc hides)" || bad "merge stale side: [$O]"
/usr/bin/grep -q -- '--cc' "$LIB/freshness.py" && bad "freshness.py mentions --cc" || ok "engine never uses --cc"

# 20. more than 8 distinct stamps → the rest UNVERIFIED (no silent FRESH)
D=$(fresh t20 "$NOAPI")
for i in 3 4 5 6 7 8 9 10 11; do
  n=$(printf '%03d' "$i")
  printf -- '---\nid: U-%s\ntarget_files:\n  - path: apps/web/src/F%s.tsx\n    operation: create\n---\n' "$n" "$n" > "$D/.mega-sdd/vaults/web/units/U-$n.md"
  ( cd "$D" && echo "$i" >> README.md && G commit -qam "r$i" )
  stamp_v2 "$D" web "U-$n" "$(git -C "$D" rev-parse HEAD)"
done
( cd "$D" && G add -A && G commit -qm units )
O=$(run "$D")
has "$O" "UNVERIFIED" && ok ">8 distinct stamps: the overflow is UNVERIFIED" || bad ">8 stamps: [$O]"

# 21. nested project (monorepo prefix) + a root-escaping scope path
M="$WORK/mono"; mkdir -p "$M/shared" "$M/proj/.mega-sdd/vaults/web/units" "$M/proj/src"
echo 'lib' > "$M/shared/lib.ts"; echo 'x' > "$M/proj/src/a.ts"
printf -- '---\nid: U-001\ntarget_files:\n  - path: src/a.ts\n    operation: modify\n---\n## Anchors\n- `../shared/lib.ts:1`\n' > "$M/proj/.mega-sdd/vaults/web/units/U-001.md"
( cd "$M" && git init -q -b main . && G add -A && G commit -qm seed )
stamp_v2 "$M/proj" web U-001 "$(git -C "$M" rev-parse HEAD)"
( cd "$M" && G add -A && G commit -qm bind && echo more >> shared/lib.ts && G commit -qam "feat(shared): lib" )
O=$(run "$M/proj")
has "$O" "web: STALE since" && has "$O" "../shared/lib.ts" \
  && ok "nested project: root-escaping scope path diffed from the worktree top" || bad "nested/escaping: [$O]"

# 22. unit-ID collision across vaults switches the own-commit exemption off
D=$(fresh t22 "$NOAPI")
mkdir -p "$D/.mega-sdd/vaults/web2/units"; cp "$D/.mega-sdd/vaults/web/units/U-001.md" "$D/.mega-sdd/vaults/web2/units/"
stamp_v2 "$D" web2 U-001 "$(git -C "$D" rev-parse HEAD)"
( cd "$D" && G add -A && G commit -qm web2 )
s=$(git -C "$D" rev-parse HEAD); for v in web web2; do stamp_v2 "$D" $v U-001 "$s"; done; stamp_v2 "$D" web U-002 "$s"
( cd "$D" && G add -A && G commit -qm restamp && echo '// b' >> apps/web/src/Login.tsx && G commit -qa -F <(FIELD_MSG U-001 "feat(U-001): login") )
O=$(run "$D")
has "$O" "implemented code changed since bolt: U-001" \
  && ok "unit-ID collision: own-commit drop off for the shared path" || bad "collision: [$O]"

# 23. safe.directory-class git failure (rc 128 on every call) → UNVERIFIED, never STALE
D=$(fresh t23 "$NOAPI")
( cd "$D" && echo 'x' >> apps/web/src/client.ts && G commit -qam "feat(web): moved" )
SH="$WORK/shim128"; mkdir -p "$SH"
printf '#!/bin/sh\necho "fatal: detected dubious ownership" >&2\nexit 128\n' > "$SH/git"; chmod +x "$SH/git"
O=$(PATH="$SH:$PATH" run "$D")
has "$O" "UNVERIFIED" && ! has "$O" "unreachable" && ok "git rc 128 everywhere: UNVERIFIED, not 'unreachable'" || bad "rc128: [$O]"

# 24. git exec counts (PATH shim): fast path = status + ls-files only
D=$(fresh t24 "$NOAPI"); CNT="$WORK/gitcount"; SH2="$WORK/shimc"; mkdir -p "$SH2"
s=$(git -C "$D" rev-parse HEAD); stamp_v2 "$D" web U-001 "$s"; stamp_v2 "$D" web U-002 "$s"
REALGIT=$(command -v git)
printf '#!/bin/sh\necho "$*" >> "%s"\nexec "%s" "$@"\n' "$CNT" "$REALGIT" > "$SH2/git"; chmod +x "$SH2/git"
: > "$CNT"; PATH="$SH2:$PATH" run "$D" >/dev/null
N=$(grep -c . "$CNT" | tr -d ' ')
[ "$N" -eq 2 ] && ok "fast path (every stamp == HEAD): 2 git execs (status + ls-files)" || bad "fast path git execs=$N ($(tr '\n' ' ' < "$CNT"))"
( cd "$D" && echo 'x' >> apps/web/src/client.ts && G commit -qam "feat(web): moved" )
: > "$CNT"; PATH="$SH2:$PATH" run "$D" >/dev/null
N=$(grep -c . "$CNT" | tr -d ' ')
[ "$N" -le 6 ] && ok "one stamp moved in scope: $N git execs (≤6: merge-base, diff, log, status, ls-files)" || bad "moved git execs=$N ($(tr '\n' ' ' < "$CNT"))"

# 25. the view cache lands in the git dir, complete (v=1 … end=<checked>), never in the tree
D="$WORK/t4"; run "$D" >/dev/null
C="$D/.git/mega-sdd-freshness"
[ -f "$C" ] && [ "$(head -1 "$C")" = "v=1" ] && [ "$(tail -1 "$C")" = "end=$(git -C "$D" rev-parse HEAD)" ] \
  && [ -z "$(git -C "$D" status --porcelain)" ] \
  && ok "view cache in the git dir, complete, tree untouched" || bad "view cache"

# 26. the controller's L0 follow-up commit (Unit + PROVENANCE, no Acceptance) after the v5 bolt → dropped
D=$(fresh t26 "$NOAPI")
( cd "$D" && echo '// impl' >> apps/web/src/Login.tsx && G commit -qa -F <(FIELD_MSG U-001 "feat(U-001): login") \
  && echo '// fmt' >> apps/web/src/Login.tsx \
  && G commit -qa -F <(printf 'style(U-001): L0 format fix\n\nUnit: U-001\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001\n') )
O=$(run "$D")
has "$O" "- FRESH: web" && ok "L0 follow-up commit (no Acceptance line) of a v5-keyed unit: dropped" || bad "L0 follow-up: [$O]"

# 27. plain subject + all three body lines → NOT own (the gates' unit_of() does not attribute it)
D=$(fresh t27 "$NOAPI")
( cd "$D" && echo '// c' >> apps/web/src/Login.tsx && G commit -qa -F <(FIELD_MSG U-001 "chore: cleanup") )
O=$(run "$D")
has "$O" "web: STALE since" && ok "body lines under a non-unit subject: NOT own (unit_of mismatch)" || bad "plain subject: [$O]"

# 28. glob-declared target (B3 matcher): an own commit on a file it covers is dropped
D=$(fresh t28 "$NOAPI")
sed -i.bak 's#path: apps/web/src/Login.tsx#path: apps/web/src/**/*.tsx#' "$D/.mega-sdd/vaults/web/units/U-001.md"; rm -f "$D/.mega-sdd/vaults/web/units/U-001.md.bak"
mkdir -p "$D/apps/web/src/login"; echo 'x' > "$D/apps/web/src/login/Form.tsx"
( cd "$D" && G add -A && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): form") )
O=$(run "$D")
! has "$O" "STALE since" && ok "glob target_files: own commit on a covered file is dropped" || bad "glob target: [$O]"

# 29. a directory scope path on a clean tree is not dirt; an untracked file under it is (at the file)
D=$(fresh t29 "$NOAPI")
mkdir -p "$D/apps/web/src/config"; echo 'c' > "$D/apps/web/src/config/index.ts"
printf '## Claims\n- C-U002-01 "config exists" — expect: apps/web/src/config — must-exist\n' >> "$D/.mega-sdd/vaults/web/units/U-002.md"
( cd "$D" && G add -A && G commit -qm "config dir" )
s=$(git -C "$D" rev-parse HEAD); stamp_v2 "$D" web U-001 "$s"; stamp_v2 "$D" web U-002 "$s"
O=$(run "$D")
has "$O" "- FRESH: web" && ! has "$O" "dirty" && ok "clean directory scope path (field U-005 shape): dirty 0" || bad "dir clean: [$O]"
echo 'n' > "$D/apps/web/src/config/new.ts"
O=$(run "$D")
has "$O" "dirty 1" && ok "untracked file under a directory scope path: dirty 1" || bad "dir untracked: [$O]"

# 30. a rename of an out-of-scope file INTO an own target is not own (no hidden rename source)
D=$(fresh t30 "$NOAPI")
( cd "$D" && git rm -q apps/web/src/Login.tsx && git mv apps/api/src/Svc.php apps/web/src/Login.tsx \
  && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): move") )
O=$(run "$D")
has "$O" "web: STALE since" && ok "rename from outside the unit into its target: NOT own" || bad "rename: [$O]"

[ "$fail" -eq 0 ] && { echo "PASS state-anchor freshness engine"; exit 0; }
echo "state-anchor freshness engine FAILED"; exit 1

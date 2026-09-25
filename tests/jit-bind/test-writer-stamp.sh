#!/usr/bin/env bash
# State anchor — the honest writer (spec docs/superpowers/specs/2026-09-25-state-anchor-design.md
# §3, §9, §13 "test-writer-stamp"). Drives derive-unit-claims.sh + write-unit-binding.sh (+
# rebind-units.sh) on git fixtures and asserts what binding.json records:
#   the honest stamp and its null causes · refuse on a git error · claim-set integrity ·
#   unit_sha256 after an R1 rewrite · the content ladder rungs 1–5 · content_sha shapes ·
#   human-resolution carry-forward · IMPLEMENTED_BY_UNIT (incl. a legacy prior) · the index rule.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
S="$REPO/plugins/mega-sdd/scripts"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1 HOME="$WORK/home"
mkdir -p "$HOME"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
G() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
FIELD_MSG() { printf '%s\n\nUnit: %s\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=%s\nSDD-Acceptance: v5\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' "$2" "$1" "$1"; }
J() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d, "c": {x["id"]: x for x in d.get("claims", [])}}))' "$1" "$2" 2>&1; }

mk() { # <dir> — U-001: modify src/a.ts, anchors src/b.ts:2-3 (`beta` label) + src/c.ts:1, create src/New.ts
  local F="$1" V="$1/.mega-sdd/vaults/web"
  mkdir -p "$F/src" "$V/units"
  printf 'lane: lite\n' > "$F/.mega-sdd/config.yaml"
  printf 'a1\na2\n' > "$F/src/a.ts"
  printf 'b1\nfunction beta() {\n  return 1\n}\nb5\n' > "$F/src/b.ts"
  printf 'c1\nc2\n' > "$F/src/c.ts"
  cat > "$V/units/U-001.md" <<'U'
---
id: U-001
title: t
target_files:
  - path: src/a.ts
    operation: modify
  - path: src/New.ts
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: "ok"
---
## Anchors
- `src/b.ts:2-3` — the `beta` function
- `src/c.ts:1` — c header
U
  ( cd "$F" && git init -q -b main . && G add -A && G commit -qm seed )
}
V_OF() { printf '%s/.mega-sdd/vaults/web' "$1"; }
bind() { # <dir> [writer flags…]
  local F="$1" V; V=$(V_OF "$1"); shift
  bash "$S/derive-unit-claims.sh" --cwd="$F" --vault="$V" --units=U-001 >/dev/null 2>&1
  bash "$S/write-unit-binding.sh" --cwd="$F" --vault="$V" --unit=U-001 --claims="$V/bolts/_wave-claims.json" "$@" >/dev/null 2>&1
}
B() { printf '%s/bolts/U-001/binding.json' "$(V_OF "$1")"; }
BASE="$WORK/base"; mk "$BASE"
fresh() { rm -rf "$WORK/$1"; cp -a "$BASE" "$WORK/$1"; printf '%s' "$WORK/$1"; }

# 1. the honest stamp at HEAD: full hex, head alias, scope, own_targets, dirty, unit_sha256
D=$(fresh a); bind "$D"; H=$(git -C "$D" rev-parse HEAD)
[ "$(J "$(B "$D")" 'd["based_on_sha"]')" = "$H" ] && [ "$(J "$(B "$D")" 'd["head"]')" = "${H:0:8}" ] \
  && [ "$(J "$(B "$D")" 'sorted(d["own_targets"])')" = "['src/New.ts', 'src/a.ts']" ] \
  && [ "$(J "$(B "$D")" 'd["dirty"]')" = "{}" ] \
  && [ "$(J "$(B "$D")" 'd["unit_sha256"]')" = "$(shasum -a 256 "$(V_OF "$D")/units/U-001.md" | cut -c1-64)" ] \
  && ok "honest stamp: based_on_sha = HEAD, head = its prefix, own_targets, dirty {}, unit_sha256" || bad "stamp: $(cat "$(B "$D")" | head -c 400)"
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["absent_at"]')" = "$H" ] && ok "create target absent → absent_at = HEAD" || bad "absent_at"

# 2. writer_capture_moved: dirt appears between the capture and the write
D=$(fresh b); V=$(V_OF "$D")
bash "$S/derive-unit-claims.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
echo 'b6' >> "$D/src/b.ts"
bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --claims="$V/bolts/_wave-claims.json" >/dev/null 2>&1
[ "$(J "$(B "$D")" 'd["based_on_sha"]')" = "None" ] && [ "$(J "$(B "$D")" 'd.get("null_cause")')" = "writer_capture_moved" ] && [ "$(J "$(B "$D")" 'd["head"]')" = "None" ] \
  && ok "dirt between capture and write: stamp null (writer_capture_moved), head alias null" || bad "capture moved: $(J "$(B "$D")" 'd.get("null_cause")')"

# 3. evidence_off_line: an E3 pass whose capture predates an in-scope commit
D=$(fresh c); V=$(V_OF "$D")
printf '\n## Claims\n- C-U001-01 "beta returns one" — expect: beta returns a constant\n' >> "$V/units/U-001.md"
( cd "$D" && G add -A && G commit -qm claims ); bind "$D"
( cd "$D" && echo 'c3' >> src/c.ts && G commit -qam "feat: c3" )
printf '{"C-U001-01":{"verdict":"CONFIRMED","anchor":"src/b.ts:3","confidence":"high","evidence":"read"}}\n' > "$WORK/v.json"
bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --claims="$V/bolts/_wave-claims.json" --verdicts="$WORK/v.json" >/dev/null 2>&1
[ "$(J "$(B "$D")" 'd.get("null_cause")')" = "evidence_off_line" ] && ok "E3 evidence from a capture before an in-scope commit: null evidence_off_line" || bad "off_line: $(J "$(B "$D")" 'd.get("null_cause")')"

# 4. a git error while a .git exists REFUSES (exit 3, nothing written)
D=$(fresh d); V=$(V_OF "$D"); bash "$S/derive-unit-claims.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
SH="$WORK/gfail"; mkdir -p "$SH"; RG=$(command -v git)
printf '#!/bin/bash\ncase "$*" in *ls-files*) echo "fatal: index file corrupt" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$RG" > "$SH/git"; chmod +x "$SH/git"
PATH="$SH:$PATH" bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --claims="$V/bolts/_wave-claims.json" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 3 ] && [ ! -f "$(B "$D")" ] && ok "git failure during the dirty map: REFUSE exit 3, no binding written" || bad "git refuse rc=$rc"

# 5. claim-set integrity: the unit's claims changed after the capture → refuse
D=$(fresh e); V=$(V_OF "$D"); bash "$S/derive-unit-claims.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
sed -i.bak 's#src/c.ts:1#src/c.ts:2#' "$V/units/U-001.md"; rm -f "$V/units/U-001.md.bak"
bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --claims="$V/bolts/_wave-claims.json" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 3 ] && ok "claims drifted since the capture: REFUSE (exit 3)" || bad "integrity rc=$rc"

# 6. ladder: rung 1 identical, rung 2a moved verbatim (prior content_sha), rung 4 label, rung 5 drift
D=$(fresh f); bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A03"]["verdict"]')" = "CONFIRMED" ] && ok "rung 1: block identical → CONFIRMED" || bad "rung1"
( cd "$D" && printf 'x0\n' | cat - src/b.ts > src/b.tmp && mv src/b.tmp src/b.ts && G commit -qam "feat: shift b" )
bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A03"]["repair"]["rule"]')" = "R1-shift" ] && grep -q 'src/b.ts:3-4' "$(V_OF "$D")/units/U-001.md" \
  && ok "rung 2: the bound block moved verbatim → R1-shift repair, ## Anchors rewritten" || bad "rung2: $(J "$(B "$D")" 'c["C-U001-A03"]')"
D=$(fresh g); bind "$D"
( cd "$D" && sed -i.bak 's/return 1/return 2/' src/b.ts && rm -f src/b.ts.bak && G commit -qam "feat: beta 2" ); bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A03"]["verdict"]')" = "CONFIRMED" ] && [ "$(J "$(B "$D")" 'bool(c["C-U001-A03"].get("anchor_changed"))')" = "True" ] \
  && ok "rung 4: block changed, label \`beta\` still in range → CONFIRMED + anchor_changed" || bad "rung4: $(J "$(B "$D")" 'c["C-U001-A03"]')"
bind "$D"
[ "$(J "$(B "$D")" 'bool(c["C-U001-A03"].get("anchor_changed"))')" = "True" ] && ok "rung 4 mark persists on the next re-bind (reference kept)" || bad "rung4 persist"
D=$(fresh h); bind "$D"
( cd "$D" && printf 'CHANGED\nc2\n' > src/c.ts && G commit -qam "feat: rewrite c" ); bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A04"]["verdict"]')" = "CONFLICT" ] && J "$(B "$D")" 'c["C-U001-A04"]["evidence"]' | grep -q anchor_content_drift \
  && ok "rung 5: block rewritten by someone else, no label → CONFLICT anchor_content_drift" || bad "rung5: $(J "$(B "$D")" 'c["C-U001-A04"]')"

# 7. rung 3: the block changed only through the unit's own commits (vetted prior as the base)
D=$(fresh i); bind "$D"
( cd "$D" && printf 'C1-own\nc2\n' > src/c.ts && echo a3 >> src/a.ts && G add -A && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): own edit") )
sed -i.bak 's#  - path: src/a.ts#  - path: src/c.ts\n    operation: modify\n  - path: src/a.ts#' "$(V_OF "$D")/units/U-001.md"; rm -f "$(V_OF "$D")/units/U-001.md.bak"
( cd "$D" && G add -A && G commit -qm "docs: c is a target" ); bind "$D"
[ "$(J "$(B "$D")" '[x for x in d["claims"] if x["expect"].startswith("src/c.ts:")][0]["state"]')" = "IMPLEMENTED_BY_UNIT" ] \
  && ok "rung 3: anchored block changed only by own commits → CONFIRMED IMPLEMENTED_BY_UNIT" || bad "rung3: $(J "$(B "$D")" '[x for x in d["claims"] if x["expect"].startswith("src/c.ts:")]')"

# 8. content_sha shapes: a directory → null, a whole file → file sha, an unanchored claim → key present, null
D=$(fresh j); V=$(V_OF "$D"); mkdir -p "$D/src/cfg"; echo k > "$D/src/cfg/i.ts"
printf '\n## Claims\n- C-U001-01 "cfg dir" — expect: src/cfg — must-exist\n- C-U001-02 "whole a" — expect: src/a.ts — must-exist\n- C-U001-03 "prose" — expect: something prose\n' >> "$V/units/U-001.md"
( cd "$D" && G add -A && G commit -qm c ); bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-01"]["content_sha"]')" = "None" ] && [ "$(J "$(B "$D")" 'c["C-U001-02"]["content_sha"]')" = "$(shasum -a 256 "$D/src/a.ts" | cut -c1-64)" ] \
  && [ "$(J "$(B "$D")" '"content_sha" in c["C-U001-03"] and c["C-U001-03"]["content_sha"] is None')" = "True" ] \
  && ok "content_sha: directory → null, whole file → file sha, unanchored → key present, null" || bad "content_sha shapes"
[ "$(J "$(B "$D")" 'd["dirty"]')" = "{}" ] && ok "a clean directory claim path is not dirt (field U-005 shape)" || bad "dir dirt"

# 9. human-resolution carry-forward: kept when nothing moved, reopened when its evidence changed
D=$(fresh k); V=$(V_OF "$D"); echo 'exists' > "$D/src/New.ts"; ( cd "$D" && G add -A && G commit -qm "teammate made New" ); bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["verdict"]')" = "CONFLICT" ] || bad "fixture: pre-existing create target should CONFLICT"
bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --resolve=C-U001-A02=KEEP_CODE --by=user >/dev/null 2>&1
bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["resolution"]["action"]')" = "KEEP_CODE" ] && ok "resolution carried forward across a re-bind when nothing moved" || bad "carry: $(J "$(B "$D")" 'c["C-U001-A02"]')"
( cd "$D" && echo more >> src/New.ts && G commit -qam "feat: New changed" ); bind "$D"
[ "$(J "$(B "$D")" '"resolution" not in c["C-U001-A02"] and c["C-U001-A02"]["prior_resolution"]["action"]')" = "KEEP_CODE" ] \
  && ok "resolution reopened (prior_resolution kept) once its evidence path changed" || bad "reopen: $(J "$(B "$D")" 'c["C-U001-A02"]')"

# 10. IMPLEMENTED_BY_UNIT: created by its own commit; stays so across two re-binds; teammate-made stays CONFLICT
D=$(fresh l); bind "$D"
( cd "$D" && echo new > src/New.ts && G add -A && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): New") ); bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["state"]')" = "IMPLEMENTED_BY_UNIT" ] && ok "create target made by its own bolt commit → IMPLEMENTED_BY_UNIT" || bad "ibu: $(J "$(B "$D")" 'c["C-U001-A02"]')"
( cd "$D" && echo r >> README.md 2>/dev/null; echo r > README.md; G add -A && G commit -qm r ); bind "$D"; bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["state"]')" = "IMPLEMENTED_BY_UNIT" ] && ok "…and stays so across two further re-binds (inductive absent_at)" || bad "ibu inductive"
D=$(fresh m); bind "$D"; echo new > "$D/src/New.ts"; bind "$D"
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["verdict"]')" = "CONFLICT" ] && ok "an untracked-only create target → CONFLICT" || bad "untracked create"

# 11. a legacy unit-binding/1 prior (D21 upgrade): the short-8 head is the absent_at base
D=$(fresh n); V=$(V_OF "$D"); H0=$(git -C "$D" rev-parse HEAD)
mkdir -p "$V/bolts/U-001"
printf '{"schema":"unit-binding/1","head":"%s","unit":"U-001","claims":[{"id":"C-U001-A02","kind":"fs_must_not_exist","expect":"src/New.ts","verdict":"CONFIRMED","state":"NEW"}]}\n' "${H0:0:8}" > "$V/bolts/U-001/binding.json"
( cd "$D" && echo new > src/New.ts && G add -A && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): New") )
bash "$S/rebind-units.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
[ "$(J "$(B "$D")" 'c["C-U001-A02"]["state"]')" = "IMPLEMENTED_BY_UNIT" ] && [ "$(J "$(B "$D")" 'len(c["C-U001-A02"]["absent_at"])')" = "40" ] \
  && ok "legacy /1 prior → 3.9b: own-created target is IMPLEMENTED_BY_UNIT with a 40-hex absent_at" || bad "legacy: $(J "$(B "$D")" 'c["C-U001-A02"]')"
[ "$(J "$(B "$D")" 'd["rebind_head"]')" = "$(git -C "$D" rev-parse HEAD)" ] && ok "a 3.9b (--units) records rebind_head" || bad "rebind_head"

# 12. the index rule: a stale index with ast-grep present nulls (index_stale); `sg` alone is not ast-grep
D=$(fresh o); V=$(V_OF "$D")
cat > "$V/units/U-001.md" <<'U'
---
id: U-001
title: t
target_files:
  - path: src/a.ts
    operation: modify
existing_interfaces:
  - file: src/b.ts
    symbol: beta
acceptance_test:
  - type: test
    command: x
    expects: "ok"
---
U
( cd "$D" && G add -A && G commit -qm iface )
printf '{"generated_by":"t","head_commit":"%s","symbols":[{"name":"beta","file":"src/b.ts","line":2}],"dirty":{},"files":["src/b.ts"]}\n' "$(git -C "$D" rev-parse HEAD~1)" > "$WORK/idx.json"
mkdir -p "$D/.mega-sdd/codebase"; cp "$WORK/idx.json" "$D/.mega-sdd/codebase/symbol-index.json"
NOAG="$WORK/noag"; mkdir -p "$NOAG"; for tl in git python3 bash dirname sed cat; do ln -sf "$(command -v $tl)" "$NOAG/$tl"; done
printf '#!/bin/sh\nexit 1\n' > "$NOAG/sg"; chmod +x "$NOAG/sg"
( export PATH="$NOAG"; bind "$D" )
[ "$(J "$(B "$D")" 'd.get("null_cause")')" = "None" ] && [ "$(J "$(B "$D")" '[x for x in d["claims"] if x["kind"]=="symbol"][0]["verdict"]')" = "OQ" ] \
  && ok "no ast-grep (a shadow-utils \`sg\` on PATH): the stale index is treated as absent → OQ, stamp honest" || bad "no-astgrep: $(J "$(B "$D")" 'd.get("null_cause")')"
if command -v ast-grep >/dev/null 2>&1; then
  cp "$WORK/idx.json" "$D/.mega-sdd/codebase/symbol-index.json"; bind "$D"
  [ "$(J "$(B "$D")" 'd.get("null_cause")')" = "index_stale" ] && ok "ast-grep present + index from another HEAD: null index_stale" || bad "index_stale: $(J "$(B "$D")" 'd.get("null_cause")')"
  bash "$S/rebind-units.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
  [ "$(J "$(B "$D")" 'd["index_head"]')" = "$(git -C "$D" rev-parse HEAD)" ] && [ "$(J "$(B "$D")" 'd.get("null_cause")')" = "None" ] \
    && ok "3.9b rebuilds the stale index first → honest stamp" || bad "3.9b index: $(J "$(B "$D")" 'd.get("null_cause")')"
else
  ok "ast-grep not installed here: the index_stale / 3.9b rebuild arm is skipped (CI covers it where ast-grep exists)"
fi

[ "$fail" -eq 0 ] && { echo "PASS state-anchor writer stamp"; exit 0; }
echo "state-anchor writer stamp FAILED"; exit 1

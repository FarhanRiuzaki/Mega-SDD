#!/usr/bin/env bash
# test-p2-ground-express-default.sh — v6 P2 proof suite (spec
# 2026-08-03-v6-express-spine-design.md §P2.7):
#
#   1. Chain renders: express DEFAULT (no scan hop, --express on bind) per
#      position; `spine: classic` restores the scan-first rows verbatim.
#   2. probe_framework_pack: precedence (starterkit variant > base, meta >
#      substrate), *.csproj glob, manifest alternates, _universal fallback;
#      resolver reads the matcher's state.json output (one sniff, one grammar).
#   3. Sync on express-born projects: index-stale change signal fires, Mode D
#      proposes the derive-changed-paths chain, and the script derives the
#      changed set from git diff ∪ dirty journal.
#   4. Resurrect-vector pins: preflight express carve-out wiring, chain-
#      optimization short-circuit, units Step 0.5, intent map-less default,
#      oq_gate probe-keyed resolution.
#   5. validate-pack detection_priority lint; ground.sh wrapper honesty.
#
# CI-safe: bash + python3 + git only (no ast-grep; index fixtures hand-written).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/plugins/mega-sdd"
LIB="$P/scripts/_lib"

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

py_probe() {  # $1=cwd  $2=python expr over `d` (the collect_state payload)
  CWD="$1" EXPR="$2" LIB="$LIB" python3 - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["LIB"])
import state_probes
d = state_probes.collect_state(os.environ["CWD"])
print(eval(os.environ["EXPR"]))
PY
}

# ══ 1. Chain renders — express default vs classic ════════════════════════════
PROJ="$WORK/p1"; mkdir -p "$PROJ/.mega-sdd/codebase"
( cd "$PROJ" && git init -q . )
printf '{"require": {"laravel/framework": "^11.0"}}' > "$PROJ/composer.json"
printf '# PRD\nfitur cuti\n' > "$PROJ/prd.md"
# host-independent viability: an index file makes express viable whether or
# not the runner has ast-grep (CI has none — the viability fallback would
# otherwise flip these arms to classic)
printf '{"generated_by":"build-symbol-index.sh","head_commit":"abc","symbols":[]}' \
  > "$PROJ/.mega-sdd/codebase/symbol-index.json"

CHAIN=$(py_probe "$PROJ" "d['derived']['proposed_next']")
echo "$CHAIN" | grep -q "scan-codebase" \
  && fail "express prd_no_vault chain still carries scan: $CHAIN" \
  || pass "express default: prd_no_vault chain has NO scan hop"
echo "$CHAIN" | grep -q -- "--scan=" \
  && fail "express chain carries --scan=: $CHAIN" \
  || pass "express default: no --scan= argument (no producer exists)"
echo "$CHAIN" | grep -q "bind-codebase --express" \
  && pass "express default: bind hop carries --express (finish() injection)" \
  || fail "bind hop missing --express: $CHAIN"
POS=$(py_probe "$PROJ" "d['derived']['position']")
[ "$POS" = "prd_no_vault" ] && pass "position prd_no_vault unchanged" \
  || fail "position drifted: $POS"

printf 'spine: classic\n' > "$PROJ/.mega-sdd/config.yaml"
CHAIN_C=$(py_probe "$PROJ" "d['derived']['proposed_next']")
echo "$CHAIN_C" | grep -q "scan-codebase" \
  && pass "classic spine restores the scan-first chain" \
  || fail "classic chain lost scan: $CHAIN_C"
echo "$CHAIN_C" | grep -q -- "--express" \
  && fail "classic chain carries --express: $CHAIN_C" \
  || pass "classic chain carries no --express"
SPINE=$(py_probe "$PROJ" "d['derived']['spine']")
[ "$SPINE" = "classic" ] && pass "derived.spine reads the config key" \
  || fail "derived.spine=$SPINE"
rm -f "$PROJ/.mega-sdd/config.yaml"

# ══ 2. The pack matcher ══════════════════════════════════════════════════════
M1="$WORK/m1"; mkdir -p "$M1"
printf '{"require": {"laravel/framework": "^11.0", "pixinvent/vuexy-laravel-bootstrap-jetstream": "^1.0"}}' > "$M1/composer.json"
printf '{"dependencies": {"@remix-run/react": "^2.0", "express": "^4.0"}}' > "$M1/package.json"
GOT=$(py_probe "$M1" "d['probes']['framework_pack']['pack']")
[ "$GOT" = "laravel-base-26" ] \
  && pass "matcher precedence: starterkit variant (p10) beats laravel/remix/express" \
  || fail "matcher picked $GOT (want laravel-base-26)"

M2="$WORK/m2"; mkdir -p "$M2"
printf '{"dependencies": {"@remix-run/react": "^2.0", "express": "^4.0"}}' > "$M2/package.json"
GOT=$(py_probe "$M2" "d['probes']['framework_pack']['pack']")
[ "$GOT" = "remix" ] \
  && pass "matcher precedence: meta-framework (remix p50) beats express (p100)" \
  || fail "matcher picked $GOT (want remix)"

M3="$WORK/m3"; mkdir -p "$M3"
printf '<Project Sdk="Microsoft.NET.Sdk.Web"><ItemGroup><PackageReference Include="Microsoft.AspNetCore.OpenApi" /></ItemGroup></Project>' > "$M3/App.csproj"
GOT=$(py_probe "$M3" "d['probes']['framework_pack']['pack'] + '|' + str(d['probes']['manifests'])")
echo "$GOT" | grep -q "aspnetcore|.*App.csproj" \
  && pass "glob manifest: *.csproj detected + aspnetcore beats dotnet" \
  || fail "csproj arm: $GOT"

M4="$WORK/m4"; mkdir -p "$M4"
printf 'django>=4.2\n' > "$M4/requirements.txt"
GOT=$(py_probe "$M4" "d['probes']['framework_pack']['pack']")
[ "$GOT" = "django" ] \
  && pass "manifest alternate: django matched via requirements.txt (canonical pyproject absent)" \
  || fail "alternate arm picked $GOT"

M5="$WORK/m5"; mkdir -p "$M5"
printf 'x = 1\n' > "$M5/main.py"
GOT=$(py_probe "$M5" "d['probes']['framework_pack']['pack']")
[ "$GOT" = "_universal" ] \
  && pass "no manifest -> _universal fallback (same as scan Step 8.5)" \
  || fail "fallback arm picked $GOT"

# resolver parity: state.json is a resolver source (one matcher, one grammar)
RP="$WORK/rp"; mkdir -p "$RP/.mega-sdd"
printf '{"require": {"laravel/framework": "^11.0"}}' > "$RP/composer.json"
bash "$P/scripts/derive-state.sh" --cwd="$RP" >/dev/null 2>&1
RES=$(bash "$LIB/resolve-framework-pack.sh" --cwd="$RP" 2>&1)
echo "$RES" | grep -q "state.json derived.framework_pack" \
  && echo "$RES" | grep -q "laravel.md" \
  && pass "resolver source: state.json GROUND matcher feeds the pack chain" \
  || fail "resolver did not consume state.json: ${RES:0:120}"
rtk_head=$(head -1 "$RP/.mega-sdd/.cache/pack-resolver/_chain.out" 2>/dev/null || echo "")
echo "$rtk_head" | grep -q "packres-v2 .* st=1" \
  && pass "pack-resolver cache bumped to v2 with the state input flag" \
  || fail "cache meta not v2/st: $rtk_head"

# ══ 3. Sync on an express-born project ═══════════════════════════════════════
SY="$WORK/sync"; mkdir -p "$SY/.mega-sdd/codebase" "$SY/.mega-sdd/vaults/demo"
cp "$P/tests/graph/fixtures/derive-vault"/0*.md "$SY/.mega-sdd/vaults/demo/"
# neutralize the fixture's open P0/P1 OQs — this arm tests Mode D, and the
# oq_gate position deliberately outranks sync
python3 - "$SY/.mega-sdd/vaults/demo" <<'PY'
import glob, sys
for f in glob.glob(sys.argv[1] + "/0*.md"):
    s = open(f, encoding="utf-8").read()
    open(f, "w", encoding="utf-8").write(s.replace("- [ ] **OQ-", "- [x] **OQ-"))
PY
python3 - "$P/tests/graph/fixtures/derive-vault/expected-vault.json" "$SY/.mega-sdd/vaults/demo/vault.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for oq in d.get("open_questions") or []:
    oq["status"] = "resolved"
d["open_questions_summary"] = {}
json.dump(d, open(sys.argv[2], "w"), indent=2)
PY
( cd "$SY" && git init -q . && git config user.email t@t && git config user.name t \
  && printf 'a\n' > app.py && git add app.py && git commit -qm one )
OLD_HEAD=$(git -C "$SY" rev-parse HEAD)
printf '{"generated_by":"build-symbol-index.sh","head_commit":"%s","symbols":[]}' "$OLD_HEAD" \
  > "$SY/.mega-sdd/codebase/symbol-index.json"
# binding present (Mode D requires it) — minimal grammar-valid binding
cat > "$SY/.mega-sdd/vaults/demo/binding.md" <<'EOF'
---
vault: demo
binding_metadata:
  codebase_map_provenance: no-snapshot
  head: abc
  retrieval: express-index@abc
---
# Binding Manifest
## Implementation State Map (0 — ALWAYS 6 columns)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
## Conflicts (0) — BLOCKING
EOF
# move HEAD past the index stamp
( cd "$SY" && printf 'b\n' >> app.py && git add app.py && git commit -qm two )

SIG=$(py_probe "$SY" "d['derived']['change_signal']['index_stamp_matches_head']")
[ "$SIG" = "no" ] && pass "express-born change signal: index stamp != HEAD detected" \
  || fail "index change signal: $SIG"
POS=$(py_probe "$SY" "d['derived']['position']")
[ "$POS" = "maintenance_sync" ] \
  && pass "express-born Mode D reachable (no map, index substrate)" \
  || fail "express-born sync position: $POS"
CHAIN=$(py_probe "$SY" "d['derived']['proposed_next']")
echo "$CHAIN" | grep -q "derive-changed-paths.sh" \
  && echo "$CHAIN" | grep -q "bind-codebase --paths=.*--express" \
  && pass "express-born Mode D chain: script changed-set producer + bind --paths --express" \
  || fail "express-born sync chain: $CHAIN"

# the changed-set producer itself
printf '{"ts":"t","path":"lib/extra.py","tool":"write","session":"s"}\n' \
  > "$SY/.mega-sdd/codebase/.dirty-paths.jsonl"
bash "$P/scripts/derive-changed-paths.sh" --cwd="$SY" --vault "$SY/.mega-sdd/vaults/demo" >/dev/null 2>&1
RC=$?
[ "$RC" -eq 0 ] && [ -f "$SY/.mega-sdd/vaults/demo/.sync-changed-paths.txt" ] \
  && grep -q "app.py" "$SY/.mega-sdd/vaults/demo/.sync-changed-paths.txt" \
  && grep -q "lib/extra.py" "$SY/.mega-sdd/vaults/demo/.sync-changed-paths.txt" \
  && pass "derive-changed-paths: git diff ∪ journal -> .sync-changed-paths.txt" \
  || fail "derive-changed-paths rc=$RC or content wrong"
ls "$SY/.mega-sdd/codebase/".dirty-paths.consumed-* >/dev/null 2>&1 \
  && pass "journal rotated to .consumed-<ts> (never truncated)" \
  || fail "journal not rotated"
# no stamp -> honest exit 3
rm "$SY/.mega-sdd/codebase/symbol-index.json"
bash "$P/scripts/derive-changed-paths.sh" --cwd="$SY" --vault "$SY/.mega-sdd/vaults/demo" >/dev/null 2>&1
[ $? -eq 3 ] && pass "no index stamp -> exit 3 (full re-bind fallback, never a guess)" \
  || fail "stamp-less derive-changed-paths did not exit 3"

# ══ 4. Resurrect-vector pins ═════════════════════════════════════════════════
grep -qF -- '--args-b64="${SKILL_ARGS_B64:-}"' "$P/hooks/pre-tool-use" \
  && pass "pre-tool-use forwards dispatch args to validate-preflight" \
  || fail "hook args forwarding missing"
grep -qF 'elif not express and not has_codebase_map():' "$P/scripts/validate-preflight.sh" \
  && pass "validate-preflight map arm is express-aware (vault arm stays FATAL)" \
  || fail "preflight carve-out missing"
CE="$P/skills/orchestrate-flow/references/chain-execution.md"
grep -qF 'Express-lane short-circuit' "$CE" \
  && pass "chain-optimization no-snapshot branch cannot resurrect scan on express" \
  || fail "chain-execution short-circuit missing"
grep -qF 'Express-lane rule (P2)' "$P/skills/generate-units/SKILL.md" \
  && pass "generate-units Step 0.5 cannot auto-resurrect scan on express projects" \
  || fail "units Step 0.5 express rule missing"
SF="$P/skills/generate-intent/references/setup-flow.md"
grep -qF 'DEFAULT (express spine, P2): proceed map-less' "$SF" \
  && pass "intent brownfield default is map-less (prompt demoted to classic)" \
  || fail "intent map-less default missing"
grep -qF 'keeps the express path non-stop' "$SF" \
  && pass "oq_gate trap: classifier resolves tech/scan OQs from probes" \
  || fail "oq_gate classifier re-key missing"
grep -qF 'symbol-index LeaveRequest' "$P/skills/generate-intent/references/vault-core.md" \
  && pass "vault-core scan_query re-keyed to probe targets" \
  || fail "scan_query re-key missing"
grep -qF 'the lane the express spine dispatches by default' "$P/skills/bind-codebase/references/express-bind.md" \
  && grep -qF 'Lane default:' "$P/skills/bind-codebase/SKILL.md" \
  && pass "express-bind.md states the spine-dispatch default (+ SKILL lane-default sentence)" \
  || fail "express-bind default note missing"

# ══ 4b. Round-folded arms (P2 dual-blind) ════════════════════════════════════
# F1 — ground.sh must NOT clobber the sync baseline: with a sync pending, the
# index rebuild is DEFERRED so derive-changed-paths keeps its diff baseline.
printf '{"generated_by":"build-symbol-index.sh","head_commit":"%s","symbols":[]}' "$OLD_HEAD" \
  > "$SY/.mega-sdd/codebase/symbol-index.json"
rm -f "$SY/.mega-sdd/vaults/demo/.sync-changed-paths.txt"
bash "$P/scripts/ground.sh" --cwd="$SY" 2>&1 | grep -q "rebuild DEFERRED" \
  && pass "F1: ground.sh defers the index rebuild while a sync is pending" \
  || fail "F1: ground.sh did not defer"
STAMP_AFTER=$(python3 -c "import re;print(re.search(r'\"head_commit\"\s*:\s*\"([0-9a-f]+)\"',open('$SY/.mega-sdd/codebase/symbol-index.json').read()).group(1))")
[ "$STAMP_AFTER" = "$OLD_HEAD" ] \
  && pass "F1: the baseline stamp survived GROUND" \
  || fail "F1: stamp advanced to $STAMP_AFTER"
bash "$P/scripts/derive-changed-paths.sh" --cwd="$SY" --vault "$SY/.mega-sdd/vaults/demo" >/dev/null 2>&1
grep -q "app.py" "$SY/.mega-sdd/vaults/demo/.sync-changed-paths.txt" 2>/dev/null \
  && pass "F1: post-GROUND changed set is NON-empty (false-in-sync closed)" \
  || fail "F1: changed set empty after ground"

# F6 — a failed output write must NOT consume the journal
printf '{"ts":"t","path":"lib/precious.py","tool":"write","session":"s"}\n' \
  > "$SY/.mega-sdd/codebase/.dirty-paths.jsonl"
RO="$SY/.mega-sdd/vaults/rovault"; mkdir -p "$RO"; chmod 555 "$RO"
bash "$P/scripts/derive-changed-paths.sh" --cwd="$SY" --vault "$RO" >/dev/null 2>&1
RC=$?
chmod 755 "$RO"
[ "$RC" -eq 3 ] && [ -f "$SY/.mega-sdd/codebase/.dirty-paths.jsonl" ] \
  && pass "F6: failed write -> exit 3, journal NOT consumed" \
  || fail "F6: rc=$RC journal_present=$([ -f "$SY/.mega-sdd/codebase/.dirty-paths.jsonl" ] && echo yes || echo no)"

# F2 — marker word-boundary: i18next / next-themes must NOT route to next
MB="$WORK/mb"; mkdir -p "$MB"
printf '{"dependencies": {"i18next": "^23.0", "next-themes": "^0.3", "react": "^18.0"}}' > "$MB/package.json"
GOT=$(py_probe "$MB" "d['probes']['framework_pack']['pack']")
[ "$GOT" != "next" ] \
  && pass "F2: i18next/next-themes do NOT match the bare 'next' marker (got $GOT)" \
  || fail "F2: substring misroute to next survives"
MB2="$WORK/mb2"; mkdir -p "$MB2"
printf '{"dependencies": {"next": "^14.0", "react": "^18.0"}}' > "$MB2/package.json"
GOT=$(py_probe "$MB2" "d['probes']['framework_pack']['pack']")
[ "$GOT" = "next" ] \
  && pass "F2: a REAL next dependency still routes to next (boundary keeps true positives)" \
  || fail "F2: true positive lost: $GOT"

# F7 — tool-config-only pyproject + deps in requirements.txt
F7="$WORK/f7"; mkdir -p "$F7"
printf '[tool.black]\nline-length = 88\n' > "$F7/pyproject.toml"
printf 'django>=4.2\n' > "$F7/requirements.txt"
GOT=$(py_probe "$F7" "d['probes']['framework_pack']['pack']")
[ "$GOT" = "django" ] \
  && pass "F7: alternates fire even when the canonical manifest exists markerless" \
  || fail "F7: picked $GOT"

# F4 — classic parity: fresh map + stale index must NOT trigger Mode D
F4="$WORK/f4"; mkdir -p "$F4/.mega-sdd/codebase"
( cd "$F4" && git init -q . && git config user.email t@t && git config user.name t \
  && printf 'x\n' > a.py && git add a.py && git commit -qm one )
H=$(git -C "$F4" rev-parse HEAD)
printf -- '---\nlast_scanned_commit: %s\n---\n# map\n' "$H" > "$F4/.mega-sdd/codebase/codebase-map.md"
printf '{"generated_by":"build-symbol-index.sh","head_commit":"0000000000000000000000000000000000000000","symbols":[]}' \
  > "$F4/.mega-sdd/codebase/symbol-index.json"
SIG=$(py_probe "$F4" "d['derived']['change_signal']['index_stamp_matches_head']")
[ "$SIG" = "n/a" ] \
  && pass "F4: index leg is n/a on a map-bearing project (substrate rule — no livelock)" \
  || fail "F4: index leg fired beside a fresh map: $SIG"

# doc-6 — express unviable (no index, no ast-grep) -> classic render, loudly
UV="$WORK/uv"; mkdir -p "$UV"
( cd "$UV" && git init -q . )
printf '{"require": {"laravel/framework": "^11.0"}}' > "$UV/composer.json"
printf '# PRD\n' > "$UV/prd.md"
UV_OUT=$(CWD="$UV" LIB="$LIB" python3 - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["LIB"])
import state_probes
state_probes._ASTGREP_CACHE = False  # simulate ast-grep absent
d = state_probes.collect_state(os.environ["CWD"])
print(json.dumps({"chain": d["derived"]["proposed_next"],
                  "notes": d["derived"]["notes"]}))
PY
)
echo "$UV_OUT" | grep -q "scan-codebase" \
  && echo "$UV_OUT" | grep -q "express unavailable" \
  && pass "doc-6: no index + no ast-grep -> CLASSIC chain + loud note (no dead-end)" \
  || fail "doc-6: unviable-express render: $UV_OUT"

# F3 — session-start staleness fires on an express-born project (index, no map)
SS_OUT=$(STATE="$SY/.mega-sdd/state.json" python3 - <<'PY'
import json, os
s = json.load(open(os.environ["STATE"]))
p = s["probes"]
dirty = p.get("dirty_journal_rows", 0)
cmap = p.get("codebase_map") or {}
stamp = cmap.get("last_scanned_commit")
head = (p.get("git") or {}).get("head")
sidx = p.get("symbol_index") or {}
istamp = sidx.get("head_commit") if not cmap.get("present") else None
moved = (dirty > 0 or bool(stamp and head and head != stamp)
         or bool(istamp and head and head != istamp))
print("MOVED" if moved else "CLEAN")
PY
)
bash "$P/scripts/derive-state.sh" --cwd="$SY" >/dev/null 2>&1
SS_OUT=$(STATE="$SY/.mega-sdd/state.json" python3 -c "
import json, os
s = json.load(open(os.environ['STATE'])); p = s['probes']
cmap = p.get('codebase_map') or {}
sidx = p.get('symbol_index') or {}
istamp = sidx.get('head_commit') if not cmap.get('present') else None
head = (p.get('git') or {}).get('head')
print('MOVED' if (istamp and head and head != istamp) else 'CLEAN')")
[ "$SS_OUT" = "MOVED" ] \
  && grep -q 'LV_IDX' "$P/hooks/session-start" \
  && grep -qF 'if { [ -f "$LV_MAP" ] || [ -f "$LV_IDX" ]; }' "$P/hooks/session-start" \
  && pass "F3: index substrate opens the staleness gate (dead-code leg revived)" \
  || fail "F3: session-start gate still map-only or signal dead ($SS_OUT)"

# ══ 5. Lint + wrapper ════════════════════════════════════════════════════════
BADPACK="$WORK/badpack.md"
cat > "$BADPACK" <<'EOF'
---
framework: fakefw
framework_version_range: "1.x"
detection_priority: high
detection_signature:
  package_manifest: fake.json
  dependency_marker: "fake"
extends: _universal
---
# Fake
EOF
VP_OUT=$(bash "$P/scripts/validate-pack.sh" "$BADPACK" 2>/dev/null || true)
echo "$VP_OUT" | grep -q "detection_priority present but not a bare integer" \
  && pass "validate-pack lints a malformed detection_priority" \
  || fail "detection_priority lint missing"

G="$WORK/ground"; mkdir -p "$G/.mega-sdd"
( cd "$G" && git init -q . )
printf '{"dependencies": {}}' > "$G/package.json"
OUT=$(bash "$P/scripts/ground.sh" --cwd="$G" 2>&1)
RC=$?
[ "$RC" -eq 0 ] && [ -f "$G/.mega-sdd/state.json" ] && echo "$OUT" | grep -q "GROUND: state rc=0" \
  && pass "ground.sh: state derived + index status reported honestly (rc always 0)" \
  || fail "ground.sh rc=$RC out=${OUT:0:100}"

# ══ verdict ═══════════════════════════════════════════════════════════════════
echo
if [ "$fails" -eq 0 ]; then
  echo "test-p2-ground-express-default: ALL PASS"
  exit 0
else
  echo "test-p2-ground-express-default: $fails FAILURE(S)"
  exit 1
fi

#!/usr/bin/env bash
# test-run-code-gates.sh — tranche 2c (spec 2026-07-30 §2c): the single-call L0
# executor. BEHAVIORAL proofs, not JSON trust:
#   - the blocking short-circuit is proven by a PATH-shim spy (a marker-writing
#     `semgrep`) that must NEVER be spawned when the secret gate blocks — the
#     spec's hard constraint ("strictly less subprocess work on a blocking run")
#     as an executable assertion;
#   - the pack `## Toolchain` override is proven by override commands that RUN
#     (a failing lint_cmd surfaces as a finding);
#   - opt-out parity (--no-code-gates / config code_gates: false) keeps the
#     always-run pair (secrets + dep-existence) running.
# Environment-agnostic: gitleaks/semgrep may be present (macOS dev) or absent
# (CI) — every assertion holds in both worlds because tool-absence handling
# lives INSIDE the gate scripts and surfaces as visible JSON, never divergence.
#
# Run: bash tests/code-gates/test-run-code-gates.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RCG="${ROOT}/plugins/mega-sdd/scripts/run-code-gates.sh"
SK="${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
CG="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/code-gates.md"
SB="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md"
[ -f "$RCG" ] || { echo "missing run-code-gates.sh"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkfix() { # $1=dir — a git repo with a base commit; prints nothing
  local d="$1"
  mkdir -p "$d" && git -C "$d" init -q . \
    && git -C "$d" config user.email t@t && git -C "$d" config user.name t \
    && printf 'x = 1\n' > "$d/app.py" \
    && git -C "$d" add app.py && git -C "$d" commit -qm base
}
jget() { # $1=json-file $2=python-expr over `d`
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(sys.argv[2] and eval(sys.argv[2]))" "$1" "$2" 2>/dev/null
}
jaccount() { # $1=json-file — the gate-accounting invariant: each of the 6 gates
             # in EXACTLY ONE of gates{ran:true} / skips[] / not_run[]
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ORDER = ["format","lint_typecheck","secrets","sast","new_deps","dep_authorization"]
bad = []
for g in ORDER:
    n = 0
    if d["gates"].get(g, {}).get("ran"): n += 1
    if any(s["gate"] == g for s in d["skips"]): n += 1
    if g in d["not_run"]: n += 1
    if n != 1: bad.append("%s appears in %d buckets" % (g, n))
print("ACCOUNT-OK" if not bad else "ACCOUNT-BAD: " + "; ".join(bad))
PY
}

note "== 1. clean run: exit 0, merged JSON, always-run pair ran, skips visible =="
FIX="$WORK/clean"; mkfix "$FIX"
BASE=$(git -C "$FIX" rev-parse HEAD)
printf 'y = 2\n' >> "$FIX/app.py"; git -C "$FIX" add app.py; git -C "$FIX" commit -qm change
HEAD=$(git -C "$FIX" rev-parse HEAD)
OUT="$WORK/clean.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" > "$OUT"; rc=$?
[ "$rc" -eq 0 ] && ok "exit 0 on a clean diff" || fail "clean run exited $rc"
[ "$(jget "$OUT" "d['status']")" = "pass" ] && ok "status: pass" || fail "status not pass"
[ "$(jget "$OUT" "d['gates']['secrets']['ran']")" = "True" ] && ok "secrets gate ran (always-run)" || fail "secrets did not run"
[ "$(jget "$OUT" "d['gates']['new_deps']['ran']")" = "True" ] && ok "new-dep gate ran (always-run)" || fail "new_deps did not run"
[ "$(jget "$OUT" "d['gates']['sast']['ran']")" = "True" ] && ok "SAST gate ran (semgrep-absent is a visible internal skip, not a missing gate)" || fail "sast did not run"
[ "$(jget "$OUT" "len([s for s in d['skips'] if s['gate']=='dep_authorization'])")" = "1" ] && ok "no --unit → gate 6 is a visible SKIP, never silent" || fail "dep_authorization skip not recorded"
[ "$(jget "$OUT" "d['written_by']")" = "run-code-gates.sh" ] && ok "written_by stamped" || fail "written_by missing"

note "== 2. blocking short-circuit: secret halts, later gates NEVER SPAWNED (spy proof) =="
BASE2=$(git -C "$FIX" rev-parse HEAD)
printf 'aws_key = "AKIAZZQQXX43PQRSTUVW"\ntoken = "ghp_16C7e42F292c6912E7710c838347Ae178B4a"\n' > "$FIX/creds.py"
git -C "$FIX" add creds.py; git -C "$FIX" commit -qm leak
HEAD2=$(git -C "$FIX" rev-parse HEAD)
SHIM="$WORK/shim"; mkdir -p "$SHIM"
printf '#!/usr/bin/env bash\ntouch "%s/SEMGREP_SPAWNED"\nexec /usr/bin/true\n' "$SHIM" > "$SHIM/semgrep"
chmod +x "$SHIM/semgrep"
OUT2="$WORK/block.json"
PATH="$SHIM:$PATH" bash "$RCG" --cwd="$FIX" --base="$BASE2" --head="$HEAD2" > "$OUT2"; rc=$?
[ "$rc" -eq 1 ] && ok "exit 1 on a blocking finding" || fail "blocking run exited $rc (want 1)"
[ "$(jget "$OUT2" "d['halt']['type']")" = "secret_in_code" ] && ok "halt.type = secret_in_code (JSON IS the blocker payload)" || fail "halt.type wrong"
[ "$(jget "$OUT2" "'sast' in d['not_run'] and 'new_deps' in d['not_run']")" = "True" ] && ok "not_run[] records the short-circuit tail" || fail "not_run tail missing"
if [ -e "$SHIM/SEMGREP_SPAWNED" ]; then fail "semgrep WAS spawned after the secret block — short-circuit breached (the spec's hard constraint)"; else ok "semgrep never spawned after the block (spy shim untouched — short-circuit is structural)"; fi
[ "$(jget "$OUT2" "d['gates']['secrets']['rc']")" = "1" ] && ok "secret gate rc recorded" || fail "secrets rc missing"
[ "$(jaccount "$OUT2")" = "ACCOUNT-OK" ] && ok "accounting invariant on the no-unit short-circuit (gate 6 skip prerecorded, never dropped)" || fail "accounting: $(jaccount "$OUT2")"
[ "$(jaccount "$OUT")" = "ACCOUNT-OK" ] && ok "accounting invariant on the clean run" || fail "accounting clean: $(jaccount "$OUT")"

note "== 2b. blocking at SAST (ERROR shim): not_run tail + accounting =="
SHIM2="$WORK/shim2"; mkdir -p "$SHIM2"
cat > "$SHIM2/semgrep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"results":[{"check_id":"fixture.err","path":"app.py","start":{"line":1},"extra":{"severity":"ERROR","message":"fixture ERROR finding"}}],"errors":[]}'
exit 0
EOF
chmod +x "$SHIM2/semgrep"
OUT2B="$WORK/sastblock.json"
PATH="$SHIM2:$PATH" bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" > "$OUT2B"; rc=$?
[ "$rc" -eq 1 ] && [ "$(jget "$OUT2B" "d['halt']['type']")" = "sast_critical_finding" ] \
  && ok "ERROR-severity SAST blocks (exit 1, halt sast_critical_finding)" || fail "SAST block path broken (rc=$rc)"
[ "$(jget "$OUT2B" "d['not_run']")" = "['new_deps']" ] && ok "not_run after a SAST block = ['new_deps'] (gate 6 skip prerecorded)" || fail "SAST-block not_run wrong: $(jget "$OUT2B" "d['not_run']")"
[ "$(jaccount "$OUT2B")" = "ACCOUNT-OK" ] && ok "accounting invariant on the SAST block" || fail "accounting: $(jaccount "$OUT2B")"
[ "$(jget "$OUT2B" "d['gates']['secrets']['ran']")" = "True" ] && ok "earlier gate results present on a mid-sequence block" || fail "secrets result lost on SAST block"

note "== 2c. unknown gate rc is NEVER pass (the WindowsApps stub environment) =="
REAL_PY="$(command -v python3)"
STUBROOT="$WORK/stubenv"; mkdir -p "$STUBROOT/WindowsApps" "$STUBROOT/bin"
printf '#!/usr/bin/env bash\nexit 49\n' > "$STUBROOT/WindowsApps/python3"
printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$REAL_PY" > "$STUBROOT/bin/python"
chmod +x "$STUBROOT/WindowsApps/python3" "$STUBROOT/bin/python"
OUT2C="$WORK/stub.json"
PATH="$STUBROOT/WindowsApps:$STUBROOT/bin:/usr/bin:/bin" bash "$RCG" --cwd="$FIX" --base="$BASE2" --head="$HEAD2" > "$OUT2C" 2>"$WORK/stub.err"; rc=$?
if [ "$rc" -eq 0 ]; then
  fail "CRITICAL regression: gate scripts' python3 is a broken stub (exit 49) and a SECRET-bearing diff was certified clean (exit 0)"
else
  [ "$rc" -eq 2 ] && ok "broken gate interpreter → exit 2 (nothing certified — never clean, never a silent pass)" || fail "stub env exited $rc (want 2)"
fi
grep -q "never treat as clean" "$WORK/stub.err" && ok "stderr names the un-completed always-run gate" || fail "stub-env stderr silent"

note "== 2d. secrets still BLOCK under --no-code-gates =="
OUT2D="$WORK/ncgblock.json"
bash "$RCG" --cwd="$FIX" --base="$BASE2" --head="$HEAD2" --no-code-gates > "$OUT2D"; rc=$?
[ "$rc" -eq 1 ] && [ "$(jget "$OUT2D" "d['halt']['type']")" = "secret_in_code" ] \
  && ok "secret blocks even with gates 1-2/4/6 skipped (exit 1)" || fail "--no-code-gates weakened the secret gate (rc=$rc)"
[ "$(jget "$OUT2D" "d['not_run']")" = "['new_deps']" ] && ok "not_run = ['new_deps'] (skipped gates stay skips, never double-listed)" || fail "no-code-gates block not_run wrong"
[ "$(jaccount "$OUT2D")" = "ACCOUNT-OK" ] && ok "accounting invariant under --no-code-gates block" || fail "accounting: $(jaccount "$OUT2D")"

note "== 3. --no-code-gates: skips 1-2/4/6, always-run pair still runs =="
OUT3="$WORK/nogates.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --no-code-gates > "$OUT3"; rc=$?
[ "$rc" -eq 0 ] && ok "exit 0" || fail "no-code-gates run exited $rc"
for g in format lint_typecheck sast dep_authorization; do
  [ "$(jget "$OUT3" "d['gates']['$g']['ran']")" = "False" ] || fail "$g ran under --no-code-gates"
done
[ "$FAILED" -eq 0 ] && ok "gates 1-2, 4, 6 skipped (visible in skips[])"
[ "$(jget "$OUT3" "d['gates']['secrets']['ran']")" = "True" ] && [ "$(jget "$OUT3" "d['gates']['new_deps']['ran']")" = "True" ] \
  && ok "secrets + dep-existence STILL ran — no flag disables them" || fail "always-run pair did not survive --no-code-gates"
[ "$(jget "$OUT3" "d['config']['no_code_gates_flag']")" = "True" ] && ok "flag recorded in config{}" || fail "flag not recorded"

note "== 4. config code_gates: false — same effect, read by the wrapper itself =="
mkdir -p "$FIX/.mega-sdd"; printf 'code_gates: false\n' > "$FIX/.mega-sdd/config.yaml"
OUT4="$WORK/cfg.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" > "$OUT4"; rc=$?
[ "$rc" -eq 0 ] && [ "$(jget "$OUT4" "d['config']['code_gates_enabled']")" = "False" ] \
  && [ "$(jget "$OUT4" "d['gates']['sast']['ran']")" = "False" ] \
  && [ "$(jget "$OUT4" "d['gates']['secrets']['ran']")" = "True" ] \
  && ok "config key honored without a controller pre-check; secrets still ran" || fail "config code_gates: false not honored (rc=$rc)"
rm -f "$FIX/.mega-sdd/config.yaml"

note "== 5. --unit feeds gate 6 =="
UNIT="$FIX/U-001.md"
printf -- '---\nid: U-001\nallowed_new_deps: []\n---\n# unit\n' > "$UNIT"
OUT5="$WORK/unit.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --unit="$UNIT" > "$OUT5"; rc=$?
[ "$rc" -eq 0 ] && [ "$(jget "$OUT5" "d['gates']['dep_authorization']['ran']")" = "True" ] \
  && ok "gate 6 ran with --unit (advisory, exit 0)" || fail "gate 6 did not run with --unit (rc=$rc)"

note "== 6. pack ## Toolchain override: commands RUN (pack override > detection) =="
PACK="$WORK/pack.md"
cat > "$PACK" <<'EOF'
# Fixture pack

## Toolchain

```yaml
toolchain:
  format_check_cmd: true
  lint_cmd: false
```

## Notes
EOF
OUT6="$WORK/pack.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --pack="$PACK" > "$OUT6"; rc=$?
[ "$rc" -eq 0 ] && ok "exit 0 (lint failure is a finding, not a block)" || fail "pack run exited $rc"
[ "$(jget "$OUT6" "d['gates']['toolchain']['source']")" = "pack" ] && ok "toolchain source = pack" || fail "pack override not applied"
[ "$(jget "$OUT6" "d['gates']['format']['results'][0]['pass']")" = "True" ] && ok "pack format_check_cmd executed (passed)" || fail "pack format cmd not run"
[ "$(jget "$OUT6" "d['gates']['lint_typecheck']['findings']")" = "1" ] && ok "pack lint_cmd executed and its failure is a FINDING (proof the override runs)" || fail "pack lint finding missing"

note "== 6b. fix_cmd path: attempted/exit-code/re-check disclosure =="
PACKFIX="$WORK/packfix.md"
cat > "$PACKFIX" <<'EOF'
# Fixture pack (fix path)

## Toolchain

```yaml
toolchain:
  format_check_cmd: test -f .fixed
  format_fix_cmd: touch .fixed
```
EOF
rm -f "$FIX/.fixed"
OUT6B="$WORK/fixpath.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --pack="$PACKFIX" > "$OUT6B"; rc=$?
[ "$rc" -eq 0 ] && [ "$(jget "$OUT6B" "d['gates']['format']['results'][0]['fix_applied']")" = "True" ] \
  && [ "$(jget "$OUT6B" "d['gates']['format']['results'][0]['fix_rc']")" = "0" ] \
  && [ "$(jget "$OUT6B" "d['gates']['format']['results'][0]['fixed']")" = "True" ] \
  && ok "fix_cmd ran (fix_applied), its rc recorded (fix_rc=0), re-check passed (fixed)" || fail "fix path disclosure wrong (rc=$rc)"
rm -f "$FIX/.fixed"
PACKBADFIX="$WORK/packbadfix.md"
cat > "$PACKBADFIX" <<'EOF'
# Fixture pack (failing fix)

## Toolchain

```yaml
toolchain:
  format_check_cmd: sh -c 'echo FIRST-CHECK; exit 3'
  format_fix_cmd: sh -c 'exit 7'
```
EOF
OUT6C="$WORK/fixfail.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --pack="$PACKBADFIX" > "$OUT6C"; rc=$?
[ "$(jget "$OUT6C" "d['gates']['format']['results'][0]['fix_rc']")" = "7" ] && ok "a FAILING fix_cmd's exit code is recorded (fix_rc=7), not masked" || fail "failing fix_cmd rc not recorded"
[ "$(jget "$OUT6C" "d['gates']['format']['results'][0]['fixed']")" = "False" ] && ok "fixed=false when the re-check still fails" || fail "fixed wrongly true"

note "== 6c. requested-but-not-engaged pack is a VISIBLE note, never silent =="
OUT6D="$WORK/packmiss.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --pack="$WORK/does-not-exist.md" > "$OUT6D"; rc=$?
[ "$rc" -eq 0 ] && [ "$(jget "$OUT6D" "d['gates']['toolchain'].get('pack_requested_not_engaged')")" = "True" ] \
  && ok "missing --pack file → pack_requested_not_engaged flagged + detection fallback" || fail "missing pack silently fell back (rc=$rc)"
[ "$(jget "$OUT6D" "len([s for s in d['skips'] if s['gate']=='toolchain'])")" = "1" ] && ok "the non-engagement reason rides in skips[]" || fail "pack non-engagement reason missing"

note "== 6d. unresolvable --unit is a VISIBLE skip, never a silent enforced:false =="
OUT6E="$WORK/unitmiss.json"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --unit="$WORK/no-such-unit.md" > "$OUT6E"; rc=$?
[ "$rc" -eq 0 ] && [ "$(jget "$OUT6E" "d['gates']['dep_authorization']['ran']")" = "False" ] \
  && [ "$(jget "$OUT6E" "any('does not resolve' in s['reason'] for s in d['skips'] if s['gate']=='dep_authorization')")" = "True" ] \
  && ok "nonexistent --unit → gate 6 skip with 'does not resolve' reason" || fail "unresolvable --unit degraded silently (rc=$rc)"

note "== 6e. range{} pins resolved 40-hex SHAs, never a moving ref =="
OUT6F="$WORK/refrange.json"
bash "$RCG" --cwd="$FIX" --base="HEAD~1" --head="HEAD" > "$OUT6F"; rc=$?
[ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || fail "symbolic-ref invocation failed (rc=$rc)"
[ "$(jget "$OUT6F" "len(d['range']['base'])==40 and len(d['range']['head'])==40")" = "True" ] \
  && ok "symbolic refs (HEAD~1/HEAD) resolved to 40-hex SHAs in range{}" || fail "range{} carries unresolved refs"

note "== 7. usage/environment errors are exit 2, never clean =="
bash "$RCG" --cwd="$FIX" --base="$BASE" >/dev/null 2>&1; [ $? -eq 2 ] && ok "missing --head → exit 2" || fail "missing arg not exit 2"
bash "$RCG" --cwd="$FIX" --base=deadbeef --head="$HEAD" >/dev/null 2>&1; [ $? -eq 2 ] && ok "unresolvable --base → exit 2" || fail "bad base not exit 2"
NOREPO="$WORK/norepo"; mkdir -p "$NOREPO"
bash "$RCG" --cwd="$NOREPO" --base="$BASE" --head="$HEAD" >/dev/null 2>&1; [ $? -eq 2 ] && ok "non-repo --cwd → exit 2" || fail "non-repo not exit 2"
bash "$RCG" --cwd="$FIX" --base="$BASE" --head="$HEAD" --bogus >/dev/null 2>&1; [ $? -eq 2 ] && ok "unknown arg → exit 2" || fail "unknown arg not exit 2"

note "== 8. wiring pins: the wrapper is the shipped path =="
grep -q 'run-code-gates.sh' "$SK" && ok "SKILL.md invokes the wrapper" || fail "SKILL.md missing wrapper invocation"
grep -qF '${CLAUDE_PLUGIN_ROOT}/scripts/run-code-gates.sh' "$SK" && ok "SKILL.md carries the runnable form" || fail "runnable form missing from SKILL.md"
grep -q 'run-code-gates.sh' "$CG" && ok "code-gates.md documents the wrapper" || fail "code-gates.md missing wrapper"
grep -qF 'not_run' "$CG" && ok "code-gates.md documents the short-circuit record" || fail "not_run contract missing"
if grep -q 'resolve-plugin-root.sh' "$CG"; then fail "the retired per-bolt resolver block survives in code-gates.md"; else ok "per-bolt resolver block retired from code-gates.md"; fi
grep -q 'ONE call: run-code-gates.sh' "$SB" && ok "bridge diagram: L0 is one call" || fail "bridge diagram not updated"
grep -qF 'gates 3 and 5 always run' "$CG" && ok "always-run pair pinned in the wrapper contract" || fail "always-run pair not in wrapper contract"

if [ "$FAILED" -eq 0 ]; then note "ALL RUN-CODE-GATES PROOFS OK"; else note "run-code-gates FAILED"; fi
exit $FAILED

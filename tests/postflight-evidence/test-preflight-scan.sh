#!/usr/bin/env bash
# W4 (spec 2026-07-19-w-batch-script-derive.md): preflight.json is SCRIPT-written.
# run-preflight-scan.sh is the deterministic pre-flight Hard-rule BASELINE writer —
# it imports the SAME _lib/postflight_rules.py primitives the post-flight engine
# evaluates with, so the snapshot is byte-compatible with both consumers
# (run-postflight-scan.sh and the gate recompute), and it REFUSES to mint a
# baseline after bolt commits exist (anti-laundering).
#   A. schema — snapshot entries per rule type; written_by/grammar/head_sha stamps
#   B. round-trip parity — with a committed bolt the engine judges by the unit's
#      OWN commit touched-set (7.9.0, spec 2026-08-30 §1.2 / F-06); the snapshot is
#      a NOTE on the evidence (honest -> "did not touch" pass; tamper -> "touched" fail
#      carrying the sha-drift note)
#   C. unparseable line -> exit 3, no artifact, offending line named
#   D. mixed grammar -> exit 4; --grammar=v1 override -> exit 0
#   E. no Hard rules -> exit 0, NO artifact created
#   F. anti-laundering — commits + no baseline -> exit 7 no artifact;
#      commits + existing baseline -> exit 0, byte-identical (immutable)
#   G. re-capture allowed pre-commit (overwrite; snapshot_at changes)
#   H. SIGNATURE_RULE on an absent symbol -> exit 5
#   I. threat pin (REPINNED 7.9.0) — a FORGED post-tamper baseline no longer
#      launders a committed DO_NOT_MODIFY violation: the touched-set verdict does
#      not consult the snapshot. The write guard + post-hoc refusal stay
#      load-bearing for SIGNATURE rules and the pre-commit working-tree mode.
#   J. tamper-BEFORE-mint — a dirty DO_NOT_MODIFY target at baseline time ->
#      exit 8, NO artifact (the baseline would bake the tampered sha in);
#      same for a dirty SIGNATURE_RULE declaring file; restored tree -> mints
#   K. dirty UNRELATED file -> still mints (the refusal scopes to protected
#      paths only)
set -u
err=0
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PABS="$ROOT/plugins/mega-sdd/scripts/run-preflight-scan.sh"
QABS="$ROOT/plugins/mega-sdd/scripts/run-postflight-scan.sh"
[ -x "$PABS" ] || { echo "preflight writer missing/non-executable: $PABS"; exit 1; }
[ -x "$QABS" ] || { echo "postflight writer missing/non-executable: $QABS"; exit 1; }

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
( cd "$repo" && git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false )
mkdir -p "$repo/.mega-sdd/vaults/v1/units" "$repo/src"
printf 'export function keep(a,b){return a+b;}\n' > "$repo/src/core.js"
printf 'locked content\n' > "$repo/src/locked.js"
printf '{ "dependencies": { "left-pad": "^1.0.0" } }\n' > "$repo/package.json"
( cd "$repo" && git add . && git commit -qm seed >/dev/null )

mkunit(){ # uid rule_body...
  local uid="$1"; shift
  { printf -- '---\nunit_id: %s\ntask_type: create\n---\n# %s\n\n## Hard rules\n\n' "$uid" "$uid"
    local r; for r in "$@"; do printf -- '- %s\n' "$r"; done
    printf '\n## Acceptance\n'; } > "$repo/.mega-sdd/vaults/v1/units/$uid.md"
}
pf(){ echo "$repo/.mega-sdd/vaults/v1/bolts/$1/preflight.json"; }

# ── A. schema: one unit exercising every v1 rule type + a directive ──
mkunit U-001 \
  'DO NOT modify src/locked.js' \
  'DO NOT modify src/ghost.js' \
  'DO NOT add new package.json dependencies' \
  'function keep MUST preserve signature: (a,b)' \
  'src/**/*.js MUST follow camelCase naming' \
  'file src/core.js MUST exist after bolt' \
  'MUST log all access to the audit trail'
out=$(bash "$PABS" --cwd="$repo" --unit=U-001 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "A: expected exit 0, got $rc: $out"; err=1; }
HEAD=$(git -C "$repo" rev-parse HEAD)
HEAD="$HEAD" REPO="$repo" python3 - "$(pf U-001)" </dev/null <<'PY' || err=1
import hashlib, json, os, sys
d = json.load(open(sys.argv[1]))
ok = True
def chk(c, m):
    global ok
    if not c:
        ok = False
        print("A: " + m)
chk(d.get("written_by") == "run-preflight-scan.sh", "written_by wrong: %r" % d.get("written_by"))
chk(d.get("grammar") == "v1", "grammar wrong: %r" % d.get("grammar"))
chk(d.get("head_sha") == os.environ["HEAD"], "head_sha != HEAD")
by = {}
for r in (d.get("rules") or []):
    by.setdefault(r.get("type"), []).append(r)
lock = {r["path"]: r["sha256"] for r in by.get("DO_NOT_MODIFY", [])}
want = hashlib.sha256(open(os.path.join(os.environ["REPO"], "src/locked.js"), "rb").read()).hexdigest()
chk(lock.get("src/locked.js") == want, "DO_NOT_MODIFY sha256 != python-hashlib sha of the file")
chk(lock.get("src/ghost.js") == "absent", "absent file must record the string 'absent'")
deps = by.get("DO_NOT_ADD_DEPS", [])
chk(len(deps) == 1 and deps[0].get("manifest") == "package.json" and "deps_section" in deps[0],
    "DO_NOT_ADD_DEPS entry missing/malformed")
sig = by.get("SIGNATURE_RULE", [])
chk(len(sig) == 1 and sig[0].get("function") == "keep", "SIGNATURE_RULE entry missing")
chk(bool(sig) and sig[0].get("signature_at_preflight") == "export function keep(a,b)",
    "signature_at_preflight not the pre-{ decl prefix: %r" % (sig[0].get("signature_at_preflight") if sig else None))
for t in ("NAMING_RULE", "FILE_PRESENCE_RULE", "directive"):
    chk(t not in by, "unexpected snapshot entry for %s" % t)
sys.exit(0 if ok else 1)
PY

# ── B. round-trip parity: the engine takes the SNAPSHOT branch ──
# honest sibling: baseline captured pre-commit; bolt does NOT touch the locked file
mkunit U-002 'DO NOT modify src/locked.js'
bash "$PABS" --cwd="$repo" --unit=U-002 </dev/null >/dev/null 2>&1 || { echo "B: U-002 capture failed"; err=1; }
( cd "$repo" && echo n2 > src/n2.js && git add . && git commit -qm "feat(U-002): bolt

Unit: U-002" >/dev/null )
out=$(bash "$QABS" --cwd="$repo" --unit=U-002 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "B: honest U-002 postflight expected 0, got $rc: $out"; err=1; }
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
ev = [r for r in d["rules"] if r.get("type") == "DO_NOT_MODIFY"][0]["evidence"]
if ev != "bolt commits did not touch src/locked.js":
    print("B: engine did not take the TOUCHED-SET branch (7.9.0 contract): %r" % ev)
    sys.exit(1)
' "$repo/.mega-sdd/vaults/v1/bolts/U-002/postflight.json" </dev/null || err=1
# tampering sibling: baseline captured, then the bolt commit modifies the locked file
mkunit U-003 'DO NOT modify src/locked.js'
bash "$PABS" --cwd="$repo" --unit=U-003 </dev/null >/dev/null 2>&1 || { echo "B: U-003 capture failed"; err=1; }
( cd "$repo" && echo '// tampered' >> src/locked.js && git add . && git commit -qm "feat(U-003): bolt

Unit: U-003" >/dev/null )
out=$(bash "$QABS" --cwd="$repo" --unit=U-003 </dev/null 2>&1); rc=$?
[ $rc -eq 1 ] || { echo "B: tampered U-003 postflight expected 1, got $rc"; err=1; }
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
ev = [r for r in d["rules"] if r.get("type") == "DO_NOT_MODIFY"][0]["evidence"]
if not ev.startswith("bolt commit touched src/locked.js") or "note: sha256 differs" not in ev:
    print("B: touched evidence wrong (must name the touch AND carry the sha-drift note): %r" % ev)
    sys.exit(1)
' "$repo/.mega-sdd/vaults/v1/bolts/U-003/postflight.json" </dev/null || err=1

# ── C. unparseable line -> exit 3, no artifact, line named ──
mkunit U-010 'Refactor the login page nicely'
out=$(bash "$PABS" --cwd="$repo" --unit=U-010 </dev/null 2>&1); rc=$?
[ $rc -eq 3 ] || { echo "C: expected exit 3, got $rc: $out"; err=1; }
echo "$out" | grep -q 'Refactor the login page nicely' || { echo "C: offending line not named in output"; err=1; }
[ ! -f "$(pf U-010)" ] || { echo "C: artifact must not be written on unparseable"; err=1; }

# ── D. mixed grammar -> exit 4; --grammar=v1 override -> exit 0 ──
{ printf -- '---\nunit_id: U-011\ntask_type: create\n---\n# U-011\n\n## Hard rules\n\n- DO NOT modify src/locked.js\n\n```yaml\nid: no-eval\nlanguage: js\nrule:\n  pattern: eval($X)\n```\n\n## Acceptance\n'; } > "$repo/.mega-sdd/vaults/v1/units/U-011.md"
out=$(bash "$PABS" --cwd="$repo" --unit=U-011 </dev/null 2>&1); rc=$?
[ $rc -eq 4 ] || { echo "D: expected exit 4 on mixed grammar, got $rc: $out"; err=1; }
out=$(bash "$PABS" --cwd="$repo" --unit=U-011 --grammar=v1 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "D: --grammar=v1 override expected 0, got $rc: $out"; err=1; }

# ── E. no Hard rules -> exit 0 and NO artifact ──
{ printf -- '---\nunit_id: U-012\ntask_type: create\n---\n# U-012\n\n## Hard rules\n\n_None._\n\n## Acceptance\n'; } > "$repo/.mega-sdd/vaults/v1/units/U-012.md"
out=$(bash "$PABS" --cwd="$repo" --unit=U-012 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "E: expected exit 0, got $rc: $out"; err=1; }
[ ! -f "$(pf U-012)" ] || { echo "E: no-rules unit must not get a preflight.json"; err=1; }

# ── F. anti-laundering: post-hoc refusal + immutable baseline ──
mkunit U-020 'DO NOT modify src/locked.js'
( cd "$repo" && echo n20 > src/n20.js && git add . && git commit -qm "feat(U-020): bolt

Unit: U-020" >/dev/null )
out=$(bash "$PABS" --cwd="$repo" --unit=U-020 </dev/null 2>&1); rc=$?
[ $rc -eq 7 ] || { echo "F1: expected exit 7 post-hoc refusal, got $rc: $out"; err=1; }
[ ! -f "$(pf U-020)" ] || { echo "F1: refused run must not write an artifact"; err=1; }
cp "$(pf U-002)" "$repo/.u2.before"
out=$(bash "$PABS" --cwd="$repo" --unit=U-002 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "F2: expected exit 0 (baseline kept), got $rc: $out"; err=1; }
cmp -s "$(pf U-002)" "$repo/.u2.before" || { echo "F2: baseline not byte-identical after re-run (immutability broken)"; err=1; }
rm -f "$repo/.u2.before"

# ── G. re-capture allowed pre-commit (snapshot_at changes) ──
mkunit U-030 'DO NOT modify src/locked.js'
bash "$PABS" --cwd="$repo" --unit=U-030 </dev/null >/dev/null 2>&1 || { echo "G: first capture failed"; err=1; }
T1=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["snapshot_at"])' "$(pf U-030)" </dev/null)
bash "$PABS" --cwd="$repo" --unit=U-030 </dev/null >/dev/null 2>&1 || { echo "G: re-capture failed"; err=1; }
T2=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["snapshot_at"])' "$(pf U-030)" </dev/null)
[ -n "$T1" ] && [ "$T1" != "$T2" ] || { echo "G: re-capture did not overwrite (snapshot_at unchanged: $T1)"; err=1; }

# ── H. SIGNATURE_RULE on an absent symbol -> exit 5 ──
mkunit U-031 'function ghostFn MUST preserve signature: (x) => y'
out=$(bash "$PABS" --cwd="$repo" --unit=U-031 </dev/null 2>&1); rc=$?
[ $rc -eq 5 ] || { echo "H: expected exit 5 unanchored, got $rc: $out"; err=1; }

# ── I. threat pin (repinned 7.9.0): a FORGED post-tamper baseline does NOT launder ──
# Pre-7.9.0 the engine preferred a present snapshot over commit evidence, so a
# baseline minted AFTER the tamper (sha == tampered bytes) passed B1 — the
# residual that made the write guard + post-hoc refusal load-bearing. F-06
# flipped the DO_NOT_MODIFY verdict to the unit's own commit touched-set: the
# forged snapshot is now only a note, and the committed touch FAILS.
mkunit U-040 'DO NOT modify src/locked.js'
( cd "$repo" && echo '// tamper40' >> src/locked.js && git add . && git commit -qm "feat(U-040): bolt

Unit: U-040" >/dev/null )
mkdir -p "$repo/.mega-sdd/vaults/v1/bolts/U-040"
python3 -c '
import hashlib, json, sys
sha = hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest()
json.dump({"unit_id": "U-040", "rules": [{"type": "DO_NOT_MODIFY", "path": "src/locked.js", "sha256": sha}]},
          open(sys.argv[2], "w"))
' "$repo/src/locked.js" "$(pf U-040)" </dev/null
out=$(bash "$QABS" --cwd="$repo" --unit=U-040 </dev/null 2>&1); rc=$?
[ $rc -eq 1 ] || { echo "I: REGRESSION — a forged post-tamper baseline passes the engine again (rc=$rc); the snapshot has regained precedence over the unit's own commit touched-set (F-06)"; err=1; }
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
ev = [r for r in d["rules"] if r.get("type") == "DO_NOT_MODIFY"][0]["evidence"]
if not ev.startswith("bolt commit touched src/locked.js"):
    print("I: forged-baseline verdict must come from the touched-set, got %r" % ev); sys.exit(1)
' "$repo/.mega-sdd/vaults/v1/bolts/U-040/postflight.json" </dev/null || err=1

# ── J. tamper-BEFORE-mint: dirty protected path -> exit 8, no artifact ──
# The tamper-then-mint hole: edit the frozen file FIRST (no commit), then run
# the sanctioned writer — the baseline must be REFUSED, never minted from the
# tampered working tree (it would bake the tampered sha in and pass B1).
mkunit U-050 'DO NOT modify src/locked.js'
echo '// tamper-before-mint' >> "$repo/src/locked.js"
out=$(bash "$PABS" --cwd="$repo" --unit=U-050 </dev/null 2>&1); rc=$?
[ $rc -eq 8 ] || { echo "J1: expected exit 8 dirty-protected refusal, got $rc: $out"; err=1; }
[ ! -f "$(pf U-050)" ] || { echo "J1: refused run must not write an artifact"; err=1; }
echo "$out" | grep -q 'src/locked.js' || { echo "J1: refusal must name the dirty protected path"; err=1; }
echo "$out" | grep -qi 'indistinguishable from tampering' || { echo "J1: refusal must carry the remedy keterangan"; err=1; }
( cd "$repo" && git checkout -q -- src/locked.js )
out=$(bash "$PABS" --cwd="$repo" --unit=U-050 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] && [ -f "$(pf U-050)" ] || { echo "J1: restored clean tree must mint (rc=$rc): $out"; err=1; }
# same refusal for a dirty SIGNATURE_RULE declaring file
mkunit U-051 'function keep MUST preserve signature: (a,b)'
printf '// touched\n' >> "$repo/src/core.js"
out=$(bash "$PABS" --cwd="$repo" --unit=U-051 </dev/null 2>&1); rc=$?
[ $rc -eq 8 ] || { echo "J2: expected exit 8 for dirty SIGNATURE_RULE file, got $rc: $out"; err=1; }
[ ! -f "$(pf U-051)" ] || { echo "J2: refused run must not write an artifact"; err=1; }
echo "$out" | grep -q 'src/core.js' || { echo "J2: refusal must name the signature file"; err=1; }
( cd "$repo" && git checkout -q -- src/core.js )

# ── K. dirty UNRELATED file -> still mints (scope = protected paths only) ──
mkunit U-052 'DO NOT modify src/locked.js'
echo 'unrelated' > "$repo/src/unrelated.js"          # untracked, not a rule target
echo '// tweak' >> "$repo/src/n2.js"                 # tracked+dirty, not a rule target
out=$(bash "$PABS" --cwd="$repo" --unit=U-052 </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] && [ -f "$(pf U-052)" ] || { echo "K: unrelated dirty files must not block the mint (rc=$rc): $out"; err=1; }
rm -f "$repo/src/unrelated.js"
( cd "$repo" && git checkout -q -- src/n2.js )

[ $err -eq 0 ] && echo "PASS: test-preflight-scan (W4 script-written baseline)" || echo "FAIL: test-preflight-scan"
exit $err

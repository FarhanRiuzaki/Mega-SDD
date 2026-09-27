#!/usr/bin/env bash
# Lanes — route-lane.sh (observable signals → direct / assisted / guarded),
# delivery-check.sh (a fresh checkout of HEAD: test script, TZ, empty-env build,
# route reachability), the managed .mega-sdd/.gitignore, and the wiring that makes
# the front door route before any pipeline step. Fixtures are synthetic git repos;
# no network, no model. Evidence the checks target: research/2026-09-27-vanilla-vs-
# megasdd-results.md §4 (every defect below was found by hand in a benchmark run).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$here/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
R="$P/scripts/route-lane.sh"; D="$P/scripts/delivery-check.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/lanes.XXXXXX")"; trap 'rm -rf "$T"' EXIT
rc=0
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; rc=1; }
lane() { python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["lane"])'; }
fired() { python3 -c 'import json,sys; print(" ".join(json.loads(sys.stdin.read())["signals_fired"]))'; }
mkrepo() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" config user.email t@t && git -C "$1" config user.name t; }
commit() { git -C "$1" add -A && git -C "$1" commit -qm "${2:-c}"; }

echo "── L: route-lane.sh ──"
G="$T/green"; mkrepo "$G"; mkdir -p "$G/src/app"; echo 'export default function P(){}' > "$G/src/app/page.tsx"
echo '{}' > "$G/package.json"; echo 'export default {}' > "$G/next.config.ts"; commit "$G"
cat > "$T/clear.md" <<'EOF'
# PRD — Profil perusahaan
## Halaman
- Beranda
- Tentang Kami (nama + peran tim, tanpa foto)
## Di luar lingkup
Autentikasi, panel admin, pembayaran.
## Open questions
- Tidak ada — PRD FINAL.
EOF
out="$(bash "$R" --cwd="$G" --prd="$T/clear.md")"
[ "$(echo "$out" | lane)" = direct ] && ok "L1 clear greenfield PRD → direct (headed 'Open questions: Tidak ada' and out-of-scope security words do not fire)" || bad "L1 expected direct: $out"
[ ! -e "$G/.mega-sdd" ] && ok "L2 router writes nothing (no .mega-sdd/)" || bad "L2 router created .mega-sdd/"
cat > "$T/oq.md" <<'EOF'
# PRD
## Open Questions
- OQ-1 [P1] [business]: cancellation window?
EOF
out="$(bash "$R" --cwd="$G" --prd="$T/oq.md")"
[ "$(echo "$out" | lane)" = assisted ] && echo "$out" | fired | grep -q spec_open_items && ok "L3 a real open business item → assisted (batched ask), not the pipeline" || bad "L3 $out"
out="$(bash "$R" --cwd="$G" --text="halaman promo, harga TBD")"
[ "$(echo "$out" | lane)" = assisted ] && ok "L4 inline TBD in a brief → assisted" || bad "L4 $out"
cat > "$T/sec.md" <<'EOF'
# PRD
Staff log in with a password; only the admin role can approve refunds.
EOF
out="$(bash "$R" --cwd="$G" --prd="$T/sec.md")"
echo "$out" | fired | grep -q security_surface && [ "$(echo "$out" | lane)" = assisted ] && ok "L5 security surface → assisted (one blind review)" || bad "L5 $out"
B="$T/brown"; mkrepo "$B"; mkdir -p "$B/src"; for i in $(seq 1 12); do echo "export const a$i=1" > "$B/src/m$i.ts"; done; commit "$B"
out="$(bash "$R" --cwd="$B" --prd="$T/clear.md")"
[ "$(echo "$out" | lane)" = assisted ] && ok "L6 PRD on an existing app (≥10 source files) → assisted (brownfield block: the pipeline added cost, not catches)" || bad "L6 $out"
out="$(bash "$R" --cwd="$B" --text="tambah field telepon")"
[ "$(echo "$out" | lane)" = assisted ] && ok "L7 short brief on an existing app → assisted (too few claims to bind)" || bad "L7 $out"
V="$T/vault"; mkrepo "$V"; mkdir -p "$V/.mega-sdd/vaults/x"; echo '{}' > "$V/.mega-sdd/vaults/x/vault.json"
out="$(bash "$R" --cwd="$V" --text="ubah flow checkout")"
[ "$(echo "$out" | lane)" = guarded ] && ok "L8 existing vault → guarded (delta lane)" || bad "L8 $out"
out="$(bash "$R" --cwd="$B" --prd="$T/clear.md" --lane=direct)"
[ "$(echo "$out" | lane)" = direct ] && echo "$out" | grep -q '"override": {"from": "assisted"' && ok "L9 --lane override wins and is recorded" || bad "L9 $out"
bash "$R" --cwd="$G" --lane=bogus >/dev/null 2>&1; [ $? -eq 2 ] && ok "L10 bad --lane → exit 2" || bad "L10 usage exit"

echo "── D: delivery-check.sh ──"
command -v npm >/dev/null 2>&1 || { echo "SKIP: npm not installed — D checks need it"; exit $rc; }
N="$T/node"; mkrepo "$N"
cat > "$N/package.json" <<'EOF'
{"name":"f","version":"1.0.0","scripts":{"test":"node tz.test.js","build":"node build.js"}}
EOF
echo 'if (new Date(0).getTimezoneOffset() !== 0) { console.error("host tz leaked"); process.exit(1) }' > "$N/tz.test.js"
echo 'if (!process.env.SECRET) { console.error("Error: SECRET missing at build"); process.exit(1) }' > "$N/build.js"
mkdir -p "$N/src/app/tentang" "$N/src/app/kontak"
echo 'export default function H(){ return <a href="/kontak">k</a> }' > "$N/src/app/page.tsx"
echo 'export default function T(){}' > "$N/src/app/tentang/page.tsx"
echo 'export default function K(){}' > "$N/src/app/kontak/page.tsx"
echo 'SECRET=x' > "$N/.env"; printf '.env\n' > "$N/.gitignore"; commit "$N"
out="$(SECRET=x bash "$D" --cwd="$N" --json="$T/d.json")"; ec=$?
[ $ec -eq 1 ] && ok "D0 a blocking failure → exit 1" || bad "D0 exit $ec"
echo "$out" | grep -q '^  D3 FAIL tests depend on the host timezone' && ok "D3 TZ-dependent test caught (passes under UTC, fails under UTC+14)" || bad "D3 $out"
echo "$out" | grep -q '^  D4 FAIL' && ok "D4 build needing a secret fails on a fresh checkout even with it set locally and in .env" || bad "D4 $out"
echo "$out" | grep -q 'D5 WARN.*/tentang' && ! echo "$out" | grep -q 'D5 WARN.*/kontak' && ok "D5 unlinked page flagged, linked page not" || bad "D5 $out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["verdict"]=="FAIL" and any(c["id"]=="D5" and not c["blocking"] for c in d["checks"])' "$T/d.json" && ok "D6 --json verdict + D5 advisory" || bad "D6 json"
cat > "$N/package.json" <<'EOF'
{"name":"f","version":"1.0.0","scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}
EOF
commit "$N"; out="$(bash "$D" --cwd="$N")"
echo "$out" | grep -q '^  D1 FAIL' && ok "D1 npm's placeholder test script is not a test script" || bad "D1 $out"
cat > "$N/package.json" <<'EOF'
{"name":"f","version":"1.0.0","scripts":{"test":"TZ=Asia/Jakarta node -e 1","build":"node -e 1"}}
EOF
echo 'export default function T(){ return <a href="/tentang">t</a> }' > "$N/src/app/kontak/page.tsx"; commit "$N"
bash "$D" --cwd="$N" >/dev/null; [ $? -eq 0 ] && ok "D7 clean repo → PASS, exit 0" || bad "D7 expected PASS"
X="$T/py"; mkrepo "$X"; echo 'print(1)' > "$X/a.py"; commit "$X"
out="$(bash "$D" --cwd="$X")"; [ $? -eq 0 ] && echo "$out" | grep -q 'SKIP' && ok "D8 no package.json → SKIP, never a guessed toolchain" || bad "D8 $out"
bash "$D" --cwd="$T" >/dev/null 2>&1; [ $? -eq 2 ] && ok "D9 not a git repo → exit 2" || bad "D9"

echo "── A: artefact hygiene (managed .mega-sdd/.gitignore) ──"
A="$T/art"; mkrepo "$A"; mkdir -p "$A/.mega-sdd/vaults/v/html" "$A/.mega-sdd/vaults/v/lens-inputs/U-001" "$A/.mega-sdd/vaults/v/bolts/U-001"
bash "$P/scripts/derive-state.sh" --cwd="$A" --json-only >/dev/null 2>&1
[ -f "$A/.mega-sdd/.gitignore" ] && ok "A1 derive-state writes the managed .gitignore" || bad "A1 missing"
for f in vaults/v/html/index.html vaults/v/lens-inputs/U-001/unit-slice-spec.md .bolt-panel-state.json state.json vaults/v/lens-inputs/U-001/l0-results.json vaults/v/bolts/U-001/bolt-report.md vaults/v/bolts/U-001/dispatch-prompt.md vaults/v/context.md; do
  mkdir -p "$(dirname "$A/.mega-sdd/$f")"; echo x > "$A/.mega-sdd/$f"; done
ign="$(cd "$A" && git status --porcelain --untracked-files=all --ignored .mega-sdd | grep '^!!' | sed 's/^!! //')"
for f in vaults/v/html/index.html vaults/v/lens-inputs/U-001/unit-slice-spec.md .bolt-panel-state.json state.json; do
  echo "$ign" | grep -q "$f" && ok "A2 ignored (regenerable/transient): $f" || bad "A2 not ignored: $f"; done
for f in vaults/v/lens-inputs/U-001/l0-results.json vaults/v/bolts/U-001/bolt-report.md vaults/v/bolts/U-001/dispatch-prompt.md vaults/v/context.md; do
  echo "$ign" | grep -q "$f" && bad "A3 evidence ignored: $f" || ok "A3 kept (evidence/spec): $f"; done
printf 'mine\n' > "$A/.mega-sdd/.gitignore"; bash "$P/scripts/derive-state.sh" --cwd="$A" --json-only >/dev/null 2>&1
[ "$(cat "$A/.mega-sdd/.gitignore")" = mine ] && ok "A4 a user-owned .gitignore is never overwritten" || bad "A4 overwritten"

echo "── W: wiring ──"
grep -q 'route-lane.sh' "$P/commands/mega-sdd.md" && grep -q 'direct-lane.md' "$P/commands/mega-sdd.md" && ok "W1 front door routes before any pipeline step" || bad "W1"
grep -q 'route-lane.sh' "$P/skills/using-mega-sdd/SKILL.md" && ok "W2 router tier L names the lane router" || bad "W2"
grep -q 'delivery-check.sh' "$P/references/direct-lane.md" && grep -q 'delivery-check.sh' "$P/skills/execute-bolts/SKILL.md" && ok "W3 every lane ends with delivery-check" || bad "W3"
exit $rc

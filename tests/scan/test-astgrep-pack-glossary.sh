#!/usr/bin/env bash
# test-astgrep-pack-glossary.sh — the ast-grep language glossary contract
# (v5.33.0, the tsx-regression fix + full language coverage).
#
# STRUCTURAL (always):
#   1. Every glossary pack exists (20 languages).
#   2. LANE LAW: every rule's `language:` equals its pack's basename — the
#      Step-0 router derives lanes from FILENAMES, so a rule parked in another
#      file is invisible to routing (exactly how 182 .tsx files fell to regex).
#   3. Rule ids are unique across all packs.
#   4. jsx.yml must NOT exist (ast-grep's javascript grammar parses .jsx; a
#      jsx pack would double-count every .jsx symbol in the index) — jsx routes
#      via the ASTGREP_ALIASES map instead.
#
# LIVE (only when a real ast-grep is installed — skipped gracefully in CI):
#   5. For the 13 sampled packs (the 11 new + ts/js), the sample exercises
#      EVERY rule id and every rule fires >=1 (kind-name typos cannot ship
#      silently). The 7 remaining pre-glossary packs are exercised by the
#      ladder test's live arm.
#   5b. EXACT-set pins for the noise-prone packs (c/kotlin/haskell/dart/swift):
#      the sample's (ruleId, 0-based line) set must match EXACTLY - a rule
#      that also fires on usage sites/locals/signature types passes the
#      "fires >=1" arm while poisoning the index; this arm catches it.
#   6. Router pin: probe-scan-engine routes tsx AND jsx to astgrep_langs
#      (no `no_astgrep_pack` fallback — the training-nextjs regression).
#   7. Dup guard: a .jsx sample scanned with ALL packs concatenated yields
#      exactly ONE function row (a second row = someone added jsx.yml back).
#
# CI-safe: bash + python3; ast-grep optional.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKS="$REPO_ROOT/plugins/mega-sdd/skills/scan-codebase/queries/astgrep"
PROBE="$REPO_ROOT/plugins/mega-sdd/scripts/probe-scan-engine.sh"

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

GLOSSARY=(typescript tsx javascript php python rust go ruby java csharp \
          kotlin swift scala c cpp dart elixir lua bash haskell)

# ── 1. presence ──────────────────────────────────────────────────────────────
MISS=0
for L in "${GLOSSARY[@]}"; do
  [ -f "$PACKS/$L.yml" ] || { fail "missing pack $L.yml"; MISS=1; }
done
[ "$MISS" = "0" ] && pass "all ${#GLOSSARY[@]} glossary packs present"

# ── 2+3. lane law + unique ids ───────────────────────────────────────────────
LANE=$(PACKS="$PACKS" python3 - <<'PY'
import os, re, sys
packs = os.environ["PACKS"]
ids, bad_lane, dup = [], [], []
for fn in sorted(os.listdir(packs)):
    if not fn.endswith(".yml"):
        continue
    lang = fn[:-4]
    text = open(os.path.join(packs, fn), encoding="utf-8").read()
    langs = re.findall(r"^language:\s*(\S+)", text, re.M)
    for l in langs:
        if l != lang:
            bad_lane.append("%s carries language: %s" % (fn, l))
    for i in re.findall(r"^id:\s*(\S+)", text, re.M):
        if i in ids:
            dup.append(i)
        ids.append(i)
    if not langs:
        bad_lane.append("%s has no language field" % fn)
print("BAD_LANE:%s" % ";".join(bad_lane))
print("DUP:%s" % ";".join(dup))
PY
)
echo "$LANE" | grep -q "^BAD_LANE:$" && pass "lane law holds (every rule's language == its pack filename)" \
  || fail "lane law broken: $(echo "$LANE" | grep BAD_LANE)"
echo "$LANE" | grep -q "^DUP:$" && pass "rule ids unique across all packs" \
  || fail "duplicate rule ids: $(echo "$LANE" | grep DUP)"

# ── 4. jsx.yml must not exist ────────────────────────────────────────────────
[ ! -f "$PACKS/jsx.yml" ] && pass "no jsx.yml (jsx aliases to the javascript lane — dup guard)" \
  || fail "jsx.yml exists — every .jsx symbol will double-count in the index"
grep -q 'ASTGREP_ALIASES = {"jsx": "javascript"}' "$PROBE" \
  && pass "probe carries the jsx->javascript alias" || fail "jsx alias missing from probe-scan-engine.sh"

# ── LIVE arms ────────────────────────────────────────────────────────────────
if ! command -v ast-grep >/dev/null 2>&1; then
  echo "  PASS: (live arms skipped — ast-grep not on this runner; structural pins above hold)"
  echo
  [ "$fails" -eq 0 ] && { echo "test-astgrep-pack-glossary: ALL PASS"; exit 0; } \
    || { echo "test-astgrep-pack-glossary: $fails FAILURE(S)"; exit 1; }
fi

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# ── 5. every rule fires on its language sample ───────────────────────────────
cat > "$W/s.tsx" <<'EOF'
export function Page(){return <div/>}
class Store {}
interface P { x: number }
type T = string
enum E { A }
class M { render(){ return null } }
const Btn = () => <b/>
const f2 = function(){ return 1 }
EOF
cat > "$W/s.ts" <<'EOF'
export function f(){}
class C { m(){} }
interface I { x: number }
type T = string
enum E { A }
const g = () => 1
const h = function(){ return 1 }
EOF
cat > "$W/s.js" <<'EOF'
function f(){}
function* gen(){}
class C { m(){} }
const g = () => 1
const h = function(){ return 1 }
EOF
cat > "$W/s.kt" <<'EOF'
fun top(x: Int): Int { val local = 1; return x }
class Repo(val id: Int) { fun find(): Int = id }
object Singleton { }
interface Api { fun call(): Int }
enum class Color { RED }
val topProp = 42
typealias H = (Int) -> Int
class Box {
    companion object {
        val S = 1
    }
}
EOF
cat > "$W/s.swift" <<'EOF'
func top(x: Int) -> Int { return x }
class Repo { init(x: Int) {} func find() -> Int { return 1 } }
struct Point { var x: Int }
protocol Api { func call() -> Int }
enum Color { case red }
actor Counter { func inc() {} }
extension Repo { func extra() {} }
EOF
cat > "$W/s.scala" <<'EOF'
object App { def main(args: Array[String]): Unit = () }
class Repo(id: Int) { def find(): Int = id }
trait Api { def call(): Int }
enum Color:
  case Red, Green
given intOrd: Ordering[Int] = Ordering.Int
EOF
cat > "$W/s.c" <<'EOF'
struct point { int x; };
enum color { RED };
typedef struct point point_t;
struct point g;
int add(int a, int b) { struct point l; return sizeof(struct point); }
EOF
cat > "$W/s.cpp" <<'EOF'
class Repo { public: int find(); };
struct Point { int x; };
enum Color { RED };
namespace ns { int add(int a, int b) { return a + b; } }
template<typename T> T idf(T v) { return v; }
EOF
cat > "$W/s.dart" <<'EOF'
int add(int a, int b) => a + b;
class Repo {
  Repo(this.id);
  Repo.named(int x) : id = x;
  factory Repo.f() => Repo(1);
  final int id;
  int find() { return 1; }
  int get total => id;
}
enum Color { red }
mixin Walkable { void walk() {} }
extension RepoX on Repo { int extra() { return 2; } }
EOF
cat > "$W/s.ex" <<'EOF'
defmodule Repo do
  def find(id), do: id
  defp hidden(x), do: x
  defguard is_adult(age) when age >= 18
  defdelegate reverse(list), to: Enum
end
EOF
cat > "$W/s.lua" <<'EOF'
function top(x) return x end
local function helper(y) return y end
local M = {}
function M.method(z) return z end
EOF
cat > "$W/s.sh" <<'EOF'
#!/bin/bash
foo() { echo hi; }
EOF
cat > "$W/s.hs" <<'EOF'
add :: Int -> Int -> Int
add x y = x + y
data Color = Red | Blue
newtype Age = Age Int
class Shape a where
  area :: a -> Int
EOF

LIVE=$(W="$W" PACKS="$PACKS" python3 - <<'PY'
import json, os, re, subprocess
w = os.environ["W"]; packs = os.environ["PACKS"]
SAMPLES = {"tsx": "s.tsx", "typescript": "s.ts", "javascript": "s.js",
           "kotlin": "s.kt", "swift": "s.swift", "scala": "s.scala",
           "c": "s.c", "cpp": "s.cpp", "dart": "s.dart", "elixir": "s.ex",
           "lua": "s.lua", "bash": "s.sh", "haskell": "s.hs"}
problems = []
for lang, sample in SAMPLES.items():
    text = open(os.path.join(packs, lang + ".yml"), encoding="utf-8").read()
    want = set(re.findall(r"^id:\s*(\S+)", text, re.M))
    p = subprocess.run(["ast-grep", "scan", "--inline-rules", text, "--json=compact",
                        os.path.join(w, sample)],
                       capture_output=True, text=True, timeout=60)
    if p.returncode != 0:
        problems.append("%s: scan rc=%s %s" % (lang, p.returncode, p.stderr.strip()[:80]))
        continue
    got = set(m.get("ruleId") for m in (json.loads(p.stdout) if p.stdout.strip() else []))
    silent = want - got
    if silent:
        problems.append("%s: rules never fired on sample: %s" % (lang, ",".join(sorted(silent))))
print("PROBLEMS:%s" % "|".join(problems))
PY
)
echo "$LIVE" | grep -q "^PROBLEMS:$" \
  && pass "every rule in all 13 sampled packs fires live (ast-grep $(ast-grep --version | head -1))" \
  || fail "silent rules: $(echo "$LIVE" | grep PROBLEMS | head -c 300)"

# ── 5b. EXACT-set pins for the noise-prone packs ─────────────────────────────
EXACT=$(W="$W" PACKS="$PACKS" python3 - <<'PY'
import json, os, subprocess
w = os.environ["W"]; packs = os.environ["PACKS"]
EXPECT = {
 "c":       ("s.c",     [("c-enum",1),("c-function",4),("c-struct",0),("c-typedef",2)]),
 "kotlin":  ("s.kt",    [("kotlin-class",1),("kotlin-class",3),("kotlin-class",4),("kotlin-class",7),
                          ("kotlin-companion-object",8),("kotlin-function",0),("kotlin-function",1),
                          ("kotlin-function",3),("kotlin-object",2),("kotlin-property",5),
                          ("kotlin-property",9),("kotlin-typealias",6)]),
 "haskell": ("s.hs",    [("haskell-class",4),("haskell-data",2),("haskell-function",1),
                          ("haskell-newtype",3),("haskell-signature",0),("haskell-signature",5)]),
 "dart":    ("s.dart",  [("dart-class",1),("dart-constructor",2),("dart-constructor",3),
                          ("dart-enum",9),("dart-extension",11),("dart-function",0),
                          ("dart-method",4),("dart-method",6),("dart-method",7),
                          ("dart-method",10),("dart-method",11),("dart-mixin",10)]),
 "swift":   ("s.swift", [("swift-class",1),("swift-class",2),("swift-class",4),("swift-class",5),
                          ("swift-class",6),("swift-function",0),("swift-function",1),
                          ("swift-function",5),("swift-function",6),("swift-init",1),
                          ("swift-protocol",3)]),
}
bad = []
for lang, (sample, exp) in EXPECT.items():
    rules = open(os.path.join(packs, lang + ".yml"), encoding="utf-8").read()
    p = subprocess.run(["ast-grep", "scan", "--inline-rules", rules, "--json=compact",
                        os.path.join(w, sample)],
                       capture_output=True, text=True, timeout=60)
    got = sorted((m["ruleId"], m["range"]["start"]["line"])
                 for m in (json.loads(p.stdout) if p.stdout.strip() else []))
    if got != sorted(exp):
        bad.append("%s: got %s expected %s" % (lang, got, sorted(exp)))
print("BAD:%s" % "|".join(bad))
PY
)
echo "$EXACT" | grep -q "^BAD:$" \
  && pass "exact-set pins hold for c/kotlin/haskell/dart/swift (usage-site/local/signature noise stays silent)" \
  || fail "exact-set drift: $(echo "$EXACT" | grep BAD | head -c 400)"

# ── 6. router pin: tsx + jsx land on the ast lane ────────────────────────────
printf 'export function P(){return <a/>}\n' > "$W/r.tsx"
printf 'export function Q(){return <a/>}\n' > "$W/r.jsx"
DIGEST=$(bash "$PROBE" --cwd="$W" --lang=tsx:r.tsx --lang=jsx:r.jsx 2>/dev/null)
echo "$DIGEST" | python3 -c "
import json, sys
d = json.load(sys.stdin)
langs = d.get('astgrep_langs', [])
falls = [f for f in d.get('fallbacks', []) if f.get('reason') == 'no_astgrep_pack']
ok = 'tsx' in langs and 'jsx' in langs and not falls
sys.exit(0 if ok else 1)" \
  && pass "probe routes tsx + jsx to astgrep_langs (the training-nextjs regression pin)" \
  || fail "probe still drops tsx/jsx to regex: $DIGEST"

# ── 7. dup guard: one function row for a .jsx file across ALL packs ──────────
ALLRULES=$(awk 'FNR==1 && NR!=1 {print "---"} {print}' "$PACKS"/*.yml)
NJSX=$(ast-grep scan --inline-rules "$ALLRULES" --json=compact "$W/r.jsx" 2>/dev/null \
  | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
[ "${NJSX:-0}" = "1" ] && pass "concatenated glossary yields exactly 1 row for a .jsx function (no double-count)" \
  || fail ".jsx function matched $NJSX rows across the glossary (want 1 — dup regression)"

echo
if [ "$fails" -eq 0 ]; then
  echo "test-astgrep-pack-glossary: ALL PASS"
  exit 0
else
  echo "test-astgrep-pack-glossary: $fails FAILURE(S)"
  exit 1
fi

#!/usr/bin/env bash
# test-3b-extraction-parity.sh — god-review stage 3, Batch 3B.
# Pins detection↔extraction parity: every ecosystem Step 8.5 can detect must have
# a Step 5 symbol pattern + Step 6 route row + Step 7 model row (or hit the
# explicit parity-rail fallback), and the regex rows must actually match the
# dominant real-world symbol forms they claim to cover.
#
#   ECO-1  .NET rows exist in Step 6 (attribute + minimal API) and Step 7 (EF Core);
#          the _universal fallback is re-keyed to also fire on a signature-row gap.
#   ECO-2  C# / Kotlin / F# regex rows exist and match real declarations.
#   SP-1   widened patterns match export-default-async / final class / async def /
#          Go receiver / pub async fn (the forms the originals missed).
#   SP-5   @remix-run/ and @sveltejs/kit precede "express" in the detection table.
#   V8     the three language-coverage lists agree (SKILL.md 9 langs; integration
#          ref lists tags-csharp.scm; VERSIONS.md pins C#).
#
# Run: bash tests/god-review-s3/test-3b-extraction-parity.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SP="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md"
TS="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/tree-sitter-integration.md"
VM="${ROOT}/plugins/mega-sdd/skills/scan-codebase/queries/VERSIONS.md"
SK="${ROOT}/plugins/mega-sdd/skills/scan-codebase/SKILL.md"
for f in "$SP" "$TS" "$VM" "$SK"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 3B: detection-vs-extraction parity =="

# ── ECO-1: .NET rows present in Steps 6 + 7; parity-rail fallback re-keyed ──
grep -qF '[Http(Get\|Post\|Put\|Delete\|Patch)' "$SP" && ok "ECO-1: ASP.NET attribute-routing row in Step 6" || fail "ECO-1: no ASP.NET attribute route row"
grep -qF 'app.Map(Get\|Post\|Put\|Delete\|Patch)(' "$SP" && ok "ECO-1: minimal-API row in Step 6" || fail "ECO-1: no minimal-API route row"
grep -qF ': DbContext' "$SP" && grep -qF 'DbSet<' "$SP" && ok "ECO-1: EF Core row in Step 7" || fail "ECO-1: no EF Core model row"
grep -qF 'a matched framework with no signature row in this table' "$SP" && ok "ECO-1: _universal fallback re-keyed to signature-row gap (Step 6)" || fail "ECO-1: Step 6 fallback not re-keyed"
grep -qF 'No ORM signature match for a detected ecosystem' "$SP" && ok "ECO-1: Step 7 gained a parity fallback" || fail "ECO-1: Step 7 fallback missing"

# ── ECO-2 + SP-1: the documented regex rows match the dominant forms ──
# Patterns are read from the doc between backticks so the DOC is what's tested.
pat() { # $1 = language label at line start
  python3 - "$SP" "$1" <<'PY'
import re, sys
doc = open(sys.argv[1]).read()
lang = sys.argv[2]
m = re.search(r"^- \*\*" + re.escape(lang) + r":\*\* (.+)$", doc, re.M)
if not m:
    print("")
    raise SystemExit(0)
print("\x1f".join(re.findall(r"`([^`]+)`", m.group(1))))
PY
}
# The doc patterns target rg + grep -E, which support POSIX classes; python re
# (this harness) does not — translate the POSIX classes before matching.
assert_match() { # $1=lang $2=snippet $3=desc
  PATS="$(pat "$1")" SNIP="$2" python3 -c "
import os, re, sys
def posix(p): return p.replace('[[:space:]]', r'[ \t]').replace('[[:alpha:]]', '[A-Za-z]')
pats = [posix(p) for p in os.environ['PATS'].split('\x1f') if p and not p.startswith('--') and ('^' in p or '(' in p)]
snip = os.environ['SNIP']
sys.exit(0 if any(re.search(p, snip, re.M) for p in pats) else 1)
" && ok "$1: matches $3" || fail "$1 pattern misses $3"
}
assert_nomatch() {
  PATS="$(pat "$1")" SNIP="$2" python3 -c "
import os, re, sys
def posix(p): return p.replace('[[:space:]]', r'[ \t]').replace('[[:alpha:]]', '[A-Za-z]')
pats = [posix(p) for p in os.environ['PATS'].split('\x1f') if p and not p.startswith('--') and ('^' in p or '(' in p)]
snip = os.environ['SNIP']
sys.exit(1 if any(re.search(p, snip, re.M) for p in pats) else 0)
" && ok "$1: correctly ignores $3" || fail "$1 pattern false-positives on $3"
}

# round-2 (fix-review): the documented list must stay POSIX-ERE-safe — `\w` inside a
# bracket class is LITERAL under GNU/BSD grep -E (the guaranteed fallback engine), so
# rows carrying it extract zero symbols there.
python3 - "$SP" <<'PY' && ok "r2: no PCRE-only \\w token in the per-language pattern list (grep -E safe)" || fail "r2: \\w survives in a documented pattern"
import re, sys
doc = open(sys.argv[1]).read()
m = re.search(r"Per-language patterns \(engine: regex\).*?(?=\n## )", doc, re.S)
assert m, "pattern list not found"
bad = [ln for ln in m.group(0).split("\n") if ln.startswith("- **") and "\\w" in ln]
sys.exit(1 if bad else 0)
PY

assert_match "TypeScript/JS" 'export default async function handler(req, res) {' 'export default async function'
assert_match "TypeScript/JS" 'export enum Role {' 'export enum'
assert_match "TypeScript/JS" 'export abstract class Base {' 'export abstract class'
assert_match "PHP" 'final class PaymentService' 'final class'
assert_match "PHP" '    public static function make(): self' 'public static function'
assert_match "PHP" 'enum OrderStatus: string' 'php enum'
assert_match "Python" 'async def fetch_data(url):' 'async def'
assert_match "Go" 'func (s *Server) HandleLogin(w http.ResponseWriter) {' 'receiver method (exported)'
assert_nomatch "Go" 'func (s *Server) internalHelper() {' 'unexported receiver method'
assert_match "Rust" 'pub async fn run() {' 'pub async fn'
assert_match "Rust" 'pub(crate) fn helper() {' 'pub(crate) fn'
assert_match "Rust" 'pub type Result<T> = std::result::Result<T, Error>;' 'pub type'
assert_match "C#" 'public sealed class OrderService' 'C# sealed class'
assert_match "C#" '    public async Task<IActionResult> Create(OrderDto dto)' 'C# async action method'
assert_match "C#" 'public record OrderCreated(Guid Id);' 'C# record'
assert_match "Kotlin" 'data class User(val id: Long)' 'Kotlin data class'
assert_match "Kotlin" 'suspend fun loadUser(id: Long): User {' 'Kotlin suspend fun'
assert_match "F#" 'type Order = { Id: int }' 'F# type'
assert_match "F#" 'let rec traverse node =' 'F# let rec'
# round-2 forms the first cut missed:
assert_match "PHP" 'final readonly class Money' 'final readonly class (repeatable modifiers)'
assert_match "Rust" 'pub(in crate::my_mod) fn helper() {' 'pub(in crate::my_mod) fn'
assert_match "Kotlin" '    override fun onCreate(savedInstanceState: Bundle?) {' 'override fun'
assert_match "Kotlin" 'suspend operator fun invoke(id: Long): User {' 'suspend operator fun'
assert_match "C#" 'public readonly record struct Point(int X, int Y);' 'readonly record struct'
assert_nomatch "F#" '    let localHelper x = x + 1' 'indented function-local let binding'

# ── SP-5: meta-frameworks precede server substrates in the 8.5 table ──
python3 - "$SP" <<'PY' && ok "SP-5: @remix-run/ + @sveltejs/kit precede express/fastify" || fail "SP-5: detection-table order wrong"
import sys
doc = open(sys.argv[1]).read()
idx = {k: doc.find(k) for k in ('"@remix-run/"', '"@sveltejs/kit"', '"express"', '"fastify"')}
assert all(v >= 0 for v in idx.values()), idx
ok_order = max(idx['"@remix-run/"'], idx['"@sveltejs/kit"']) < min(idx['"express"'], idx['"fastify"'])
sys.exit(0 if ok_order else 1)
PY
grep -qF 'meta-frameworks precede the server substrates' "$SP" && ok "SP-5: ordering rule documented" || fail "SP-5: ordering rule prose missing"

# ── V8: the three coverage lists agree ──
grep -qF '9 languages: TS/JS/PHP/Python/Go/Rust/Ruby/Java/C#' "$SK" && ok "V8: SKILL.md queries note lists 9 languages" || fail "V8: SKILL.md queries note stale"
grep -qF 'tags-csharp.scm' "$TS" && ok "V8: integration ref lists tags-csharp.scm" || fail "V8: integration ref missing C#"
grep -qF 'tree-sitter-c-sharp' "$VM" && ok "V8: VERSIONS.md pins the C# grammar" || fail "V8: C# grammar unpinned"
N_SCM=$(ls "$ROOT/plugins/mega-sdd/skills/scan-codebase/queries/"tags-*.scm | wc -l | tr -d ' ')
N_TS=$(grep -c '^- `tags-.*\.scm`' "$TS")
[ "$N_SCM" = "$N_TS" ] && ok "V8: integration ref lists all $N_SCM shipped query files" || fail "V8: ref lists $N_TS of $N_SCM query files"

if [ "$FAILED" -eq 0 ]; then note "ALL 3B OK"; else note "3B had failures"; fi
exit $FAILED

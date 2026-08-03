#!/usr/bin/env bash
# test-p3-oq-defer-risk-router.sh — v6 P3 proof suite (spec §P3.5):
#   1. resolve-review-tier.sh — deterministic router fixtures (minimal newly
#      reachable; every risk signal forces full; unknown rc never a low tier).
#   2. OQ prose pins — batched P1 walk, auto-defer recorded + rails re-scoped,
#      A6 resurface surfaces (metrics id list, _summary section, Step 9 +
#      appendix bullets).
#   3. Lean-by-default — orchestrate paragraph, Stop-aggregate condition
#      (classic|full fires, lean never), advisor stays default-on.
# CI-safe: bash + python3 only.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/plugins/mega-sdd"
RT="$P/scripts/resolve-review-tier.sh"
fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkunit() {  # $1=file $2=task_type $3=risk(optional) $4=paths(space-sep) $5=body
  local f="$1" tt="$2" risk="$3" paths="$4" body="$5"
  {
    printf -- '---\nunit_id: U-001\ntask_type: %s\n' "$tt"
    [ -n "$risk" ] && printf 'risk: %s\n' "$risk"
    printf 'target_files:\n'
    for pth in $paths; do printf '  - path: %s\n    operation: create\n' "$pth"; done
    printf 'binding_refs:\n  - C-001\n---\n\n# Unit\n%s\n' "$body"
  } > "$f"
}

# ── 1. Router fixtures ───────────────────────────────────────────────────────
mkunit "$WORK/u-verify.md" verify "" "app/Models/User.php" "Verify the model exists."
T=$(bash "$RT" --unit "$WORK/u-verify.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "minimal" ] && pass "verify unit -> minimal" || fail "verify tier=$T"

mkunit "$WORK/u-small.md" create "" "app/Services/Report.php app/Views/report.blade.php" "Render laporan bulanan sederhana."
T=$(bash "$RT" --unit "$WORK/u-small.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "minimal" ] && pass "<=2-file clean create -> minimal (the newly-reachable case)" || fail "small tier=$T"

mkunit "$WORK/u-3file.md" create "" "a/One.php a/Two.php a/Three.php" "Clean tiga file."
T=$(bash "$RT" --unit "$WORK/u-3file.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "standard" ] && pass "3-file clean -> standard (default)" || fail "3file tier=$T"

mkunit "$WORK/u-many.md" create "" "a/1.php a/2.php a/3.php a/4.php" "Empat file."
OUT=$(bash "$RT" --unit "$WORK/u-many.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'file_count' in d['signals_fired']" \
  && pass ">=4 files -> full (file_count fired)" || fail "many: $OUT"

mkunit "$WORK/u-vocab.md" create "" "app/Services/Pay.php" "Handle payment settlement via token."
OUT=$(bash "$RT" --unit "$WORK/u-vocab.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'vocabulary' in d['signals_fired']" \
  && pass "payment/token vocabulary -> full" || fail "vocab: $OUT"

mkunit "$WORK/u-manifest.md" extend "" "composer.json app/Support/Helper.php" "Tambah dependency util."
OUT=$(bash "$RT" --unit "$WORK/u-manifest.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'manifest' in d['signals_fired']" \
  && pass "dependency manifest in target_files -> full" || fail "manifest: $OUT"

mkunit "$WORK/u-risk.md" create high "app/Anything.php" "Netral."
OUT=$(bash "$RT" --unit "$WORK/u-risk.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'risk_field' in d['signals_fired']" \
  && pass "risk: high alone -> full" || fail "risk: $OUT"

cat > "$WORK/u-b.md" <<'EOF'
---
unit_id: U-009
task_type: create
target_files:
  - path: app/Http/Middleware/Check.php
    operation: create
binding_refs:
  - C-004
  - B-002
---

# Unit
Netral body.
EOF
OUT=$(bash "$RT" --unit "$WORK/u-b.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'constitution_b' in d['signals_fired']" \
  && pass "constitution §B clause in binding_refs -> full" || fail "B-clause: $OUT"

cat > "$WORK/pack.md" <<'EOF'
---
framework: fake
auth_hints:
  - app/Http/Middleware/*
authz_hints:
  - app/Policies/*
---
EOF
mkunit "$WORK/u-glob.md" create "" "app/Policies/PostPolicy.php" "Netral."
OUT=$(bash "$RT" --unit "$WORK/u-glob.md" --pack "$WORK/pack.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'auth_globs' in d['signals_fired']" \
  && pass "pack authz glob hit -> full" || fail "glob: $OUT"

bash "$RT" --unit "$WORK/nonexistent.md" >/dev/null 2>&1
[ $? -eq 2 ] && pass "unreadable unit -> exit 2 (caller falls back to standard, never minimal)" || fail "unreadable rc"

# ── 1b. Round-folded negative-recall fixtures ────────────────────────────────
cat > "$WORK/pack2.md" <<'EOF2'
---
framework: fake
auth_hints:
  - "**/auth*"
  - "**/login*"
---
EOF2
mkunit "$WORK/u-caps.md" create "" "app/Http/Controllers/Auth/LoginController.php" "Implement the user authentication flow with authorization middleware."
OUT=$(bash "$RT" --unit "$WORK/u-caps.md" --pack "$WORK/pack2.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and ('auth_globs' in d['signals_fired'] or 'vocabulary' in d['signals_fired']), d" \
  && pass "round-1: capitalized Auth path + derived words -> full (case-folded globs + stems)" || fail "caps arm: $OUT"

mkunit "$WORK/u-plural.md" create "" "app/S.php" "Store hashed passwords and refresh tokens; sessions expire nightly."
T=$(bash "$RT" --unit "$WORK/u-plural.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "full" ] && pass "round-4: plural vocabulary fires" || fail "plural tier=$T"

mkunit "$WORK/u-id.md" create "" "app/S.php" "Simpan sandi pengguna untuk alur autentikasi; manajer menyetujui pengajuan."
T=$(bash "$RT" --unit "$WORK/u-id.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "full" ] && pass "round-3: sandi/autentikasi/menyetujui fire (doc-verbatim list + stems)" || fail "id-vocab tier=$T"

printf '\xef\xbb\xbf' > "$WORK/u-bom.md"
cat >> "$WORK/u-bom.md" <<'EOF2'
---
unit_id: U-020
task_type: create
risk: critical
target_files:
  - path: app/One.php
    operation: create
---

# Unit
Netral.
EOF2
T=$(bash "$RT" --unit "$WORK/u-bom.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "full" ] && pass "round-2: BOM does not blank the frontmatter (risk still fires)" || fail "bom tier=$T"

cat > "$WORK/u-flow.md" <<'EOF2'
---
unit_id: U-021
task_type: create
target_files: [app/A.php, app/B.php, app/C.php, app/D.php, composer.json]
---

# Unit
Netral.
EOF2
OUT=$(bash "$RT" --unit "$WORK/u-flow.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='full' and 'manifest' in d['signals_fired'] and d['target_files']==5, d" \
  && pass "round-doc4: inline-flow target_files parsed (manifest + count fire)" || fail "flow arm: $OUT"

mkunit "$WORK/u-zero.md" create "" "" "Netral tanpa file."
T=$(bash "$RT" --unit "$WORK/u-zero.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "standard" ] && pass "round-2: zero declared files on create -> standard, never minimal" || fail "zero tier=$T"

cat > "$WORK/u-cb.md" <<'EOF2'
---
unit_id: U-022
task_type: create
target_files:
  - path: app/One.php
    operation: create
binding_refs:
  - C-B-001
---

# Unit
Netral.
EOF2
T=$(bash "$RT" --unit "$WORK/u-cb.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "minimal" ] && pass "round-10: composite id C-B-001 does NOT false-fire constitution_b" || fail "cb tier=$T"

mkunit "$WORK/u-author.md" create "" "app/One.php" "Track the author of each post."
T=$(bash "$RT" --unit "$WORK/u-author.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "minimal" ] && pass "round: 'author' still does not fire 'auth' (boundary intact)" || fail "author tier=$T"

# false-positive guard: 'akseskan'-style word-boundary (access inside a longer word)
mkunit "$WORK/u-fp.md" create "" "app/One.php" "Proses aksesibilitas laporan."
T=$(bash "$RT" --unit "$WORK/u-fp.md" | python3 -c "import json,sys;print(json.load(sys.stdin)['tier'])")
[ "$T" = "minimal" ] && pass "vocab word-boundary: 'aksesibilitas' does not fire 'akses'" || fail "fp tier=$T"

# ── 2. OQ prose pins ─────────────────────────────────────────────────────────
RO="$P/skills/resolve-oq"
grep -qF 'express-batched' "$RO/SKILL.md" && grep -qF 'ceil(N/4)' "$RO/SKILL.md" \
  && pass "SKILL: express-batched scope + chunking rule" || fail "batched scope missing"
grep -qF 'auto-deferred (P<n>, express)' "$RO/SKILL.md" \
  && pass "SKILL: mechanical defer reason format" || fail "defer reason missing"
grep -qF 'A standalone/explicit invocation (any spine) and every classic-spine invocation keep the fully interactive walk' "$RO/SKILL.md" \
  && pass "SKILL: interactive walk preserved outside the express chain" || fail "rail re-scope missing"
grep -qF 'this rail governs ANSWERS' "$RO/SKILL.md" \
  && pass "SKILL: refuse-rail scoped to answers (defer invents nothing)" || fail "refuse-rail scope missing"
grep -qF 'Express-batched variant' "$RO/references/interactive-walk.md" \
  && pass "walk: batched variant (same grammar, fewer round trips)" || fail "walk variant missing"
grep -qF 'ALWAYS stay interactive on the BLOCKING tier' "$RO/references/auto-memory-handoff.md" \
  && pass "handoff ref: substance-prompt rail re-scoped" || fail "handoff rail missing"
grep -qF 'ID LIST, never a bare count' "$RO/references/auto-memory-handoff.md" \
  && pass "metrics.items_deferred is an id list (a count cannot re-surface)" || fail "metrics id list missing"

# A6 surfaces
grep -qF '## Deferred open questions (N)' "$P/skills/execute-bolts/references/halts-and-handoff.md" \
  && pass "_summary.md gains the deferred-OQ section" || fail "_summary section missing"
grep -qF 'Deferred open questions (P3/A6)' "$P/skills/orchestrate-flow/references/chain-execution.md" \
  && pass "--deep appendix carries the deferred-OQ bullet" || fail "appendix bullet missing"
grep -qF 'Deferred-OQ resurface (P3/A6, ALWAYS' "$P/skills/orchestrate-flow/SKILL.md" \
  && pass "Step 9 resurfaces deferred OQs (deep or not)" || fail "Step 9 line missing"

# ── 3. Risk-router wiring + lean default ─────────────────────────────────────
grep -qF 'resolve-review-tier.sh' "$P/skills/execute-bolts/references/review-panel.md" \
  && pass "review-panel routes tier via the script (A5)" || fail "router not wired"
grep -qF 'signals_fired' "$P/skills/execute-bolts/references/superpowers-bridge.md" \
  && pass "bolt-report requires signals_fired (audit trail)" || fail "audit trail missing"
grep -qE 'minimal.*task_type: verify.*OR' "$P/skills/execute-bolts/references/review-panel.md" \
  && pass "minimal predicate rewritten (reachable)" || fail "predicate not rewritten"
grep -qF 'unknown rc is never a LOW tier' "$P/skills/execute-bolts/references/review-panel.md" \
  && pass "router fallback = standard on unknown rc" || fail "rc fallback missing"

OF="$P/skills/orchestrate-flow/SKILL.md"
grep -qF 'Diagnostics are LEAN-BY-DEFAULT on the express spine (P3)' "$OF" \
  && pass "diagnostics lean-by-default under express" || fail "lean default missing"
grep -qF 'The advisor legs stay DEFAULT-ON on every spine' "$OF" \
  && pass "advisor stays default-on (rail 1 over the cut table — stated deviation)" || fail "advisor deviation missing"
grep -qF 'spine:' "$P/hooks/stop" && grep -qF 'profile:[[:space:]]*[\"'"'"']?full' "$P/hooks/stop" \
  && pass "Stop aggregate keyed to classic|full opt-in" || fail "stop condition missing"
grep -qF 'HONESTY NOTE (P3)' "$P/scripts/_lib/state_probes.py" \
  && pass "pending_p0_p1 docstring honesty (no P0 exists)" || fail "docstring note missing"
grep -qF 'spine: express' "$P/references/project-config.md" \
  && pass "project-config documents spine + profile semantics" || fail "config doc missing"

echo
if [ "$fails" -eq 0 ]; then echo "test-p3-oq-defer-risk-router: ALL PASS"; exit 0
else echo "test-p3-oq-defer-risk-router: $fails FAILURE(S)"; exit 1; fi

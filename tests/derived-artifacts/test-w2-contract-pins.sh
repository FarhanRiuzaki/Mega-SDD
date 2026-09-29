#!/usr/bin/env bash
# test-w2-contract-pins.sh — W-batch W2 (spec 2026-07-19-w-batch-script-derive.md):
# binding.json is script-derived from binding.md — doc/skill contract pins.
#
# 9.0 P1 (spec 2026-09-27-v9-simplification-design.md): bind-codebase is gone.
# binding.md survives only as the layout-2 artifact (read support + the
# resolve-oq --binding layout-2 leg). §7 decision #10: the layout-2 binding
# grammar is owned by the code (scripts/_lib/binding_md.py); the bind templates
# (binding-md-template.md, binding-json-schema.md) were not relocated.
#
#   P1  RETIRED 9.0 — pinned bind-codebase SKILL.md Step 4.5 (the whole-vault
#       bind that wrote binding.md). The skill is deleted; no mega-sdd phase
#       authors binding.md any more (derive-binding-json.sh dropped its
#       "fix the Step-4 write" posture in the same change).
#   P2  the three grammar obligations — binding_metadata `head:`, the
#       `[reason:` Anchor-cell token (closed enum), the `- **Claim**:`
#       conflict-block line — plus 6-columns-always (the token lives INSIDE the
#       Anchor cell). Repointed 9.0 from binding-md-template.md to the grammar
#       owner _lib/binding_md.py, pinned on its PARSE BEHAVIOUR (not comments)
#   P3  binding-mode re-derives via derive-binding-json.sh; the hand-patch-json
#       instruction ("set the claim's `resolution:`") is gone; derive-binding-json
#       is named the single binding.json writer (no separate parity re-run)
#   P4  binding.json schema: generated_by = derive-binding-json@1.0.0, schema
#       stays "1.0", the resolution enum is KEEP_VAULT|KEEP_CODE|DEFER|SPLIT|null.
#       Repointed 9.0 from binding-json-schema.md to the derived output (P6's
#       pair) + binding_md.RESOLUTION_ACTIONS. The 'bind-time authoring
#       obligation' pin is RETIRED (it described the deleted bind skill's
#       Anchor-authoring duty).
#   P5  _lib/binding_md.py exists; the generator imports it (one grammar,
#       never forked)
#   P6  empirical: derive on the plugin round-trip fixture exits 0 (top-level
#       CI exercises the shared lib; P4 reads the derived binding.json)
#   P7  tests/god-review-s4/test-4d-contract-truth.sh still exits 0 (all its
#       string + empirical pins survive W2)
#
# 9.0 P1b: validate-binding-json.sh was deleted (its only executor, make-bound.sh,
# left with bind-codebase). Its halves of P5/P6 went with it; P3 pins the
# reworded binding-mode posture (derive-binding-json is the single writer).
#
# Run: bash tests/derived-artifacts/test-w2-contract-pins.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
BM="${P}/skills/resolve-oq/references/binding-mode.md"
LIBDIR="${P}/scripts/_lib"
LIB="${LIBDIR}/binding_md.py"
DERIVE="${P}/scripts/derive-binding-json.sh"
FX="${P}/tests/graph/fixtures/derive-full"
for f in "$BM" "$DERIVE"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w2pins)"
trap 'rm -rf "$WORK"' EXIT

# py_lib <label-ok> <label-fail> — runs the stdin python with binding_md importable
py_lib() {
  if python3 - "$LIBDIR" >/dev/null 2>&1; then ok "$1"; else fail "$2"; fi
}

echo "== W2 contract pins: binding.json is derived, never re-typed =="

# ── P1: RETIRED 9.0 (bind-codebase SKILL.md deleted — see header) ──

# ── P2: layout-2 grammar, owned by _lib/binding_md.py (§7 decision #10) ──
py_lib "P2: ALWAYS 6 columns — [reason:] token rides INSIDE the Anchor cell; a 5-cell row is malformed" \
       "P2: 6-column State Map grammar lost (token not in Anchor cell, or short row accepted)" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import binding_md as b
md = ("## Implementation State Map (1)\n"
      "| Claim ID | Verdict | State | Anchor | Confidence | Field diff |\n"
      "|---|---|---|---|---|---|\n"
      "| C-044 | CONFIRMED | UNKNOWN | map capped [reason: truncated_section] | low | n/a |\n")
errs = []; rows = b.parse_state_map(md, errs, full=True)
r = rows.get("C-044", {})
assert not errs and r.get("anchor_cell", "").endswith("[reason: truncated_section]") and r.get("field_diff") == "n/a"
short = "## Implementation State Map (1)\n|---|---|---|---|---|---|\n| C-002 | CONFIRMED | NEW | — | n/a |\n"
errs = []; rows = b.parse_state_map(short, errs, full=True)
assert "C-002" not in rows and any("need 6" in e for e in errs)
PY
py_lib "P2: [reason: <enum>] Anchor-cell token grammar present" \
       "P2: reason-token grammar missing" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import binding_md as b
m = b.REASON_TOKEN_RE.search("app/X.php:9 [reason: kb_confirmed]")
assert m and m.group(1) == "kb_confirmed"
assert b.REASON_TOKEN_RE.search("app/X.php:9") is None
PY
py_lib "P2: closed state_reason enum spelled out" \
       "P2: closed enum incomplete" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import binding_md as b
assert isinstance(b.STATE_REASON_ENUM, tuple)
assert "truncated_section" in b.STATE_REASON_ENUM and "kb_confirmed" in b.STATE_REASON_ENUM
PY
py_lib "P2: '- **Claim**:' conflict-block line present" \
       "P2: Claim-line grammar missing" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import binding_md as b
m = b.CLAIM_LINE_RE.search("### CONFLICT-1 — x\n- **Claim**: C-051\n- **Verdict**: CONFLICT (BLOCKING)\n")
assert m and m.group(1) == "C-051"
PY
py_lib "P2: binding_metadata head: field present" \
       "P2: head: frontmatter field missing" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import binding_md as b
md = "---\nvault: v1\nbinding_metadata:\n  codebase_map_provenance: snapshot-verified\n  head: abc123def456\n---\n# Binding Manifest\n"
assert b.parse_frontmatter_metadata(md)["head"] == "abc123def456"
PY

# ── P3: binding-mode write-back ──
grep -qF 'derive-binding-json.sh' "$BM" && ok "P3: binding-mode re-derives binding.json via the script" || fail "P3: re-derive instruction missing"
if grep -qF "set the claim's" "$BM"; then fail "P3: hand-patch-json instruction survives"; else ok "P3: hand-patch-json instruction gone"; fi
grep -qF -- '- **Claim**: C-NNN' "$BM" && ok "P3: write-back ensures the Claim line (legacy self-heal)" || fail "P3: Claim-line self-heal missing"
grep -qF '`derive-binding-json.sh` is the single binding.json writer; there is no separate parity re-run' "$BM" && ok "P3: derive-binding-json named the single writer (no post-derive parity re-run)" || fail "P3: single-writer posture missing"

# ── P5: shared lib, imported by the generator ──
[ -f "$LIB" ] && ok "P5: scripts/_lib/binding_md.py exists" || fail "P5: binding_md.py missing"
# anchored to REAL import statements — the bare 'binding_md' token also lives
# in header comments, so a grammar fork that keeps the comment would pass
grep -qE '(^|[[:space:]])(from binding_md import|import binding_md)' "$DERIVE" \
  && ok "P5: generator imports the shared parser (import statement, not a comment)" \
  || fail "P5: generator does not IMPORT binding_md (comment-only reference?)"
# (P5 removed v7 Fase 2 — validate-conflict-classification.sh deleted.)

# ── P6: empirical — top-level CI exercises the shared lib ──
V="$WORK/v1"; mkdir -p "$V"
cp "$FX/binding.md" "$V/binding.md"
bash "$DERIVE" --vault "$V" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "P6: derive green on the round-trip fixture" || fail "P6: derive failed on the round-trip fixture (rc=$RC)"

# ── P4: schema pins — on the derived output of P6 (the schema doc was not relocated) ──
jq_py() {  # <python-expr over d> — evaluates against P6's derived binding.json
  python3 - "$V/binding.json" "$1" <<'PY' >/dev/null 2>&1
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
}
jq_py 'd.get("generated_by") == "derive-binding-json@1.0.0"' \
  && ok "P4: generated_by = derive-binding-json@1.0.0" || fail "P4: generated_by provenance stale"
jq_py 'd.get("schema_version") == "1.0"' \
  && ok "P4: schema_version stays 1.0 (key set unchanged)" || fail "P4: schema_version drifted"
python3 - "$LIBDIR" "$V/binding.json" >/dev/null 2>&1 <<'PY' \
  && ok "P4: resolution enum = KEEP_VAULT | KEEP_CODE | DEFER | SPLIT | null (4D pin)" \
  || fail "P4: resolution enum drifted"
import json, sys; sys.path.insert(0, sys.argv[1]); import binding_md as b
enum = ("KEEP_VAULT", "KEEP_CODE", "DEFER", "SPLIT")
assert tuple(b.RESOLUTION_ACTIONS) == enum
claims = json.load(open(sys.argv[2], encoding="utf-8"))["claims"]
assert claims and all("resolution" in c and c["resolution"] in enum + (None,) for c in claims)
assert {c["id"]: c["resolution"] for c in claims}.get("C-051") == "KEEP_VAULT"
PY
# ('bind-time authoring obligation' RETIRED 9.0 — bind-codebase deleted.)

# ── P7: 4D contract-truth suite survives W2 ──
if bash "${ROOT}/tests/god-review-s4/test-4d-contract-truth.sh" </dev/null >/dev/null 2>&1; then
  ok "P7: test-4d-contract-truth.sh still exits 0"
else
  fail "P7: 4D contract pins broken by W2"
fi

if [ "$FAILED" -eq 0 ]; then echo "ALL W2 PINS OK"; exit 0; else echo "W2 pins FAILED"; exit 1; fi

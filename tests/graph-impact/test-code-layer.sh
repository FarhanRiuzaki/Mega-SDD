#!/usr/bin/env bash
# test-code-layer.sh — pins the v6.20.0 graph code layer (spec
# docs/superpowers/specs/2026-08-21-graph-code-layer.md): reuse-index.yaml
# symbols become queryable nodes, purpose_confidence is non-strippable,
# truncation is visible, and the cross-layer join (symbol -> code_anchor <- unit
# / claim) actually lands on ONE node id. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
BUILD="$P/scripts/build-graph.sh"
QUERY="$P/scripts/query-graph.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PRJ="$WORK/prj"
MS="$PRJ/.mega-sdd"
mkdir -p "$MS/codebase" "$MS/vaults/app/units"

# ── Fixture: the scan's function map ─────────────────────────────────────────
# Inline flow mappings with commas INSIDE quoted signatures — the shape the real
# scan emits, and the shape a naive comma-split would shred.
cat > "$MS/codebase/reuse-index.yaml" <<'YAML'
reuse_index:
  helpers:
    - { signature: "format_number($number, int $decimals = 0): string", purpose: "Format number with separators", purpose_confidence: stated, _source: "app/Helpers/format.php:21" }
    - { signature: "is_admin(): bool", purpose: "Check admin role", purpose_confidence: inferred, _source: "app/Helpers/auth.php:49" }
  services:
    - { class: "Recon/MatchingEngine", signature: "static executeMatching(ReconJob $job): array", purpose: "Execute matching strategies", purpose_confidence: inferred, _source: "app/Services/Matching.php:54" }
  commands:
    - { signature: "role:assign {role} {username}", purpose: "Assign role to user", purpose_confidence: stated, _source: "app/Console/AssignRole.php:10" }
  truncated: {}
YAML

# Vault side: a claim anchored at the SAME file a symbol lives in (join proof),
# and a unit whose target_files use inline flow mappings.
cat > "$MS/vaults/app/vault.json" <<'JSON'
{"flows": [{"id": "F-1", "title": "Matching", "doc": "04-flows.md"}]}
JSON
cat > "$MS/vaults/app/binding.json" <<'JSON'
{"claims": [{"id": "C-1", "verdict": "CONFIRMED", "anchor": "app/Services/Matching.php:54"}]}
JSON
cat > "$MS/vaults/app/units/U-001.md" <<'MD'
---
unit_id: U-001
task_type: verify
target_files:
  - { path: app/Services/Matching.php, operation: modify }
  - { path: app/Helpers/format.php, operation: create }
  - { path: docs/untouched.md, operation: none }
---
# U-001
MD

build() { bash "$BUILD" --root "$PRJ" >/dev/null 2>&1; }
jq_() { python3 -c "$1" "$MS/graph.json"; }

# ── 1. symbols land, from every category ─────────────────────────────────────
build
N=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="symbol"))')
[ "$N" = "4" ] && ok "4 symbol nodes (all categories)" || fail "symbol count: want 4, got $N"

CATS=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(",".join(sorted({n["attrs"]["category"] for n in g["nodes"] if n["type"]=="symbol"})))')
[ "$CATS" = "commands,helpers,services" ] && ok "categories carried: $CATS" || fail "categories: $CATS"

# Quoted commas must not split the mapping — the signature survives whole.
SIG=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print([n["attrs"]["signature"] for n in g["nodes"] if n["id"].endswith("#format_number")][0])')
[ "$SIG" = 'format_number($number, int $decimals = 0): string' ] && ok "quoted comma preserved in signature" || fail "signature shredded: $SIG"

# ── 2. purpose_confidence is non-strippable ──────────────────────────────────
MISS=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="symbol" and not n["attrs"].get("purpose_confidence")))')
[ "$MISS" = "0" ] && ok "every symbol carries purpose_confidence" || fail "$MISS symbol(s) without purpose_confidence"
CONF=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print([n["attrs"]["purpose_confidence"] for n in g["nodes"] if n["id"].endswith("#is_admin")][0])')
[ "$CONF" = "inferred" ] && ok "inferred purpose keeps its marker" || fail "confidence: $CONF"

# defined_in confidence mirrors the marker (stated -> VERIFIED, inferred -> INFERRED)
EC=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(",".join(sorted({e["confidence"] for e in g["edges"] if e["relation"]=="defined_in"})))')
[ "$EC" = "INFERRED,VERIFIED" ] && ok "defined_in confidence mirrors the marker" || fail "edge confidence: $EC"

# ── 3. name extraction: callable vs console signature ────────────────────────
IDS=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(",".join(sorted(n["id"] for n in g["nodes"] if n["type"]=="symbol")))')
case "$IDS" in
  *"sym:app/Console/AssignRole.php#role:assign,"*) ok "console signature -> first token" ;;
  *) fail "console id wrong: $IDS" ;;
esac
case "$IDS" in
  *"sym:app/Services/Matching.php#executeMatching"*) ok "modifier dropped (static ... -> executeMatching)" ;;
  *) fail "callable id wrong: $IDS" ;;
esac

# ── 4. id is line-independent (delta-by-sha would churn otherwise) ───────────
BEFORE="$IDS"
sed -i.bak 's#app/Helpers/auth.php:49#app/Helpers/auth.php:77#' "$MS/codebase/reuse-index.yaml"
build
AFTER=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(",".join(sorted(n["id"] for n in g["nodes"] if n["type"]=="symbol")))')
[ "$BEFORE" = "$AFTER" ] && ok "symbol ids stable under a line shift" || fail "ids churned on line shift"
LINE=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print([n["attrs"]["line"] for n in g["nodes"] if n["id"].endswith("#is_admin")][0])')
[ "$LINE" = "77" ] && ok "line attr still tracks the move" || fail "line attr: $LINE"
mv "$MS/codebase/reuse-index.yaml.bak" "$MS/codebase/reuse-index.yaml"
build

# ── 5. THE JOIN: symbol -> code_anchor <- claim AND <- unit, one node id ─────
JOIN=$(jq_ '
import json,sys
g=json.load(open(sys.argv[1]))
d={e["target"] for e in g["edges"] if e["relation"]=="defined_in"}
i={e["target"] for e in g["edges"] if e["relation"]=="implements"}
t={e["target"] for e in g["edges"] if e["relation"]=="touches"}
print("app/Services/Matching.php" in (d & i & t))')
[ "$JOIN" = "True" ] && ok "cross-layer join lands on ONE code_anchor id" || fail "join broken (symbol/claim/unit anchors diverged)"

# ── 6. touches: shapes + operation:none skipped ──────────────────────────────
TN=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for e in g["edges"] if e["relation"]=="touches"))')
[ "$TN" = "2" ] && ok "touches edges emitted, operation:none skipped" || fail "touches count: want 2, got $TN"
OP=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print([e.get("operation") for e in g["edges"] if e["relation"]=="touches" and e["target"]=="app/Helpers/format.php"][0])')
[ "$OP" = "create" ] && ok "operation carried on the edge" || fail "operation: $OP"
NONE=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(any(e["target"]=="docs/untouched.md" for e in g["edges"]))')
[ "$NONE" = "False" ] && ok "operation:none never becomes an edge" || fail "operation:none leaked an edge"

# Same fixture through the hand-rolled YAML fallback (the LIVE parser wherever
# PyYAML is absent — the shape difference there is exactly what silently
# emptied this layer before).
MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$BUILD" --root "$PRJ" >/dev/null 2>&1
TNF=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for e in g["edges"] if e["relation"]=="touches"))')
SNF=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="symbol"))')
{ [ "$TNF" = "2" ] && [ "$SNF" = "4" ]; } && ok "identical under YAML fallback (symbols=$SNF touches=$TNF)" \
  || fail "fallback parse diverged: symbols=$SNF touches=$TNF"
build

# ── 7. truncation is visible ─────────────────────────────────────────────────
T=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(g["_meta"]["code_layer"]["truncated"])')
[ "$T" = "False" ] && ok "truncated false when the scan capped nothing" || fail "truncated: $T"
sed -i.bak 's#truncated: {}#truncated: { services: 12 }#' "$MS/codebase/reuse-index.yaml"
build
T=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(g["_meta"]["code_layer"]["truncated"])')
[ "$T" = "True" ] && ok "truncated surfaces when a category was capped" || fail "capped scan reported truncated=$T"
mv "$MS/codebase/reuse-index.yaml.bak" "$MS/codebase/reuse-index.yaml"
build

# ── 8. id-only flows must degrade, never abort the build (regression) ────────
cp "$MS/vaults/app/vault.json" "$WORK/vault.bak"
echo '{"flows": ["F-1", "F-2"]}' > "$MS/vaults/app/vault.json"
if bash "$BUILD" --root "$PRJ" >/dev/null 2>&1; then
  FN=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="flow"))')
  S=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="symbol"))')
  { [ "$FN" = "2" ] && [ "$S" = "4" ]; } && ok "id-only flows degrade; other layers survive" \
    || fail "id-only flows: flows=$FN symbols=$S"
else
  fail "id-only flows aborted the whole build (pre-v6.20.0 crash)"
fi
cp "$WORK/vault.bak" "$MS/vaults/app/vault.json"
build

# ── 9. a builder version bump forces one rebuild (else old graphs stay blind) ─
python3 - "$MS/graph.json" <<'PY'
import json,sys
p=sys.argv[1]; g=json.load(open(p))
g["_meta"]["generated_by"]="build-graph@1.0.0"        # pretend it is an old graph
g["nodes"]=[]; g["edges"]=[]                          # ...with no code layer
json.dump(g, open(p,"w"))
PY
bash "$QUERY" --root "$PRJ" --impact "app/Services/Matching.php" >/dev/null 2>&1
V=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(g["_meta"]["generated_by"])')
S=$(jq_ 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="symbol"))')
{ [ "$V" != "build-graph@1.0.0" ] && [ "$S" = "4" ]; } && ok "stale-builder graph rebuilt on query ($V)" \
  || fail "old graph stayed layer-blind: generated_by=$V symbols=$S"

# ── 10. the OTHER reuse-index shape (references/reuse-index-schema.md) ───────
# Two shapes exist in the wild: what deep-scan emits (nested under `reuse_index:`,
# inline flow entries, `_source`) and what the schema documents (top-level
# categories, block entries, `path` + `line`, top-level `truncated`). A parser
# that reads only one silently produces an EMPTY code layer on the other.
PRJ2="$WORK/prj2"; MS2="$PRJ2/.mega-sdd"
mkdir -p "$MS2/codebase"
cat > "$MS2/codebase/reuse-index.yaml" <<'YAML'
schema_version: "1.0"
generated_from: "abc123"
truncated: { helpers: false, services: true }

helpers:
  - name: format_currency
    kind: global_helper
    path: app/Helpers/money.php
    line: 21
    signature: "format_currency(int $amount, string $currency = 'IDR'): string"
    purpose: "Format minor-units into a currency string"
    purpose_confidence: stated
services:
  - name: reconcile
    path: app/Services/Recon.php
    signature: "reconcile(Job $j): array"
    purpose: "Run reconciliation"
    purpose_confidence: inferred
YAML
bash "$BUILD" --root "$PRJ2" >/dev/null 2>&1
S2=$(python3 -c 'import json,sys; g=json.load(open(sys.argv[1])); print(sum(1 for n in g["nodes"] if n["type"]=="symbol"))' "$MS2/graph.json")
[ "$S2" = "2" ] && ok "schema-shape reuse-index parses (block entries + path anchor)" || fail "schema shape: symbols=$S2"
L2=$(python3 -c 'import json,sys; g=json.load(open(sys.argv[1])); print([n["attrs"].get("line") for n in g["nodes"] if n["id"].endswith("#format_currency")][0])' "$MS2/graph.json")
[ "$L2" = "21" ] && ok "separate line: field honored as the anchor line" || fail "line: $L2"
T2=$(python3 -c 'import json,sys; g=json.load(open(sys.argv[1])); print(g["_meta"]["code_layer"]["truncated"])' "$MS2/graph.json")
[ "$T2" = "True" ] && ok "top-level truncated map read (services: true)" || fail "schema-shape truncated: $T2"
# `false` values must NOT read as truncated — that is the normal, complete case
python3 - "$MS2/codebase/reuse-index.yaml" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("services: true", "services: false"))
PY
bash "$BUILD" --root "$PRJ2" >/dev/null 2>&1
T3=$(python3 -c 'import json,sys; g=json.load(open(sys.argv[1])); print(g["_meta"]["code_layer"]["truncated"])' "$MS2/graph.json")
[ "$T3" = "False" ] && ok "all-false truncated map is not a truncation" || fail "false read as truncated: $T3"

echo
echo "code-layer: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]

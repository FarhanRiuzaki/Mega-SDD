#!/usr/bin/env bash
# test-sync-intersect.sh — pins the S4 sync claim-intersection short-circuit
# (spec 2026-08-11-audit-phase2b-scripts-and-owners.md §S4): empty intersection
# -> exit 0 in_sync; anchor/unit-target hit -> exit 4 reconcile_needed;
# unreadable binding.json / missing vault -> exit 2 FAIL-CLOSED (full chain);
# ancestor-dir containment counts as intersecting.
# Run: bash tests/sync/test-sync-intersect.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
SI="plugins/mega-sdd/scripts/sync-intersect.sh"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── fixture: repo root + vault with binding.json + one unit ──
ROOT="$TMP/repo"
VAULT="$ROOT/.mega-sdd/vaults/fixture"
mkdir -p "$VAULT/units"
cat > "$VAULT/binding.json" <<'EOF'
{
  "schema_version": "1.0",
  "generated_by": "derive-binding-json@1.0.0",
  "generated_at": "2026-08-11T00:00:00Z",
  "vault": ".mega-sdd/vaults/fixture",
  "codebase_map_provenance": "snapshot-verified",
  "head": "0000000",
  "claims": [
    {"id": "C-001", "verdict": "CONFIRMED", "state": "IMPLEMENTED",
     "anchor": "src/a.php:45 + routes/api.php:12", "confidence": "high",
     "field_diff": "(exact match)", "vault_source": "03-data-model.md:42",
     "state_reason": null, "resolution": null},
    {"id": "C-002", "verdict": "CONFIRMED", "state": "IMPLEMENTED",
     "anchor": "src/lib", "confidence": "medium",
     "field_diff": "n/a", "vault_source": null,
     "state_reason": null, "resolution": null},
    {"id": "C-003", "verdict": "OQ", "state": null,
     "anchor": null, "confidence": null, "field_diff": "n/a",
     "vault_source": null, "state_reason": null, "resolution": null}
  ]
}
EOF
cat > "$VAULT/units/U-001-fixture.md" <<'EOF'
---
unit_id: U-001
title: Fixture unit
task_type: extend
target_files:
  - path: src/b.php
    operation: modify
vault_source: 03-data-model.md:42
vault_anchors: []
---

# U-001 — Fixture unit
EOF

run() { out="$(bash "$SI" "$@" 2>&1)"; code=$?; }

# ── (a) changed=[docs/readme.md] → exit 0 in_sync ──
run --cwd="$ROOT" --vault="$VAULT" --paths=docs/readme.md
if [ "$code" -eq 0 ] && echo "$out" | grep -qF '"verdict": "in_sync"' \
   && echo "$out" | grep -qF '"intersecting": 0'; then
  pass "(a) non-intersecting change -> exit 0 in_sync"
else fail "(a) expected exit 0 in_sync, got exit $code: $out"; fi

# ── (b) changed=[src/a.php] → exit 4, intersect_paths lists it (anchor) ──
run --cwd="$ROOT" --vault="$VAULT" --paths=src/a.php
if [ "$code" -eq 4 ] && echo "$out" | grep -qF '"verdict": "reconcile_needed"' \
   && echo "$out" | grep -qF '"src/a.php"'; then
  pass "(b) binding-anchor hit -> exit 4 with src/a.php in intersect_paths"
else fail "(b) expected exit 4 listing src/a.php, got exit $code: $out"; fi

# ── (c) changed=[src/b.php] → exit 4 (unit target_files) ──
run --cwd="$ROOT" --vault="$VAULT" --paths=src/b.php
if [ "$code" -eq 4 ] && echo "$out" | grep -qF '"src/b.php"'; then
  pass "(c) unit target_files hit -> exit 4"
else fail "(c) expected exit 4 on unit target src/b.php, got exit $code: $out"; fi

# ── (b2) @file path-list form: same anchor hit through the file channel ──
printf 'docs/other.md\nsrc/a.php\n' > "$TMP/changed.txt"
run --cwd="$ROOT" --vault="$VAULT" --paths=@"$TMP/changed.txt"
if [ "$code" -eq 4 ] && echo "$out" | grep -qF '"changed": 2' \
   && echo "$out" | grep -qF '"intersecting": 1'; then
  pass "(b2) @file changed-set form -> exit 4, counts 2 changed / 1 intersecting"
else fail "(b2) expected exit 4 (2 changed, 1 intersecting) via @file, got exit $code: $out"; fi

# ── (d) broken binding.json (invalid JSON) → exit 2 fail-closed ──
BROKEN="$TMP/broken-vault"
mkdir -p "$BROKEN/units"
echo '{ not json ]' > "$BROKEN/binding.json"
run --cwd="$ROOT" --vault="$BROKEN" --paths=docs/readme.md
if [ "$code" -eq 2 ] && echo "$out" | grep -qi "fail-closed"; then
  pass "(d) invalid binding.json -> exit 2 fail-closed (never in_sync)"
else fail "(d) expected exit 2 fail-closed on broken binding.json, got exit $code: $out"; fi

# ── (e) missing vault dir → exit 2 fail-closed ──
run --cwd="$ROOT" --vault="$TMP/no-such-vault" --paths=docs/readme.md
if [ "$code" -eq 2 ]; then
  pass "(e) missing vault dir -> exit 2 fail-closed"
else fail "(e) expected exit 2 on missing vault, got exit $code: $out"; fi

# ── (f) changed file UNDER an anchored dir → exit 4 (ancestor match) ──
run --cwd="$ROOT" --vault="$VAULT" --paths=src/lib/deep/helper.php
if [ "$code" -eq 4 ] && echo "$out" | grep -qF '"src/lib/deep/helper.php"'; then
  pass "(f) change under anchored dir src/lib -> exit 4 (ancestor match)"
else fail "(f) expected exit 4 ancestor match under src/lib, got exit $code: $out"; fi

# ── (g) malformed unit frontmatter → exit 2 fail-closed ──
MAL="$TMP/mal-vault"
mkdir -p "$MAL/units"
cp "$VAULT/binding.json" "$MAL/binding.json"
printf '# no frontmatter here\n' > "$MAL/units/U-001-broken.md"
run --cwd="$ROOT" --vault="$MAL" --paths=docs/readme.md
if [ "$code" -eq 2 ] && echo "$out" | grep -qi "frontmatter"; then
  pass "(g) unit without frontmatter -> exit 2 fail-closed"
else fail "(g) expected exit 2 on malformed unit frontmatter, got exit $code: $out"; fi

# ── fixture: slash-less anchors (canonical schema shape) + a prose piece ──
BN="$TMP/bn-vault"
mkdir -p "$BN/units"
cat > "$BN/binding.json" <<'EOF'
{
  "schema_version": "1.0",
  "claims": [
    {"id": "C-101", "verdict": "CONFIRMED", "state": "IMPLEMENTED",
     "anchor": "UserController.php:45", "confidence": "high"},
    {"id": "C-102", "verdict": "CONFIRMED", "state": "IMPLEMENTED",
     "anchor": "App.tsx:12", "confidence": "high"},
    {"id": "C-103", "verdict": "CONFIRMED", "state": "IMPLEMENTED",
     "anchor": "verified against spec", "confidence": "low"}
  ]
}
EOF

# ── (h) slash-less anchor piece matches the changed path by BASENAME ──
run --cwd="$ROOT" --vault="$BN" --paths=app/Http/Controllers/UserController.php
if [ "$code" -eq 4 ] && echo "$out" | grep -qF '"app/Http/Controllers/UserController.php"'; then
  pass "(h) anchor UserController.php:45 basename-matches the changed path -> exit 4"
else fail "(h) expected exit 4 basename match, got exit $code: $out"; fi

# ── (i) widened file-like filter: .tsx (outside the old code-ext whitelist) ──
run --cwd="$ROOT" --vault="$BN" --paths=src/components/App.tsx
if [ "$code" -eq 4 ] && echo "$out" | grep -qF '"src/components/App.tsx"'; then
  pass "(i) anchor App.tsx:12 basename-matches src/components/App.tsx -> exit 4"
else fail "(i) expected exit 4 on App.tsx, got exit $code: $out"; fi

# ── (j) prose-word anchor piece stays dropped -> in_sync when nothing else intersects ──
run --cwd="$ROOT" --vault="$BN" --paths=docs/notes.md
if [ "$code" -eq 0 ] && echo "$out" | grep -qF '"verdict": "in_sync"' \
   && echo "$out" | grep -qF '"intersecting": 0'; then
  pass "(j) prose anchor piece (verified against spec) dropped -> in_sync"
else fail "(j) expected exit 0 in_sync with prose-only leftover, got exit $code: $out"; fi

echo
if [ "$rc" -eq 0 ]; then echo "test-sync-intersect: ALL PASS"; else echo "test-sync-intersect: FAILURES"; fi
exit "$rc"

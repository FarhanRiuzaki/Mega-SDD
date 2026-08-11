#!/usr/bin/env bash
# Delta lane (spec 2026-08-11-free-text-delta-lane.md §D2/§Proof) —
# derive-delta-paths.sh: touched VAULT-DIFF docs -> affected claims' anchor
# paths -> <vault>/.delta-changed-paths.txt; fail-closed edges; mutation arm.
# Run: bash tests/delta-lane/test-derive-delta-paths.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$here/../.."
SCRIPT="$ROOT/plugins/mega-sdd/scripts/derive-delta-paths.sh"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
V="$T/vault"; mkdir -p "$V"

mk_binding() {
  cat > "$V/binding.json" <<'EOF'
{"claims": [
 {"id": "C-001", "verdict": "CONFIRMED", "vault_source": "03-data-model.md:42",
  "anchor": "app/Models/Nasabah.php:12 + database/migrations/2026_create_nasabah.php:8"},
 {"id": "C-002", "verdict": "CONFIRMED", "vault_source": "04-flows.md:30",
  "anchor": "NasabahController.php:45"},
 {"id": "C-003", "verdict": "CONFIRMED", "vault_source": "05-decisions.md:10",
  "anchor": "app/Services/Untouched.php:5"},
 {"id": "C-004", "verdict": "OQ", "vault_source": "03-data-model.md:60", "anchor": "—"}
]}
EOF
}

mk_diff() {
  cat > "$V/VAULT-DIFF.md" <<'EOF'
# Vault Diff Report

**New source**: chat brief (--from-prompt)

## Summary

- **Added**: 1 / 0 / 0 / 0

## Added entities / flows / decisions

### Entity (added): `npwp`

**Action on apply**: append to `03-data-model.md` Entities section.

## Changed entities / flows / decisions

### Flow F-U-001 — changed

**Action on apply**: update the node in `04-flows.md`.

## Unchanged sections (no action needed)

- `05-decisions.md` unchanged
EOF
}

# ── (a) touched-section claims -> anchor paths, sorted/deduped; basename lane ──
mk_binding; mk_diff
OUT="$(bash "$SCRIPT" --vault="$V" --cwd="$T" 2>&1)"; RC=$?
PF="$V/.delta-changed-paths.txt"
if [ $RC -eq 0 ] && [ -f "$PF" ] \
   && grep -qx 'app/Models/Nasabah.php' "$PF" \
   && grep -qx 'database/migrations/2026_create_nasabah.php' "$PF" \
   && grep -qx 'NasabahController.php' "$PF"; then
  pass "a: touched docs (03,04) -> both anchors of C-001 + basename anchor of C-002 land in .delta-changed-paths.txt"
else fail "a: expected anchor paths missing (rc=$RC, out=$OUT, file: $(cat "$PF" 2>/dev/null | tr '\n' ' '))"; fi
sort -c "$PF" 2>/dev/null && pass "a2: paths file sorted" || fail "a2: paths file not sorted"

# ── (b) untouched claims contribute nothing (05-decisions only in Unchanged) ──
grep -qx 'app/Services/Untouched.php' "$PF" \
  && fail "b: untouched doc's claim leaked into the paths file" \
  || pass "b: C-003 (05-decisions.md — Unchanged section only) contributes no path"

# ── (c) OQ/null-anchor rows are path-silent but counted ──
echo "$OUT" | grep -q '"anchorless_claims": 1' \
  && pass "c: anchor-less affected claim (C-004, '—') counted anchorless, no path" \
  || fail "c: anchorless accounting wrong (out=$OUT)"

# ── (d) no binding.json -> exit 3 (unbound vault, normal chain) ──
rm "$V/binding.json"
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
[ $RC -eq 3 ] && pass "d: no binding.json -> exit 3 (caller proposes the normal chain)" \
             || fail "d: expected exit 3, got $RC"
mk_binding

# ── (e) corrupt inputs -> exit 2 fail-closed ──
echo '{broken' > "$V/binding.json"
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
[ $RC -eq 2 ] && pass "e1: malformed binding.json -> exit 2 FAIL-CLOSED (full re-bind)" \
             || fail "e1: expected exit 2, got $RC"
mk_binding; rm "$V/VAULT-DIFF.md"
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
[ $RC -eq 2 ] && pass "e2: missing VAULT-DIFF.md -> exit 2 FAIL-CLOSED" \
             || fail "e2: expected exit 2, got $RC"
mk_diff
printf '# Vault Diff Report\n\n## Summary\n\nno doc literals here\n' > "$V/VAULT-DIFF.md"
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
[ $RC -eq 2 ] && pass "e3: diff body with zero vault-doc literals -> exit 2 (cannot prove scope)" \
             || fail "e3: expected exit 2, got $RC"
mk_diff

# ── (f) MUTATION arm — moving a claim to an untouched doc changes the output ──
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1 || fail "f: baseline rerun failed"
BASE="$(cat "$PF")"
python3 - "$V/binding.json" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for c in d["claims"]:
    if c["id"] == "C-001":
        c["vault_source"] = "06-constraints.md:9"
json.dump(d, open(p, "w"))
EOF
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1 || fail "f: mutated run failed"
MUT="$(cat "$PF")"
if [ "$BASE" != "$MUT" ] && ! grep -qx 'app/Models/Nasabah.php' "$PF"; then
  pass "f: mutation (C-001 moved to untouched doc) changes the output — no hardcoded pass"
else fail "f: mutation did not change the derived set"; fi

# ── (g) ROUND-HARDENED: fenced heading cannot truncate the body (R2 A4b) ──
python3 - "$V/binding.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
for c in d["claims"]:
    if c["id"] == "C-001":
        c["vault_source"] = "03-data-model.md:42"
json.dump(d, open(sys.argv[1], "w"))
EOF
cat > "$V/VAULT-DIFF.md" <<'EOF'
# Vault Diff Report

## Summary

- counts

## Changed entities / flows / decisions

### Entity changed, quoting the template:

```markdown
## Unchanged sections (no action needed)
```

**Action on apply**: update `03-data-model.md`.

## Added entities / flows / decisions

**Action on apply**: append to `04-flows.md`.
EOF
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
if [ $RC -eq 0 ] && grep -qx 'NasabahController.php' "$PF" && grep -qx 'app/Models/Nasabah.php' "$PF"; then
  pass "g: a fenced '## Unchanged' quote does NOT truncate — the real Added section after it still counts"
else fail "g: fence-blind truncation (rc=$RC, file: $(cat "$PF" 2>/dev/null | tr '\n' ' '))"; fi

# ── (h) duplicate '## Summary' text in a fence does not discard earlier sections (R2 A5) ──
cat > "$V/VAULT-DIFF.md" <<'EOF'
# Vault Diff Report

## Summary

- counts

## Changed entities / flows / decisions

**Action on apply**: update `03-data-model.md`.

### quoting the header template:

```markdown
## Summary
```

## Added entities / flows / decisions

**Action on apply**: append to `04-flows.md`.
EOF
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
if [ $RC -eq 0 ] && grep -qx 'app/Models/Nasabah.php' "$PF" && grep -qx 'NasabahController.php' "$PF"; then
  pass "h: a fenced duplicate '## Summary' does not discard the sections before it"
else fail "h: occurrence-sensitive Summary split (rc=$RC)"; fi

# ── (i) out-of-order report: a real section AFTER '## Unchanged' still counts (R2 A6) ──
cat > "$V/VAULT-DIFF.md" <<'EOF'
# Vault Diff Report

## Summary

- counts

## Unchanged sections (no action needed)

- `05-decisions.md` unchanged

## Added entities / flows / decisions

**Action on apply**: append to `03-data-model.md`.
EOF
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
if [ $RC -eq 0 ] && grep -qx 'app/Models/Nasabah.php' "$PF" \
   && ! grep -qx 'app/Services/Untouched.php' "$PF"; then
  pass "i: section order does not matter — Added-after-Unchanged counts, Unchanged still excluded"
else fail "i: order-dependent section cut (rc=$RC)"; fi
mk_diff

# ── (j) vault_source shape drift -> exit 2 fail-closed (R1 m3) ──
python3 - "$V/binding.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["claims"][0]["vault_source"] = "docs/spec.md:9"
json.dump(d, open(sys.argv[1], "w"))
EOF
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
[ $RC -eq 2 ] && pass "j: unrecognizable vault_source -> exit 2 FAIL-CLOSED (never silently skipped)" \
             || fail "j: expected exit 2 on vault_source drift, got $RC"
mk_binding

# ── (k) zero affected claims (incl. empty claims[]) -> exit 2, never a vacuous scoped bind ──
echo '{"claims": []}' > "$V/binding.json"
bash "$SCRIPT" --vault="$V" --cwd="$T" >/dev/null 2>&1; RC=$?
[ $RC -eq 2 ] && pass "k: empty claims[] / zero affected -> exit 2 FAIL-CLOSED (full re-bind)" \
             || fail "k: expected exit 2 on zero affected, got $RC"
mk_binding

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc

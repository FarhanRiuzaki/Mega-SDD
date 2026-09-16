#!/usr/bin/env bash
# ground.sh self-resolve notices — two debt fixes pinned by behavior:
#   model_tiers: override roles compare `_`→`-` normalized against references/model-tiers.md, so the
#   documented key `model_tiers.bolt_implementer` no longer trips model_tier_unknown on every run;
#   a vault.json the mode guard cannot parse is REPORTED (`[self-resolved] vault_json_corrupt`
#   naming the file) — never skipped silently, never rewritten, and the chain still continues (rc 0).
#   a   bolt_implementer: sonnet (underscored, the documented form) → no model_tier_unknown
#   a2  bolt-implementer: sonnet (the catalog's own spelling) → no model_tier_unknown
#   b   nonexistent_role: sonnet → model_tier_unknown naming nonexistent_role (proves the catalog loaded)
#   c   vaults/app/vault.json = `{not json` → notice names the file; file byte-untouched; rc 0
#   d   a valid vault.json → no vault_json_corrupt
# Run: bash tests/state/test-ground-model-tier-norm.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts/ground.sh"
[ -f "$P/references/model-tiers.md" ] || { echo "FATAL: $P/references/model-tiers.md missing"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mk() { local d="$T/$1"; mkdir -p "$d/.mega-sdd"; ( cd "$d" && git init -q . ); printf '%s' "$d"; }   # one project per case: the guards scan every vault
gr() { PLUGIN_ROOT_HINT="$P" bash "$S" --cwd="$1" </dev/null 2>&1; }

# a — the documented underscored key must not be flagged
A="$(mk a)"; printf 'model_tiers:\n  bolt_implementer: sonnet\n' > "$A/.mega-sdd/config.yaml"
OUT="$(gr "$A")"; RC=$?
[ "$RC" = "0" ] && ! echo "$OUT" | grep -q 'model_tier_unknown' && pass "a: model_tiers.bolt_implementer (underscored) → no model_tier_unknown" || fail "a: rc=$RC out=$(echo "$OUT" | grep 'model_tier' | head -2)"
# a2 — the catalog spelling keeps working too (normalization is symmetric)
A2="$(mk a2)"; printf 'model_tiers:\n  bolt-implementer: sonnet\n' > "$A2/.mega-sdd/config.yaml"
OUT="$(gr "$A2")"; ! echo "$OUT" | grep -q 'model_tier_unknown' && pass "a2: model_tiers.bolt-implementer (hyphenated) → no model_tier_unknown" || fail "a2: $(echo "$OUT" | grep 'model_tier' | head -2)"

# b — an unknown role is still flagged (and proves the catalog was found, so a/a2 did not pass vacuously)
B="$(mk b)"; printf 'model_tiers:\n  nonexistent_role: sonnet\n' > "$B/.mega-sdd/config.yaml"
OUT="$(gr "$B")"; echo "$OUT" | grep 'model_tier_unknown' | grep -q 'nonexistent_role' && pass "b: unknown role → model_tier_unknown naming nonexistent_role" || fail "b: $(echo "$OUT" | head -5)"

# c — a corrupt vault.json is reported by name, left untouched, and the chain continues
C="$(mk c)"; mkdir -p "$C/.mega-sdd/vaults/app"; printf '{not json' > "$C/.mega-sdd/vaults/app/vault.json"
OUT="$(gr "$C")"; RC=$?
echo "$OUT" | grep -q '\[self-resolved\] vault_json_corrupt' && pass "c1: corrupt vault.json → [self-resolved] vault_json_corrupt notice" || fail "c1: $(echo "$OUT" | head -5)"
echo "$OUT" | grep 'vault_json_corrupt' | grep -q '\.mega-sdd/vaults/app/vault\.json' && pass "c2: the notice names the file" || fail "c2: $(echo "$OUT" | grep 'vault_json_corrupt')"
[ "$(cat "$C/.mega-sdd/vaults/app/vault.json")" = "{not json" ] && pass "c3: the corrupt file is byte-untouched (detection, not a hand edit)" || fail "c3: file rewritten: $(cat "$C/.mega-sdd/vaults/app/vault.json")"
[ "$RC" = "0" ] && echo "$OUT" | grep -q 'GROUND: state rc=' && pass "c4: ground.sh still rc 0 and reaches derive-state (the chain continues)" || fail "c4: rc=$RC out=$(echo "$OUT" | tail -2)"

# d — a parseable vault.json raises no corrupt notice
D="$(mk d)"; mkdir -p "$D/.mega-sdd/vaults/app"; printf '{"mode":"existing","project_name":"d"}\n' > "$D/.mega-sdd/vaults/app/vault.json"
OUT="$(gr "$D")"; ! echo "$OUT" | grep -q 'vault_json_corrupt' && pass "d: valid vault.json → no vault_json_corrupt" || fail "d: $(echo "$OUT" | grep 'vault_json_corrupt')"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc

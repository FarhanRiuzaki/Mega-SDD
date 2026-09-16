#!/usr/bin/env bash
# validate-unit-spec.sh accepts `--vault=<name|dir>` as an EXIT-CODE scope only: the state file
# stays project-wide (every unit listed, the gate's re-derive contract), the exit code reflects
# the units under that vault. Controllers typed --vault= on live runs and hit "unknown arg" rc=2,
# so the scope must never be a usage error, and an unresolvable vault is a note in the state.
#   a  --cwd=<root> (no vault) → exit 1, state lists vault a's broken unit, vault_filter null
#   b  --vault=b (the clean vault) → exit 0, state STILL lists a's unit, vault_filter = .mega-sdd/vaults/b
#   c  --vault=a (the broken vault) → exit 1
#   d  --vault=<dir path> behaves exactly like the name form (both vaults)
#   e  --vault=nope → rc is 0/1 (never 2), vault_filter starts with `unresolved:`
#   f  --bogus is still a usage error (rc 2) — the tolerance is for --vault= only
#   g  validate-sibling-consistency.sh stays strict: its own pin (test-plan-validator-args.sh) still passes
# Run: bash tests/v8-plan/test-unit-spec-vault-scope.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts/validate-unit-spec.sh"
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.mega-sdd/vaults/a/units" "$T/.mega-sdd/vaults/b/units"; ( cd "$T" && git init -q . )
# vault a carries ONE unit with no frontmatter at all → the validator FAILs it; vault b is empty (clean)
printf '# U-001 — no frontmatter\n\nBody only.\n' > "$T/.mega-sdd/vaults/a/units/U-001.md"
ST="$T/.mega-sdd/.unit-spec-state.json"; UA=".mega-sdd/vaults/a/units/U-001.md"
st() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2],{'d':d}))" "$ST" "$1"; }
run() { bash "$S" --cwd="$T" "$@" --quiet </dev/null >/dev/null 2>&1; echo $?; }

# a — the project-wide baseline: broken unit → exit 1, listed, no filter recorded
RC=$(run); [ "$RC" = "1" ] && [ -f "$ST" ] && pass "a1: --cwd only → exit 1 (vault a's unit fails)" || fail "a1: rc=$RC state=$([ -f "$ST" ] && echo present || echo missing)"
[ "$(st "'$UA' in d['checked_files']")" = "True" ] && pass "a2: state lists vault a's unit" || fail "a2: checked_files=$(st "d['checked_files']")"
[ "$(st "any('no frontmatter' in (i.get('detail') or '') for i in d['issues'])")" = "True" ] && pass "a3: the recorded issue is the no-frontmatter one (fixture is what it claims)" || fail "a3: issues=$(st "d['issues']")"
[ "$(st "d['vault_filter']")" = "None" ] && pass "a4: vault_filter is null without --vault=" || fail "a4: vault_filter=$(st "d['vault_filter']")"

# b — pins: the scope narrows the EXIT, never the state
RC=$(run --vault=b); [ "$RC" = "0" ] && pass "b1: --vault=b (no issues under b) → exit 0" || fail "b1: rc=$RC"
[ "$(st "'$UA' in d['checked_files']")" = "True" ] && pass "b2: state STILL lists vault a's unit (project-wide merge kept)" || fail "b2: checked_files=$(st "d['checked_files']")"
[ "$(st "d['status']")" = "FAIL" ] && pass "b3: merged status stays FAIL in the state (the gate reads the whole project)" || fail "b3: status=$(st "d['status']")"
[ "$(st "d['vault_filter']")" = ".mega-sdd/vaults/b" ] && pass "b4: vault_filter = .mega-sdd/vaults/b" || fail "b4: vault_filter=$(st "d['vault_filter']")"

# c — the broken vault in scope → exit 1
RC=$(run --vault=a); [ "$RC" = "1" ] && pass "c1: --vault=a → exit 1" || fail "c1: rc=$RC"
[ "$(st "d['vault_filter']")" = ".mega-sdd/vaults/a" ] && pass "c2: vault_filter = .mega-sdd/vaults/a" || fail "c2: vault_filter=$(st "d['vault_filter']")"

# d — the dir form resolves the same as the name form
RC=$(run --vault="$T/.mega-sdd/vaults/b"); [ "$RC" = "0" ] && [ "$(st "d['vault_filter']")" = ".mega-sdd/vaults/b" ] && pass "d1: --vault=<dir of b> → exit 0, same vault_filter" || fail "d1: rc=$RC vault_filter=$(st "d['vault_filter']")"
RC=$(run --vault="$T/.mega-sdd/vaults/a"); [ "$RC" = "1" ] && pass "d2: --vault=<dir of a> → exit 1" || fail "d2: rc=$RC"
RC=$(run --vault=.mega-sdd/vaults/b); [ "$RC" = "0" ] && pass "d3: --vault=<cwd-relative dir> → exit 0" || fail "d3: rc=$RC"

# e — pins: an unresolvable vault is NOT a usage error; it is noted and the exit falls back to project-wide
RC=$(run --vault=nope); { [ "$RC" = "0" ] || [ "$RC" = "1" ]; } && pass "e1: --vault=nope → rc=$RC (never 2)" || fail "e1: rc=$RC"
[ "$(st "str(d['vault_filter']).startswith('unresolved:')")" = "True" ] && echo "$(st "d['vault_filter']")" | grep -q 'nope' && pass "e2: vault_filter = '$(st "d['vault_filter']")'" || fail "e2: vault_filter=$(st "d['vault_filter']")"
[ "$(st "'$UA' in d['checked_files']")" = "True" ] && pass "e3: state still lists every unit on an unresolved scope" || fail "e3: checked_files=$(st "d['checked_files']")"

# f — a real unknown arg is still refused
RC=$(run --bogus); [ "$RC" = "2" ] && pass "f: --bogus → rc 2 (usage error kept for real unknown args)" || fail "f: rc=$RC"

# g — the sibling validator keeps its strict arg parse (its own pin runs unchanged)
bash "$ROOT/tests/v8-plan/test-plan-validator-args.sh" </dev/null >/dev/null 2>&1 && pass "g: test-plan-validator-args.sh still passes (validate-sibling-consistency.sh stays strict)" || fail "g: test-plan-validator-args.sh failed"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc

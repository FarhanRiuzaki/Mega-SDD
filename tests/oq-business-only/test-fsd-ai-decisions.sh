#!/usr/bin/env bash
# FSD §10 — what the TEAM sees (spec 2026-09-20-oq-business-only-design.md §9.12).
# An AI technical decision is `resolved`, so §10.1 never lists it; a team that
# reads only the FSD must still see the picks it may override.
#   F1 §10.4 lists every `resolved_by: ai` OQ, P1 first, cells verbatim from vault.json
#   F2 §10.4 never lists a HUMAN-resolved OQ
#   F3 a `|` inside a cell is escaped — the table keeps 6 columns
#   F4 §10.1 lists the vault's OPEN OQs on a layout-3 vault (it used to render a bogus
#      "format tidak dikenali" row and HIDE them: the vault.json branch was an `elif`)
#   F5 §10.1 never lists a resolved OQ (AI or human)
#   F6 no unfilled `{{slot}}` survives; vault.json is cited for §10
#   F7 a vault with NO AI decision renders one honest `(none)` row, never an empty table
# Run: bash tests/oq-business-only/test-fsd-ai-decisions.sh </dev/null
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
S="$ROOT/plugins/mega-sdd/scripts"; FIX="$ROOT/tests/v8-layout3/fixtures/context-vault"
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

mkvault() {   # $1 = project dir, stdin = the OQ lines
  local v="$1/.mega-sdd/vaults/v"; mkdir -p "$v"
  cp "$FIX/context.md" "$FIX/constitution.md" "$v/"
  OQ_LINES="$(cat)" python3 - "$v/context.md" <<'PY'
import os, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.split("## Open Questions")[0] + "## Open Questions\n\n" + os.environ["OQ_LINES"] + "\n")
PY
}
sec10() { awk '/^## 10\. /{f=1} f{print}' "$1"; }
sub()   { awk -v h="$2" '$0 ~ "^### " h {f=1; next} /^### /{f=0} f{print}' "$1"; }

A="$T/a"; mkvault "$A" <<'EOF'
- [ ] **OQ-FL-3** [P1] [business] [conf: high] [origin: context.md#F-U-001]: which screen opens after submit? — resolve: PM
- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? → **Resolved v1.0** (AI decision, 2026-09-20): RFC 7807 problem+json
- [x] **OQ-AR-1** [P1] [tech / recommend] [conf: medium] [origin: context.md#Overview]: which test runner? → **Resolved v1.0** (AI decision, 2026-09-20): Vitest
- [x] **OQ-DM-1** [P1] [business] [origin: context.md#Data-model]: which ID type? → **Resolved v1.1** (2026-07-19): UUID.
EOF
printf '%s' '{"open_questions":{"OQ-AR-7":{"recommendation":"RFC 7807","rationale":"matches ErrorResource","scan_citations":["src/http/error.ts:12","pack:nextjs §Errors"],"fallback_if_wrong":"JSON:API errors | or a plain shape"},"OQ-AR-1":{"recommendation":"Vitest","rationale":"already installed","scan_citations":["package.json:31"],"fallback_if_wrong":"use Jest"}}}' > "$T/patch.json"
bash "$S/derive-vault-json.sh" --vault="$A/.mega-sdd/vaults/v" --patch="$T/patch.json" </dev/null >/dev/null 2>&1 || fail "setup: derive A"
bash "$S/build-fsd-core.sh" --vault="$A/.mega-sdd/vaults/v" --cwd="$A" --quiet </dev/null >"$T/a.log" 2>&1 || fail "setup: build-fsd-core A ($(tail -1 "$T/a.log"))"
F="$A/.mega-sdd/vaults/v/fsd/FSD.md"; [ -f "$F" ] || { fail "setup: FSD.md not written"; echo "SOME FAILED"; exit 1; }
sec10 "$F" > "$T/s10.md"; sub "$T/s10.md" "10.4" > "$T/s104.md"; sub "$T/s10.md" "10.1" > "$T/s101.md"

R1=$(grep -n '^| OQ-AR-1 | P1 | which test runner? | Vitest | package.json:31 | use Jest |$' "$T/s104.md" | cut -d: -f1)
R7=$(grep -n '^| OQ-AR-7 | P2 | what HTTP error envelope shape? | RFC 7807 problem+json | src/http/error.ts:12, pack:nextjs §Errors | ' "$T/s104.md" | cut -d: -f1)
[ -n "$R1" ] && [ -n "$R7" ] && [ "$R1" -lt "$R7" ] && pass "F1: §10.4 lists both AI decisions, P1 first, cells verbatim" || fail "F1: rows r1=$R1 r7=$R7 :: $(cat "$T/s104.md")"
grep -q 'OQ-DM-1' "$T/s104.md" && fail "F2: a human-resolved OQ leaked into §10.4" || pass "F2: §10.4 never lists a human-resolved OQ"
ROW7=$(grep '^| OQ-AR-7 ' "$T/s104.md")
COLS=$(printf '%s' "$ROW7" | sed 's/\\|//g' | awk -F'|' '{print NF-2}')
[ "$COLS" = "6" ] && printf '%s' "$ROW7" | grep -qF 'JSON:API errors \| or a plain shape' && pass "F3: a pipe inside a cell is escaped — the row keeps 6 columns" || fail "F3: cols=$COLS row=$ROW7"
grep -q '^| OQ-FL-3 | which screen opens after submit? | P1 | business |$' "$T/s101.md" && ! grep -q 'formatnya tidak dikenali' "$T/s101.md" \
  && pass "F4: §10.1 lists the OPEN business OQ on layout-3 (no bogus format-gap row)" || fail "F4: $(cat "$T/s101.md")"
if grep -qE 'OQ-AR-7|OQ-AR-1|OQ-DM-1' "$T/s101.md"; then fail "F5: a resolved OQ leaked into §10.1"; else pass "F5: §10.1 never lists a resolved OQ"; fi
[ "$(grep -c '{{' "$F")" = "0" ] && grep -q 'vault.json' "$T/s10.md" && pass "F6: no unfilled slot; vault.json cited for §10" || fail "F6: slots=$(grep -c '{{' "$F")"

B="$T/b"; mkvault "$B" <<'EOF'
- [ ] **OQ-FL-3** [P1] [business] [conf: high] [origin: context.md#F-U-001]: which screen opens after submit? — resolve: PM
EOF
bash "$S/derive-vault-json.sh" --vault="$B/.mega-sdd/vaults/v" </dev/null >/dev/null 2>&1 || fail "setup: derive B"
bash "$S/build-fsd-core.sh" --vault="$B/.mega-sdd/vaults/v" --cwd="$B" --quiet </dev/null >/dev/null 2>&1 || fail "setup: build-fsd-core B"
sec10 "$B/.mega-sdd/vaults/v/fsd/FSD.md" > "$T/b10.md"; sub "$T/b10.md" "10.4" > "$T/b104.md"
grep -q '^| — | — | (none) | — | — | — |$' "$T/b104.md" && pass "F7: no AI decision → one honest (none) row" || fail "F7: $(cat "$T/b104.md")"

[ "$rc" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $rc

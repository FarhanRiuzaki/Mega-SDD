#!/usr/bin/env bash
# OQ = business-only (spec docs/superpowers/specs/2026-09-20-oq-business-only-design.md)
# — pins the MECHANISM: the `(AI decision …)` annotation marker, the md-owned
# `resolved_by` field, and the two validator rails.
#   P1 parser: `(AI decision, date)` → status resolved + resolution + resolved_by: ai
#   P2 parser: a plain human resolution carries NO resolved_by (back-compat)
#   P3 parser: legacy `→ **Resolved (plan)** (date): x` keeps its answer (was dropped)
#   P4 parser: forgery probes — the marker must OPEN the parenthetical; a human note that
#      mentions "AI decision", an answer TEXT that mentions it, a question text that
#      contains it, and a neighbour OQ's marker never stamp resolved_by
#   D1 deriver: resolved_by lands in vault.json
#   D2 deriver: a --patch can never set resolved_by (md-owned → exit 2)
#   D3 deriver: human override (marker removed) drops resolved_by on re-derive
#   V1 validator --strict-tech: open tech/recommend → FAIL oq_tech_undecided (rc 1)
#   V2 validator (analyze, no flag): same vault → WARN, rc 0 (older vaults never retro-fail)
#   V3 validator: layout-3 open tech/scan is undecided under --strict-tech (no bind phase follows)
#   V4 validator: AI-decided + business signal → FAIL oq_decided_business_signal, flag or not
#   V5 validator: AI-decided + source-vs-code contradiction wording → FAIL
#   V6 validator: AI-decided [business] category → FAIL
#   V7 validator: a clean AI-decided tech OQ + open business OQ → no new-rail issue
#   V8 validator: QUESTION-only rows (paid licence / hosting / NFR targets / technology stack)
#      FAIL an AI decision — every row is a class found tagged `tech` in the field vaults
#   V9 validator: the same words in the RATIONALE only ("no paid license needed") do NOT fail
#   --- second-eyes review of 8.5.0 (3 clean-context reviewers) ---
#   P5 marker is case/spacing tolerant; P6 the stamp is anchored to the annotation that supplies
#      `resolution` (a kept history line / a fenced example never stamps a human answer)
#   D4 resolved_by is unpatchable on a `defer_to: binding` orphan too
#   V10 a DEFERRED tech OQ is undecided · V11 --strict-tech never goes blind (missing / corrupt
#      vault.json → md fallback; an unvalidatable path → rc 2) · V12 the Design-Source OQ is never an
#      AI decision · V13 engineering vocabulary in the pick/rationale is not a business signal ·
#      V14 business wins ties (no oq_misclassified_tech) · V15 greenfield open `scan` is undecided ·
#      V16 a translated marker is surfaced (advisory)
# Run: bash tests/oq-business-only/test-ai-decided-oq.sh </dev/null
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
FIX="$ROOT/tests/v8-layout3/fixtures/context-vault"
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# ── parser ──────────────────────────────────────────────────────────────────
OUT=$(MEGA_SDD_LIB_DIR="$S/_lib" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md
md = "\n".join([
 "- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium]: envelope shape? → **Resolved v1.0** (AI decision, 2026-09-20): RFC 7807 problem+json",
 "- [x] **OQ-DM-1** [P1] [business]: which ID type? → **Resolved v1.1** (2026-07-19): UUID.",
 "- [x] **OQ-FL-3** [P1] [business]: refund on cancel? → **Resolved (plan)** (2026-09-16): no refund",
 "- [x] **OQ-FL-4** [P1] [business]: refund window? → **Resolved v1.1** (2026-09-21): keep the AI decision (no refund) per PM",
 "- [x] **OQ-AR-9** [P2] [tech / recommend] [conf: medium]: lib? → **Resolved v1.2** (PM, after reviewing the AI decision log): zod",
 "- [ ] **OQ-AR-2** [P2] [tech / recommend] [conf: medium]: should the (AI decision, draft) label show in the UI?",
 "- [x] **OQ-DM-2** [P1] [business]: which ID type? → **Resolved v1.1** (2026-07-19): ULID.",
 "- [x] **OQ-AR-8** [P2] [tech / recommend] [conf: medium]: envelope v2?",
 "  → **Resolved v1.0** (AI decision): RFC 9457",
])
for o in vault_md.parse_open_questions("context.md", md, []):
    print(o["tag"], o["status"], o.get("resolved_by"), "|", o.get("resolution"))
PY
)
echo "$OUT" | grep -q '^OQ-AR-7 resolved ai | RFC 7807 problem+json$' && pass "P1: (AI decision, date) → resolved + resolution + resolved_by ai" || fail "P1: $OUT"
echo "$OUT" | grep -q '^OQ-DM-1 resolved None | UUID\.$' && pass "P2: human resolution carries no resolved_by" || fail "P2: $OUT"
echo "$OUT" | grep -q '^OQ-FL-3 resolved None | no refund$' && pass "P3: legacy 'Resolved (plan)' keeps its answer" || fail "P3: $OUT"
if echo "$OUT" | grep -q '^OQ-FL-4 resolved None ' && echo "$OUT" | grep -q '^OQ-AR-9 resolved None | zod$' \
   && echo "$OUT" | grep -q '^OQ-AR-2 open None ' && echo "$OUT" | grep -q '^OQ-DM-2 resolved None | ULID\.$' \
   && echo "$OUT" | grep -q '^OQ-AR-8 resolved ai | RFC 9457$'; then
  pass "P4: forgery probes — only a parenthetical that OPENS with the marker stamps resolved_by"
else fail "P4: $OUT"; fi

# ── fixture builder: the layout-3 fixture with a rewritten OQ section ─────────
mkvault() {   # $1 = project dir, stdin = the OQ lines
  local prj="$1" v="$1/.mega-sdd/vaults/v"; mkdir -p "$v"
  cp "$FIX/context.md" "$FIX/constitution.md" "$v/" 2>/dev/null
  OQ_LINES="$(cat)" python3 - "$v/context.md" <<'PY'
import os, re, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
head = s.split("## Open Questions")[0]
open(p, "w", encoding="utf-8").write(head + "## Open Questions\n\n" + os.environ["OQ_LINES"] + "\n")
PY
}
derive() { bash "$S/derive-vault-json.sh" --vault="$1/.mega-sdd/vaults/v" "${@:2}" </dev/null >"$T/derive.out" 2>&1; }
oqfield() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print([o for o in d['open_questions'] if o['tag']==sys.argv[2]][0].get(sys.argv[3]))" "$1/.mega-sdd/vaults/v/vault.json" "$2" "$3"; }
PATCH_OK='{"open_questions":{"OQ-AR-7":{"recommendation":"RFC 7807 problem+json","rationale":"matches the existing ErrorResource shape","scan_citations":["src/http/error.ts:12"],"fallback_if_wrong":"switch to JSON:API errors"}}}'
validate() { bash "$S/validate-vault-oqs.sh" --cwd="$1" --file-path="$1/.mega-sdd/vaults/v/context.md" --quiet "${@:2}" </dev/null >/dev/null 2>&1; echo $?; }
halts() { python3 -c "import json,sys; print(' '.join(sorted({i['halt_type'] for i in json.load(open(sys.argv[1]))['issues']})))" "$1/.mega-sdd/.vault-oqs-state.json"; }
vstatus() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['status'])" "$1/.mega-sdd/.vault-oqs-state.json"; }

# ── deriver ─────────────────────────────────────────────────────────────────
A="$T/a"; mkvault "$A" <<'EOF'
- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? → **Resolved v1.0** (AI decision, 2026-09-20): RFC 7807 problem+json
- [ ] **OQ-FL-3** [P1] [business] [conf: high] [origin: context.md#F-U-001]: does cancelling return the prior payment? — resolve: PM
EOF
echo "$PATCH_OK" > "$T/patch.json"
derive "$A" --patch="$T/patch.json" && [ "$(oqfield "$A" OQ-AR-7 resolved_by)" = "ai" ] && [ "$(oqfield "$A" OQ-AR-7 status)" = "resolved" ] \
  && pass "D1: resolved_by: ai + status resolved land in vault.json" || fail "D1: $(cat "$T/derive.out" | tail -3)"
echo '{"open_questions":{"OQ-FL-3":{"resolved_by":"ai"}}}' > "$T/forge.json"
derive "$A" --patch="$T/forge.json"; DRC=$?
[ "$DRC" -eq 2 ] && grep -q "resolved_by" "$T/derive.out" && pass "D2: --patch cannot forge resolved_by (md-owned, exit 2)" || fail "D2: rc=$DRC $(tail -2 "$T/derive.out")"
python3 - "$A/.mega-sdd/vaults/v/context.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s = s.replace("(AI decision, 2026-09-20): RFC 7807 problem+json", "(2026-09-21): JSON:API errors — platform team ruling")
open(p, "w", encoding="utf-8").write(s)
PY
derive "$A" && [ "$(oqfield "$A" OQ-AR-7 resolved_by)" = "None" ] && [ "$(oqfield "$A" OQ-AR-7 resolution)" = "JSON:API errors — platform team ruling" ] \
  && pass "D3: human override drops resolved_by and carries the new answer" || fail "D3: by=$(oqfield "$A" OQ-AR-7 resolved_by) res=$(oqfield "$A" OQ-AR-7 resolution)"

# ── validator: undecided tech ───────────────────────────────────────────────
B="$T/b"; mkvault "$B" <<'EOF'
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? — resolve: recommendation in vault.json
EOF
derive "$B" --patch="$T/patch.json" || fail "V-setup B: $(tail -2 "$T/derive.out")"
R=$(validate "$B" --strict-tech); [ "$R" = "1" ] && halts "$B" | grep -q oq_tech_undecided && pass "V1: --strict-tech → open tech/recommend FAILs (oq_tech_undecided, rc 1)" || fail "V1: rc=$R halts=$(halts "$B")"
R=$(validate "$B"); [ "$R" = "0" ] && [ "$(vstatus "$B")" = "WARN" ] && halts "$B" | grep -q oq_tech_undecided && pass "V2: without the flag the same vault is WARN / rc 0 (no retro-FAIL)" || fail "V2: rc=$R status=$(vstatus "$B")"

C="$T/c"; mkvault "$C" <<'EOF'
- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high] [origin: context.md#Overview]: which test framework? — resolve: scan manifest package.json
EOF
echo '{"open_questions":{"OQ-AR-1":{"scan_query":"manifest package.json"}}}' > "$T/scan.json"
derive "$C" --patch="$T/scan.json" || fail "V-setup C: $(tail -2 "$T/derive.out")"
R=$(validate "$C" --strict-tech); [ "$R" = "1" ] && halts "$C" | grep -q oq_tech_undecided && pass "V3: layout-3 open tech/scan is undecided under --strict-tech" || fail "V3: rc=$R halts=$(halts "$C")"

# ── validator: the AI decided something it must not ─────────────────────────
D="$T/d"; mkvault "$D" <<'EOF'
- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what is the limit for failed login attempts before lockout? → **Resolved v1.0** (AI decision, 2026-09-20): 5 attempts
EOF
derive "$D" --patch="$T/patch.json" || fail "V-setup D: $(tail -2 "$T/derive.out")"
R=$(validate "$D"); [ "$R" = "1" ] && halts "$D" | grep -q oq_decided_business_signal && pass "V4: AI-decided + business signal (limit) → FAIL even without the flag" || fail "V4: rc=$R halts=$(halts "$D")"

E="$T/e"; mkvault "$E" <<'EOF'
- [x] **OQ-AR-7** [P1] [tech / recommend] [conf: medium] [origin: context.md#Constraints]: the PRD names Bun + PostgreSQL but the repo is a Next.js starter kit — which stack is authoritative for v1? → **Resolved v1.0** (AI decision, 2026-09-20): keep the repo stack
EOF
derive "$E" --patch="$T/patch.json" || fail "V-setup E: $(tail -2 "$T/derive.out")"
R=$(validate "$E"); [ "$R" = "1" ] && halts "$E" | grep -q oq_decided_business_signal && pass "V5: source-vs-code contradiction is never an AI pick" || fail "V5: rc=$R halts=$(halts "$E")"

F="$T/f"; mkvault "$F" <<'EOF'
- [x] **OQ-FL-3** [P1] [business] [conf: high] [origin: context.md#F-U-001]: which screen opens after submit? → **Resolved v1.0** (AI decision, 2026-09-20): the list screen
EOF
derive "$F" || fail "V-setup F: $(tail -2 "$T/derive.out")"
R=$(validate "$F"); [ "$R" = "1" ] && halts "$F" | grep -q oq_decided_business_signal && pass "V6: an AI decision on a [business] OQ → FAIL" || fail "V6: rc=$R halts=$(halts "$F")"

G="$T/g"; mkvault "$G" <<'EOF'
- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? → **Resolved v1.0** (AI decision, 2026-09-20): RFC 7807 problem+json
- [ ] **OQ-FL-3** [P1] [business] [conf: high] [origin: context.md#F-U-001]: which screen opens after submit? — resolve: PM
EOF
derive "$G" --patch="$T/patch.json" || fail "V-setup G: $(tail -2 "$T/derive.out")"
R=$(validate "$G" --strict-tech)
if [ "$R" = "0" ] && [ -f "$G/.mega-sdd/.vault-oqs-state.json" ] && [ "$(oqfield "$G" OQ-AR-7 resolved_by)" = "ai" ] \
   && ! halts "$G" | grep -Eq "oq_tech_undecided|oq_decided_business_signal"; then
  pass "V7: clean AI-decided tech OQ + open business OQ → rc 0, state written, stamp present, neither new rail fires"
else fail "V7: rc=$R state=$([ -f "$G/.mega-sdd/.vault-oqs-state.json" ] && echo yes || echo NO) by=$(oqfield "$G" OQ-AR-7 resolved_by) halts=$(halts "$G")"; fi

# ── validator: question-only rows (field-derived) ───────────────────────────
v8() {  # $1 = label, $2 = question text
  local d="$T/v8-$1"
  printf -- '- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: %s → **Resolved v1.0** (AI decision, 2026-09-20): the pick\n' "$2" | mkvault "$d"
  derive "$d" --patch="$T/patch.json" || { fail "V8-setup $1: $(tail -2 "$T/derive.out")"; return; }
  local r; r=$(validate "$d")
  [ "$r" = "1" ] && halts "$d" | grep -q oq_decided_business_signal && pass "V8: $1 in the QUESTION → an AI decision FAILs" || fail "V8: $1 rc=$r halts=$(halts "$d")"
}
v8 "paid-licence"     "the PRD suggests Schedule-X, or FullCalendar Premium if a paid license is acceptable — which one?"
v8 "hosting"          "where will the app run — Vercel or self-hosted?"
v8 "nfr-targets"      "PRD performance targets depend on the upstream API — who owns them?"
v8 "technology-stack" "the PRD names a Bun stack (PRD §6.3 Technology Stack) but this repository is Next.js — which one?"

H="$T/h"
printf -- '- [x] **OQ-DC-1** [P3] [tech / recommend] [conf: medium] [origin: context.md#Overview]: no date-picker library is installed in the repo — which date picker? → **Resolved v1.0** (AI decision, 2026-09-20): react-day-picker\n' | mkvault "$H"
echo '{"open_questions":{"OQ-DC-1":{"recommendation":"react-day-picker","rationale":"MIT, no paid license or premium tier needed; self-hosted friendly; already a shadcn peer","scan_citations":["package.json:31"],"fallback_if_wrong":"swap to MUI X date pickers"}}}' > "$T/rat.json"
derive "$H" --patch="$T/rat.json" || fail "V9-setup: $(tail -2 "$T/derive.out")"
R=$(validate "$H" --strict-tech)
if [ "$R" = "0" ] && [ -f "$H/.mega-sdd/.vault-oqs-state.json" ] && [ "$(oqfield "$H" OQ-DC-1 resolved_by)" = "ai" ] \
   && ! halts "$H" | grep -q oq_decided_business_signal; then
  pass "V9: 'no paid license needed' in the RATIONALE does not fail a technical pick (rc 0, state written, stamp present)"
else fail "V9: rc=$R by=$(oqfield "$H" OQ-DC-1 resolved_by) halts=$(halts "$H")"; fi

# ═══ second-eyes review of 8.5.0 ═════════════════════════════════════════════
OUT2=$(MEGA_SDD_LIB_DIR="$S/_lib" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"]); import vault_md
md = "\n".join([
 "- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: medium]: a? → **Resolved v1.0** (AI Decision, 2026-09-20): one",
 "- [x] **OQ-AR-2** [P2] [tech / recommend] [conf: medium]: b? → **Resolved v1.0** (ai  decision): two",
 "- [x] **OQ-AR-3** [P2] [tech / recommend] [conf: medium]: c? → **Resolved v1.1** (2026-09-22): JSON:API — platform ruling",
 "  ~~→ **Resolved v1.0** (AI decision, 2026-09-20): RFC 7807~~",
 "- [x] **OQ-DM-4** [P1] [business]: d? → **Resolved v1.1** (2026-07-19): UUID.",
 "  ```",
 "  → **Resolved v1.0** (AI decision, 2026-09-20): example only",
 "  ```",
 "- [x] **OQ-AR-5** [P2] [tech / recommend] [conf: medium]: e? → **Resolved v1.0** (Keputusan AI, 2026-09-20): lima",
])
for o in vault_md.parse_open_questions("context.md", md, []):
    print(o["tag"], o.get("resolved_by"), "|", o.get("resolution"))
PY
)
echo "$OUT2" | grep -q '^OQ-AR-1 ai | one$' && echo "$OUT2" | grep -q '^OQ-AR-2 ai | two$' \
  && pass "P5: '(AI Decision, …)' and '(ai  decision)' keep the stamp (a lost stamp switches the business rail off)" || fail "P5: $OUT2"
echo "$OUT2" | grep -q '^OQ-AR-3 None | JSON:API — platform ruling$' && echo "$OUT2" | grep -q '^OQ-DM-4 None | UUID\.$' \
  && pass "P6: a kept AI history line / a fenced example never stamps the HUMAN answer above it" || fail "P6: $OUT2"
echo "$OUT2" | grep -q '^OQ-AR-5 None | lima$' && pass "P7: a translated marker is NOT parsed (Tier-1 token) — V16 surfaces it" || fail "P7: $OUT2"

echo '{"open_questions":{"OQ-ZZ-9":{"defer_to":"binding","status":"resolved","resolved_by":"ai"}}}' > "$T/orphan.json"
derive "$A" --patch="$T/orphan.json"; DRC=$?
[ "$DRC" -eq 2 ] && grep -q "resolved_by" "$T/derive.out" && pass "D4: resolved_by is unpatchable on a defer_to: binding orphan too (exit 2)" || fail "D4: rc=$DRC $(tail -2 "$T/derive.out")"

J="$T/j"; mkvault "$J" <<'EOF'
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? **Deferred (plan)**: resurfaced after bolts
EOF
derive "$J" --patch="$T/patch.json" || fail "V10-setup: $(tail -2 "$T/derive.out")"
R=$(validate "$J" --strict-tech); [ "$R" = "1" ] && halts "$J" | grep -q oq_tech_undecided && pass "V10: a DEFERRED tech OQ is undecided under --strict-tech (a deferral resurfaces to a human)" || fail "V10: rc=$R halts=$(halts "$J")"

K="$T/k"; mkvault "$K" <<'EOF'
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? — resolve: recommendation in vault.json
EOF
rm -f "$K/.mega-sdd/vaults/v/vault.json"
R=$(validate "$K" --strict-tech); [ "$R" = "1" ] && halts "$K" | grep -q oq_tech_undecided && pass "V11a: --strict-tech with NO vault.json falls back to the markdown — still FAILs" || fail "V11a: rc=$R halts=$(halts "$K" 2>/dev/null)"
printf '{not json' > "$K/.mega-sdd/vaults/v/vault.json"
R=$(validate "$K" --strict-tech); [ "$R" = "1" ] && pass "V11b: --strict-tech with a CORRUPT vault.json still FAILs" || fail "V11b: rc=$R"
bash "$S/validate-vault-oqs.sh" --cwd="$K" --file-path="$K/.mega-sdd/vaults/v/nope.json" --strict-tech --quiet </dev/null >/dev/null 2>&1; R=$?
[ "$R" = "2" ] && pass "V11c: --strict-tech on a missing path is rc 2, never a silent pass" || fail "V11c: rc=$R"
bash "$S/validate-vault-oqs.sh" --cwd="$K" --file-path="$K/.mega-sdd/vaults/v/constitution.md" --strict-tech --quiet </dev/null >/dev/null 2>&1; R=$?
[ "$R" = "2" ] && pass "V11d: --strict-tech on a path it cannot validate is rc 2" || fail "V11d: rc=$R"
bash "$S/validate-vault-oqs.sh" --cwd="$K" --file-path="$K/.mega-sdd/vaults/v/constitution.md" --quiet </dev/null >/dev/null 2>&1; R=$?
[ "$R" = "0" ] && pass "V11e: without the flag an unrelated path stays a quiet no-op (analyze contract unchanged)" || fail "V11e: rc=$R"

L="$T/l"; mkvault "$L" <<'EOF'
- [x] **OQ-DESIGN-SOURCE-1** [P1] [tech / recommend] [conf: medium] [origin: context.md#Constraints]: no design source in the PRD — which style, palette and typography? → **Resolved v1.0** (AI decision, 2026-09-20): minimalism, Poppins, WCAG AA
EOF
derive "$L" || fail "V12-setup: $(tail -2 "$T/derive.out")"
R=$(validate "$L"); [ "$R" = "1" ] && halts "$L" | grep -q oq_decided_business_signal && pass "V12: the Design-Source OQ is never an AI decision (no defaulted standards)" || fail "V12: rc=$R halts=$(halts "$L")"

M="$T/m"; mkvault "$M" <<'EOF'
- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: which form-validation approach? → **Resolved v1.0** (AI decision, 2026-09-20): zod schema shared by form and API
EOF
echo '{"open_questions":{"OQ-AR-7":{"recommendation":"zod schema shared by form and API","rationale":"the schema becomes the single source of truth; it also handles the DST edge case and keeps us clear of legal/compliance review","scan_citations":["package.json:31"],"fallback_if_wrong":"use yup"}}}' > "$T/vocab.json"
derive "$M" --patch="$T/vocab.json" || fail "V13-setup: $(tail -2 "$T/derive.out")"
R=$(validate "$M" --strict-tech)
[ "$R" = "0" ] && ! halts "$M" | grep -q oq_decided_business_signal && pass "V13: 'source of truth' / 'edge case' / 'compliance' in the RATIONALE is engineering vocabulary, not a business signal" || fail "V13: rc=$R halts=$(halts "$M")"

N="$T/n"; mkvault "$N" <<'EOF'
- [ ] **OQ-DC-2** [P2] [business] [conf: high] [origin: context.md#Overview]: which library for the schedule grid — is a paid license acceptable? — resolve: PO
EOF
derive "$N" || fail "V14-setup: $(tail -2 "$T/derive.out")"
validate "$N" --strict-tech >/dev/null
[ -f "$N/.mega-sdd/.vault-oqs-state.json" ] && ! halts "$N" | grep -q oq_misclassified_tech && pass "V14: business wins ties — a [business] OQ that ALSO matches a tech row is not 'misclassified'" || fail "V14: halts=$(halts "$N")"

O="$T/o"; mkvault "$O" <<'EOF'
- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high] [origin: context.md#Overview]: which test framework? — resolve: scan manifest package.json
EOF
derive "$O" --patch="$T/scan.json" || fail "V15-setup: $(tail -2 "$T/derive.out")"
python3 - "$O/.mega-sdd/vaults/v/vault.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); assert d.get("implementation_mode") == "new", d.get("implementation_mode")
PY
[ $? -eq 0 ] && { R=$(validate "$O" --strict-tech); [ "$R" = "1" ] && halts "$O" | grep -q oq_tech_undecided && pass "V15: greenfield (implementation_mode: new) open scan is undecided — nothing to scan, no bind phase" || fail "V15: rc=$R"; } || fail "V15: fixture is not greenfield"

Q="$T/q"; mkvault "$Q" <<'EOF'
- [x] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#Overview]: what HTTP error envelope shape? → **Resolved v1.0** (Keputusan AI, 2026-09-20): RFC 7807
EOF
derive "$Q" --patch="$T/patch.json" || fail "V16-setup: $(tail -2 "$T/derive.out")"
R=$(validate "$Q" --strict-tech)
[ "$R" = "0" ] && [ "$(vstatus "$Q")" = "WARN" ] && halts "$Q" | grep -q oq_tech_undecided && pass "V16: a translated marker is surfaced as an ADVISORY (WARN, rc 0 — a human override looks the same)" || fail "V16: rc=$R status=$(vstatus "$Q") halts=$(halts "$Q")"

[ "$rc" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $rc

#!/usr/bin/env bash
# test-5e-doc-builders.sh — tranche 5e (spec §Phase 5 "DESIGN 2026-08-02 (tranche 5e").
# BEHAVIORAL proofs for build-fsd-core.sh + build-prd-core.sh:
#   FSD   every slot pre-filled (model_slots=0), mode detect pre/post-dev, FR
#         table + binding verdict + bolt rows, resolved-OQ filtered, [Pending]
#         discipline on missing sources, drift callouts inserted verbatim on
#         re-emit, DOWNSTREAM INTEGRATION: slot scan clean + the REAL
#         build-citation-map.sh stamps every citation (exit 0).
#   PRD   forward: FR first-paragraph verbatim + flow inventory + Mermaid
#         VERBATIM + model_slots exactly the synthetic set; reverse: marker
#         harvest VERBATIM ([V]/[I]/[O] counts), [OPEN] rows land in §6,
#         diagram-less workflow → journey-<slug> model slot with quoted steps,
#         markers check (check-prd-markers.sh) passes on builder output after
#         simulated model fill.
#   WIRING SKILL.mds instruct the builders; templates stay the parse source
#         (no hand-duplicated skeletons).
# Run: bash tests/token-efficiency/test-5e-doc-builders.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FSD="${ROOT}/plugins/mega-sdd/scripts/build-fsd-core.sh"
PRD="${ROOT}/plugins/mega-sdd/scripts/build-prd-core.sh"
CMAP="${ROOT}/plugins/mega-sdd/scripts/build-citation-map.sh"
MRK="${ROOT}/plugins/mega-sdd/scripts/check-prd-markers.sh"
for f in "$FSD" "$PRD" "$CMAP" "$MRK"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── FSD fixture ──
P="$WORK/proj"; V="$P/.mega-sdd/vaults/v1"
mkdir -p "$V/units" "$V/_meta" "$P/.mega-sdd/codebase"
( cd "$P" && git init -q . && git config user.email t@t && git config user.name t )
printf '{"project_name":"demo","vault_version":"1.0","author":"Tim"}\n' > "$V/vault.json"
printf '# O\n\n## Purpose\n\nTujuan demo.\n\n## Scope\n\nModul X.\n\n## Goals\n\n- G1\n\n## Non-Goals\n\n- NG1\n' > "$V/01-overview.md"
printf '# F\n\n## FR-001 — Login\n\nDeskripsi login.\n\n**Priority:** HIGH\n\n## NFR\n\n### Performance\n\n- p95 < 300ms\n' > "$V/02-functional.md"
printf '# OQ\n\n## OQ-001 — Limit?\n\n**Priority:** P1\n**Category:** business\n\n## OQ-002 — Done\n\n**Status:** resolved\n' > "$V/03-open-questions.md"
printf '# B\n\n## Confirmed Claims\n\n- [C-001] FR-001 ada — CONFIRMED\n' > "$V/binding.md"
printf -- '---\nunit_id: U-001\nscope: BE\ni_want: login endpoint\n---\n# U-001 — Login endpoint\n\n## Acceptance\n\n- command: make test\n- expected: pass\n' > "$V/units/U-001.md"
printf '# M\n\n## Entities\n\n- User — akun\n\n## Modules\n\n| Module | Path | Responsibility |\n|---|---|---|\n| Auth | app | login |\n\n## Public interfaces\n\n| Endpoint / Function | Signature | Source |\n|---|---|---|\n| POST /login | login(email) | app/L.php:10 |\n' > "$P/.mega-sdd/codebase/codebase-map.md"

note "== FSD: one call fills every slot (model_slots=0) =="
OUT=$(bash "$FSD" --vault="$V" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q 'model_slots=0' && ok "builder exit 0, model_slots=0" || fail "rc=$RC out=$OUT"
printf '%s' "$OUT" | grep -q 'mode=pre-dev' && ok "pre-dev mode detected" || fail "mode detect wrong"
F="$V/fsd/FSD.md"
if grep -qE '\{\{[a-z0-9_-]+\}\}' "$F"; then fail "leftover slots in FSD.md"; else ok "slot scan clean (Step 4.5 grammar)"; fi
grep -q '| FR-001 | Login | HIGH | Specified |' "$F" && ok "FR table row" || fail "FR table wrong"
grep -qF 'CONFIRMED (per `binding.md` claim C-001)' "$F" && ok "binding verdict wired into FR detail" || fail "binding verdict missing"
grep -q '| OQ-001 | Limit? | P1 | business |' "$F" && ok "OQ row with bolded fields parsed" || fail "OQ row wrong"
if grep -q 'OQ-002' "$F"; then fail "resolved OQ leaked into §10"; else ok "resolved OQ filtered"; fi
grep -qF '**As a** API consumer' "$F" && ok "user-story scope fallback (BE -> API consumer)" || fail "as_a fallback wrong"
N_PEND=$(grep -c '(sha256: `pending`)\|(sha256: pending)' "$F")
[ "$N_PEND" -ge 8 ] && ok "citation stamps are pending LITERALS ($N_PEND)" || fail "too few pending stamps ($N_PEND)"

note "== FSD: downstream integration — the REAL citation stamper accepts the output =="
bash "$CMAP" --vault="$V" --cwd="$P" --mode=pre-dev </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && ok "build-citation-map.sh exit 0 (every builder citation resolves; stamps now real)" || fail "citation map rc=$RC on builder output"
[ -f "$V/fsd/.citation-map.json" ] && ok ".citation-map.json written" || fail "map missing"
if grep -q 'sha256: `pending`' "$F"; then fail "pending stamps survived stamping"; else ok "all stamps replaced with real prefixes"; fi

note "== FSD: [Pending] discipline on a bare vault =="
V2="$P/.mega-sdd/vaults/v2"; mkdir -p "$V2"
printf '{"project_name":"bare"}\n' > "$V2/vault.json"
OUT=$(bash "$FSD" --vault="$V2" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" = "0" ] && ok "bare vault still emits (rc 0)" || fail "bare vault rc=$RC"
grep -q '\[Pending — vault/01-overview.md not yet generated\]' "$V2/fsd/FSD.md" && ok "missing source -> [Pending] marker, never fabrication" || fail "[Pending] discipline broken"
if grep -qE '\{\{[a-z0-9_-]+\}\}' "$V2/fsd/FSD.md"; then fail "bare vault leftover slots"; else ok "bare vault slot-clean"; fi

note "== FSD: post-dev mode + drift callout on re-emit =="
mkdir -p "$V/bolts/U-001"
printf 'bolt_status: completed\nacceptance_test_concern: flaky\nbolt_subagent_id: a1\ncommit: abc1234def\n' > "$V/bolts/U-001/bolt-report.md"
printf '\n- G2 baru\n' >> "$V/01-overview.md"
OUT=$(bash "$FSD" --vault="$V" --cwd="$P" </dev/null 2>&1)
printf '%s' "$OUT" | grep -q 'mode=post-dev' && ok "bolt-report flips mode to post-dev" || fail "post-dev detect broken"
printf '%s' "$OUT" | grep -q '^DRIFT ' && ok "drift lines printed for the change-note derivation" || fail "no drift lines on changed source"
grep -q 'Updated since last emit' "$F" && ok "drift callout inserted into FSD.md (old12/new12 script-verbatim)" || fail "drift callout missing"
grep -q '✅ completed | abc1234d' "$F" && ok "post-dev bolt row with short commit" || fail "bolt row wrong"

note "== PRD forward: mechanical fill + exact model-slot set =="
printf '# Fl\n\n## F-U-001 — Login flow\n\n```mermaid\nflowchart TD\n  A-->B\n```\n' > "$V/04-flows.md"
OUT=$(bash "$PRD" --out-root="$V" --cwd="$P" --mode=forward </dev/null 2>&1); RC=$?
[ "$RC" = "0" ] && ok "forward builder exit 0" || fail "prd fwd rc=$RC"
printf '%s' "$OUT" | grep -q 'model_slots=3 (section-1-background,section-1-purpose,section-2-actors-table)' \
  && ok "model slots = exactly the synthetic set (no squads.yaml -> actors is model)" || fail "model slot set wrong: $OUT"
PF="$V/prd/PRD.md"
grep -q 'FR-001 — Login\*\*: Deskripsi login\.' "$PF" && ok "§3 FR line carries the FIRST paragraph VERBATIM (extraction, not summarization)" || fail "§3 first-para extraction wrong"
grep -q 'flowchart TD' "$PF" && ok "§4 Mermaid carried VERBATIM" || fail "journey diagram missing"
grep -q '| OQ-001 | Limit? | P1 |' "$PF" && ok "§6 open-items row" || fail "§6 row wrong"
N_MS=$(grep -cE '\{\{[a-z0-9_-]+\}\}' "$PF")
[ "$N_MS" = "3" ] && ok "exactly 3 {{…}} markers left for the model" || fail "$N_MS markers left (want 3)"

note "== PRD reverse: marker harvest VERBATIM + [OPEN] -> §6 + journey slot =="
K="$WORK/kbp"; mkdir -p "$K/.mega-sdd/knowledge-base/10-domains" "$K/.mega-sdd/knowledge-base/20-workflows"
( cd "$K" && git init -q . && git config user.email t@t && git config user.name t )
printf '# KB\n' > "$K/.mega-sdd/knowledge-base/README.md"
printf '# Pay\n\n- [VERIFIED] QRIS statis dipakai\n- [INFERRED] Limit 5jt dari kode\n- [OPEN] Refund manual boleh?\n' > "$K/.mega-sdd/knowledge-base/10-domains/pay.md"
printf '# Settlement\n\n## Steps\n\n1. Tarik mutasi\n2. Rekonsiliasi\n' > "$K/.mega-sdd/knowledge-base/20-workflows/settle.md"
OUT=$(bash "$PRD" --out-root="$K/.mega-sdd" --cwd="$K" --mode=reverse </dev/null 2>&1); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q 'markers=1/1/1' && ok "reverse harvest counts [V]/[I]/[O] = 1/1/1" || fail "reverse rc=$RC out=$OUT"
PR="$K/.mega-sdd/prd/PRD.md"
grep -q '\- \[INFERRED\] Limit 5jt dari kode \[Source: .mega-sdd/knowledge-base/10-domains/pay.md:L4' "$PR" \
  && ok "marker + claim + per-line citation VERBATIM in §3" || fail "harvest line wrong"
grep -q '| KB-OPEN-1 | \[OPEN\] Refund manual boleh?' "$PR" && ok "[OPEN] claim landed in §6 too" || fail "§6 OPEN row missing"
printf '%s' "$OUT" | grep -q 'journey-settle' && grep -q '{{journey-settle}}' "$PR" && grep -q '> 1. Tarik mutasi' "$PR" \
  && ok "diagram-less workflow -> journey model slot with quoted recorded steps" || fail "journey slot wiring wrong"
grep -q 'Legenda marker' "$PR" && ok "marker legend emitted in reverse mode" || fail "legend missing"

note "== PRD reverse: simulated model fill passes the REAL markers check =="
python3 - "$PR" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("{{section-1-background}}", "Sistem legacy pembayaran. Klaim inti: [VERIFIED] QRIS statis dipakai.")
s = s.replace("{{section-1-purpose}}", "Mendokumentasikan kebutuhan sebelum rebuild.")
s = s.replace("{{section-2-actors-table}}", "| Kasir | Melakukan pembayaran | `10-domains/pay.md` |")
s = s.replace("{{journey-settle}}", "```mermaid\nflowchart TD\n  A[Tarik mutasi] --> B[Rekonsiliasi]\n```")
open(p, "w", encoding="utf-8").write(s)
PY
if grep -qE '\{\{[a-z0-9_-]+\}\}' "$PR"; then fail "slots left after simulated fill"; else ok "all model slots fillable via targeted edits"; fi
bash "$MRK" --prd="$PR" --cwd="$K" --kb="$K/.mega-sdd/knowledge-base" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && ok "check-prd-markers.sh exit 0 on builder output + model fill (markers preserved)" || fail "markers check rc=$RC"
bash "$CMAP" --vault="$K/.mega-sdd" --cwd="$K" --mode=reverse --doc=prd </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && ok "citation map --doc=prd exit 0 on reverse output" || fail "prd citation map rc=$RC"

note "== ROUND-1 regressions (F1–F6) =="
# F1: FR-id prefix must not steal status/verdict; F2: nested units layout cites the real path;
# F3: #### FR headings parsed; F5: squads split-per-entry
PH="$WORK/hard"; VH="$PH/.mega-sdd/vaults/v1"
mkdir -p "$VH/units/U-010" "$VH/_meta" "$VH/bolts/U-010"
( cd "$PH" && git init -q . )
printf '{"project_name":"hard","author":"T"}\n' > "$VH/vault.json"
printf '# F\n\n## FR-001 — Kecil\n\nSatu.\n\n#### FR-0010 — Besar\n\nDua.\n\n**Priority:** LOW\n' > "$VH/02-functional.md"
printf '# B\n\n- [C-001] FR-0010 flow — CONFIRMED\n- [C-002] FR-001 flow — CONFLICT\n' > "$VH/binding.md"
printf -- '---\nunit_id: U-010\nimplements_claim: FR-0010\n---\n# U-010 — Impl besar\n\n## Acceptance\n\n- command: make t\n- expected: pass\n' > "$VH/units/U-010/unit.md"
printf 'bolt_status: completed\ncommit: 1234567890\n' > "$VH/bolts/U-010/bolt-report.md"
printf -- '- squad: Dev\n  lead_name: Budi\n  responsibility: koding\n- squad: Analyst\n' > "$VH/_meta/squads.yaml"
bash "$FSD" --vault="$VH" --cwd="$PH" </dev/null >/dev/null 2>&1 || fail "hard vault builder rc"
FH="$VH/fsd/FSD.md"
grep -qE '\| FR-001 \| Kecil \| MEDIUM \| Specified \(no unit\) \|' "$FH" && ok "F1: FR-001 NOT stolen by FR-0010's unit/bolt (prefix-immune)" || fail "F1 regressed: $(grep '| FR-001 ' "$FH")"
grep -qF 'CONFLICT (per `binding.md` claim C-002)' "$FH" && ok "F1: FR-001 verdict = CONFLICT from ITS line (not C-001's CONFIRMED)" || fail "F1 verdict regressed"
grep -q '| FR-0010 | Besar | LOW | Implemented |' "$FH" && ok "F3: #### FR heading parsed with its own priority" || fail "F3 regressed"
grep -q '\[Source: units/U-010/unit.md' "$FH" && ok "F2: nested unit cited at its REAL path" || fail "F2 regressed"
bash "$CMAP" --vault="$VH" --cwd="$PH" --mode=post-dev </dev/null >/dev/null 2>&1 && ok "F2: citation map resolves the nested-unit citation (exit 0)" || fail "F2 downstream regressed"
grep -q '| Dev | Budi | koding |' "$FH" && grep -q '| Analyst | (unspecified) |  |' "$FH" && ok "F5: squads entries isolated (no cross-entry bleed, no dropped row)" || fail "F5 regressed"
# F4: fenced marker must not be harvested; F6: same-slug workflows get distinct slots
KH="$WORK/kbh"; mkdir -p "$KH/.mega-sdd/knowledge-base/10-domains" "$KH/.mega-sdd/knowledge-base/20-workflows"
( cd "$KH" && git init -q . )
printf '# KB\n' > "$KH/.mega-sdd/knowledge-base/README.md"
printf '# D\n\n- [VERIFIED] Klaim asli\n\n```text\n- [VERIFIED] contoh di dalam fence\n```\n' > "$KH/.mega-sdd/knowledge-base/10-domains/d.md"
printf '# W1\n\n## Steps\n\n1. A\n' > "$KH/.mega-sdd/knowledge-base/20-workflows/pay-out.md"
printf '# W2\n\n## Steps\n\n1. B\n' > "$KH/.mega-sdd/knowledge-base/20-workflows/pay_out.md"
OUT=$(bash "$PRD" --out-root="$KH/.mega-sdd" --cwd="$KH" --mode=reverse </dev/null 2>&1)
PRH="$KH/.mega-sdd/prd/PRD.md"
if grep -q 'contoh di dalam fence \[Source' "$PRH"; then fail "F4 regressed: fenced example harvested as a claim"; else ok "F4: fence-quoted marker NOT harvested"; fi
printf '%s' "$OUT" | grep -q 'markers=1/0/0' && ok "F4: marker count excludes the fenced line" || fail "F4 count wrong: $OUT"
printf '%s' "$OUT" | grep -q 'journey-pay-out,' && printf '%s' "$OUT" | grep -q 'journey-pay-out-2' \
  && ok "F6: same-slug workflows got DISTINCT journey slots" || fail "F6 regressed: $OUT"

note "== REAL vault contract (round-1 ADV-005/007/008: fixtures must match the producers) =="
PR2="$WORK/realshape"; VR="$PR2/.mega-sdd/vaults/v1"
mkdir -p "$VR" "$PR2/.mega-sdd/codebase"
( cd "$PR2" && git init -q . )
printf '{"project_name":"real","author":"T","open_questions":[{"id":"OQ-R-1","question":"Kebijakan carry-over?","priority":"P1","status":"open"}]}\n' > "$VR/vault.json"
printf '# Overview\n\n## Product\n\nAplikasi cuti multi-tenant.\n\n## Problem\n\nSpreadsheet tidak skala.\n\n## Success criteria\n\n- Approval < 1 hari\n\n## Out of Scope\n\n- Mobile native\n' > "$VR/01-overview.md"
printf '# Map\n\n## 1. Top-level structure\n\n| Module | Path | Responsibility |\n|---|---|---|\n| Core | app | inti |\n\n## 2. Public interfaces\n\n| File | Type | Symbol | Signature | Last_Scanned_Sha256 |\n|---|---|---|---|---|\n| app/L.php | fn | login | login(email) | abc |\n\n## 4. Data models / Schemas\n\n- User — akun\n' > "$PR2/.mega-sdd/codebase/codebase-map.md"
bash "$FSD" --vault="$VR" --cwd="$PR2" </dev/null >/dev/null 2>&1 || fail "real-shape builder rc"
FR2="$VR/fsd/FSD.md"
grep -q 'Aplikasi cuti multi-tenant.' "$FR2" && ok "ADV-007: §Product accepted as §1 content (real generate-intent vocabulary)" || fail "ADV-007 regressed: §1 empty on a real-shaped overview"
grep -q 'Approval < 1 hari' "$FR2" && grep -q 'Mobile native' "$FR2" && ok "ADV-007: §Success criteria/§Out of Scope land in §2" || fail "ADV-007 §2 regressed"
grep -q '| login | login(email) | app/L.php |' "$FR2" && ok "ADV-008: numbered map heading + name-mapped columns (Symbol/Signature/File)" || fail "ADV-008 regressed"
if grep -q '| File | fn |' "$FR2"; then fail "ADV-008: header row leaked as data"; else ok "ADV-008: header row skipped"; fi
if grep -q '^- Slot semantics' "$FR2"; then fail "ADV-014: template-internal ToC leaked into the FSD"; else ok "ADV-014: no template ToC in the emitted doc"; fi
OUT=$(bash "$PRD" --out-root="$VR" --cwd="$PR2" --mode=forward </dev/null 2>&1)
grep -qF '| OQ-R-1 | Kebijakan carry-over? | P1 | `vault.json` |' "$VR/prd/PRD.md" && ok "ADV-009: PRD §6 falls back to vault.json.open_questions[]" || fail "ADV-009 regressed"
# ADV-004: a bolt-report with NO bolt_status must never read as completed
mkdir -p "$VR/units" "$VR/bolts/U-001"
printf -- '---\nunit_id: U-001\nimplements_claim: FR-001\n---\n# U-001\n\n## Acceptance\n\n- command: make t\n- expected: pass\n' > "$VR/units/U-001.md"
printf '# report with no status field\n' > "$VR/bolts/U-001/bolt-report.md"
printf '# F\n\n## FR-001 — Login\n\nDesc.\n' > "$VR/02-functional.md"
bash "$FSD" --vault="$VR" --cwd="$PR2" --mode=post-dev </dev/null >/dev/null 2>&1
if grep -q '| FR-001 | Login | MEDIUM | Implemented |' "$FR2"; then fail "ADV-004 regressed: absent bolt_status read as completed"; else ok "ADV-004: absent bolt_status is never success (status stays non-Implemented)"; fi
# ADV-002: marker-carrying KB workflow must not halt the markers check
KM="$WORK/kbm"; mkdir -p "$KM/.mega-sdd/knowledge-base/20-workflows"
( cd "$KM" && git init -q . )
printf '# KB\n' > "$KM/.mega-sdd/knowledge-base/README.md"
printf '# Alur bayar\n\n- [VERIFIED] Dipicu kasir\n\n```mermaid\nflowchart TD\n  A-->B\n```\n' > "$KM/.mega-sdd/knowledge-base/20-workflows/bayar.md"
bash "$PRD" --out-root="$KM/.mega-sdd" --cwd="$KM" --mode=reverse </dev/null >/dev/null 2>&1
PRM="$KM/.mega-sdd/prd/PRD.md"
python3 - "$PRM" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
for a in ("{{section-1-background}}", "{{section-1-purpose}}"):
    s = s.replace(a, "Narasi.")
s = s.replace("{{section-2-actors-table}}", "| Kasir | bayar | `kb` |")
open(sys.argv[1], "w", encoding="utf-8").write(s)
PY
bash "$MRK" --prd="$PRM" --cwd="$KM" --kb="$KM/.mega-sdd/knowledge-base" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && ok "ADV-002: line-anchored journey citation passes the markers check on a marker-carrying workflow" || fail "ADV-002 regressed: markers check rc=$RC"

note "== WIRING pins =="
grep -q 'build-fsd-core.sh --vault=' "${ROOT}/plugins/mega-sdd/skills/emit-fsd/SKILL.md" && ok "emit-fsd SKILL instructs the builder" || fail "emit-fsd not rewired"
grep -q 'build-prd-core.sh --out-root=' "${ROOT}/plugins/mega-sdd/skills/emit-prd/SKILL.md" && ok "emit-prd SKILL instructs the builder" || fail "emit-prd not rewired"
grep -qF 'EXECUTED BY `scripts/build-fsd-core.sh`' "${ROOT}/plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md" && ok "section-mapping declares the builder contract" || fail "mapping note missing"
grep -q 'fsd-template.md' "$FSD" && ! grep -q '## 1. Overview' "$FSD" && ok "builder parses the template (no hand-duplicated skeleton)" || fail "skeleton duplicated in builder"

if [ "$FAILED" -eq 0 ]; then note "ALL 5E DOC-BUILDER PROOFS OK"; else note "5e proofs FAILED"; fi
exit $FAILED

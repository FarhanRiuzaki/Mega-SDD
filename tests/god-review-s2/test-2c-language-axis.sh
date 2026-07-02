#!/usr/bin/env bash
# test-2c-language-axis.sh — god-review stage 2, Batch 2C (High).
# Pins the language-axis generalization of the operator-UX rails.
#
# generate-intent emits the vault in the INPUT language (Indonesian PRD → Indonesian
# vault). The operator-workflow / operator-surface / flow-staging detectors were keyed
# on English-only vocabulary (approve/reject/review/confirm, maker→checker), so on an
# Indonesian maker→checker vault the whole operator-UX block went inert → silent PASS —
# the exact vault the rails were built to protect. This matrix pins:
#   H1  detection fires on an INDONESIAN maker→checker vault via language-invariant
#       structural markers (stages:/stage_id:/actor_role: + stateDiagram) — never silent-PASS;
#       an English vault still yields operator_surface_missing (regression).
#   H4  Rail-2 (design_source_oq_missing) runs WITHOUT a workflow flow and on an
#       Indonesian vault (its inputs — design_system_flags + OQ-DESIGN tokens — are
#       language-invariant); pre-fix it was gated behind the English workflow detector.
#   M2  validate-vault-flow-staging flags an Indonesian stateDiagram flow with no stages.
#
# Run: bash tests/god-review-s2/test-2c-language-axis.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OQ="${ROOT}/plugins/mega-sdd/scripts/validate-vault-oqs.sh"
FS="${ROOT}/plugins/mega-sdd/scripts/validate-vault-flow-staging.sh"
for f in "$OQ" "$FS"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t lang2c)"
trap 'rm -rf "$WORK"' EXIT

# mkv <sub> <04-flows body> <02-arch body> <vault.json>
mkv() {
  local d="$WORK/$1/.mega-sdd/vaults/tv"; mkdir -p "$d"
  printf '%s\n' "$2" > "$d/04-flows.md"
  printf '%s\n' "$3" > "$d/02-architecture.md"
  printf '%s\n' "$4" > "$d/vault.json"
}
runoq() { bash "$OQ" --cwd="$WORK/$1" --file-path="$WORK/$1/.mega-sdd/vaults/tv/04-flows.md" 2>/dev/null; }
halts() { OUT="$1" python3 -c "
import json,os
try: st=json.loads(os.environ['OUT']); print(' '.join(i.get('halt_type','') for i in st.get('issues',[])))
except Exception as e: print('ERR')"; }

VJ_PLAIN='{"open_questions":[]}'
VJ_DESIGN_GAP='{"open_questions":[],"design_system_flags":{"HAS_UI_COMPONENTS":true,"HAS_TOKENS":false,"HAS_A11Y":false,"HAS_VOICE_BRAND":false}}'

# ── Case 1: INDONESIAN maker→checker workflow, NO operator surface, NO design OQ ──
# Structural markers (stages/stage_id/actor_role + stateDiagram) are language-invariant.
mkv id-wf '### F-U-001: Persetujuan Transaksi (pembuat→pemeriksa)

**Stages**
```yaml
stages:
  - stage_id: "S1"
    actor_role: "Pembuat"
    input_fields: [jumlah, penerima]
  - stage_id: "S2"
    actor_role: "Pemeriksa"
    input_fields: [keputusan]
```

**Diagram status alur kerja**
```mermaid
stateDiagram-v2
  [*] --> Diajukan
  Diajukan --> Ditinjau
  Ditinjau --> Disetujui
  Ditinjau --> Ditolak
```' \
'# Arsitektur

Sistem ini memakai lapisan layanan dan basis data untuk memproses setiap pengajuan
transaksi dari pengguna. Setiap pengajuan disimpan lalu diteruskan ke tahap berikutnya
sesuai peran yang berlaku pada alur persetujuan berjenjang.' \
"$VJ_PLAIN"

H1="$(halts "$(runoq id-wf)")"
case "$H1" in
  *operator_surface_missing*|*operator_surface_uncheckable*)
    ok "ID maker→checker workflow is NOT silent-PASS — operator rail fires ($H1)";;
  *) fail "ID workflow silent-PASSed (pre-fix bug): '$H1'";;
esac
case "$H1" in
  *operator_surface_uncheckable*) ok "ID non-English → operator_surface_uncheckable (SKIP-advisory, not false-missing)";;
  *) note "  (note: ID case fired '$H1' — acceptable as long as a rail fired)";;
esac

# ── Case 2: ENGLISH maker→checker workflow, NO operator surface → missing (regression) ──
mkv en-wf '### F-U-001: Transaction Approval (maker→checker)

1. Maker submits the transaction request → Checker
2. Checker reviews the submitted request
3. Checker approves or rejects the transaction' \
'# Architecture

The system has a service layer and a database. Each request is processed by the
service and then stored for the next actor to handle in the approval workflow.' \
"$VJ_PLAIN"
H2="$(halts "$(runoq en-wf)")"
case "$H2" in
  *operator_surface_missing*) ok "EN maker→checker, no surface → operator_surface_missing (regression intact)";;
  *) fail "EN workflow should fire operator_surface_missing: '$H2'";;
esac

# ── Case 3: ENGLISH workflow WITH an operator surface → quiet (no false-positive) ──
mkv en-surf '### F-U-001: Transaction Approval (maker→checker)

1. Maker submits the transaction → Checker
2. Checker reviews and then approves or rejects' \
'# Architecture

The Checker uses a pending-approvals worklist (inbox) with an approve / reject decision
panel and an audit trail timeline showing each workflow transition.' \
"$VJ_PLAIN"
H3="$(halts "$(runoq en-surf)")"
case "$H3" in
  *operator_surface_missing*|*operator_surface_uncheckable*) fail "EN vault WITH a worklist/inbox surface should be quiet: '$H3'";;
  *) ok "EN workflow WITH operator surface → quiet (no false operator_surface_*)";;
esac

# ── Case 4 (H4): NO workflow flow at all + design gap → design_source_oq_missing fires ──
# Pre-fix this rail was gated behind the English workflow detector → unreachable here.
mkv h4-en '### F-U-001: View Dashboard

1. User opens the dashboard
2. System renders the widgets' \
'# Architecture

The dashboard shows widgets rendered by the frontend components.' \
"$VJ_DESIGN_GAP"
H4="$(halts "$(runoq h4-en)")"
case "$H4" in
  *design_source_oq_missing*) ok "H4: design_source_oq_missing fires with NO workflow flow (decoupled)";;
  *) fail "H4: design_source_oq_missing should fire without a workflow: '$H4'";;
esac

# ── Case 5 (H4 + language): Indonesian vault, no workflow, design gap → still fires ──
mkv h4-id '### F-U-001: Lihat Dasbor

1. Pengguna membuka dasbor
2. Sistem menampilkan widget' \
'# Arsitektur

Dasbor menampilkan widget yang ditampilkan oleh komponen antarmuka.' \
"$VJ_DESIGN_GAP"
H5="$(halts "$(runoq h4-id)")"
case "$H5" in
  *design_source_oq_missing*) ok "H4: design_source_oq_missing fires on an Indonesian vault (language-invariant)";;
  *) fail "H4: design_source_oq_missing should fire on ID vault: '$H5'";;
esac

# ── Case 6 (M2): Indonesian stateDiagram flow, no stages block, no _kb_source ──
mkv m2-id '### F-U-001: Alur Persetujuan

```mermaid
stateDiagram-v2
  [*] --> Diajukan
  Diajukan --> Ditinjau
  Ditinjau --> Disetujui
```' \
'# Arsitektur

Alur persetujuan berjenjang tanpa blok stages yang eksplisit.' \
"$VJ_PLAIN"
FSOUT="$(bash "$FS" --cwd="$WORK/m2-id" 2>/dev/null)"
M2="$(OUT="$FSOUT" python3 -c "
import json,os
try: r=json.loads(os.environ['OUT']); print(' '.join(a.get('halt_type','') for a in r.get('advisories',[])))
except Exception: print('ERR')")"
case "$M2" in
  *vault_flow_staging_missing*) ok "M2: flow-staging flags an Indonesian stateDiagram flow with no stages (language-invariant)";;
  *) fail "M2: flow-staging should advise on ID stateDiagram flow: '$M2'";;
esac

# ── round-2 (review): benign English stateDiagram must NOT cry-wolf uncheckable ──
mkv en-lifecycle '### F-U-001: Order Lifecycle

```mermaid
stateDiagram-v2
  [*] --> Placed
  Placed --> Shipped
  Shipped --> Delivered
  Delivered --> [*]
```' \
'# Architecture

The order moves through a simple lifecycle from placed to shipped to delivered. There is
no human decision step and no second actor; the system advances the state automatically.' \
"$VJ_PLAIN"
H6="$(halts "$(runoq en-lifecycle)")"
case "$H6" in
  *operator_surface_uncheckable*|*operator_surface_missing*) fail "r2: benign English lifecycle stateDiagram should NOT fire an operator rail: '$H6'";;
  *) ok "r2: benign English lifecycle stateDiagram → quiet (no false uncheckable/missing)";;
esac

# ── round-2: single-actor wizard (stages block, ONE actor_role) must NOT fire missing ──
mkv wizard '### F-U-001: Onboarding Wizard

**Stages**
```yaml
stages:
  - stage_id: "S1"
    actor_role: "Applicant"
    input_fields: [name, email]
  - stage_id: "S2"
    actor_role: "Applicant"
    input_fields: [address]
```' \
'# Architecture

A single applicant fills a three-step onboarding wizard. Each step collects a few fields
and the applicant advances to the next; there is no second reviewer and no approval.' \
"$VJ_PLAIN"
H7="$(halts "$(runoq wizard)")"
case "$H7" in
  *operator_surface_missing*) fail "r2: single-actor wizard (1 role) should NOT fire operator_surface_missing: '$H7'";;
  *) ok "r2: single-actor wizard (1 distinct actor_role) → no false operator_surface_missing";;
esac

# ── round-2: soft advisory (uncheckable) → status WARN, hard gap (missing) → status FAIL ──
stat() { OUT="$1" python3 -c "import json,os;print(json.loads(os.environ['OUT']).get('status'))" 2>/dev/null; }
[ "$(stat "$(runoq id-wf)")" = "WARN" ] && ok "r2: operator_surface_uncheckable → status WARN (not a blocking FAIL in analyze)" || fail "r2: uncheckable should be WARN, got $(stat "$(runoq id-wf)")"
[ "$(stat "$(runoq en-wf)")" = "FAIL" ] && ok "r2: operator_surface_missing → status FAIL (real gap stays loud)" || fail "r2: missing should be FAIL"

if [ "$FAILED" -eq 0 ]; then note "ALL 2C OK"; else note "2C had failures"; fi
exit $FAILED

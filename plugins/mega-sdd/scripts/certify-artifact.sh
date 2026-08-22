#!/usr/bin/env bash
# certify-artifact.sh — the adoption certifier (P2, spec
# 2026-07-19-v5-execution-spec.md P2 row + decision 7; research
# 2026-07-19-v5-architecture-research.md §3 entry matrix).
#
# Externally-authored artifacts get a first-class adoption story at every rung:
# ONE deterministic verdict from the closed vocabulary
#   CERTIFIED            — artifact enters its rung as-is
#   CERTIFIED_DEGRADED   — enters, with a stated degradation (e.g. the P0
#                          unverified-external map provenance note)
#   DEMOTE               — offered a LOWER rung (e.g. foreign vault grammar →
#                          PRD-rung re-ingest). Under --auto a DEMOTE is ALWAYS
#                          a confirmed C2 halt (adoption_demote_confirm,
#                          decision 7) — it burns generate-intent tokens and
#                          produces a DIFFERENT vault than the user placed.
#   REJECTED             — cannot enter (binary PRD, degenerate map, not-a-vault)
# every verdict with keterangan (Indonesian: why + what to do next).
#
# BINDING MIGRATION GUARANTEE: a v4-mega-sdd-authored artifact may NEVER receive
# REJECTED — CERTIFIED_DEGRADED is the floor. Structurally: REJECTED lanes only
# fire on shapes a v4 writer can never emit (binary file, map missing sections
# WITHOUT mega-sdd provenance, vault without 00-index, unit without frontmatter),
# and the map rung additionally floors a mega-sdd-provenance map at
# CERTIFIED_DEGRADED even when degenerate. Pinned by
# tests/state/test-certify-artifact.sh (the migration sweep).
#
# REUSE, NEVER RE-IMPLEMENT: each rung maps the OUTCOMES of the existing
# validator/deriver for that rung —
#   prd   → shape sniffer (NEW, heuristic-only: classifies likely-PRD vs
#           arbitrary-text vs non-text; it gates NOTHING downstream)
#   map   → validate-codebase-map.sh
#   vault → derive-vault-json.sh (exit-2 KETERANGAN echoed verbatim)
#   kb    → validate-kb.sh --surface=output + --surface=markers over the SAME file
#           selection run-analyze.sh uses (10-domains/20-workflows/40-business-rules;
#           markers over 10-domains) — the citations surface needs
#           --legacy-root and stays in the extract/bind lane
#   units → validate-unit-spec.sh (file staged into a scratch vault layout so
#           the validator's path filter accepts it)
# Validator state files land in a SCRATCH cwd — certify writes NOTHING into the
# user's project except (vault rung) the vault.json that derive-vault-json
# legitimately derives.
#
# Usage: certify-artifact.sh --cwd=<root> --rung=<prd|map|vault|kb|units> --path=<artifact>
# Output: `VERDICT: <verdict> <rung> <path>` + KETERANGAN block (Indonesian).
# Exit: 0 = CERTIFIED | CERTIFIED_DEGRADED; 3 = DEMOTE offered; 4 = REJECTED;
#       2 = usage / internal error.

set -uo pipefail

CWD=""
RUNG=""
APATH=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --rung=*) RUNG="${arg#*=}" ;;
    --path=*) APATH="${arg#*=}" ;;
    *) echo "certify-artifact: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

usage() { echo "usage: certify-artifact.sh --cwd=<root> --rung=<prd|map|vault|kb|units> --path=<artifact>" >&2; exit 2; }

[ -n "$CWD" ] && [ -n "$RUNG" ] && [ -n "$APATH" ] || usage
case "$RUNG" in prd|map|vault|kb|units) ;; *) usage ;; esac
[ -d "$CWD" ] || { echo "certify-artifact: --cwd not a directory: $CWD" >&2; exit 2; }
[ -e "$APATH" ] || { echo "certify-artifact: --path not found: $APATH" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
# Scratch cwd: reused validators write their state files here, never into the
# user's project (writing e.g. a one-unit .unit-spec-state.json into a real
# project would clobber PROJECT-WIDE gate state).
SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t certify)"
trap 'rm -rf "$SCRATCH"' EXIT

# emit <verdict> <exit-code> <<keterangan-on-stdin>>
emit() {
  local verdict="$1" rc="$2"
  printf 'VERDICT: %s %s %s\n' "$verdict" "$RUNG" "$APATH"
  printf 'KETERANGAN:\n'
  sed 's/^/  /'
  exit "$rc"
}

# ── prd — shape sniffer (heuristic-only; gates nothing downstream) ────────────
if [ "$RUNG" = "prd" ]; then
  [ -f "$APATH" ] || { echo "certify-artifact: --rung=prd needs a file, got a directory: $APATH" >&2; exit 2; }
  APATH="$APATH" python3 <<'PYEOF'
import os, re, sys

path = os.environ["APATH"]
with open(path, "rb") as f:
    raw = f.read(262144)

verdict = None
lines = []
if b"\x00" in raw:
    verdict = "REJECTED"
else:
    text = raw.decode("utf-8", errors="replace")
    if text and text.count("�") / max(len(text), 1) > 0.05:
        verdict = "REJECTED"

if verdict == "REJECTED":
    lines = [
        "File biner / bukan teks — tidak bisa dibaca sebagai dokumen PRD.",
        "Selanjutnya: sediakan dokumen teks (.md/.pdf yang sudah diekstrak/.docx/.txt),",
        "atau jelaskan maksud file ini supaya lane yang benar bisa dipilih.",
    ]
else:
    headings = len(re.findall(r"^#{1,6}\s+\S", text, re.MULTILINE))
    req_pat = re.compile(
        r"\b(shall|must|should|requirements?|acceptance criteria|"
        r"user stor(?:y|ies)|as an? .{1,40}? i want|harus|wajib|kebutuhan|"
        r"fitur|kriteria|scope|goals?)\b"
        r"|\bAC[- ]?\d|\bFR?-\d|\bUS-\d"
        r"|^\s*-\s\[\s?\]",
        re.IGNORECASE | re.MULTILINE,
    )
    req_hits = len(req_pat.findall(text))
    words = len(text.split())
    stats = "(%d heading, %d sinyal requirement/AC, %d kata)" % (headings, req_hits, words)
    looks_like_code = bool(re.search(
        r"(?m)^\s*(<\?php|import\s+\w|def\s+\w+\(|function\s+\w+\(|class\s+\w+|package\s+\w)", text))
    if words >= 60 and headings >= 2 and req_hits >= 3:
        verdict = "CERTIFIED"
        lines = [
            "Dokumen terdeteksi berbentuk PRD %s." % stats,
            "Siap masuk `generate-intent <path>` (Mode A).",
            "Catatan: sniffer ini hanya MENGKLASIFIKASI — tidak ada gate downstream;",
            "grounding tetap ditegakkan oleh pipeline (OQ, binding, citation).",
        ]
    else:
        verdict = "CERTIFIED_DEGRADED"
        lines = [
            "Dokumen teks tapi TIDAK berbentuk PRD %s —" % stats,
            "struktur heading/pola requirement/panjang di bawah ambang sniffer.",
            "Tetap bisa masuk `generate-intent`, tapi vault-nya bakal berat di Open",
            "Question. Selanjutnya: lengkapi dokumen jadi PRD, ATAU pakai Mode B",
            "(`generate-intent --from-prompt`) untuk brief bebas.",
        ]
        if looks_like_code:
            lines.append(
                "File ini kelihatan seperti SOURCE CODE — kalau ini codebase, lane yang"
            )
            lines.append(
                "benar adalah `scan-codebase` / `extract-intelligence`, bukan rung PRD."
            )

print("VERDICT: %s prd %s" % (verdict, path))
print("KETERANGAN:")
for ln in lines:
    print("  " + ln)
sys.exit(4 if verdict == "REJECTED" else 0)
PYEOF
  exit $?
fi

# ── map — validate-codebase-map.sh outcome mapping ───────────────────────────
if [ "$RUNG" = "map" ]; then
  [ -f "$APATH" ] || { echo "certify-artifact: --rung=map needs a file, got a directory: $APATH" >&2; exit 2; }
  MAP_JSON="$(bash "${SCRIPT_DIR}/validate-codebase-map.sh" --cwd="$SCRATCH" --file-path="$APATH" </dev/null 2>/dev/null | tail -n 1)"
  RC=$?
  MAP_JSON="$MAP_JSON" APATH="$APATH" python3 <<'PYEOF'
import json, os, re, sys

path = os.environ["APATH"]
try:
    d = json.loads(os.environ.get("MAP_JSON") or "{}")
except Exception:
    d = {}
status = d.get("status")
if status not in ("PASS", "WARN", "FAIL"):
    print("certify-artifact: validate-codebase-map.sh produced no verdict", file=sys.stderr)
    sys.exit(2)

checks = {c.get("check"): c for c in d.get("checks", [])}
issues = d.get("issues", [])
issue_types = {i.get("halt_type") for i in issues}
sections_fail = checks.get("sections_complete", {}).get("status") == "FAIL"
unreadable = "codebase_map_unreadable" in issue_types

# Migration guarantee: a mega-sdd-provenance map (generated_by mentions mega-sdd)
# is floored at CERTIFIED_DEGRADED — never REJECTED.
megasdd_authored = False
try:
    with open(path, encoding="utf-8", errors="replace") as f:
        head = f.read(4096)
    m = re.match(r"^---\n(.*?)\n---", head, re.DOTALL)
    if m and re.search(r"(?m)^\s*generated_by\s*:.*mega-sdd", m.group(1)):
        megasdd_authored = True
except OSError:
    pass

warn_notes = [
    "- %s: %s" % (c.get("check"), c.get("detail") or "")
    for c in d.get("checks", []) if c.get("status") == "WARN"
]

if status in ("PASS", "WARN"):
    verdict, rc = "CERTIFIED", 0
    lines = ["Peta codebase lolos validate-codebase-map.sh (frontmatter + 7 section lengkap).",
             "Siap dipakai `bind-codebase` sebagai ground truth."]
    if warn_notes:
        lines.append("Catatan (advisory, tidak menahan):")
        lines.extend(warn_notes)
elif unreadable or (sections_fail and not megasdd_authored):
    verdict, rc = "REJECTED", 4
    missing = next((i.get("missing") for i in issues if i.get("halt_type") == "codebase_map_sections_incomplete"), None)
    lines = ["Peta ini DEGENERATE — bukan codebase-map yang bisa dipakai binding."]
    if unreadable:
        lines.append("File tidak terbaca sebagai teks.")
    if missing:
        lines.append("Section wajib yang hilang: %s." % ", ".join(missing))
    lines += [
        "Tawaran DEMOTE ke rung scan: buang peta ini dan jalankan",
        "`scan-codebase` — men-generate ulang codebase-map ber-provenance",
        "langsung dari repo (deterministik, bukan menebak isi peta lama).",
    ]
elif sections_fail and megasdd_authored:
    verdict, rc = "CERTIFIED_DEGRADED", 0
    lines = [
        "Peta ber-provenance mega-sdd tapi section wajibnya tidak lengkap —",
        "kemungkinan terpotong / teredit manual. Migration guarantee: artefak",
        "buatan mega-sdd tidak pernah REJECTED; floor-nya CERTIFIED_DEGRADED.",
        "Selanjutnya: jalankan `scan-codebase` untuk restamp peta utuh.",
    ]
else:
    # Sections present; frontmatter/provenance missing → the P0
    # unverified-external lane (bind SKILL.md Step 1).
    verdict, rc = "CERTIFIED_DEGRADED", 0
    lines = [
        "Section lengkap tapi frontmatter provenance hilang/invalid — peta ini",
        "ditulis di luar mega-sdd (unverified-external).",
        "Bind TETAP jalan, tapi presisi binding turun ke klasifikasi biner dan",
        "binding.md akan mencatat `codebase_map_provenance: \"unverified-external\"`",
        "(tidak pernah `snapshot-verified` untuk peta seperti ini).",
        "Selanjutnya: jalankan `scan-codebase` untuk map ber-provenance",
        "dengan presisi penuh (field-level diff).",
    ]

print("VERDICT: %s map %s" % (verdict, path))
print("KETERANGAN:")
for ln in lines:
    print("  " + ln)
sys.exit(rc)
PYEOF
  exit $?
fi

# ── vault — derive-vault-json.sh outcome mapping (exit-2 KETERANGAN echoed) ──
if [ "$RUNG" = "vault" ]; then
  [ -d "$APATH" ] || { echo "certify-artifact: --rung=vault needs a directory, got a file: $APATH" >&2; exit 2; }
  DERIVE_OUT="$(bash "${SCRIPT_DIR}/derive-vault-json.sh" --vault "$APATH" </dev/null 2>&1)"
  RC=$?
  case "$RC" in
    0)
      emit "CERTIFIED" 0 <<EOF
Dokumen vault cocok dengan grammar mega-sdd — vault.json berhasil diderivasi
(sekarang ada di ${APATH%/}/vault.json; satu-satunya file yang ditulis).
Siap dikonsumsi pipeline: bind-codebase / generate-units membaca manifest ini.
$(printf '%s\n' "$DERIVE_OUT" | grep '^WARN' | sed 's/^/Catatan deriver: /')
EOF
      ;;
    2)
      emit "DEMOTE" 3 <<EOF
Grammar mismatch — dokumen di direktori ini TIDAK cocok dengan grammar vault
mega-sdd (derive-vault-json.sh exit 2; vault.json TIDAK ditulis).
Output deriver (verbatim):
$(printf '%s\n' "$DERIVE_OUT" | sed 's/^/  | /')
Tawaran DEMOTE (butuh konfirmasi lo — decision 7):
  (a) RE-INGEST — perlakukan dokumen vault ini sebagai input rung PRD:
      \`generate-intent\` membacanya sebagai dokumen sumber dan membangun vault
      BARU ber-grammar mega-sdd. Konsekuensi: burn token generate-intent dan
      hasilnya vault yang BERBEDA dari yang lo taruh — makanya di --auto ini
      selalu halt C2 \`adoption_demote_confirm\`, tidak pernah jalan sendiri.
  (b) MANUAL FIX — perbaiki dokumen mengikuti template generate-intent
      (skills/generate-intent/references/), lalu jalankan ulang certify.
EOF
      ;;
    3)
      emit "REJECTED" 4 <<EOF
Direktori ini bukan vault mega-sdd — vault.md (layout-2) maupun 00-index.md
(legacy) tidak ada / direktori tidak terbaca (derive-vault-json.sh exit 3).
$(printf '%s\n' "$DERIVE_OUT" | sed 's/^/  | /')
Selanjutnya: kalau ini kumpulan dokumen spec, masuk lewat rung PRD —
\`certify-artifact --rung=prd --path=<file>\` per dokumen, lalu \`generate-intent\`.
EOF
      ;;
    4)
      echo "certify-artifact: vault.json.lock ditahan proses lain (derive-vault-json exit 4) — coba lagi." >&2
      exit 2
      ;;
    *)
      echo "certify-artifact: derive-vault-json.sh internal error (rc=$RC)" >&2
      printf '%s\n' "$DERIVE_OUT" >&2
      exit 2
      ;;
  esac
fi

# ── kb — validate-kb.sh output/markers surfaces over run-analyze's selection ─
if [ "$RUNG" = "kb" ]; then
  [ -d "$APATH" ] || { echo "certify-artifact: --rung=kb needs a directory, got a file: $APATH" >&2; exit 2; }
  KB_FILES="$SCRATCH/kb-files.txt"
  : > "$KB_FILES"
  for sub in 10-domains 20-workflows 40-business-rules; do
    [ -d "$APATH/$sub" ] && find "$APATH/$sub" -name "*.md" -not -path "*/.archived/*" >> "$KB_FILES" 2>/dev/null
  done
  if [ ! -s "$KB_FILES" ]; then
    ANY_MD=$(find "$APATH" -name "*.md" 2>/dev/null | head -n 1)
    if [ -n "$ANY_MD" ]; then
      emit "DEMOTE" 3 <<EOF
Ada dokumen markdown, tapi struktur folder BUKAN knowledge base mega-sdd
(tidak ada 10-domains/ / 20-workflows/ / 40-business-rules/ berisi domain file) —
grammar KB tidak pernah diadopsi di sini.
Tawaran DEMOTE (butuh konfirmasi lo — decision 7):
  (a) RE-INGEST — perlakukan dokumen-dokumen ini sebagai input rung PRD
      (\`generate-intent\` per dokumen / gabungan). Konsekuensi: burn token dan
      hasilnya artefak BARU — di --auto selalu halt C2 \`adoption_demote_confirm\`.
  (b) RE-EXTRACT — kalau sumber aslinya codebase legacy, jalankan
      \`extract-intelligence <legacy>\` untuk KB ber-grammar mega-sdd.
EOF
    else
      emit "REJECTED" 4 <<EOF
Bukan knowledge base — tidak ada satu pun file markdown di bawah direktori ini.
Selanjutnya: tunjuk direktori KB yang benar, atau bangun KB via
\`extract-intelligence <legacy>\`.
EOF
    fi
  fi
  TOTAL=0; FAILED=0; NOFM=0; DETAILS="$SCRATCH/kb-details.txt"; : > "$DETAILS"
  while IFS= read -r kf; do
    TOTAL=$((TOTAL + 1))
    OUT_ALL="$(bash "${SCRIPT_DIR}/validate-kb.sh" --surface=output --cwd="$SCRATCH" --file-path="$kf" </dev/null 2>/dev/null)"
    ORC=$?
    OUT_JSON="$(printf '%s\n' "$OUT_ALL" | tail -n 1)"
    MRC=0
    case "$kf" in
      */10-domains/*)
        bash "${SCRIPT_DIR}/validate-kb.sh" --surface=markers --cwd="$SCRATCH" --file-path="$kf" </dev/null >/dev/null 2>&1
        MRC=$? ;;
    esac
    FM_FAIL=$(printf '%s' "$OUT_JSON" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('parse-error'); raise SystemExit
print('yes' if any(c.get('check')=='frontmatter_present' and c.get('status')=='FAIL' for c in d.get('checks',[])) else 'no')
" 2>/dev/null)
    if [ "$ORC" -ne 0 ] || [ "$MRC" -ne 0 ]; then
      FAILED=$((FAILED + 1))
      printf -- '- %s: kb-output rc=%s, kb-markers rc=%s\n' "$(basename "$kf")" "$ORC" "$MRC" >> "$DETAILS"
    fi
    [ "$FM_FAIL" = "yes" ] && NOFM=$((NOFM + 1))
  done < "$KB_FILES"

  if [ "$NOFM" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    emit "DEMOTE" 3 <<EOF
Struktur folder mirip KB, tapi SEMUA domain file ($TOTAL file) tanpa frontmatter
KB mega-sdd — grammar-nya asing (KB ini ditulis tool lain).
Tawaran DEMOTE (butuh konfirmasi lo — decision 7):
  (a) RE-INGEST — dokumen-dokumen ini masuk sebagai rung PRD via \`generate-intent\`.
  (b) RE-EXTRACT — \`extract-intelligence <legacy>\` untuk KB ber-grammar
      mega-sdd (dengan marker [VERIFIED]/[INFERRED]/[OPEN]).
EOF
  elif [ "$FAILED" -eq 0 ]; then
    emit "CERTIFIED" 0 <<EOF
Knowledge base lolos validator KB ($TOTAL domain file: validate-kb.sh
surface output + markers untuk 10-domains) — marker grounding + struktur 11-section OK.
Siap dikonsumsi \`generate-intent --kb=$APATH\` dan \`bind-codebase\` (ground truth
sekunder). Catatan: cek citation-ke-legacy (surface citations) butuh
--legacy-root dan jalan di lane extract/bind, bukan di certify.
EOF
  else
    emit "CERTIFIED_DEGRADED" 0 <<EOF
KB dikenali (grammar mega-sdd) tapi $FAILED dari $TOTAL domain file gagal
validator (marker tanpa citation / count mismatch / section kurang):
$(cat "$DETAILS")
Konsekuensi: klaim yang gagal grounding diperlakukan maksimal [INFERRED] oleh
konsumen — bind-codebase tidak akan menaikkan claim tak-bercitation jadi fakta.
Selanjutnya: perbaiki file yang gagal (atau re-extract domain terkait), lalu
jalankan ulang certify.
EOF
  fi
fi

# ── units — validate-unit-spec.sh over a staged scratch layout ───────────────
if [ "$RUNG" = "units" ]; then
  [ -f "$APATH" ] || { echo "certify-artifact: --rung=units needs a unit FILE, got a directory: $APATH" >&2; exit 2; }
  STAGE_DIR="$SCRATCH/.mega-sdd/vaults/adopt/units"
  mkdir -p "$STAGE_DIR"
  BASE="$(basename "$APATH")"
  case "$BASE" in
    U-*.md) STAGED="$STAGE_DIR/$BASE" ;;
    *)      STAGED="$STAGE_DIR/U-adopt.md" ;;
  esac
  cp "$APATH" "$STAGED"
  UNIT_JSON="$(bash "${SCRIPT_DIR}/validate-unit-spec.sh" --cwd="$SCRATCH" --file-path="$STAGED" </dev/null 2>/dev/null)"
  RC=$?
  UNIT_JSON="$UNIT_JSON" APATH="$APATH" URC="$RC" python3 <<'PYEOF'
import json, os, sys

path = os.environ["APATH"]
rc = os.environ.get("URC")
try:
    d = json.loads(os.environ.get("UNIT_JSON") or "{}")
except Exception:
    d = {}
if not d:
    print("certify-artifact: validate-unit-spec.sh produced no verdict (rc=%s)" % rc, file=sys.stderr)
    sys.exit(2)

# The validator merges project-wide + focal state; dedupe identical findings
# for display (verdict logic is set-based anyway).
issues, seen = [], set()
for i in d.get("issues", []):
    key = (i.get("halt_type"), i.get("detail"))
    if key not in seen:
        seen.add(key)
        issues.append(i)
advisory = [i for i in issues if i.get("severity") == "advisory"]
blocking = [i for i in issues if i.get("severity") != "advisory"]
no_frontmatter = any("entire_frontmatter" in (i.get("missing_fields") or []) for i in issues)

if no_frontmatter:
    verdict, rc_out = "REJECTED", 4
    lines = [
        "File ini bukan unit spec mega-sdd — tidak ada blok frontmatter YAML",
        "(--- ... ---) sama sekali, jadi tidak ada id/task_type/target_files yang",
        "bisa dibaca dispatcher bolt.",
        "Selanjutnya: generate unit yang benar via `generate-units`",
        "(dari vault ter-bind), atau kalau ini dokumen kebutuhan, masuk lewat",
        "rung PRD (`certify-artifact --rung=prd`).",
    ]
elif not blocking:
    verdict, rc_out = "CERTIFIED", 0
    lines = ["Unit spec lolos validate-unit-spec.sh — field wajib lengkap, siap dieksekusi execute-bolts."]
    if advisory:
        lines.append("Catatan advisory (tidak menahan):")
        for i in advisory:
            lines.append("- %s: %s" % (i.get("halt_type"), i.get("detail")))
else:
    verdict, rc_out = "CERTIFIED_DEGRADED", 0
    lines = [
        "Unit dikenali (frontmatter ada) tapi speknya kurang — temuan blocking:",
    ]
    for i in blocking:
        lines.append("- %s: %s" % (i.get("halt_type"), i.get("detail")))
    lines += [
        "Konsekuensi: execute-bolts akan halt di pre-flight untuk field yang hilang.",
        "Selanjutnya: lengkapi field wajib (unit_id/title/task_type/target_files/",
        "vault_source + acceptance_test) atau re-generate via `generate-units`.",
    ]

print("VERDICT: %s units %s" % (verdict, path))
print("KETERANGAN:")
for ln in lines:
    print("  " + ln)
sys.exit(rc_out)
PYEOF
  exit $?
fi

echo "certify-artifact: unreachable rung dispatch" >&2
exit 2

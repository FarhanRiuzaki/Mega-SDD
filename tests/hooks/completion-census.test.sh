#!/usr/bin/env bash
# v7.5.0 №G — auto-aware tier S: completion census + LOCKED-edit notice.
#
# Three surfaces, all 0-fork by contract:
#  A. UserPromptSubmit completion census: a "selesai"-class sentence + a dirty
#     journal → ONE offer line after the verbatim gateway tag; no signal or no
#     keyword → tag only. Census verified against 10 real office-style
#     sentences (BI/finance, ID-mix) — 5 must fire, 5 must NOT (incl. the
#     'mudah'≠'udah' word-boundary trap).
#  B. PostToolUse LOCKED-edit notice: editing a locked-index file emits one
#     additionalContext line (0 python); a free file stays silent.
#  C. auto_verify_on_edit: default false = no offer; true + target_files match
#     with acceptance_test = one offer line.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$REPO/plugins/mega-sdd/hooks"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

FIX="$WORK/proj"; mkdir -p "$FIX/.mega-sdd/codebase" "$FIX/src"
echo x > "$FIX/src/app.js"
printf '{"ts":"t","path":"src/app.js","tool":"Edit","session":"s"}\n' > "$FIX/.mega-sdd/codebase/.dirty-paths.jsonl"

ups() { printf '{"session_id":"s","cwd":"%s","prompt":"%s"}' "$FIX" "$1" | bash "$HOOKS/user-prompt-submit" 2>/dev/null; }

# ── A. census — 5 kalimat kantor yang HARUS memicu tawaran ──────────────────
FIRE=(
  "oke fitur limit kredit udah gue commit, lanjut apa?"
  "sudah selesai integrasi BI-Checking nya, tolong review"
  "report rekonsiliasi beres, gue push ke branch develop ya"
  "udh kelar semua perbaikan bug transfer antar bank"
  "PR untuk modul kolektibilitas sudah dibuat, done dari sisi gue"
)
for msg in "${FIRE[@]}"; do
  OUT=$(ups "$msg")
  if printf '%s\n' "$OUT" | head -1 | grep -qx "mega-sdd-trace:turn" \
     && printf '%s' "$OUT" | grep -q "TAWARKAN /mega-sdd:sync"; then
    ok "A-fire: offer emitted for: ${msg:0:44}…"
  else
    bad "A-fire: NO offer for: $msg"
  fi
done

# ── A2. census — 5 kalimat yang TIDAK boleh memicu ──────────────────────────
QUIET=(
  "cara setting limit approval itu mudah ga sih?"
  "tolong jelaskan flow pencairan kredit modal kerja"
  "kenapa validasi NIK di form pembukaan rekening gagal terus?"
  "buatkan unit test untuk perhitungan bunga deposito"
  "prosedur eskalasi fraud gimana urutannya?"
)
for msg in "${QUIET[@]}"; do
  OUT=$(ups "$msg")
  if printf '%s' "$OUT" | grep -q "TAWARKAN /mega-sdd:sync"; then
    bad "A2-quiet: false-positive offer for: $msg"
  else
    ok "A2-quiet: silent for: ${msg:0:44}…"
  fi
done

# ── A3. no change signal → keyword alone must NOT fire ──────────────────────
rm "$FIX/.mega-sdd/codebase/.dirty-paths.jsonl"
OUT=$(ups "udah selesai, commit dan push semua")
printf '%s' "$OUT" | grep -q "TAWARKAN" \
  && bad "A3: offer fired with NO change signal" \
  || ok "A3: no journal rows → tag only (change_signal gate holds)"
printf '{"ts":"t","path":"src/app.js","tool":"Edit","session":"s"}\n' > "$FIX/.mega-sdd/codebase/.dirty-paths.jsonl"

# ── B. LOCKED-edit notice (PostToolUse, 0 python) ───────────────────────────
printf '{"generated_at":"t","sources_scanned":1,"files":{"src/app.js":[".mega-sdd/vaults/v1/binding.md:2"]}}' \
  > "$FIX/.mega-sdd/.locked-files-index.json"
post() { printf '{"session_id":"s","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$FIX" "$1" | bash "$HOOKS/post-tool-use" 2>/dev/null; }
SHIM="$WORK/shim"; CNT="$WORK/cnt"; mkdir -p "$SHIM" "$CNT"
REALPY="$(command -v python3)"
printf '#!/bin/bash\necho 1 >> "%s/py"\nexec "%s" "$@"\n' "$CNT" "$REALPY" > "$SHIM/python3"; chmod +x "$SHIM/python3"
: > "$CNT/py"
OUT=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$FIX" "$FIX/src/app.js" | PATH="$SHIM:$PATH" bash "$HOOKS/post-tool-use" 2>/dev/null)
NPY=$(wc -l < "$CNT/py" | tr -d ' ')
if printf '%s' "$OUT" | grep -q '"additionalContext"' \
   && printf '%s' "$OUT" | grep -q "terikat ke claim \[LOCKED\]" \
   && printf '%s' "$OUT" | grep -q "src/app.js" \
   && [ "$NPY" -eq 0 ]; then
  ok "B: LOCKED edit → one additionalContext notice, ZERO python (tier-S pin)"
else
  bad "B: notice wrong (py=$NPY out=[${OUT:0:100}])"
fi
python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d['hookSpecificOutput']['additionalContext']" <<<"$OUT" 2>/dev/null \
  && ok "B2: notice payload is valid hookSpecificOutput JSON" \
  || bad "B2: notice JSON invalid: $OUT"
echo y > "$FIX/src/free.js"
OUT=$(post "$FIX/src/free.js")
[ -z "$OUT" ] && ok "B3: non-LOCKED edit stays silent" || bad "B3: unexpected output [$OUT]"

# ── C. auto_verify_on_edit ──────────────────────────────────────────────────
mkdir -p "$FIX/.mega-sdd/vaults/v1/units"
printf '%s\n' '# U-001' 'target_files:' '  - src/app.js' 'acceptance_test:' '  - run: npm test' \
  > "$FIX/.mega-sdd/vaults/v1/units/U-001.md"
OUT=$(post "$FIX/src/app.js")
printf '%s' "$OUT" | grep -q "auto_verify_on_edit" \
  && bad "C1: offer fired with the DEFAULT (false) config" \
  || ok "C1: default off → no acceptance offer"
printf 'auto_verify_on_edit: true\n' > "$FIX/.mega-sdd/config.yaml"
OUT=$(post "$FIX/src/app.js")
if printf '%s' "$OUT" | grep -q "auto_verify_on_edit" \
   && printf '%s' "$OUT" | grep -q "U-001" \
   && printf '%s' "$OUT" | grep -q "tawaran satu baris"; then
  ok "C2: opt-in true + target_files+acceptance match → one offer line (U-001)"
else
  bad "C2: opt-in offer missing (out=[${OUT:0:120}])"
fi

echo
if [ "$fail" -eq 0 ]; then echo "PASS completion census + auto-aware notices"; exit 0
else echo "completion census FAILED"; exit 1; fi

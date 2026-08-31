#!/usr/bin/env bash
# test-render-html.sh — 7.16.0 (research + spec 2026-08-31 render-html standard).
#
# The renderer is DETERMINISTIC md→HTML wrapping: md stays the only ground
# truth, the HTML re-renders it client-side (vendored marked+mermaid). Pins:
#   A  file mode renders a self-contained page: raw md embedded (escaped so
#      </script> can't break out), BOTH vendored libs inline, ZERO external
#      resource references (offline mandate), frontmatter stripped from display
#   B  lens detection: *.prd.md → kb-module (badge + audience + tier tiles),
#      binding.md → binding (CONFIRMED/CONFLICT tiles), unknown → generic
#   C  provenance: sha256 of the SOURCE md + plugin_version in the page (F-26)
#   D  diagram budget is ADVISORY: >20 edges → warning in JSON + warnbar in
#      page; under budget → no warnbar; never a non-zero exit
#   E  dir mode + --index: every md rendered, index.html links them all
#   F  --assets-dir: shared assets/ folder, page references them relatively
#      (still zero http(s) references)
#   G  natural-language template strings present (mandate §6) + usage errors exit 2
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
R="$ROOT/plugins/mega-sdd/scripts/render-html.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

mkdir -p "$WORK/kb/modules"
cat > "$WORK/kb/modules/acquisition.prd.md" <<'MD'
---
module: acquisition
---
# Module: Acquisition

## Flow utama

```mermaid
flowchart LR
  A --> B
  B --> C
```

## Aturan

- `[LOCKED]` R-07 aturan pembulatan
- `[INTENT]` R-14 notifikasi
- OQ-A03 pertanyaan terbuka
- penutup </script> nakal di teks
MD

echo "── A: self-contained + offline + frontmatter stripped ──"
OUT_JSON=$(bash "$R" "$WORK/kb/modules/acquisition.prd.md" --cwd="$WORK" 2>&1); rc=$?
H="$WORK/kb/modules/html/acquisition.prd.html"
[ $rc -eq 0 ] && [ -f "$H" ] && ok "A1 rendered to <parent>/html/ (rc 0)" || { bad "A1 rc=$rc json=$OUT_JSON"; }
grep -q "marked v15" "$H" && grep -q "__esbuild_esm_mermaid_nm" "$H" && ok "A2 both vendored libs inline" || bad "A2 libs not inlined"
grep -qE 'src="http|href="http|url\(http' "$H" && bad "A3 external resource reference found — offline broken" || ok "A3 zero external resources"
grep -qF 'penutup <\/script> nakal' "$H" && ok "A4 </script> in md is escaped in the embed" || bad "A4 script-breakout escape missing"
grep -q "module: acquisition" "$H" && bad "A5 frontmatter leaked into the page" || ok "A5 frontmatter stripped from display"

echo "── B: lens detection ──"
echo "$OUT_JSON" | grep -q '"lens": "kb-module"' && ok "B1 *.prd.md → kb-module" || bad "B1 lens: $OUT_JSON"
grep -q "PRD-KONTRAK · MODULE" "$H" && grep -q "tanpa baca source legacy" "$H" && ok "B2 badge + audience follow the lens" || bad "B2 lens strings missing"
grep -qi ">locked<" "$H" && ok "B3 tier tiles in the summary strip" || bad "B3 tier tiles missing"
printf '# Binding\n\n- klaim 1: CONFIRMED\n- klaim 2: CONFLICT\n' > "$WORK/binding.md"
J=$(bash "$R" "$WORK/binding.md" --cwd="$WORK" 2>&1)
echo "$J" | grep -q '"lens": "binding"' && ok "B4 binding.md → binding lens" || bad "B4 $J"
grep -qi ">confirmed<" "$WORK/html/binding.html" && ok "B5 verdict tiles on the binding page" || bad "B5 verdict tiles missing"
printf '# Catatan biasa\n\nteks.\n' > "$WORK/notes.md"
bash "$R" "$WORK/notes.md" --cwd="$WORK" 2>&1 | grep -q '"lens": "generic"' && ok "B6 unknown file → generic" || bad "B6 generic fallback broken"

echo "── C: provenance ──"
SHA=$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest()[:12])" "$WORK/kb/modules/acquisition.prd.md")
grep -q "$SHA" "$H" && ok "C1 sha256 of the source md is in the page" || bad "C1 sha missing"
grep -q "mega-sdd render-html · plugin" "$H" && ok "C2 plugin_version + written_at footer (F-26 pattern)" || bad "C2 provenance footer missing"

echo "── D: diagram budget is advisory ──"
{ printf '# Gede\n\n```mermaid\nflowchart LR\n'; for i in $(seq 1 25); do printf '  N%d --> N%d\n' "$i" $((i+1)); done; printf '```\n'; } > "$WORK/big.md"
J=$(bash "$R" "$WORK/big.md" --cwd="$WORK" 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$J" | grep -q "kegedean" && ok "D1 over-budget → warning, exit stays 0 (advisory)" || bad "D1 rc=$rc $J"
grep -q "warnbar" "$WORK/html/big.html" && grep -q "Budget diagram" "$WORK/html/big.html" && ok "D2 warnbar on the page" || bad "D2 warnbar missing"
grep -q '<div class="warnbar">' "$H" && bad "D3 under-budget page has a warnbar" || ok "D3 under-budget page stays clean"

echo "── E: dir mode + --index ──"
J=$(bash "$R" "$WORK/kb" --index --cwd="$WORK" 2>&1); rc=$?
[ $rc -eq 0 ] && [ -f "$WORK/kb/html/index.html" ] && [ -f "$WORK/kb/html/modules/acquisition.prd.html" ] \
  && ok "E1 bundle rendered + index.html" || bad "E1 rc=$rc $J"
grep -q "modules/acquisition.prd.html" "$WORK/kb/html/index.html" && ok "E2 index links the rendered pages" || bad "E2 index missing links"

echo "── F: --assets-dir ──"
J=$(bash "$R" "$WORK/kb" --index --assets-dir --out="$WORK/kb/html2" --cwd="$WORK" 2>&1)
[ -f "$WORK/kb/html2/assets/mermaid.min.js" ] && ok "F1 shared assets folder written once" || bad "F1 assets dir missing"
grep -q 'src="assets/marked.min.js"' "$WORK/kb/html2/index.html" && ok "F2 pages reference shared assets relatively" || bad "F2 relative asset refs missing"
grep -qE 'src="http|href="http' "$WORK/kb/html2/index.html" && bad "F3 external refs in assets-dir mode" || ok "F3 still zero external resources"

echo "── G: language + usage ──"
grep -q "Untuk siapa" "$H" && grep -q "md = ground truth" "$H" && ok "G1 natural mixed-language template strings" || bad "G1 template strings missing"
bash "$R" "$WORK/does-not-exist.md" >/dev/null 2>&1; [ $? -eq 2 ] && ok "G2 missing input → exit 2" || bad "G2 usage exit wrong"

echo; [ $err -eq 0 ] && { echo "test-render-html: ALL PASS"; exit 0; } || { echo "test-render-html: FAILED"; exit 1; }

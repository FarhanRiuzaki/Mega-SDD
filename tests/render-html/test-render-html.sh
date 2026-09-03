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

## 6. Open Questions

- [ ] OQ-A04 [P1] pertanyaan blocking terbuka
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

echo "── H: reachability — the emit html lane (7.18.0, field-test miss on day 1) ──"
EMIT="$ROOT/plugins/mega-sdd/commands/emit.md"
grep -q "render html" "$EMIT" && grep -q "html-kan" "$EMIT" && ok "H1 trigger phrases live in the always-loaded description" || bad "H1 trigger phrases missing from emit description"
grep -q "render-html.sh" "$EMIT" && ok "H2 emit html dispatches the script" || bad "H2 script dispatch missing"
grep -q "jangan menebak" "$EMIT" && ok "H3 ambiguous target → ask, never guess" || bad "H3 no-guess rail missing"
grep -q "emit html" "$ROOT/plugins/mega-sdd/skills/using-mega-sdd/SKILL.md" && ok "H4 router side-lane names the html lane" || bad "H4 router pointer missing"

echo "── I: auto-render at every pipeline hand-off (7.18.0) ──"
for s in extract-intelligence generate-intent generate-units execute-bolts; do
  SK="$ROOT/plugins/mega-sdd/skills/$s/SKILL.md"
  if grep -q "render-html.sh" "$SK" && grep -q "Fail-open" "$SK" && grep -q "render_html: off" "$SK"; then
    ok "I1 $s hand-off auto-renders (fail-open + config opt-out)"
  else
    bad "I1 $s missing the auto-render hand-off line"
  fi
done

echo "── J: back ke index (7.19.0) ──"
mkdir -p "$WORK/kb3/modules"
printf '# Roll-up KB\n\nRingkasan grounded emitter.\n' > "$WORK/kb3/README.md"
printf '# Mod A\n\n## Aturan denda\n\nDenda harian.\n' > "$WORK/kb3/modules/a.prd.md"
bash "$R" "$WORK/kb3" --index --cwd="$WORK" >/dev/null 2>&1
grep -q 'class="idx-link" href="../index.html"' "$WORK/kb3/html/modules/a.prd.html" \
  && ok "J1 nested page links back to index (relative)" || bad "J1 index link missing/wrong"
grep -q 'class="idx-link" href' "$H" && bad "J2 single-file page has an index link (there is no index)" || ok "J2 single-file mode stays linkless"

echo "── K: cross-bundle search ──"
[ -f "$WORK/kb3/html/search-index.js" ] && ok "K1 search-index.js written" || bad "K1 search index missing"
python3 - "$WORK/kb3/html/search-index.js" <<'EOF' && ok "K2 entries carry headings with nav-matching slugs + plain text" || bad "K2 search index shape wrong"
import json, re, sys
t = open(sys.argv[1]).read()
d = json.loads(re.sub(r"^window.MEGA_SEARCH=|;\s*$", "", t.strip()).replace("<\\/", "</"))
a = [e for e in d if "modules/a.prd.html" == e["h"]][0]
assert ["aturan-denda", "Aturan denda"] in a["hd"], a["hd"]   # slug == template nav slug
assert "Denda harian" in a["x"], a["x"]
EOF
grep -q 'id="q"' "$WORK/kb3/html/index.html" && grep -q "search-index.js" "$WORK/kb3/html/index.html" \
  && ok "K3 index page carries the search box + include" || bad "K3 search UI missing on index"
# K4 REPINNED at 7.23.0 (spec 2026-09-03 template v2): the box-on-index-only design is
# superseded by the global ⌘K modal — content pages now carry the search UI + data include.
grep -q 'id="q"' "$WORK/kb3/html/modules/a.prd.html" && grep -q 'search-index.js"' "$WORK/kb3/html/modules/a.prd.html" \
  && ok "K4 content pages carry the global ⌘K search (repinned 7.23.0)" || bad "K4 global search missing on content page"

echo "── L: README as the index face ──"
grep -q "Ringkasan grounded emitter" "$WORK/kb3/html/index.html" && grep -q "Semua dokumen" "$WORK/kb3/html/index.html" \
  && ok "L1 index face = README roll-up + the full listing" || bad "L1 README face missing"

echo "── M: the emit summary lane ──"
EMIT="$ROOT/plugins/mega-sdd/commands/emit.md"
grep -q "emit summary" "$EMIT" && grep -q "rangkuman eksekutif" "$EMIT" && ok "M1 trigger phrases in the always-loaded description" || bad "M1 summary triggers missing"
grep -q "angka TIDAK PERNAH dikarang" "$EMIT" && grep -q "belum ada datanya" "$EMIT" \
  && ok "M2 anti-fabrication rail (cite every number; honest gaps)" || bad "M2 citation rail missing"
grep -q "takeaway tebal" "$EMIT" && grep -q "status JUJUR" "$EMIT" && ok "M3 DD9000 pattern pinned (takeaway + honest status)" || bad "M3 pattern points missing"
grep -q 'render-html.sh" <target>/summary/SUMMARY.md' "$EMIT" && ok "M4 summary auto-renders after authoring" || bad "M4 auto-render step missing"

echo "── N: template v2 'developer platform' (7.23.0, spec 2026-09-03) ──"
T="$ROOT/plugins/mega-sdd/assets/render-html/template.html"
grep -q "data:font/woff2;base64," "$H" && ok "N1 vendored fonts inline as data URIs (offline intact)" || bad "N1 inline fonts missing"
grep -q 'data-theme="dark"' "$T" && grep -q "prefers-color-scheme" "$T" && grep -qF ':root:not([data-theme="light"])' "$T" \
  && ok "N2 3-state theme tokens (system default + toggle override)" || bad "N2 theme token pattern missing"
grep -qF 'theme: "base"' "$T" && grep -q "themeVariables" "$T" && grep -q "document.fonts.ready" "$T" \
  && ok "N3 mermaid base+tokens, rendered after fonts.ready" || bad "N3 mermaid theming missing"
grep -q "colorizeDiagrams" "$T" && grep -q "urutan render DOM mermaid" "$T" && grep -q "setLegend" "$T" \
  && ok "N4 role colors (label-matched actors) + legend" || bad "N4 colorize/legend missing"
grep -q 'window.MEGA_SELF="' "$WORK/kb3/html/modules/a.prd.html" && grep -qE "Berikutnya|Sebelumnya" "$WORK/kb3/html/modules/a.prd.html" \
  && ok "N5 bundle pages carry nav data + prev/next" || bad "N5 nav data/prev-next missing"
grep -q 'window.MEGA_SELF="' "$H" && bad "N6 single-file page carries bundle nav data" || ok "N6 single-file mode stays bundle-less"
grep -q 'src="../assets/marked.min.js"' "$WORK/kb/html2/modules/acquisition.prd.html" 2>/dev/null \
  && ok "N7 nested assets-dir page uses the CORRECT relative prefix (v1 bug fixed)" || bad "N7 nested rel-prefix wrong/missing"
grep -q 'class="st warn"' "$H" && ok "N8 strip warns on open-questions count" || bad "N8 strip warn class missing"
grep -q "function highlight" "$T" && grep -q "hl-k" "$T" && ok "N9 tokenizer-mini highlighter (zero dependency)" || bad "N9 highlighter missing"
grep -qE 'src="http|href="http|url\(http' "$T" && bad "N10 template references an external resource" || ok "N10 template itself stays offline"

echo; [ $err -eq 0 ] && { echo "test-render-html: ALL PASS"; exit 0; } || { echo "test-render-html: FAILED"; exit 1; }

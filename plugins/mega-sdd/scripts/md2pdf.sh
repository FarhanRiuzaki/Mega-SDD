#!/usr/bin/env bash
# md2pdf.sh — render a Markdown doc to PDF in the GitHub / VS Code style.
#
# The mega-sdd emit lanes (emit-fsd / emit-prd / emit-sit) render human-facing
# PDFs through THIS pipeline, NOT pandoc+LaTeX. LaTeX output is academic-paper
# style (borderless tables, float "Figure N" diagrams, page-break-cut tall
# diagrams) — banned by the PDF export standard
# (docs/superpowers/specs/2026-07-20-md2pdf-render-engine.md).
#
# Pipeline (all on a THROWAWAY copy — the source .md is NEVER modified, so a
# citation-stamped FSD.md keeps its sha256 and the --check-drift reader stays clean):
#   1. YAML frontmatter -> a visible ```yaml block (renders, not swallowed).
#   2. ```mermaid blocks -> SVG via mmdc (only if present + mmdc on PATH).
#   3. pandoc -f markdown-implicit_figures -> HTML (implicit_figures OFF so
#      images stay inline in place, not floated) with github.css embedded.
#   4. Chrome/Chromium headless --print-to-pdf.
#
# Fallback ladder (NO LaTeX anywhere): Chrome -> PDF ; no Chrome -> GitHub-styled
# HTML (same css; print from a browser) ; no pandoc -> nothing (caller keeps md).
#
# Styling: <out-dir>/github.css if present (per-vault override), else the shipped
# plugin default references/github.css.
#
# Usage: md2pdf.sh <input.md> [output.pdf] [--toc]
# Exit: 0 = PDF written · 3 = Chrome absent, HTML fallback written · 2 = pandoc
#       absent (nothing written) / usage · 1 = render error.
set -uo pipefail

IN="${1:-}"
[ -n "$IN" ] || { echo "usage: md2pdf.sh <input.md> [output.pdf] [--toc]" >&2; exit 2; }
[ -f "$IN" ] || { echo "md2pdf: input not found: $IN" >&2; exit 2; }
shift
OUT="" ; TOC="" ; FORCE_HTML=0
for a in "$@"; do
  case "$a" in
    --toc)  TOC="--toc --toc-depth=2" ;;
    --html) FORCE_HTML=1 ;;   # skip Chrome, emit GitHub-styled HTML (CI/testing/print-from-browser)
    --*)    ;;  # ignore unknown flags (forward-compat)
    *)      OUT="$a" ;;
  esac
done
[ -n "$OUT" ] || OUT="${IN%.md}.pdf"

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
IN="$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"
OUT_DIR="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd || pwd)"
OUT_ABS="$OUT_DIR/$(basename "$OUT")"
HTML_ABS="${OUT_ABS%.pdf}.html"
TITLE="$(basename "${IN%.md}")"

# Styling: per-output-dir override wins, else the shipped default.
CSS="$SCRIPT_DIR/../references/github.css"
[ -f "$OUT_DIR/github.css" ] && CSS="$OUT_DIR/github.css"
[ -f "$CSS" ] || { echo "md2pdf: github.css not found ($CSS)" >&2; exit 1; }

command -v pandoc >/dev/null 2>&1 || {
  echo "md2pdf: pandoc absent — cannot render; leaving markdown as-is. Install: brew install pandoc" >&2
  exit 2; }

CHROME=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
         "/Applications/Chromium.app/Contents/MacOS/Chromium" \
         "$(command -v google-chrome 2>/dev/null || true)" \
         "$(command -v google-chrome-stable 2>/dev/null || true)" \
         "$(command -v chromium 2>/dev/null || true)" \
         "$(command -v chromium-browser 2>/dev/null || true)" \
         "/c/Program Files/Google/Chrome/Application/chrome.exe" \
         "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
         "${LOCALAPPDATA:+${LOCALAPPDATA}/Google/Chrome/Application/chrome.exe}" \
         "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
  [ -n "$c" ] && [ -x "$c" ] && CHROME="$c" && break
done

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t md2pdf)"
trap 'rm -rf "$WORK"' EXIT

# (1) frontmatter YAML -> visible code block. READS $IN, writes a COPY -> WORK.
IN="$IN" python3 - "$WORK/doc.md" <<'PY'
import os, re, sys, pathlib
text = pathlib.Path(os.environ["IN"]).read_text(encoding="utf-8")
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if m:
    text = "## Frontmatter (metadata dokumen)\n\n```yaml\n" + m.group(1) + "\n```\n" + text[m.end():]
pathlib.Path(sys.argv[1]).write_text(text, encoding="utf-8")
PY

# (2) mermaid -> SVG (only when present + mmdc available; the source md untouched).
SRC="$WORK/doc.md"
if grep -q '^```mermaid' "$WORK/doc.md"; then
  if command -v mmdc >/dev/null 2>&1; then
    PUP="$WORK/puppeteer.json"
    printf '{ "args": ["--no-sandbox", "--headless=new"]%s }\n' \
      "$([ -n "$CHROME" ] && printf ', "executablePath": "%s"' "$CHROME")" > "$PUP"
    if mmdc -p "$PUP" -i "$WORK/doc.md" -o "$WORK/doc-svg.md" -e svg --backgroundColor white >/dev/null 2>&1; then
      SRC="$WORK/doc-svg.md"
    else
      echo "md2pdf: WARN mmdc failed — mermaid blocks stay as code (quality drop; mermaid-flows is a hard rule)" >&2
    fi
  else
    echo "md2pdf: WARN mmdc absent — mermaid blocks stay as code. Install: npm install -g @mermaid-js/mermaid-cli" >&2
  fi
fi

# (3) markdown -> GitHub-styled HTML (implicit_figures OFF = inline images).
# shellcheck disable=SC2086
# --resource-path=$WORK so mmdc's relative `./doc-svg-N.svg` refs embed (mermaid).
pandoc "$SRC" -f markdown-implicit_figures -o "$WORK/doc.html" --standalone --embed-resources \
  --resource-path="$WORK" --css="$CSS" $TOC --metadata title="$TITLE" \
  || { echo "md2pdf: pandoc HTML render failed" >&2; exit 1; }

# (4) HTML -> PDF via Chrome; absent or --html -> HTML output (same styling, no LaTeX).
if [ "$FORCE_HTML" = 1 ]; then
  cp "$WORK/doc.html" "$HTML_ABS"
  echo "HTML: $HTML_ABS"
  exit 3
fi
if [ -z "$CHROME" ]; then
  cp "$WORK/doc.html" "$HTML_ABS"
  echo "md2pdf: Chrome/Chromium absent — wrote GitHub-styled HTML instead of PDF: $HTML_ABS (print-to-PDF from a browser; install Chrome for direct PDF)" >&2
  echo "HTML: $HTML_ABS"
  exit 3
fi
if "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
     --print-to-pdf="$OUT_ABS" "file://$WORK/doc.html" >/dev/null 2>&1 && [ -s "$OUT_ABS" ]; then
  echo "PDF: $OUT_ABS"
  exit 0
fi
# Chrome present but print failed -> HTML fallback rather than a hard fail.
cp "$WORK/doc.html" "$HTML_ABS"
echo "md2pdf: Chrome print-to-pdf failed — wrote GitHub-styled HTML fallback: $HTML_ABS" >&2
echo "HTML: $HTML_ABS"
exit 3

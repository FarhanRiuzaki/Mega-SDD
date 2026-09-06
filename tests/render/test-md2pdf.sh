#!/usr/bin/env bash
# test-md2pdf.sh — the GitHub/VS Code PDF render pipeline (md2pdf.sh), the native
# emit-lane renderer (spec docs/superpowers/specs/2026-07-20-md2pdf-render-engine.md).
#
# CI-safe: exercises the transform stages + the HTML path via --html (CI runners
# have no Chrome), so it never depends on a browser. The load-bearing assertion is
# the MOAT one: a citation-stamped source .md must be BYTE-IDENTICAL after render
# (transforms run on a mktemp copy) — else the --check-drift reader sees false drift.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../plugins/mega-sdd"
SC="$PLUGIN/scripts/md2pdf.sh"
rc=0
ok()  { echo "PASS ($1)"; }
bad() { echo "FAIL ($1)"; rc=1; }

if ! command -v pandoc >/dev/null 2>&1; then
  # LOUD skip (7.29.1): without pandoc the render assertions — including the
  # BYTE-IDENTICAL moat check — do NOT run. CI installs pandoc so they do there.
  echo "SKIP: pandoc absent — render + BYTE-IDENTICAL (moat) assertions NOT run (brew install pandoc / apt-get install pandoc)"
  [ -f "$PLUGIN/references/github.css" ] && ok "github.css shipped in the plugin (not ~/.claude)" || bad "github.css missing from plugin"
  exit $rc
fi

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t md2pdf)"
trap 'rm -rf "$WORK"' EXIT

# ── the shipped stylesheet exists beside the script ──────────────────────────
[ -f "$PLUGIN/references/github.css" ] && ok "github.css shipped in the plugin (not ~/.claude)" || bad "github.css missing from plugin"
grep -q "border-collapse" "$PLUGIN/references/github.css" && ok "github.css is GitHub-style (bordered tables)" || bad "github.css not the expected stylesheet"

# ── a doc with frontmatter + a table + a mermaid block ───────────────────────
D="$WORK/v"; mkdir -p "$D"
cat > "$D/doc.md" <<'EOF'
---
title: Test Doc
version: 2.0
---
# Heading One

| col a | col b |
|-------|-------|
| 1     | 2     |

```mermaid
flowchart LR
  A --> B
```

Some body text.
EOF
SHA_BEFORE="$(shasum -a 256 "$D/doc.md" | cut -d' ' -f1)"

OUT="$(bash "$SC" "$D/doc.md" "$D/doc.pdf" --toc --html 2>&1)"; E=$?
[ "$E" -eq 3 ] && ok "--html forces the HTML path (exit 3)" || bad "--html exit=$E (want 3): $OUT"
[ -f "$D/doc.html" ] && ok "HTML written" || bad "no HTML output"

# ── MOAT: the source .md is byte-identical after render ──────────────────────
SHA_AFTER="$(shasum -a 256 "$D/doc.md" | cut -d' ' -f1)"
[ "$SHA_BEFORE" = "$SHA_AFTER" ] && ok "source .md BYTE-IDENTICAL after render (citation sha intact)" || bad "source .md MUTATED — moat break (invariant #3)"

# ── transform correctness ────────────────────────────────────────────────────
grep -q "border-collapse" "$D/doc.html" && ok "github.css embedded in output (bordered tables)" || bad "github.css not applied"
grep -qi "frontmatter-metadata-dokumen\|Frontmatter (metadata" "$D/doc.html" && ok "frontmatter rendered as a visible section (not swallowed)" || bad "frontmatter lost"
grep -q "col a" "$D/doc.html" && ok "table content present" || bad "table missing"
# implicit_figures OFF → pandoc must NOT wrap images in a <figure> float
grep -q "<figure" "$D/doc.html" && bad "implicit_figures ON — image floated as a figure (banned)" || ok "implicit_figures OFF — images inline, not floated"

# ── per-vault github.css override is honored (pandoc strips CSS comments when
#    embedding, so the sentinel must be a RULE VALUE, not a comment) ───────────
D2="$WORK/v2"; mkdir -p "$D2"
printf '%s\n' 'table{border:7px solid magenta}' > "$D2/github.css"
printf '%s\n' '# T' 'x' > "$D2/doc.md"
bash "$SC" "$D2/doc.md" "$D2/out.pdf" --html >/dev/null 2>&1
grep -q "magenta" "$D2/out.html" && ok "per-vault github.css override honored" || bad "override css ignored"

# ── usage guard ──────────────────────────────────────────────────────────────
bash "$SC" >/dev/null 2>&1; [ $? -eq 2 ] && ok "no input -> usage exit 2" || bad "usage exit contract"
bash "$SC" "$WORK/nonexistent.md" >/dev/null 2>&1; [ $? -eq 2 ] && ok "missing input -> exit 2" || bad "missing-input exit contract"

# ── if Chrome IS present (local dev), the real PDF path produces a PDF ────────
CHROME=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "$(command -v google-chrome 2>/dev/null||true)" "$(command -v chromium 2>/dev/null||true)"; do
  [ -n "$c" ] && [ -x "$c" ] && CHROME="$c" && break
done
if [ -n "$CHROME" ]; then
  bash "$SC" "$D/doc.md" "$D/real.pdf" --toc >/dev/null 2>&1
  if [ -s "$D/real.pdf" ] && head -c4 "$D/real.pdf" | grep -q "%PDF"; then ok "Chrome present -> real PDF produced (%PDF)"; else bad "Chrome present but no valid PDF"; fi
else
  echo "PASS (Chrome absent on this runner -> PDF path covered where Chrome exists; HTML fallback exercised above)"
fi

echo "== test-md2pdf: $([ $rc -eq 0 ] && echo ALL-PASS || echo HAS-FAIL) =="
exit $rc

# md2pdf render engine — the GitHub/VS Code PDF pipeline as the native emit renderer

**Date:** 2026-07-20 · **Trigger:** user-mandated PDF export standard ([[pdf-export-standard]] memory): markdown→PDF must NEVER use the pandoc+LaTeX default (academic look — borderless tables, float "Figure N" diagrams, page-break-cut tall diagrams). The three emit lanes (emit-fsd / emit-prd / emit-sit) must adopt the GitHub/VS Code-style Chrome-print pipeline natively. · **Advisor-reviewed.**

## Decisions (locked)

1. **Replace, not dual-engine.** The PDF render is exactly ONE styling system (`github.css`) and ONE fallback ladder: **Chrome → PDF** → (no Chrome) **GitHub-styled HTML** (same css; user prints from browser) → (no pandoc) **markdown only**. LaTeX / xelatex / tectonic appears NOWHERE — a LaTeX fallback would silently ship the exact academic look the user banned.
2. **Retire the LaTeX assets** — `emit-fsd/references/pandoc-template.tex` and the LaTeX variables in `styling-config.yaml`. **Migrate the override knob:** the old per-vault `FSD.styling.yaml` override becomes a per-vault **`<vault>/fsd/github.css`** override (if present, md2pdf uses it instead of the shipped default) so anyone who customized styling keeps a knob.
3. **Markdown is the moat-cited, CI artifact; the PDF is human-facing.** Headless / no-Chrome (CI, `claude -p`) emitting HTML instead of PDF is ACCEPTABLE BY DESIGN — the source of truth (`FSD.md` + `.citation-map.json`) is unchanged. CI is NOT gated on Chrome.
4. **MOAT × RENDER (correctness-critical).** md2pdf transforms the doc (frontmatter → ```yaml block, ```mermaid → SVG). These run on a **throwaway `mktemp` copy**; the citation-stamped source `.md` stays **BYTE-IDENTICAL**. Otherwise the next `check-citation-drift` sees a changed sha256 → false drift / `[Pending]` → invariant #3 broken by a "cosmetic" change. Pinned by a test asserting the source `.md` is unchanged after render.
5. **Dependency shift (consistent with 5.2.2 "install only what's used", NOT a flip-flop):** `pandoc` KEEPS (md→HTML). `tectonic`/`xelatex` become UNUSED → dropped. `mmdc` (`@mermaid-js/mermaid-cli`, npm) becomes USED → added to the install-deps matrix (`fsd_extension`). **Chrome is detect-only** — a GUI cask that does not fit install-deps' `command -v` + never-sudo model; the pipeline probes common paths, and absence → HTML fallback + a one-line "install Chrome for PDF" advisory. It is NOT a matrix entry install-deps tries to install.
6. **Known degradation (documented, not a bug):** mermaid-flows is a hard rule, so a PDF built without Chrome+mmdc shows mermaid blocks as code, not diagrams — a visible quality drop the fallback ladder accepts.

## What ships

- `plugins/mega-sdd/scripts/md2pdf.sh` — the pipeline, plugin-native: resolves `github.css` relative to itself (never `~/.claude/`), probes Chrome via the common-path list, transforms on a mktemp copy, `pandoc -f markdown-implicit_figures` → HTML → Chrome `--print-to-pdf`; Chrome-absent → leaves the HTML + exit-note; per-vault `<vault>/fsd|prd|sit>/github.css` override honored.
- `plugins/mega-sdd/references/github.css` — the GitHub-style stylesheet (shipped verbatim).
- `plugins/mega-sdd/tests/token-cost/` sibling or `tests/render/test-md2pdf.sh` — CI-safe: exercises the transform stages + the HTML-fallback path (no Chrome in CI), asserts github.css is embedded AND the source `.md` is byte-identical after render.

## What changes

- emit-fsd Step 5 (canonical; emit-prd/emit-sit "same lane" inherit) → `bash <plugin>/scripts/md2pdf.sh <doc>.md <doc>.pdf --toc`. The citation gate stays BEFORE render (moat untouched). Preflight `pandoc_latex_engine_present` → replaced by `chrome_present` (warn-only) + `mmdc_present` (warn-only, mermaid quality).
- `validate-pandoc-render.sh` remedy text: tectonic-install → Chrome/mmdc guidance + HTML-fallback note.
- install-deps `tool-matrix.yaml` + `tooling-install.md`: drop tectonic, add mmdc, document Chrome as detect-only. READMEs: "pandoc + tectonic" → "pandoc + Chrome (+ mmdc for mermaid)".

## Acceptance (the un-fakeable check, per [[pdf-export-standard]])

Generate a real PDF from an actual emit output and **Read 2-3 pages (including a mermaid page)** — diagrams whole (not split), tables bordered, no overflow — before declaring done. The automated test covers the CI-safe stages; the visual read covers what CI cannot.

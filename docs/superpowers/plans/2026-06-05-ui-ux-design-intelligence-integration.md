# UI/UX Design-Intelligence Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distill `ui-ux-pro-max`'s design knowledge into injected-context references inside mega-sdd, wired into intent-time (Design-Source OQ → `recommend`) and bolt-time (Step 4.5 enrichment), with a deterministic validator extension — so generated UIs are higher quality without adding a runtime dependency.

**Architecture:** Pattern = **distilasi → injected-context → validator**, reusing existing machinery (Design-Source OQ, `context-enrichment.md` Step 4.5 ui_ux slice, `validate-dispatch-prompt.sh`). A sync-time Python distiller (`distill-ui-ux.py`, invoked only by `sync-ui-ux.sh`) regenerates 5 curated reference files from the installed `ui-ux-pro-max` CSVs; mega-sdd runtime reads only the committed markdown/YAML — **never** Python.

**Tech Stack:** Bash + Python3 (sync-time only), Markdown/YAML reference files, mega-sdd skill-prose + JSON-schema docs, existing bash/python validators.

**Branch:** `feat/ui-ux-design-intelligence` (already created).

**Source of truth for distillation:** `~/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.5.0/src/ui-ux-pro-max/data/` — `products.csv`, `styles.csv`, `colors.csv`, `typography.csv`, `ux-guidelines.csv` (MIT, nextlevelbuilder).

---

## File Structure

**Create:**
- `plugins/mega-sdd/scripts/_lib/distill-ui-ux.py` — sync-time CSV → curated reference distiller.
- `plugins/mega-sdd/scripts/sync-ui-ux.sh` — mirror of `sync-superpowers.sh`; resolves installed plugin, runs the distiller, stamps ATTRIBUTION.
- `plugins/mega-sdd/references/design-intelligence/ATTRIBUTION.md` — MIT attribution + sync metadata.
- `plugins/mega-sdd/references/design-intelligence/product-style-map.yaml` — GENERATED: product-type → {style, palette, typography, a11y_baseline}.
- `plugins/mega-sdd/references/design-intelligence/style-principles.md` — GENERATED: per-style traits / CSS keywords / anti-patterns.
- `plugins/mega-sdd/references/design-intelligence/palette-principles.md` — GENERATED: per-product palette hexes + semantic roles.
- `plugins/mega-sdd/references/design-intelligence/typography-pairings.md` — GENERATED: font pairings + imports.
- `plugins/mega-sdd/references/design-intelligence/ux-rules.md` — GENERATED: UX guidelines + a11y priority table.
- `plugins/mega-sdd/tests/design-intelligence/test-distill.sh` — structural lint of distiller output.
- `plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh` — TDD harness for the validator extension.

**Modify:**
- `plugins/mega-sdd/scripts/validate-dispatch-prompt.sh` — add `design_system_not_injected` finding.
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — `vault_version` 1.0→1.1, new `design_system` block, OQ-DESIGN-SOURCE recommend schema.
- `plugins/mega-sdd/skills/generate-intent/references/generation-guide.md` — Design-Source OQ Rule 2 gains the `recommend` path.
- `plugins/mega-sdd/skills/generate-units/references/decomposition-rails.md` — `## UI contract` gains `design_system_ref`.
- `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md` — build + emit a `Design system:` line in the ui_ux slice.
- `plugins/mega-sdd/skills/generate-intent/SKILL.md`, `skills/execute-bolts/SKILL.md`, `skills/generate-units/SKILL.md` — `version:` bumps.
- `plugins/mega-sdd/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` (root) — 4.0.0 → 4.1.0.
- `CHANGELOG.md` (repo root) — new `[4.1.0]` entry.

---

## Task 1: Sync-time distiller (`distill-ui-ux.py`)

The distiller is the single source of truth for the reference file FORMAT. Build it first so later tasks consume real generated output, not hand-fabricated content.

**Files:**
- Create: `plugins/mega-sdd/scripts/_lib/distill-ui-ux.py`
- Test: `plugins/mega-sdd/tests/design-intelligence/test-distill.sh`

- [ ] **Step 1: Write the failing test**

```bash
# plugins/mega-sdd/tests/design-intelligence/test-distill.sh
#!/usr/bin/env bash
# Structural lint: run the distiller against the installed ui-ux-pro-max data and
# assert the 5 reference files are produced with the expected shape. Sync-time only.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC="${HOME}/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max"
SRC_VER="$(find "$SRC" -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | sort -V | tail -1)"
if [ -z "$SRC_VER" ]; then echo "SKIP: ui-ux-pro-max not installed"; exit 0; fi
DATA="${SRC_VER}/src/ui-ux-pro-max/data"
OUT="$(mktemp -d)"
python3 "${PLUGIN_ROOT}/scripts/_lib/distill-ui-ux.py" --data="$DATA" --out="$OUT" || { echo "FAIL: distiller errored"; exit 1; }
fail=0
for f in product-style-map.yaml style-principles.md palette-principles.md typography-pairings.md ux-rules.md; do
  [ -s "${OUT}/${f}" ] || { echo "FAIL: ${f} missing/empty"; fail=1; }
done
# product-style-map.yaml must parse as YAML and carry >=10 product entries each with the 4 required keys.
python3 - "$OUT/product-style-map.yaml" <<'PY' || fail=1
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
entries = d.get("products", {})
assert len(entries) >= 10, f"only {len(entries)} products"
for k, v in entries.items():
    for key in ("style", "palette", "typography", "a11y_baseline"):
        assert key in v, f"{k} missing {key}"
print(f"OK: {len(entries)} products")
PY
[ "$fail" = 0 ] && echo "PASS" || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/mega-sdd/tests/design-intelligence/test-distill.sh`
Expected: FAIL with "distiller errored" (script does not exist yet). If ui-ux-pro-max is not installed it prints `SKIP` and exits 0 — install it first (`/plugin`) before continuing.

- [ ] **Step 3: Write the distiller**

```python
# plugins/mega-sdd/scripts/_lib/distill-ui-ux.py
"""Sync-time distiller: ui-ux-pro-max CSVs -> mega-sdd design-intelligence references.

Runs ONLY at sync/release time (invoked by sync-ui-ux.sh). mega-sdd runtime never
calls this — it reads the committed markdown/YAML output instead. No third-party deps
beyond PyYAML (already used by other mega-sdd sync tooling); falls back to a minimal
hand-rolled YAML emitter so the distiller never hard-depends on PyYAML at sync time.
"""
import argparse, csv, os, sys, re

def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.strip().lower()).strip("-")

def read_csv(path):
    if not os.path.isfile(path):
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def emit_yaml_products(rows_products, rows_colors, out):
    # index colors.csv by Product Type for palette join
    color_by_pt = {r.get("Product Type", "").strip(): r for r in rows_colors}
    lines = ["# GENERATED by scripts/_lib/distill-ui-ux.py — do not hand-edit; re-run sync-ui-ux.sh.",
             "# Source: ui-ux-pro-max products.csv + colors.csv (MIT, nextlevelbuilder).",
             "products:"]
    count = 0
    for r in rows_products:
        pt = r.get("Product Type", "").strip()
        if not pt:
            continue
        c = color_by_pt.get(pt, {})
        palette = ", ".join(v for v in [
            f"primary {c.get('Primary (Hex)','').strip()}" if c.get("Primary (Hex)") else "",
            f"cta {c.get('CTA (Hex)','').strip()}" if c.get("CTA (Hex)") else "",
        ] if v) or (r.get("Color Palette Focus", "").strip())
        lines += [
            f"  {slug(pt)}:",
            f"    label: {yq(pt)}",
            f"    style: {yq(r.get('Primary Style Recommendation','').strip())}",
            f"    secondary_styles: {yq(r.get('Secondary Styles','').strip())}",
            f"    palette: {yq(palette)}",
            f"    typography: {yq(r.get('Color Palette Focus','').strip() or 'see typography-pairings.md by mood')}",
            f"    a11y_baseline: {yq('WCAG AA')}",
            f"    considerations: {yq(r.get('Key Considerations','').strip())}",
        ]
        count += 1
    open(os.path.join(out, "product-style-map.yaml"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return count

def yq(s):
    s = (s or "").replace('"', "'")
    return f'"{s}"'

def emit_md_table(out, fname, title, source, header, rows, cols):
    lines = [f"# {title}", "", f"> GENERATED by distill-ui-ux.py from {source} (MIT, nextlevelbuilder). Do not hand-edit.", "",
             "| " + " | ".join(header) + " |", "|" + "|".join(["---"] * len(header)) + "|"]
    for r in rows:
        cells = [(r.get(c, "") or "").replace("\n", " ").replace("|", "/").strip() for c in cols]
        if not cells[0]:
            continue
        lines.append("| " + " | ".join(cells) + " |")
    open(os.path.join(out, fname), "w", encoding="utf-8").write("\n".join(lines) + "\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="ui-ux-pro-max src/.../data dir")
    ap.add_argument("--out", required=True, help="output references/design-intelligence dir")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    products = read_csv(os.path.join(a.data, "products.csv"))
    colors = read_csv(os.path.join(a.data, "colors.csv"))
    styles = read_csv(os.path.join(a.data, "styles.csv"))
    typo = read_csv(os.path.join(a.data, "typography.csv"))
    ux = read_csv(os.path.join(a.data, "ux-guidelines.csv"))
    n = emit_yaml_products(products, colors, a.out)
    emit_md_table(a.out, "style-principles.md", "Style Principles", "styles.csv",
                  ["Style", "Best For", "Avoid For", "CSS Keywords"], styles,
                  ["Style Category", "Best For", "Do Not Use For", "CSS/Technical Keywords"])
    emit_md_table(a.out, "palette-principles.md", "Palette Principles", "colors.csv",
                  ["Product", "Primary", "CTA", "Background", "Text", "Notes"], colors,
                  ["Product Type", "Primary (Hex)", "CTA (Hex)", "Background (Hex)", "Text (Hex)", "Notes"])
    emit_md_table(a.out, "typography-pairings.md", "Typography Pairings", "typography.csv",
                  ["Pairing", "Heading", "Body", "Mood", "Best For", "CSS Import"], typo,
                  ["Font Pairing Name", "Heading Font", "Body Font", "Mood/Style Keywords", "Best For", "CSS Import"])
    # ux-guidelines.csv header varies; emit the first 4 columns generically.
    ux_cols = list(ux[0].keys())[:4] if ux else []
    emit_md_table(a.out, "ux-rules.md", "UX Rules & Accessibility", "ux-guidelines.csv",
                  ux_cols, ux, ux_cols)
    print(f"distilled: {n} products + styles/palette/typography/ux into {a.out}", file=sys.stderr)

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash plugins/mega-sdd/tests/design-intelligence/test-distill.sh`
Expected: `OK: <N> products` then `PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/_lib/distill-ui-ux.py plugins/mega-sdd/tests/design-intelligence/test-distill.sh
git commit -m "feat(design-intelligence): sync-time CSV distiller + structural lint"
```

---

## Task 2: Sync script + generated references + ATTRIBUTION

**Files:**
- Create: `plugins/mega-sdd/scripts/sync-ui-ux.sh`
- Create: `plugins/mega-sdd/references/design-intelligence/ATTRIBUTION.md`
- Create (generated, committed): the 5 `references/design-intelligence/*` files.

- [ ] **Step 1: Write `sync-ui-ux.sh`** (mirror of `sync-superpowers.sh`)

```bash
#!/usr/bin/env bash
# Sync vendored (distilled) ui-ux-pro-max design intelligence into mega-sdd.
# Usage: bash scripts/sync-ui-ux.sh [UI_UX_DIR]
# Distillation runs at SYNC TIME ONLY; mega-sdd runtime reads the committed output.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${PLUGIN_ROOT}/references/design-intelligence"
DEFAULT_CACHE="${HOME}/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max"
UX_DIR="${1:-}"
if [ -z "$UX_DIR" ] && [ -d "$DEFAULT_CACHE" ]; then
  UX_DIR="$(find "$DEFAULT_CACHE" -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -1)"
fi
if [ -z "$UX_DIR" ] || [ ! -d "$UX_DIR" ]; then
  echo "ERROR: ui-ux-pro-max source not found. Pass path as arg or install the plugin." >&2
  exit 1
fi
DATA="${UX_DIR}/src/ui-ux-pro-max/data"
[ -d "$DATA" ] || { echo "ERROR: data dir missing: $DATA" >&2; exit 1; }
echo "Distilling from: $DATA"
mkdir -p "$OUT_DIR"
python3 "${SCRIPT_DIR}/_lib/distill-ui-ux.py" --data="$DATA" --out="$OUT_DIR"

UX_VERSION="$(basename "$UX_DIR")"
TODAY="$(date -u +%Y-%m-%d)"
ATTR="${OUT_DIR}/ATTRIBUTION.md"
sed -i.bak \
  -e "s|^- \*\*Distilled from version:\*\*.*$|- **Distilled from version:** ${UX_VERSION}|" \
  -e "s|^- \*\*Distilled on date:\*\*.*$|- **Distilled on date:** ${TODAY}|" \
  "$ATTR" 2>/dev/null || true
rm -f "${ATTR}.bak"
echo "Sync complete. Review diffs and commit."
```

- [ ] **Step 2: Write `ATTRIBUTION.md`**

```markdown
# Distilled Design Intelligence — Attribution

These reference files are a **distillation** of the [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max) design-intelligence database by nextlevelbuilder, licensed under MIT.

## Why distilled (not vendored wholesale)

ui-ux-pro-max ships a Python + ~11MB CSV search engine. mega-sdd runs standalone with **no extra runtime dependencies**, so we distill its CSV data into static markdown/YAML consumed as **injected context** (per the Fork-A doctrine in `plugins/mega-sdd/CLAUDE.md`: prose Skill-invokes no-op; injected text + validators are what work). No Python is executed at mega-sdd runtime.

## Files (all GENERATED — do not hand-edit)

| File | Distilled from |
|---|---|
| `product-style-map.yaml` | `products.csv` + `colors.csv` |
| `style-principles.md` | `styles.csv` |
| `palette-principles.md` | `colors.csv` |
| `typography-pairings.md` | `typography.csv` |
| `ux-rules.md` | `ux-guidelines.csv` |

## Metadata

- **Source repo:** https://github.com/nextlevelbuilder/ui-ux-pro-max
- **License:** MIT
- **Distilled from version:** 2.5.0
- **Distilled on date:** 2026-06-05

## Sync policy

Run `scripts/sync-ui-ux.sh` to regenerate from the installed plugin. Review diffs before commit. Sync before each mega-sdd release.

Copyright (c) nextlevelbuilder — original ui-ux-pro-max data.
Copyright (c) 2026 Farhan Riuzaki — mega-sdd distillation + integration.
```

- [ ] **Step 3: Generate the references**

Run: `bash plugins/mega-sdd/scripts/sync-ui-ux.sh`
Expected: `Distilling from: …/data` then `Sync complete.` and 5 files present in `references/design-intelligence/`.

- [ ] **Step 4: Verify output structure**

Run: `bash plugins/mega-sdd/tests/design-intelligence/test-distill.sh && head -20 plugins/mega-sdd/references/design-intelligence/product-style-map.yaml`
Expected: `PASS`, and the YAML shows `products:` with slugged product entries each carrying style/palette/typography/a11y_baseline.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/sync-ui-ux.sh plugins/mega-sdd/references/design-intelligence/
git commit -m "feat(design-intelligence): sync script + generated distilled references + ATTRIBUTION"
```

---

## Task 3: Validator extension — `design_system_not_injected` (TDD)

Extend `validate-dispatch-prompt.sh` so a ui_ux dispatch prompt that carries `Design tokens:` but NOT `Design system:` FAILs. Tech-agnostic: `Design system:` is mega-sdd FORMAT vocabulary, like the existing `Design tokens:` line.

**Files:**
- Modify: `plugins/mega-sdd/scripts/validate-dispatch-prompt.sh`
- Test: `plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# TDD harness: a ui_ux dispatch prompt with Design tokens but NO Design system => FAIL.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/scripts/validate-dispatch-prompt.sh"
ROOT="$(mktemp -d)"
PD="${ROOT}/.mega-sdd/vaults/v1/bolts/U-001"
mkdir -p "$PD"
# minimal pack so the gate does not SKIP: provide a UI quality signatures view_glob
PACKDIR="${ROOT}/.mega-sdd"; mkdir -p "$PACKDIR"
cat > "${ROOT}/.mega-sdd/config.yaml" <<'EOF'
framework_pack: laravel
EOF
# Use the repo laravel pack via resolver default; if unavailable the gate SKIPs (acceptable).
cat > "${PD}/dispatch-prompt.md" <<'EOF'
starterkit_relevance: [ui_ux]
UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[toast]
Design tokens: colors={primary:#2563EB}; spacing=8px; fonts=[Inter]
Reference code example
File: resources/views/orders/show.blade.php
Pattern: view
EOF
OUT="$(bash "$VALIDATOR" --cwd="$ROOT" --quiet 2>/dev/null; echo "EXIT=$?")"
code=$(grep -o 'EXIT=[0-9]*' <<<"$OUT" | cut -d= -f2)
state="${ROOT}/.mega-sdd/.dispatch-prompt-state.json"
if grep -q '"reason": "pack declares no' "$state" 2>/dev/null; then echo "SKIP: no pack view_glob in env"; exit 0; fi
grep -q 'design_system_not_injected' "$state" || { echo "FAIL: expected design_system_not_injected finding"; cat "$state"; exit 1; }
[ "$code" = "1" ] || { echo "FAIL: expected exit 1, got $code"; exit 1; }
echo "PASS (negative)"
# Now add the Design system line => PASS for that finding.
printf 'Design system: minimalism/trust-blue\n' >> "${PD}/dispatch-prompt.md"
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1
grep -q 'design_system_not_injected' "$state" && { echo "FAIL: design_system_not_injected should be gone"; exit 1; }
echo "PASS (positive)"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh`
Expected: FAIL "expected design_system_not_injected finding" (the validator does not check it yet). If the env lacks a laravel pack view_glob it prints `SKIP` — in that case run from the repo root where `references/framework-conventions/laravel.md` resolves.

- [ ] **Step 3: Add the check to the validator**

In `plugins/mega-sdd/scripts/validate-dispatch-prompt.sh`, after the `DESIGN_TOKENS_RE` / `TOKEN_CONTENT_RE` block (currently lines 240–246), add:

```python
# (1b) injected design system — a `Design system:` line carrying a chosen style/palette.
#      Like `Design tokens:`, this is mega-sdd FORMAT vocabulary (the vault `design_system`
#      block, surfaced by execute-bolts Step 4.5), NOT a stack signature.
DESIGN_SYSTEM_RE = re.compile(r"^\s*Design system\s*:(.*)$", re.MULTILINE | re.IGNORECASE)
```

After `has_design_tokens` (currently ends line 267), add:

```python
def has_design_system(text):
    m = DESIGN_SYSTEM_RE.search(text)
    if not m:
        return False
    # require non-empty value (a style/palette token), not a bare label.
    return bool(m.group(1).strip())
```

In the scan loop, after the `tokens_not_injected` append block (currently ends line 309), add:

```python
    if not has_design_system(text):
        issues.append({
            "unit": unit,
            "prompt": rel,
            "issue": "design_system_not_injected",
            "message": (
                "A ui_ux unit's dispatch prompt carries no chosen design system "
                "(no `Design system:` line). execute-bolts Step 4.5 must inject the vault "
                "`design_system` (style/palette) for ui_ux units when the vault resolved a "
                "Design-Source recommendation; the bolt must render per the chosen style, "
                "not a generic look."
            ),
        })
```

In the verdict summary (currently lines 333–345), add a counter and summary key:

```python
design_system_n = sum(1 for i in issues if i["issue"] == "design_system_not_injected")
```
and add `"design_system_not_injected": design_system_n,` inside the `"summary"` dict alongside `tokens_not_injected`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh`
Expected: `PASS (negative)` then `PASS (positive)`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/validate-dispatch-prompt.sh plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh
git commit -m "feat(validator): assert Design system line in ui_ux dispatch prompts"
```

---

## Task 4: Vault schema — `design_system` block + `vault_version` bump

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`

- [ ] **Step 1: Bump `vault_version`**

Replace line 13:
```
  "vault_version": "1.0",
```
with:
```
  "vault_version": "1.1",
```

- [ ] **Step 2: Add the `design_system` block to the schema**

Immediately after the `design_system_flags` block (currently closes at line 47 `}`), add a sibling block. Replace:
```
  "design_system_flags": {
    "HAS_UI_COMPONENTS": false,
    "HAS_TOKENS": false,
    "HAS_A11Y": false,
    "HAS_VOICE_BRAND": true
  }
```
with:
```
  "design_system_flags": {
    "HAS_UI_COMPONENTS": false,
    "HAS_TOKENS": false,
    "HAS_A11Y": false,
    "HAS_VOICE_BRAND": true
  },
  "design_system": {
    "style": "minimalism",
    "palette": "primary #2563EB; accent #EA580C",
    "typography": "Modern Professional (Poppins/Open Sans)",
    "a11y_level": "WCAG AA",
    "source": "design-intelligence-recommend",
    "provenance": "recommend:OQ-DESIGN-SOURCE-1 (references/design-intelligence/product-style-map.yaml#saas-general + PRD §1)"
  }
```

- [ ] **Step 3: Document the field rules + vault_version note**

After the closing ``` of the schema block, add a `§design_system` subsection:

```markdown
### §design_system (v1.1+)

Present when a design system has been resolved for the vault — from a scanned template, an accepted Design-Source recommendation, or an explicit PRD source. Absent otherwise — never a silent default. Fields:

- `style` / `palette` / `typography` / `a11y_level` — the resolved design system, each traceable to its source.
- `source` — one of `prd` | `scanned-template` | `design-intelligence-recommend`. **Precedence (highest→lowest): `prd` > `scanned-template` > `design-intelligence-recommend`.** When a template was scanned (`starterkit-context.yaml §ui_ux`), `source: scanned-template` and the values are DERIVED FROM the template — ui-ux-pro-max never overrides it, only gap-fills.
- `provenance` — the source citation: the resolving OQ tag + design-intelligence citation + PRD signal (for `design-intelligence-recommend`), or the `starterkit-context.yaml §ui_ux` anchor (for `scanned-template`). Required when the block is present (anti-halu: no design system without provenance).

`vault_version` is bumped to `1.1` because this block is additive to the manifest. Consumers on `1.0` simply do not see it (backward compatible).
```

- [ ] **Step 4: Verify**

Run: `python3 -c "import json,sys" && grep -n 'design_system' plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`
Expected: `design_system_flags` AND the new `design_system` block + `§design_system` heading appear.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "feat(vault): add design_system block (vault_version 1.0->1.1)"
```

---

## Task 5: Intent-time — Design-Source OQ gains the `recommend` path

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/generation-guide.md`

- [ ] **Step 1: Extend Rule 2** — replace the current Rule 2 (line 42) so the OQ is emitted as `recommend` with a grounded design-intelligence pick, not only blocking.

Replace:
```
**Rule 2 — emit a Design-Source OQ, never a defaulted value.** When `HAS_UI_COMPONENTS = true` (UI components exist) but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`** (no design tokens, no accessibility spec, no voice/brand source was provided), emit a single high-priority **Design-Source Open Question** — e.g. `OQ-DESIGN-SOURCE-{N} [P1]` — requesting the design-system source (token palette, WCAG target, brand voice) before UI units are enriched. **DO NOT relax the anti-hallucination rail:** never default WCAG levels, Material/Tailwind palettes, spacing scales, or brand voice from prior knowledge — the gap is captured as an OQ ONLY. The validator FAILs with `design_source_oq_missing` when UI components exist with all three design flags false and no Design-Source OQ is present.
```
with:
```
**Rule 2 — design system: template-first, then recommend, never a defaulted value.** When `HAS_UI_COMPONENTS = true` (UI components exist) but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`** (no design source in PRD/Figma/KB), resolve the design system by **precedence** — never by silently defaulting WCAG levels, Material/Tailwind palettes, spacing scales, or brand voice from prior knowledge:

1. **Scanned template wins (source: `scanned-template`).** If a starterkit was scanned and `starterkit-context.yaml §ui_ux` supplies a design system (`design_tokens` / `layout_extends` / `idioms`), DERIVE `design_system` from the template — its flow is authoritative. **ui-ux-pro-max does NOT recommend a style here; it must not override or contradict the template.** Emit a Design-Source OQ ONLY for a genuine gap the template is silent on (e.g. a missing chart palette), and that gap-fill OQ must align with template idioms. Write `design_system` with `source: scanned-template`, `provenance` citing the `starterkit-context.yaml §ui_ux` anchor.

2. **Greenfield — recommend (source: `design-intelligence-recommend`).** ONLY when there is no scanned template design system (true greenfield / `--greenfield`), emit a single high-priority **Design-Source Open Question** `OQ-DESIGN-SOURCE-{N} [P1]` with `resolution_mode: recommend` (NOT a silent default — see vault-contract.md §OQ schema). Consult `references/design-intelligence/product-style-map.yaml` using PRD signals (product type, industry, brand hints):
   - `recommendation`: the chosen `{style, palette, typography, a11y_level}` from the matched `product-style-map` entry.
   - `rationale`: the PRD signal → matched map key (e.g. "product_type=SaaS dashboard (PRD §1) → product-style-map.yaml#saas-general").
   - `scan_citations`: `["references/design-intelligence/product-style-map.yaml#<key>", "<PRD §>"]` — **never fabricate**; if no map entry matches, fall back to a bare `resolution_mode: blocking` OQ instead.
   - `fallback_if_wrong`: "blocking — request an explicit design source from the PO".
   Only when the user accepts is the `design_system` block written (with `source: design-intelligence-recommend`).

In both cases the `design_system` block (vault-contract.md §design_system) is written to `vault.json` + the `06-constraints.md > Design system` section, each line cited to its source. The validator still FAILs with `design_source_oq_missing` when UI components exist with all three design flags false and **no** Design-Source OQ (blocking or recommend) is present AND no scanned-template design system was derived.
```

- [ ] **Step 2: Verify**

Run: `grep -n 'resolution_mode: recommend\|product-style-map' plugins/mega-sdd/skills/generate-intent/references/generation-guide.md`
Expected: the new lines appear inside Rule 2.

- [ ] **Step 3: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/generation-guide.md
git commit -m "feat(generate-intent): resolve Design-Source OQ as recommend via design-intelligence"
```

---

## Task 6: Propagation — `design_system_ref` in the UI contract

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/references/decomposition-rails.md`

- [ ] **Step 1: Add the field** — in the `## UI contract` YAML block, after the `grounded_in` line (currently line 120), add `design_system_ref`.

Replace:
```
grounded_in: ["04-flows.md F-U-003 step 2", "02-architecture §Widget"]   # citations (anti-halu)
```
with:
```
grounded_in: ["04-flows.md F-U-003 step 2", "02-architecture §Widget"]   # citations (anti-halu)
design_system_ref: "vault.design_system"   # present ONLY when the vault carries a design_system block (vault-contract.md §design_system); propagates the accepted style/palette/a11y to the bolt so the view renders on-system, not generic. Omit when absent.
```

- [ ] **Step 2: Verify**

Run: `grep -n 'design_system_ref' plugins/mega-sdd/skills/generate-units/references/decomposition-rails.md`
Expected: the new field appears in the UI contract block.

- [ ] **Step 3: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/references/decomposition-rails.md
git commit -m "feat(generate-units): UI contract design_system_ref for propagation"
```

---

## Task 7: Bolt-time — inject `Design system:` in the ui_ux slice

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md`

- [ ] **Step 1: Extend the slice BUILD** — after the `design_tokens` build comment (currently lines 108–115), add the design_system build. Replace the line:
```
IF "ui_ux" in unit.starterkit_relevance AND starterkit_context.ui_ux exists:
  slice.ui_ux = starterkit_context.ui_ux (layout_extends, notification_lib, idioms, AND design_tokens — exclude _source)
```
with:
```
IF "ui_ux" in unit.starterkit_relevance AND starterkit_context.ui_ux exists:
  slice.ui_ux = starterkit_context.ui_ux (layout_extends, notification_lib, idioms, AND design_tokens — exclude _source)
  # TEMPLATE FLOW IS AUTHORITATIVE: the starterkit design_tokens/layout/idioms above WIN. Anything
  # from design_system only SUPPLEMENTS them — it must never override the scanned template.
  IF vault.design_system present (vault-contract.md §design_system):
    slice.design_system = vault.design_system (style, palette, a11y_level, source)
    IF design_system.source == "scanned-template":
      # the `Design system:` line restates the TEMPLATE's own style/tokens; the design-intelligence
      # slice (style-principles/ux-rules) is injected ONLY as gap-fill, explicitly subordinate to the
      # starterkit tokens already in the prompt — the bolt follows the repo's existing flow.
    ELSE:  # source == design-intelligence-recommend or prd (greenfield / explicit source)
      # pull the matching slice of references/design-intelligence: style-principles[style]
      # (traits + CSS keywords + anti-patterns) and the a11y rows of ux-rules.md, as injected text
      # so the bolt renders ON the chosen style.
    # ALL of this is INJECTED TEXT — never a Skill-invoke.
```

- [ ] **Step 2: Extend the slice EMIT** — after the `Design tokens:` emit line (currently lines 244–246), add the `Design system:` marker line. Replace:
```
<IF slice.ui_ux.design_tokens present:>     # emit the literal `Design tokens:` marker line
Design tokens: colors=<design_tokens.colors as compact map>; spacing=<design_tokens.spacing>; fonts=[<design_tokens.fonts joined by ", ">]
</IF>
```
with:
```
<IF slice.ui_ux.design_tokens present:>     # emit the literal `Design tokens:` marker line
Design tokens: colors=<design_tokens.colors as compact map>; spacing=<design_tokens.spacing>; fonts=[<design_tokens.fonts joined by ", ">]
</IF>
<IF slice.design_system present:>           # emit the literal `Design system:` marker line (validate-dispatch-prompt.sh asserts it)
Design system: <design_system.style>/<design_system.palette> (a11y <design_system.a11y_level>) — render on this style; see injected style-principles + ux-rules.
</IF>
```

- [ ] **Step 3: Verify**

Run: `grep -n 'Design system:' plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md`
Expected: both the build (`slice.design_system`) and the emit (`Design system:` marker line) appear.

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md
git commit -m "feat(execute-bolts): inject Design system line in ui_ux bolt dispatch slice"
```

---

## Task 8: Versioning consistency + CHANGELOG

**Files:**
- Modify: 3 SKILL.md `version:` lines, `plugin.json`, root `marketplace.json`, root `CHANGELOG.md`.

- [ ] **Step 1: Bump the 3 skill versions** (all currently `version: 2.0.0` at line 3)

In each of `skills/generate-intent/SKILL.md`, `skills/execute-bolts/SKILL.md`, `skills/generate-units/SKILL.md`, replace `version: 2.0.0` with `version: 2.1.0`.

- [ ] **Step 2: Bump the plugin version**

In `plugins/mega-sdd/.claude-plugin/plugin.json`, replace `"version": "4.0.0",` with `"version": "4.1.0",`.

In root `.claude-plugin/marketplace.json`, replace the mega-sdd entry version (line 12) `"version": "4.0.0",` with `"version": "4.1.0",`. **Do NOT touch line 27 (`"0.16.0"` — a different plugin entry).**

- [ ] **Step 3: Verify the two match**

Run: `grep -m1 '"version"' plugins/mega-sdd/.claude-plugin/plugin.json && sed -n '12p' .claude-plugin/marketplace.json`
Expected: both show `4.1.0`.

- [ ] **Step 4: Add the CHANGELOG entry** — insert directly above `## [4.0.0] - 2026-06-04` (currently line 10) in root `CHANGELOG.md`:

```markdown
## [4.1.0] - 2026-06-05

### Added — UI/UX design intelligence (distilled ui-ux-pro-max)

Distilled `ui-ux-pro-max` v2.5.0 (MIT, nextlevelbuilder) design knowledge into `references/design-intelligence/` (product-style-map, style/palette/typography principles, ux-rules) via a sync-time distiller (`scripts/_lib/distill-ui-ux.py` + `scripts/sync-ui-ux.sh`). **No runtime dependency** — mega-sdd reads only the committed markdown/YAML.

- **Intent-time:** the Design-Source OQ now resolves as `resolution_mode: recommend`, populating a grounded `{style, palette, typography, a11y_level}` from `product-style-map.yaml` (rationale + citation + fallback + user confirmation). Anti-halu moat preserved — a recommendation, never a silent default.
- **Vault:** new `design_system` block in `vault.json` (`vault_version` 1.0 → 1.1) carrying the accepted design system + provenance.
- **Units:** `## UI contract` gains `design_system_ref` to propagate the choice to bolts.
- **Bolt-time:** `execute-bolts` Step 4.5 injects a `Design system:` line + the matching style-principles/ux-rules slice into ui_ux dispatch prompts.
- **Enforcement:** `validate-dispatch-prompt.sh` now also asserts the `Design system:` line for ui_ux units (`design_system_not_injected`).

Skills bumped: `generate-intent`, `generate-units`, `execute-bolts` → 2.1.0.

```

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/SKILL.md plugins/mega-sdd/skills/execute-bolts/SKILL.md plugins/mega-sdd/skills/generate-units/SKILL.md plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "chore(release): mega-sdd 4.1.0 — design-intelligence integration + version sync"
```

---

## Final verification

- [ ] **Run the new tests:**
```bash
bash plugins/mega-sdd/tests/design-intelligence/test-distill.sh
bash plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh
```
Both expected: `PASS`.

- [ ] **Run the existing dispatch-prompt + ui-quality fixtures** to confirm no regression:
```bash
ls plugins/mega-sdd/tests/ && grep -rl "validate-dispatch-prompt" plugins/mega-sdd/tests/ 2>/dev/null
```
Run any found, expected: unchanged pass/skip behavior.

- [ ] **Confirm version parity:**
```bash
grep -m1 '"version"' plugins/mega-sdd/.claude-plugin/plugin.json   # 4.1.0
sed -n '12p' .claude-plugin/marketplace.json                        # 4.1.0
grep -n 'version: 2.1.0' plugins/mega-sdd/skills/generate-intent/SKILL.md plugins/mega-sdd/skills/execute-bolts/SKILL.md plugins/mega-sdd/skills/generate-units/SKILL.md
```

- [ ] **Push the branch** (only when the user asks) and open a PR per `CLAUDE.md` review policy.
```

## Notes for the executor

- **`ui-ux-pro-max` must be installed** for Tasks 1–2 (the distiller needs the CSVs). If absent, those tasks `SKIP` — install via `/plugin` first, or the committed `references/design-intelligence/*` from a prior sync can be reused.
- The `ux-guidelines.csv` column names vary by version; the distiller emits the first 4 columns generically (Step 3, Task 1) — eyeball `ux-rules.md` after the first sync and tighten the column selection if the headers are awkward (the one curation-depth detail flagged in the spec §12).
- Every prose-skill edit (Tasks 4–7) is enforced downstream by the Task 3 validator + the generate-intent `design_source_oq_missing` gate — that is the durable guarantee, per the rule→gate→hook doctrine.

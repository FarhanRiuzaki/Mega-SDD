# Distilled Design Intelligence — Attribution

These reference files are a **distillation** of the [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max) design-intelligence database by nextlevelbuilder, licensed under MIT.

## Why distilled (not vendored wholesale)

ui-ux-pro-max ships a Python + ~11MB CSV search engine. mega-sdd runs standalone with **no extra runtime dependencies**, so we distill its CSV data into static markdown/YAML consumed as **injected context** (per the enforcement doctrine in `plugins/mega-sdd/CLAUDE.md §The enforcement doctrine`: prose Skill-invokes no-op; injected text + validators are what work). No Python is executed at mega-sdd runtime.

## Files (all GENERATED, frozen since 2026-06-05 — do not hand-edit)

| File | Distilled from |
|---|---|
| `product-style-map.yaml` | `products.csv` + `colors.csv` |
| `style-principles.md` | `styles.csv` |
| `typography-pairings.md` | `typography.csv` |
| `ux-rules.md` | `ux-guidelines.csv` |

## Metadata

- **Source repo:** https://github.com/nextlevelbuilder/ui-ux-pro-max
- **License:** MIT
- **Distilled from version:** 2.5.0
- **Distilled on date:** 2026-06-05

## Sync policy

The distiller (`distill-ui-ux.py`) was retired on 2026-09-29: nothing ran it and the data has not changed since 2026-06-05. To re-sync with a newer ui-ux-pro-max, restore it from commit 94121d8c (`git show 94121d8c:plugins/mega-sdd/scripts/_lib/distill-ui-ux.py`), run it against the installed plugin's data, and review the diffs before commit.

Copyright (c) nextlevelbuilder — original ui-ux-pro-max data.
Copyright (c) 2026 Farhan Riuzaki — mega-sdd distillation + integration.

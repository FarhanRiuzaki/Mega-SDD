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

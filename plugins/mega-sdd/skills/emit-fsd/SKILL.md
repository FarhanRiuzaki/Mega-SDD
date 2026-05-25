---
name: emit-fsd
version: 1.0.0
description: Generate a Hybrid Confluence-format FSD (Functional Specification Document) — Markdown + PDF — from a mega-sdd vault. Grounded on actual vault/units/bolts/binding artifacts with sha256-stamped citation discipline per `.citation-map.json`. Mode auto-detect — pre-development (vault only) vs post-development (vault + bolts). PDF via pandoc + xelatex/tectonic; HTML fallback when LaTeX absent; markdown-only when pandoc absent. Triggers — "generate FSD", "emit FSD", "buat FSD", "FSD untuk confluence", or paraphrases.
---

# Emit-FSD — Functional Specification Document Generator

**Announce at start:** "I'm using the emit-fsd skill to generate the FSD from the current vault."

## When to use

- "generate FSD" / "emit FSD" / "buat FSD" / "FSD untuk confluence"
- Pre-development sign-off: after generate-intent stabilizes the vault, before bolts run
- Post-development as-built record: after execute-bolts completes
- Re-emission on PRD revision (diff-vault) or OQ resolution (resolve-oq)

## Inputs

- `<vault-path>` (positional, optional — defaults to first vault detected via `references/paths.md` priority order)
- `--mode={pre-dev|post-dev|auto}` (default: `auto` — detect from CWD state)
- `--no-pdf` (markdown-only; useful when pandoc/LaTeX absent)
- `--styling=<path-to-yaml>` (override default `FSD.styling.yaml`)
- `--sections=<comma-list>` (emit subset; e.g., `--sections=1,2,5,7,8,10`)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per `mega-sdd:orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<vault-path>/fsd/
├── FSD.md                      # source markdown (10-section Hybrid Confluence template)
├── FSD.pdf                     # rendered PDF via pandoc (absent if pandoc/LaTeX unavailable)
├── FSD.styling.yaml            # styling config (generated on first run; preserved on re-emit)
└── .citation-map.json          # vault-section → FSD-section citation trace
```

## Pre-flight checks

1. **vault_present_for_fsd**: `test -f <vault-path>/vault.json` — required (halt `dep_missing` if absent)
2. **pandoc_installed**: `command -v pandoc` — warn if absent (degraded to markdown-only)
3. **pandoc_latex_engine_present**: `command -v xelatex || command -v tectonic` — warn if absent (degraded to HTML fallback)

Full preflight catalog: `mega-sdd:orchestrate-flow/references/predictive-checks.md` §emit-fsd preflight checks.

## Procedure

(filled in subsequent tasks — see plan)

## Halt protocol

(filled in Task 6)

## Handoff emission (v1.0.0+, Iter 54)

(filled in Task 6)

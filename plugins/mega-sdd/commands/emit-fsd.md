---
description: ADVANCED / AUTO-INVOKED — Generate Hybrid Confluence FSD (Markdown + PDF) from vault/units/bolts state with sha256-stamped citation discipline. Auto-invoked by `/mega-sdd:auto` at chain end (skip via `--no-fsd`). Run standalone for on-demand regen (e.g., after diff-vault / resolve-oq). Mode auto-detect — pre-development (vault only) vs post-development (vault + bolts). PDF via pandoc + xelatex/tectonic; HTML fallback when LaTeX absent; markdown-only when pandoc absent. Anti-hallucination — every section traces to source artifact; missing source emits [Pending — X] placeholder, never fabricates.
argument-hint: "[vault-path] [--mode=pre-dev|post-dev|auto] [--no-pdf] [--styling=<path>] [--sections=<csv>] [--auto]"
---

Invoke the `mega-sdd:emit-fsd` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault path (default: detect in priority order — `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy back-compat))
- `--mode=pre-dev|post-dev|auto`: emit mode override (default `auto` — detect from CWD state)
- `--no-pdf`: markdown-only output (skips pandoc invocation; useful when pandoc/LaTeX absent or for fast preview)
- `--styling=<path-to-yaml>`: override default `<vault>/fsd/FSD.styling.yaml` location
- `--sections=<comma-list>`: emit subset (e.g., `--sections=1,2,5,7,8,10` for stakeholder-specific FSD)
- `--auto`: skip confirmation prompts + emit handoff YAML in chat (e.g., when invoked by orchestrate-flow at chain end)

Follow `skills/emit-fsd/SKILL.md` Procedure exactly. Auto-invocation respects `--no-fsd` flag on `/mega-sdd:auto` (skip emit at chain end).

Hard rails (anti-halu):
- FSD is a CITATION-GROUNDED VIEW of vault/units/bolts/binding. NEVER adds info not in source artifacts.
- Every section text MUST trace to a source artifact via `.citation-map.json` — the map and ALL sha256 stamps are SCRIPT-COMPUTED (`scripts/build-citation-map.sh`) from file bytes; the model never writes a hash.
- Missing source → emit `[Pending — <source> not yet generated]` placeholder; NEVER fabricate content.
- Slot markers `{{slot_name}}` in fsd-template.md MUST be filled OR explicitly placeholdered — empty slot = halt `quality_gate_failed:template_slot_unfilled`.
- Drift callouts MUST surface in PDF on re-emit when source sha256 changed — silent regeneration would hide content changes from reviewers (drift list produced by `scripts/check-citation-drift.sh`).
- Mode auto-detect from CWD state; user can force via `--mode=pre-dev|post-dev`.

On completion, announce path to `<vault>/fsd/FSD.pdf` (or `FSD.html` LaTeX-fallback / `FSD.md` pandoc-absent fallback) + summary line: "FSD emitted: N sections, M citations, mode: <pre-dev|post-dev>". User uploads PDF manually to Confluence per corporate workflow.

# UI/UX Design-Intelligence Integration — Design Spec

- **Date:** 2026-06-05
- **Status:** Approved (brainstorm) — pending implementation plan
- **Target plugin version:** mega-sdd 4.0.0 → 4.1.0 (minor; additive, non-breaking)
- **Source:** `ui-ux-pro-max` v2.5.0 (MIT, nextlevelbuilder) — distilled, not vendored wholesale

## 1. Goal

Raise the quality of UIs that mega-sdd generates by bringing `ui-ux-pro-max`'s design knowledge (67 styles, 161 palettes, 57 font pairings, 99 UX guidelines) into the pipeline as a **grounded design decision** at spec time and as **injected rendering context** at implementation time.

The outcome is better-looking, more consistent, more accessible generated UI — **not** a literal live invocation of the `ui-ux-pro-max` skill. Mechanism follows the outcome.

## 2. Constraints (the forks that shaped this design)

1. **`ui-ux-pro-max` is a Python + CSV search engine (~11MB), not a markdown skill.** Its `SKILL.md` drives `search.py` (BM25 over CSV data) via symlinks to `src/`. It cannot be vendored like superpowers (pure prompt-text skills), and a live call would require a **Python runtime dependency** — which violates mega-sdd's "no extra runtime dependencies" rule. → We **distill** its data into injected-context references; **no runtime Python**.
2. **mega-sdd's architecture rejects prose Skill-invokes.** Per `CLAUDE.md` Fork-A doctrine + `references/ui-design-heuristics.md`, "invoke skill X" wire-ups in skill bodies historically no-op'd. The proven pattern is **distilled data → injected text context → deterministic validator wired to a hook** (rule → gate → hook). This integration uses that pattern exclusively.
3. **Anti-hallucination moat — "no defaulted standards."** WCAG levels, palettes, type scales may appear ONLY when a source supplies them, otherwise they become Open Questions. A design recommendation therefore cannot be a silent default; it must be a **flagged recommendation** that resolves an OQ with rationale + citation + fallback + user confirmation.
4. **Tech-stack agnostic mandate.** Design decisions (style/palette/typography) are stack-independent and live in a universal reference. Per-stack rendering detail stays in the existing framework-pack lane — no duplication.

## 3. Architecture overview

Pattern: **distilasi → injected-context → validator**, reusing existing pipeline machinery (Design-Source OQ, Step 4.5 context-enrichment, `validate-dispatch-prompt.sh`).

```
plugins/mega-sdd/
├── references/design-intelligence/          ← NEW (vendored DISTILLATION, not the engine)
│   ├── ATTRIBUTION.md                         ← MIT, nextlevelbuilder/ui-ux-pro-max, version+date (sync-stamped)
│   ├── product-style-map.yaml                 ← product-type / industry → {style, palette-family, type-pairing, a11y-baseline}
│   ├── style-principles.md                    ← per-style traits + CSS keywords + anti-patterns (distilled from styles.csv)
│   ├── palette-principles.md                  ← palette principles + semantic tokens (distilled from colors.csv)
│   ├── typography-pairings.md                 ← font pairings + Google Fonts imports (distilled from typography.csv)
│   └── ux-rules.md                            ← 99 UX guidelines + a11y priority 1→10 table (distilled from SKILL.md + ux data)
└── scripts/sync-ui-ux.sh                     ← NEW (mirror sync-superpowers.sh): regen the 5 files from the installed plugin
```

- Home is `references/design-intelligence/` (sibling to `framework-conventions/`), **not** `skills/_vendored/` — the latter is reserved for runnable skill copies. This is distilled data consumed as injected context.
- All five reference files are **stack-agnostic**.

## 4. Component design

### 4.1 The distilled reference (`references/design-intelligence/`)

- `product-style-map.yaml` — the selection backbone. Keyed by product type / industry signal; each entry yields a recommended `{style, palette, typography, a11y_level}` with a short rationale. This is what generate-intent reasons over to produce a grounded recommendation **without** a Python search at runtime.
- `style-principles.md`, `palette-principles.md`, `typography-pairings.md`, `ux-rules.md` — the supporting knowledge injected at bolt time (only the slice relevant to the chosen style / the unit's component).
- `ATTRIBUTION.md` — MIT attribution to `ui-ux-pro-max` v2.5.0, stamped with vendored version + date by the sync script.

### 4.2 `scripts/sync-ui-ux.sh`

Mirrors `sync-superpowers.sh`:
- Auto-resolve the latest installed `ui-ux-pro-max` version under the plugin cache (or accept an explicit source path arg).
- Run a distillation helper that transforms the plugin's CSV data + `SKILL.md` quick-reference into the five curated files. **The helper may use the plugin's own `search.py`/Python at sync/release time only — never at mega-sdd runtime.**
- Stamp `ATTRIBUTION.md` with source version + today's date.
- Manual diff review before commit is mandatory (same policy as superpowers).

## 5. Data flow

### 5.1 Intent-time (generate-intent) — resolve the Design-Source OQ as `recommend`

Reuse the **existing** Design-Source OQ mechanism. Today: when `HAS_UI_COMPONENTS=true` but no design source is present, a blocking OQ is emitted. New behavior:

```
IF HAS_UI_COMPONENTS=true AND no design source in PRD/Figma/KB:
  → consult references/design-intelligence/product-style-map.yaml using PRD signals
    (product type, industry, brand hints)
  → emit a GROUNDED RECOMMENDATION (never a silent default):
      OQ-DESIGN-SOURCE-1 [P1] [tech]
        resolution_mode: recommend
        recommendation: { style, palette, typography, a11y_level }
        rationale: "<PRD signal> → design-intelligence/product-style-map"
        scan_citations: [references/design-intelligence/product-style-map.yaml#<key>, <PRD §>]
        fallback_if_wrong: "blocking — request a design source from the PO"
  → user CONFIRMS (or via resolve-oq) → THEN write the design_system block
```

On acceptance, the vault gains:
- `06-constraints.md > Design system` — style / palette / tokens / a11y, each line cited to design-intelligence + the PRD signal.
- `vault.json` → new `design_system: { style, palette, typography, a11y_level, provenance }` block.

**Moat preserved:** this is `recommend` (flagged + rationale + citation + fallback + confirmation), exactly the existing tech-OQ `recommend` pattern — not the forbidden "defaulted standard."

### 5.2 Propagation (generate-units)

Light touch: the `## UI contract` attached to view-bearing units gains a `design_system_ref` that cites `vault.design_system`, so the chosen design propagates from spec to bolt (producer + consumer in the same iteration).

### 5.3 Bolt-time (execute-bolts Step 4.5 context-enrichment)

Extend the existing `ui_ux` starterkit slice (which already injects `design_tokens` + `ui-design-heuristics.md`):

```
IF "ui_ux" in unit.starterkit_relevance:
  slice.design_system = vault.design_system          # style + palette + tokens + a11y
  + inject the RELEVANT slice of references/design-intelligence:
      - style-principles[chosen_style]   (traits, CSS keywords, anti-patterns)
      - ux-rules                          (required states + a11y for this unit's component)
  → all as INJECTED TEXT in the dispatch prompt (NOT a Skill-invoke)
```

The bolt subagent renders the view per the **chosen, cited** style/palette instead of a generic look.

## 6. Validation (reuse, no new hook)

Per the rule → gate → hook doctrine, no new hook is added:
- **Extend `validate-dispatch-prompt.sh`** — it already asserts a `Design tokens:` line is present for `ui_ux` units; add an assertion that a `Design system: <style>/<palette>` line is present. Deterministic, cheap, wired to the existing PreToolUse gate.
- **`validate-ui-quality.sh` is left unchanged** — it keeps checking scaffold_tells / required_elements. It is deliberately NOT made to verify hex/color matching (fragile, over-build).

## 7. Error handling / halts

- Intent-time: if the user rejects the recommendation and supplies no design source, the OQ falls back to `blocking` (existing `design_source_oq_missing` behavior). No regression.
- Bolt-time: if a `ui_ux` unit's dispatch prompt lacks the `Design system:` line, `validate-dispatch-prompt.sh` fails the existing gate (blocks the bolt) — surfaced like any other dispatch-prompt failure.
- Sync: if `ui-ux-pro-max` is not installed, `sync-ui-ux.sh` errors with guidance (same shape as `sync-superpowers.sh`); the committed distilled files remain usable regardless (runtime never needs the plugin).

## 8. Versioning consistency (first-class deliverable, same iteration)

- Per-skill `version:` bumps: `generate-intent`, `execute-bolts`, `generate-units`.
- Plugin SemVer **4.0.0 → 4.1.0** in `plugin.json` AND `marketplace.json` (must match).
- `vault.json` `vault_version` bump for the new `design_system` block, documented in `vault-contract.md`.
- `CHANGELOG.md` entry.
- `references/design-intelligence/ATTRIBUTION.md` (MIT, ui-ux-pro-max v2.5.0).
- Derivative docs: note `design_system` in the vault/template references so they stay consistent with the prior frontmatter-contract cleanup.

## 9. Testing

- Fixture proving: (a) Design-Source OQ resolves via `recommend` → `design_system` written to the vault; (b) a `ui_ux` bolt dispatch carries the `Design system:` line and the validator passes.
- Update the `validate-dispatch-prompt.sh` test for the new assertion.
- No new trigger test (no new skill introduced).

## 10. Scope

One full vertical slice in a single iteration, committed in sync: distilled artifact + sync script + intent-time OQ-recommend + vault schema + units propagation + bolt-time injection + validator extension + tests + version bumps + changelog. Nothing deferred.

## 11. Out of scope

- Live querying of `ui-ux-pro-max` at runtime (rejected: Python runtime dep).
- Vendoring the full 11MB CSV corpus or the search engine.
- Per-stack design rendering specifics (stays in framework-packs).
- Color/hex correctness verification in the post-render UI-quality gate.

## 12. Open questions

- None blocking. The exact curation depth of each distilled file (how many styles/palettes to carry vs. summarize) is an implementation detail to settle when writing `sync-ui-ux.sh`'s distillation helper.

# Review Panel — parallel blind reviewer lenses

How the execute-bolts controller reviews a bolt after `bolt-implementer` reports DONE: a risk-tiered panel of read-only lenses dispatched **in parallel, blind**, then merged in the main thread. Design: `docs/superpowers/specs/2026-06-12-review-panel-design.md`.

## Contents

- The lenses
- Tier selection (risk-based)
- Blind dispatch protocol
- Merge + severity gate
- Cost notes

## The lenses

| Lens | Agent | Model (catalog) | Judges |
|---|---|---|---|
| spec | `mega-sdd:spec-reviewer` | §spec-reviewer | spec fidelity: nothing missing/extra, Hard rules, target_files, acceptance test real |
| quality | `mega-sdd:code-quality-reviewer` | §code-quality-reviewer | duplication/failure-to-reuse, test quality, over-engineering, maintainability |
| security | `mega-sdd:security-reviewer` | §security-reviewer | input validation, authz vs spec, secrets, new deps, fail-open, architectural drift |
| standards | `mega-sdd:standards-reviewer` | §standards-reviewer | naming/location/idiom conformance vs pack + surrounding code |

Models are NEVER hardcoded — cite `plugins/mega-sdd/references/model-tiers.md` rows; the override chain (CLI > project config > user preference > catalog) applies per lens.

## Tier selection (risk-based)

Resolve the tier BEFORE dispatch, once per unit:

| Tier | Lenses | Selected when |
|---|---|---|
| `minimal` | spec | ALL of: ≤2 target files · zero risk signals · no `operation: create` files |
| `standard` | spec + quality | default — anything neither minimal nor full |
| `full` | all four | ANY risk signal fires |

**Risk signals** (evaluate against the unit + active framework pack):
1. Any `target_files` path matches the pack's `auth_hints` or `authz_hints` globs.
2. A dependency manifest (package.json, composer.json, requirements/pyproject, go.mod, Cargo.toml, Gemfile) is in `target_files`.
3. `target_files` count ≥ 4.
4. The unit body mentions auth, session, token, crypto, password, payment, or upload (case-insensitive).
5. `binding_refs` cite a constitution §B (Security) clause.

**Override chain:** `--review-panel=minimal|standard|full|auto` CLI flag > `.mega-sdd/config.yaml` `review_panel:` > `auto` (the table above). A forced tier is logged in the bolt-report; forcing `minimal` on a unit with risk signals adds a one-line warning (never silent).

## Blind dispatch protocol

- **One message, N Agent calls** — all selected lenses dispatch concurrently from the main-thread controller. Depth-1 is preserved: the controller→agent shape is unchanged; the panel adds parallelism, not nesting.
- **Each lens prompt contains:** the unit body + frontmatter, base/head commit SHAs, and lens-specific context only — security gets the constitution §B clauses + binding_refs + the active pack's `## Security idioms` slice; standards gets the pack naming/location/idiom slice + codebase-map conventions; quality gets the reuse-index path + reuse_candidates.
- **Each lens prompt NEVER contains:** the implementer's report or self-assessment, another lens's verdict, or any prior attempt's review. Blind review is the anti-rubber-stamp rail — do not "save tokens" by sharing context between lenses.
- **Each lens prompt DOES contain the L0 code-gate results** (`## Deterministic scan results`, per `code-gates.md`) — machine fact, not another lens's opinion, so blindness is intact. Lenses skip what machines already caught and judge what machines can't.
- Re-reviews after a re-dispatch are equally blind: the lens gets the new SHAs and the unit, not the history of what it flagged before.

## Merge + severity gate

The controller (main thread) merges the lens reports:

1. **Evidence-or-drop** — a finding with no `file:line` anchor is discarded (mirrors the no-fabrication invariant). Log dropped count.
2. **Dedup** — same (file, overlapping lines, same issue class) across lenses → keep one entry at the MAX severity, note all reporting lenses.
3. **Consensus** — a finding reported by ≥2 lenses is marked `confidence: high` in the merged list.
4. **Gate:**
   - spec lens ❌ OR any **Critical** (any lens) → re-dispatch `bolt-implementer` with the merged issue list (the SHARED `--max-retries` cap — panel retries and spec retries draw from the same budget).
   - **Important** findings → recorded in `bolt-report.md` under `## Review panel`; the bolt is mergeable.
   - **Minor** → logged in the same section, no action required.
5. The merged findings are written into `bolt-report.md` `## Review panel` (lens list, tier used, finding table, dropped-no-evidence count). No separate artifact file.

The deterministic post-flight Hard-rule scan still runs AFTER the panel passes and BEFORE commit — the panel is judgment, the scan is the contract. Neither replaces the other.

## Cost notes

A full panel is ~4 fresh agent contexts per bolt attempt — multiples of a single-reviewer run. The tier table is the cost control: routine bolts pay for one lens, risky bolts pay for four. Tune per project via `review_panel:` in `.mega-sdd/config.yaml` (e.g., `full` for a payments service, `standard` for an internal tool) and per-lens model tiers via `model_tiers:`.

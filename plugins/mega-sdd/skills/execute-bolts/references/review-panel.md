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
| design | `mega-sdd:design-reviewer` | §design-reviewer | modern UI quality vs the vault design_system + modern-baseline (UI-bearing units only) |

Panel lens models are pinned in each agent's frontmatter (`agents/*-reviewer.md` `model:`) — that is the value the runtime actually uses; the `model-tiers.md` catalog rows document the intended tier, and catalog↔frontmatter parity is a release-time obligation (checked by the panel pin test), not a runtime override. The `model_tiers:` config override chain applies to skill-level model picks, NOT to the panel lenses — a `model_tiers: {security-reviewer: …}` entry is silently ignored at panel dispatch (plugin agents read their own frontmatter).

## Tier selection (risk-based)

Resolve the tier BEFORE dispatch, once per unit:

| Tier | Lenses | Selected when |
|---|---|---|
| `minimal` | spec | ALL of: ≤2 target files · zero risk signals · no `operation: create` files |
| `standard` | spec + quality | default — anything neither minimal nor full |
| `full` | spec + quality + security + standards | ANY risk signal fires |

**Additive design lens:** `design-reviewer` JOINS the selected tier (any tier) whenever the unit is UI-bearing per `context-enrichment.md §Design slice` (target_files match the pack `view_glob` or the universal frontend shapes). It receives the SAME design slice injected into the implementer's prompt as its rubric — one contract, two sides. Pure-backend units never pay for it.

**Live-app capture (the ceiling lens).** The design slice carries `modern-baseline.md §Ceiling moves` — the floor (tokens/states/a11y, provable from code) is not a passing grade; the ceiling (composition, hierarchy, distinctiveness) usually needs the render. Before dispatching the design lens, the controller MAY run `scripts/capture-views.sh --url=<dev-server> --routes=<unit's routes> --out=<bolt-dir>/views` when a dev-server URL is known (`.mega-sdd/config.yaml` `preview_url:` or the operator supplies one — there is NO per-unit frontmatter field; unit-schema.md defines none and generate-units would never round-trip it); captured screenshots are passed to the design lens, which judges the actual render. **Stack-agnostic** — capture hits URLs, so it works for any stack (Laravel/Blade, Django, Rails, a Node SPA); the driver tries a system Chrome/Chromium first (no Node) then npx playwright. Every failure mode (server down, no headless browser, no URL) is a graceful SKIP — the lens then judges the ceiling from code and SAYS it saw no render. Capture is never a gate; an un-captured render is never reported as fine.

**Risk signals** (evaluate against the unit + active framework pack):
1. Any `target_files` path matches the pack's `auth_hints` or `authz_hints` globs.
2. A dependency manifest (package.json, composer.json, requirements/pyproject, go.mod, Cargo.toml, Gemfile) is in `target_files`.
3. `target_files` count ≥ 4.
4. The unit body mentions auth, session, token, crypto, password, payment, upload — or the authorization class: role, permission, access, admin, acl, approv- (approve/approval) — or the Indonesian equivalents the plugin's ID/EN surface already carries: kata sandi, sandi, pembayaran, unggah, hak akses, peran, izin, otorisasi, autentikasi, persetujuan (all case-insensitive, matched as WHOLE words — `approv-` is the sole deliberate prefix match; a substring inside a longer word never fires: "perancangan"/"perangkat" do not match peran, "accessibility" does not match access — otherwise every a11y-discussing UI unit would pay the full panel). S7-TIER-5: the old EN-only list had NO authz vocabulary and none of the plugin's second language — "Hanya manajer yang bisa menyetujui pengajuan" selected a tier with no security lens.
5. `binding_refs` cite a constitution §B (Security) clause.
6. The unit frontmatter carries `risk: high` or `risk: critical` (the producer-stamped field per `generate-units/references/unit-schema.md`) — this signal ALONE forces `full`; when it disagrees with signals 1–5 (e.g. `risk: critical` on a unit no other signal fires for), log the disagreement in the bolt-report.

**Override chain:** `--review-panel=minimal|standard|full|auto` CLI flag > `.mega-sdd/config.yaml` `review_panel:` > `auto` (the table above). A forced tier is logged in the bolt-report; forcing `minimal` on a unit with risk signals adds a one-line warning (never silent).

## Blind dispatch protocol

- **One message, N Agent calls** — all selected lenses dispatch concurrently from the main-thread controller. Depth-1 is preserved: the controller→agent shape is unchanged; the panel adds parallelism, not nesting.
- **Each lens prompt contains:** base/head commit SHAs + lens-specific context, plus a unit-body slice **sized to the lens**. The **spec lens gets the full unit body verbatim** — it is the lens that verifies Implementation-steps fidelity, Hard-rule honoring, and `target_files` coverage (the moat checks), so it must see everything. The **other lenses (security, standards, quality, design) get frontmatter + requirements + Hard rules + Anchors/Anti-patterns + Migration notes, but NOT the Implementation-steps NARRATIVE** — they judge the landed diff (security judges the actual authz/validation in the code, not the step prose describing it), so the step narrative is dead weight (~40–50% of a typical body) sent 4× per full-tier bolt attempt. **Migration notes STAYS in every lens** — on an `extend` unit its KEEP sub-list ("code to preserve, do not touch") is the authoritative preserve-intent for pre-existing controls that predate the unit and are therefore absent from its `binding_refs`/§B slice; the security lens's bypass-detection (a silently-dropped scope filter / middleware) is blind without it, and the list is only a few short lines (near-zero cost). Only the step narrative is trimmed. Lens-specific context is unchanged: security gets the constitution §B clauses + binding_refs + the active pack's `## Security idioms` slice; standards gets the pack naming/location/idiom slice + codebase-map conventions; quality gets the reuse-index path + reuse_candidates; design gets the design slice (vault design_system + style-principles slice + modern-baseline digest).
- **Each lens prompt NEVER contains:** the implementer's report or self-assessment, another lens's verdict, or any prior attempt's review. Blind review is the anti-rubber-stamp rail — do not "save tokens" by sharing context between lenses.
- **Each lens prompt DOES contain the L0 code-gate results** (`## Deterministic scan results`, per `code-gates.md`) — machine fact, not another lens's opinion, so blindness is intact. Lenses skip what machines already caught and judge what machines can't.
- Re-reviews after a re-dispatch are equally blind: the lens gets the new SHAs and the unit, not the history of what it flagged before. The re-review diff range keeps the ORIGINAL bolt base (base..new-head) — the lens judges the whole bolt, never just the fix commit — and its prompt carries the FRESH L0 results from the re-run gates (below), never attempt-1 scan output.

## Merge + severity gate

The controller (main thread) merges the lens reports:

1. **Evidence-or-drop** — a finding with no `file:line` anchor is discarded (mirrors the no-fabrication invariant). Log dropped count.
2. **Dedup** — same (file, overlapping lines, same issue class) across lenses → keep one entry at the MAX severity, note all reporting lenses.
3. **Consensus** — a finding reported by ≥2 lenses is marked `confidence: high` in the merged list.
4. **Gate:**
   - spec lens ❌ OR any **Critical** (any lens) → re-dispatch `bolt-implementer` with the merged issue list (the SHARED `--max-retries` cap — panel retries and spec retries draw from the same budget). **A re-dispatch RE-ENTERS the per-unit flow at the L0 code gates** (S7-GATES-2): the gates re-run over the SAME range the re-review judges — **ORIGINAL bolt base..new head**, never fix-commit-only (a narrower scan would drop attempt-1's non-blocking findings from the record while the re-review is forbidden from carrying attempt-1 output) — a fix commit that adds a dependency or pastes a credential must pass `validate-new-deps.sh` / `scan-secrets-code.sh` like any other commit ("always run" means every commit, not every first attempt) — and the re-review prompts carry the NEW L0 results.
   - Retries EXHAUSTED with a Critical still open **OR the spec lens still ❌** → **halt `review_critical_unresolved`** (terminal — the run stops; never proceed to the next bolt over an open Critical or an unmet requirement). Spec ❌ is definitionally must-fix per this gate's own re-dispatch rule — a missing/misread requirement carries no severity grade, so without this clause the exhausted-retries case fell through to "mergeable" (S7-PANEL-4). The halt YAML lives in `references/halt-recovery.md`; the unresolved finding is recorded in `bolt-report.md` `## Review panel`.
   - **Important** findings → recorded in `bolt-report.md` under `## Review panel`; the bolt is mergeable.
   - **Minor** → logged in the same section, no action required.
5. The merged findings are written into `bolt-report.md` `## Review panel` (lens list, tier used, finding table, dropped-no-evidence count) — a MANDATORY section of the canonical schema (`superpowers-bridge.md §bolt-report.md schema`). No separate artifact file.

The deterministic post-flight Hard-rule scan still runs AFTER the panel passes (both run against the implementer's already-landed commit — detect-after topology per SKILL.md) — the panel is judgment, the scan is the contract. Neither replaces the other.

## Cost notes

A full panel is ~4 fresh agent contexts per bolt attempt — multiples of a single-reviewer run. The tier table is the cost control: routine bolts pay for one lens, risky bolts pay for four. Tune per project via `review_panel:` in `.mega-sdd/config.yaml` (e.g., `full` for a payments service, `standard` for an internal tool). Per-lens models are frontmatter-pinned and NOT tunable via `model_tiers:` (see the pin note above).

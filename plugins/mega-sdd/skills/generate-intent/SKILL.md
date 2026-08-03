---
name: generate-intent
version: 2.15.1
description: Spec-driven intent generation — a PRD/BRD (+ Figma), a free-text brief (--from-prompt), or a KB (--kb) becomes a 7-file anti-hallucination vault; Mode A/B auto-detected; --scope selects one scope of a multi-scope PRD; every OQ tagged category + resolution_mode. Use when the user says "spec out this feature", "buat dev handoff", "break down this PRD for the dev team", "pecah PRD ini buat AI dev", "from this prompt", "from a brief", "rebuild from KB", or paraphrases.
---

# Grand Design Spec Generator (generate-intent)

Converts a PRD/BRD (+ Figma), a free-text brief, or a knowledge base into 7 markdown files inside a user-specified folder, optimized for **anti-hallucination dev handoff** — a downstream dev (human or AI) can implement from these docs without inventing requirements.

> **Skill instruction language:** this skill reasons in English. **Generated docs match the input language** — Indonesian PRD → Indonesian vault; English PRD → English vault. Chat prompts default to **Indonesian + English technical terms**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (full rules → `plugins/mega-sdd/references/output-language.md`).

## Anti-hallucination rails (THE MOAT — never relax)

> **Ground everything in the source (PRD / BRD / Figma / uploaded docs / KB). Do NOT invent.**
> **If it is not explicit in the source, it does NOT go in the body. It goes in Open Questions.**

This is the core rail and applies to every doc and to **section presence**, not just content within sections:

- **No fabrication.** No "industry best practice" insertions, no "probably they meant X" guesses, no filler. The source documents are the ONLY ground truth. If the source is silent, the answer is an Open Question — never Claude's prior knowledge.
- **Unknowns become Open Questions (OQs), never guesses.** Every ambiguity, contradiction, or gap is captured as a tagged, prioritized OQ. 50 honest OQs beats 5 fabricated answers.
- **Every claim traces to its source.** Each entity, field, endpoint, decision, flow step, and constraint cites the PRD section / Figma frame / uploaded file / KB anchor it came from. Out of Scope is always explicit (`TBD - confirm with PO` when genuinely unknown — never empty).
- **No defaulted standards.** WCAG levels, Material/Tailwind palettes, spacing scales, brand voice appear ONLY if a source explicitly contains them. Project shape is NOT a trigger; design-system sections appear only when a source supplies design-system content.
- **`--auto` never bypasses the rails.** Autonomous mode skips logistical prompts only — it must NEVER auto-answer OQs, invent field values, skip source citations, skip OQ tagging, or pretend a draft PRD is final. (Full `--auto` behavior → `references/auto-and-handoff.md`.)

These invariants hold in BOTH output modes (`compact` and `full`) and are re-asserted in the self-check before delivery.

## When to use this skill

Trigger for any of the following, **stated literally or paraphrased**:

- "Break down this PRD for the dev team" / "pecah PRD ini buat dev"
- "Spec out this feature" / "buat dev handoff"
- "Prepare context for AI-assisted dev" / "siapkan context buat AI dev"
- "Translate business requirements into architecture docs" / "Convert PRD + Figma into dev-ready specifications"
- "from this prompt" / "from a brief" / "baku dari ide" → Mode B (free-text)
- "I only have an idea, not a PRD" / "ide aja gue belum sempat PRD" → Mode B
- "rebuild from KB" / "pecah PRD ini buat AI dev" → KB sub-mode / Mode A as detected

Do NOT use to validate a vault against live code (`bind-codebase` / `detect-drift`), to evolve a vault from a revised PRD (`diff-vault`), or to resolve OQs (`resolve-oq`).

## Invocation modes (auto-detected — no flag required)

`generate-intent` has TWO input modes (Mode A structured, Mode B free-text), a KB sub-mode under Mode B, and a starterkit-aware overlay that applies to ALL modes when scan-codebase ran first.

- **Mode A — structured input (PRD / BRD / Figma).** `generate-intent ./prd.md`. Parse + decompose directly per `references/vault-contract.md`. No Q&A unless the source is critically incomplete.
- **Mode B — free-text brief.** `generate-intent --from-prompt "<brief>"` (or detected when no structured path is given). Runs adaptive Q&A (≤10 questions) to fill gaps, then produces a seed-PRD + vault in one pass. Procedure → `references/from-prompt-mode.md`.
- **Mode B (KB sub-mode) — `--kb=<path>`.** `generate-intent --kb=.mega-sdd/knowledge-base/`. Consumes an `extract-intelligence` knowledge base as a legacy-rebuild brief. KB is ANALYSIS INPUT, not a 1:1 spec: vault emphasizes reengineering goals + business intent; legacy detail surfaces only where the `[LOCKED]` tier requires 1:1 preservation. Full procedure (freshness preflight, tier-aware routing, ERD freedom, Q&A loop) → `references/kb-submode.md`.

All three modes share the SAME vault contract (`references/vault-contract.md`); only input parsing differs.

### Mode A / B detection rules (deterministic — no LLM judgment)

When the user invokes `generate-intent <arg>`, evaluate rules **in order; first match wins**:

| Rule | Match condition | Mode |
|---|---|---|
| 0 | `--kb=<path>` flag present | **B (KB sub-mode)** — explicit; positional and `--from-prompt` ignored |
| 1 | `--from-prompt` flag present | **B** — explicit override; positional ignored as a path |
| 2 | Positional arg resolves to an existing file on disk | **A** |
| 3 | Positional arg matches glob `*.md` / `*.pdf` / `*.docx` (whether or not it exists) | **A** — warn if file missing; offer to switch to B |
| 4 | Positional arg contains whitespace OR is quoted OR is longer than 80 chars | **B** (treat as brief) |
| 5 | Positional arg has no path separators (`/`, `\`) AND no recognized extension | **B** |
| 6 | No positional arg AND CWD has a KB README (priority: `.mega-sdd/knowledge-base/README.md` → `docs/knowledge-base/README.md` → `docs/mega-sdd/knowledge-base/README.md` → `old-reference/knowledge-base/README.md`) | **B (KB sub-mode)** — auto-detect, confirm with user |
| 7 | No positional arg AND no KB | CWD scan for `prd.md` / `seed-PRD.md` / `*.md` PRD candidates — at the ROOT plus one level inside dirs whose name case-insensitively matches `PRD`/`docs`/`documents`/`requirements` (the same set as derive-state's `probes.prd`; fixed set, never a repo walk). 1 hit → confirm Mode A; 0 or >1 → prompt user |

`--from-prompt` remains supported for explicit invocation; new users typically won't need it. When detection is ambiguous (Rule 3 with a missing file, Rule 6 with multiple candidates), **always confirm with the user**; detect silently only when high-confidence. **Announce any suppressed input:** whenever a higher-priority rule discards a lower-priority flag or positional (Rule 0 suppressing a co-present `--from-prompt`/positional; Rule 1 suppressing the positional), say so — "ignoring X because Y took precedence" — never drop a user's steering input silently. Edge cases (quoted single word, looks-like-path-but-missing, bare single word, flag+positional conflict) → `references/detection-and-shapes.md`.

## Flags

| Flag | Effect | Detail |
|---|---|---|
| `--from-prompt "<brief>"` | Force Mode B (free-text); explicit override of detection. | `references/from-prompt-mode.md` |
| `--kb=<path>` | Mode B KB sub-mode — consume an extract-intelligence knowledge base as the brief. | `references/kb-submode.md` |
| `--phase=N` | KB sub-mode only — scope vault generation to Phase N of `suggested-phasing.md`; writes `phase` + `phase_total` to `vault.json`; emits the §Phase context block in `00-index.md`. Default `--phase=1`; out-of-range → invocation-time error/halt. Non-KB modes are always `phase: 1, phase_total: 1`. | `references/kb-submode.md` |
| `--scope=<id>` | Select one scope (BE/MW/FE/custom id, or `all` for legacy single vault) of a multi-scope PRD. When the PRD has a `scopes:` block and the flag is unset, the interactive picker fires (Step 0.9). Invalid id → halt `scope_not_declared_in_prd`. | `references/setup-flow.md` |
| `--scan=<codebase-map-path>` | Starterkit overlay — read `codebase-map.md` before drafting so vault sections use dual-citation (Intent + Starterkit binding) per `vault-contract.md §Starterkit-binding`. Auto-applied when a codebase-map exists and `--greenfield` is unset (confirm first unless `--auto`). | `references/setup-flow.md` |
| `--greenfield` | Explicit opt-in for stack-agnostic generation — skips scan reading; vault stays generic. Required when no starterkit is present. | `references/setup-flow.md` |
| `--auto` | Skip logistical prompts (set by orchestrate-flow); emit a handoff YAML; participate in the memory layer. NEVER bypasses the anti-halu rails. | `references/auto-and-handoff.md` |
| `--no-pre-scan` | Skip Step 0.8 scan-aware context loading. | `references/setup-flow.md` |
| `--no-constitution` | Skip Step 3.4 (`constitution.md`) — 7-file vault only. | `references/setup-flow.md` |
| `--memory-off` | Disable memory-layer reads + writes. | `references/auto-and-handoff.md` |
| `--no-advisor` | Skip the phase-advisor adversarial pass before finalize. Default-on; still runs under `--auto` unless this flag is set. | `references/advisor-checklist.md` |

When BOTH `--scan` AND `--kb` are set (legacy-rebuild on a target scaffold): the vault synthesizes legacy domain intent (from the KB) with target scaffold conventions (from the scan). `[LOCKED]` KB items are preserved 1:1; `[INTENT]` items are rendered using starterkit conventions; `[ARTIFACT]` items are discarded.

## The 7-file vault output contract

Mode A/B/KB all emit the SAME canonical artifact set into the user-confirmed `<OUTPUT_DIR>`:

```
<OUTPUT_DIR>/
├── 00-index.md          ← Navigation + Vault Lock + Implementation Notes for AI Consumers + OQ roll-up
├── 01-overview.md       ← What, who, why, success criteria
├── 02-architecture.md   ← Components by layer (per PROJECT_SHAPE), API contracts
├── 03-data-model.md     ← Entities, relations, constraints (DBML preferred)
├── 04-flows.md          ← User + system flows (per-layer addressable) + per-flow Definition of Done
├── 05-decisions.md      ← ADR-style: context → decision → consequences
├── 06-constraints.md    ← Technical, business, non-functional
├── _meta/ai-consumer-guide.md ← static copy (script — `copy-consumer-guide.sh`; never model-rendered)
└── vault.json           ← Machine-readable manifest (script-derived — `derive-vault-json.sh`; markdown stays human-authoritative)
```

- `vault.json` is the canonical structured manifest AI consumers load for fast, reliable context without parsing prose. Schema, field rules, and regeneration triggers → `references/vault-contract.md §schema`. It is **script-derived via `scripts/derive-vault-json.sh`** — the script derives the structural arrays from the 7 markdown files, carries at-generation pins forward, merges the authored `--patch`, and holds the `vault.json.lock` itself (exit 4 → `memory_in_use` halt). Never hand-write vault.json.
- An 8th file, `constitution.md` (§A–§F project rules), is written at Step 3.4 unless `--no-constitution` is set → `references/vault-contract.md §constitution`.
- Multi-squad mode (≥2 squads) additionally emits `_meta/squads.yaml`, `interfaces/_index.md`, and `.obsidian/graph.json` → `references/setup-flow.md`.
- Multi-scope vaults tag `vault.json` with `scope` / `scope_metadata` / `prd_sha256` → `references/multi-scope.md`.

The per-file content guide (output-mode policy, readability standards, the `00-index.md` section order + Phase-context block, the mandatory `Sources` / `Out of Scope` / `Open Questions` template, and the operator-surface capture rules) lives in `references/generation-guide.md`.

## OQ classification (every OQ, every run)

Every Open Question is tagged at generation time with `category: business | tech` + `resolution_mode` + `classification_confidence`, using the auto-classifier heuristics in `references/vault-contract.md §Auto-classifier heuristics`:

- **`business`** OQs → `resolution_mode: blocking` (need a stakeholder decision).
- **`tech`** OQs → `scan` (resolvable from a codebase-map; needs `scan_query`), `recommend` (Claude proposes a pick; needs `recommendation` + `rationale` + `scan_citations` + `fallback_if_wrong` — **never fabricate citations**), or `blocking`.
- **Conservative default** when no pattern matches: `category: business`, `resolution_mode: blocking`, `classification_confidence: low` (preserves blocking behavior — safe).
- Only `high`-confidence tech OQs auto-resolve downstream in `bind-codebase`; `medium`/`low` are flagged for human review in the `00-index.md` `## Auto-Classification Review` section.
- **Memoization (re-runs / `--regenerate`):** when the vault already carries a classification for an OQ whose TEXT is unchanged (exact match against the existing `vault.json` entry), REUSE it verbatim — re-classify only new or text-changed OQs. A user override recorded in `classifier-accuracy.json` always wins over re-classification (never silently overwrite a human correction).

The classifier runs at Step 3.5 (after the 7 files, before the self-check) and writes the classification brackets/hints into the markdown body and the JSON-only fields (`scan_query`, `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`) into the authored patch consumed at Step 3.8 by `derive-vault-json.sh`, per `vault-contract.md §Updated OQ schema`. Validation gate + halts (`oq_tech_missing_mode`, `oq_recommend_underspecified`, `oq_scan_missing_query`) → `references/generation-guide.md`.

## Workflow skeleton

Run in order. Heavy detail for each step lives in the referenced files; the **existence and trigger** of every step stays here.

1. **Step 0–0.9 — Setup (MANDATORY before any generation).** Confirm + create `OUTPUT_DIR`; set `IMPLEMENTATION_MODE` (`new` | `existing`, with `mode_migrate_after` for new); set `PRD_STATUS` (`final` | `draft`); set `OUTPUT_MODE` (`compact` | `full`); squad partition (single vs ≥2); Step 0.8 scan-aware context loading (probe codebase-map / conventions / KB; auto-route to scan-codebase if accepted); Step 0.9 scope detection + PRD filtering (picker / retrofit bridge). Full procedures, runtime ordering note (0.8 runs before 0.9), the squad-partition Q&A, and the three scope halts → `references/setup-flow.md`.
2. **Step 1 — Inventory and read.** Locate inputs (sandbox `/mnt/user-data/uploads/` vs local CWD/ask); route each file to the right reader (PDF / DOCX / MD-TXT); for any Figma URL, load Figma MCP via `ToolSearch query:"figma"` — **if no MCP and no screenshots, ask before proceeding; never invent UI structure.** Read every input fully.
3. **Step 2 — Extract before writing.** Build an internal map (product, project shape, components, entities, flows, decisions, constraints, gaps, optional design-system flags `HAS_UI_COMPONENTS` / `HAS_TOKENS` / `HAS_A11Y` / `HAS_VOICE_BRAND`). Infer + **confirm `PROJECT_SHAPE`** with the user (Project Shape Registry → `references/detection-and-shapes.md`). Gap-handling depends on `PRD_STATUS`: `draft` may pause when gaps > 10; `final` never pauses — every gap goes to OQs.
4. **Step 3 — Generate the 7 files** into `<OUTPUT_DIR>`, per `references/generation-guide.md` (conditional design-system sections; operator-surface + Design-Source OQ rules). Then **Run** `bash $PLUGIN_ROOT/scripts/copy-consumer-guide.sh --vault <OUTPUT_DIR>` — installs the static `_meta/ai-consumer-guide.md` (script-copied, never model-rendered; `$PLUGIN_ROOT` per `references/generation-guide.md §Reading the templates`). Multi-squad artifacts if applicable. `vault.json` is NOT derived here — the single derive runs at Step 3.8, after constitution (3.4), classifier (3.5), and advisor (3.7) have produced the patch content.
5. **Step 3.4 — Write `constitution.md`** (§A–§F, every clause source-cited) unless `--no-constitution` → `references/vault-contract.md §constitution`.
6. **Step 3.5 — OQ auto-classification** on every generated OQ (see "OQ classification" above) → validation gate → `references/generation-guide.md`.
7. **Step 3.7 — Phase-advisor pass (adversarial second-opinion; default-on, `--no-advisor` skips).** Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (intent focus) + **the vault DIR path, the source file PATHS (PRD/brief/screenshot files/KB dir), the scope id + phase N/total when this is a `--scope`/`--phase` run, and the OQ roll-up counts** — **NOT the pasted file contents** (the claims, OQ text, and classification brackets are on disk after Step 3; the advisor has `Read`/`Grep`/`Glob` and opens the corpus itself — the dispatch is a SEED it expands past, never its horizon; this is the P7 slice-first cut on the intent leg, mirroring the bind leg's seed-not-horizon contract). **Pre-dispatch precondition (fail-closed): verify every named path resolves on disk.** An unresolvable source path → record `advisor: unavailable` (never clean) or fix the path and re-dispatch. **Figma frames loaded via MCP are NOT on disk and are unreadable by the advisor** — state `Figma: MCP-loaded, unreadable by you` in the seed instead of naming a path (uploaded screenshot FILES are real paths and stay in scope). Materialize its findings BEFORE finalize:
   - `fabrication` → demote the claim to an OQ (or flag) + Changelog note.
   - `missed_oq` → add an OQ to the roll-up (run it through the Step 3.5 classifier).
   - `misclassification` → retag the OQ `category`.
   - `coverage_gap` → add an OQ / flagged note.
   Evidenceless findings are dropped. Record the pass in `vault.json` provenance via the authored patch consumed at Step 3.8: `advisor: {model, findings:{high,med,low}}` OR `advisor: skipped` (`--no-advisor`) OR `advisor: unavailable` (agent error — NEVER reported as clean). Focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`.
8. **Step 3.8 — Derive `vault.json` (single derive; MANDATORY).** Assemble the **FULL authored patch** into a scratchpad temp file — metadata + `source_documents` + `design_system_flags` [+ `design_system`] [+ scope block] [+ `phase`/`phase_total`] + the per-OQ classifier records (Step 3.5) + the advisor provenance record (Step 3.7) — then **Run** `bash $PLUGIN_ROOT/scripts/derive-vault-json.sh --vault <OUTPUT_DIR> --patch <patch-file>` ONCE: the script derives the structural arrays from the 7 files, computes `constitution_hash` from the Step-3.4 `constitution.md` now on disk, and merges the authored patch — **never hand-write `vault.json`**.
9. **Step 4 — Self-check before delivery.** Full anti-halu + readability + output-mode + `vault.json` integrity checklist → `references/self-check.md`.
10. **Step 5 — Present.** Chat-only summary: doc + OQ counts, `PRD_STATUS`/`OUTPUT_MODE`, top blocker OQs, vault path, suggested next skill (`resolve-oq` / `detect-drift` / `diff-vault`). No "I have created…" preamble → `references/self-check.md`.

## Simplicity policy

**Default: as simple as possible** — each doc is the shortest version that still answers what its readers need; cut anything that doesn't earn its place. **Exception: `04-flows.md` may be reasonably complete** — flows describe step-by-step behavior with branching, error paths, and Definition of Done; completeness matters more than terseness there. Length follows content needed, not a target.

## When to push back on the user

Push-back is **conditional on `PRD_STATUS`** (full matrix → `references/self-check.md`).

- **Always (any PRD_STATUS):** Figma referenced but no MCP and no screenshots → ask, never invent UI. "Just guess the rest" → refuse politely; offer OQs instead (`final` does NOT license invention). Alien path for the environment → reject per Step 0. Output folder exists and non-empty → ask before overwriting.
- **Only when `PRD_STATUS=draft`:** missing critical sections, contradictory PRD, or gaps > 10 → pause and ask.
- **Only when `PRD_STATUS=final`:** never pause for those three; funnel missing sections / contradictions / large gaps into the OQ roll-up with full context (PRD quotes side-by-side).
- **Design-system absence is acceptable — no push-back.** Never prompt for a Figma/tokens/Storybook source, never default to industry standards, never emit placeholder OQs for missing design-system content.

## Halt conditions

All halts emit the unified `blocker` envelope (`plugins/mega-sdd/references/halt-protocol.md §halt-protocol`); under `--auto`, P1 business-blocking OQs additionally emit a blocker the orchestrator surfaces.

- **OQ classification (Step 3.5):** `oq_tech_missing_mode`, `oq_recommend_underspecified`, `oq_scan_missing_query`. (See `references/generation-guide.md` for the halt YAML.)
- **Scope detection (Step 0.9):** `scope_not_declared_in_prd`, `prd_no_scopes_block_user_rejected_retrofit`, `prd_retrofit_low_confidence` — all ALWAYS STOP CHAIN. (See `references/setup-flow.md` for the halt YAMLs.)
- **vault.json derive:** `memory_in_use` when `derive-vault-json.sh` exits 4 (the script holds and releases the `vault.json.lock` itself; exit 4 = lock held after backoff — surface the existing `memory_in_use` envelope, keterangan unchanged).

## Quality bar

Grounded (every non-trivial claim cites a source) · honest about gaps (OQs over guesses) · simple (except flows) · human-readable (reviewable by architect, PM, business owner, QA — not just AI consumers) · predictable structure · language match (output follows input language; code-level terms stay English).

## Specialist references (load on demand)

- **`references/vault-contract.md`** — the shared contract: `vault.json` §schema, §OQ-conventions, §Auto-classifier heuristics, §constitution, §Starterkit-binding, §stages-propagation, §Concurrency contract. The halt machinery (§halt-protocol — the full `blocker` envelope + halt-type roster — and §halt-escalation-discipline) lives in `plugins/mega-sdd/references/halt-protocol.md`.
- **`references/multi-scope.md`** — §Multi-scope vault scope-tagging schema (load when the PRD declares a `scopes:` block or `--scope=<id>` is passed).
- **`references/setup-flow.md`** — Steps 0–0.9: output-path resolution + environment checks, `IMPLEMENTATION_MODE` / `PRD_STATUS` / `OUTPUT_MODE` flags, squad partition + multi-squad emission, Step 0.8 scan-aware loading, Step 0.9 scope picker + retrofit bridge + the three scope halt YAMLs, and the `--scan` / `--greenfield` / `--scope` / `--no-pre-scan` / `--no-constitution` flag mechanics.
- **`references/kb-submode.md`** — Mode B KB sub-mode: freshness-snapshot preflight, the tier-aware routing table (`[VERIFIED]/[INFERRED]/[OPEN]` × `[LOCKED]/[INTENT]/[ARTIFACT]`), `--phase=N` parsing + phasing, ERD freedom, and the KB Q&A loop.
- **`references/from-prompt-mode.md`** — Mode B free-text: the adaptive ≤10-question walk and seed-PRD synthesis.
- **`references/detection-and-shapes.md`** — Mode A/B detection edge cases + the full Project Shape Registry (pre-templated shapes, custom fallback, inference rules).
- **`references/generation-guide.md`** — Step 3 file-by-file content guide, output-mode policy, readability standards, the `00-index.md` section order + Phase-context block, the mandatory section template + OQ tagging, operator-surface + Design-Source OQ capture, and the Step 3.5 classifier procedure + halt YAML.
- **`references/self-check.md`** — Step 4 self-check checklist, Step 5 present, and the full push-back matrix.
- **`references/auto-and-handoff.md`** — `--auto` behavior table + anti-halu carve-outs, handoff YAML, memory layer, and path resolution.
- **`references/scope-picker.md`** — scope filter logic + memory write rules (used by Step 0.9).
- **`references/legacy-retrofit-prompt.md`** — the AI subagent prompt for the legacy-PRD scope retrofit bridge.
- **`references/squad-partition.md`** — squad-declaration validation rules.
- **`references/templates/`** — scaffolds for each of the 7 files + `vault.json`, `squads.yaml`, `interfaces-index`, `obsidian-graph.json`. Read the relevant template before drafting.

## Related skills

Free-text/KB rebuild feeds `scan-codebase` → `bind-codebase` (brownfield) or `generate-units` (greenfield). Vault evolution from a revised PRD: `diff-vault`. OQ resolution: `resolve-oq`. Drift vs live code (after `mode=existing`): `detect-drift`. Knowledge-base production for the KB sub-mode: `extract-intelligence`.

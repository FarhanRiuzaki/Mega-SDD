---
name: diff-vault
version: 2.3.0
description: Evolves an existing mega-sdd vault when the PRD/BRD/Figma source changes. Computes a structured diff, preserves resolved OQs, flags conflicts where new source contradicts a resolved decision, and applies approved changes — without erasing history. Use when the user says "PRD updated", "vault diff", "regenerate vault from new PRD", "PRD versi baru", "new BRD revision", or paraphrases.
---

# Vault Diff — vault evolution across source revisions

Evolves an existing vault when the PRD/BRD/Figma source revises. The naive option ("delete vault, regenerate from scratch") loses every resolved OQ, every captured ADR rationale, and every Changelog entry built up through `resolve-oq` rounds. This skill keeps that history while updating the vault to reflect new source content. Findings land in a persistent `VAULT-DIFF.md` the user reviews; conflicts between vault state and new source always surface — the skill never silently overwrites.

> **Instruction language:** this skill reasons in English. Diff content (entity names, flow IDs, decision text) is recorded in the vault's existing language — same as the rest of the vault.

## When to use

Trigger when the user has an existing vault (from `generate-intent`) **and** an updated PRD/BRD that revises the source it was built from: "PRD updated", "vault diff", "regenerate vault from new PRD", "PRD versi baru", "new BRD revision". Also useful when the PRD was clarified by stakeholders post-generation (the new version answers prior Open Questions), or when a new Figma frame set / design-tokens file should update the vault's UI sections.

Do NOT use when: the vault doesn't exist yet (use `generate-intent`); the user just wants to walk Open Questions interactively without a new source (use `resolve-oq`); or the new "source" is the same content with cosmetic edits only (no semantic change — running the skill is wasted effort).

## Core principle

> **The vault has memory. PRD revisions update content; they do not delete history.**

Three things are preserved across every diff:

1. **OQ tag identity.** An OQ resolved in v1.1 stays resolved in v1.2 — even if the new PRD now says something different. The skill flags the conflict; it does NOT silently overwrite.
2. **Decision provenance.** ADRs in `05-decisions.md` retain their original `Source:` citation. If the new PRD supersedes a decision, the new ADR carries `Status: Supersedes D-XXX`, and the old ADR carries `Status: Superseded by D-YYY`.
3. **Changelog continuity.** Every prior Changelog entry stays. The diff session appends a new entry; it never rewrites prior entries.

## Diff outcome categories

Every diff item lands in one of these. The skill walks them in this order:

| Category | What it means | Default action | User input? |
|----------|---------------|----------------|-------------|
| **Auto-resolved OQ** | An `[ ]` open OQ is now answered explicitly in the new PRD. | Auto-resolve `[x]` with the new-PRD answer; cite §X.Y as source. | No — show summary to confirm. |
| **New OQ** | New PRD introduces a section/AC/flow creating ambiguity absent from the old PRD. | Append to the relevant doc's Open Questions with the next `OQ-{CODE}-{N}`. | No — show for awareness. |
| **Added entity / flow / decision** | New PRD adds content with no analog in the old PRD. | Append to the relevant doc per existing convention. | Yes — confirm placement & priority. |
| **Changed entity / flow / decision** | Same identifier, different content (new field, changed step, refined rationale). | Update in-place; preserve identifier. | Yes — review diff, confirm. |
| **Removed entity / flow / decision** | Old vault references something no longer in the new PRD. | Mark as removed (do NOT delete from history); annotate in Changelog. | Yes — removal vs out-of-scope vs missed-by-new-PRD. |
| **Resolved-OQ conflict** | An OQ resolved in a prior round (`[x]`) now has a different answer in the new PRD. | Surface inline; user decides keep / supersede / capture-both. | **Yes — always.** Never silently overwrite. |
| **Decision conflict** | An ADR in the vault contradicts new PRD §X.Y. | Surface inline; user decides supersede vs reformulate. | **Yes — always.** |
| **Unchanged** | Old vault content still accurate per new PRD. | No-op. | No. |

## Workflow

The skill never proceeds past Step 0 without verified inputs. Re-echo `VAULT_DIR` / `NEW_SOURCE_PATHS` / `DIFF_SCOPE` at the start of each major step.

**Step 0 — Inputs (MANDATORY).** Vault path (same auto-detection as `resolve-oq`; verify all 7 files exist + `00-index.md` has a Vault Lock Status section). New source path(s) — accept PDF / DOCX / MD / TXT; multiple allowed (e.g., new PRD + new tokens.json). Git safety check — run `git status` in the vault dir; if uncommitted, `AskUserQuestion` — question states the situation + consequence ("Vault dir punya uncommitted changes (<ringkas git status>). Diff-apply menulis 7 file + vault.json — tanpa commit, tidak ada rollback point."); options: `Yes, I'll commit first then re-invoke` **(recommended — commit-before-diff per the Hard rules)**, `No, proceed anyway` — perubahan tidak bisa di-revert via git, `Cancel`. Persist `VAULT_DIR` and `NEW_SOURCE_PATHS` as absolute paths.

**Step 0.5 — Diff scope (MANDATORY).** `full` (default — diff every doc; for significant revisions) | `oq-only` (only check whether open OQs are now answered; skip entity/flow/decision diff; fast pass for minor clarifications) | `specific-docs` (user lists docs, e.g. "just `04-flows.md` and `06-constraints.md`"). Persist `DIFF_SCOPE`. Echo the plan. **Scope honesty:** if the user picks `oq-only`, do NOT secretly diff entities/flows.

**Step 1 — Read both states.** Read the entire current vault (all 7 files). Read every new source fully (PDF → `pdf-reading` skill, DOCX → `docx` skill, etc.). Read the OLD source if available — ask once: *"Path to the old source the current vault was generated from? (optional — improves conflict detection)"*. Without it, the diff uses `vault state vs new source` rather than `old source vs new source vs vault`; both work, old source improves precision on which OQs were *already* gaps vs newly-introduced.

**Step 1.5 — PRD change detection.** When `vault.json` has a `prd_sha256` field, compute the sha256 of the current PRD at `vault.json.prd_path_at_generation` and compare; emit `prd_sha256_changed: yes | no | n/a` in the report header. If the recorded path no longer exists → **halt `prd_path_missing`** (ALWAYS STOP). Legacy vault (no `prd_sha256`) → skip gracefully with an advisory note. Full logic + the scope handoff block: `references/diff-procedure.md`.

**Step 2 — Re-extract from new source.** Run the same extraction logic as `generate-intent` Step 2 — build an internal model of the new source's components, entities, flows, decisions, constraints, gaps. Persist the four design-system flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) for the new source so design-system sections can also diff.

**Step 3 — Compute structured diff.** Per axis (entities, flows, decisions, OQs, constraints/overview/architecture, design-system), classify each item into the categories above. Resolved-OQ conflicts and Decision conflicts ALWAYS require user resolution. Removed flows get a `> **Removed in v{X.Y}**` banner — never deleted. Per-axis matching rules: `references/diff-procedure.md`.

**Step 4 — Generate `VAULT-DIFF.md`.** Write the structured diff report to `<VAULT_DIR>/VAULT-DIFF.md` (overwrites). Conflicts go in a PRIORITY-1 section at the top. This persistent artifact is what the user reviews offline. Full template + per-section examples: `references/report-format.md`.

**Step 5 — Interactive resolution walk-through.** Walk the report, **conflicts first**. Each conflict → `AskUserQuestion` with the report's options (Supersede / Keep vault / Capture both / Skip). Auto-resolved OQs → batch `["Apply all", "Review one-by-one", "Skip"]`. Added/Changed/Removed → batch where safe, one-by-one for substantive changes. New OQs → confirm priority. The user can stop anytime; partial decisions persist for the next run. Under `--auto`, conflicts emit a `diff_conflict` blocker instead — see below. Walkthrough detail: `references/report-format.md`.

**Step 6 — Apply approved changes.** `Edit` (preferred) or `Write` (large restructures) per category: auto-resolved OQs → `[x]` + resolution pointer; new OQs → append `[ ] **OQ-{CODE}-{N+1}**`; added → append per convention in the vault's existing `OUTPUT_MODE`; changed → in-place with a `> **Changed in v{X.Y}**` banner, IDs preserved; removed → annotate banner, content retained; conflicts (per user choice) → Supersede / Keep-vault / Capture-both. Exact apply rules per category: `references/diff-procedure.md`.

**Step 6.5 — Refresh `vault.json`.** After applying, **Run** `bash <plugin>/scripts/derive-vault-json.sh --vault <VAULT_DIR> --patch <sources-patch>` — the script re-derives the structural arrays from the now-updated markdown per `../generate-intent/references/vault-contract.md §schema`; the patch carries the replaced `source_documents` entry + updated `prd_sha256`/`prd_path_at_generation` when the PRD changed (the ONLY fields diff-vault still authors). The script holds the `vault.json.lock` itself (exit 4 → halt `memory_in_use`). Re-running against an unchanged source is a byte-identical no-op (`generated_at` preserved). Detail: `references/diff-procedure.md`.

**Step 7 — Update vault metadata.** Bump the vault version in `00-index.md` Vault Lock Status (patch = minor changes/no scope shift; minor = significant additions, e.g. new feature scope; skill suggests, user confirms). Append a Changelog entry (counts per category + conflicts resolved + source). Update `Last updated`. Update the PRD source reference (old → new; prior version moves into Changelog history). Changelog template: `references/diff-procedure.md`.

**Step 8 — Self-check before delivery:** every diff item ended in applied / user-skipped / deferred (nothing silently dropped); every conflict had explicit user input (no auto-supersede); every Removed item still exists with a `> **Removed in v{X.Y}**` banner (content not deleted); every Added entry follows the vault's `OUTPUT_MODE`; OQ identifiers still unique; vault version bumped + Changelog appended + `Last updated` set; `git status` run if available; `vault.json` regenerated and its arrays match the markdown; `open_questions_summary.total` equals the `00-index.md` roll-up count; `vault_version` equals Step 7's new version with `generated_at` updated; `source_documents[]` reflects the new PRD.

**Step 9 — Present summary:** total diff stats per category; new vault version `v{X.Y}`; conflicts deferred/skipped; path to `VAULT-DIFF.md`; suggested next step (run `resolve-oq` if new OQs were introduced). No "I have completed…" preamble.

## Hard rules (the rails)

- **No history erasure.** Every prior Changelog entry, resolved OQ, and ADR `Source:` citation persists across diffs. Identifiers are stable; Removed content is banner-annotated, never deleted.
- **No silent overwrites.** Any conflict between vault state and new source (Resolved-OQ conflict, Decision conflict) surfaces to the user. The skill never auto-decides — even under `--auto` it emits a `diff_conflict` blocker instead.
- **`prd_path_missing` → STOP.** If `vault.json.prd_path_at_generation` points to a non-existent file, halt; the user must restore the PRD or regenerate the vault. Holds under `--auto`.
- **`memory_in_use` on lock failure.** The derive script acquires the advisory lock itself; when it exits 4 (lock held after retries), halt with the existing `memory_in_use` envelope rather than risk a corrupt manifest.
- **Scope honesty.** `oq-only` does not secretly diff entities/flows. Scope is honored strictly.
- **Reversibility.** The skill assumes git is in use and encourages commit-before-diff for rollback. No git → warn, don't refuse.
- **Idempotency.** Re-running against an already-diffed (unchanged) source is a no-op beyond `Last updated` / the Changelog timestamp; the report regenerates but applying it changes nothing.

## When to push back

**Always:** vault doesn't exist (STOP → `generate-intent`); no new source provided (STOP, ask for the path — no diff makes sense without comparison input); vault is LOCKED per Vault Lock Status `Status: 🔒 LOCKED` (STOP → *"Diffing implies unlocking. Confirm: unlock and apply (re-sign-off required after), or cancel?"*); user says "auto-resolve all conflicts" (refuse — conflicts are exactly the cases needing human judgment; offer batch-confirm for non-conflict categories only); major scope shift (new project name differs significantly, >50% entities Removed, or >30% Added → *"This looks like a different project, not a revision. Sure this is the right source for this vault?"*); `vault.json.prd_path_at_generation` missing → halt `prd_path_missing`.

**Conditional:** old source not provided → use vault-state-as-baseline; surface the precision caveat once in Step 5. Multiple new sources conflict with each other → emit a conflict per `generate-intent` Step 2 source-merge rules; user resolves. Resolved-OQ conflict count > 5 → recommend a focused stakeholder session before applying (the team's prior decisions are under question).

## Specialist references (load on demand)

- **`references/diff-procedure.md`** — PRD change detection (`prd_sha256`), per-axis diff computation, apply mechanics (Step 6), `vault.json` refresh via `derive-vault-json.sh` + sources-patch (Step 6.5), vault metadata update (Step 7), and the `prd_path_missing` / `memory_in_use` halts.
- **`references/report-format.md`** — the full `VAULT-DIFF.md` template, per-section examples (conflicts, auto-resolved OQs, new OQs, added/changed/removed), and the Step 5 interactive walkthrough.
- **`references/auto-and-chain.md`** — `--auto` behavior table, what stays interactive, the `diff_conflict` blocker YAML (incl. the `OQ-FLOW-3-cap` change-cap variant), canonical diff via `jd`, and the handoff YAML (with the scope block).

## Related skills

Source must be a `mega-sdd` vault with the standard 7-file structure, Vault Lock Status, OQ tagging convention, and Changelog. OQ tagging conventions, status-marker semantics, and `vault.json` field rules + regeneration triggers: `../generate-intent/references/vault-contract.md` (§OQ-conventions, §schema). OQ resolution mechanics (how `[x]` markers + resolution pointers are formatted): `resolve-oq` SKILL.md. Initial vault generation: `generate-intent`. Vault-vs-live-code reconciliation (not source-vs-source): `detect-drift`.

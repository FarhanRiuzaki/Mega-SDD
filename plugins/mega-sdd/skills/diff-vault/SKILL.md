---
name: diff-vault
version: 2.5.0
description: Evolves an existing vault when its PRD/BRD/Figma source changes — structured diff, preserves resolved OQs, flags contradictions with resolved decisions. Also the delta lane's entry (--from-prompt) when the FRONT DOOR routes a ticket-scale change-request to it — that lane is propose-first and never auto-triggers off a bare code-edit sentence. Use when the user says "PRD updated", "vault diff", "regenerate vault from new PRD", "PRD versi baru", "new BRD revision", or paraphrases.
---

# Vault Diff — vault evolution across source revisions

Evolves an existing vault when the PRD/BRD/Figma source revises. The naive option ("delete vault, regenerate from scratch") loses every resolved OQ, every captured ADR rationale, and every Changelog entry built up through `resolve-oq` rounds. This skill keeps that history while updating the vault to reflect new source content. Findings land in a persistent `VAULT-DIFF.md` the user reviews; conflicts between vault state and new source always surface — the skill never silently overwrites.

> **Instruction language:** this skill reasons in English. Diff content (entity names, flow IDs, decision text) is recorded in the vault's existing language — same as the rest of the vault.

## When to use

Trigger when the user has an existing vault (from `generate-intent`) **and** an updated PRD/BRD that revises the source it was built from: "PRD updated", "vault diff", "regenerate vault from new PRD", "PRD versi baru", "new BRD revision". Also useful when the PRD was clarified by stakeholders post-generation (the new version answers prior Open Questions), or when a new Figma frame set / design-tokens file should update the vault's UI sections.

Do NOT use when: the vault doesn't exist yet (use `generate-intent`); the user just wants to walk Open Questions interactively without a new source (use `resolve-oq`); or the new "source" is the same content with cosmetic edits only (no semantic change — running the skill is wasted effort).

**Delta lane (`--from-prompt "<brief>"`)** — a ticket-scale chat requirement ("tambah kolom npwp di form nasabah") against an existing vault is a DELTA, not a new epic: the brief itself is the comparison input. The lane is propose-first (front door / explicit mega-sdd intent — never auto-triggered off a bare code-edit request) and converges into the existing scoped machinery: apply → `scripts/derive-delta-paths.sh` → claim-scoped re-bind → `generate-units --reconcile` → stale/new bolts. An epic hiding in a "delta" is forced out by the cap (halt `delta_too_large`, Step 3). Full contract: `references/diff-procedure.md §From-prompt delta lane`.

## Core principle

> **The vault has memory. PRD revisions update content; they do not delete history.**

Three things are preserved across every diff:

1. **OQ tag identity.** An OQ resolved in v1.1 stays resolved in v1.2 — even if the new PRD now says something different. The skill flags the conflict; it does NOT silently overwrite.
2. **Decision provenance.** ADRs in `vault.md ## Decisions` (legacy `05-decisions.md`) retain their original `Source:` citation. If the new PRD supersedes a decision, the new ADR carries `Status: Supersedes D-XXX`, and the old ADR carries `Status: Superseded by D-YYY`.
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

**Step 0 — Inputs (MANDATORY).** Vault path (same auto-detection as `resolve-oq`; verify the layout's files exist + the lock home is readable — vault.md frontmatter, legacy: 00-index.md Vault Lock Status). New source path(s) — accept PDF / DOCX / MD / TXT; multiple allowed (e.g., new PRD + new tokens.json) — OR `--from-prompt "<brief>"` (the chat brief IS the comparison input; no source file; mutually exclusive with source paths — both given → the file wins, warn once). Git safety check — run `git status` in the vault dir; if uncommitted, `AskUserQuestion` — question states the situation + consequence ("Vault dir punya uncommitted changes (<ringkas git status>). Diff-apply menulis file vault + vault.json — tanpa commit, tidak ada rollback point."); options: `Yes, I'll commit first then re-invoke` **(recommended — commit-before-diff per the Hard rules)**, `No, proceed anyway` — perubahan tidak bisa di-revert via git, `Cancel`. Persist `VAULT_DIR` and `NEW_SOURCE_PATHS` as absolute paths.

**Step 0.5 — Diff scope (MANDATORY).** `full` (default — diff every doc; for significant revisions) | `oq-only` (only check whether open OQs are now answered; skip entity/flow/decision diff; fast pass for minor clarifications) | `specific-docs` (user lists docs, e.g. "just `flows.md` and `constraints.md`"). Under `--from-prompt`, scope is AUTO-DERIVED `specific-docs` from the entities/flows the brief names (heading-match against the OQ surface — constraints.md `## Open Questions`; legacy: the 00-index roll-up; no match → the doc most plausibly owning the change + `model.md`) — NEVER `full` for a from-prompt run (a one-sentence ticket does not command a whole-vault read). Persist `DIFF_SCOPE`. Echo the plan. **Scope honesty:** if the user picks `oq-only`, do NOT secretly diff entities/flows.

**Step 1 — Read both states (read width follows `DIFF_SCOPE`).**

- `full` | `specific-docs` — read the entire current vault (all of its md files) and every new source fully (PDF → `pdf-reading` skill, DOCX → `docx` skill, etc.).
- `oq-only` — fast pass. Read ONLY: the authored OQ surface (constraints.md `## Open Questions`; legacy: the 00-index roll-up + per-doc OQ sections) and the new-source sections targeted by those open OQs (resolve each open OQ row's cited § / topic in the new source by heading match; no heading match → scan the source's heading outline once to locate the topic, never the whole document). Do NOT load the full vault or the full source under this scope — the read width matches the diff width (same Scope honesty rule as Step 0.5).

Read the OLD source if available — ask once: *"Path to the old source the current vault was generated from? (optional — improves conflict detection)"*. Without it, the diff uses `vault state vs new source` rather than `old source vs new source vs vault`; both work, old source improves precision on which OQs were *already* gaps vs newly-introduced.

**Step 1.5 — PRD change detection.** When `vault.json` has a `prd_sha256` field, compute the sha256 of the current PRD at `vault.json.prd_path_at_generation` and compare; emit `prd_sha256_changed: yes | no | n/a` in the report header. If the recorded path no longer exists → **halt `prd_path_missing`** (ALWAYS STOP). Legacy vault (no `prd_sha256`) → skip gracefully with an advisory note. Full logic + the scope handoff block: `references/diff-procedure.md`.

**Step 2 — Re-extract from new source (full | specific-docs; under `oq-only` skip this step — the OQ axis needs no full source model, only the targeted sections Step 1 read).** Run the same extraction logic as `generate-intent` Step 2 — build an internal model of the new source's components, entities, flows, decisions, constraints, gaps. Persist the four design-system flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) for the new source so design-system sections can also diff.

**Step 3 — Compute structured diff (full | specific-docs axes; under `oq-only` diff ONLY the OQ axis — answered/unanswered per the targeted reads).** Per axis (entities, flows, decisions, OQs, constraints/overview/architecture, design-system), classify each item into the categories above. Resolved-OQ conflicts and Decision conflicts ALWAYS require user resolution. Removed flows get a `> **Removed in v{X.Y}**` banner — never deleted. **From-prompt cap guard (BEFORE apply):** a from-prompt diff exceeding ANY of — new entities + new flows > 2, total changed rows > 12, any new scope/squad, or the major-scope-shift thresholds — halts `delta_too_large` (ALWAYS STOP; options full_lane / split_ticket / cancel with keterangan — envelope per `plugins/mega-sdd/references/halt-protocol.md`). Per-axis matching rules + cap detail: `references/diff-procedure.md`.

**Step 4 — Generate `VAULT-DIFF.md`.** Write the structured diff report to `<VAULT_DIR>/VAULT-DIFF.md` (overwrites). Conflicts go in a PRIORITY-1 section at the top. This persistent artifact is what the user reviews offline. Full template + per-section examples: `references/report-format.md`.

**Step 5 — Interactive resolution walk-through.** Walk the report, **conflicts first**. Each conflict → `AskUserQuestion` with the report's options (Supersede / Keep vault / Capture both / Skip). Auto-resolved OQs → batch `["Apply all", "Review one-by-one", "Skip"]`. Added/Changed/Removed → batch where safe, one-by-one for substantive changes. New OQs → confirm priority. The user can stop anytime; partial decisions persist for the next run. Under `--auto`, conflicts emit a `diff_conflict` blocker instead — see below. Walkthrough detail: `references/report-format.md`.

**Step 6 — Apply approved changes.** `Edit` (preferred) or `Write` (large restructures) per category: auto-resolved OQs → `[x]` + resolution pointer; new OQs → append `[ ] **OQ-{CODE}-{N+1}**`; added → append per convention in the vault's existing `OUTPUT_MODE`; changed → in-place with a `> **Changed in v{X.Y}**` banner, IDs preserved; removed → annotate banner, content retained; conflicts (per user choice) → Supersede / Keep-vault / Capture-both. Exact apply rules per category: `references/diff-procedure.md`.

**Step 6.5 — Refresh `vault.json`.** After applying, **Run** `bash <plugin>/scripts/derive-vault-json.sh --vault <VAULT_DIR> --patch <sources-patch>` — the script re-derives the structural arrays from the now-updated markdown per `../generate-intent/references/vault-contract.md §schema`; the patch carries the replaced `source_documents` entry + updated `prd_sha256`/`prd_path_at_generation` when the PRD changed (the ONLY fields diff-vault still authors). **Under `--from-prompt` the patch APPENDS a `type: brief` entry to `source_documents[]` instead of replacing the PRD entry, and `prd_sha256`/`prd_path_at_generation` are NOT re-baselined** (a chat ticket is not a PRD revision; the report header already carries `prd_sha256_changed: n/a`). The script holds the `vault.json.lock` itself (exit 4 → halt `memory_in_use`). Re-running against an unchanged source is a byte-identical no-op (`generated_at` preserved). Detail: `references/diff-procedure.md`.

**Step 7 — Update vault metadata.** Bump the vault version in the lock home (vault.md frontmatter; legacy: 00-index.md Vault Lock Status) (small bump vX.Y+1 = minor changes/no scope shift; scope bump vX+1.0 = significant additions, e.g. new feature scope; skill suggests, user confirms — grammar + tiebreak per `references/diff-procedure.md` §Update vault metadata, single owner). Append a Changelog entry (counts per category + conflicts resolved + source). Update `Last updated`. Update the PRD source reference (old → new; prior version moves into Changelog history). Changelog template: `references/diff-procedure.md`.

**Step 7.5 — Delta scope derivation (`--from-prompt` only).** **Run** `bash <plugin>/scripts/derive-delta-paths.sh --vault=<VAULT_DIR>` — touched VAULT-DIFF docs → affected claims' anchor paths → `<VAULT_DIR>/.delta-changed-paths.txt` (the `bind-codebase --paths=@file` consumer contract; deliberately NOT `.sync-changed-paths.txt` — different lane, different lifecycle). Exit 3 (no `binding.json` — unbound vault) → skip, the router proposes the normal chain; exit 2 → FAIL-CLOSED, the router proposes a FULL re-bind, never a guessed narrow one. File-lane runs skip this step.

**Step 8 — Self-check before delivery:** every diff item ended in applied / user-skipped / deferred (nothing silently dropped); every conflict had explicit user input (no auto-supersede); every Removed item still exists with a `> **Removed in v{X.Y}**` banner (content not deleted); every Added entry follows the vault's `OUTPUT_MODE`; OQ identifiers still unique; vault version bumped + Changelog appended + `Last updated` set; `git status` run if available; `vault.json` regenerated and its arrays match the markdown; `open_questions_summary.total` equals the authored OQ surface count (constraints.md; legacy: the 00-index roll-up); `vault_version` equals Step 7's new version with `generated_at` updated; `source_documents[]` reflects the new PRD.

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

**Always:** vault doesn't exist (STOP → `generate-intent`); no new source provided AND no `--from-prompt` brief (STOP, ask for the path — no diff makes sense without comparison input; under `--from-prompt` the brief IS the comparison input); vault is LOCKED per Vault Lock Status `Status: 🔒 LOCKED` (STOP → *"Diffing implies unlocking. Confirm: unlock and apply (re-sign-off required after), or cancel?"*); user says "auto-resolve all conflicts" (refuse — conflicts are exactly the cases needing human judgment; offer batch-confirm for non-conflict categories only); major scope shift (new project name differs significantly, >50% entities Removed, or >30% Added → *"This looks like a different project, not a revision. Sure this is the right source for this vault?"*); `vault.json.prd_path_at_generation` missing → halt `prd_path_missing`.

**Conditional:** old source not provided → use vault-state-as-baseline; surface the precision caveat once in Step 5. Multiple new sources conflict with each other → emit a conflict per `generate-intent` Step 2 source-merge rules; user resolves. Resolved-OQ conflict count > 5 → recommend a focused stakeholder session before applying (the team's prior decisions are under question).

## Specialist references (load on demand)

- **`references/diff-procedure.md`** — PRD change detection (`prd_sha256`), per-axis diff computation, apply mechanics (Step 6), `vault.json` refresh via `derive-vault-json.sh` + sources-patch (Step 6.5), vault metadata update (Step 7), the `prd_path_missing` / `memory_in_use` halts, and §From-prompt delta lane (brief extraction, ≤3 Q&A, cap guard, no-rebaseline provenance, Step 7.5 scope derivation).
- **`references/report-format.md`** — the full `VAULT-DIFF.md` template, per-section examples (conflicts, auto-resolved OQs, new OQs, added/changed/removed), and the Step 5 interactive walkthrough.
- **`references/auto-and-chain.md`** — `--auto` behavior table, what stays interactive, the `diff_conflict` blocker YAML (incl. the `OQ-FLOW-3-cap` change-cap variant), canonical diff via `jd`, and the handoff YAML (with the scope block).

## Related skills

Source must be a `mega-sdd` vault with the standard structure (layout-2 4-file or legacy 7-file), the lock values, OQ tagging convention, and Changelog. OQ tagging conventions, status-marker semantics, and `vault.json` field rules + regeneration triggers: `../generate-intent/references/vault-contract.md` (§OQ-conventions, §schema). OQ resolution mechanics (how `[x]` markers + resolution pointers are formatted): `resolve-oq` SKILL.md. Initial vault generation: `generate-intent`. Vault-vs-live-code reconciliation (not source-vs-source): `detect-drift`.

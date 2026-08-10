---
name: bind-codebase
version: 2.17.2
description: Validate a vault against codebase-map.md (+ KB secondary), producing binding.md with CONFIRMED / CONFLICT / OQ verdicts per claim + an Implementation State Map; BLOCKS unit generation while conflicts remain. Use when the user says "bind vault to code", "validate vault against repo", "cek vault vs codebase", "binding gate", or orchestrate-flow routes a brownfield vault here.
---

# Bind-Codebase

The brownfield anti-hallucination keystone. Refuses to let unit generation proceed against an ungrounded vault.

> **Non-interactive by contract (fork-ready).** This skill **NEVER calls `AskUserQuestion`** and never prompts on any path — the former `--auto` behavior is the *only* behavior. Inputs resolve deterministically from `$ARGUMENTS`/CWD (§Inputs **Step 0**); an unresolvable, ambiguous, or out-of-glob-root required input emits the `bind_inputs_missing` blocker, never a prompt. Conflict resolution — the KEEP_VAULT / KEEP_CODE / DEFER / SPLIT choice and any vault patch it implies — belongs to `resolve-oq`; bind writes verdicts and re-derives them on the next re-bind. This contract holds whether the body runs inline or as a forked subagent. The `context: fork` frontmatter flip is deliberately NOT taken yet: it is gated on the two interactive runs in `research/2026-07-30-fork-safety-audit-scan-bind.md §4` (Precondition 0 — the detect-drift token before/after per `plugins/mega-sdd/CLAUDE.md`; and the depth-2 `Agent` probe that the default-on Step 2.12 phase-advisor pass depends on).

**Announce at start:** "I'm using the bind-codebase skill to validate the vault against the codebase map."

> **Instruction language:** this skill reasons in English. Vault claim text, codebase anchors, paths, and line numbers are recorded verbatim from their sources. Narrate (the announce, halt keterangan, progress, summary) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`). *(A forked body never receives the SessionStart anchor that normally carries this policy, and this skill emits Indonesian keterangan of its own — so it carries the policy itself rather than relying on the anchor.)*

## When to use

- After `scan-codebase` produced `codebase-map.md` and a vault exists.
- `orchestrate-flow` auto-routes here for brownfield projects.
- Explicit: `bind-codebase <vault> [<codebase-map>]`.

## Inputs

- **Vault path** (positional, required) — the 7-file vault directory.
- **Codebase map** (optional; probe order `.mega-sdd/codebase/codebase-map.md` → `<repo-root>/codebase-map.md` → `./codebase-map.md`).
- **Knowledge base** (optional; probe `.mega-sdd/knowledge-base/` → `docs/knowledge-base/` → `docs/mega-sdd/knowledge-base/` → `old-reference/knowledge-base/`, first hit wins; override `--kb=<path>`).
- **Flags:** `--strict` (block on OQ too, not just CONFLICT), `--auto`, `--kb=<path>`, `--no-kb`, `--no-framework-pack`, `--framework-pack=<custom-path>`, `--strict-constitution`, `--no-advisor` (skip the phase-advisor pass; the advisor is default-on and still runs under `--auto` unless this flag is set), `--memory-off` (disable memory-layer reads and writes per `references/auto-memory-handoff.md`), `--paths=<csv|@file>` (claim-scoped re-bind for the sync lane — re-verdict ONLY claims whose anchors or vault sections intersect the changed paths; everything else carried forward per `references/binding-contract.md §Claim-scoped re-bind`; **active CONFLICTs are ALWAYS re-validated, never carried silently** — the gate sees the full verdict set either way), `--express` (claim-scoped retrieval lane: claims enumerate from the script-derived `claims-ledger.json` skeleton PLUS a mandatory model completeness sweep of the vault docs — the ledger is never the claim boundary — and evidence comes from symbol-index queries + targeted source Reads with ZERO codebase-map load; the verdict grammar, the CONFLICT gate, and Steps 2.5–2.12 are unchanged — full procedure, fail-closed ladder, and honest-fallback rules → `references/express-bind.md`).

**Step 0 — Vault resolution (MANDATORY, deterministic — NEVER ask).** Resolve `VAULT_DIR` in this exact order. A prompt is not an option on any branch, so an unresolvable OR ambiguous vault emits the `bind_inputs_missing` blocker (YAML shape → `references/auto-memory-handoff.md`) and the bind stops — never `vaults[0]`, never a guess, never a question.

1. **`--vault=<path>`, else the first positional arg** — highest precedence. The chain always pre-resolves this on the main thread (`orchestrate-flow/references/handoff-contract.md` renders `mega-sdd:bind-codebase <vault> --auto`), so branches 2–3 are reached only on a standalone invocation.
2. **`bash <plugin>/scripts/derive-state.sh --cwd=<project-root> --json-only`** → from that payload read **`probes.vaults[]`**, keep ONLY entries whose `path` is a DIRECT CHILD of `<project-root>/.mega-sdd/vaults/` (one level down — the glob-root constraint below), and THEN count. Exactly 1 surviving candidate → adopt it (this is the same path the payload reports as **`derived.vault_path`**; `derived.vault` is the vault NAME, not a path, and `derived.vault_path` on its own is `_primary_vault` = `vaults[0]` — first-hit-wins is fine for a status digest and NOT for the moat keystone's input, so filter-then-count is what decides). >1 → `bind_inputs_missing` (`reason: vault_ambiguous`) listing every candidate path. Filter-BEFORE-count matters: one canonical vault plus one legacy `docs/mega-sdd/vaults/` vault is one valid candidate, not an ambiguity. A non-zero exit or unparseable stdout is NOT ambiguity — derive-state is a read-only inspection surface that never blocks; fall through to (3).
3. **CWD probe** — a directory holding all 7 standard vault files (`00-index.md` … `06-constraints.md`), searched ONE level below the same `.mega-sdd/vaults/` root (a non-recursive `vaults/*/` sweep, matching what the gate globs — do not recurse deeper looking for a match the validator could never see). >1 hit → `bind_inputs_missing` (`reason: vault_ambiguous`) with the candidate list; 0 hits → `bind_inputs_missing` (`reason: not_found`).

**Glob-root constraint — applies to all three channels.** The resolved `VAULT_DIR` MUST be a **DIRECT CHILD** of `<project-root>/.mega-sdd/vaults/` — exactly one level down, i.e. `.mega-sdd/vaults/<slug>/` (`plugins/mega-sdd/references/paths.md`). "Somewhere under `.mega-sdd/vaults/`" is NOT the test and is too loose: a deeper nest such as `.mega-sdd/vaults/<group>/<slug>/` is *under* the root and still invisible. Anything that is not a direct child → `bind_inputs_missing` (`reason: vault_outside_glob_root`, `next_action` = run `/mega-sdd:migrate-paths` to move the legacy or nested layout onto the canonical one). An explicit `--vault=`/positional does NOT bypass this — precedence decides *which* candidate wins, never *whether* the gate can see the result. This is a moat-visibility rail: `binding.md` is written under `<vault>/`, and `scripts/validate-handoff-binding-units.sh` scans four **non-recursive** globs rooted at `<cwd>/.mega-sdd/vaults/` — `vaults/binding.md`, `vaults/binding-*.md`, `vaults/*/binding.md`, `vaults/*/binding-*.md` — whose deepest reach is that single `*` level, so a `binding.md` any deeper (or anywhere outside) is invisible to the validator and the gate reports PASS while an active CONFLICT exists.

**Why Step 0 exists — do not "simplify" it away as redundant.** A *missing* vault is already hook-blocked deterministically (`scripts/validate-preflight.sh` FATAL `binding_input_vault_missing` → `hooks/pre-tool-use` `emit_block`). Step 0 closes what that hook does not see: **ambiguity** (>1 vault under the root with no positional arg — the hook's `has_vault()` passes) and **location** (a vault that is not a direct child of the glob root — outside it, or nested a level too deep inside it). Both fail silently — the first binds an unintended vault, the second blinds the CONFLICT gate.

## Outputs

- `binding.md` — always written, even when blocking.
- `<vault>/bound/` (nested in the vault dir, beside `units/` and `bolts/` per `plugins/mega-sdd/references/paths.md`) — written ONLY when no CONFLICTs (or `--strict` and no OQs); derived by `scripts/make-bound.sh` from the vault docs + `binding.json` — never typed out by the model.

## Procedure

**1. Load inputs.** `VAULT_DIR` is already resolved by §Inputs **Step 0** — use it as-is; never re-resolve or widen it here. **`--express` set → this step and Step 2's retrieval are replaced by `references/express-bind.md`** (ledger + symbol-index + targeted Reads, zero map load; falls back HERE loudly when the index or ledger is unavailable) — Steps 2.5–2.12 and 3–6 then continue below unchanged. Otherwise (standard lane): read the vault files (`00-index` … `vault.json`) + `codebase-map.md`. If the codebase-map is missing → halt, emitting `bind_inputs_missing` (`missing: codebase_map`) whose `next_action` instructs the user to run `scan-codebase` first (shape → `references/auto-memory-handoff.md`). Reuse the codebase-map shared snapshot as a freshness attestation — `snapshot-verified` requires BOTH the sha256 match AND the map's `last_scanned_commit` == current HEAD (the sha256 alone proves the map file is unchanged, not that the code hasn't moved); a HEAD mismatch → `snapshot-stale` + a warning to run `/mega-sdd:sync` first. **External-map provenance check:** also read `.mega-sdd/.codebase-map-state.json` (written by `validate-codebase-map.sh`); if it records `status: FAIL` or a `codebase_map_fm_missing` issue (an externally-authored map without writer-provenance frontmatter), the bind PROCEEDS but WARN with keterangan: "peta codebase ini ditulis di luar mega-sdd (frontmatter provenance hilang/invalid) — presisi binding turun ke klasifikasi biner; jalankan scan-codebase untuk map ber-provenance" and record `binding_metadata.codebase_map_provenance: "unverified-external"` — NEVER `"snapshot-verified"` for such a map. Propagate `scope_metadata` when the vault is scoped. When a KB is present (legacy-rebuild lane), run the advisory **extraction-scorecard preflight** before processing KB claims so binding builds on extraction whose gaps are visible. Detail for snapshot reuse, scope propagation, and the scorecard preflight → `references/auto-memory-handoff.md`.

**2. Per claim, produce a verdict** (per `references/binding-contract.md`). **This is the moat:**

- **Project constitution gate (multi-PRD lifecycle).** Before binding a NEW vault's claims, read `.mega-sdd/constitution.md` (project-scope locked rules inherited by every vault, per `plugins/mega-sdd/references/multi-prd-lifecycle.md`) if present. Any vault claim that contradicts a project-locked clause (e.g. a new PRD proposes a different datastore than the project locks) is a **CONFLICT** at this gate — surfaced, never silently accepted. This is what keeps PRD 2..N inline with PRD 1's shipped decisions. Absent file = no project-scope layer = unchanged behavior.
- Primary ground truth = the codebase-map. Search it for matching evidence:
  - Exact match (file path + signature) → **CONFIRMED**.
  - Found but contradicts → **CONFLICT** (NEVER overridden by KB — codebase-map wins for conflicts).
  - Not found → consult the KB (secondary ground truth), if present.
- **KB consultation fires ONLY when the codebase-map is silent** (skip if `--no-kb`). Marker-aware, dual-axis (mutability-tier) verdicts:
  - `[VERIFIED][LOCKED]` → CONFIRMED + `mutability_source: kb_locked` (CONFLICT severity HIGH if code diverges — 1:1 preservation required by regulatory/contractual lock).
  - `[VERIFIED][INTENT]` → CONFIRMED + `kb_intent` (CONFLICT severity MEDIUM — rebuild has design freedom).
  - `[VERIFIED][ARTIFACT]` → CONFIRMED-with-discard-recommendation + `kb_artifact`.
  - `[INFERRED]` → CONFIRMED with note; `[OPEN]` → **OQ**; no KB match → **OQ** (no auto-resolve attempted).
  - Pre-tier KBs (no markers) → treat as `[INTENT]` for back-compat.
- **Never override a codebase-map CONFLICT via the KB.** The KB is consulted only when the codebase-map is silent — this preserves the gate's primary contract.

**2.5–2.11 — per-claim enrichment.** Each step annotates verdicts; **none relaxes the gate** (CONFLICT still blocks). Full procedures, examples, anti-hallucination rails, and halt YAMLs live in the referenced files:

- **2.5 Implementation-state classification** → `IMPLEMENTED / NEW / UNKNOWN / PARTIAL_FIELDS_*` via deterministic field-level diff (vault field-set V vs code field-set C; requires `precision_tier: ast`, regex falls back to binary). Defaults to `UNKNOWN`/low when undecidable; never marks `IMPLEMENTED` without a concrete anchor. → `references/implementation-state.md`.
- **2.6 Tech-OQ auto-resolution (scan)** + **2.7 recommendation surfacing** → scan auto-resolves only at `classification_confidence: high`; recommendation surfacing fires at `high`/`medium` (advisory, never blocks); skipped OQs pass through UNCHANGED (`resolution_mode` never mutated on confidence grounds); a scan with no match or multiple matches flips the OQ to `blocking` (never guesses); recommendations never auto-accept and require citations that resolve in the codebase-map/KB. → `references/oq-resolution.md`.
- **2.8 Framework-convention pack load** + **2.9 Suggested Unit Hard Rules** → packs from `plugins/mega-sdd/references/framework-conventions/`; a rule is promoted to a machine-validated Hard Rule ONLY when its KB marker is `[VERIFIED]` and it is mechanically detectable + anchored in the codebase-map, otherwise it becomes an informational Anti-pattern. → `references/hard-rules-and-packs.md`.
- **2.10 Constitution-aware CONFLICT surfacing** → cite constitution §A–F clauses on relevant conflicts; `--strict-constitution` raises `bind_conflict_constitution_violation`; persist `constitution_hash` for `detect-drift`. → `references/constitution-and-oq.md`.
- **2.11 Deferred-OQ auto-resolution** → high-confidence codebase-map evidence resolves `defer_to: binding` OQs; ambiguous/no match → stays `deferred`; never write an evidence string that is not actually in the codebase-map. → `references/oq-resolution.md`.

**2.12 — Phase-advisor pass (adversarial second-opinion; default-on, `--no-advisor` skips).** First **Run** `bash <plugin>/scripts/build-advisor-bundle.sh --vault <vault>` to derive `<vault>/.advisor-bundle.md` — the compact SEED (draft verdict+anchor set + the map/vault/KB **paths** + the map's sha256 + the expansion contract). Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus) + **the bundle path + the codebase-map / vault / KB PATHS** — **NOT** the pasted file contents. The advisor has `Read`/`Grep`/`Glob`: it opens each cited anchor and **Greps the full on-disk codebase-map** for `missed_match` (evidence outside the bundle is in scope — the bundle is a seed, never the advisor's horizon; this is the P7 slice-first token cut — the whole-map paste into a FRESH subagent was the top real-dollar lever, `research/2026-07-19-p7-seed-budget-baseline.md`). Materialize its findings INTO the verdict set BEFORE Step 3 so they are counted + written as canonical `### CONFLICT-NNN` headings in Step 4 (the exact token the Step 5 gate AND `validate-handoff-binding-units.sh` → `.validation-blockers.json` read):
- `false_confirmed`/`missed_match` confidence HIGH → add a real CONFLICT verdict (canonical `CONFLICT-NNN`, or the template-blessed `CONFLICT-ADV-N` advisor form — both are read by the gate + validators; tagged `source: advisor`). This is fail-safe blocking — a suspected hole in the moat closes the gate until a human clears it via `resolve-oq`.
- same, confidence MED/LOW → add an OQ (non-blocking, surfaced).
- `false_conflict`/`state_map_error` → FLAG ONLY in `binding.md`; the advisor may ADD a blocker autonomously but may NEVER auto-remove or auto-downgrade a CONFLICT (downgrade is human-only — invariant #2).
- Evidenceless findings are dropped. Record the pass in the Step 6 audit log: `advisor: {model, findings: {high,med,low}}` OR `advisor: skipped` (`--no-advisor`) OR `advisor: unavailable` (agent error — NEVER reported as clean). Full focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`.

**3. Aggregate counts.** `claims_total`, `confirmed`, `conflict`, `oq`.

**4. Write `binding.md`** using the template in `references/binding-md-template.md` (Summary · Confirmed Claims · Implementation State Map · Tech-OQ Auto-Resolved · Tech-OQ Recommendations · Suggested Unit Hard Rules · Conflicts [BLOCKING] · Open Questions · Auto-Resolved Deferred OQs). The model writes NO banner and NO enum legend — both are stamped by the Step 4.5 script. Conflicts render as `### CONFLICT-N` detail blocks ONLY (each opening with its `- **Vault claim**:` / `- **Codebase reality**:` pair) — the machine-read form is the only form; there is no summary table. The frontmatter's `binding_metadata` block carries `codebase_map_provenance` (Step 1) AND `head` — the current `git rev-parse HEAD` (or `null` outside git), written ONCE here; Step 4.5 copies both into `binding.json` verbatim. State Map rows whose state comes from a truncation/heuristic condition end their Anchor cell with the `[reason: <enum>]` token (S4 — `truncated_section` is mandatory when the truncation exception fired; generate-units keys its direct-probe rule on the derived `state_reason`), and RESOLVED `### CONFLICT-N` blocks carry their `- **Claim**: C-NNN` line — both per the template grammar.

**4.5. Stamp boilerplate, then derive `binding.json`** (structured State Map sidecar; schema → `references/binding-json-schema.md`).
**Run** `scripts/stamp-binding-boilerplate.sh --vault <vault>` FIRST — injects the
do-not-hand-edit banner + the keterangan enum legend into `binding.md` (static,
idempotent, parser-invisible — the legend gloss text single-sources in that
script; the model never types either block). THEN
**Run** `scripts/derive-binding-json.sh --vault <vault>` — deterministic
generator: `binding.json` is derived FROM `binding.md` (never hand-written —
the State Map rows, Confirmed Claims list, CONFLICT blocks, and
`binding_metadata` frontmatter you wrote in Step 4 are the single source of
truth; `[reason: <enum>]` Anchor tokens become `state_reason`, RESOLVED
blocks' Claim lines become `resolution`). This is part of the binding write —
run it whether the bind is clean or blocked. Exit 2 = the artifact does not
match the mega-sdd grammar. When mega-sdd wrote `binding.md` this run: fix the Step-4
`binding.md` write and re-run — an authoring bug, not a halt (do NOT emit a
halt YAML for this). When `binding.md` was authored EXTERNALLY (hand/foreign
tool): itu bukan bug — grammar-nya memang belum diadopsi (binding adalah artefak
mid-pipeline yang di-derive, bukan rung adopsi `certify-artifact`); perbaiki manual
mengikuti `references/binding-md-template.md`, atau re-generate via pipeline (re-bind).

**5. Decision gate — non-negotiable:**

- If `conflict == 0` AND (`oq == 0` OR `--strict` not set): **produce `<vault>/bound/`** by **Running** `scripts/make-bound.sh --vault <vault>` (append `--strict` when the flag is set) — the deterministic deriver: it re-checks binding.md↔binding.json parity, REFUSES (exit 2) while any CONFLICT verdict exists, then copies the vault docs into `bound/`, injects the `<!-- BIND: -->` annotations from binding.json `vault_source` cells, and mirrors `binding.md`. NEVER hand-write bound/ files — a non-zero exit means fix the bind write, not bypass the script. Announce clean + next step `generate-units <vault>/`.
- If `conflict > 0` OR (`--strict` AND `oq > 0`): **DO NOT write `<vault>/bound/`.** (make-bound.sh independently refuses while any CONFLICT verdict is in binding.json — never work around it by hand-writing files.) Announce the blocker, emit the `bind_conflict` halt YAML (below), route to `resolve-oq`. Per-conflict recovery (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT) and the bind ↔ resolve-oq sequence → `references/conflict-resolution.md`.

```yaml
blocker:
  type: bind_conflict
  emitted_at: <ISO8601 timestamp>
  emitted_by: bind-codebase
  details:
    vault: <vault path>
    conflict_count: N
    conflicts:
      - id: CONFLICT-1   # canonical conflict-ID form (the token the gate + validators read); C-NNN is the CLAIM-ID namespace
        vault_claim: <verbatim from the ### CONFLICT-N detail block's `- **Vault claim**:` line>
        codebase_reality: <verbatim from the detail block's `- **Codebase reality**:` line (incl. the evidence anchor)>
        suggested_action: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT
  next_action: "Run resolve-oq --binding <binding.md>"
```

This YAML is the canonical halt artifact (for orchestrate-flow consumption); the prose announcement is for human readability.

**6. Audit log.** **Run** `bash <plugin>/scripts/derive-vault-json.sh --vault <vault> --event '{"event":"bind","at":"<iso>","binding":"binding.md","summary":"<claims/confirmed/conflict counts>"}'` — the script appends the `bind` event to the vault.json changelog under its own `vault.json.lock` (exit 4 → `memory_in_use` halt); never hand-edit vault.json. → `references/auto-memory-handoff.md`.

## Anti-hallucination rails

- **Non-interactive (fork-ready).** NEVER calls `AskUserQuestion` and never prompts. Inputs resolve from `$ARGUMENTS`/CWD; an unresolvable, ambiguous, or out-of-glob-root input emits `bind_inputs_missing` (never a prompt). Conflict resolution belongs to `resolve-oq`, not bind: bind never asks the user to choose KEEP_VAULT / KEEP_CODE / DEFER / SPLIT and never patches the vault — it re-derives verdicts on the next re-bind.
- Never auto-resolve CONFLICTs — always human-in-the-loop.
- Never write the bound-vault while conflicts exist — the gate is non-negotiable.
- Ambiguous evidence → OQ, not CONFIRMED.
- `binding.md` claim text is verbatim from the vault — no paraphrasing.
- Implementation-state defaults to `UNKNOWN`/low when undecidable; never silently `IMPLEMENTED` without a concrete anchor. State classification **annotates** CONFIRMED claims — it does NOT relax the gate; CONFLICT still blocks.
- Tech-OQ scan resolution fires only at `classification_confidence: high`; no/multiple matches → flip to `blocking`, never guess.
- Tech-OQ recommendations never auto-accept; unverifiable citations → halt `oq_recommend_citation_invalid`.
- Suggested Hard Rules are promoted only from KB `[VERIFIED]` markers and only when anchored in the codebase-map; `[INFERRED]`/`[OPEN]` items → Anti-patterns only.

## Halt conditions

Vault unresolvable / ambiguous / not a direct child of `.mega-sdd/vaults/` → `bind_inputs_missing` (`missing: vault`; §Inputs Step 0). Missing `codebase-map.md` → `bind_inputs_missing` (`missing: codebase_map`, `next_action` = run `scan-codebase` first) — **classic lane only; unreachable under `--express`** (the default spine reads no map — `references/express-bind.md`). Vault missing or malformed `00-index`/`vault.json` → `bind_inputs_missing` (`missing: vault_index`, `reason: malformed`, `next_action` = repair the vault). `claims_total == 0` → **not an error and not a halt**: this is the greenfield path. Write `binding.md` as usual with `claims_total: 0` in its `## Summary` plus a one-line keterangan that the vault carries no bindable claims (binding skipped, bukan kegagalan), and emit `status: completed` whose `rationale` names the skip — the record must be on disk and in the handoff, never chat-only, so the chain reads a deliberate skip rather than a silent no-op. Tech-OQ `recommend` missing required fields → `oq_recommend_underspecified`. Recommendation `scan_citations` don't resolve → `oq_recommend_citation_invalid`. `--strict-constitution` + code violates a clause → `bind_conflict_constitution_violation`. Framework pack declared but missing / cyclic `extends:` / unparseable → `framework_pack_missing` / `framework_pack_cycle` / `framework_pack_unparseable`. Full halt YAMLs in the per-step refs.

## Hand-off

Clean binding → `generate-units <vault>/` (the bound-vault is the nested `<vault>/bound/`). Blocked → `resolve-oq --binding <binding.md>`. Emit the handoff YAML — with conditional `scope:` / `mutability:` / `constitution:` blocks — on **every** invocation, chain (`--auto`, typically `orchestrate-flow --deep` / `/mega-sdd`) *and* standalone. It is NOT `--auto`-gated: a direct `bind-codebase <vault>` run never injects `--auto`, and this skill is non-interactive, so the handoff is the only channel by which the caller receives `next_action` / `artifacts[]` / `blockers[]` — gating it would leave a `bind_conflict` or Step-0 `bind_inputs_missing` stop routed nowhere on exactly the lane that has no chain to fall back on. Also participate in the memory layer. Both → `references/auto-memory-handoff.md`.

## Specialist references (load on demand)

- `references/binding-contract.md` — verdict types, blocking rules, `binding.md` schema, bound-vault annotation format.
- `references/implementation-state.md` — Step 2.5 classification, field-level diff, worked example, anti-halu rails.
- `references/oq-resolution.md` — Steps 2.6 / 2.7 / 2.11 (tech-OQ scan, recommendations, deferred-OQ auto-resolution).
- `references/hard-rules-and-packs.md` — Steps 2.8 / 2.9 (framework packs + Suggested Unit Hard Rules emission).
- `references/constitution-and-oq.md` — Step 2.10 constitution-aware conflicts + `bind_conflict_constitution_violation` halt YAML.
- `references/binding-md-template.md` — the full `binding.md` output template.
- `references/auto-memory-handoff.md` — extraction-scorecard preflight, snapshot reuse, scope propagation, handoff YAML, memory layer.
- `references/conflict-resolution.md` — per-conflict-type recovery + the bind ↔ resolve-oq interaction.
- `references/express-bind.md` — the `--express` claim-scoped retrieval lane (ledger + index + targeted Reads, zero map load, fail-closed ladder, honest fallback).
- `references/handoff-validation.md` — the manual binding→units handoff-integrity surface (`validate-handoff-binding-units.sh`): drop types + per-type resolution; relocated from `commands/validate-handoff.md` in the surface cull.

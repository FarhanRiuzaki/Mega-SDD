# Phase B Enforcement Classification — 2026-05-27

## Purpose

Reviewer audit gate BEFORE Phase B coding starts. The 22 C1 main candidates + 3 quality_gate subtypes are NOT homogeneous — they emit from different points in the chain. SessionStart-guard pattern (proven for Phase A slices 1-4) covers ONLY precondition-state halts. Mid-chain halts need a different surface or genuinely have no hook-enforceable surface.

Per reviewer 2026-05-27 design requirement: "Tandai tiap dari 22 sebagai [SessionStart-guard] / [PostToolUse-validate] / [neither]. Yang [neither] jangan dipaksa jadi prose — itu persis pola gagal."

## Three enforcement patterns

| Pattern | When applicable | Proven slice |
|---|---|---|
| **[SessionStart-guard]** | Precondition-state check at session start. File content / config validity / dependency presence. Hook runs deterministically before any chain logic. | Phase A slices 1-4 (mode_migrate, partial_state_corrupt, routing_outcome_corrupt, verify_unit_writable detection) |
| **[PostToolUse-validate]** | Tool-boundary validation. Fires after Write/Edit/Skill/Bash. Hook reads tool_input + tool_response, validates output, optionally renames/blocks downstream. Includes PreToolUse blocking sub-pattern. | Iter 67.6 slice 1 handoff-validator (PostToolUse Write of units → validate binding_refs; PreToolUse Skill mega-sdd:execute-bolts → block if state=FAIL) |
| **[neither]** | Mid-chain emit inside skill body execution with no clean tool surface. Cannot be hook-enforced without skill-body prose dependency (= 4× audit failure pattern). Goes to deferred edge-case track with Phase A slices 5+6. | None (defer; do NOT prose-force) |

Distinguisher: "what triggers the halt?"
- File/config state at session start → [SessionStart-guard]
- A tool call's input or output → [PostToolUse-validate]
- Skill's internal reasoning loop without tool dispatch → [neither]

## The 25 candidates (22 main + 3 subtypes)

### [SessionStart-guard] (5)

| # | Halt | Source skill | Rationale | Confidence |
|---|---|---|---|---|
| 7 | `deep_scan_cache_corrupt` | scan-codebase | YAML parse-check on `<cwd>/.mega-sdd/codebase/starterkit-context.yaml`. Same pattern as routing_outcome_corrupt (slice 3). Rename `.corrupt-<ts>` + telemetry; next scan rebuilds. | HIGH |
| 8 | `dep_missing` | scan-codebase | Pre-check PATH for required binaries (tree-sitter, ast-grep). If missing, invoke `install-deps` script + retry; fall back to regex tier if install fails. Mostly self-contained at session start. | MEDIUM (depends on whether install-deps subsystem invokes cleanly from hook context) |
| 9 | `framework_pack_missing` | bind-codebase | Scan vault for `framework_pack:` references in binding.md / starterkit-context.yaml; verify each referenced pack file exists. Missing → emit warning telemetry + chat notice; degrade to framework-only on dispatch (existing behavior). | MEDIUM (needs vault parsing to extract refs) |
| 10 | `framework_pack_cycle` | bind-codebase | Parse all pack files, build inheritance graph, detect cycles. Cycle found → emit telemetry + chat notice; break at most-derived edge. Pure structural fix. | HIGH |
| 11 | `framework_pack_unparseable` | bind-codebase | YAML parse-check on each pack file. Same pattern as routing_outcome_corrupt. Unparseable → log + skip pack + fall back to parent in inheritance chain. | HIGH |

**Walking-skeleton next slice:** any of 7/10/11 are clean clones of Phase A slice pattern (parse-check + rename or graph check + repair). Recommended first: `framework_pack_unparseable` (simplest — single file parse). Then `framework_pack_cycle` (adds graph algorithm but still deterministic). Then `deep_scan_cache_corrupt` (third clone).

### [PostToolUse-validate] (15 main + 3 subtypes = 18)

#### 5a. generate-intent vault output validation (5)

| # | Halt | Source skill | Hook trigger | Validator scope |
|---|---|---|---|---|
| 1 | `oq_tech_missing_mode` | generate-intent | PostToolUse Write of vault doc files (`<vault>/0[1-6]-*.md`) OR `vault.json` | Parse OQ entries; verify each tech-categorized OQ has `mode:` field. Missing → re-emit attempt via vault.json patch or escalate. |
| 2 | `oq_recommend_underspecified` | generate-intent | Same as #1 | Verify each `mode: recommend` OQ has `recommendation`, `rationale`, `citations`. Missing → re-attempt OR downgrade to scan. |
| 3 | `oq_scan_missing_query` | generate-intent | Same as #1 | Verify each `mode: scan` OQ has `scan_target`. Missing → auto-emit default `codebase-map §<category>`. |
| 4 | `oq_recommend_citation_invalid` | generate-intent | Same as #1 | Verify each recommendation citation exists in KB inventory (`<cwd>/.mega-sdd/knowledge-base/` if present). Invalid → re-pick OR drop. |
| 5 | `scope_not_declared_in_prd` | generate-intent | **PreToolUse** Skill matcher `mega-sdd:auto\|mega-sdd:generate-intent` | Read `tool_input` for `--scope=X` flag; cross-check against PRD `scopes:` frontmatter; block with list of valid scopes if mismatch. |

#### 5b. generate-units output validation (3)

| # | Halt | Hook trigger | Validator scope |
|---|---|---|---|
| 12 | `unit_underspecified` (target_files C1 path) | PostToolUse Write of `<vault>/*-bound/units/U-*.md` OR `<vault>/*-bound/units/U-*/unit.md` | Verify required frontmatter fields present (target_files derived from vault_source if missing). acceptance_test path = C2 escalate per attestation reclassification #12. |
| 13 | `hard_rule_unparseable` (re-emit C1 path) | Same | Parse `## Hard Rules` block; validate ast-grep YAML grammar. Unparseable → re-emit attempt; 2nd fail → escalate C2 per reclassification #13. |
| 14 | `starterkit_rule_citation_missing` | Same | Verify every starterkit-derived Hard Rule has `Citation: starterkit-context.yaml §<path>` field. Missing → re-emit with citation from skill's tracking. |

#### 5c. execute-bolts artifact validation (3)

| # | Halt | Hook trigger | Validator scope |
|---|---|---|---|
| 16 | `provenance_missing` | PostToolUse Write of bolt-modified files (path matches bolt's target_files entries) | Check file footer for provenance trailer marker. Missing → auto-add trailer from bolt context. |
| 17 | `self_assessment_missing` | PostToolUse Write of `<vault>/bolts/U-*/bolt-report.md` | Parse markdown; verify `## Self-Assessment` section exists. Missing → auto-generate from bolt context. |
| 18 | `pbt_citation_invalid` | PostToolUse Write of unit (where PBT block lives) | Parse PBT properties; verify each `Cites: §Decision-D-NNN` exists in `<vault>/decisions/`. Invalid → re-pick OR drop property. |

#### 5d. orchestrate-flow handoff validation (4) — natural BATCH SLICE

| # | Halt | Hook trigger | Validator scope |
|---|---|---|---|
| 20 | `invalid_handoff` | PostToolUse Skill matcher `mega-sdd:*` | Parse Skill's chat response for `handoff:` YAML; validate against `handoff-contract.md` schema. Invalid → re-invoke producer with `--strict-handoff`; escalate C2 after 2 fails. |
| 21 | `handoff_type_mismatch` | Same | Same parser; check TYPE annotations match. Same retry-then-escalate. |
| 22 | `handoff_missing` | Same | Same parser; check `handoff:` block present at all. Missing → re-invoke; escalate. |
| 23 | `artifact_missing` | Same | Same parser; verify every `artifacts: [paths]` entry passes `os.path.exists`. Missing → re-invoke producer; escalate. |

**Batch slice recommendation:** halts 20-23 share emit context (orchestrate-flow consumer dispatch after sub-skill). One PostToolUse Skill validator script can handle all four. Natural single slice.

#### 5e. quality_gate_failed subtypes (3)

| # | Halt | Hook trigger | Validator scope |
|---|---|---|---|
| S1 | `quality_gate_failed:starterkit_metrics_inconsistent` | PostToolUse Skill `mega-sdd:generate-units` | Cross-check generate-units handoff `units_with_starterkit_rules > 0` vs `starterkit-context.yaml.partial == true`. Inconsistent → trigger `/mega-sdd:scan-codebase --force-deep` (which is the prescribed fix). |
| S2 | `quality_gate_failed:pdf_render_failed` | PostToolUse Bash matcher pattern `pandoc` | If exit_code != 0 → invoke `install-deps --tools=tectonic` + retry. Pure deterministic. |
| S3 | `quality_gate_failed:template_slot_unfilled` | PostToolUse Write matcher `*FSD.md` | Grep written file for `{{slot_name}}` placeholder. Found → emit warning + replace with `(content pending — slot=<name>)`. |

### [neither] (2)

These emit from inside skill body execution with no tool surface. Per discipline: DO NOT prose-force.

| # | Halt | Source skill | Why no tool surface | Track |
|---|---|---|---|---|
| 6 | `deep_scan_subagent_failed` | scan-codebase | Subagent retry logic happens inside scan-codebase skill body. PostToolUse on Agent tool could DETECT failure but cannot trigger another Agent dispatch (hooks don't have tool access). Retry must stay in skill body. Single-failure soft-halt → partial: true on second failure is acceptable best-effort already. | Edge-case track (with Phase A flagged 5+6) |
| 15 | `dispatch_prompt_too_large` | execute-bolts | Bolt prompt assembly happens entirely inside execute-bolts skill body BEFORE any tool dispatch. The 10KB cap check is on the assembled prompt string in working memory, not on any tool input/output. No hook surface fires before the prompt is built. | Edge-case track |

**Edge-case track joins Phase A flagged-pair:**
- Slice 5: `model_tier_unknown` (mid-chain orchestrate-flow Step 2.8.f)
- Slice 6: `memory_in_use` (memory subsystem file-lock retry prose)
- Phase B #6: `deep_scan_subagent_failed` (scan-codebase subagent retry prose)
- Phase B #15: `dispatch_prompt_too_large` (execute-bolts prompt assembly prose)

**4 items in edge-case track**, all share root cause: emit from inside skill-body execution. None fit SessionStart-guard or PostToolUse-validate patterns.

**Options for edge-case track (require separate design iter):**
- Move logic from skill body prose to scripts (similar to how validate-handoff-binding-units.sh extracted slice 1's logic). Skill body invokes script via Bash; script owns deterministic logic.
- Accept best-effort prose for the warn-only soft cases (deep_scan_subagent_failed) if reviewer confirms degradation paths are visible enough.
- For hard cases (dispatch_prompt_too_large, model_tier_unknown), defer to Fork B (custom runtime can intercept mid-reasoning).

## Summary tallies

| Pattern | Count | Slice batchability |
|---|---|---|
| [SessionStart-guard] | 5 | 3 clean clones (#7, #10, #11) + 2 medium-confidence (#8, #9). Sequential slices. |
| [PostToolUse-validate] | 18 | Natural batches: handoff suite (#20-23) = ONE slice; vault-OQ validation (#1-4) = ONE slice; unit validation (#12-14) = ONE slice; bolt artifacts (#16-18) = ONE slice; subtypes (#S1-S3) = mixed (S2 is Bash matcher, S1+S3 are Write/Skill — could be separate). |
| [neither] | 2 | Defer to edge-case track. |
| **TOTAL** | **25** | |

## Recommended Phase B slice order (when reviewer signs off classification)

**SessionStart-guard track:**
- Slice B.1: `framework_pack_unparseable` (simplest, clean pattern clone of Phase A slice 3)
- Slice B.2: `framework_pack_cycle` (adds graph algo, deterministic)
- Slice B.3: `deep_scan_cache_corrupt` (third file parse-check clone)
- Slice B.4: `framework_pack_missing` (vault parsing for refs — medium complexity)
- Slice B.5: `dep_missing` (install-deps integration — requires verifying install-deps invokes cleanly from hook context)

**PostToolUse-validate track:**
- Slice B.6: **Handoff validation suite** (4 halts — #20/21/22/23) — extends 67.6 slice 1 pattern naturally; PostToolUse Skill matcher → handoff schema validator script. HIGH-value (closes silent-failure paths) + LOW-incremental-risk (uses proven pattern).
- Slice B.7: Bolt artifact validation (3 halts — #16/17/18) — PostToolUse Write matcher → simple structural checks on bolt outputs.
- Slice B.8: Unit validation (3 halts — #12/13/14) — PostToolUse Write of units → frontmatter + Hard Rules + citation checks. Composite slice; might split further.
- Slice B.9: Vault OQ validation (4 halts — #1/2/3/4) — PostToolUse Write of vault docs → OQ structural checks. Heaviest slice; might split per OQ class.
- Slice B.10: PreToolUse Skill flag-validation (#5) — different hook surface (PreToolUse blocking rather than PostToolUse reactive). Could be done earlier as a pattern-prove slice.
- Slice B.11: quality_gate subtypes (#S1/S2/S3) — mixed patterns (Skill / Bash / Write); might batch or split.

**Edge-case track (parallel, separate iter):**
- Memory subsystem hardening (extract memory-write.sh; covers Phase A slice 6 + makes future similar refactors easier)
- Subagent retry hardening (extract subagent dispatch wrapper; covers Phase B #6)
- Bolt prompt assembly hardening (extract prompt-builder script; covers Phase B #15)
- Mid-chain config validation (covers Phase A slice 5 + #5 if not done via PreToolUse)

## Walking-skeleton discipline (held)

- Real-run proof per slice; corruption tests in sandbox per locked safety rule
- Slice 1 of Phase B should be the simplest [SessionStart-guard] (framework_pack_unparseable) — confirms pattern reuses cleanly
- Batch only after first pattern-clone proves
- Edge-case track is its own design phase — DO NOT prose-fake C1 for those halts

## Risk flags

1. **`scope_not_declared_in_prd` PreToolUse classification** — new hook surface (PreToolUse Skill with tool_input inspection). Pattern not yet proven in this codebase. Could move to slice B.10 as a pattern-prove exercise OR defer if other slices need pure PostToolUse first.
2. **`oq_recommend_citation_invalid` KB cross-check** — assumes KB exists at `<cwd>/.mega-sdd/knowledge-base/`. Not all projects have KB. Validator needs graceful "no KB → skip check, log advisory".
3. **`framework_pack_missing` vault parsing** — requires extracting pack refs from binding.md / starterkit-context.yaml. Parser complexity higher than slice 3 (routing-outcomes.md just needs UTF-8 + header check). Medium confidence.
4. **`dep_missing` install-deps integration** — install-deps subsystem invocation from hook context not yet tested. If install-deps requires interactive sudo or similar, hook-layer auto-install may fail. Medium confidence; needs verification.
5. **Handoff validation suite (#20-23)** — the PostToolUse Skill matcher captures the skill's `tool_response` string. Schema validation on that string needs robust YAML extraction (handoff blocks may be wrapped in code fences, markdown, etc.). Iter 67.6 handoff parser exists (in orchestrate-flow body prose) — needs porting to deterministic script. Doable but non-trivial.

## What this doc does NOT pre-commit

- Slice ORDER (recommended above is one option; reviewer can reorder)
- BATCH vs SPLIT decisions (e.g., split slice B.6 into B.6a/B.6b if validators differ enough)
- Whether [PostToolUse-validate] medium-confidence items (#5 PreToolUse Skill, #16-18 with potentially varied trailer patterns) are reclassified [neither] if implementation reveals no clean surface
- Edge-case track timing — could run parallel with later Phase B slices or wait until Phase B is done

## Audit gate

Reviewer to confirm:
1. The 25 classifications hold per the proposed pattern definitions
2. [neither] track is acceptable to defer (not pressured into prose-fake)
3. Recommended slice order is reasonable OR specify alternative
4. Risk flags (5 items) are acknowledged

Phase B coding STARTS when reviewer signs off.

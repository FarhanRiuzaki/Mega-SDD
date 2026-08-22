# Halt guidance — flow family

Per-type guidance for halts emitted by: orchestrate-flow / front door / sync (detect-drift) / memory / install-deps (+ anti-recursive guards).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### drift_framework_mismatch

**`drift_framework_mismatch`** — emitted by `detect-drift` Step 1.5 when the vault implies one framework but the codebase is another. `tag` is `n/a`. `priority` is `n/a`. `detected_framework` and `expected_framework` are required.

Registry one-liner (absorbed, same type):

- `drift_framework_mismatch` — detect-drift: scanned code framework differs from vault framework. ALWAYS STOP.

### constitution_drift_detected

- `constitution_drift_detected` — detect-drift: §B Security or §F Compliance constitution clause drift detected in code. ALWAYS STOP.

### memory_in_use

- `memory_in_use` — memory: file lock collision; concurrent writer holds lock. **C1 SELF-RESOLVE:** retry budget extended to 10 attempts with exponential backoff (250ms → 500ms → 1s → 2s → 4s → 8s → 8s → 8s → 8s → 8s, total ~40s). If still locked after 10x → log + skip memory update (memory writes are advisory; chain proceeds). The chat one-liner is the record. Human visible via chat one-liner `[self-resolved] memory_in_use: skipped after 10 retries`. NEVER halts the chain.

### mode_migrate

- `mode_migrate` — orchestrate-flow: vault.json `mode` field (greenfield | existing) doesn't match CWD signals (.git present, package.json present, etc.). **C1 SELF-RESOLVE:** re-detect from CWD signals deterministically (.git present + composer.json/package.json/etc. → `existing`; absence → `greenfield`); update `vault.json.mode`; log change to chat. The chat one-liner is the record. NEVER halts. User can override by passing explicit `--mode=<value>` flag on next chain invocation. CWD signals are ground truth — no fabrication risk.

### routing_outcome_corrupt

- `routing_outcome_corrupt` — orchestrate-flow: routing-outcomes.md fails parse. **C1 SELF-RESOLVE (SCRIPT-LAYER ENFORCED via GROUND — `scripts/ground.sh` at M/L entry, moved from SessionStart in v7):** at GROUND, the script checks `<cwd>/.mega-sdd/memory/routing-outcomes.md` for UTF-8 validity + schema header presence (`# Routing Outcomes` marker in first 200 chars). If corrupt → rename to `.corrupt-<ISO8601>`; log the corruption reason (`non-utf8-binary` or `missing_schema_header`) in the chat notice; chain proceeds with default routing. NEVER halts.

### predictive_check_failed

- `predictive_check_failed` — orchestrate-flow: predictive preflight check marked `fatal: yes` failed. ALWAYS STOP. Resolution: user fixes precondition (install dep / add framework pack / etc.) per `next_action.hint`; re-run chain.

### invalid_handoff

- `invalid_handoff` — orchestrate-flow: handoff YAML from sub-skill fails schema validation (missing REQUIRED field, or CONDITIONAL field missing when condition met, or YAML parse error). **C1 SELF-RESOLVE (HOOK-LAYER ENFORCED at GATE TIME via PreToolUse — the Stop leg was removed in v7):** on every `mega-sdd:*` Skill dispatch (excluding the `mega-sdd:using-mega-sdd` anchor), PreToolUse Branch 1a reads the transcript's last assistant message; if it carries a REAL handoff envelope (`handoff:` block + line-start `emitted_by:` — narration is not a handoff), it invokes `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` which parses + validates against this schema and writes `<cwd>/.mega-sdd/.handoff-validation-state.json` (current-truth, overwrite-not-append; identical text short-circuits on `content_sha256` so re-dispatch never double-counts retry). If the derived/stored status=FAIL, the dispatch is blocked with the validator's reason. Retry counter tracks repeated failures of same skill+halt: 1st failure = self-resolve with "re-invoke producer" recommendation; 2nd failure = escalate to C2 user_review. Producer skill author still fixes handoff template per handoff-contract.md schema for permanent fix; hook is the enforcement layer. NEVER halts the chain on first fail; blocks next-skill consumption deterministically.

### handoff_type_mismatch

- `handoff_type_mismatch` — orchestrate-flow: handoff YAML field type doesn't match TYPE annotation in handoff-contract.md schema. ALWAYS STOP. Resolution: producer skill author fixes type emission per handoff-contract.md TYPE annotation; re-run chain.

### model_tier_unknown

- `model_tier_unknown` — orchestrate-flow: model-tier override references a role not in plugins/mega-sdd/references/model-tiers.md catalog. **C1 SELF-RESOLVE (formalizing pre-existing SOFT semantics):** log + ignore override; chain proceeds with catalog default for unknown roles. The chat one-liner is the record. Forward-compat for future role additions. NEVER halts.

### handoff_missing

- `handoff_missing` — orchestrate-flow: sub-skill chat output contains no parseable `handoff:` YAML block (skills emit handoff inline in chat, not to a file). ALWAYS STOP. Resolution: inspect sub-skill chat output (`response_tail` in the validator state shows the last 300 chars; also fires on multiple `handoff:` blocks with conflicting `emitted_by`) for crash logs / parse errors / OS-level failures; re-run sub-skill standalone to reproduce; report as skill-author bug if reproducible.

### artifact_missing

- `artifact_missing` — orchestrate-flow: handoff YAML lists `artifacts: [paths]` and one or more paths fail existence check (`test -f` for files, `test -d` for directories). ALWAYS STOP. Resolution: re-run producer skill standalone to confirm artifacts actually written; inspect producer chat for mid-write crash logs.

### memory_schema_mismatch

- `memory_schema_mismatch` — memory subsystem: persisted memory file schema_version differs from current code's expected schema. ALWAYS STOP (presents migration prompt). Resolution: user opts in to migration via `/mega-sdd:memory migrate`.

### install_failed

- `install_failed` — install-deps: install command exited non-zero OR `verify_cmd` failed post-install. ALWAYS STOP. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail (last 500 chars), subtype: install_command_failed | verify_after_install_failed}`. Resolution: inspect stderr_tail, fix root cause (PATH refresh / repo signing / network), re-run `/mega-sdd:install-deps --tools=<failed-tool>` to retry single tool. Source skill: `install-deps`.

### pkg_mgr_not_found

- `pkg_mgr_not_found` — install-deps: no compatible package manager detected for OS (PKG_MGR=`none` AND no cross-platform fallbacks like cargo/npm/go on PATH). ALWAYS STOP. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`. Resolution: install brew (macOS) / verify apt is on PATH (Linux) / install WSL Ubuntu (Windows native) → re-run `/mega-sdd:install-deps`. Source skill: `install-deps`.

### oq_business_p1_unresolved

- `oq_business_p1_unresolved` — orchestrate-flow: a P1 business OQ blocks downstream pipeline; chain pauses until user resolves via `resolve-oq`. ALWAYS STOP. Details `{oq_id, priority: P1, category: business, blocked_units}`. Resolution: user answers OQ interactively; vault.json updated; chain resumes. Source skill: `orchestrate-flow` (re-emits from generate-intent's prose claim). **Deprecation note:** older skill bodies may emit `oq_blocker` (legacy name); both are accepted during transition. New code should use `oq_business_p1_unresolved` as canonical name.

### no_starterkit_detected

- `no_starterkit_detected` — orchestrate-flow: starterkit-first mode default but no framework manifest detected (no composer.json / package.json / Gemfile / etc.) AND user did NOT pass `--greenfield` flag. ALWAYS STOP. Details `{cwd, detected_manifests, suggestions}`. Resolution: user picks (a) scaffold starterkit, (b) re-run with `--greenfield`, or (c) cancel. Source skill: `orchestrate-flow`.

### adoption_demote_confirm

- `adoption_demote_confirm` — orchestrate-flow / auto (P2 adoption lane, LOCKED): `scripts/certify-artifact.sh` returned verdict `DEMOTE` for an externally-authored artifact (foreign vault/KB grammar → PRD-rung re-ingest; degenerate map → re-scan). **C2 — business gate, ALWAYS a halt under `--auto`, never unconfirmed**: the demotion burns generate-intent tokens and produces a DIFFERENT vault than the artifact the user placed. Displayer renders the certify keterangan block verbatim FIRST (per step 0 — it already carries why + per-option consequences in Indonesian), then ONE AskUserQuestion-shaped confirmation with glossed options `RE_INGEST` (jalankan re-ingest di rung PRD — artefak BARU ber-grammar mega-sdd, burn token) / `MANUAL_FIX` (berhenti; user perbaiki artefak mengikuti template lalu jalankan ulang certify) / `CANCEL` (batal — artefak tidak diadopsi). After the answer the chain PROCEEDS per the choice (this is confirm-then-proceed, NOT an always-stop-re-run halt). Never fires for a v4-mega-sdd-authored artifact (migration guarantee: CERTIFIED_DEGRADED floor, REJECTED forbidden). Source skill: `orchestrate-flow`.

### convergence_max_reached

- `convergence_max_reached` — orchestrate-flow: convergence loop hit `--max-cycles`. User reviews cycle history (envelope in the convergence-loops reference). ALWAYS STOP.

### phase_stuck

- `phase_stuck` — factory-line: a phase failed to reach a green checkpoint within the retry cap (default 3); the loop stops and a human must resolve the underlying blocker before re-running. (Auto-looped while cycle-eligible up to the cap; becomes always-stop at the cap.)

### anti_spin

- `anti_spin` — factory-line: a phase re-ran with an identical unresolved set (no progress); the loop stops to avoid spinning, human resolution required. ALWAYS STOP.

### starterkit_metrics_inconsistent

*Subtype of `quality_gate_failed` (`details.subtype: starterkit_metrics_inconsistent`) — enum + dispatch rule live in the registry §`quality_gate_failed` subtypes.*

- `starterkit_metrics_inconsistent` — orchestrate-flow: generate-units handoff reports `units_with_starterkit_rules > 0` but `starterkit-context.yaml` flags `partial: true` (rules pulled from incomplete framework slice may cite missing conventions). Resolution: re-run `scan-codebase` (since the failed-slice fix, a plain re-run re-dispatches failed slices — they carry no per_slice cache signature; `--no-cache` is the belt-and-braces option that re-dispatches everything; `--force-deep` is only needed when a LOW-confidence trigger skipped deep-scan entirely) then regenerate units.

### replan_budget_exceeded

*Subtype of `quality_gate_failed` (`details.subtype: replan_budget_exceeded`) — enum + dispatch rule live in the registry §`quality_gate_failed` subtypes.*

- `replan_budget_exceeded` — anti-recursive guard: a task's re-plan count exceeded `max_replan_count` cap (default 2; configurable). Details `{task_id, max_replan_count, actual_replan_count, trigger_history: [<closed-enum triggers per RULE 1>]}`. Resolution: user reviews trigger history; if hitting same trigger repeatedly, root-cause the underlying issue (don't just raise the cap); if scope grew beyond original task, restart task with corrected scope.

### revalidate_budget_exceeded

*Subtype of `quality_gate_failed` (`details.subtype: revalidate_budget_exceeded`) — enum + dispatch rule live in the registry §`quality_gate_failed` subtypes.*

- `revalidate_budget_exceeded` — anti-recursive guard: a task's re-validate count exceeded `max_revalidate_count` cap (default 3). Details `{task_id, max_revalidate_count, actual_revalidate_count}`. Resolution: validators are LEAF NODES — repeated validation failure means root issue is in validated artifact, not validation logic. Fix artifact; do not validate the validation.

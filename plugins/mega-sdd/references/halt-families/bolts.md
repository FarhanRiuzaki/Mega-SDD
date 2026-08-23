# Halt guidance — bolts family

Per-type guidance for halts emitted by: execute-bolts (L0 + B1–B4 evidence gates, review panel, verify units).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### dispatch_prompt_too_large

- `dispatch_prompt_too_large` — execute-bolts: assembled bolt dispatch prompt exceeds 10KB hard cap. ALWAYS STOP. Resolution: re-tier context.

### bolt_repeated_partial_failure

- `bolt_repeated_partial_failure` — execute-bolts: bolt failed 3 partial-state recovery cycles. ALWAYS STOP. Resolution: review unit spec.

### provenance_missing

- `provenance_missing` — execute-bolts: bolt modified file lacks provenance trailer. ALWAYS STOP.

### bolt_introduces_locked_drift

- `bolt_introduces_locked_drift` — execute-bolts: bolt drift hits a LOCKED entity. ALWAYS STOP (eligible for propose-and-confirm override).

### self_assessment_missing

- `self_assessment_missing` — execute-bolts: bolt-report.md lacks self-assessment section. ALWAYS STOP.

### pbt_citation_invalid

- `pbt_citation_invalid` — execute-bolts: a PBT property block declares `Cites: §Decision-D-NNN` but the cited ADR ID does not exist in the bound vault's decisions surface (`vault.md ## Decisions` on layout-2; `05-decisions.md` / `decisions/` on legacy). ALWAYS STOP. Resolution: fix the citation in the unit's PBT block (or remove the property if the underlying decision was rescinded), then re-run the bolt.

### partial_state_corrupt

- `partial_state_corrupt` — execute-bolts: `--resume` mode loaded `<vault>/bolts/U-XXX/partial-state.json` (canonical path per execute-bolts §Partial-state contract) and JSON parse failed. **C1 SELF-RESOLVE (SCRIPT-LAYER ENFORCED via GROUND — `scripts/ground.sh` at M/L entry, moved from SessionStart in v7):** at GROUND, the script scans `<cwd>/.mega-sdd/vaults/*-bound/bolts/U-*/partial-state.json`; any file failing JSON parse is renamed to `partial-state.json.corrupt-<ISO8601>` (forensics preserved); next `--resume` invocation restarts fresh from unit spec. The chat one-liner is the record. NEVER halts. Limitation: the GROUND C1 battery globs the legacy `*-bound/` sibling only; canonical-layout vaults are not scanned by this self-resolve rung (tracked).

### hard_rule_violated

- `hard_rule_violated` — execute-bolts: the post-flight scan of the ALREADY-COMMITTED bolt found a Hard Rule violation (detect-after — the implementer committed before the scan). ALWAYS STOP (no auto-retry). Resolution: fix forward OR `git revert` the flagged bolt commit, then re-run the post-flight scan; the B1 gate blocks every further execute-bolts until a passing `postflight.json` is recorded.

### module_blocked_by

- `module_blocked_by` — execute-bolts: bolt invocation blocked because prerequisite module hasn't completed yet (module-graph dependency). ALWAYS STOP. Details `{unit_id, blocking_module_id, blocked_status}`. Resolution: user runs prerequisite module first OR adjusts module dependency graph in `vault/_meta/modules.yaml`. Source skill: `execute-bolts`.

### hard_rule_unanchored

- `hard_rule_unanchored` — execute-bolts: a unit's `## Hard Rules` block references an ANCHOR (file path / function signature) that cannot be resolved against the current codebase-map. ALWAYS STOP. Details `{unit_id, rule, missing_anchor}`. Resolution: user fixes anchor reference (rename to current symbol) OR removes obsolete rule. Source skill: `execute-bolts`.

### verify_unit_writable

- `verify_unit_writable` — execute-bolts: a `task_type: verify` unit has non-empty `target_files` with operation ∈ {create, modify, delete} (verify units should not write code). **C1 SELF-RESOLVE (SCRIPT-LAYER DETECTION via GROUND — `scripts/ground.sh` at M/L entry, moved from SessionStart in v7 — DISPATCH-LAYER AUTO-CLEAR in execute-bolts):** at GROUND, the script scans `<cwd>/.mega-sdd/vaults/*-bound/units/U-*.md` AND `<cwd>/.mega-sdd/vaults/*-bound/units/U-*/unit.md` (both layouts). For each `task_type: verify` unit with forbidden ops → emit the chat notice in the GROUND output. On-disk unit NOT modified (preserves bad spec for human review). Dispatch-time auto-clear is execute-bolts's responsibility (separate code path). Detection-only at GROUND means the warning re-fires at every M/L entry until human fixes the unit — intentional visibility. NEVER halts. Source skill: `execute-bolts`. Limitation: the GROUND C1 battery globs the legacy `*-bound/` sibling only; canonical-layout vaults are not scanned by this self-resolve rung (tracked).

### secret_in_code

- `secret_in_code` — execute-bolts (L0 gate): a committed secret was detected; user rotates it + purges it from history. ALWAYS STOP.

### sast_critical_finding

- `sast_critical_finding` — execute-bolts (L0 gate): a Critical SAST finding; user fixes before the panel. ALWAYS STOP.

### dep_not_found

- `dep_not_found` — execute-bolts (L0 gate): a newly-added dependency does not resolve in its registry; user corrects the manifest. ALWAYS STOP.

### review_critical_unresolved

- `review_critical_unresolved` — execute-bolts: the review panel's Critical findings (or a still-❌ spec lens — an unmet requirement carries no severity grade) survived the retry cap; user resolves them. ALWAYS STOP.

### batch_suite_red

- `batch_suite_red` — execute-bolts: the batch-completion FULL suite ended RED; user fixes the failing test(s) then re-runs the suite. ALWAYS STOP.

### batch_suite_gate_missing

- `batch_suite_gate_missing` — execute-bolts: no green `_batch-suite.json` covers the newest code commit (a bolt OR an out-of-band edit); user runs the suite via `run-full-suite.sh`. ALWAYS STOP.

### postflight_evidence_missing

- `postflight_evidence_missing` — execute-bolts: a committed Hard-rule bolt has no passing `postflight.json`; user runs the post-flight scan via `run-postflight-scan.sh`. ALWAYS STOP.

### acceptance_evidence_missing

- `acceptance_evidence_missing` — execute-bolts (B4): a **v5-keyed** bolt (its commit carries the `SDD-Acceptance: v5` trailer — commit-keyed so legacy pre-v5 bolts NEVER retro-block) has no fresh readable `acceptance.json` covering its newest bolt commit. ALWAYS STOP. Keterangan: bolt versi v5 wajib punya bukti acceptance yang tereksekusi — jalankan `bash <plugin>/scripts/run-acceptance-tests.sh --cwd=<project-root> --unit=U-XXX` (script itu yang mengeksekusi acceptance_test unit + lantai sintaks L0 dan menulis buktinya sendiri; tulis-tangan ditolak hook). Bolt lama tanpa trailer hanya dapat catatan advisory, tidak pernah diblokir.

### acceptance_red

- `acceptance_red` — execute-bolts (B4): the recorded `acceptance.json` is RED — an executed `acceptance_test` entry failed against the COMMITTED code even after the single bounded auto-retry. ALWAYS STOP. Keterangan: kode yang sudah di-commit gagal acceptance test unit-nya — perbaiki kodenya (atau `git revert` commit bolt yang ditandai), lalu jalankan ulang `run-acceptance-tests.sh` sampai hijau; gate execute-bolts terkunci sampai bukti hijau terekam.

### build_broken

- `build_broken` — execute-bolts (L0 syntax floor, B4 pre-rung): a committed file fails the zero-config syntax check of its own language (`php -l` / `python3 -m py_compile` / `node --check` / `ruby -c` — run only when the interpreter exists, detect-never-impose). ALWAYS STOP, NO retry (syntax is deterministic — a re-run cannot change the verdict). Keterangan: file yang di-commit tidak lolos cek sintaks bahasanya sendiri — build rusak di lantai paling dasar, tidak ada test yang bisa jalan di atasnya; perbaiki sintaks file yang ditandai lalu jalankan ulang `run-acceptance-tests.sh`.

### anchor_missing

- `anchor_missing` — execute-bolts (pre-flight, `check-anchor-freshness.sh`): a `## Anchors` entry `file:line` no longer resolves — the file is not git-tracked (deleted/renamed) or the line is past the end of the file. ALWAYS STOP before dispatch (commit-keyed: a unit whose bolts already committed gets an advisory WARN only, never a retro-block). Keterangan: anchor unit menunjuk file/baris yang sudah tidak ada — bolt-implementer akan membaca evidence yang salah; refresh anchors via `/mega-sdd:sync` atau bind ulang, ATAU perbaiki baris `## Anchors` unit ke path:line yang benar, lalu jalankan ulang execute-bolts.

### whitelist_violation

- `whitelist_violation` — execute-bolts: a bolt commit touched files outside the unit's `target_files` ∪ sanctioned extras; user reverts/fixes the scope escape. ALWAYS STOP.

### commit_rejected_by_hook

- `commit_rejected_by_hook` — execute-bolts: the repo's own commit hook (pre-commit/husky/lefthook) or required GPG signing rejected the bolt commit; user fixes the hook finding (never `--no-verify`). ALWAYS STOP.

### scope_creep_detected

- `scope_creep_detected` — execute-bolts: a bolt exceeded its declared scope; user reviews the deviation. ALWAYS STOP.

### bolt_artifacts_missing

- `bolt_artifacts_missing` — execute-bolts: a `completed` unit emitted no `bolts/U-XXX/bolt-report.md`; structural silent-failure closure, user re-runs. ALWAYS STOP.

### hard_rule_mixed_grammar

- `hard_rule_mixed_grammar` — execute-bolts: a unit's `## Hard rules` mixes v1 (bulleted) + v2 (YAML) grammar; user picks one grammar. ALWAYS STOP.

### verify_grounding_untrusted

- `verify_grounding_untrusted` — execute-bolts (A1 verify-grounding gate): a `task_type: verify` unit with HIGH `grounding_confidence` whose acceptance criteria lack a non-test source anchor; blocking at the execute-bolts gate. ALWAYS STOP. Resolution: user adds a non-test source anchor to the unit's acceptance criteria (or downgrades `grounding_confidence`), then re-runs execute-bolts.

### pbt_property_violated

- `pbt_property_violated` — execute-bolts post-flight (properties born in generate-units `references/pbt-integration.md`): a property-based test failure with `severity: error` halts (severity `warning` → log + commit anyway, per pbt-integration.md Step 3); the counterexample input + failing property definition are preserved in the envelope. Bridged via propose-and-confirm in convergence loops (`orchestrate-flow/references/convergence-loops.md` — propose fix → user approve → re-execute → continue).

### test_fail

- `test_fail` — execute-bolts: a bolt's acceptance test still fails after the max retry budget (the attempt loop stops instead of thrashing). ALWAYS STOP. Details `{unit_id, attempts, failing_test, last_error}` (registry §Type-specific schemas). Resolution: read `<vault>/bolts/U-XXX/bolt-report.md` for the failure trail; common causes are a missing test runner (`install-deps`), an unmigrated database, or a unit missing a `target_files` dependency — fix, then `/mega-sdd --resume`.

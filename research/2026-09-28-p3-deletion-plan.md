> **Owner decisions (2026-09-28):** run the full P3 (C0–C9, O2 accepted); the per-unit trace tag `mega-sdd-trace:execute-bolts:<unit-id>` is RETIRED and recorded in docs/gateway-contract.md with a note for the gateway team (O1). Produced by the read-only workflow `p3-caller-audit` (144 agents: inventory → 9 cluster audits → 135 adversarial refutation checks → synthesis) at 4e1cf166.


# P3 deletion plan: retiring the per-dispatch machinery

This plan covers HEAD `4e1cf166` on `bench/vanilla-arm`, plugin `plugins/mega-sdd/`. It is read-only: nothing has been edited. The line counts marked "measured" come from `wc -l`/`git ls-files` at HEAD. Numbers marked `≈` are estimates, and the ratchet test re-measures them.

**Rules applied**
- **R1. Refuted items become KEEP.** An item the verifier refuted (16 items, marked **YES** below) is not changed, and its proposed surgery is not applied.
- **R2. Lockstep lines still move.** A non-refuted item may need one named line changed inside a refuted-KEEP file. That single line is applied and listed in §2b. The rest of the file stays as it is.
- **R3. Forced tests get the verifier's fix.** Four refuted items are tests that pin code a non-refuted item deletes, so keeping them unchanged would turn CI red. For those I apply the verifier's corrected surgery, flag it in §2b, and require a re-audit before the commit. The plugin `CLAUDE.md` is handled the same way: after the deletions it would state gates that no longer exist.
- **R4. HOLD → P3b.** Items that were not refuted but are coupled to a refuted KEEP are deferred to P3b as a unit, not half-done.
- **R5. No gains are claimed.** P3 claims no speed, cost or quality gain. The only basis for deleting is the P2 measurement: `--inline` was non-inferior on one brownfield fixture, n=3.

---

## 1) Item table

Commit tags (C0–C9) are defined in §6.

### Agents
| path | verdict | lines | why (1 line) | refuted? |
|---|---|---|---|---|
| agents/bolt-implementer.md | DELETE (C6b) | 167 | Only `--agents` dispatches it. It goes in the same commit as the F-09 hook leg, so no ungated dispatch path remains. | no |
| agents/spec-reviewer.md | DELETE (C3) | 48 | Per-unit panel lens (§8.3). The inline close uses one `general-purpose` reviewer. | no |
| agents/code-quality-reviewer.md | DELETE (C3) | 57 | Panel lens. `validate-reuse-duplication.sh` keeps its analyze caller. | no |
| agents/security-reviewer.md | DELETE (C3) | 54 | Panel lens. The pack `## Security idioms` consumer gap goes to the packs cluster. | no |
| agents/standards-reviewer.md | DELETE (C3) | 59 | Panel lens. The pack `## Code style` consumer gap goes to the packs cluster. | no |
| agents/design-reviewer.md | DELETE (C3) | 61 | Panel UI lens. The deterministic `validate-ui-quality.sh` floor stays. | no |
| agents/resolution-verifier.md | DELETE (C3) | 46 | `--agents` fix rounds only. The inline run has "no second review". | no |

### execute-bolts references
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| skills/execute-bolts/references/review-panel.md | DELETE (C3) | 152 | `--agents` only. Its one inline rule (the trace tag) already lives in inline-run.md:81 and derive-exec-plan.sh:385. | no |
| .../context-enrichment.md | DELETE (C5) | 503 | This is the builder's spec. Known-open row 1 (resolver exit codes, 12 call sites) moves to a research backlog note first. | no |
| .../starterkit-enrichment.md | DELETE (C5) | 271 | The builder's starterkit-slice spec. | no |
| .../bolt-dispatch-prompt.md | DELETE (C5) | 364 | The builder's prompt template. | no |
| .../partial-state-and-saga.md | DELETE (C7) | 107 | Its only writer prose is in bolt-implementer §Rollback hints. The inline run resumes from its own plan. | no |
| .../squad-subagent.md | HOLD→P3b | 91 | Holds the only per-squad interface-lock and failure-isolation text, and is linked from batch-and-fanout.md (KEEP). | no |
| .../batch-and-fanout.md | **KEEP (refuted)** | 106 | `--module` step 3 reads `bolt-outcomes.json`, which inline never writes. The selection prose needs relocating and measuring. | **YES** |
| .../superpowers-bridge.md | **KEEP (refuted)**, byte-identical | 193 | Owns the inline bolt-report schema. `halted_postflight`/`forced_pass` are live, and h15, test-run-code-gates:258 and no-depth2:74 pin it. | **YES** |
| .../halts-and-handoff.md | **KEEP (refuted)** + 2 lockstep lines | 334 | The panel/L0 halts and the `starterkit_context` passthrough are live contracts. Only :118 (C5) and :323 (C7) change. | **YES** |
| .../halt-recovery.md | HOLD→P3b (+1 lockstep line in C7) | 166 | halts-and-handoff.md:31 (KEEP) points at its `review_critical_unresolved` YAML. | no |
| .../propose-and-confirm-prompt.md | **KEEP (refuted)** | 198 | Rewording "re-run the task inline" would break the fix-forward of a unit that is already committed. | **YES** |
| .../code-gates.md | REWRITE (C3) | 101 | The L0 floor runs on every inline task. Only the panel coupling is stripped. | no |
| .../hard-rule-scan.md#L166-169 | HOLD→P3b | 4 | Safe only together with batch-and-fanout.md:104, which is KEEP. | no |
| .../jit-bind-and-quarantine.md#3.9b | DELETE (C6a) | 19 | The deny table of the per-dispatch freshness leg. | no |
| .../jit-bind-and-quarantine.md#3.9 | REWRITE (C6b) | 64 | Keep the binding contract (:39-72) verbatim. Drop per-wave steps 0/1 and the dispatch-gate sentence. | no |
| skills/execute-bolts/SKILL.md | REWRITE (C2–C7) | 213 | Loaded on every run. Only the `--agents` legs go, and the pre-flight numbering stays. | no |

### Scripts and `_lib`
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| scripts/merge-panel-findings.sh | DELETE (C3) | 337 | Named in §8.3. Must go in the same commit as the panel-scan block and the hook panel reader. | no |
| scripts/resolve-review-tier.sh | DELETE (C4) | 380 | Every output feeds deleted machinery. `size_proxy` stays in `_lib/unit_tier.py`. | no |
| scripts/capture-views.sh | DELETE (C3) | 131 | Its only consumer is the design lens. `preview_url` stays with uat-run.sh. | no |
| scripts/build-dispatch-prompt.sh | DELETE (C5) | 3853 | Per-unit only. It ran 0 times in the 3 P2 inline runs. | no |
| scripts/validate-dispatch-prompt.sh | DELETE (C5) | 420 | Its only input is written by the builder. Analyze row V16 degrades to SKIP. | no |
| scripts/validate-reuse-duplication.sh | REWRITE (C3, header only) | 208 | Analyze still runs it. Keep `--json`, `--range` and mode 100755. | no |
| scripts/validate-bolt-artifacts.sh#L1006-1111 | DELETE (C3), keep a `--panel-scan` no-op arm | 106 | Keyed only on `review-tier.json`. Open plans on disk still pass the flag, and an unknown arg exits 2. | no |
| scripts/run-analyze.sh#L537,L730 | **KEEP (refuted)** | 2 | The literal edit crashes FULL mode (unbound V15_RC/V16_RC). V16 already SKIPs once the validator is gone. | **YES** |
| scripts/derive-exec-plan.sh#L246-253,L270 | REWRITE (C8, optional and last) | 9 | The retire shim is dead once panel-scan is gone, but removing it changes the generated plan text, so it is isolated. | no |
| scripts/derive-state.sh#L94-113 | REWRITE (C9, comment only) | 20 | Label the tracked legacy evidence. The managed `.gitignore` body bytes stay unchanged. | no |
| scripts/derive-ready-units.sh | HOLD→P3b | 107 | On the inline path. `dispatch_plan` is dead but harmless, and its only prose consumer (batch-and-fanout.md) is KEEP. | no |
| scripts/derive-unit-claims.sh | HOLD→P3b | 126 | After the §3.9 rewrite, only tests use wave mode. Coupled to the protected-set KEEP. | no |
| scripts/_lib/vault_layouts.py#L69-225 | **KEEP (refuted)** | 157 | `inflight_units` feeds the unit_binding.py:460 done-rule. Removing it loses an anchor-drift CONFLICT on legacy leftovers. | **YES** |
| scripts/_lib/unit_binding.py#L460 | HOLD→P3b | 2 | The vault_layouts refutation shows the inline CONFLICT verdict changes, which contradicts this item's own verifier. | no |
| scripts/_lib/freshness.py#L768-774,L836-837 | REWRITE (C6a, reduced) | 27 | Drop the `dispatch_prompt_stale` branch and `gate_main`. **Keep** the `prompt_path=None` parameter so derive-exec-plan.sh:226 stays byte-identical. | no |
| scripts/_lib/state_probes.py#L1349-1353 | REWRITE (C2, comment) | 5 | Comment only. The `execute-bolts --all --lite` proposal is unchanged. | no |
| scripts/ground.sh#L128-167 | REWRITE (C7) | 40 | Guard 2 is dead. Keep `ts_fname`, because Guard 7 uses it at :369. | no |
| scripts/validate-preflight.sh#L360-368,L498-502 | DELETE (C7) | 14 | A non-fatal warning about a file nothing writes. | no |

### Hooks
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| hooks/pre-tool-use#L13-22 | REWRITE (C5: items 4-5; C6b: item 3, plus :55) | 10 | Header comment only. | no |
| hooks/pre-tool-use#L112-118 | DELETE (C6b) | 7 | Agent fast path. Only bolt-implementer ever passed through it. | no |
| hooks/pre-tool-use#L133-138 | DELETE (C5) | 6 | Wave-rail prefilter fragments. L132 (the anti-self-bypass list) stays. | no |
| hooks/pre-tool-use#L303-325 | DELETE (C6b) | 23 | Agent payload parse. Only the F-09 legs read it. | no |
| hooks/pre-tool-use#L329-373 | DELETE (C5) | 45 | Wave and probe hazard classifiers. Their only reader is the rail at L1682. | no |
| hooks/pre-tool-use#L559-583 | DELETE (C6b), except **keep L570-571** | 25 | F-09 mapping. The `GATE_MODE="run"` / `GATE_SUBJECT` resets block environment inheritance. | no |
| hooks/pre-tool-use#L968-1007 | **KEEP (refuted)** | 40 | Removing `IN_RUN` raises a NameError at L1124/1277/1297, which fails **open** at the Skill entry. | **YES** |
| hooks/pre-tool-use#L1108-1119 | DELETE (C3), in the same commit as panel-scan | 12 | A stale FAIL `.bolt-panel-state.json` would otherwise block every run. | no |
| hooks/pre-tool-use#L1120-1132 | DELETE (C6a) | 13 | F-18 in-run leg. The validator check at validate-unit-spec.sh:442-480 stays. | no |
| hooks/pre-tool-use#L1133-1284 | DELETE (C6a) | 152 | Binding-freshness in-run leg. The inline equivalent is derive-exec-plan.sh:226. | no |
| hooks/pre-tool-use#L1285-1325,L1390-1414 | DELETE (C4) | 66 | Attempt cap (§8.3). It fired 0 times in the P2 guarded arm. | no |
| hooks/pre-tool-use#L1415-1420 | DELETE (C6a) | 6 | D24a crash-deny, in-run only. | no |
| hooks/pre-tool-use#L1670-1696 | DELETE (C5), with or after the dispatch-prompt writer | 27 | Wave and probe rails. They only fire while a `dispatch-prompt.md` exists. | no |
| hooks/pre-tool-use#protected-set-tokens | **KEEP (refuted)** | 9 | `_wave-claims.json` still has a producer (sync `--full-bind` docs, tests). A stale `attempts` token is harmless. | **YES** |
| hooks/hooks.json#PreToolUse.matcher | REWRITE (C6b) → `Skill\|Bash\|Edit\|Write` | 1 | `Agent` existed only for F-09. | no |
| hooks/stop#L177-182 | REWRITE (C8, optional) | 6 | Only the `--panel-scan` token changes. The flag is a no-op from C3 on. | no |

### Vault and state artifacts
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| `<vault>/bolts/U-*/review-tier.json` | DELETE (writer gone in C4) | — | Its readers are panel-scan (C3), attempt-cap (C4) and merge-panel (C3). The leftover-retire shim stays until C8. | no |
| `<vault>/bolts/U-*/attempts.json` | DELETE (writer gone in C4) | — | Written only by the attempt-cap hook. | no |
| `<vault>/bolts/U-*/findings.json` | DELETE (writer gone in C3) | — | Written only by merge-panel-findings. The hook guard token stays (KEEP). | no |
| `<vault>/bolts/U-*/dispatch-prompt.md` | DELETE (writer gone in C5) | — | Legacy files still feed `inflight_units`, which is kept. | no |
| `<vault>/lens-inputs/U-*/design-slice.md` | DELETE (writer gone in C5) | — | Design-lens input. `lens-inputs/` survives for `l0-results.json`. | no |
| `<vault>/bolts/_wave-claims.json` | HOLD→P3b | — | Wave mode and its guard stay until the JIT-capture cleanup. | no |
| `.mega-sdd/.bolt-panel-state.json` | DELETE (C3) | — | Its only reader, L1111, goes in the same commit. | no |
| `.mega-sdd/.dispatch-prompt-state.json` | DELETE (C5) | — | Writer gone. The analyze V16 row stays and reads SKIP (run-analyze is KEEP). | no |
| `<vault>/bolts/U-*/partial-state.json` | DELETE (C7) | — | No writer exists. The readers (Guard 2, preflight) are removed in C7. | no |

### Registry, orchestrate-flow and other plugin prose
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| references/model-tiers.md | REWRITE (C3/C4/C6b) | 157 | Keep rows 6 and 23 (extract roles) and Guard 8. The panel and implementer rows go. | no |
| references/project-config.md#review_panel,bolt_implementer | REWRITE (C3/C6b) | 96 | The keys are `--agents`-only. `model_tiers:` stays, with an extract-role example. | no |
| references/project-config.md#parallel_max,max_retries | REWRITE `max_retries` (C4); HOLD `parallel_max` | 13 | The attempt cap is gone. `parallel_max` is still read by held code. | no |
| references/paths.md | **KEEP (refuted)** | 320 | findings/dispatch-prompt/_wave-claims still have readers, G3b pins `attempts.json`, and h9 is unaffected (no `scripts/` path names a deleted script). | **YES** |
| references/halt-protocol.md + halt-families/bolts.md | REWRITE (C7: `partial_state_corrupt` only) | 551 | The registry survives. The other emitterless rows are HOLD (their taxonomy and handoff mirrors are KEEP). | no |
| skills/orchestrate-flow/SKILL.md | REWRITE (C2/C6b) | 174 | Retire `--agents`. Keep model-tier resolution. Keep :88 (pinned by test-e-lean-profile:67). | no |
| .../orchestrate-flow/references/convergence-loops.md | REWRITE (C6b) | 161 | Delete row :22 after moving its action and safety text into :23. Keep rows :25-26. | no |
| .../orchestrate-flow/references/chain-execution.md | **KEEP (refuted)** + 1 lockstep block (C3) | 229 | The analyze-parallelism row still feeds `--full`, `--no-analyze` and the `--deep` speedup line. | **YES** |
| .../orchestrate-flow/references/routing-rules.md | REWRITE (C2/C6b) | 235 | Strip the `--agents`/`--per-squad` proposals. Keep `--squad=` validation. | no |
| .../orchestrate-flow/references/diagnostics-procedures.md | REWRITE (C2/C3) | 182 | Replace the `--agents` suggestion at :132 with `--sprint=<n>`. Keep the "halting form" phrase. | no |
| .../orchestrate-flow/references/handoff-contract.md | REWRITE (C3/C5/C6b), reduced | 337 | **Keep** the `starterkit_context` block (live CONDITIONAL contract). Fix :79/:83, :213, :255. | no |
| .../orchestrate-flow/references/halt-taxonomy.md | **KEEP (refuted)** + 1 lockstep token (C7) | 37 | panel/L0 halts: rows stay until the P3b re-audit. | **YES** |
| skills/using-mega-sdd/SKILL.md | REWRITE (C6b) | 90 | Anchor core: drop "`--agents`: at dispatch". The byte re-baseline is recorded. | no |
| skills/plan/references/* | REWRITE (C5/C6b), verifier-corrected | 2169 | Prose only. Keep the whitelist tokens pinned by test-5d. | no |
| skills/extract-intelligence/SKILL.md#L200 | REWRITE (C5) | 1 | Keep the E3 rung-5 clause, drop the builder clause. The extract agents are untouched. | no |
| commands/mega-sdd.md#L74-76 | REWRITE (C2/C6b) | 3 | Retire `--agents` with a notice. Keep `--inline` and `--model-tier=<role>:<tier>`. | no |
| plugins/mega-sdd/CLAUDE.md | **KEEP (refuted)**, forced honesty edit (§2b) | 125 | The auditor's list dropped the live `_claims/_wave-claims` guard sentence and cited a non-existent §8.6. | **YES** |
| plugins/mega-sdd/README.md | REWRITE (C6b/C9), verifier-corrected | 313 | The per-dispatch gates and agents list go. The analyze duplication sweep and the pack rules stay described. | no |

### Repo docs and benchmarks
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| docs/gateway-contract.md#L11 | REWRITE (C3 lens part; C5 per-unit part, **needs owner sign-off**) | 1 | The per-unit tag loses its only emitter. The `mega-sdd-trace:*` and `mega-sdd-note:` families survive. | no |
| docs/superpowers/specs/2026-09-27-v9-simplification-design.md | REWRITE, append-only (C1 skeleton, C9 numbers) | 354 | Add §8.6. §8.1–8.5 are untouched (pinned by h9/h15). | no |
| README.md | REWRITE (C6b), verifier-corrected (incl. :315) | 512 | Replace the `PANEL --> CHECK` edge with `REVIEW --> CHECK --> OUT`. | no |
| CONTRIBUTING.md | REWRITE (C6b) | 147 | Rail 2: drop only the `--agents` clause. | no |
| benchmarks/config/complexity-budget.json | REWRITE (C9) | 153 | Lower every shrunk ceiling. No `raises` entry is needed. | no |
| benchmarks/tasks/T01-greenfield-chain/files.lite.txt | HOLD→P3b | 43 | batch-and-fanout.md is KEEP, so nothing goes missing. The trace re-point (to the inline set) raises the ceiling and needs a `raises` entry. | no |
| benchmarks/tasks/T10-bolts-per-unit/ | DELETE (C9) | 28 | It traces the `--agents` lane. Drop the "covered by T01" claim; see gap G7. | no |
| benchmarks/scripts/vanilla-ab-batch.sh | REWRITE (C2) | 66 | Remove the `guarded-agents` arm, so no inline run is recorded under an "agents" label. | no |

### Tests
| path | verdict | lines | why | refuted? |
|---|---|---|---|---|
| tests/review-panel/ | DELETE (C3) | 99 | Pins panel surfaces only. | no |
| tests/review-lens-seam/test-review-lens-seam.sh | DELETE (C3) | 38 | Pins lens seam text only. | no |
| tests/round-discipline/test-merge-panel-findings.sh | DELETE (C3) | 203 | Behavioural suite of a deleted script. | no |
| tests/security-idioms/test-lens-wired.sh | DELETE (C3) | 10 | The sibling test-packs-have-section.sh stays. | no |
| tests/size-weighted/test-standards-lens-h1.sh | DELETE (C4) | 30 | Router lens set only. | no |
| tests/size-weighted/test-unit-tier-router.sh | DELETE (C4), after the C0 re-home | 117 | Re-home cases 1-9 (including the case-2 fixture) against `size_proxy` first. | no |
| tests/design-ceiling/ | DELETE (C3) | 57 | Design lens and capture-views. | no |
| tests/design-aware/ (test-design-pipe.sh + run-all.sh) | DELETE (C3) | 61 | Fails at :34 once design-reviewer is gone. | no |
| tests/god-review-s7/test-s7c-review-panel.sh | REWRITE (C3) | 109 | Keep the secret-scan probes :20-22, :29-34, :38-70. | no |
| tests/token-efficiency/test-b3-anchor-and-panel.sh | REWRITE (C3) | 103 | Keep M-13a/b, including the `-lt 4000` line that p9 D3 greps. | no |
| tests/surface/test-p7-bolt-loop-efficiency.sh | DELETE (C3), after moving M8/F1/F2 in C0 | 104 | Verifier-corrected: M8 is the only pin of the citation rule. | no |
| tests/boilerplate-diet/test-p2d-agent-contracts.sh | trim in C5, DELETE in C6b | 108 | §4 validator keys move to test-provenance-trailer-2line.sh in C0. | no |
| plugins/mega-sdd/tests/moat/test-no-depth2-dispatch.sh | HOLD→P3b (no change) | 82 | Every file it scans is kept, so it stays green. | no |
| tests/express-default/test-p3-oq-defer-risk-router.sh | REWRITE (C3 :239-246; C4 §1) | 269 | Keep §2 and the rest of §3. | no |
| tests/scenarios/scenario-11-model-tier-override.md | REWRITE (C6b) | 145 | Rewrite around config `model_tiers` for the extract roles. | no |
| tests/playwright-embed/test-playwright-embed-contracts.sh | REWRITE (C3 F; C5 E4; C6b E1/E3 + C1/C1b) | 173 | E1/E3 re-point to extras slice-procedure.md:56. | no |
| tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh | DELETE (C5) | 2375 | Every arm runs the builder. | no |
| plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh | DELETE (C5) | 2316 | Builder cascade only. | no |
| tests/dispatch-parity/ | DELETE (C5) | 1798 (29 files) | Builder golden corpus. | no |
| plugins/mega-sdd/tests/design-intelligence/test-dispatch-prompt-design-system.sh | DELETE (C5) | 44 | Validator harness. | no |
| tests/fixtures/code-delivery/dispatch-prompt/ | DELETE (C5), `git rm` + `rm -rf` leftovers | 240 (5 files) | Manual fixture. Ignored `.dispatch-prompt-state.json` and `.cache/` files sit on disk. | no |
| plugins/mega-sdd/tests/scan/test-symbol-index-reuse.sh | REWRITE (C5) | 231 | Delete R2 over **:122-211**, not :210 (otherwise `bash -n` fails). | no |
| tests/comment-diet/test-code-style-slice.sh | DELETE (C5) | 118 | Builder T2 slice. | no |
| tests/reuse-awareness/test-bolt-reuse-first.sh | DELETE (C5) | 13 | context-enrichment and bolt-implementer pins. | no |
| tests/scenarios/scenario-8-starterkit-aware-generation.md | REWRITE (C5), verifier-corrected | 146 | Step 4 already fails on inline. | no |
| tests/hooks/agent-dispatch-gate.test.sh | trim G in C3, DELETE in C6b | 194 | The F-09 pins stay live until C6b. | no |
| tests/hooks/attempt-cap-gate.test.sh | DELETE (C4) | 138 | Attempt cap. | no |
| tests/state-anchor/test-gate-binding-freshness.sh | **KEEP (refuted)**, forced re-pin (C6a, §2b) | 371 | Case 18 must stay intact, case 19 was unaccounted for, and the ALLOW cases need re-pinning. | **YES** |
| tests/wave-rail/ | DELETE (C5), after the C0 moves | 158 | Keep the `inflight_units` assert and the 120 s default elsewhere. | no |
| tests/audit-hardening/test-t3-expects-gate.sh | **KEEP (refuted)**, forced re-pin (C6a, §2b) | 76 | **B4** is the only pin that the inline Skill entry is never held by F-18. | **YES** |
| tests/v9/test-migrated-conflict-blocks.sh | REWRITE (C6b) | 214 | Point a5 at the Skill entry (still denies `binding_missing`). | no |
| tests/scripts/test-predictive-preflight.sh | REWRITE (C6b) | 444 | Drop the Agent half of §12. | no |
| tests/weighted-routing/test-spawn-ceilings.sh | **KEEP (refuted)**, forced re-pin (C6b, §2b) | 362 | C8b must become a Skill-entry pin on FIXJ (measured 91 spawns, above C8's 90). | **YES** |
| tests/audit-hardening/test-t3-panel-evidence.sh | **KEEP (refuted)**, forced re-pin (C3, §2b) | 140 | B/C5/C6/D1 test a gate the inline lane runs until C3. Fixture dependencies must be preserved. | **YES** |
| tests/w2-fast-lane/test-l1-dispatch-plan.sh | HOLD→P3b | 58 | derive-ready-units is HOLD, so it stays green. | no |
| tests/w2-fast-lane/test-w2-lite.sh | REWRITE, reduced (d in C3, e in C4) | 54 | c/f/g/h pin KEEP/HOLD files and stay. | no |
| tests/sprint-lane/test-sprint-lane.sh | HOLD→P3b (no change) | 98 | Fan-out flags and batch-and-fanout are kept. | no |
| tests/token-efficiency/test-2a2d-chain-parallel.sh | REWRITE, forced subset (:61-62 in C2, :100 in C6b) | 158 | All of 2d (extract `--max-parallel`) stays. | no |
| tests/scenarios/scenario-5-multi-squad-parallel.md | HOLD→P3b | 161 | Needs the fan-out relocation first. | no |
| tests/scenarios/scenario-6-recovery-from-halt.md | REWRITE (C7, one pass) | 816 | Keep the file (6d scan target). No TOPO_BAD phrasing, no screen headings. | no |
| tests/surface/test-p11-owner-parity.sh | REWRITE (S6c/S6e in C3, S6b in C5, S6d in C7) | 108 | Keep S4, S5a, S6a. | no |
| tests/skill-triggering/execute-bolts.test.md | REWRITE (C2–C6b), by case ID | 242 | Keep `--inline` (h13) and `detect-after` (6d). BH7 is HOLD. | no |
| tests/v9/test-no-removed-skill-refs.sh | REWRITE, minimal extension (C9) | 50 | Assert the 7 agent files are gone. Skip the plugin-wide agent-id scan (the bridge is KEEP). | no |

### KEEP items (from the audit's KEEP list)
| path | verdict | why |
|---|---|---|
| scripts/_lib/unit_tier.py | KEEP (docstring touch in C4) | Sole importer after P3 is validate-unit-spec.sh. |
| references/framework-conventions/ | KEEP, packs decision → P3b | About 24 blurbs name the builder, the standards/security lens or "Iron Rule 6 (agents/bolt-implementer.md)". `validate-pack.sh` still requires `## Code style`. |
| tests/v9/test-inline-lane.sh | KEEP, re-pinned per commit (§3) | The P2 inline regression suite. |
| tests/audit-hardening/test-l0-vacuous-advisory.sh | KEEP (case F removed in C7) | GROUND L0 advisory. |
| tests/lanes/test-lanes.sh | KEEP (optional fixture re-pin in C9) | Still green. |
| scripts/analyze-parallelism.sh | KEEP | Numbers the `--sprint=` waves. |
| `<vault>/bolts/U-*/proposed-fix.md` | KEEP | Unmeasured, not shown to be unnecessary. |
| tests/god-review-s6/test-6d-doc-pins.sh | KEEP, re-pinned (§3) | Needs the lockstep EB-DOC-5 edits. |
| tests/halt-registry/test-family-split.sh | KEEP, no edit | The C7 lockstep keeps a1/d1 consistent. |
| scripts/run-code-gates.sh | KEEP | Runs on every inline task. |
| orchestrate-flow/references/{checkpoint-protocol,factory-ledger-contract,factory-routing,handoff-consumption,predictive-checks,sync-digest}.md | KEEP (predictive-checks edited in C6b/C7) | — |

---

## 2) REWRITE surgery

### 2a. Non-refuted REWRITEs applied in P3

**skills/execute-bolts/SKILL.md.** Pre-flight item numbers stay unchanged, because derive-exec-plan.sh:336 and inline-run.md:14 cite them. Every commit must stay ≤500 lines and be net-negative on `skill_md_total_bytes`, which is at its ceiling. Bump `version:` once, in C2.
- **C2**
  - `--agents` bullet (:28) → the retired line from §5.
  - `--inline` (:29): drop ", with `--agents` it is a usage error".
  - Frontmatter description: drop the per-unit agents + review panel `--agents` clause.
  - Intro "two modes" sentence (:9) → one mode. Keep the announce line and its `mega-sdd-trace:execute-bolts` tag.
  - Keep byte-identical: the `--parallel`, `--sequential`, `--per-squad`, `--worktree` and `--sprint-checkpoint` bullets (fan-out HOLD; they read "(`--agents` only)" and are now unreachable), and the specialist rows at :196-197.
- **C3**
  - Delete the `--review-panel` bullet (:39) and fold it into the retired line.
  - Delete Step 4 (review panel, :94) and the panel sentence at :76.
  - :160 whitelist bullet → "plan Global Constraint + the commit step's `git show --stat HEAD` check + B3".
  - Delete the :195 review-panel row.
  - Remove `review-panel.md` from the :186 "replaces" list.
- **C4**
  - Delete the `--model-tier` (:40) and `--no-escalate` (:41) bullets and fold them into the retired line.
  - `--max-retries` (:33) → "default 3; `.mega-sdd/config.yaml max_retries:` sets the project default; a prose cap per task (`references/inline-run.md` (a))". Drop the xs→1, HOOK-ENFORCED and resolve-review-tier legs.
  - Delete Step 2 model routing (:80) and :105-108.
- **C5**
  - Delete Step 4.5 (:97-122), :120, the :140 "Step 4.5 is NOT skipped" clause, the :165 starterkit-slice rail and the script-owned specs block (:204-207).
  - :186: drop `context-enrichment.md` and `bolt-dispatch-prompt.md`.
  - Pre-flight 5 rationale (:71) → "so the JIT bind reads a fresh index (`rebind-units.sh` rebuilds a stale one)". Re-pin test-symbol-index-reuse :218 in the same commit.
- **C6b**
  - Delete pre-flight 1 (:61). :59 → "The inline run applies every check below; `references/inline-run.md` (b) runs the 3.9 bind."
  - 3.9 (:68) → a pointer that keeps, word for word: "runs on every run", "Read `references/jit-bind-and-quarantine.md §3.9`", "`text` claims via ladder E3 verbatim" (M2 moat pin), and "execute-bolts runs the lite lane only; `--lite` is accepted as a no-op marker" (test-lite-lane:59). Do not write the string "(every run)" (h15).
  - Before deleting §Procedure (per unit, `--agents`) :74-95, move these out:
    - (i) the step-5 `run-acceptance-tests.sh` contract (L0 syntax rung, exit 1 → build_broken/acceptance_red, pending_manual) into the B4 paragraph;
    - (ii) the MANDATORY `target_hashes` line into §Outputs;
    - (iii) one runnable `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-code-gates.sh" …` form into B4/L0 (test-run-code-gates:253-254);
    - (iv) the `mkdir -p … <vault>/bolts/U-XXX` + `bolt_artifacts_missing` sentence into §Outputs (test-skill-has-mkdir-step:5-6).
  - Verify-unit path :138-140 → "the plan's verify task".
  - Related skills: drop `subagent-driven-development`.
- **C7**
  - `--resume` / `--rollback` (:50-51) → retired lines.
  - §Partial-state (:150-152) → one line: "An open run resumes from its `_exec-plan-*.md` (`references/inline-run.md` (b))."
  - Delete the :198 row.
- **Unchanged:** the refused flags (`--force`, `--no-code-gates`, `--no-full-suite`, `--force-skip-postflight`) and the :55 anti-bypass box (test-gates-wired:24-25, hard-rule-scan.md:154); §Hand-off (verbatim); :128 per-bolt drift paragraph and :144 §Batch paragraph (HOLD).

**commands/mega-sdd.md.** It is in the T01 default trace, so every edit must be net-negative.
- **C2**
  - :3 argument-hint: drop `[--agents]`, `[--no-escalate]` and the bare `<tier>|` form. Keep `[--inline]` and `[--model-tier=<role>:<tier>]`.
  - :74 → "`--model-tier=<role>:<tier>` — resolved by orchestrate-flow (`orchestrate-flow/references/chain-execution.md` §Model-tier override resolution; roles `extract-intelligence-module`/`-verify`)", followed by the retired line from §5 for the bare form and `--no-escalate`.
  - :75 → the `--agents` retired line from §5. It still implies `--guarded`, so a user who asked for guarded gets it.
  - :76 → "`--inline` — accepted no-op alias of the default inline run: forwarded as `execute-bolts --all --lite --inline` (changes nothing), never to `plan`; implies `--guarded`."
  - :38: keep "`--inline`, `--agents`) imply `--guarded`" (h7b).
  - Delete :127 (the "W2 fast lane (`--agents`)" line).
- **C6b**
  - :8: drop only the "matcher includes `Agent` but gates ONLY a `bolt-implementer`" clause. Keep "NEVER offloaded to the Agent" (test-p6:50).
  - :50 and :77: drop the "(`--agents`: pre-flight 3.9 …)" parentheticals.

**skills/orchestrate-flow/SKILL.md**
- **C2**
  - :126 → "`--agents`: retired — say so in ONE line (§5) and run the hop inline (`execute-bolts --all --lite`)."
  - :127: keep `execute-bolts --all --lite --inline` (h7) and drop ", with `--agents` a usage error".
  - Bump the version.
- **C6b**
  - :120 → "`--full-bind`: the re-bind hop becomes `rebind-units.sh --units=all` (as `commands/sync.md`)". Keep the `--full-bind` token.
- Keep :55, :62, :88 (test-e-lean-profile:67 pins "review-panel risk tiering") and :162.

**orchestrate-flow/references/routing-rules.md**
- **C2**
  - :58: strip the carried-`--agents` tail. At least 3 rows must still match `execute-bolts --all --lite` (test-2a2d:59-60).
  - :85: collapse into :84 by dropping "(with `--agents`: `execute-bolts --per-squad --agents`)".
  - Delete :135-136 and the `--per-squad` sentence at :141-142. Keep :131 and :133-134 (squad-ID validation for `--squad=`), and move :137-139 out of the `--agents` bullet.
  - Keep the :232-235 tombstone, because the ToC at :21 links to it.
- **C6b**
  - :64: drop "or per dispatch under `--agents`".

**orchestrate-flow/references/diagnostics-procedures.md**
- **C2:** :132 → "`parallelism_speedup` ≥ 2: suggest `execute-bolts --sprint=<n>` for the first incomplete sprint — never suggest the halting form (an earlier incomplete sprint halts `sprint_blocked_by`)." This keeps the test-2a2d:102-103 phrase.
- **C3:** :68 "merge = 1 bolt + 1 panel" → "merge = 1 bolt". Keep the `merge_candidate: U-00X..U-00Z` prefix (test-unit-granularity E4).

**orchestrate-flow/references/convergence-loops.md (C6b)**
- Copy row :22's action ("with grounded recommendations; it writes each choice via `write-unit-binding.sh --resolve`") and its safety condition ("Recommendation confidence ≥ 0.80; else stop") into row :23, then delete :22.
- Rewrite the algorithm at :58-70 (3.9b, re-dispatch) as the inline scope-run re-bind.
- Rewrite the worked example at :84-95 as an inline scope run: the derive-exec-plan halt → `resolve-oq --binding` → re-run.
- Keep rows :25-26 (fan-out HOLD) and these phrases: `scope: close`, "Close: reviewed", "default 3; canonical", "follows its taxonomy class", "self-resolve C1". Do not add "Cycle N/5".
- Apply the same rewrite to resolve-oq/references/auto-memory-handoff.md:57-69.

**orchestrate-flow/references/handoff-contract.md**
- **C3:** :79 and :83 example role `code-quality-reviewer` → `extract-intelligence-module`.
- **C5:** :213 → "execute-bolts passes the block through from `starterkit-context.yaml` (no execution-time reader)".
- **C6b:** :255 → "each unit is bound up front and again at its task".
- **Keep** :69-75, :147, the starterkit block :205-231 and the :231 type-check paragraph.

**skills/using-mega-sdd/SKILL.md (C6b)**
- :35 Hard gate → "… quarantines the unit at `execute-bolts` run start (`binding_conflict`) until `resolve-oq --binding` settles it."
- :75 "at dispatch" → "at run start".
- :85: drop "(`--agents`: pre-flight 3.9, dispatch gate)".
- Recorded re-baseline: anchor core 3,988 → 3,963 B, compact core 1,625 → 1,600 B.

**references/model-tiers.md**
- **C3:** delete rows 16, 17, 19, 20, 21 and 21b (:79-84). Update the :39 and :48 examples, reword the :77 rationale, and fix the :97 lens-override note.
- **C4:** update the :30 haiku rung example.
- **C6b**
  - Delete rows 15 and 22 (:78, :85), the `inherit` subsection (:50-58) and the Office runbook (:152-157).
  - Header :6-7 → "parity with rows 6, 23".
  - :91-98 and the examples at :104-119 → extract roles.
  - Fix the :87 distribution line.
- Keep rows 6 and 23. The Guard 8 regex still captures a non-empty set.

**references/project-config.md**
- **C3:** delete `review_panel:` (:33-34). In :57-60, keep `preview_url` (uat-run.sh reads it) and drop the capture-ladder and design-lens clause.
- **C4:** `max_retries` (:49-52) → "default for the inline run's per-task fix cap (prose, `references/inline-run.md` (a)); nothing counts it".
- **C6b:** :35-39 → `model_tiers:` with an `extract-intelligence-module: sonnet` example. :30 → "JIT bind up front + per task".
- HOLD :40-48 (`parallel_max`).

**execute-bolts/references/code-gates.md (C3)**
- :1 title and :3: drop "under/BEFORE the review panel".
- :16: keep "range = the unit's own `<BASE>..HEAD`"; drop the panel re-dispatch and `--parallel`/batch-and-fanout sentence.
- :27: drop "for the panel (spec D5)"; repoint "runnable form lives in SKILL.md Procedure step 3" to the derive-exec-plan task step.
- :35: delete (the panel-evidence halt).
- :37 → "SKIPs ride in `l0-results.json`".
- :42: drop "a panel re-dispatch re-enters".
- :52 → "at post-flight per the plan's task step".
- :58: drop "before the panel dispatches".
- :62 → "FINDINGS (non-blocking, recorded in `l0-results.json`)".
- :63 → "SKIPs ride in `l0-results.json`, committed with the unit's evidence".
- :65: fix the "(below)" pointer.
- Delete :93-95.
- **Keep** :100 (`--no-code-gates`; SKILL.md keeps the refused flag). Keep every token pinned by test-gates-wired:15-19, test-run-code-gates:255-257, 6d:49/:68 and p7 M7 (`l0-results.json`).

**execute-bolts/references/jit-bind-and-quarantine.md**
- **C6a:** delete §3.9b (:197-215) and its ToC entry (:12). :86 "or in a 3.9b `_claims.json`" → "or in the unit's `_claims.json`". :226 → "`binding_stale` (run-start freshness, `derive-exec-plan.sh`)".
- **C6b:** §3.9
  - Retitle it as the binding contract, without starting with "every run —" (h15 checks the first 400 characters).
  - Delete steps 0/1 (:20-36) and the wave `--claims=<vault>/bolts/_wave-claims.json` invocation at :38 (point to the per-unit `bolts/U-XXX/_claims.json` from `rebind-units.sh`).
  - Keep :39-72 verbatim. In particular, :66 keeps the validator marker (test-p6) and :67 keeps "FAIL with `conflict_unresolved` drops ⇒ **halt `binding_conflict`**" (test-4d:171).
  - :73-75 → "The gate is the run-start quarantine (`derive-exec-plan.sh`), each task's re-bind, and `conflict_bypassed` at the run boundary and on Stop."
  - :77 → "`sync --full-bind` = `rebind-units.sh --units=all`". The `--full-bind` token stays (test-full-bind:37).

**references/halt-protocol.md + halt-families/bolts.md (C7)**
- halt-protocol.md: drop the `partial_state_corrupt` token from the :75 enum and delete the :193 row. :187 → "`bolt_repeated_partial_failure` — the same halt fired twice on one unit with different proposed fixes (propose-and-confirm cycle). ALWAYS STOP."
- bolts.md: delete :33-35 and give :13-15 the same trigger text. The file must stay at or under 14,000 B (test-family-split b2).
- C5 text-only edit: halt-families/flow.md:111, drop the "/ execute-bolts build-dispatch-prompt.sh soft_halts[]" clause.
- C6b text-only edits: bolts.md:115/:151, flow.md:115, bind.md:3/:15, halt-protocol.md:163-164/:185/:315 ("pre-flight 3.9" and "bolt-implementer" → "the up-front bind / a task's re-bind", "the implementing session"). Tokens are unchanged.

**skills/plan/references/* (C5 pack/slice lines, C6b agent/dispatch lines)**, verifier-corrected:
- plan-procedure.md:46, :83.
- task-typing.md:24 → run-start quarantine + `conflict_bypassed`.
- unit-schema.md:
  - :3 → "by execute-bolts"; :81 → "no script reader; the inline implementer reads the unit in full"; :109 → "recorded in `l0-results.json` (advisory)"; :165 → shared only with validate-unit-spec.sh; :184; :305; :334.
  - :306: whitelist layers = plan Global Constraint + commit-step `git show --stat HEAD` + B3. It must keep `--whitelist-scan` and "block the next `execute-bolts` with `whitelist_violation`" (test-5d GU-WHITELIST-6).
- unit-procedure.md:34, :61, :68, :103 (same whitelist wording), :104, :116. Keep "xs body diet … xs_body_advisory" (test-xs-body-advisory:72) and "granularity-independent" (test-unit-granularity).
- validation-passes.md:68/:72: pack rules reach execution only as plan-authored Hard rules and pack-driven gates. No slice is injected.
- decomposition-rails.md:102, :125.
- unit-grammar-cheatsheet.md:20.
- adversarial-test-prompt.md:39.
- execute-bolts/references/hard-rule-scan.md:158 (the same false slice claim).
- Leave the `cross_squad_interface_draft` promises at unit-schema:102/:322/:365 (fan-out HOLD; gap G3).

**extract-intelligence (C5)**
- SKILL.md:200: keep "the JIT bind consults the output as rung 5 … (E3)" and drop the build-dispatch-prompt clause.
- references/prd-kontrak-template.md:341-342: the consumer is `plan --kb` (kb-input.md:89/:130/:153).
- domain-extractor.md and claim-verifier.md are untouched.

**docs/gateway-contract.md**
- **C3:** row :11, drop "lens panel, verifier" and the emitter "controller (lens/verifier)".
- **C5, after owner sign-off O1:**
  - Row :11: drop "/ `mega-sdd-trace:execute-bolts:<unit-id>`", "bolt implementer … jalur `execute-bolts --agents`" and the builder emitter.
  - **:17** (not :18): "per fase/unit" → "per fase".
  - :100: the pin tests become test-inline-lane d5/h4/h13, test-honesty-docs h8 and test-gateway-trace.
- Row :11 must keep "execute-bolts --inline" + "mega-sdd-trace:execute-bolts" on one line (h13), and "Step 9.5" + "mega-sdd-trace:plan" (h8).

**Hooks** (line numbers at HEAD). Run `bash -n` after every hook commit.
- **C3:** delete L1108-1119.
- **C4:** delete L1285-1325 and L1390-1414 (the `elif ATTEMPT_PATH:` block).
- **C5:** delete L133-138, L329-373 and L1670-1696, and header items 4-5 (L17-23).
- **C6a:** delete L1120-1132 and L1133-1284. At L1415, keep `' 2>/dev/null)` and delete L1416-1420.
- **C6b**
  - Delete L112-118 and L303-325.
  - Delete L559-569 and L572-583, but **keep L570-571**.
  - Header item 3 (L13-16) and L55 → matcher `Skill|Bash|Edit|Write`.
  - hooks.json:24 → `"Skill|Bash|Edit|Write"`.
- **Leave unchanged:**
  - L922 `--units="${AGENT_UNIT:-}"` and the L959 env passthrough (empty on the Skill entry, which is today's behaviour).
  - L968-1007 (refuted; `IN_RUN` is now always False).
  - L950 `--panel-scan` (a no-op; C8).
  - The protected-set regexes (refuted).
  - L1029 text: reword "3.9b" only (C6a).

**scripts/validate-bolt-artifacts.sh**
- **C3:** delete L1006-1111. L68 → `--panel-scan) : ;;  # accepted no-op: open plans still pass it` (keep for at least one release).
- **C6b:** comments :41 and :1381 → "halts-and-handoff.md §Provenance trailer enforcement".

**scripts/_lib/freshness.py (C6a), reduced**
- Delete the :768-774 `dispatch_prompt_stale` branch, `_BSHA_RE` (:703), `gate_main` (:827-844) and the `--gate` dispatch (:1158-1159).
- **Keep** the `gate_check(root, vault_dir, uid, prompt_path=None)` signature. derive-exec-plan.sh:226 calls it with `None`, and a signature change would be swallowed there as `not_evaluated`, quarantining every unit.
- Comments :701, :735, :795: "3.9b" → "a per-unit re-bind".

**Other small edits**
- **C2:** `scripts/_lib/state_probes.py` :1349-1352 → "# The default run is inline (one context, plan order)." (The AST is unchanged.)
- **C3:** `scripts/validate-reuse-duplication.sh` header comments :19-20 and :27-28 only.
- **C4:** `scripts/_lib/unit_tier.py` docstring :2-6.
- **C6b:** `scripts/build-fsd-core.sh:321` default label `"bolt-implementer"` → `"execute-bolts"`.
- **C7:** `scripts/ground.sh` Guard 2 (see §2b note on `ts_fname`).
- **C9:** `scripts/derive-state.sh` comment :96-100 → label findings/attempts/dispatch-prompt as legacy `--agents` evidence that stays tracked. Body bytes unchanged; net lines ≤ 0.

**C7 partial-state cluster**
- `ground.sh`:
  - Delete L128-133 and L135-167, and **move L134 `ts_fname` up next to `ts` (L55)**. Guard 7 uses it at L369, and a NameError there would be swallowed.
  - Drop the `vault_prefixes as _vl_prefixes` alias (:70, :72-73).
  - Fix the comments at :25 ("9-guard"), :45 and :64-65.
- `validate-preflight.sh`: delete L360-368 and L498-502.
- `predictive-checks.md`: :217 "4 feasible static checks" → 3; delete :226-231.
- `hooks/session-start:254`: comment.

**Tests (REWRITE items)**
- **test-s7c (C3):** keep :20-22, :29-34, :38-70; drop :23-28, :72-106; update the header.
- **test-b3 (C3):** delete :89-100 and drop RP/DR/BI from the :20-23 precheck. Header :4-6.
- **test-p3-oq-defer-risk-router:** C3 delete :239-246. C4 delete §1/1b (:36-208), `RT` (:15), `WORK`/trap and `mkunit`; update header :2-9.
- **test-playwright-embed:**
  - C3: delete F (:136-167).
  - C5: delete E4 (:128-134).
  - C6b: re-point E1/E3 to `plugins/mega-sdd-extras/skills/slice-design/references/slice-procedure.md:56`; re-baseline C1 → 3963 and C1b → 1600 (recorded decision). Also extras:98 → 3963.
- **test-symbol-index-reuse (C5):** drop DISPATCH from :15-16; delete :122-211, :214-217, :220-224 and :227-228; update :218-219 to the new pre-flight-5 wording; keep :225-226; header :6-8.
- **test-migrated-conflict-blocks (C6b):** a5 → a Skill `mega-sdd:execute-bolts` payload on the same fixture. Assert a deny naming `binding_missing`, with CONFLICT-1 read via `summ`.
- **test-predictive-preflight (C6b):** delete `hook_agent()` :387-388 and the assertion at :395-398. Reword :341-344 and the :380 header. Also update validate-preflight.sh:772 and predictive-checks.md:105, :330.
- **test-p11 (C3/C5/C7):** drop S6c (:92-96), S6e (:101-104), S6b (:86-91) and S6d (:97-100). The `S6d` label must not be reused (weighted-routing has its own).
- **test-2a2d:** C2 drop :61-62; C6b drop :100.
- **test-w2-lite:** C3 drop d (:39); C4 drop e (:40).
- **execute-bolts.test.md** (edit by case ID; the audit's line numbers are off by 2):
  - C3 or C4: delete AC1-AC4 (174-189).
  - C5: delete EB-SK1/EB-SK2 including the :197 heading.
  - C6b: delete BI3 and BH0 (62-64). Move BJ1's one-screen KEEP_VAULT/KEEP_CODE/SPLIT halt, "binding.json is never edited (hook-guarded)" and `write-unit-binding.sh --resolve=…` into BI1/BI2 before deleting BJ1.
  - C2: delete BH4/BH5/BH8 (`--per-squad` via `--agents`).
  - Rewrite P1/P2, the Mode line, BH2 (70-72, → prose cap) and BH6.
  - Pass criteria at :193: drop the AC sentence; `(BJ1)` → `(BI1/BI2)`.
  - BH7 is HOLD.
- **scenario-11 (C6b):** lead with config `model_tiers` for the two extract roles; keep "Verify override applied"; add no screen headings (test-project-scale sweep).
- **scenario-8 (C5):** fix :4, :6, :59, :61-76 (drop Step 4), :112, :119, :121, :136, :142, :144, :145. Keep the legacy starterkit readers (resolver, validate-unit-spec Check 3, conformance, Guard 7, emit-agents-md). Do not claim that pack rules reach code "only through the gates" (plan authors pack-derived unit content).
- **scenario-6 (C7), one pass:**
  - Delete :383-401.
  - :714-743 → propose-and-confirm-cycle cause, and drop `cat …/partial-state.json`.
  - :457 → `/mega-sdd --resume`.
  - :449 provenance pointer → `units/U-XXX.md`.
  - :75, :166, :16, :170, :785/:794 wording.
  - :436-446 (`dispatch_prompt_too_large`) → delete.
  - Keep `--force-skip-postflight` and `bolt_introduces_locked_drift` (HOLD); keep :22.
- **test-no-removed-skill-refs (C9):** assert the 7 agent files are absent, domain-extractor and claim-verifier are present, and no `skills/*/SKILL.md` or `commands/*.md` names a deleted script. Update the header comment. Do not add the plugin-wide agent-id scan or the widened sibling glob; the verifier measured 42 false failures at HEAD.
- **benchmarks/scripts/vanilla-ab-batch.sh (C2):** delete :41, `guarded-agents` from the :47 case list, and header :5-9 ("all four" → three).

**Repo docs (C6b, when the last `--agents` surface goes, same release)**
- root README :207, :208 (binding, acceptance evidence, bolt report), :297 + **:315** (`REVIEW --> CHECK --> OUT`; remove the IMPL/PANEL nodes), :323, :388/:476 (agent count 2), :389, :393, :405. Add a "Removed in P3: `--agents`" line next to "Removed in 9.0".
- CONTRIBUTING:20: drop "and under `--agents` its dispatch is denied (`binding_conflict`)" and attach "until `resolve-oq --binding` resolves it" to the quarantine clause.
- root CLAUDE.md:13: drop "`--agents` keeps …".
- plugin README:
  - Agents tree :157-161 → 2 agents.
  - Gate list :203-209: drop panel-evidence, in-run acceptance-expects, binding-freshness, attempt cap and the Agent-dispatch sentence; **add** conflict-bypass.
  - :104, :112, :183, :212, :248 (+ the :247 orphan header), :260 ("reuse slice").
  - :188: the index feeds the bind, and the duplication sweep stays as an analyze advisory.
  - :193: packs reach units through plan-authored Hard rules and pack gates.
  - Label :135/:138 as per-unit-path history.
  - HOLD :243 (`parallel_max`).
- docs/mega-sdd/architecture.md:35, :57, :65 and upgrade-from-old-version.md:35, :50, :127, :128, :199, :278, :280, :344: add a P3 section. C9 is acceptable if in the same release.

**Spec**
- **C1:** append `### 8.6 P3 outcome` as a skeleton: decision, deletion list, the honest-loss list (G1–G9 in §6), and "`--agents` retired". Mark the §5 P3 row, and add amendment rows `| 1a |`, `| 2a |`, `| 3a |` under §7 (starterkit slice gone, pack rules no longer reach the bolt, `--per-squad` retired). Do not touch §8.1–8.5. Do not name `_run.json` or `bound_since` (h9/h10).
- **C9:** fill in the measured numbers.

### 2b. Refuted-KEEP files: forced and lockstep edits only

Each of these needs a re-audit before commit.

| file | commit | exact change | why forced |
|---|---|---|---|
| plugins/mega-sdd/CLAUDE.md | C3 | :35: delete the panel-evidence (F-07) clause; "seven scan states … panel" → six. **Keep** "`_wave-claims.json`, `_claims.json` and `dispatch-prompt.md` join the Write/Edit anti-self-bypass set", because the hook still guards all three. | Would state a gate that no longer exists. |
| same | C4 | :35: delete the attempt-cap clause. | Same. |
| same | C5 | :35 Advisory list: drop "dispatch-prompt". | Same. |
| same | C6a | :35: delete the in-run acceptance-expects and binding-freshness clauses. Gate count → six (orphans, batch-suite, postflight, whitelist, acceptance, conflict-bypass). Do not write "the seven execute-bolts artifact gates" or "ALL SEVEN bolt-stage" (h12). :27 → "freshness is checked at run start (`derive-exec-plan.sh` → `_lib/freshness.gate_check`, quarantine `binding_stale`); re-bind with `rebind-units.sh --units=U`; a second stale verdict at the same HEAD is `rebind_exhausted`". | Same. |
| same | C6b | Invariant #2 (:22): delete "Under `--agents` the hard block is the PreToolUse hook on that unit's `bolt-implementer` Agent dispatch …". Keep "By default", "derive-exec-plan.sh", "conflict_bypassed", "--inline", "§8.4", "2026-09-27" and "evasion". The dated exception → "the per-dispatch path was removed in P3 (spec §8.6); `--inline` stays a no-op alias". Also: :3 and :21 clauses; :50 (`--agents` wave/dispatch_plan); :55 Agents bullet → domain-extractor and claim-verifier, with the provenance-trailer fact ("points at the tracked unit file `units/U-XXX.md`") moved to the pipeline bullet; :57 matcher text; :76 drop the bolt-implementer `model: inherit` exception; :88 drop the matcher aside and keep "context: fork … PILOT LIVE" on one line (test-roadmap :26/:29); :104 → "per-dispatch path removed in P3 (spec §8.6)". Keep :48. | Invariant #2 would describe a hook leg that no longer exists. |
| tests/audit-hardening/test-t3-panel-evidence.sh | C3 | Keep C3/C4 (stamped `lens-inputs/U-001/l0-results.json` from `run-code-gates.sh --write`), the E legs for l0-results, findings.json and review-tier.json (their guard tokens stay), the sanctioned `run-code-gates.sh` pass, and F (provenance on postflight, acceptance and `_batch-suite.json`). **Preserve the fixtures:** `mkunit U-001` (L50) without the router call, the bolt commits at L59/L73 moved out of A/B, and L107 `run-full-suite.sh --runner=true` moved out of D (it writes the `_batch-suite.json` that F reads). Delete A, B, C1/C2/C5/C6, D and the merge-panel sanctioned pass. Rename to `test-evidence-provenance.sh`. | Pins panel-scan and merge-panel, both deleted in C3. |
| tests/audit-hardening/test-t3-expects-gate.sh | C6a | Delete L47-54 (dispatch-prompt/`agent()`, B1-B3) and L57-60 (B5). Keep `HOOK` (L18), `drive()` (L46) and **B4** (L55-56), reworded: "the execute-bolts Skill entry (inline's only gate) is never held by acceptance_expects_missing". Header L11-13. | B1-3/B5 drive the deleted F-18 leg. B4 is the only pin that the inline entry stays open. |
| tests/state-anchor/test-gate-binding-freshness.sh | C6a | Replace `dispatch()` (L67-71) with a direct `gate_check(root, vault, "U-001")` harness. Re-pin the reason table (binding_stale, diverged, stamp_unreachable, stamp_null, uncommitted_in_scope, unit_changed_since_bind, binding_legacy, absent, unparseable, rebind_exhausted, not_evaluated, glob targets, skip-worktree, gitignored scope, two-wave index_stale) **and** the ALLOW cases 1, 2, 4, 9, 23a, 27a, 29 and 30. Keep 0, 25, 26 and **18 unchanged**, all three paths including `_wave-claims.json`. Delete 6, 12, 13, 15b, 17, 19 (layout-2 in-run D9 leg; amend the state-anchor spec §3 "layout-2 legs stay" sentence) and the :136/:212 "3.9b" remedy-text checks. Re-pin case 15 as "gate_check raises → derive-exec-plan quarantines `freshness: not_evaluated`". The :166 fault-injection string still matches because the signature is kept. | The leg is deleted, and its reasons survive in gate_check. |
| tests/weighted-routing/test-spawn-ceilings.sh | C6b | C8b (L262-277) → a **Skill** `mega-sdd:execute-bolts` payload on FIXJ. Keep the ≤95 ceiling and the `jit_units == 1` assertion. Drop the Agent payload, the `dispatch-prompt.md` printf fixture and the `*binding-freshness*` case. Rewrite the L197-199 note to cite the Skill-entry measurement (91 spawns; owner disclosure O3). | After the F-09 deletion the Agent payload exits at 0 spawns and `jit_units` = 0, so C8b fails. |
| execute-bolts/references/halts-and-handoff.md | C5 | :118 only: cite `check-anchor-freshness.sh` instead of "context-enrichment.md §Re-decided amendments row 4". Keep "Never print a verified count no check produced." | The target file is deleted in C5. |
| same | C7 | :323 only: drop the `partial_state_corrupt` token. | Registry lockstep (6d EB-DOC-5, family-split d1). |
| orchestrate-flow/references/halt-taxonomy.md | C7 | :27 only: drop `partial_state_corrupt`. | Same. |
| execute-bolts/references/halt-recovery.md (HOLD) | C7 | :111 only: drop "3+ partial-state attempts on the same bolt OR". | Registry mirror. |
| orchestrate-flow/references/chain-execution.md | C3 | :60-70 and :81 only: example role `code-quality-reviewer` → `extract-intelligence-module`. The analyze-parallelism row :151, first-run pre-flight :131-135 and :211 stay. | The example would teach a role that no longer exists after model-tiers row 17 goes. |

Unchanged in P3: run-analyze.sh (V16 → SKIP), pre-tool-use L968-1007, the protected-set regexes, vault_layouts.py, paths.md, batch-and-fanout.md, superpowers-bridge.md, propose-and-confirm-prompt.md.

---

## 3) Reference updates and tests

### 3a. Reference updates by file (pointers not already in §2)
- **validate-handoff-binding-units.sh** :813 remedy and :863 `expected` text ("pre-flight 3.9", "3.9b") → "the per-unit re-bind (`rebind-units.sh --units=`)" (C6a/C6b). The legs themselves stay.
- **certify-artifact.sh** :208, :263: the user-facing "execute-bolts pre-flight 3.9" → "the up-front bind" (C6b).
- **Script comments, C6b:** rebind-units.sh :15, :25-26, :157; write-unit-binding.sh :31-32; state_probes.py:1237; validate-preflight.sh:772.
- **Comments, C4/C5:** validate-unit-spec.sh :449-450 (F-18 → analyze advisory, C6a) and :1060 (C4); run-acceptance-tests.sh :269-270 (C6a); resolve-framework-pack.sh :5, :196-199; binding_md.py:5; unit_claims.py:26; ground.sh:354; check-anchor-freshness.sh :5, :191; derive-state.sh:97 (C5).
- **context-enrichment Known-open row 1** → a new `research/2026-09-28-p3-backlog.md` note, not the resolver header, so no script lines are added at the ratchet ceiling. Correct its text: validate-dispatch-prompt.sh:117 was a 12th call site, and it is now deleted.
- **references/starterkit-context-schema.md** :7, :417: drop the execute-bolts consumer (C5).
- **references/ui-design-heuristics.md** :3: the surviving reader is extras slice-procedure.md (C5).
- **references/design-intelligence/modern-baseline.md** :4, :112: left orphaned (design-cluster decision, G6); pointer text only.
- **skills/orchestrate-flow/references/predictive-checks.md** :105, :330 (C6b); :217, :226-231 (C7).
- **resolve-oq/references/binding-mode.md** :3 (C6b label).
- **docs/mega-sdd/architecture.md, upgrade-from-old-version.md** (C6b/C9); **CHANGELOG.md** (C9, including relaxation O2 and no gain claims).
- **benchmarks/runbooks/vanilla-vs-megasdd.md** :114 matcher string, :128 test-standards-lens-h1 pin (C9). p2-inline-vs-agents.md stays as history.
- **Known staleness left for P3b, listed:**
  - About 24 framework packs (and _template.md, _lint.md:49, validate-pack.sh:162) name "Iron Rule 6 (`agents/bolt-implementer.md`)", the builder T2 slice or the standards/security lens.
  - superpowers-bridge.md §Dispatch order and §Per-unit flow name the deleted agents.
  - paths.md :51, :52, :55-57, :80, :101-102, :146, :273, :301, :318.
  - halt rows for `dispatch_prompt_too_large`, `panel_evidence_missing`, `l0_evidence_missing`, `review_critical_unresolved` and `bolt_introduces_locked_drift` (now emitterless) in halt-protocol, bolts.md, halts-and-handoff:323 and halt-taxonomy:19/:21.
  - chain-execution.md:131-135.
  - The wave commit rail (the PreToolUse hook denies `git add -A/--all/.`, `git commit -a/--amend`, `git stash`, `git reset --hard` while a unit's `dispatch-prompt.md` is newer than its `postflight.json`) is still described as live in batch-and-fanout.md:26 (KEEP), vault_layouts.py:83 (KEEP) and derive-ready-units.sh:27 (HOLD). C5 removed the rail, so those verbs now pass. Fan-out and done-rule clusters (P3b); the files stay untouched in P3.

### 3b. Tests to delete (57 files, measured)
| commit | files | lines | precondition |
|---|---|---|---|
| C3 | tests/review-panel/ (3), review-lens-seam, round-discipline, security-idioms/test-lens-wired.sh, design-ceiling/ (2), design-aware/ (2), surface/test-p7-bolt-loop-efficiency.sh | 99+38+203+10+57+61+104 = 572 | p7 M8/F1/F2 moved in C0. |
| C4 | size-weighted/test-standards-lens-h1.sh, size-weighted/test-unit-tier-router.sh, hooks/attempt-cap-gate.test.sh | 30+117+138 = 285 | size_proxy cases 1-9 re-homed in C0. |
| C5 | derived-artifacts/test-dispatch-prompt-builder-shape.sh, moat/test-dispatch-prompt-cascade.sh, dispatch-parity/ (29), design-intelligence/test-dispatch-prompt-design-system.sh, fixtures/code-delivery/dispatch-prompt/ (5), comment-diet/test-code-style-slice.sh, reuse-awareness/test-bolt-reuse-first.sh, wave-rail/ (2) | 2375+2316+1798+44+240+118+13+158 = 7,062 | wave-rail pins moved in C0; gateway sign-off O1. |
| C6b | hooks/agent-dispatch-gate.test.sh (G trimmed in C3), boilerplate-diet/test-p2d-agent-contracts.sh (§2-3 trimmed in C5) | 194+108 = 302 | p2d §4 moved in C0. |

Total: **8,221 lines in 57 files.**

### 3c. Tests to re-pin (non-deleted)
| test | commit | change |
|---|---|---|
| tests/v9/test-inline-lane.sh | C2 | h3: the `--agents` line → retired notice, `--inline` no-op alias still asserted (the 3.9 part moves to C6b). h7: drop the `--agents` argument-hint / `--all --lite --agents` asserts and keep `--inline` + version. h7b: the `--model-tier=` line → `<role>:<tier>`; keep "imply `--guarded`". h8: keep the guarded-inline half and assert `guarded-agents` is absent. |
| same | C3 | h15 `cond` (:610): assert `review-panel.md` is absent from SKILL.md. |
| same | C4 | h15 `mr` (:604-605): `--max-retries` asserts "prose" and no longer requires `--agents`. |
| same | C5 | Delete m9b (:515-518). |
| same | C6b | Delete g2 (:315-316); keep g1. h3 (3.9 line wording). h9 (:576-577): drop the two `--agents` asserts and assert "§8.6". h15: anchor (:596-597) `--agents` absent; convergence (:600) `--agents` absent, keep `scope: close` / "Close: reviewed"; root CLAUDE.md (:614) `--agents keeps` absent; README (:615) `--agents` in the "Removed in P3" line; CONTRIBUTING (:617): keep "quarantined at run start" and drop `--agents`. The bridge (:611-612) and spec (:619-621) asserts stay unchanged. |
| same | C8 (optional) | h5: drop "--panel-scan". Delete e8 (:211-213) and the m8b retire half (:463, :467). |
| tests/v9/test-honesty-docs.sh | C6b | h5 (:88): invariant #2 must no longer name `bolt-implementer`. |
| tests/v9/test-gateway-trace.sh | C5 | :32 → `grep -qF 'A("mega-sdd-trace:execute-bolts")' derive-exec-plan.sh` plus the own-line tag in inline-run.md:81. |
| tests/surface/test-p9-audit-phase1.sh | C3 / C7 | C4 (:175-176) → inline-run.md:81. A11c (:152-155): delete. C7: the A2 literal becomes "memory_in_use` · `mode_migrate` · `invalid_handoff` · `verify_unit_writable". |
| tests/delta-hygiene/test-a1-a4.sh | C3 / C6b | Remove the 6 lens/verifier CAPS entries (C3), then `bolt-implementer` (C6b). Keep the `domain-extractor` and `claim-verifier` pins. Header "all 9 plugin agents" → "all plugin agents". |
| tests/god-review-s6/test-6d-doc-pins.sh | C3 / C5 / C6b | C3: :131-147 lens pins; remove review-panel.md from the :49 scan list. C5: remove `bp` from the :123 loop. C6b: :75-77, :123-129. EB-DOC-5 unchanged. |
| tests/efficiency/test-efficiency-pins.sh | C3 | E3 (:28). |
| tests/comment-diet/test-comment-why-rule.sh | C3 / C6b | d, e (C3); a (C6b). |
| tests/comment-diet/test-provenance-trailer-2line.sh | C0 / C5 / C6b | C0: add the validator keys from p2d :102-105. C5: drop f. C6b: drop d, d2, e. Keep a, b, c. |
| tests/reuse-awareness/test-dup-sweep-hardening.sh | C3 | Delete the wiring pins :157-165. Keep the `--json` cases (`--json` is kept). |
| tests/code-gates/test-gates-wired.sh | C3 | Drop only the assertions that read review-panel.md. The bridge assertions stay (bridge KEEP). |
| tests/token-efficiency/test-p3-unit-diet.sh | C3 | (c) :93+ and :101-110 lens wording. |
| tests/unit-grammar-p1/test-xs-body-advisory.sh | C4 | Case b (:59-65): assert `from unit_tier import size_proxy` in validate-unit-spec.sh instead. |
| tests/extract-census/test-prd-kontrak-engine.sh | C5 / C6b | C5: :72 relabel "(plan --kb contract)"; :98-101 → the kb-input.md:89/:130 dual probe. C6b: :112-116 → assert `extract-intelligence-verify` and add a synthetic `\| 21b \| foo-bar \|` fixture row inside the test (the catalog loses its only `[a-z]?` row). |
| tests/state/test-ground-model-tier-norm.sh | C6b | a/a2 (:22-27) → `extract_intelligence_module` / `extract-intelligence-module`. |
| tests/windows/test-pagerank-removed.sh | C5 | Drop the builder `symbol_slice` proof (:72-76). |
| tests/token-efficiency/test-4de-batch-preflight-ptu-debounce.sh | C5 | Drop the RE2 parity arm (:168-172). |
| tests/de-laravelize/test-consumer-migration.sh | C5 | Drop :14-15 from `files[]` and :27-28. |
| tests/delivery/test-delivery-pins.sh | C5 | Drop D3 (:31-38). |
| plugins/mega-sdd/tests/moat/test-bind-codebase-fork.sh | C6b | :79-84: keep "**halt `binding_conflict`** — ALWAYS STOP"; replace "on every `bolt-implementer` dispatch" with the run-start quarantine + `conflict_bypassed` sentence. **Re-point; never drop (moat).** |
| tests/surface/test-p10-when-triggered-refs.sh | C6b | M2 (:118-121): unchanged if the SKILL.md 3.9 pointer keeps the three phrases; otherwise re-point to inline-run.md:37-39 + `^## E3 Text-claim ladder`. |
| tests/audit-hardening, state-anchor, weighted-routing (refuted/forced) | C3 / C6a / C6b | See §2b. |
| tests/skill-triggering/orchestrate-flow.test.md | C2 / C3 / C6b | MS2/MS3 (:111-119), :40, :155 (C2); :306 (C3); R-FACTORY-4 (:74-76), RES5 (:186) (C6b). |
| tests/skill-triggering/auto.test.md, resolve-oq.test.md | C2 / C6b | `--agents` / "pre-flight 3.9" asides. |
| tests/token-efficiency/test-4abc-spawn-tax.sh | C8 (optional) | :99, :105: flag strings without `--panel-scan`; wording "the six scans" (h12 forbids "all six scans"). |
| tests/lanes/test-lanes.sh | C9 (optional) | A2 fixture → `.bolt-conflict-bypass-state.json`; A3 → `bolts/U-001/binding.json` (green either way). |

### 3d. Tests to add (C0, before any deletion)
- **Direct `_lib/unit_tier.size_proxy` test** (e.g. `tests/unit-grammar-p1/test-size-proxy.sh`) with cases 1-9 from test-unit-tier-router. Include the **case-2 fixture** (two `acceptance_test` entries followed by a `binding_refs:` list). It is the only pin of the column-0 stop rule.
- **`tests/v9/test-inflight-units.sh`**: the `vault_layouts.inflight_units` assert from test-wave-commit-rail:75-79. The function is kept.
- **The 120 s default pin:** grep `TIMEOUT=120` in run-acceptance-tests.sh, added to tests/postflight-evidence/test-acceptance-evidence.sh.
- **p7 carried pins** (e.g. `tests/surface/test-p3-carried-pins.sh`): M8 re-pointed to `plan/references/templates/ai-consumer-guide.md` ("Never put a vault claim/flow/OQ id in a CODE COMMENT"), and F1/F2 (halts-and-handoff "Evidence-commit batching").
- **p2d §4 validator keys** → test-provenance-trailer-2line.sh.
- **C7: a GROUND Guard 7 test.** Plant a corrupt `starterkit-context.yaml` and assert the `.corrupt-<ts>` rename. This pins the `ts_fname` carve-out; no test covers it today.

---

## 4) Totals

Measured values come from `wc -l` at 4e1cf166. `≈` marks estimates; the ratchet test re-measures them in C9.

| bucket | deleted | notes |
|---|---|---|
| **Plugin executable: scripts + _lib** | 5,121 (5 whole scripts, measured) + ≈190 trimmed (validate-bolt-artifacts ≈105, freshness ≈28, ground ≈41, validate-preflight 14; +≈10 if C8) ≈ **5,310** | `scripts_total_lines` 45,456 → ≈40,145. The verifier simulated builder + validator alone at 41,183, which is consistent. |
| **Plugin executable: hooks** | pre-tool-use ≈**390** (C3 12, C4 66, C5 85, C6a 170, C6b 57); hooks.json 1 token; stop 0 | `hooks_total_lines` 3,232 → ≈2,842; pre-tool-use 1,819 → ≈1,429. |
| **Plugin prose** | 7 agents (492, measured) + 5 references (1,397, measured) + ≈170 trimmed (SKILL.md ≈60, jit-bind ≈36, model-tiers ≈28, others) ≈ **2,060** | |
| **Repo docs** | net ≈ −40 … +10 | Mostly rewrites. Spec §8.6 adds ≈40. |
| **Tests** | 8,221 in 57 whole files (measured) + ≈800 trimmed in about 30 files − ≈100 added ≈ **−8,900** | The largest trims are test-p3-oq §1 (≈190) and test-symbol-index-reuse R2 (90). |
| **Benchmarks** | T10 dir (28 lines) + 3 lines in vanilla-ab-batch | |

- **Agents removed:** 7 of 9 (bolt-implementer, spec-, code-quality-, security-, standards-, design-reviewer, resolution-verifier). domain-extractor and claim-verifier remain.
- **Hook lines removed:** ≈390, all in `hooks/pre-tool-use`. The `Agent` matcher leg is removed.

**Complexity budget.** Every metric shrinks, so no `raises` entry is needed. Lower each ceiling to the measured value in C9, and never raise one mid-P3.

| metric | ceiling now | expected after P3 |
|---|---|---|
| always_loaded_description_chars | 12,485 | ≈9,820 (−2,613 agents, −≈50 execute-bolts description) |
| skill_md_total_bytes | 279,748 | lower (execute-bolts SKILL.md trim, plus orchestrate-flow and using-mega-sdd); measure |
| t01_lite_commanded_bytes | 464,611 | slightly lower (SKILL.md, jit-bind, model-tiers, using-mega-sdd, orchestrate-flow are traced). The trace itself is **unchanged** (HOLD; see G7). |
| t01_default_commanded_bytes | 40,535 | slightly lower (commands/mega-sdd.md, using-mega-sdd) |
| scripts_total_lines | 45,456 | ≈40,145 |
| hooks_total_lines | 3,232 | ≈2,842 |

`scripts_total_lines`, `skill_md_total_bytes` and `t01_default_commanded_bytes` sit **exactly at their ceilings** today. Every commit must be net ≤ 0 on each metric, which is why the Known-open relocation goes to `research/` and not into a script header.

---

## 5) What `--agents` becomes, and every user-facing flag that changes

**`--agents` is removed as a mode and kept as a thin, recognized token.**
- The per-unit bolt-implementer dispatch, the review panel, the resolution verifier, per-unit model routing, the attempt cap and the per-dispatch hook legs are all deleted.
- The token stays recognized, and still implies `--guarded`, so that:
  - the front door's translation law does not silently drop it (mega-sdd.md:73);
  - a user who typed it gets the guarded lane they meant, with a one-line notice.
- It is removed from the argument-hint.
- The benchmark arm `guarded-agents` is deleted, not left to record inline runs under an "agents" label.
- It follows the same pattern as the 9.0 `--classic` retirement.

| flag / key | where | after P3 | one-line message (said once, then carry on) | commit |
|---|---|---|---|---|
| `--agents` | front door, orchestrate-flow, execute-bolts | retired; runs the default inline run; still implies `--guarded` | `--agents is retired: the per-unit agent path was removed (spec v9 §8.6); running the default inline run.` | C2 |
| `--inline` | same | unchanged no-op alias; the usage-error clause is removed | none | C2 |
| `--review-panel=…` | execute-bolts | retired | `--review-panel is retired: the run closes with one blind review of the whole range.` | C3 |
| `--model-tier=<tier>` (bare), `--no-escalate` | front door, execute-bolts | retired | `--model-tier=<tier> and --no-escalate are retired (no implementer is dispatched); --model-tier=<role>:<tier> still sets extract-intelligence tiers.` | C2 (front door), C4 (execute-bolts) |
| `--model-tier=<role>:<tier>` | front door → orchestrate-flow | unchanged | none | — |
| `--max-retries=N` | execute-bolts | flag kept; always a prose per-task cap, with no hook counting | none | C4 |
| `--resume` (execute-bolts) | execute-bolts | retired. Front-door `/mega-sdd --resume` is unchanged. | `execute-bolts --resume is retired: an open run resumes from its _exec-plan-*.md automatically.` | C7 |
| `--rollback <unit>` | execute-bolts | retired | `--rollback is retired: there is no saga state; revert the unit's commits with git.` | C7 |
| `--parallel`, `--sequential`, `--per-squad`, `--worktree`, `--sprint-checkpoint` | execute-bolts | **text unchanged in P3** (fan-out HOLD). They are inert because they are scoped to `--agents`, and inline-run.md (a) already maps them to "nothing". | none in P3; retired in P3b | P3b |
| `--force`, `--no-code-gates`, `--no-full-suite`, `--force-skip-postflight` | execute-bolts | unchanged (already refused by inline, inline-run.md:24) | none | — |
| `--panel-scan` (script flag; appears in plans on disk) | validate-bolt-artifacts.sh | accepted no-op for at least one release | none | C3 |
| config `review_panel:` | .mega-sdd/config.yaml | ignored (unknown keys are ignored) | none | C3 |
| config `model_tiers.bolt_implementer` / `*-reviewer` | same | GROUND's existing `[self-resolved] model_tier_unknown` notice on every run (C1, never halts; precedent model-tiers.md:68-72) | existing notice | C3/C6b |
| config `max_retries:` | same | default for the prose cap | none | C4 |
| config `parallel_max:` | same | unchanged (read by held code) | none | P3b |

---

## 6) Risks, order of operations, checks

### Owner sign-offs (gates)
- **O1, before C5:** retire the per-unit tag `mega-sdd-trace:execute-bolts:<unit-id>`. It narrows the documented gateway contract, so the gateway team needs a note. `mega-sdd-trace:execute-bolts`, `:turn`, `:plan`, the announce tags and `mega-sdd-note:` are all unchanged.
- **O2, before C3 (release note):** the panel and L0 obligations on legacy `--agents`-committed units stop being enforced. Today they can block inline runs through `--panel-scan`, and after P3 there would be no remedy script.
- **O3, C6b:** disclose the spawn pin C8b move (D30). The Skill entry on a bound fixture measured 91 spawns, above C8's 90 on the unbound fixture; it stays under ≤95.
- **O4, C6b:** the `model_tier_unknown` notice for stale `bolt_implementer` config keys is visible to users.
- **O5, non-blocking, P3b:** the packs cluster decides the fate of `## Code style`, `## Hard Rules emitted` and `## Security idioms`.

### Risks and mitigations
| # | risk | mitigation / check |
|---|---|---|
| R1 | Removing `IN_RUN` (L973) → NameError → the Skill entry **fails open**. This is the refuted item. | L968-1007 stays. Every C3–C6b commit runs the fail-open probe below. |
| R2 | An inherited `GATE_MODE=in-run` / `GATE_SUBJECT` environment reaching the Skill entry once the F-09 block goes. | Keep the L570-571 resets. The probe also runs with that environment set. |
| R3 | A stale FAIL `.bolt-panel-state.json` blocks every run once no scan rewrites it. | Delete the reader L1108-1119 in the same commit as the scan (C3). |
| R4 | `--panel-scan` unknown-arg exit 2 → the composite scan does not run (conflict_bypassed goes stale); `\|\| true` hides it. | No-op parser arm; callers untouched until C8. |
| R5 | `AGENT_VAULT_DIR` NameError swallowed → attempt-cap fails open. | Attempt-cap goes in C4, before binding-freshness (C6a). |
| R6 | Changing the `freshness.gate_check` signature → TypeError swallowed → every inline unit quarantined as `not_evaluated`. | Keep `prompt_path=None`. test-inline-lane catches it (28 FAILs in the verifier's negative control). |
| R7 | Legacy `dispatch-prompt.md` leftovers change the unit_binding done-rule. | vault_layouts and unit_binding.py:460 are both unchanged (KEEP/HOLD). |
| R8 | The window between F-09 deletion and agent deletion allows an ungated hand dispatch. | They are in the same commit (C6b). |
| R9 | Fixture dependencies in test-t3-panel-evidence (L107 run-full-suite, the U-001 commits inside A/B). | §2b surgery. F must still pass. |
| R10 | Registry lockstep (test-family-split d1, 6d EB-DOC-5). | All `partial_state_corrupt` edits in one commit (C7). Other halt rows are HOLD. |
| R11 | Ratchet metrics exactly at their ceilings. | Every commit net ≤ 0. Relocation goes to `research/`, not scripts. |
| R12 | CI skips doc-only pushes (.github/workflows/tests.yml:27-43). | Run the full local loop on **every** commit, including doc commits. |
| R13 | Editing inline-loaded prose changes the measured inline context. | Only `--agents` legs change. superpowers-bridge, halts-and-handoff, inline-run.md and propose-and-confirm stay byte-identical. One inline smoke after C2, C6b and C8. No claims. |
| R14 | Moat pins silently weakened. | test-bind-codebase-fork is re-pointed, never dropped. test-migrated-conflict-blocks a5 moves to the Skill entry (still denies `binding_missing`). |
| R15 | Anchor-core byte pins (3988/1625) break. | Recorded re-baseline in C6b (3963/1600), together with extras:98. |

### Honest losses to record in spec §8.6

None of these was measured on the inline arm, which never had any of them.
- **G1.** Iron Rules 5/6 and the Context7 consult guidance no longer reach implement time. Context7 guidance survives in extras slice-procedure.md:56 and plan.
- **G2.** Per-unit trace tag; per-dispatch freshness, F-18 and attempt cap; `acceptance_test_concern` writer (the FSD label is fixed); per-bolt LOCKED drift check (`bolt_introduces_locked_drift`) in every mode.
- **G3.** `cross_squad_interface_draft` and `module_blocked_by` stay promised in SKILL.md:44, unit-schema:322 and modules-schema, but have no implementation on inline. This gap exists since P2; it is not caused by P3. It is fixed in P3b.
- **G4.** Pack rules, reuse, design and starterkit slices no longer reach any bolt. `[LOCKED]` still reaches units via `plan --kb` Hard rules and GateGuard.
- **G5.** No gate reads `l0-results.json`. SAST WARN findings have no reader.
- **G6.** modern-baseline.md and the pack `## Code style` / `## Security idioms` sections have no runtime reader.
- **G7.** The T01 lite trace does not trace the inline reference set (about 74 KB). Re-pointing it raises the ceiling and needs a `raises` entry (P3b).
- **G8.** The inline controller has no bounded-probe rule (existing gap).
- **G9.** The fix-proposer prompt carries no `mega-sdd-trace` line (existing gap; propose-and-confirm is KEEP).

### Order of operations

Each commit is small and reviewable. C2–C7 ship in one release, with **no tag between C3 and C6b**.

| commit | content | extra gate |
|---|---|---|
| **C0** | Additions only (§3d). Baseline: full suite green, complexity numbers recorded. | none |
| **C1** | Spec §8.6 skeleton, §5 row, §7 amendment rows. | none |
| **C2** | Retire `--agents` entry points (front door, orchestrate-flow, execute-bolts SKILL.md :28/:29/description), state_probes comment, routing-rules, diagnostics :132, vanilla-ab-batch arm, execute-bolts.test.md BH4/5/8, test-inline-lane h3/h7/h7b/h8, test-2a2d :61-62. After this commit no product path dispatches bolt-implementer. | inline smoke |
| **C3** | Panel: merge-panel-findings.sh, 6 lens/verifier agents, review-panel.md, capture-views.sh, panel-scan → no-op, hook L1108-1119, code-gates.md, validate-reuse-duplication header, model-tiers rows 16-21b, project-config review_panel + preview_url, handoff-contract / chain-execution examples, gateway row lens part, CLAUDE.md C3 lines, and the C3 test deletions and re-pins. | O2 |
| **C4** | Router and attempt cap: resolve-review-tier.sh, hook L1285-1325 + L1390-1414, SKILL.md model routing / `--max-retries`, project-config max_retries, unit_tier docstring, tests. | none |
| **C5** | Builder: build-dispatch-prompt.sh, validate-dispatch-prompt.sh, context-enrichment, starterkit-enrichment, bolt-dispatch-prompt; wave/probe rails and fragments; extract-intelligence :200 + template; gateway per-unit tag; halts-and-handoff:118; plan refs (slice lines); scenario-8; builder tests. | O1 |
| **C6a** | In-run hook legs: F-18, binding-freshness, D24a; freshness.py (reduced); §3.9b; CLAUDE.md C6a lines; test-gate-binding-freshness and test-t3-expects-gate (§2b). | re-audit §2b |
| **C6b** | F-09 mapping, Agent parse, fast path, matcher → `Skill\|Bash\|Edit\|Write`, header, **agents/bolt-implementer.md**; §3.9 rewrite + orchestrate-flow:120; convergence-loops; using-mega-sdd; commands :8/:50/:77; invariant #2; model-tiers rows 15/22; READMEs, CONTRIBUTING, root CLAUDE.md; spawn C8b; migrated a5; predictive §12; agent-dispatch-gate / p2d deletion; honesty h5; inline-lane g2/h9/h15. | O3, O4, re-audit §2b, inline smoke |
| **C7** | Partial-state cluster, including the `ts_fname` carve-out, registry and lockstep tokens, and scenario-6. Separable: it may slip to P3b without harm. | none |
| **C8** | Optional and isolated: remove the `--panel-scan` token from derive-exec-plan.sh:270, inline-run.md:104, pre-tool-use:950 and stop:182; delete the retire shim :246-252 + :63 import; h5/e8/m8b; 4abc wording. Keep the parser no-op arm. | inline smoke (touches the inline plan text) |
| **C9** | Measure and lower the budget ceilings; spec §8.6 numbers; CHANGELOG (no gain claims; note that the C2 inline smoke was combined with the C6b one, §6 check 5); T10 deletion; test-no-removed-skill-refs extension; derive-state comment; runbook refs. | none |

### Checks after every commit
1. **Full local suite, mirroring CI:**
   `find plugins/mega-sdd/tests tests \( -name 'test-*.sh' -o -name '*.test.sh' \) | sort | while read t; do bash "$t" || echo "FAIL $t"; done`
   It must show zero FAILs beyond the C0 baseline.
2. **Focused:**
   - tests/v9/{test-inline-lane, test-gateway-trace, test-result-contract, test-no-removed-skill-refs, test-honesty-docs, test-migrated-conflict-blocks}.sh
   - tests/lanes/test-lanes.sh
   - tests/session-note/test-session-note.sh
   - tests/halt-registry/test-family-split.sh
   - tests/god-review-s6/test-6d-doc-pins.sh
   - tests/extract-census/*.sh
   - tests/surface/test-front-door-flag-parity.sh
   - tests/benchmarks/test-complexity-budget.sh
3. **Hook commits (C3–C6b):**
   - `bash -n plugins/mega-sdd/hooks/pre-tool-use plugins/mega-sdd/hooks/stop`.
   - Fail-open probe on a temp repo: plant FAIL `.bolt-conflict-bypass-state.json` and FAIL `.validation-blockers.json`, then send `{"tool_name":"Skill","tool_input":{"skill":"mega-sdd:execute-bolts","args":"--all --lite"}}`. It must return `"permissionDecision": "deny"`, naming both gates.
   - Repeat with `GATE_MODE=in-run GATE_SUBJECT=X` exported. The deny text must be identical, starting with `mega-sdd:execute-bolts is blocked`.
   - Send a `general-purpose` Agent payload: empty output, rc 0.
4. **Stale-name sweep:**
   `git grep -nE 'bolt-implementer|spec-reviewer|code-quality-reviewer|security-reviewer|standards-reviewer|design-reviewer|resolution-verifier|merge-panel-findings|resolve-review-tier|capture-views|build-dispatch-prompt|validate-dispatch-prompt' -- plugins ':!**/tests/**'`
   Remaining hits may only be in the KEEP/HOLD files listed in §3a.
5. **Inline smoke (C2, C6b, C8):** one `xs guarded-inline` run (the v9-smoke precedent), n=1. Report it as a smoke run, never as a benchmark.
   **Recorded (C2 + C6b):** the C2 smoke was not run at C2; it is combined with the C6b smoke. One run of plugin 561e418d (C6b), fixture-xs @ ff006be, opus (`benchmarks/results/v9-smoke/plan-p3.txt`, `xs/guarded-inline-p3/`): 16.7 min, $7.93, 5 units, 1 subagent (the general-purpose blind review, trace line carried), no `dispatch-prompt.md` written, no hook deny, delivery-check `VERDICT: PASS` (5/5). A smoke run, not a benchmark: no claim.

### P3b backlog (deferred as units, each needing its own re-audit)
- **Fan-out:** batch-and-fanout.md selection relocation (with the `exec_units.done` fix for `--module`), squad-subagent.md, hard-rule-scan L166-169, derive-ready-units `dispatch_plan`, test-l1, scenario-5, the fan-out flags, `parallel_max`, test-no-depth2 header, G3.
- **Halt vocabulary:** halts-and-handoff, halt-taxonomy, halt-recovery, propose-and-confirm (plus the fix-proposer trace), and the emitterless registry rows.
- **JIT capture:** derive-unit-claims wave mode, `_wave-claims` guard, protected-set tokens.
- **Done-rule:** unit_binding.py:460 and the dead vault_layouts functions.
- **Other:** superpowers-bridge `--agents` sections; the narrowed paths.md strip; chain-execution rows; run-analyze V16 (the correct surgery is L140/L537/L674/L730 + comments, **keeping L536**); packs O5; design-intelligence G6; T01 trace re-point G7.
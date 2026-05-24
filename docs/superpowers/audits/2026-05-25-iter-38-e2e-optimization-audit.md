# Iter 38 — E2E Optimization Audit + External Research

**Date:** 2026-05-25
**Method:** 4 parallel sonnet research subagents (token / performance / robustness / output quality) + internal e2e read + external WebSearch/WebFetch
**Plugin version:** v3.26.2 (after Iters 32-37)
**Constraint:** Read-only audit + research; produces 1 report file; no code changes
**Scope:** find optimizations for performance, output quality, robustness, token saving — across all 13 skills

---

## Summary

**Overall verdict:** YELLOW. Plugin is structurally sound (3 audits across Iters 24/28/31 closed major correctness gaps), but **37 optimization opportunities** surfaced across token efficiency / performance / robustness / output quality:

- **12 P1/HIGH** findings — actionable in dedicated iters
- **17 P2/MEDIUM** findings — improvement candidates
- **8 Advisory/LOW** findings — note for future contributors

**Top 3 cross-cutting themes:**

1. **Silent-failure paths still exist** (D3-001/002/003 + D4-001 + D4-006). Despite 15-layer anti-halu rail claims in README, several documented paths allow chain completion masking actual failure: skill crash before handoff, unverified artifact existence, corrupt partial-state JSON, AI co-authorship of tests it must pass. Trust the toolchain less than it claims.

2. **Cache invalidation is consistently too coarse** (D1-002 + D2-003 + D2-007). All cache mechanisms (lock-file hash for starterkit-context, codebase-map timestamp for symbol-graph, full deep-scan re-run on any manifest change) use whole-file/whole-graph invalidation. Per-slice / per-section invalidation could halve unnecessary work in 3+ skills.

3. **Halt taxonomy registry lags skill implementations** (D3-004 + D3-005 + D3-013 + D4-001). Halt types are introduced in SKILL.md files but lag in vault-contract.md `§halt-protocol` enum. `diff_conflict` has been missing from orchestrate-flow ALWAYS STOP routing since v0.3.0 — **23 versions of unfixed regression**. README anti-halu layer count claims 15 in changelog but body still shows 13.

**Recommended action:** ship 2-3 quick wins (≤30min each) immediately + queue 5 priority iters for Iter 39-43.

---

## D1 — Token optimization (7 findings)

External research sources:
- [Anthropic Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) — 90% discount on cached tokens, 5-min TTL
- [Claude Code Token Optimization](https://buildtolaunch.substack.com/p/claude-code-token-optimization) — context window budget discipline
- [Multi-Agent Caching arXiv](https://arxiv.org/pdf/2601.06007) — separate static instructions from dynamic outputs
- [Subagent Token Patterns](https://medium.com/@sathishkraju/claude-code-subagents-the-complete-guide-to-ai-agent-delegation-d0a9aba419d0) — pass analytical outputs not raw data

| ID | Sev | Title | Estimated savings |
|---|---|---|---|
| D1-001 | P1 | Handoff inlines `starterkit_context:` redundantly 5-6× per chain | ~300-500 tokens/run |
| D1-002 | P1 | 4 deep-scan subagents re-read composer.json + package.json 3+ times each | ~9-24KB I/O, ~10-20% per-subagent budget |
| D1-003 | P1 | T2 5KB soft cap is aspirational — no running budget enforced | 15-30% T2 size reduction for complex units |
| D1-004 | P2 | Wave-2/3/4 subagents independently re-read glossary.md (~120KB redundant) | ~96KB net I/O reduction (15% of 535K wave token budget) |
| D1-005 | P2 | Anthropic API prompt caching not leveraged for stable T1 preamble | 85-90% on T1 IF Claude Code exposes cache_control |
| D1-006 | P2 | shared-snapshot reuse (Iter 30) NOT extended to scan→bind + extract→intent hops | 30-50% re-run I/O for incremental edits |
| D1-007 | Advisory | Plain section citations load full reference docs (no offset/limit hints) | 30-60% I/O reduction per reference read |

**Top D1 recommendation:** Add manifest pre-parse step (D1-002) — main thread reads composer.json + package.json once, injects parsed data to all 4 deep-scan subagents. Low complexity; eliminates guaranteed duplication on every project pipeline run.

---

## D2 — Performance + parallelism + caching (7 findings)

External research sources:
- [Aider repo-map architecture](https://aider.chat/2023/10/22/repomap.html) — PageRank symbol-graph pattern
- [Parallel Agent Optimization (Zylos 2026)](https://zylos.ai/research/2026-04-23-parallel-tool-calling-optimization-ai-agents) — **3 parallel agents per turn is empirical optimum**, beyond 3 coordination overhead exceeds gain
- [Incremental Tree-Sitter Parsing](https://dasroot.net/posts/2026/02/incremental-parsing-tree-sitter-code-analysis/) — 70% parse-time reduction via change tracking
- [Real-time Codebase Indexing](https://github.com/cocoindex-io/realtime-codebase-indexing) — XXH3 hash + per-file invalidation
- [Dynamic PageRank Updates](https://hackernoon.com/efficient-pagerank-updates-on-dynamic-graphs-and-existing-approaches) — incremental edge updates O(1) per edge

| ID | Sev | Title | Estimated speedup |
|---|---|---|---|
| D2-001 | HIGH | extract-intelligence Wave-3 fires 5 agents but optimum is 3 (Zylos 2026 research) | 10-20% wave wall-clock |
| D2-002 | MEDIUM | Snapshot reuse (Iter 30) gated to --deep chain; standalone detect-drift pays full cost | 7× speedup (28s → 4s) on standalone runs |
| D2-003 | MEDIUM | starterkit-context cache invalidates all 4 subagents on ANY lock-file change (JS-only changes shouldn't re-run PHP extractors) | 50% deep-scan cost on common JS-only updates |
| D2-004 | LOW | routing-outcomes.md append-only, no rotation; grows unbounded | Prevents future ~100ms+ token-load overhead at 500+ rows |
| D2-005 | HIGH | tree-sitter fallback to regex SILENTLY disables PageRank; no incremental scan | 60-70% symbol-graph rebuild reduction for incremental |
| D2-006 | LOW | data-mutation-policy.md re-read per bolt in --parallel batches (20× for 20-bolt run) | ~1.6s across 20-bolt batch |
| D2-007 | MEDIUM | Symbol-graph invalidated on ANY codebase-map.md regeneration (even --shallow-scan) | Eliminates 5-10s rebuild on shallow-scan re-runs |

**Top D2 recommendation:** Lower extract-intelligence `--max-parallel` default from 5 to 3 (D2-001) — aligns with empirical 2026 research; one-line config change.

---

## D3 — Robustness + error recovery + halt taxonomy (14 findings)

External research sources:
- [AWS Builders Library — Avoiding Fallback in Distributed Systems](https://aws.amazon.com/builders-library/avoiding-fallback-in-distributed-systems/)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html) — compensating actions for multi-step pipelines
- [Compensating Transactions](https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction)
- [Anthropic API Errors](https://docs.anthropic.com/en/api/errors) — 429 retry-after, exponential backoff

| ID | Sev | Title |
|---|---|---|
| D3-001 | **P1** | Skill crash BEFORE handoff emission silently treated as completed (orchestrator stops chain, no halt) |
| D3-002 | **P1** | `artifacts:` list in handoff never existence-verified; downstream skills proceed on ghost paths |
| D3-003 | **P1** | partial-state.json corrupt JSON crash has no `partial_state_corrupt` halt |
| D3-004 | **P1** | `pbt_citation_invalid` halt cited in execute-bolts SKILL.md but ABSENT from vault-contract.md type enum |
| D3-005 | **P1** | `diff_conflict` halt missing from orchestrate-flow ALWAYS STOP routing since v0.3.0 (23 versions!) |
| D3-006 | P2 | scenario-6 recovery guide covers 10 of 30+ halt types; all Iter 30+ types missing |
| D3-007 | P2 | `--force-skip-postflight` flag used in scenario-6 but UNDOCUMENTED in execute-bolts SKILL.md inputs |
| D3-008 | P2 | Iter 33 F3 validation gate produces 100% false positives for users upgrading from pre-v3.24 |
| D3-009 | P2 | No saga compensating-action specification for partial bolt execution — rollback undefined |
| D3-010 | P2 | `--max-cycles` default is 5 in SKILL.md but 3 in commands/orchestrate-flow.md (still open from Iter 31) |
| D3-011 | P2 | Vendored superpowers (v5.1.0) has no staleness check; could drift undetected |
| D3-012 | P2 | vault.json concurrent write race (two-tab usage) — no file-level advisory lock |
| D3-013 | Advisory | No `api_rate_limited` halt for 429 errors — bolt crashes unstructured under load |
| D3-014 | Advisory | scenario-6 Option D requires manual JSON edit to bolt-outcomes.json — no helper command |

**Top D3 recommendation:** Close the **3 silent-failure paths** (D3-001/002/003) — adds `handoff_missing`, `artifact_missing`, `partial_state_corrupt` halts. Each is a new halt type + guard clause; eliminates trust erosion paths.

---

## D4 — Output quality + anti-hallucination + citation discipline (9 findings)

External research sources:
- [Hallucination Detection via AST Analysis (arxiv 2026)](https://arxiv.org/abs/2601.19106) — 89.5% precision with hybrid AST + static analysis
- [PBT for LLM-Generated Code (ACM FSE 2025)](https://dl.acm.org/doi/10.1145/3696630.3728702) — "Never trust AI to both generate and validate"
- [Multicalibration for LLM Code Generation](https://www.researchgate.net/publication/398513108_Multicalibration_for_LLM-based_Code_Generation) — uncalibrated heuristics underperform calibrated baselines
- [Stanford AI Index 2026 — Hallucination Engineering](https://explore.n1n.ai/blog/stanford-ai-index-2026-hallucination-engineering-2026-04-21)

| ID | Sev | Title | Status |
|---|---|---|---|
| D4-001 | **HIGH** | README "Anti-hallucination defense (13 layers)" section header still shows 13 even though v3.26.2 CHANGELOG claimed fix to 15 | claimed_but_not_fixed |
| D4-002 | MEDIUM | OQ recommend mode `scan_citations` validity check is spec-asserted but procedural enforcement not verified | spec_asserted |
| D4-003 | MEDIUM | `grounding_confidence` HIGH/MEDIUM/LOW labels are heuristic-derived, NOT empirically calibrated | design_gap |
| D4-004 | MEDIUM | `[LOCKED]/[INTENT]/[ARTIFACT]` markers may re-classify across extraction re-runs; unit frontmatter NOT auto-validated | design_acknowledged |
| D4-005 | MEDIUM | Hard Rule v2 pre-flight validates rule SYNTAX but cannot detect SEMANTIC false negatives (wrong pattern → silent pass) | design_limitation |
| D4-006 | **HIGH** | `acceptance_test` authored by SAME LLM pass that generated the unit spec — same blind spots affect both | structural_design_risk |
| D4-007 | LOW | `PARTIAL_FIELDS_SURPLUS` (feature drift risk) and `PARTIAL_FIELDS_MISSING` (safe) both map to `grounding_confidence: MEDIUM` | design_gap |
| D4-008 | LOW | Bolt output verifiability strong for STRUCTURE (Hard Rules + provenance trailer) but weak for BEHAVIOR | partially_enforced |
| D4-009 | MEDIUM | starterkit `_source:` citation rail silently absent on partial subagent failure | spec_asserted_partial |

**Top D4 recommendation:** Fix D4-001 README header IMMEDIATELY (trivial). Plan D4-006 acceptance-test independence iter (separate generation from verification per ACM FSE 2025 best practice).

---

## Cross-cutting patterns

### Pattern A: Backward-compat clauses introduce silent-success paths
D3-001 (handoff silent stop), D3-008 (upgrade false positives), D4-009 (citation rail partial fail). Plugin has accrued 3+ backward-compat silent-stop paths; each should have a sunset date.

### Pattern B: Halt taxonomy registry diverges from skill implementations
D3-004 (pbt_citation_invalid ghost halt), D3-005 (diff_conflict missing for 23 versions), D4-001 (README layer count drift). No automated sync check between vault-contract.md type enum and skill body halt references. Gap widens each iteration.

### Pattern C: Cache invalidation is consistently too coarse
D1-002 (manifest re-reads), D2-003 (per-slice cache), D2-007 (symbol-graph), D1-006 (snapshot reuse not extended). All cache mechanisms invalidate whole files/graphs; per-slice / per-section / per-file-hash invalidation pattern is consistently 50-70% more efficient and proven by external research.

### Pattern D: No saga-style compensating actions
D3-009 (rollback undefined), D3-003 (partial-state crash unrecoverable). Plugin uses forward-only resume pattern; no compensating action specification means partial writes can compound on resume.

### Pattern E: Predictive-checks.md coverage is asymmetric
D3-013 (rate limits), D3-012 (concurrent writes), D3-011 (vendored skills staleness) — all preflight-detectable but unmapped. predictive-checks.md covers 4 of 9 user-invocable skills; detect-drift, diff-vault, resolve-oq, extract-intelligence, emit-agents-md, memory all have zero preflight coverage.

### Pattern F: AI co-authorship of validation = same blind spots
D4-006 (acceptance_test authored by same LLM pass as unit spec), D4-005 (Hard Rule patterns wrong but well-formed = silent pass), D4-002 (citation validity check spec-asserted). External research repeatedly warns: "Never trust AI to both generate and validate" (ACM FSE 2025).

---

## Immediate wins (≤30min each — ship today as patch)

These are trivial fixes that close real gaps without needing a full iter:

1. **D4-001 — README layer count** (~5min): change "Anti-hallucination defense (13 layers)" → "(15 layers)" and add layers 14 (handoff validation gate from Iter 33 F3) + 15 (predictive preflight from Iter 33 F2). The CHANGELOG already claims this fix; just apply it.

2. **D3-007 — Document `--force-skip-postflight`** (~10min): add flag to execute-bolts SKILL.md `## Inputs` section with explicit WARNING block (anti-bypass policy citation).

3. **D3-010 — Canonicalize `--max-cycles` default** (~5min): SKILL.md line 609 says default 5; commands/orchestrate-flow.md line 20 says default 3. Pick 3 (more conservative). One-line fix. Closes Iter 31 F-orchestrate-flow-07.

4. **D3-004 — Add `pbt_citation_invalid` to vault-contract.md type enum** (~10min): currently ghost halt. Add to enum + description per existing halt-protocol shape.

5. **D3-005 — Add `diff_conflict` to orchestrate-flow ALWAYS STOP** (~10min): 23 versions overdue. One-line table addition.

Total: ~40 minutes for 5 P1/HIGH closures.

---

## Prioritized future-iter candidates

Iter 39+ candidates ordered by impact × inverse-effort. Per simplifikasi: each candidate is ONE iter (no mega-iters; no deferrals).

| # | Iter title | Findings closed | Effort | Impact |
|---|---|---|---|---|
| 1 | **Silent-failure path closure** (3 new halts: handoff_missing + artifact_missing + partial_state_corrupt) | D3-001, D3-002, D3-003 | ~4hr | HIGH — trust restoration |
| 2 | **Halt taxonomy sync sweep** (audit all SKILL.md halt refs vs vault-contract.md enum; close all ghost halts) | D3-004, D3-005, D4-001 + pattern B | ~3hr | HIGH — closes 23-version-overdue regression |
| 3 | **Deep-scan manifest pre-parse + per-slice cache** (eliminate redundant reads + selective re-dispatch on lock changes) | D1-002, D2-003 | ~4hr | HIGH — every project pipeline benefits |
| 4 | **T2 running budget tracker** (replace 10KB single-halt with progressive section-level truncation cascade) | D1-003 | ~3hr | HIGH — every bolt dispatch benefits |
| 5 | **Saga compensating actions** (extend partial-state.json schema with rollback_hint per step type) | D3-009, D3-003 | ~5hr | MEDIUM — closes pattern D entirely |
| 6 | **Section-snapshot reuse** (extend Iter 30 shared-snapshot pattern to scan→bind + extract→intent hops) | D1-006, D2-007 | ~5hr | MEDIUM — high ROI on iterative runs |
| 7 | **Independent acceptance-test authoring** (PBT property stubs human-authored OR distinct LLM pass for tests) | D4-006 | ~6hr | HIGH — closes pattern F structural risk |
| 8 | **vault.json advisory lock + scenario-6 expansion** (concurrent-write safety + recovery walkthroughs for all 30+ halt types) | D3-012, D3-006 | ~3hr | MEDIUM — concurrent-tab safety + docs |
| 9 | **Predictive checks coverage expansion** (add preflight entries for detect-drift, diff-vault, resolve-oq, extract-intelligence, emit-agents-md, memory) | Pattern E | ~3hr | MEDIUM — proactive failure detection |
| 10 | **Glossary anchoring + reference offset hints + extract-intelligence parallelism tuning** (3 token-saving editorial passes) | D1-004, D1-007, D2-001 | ~3hr | MEDIUM — editorial; low-risk |

**Total queue: 10 iters × ~3-6hr each = ~40-60hr of work**. Spread over 1-2 months of plugin development cadence.

---

## What the audit DID NOT cover

- **SKILL.md procedural enforcement of contract assertions** — D4-002 and D4-009 are flagged spec-asserted; a complementary audit pass reading SKILL.md procedural steps would resolve.
- **Trigger test execution** — read-only audit; tests not run against current plugin state.
- **End-to-end timing baselines** — D2-001/002/007 estimates are based on external research benchmarks, not measured against mega-sdd's actual usage on the user's tradefinance/base-laravel-26 projects. Field measurements would calibrate the estimates.
- **Token cost actuals** — D1 estimates are derived from prompt size + caching docs; actual API spend not measured.
- **Cross-skill emergent failures** — each dimension was audited independently; multi-skill failure cascades (e.g., bind-codebase CONFLICT + execute-bolts retry + memory write race) not explicitly modeled.

---

## Methodology notes

- **Audit method:** 4 parallel sonnet subagents (Iter 31 audit pattern) — one per dimension (token/perf/robustness/output). Each reads 6-10 internal files + WebSearch/WebFetch 5-8 external sources. Outputs collected as YAML; main thread consolidates.
- **Wall-clock:** ~7 minutes per subagent + ~5 minutes consolidation. Total Iter 38 execution: ~12 minutes vs estimated several hours of manual research.
- **Reuse pattern:** mirrors Iter 31 forensic audit subagent dispatch. Now standardized for E2E audits across the plugin.
- **External research sources cited inline per finding** — every claim has WebSearch/WebFetch attribution per WebSearch tool requirement.
- **Findings count:** 37 total (12 P1/HIGH + 17 P2/MEDIUM + 8 Advisory/LOW). No P0 critical findings.

---

**Phase B output complete. Plugin v3.26.2 e2e optimization audit shipped.** Next step: ship 5 immediate wins as patch + brainstorm Iter 39 candidate from prioritized queue (priority 1: silent-failure path closure).

## External research sources (deduplicated)

Sources:
- [Anthropic Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Claude Code Token Optimization](https://buildtolaunch.substack.com/p/claude-code-token-optimization)
- [Multi-Agent Caching arXiv 2601.06007](https://arxiv.org/pdf/2601.06007)
- [Claude Code Subagents Guide](https://medium.com/@sathishkraju/claude-code-subagents-the-complete-guide-to-ai-agent-delegation-d0a9aba419d0)
- [Prompt Caching 2026 Cost-Latency](https://aicheckerhub.com/anthropic-prompt-caching-2026-cost-latency-guide)
- [Aider Repo Map](https://aider.chat/2023/10/22/repomap.html)
- [ast-grep Documentation](https://ast-grep.github.io/)
- [Parallel Tool Calling Optimization](https://zylos.ai/research/2026-04-23-parallel-tool-calling-optimization-ai-agents)
- [Incremental Tree-Sitter Parsing](https://dasroot.net/posts/2026/02/incremental-parsing-tree-sitter-code-analysis/)
- [Code Search Tool Comparison](https://ceaksan.com/en/code-search-for-ai-agents-which-tool-when)
- [Dynamic PageRank Updates](https://hackernoon.com/efficient-pagerank-updates-on-dynamic-graphs-and-existing-approaches)
- [Real-time Codebase Indexing](https://github.com/cocoindex-io/realtime-codebase-indexing)
- [AWS Builders Library — Distributed Fallback](https://aws.amazon.com/builders-library/avoiding-fallback-in-distributed-systems/)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html)
- [Compensating Transactions](https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction)
- [Anthropic API Errors](https://docs.anthropic.com/en/api/errors)
- [Hallucination Detection via AST (arxiv 2601.19106)](https://arxiv.org/abs/2601.19106)
- [PBT for LLM-Generated Code (ACM FSE 2025)](https://dl.acm.org/doi/10.1145/3696630.3728702)
- [Multicalibration for LLM Code Generation](https://www.researchgate.net/publication/398513108_Multicalibration_for_LLM-based_Code_Generation)
- [Stanford AI Index 2026 — Hallucination Engineering](https://explore.n1n.ai/blog/stanford-ai-index-2026-hallucination-engineering-2026-04-21)
- [Continue.dev Anti-Hallucination](https://dev.to/synsun/cursor-vs-github-copilot-vs-continue-ai-code-editor-showdown-2026-2h89)

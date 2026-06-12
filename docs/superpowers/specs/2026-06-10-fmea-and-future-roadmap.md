# FMEA + future roadmap — per-phase edge-case audit & ecosystem R&D (v4.18)

**Status: rails SHIPPED; roadmap items TRACKED.** Four parallel audits (2026-06-10/11): upstream FMEA (62 cases), downstream FMEA (36 cases), environment/platform FMEA, and a cited future-ecosystem research pass. Every shipped rail's lead was re-verified against the source before implementation.

## Coverage picture

- Upstream phases: 71% of stressed edge cases already covered by existing prose/halts/validators (quoted in the audit transcripts, see git).
- The moat held everywhere EXCEPT one verified hole: **python3 absent → every hook exits silently → the binding→units gate fails OPEN**. Closed in v4.18 (shell fail-closed fallback, empirically tested in 3 states).
- Strongest existing protections confirmed: secret-scan gate (scan), `--force-large` gate, deep-scan soft-halt + partial output, journal rotate-don't-truncate, vault.json O_EXCL lock, partial-state self-heal guard, blockers-file atomic write (tmp+os.replace), fail-closed corrupt-moat.

## Rails shipped in v4.18 (each lead verified first)

| # | Risk (likelihood×impact) | Rail |
|---|---|---|
| E1 | python3 absent → moat fails open (HIGH×CRITICAL) | pre-tool-use shell fallback: sed-extract cwd+skill; execute-bolts blocked unless blockers file attests PASS (fail-closed) |
| U1 | legacy secrets leak into KB (HIGH×HIGH) | extract-intelligence secret-scan gate before every KB file write (mirrors scan Step 10a; redacts artifact, never the source) |
| U2 | symlink loops hang the scan walk; >10MB files stall tree-sitter (HIGH×HIGH) | Step 4 symlink rail (never follow dir symlinks) + big-file skip |
| U3 | monorepo multi-app conflated into one map (HIGH×HIGH) | Step 2 monorepo rail: ask the PRIMARY app once when app-root manifests span multiple dirs |
| U4 | manual binding.md edits silently lost on re-bind (HIGH×HIGH) | mandatory REGENERATED banner in the emitted binding.md; resolutions routed to resolve-oq |
| D1 | parallel bolts racing on shared target_files (HIGH×CRITICAL) | overlap rail: intersecting whitelists never share a parallel wave — serialize |
| D3 | two concurrent binds interleave binding.md (HIGH×HIGH) | binding.md written while HOLDING the vault.json lock (no new mechanism) |
| D2 | PENDING-SYNC.md rots unbounded (HIGH×HIGH) | lifecycle: archive resolved rows at 100KB/50-resolved; loud triage notice at >50 open; `⚠ stale?` marker when vault bumped since queueing |
| D5 | no test runner → TDD fiction (HIGH×HIGH) | pre-flight 3.5: probe the ecosystem's runner; absent → `dep_missing` (never fabricate green) |
| D6 | repo commit hooks / GPG reject the bolt commit (HIGH×HIGH) | `commit_rejected_by_hook` halt with hook output verbatim; `--no-verify` stays forbidden |
| D4 | unit explosion (200+ units) unbounded (HIGH×CRIT) | scale advisory at >100, confirm at >500 |
| D8 | sync mid-rebase/merge scans garbage (MED×HIGH) | git-state guard in sync + execute-bolts repo-state check |
| E2 | headless/CI hangs on AskUserQuestion; `--bare` bypasses hook gates (MED×HIGH) | project-config §Headless/CI: `--auto` everywhere; script-form gates documented as the CI-stable surface |
| E3 | multi-dev vault.json/binding.md git-merge corruption (MED×CRITICAL) | paths.md multi-dev note: one-writer discipline or gitignore-the-derived-file; per-dev noise files always gitignored |

## Deferred (tracked, not shipped — each needs its own session)

- Session-level chain mutex (two `/mega-sdd:auto` in one project) — design needed (stale-lock semantics).
- Atomic temp+rename for vault.json/binding.md skill-level writes (Claude Code Write tool semantics; revisit when skill-scoped hooks land).
- Per-unit wall-clock timeout + chain-level token budget.
- resolve-oq `--batch-mode` for 50-CONFLICT fatigue.
- Encoding sniff for non-UTF8 legacy sources; stored-procedure extraction lane (`--seed` SQL guidance exists).
- telemetry.jsonl rotation; OQ near-duplicate merge; checkpoint model-compat stamp.
- handoff-contract full de-duplication + starterkit schema copy (carried from the v4.17 audit).

## Future radar (cited research, 2026-06; full report in git)

**Adopt-now (status v4.19):** worktree-proofing SHIPPED (all git-state probes via `rev-parse --git-path`; scan walk-up handles `.git`-as-file); AGENTS.md interop pair SHIPPED (emit-agents-md 1.4.0, consent-gated `@AGENTS.md` stub); `context: fork` EVALUATED → PILOT-GATED (forked skills lose the invocation's memory_context + can't AskUserQuestion — no clean candidate today; decision recorded in CLAUDE.md §Capability-adoption); skill-scoped `hooks:` EVALUATED → NOT adopted for the moat (the global gate must see Bash tampering + user edits outside skill lifecycles; recorded ibid).

**Prepare (status v4.19):** CI recipe SHIPPED (`references/ci-recipe.md` — PR drift gate, sync-on-merge, pure-script exit-code gates, `--bare` warning); EARS optional tier SHIPPED (unit-schema `acceptance_test[].ears`, additive + backward-compatible). Still open: unit DAG as a platform dynamic-workflow plan; sandbox smoke-test of the hook suite; `Stop` hook `additionalContext` as a halt channel.

**Validated assumptions:** lean-core/progressive disclosure does NOT expire with 1M contexts — Claude Code tightened description budgets (1% window, 1536-char cap) and compaction re-attaches only ~5K tokens/skill; chain state must live in `.mega-sdd/` files, never in conversational skill context (mega-sdd already does this).

**Do NOT yet:** rebuild execute-bolts on ultracode/dynamic workflows (unstable API, token-cost warned); port to a standalone Agent SDK app (SDK loads filesystem plugins as-is); EARS as the only criteria format; ship MCP servers; team/shared-memory features (the vault in git IS the shared memory); re-propose `when_to_use`/`disable-model-invocation` (rejected with rationale in CLAUDE.md; the 1536-char cap strengthens the rejection).

## Platform-assumption sweep (v4.20 addendum)

Docs-verification sweep (2026-06-11) found and fixed 5 WRONGs: PreToolUse deny format (continue:false never processed for PreToolUse → hookSpecificOutput.permissionDecision dual-format); /command path bypassing the PreToolUse Skill gate (→ UserPromptExpansion gate, decision:block); pandoc failure detection dead (PostToolUse fires on success only; no exit_code field → PostToolUseFailure wiring); stop-hook fossil re-running the validator with the pre-Iter-74 regex (removed; stdin last_assistant_message preferred); ${CLAUDE_PLUGIN_ROOT} unsubstituted inside references/*.md (→ <plugin-root> derivation notes). Plus: SessionStart re-fires on resume; AskUserQuestion 4-option cap; AAIF url; /reload-plugins; ghost superpowers skill ref. Deferred (tracked): reframe the <<EXTREMELY_IMPORTANT>> session-start wrapper to factual framing (docs counter-recommend command-framing; needs a skill-triggering field-test first — the wrapper is load-bearing for routing); asyncRewake on the Stop validator; `if:` permission-rule narrowing of the anti-self-bypass Bash branch; FileChanged/watchPaths as a journal complement; Agent tool_response.status for subagent-outcome telemetry.

## Test obligations

`tests/fmea/test-fmea-pins.sh` — pins for every shipped rail + a FUNCTIONAL python3-absent gate test (minimal-PATH harness; FAIL→block, PASS→allow, non-gated→allow).

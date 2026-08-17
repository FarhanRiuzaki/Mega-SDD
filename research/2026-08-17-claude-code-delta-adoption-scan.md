# Claude Code / Anthropic delta scan (Feb–Aug 2026) → mega-sdd adoption verdicts

**Method:** two parallel web researchers (2026-08-17) — (a) Claude Code changelog + docs for plugin authors (hooks/plugins/subagents/workflows/memory/settings), (b) Anthropic engineering blog + Agent SDK + API release notes for design patterns. Findings mapped against the plugin's standing capability-adoption decisions (`plugins/mega-sdd/CLAUDE.md`) and judged per the no-gimmick rule. Full raw findings: the two subagent reports (this file keeps only the verdicts).

## The headline validations (no work needed — our architecture is now the official pattern)

- **Context resets + structured handoff artifacts beat compaction** and **artifact-based communication between agents** are now NAMED Anthropic patterns (harness-design post, Mar 2026) — exactly mega-sdd's handoff-YAML + pointer-dispatch + bolt-report architecture.
- **Grader in a separate context window to avoid contamination** (Managed Agents `define_outcome`) — our blind review panel's core mechanic, now platform doctrine.
- **Two-stage find-then-filter review** is officially recommended for Sonnet 5 (which literally withholds low-severity findings when told "high-severity only") — our lenses already return ALL severities incl. Minor and filter at the controller merge; spot-audit found no pre-filtering language in the lens prompts.
- **"Sprint Contracts"** (generator/evaluator agree on "done" before implementation) — our acceptance_test-at-unit-authoring + adversarial test review (Step 9.5) is this pattern.
- **"The task verifier must be nearly perfect or Claude solves the wrong problem"** (C-compiler case study) — the moat's whole thesis.

## Adopt-now candidates (ranked; each needs its own spec per house policy)

| # | Design | Source capability | Buy | Cost/risk |
|---|---|---|---|---|
| A1 | **CI runs `claude plugin validate --strict`** | v2.1.233 validator | Catches misspelled plugin.json/marketplace fields pre-publish — the manifest-parity class we check by hand | Trivial; CI availability of the CLI to verify |
| A2 | **Vendored-skill TodoWrite repair** | Todo/Task tools DISABLED on Opus 4.8 / Sonnet 5 / Fable 5+ (v2.1.233) | `_vendored/executing-plans` + `subagent-driven-development` instruct TodoWrite → dead tool on every current model; the superpowers bridge path silently degrades | Small; vendored files are sync-managed (patch policy: note + fallback wording, or upstream sync) |
| A3 | **Hook `statusMessage` (+ `once` where apt)** | v2.1.229 hook fields | The slow PreToolUse gate (Windows/EDR fleet) gets a visible status line instead of a silent hang — the exact complaint class from the office laptops | Trivial-to-small; no behavior change |
| A4 | **`maxTurns` caps on plugin agents** | subagent frontmatter v2.1.229 | Runaway reviewer/implementer loops get a deterministic ceiling — the attempt-loop-as-context-burner class we measured in the bolt-loop research | Small; pick caps per role honestly (implementer needs headroom) |
| A5 | **agent_type-scoped PreToolUse fast path** | hook inputs now carry `agent_id`/`agent_type` (v2.1.229) | Read-only panel lenses (spec/quality/security/standards/design reviewers) currently pay the full gate aggregator on every Bash call; scoping the write-guard battery to agents that CAN write = spawn savings exactly where CrowdStrike hurts | **Moat-adjacent** — needs a spec + round; bolt-implementer and the main thread MUST keep the full gate; fail-closed on missing/unknown agent_type |
| A6 | **Constitution → `.claude/rules/` path-scoped emission** | `.claude/rules/*.md` with `paths:` globs, load-on-demand (v2.1.211) | Vault constitution clauses ride the code paths they govern — loaded ONLY when Claude touches matching files, in EVERY session (not just chain runs); anti-hallucination context that costs nothing when irrelevant | New emission surface: SSOT discipline required (script-generated, "do not hand-edit", refreshed by sync; vault stays canonical); needs the usual round |
| A7 | **plugin.json `userConfig` + `displayName`** | typed install-time config (v2.1.143+/229) | Proper UI surface for the config.yaml knobs users actually set (telemetry, spine, profile); "Mega-SDD" display name | Dual-source config precedence must be specified (config.yaml stays canonical, userConfig seeds it) |
| A8 | **`FileChanged` event → sync detection probe** | new hook event (v2.1.229) | If it fires on out-of-band file changes, the sync lane's change detection (journal ∪ git) gains a third live channel | Investigate semantics FIRST (in-session only vs external); adopt only if it adds signal the journal misses |

## Evaluated — NOT adopted (rationale on the record, mirroring the CLAUDE.md adoption table)

- **Agent/prompt/MCP-tool hooks** (`"type": "agent|prompt|mcp_tool"`): puts model judgment inside the hook layer — the moat doctrine is *deterministic validators in hooks, judgment in gates*; adopting would re-open the exact erosion class the doctrine exists to stop. Advisory surfaces already have the analyze skill.
- **`subagent_type: "fork"` for the review panel**: forks INHERIT the conversation — the panel's value is BLINDNESS (fresh context, evidence-only). Fork is the anti-pattern for lenses; pointer dispatch already solves implementer context cost. (Unrelated to the pending `context: fork` skill-frontmatter flip, which stays gated on the 2 interactive runs.)
- **Agent teams for the panel**: mailbox/task-list coordination between lenses would un-blind them; the controller-merge design is deliberate.
- **`memory:` frontmatter on plugin agents**: a second, uncurated memory channel beside the mega-sdd memory layer (suggestion-only, human-reviewed) = drift risk; revisit only with a concrete recurring-forgetting case.
- **channels / LSP servers / themes / monitors (experimental)**: no current job-to-be-done in the pipeline — load-adding gimmick class.
- **Workflow-tool conversion of the panel fan-out**: Workflow needs user opt-in (ultracode) and adds nothing over the current Agent-tool fan-out inside a gated skill.

## Notes for existing backlogs

- **Advisor tool (`/advisor`)** pairing rules (executor + stronger advisor) rhyme with our phase-advisor P3 scope gate — no action; the platform validates the "expensive second opinion, scoped" shape.
- **Effort ladder / task budgets / auto-caching / cache diagnostics** are API-plane; useful when the benchmarks runbook next runs (pass^k metric + mandatory transcript reading from the evals post apply there too).
- **Infra-noise post**: don't trust <3pp deltas in our own A/Bs without multi-day runs — applies to the pending fork A/B and any advisor A/B.
- **1M-context defaults + adaptive thinking** change the compaction math the PreCompact snapshot was built for — no action now; re-check `autoCompactWindow` guidance in README when field laptops move to 5-family defaults.

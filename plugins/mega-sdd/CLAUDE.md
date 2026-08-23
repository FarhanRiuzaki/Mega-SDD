# Mega-SDD — Contributor & Agent Guide

Mega-SDD is an opinionated plugin for spec-driven AI development: **extract → intent → scan → bind → units → bolts**, with anti-hallucination by construction. This file is the contract. PRs that deviate from it are closed without review.

## If you are an AI agent

Stop and read this before changing anything.

1. **Read the design spec** for the area you're touching (`docs/superpowers/specs/`). Every behavior change should trace to a spec section.
2. **Read the whole skill** you're modifying — `SKILL.md` + every `references/*.md`. Skills are tuned for agent behavior; surface edits break invariants.
3. **Run the trigger tests** (`tests/skill-triggering/<skill>.test.md`) and, for pipeline changes, the fixtures under `tests/fixtures/`.
4. **Never bypass the binding gate.** Any change to `bind-codebase`, `generate-units`, or `execute-bolts` must preserve the CONFLICT-blocking contract.
5. **Show your human partner the complete diff and get explicit approval** before opening a PR.

## The 5 non-negotiable invariants (the moat)

These are the reason Mega-SDD exists. Preserve their behavior exactly.

1. **Spec↔code binding** — `bind-codebase` produces CONFIRMED / CONFLICT / OQ verdicts per claim with codebase anchors + an Implementation State Map.
2. **The CONFLICT gate blocks** — unresolved CONFLICTs block downstream unit/bolt generation. This is enforced by the PreToolUse hook on `execute-bolts` (reads `.validation-blockers.json`) and by prose in `generate-units`. Do not downgrade it.
3. **Citation discipline** — `emit-fsd` stamps `.citation-map.json` with sha256; missing sources become `[Pending — X]`, never fabrication.
4. **Halt taxonomy (C1/C2/C3) + mutability tiers** (`[LOCKED]/[INTENT]/[ARTIFACT]`) are the domain vocabulary for rebuilds.
5. **No fabrication** — if it isn't in the source (PRD/BRD/Figma/KB/codebase), it's an Open Question, not a guess.

## The enforcement doctrine (hard-won — do not relitigate)

> **A blocking enforcement gate must be a deterministic validator wired to a hook. Prose that says "HALT" enforces nothing.**

Skill bodies shape behavior but cannot *enforce* it — the model may or may not comply. Anything that must hold deterministically lives in a hook + validator, not in prose. Conversely, do not over-build hooks: prefer a self-checked **gate** in prose, and reserve real hooks for the few invariants that are both critical and un-promptable. The hierarchy is **rule → gate → hook**, escalating only when needed.

**What is actually enforced (PreToolUse, hard-block):** the binding→units gate (re-derived unconditionally at the execute-bolts gate), predictive preflight, scope-flag, anti-self-bypass (Bash + Write/Edit, covering the moat state, every quality-gate state file, AND the B1/B2/B4 evidence artifacts `postflight.json`/`_batch-suite.json`/`acceptance.json` PLUS the B1 pre-flight BASELINE `preflight.json` (written by `scripts/run-preflight-scan.sh` — `scan_unit` gives a present sha/signature snapshot precedence over commit evidence, so a forged baseline would launder a DO_NOT_MODIFY/SIGNATURE violation past B1; the writer also refuses to mint a baseline after bolt commits exist) — these are written by their deterministic writers `scripts/run-preflight-scan.sh` / `scripts/run-postflight-scan.sh` / `scripts/run-acceptance-tests.sh` / `scripts/run-full-suite.sh` and hook-guarded against direct + common programmatic writes; **B1's `postflight.json` is now RECOMPUTED at the gate** (`--postflight-scan --recompute` re-executes each committed Hard-rule bolt's mechanical rules from git/fs ground truth via the shared `scripts/_lib/postflight_rules.py` engine and OVERWRITES the artifact before the state is read — a forged/stale/absent artifact is regenerated, at parity with the six re-derived states; directives keep their prior human attestation via carry-forward, and `scan_unit` reclassifies each rule by its text so a mechanical rule cannot be relabelled a directive to dodge recompute). **B2's `_batch-suite.json` is still READ, not recomputed** — re-running a ~387s suite inside a PreToolUse hook is the inflation the doctrine forbids, so B2 stays a verified artifact and its verb-enumeration write-guard is a best-effort deny, not a cryptographic guarantee — recompute is the durable hardening, shipped for B1, deliberately not for B2), the kept code-delivery quality gates (flow-coverage, render-test, **verify-grounding** (A1 — a `verify`+`grounding_confidence: HIGH` unit whose acceptance criteria lack a non-test source anchor; `verify_grounding_untrusted`), sibling-consistency, ui-quality, cross-cutting-registration — unit-spec/flow-coverage/sibling-consistency are ALSO re-derived at the execute-bolts gate, so a stale/deleted state or a Bash-written unit cannot open them; `.unit-spec-state.json` is PROJECT-WIDE, never a per-unit slot), the four execute-bolts artifact gates — **batch-suite-gate** (B2 — no green full-suite result covers the newest code commit; symbolic `head_sha` rejected; `batch_suite_red`/`batch_suite_gate_missing`), **postflight-evidence** (B1 — a committed Hard-rule bolt with no passing `postflight.json`; obligation read from the unit AT the bolt commit; `postflight_evidence_missing`), the **whitelist observer** (B3 — a bolt commit touching files outside the unit's `target_files` ∪ sanctioned extras; `whitelist_violation`), and the **acceptance-evidence gate** (B4 — COMMIT-KEYED via the `SDD-Acceptance: v5` trailer stamped into the bolt commit at commit time, so legacy pre-v5 bolts NEVER retro-block (advisory note at most); a v5-keyed bolt with no fresh passing `acceptance.json` → `acceptance_evidence_missing`/`acceptance_red`/`build_broken` — the artifact is READ like B2, never recomputed in the hook) — ALL SEVEN bolt-stage/quality states are re-derived at the execute-bolts gate itself (a forged/stale/absent state is overwritten before it is read) — and the Factory Line ledger gate in **both directions** — forward (blocks `execute-bolts` while the ledger is FAIL) and backward (blocks re-dispatch of an upstream phase already in `phase_stuck`/`anti_spin` cap-/spin-breach). **Advisory (surfaced via the analyze skill, non-blocking):** dispatch-prompt, operator-UX, fan-out-parity, ui-deferral, vault-flow-staging. Everything else in skill bodies is design vocabulary + AI-coding-prompt scaffolding — best-effort, not enforced.

## Architecture (v4 lean-core)

- **Skills** (`skills/`) are lean routers (≤500 lines) using progressive disclosure — heavy detail lives in `references/*.md` loaded on demand. Don't reinflate a SKILL.md body.
- **Agents** (`agents/`) are first-class plugin subagents: `bolt-implementer`, `spec-reviewer`, `code-quality-reviewer`, `security-reviewer`, `standards-reviewer`, `design-reviewer`, `resolution-verifier`, `domain-extractor`. `execute-bolts` dispatches the bolt agents (risk-tiered parallel review panel — blind lenses merged in the controller, per `skills/execute-bolts/references/review-panel.md`); `extract-intelligence` dispatches `domain-extractor` per wave. Plugin agents must NOT use `hooks`/`mcpServers`/`permissionMode` frontmatter (silently ignored).
- **Commands** (`commands/`) — the public surface is FOUR verbs: `/mega-sdd` (front door), `/mega-sdd:sync`, `/mega-sdd:emit <prd|fsd|sit|uat>`, `/mega-sdd:slice` (standalone UI slicing — ADDED 6.8.0 by user decision, spec 2026-08-12; command-invocation only, no census), plus the three maintenance one-timers (`migrate-paths`, `install-deps`, `update-plugin`) — exactly 7 files, nothing else (the `memory` one-timer was removed in v7.3.0 with the whole memory/observability lane). The 24 5.x deprecation aliases were REMOVED at 6.0.0 per policy (demoted in the 5.0 MAJOR, removed the following major after a usage review — v6 spec §P4.0/§P4.1; the review's telemetry corpus itself was removed in v7.3.0); their operative content was relocated into skill references first, and a typed legacy form still routes as plain text. **The demotion policy stands for any future cull:** a pipeline command may be demoted to an alias only in a MAJOR release, must keep resolving for that whole major cycle, and may be removed only in the FOLLOWING major after a usage review (v5 spec decision 2; the in-plugin telemetry corpus is gone since v7.3.0 — the review is procedural).
- **Hooks** (`hooks/`) — SessionStart anchor injection (v7 Fase 2: it no longer writes vault artifacts — the C1 self-resolve battery lives in `scripts/ground.sh` at M/L entry); a synchronous PreToolUse gate aggregator (v7: derives the handoff verdict at gate time on EVERY guarded dispatch — sole writer, `content_sha256` dedup in the validator — and writes the `chain_engaged` session marker on mega-sdd:* Skill dispatches); PostToolUse validators (write the state files — v7: chain-scoped, they run only in an armed session; the dirty journal stays always-on); a Stop hook carrying ONLY pipeline legs — bolt-artifact/B1-B4 detection (turn-gated), the classic/full analyze aggregate, and the artifact publisher (v7.3.0 deleted ALL observability — telemetry, SubagentStop, PreCompact; v7.3.1 restored ONE exception as a GATEWAY CONTRACT: the `mega-sdd-trace:*` filter tag — a pure-shell UserPromptSubmit echo + announce/dispatch-prompt lines, spec `docs/gateway-contract.md`; 6 hook events). v7 tier gate: anti-forge guards (forged-verdict Write/Edit, Bash state-tamper) are ALWAYS-ON; GateGuard + the validator fan-out arm only when a chain runs this session (spec 2026-08-21-v7-weighted-routing-design.md; ceilings locked by tests/weighted-routing/).
- **The analyze skill** ("cek konsistensi" — routed by phrase or via the front door) is the consolidated consistency surface — runs the validators, emits `CONSISTENCY-REPORT.md`.

## Authoring standards (current Claude Code / Anthropic guidance)

These are the rules v4 was built to. They are **derived from Anthropic's published guidance, not invented** — follow them; do not regress to the pre-v4 anti-patterns (1,000-line skills, version archaeology, enforcement-by-prose).

**Skills**
- **SKILL.md body ≤ 500 lines** (anchor / hot skills ≤ ~200). Use **progressive disclosure**: the SKILL.md is a thin router; heavy procedure / schema / template / example detail lives in `references/*.md` loaded on demand. Don't reinflate a slimmed body.
- **Description = what it does + when to use it**, third person, ≤ 1024 chars. **No time-sensitive info** — never put `Iter N` / `vN+` / changelog fragments in a description (or any runtime prose). Preserve every trigger keyword, **including the Indonesian variants** (they drive ID/EN routing).
- **Frontmatter must be valid YAML.** A description containing a bare `key: value` (colon-space) is parsed as a nested mapping and breaks loading → rephrase to `key (value)` or quote the string. (This regressed once on `generate-intent` / `generate-units`; the audit caught it.)

**References**
- One level deep — **SKILL.md is the only router**: every ref file must be reachable directly from its SKILL.md, and a ref file must never be the ONLY route to another ref. A sibling cross-pointer (naming another ref that SKILL.md already routes to) is allowed; a sibling link whose target SKILL.md does NOT route is a violation. Cross-skill refs use the skill-name-relative form `<skill>/references/X.md`; plugin-root refs use `plugins/mega-sdd/references/X.md` (never bare `references/X.md` from inside a skill's ref — it resolves ambiguously). No `@`-links (they force-load context). Any ref > 100 lines gets a `## Contents` ToC. Exempt: framework-convention packs + lib-pattern catalogs (rigid-schema catalogs consumed whole by extractors, linted by `validate-pack.sh`), `templates/` output scaffolds (a ToC there would leak into generated user artifacts), and script-generated catalogs marked "Do not hand-edit".

**Enforcement — gates > rules > hooks**
- Prefer a self-checked **gate** in skill prose. Escalate to a deterministic **hook + validator** only for an invariant that is both critical AND un-promptable. Don't grow the hot-path PreToolUse surface; advisory checks belong in the analyze skill, not a blocking hook.

**Agents (`agents/*.md`)**
- A plugin subagent needs only `name` (lowercase-hyphens) + `description`; the body IS its system prompt. **Do NOT use `hooks`, `mcpServers`, or `permissionMode`** — these are silently ignored for plugin agents. `tools` must exclude subagent-unavailable tools (`Agent`, `AskUserQuestion`). Assign the cheapest capable `model` per role.

**Commands** — the user's manual CLI entry points: four public verbs + four maintenance one-timers, and NOTHING else (the 5.x aliases were removed at 6.0.0 after a usage review; `/mega-sdd:slice` was ADDED 6.8.0 as a deliberate on-record surface expansion — verb ADDITION sits outside the demotion ladder, which governs alias/removal only). **Never delete a pipeline command in a cull without the policy ladder** — demotion to an alias is allowed only in a MAJOR (the alias resolves for that whole major cycle); removal only in the following major, and only after a usage review — and relocate any operative content into skill references BEFORE deletion (the 6.0.0 relocate-then-delete precedent, v6 spec §P4.1).

**Paths** — canonical nested layout per `references/paths.md`: `<vault>/{bound,units,bolts}/` + `<vault>/binding.md`, never the legacy `<vault>-bound/` sibling.

**Tech-agnosticism** — the pipeline must work for ANY supported stack, not just PHP/JS. Low-level extraction (manifests, lock digests, route/model signatures, test-framework probes) enumerates EVERY ecosystem in the §8.5 framework table; framework-specific knowledge lives in packs (`framework-conventions/`, `lib-patterns/`), never hardcoded in skill bodies. When adding a capability, ask "does this work for a Rails/Gin/Axum repo too?" before shipping.

**Capability-adoption decisions (evaluated, with rationale — do not re-adopt blindly)**
- `disable-model-invocation: true` — REJECTED for pipeline skills: it removes the skill from Claude's context entirely, which breaks natural-language routing ("scan codebase ini", "pasang tools"); mega-sdd's ID/EN trigger phrases are a core feature.
- `when_to_use:` frontmatter — NOT adopted: descriptions already carry the what+when + trigger keywords within budget; duplicating them into `when_to_use` only inflates the always-loaded listing.
- Deterministic logic belongs in `scripts/` (e.g., `compute-lock-digests.sh`, `secret-scan.sh`) invoked with explicit "Run …" intent — per Anthropic "prefer scripts for deterministic operations".
- `context: fork` — PILOT LIVE on **`detect-drift` only** (v3.0.0, since 2026-06-26). A forked skill's body becomes the subagent prompt with NO conversation history, so it is viable ONLY for a standalone, non-interactive skill: `context: fork` is UNCONDITIONAL frontmatter, so the skill must NEVER call `AskUserQuestion` on any path and must NOT depend on chain-carried context a fork cannot harvest. detect-drift was reworked to meet that contract (deterministic input resolution → `drift_inputs_missing` blocker instead of a prompt; direction calls queued to `PENDING-SYNC.md` instead of an interactive walkthrough). The other chain-participating skills remain NON-candidates — they need `AskUserQuestion`. (v7.3.0: the memory_context/drift-history clauses died with the memory lane.) PreToolUse gates are preserved under fork (the Skill call is gated BEFORE the body forks); the blocker was always interactivity, not gate-keying — do NOT confuse this with Agent-tool offload, which bypasses the gates (matcher excludes `Agent`). Contract pinned by `tests/drift/test-detect-drift-fork.sh`; design + the standalone-footprint measurement: `research/2026-06-26-context-reset-fork-feasibility.md`. `agent:` (named-subagent dispatch from a skill) remains NOT adopted. Re-evaluate fork for `scan-codebase` / `bind-codebase` (also non-interactive) only after a live token before/after on detect-drift confirms the win — the one-shot comparator scripts (`measure-fork-tokens.sh` / `measure-fork-ab.sh`) were removed in v7 Fase 2 (procedure doc `research/2026-06-26-fork-token-measurement-procedure.md` + git history carry the method; re-create from there if the A/B is ever run). **Headless caveat (probed 2026-07-20, `research/2026-07-20-fork-ab-headless-attempt.md`): under `claude -p`, `context: fork` silently NO-OPS (the skill runs inline — 0 sidechains) and the Stop hook does not fire, while PreToolUse gates + SessionStart DO fire — so scripted/CI usage stays gate-safe, but the fork's token win does not exist there and the A/B must be run in interactive sessions.**
- Skill-scoped `hooks:` frontmatter — NOT adopted for the moat (evaluated 2026-06-11): the global PreToolUse gate must also see (a) Bash calls that could tamper with state files (anti-self-bypass) and (b) USER edits outside any skill lifecycle — both invisible to skill-scoped hooks. Global hooks stay; skill-scoped hooks remain an option for future skill-local, non-moat conveniences only.

> Sources: Anthropic *Skill authoring best practices* (platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) · Claude Code *Plugins reference* + *Create custom subagents* (code.claude.com) · superpowers "rules vs gates vs hooks" (blog.fsck.com). Full analysis: `research/2026-06-04-architecture-modernization-audit.md`.

## What we will not accept

- **Extra runtime dependencies.** Mega-SDD runs standalone; superpowers (or its vendored copy) is an optional enhancement, not a requirement.
- **Weakening the rails.** PRs that downgrade a BLOCKING gate to WARNING, let units skip acceptance tests, allow bolts to commit with `--no-verify`, or relax the binding gate.
- **Project-specific behavior.** Keep your own tweaks in a fork; plugin behavior must generalize.

## Skill / behavior change policy

Behavior changes require: a spec amendment (or new spec), updated `tests/skill-triggering/` fixtures, and reviewer acknowledgment. Don't reword skills for stylistic preference — they're tuned.

## Versioning & release

- **Plugin:** SemVer in `plugin.json` (single source of truth; `marketplace.json` must match). Major bump for breaking renames, rails changes, or marketplace incompatibility.
- **Skills:** per-skill `version:` in frontmatter; bump on content change.
- **Release:** run `scripts/sync-vendored.sh` (superpowers + ui-ux legs) and review vendored diffs → run trigger tests + fixtures → add a `CHANGELOG.md` entry → bump versions → tag.
- **MCP pins:** `.mcp.json` pins EVERY bundled server (`@playwright/mcp`, `@upstash/context7-mcp`) to an exact version — review each pin (registry-rot check) at each plugin version bump, like the marketplace.json parity check. Never a floating tag. The `@playwright/test` pin in `scripts/build-uat-e2e.sh` (the generated e2e `package.json`) is the same review class.

## Co-author attribution

Mega-SDD acknowledges [superpowers](https://github.com/obra/superpowers) by Jesse Vincent as design inspiration for the plugin patterns (anchor skill, hook injection, skill structure, subagent-driven execution). See `skills/_vendored/ATTRIBUTION.md`.

---

*Pre-v4 iteration history (the "Iter N" development log and retracted experiments) lives in git and `CHANGELOG-ARCHIVE.md`. It is not needed to work on the plugin.*

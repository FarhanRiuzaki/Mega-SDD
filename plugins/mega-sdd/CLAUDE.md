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

**What is actually enforced (PreToolUse, hard-block):** the binding→units gate, predictive preflight, scope-flag, anti-self-bypass, and the kept code-delivery quality gates (flow-coverage, render-test, sibling-consistency, ui-quality, cross-cutting-registration). **Advisory (surfaced via `/mega-sdd:analyze`, non-blocking):** dispatch-prompt, operator-UX, fan-out-parity, ui-deferral, vault-flow-staging. Everything else in skill bodies is design vocabulary + AI-coding-prompt scaffolding — best-effort, not enforced.

## Architecture (v4 lean-core)

- **Skills** (`skills/`) are lean routers (≤500 lines) using progressive disclosure — heavy detail lives in `references/*.md` loaded on demand. Don't reinflate a SKILL.md body.
- **Agents** (`agents/`) are first-class plugin subagents: `bolt-implementer`, `spec-reviewer`, `code-quality-reviewer`, `domain-extractor`. `execute-bolts` dispatches the bolt agents (two-stage review); `extract-intelligence` dispatches `domain-extractor` per wave. Plugin agents must NOT use `hooks`/`mcpServers`/`permissionMode` frontmatter (silently ignored).
- **Commands** (`commands/`) are the user's manual `/mega-sdd:` CLI entry points, one per pipeline step, each with an `argument-hint`. **Keep command↔skill parity — never delete a pipeline command in a cull**, even if a same-named skill exists.
- **Hooks** (`hooks/`) — SessionStart anchor injection; a synchronous PreToolUse gate aggregator; PostToolUse validators (write the state files); Stop telemetry + handoff validation.
- **`/mega-sdd:analyze`** is the consolidated consistency surface — runs the validators, emits `CONSISTENCY-REPORT.md`.

## What we will not accept

- **Extra runtime dependencies.** Mega-SDD runs standalone; superpowers (or its vendored copy) is an optional enhancement, not a requirement.
- **Weakening the rails.** PRs that downgrade a BLOCKING gate to WARNING, let units skip acceptance tests, allow bolts to commit with `--no-verify`, or relax the binding gate.
- **Project-specific behavior.** Keep your own tweaks in a fork; plugin behavior must generalize.

## Skill / behavior change policy

Behavior changes require: a spec amendment (or new spec), updated `tests/skill-triggering/` fixtures, and reviewer acknowledgment. Don't reword skills for stylistic preference — they're tuned.

## Versioning & release

- **Plugin:** SemVer in `plugin.json` (single source of truth; `marketplace.json` must match). Major bump for breaking renames, rails changes, or marketplace incompatibility.
- **Skills:** per-skill `version:` in frontmatter; bump on content change.
- **Release:** run `scripts/sync-superpowers.sh` and review vendored diffs → run trigger tests + fixtures → add a `CHANGELOG.md` entry → bump versions → tag.

## Co-author attribution

Mega-SDD acknowledges [superpowers](https://github.com/obra/superpowers) by Jesse Vincent as design inspiration for the plugin patterns (anchor skill, hook injection, skill structure, subagent-driven execution). See `skills/_vendored/ATTRIBUTION.md`.

---

*Pre-v4 iteration history (the "Iter N" development log and retracted experiments) lives in git and `CHANGELOG-ARCHIVE.md`. It is not needed to work on the plugin.*

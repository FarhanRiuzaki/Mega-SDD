# Research — Parallel Review Panel: code quality, security awareness, code standardization

**Date:** 2026-06-12 · **Status:** research complete, design proposal — not yet implemented
**Goal:** improve mega-sdd's generated-code quality, security awareness, and standardization via autonomous parallel reviewer agents — reusable, scalable, context-dependent.

Three research streams: (A) official Claude Code / Anthropic guidance, (B) industry best practice 2025–2026, (C) inventory of what mega-sdd already has.

---

## A. Official Claude Code / Anthropic guidance

- **Anthropic's `security-guidance` plugin** (official marketplace) uses a 3-layer architecture: per-edit pattern match (no model cost) → end-of-turn semantic diff review (async model call) → agentic commit review with contextual verification to cut false positives. Findings are surfaced as fix instructions, **not** hard blocks. Extensible per-project via `.claude/security-patterns.yaml` + a guidance markdown (additive overlay, never replaces built-ins).
- **Parallel subagent dispatch is supported and encouraged** for independent tasks: multiple Agent calls in one message run concurrently; no documented hard concurrency limit, but docs warn token usage multiplies. Code *review* lenses are independent → good parallel fit; code *writing* is not.
- **Read-only reviewer pattern** (documented): narrow task + `tools: Read, Grep, Glob, Bash` + `disallowedTools: Write, Edit` + structured output contract. A fresh model should try to refute the result — "the agent doing the work isn't the one grading it."
- Plugin agents support `model`, `effort`, `maxTurns`, `tools`/`disallowedTools`; `hooks`/`mcpServers`/`permissionMode` remain silently ignored (already in our CLAUDE.md).
- Anthropic's managed GitHub Code Review: parallel specialized agents + a **verification step to filter false positives** + severity tags; customizable via CLAUDE.md/REVIEW.md. Same shape we should emulate locally.

Sources: code.claude.com/docs/en/security-guidance.md · /code-review.md · /agents.md · /sub-agents.md · /plugins-reference.md · /hooks-guide.md · github.com/anthropics/claude-plugins-official.

## B. Industry best practice (2025–2026)

- **Risk baseline:** ~45% of AI-generated code carries OWASP Top-10-class flaws (Veracode 2025, 100+ LLMs). Dominant classes AI actually introduces: missing input validation/injection (CWE-20/89/78), authn/authz gaps (CWE-306/284/798), dependency risk incl. **hallucinated packages** (slopsquatting — ~5–22% of suggested packages don't exist), and **architectural drift** (semantic security bypass no linter can catch — needs spec-aware LLM review).
- **OWASP Top 10:2025** adds A03 Software Supply Chain Failures and A10 Mishandling of Exceptional Conditions (fail-open error handling — a classic LLM defect). Security rubrics should key to these + the AI-specific classes.
- **Shift-left into the agent loop:** the consensus moved scanning from CI into the generation loop — scan at write/commit time, feed findings back, regenerate until clean (Semgrep Guardian is the productized canon). A pipeline that owns the commit step (execute-bolts does) should gate the commit on the scan, not rely on git hooks (`--no-verify`-bypassable).
- **Tooling consensus (cross-language, agent-loop friendly):** `semgrep` (SAST, JSON out), `gitleaks` (secrets, ms-fast, offline — better in-loop than TruffleHog), ecosystem dep audits (`npm audit`/`pip-audit`/`cargo audit`/`composer audit`) + `osv-scanner` fallback, **new-dependency existence/age verification** before install (anti-slopsquatting), lockfile + hash pinning.
- **Hybrid review is the norm:** deterministic first (formatter, linter, types, tests, SAST — cheap, repeatable), LLM judge second **only for what machines can't decide** (spec conformance, authz semantics, duplication-vs-reuse judgment, architectural drift). LLM reviewers must not report what a linter covers — noise is the #1 reported failure of AI review bots (audit: 15% useless + 21% nitpick comments).
- **LLM self-review fails measurably** (self-preference bias; self-refinement amplifies it). Mitigations with evidence: independent fresh-context reviewer that never sees the implementer's report; decomposed analytic rubrics (−31.5% bias in one study); adversarial framing with mandatory file:line evidence; multi-lens panels with consensus weighting; deterministic results anchored into the judge's context.
- **Quality dimensions specific to AI code** (GitClear, 211M lines): duplication/failure-to-reuse is THE signature AI defect (8× duplicated blocks, refactoring collapsed, 2-week churn ~doubled); then tautological tests, over-engineering, dead code.
- **Standardization:** "linting is the executable spec" — auto-detect the repo's existing formatter/linter and run it (never impose one); ast-grep YAML for project idioms generic linters can't express; convention packs should carry project-specific deltas, not generic best practice the model already knows.
- **Parallel review architecture in the wild:** N read-only single-lens reviewers run blind + concurrent → mandatory merge/dedup/severity-rank step → gate by severity. 2–4 lenses is the sweet spot; findings without code citations are dropped at merge; consensus across 2+ lenses raises confidence. Cost: multi-agent ≈ 15× chat-token class — scale panel size to bolt risk; tier models per lens.

Key sources: owasp.org/Top10/2025 · genai.owasp.org (Agentic Top 10) · docs.semgrep.dev/guardian · Veracode GenAI Code Security 2025 · Endor Labs · Snyk/Trend Micro slopsquatting · GitClear 2025 · arXiv 2410.21819 / 2402.11436 (self-preference bias) · anthropic.com/engineering/multi-agent-research-system · factory.ai linters-direct-agents.

## C. What mega-sdd already has (extend, don't duplicate)

**Strong:** two-stage serial review (spec-reviewer sonnet → code-quality-reviewer opus, retry cap 3); 32 deterministic validators (5 blocking code-delivery gates + advisory via `/mega-sdd:analyze`); Hard Rules v2 (ast-grep YAML, pre/post-flight snapshots, blocking halts); 24 framework-convention packs with lint + registry machinery; `secret-scan.sh` (artifact redaction); model-tiers catalog; per-project `.mega-sdd/config.yaml`; the moat (binding gate, citation discipline, no fabrication).

**Gaps:**
- No dedicated **security-reviewer** agent (security is a side-duty of code-quality-reviewer); no SAST (semgrep) integration; no repo-code secrets scanner (only artifact redaction); no dep-audit / hallucinated-package check.
- No **linter/formatter invocation** in the bolt loop (the cheapest standardization ground truth is unused).
- Review is **serial**, anchored (quality reviewer runs after spec verdict), not a blind parallel panel.
- Packs have **no security-idiom section** ("CSRF required", "parameterized queries", "Argon2 hashing") and no toolchain (lint/format command) section.
- No complexity/duplication gate; no reuse-enforcement validator (reuse-index exists but unenforced at bolt time).
- No project-overlay for custom security patterns (Anthropic-style `.claude/security-patterns.yaml` extensibility).

---

## Proposed architecture — "Review Panel" (3 layers)

Pipeline per bolt (replaces the serial two-stage tail of execute-bolts):

```
bolt-implementer
  → L0 deterministic pre-gates (scripts, no model cost)
       format-fix → lint → semgrep → gitleaks → dep-audit + new-dep existence
  → L1 parallel LLM lens panel (blind, read-only, one Agent message)
       spec-reviewer | security-reviewer (NEW) | code-quality-reviewer | standards-reviewer (NEW)
  → L2 merge/dedup/severity-rank (main-thread conductor; depth-1 — respects the L3 fix)
  → gate: block Critical → re-dispatch implementer (existing retry cap) · surface Important · log Minor
  → commit
```

**L0 — deterministic pre-gates.** New pack section `## Toolchain` (detect-don't-impose: lint/format/typecheck commands per stack); new scripts `run-code-scan.sh` (semgrep changed-files), `scan-secrets-code.sh` (gitleaks; extends secret-scan.sh's role from artifacts to code), `validate-new-deps.sh` (audit + registry existence/age check). All optional-dep with graceful fallback (install-deps matrix gains semgrep, gitleaks, osv-scanner). L0 results are injected into L1 prompts so LLM lenses skip machine-caught issues. Blocking per doctrine only where critical + un-promptable: leaked secret and Critical SAST finding; the rest advisory → `/mega-sdd:analyze`.

**L1 — the parallel panel.** Two new agents (read-only: `tools: Read, Grep, Glob, Bash`):
- `security-reviewer` — rubric keyed to OWASP Top 10:2025 + AI-specific classes (input validation, authz gaps vs unit spec, secrets, hallucinated/unvetted deps, fail-open error handling, architectural drift). Model: opus (semantic authz/drift needs it).
- `standards-reviewer` — rubric = convention pack + codebase-map conventions; only judges what L0 linters can't express. Model: haiku/sonnet (cheap lens).
Existing agents adjust: code-quality-reviewer drops security duties, prioritizes GitClear defects (duplication/failure-to-reuse vs reuse-index, tautological tests, over-engineering), explicitly excludes linter-covered findings. All lenses run **blind** (no implementer report, no sibling verdicts), evidence mandatory (file:line or dropped at merge).
Rubrics live as reusable plugin-root refs: `references/review-lenses/{security,quality,standards,spec}.md`.

**L2 — merge in the conductor (main thread).** Dedup by file:line, consensus weighting (2+ lenses → confidence up), severity gate. No new hooks — the gate is conductor prose + the existing PreToolUse blocker file mechanism, per gates>rules>hooks.

**Context-dependent scaling (risk-tiered panel).** Panel size derives from unit risk signals: target_files count, overlap with pack `auth_hints`/`authz_hints` globs, new deps present, UI surface. Low risk → L0 + spec-reviewer only; medium → + quality; high (auth/payment/multi-file/new-deps) → full 4-lens panel. Config surface in `.mega-sdd/config.yaml`: `review_panel: auto|full|minimal` + per-lens toggles. Project overlay `.mega-sdd/security-patterns.yaml` (additive, Anthropic-style).

**Reusability:** lens rubrics are plugin-root references (stack-agnostic); stack specifics live in packs via two new sections (`## Toolchain`, `## Security idioms`) flowing through the existing pack lint/registry machinery; per-project deltas via config + overlay — nothing hardcoded in skill bodies (tech-agnosticism rule).

## Suggested phasing

1. **Phase 1 — the panel:** security-reviewer + standards-reviewer agents, lens rubrics, parallel blind dispatch + L2 merge in execute-bolts, risk-tiering, config keys. (Highest leverage, no new native deps.)
2. **Phase 2 — deterministic floor:** `## Toolchain` pack section + lint/format-fix in bolt loop; semgrep/gitleaks/dep-audit scripts; install-deps matrix entries; the two blocking gates (secret, Critical SAST).
3. **Phase 3 — pack security idioms:** `## Security idioms` section across the 24 packs + emit into unit Hard Rules where expressible as ast-grep.

Doctrine check: L0 scripts = deterministic rules; secret/Critical-SAST = the only new hook-blocking gates (critical + un-promptable); panel verdicts = self-checked gates in conductor prose; everything else advisory via `/mega-sdd:analyze`. Cost honesty: full panel ≈ 15× tokens of a bare bolt — risk-tiering is what keeps this sane by default.

# Review Panel — parallel blind reviewer lenses for execute-bolts (Phase 1)

**Date:** 2026-06-12 · **Research:** `research/2026-06-12-review-panel-quality-security-standards.md`
**Scope:** Phase 1 of 3 — the parallel LLM lens panel. Phase 2 (deterministic toolchain floor: lint/format in-loop, semgrep, gitleaks, dep-audit) and Phase 3 (pack `## Security idioms`) are follow-ups.

## Problem

The bolt review tail is a serial two-stage chain (spec-reviewer → code-quality-reviewer) with three weaknesses the research quantifies:

1. **Anchoring** — the quality reviewer runs after (and aware of) the spec verdict; serial chains drift toward rubber-stamping.
2. **Security is a side-duty** — one bullet inside code-quality-reviewer. ~45% of AI-generated code carries OWASP Top-10-class flaws; authz gaps and architectural drift are *semantic* defects only a dedicated spec-aware lens catches.
3. **No conventions lens** — nothing judges generated code against the framework pack / surrounding-code conventions beyond Hard Rules.

## Design

### Per-unit flow (replaces the two-stage tail)

```
bolt-implementer DONE
  → select panel tier (risk-based, see below)
  → dispatch ALL selected lenses in ONE message (parallel, blind, read-only)
       spec-reviewer · security-reviewer (NEW) · code-quality-reviewer · standards-reviewer (NEW)
  → MERGE in the main-thread controller (depth-1 preserved):
       drop findings without file:line evidence → dedup by (file, line, class), keep max severity
       → 2+ lens consensus = elevated confidence
  → gate: spec ❌ OR any Critical → re-dispatch bolt-implementer with the merged issue list
          (shared --max-retries cap) · Important → surfaced in bolt-report (mergeable) · Minor → logged
  → post-flight Hard-rule scan → commit (unchanged)
```

**Blind protocol (the anti-self-leniency rail):** every lens prompt contains the unit body + base/head SHAs + lens-specific context ONLY — never the implementer's report, never another lens's verdict. Findings without a code citation are presumed hallucinated and dropped at merge.

### New agents (read-only: `tools: Read, Grep, Glob, Bash`)

- **`security-reviewer`** (opus — semantic authz/drift reasoning): rubric keyed to OWASP Top 10:2025 + the AI-specific classes (missing input validation/injection, authn/authz gaps vs the unit spec, hard-coded secrets, hallucinated/unvetted new dependencies, fail-open error handling, architectural drift that bypasses a security control without a syntax violation).
- **`standards-reviewer`** (sonnet — pattern recognition vs pack/conventions): judges only what a formatter/linter cannot auto-fix — naming/location/idiom conformance against the framework pack slice + codebase-map conventions + 2–3 sibling files ("match the surrounding code"). Explicitly forbidden from generic style nits.

`code-quality-reviewer` narrows: security moves to the security lens; priority shifts to the measured AI defects — duplication / failure-to-reuse (vs reuse-index), tautological tests, over-engineering — and it must not report machine-fixable style.

### Risk-tiered panel (context-dependent cost control)

Full panel ≈ 15× single-agent token class — tiering is what makes always-on review sane.

| Tier | Lenses | Selected when |
|---|---|---|
| `minimal` | spec | ALL: ≤2 target files · no risk signal · no new files |
| `standard` (default) | spec + quality | anything not minimal/full |
| `full` | spec + quality + security + standards | ANY risk signal: target_files overlap pack `auth_hints`/`authz_hints` globs · a dependency manifest in target_files · ≥4 target files · unit body touches auth/session/crypto/payment/upload · binding_refs cite constitution §B |

Override chain: `--review-panel=<tier|auto>` CLI flag > `.mega-sdd/config.yaml` `review_panel:` > `auto`.
Models per `references/model-tiers.md` (new catalog rows §security-reviewer, §standards-reviewer) — never hardcoded.

### Doctrine compliance

- **Depth-1 preserved** — lenses are dispatched by the main-thread controller exactly like the old two-stage flow; the merge runs in the controller, not a sub-controller.
- **Gate, not hook** — the Critical-blocks-commit rule is conductor prose (a self-checked gate); no new PreToolUse surface. The deterministic Hard-rule scan + existing blocking gates are untouched.
- **Tech-agnostic** — lens rubrics are stack-free; stack specifics arrive via the pack slice in the dispatch prompt.
- **No fabrication** — evidence-or-drop at merge mirrors the citation discipline invariant.

## Files

Create: `agents/security-reviewer.md`, `agents/standards-reviewer.md`, `skills/execute-bolts/references/review-panel.md`, `tests/review-panel/*`.
Edit: `superpowers-bridge.md` (flow), `execute-bolts/SKILL.md` (flag + routing, v2.12.0), `code-quality-reviewer.md` (narrowed), `spec-reviewer.md` (description), `batch-and-fanout.md` + `squad-subagent.md` (two-stage → panel wording), `model-tiers.md` (catalog 19–20), `project-config.md` (`review_panel:`), plugin `CLAUDE.md` + `README.md` (agent list), `CHANGELOG.md`, `plugin.json`/`marketplace.json` → 4.21.0.

## Acceptance

- Panel agents exist, read-only, no forbidden frontmatter keys, adversarial + evidence-disciplined (pin tests).
- superpowers-bridge describes parallel blind dispatch + controller merge; depth-1 rationale intact.
- Risk tiers + override chain documented in review-panel.md and project-config.md.
- `claude plugin validate .` passes; `tests/review-panel/run-all.sh` green.

## Phase 2 addendum — L0 deterministic floor (implemented same day)

Machine gates run between implementer DONE and the panel, scoped to the bolt diff (`references/code-gates.md`):

1. **Toolchain** (`scripts/detect-toolchain.sh`) — detect the repo's OWN formatter/linter/typechecker from config evidence (prettier/biome/eslint/tsc, ruff/black/mypy, gofmt/golangci/go-vet, rustfmt/clippy, pint/php-cs-fixer/phpstan/psalm, rubocop); **detect, never impose**. Format failures auto-fix + re-check; lint/typecheck failures are findings. Optional pack `## Toolchain` override (project packs only).
2. **Secrets** (`scripts/scan-secrets-code.sh`) — gitleaks on the diff, plugin-regex fallback when absent (always scanned). Finding → halt `secret_in_code`, no override path.
3. **SAST** (`scripts/run-code-scan.sh`) — semgrep on changed files; absent/failed tool = visible SKIP, never fabricated "clean". ERROR severity → halt `sast_critical_finding`.
4. **New-dep existence** (`scripts/validate-new-deps.sh`) — anti-slopsquatting: every ADDED dependency across 7 manifest kinds verified against its official registry; 404 → halt `dep_not_found`; offline → `unverified` warning (fail-open with note).

L0 JSON is injected into every panel lens prompt as `## Deterministic scan results` (machine fact — blindness intact). Opt-out: `code_gates: false` / `--no-code-gates` disables toolchain+SAST only; **secrets and dep-existence always run** (the critical + un-promptable pair). install-deps matrix gains semgrep/gitleaks/osv-scanner. Tests: `tests/code-gates/` (functional smoke on fixtures + wiring pins). execute-bolts → 2.13.0; plugin → 4.22.0.

Phase 3 (pack `## Security idioms` emitted into Hard Rules) remains the open follow-up.

## Phase 4 addendum — floor-vs-ceiling (live-app design judgment, 2026-06-12)

Field finding (clinic-project, browser-verified): the design pipe shipped, the floor passed (tokens/states/a11y/page-shell), but the result was still "basic banget" — a lone centered card in whitespace, no branding, no iconography, flat hierarchy. Root cause: 9 of `modern-baseline.md`'s 10 non-negotiables are binary floor checks provable from code; "distinctive, not generic" is the one that needs the RENDER and so was the weakest-enforced.

- **`modern-baseline.md §Ceiling moves`**: an explicit distinctiveness contract on top of the floor — page furniture (header/nav/footer), width-filling composition (not a lone card), iconography, layered hierarchy, a style signature, purposeful motion, product-fit density. Framed as "the floor is NOT the goal." Injected into the implementer prompt (design slice) AND the design lens rubric.
- **`design-reviewer` upgrade**: "floor met, ceiling absent" = **Important** (generic), not a pass; and when rendered screenshots are present, judge the actual render — with a hard rail never to imply a render it didn't see.
- **`scripts/capture-views.sh`** (the live-app lens, ECC Batch 3 scoped): screenshots the unit's routes when a dev server is up (`preview_url`), feeding the design lens the render. **Stack-agnostic** — hits URLs, so any stack qualifies; driver tries system Chrome/Chromium (no Node — PHP/Python/Ruby/Go repos) then npx playwright. Every failure (server down, no driver, no URL) is a graceful SKIP; an un-captured render is never reported as fine. `tests/design-ceiling/`. plugin → 4.26.0.

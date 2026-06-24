# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Pre-v3.27.0 history rotated to [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** on 2026-05-26. Rotation rule: when this file exceeds 2,000 lines OR 30 versions, oldest 50% rotate to archive.

## [4.34.0] - 2026-06-24

### Added — CI + C# AST extraction (gap audit #2 + #1 cont.)

- **CI** (`.github/workflows/tests.yml`): runs every `tests/**/test-*.sh` (moat, graph, design-intelligence) and validates all framework-convention packs on push/PR to main. Closes gap #2 (no automated test runs).
- **C# AST query** (`scan-codebase/queries/tags-csharp.scm`): .NET repos now get AST-level symbol extraction (class/interface/struct/enum/record/method/constructor/**property**) instead of regex-only — properties captured as field definitions so .NET DTOs/entities get field-level binding. Upgrades gap #1 from "recognized" to "AST-extracted".
- Remaining for gap #1: a `.NET` framework-conventions pack (convention idioms) — deferred; `_universal` applies until then.

## [4.33.0] - 2026-06-24

### Added — .NET recognized by scanner (gap audit #1, partial)

- `scan-codebase` now detects .NET: `*.csproj`/`*.sln`/`*.fsproj` manifests, `dotnet test` (xunit/nunit/MSTest) test framework, and ASP.NET Core / EF Core framework fingerprints. A .NET repo is no longer invisible (was falling through to `_universal`). Regex-tier extraction; AST query (`tags-csharp.scm`) + a .NET framework-conventions pack remain (tracked in `research/2026-06-24-skills-gap-audit.md` #1).

## [4.32.0] - 2026-06-24

### Changed — router NL-routing for diagnostic/output skills (gap audit #3)

- `using-mega-sdd` now routes `analyze`, `graph`, `memory`, `emit-fsd`, `emit-agents-md`, `install-deps` on natural language (EN+ID triggers), not just explicit `/command`. Closes the 6-skill router-orphan gap surfaced by the 2026-06-24 skills gap audit (`research/2026-06-24-skills-gap-audit.md`).
- Added the gap audit itself as a durable artifact under `research/`.

## [4.31.0] - 2026-06-24

### Changed — anti-over-engineering discipline (ponytail-inspired), shift-left into the bolt panel

- `bolt-implementer` now climbs an explicit **build ladder** before writing (reuse → stdlib → native platform/framework → already-installed dep → minimum code) — over-engineering is avoided pre-write, not just caught in review (fewer reject loops). The ladder shortens the solution, never the reading.
- `code-quality-reviewer` over-engineering findings now carry a terse, actionable tag taxonomy (`delete:`/`stdlib:`/`native:`/`yagni:`/`shrink:`), one line per finding, with an optional `net: −N lines possible` on the Assessment. Severity grading and the panel contract are unchanged.
- No new agents, no per-pack duplication: mega-sdd already enforced reuse-first (Iron Rule #4) and YAGNI; this sharpens *when* (shift-left) and *how legibly* over-engineering is surfaced.

## [4.30.0] - 2026-06-24

### Added — derived graph layer (`mega-sdd:graph`)

- New project-scope derived graph `.mega-sdd/graph.json` over existing artifacts (vault.json, binding.json, units, modules.yaml, KB) — no code re-scan.
- New `/mega-sdd:graph --impact <id|file[:line]> [--upstream|--downstream]` blast-radius query, every edge citing its source artifact + field.
- `bind-codebase` now emits a structured `binding.json` sidecar (Step 4.5) guarded by `validate-binding-json.sh` parity gate.
- Freshness gate: lazy rebuild on source-glob path-set / hash change; binding-vs-HEAD staleness banner pointing to `/mega-sdd:sync`. Graph stays out of every chain; `sync` cache-warms it (non-blocking).
- Anti-hallucination preserved: no inferred edges; unresolved references become `[Pending]` nodes.

## [4.29.0] - 2026-06-15

### Added / Changed — extract-intelligence is now genuinely tech-agnostic (not PHP-tuned) + P6 dynamic-dispatch

extract-intelligence (EI) is the front gate for reverse-engineering legacy. Its reasoning *structure* was already stack-agnostic, but the agent-facing implementation carried PHP-only illustrative vocabulary and a PHP/SQL-only tech-leak gate — biasing extraction toward PHP idioms and silently missing C#/Java/Go/Rust cases, especially **dynamic** ones (DI, reflection, attribute-routing). This aligns EI with the long-standing plugin contract: *"the pipeline must work for ANY supported stack, not just PHP/JS."* Spec: `docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md`.

- **Concept-first disciplines + STACK IDIOM TABLE.** DEEP DISCIPLINES P1–P3 (`skills/extract-intelligence/references/wave-dispatch-templates.md`) rewritten stack-neutral, backed by a new per-stack idiom table (PHP / JS-TS / Python / C#-.NET / Java / Go / Ruby / Rust) so every wave subagent gets concrete anchors for whatever the legacy is written in. SKILL.md §Deep disciplines vocabulary kept in sync.
- **P6 — Dynamic dispatch & runtime wiring (new falsifiable principle).** Captures call sites resolved at runtime (DI-container resolution, reflection/`dynamic`, attribute/annotation/convention routing, interface → implementation dispatch, event/delegate/middleware wiring) — the inverse of P2 and the dominant silent-miss on DI/reflection-heavy stacks. New REPORT BACK fields `dynamic_seams_found/resolved/open` + self-check rail; unresolvable seam → `[OPEN]`, never an invented target.
- **Extraction Completeness Contract grows to six principles.** `P6_dynamic_dispatch` added to `scripts/validate-extraction-scorecard.sh` REQUIRED_PRINCIPLES, scorecard JSON (schema 1.1), and the SKILL.md §Step 5.6 derivation table. **Version-gated back-compat:** a scorecard from a pre-1.11.0 extractor (no P6) is NOT failed for missing P6 — it degrades to an advisory; P6 is required only from 1.11.0+.
- **Per-stack tech-leak gate — `scripts/kb-leak-scan.sh` (new).** Replaces the hardcoded `grep 'varchar\|int(11)\|MySQL\|MSSQL\|composer'` inline gate. Detects the legacy stack from `.scan-meta.json` (or `--stack=`), else applies the union of every stack's leak tokens; section-aware (skips `## 11.` bodies) and dir-aware (skips `50-integrations/`). Advisory by default (preserves the old non-blocking contract); `--strict` exits 1 on hits. Catches C#/Java/Go/Rust leaks the old grep let through.
- **Skill version:** `extract-intelligence` 1.10.0 → 1.11.0. No new runtime dependency; existing five-principle verdict logic and the scorecard SKIP-on-absent contract unchanged. scan-codebase/bind-codebase C# first-class support (tree-sitter grammar, `.csproj` detection, ASP.NET pack) is explicitly out of scope — a separate deterministic-engine effort.

## [4.28.1] - 2026-06-13

### Fixed — compaction advisor over-reported every 1M-context session ~5× (false `/compact` nag)

The phase-aware compaction advisor (`hooks/user-prompt-submit`, added 4.27.0 / relocated 4.27.1) detected the context window with `"[1m]" in model`. But `[1m]` is a Claude Code **display alias** — it never reaches the transcript's `message.model`, which records the wire id (`claude-opus-4-8`, `claude-fable-5`). So the window always fell back to the 200k default and every 1M-context session was scored ~5× too high — surfaced live in the clinic runtime test: a Fable-5 bolt session at a healthy 254k (25% of 1M) was reported as **127% of 200k**, triggering a `/compact` recommendation at ~16% of the real window → premature compaction, real context lost.

- **Window now resolved from three signals, biased to the larger window** (a false silence is harmless — PreCompact still snapshots; a false `/compact` nag burns real context): the `[1m]` marker if present; OR a current 1M-context model family (`claude-opus-4*` / `claude-sonnet-4*` / `claude-fable*`); OR an **empirical** override — a context that physically exceeded 200k proves a >200k window (a true 200k session would have auto-compacted first). The empirical signal is model-agnostic, so future 1M model ids need no allowlist edit.
- `<synthetic>` turns are skipped when capturing the model id (they carry no real model).
- Verified end-to-end: both real clinic transcripts (Opus @143k, Fable @254k) now stay silent; the 200k path still fires at 85% (`170k of 200k`); the 1M path fires at 85% (`850k of 1000k`); an unknown model with >200k observed context resolves to the 1M window. Single-site fix; no other hook does window detection.

## [4.28.0] - 2026-06-12

### Added — multi-PRD lifecycle: project index + shared constitution + explicit router

A project that grows PRD-by-PRD (PRD 1 ships, PRD 2 adds an epic; docs can be PRD/BRD/Figma/brief) had real multi-vault support but no first-class linking — ambiguous, and PRD 2 could silently contradict PRD 1. Spec `docs/superpowers/specs/2026-06-12-multi-prd-lifecycle-design.md`.

- **Project index** (`scripts/build-project-index.sh` → `.mega-sdd/project.md`): derived manifest of every vault (slug, title, source, version, status intent/units-ready/in-progress/shipped, unit+bolt counts, area). The vault sequence IS the PRD/epic history, so a new vault knows what PRD 1..N-1 shipped. Regenerated at chain end (wired into `run-analyze.sh`); pure-read, exit 0 always. (Surfaced a real case immediately: the test clinic already had a shipped vault + a started v2 vault.)
- **Project constitution** (`.mega-sdd/constitution.md`, inherited by every vault): `bind-codebase` reads it before binding a NEW vault — a claim contradicting a project-locked clause (e.g. PRD 2 proposing a different datastore than the project locks) is a CONFLICT at the binding gate, never silently accepted. Keeps PRD 2..N inline. Absent = unchanged.
- **Explicit lifecycle router** (`using-mega-sdd`, contract in `references/multi-prd-lifecycle.md`): a new doc routes by what changed — same source revised → `diff-vault`; new epic → new vault + brownfield bind; code moved → `sync`. Doc-type agnostic; **when unsure, ASK** (evolve-in-place vs new-epic diverge hard).
- `tests/multi-prd/` (index functional on a 2-vault fixture + empty/non-sdd safety + wiring pins). Advisory/navigational — the only enforcement is the project-constitution CONFLICT at the existing binding gate (reuses the moat, no new blocking surface).

## [4.27.1] - 2026-06-12

### Fixed — official-docs conformance audit (2 real gaps; `research/2026-06-12-official-docs-conformance-audit.md`)

Deep audit of every hook/agent surface against code.claude.com/docs (two parallel agents + direct WebFetch of contested claims). The moat surfaces were already conformant; two gaps from this sprint fixed:

- **Compaction advisor was invisible (4.27.0).** It printed to the **Stop** hook's stdout — but per docs, Stop stdout is debug-log-only (Stop is not one of the stdout→context events) and the hook is async, so the advisory reached no one. **Relocated to a new `UserPromptSubmit` hook**, where docs confirm *"stdout is added as context that Claude can see and act on."* Same threshold (80% of the window) and `compaction_notice:` opt-out; now actually surfaces so Claude can suggest `/compact` at a phase boundary.
- **`MultiEdit` matcher (4.25.0).** Not a current Claude Code tool name. Dropped from the PreToolUse matcher, GateGuard case label, and parse tuple — now `Edit|Write` (the documented file-mutating tools).
- Verified CONFORM (no change): SessionStart/UserPromptExpansion raw-stdout→context (sub-agent's "JSON-only" claim disproved by direct fetch + the live-session anchor injection), PreToolUse `permissionDecision: deny`, PreCompact side-effect-only, plugin-agent frontmatter (only hooks/mcpServers/permissionMode banned; none used).

## [4.27.0] - 2026-06-12

### Added — ECC-adoption Batch 2: phase-aware compaction advisor + PreCompact state snapshot

Long mega-sdd chains (the clinic sync ran 26 min) have two compaction failure modes — compacting mid-bolt loses the controller's whitelist/dispatch context, and harness auto-compaction loses which phase/unit was in flight. Adopted from ECC's strategic-compact + memory-persistence (spec `docs/superpowers/specs/2026-06-12-compaction-advisor-design.md`).

- **Compaction advisor** (Stop hook, advisory): sums the transcript's true context size (`input + cache_read + cache_creation`, reusing the existing usage extractor), window-scaled (200k, or 1M on the `[1m]` marker). Over 80% AND a mega-sdd chain active → one line: "context ~Nk of ~Wk — a phase boundary is the safe place to /compact." Silent under threshold / for non-mega-sdd projects. Opt-out `compaction_notice: false`.
- **PreCompact snapshot** (new `hooks/pre-compact` on the PreCompact event): before the harness compacts, writes `.mega-sdd/.compaction-snapshot.json` — HEAD, trigger, in-flight phase guess (newest vault: units total, bolts done, last bolt unit), open PENDING-SYNC count. Pure reads, exit 0 always (never blocks compaction). SessionStart then surfaces one "resumed after a compaction at phase [X] — N units, M bolts done" line so the next window re-orients instead of re-deriving. Shares the `telemetry: false` opt-out.
- Both are advisory context, not gates (compaction is the user's call; the snapshot is insurance). `tests/compaction/` — snapshot phase-guess + degenerate-vault-still-exits-0 + advisor over/under threshold + opt-out + resume line.

## [4.26.0] - 2026-06-12

### Fixed/Added — floor-vs-ceiling: live-app design judgment (UI was "basic", not "kuno")

Browser-verified field finding (clinic-project): the v4.24 design pipe shipped, the floor passed (tokens, page shell, states, WCAG), but the rendered UI was still generic — a lone centered card in whitespace, no branding/nav, no iconography, flat hierarchy. Root cause: 9 of `modern-baseline.md`'s 10 non-negotiables are binary floor checks provable from code; "distinctive, not generic" needs the RENDER and was the weakest-enforced.

- **`modern-baseline.md §Ceiling moves`**: a distinctiveness contract above the floor — page furniture (header/nav/footer, not a bare heading over a card), width-filling composition (two-column / hero / grid, not a lone 480px card on a 1280px page), iconography, layered hierarchy, a style signature, purposeful motion, product-fit density. Explicit framing: "the floor is NOT the goal." Injected into the implementer prompt (design slice) AND the design-lens rubric.
- **`design-reviewer` upgrade**: "floor met, ceiling absent" is an **Important** finding (generic/undesigned), not a pass; when rendered screenshots are provided it judges the actual render, with a hard rail never to imply a render it didn't see.
- **`scripts/capture-views.sh`** (live-app lens, ECC Batch 3 scoped to this gap): screenshots the unit's routes when a dev server is reachable (`preview_url` config / unit frontmatter / operator). **Stack-agnostic** — capture hits URLs so the app can be any stack (Laravel/Blade, Django, Rails, Spring, a Node/Next SPA); the screenshot driver tries a system Chrome/Chromium (zero Node — PHP/Python/Ruby/Go repos) then npx playwright. Every failure mode is a graceful SKIP; an un-captured render is never reported as fine. Config `preview_url:`.
- `tests/design-ceiling/` — baseline→slice→dispatch→lens wiring + capture-views graceful-skip + stack-agnostic-driver pins.

## [4.25.0] - 2026-06-12

### Added — ECC-adoption Batch 1: instincts (closed learning loop) + GateGuard (LOCKED investigation gate)

Adopted from the affaan-m/everything-claude-code review (spec `docs/superpowers/specs/2026-06-12-instincts-and-gateguard-design.md`); both mechanisms re-shaped to mega-sdd's doctrine.

- **Instincts** (`memory/references/instincts.md`): atomic trigger→action learnings with confidence 0.3–0.9 (birth 0.5, +0.1 reconfirm capped 0.9, −0.2 on user correction, −0.1 staleness, retire <0.3), mandatory evidence (no fabricated learnings), project scope with auto-promotion to global (same key from ≥2 projects at avg ≥0.8 via `_seen.jsonl` ledger). **The point: bounded re-injection** — SessionStart appends a `<learned-instincts>` block (top 6, conf ≥0.7, 1200-char budget, advisory-explicit); matching-domain instincts also ride the bolt T2 historical-memory slice. Emission owned by the existing chain-end learning pass (Step 7.6) — no mid-chain evaluation. Opt-out `instincts: false`.
- **GateGuard** (pre-tool-use `Edit|Write|MultiEdit` branch; matcher widened): the FIRST edit touching a file anchored to a **[LOCKED]** claim is denied with the exact investigation prescribed (read the claim + binding verdict, Grep the file's importers, name the covering acceptance test; behavior changes routed via sync/propose-and-confirm) — **the retry passes** (deny-once; session-scoped state, 30-min expiry, 500-entry cap). Converts the LOCKED rule into a pre-edit gate — today LOCKED violations are only caught post-hoc (bolt drift check / sync). Index (`scripts/build-locked-index.sh`) parses binding/vault docs for `[LOCKED]` anchors, lazily rebuilt by the hook; **no LOCKED markers (typical greenfield) → inert, zero false positives**. Opt-out `gateguard: false`; state file intentionally NOT bypass-protected (deleting it merely re-gates — fail-safe direction).
- `tests/instincts-gateguard/` — functional fixtures (deny→retry-allow→new-session-regates→opt-out→greenfield-inert; conf-0.8 injected / conf-0.5 + retired excluded / opt-out honored) + wiring pins.

### Fixed

- Platform pins back to ALL PASS: P6 exemption casing in `code-gates.md` ("is NOT substituted") and the long-standing P7d — plugin README now names the full activation chain (`/plugin marketplace update mega-sdd` + `/reload-plugins`).

## [4.24.0] - 2026-06-12

### Fixed/Added — UI/UX awareness: the greenfield design pipe + a design lens

Field finding (clinic-project, greenfield): generated UI was default-browser "kuno" DESPITE generate-intent having written a full `vault.json design_system` (medical-clinic profile from `design-intelligence/product-style-map.yaml`). Root cause: the ONLY injection path for design context lived inside the starterkit branch of `context-enrichment.md` — no starterkit-context.yaml (every greenfield) → UI bolts received zero design guidance.

- **Design slice (the pipe fix)**: built INDEPENDENTLY of starterkit for any UI-bearing unit (target_files match pack `view_glob` or universal frontend shapes). Greenfield: vault `design_system` + the matching `style-principles[style]` slice + ux-rules floor + the new modern-baseline digest. Starterkit template remains AUTHORITATIVE when present (unchanged precedence). New T2 dispatch-prompt section `## Design system (UI-bearing unit)` with palette/typography anti-halu rails ("never invent a second palette").
- **`design-intelligence/modern-baseline.md`** (new): the injectable modern-UI floor — 10 non-negotiables (token layer, 4/8px spacing, type scale, page shell, interactive states, loading/empty/error states, designed forms, WCAG AA, styled data tables, distinctive-not-generic) + the anti-kuno tells list. Distilled from the existing ui-ux-pro-max distillation + Anthropic frontend-design philosophy.
- **`design-reviewer` agent (new, sonnet)**: 5th review-panel lens — judges UI code against the SAME design slice the implementer received (one contract, two sides): token discipline, layout composition, states, a11y, style conformance. ADDITIVE join: any tier, only when the unit is UI-bearing — pure-backend bolts never pay for it.
- `tests/design-aware/` pins the pipe end-to-end (baseline digests → context-enrichment slice → dispatch section → lens wiring → model-tiers row 21).

## [4.23.1] - 2026-06-12

### Fixed — field-audit of a real intent→bolts run (clinic-project): 3 enforcement gaps closed

A full pipeline test run shipped 16 bolt commits with ZERO `<vault>/bolts/` artifacts, bound against a degenerate codebase-map, and left OQ/constitution propagation FAILs — none of it caught. Root causes + fixes:

- **Orphan-bolt-commit gate (the big one)**: the bolt-report obligation was prose (Procedure Step 0/5) + a Stop gate that only fires on `--auto` handoffs; a terse interactive controller skipped both, and the file-scoped artifact validator can't see a file that was never written. NEW: `validate-bolt-artifacts.sh --orphan-scan` — repo-wide deterministic check (bolt commit subject `(bolt): U-XXX` + unit exists + no `bolts/U-XXX/bolt-report.md` → FAIL `.bolt-orphans-state.json`). Runs unconditionally from the Stop hook every turn end + in `/mega-sdd:analyze` (`bolt_orphans` boundary); the PreToolUse execute-bolts aggregator **blocks the next run** until reports are backfilled or units re-run. False-positive safe: bounded history (200 commits), only flags units that still exist in a vault.
- **bind-codebase degenerate-map gate**: the run bound against a codebase-map.md missing ALL 7 content sections — false grounding for every downstream verdict (invariant #1). NEW PreToolUse gate blocks `bind-codebase` while the map validator attests the empty-shell shape (partial maps are NOT blocked); fix is re-running scan-codebase.
- **Retired-clause false positive**: constitution-propagation demanded unit citations for a clause the constitution itself marks `*(dropped …)*` (mentioned in binding only as supersession context). The validator now exempts dropped/retired/superseded clauses.
- `tests/bolt-orphans/` (functional fixture repo + wiring pins incl. `bash -n` on every edited hook/script). Field remediation applied to the test project: 16 retroactive bolt-reports backfilled (provenance from git, `retroactive: true`, no fabricated test results) + 5 dropped OQ-IDs and 4 constitution clauses attached to their owning units → binding-units PASS, constitution-propagation PASS, orphan-scan PASS.

## [4.23.0] - 2026-06-12

### Added — `## Security idioms` across all 22 framework packs (Phase 3)

Closes the review-panel trilogy (spec `docs/superpowers/specs/2026-06-12-review-panel-design.md`): every full-tier pack now carries a `## Security idioms` section — stack-correct, mechanism-named, with **the dangerous bypass spelled out next to each idiom** (e.g. Laravel `{!! !!}`, Django `mark_safe`, Rails `html_safe`, axum routes added after `.layer()`, Next.js `NEXT_PUBLIC_` client-bundle leak, Spring `csrf().disable()`).

- **Schema** (`_template.md`): 9 canonical classes per stack — input validation, SQLi, XSS/escaping, CSRF, authn/authz enforcement point, password hashing, mass assignment, secrets/config, file uploads (+ optional session posture). A class that genuinely doesn't apply gets an honest per-bullet opt-out, never silence. Mechanically-expressible idioms route through the existing `## Hard Rules emitted` machinery — no parallel rules channel.
- **Consumption**: the review-panel `security-reviewer` lens receives the section as its pack security slice; `bolt-implementer` receives it via T2 framework-pack rules — generated code is born with the stack's security idioms, not retrofitted.
- Authored via the plugin's own pattern: 3 parallel blind subagents (one per language family) against a canonical Laravel exemplar + the cross-framework token ban; verified independently by `tests/security-idioms/` (exactly-one section, ≥7 class bullets, key classes present, per-pack) + the pack lint + token-leak suites.

## [4.22.0] - 2026-06-12

### Added — L0 Code Gates: the deterministic floor under the review panel (Phase 2)

Deterministic-first, LLM-second (spec `docs/superpowers/specs/2026-06-12-review-panel-design.md` §Phase 2 addendum): machine checks run on every bolt diff between implementer DONE and the panel — an LLM lens never burns context on what a linter, scanner, or registry lookup decides for free.

- **Toolchain detection** (`scripts/detect-toolchain.sh`): finds the repo's OWN formatter/linter/typechecker from config evidence across 7 ecosystems — detect, NEVER impose (no config evidence → no command). Format failures auto-fix + re-check (machine territory, not findings). Optional pack `## Toolchain` override for project packs (`_template.md`).
- **Secret scan on the diff** (`scripts/scan-secrets-code.sh`): gitleaks preferred, plugin provider-shaped regex fallback when absent — secrets are ALWAYS scanned; values never echoed. Finding → halt `secret_in_code`, no override path exists.
- **SAST** (`scripts/run-code-scan.sh`): semgrep over changed files only; tool absence/failure = visible SKIP with reason, never fabricated "clean". ERROR severity → halt `sast_critical_finding`.
- **Anti-slopsquatting** (`scripts/validate-new-deps.sh`): every ADDED dependency (package.json/composer.json/pyproject/requirements/go.mod/Cargo.toml/Gemfile) verified to EXIST on its official registry; definite 404 → halt `dep_not_found` (hallucinated package — never install around it); offline → `unverified` warning.
- L0 results injected into every panel lens prompt (`## Deterministic scan results` — machine fact, blindness intact); SKIPs recorded in the bolt-report so an unscanned run is never mistaken for a clean scan.
- Opt-out per doctrine: `code_gates: false` config / `--no-code-gates` flag disable toolchain+SAST only; **secrets + dep-existence always run** (critical + un-promptable). install-deps matrix + tooling-install gain semgrep/gitleaks/osv-scanner. `tests/code-gates/` (functional fixtures: planted AWS key → exit 1 + value never echoed; hallucinated npm package → NOT_FOUND blocking; empty repo → no tools imposed). execute-bolts → 2.13.0.

## [4.21.0] - 2026-06-12

### Added — Review Panel: parallel blind reviewer lenses in execute-bolts (Phase 1)

Research-driven (`research/2026-06-12-review-panel-quality-security-standards.md`; spec `docs/superpowers/specs/2026-06-12-review-panel-design.md`): the serial two-stage review tail is now a **risk-tiered panel** of read-only lenses dispatched **in parallel and blind** (no lens sees the implementer's report or another lens's verdict — the measured anti-rubber-stamp rail), merged in the main-thread controller (depth-1 preserved).

- **New agents**: `security-reviewer` (opus — OWASP-keyed: input validation/injection, authz vs unit spec, secrets, hallucinated/unvetted new deps, fail-open error handling, architectural drift) and `standards-reviewer` (sonnet — convention conformance vs framework pack + surrounding code; forbidden from machine-fixable nits). Both read-only, evidence-or-drop (`file:line` mandatory).
- **`code-quality-reviewer` narrowed**: security moved to the security lens; priority shifted to the measured AI defects — duplication/failure-to-reuse (vs reuse-index), tautological tests, over-engineering; linter-covered findings out of lane.
- **Risk-tiered panel** (`execute-bolts/references/review-panel.md`): `minimal` (spec) / `standard` (spec+quality, default) / `full` (all 4 — fires on auth/authz-glob overlap, dep-manifest in target_files, ≥4 files, auth/payment/crypto keywords, constitution §B binding_refs). Override chain: `--review-panel=` flag > `.mega-sdd/config.yaml` `review_panel:` > auto. Models cited from `model-tiers.md` (rows 19–20), never hardcoded.
- **Merge + gate in the controller**: evidence-or-drop → dedup at max severity → 2+-lens consensus marks → spec ❌ or any Critical re-dispatches the implementer (shared `--max-retries`); Important/Minor recorded in bolt-report `## Review panel`. The deterministic post-flight Hard-rule scan is unchanged — panel is judgment, scan is the contract.
- execute-bolts → 2.12.0; squad/batch fan-out wording updated (panel replaces two-stage; depth-1 rationale intact); `tests/review-panel/` pin suite (agents read-only + no forbidden frontmatter, blind protocol, risk signals, catalog rows, no stale two-stage wording).

## [4.20.1] - 2026-06-11

### Fixed — adversarial bug hunt on the freshly-shipped surfaces (2 REAL + 2 LATENT, all verified by repro)

- **validate-handoff-yaml.sh parser collapsed 2-level nesting**: BLOCK-style `suggested_args:` items under `next_action:` clobbered the parent dict → the `scope_args_missing` check silently no-fired on block-style handoffs (false negative; inline form was unaffected). Parser now tracks the pending nested key; repro'd both directions + new pin D8d.
- **memory-write.sh stale-lock race**: the rmdir+mkdir steal let a second process rmdir the winner's FRESH lock — both then "held" it. Steal is now an atomic `mv` (exactly one winner).
- **secret-scan.sh --redact** now preserves the file's permission bits (0600 stayed 0600 in repro; was rewritten as default umask).
- **compute-unit-staleness.sh** tolerates unreadable paths (perm/NFS/overlong) as missing instead of crashing.
- **pre-tool-use emit_block no-python3 fallback** sanitizes quotes/backslashes/newlines so the deny JSON stays valid.
- Hunt discipline held: 2 agent claims REFUTED with evidence (stop-hook if/fi nesting — disproved by functional smoke + read; closure-binding concern — checked correct). Stdin-first stop path smoke-proved end-to-end (empty transcript → handoff from `last_assistant_message`, single-prefix skill name).

## [4.20.0] - 2026-06-11

### Fixed — platform-assumption sweep: 5 verified WRONGs against current Claude Code docs

The AGENTS.md/worktree bug class, hunted systematically (3 doc-verification agents + manual fetches; every fix doc-quoted):

- **MOAT: PreToolUse block format** — `{"continue": false}` is NOT processed for PreToolUse (it session-halts on other events); the gate now emits `hookSpecificOutput.permissionDecision: "deny"` + legacy `decision: "block"` rider. All moat/fmea tests updated and green.
- **MOAT: /command bypass closed** — typing `/mega-sdd:execute-bolts` expands without a PreToolUse Skill event; new `hooks/user-prompt-expansion` gate (UserPromptExpansion, `decision: "block"`) blocks the expansion itself when the blockers state isn't PASS (functional 2-state test).
- **pandoc failure detection was dead code** — PostToolUse fires on SUCCESS only and carries no `exit_code` field; failures route via the newly-wired `PostToolUseFailure` (matcher Bash) into the same handler.
- **stop-hook fossil removed** — a second, older handoff-validation block re-ran the validator AFTER the fixed one and overwrote its state with the pre-Iter-74 doubled-prefix skill name (re-introducing a fixed bug); now ONE pass, preferring the documented `last_assistant_message` stdin field over transcript parsing (transcript scan kept as fallback).
- **`${CLAUDE_PLUGIN_ROOT}` in references/** — substitution happens in skill/agent/hook content only; reference files are Read raw and the var is NOT exported to the Bash tool → 6 sites now use `<plugin-root>` + a derivation note (the `:-../..` fallback was CWD-relative and wrong).

Also: SessionStart matcher gains `resume` (guards + staleness notice re-fire on resumed sessions); propose-and-confirm AskUserQuestion trimmed to the platform's 4-option cap; AAIF link fixed (Agentic AI Foundation, aaif.io — old URL 404); `/reload-plugins` named as the canonical refresh; ghost `superpowers:reverse-engineering-legacy-codebase` reference removed; exit-code comment corrected (only exit 2 blocks); fork-a-recovery-map block-format prose corrected.

Tests: `tests/platform/test-platform-pins.sh` (15 pins incl. functional UPE gate).

## [4.19.0] - 2026-06-11

### Added — adopt-now roadmap executed (carefully): worktree-proofing, interop pair, CI recipe, EARS tier

Each item verified against the official docs before adoption; two items deliberately NOT flipped, with recorded evidence.

- **Worktree-proofing**: every git-state probe now uses `git rev-parse --git-path …` (rebase/merge state, client hook detection); scan walk-up tests `-e` not `-d` (in a linked worktree `.git` is a FILE). Fixed the v4.18 rails' own literal `.git/...` probes. execute-bolts → 2.11.0, scan-codebase → 2.13.0.
- **AGENTS.md interop pair**: emit-agents-md Step 6.5 offers the OFFICIAL Claude Code bridge — Claude Code does NOT read AGENTS.md natively; the sanctioned path is an `@AGENTS.md` import in CLAUDE.md. Stub creation/append is consent-gated (CLAUDE.md is user-owned). emit-agents-md → 1.4.0.
- **Headless/CI recipe** (`references/ci-recipe.md`): PR drift gate, sync-on-merge, pure-script exit-code gates; surface table (hooks fire under `-p`/action, NOT under `--bare` — script gates are the CI-stable layer); CI never auto-resolves PENDING-SYNC.md (the moat). Wired from README + project-config.
- **EARS structured-criteria tier** (optional, additive): `acceptance_test[].ears` — "WHEN <trigger> THE SYSTEM SHALL <response>"; when present the bolt's TDD test asserts exactly that statement (PBT may derive from it); absent → prose `expects:` unchanged, validators tolerate absence. generate-units → 2.8.0.
- **Capability decisions recorded** (CLAUDE.md §Capability-adoption, do not re-propose): `context: fork` PILOT-GATED — forked skills get NO conversation history, so chain skills lose their handoff `metadata.memory_context` and interactive steps lose AskUserQuestion; no clean candidate today. Skill-scoped `hooks:` NOT adopted for the moat — the global PreToolUse gate must also see Bash state-file tampering and user edits outside any skill lifecycle.
- Tests: `tests/roadmap/test-roadmap-pins.sh` (10 pins).

## [4.18.0] - 2026-06-11

### Added — FMEA rails + future roadmap (spec `2026-06-10-fmea-and-future-roadmap.md`)

Per-phase edge-case audit (4 parallel passes: upstream 62 cases / downstream 36 / environment / cited ecosystem research). 71% of stressed cases were already covered; the rails below close the verified HIGH-likelihood gaps. Every lead re-verified before shipping.

- **Moat fail-closed without python3** (the one verified moat hole): pre-tool-use shell fallback — when python3 is absent, execute-bolts is BLOCKED unless `.validation-blockers.json` attests PASS. Functionally tested in 3 states (FAIL→block, PASS→allow, non-gated→allow) under a no-python PATH harness.
- **extract-intelligence secret-scan gate** before every KB file write (legacy creds no longer ride into KB citations; artifact redacted, source never edited). extract-intelligence → 1.10.0.
- **scan-codebase rails**: never follow symlinked dirs (loop hang); >10MB files skip tree-sitter; monorepo with app-root manifests in multiple dirs → ask the PRIMARY app once. scan-codebase → 2.12.0.
- **binding.md REGENERATED banner** (manual verdict edits are lost on re-bind — resolutions belong in resolve-oq) + binding.md now written while HOLDING the vault.json lock (two concurrent binds can't interleave). bind-codebase → 2.5.0.
- **execute-bolts rails**: parallel waves never share intersecting `target_files` (serialize, don't race); pre-flight 3.5 probes the ecosystem's TEST RUNNER (absent → `dep_missing`; "TDD without a runner is fiction"); new `commit_rejected_by_hook` halt for husky/pre-commit/GPG rejection (`--no-verify` stays forbidden); mid-rebase/merge repo state → stop. execute-bolts → 2.10.0.
- **generate-units scale advisory**: >100 units warn, >500 confirm. generate-units → 2.7.0.
- **PENDING-SYNC.md lifecycle**: archive resolved rows at 100KB/50-resolved → `PENDING-SYNC.archive.md`; loud triage notice at >50 open; `⚠ stale?` marker when the vault moved since queueing. orchestrate-flow → 2.8.0.
- **sync git-state guard**: mid-rebase/merge → stop before scanning garbage.
- **Headless/CI section** in project-config.md (`--auto` everywhere; `--bare` bypasses hook gates — the script-form gates are the CI-stable surface) + **multi-dev note** in paths.md (vault.json/binding.md git-merge corruption; one-writer discipline or gitignore-the-derived).
- generate-intent → 2.7.0 (KB consumption hardening carried in).
- **Future roadmap** (cited): adopt-now = context-fork pilot, skill-scoped hooks for bolt guards, worktree-proof paths, AGENTS.md interop pair; prepare = unit-DAG-as-workflow-plan, CI recipe, optional EARS criteria tier; validated = lean-core does NOT expire at 1M context (description budgets tightened upstream); not-yet = ultracode rebuild, SDK port, MCP servers, shared-memory features.
- Tests: `tests/fmea/test-fmea-pins.sh` — 16 pins incl. the 3-state functional python3-absent gate test.

## [4.17.0] - 2026-06-10

### Changed — redundancy + process-waste audit: optimize without touching the moat

3-layer audit (execution redundancy / contract-prose duplication / hot-path overhead); every lead re-verified before acting — refuted leads NOT applied: glossary pre-parse already fully specified; constitution_hash/prd_sha256 recomputes are intentional fresh-vs-recorded safety comparisons; sync changed-paths already computed once; deep-scan manifest pre-parse already shared; vault.json design_system + phase fields already consumed.

**Hot path:**
- `pre-tool-use`: the 1-stat `.mega-sdd` existence check now runs BEFORE the config grep — fastest exit for every tool call in non-SDD projects; the moat gate path is unchanged (verified empirically + all moat tests green).
- `post-tool-use`: the 6 independent unit-write validators now run in PARALLEL (+`wait`) instead of 6 sequential spawns — each writes its own state file; PreToolUse stays the consumer.

**Execution redundancy:**
- detect-drift Step 1.5 REUSE FIRST: adopts codebase-map §7 framework (confidence ≥ medium + stamp == HEAD) instead of re-parsing manifests the scan already parsed; manifest detection remains the fallback + the vault-stack safety check. detect-drift → 2.7.0.
- generate-intent OQ classifier memoization: unchanged-text OQs reuse their existing classification on re-runs; human overrides never silently overwritten. generate-intent → 2.6.0.
- code-quality-reviewer agent aligned to the model-tiers catalog (sonnet → opus; the catalog's own example documents sonnet as the USER override, not the default).

**Anti-drift (duplicated contracts were already drifting — all verified):**
- Phantom vault filenames eradicated: `04-functional-spec.md` → `04-flows.md` (kb-submode ×2), `01-entities.md` → `03-data-model.md` (binding-contract). bind-codebase → 2.4.0.
- KB read-path priority unified to the 4-path order (paths.md was missing `docs/mega-sdd/knowledge-base/` while being cited as the authority).
- Manifest-detection membership fixed: scan-codebase Step 2 gains `Gemfile` + pointer to the owning table; detect-drift repo-probe gains Python manifests. scan-codebase → 2.11.0.
- install-deps handoff enum gains `choco` (support was claimed, enum omitted it). install-deps → 1.3.0.
- handoff-contract.md: scan-codebase block no longer contradicts the skill's own emission spec (bind-codebase → CWD-conditional generate-intent/bind-codebase, matching starterkit-first); NEW Precedence anti-drift rule — the skill's own handoff reference is the OPERATIVE spec; the contract's per-skill blocks are a consumer-side index. orchestrate-flow → 2.7.0.
- commands/sync.md safe write-back class now mirrors + cites its owner (detect-drift Step 5) instead of paraphrasing it.
- validate-ui-quality.sh SKIP_DIRS aligned with exclusions.md (adds dist/build/target/.next/.venv/coverage); stale "SKILL.md §Default exclusions" pointer fixed.

Tests: `tests/efficiency/test-efficiency-pins.sh` — 10 pins incl. functional non-SDD quick-exit run; full battery green.

## [4.16.0] - 2026-06-10

### Added — artifact delivery: every pipeline result lands somewhere (producer→consumer matrix audit)

4-agent matrix audit over every artifact + handoff field; all ORPHAN/DROPPED leads re-verified before fixing (two agent claims refuted by verification: vault.json `design_system` and `phase`/`phase_total` ARE consumed — left untouched).

- **KB extraction waste eliminated** — three `extract-intelligence` outputs had ZERO downstream consumers; all wired into `generate-intent --kb` (kb-submode §Rebuild-architecture + integrations consumption): `suggested-system-flow.md` → seeds 02-architecture components + 04-flows skeletons (peer of suggested-erd); `module-dependency-graph.md` → `kb_module_graph` pointer consumed by generate-units module auto-derivation as grouping/dependency SEED (evidence rule unchanged); `50-integrations/` → every external contract becomes a 06-constraints integration constraint (`[LOCKED]`) or a templated OQ — "never silently dropped". generate-intent → 2.5.0, generate-units → 2.6.0.
- **codebase-map §6 delivered to bolts** — when `starterkit-context.yaml` is absent (no deep scan), execute-bolts now injects §6 Pattern signatures as a `Codebase patterns:` dispatch line instead of letting the bolt re-invent generic defaults; §6 consumer note added to the map schema. execute-bolts → 2.9.0, scan-codebase → 2.10.0.
- **`scope_args_missing` validator halt (AUDIT L9 seam, deterministically enforced)** — a scoped `execute-bolts` handoff routing to detect-drift without `--scope=` in `suggested_args` now FAILS in `validate-handoff-yaml.sh` (was: contract said MUST, nothing checked; the scope died at the seam and drift full-scanned). Conservative no-fire when undeterminable. Functional 3-state test in `tests/delivery/`.
- **`next_action.confidence` finally consumed** — the typed field now demotes auto-continue to user review when `< confidence_minimum` (default 0.80) in the orchestrator consumption loop (closes the field's own documented F4 intent). orchestrate-flow → 2.6.0.
- **FSD `missing_sources[]` surfaced** — chain final summary reports "FSD emitted with N pending section(s)" (the field was populated but unread).
- **Drift scope observability** — detect-drift Step 0 logs `Scope hint received: …` / `Full scan (no scope hint)` so a dropped scope is visible in one line. detect-drift → 2.6.0.
- **Terminal artifacts documented as terminal** — `DRIFT-ACTIONS.md` is interactive-only (PENDING-SYNC.md is its autonomous counterpart) noted in routing-rules Mode D; `.obsidian/graph.json` marked external-interop terminal.
- Tests: `tests/delivery/test-delivery-pins.sh` — 13 pins (10 contract greps + 3 functional validator runs), all green.

## [4.15.0] - 2026-06-10

### Added — learning loop: pipeline outcomes feed memory; nothing is wasted (spec `2026-06-10-learning-loop-design.md`)

Doctrine: **capture automatic, behavior change suggestion-gated** (the suggestion-only lock is untouched).

- **L1 detect-drift learns** (was: zero memory participation): vault-scope `.memory/drift-history.md` — per-run summaries + fingerprinted direction calls (`<category>:<vault-section>:<normalized-name>` → `code_right|vault_stale|deferred`). Read side pre-fills a suggested direction after ≥3 same-direction calls on a fingerprint class; NEVER auto-resolves (under `--auto` the finding still queues to PENDING-SYNC.md). detect-drift → 2.5.0.
- **L2 sync runs learn**: Mode D appends one `kind: sync` row to project `outcomes.md` (channel mix, applied-vs-queued, safe-class accept/reject, closing staleness); after 3 consistently-ACCEPTed runs the chain-end pass MAY suggest defaulting `--auto-apply=safe` — applied only on explicit ACCEPT.
- **L3 Reflexion failure memory**: `bolt-outcomes.json` gains `failure_reflection` (one-line root-cause on every retry/halt); pre-execution reads surface reflections of the unit's past attempts AND same-module siblings as `## Prior failure context`. execute-bolts → 2.8.0.
- **L4 concerns persist**: per-bolt `acceptance_test_concerns` now ALSO land in `bolt-outcomes.json` (`concerns: [...]`) so recurrence can reach a threshold.
- **L5 extract-learnings is owned**: orchestrate-flow Step 7.6 runs the `learning-rules.md §1` threshold pass ONCE at chain end → appends crossers to `patterns.md ## Pending suggestions`; no skill evaluates thresholds mid-chain. New threshold rows: drift direction (3), sync write-back class (3), concern recurrence (3). orchestrate-flow → 2.5.0, memory → 1.5.0.
- **L6 scope `_index.md`**: derived (regenerated, the one non-append-only exception) per-scope index — row counts, last-entry dates, one-line current state, pending count, size flag; chain-start reads go index-first/just-in-time; a stale index is a hint, never the data.
- **L7 hygiene rails**: secret-scan (`scripts/secret-scan.sh --check`) on EVERY memory append with `[REDACTED-SECRET]` redaction; >256 KB → prune *suggestion* (never auto-prune); detector versioning on conventions (skip-re-detect only while the recorded scan-codebase version matches). scan-codebase → 2.9.0.
- Session-start staleness notice is now PENDING-SYNC-aware: open queue items → the notice points at the queue first ("resolve the queue first"), with the code-moved line appended when both signals fire (closes the sync-digest §consumers promise; hook tested in 3 states).
- Tests: `tests/learning-loop/test-contract-pins.sh` — 17 grep pins on the contract sentences above.

### Fixed — audit remediation (E2E skills audit, same day)

- **Ref hygiene**: 13 bare `references/X` forms → canonical `plugins/mega-sdd/references/X`; 8 `../../` forms → skill-name-relative; vault templates no longer emit dead `references/vault-contract.md` pointers into user vaults. The CLAUDE.md refs rule codified with the verified nuance: SKILL.md is the only router; sibling cross-pointers allowed ONLY when SKILL.md already routes the target.
- **ToCs**: `## Contents` added to 9 long plugin-root refs (paths, telemetry-schema, starterkit-context-schema, upgrade-from-old-version, shared-snapshot-schema, mermaid-emission-rules, model-tiers, tooling-install, reading-map). Exemptions codified: packs/lib-patterns catalogs, `templates/` scaffolds, generated do-not-hand-edit catalogs.
- **Version archaeology purged** from `references/paths.md` (title + ~20 Iter/v3.x comments), `commands/migrate-paths.md` description/body, and the 00-index template heading.
- **marketplace.json cleaned**: giant `version_note` blob removed (CHANGELOG.md is the history), long-overdue deprecated `grand-design-spec` alias entry removed (its own text said "removed after 2 release cycles"), marketplace `description` added, entry version synced — `claude plugin validate` now passes with ZERO warnings.
- **README**: missing v4.14.0 "What's new" entry added.
- **Config key truth**: `project-config.md` `layout:` values corrected to `new|legacy` (what `/mega-sdd:migrate-paths` actually writes) + `output_root` documented.

## [4.14.0] - 2026-06-10

### Added — per-project configuration surface (`.mega-sdd/config.yaml`)

Adopts the plugin-settings pattern (quick-exit, defaults-when-absent, validation, no secrets) on mega-sdd's EXISTING single config surface — deliberately NOT a second `.claude/*.local.md` file. New documented keys with hook-honored opt-outs:

- `dirty_journal: false` — living-vault journaling off for this project (git channel still drives `/mega-sdd:sync`); honored by the PostToolUse hook (quick-exit).
- `staleness_notice: false` — suppress the session-start "codebase moved" line; honored by the SessionStart hook.
- Existing keys (`telemetry`, `layout`) now documented in one place: NEW `references/project-config.md` (defaults, fail-open rules, user/project/vault scope table, commit-vs-gitignore guidance). README gains a "Per-project config" section.
- Both opt-outs empirically tested; full hook suites still pass.

## [4.13.0] - 2026-06-10

### Living Vault — never-ending development (spec `2026-06-10-living-vault-continuous-sync-design.md`)

The pipeline was one-shot (`intent → scan → bind → units → bolts → done`); real products never stop changing. This release ships slices S1–S3 of the continuous-sync architecture: the system now NOTICES code movement (however it happened — manual edit, AI-prompted change outside the pipeline, hotfix, git pull) and reconciles incrementally instead of requiring a cold full re-run. Tech-agnostic by construction (path/git-based; no framework assumptions).

#### Added — S1: ambient change capture (hooks)

- **Dirty-paths journal** — the existing async PostToolUse Write|Edit hook now appends `{ts, path, tool, session}` JSONL rows to `.mega-sdd/codebase/.dirty-paths.jsonl` for source writes in a MAPPED repo (codebase-map.md present). Captures in-session AI edits even before commit. Never journals `.mega-sdd/**` (anti-feedback-loop), never fires in unmapped repos, fail-silent, advisory-only — the hot-path PreToolUse surface does not grow. Pinned by new `tests/hooks/dirty-journal.test.sh` (3 cases, all empirically passing).
- **Session-start staleness notice** — one line of additional context when the journal is non-empty OR git HEAD ≠ the map's `last_scanned_commit`: counts only, suggests `/mega-sdd:sync`. Existing session-start test still passes.

#### Added — S2: incremental re-scan (scan-codebase 2.7.0)

- **`--changed-only`** — resolves `changed_paths` as the union of the journal + `git diff <last_scanned_commit>..HEAD` + uncommitted changes; re-extracts §2/§3/§4 entries ONLY for those paths; carries every other row forward byte-identical; drops vanished files; re-runs framework detection only when a manifest changed; truncates the journal after a successful write. Auto-falls back to full scan (no halt) when preconditions are missing or the delta exceeds 40% of the file census.

#### Added — S3: maintenance routing + front-door (orchestrate-flow 2.3.0, using-mega-sdd 2.1.0, detect-drift 2.2.0)

- **Mode D (maintenance/sync)** in the routing decision matrix: map+binding exist AND change signal present → `scan-codebase --changed-only` → `detect-drift` (scoped to changed paths) → `bind-codebase` → `generate-units` → `execute-bolts` (stale/new units only). P0/P1 OQ intent gate and new-PRD-revision routing still outrank it. CWD snapshot gains `change_signal:` probes.
- **`/mega-sdd:sync` command** — the user-facing entry (like `auto.md`, it invokes the orchestrate-flow skill with `--sync`); `--dry-run` shows the change summary + proposed chain; no change signal → reports "in sync" and stops (no vacuous re-runs). `tests/skill-triggering/sync.test.md` added (5 should-trigger incl. ID variants, 5 near-misses, contract checks).
- Anchor skill (`using-mega-sdd`) routes "sync", "kode berubah", "lanjutin dari kode sekarang", "continue from current code"; detect-drift accepts the changed-paths set as its scope hint.

#### Added — S7: autonomous sync (orchestrate-flow 2.4.0, detect-drift 2.4.0, scan-codebase 2.8.0, using-mega-sdd 2.2.0)

- **Decision deferral** — `/mega-sdd:sync --auto` runs the whole Mode D chain after ONE upfront confirmation and never asks a mid-chain question: safe operations run through (scan merge, claim-scoped re-bind, reconcile, gated bolt execution); human-required decisions (drift direction calls, write-back drafts, re-bind CONFLICTs) queue into `<vault>/PENDING-SYNC.md`. CONFLICTs still close the gate for affected units — handoff `status: paused` with the digest path, never completed-with-silence.
- **`--auto-apply=safe`** (opt-in, OFF by default) — auto-applies only the narrow write-back class: confidence HIGH + name/type-drift or missing-in-vault + claim NOT `[LOCKED]` + committed code (git provenance present). Everything else queues; plain `--auto` queues ALL write-backs.
- **`SYNC-REPORT.md`** — end-of-run report (per-phase outcomes, applied-vs-queued with provenance, conflicts, reconcile counts) with a MANDATORY closing staleness verification (`compute-unit-staleness.sh` re-run; stale=0 or explained). Contracts for both files: new `orchestrate-flow/references/sync-digest.md`.
- **Seamless entry** — the anchor skill treats "map+binding present + change signal" as a strong CWD signal: a continuation prompt proposes `/mega-sdd:sync --auto`. The session-start notice points to PENDING-SYNC.md when open items exist.
- **Flawless journal handling** — consumers rotate (`mv` to `.consumed-<ts>`) instead of truncating (concurrent-session appends survive; crashed-sync leftovers re-unioned next run); the hook stops appending past 1 MB (runaway guard; git channel still covers everything). Cap pinned empirically.

#### Added — S4: claim-scoped re-bind (bind-codebase 2.3.0)

- **`--paths=<csv|@file>`** — incremental re-bind via the binding-anchor reverse-index (file → claims): only affected claims get fresh Step 2 verdicts; the rest carry forward VERBATIM with `provenance: carried_forward`. **Moat unchanged:** every ACTIVE CONFLICT from the previous binding is re-validated regardless of path intersection (never carried on trust); counts recomputed over the full set; `binding.md` rewritten whole with canonical `### CONFLICT-N` headings, so the Step 5 gate and validators see exactly the same surface as a full re-bind. Full-re-bind fallbacks: prior binding unparseable, vault regenerated, >40% of anchored files changed, or any carried anchor vanished. Pinned by new `tests/moat/test-sync-conflict-revalidate.sh` (6 invariant pins, all passing).

#### Added — S5: drift write-back (detect-drift 2.3.0)

- **Step 5.5 vault write-back** — accepted `UPDATE_VAULT` actions become DRAFTED vault patches with mandatory git provenance (`<short-sha> "<subject>" — <author>, <date>` from `git log -1` on the anchor file); batch diff presented; applied ONLY on explicit user ACCEPT; then `00-index.md` changelog + minor version bump + `vault.json` regen under the advisory lock. Per-category patch shapes in `report-format.md §Vault write-back protocol`. Rails: never patch from inference (only the finding's cited code evidence); LOW-confidence findings report-only; `[LOCKED]`-tier claims NEVER patched from code (compliance escalation, not a sync); `FIX_CODE` actions remain out-of-band (the skill never edits app source). The old report-only behavior is preserved verbatim when the user declines.

#### Added — S6: unit lifecycle (generate-units 2.5.0, execute-bolts 2.7.0)

- **`status: implemented | stale | superseded`** optional unit frontmatter (absence = legacy). `bolt-report.md` frontmatter now MUST carry `target_hashes:` (sha256 per target file at commit time) — the deterministic staleness anchor.
- **`scripts/compute-unit-staleness.sh`** — compares bolt-report hashes to the working tree → `stale`/`implemented`/`unknown` JSON (legacy reports without hashes → `unknown`, never guessed). Empirically tested (3 cases).
- **`generate-units --reconcile`** — updates EXISTING unit IDs in place against the refreshed binding: task_type flips per the new Implementation State Map (`create→verify` when code landed out-of-pipeline; `→extend` on PARTIAL_FIELDS_* with Migration notes refreshed), status recomputed, vanished claims → `superseded` (kept, never deleted), new claims → new units through the NORMAL full pipeline. Ambiguous claim↔unit match → `dedup_ambiguous` halt, never a guess.
- **execute-bolts selection** — `superseded` units SKIPPED with a warning; `stale` units eligible for re-execution (the sync lane's "stale/new only" semantics); absent `status` = legacy behavior unchanged.


## [4.12.0] - 2026-06-10

### scan-codebase pipeline audit — drift fixes + research-driven hardening (skill 2.4.0 → 2.5.0)

Pipeline-by-pipeline gap audit (scan-codebase first), grounded in current Anthropic skill-authoring guidance (platform best-practices, agentskills.io spec, Claude Code skills/plugins/sub-agents docs) and community patterns (aider repo-map, GSD codebase mapper, spec-kit, superpowers).

#### Fixed — doc↔reality drift

- **Shipped the 3 missing tree-sitter query files** — `queries/tags-javascript.scm`, `tags-go.scm`, `tags-rust.scm` (adapted from Aider's tags.scm). `tree-sitter-integration.md` claimed 6 query files but only 3 existed; JS/Go/Rust silently fell back to regex while docs promised AST precision. Coverage table in `queries/VERSIONS.md` now lists the query file per language.
- **Deep-scan slice naming/count drift** — `halts-flags-handoff.md` still said `rbac` (renamed `authz`), `subagent_index: <1-4>` and "all 4 subagents" (there are 5 slices incl. `reuse`); `model-tiers.md` example list likewise. All corrected to the 5-slice reality.
- **Stale step numbering** — `deep-scan-prompts.md` referenced "Step 2.2/2.3"; corrected to 10.5.2/10.5.3.
- **libs-extractor prompt contradiction** — the template told the subagent to re-read `composer.json`/`package.json`, contradicting the `<MANIFEST_FACTS>` authoritative-injection rail. Template now consumes `<MANIFEST_FACTS>` directly; the "runtime dispatcher strips legacy entries" caveat removed.
- **Phantom flag** — `scan-procedure.md` Step 5 referred to a non-existent `--deep-scan` flag; rephrased to "default scan (no `--shallow-scan`)".
- **Inconsistent `generated_by` stamps** — examples pinned three different versions (v3.0.0 / @2.7.1 / skill 2.4.0); now derive from the SKILL.md frontmatter version.
- **Single-binary probe drift** — `tree-sitter-integration.md` showed `command -v tree-sitter` only; aligned with SKILL.md's two-binary probe (`tree-sitter || tree-sitter-cli`).
- **Grammar install claim** — `queries/VERSIONS.md` claimed grammars "download lazily"; corrected (the CLI does not auto-download; documented `parser-directories` setup).

#### Changed — authoring-standards conformance

- Stripped version archaeology (`Iter N`, `vN.N+`, internal OQ/closure IDs) from scan-codebase runtime prose (`codebase-map-schema.md`, `tree-sitter-integration.md`, `halts-flags-handoff.md`, `deep-scan-prompts.md`, `queries/VERSIONS.md`, `commands/scan-codebase.md`) per the v4 contract + Anthropic "no time-sensitive info" best practice.
- `commands/scan-codebase.md` `argument-hint` now carries the full flag set (`--engine`, `--shallow-scan`, `--force-deep`, `--no-cache`, `--memory-off`, `--no-default-excludes`) — command↔skill parity restored.

#### Fixed — 14 command files loaded with EMPTY frontmatter at runtime (`claude plugin validate` was failing)

Surfaced by running `claude plugin validate` during the audit: 14 `commands/*.md` frontmatter blocks failed YAML parse, so `description` + `argument-hint` were **silently dropped at load time**. Three root causes, all fixed; validation now passes:

- Unquoted `argument-hint` with multiple `[...]` groups parsed as a broken YAML flow-sequence (orchestrate-flow, auto, lint-units, emit-agents-md, analyze-parallelism, list-modules, diff-vault, detect-drift, resolve-oq, migrate-paths, scan-codebase, generate-intent) → values now quoted.
- `description` starting with `[ADVANCED / AUTO-INVOKED]` / `[USER-INVOKED]` parsed as a flow-sequence (lint-units, emit-agents-md, analyze-parallelism, list-modules, emit-fsd, install-deps) → bracket prefix rephrased to `ADVANCED / AUTO-INVOKED —` form.
- `auto.md` + `orchestrate-flow.md` had **markdown blockquotes inside the frontmatter block** (invalid YAML) plus `Per AUTONOMY-OQ-1 resolved:` colon-space breakage and Iter-N archaeology in descriptions → blockquote moved to the body, descriptions rewritten timeless.

#### Added — research-driven hardening

- **`last_scanned_commit` staleness stamp** in `codebase-map.md` frontmatter (git HEAD at scan time; optional outside git). Lets `detect-drift`/`bind-codebase` derive changed paths via `git diff --name-only <stamp>..HEAD` instead of re-walking the repo (GSD `last_mapped_commit` pattern).
- **Step 10a secret-scan gate** — assembled `codebase-map.md`/`starterkit-context.yaml` content is scanned for credential patterns (AWS keys, private-key blocks, GitHub/Slack/API tokens, JWT-shaped strings, `password=` literals) BEFORE write; matched values redacted as `[REDACTED-SECRET]` with a chat warning citing source `file:line`. Redacts scan outputs only — never edits repo source (GSD secret-gate pattern).
- **Refreshed `tests/skill-triggering/scan-codebase.test.md`** (repo-root suite): output path corrected to canonical `.mega-sdd/codebase/codebase-map.md` (was "repo root"), 6→7 required sections, new behavior checks for the `last_scanned_commit` stamp and the Step 10a secret-scan gate.

### bind-codebase pipeline audit — contract drift + validator-visibility fix (skill 2.1.0 → 2.2.0)

#### Fixed

- **`binding-md-template.md` Conflicts example was invisible to the validators** — the template showed a table with ID `X-001`, which matches NEITHER `validate-handoff-binding-units.sh` (`CONFLICT-\d+`) NOR `validate-conflict-classification.sh` (`CONFLICT-\d+ | C-\d{2,}`). A binding written strictly from the template could carry conflicts the resolution validator never sees. Template now emits the canonical `### CONFLICT-N` detail heading (with `conflict_class` + `resolution_complexity` enrichment) per conflict, plus the summary table with canonical IDs, and documents WHY the heading form is mandatory.
- **`binding-contract.md` described a retired 3-state model** — "only IMPLEMENTED / NEW / UNKNOWN; PARTIAL deferred to Iter 2" contradicted SKILL.md Step 2.5 and `implementation-state.md`, which implement 6 states (`PARTIAL_FIELDS_MISSING/SURPLUS/BOTH`). Contract table updated to the 6-state reality; per-claim probe rules deferred to the implementation-state reference; Implementation State Map example gains the `Field diff` column.
- **`--no-constitution` mis-attributed** — `constitution-and-oq.md` claimed it as a bind-codebase opt-out flag; it is a generate-intent flag. Clarified: absence of `constitution.md` IS the opt-out for binding.
- **Flag parity** — `--no-advisor` + `--memory-off` existed in SKILL.md/references but were missing from `commands/bind-codebase.md`; both added. SKILL.md flags list gains `--memory-off`.
- Stripped version archaeology (`v1.2+/Iter 1`, `Iter-79 X-1`, `DESIGN-OQ-1/3`, `v1.1+/v1.9+/Iter 20/23`) from `binding-contract.md` + `commands/bind-codebase.md`.

#### Added

- `tests/skill-triggering/bind-codebase.test.md` (repo-root suite) gains a behavior check pinning canonical `### CONFLICT-N` heading emission (the validator-readable token).


### generate-intent pipeline audit — vault-contract cleanup (skill 2.3.0 → 2.4.0)

#### Fixed

- **`vault-contract.md` (the shared cross-skill contract, 951 lines) carried 50+ version-archaeology fragments** (`v1.14+/Iter 35`, `Iter 41 sweep closure`, `Iter 58 enum closure`, `DESIGN-OQ-3 resolved`, `Sandbox-proven 2026-05-27`, per-halt `skill vX.Y+, Iter N:` prefixes) — all stripped to timeless prose per the v4 contract; canonical halt registry content unchanged.
- **Stale 4-slice deep-scan naming in the halt registry** — `deep_scan_subagent_failed` said "(auth/rbac/ui-ux/libs)" and `deep_scan_subagent_all_failed` said "ALL 4 subagents"; corrected to the 5-slice reality (auth/authz/ui-ux/libs/reuse), matching the scan-codebase fix.
- **Missing `## Contents` ToCs** on 4 references > 100 lines (`vault-contract.md`, `from-prompt-mode.md`, `legacy-retrofit-prompt.md`, `scope-picker.md`) — added per the >100-line ToC rule.
- Archaeology stripped from `from-prompt-mode.md`, `legacy-retrofit-prompt.md`, `scope-picker.md` headings; `legacy-retrofit-prompt.md` sibling-ref path normalized to the canonical `generate-intent/references/scope-picker.md` form.

#### Added

- (Correction during audit: the repo-root `tests/skill-triggering/` suite already covers all pipelines — an earlier duplicate seeded under `plugins/mega-sdd/tests/skill-triggering/` was removed; the `.gitignore` negation fix for `plugins/mega-sdd/tests/**/*.test.md` is kept so future plugin-level test fixtures aren't silently excluded.)


### execute-bolts pipeline audit — stale gate names + flag parity (skill 2.5.0 → 2.6.0)

#### Fixed

- **Stale PreToolUse "Branch 6/8" names** in SKILL.md Steps 2.5/3 — the named-branch architecture was consolidated into the unified gate aggregator in v4; gates are now referenced by name (ui-quality, render-test).
- **detect-drift hand-off contradiction** — SKILL.md said "After a clean batch: `/mega-sdd:detect-drift`" while `halts-and-handoff.md` documents the auto-gate (DEFAULT-ON, `--no-drift-check` opt-out); SKILL.md now states both accurately.
- **`commands/execute-bolts.md` argument-hint underdeclared 6 flags** (`--hard-rule-grammar`, `--no-pbt`, `--resume`, `--rollback`, `--memory-off`, `--force-skip-postflight`) — full parity restored; hint quoted; `(v2.2+)` markers stripped.
- Version archaeology stripped across `bolt-dispatch-prompt.md`, `hard-rule-grammar-v2.md`, `propose-and-confirm-prompt.md`, `partial-state-and-saga.md` (Iter 30/32/38/44/45/47/76 markers, audit-closure IDs); the deprecated v1.0 tier-loading algorithm stays as a clearly-marked historical section.
- **Missing `## Contents` ToCs** added to `bolt-dispatch-prompt.md` (433 lines), `hard-rule-grammar-v2.md`, `propose-and-confirm-prompt.md`.


### orchestrate-flow + extract-intelligence + side-lane audit — plugin-wide archaeology zero (8 skills bumped)

#### Fixed — orchestrate-flow (2.1.1 → 2.2.0)

- **CWD-snapshot field drift** — SKILL.md declared `oq_p0_p1_count` while `routing-rules.md` (the decision matrix) distinguishes `pending_p0_p1_count` (gates) vs `deferred_p0_p1_count` (informational); snapshot now carries both fields.
- **Broken schema path** — `chain-execution.md` cited `plugins/mega-sdd/references/memory/routing-outcomes.md` (doesn't exist); corrected to the mega-sdd:memory skill reference `memory/references/routing-outcomes.md` (2 spots).
- **Flags gap** — SKILL.md §Flags gains `--strict-quality` + `--no-telemetry` (present in command argument-hints but undocumented in the skill).
- **Related-skills list** now includes the auto-integrated diagnostics (`enrich-semantics`, `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`, `emit-fsd`, `install-deps`) that also emit handoff YAML.

#### Fixed — extract-intelligence (1.8.0 → 1.9.0)

- **Wave-count drift** — prose said "5 sequential waves" while the table dispatches Wave 0–5 (six); command also claimed "≤5 parallel per wave (hard cap 8)" vs the documented soft-warn>5/hard-cap-8; both corrected.
- **Missing `## Contents` ToCs** added to `knowledge-base-schema.md` (441 lines) and `wave-dispatch-templates.md` (415 lines).
- Cross-skill ref normalized (`predictive-checks.md` → `orchestrate-flow/references/predictive-checks.md`); person-attribution ("Zylos 2026 empirical optimum") and audit-closure IDs removed from runtime prose.

#### Changed — plugin-wide version-archaeology ZERO

Every remaining `Iter N` / `vN.N+` / audit-closure-ID / dated-proof fragment stripped from runtime prose across `skills/` + `commands/` + `agents/` (handoff-contract.md, predictive-checks.md, routing-rules.md, checkpoint-protocol.md, knowledge-base-schema.md, wave-dispatch-templates.md, memory-schema.md, learning-rules.md, agents-md-schema.md, section-mapping.md, tool-matrix.yaml, commands auto/replay/orchestrate-flow/generate-intent/validate-handoff/analyze-parallelism/list-modules/memory/migrate-rules, and more). `migrate-paths` / `upgrade-from-old-version` keep their layout-version mentions — there they are functional (the migration is BETWEEN versions), not archaeology. Verified: `grep -rE "Iter [0-9]|vN.N+"` over skills/commands/agents (excl. _vendored + migrate-paths) returns ZERO.

`## Contents` ToCs also added to 9 further >100-line references (binding-contract, detect-drift auto-and-chain, agents-md-schema, fsd-template, section-mapping, os-detection, learning-rules, memory-schema, routing-outcomes).

Side-lane skill versions bumped: emit-agents-md 1.3.0, emit-fsd 1.2.0, install-deps 1.2.0, memory 1.4.0, resolve-oq 2.1.0, detect-drift 2.1.0.


### Tech-agnostic hardening — scan-codebase multi-ecosystem (skill 2.6.0)

The plugin is tech-agnostic by design, but the scan pipeline's low-level extraction carried a PHP/JS bias. All closed:

#### Fixed

- **Stale-cache bug for non-PHP/JS stacks** — deep-scan cache signatures hashed ONLY `composer.lock` + a JS lock, so dependency changes in Rust/Go/Ruby/Python/JVM apps NEVER invalidated the auth/authz/ui_ux/libs slices (perpetually stale starterkit-context). Cache schema v2.1: per-ecosystem `locks_sha256` map (php/js/rust/go/ruby/python/jvm) + `app_locks_digest` / `frontend_locks_digest` / `all_locks_digest` groups derived from the §7 Framework ecosystem. v2.0 caches self-heal (signature inputs changed → one full re-dispatch). Invalidation matrix rewritten ecosystem-relative (Rails+esbuild example instead of Laravel-only).
- **Manifest pre-parse was composer/package-only** — `manifest_facts` now parses EVERY detected manifest (Cargo.toml, go.mod, Gemfile, pyproject.toml/requirements/Pipfile, pom.xml/build.gradle) into per-ecosystem blocks; libs-extractor prompt inventories all ecosystems, not "composer.json + package.json".
- **Language probe missed Ruby** — `Gemfile` added to Step 2 (Rails/Sinatra were in the framework table but their repos detected as "no package manager").
- **Test-framework detection** extended: rspec/minitest (ruby), `*_test.go` + testify (go), JUnit (jvm), cypress (js), pyproject pytest config.
- **Route extraction covered 5 of 22 frameworks** — Step 6 now has signatures for every framework in the §8.5 table (Express/Fastify/NestJS/Next/Nuxt/SvelteKit/Remix/Laravel/Symfony/Slim/Rails/Sinatra/Django/FastAPI/Flask/Gin/Echo/Fiber/Actix/Axum/Rocket/Spring) + `_universal` best-effort fallback.
- **Model extraction covered 4 ORMs** — Step 7 now spans all ecosystems (Prisma/TypeORM/Sequelize/Drizzle, Eloquent/Doctrine, ActiveRecord, Django ORM/SQLAlchemy/Pydantic, GORM/ent, Diesel/SeaORM, JPA/Hibernate).

#### Added

- `queries/tags-ruby.scm` + `queries/tags-java.scm` — AST-precise extraction for Ruby (Rails/Sinatra) and Java (Spring) repos; regex fallback patterns for both added to Step 5; coverage tables updated (Kotlin/.erb noted as regex-tier gaps).
- `starterkit-context-schema.md` archaeology cleaned to zero as part of the cache v2.1 rewrite.


### Deterministic-script split + capability-adoption doctrine

#### Added

- **`scripts/compute-lock-digests.sh`** — deterministic per-ecosystem lock digests for the deep-scan cache v2.1 (probes php/js/rust/go/ruby/python/jvm locks; emits `locks_sha256` + app/frontend/all digest groups as JSON). The model no longer hand-composes sha256 inputs; deep-scan-stage Step 10.5.1 now says "RUN the script". Empirically tested (Rails+yarn fixture → distinct app vs frontend digests).
- **`scripts/secret-scan.sh`** — deterministic credential scrub backing the Step 10a gate (`--check` reports; `--redact` rewrites matched values to `[REDACTED-SECRET]` in place + JSON report that never echoes the full secret). Empirically tested (AWS key + password assignment redacted; clean rows untouched).
- **`CLAUDE.md` gains a Tech-agnosticism standard** ("does this work for a Rails/Gin/Axum repo too?") and a **Capability-adoption decisions** record: `disable-model-invocation` REJECTED (kills natural-language ID/EN routing), `when_to_use` not adopted (would duplicate description content into the always-loaded listing), deterministic logic → `scripts/` per Anthropic guidance.


## [4.11.0] - 2026-06-10

### Fixed — bolt folder not generated during execute-bolts

A reported bug: running `execute-bolts` (via `orchestrate-flow --auto`) implemented and committed the unit's code but produced **no `<vault>/bolts/U-XXX/` folder + `bolt-report.md`**. Root cause: bolt-folder creation was **prose-only** — the `bolt-implementer` agent writes code/tests/commit but never the bolt folder, and the controller's instruction to write `dispatch-prompt.md`/`bolt-report.md` into it had no deterministic `mkdir` and no end-of-run existence gate, so a terse `--auto` controller could skip it silently (violating the plugin's own "gates > rules > hooks" doctrine).

The fix is two layers — a **strengthened creation step** (still controller-run prose, but moved up and made mandatory) plus a **deterministic, hook-wired detection gate** that loudly catches the skip:

- **`execute-bolts` SKILL.md** — new per-unit **Procedure Step 0**: `mkdir -p <vault>/bolts/U-XXX/` is the literal first per-unit action, *before* pre-flight/dispatch; the folder + `bolt-report.md` are now MANDATORY per-unit outputs. (This is the creation layer — an instruction the controller runs, not a hook; the hook below is what actually enforces it.) (execute-bolts 2.4.0 → 2.5.0.)
- **`context-enrichment.md`** — the dispatch-prompt write step now `mkdir -p`s the bolt dir first (idempotent).
- **`validate-handoff-yaml.sh`** — new **deterministic** halt `bolt_artifacts_missing` (the real enforcement): an `emitted_by: execute-bolts` `status: completed` handoff that **executed units** (`metrics.items_processed > 0`) but lists no `bolts/` artifact now FAILS the Stop-hook handoff validation. This narrows the vacuous-pass hole in the prior `artifact_missing` check (which only verified *declared* paths exist — passing vacuously when none were declared) for any run that reports work. Scoped to avoid false positives — a `--dry-run` / no-op re-run (`items_processed == 0`) or an absent metrics block does NOT fire (a conscious false-negative-over-false-positive trade; the mandatory Step-0 `mkdir` is the primary mechanism, this gate the loud backstop). The execute-bolts handoff contract now requires `items_processed` to report units *actually* committed (0 for dry-run/no-op), so the exemption is contract-grounded. Registered in the halt taxonomy (`halts-and-handoff.md`, `handoff-contract.md`). (orchestrate-flow 2.1.0 → 2.1.1.)
- **Tests** — `tests/bolt-folder-fix/` gate suite (validator raises `bolt_artifacts_missing` on a units-executed no-bolts handoff, stays silent when a real bolts dir is listed, on a dry-run/no-op `items_processed:0` handoff, and on an absent metrics block; SKILL.md carries the mandatory `mkdir` step).

## [4.10.0] - 2026-06-10

### Added — per-stack packs wave 3: the long tail (full §8.5 coverage)

Full-pack coverage reaches **all 22 detectable frameworks** in the scan-codebase §8.5 table. Nine more `pack_tier: full`, lint-clean packs, authored to the 3b `_template` contract via parallel doc-grounded (context7) subagents.

- **`slim.md`** (PHP) — PSR-7/PSR-15, single-action invokables, PHP-DI, middleware authz.
- **`fastify.md`** (Node) — plugins + encapsulation, JSON Schema validation, hooks, `@fastify/jwt`.
- **`remix.md`** (React) — route modules, loaders/actions, `<Form>`, loader-guard authz (Remix v2; RR7 noted).
- **`sinatra.md`** (Ruby) — route DSL, classic/modular, `before` filters, ERB, Rack.
- **`echo.md`** (Go) — `echo.Context` handlers returning error, middleware authz.
- **`fiber.md`** (Go) — fasthttp-based `*fiber.Ctx`, `app.Test`, middleware authz.
- **`actix.md`** (Rust) — `App`/`.service()`, extractors, `.wrap()` middleware + FromRequest guards.
- **`axum.md`** (Rust) — `Router`, Tower `.layer()`, extractors + `FromRequestParts` guards.
- **`rocket.md`** (Rust) — attribute routes, `FromRequest` request guards, fairings, managed state.

### Changed

- **`_lint.md` leak map** — dropped generic `Gemfile` from rails tokens (it is generic Ruby, shared by sinatra; rails keeps `ActiveRecord`/`config/routes.rb`/`app/controllers`/`.html.erb`/`attr_accessible`).
- **`_registry.md`** regenerated — all 22 detectable frameworks show `ready`. `--all` + `--check-registry` + all suites green. The only non-`ready` row is the project-specific `laravel-base-26` starterkit (`unknown` — an open governance decision, not a coverage gap).

## [4.9.0] - 2026-06-10

### Added — per-stack packs wave 2: seven more full framework packs

Full-pack coverage extended from 5 → 12 frameworks. Seven `pack_tier: full`, lint-clean convention packs authored to the 3b `_template` contract via parallel doc-grounded (context7) subagents, each across the 9-section contract incl. the neutral 3a authz ontology.

- **`flask.md`** (Python) — app factory + Blueprints, Flask-SQLAlchemy `db.Model`, `@login_required`/`@roles_required`, Jinja2.
- **`symfony.md`** (PHP) — `#[Route]` attributes, Doctrine, Twig, Security voters + `#[IsGranted]`, `bin/console`.
- **`rails.md`** (Ruby) — ActiveRecord MVC, Pundit/CanCanCan authz, Devise, Hotwire.
- **`spring.md`** (Java) — layered controller/service/repository, Spring Data JPA, `@PreAuthorize`/SecurityFilterChain.
- **`nuxt.md`** (Vue) — file-based routing, Nitro `server/api`, route middleware, Nuxt 3/4 srcDir.
- **`sveltekit.md`** (Svelte) — `+page`/`+server` routing, load functions, form actions, `hooks.server.ts` auth.
- **`gin.md`** (Go) — router groups, middleware-based authz (JWT/casbin), `internal/` layout.

### Changed

- **`scan-codebase` §8.5 detection** — added the first JVM row (`pom.xml`/`build.gradle` → `spring-boot-starter` → `spring`); Spring projects were previously undetectable. (scan-codebase 2.3.0 → 2.4.0.)
- **`_lint.md` cross-framework leak map** — dropped non-distinctive tokens: generic PHP `composer.json` (symfony/slim use it) from laravel, and generic Jinja2 `{%extends`/`{%block` (Flask shares them) from django. Distinctive tokens retained.
- **`_registry.md`** regenerated — all 12 full packs show `ready`; `--all` + `--check-registry` green.
- **Tests** — added wave-proof `tests/per-stack-packs/test-all-full-ready.sh` (every `pack_tier: full` pack must lint clean AND register `ready`).

## [4.8.0] - 2026-06-10

### Added — per-stack packs: five full framework convention packs

Mega-SDD's deep-scan is now framework-accurate beyond Laravel. Five `pack_tier: full`, lint-clean convention packs were authored to the 3b `_template` contract (doc-grounded conventions across the 9-section contract, including the neutral 3a authz ontology). Content-only — no skill or pipeline behavior change.

- **`fastapi.md`** (new) — Python async API; OAuth2/`Security()`/`Depends()` scopes, API-only UI.
- **`next.md`** (new) — React/TS, App Router default (Pages Router noted); `middleware.ts` + NextAuth/Auth.js authz, RSC vs client components.
- **`express.md`** (new) — Node minimal; middleware-based authz (passport/jwt), layered routes→controllers→services, optional view engine.
- **`nestjs.md`** (new) — Node decorator/DI; Guards (`CanActivate`/`@UseGuards`)+`@Roles` authz, modules/providers, API-only UI.
- **`django.md`** — promoted thin proof-pack → full (added Naming standards, Idioms, Hard Rules emitted, Testing conventions; `framework_version_range` 4.2–5.x).
- **Registry:** `_registry.md` regenerated — all five show `ready`. `validate-pack.sh --all` and `--check-registry` exit 0.
- **`_lint.md`:** removed the generic `pyproject.toml` from django's cross-framework token list (it is not django-distinctive; FastAPI/Flask/Poetry use it too).
- **Tests:** new gate suite `tests/per-stack-packs/` (each-lints, five-ready, all-green); `tests/pack-kit/test-registry-fresh.sh` updated for django's promotion.

## [4.7.0] - 2026-06-09

### Added — pack-authoring kit: validate-pack/scaffold-pack/_registry; tier-aware --all CI gate

Pack-authoring kit ships three author-time tools that make adding a new framework convention pack safe and consistent. No runtime/pipeline behavior change; one new advisory scan note added to `scan-codebase`.

- **`scripts/validate-pack.sh`** — deterministic pack linter. Single-pack mode exits non-zero on any violation (missing section / bad YAML / cross-framework token leak). `--all` is tier-aware: `pack_tier: full` packs block on any violation; `thin`/untiered packs block only on structural errors (invalid YAML / cross-framework leak), keeping `--all` a green CI gate for in-progress thin proof-packs. `--registry` regenerates `_registry.md`. `--check-registry` gates freshness.
- **`references/framework-conventions/_lint.md`** — human-readable conformance checklist + cross-framework token map (data-driven; extensible without script edits).
- **`references/framework-conventions/_registry.md`** — auto-generated pack-readiness table (framework | detected? | pack file | status | lints_clean?). Never hand-edit; regenerate with `--registry`.
- **`scripts/scaffold-pack.sh`** — produces a linter-valid `<framework>.md` skeleton from `_template.md`; refuses to clobber; prints next steps.
- **`references/framework-conventions/_template.md`** — `## Reuse discovery` section added (reconciles the v4.5.0 gap: packs already carry this section; `_template.md` now documents it as the complete contract the linter validates against).
- **`scan-codebase`** — one advisory note added: when `_registry.md` reports `thin`/`none` coverage for the detected framework, scan output emits `pack coverage: <status> for <framework> — generic _universal fallback in use; see framework-conventions/_registry.md`. Advisory only; never halts; absent registry → silently skip.
- **README un-TBD** — `framework-conventions/README.md` "Adding a new pack" step 4 no longer says "TBD: pack linter". Updated to reference `validate-pack.sh`, `_lint.md`, tier-aware `--all`, and `scaffold-pack.sh` as step 1.
- **`tests/pack-kit/` suite** — 6 tests (`test-linter-not-a-hook.sh` added; all others shipped earlier in this branch).

Skills: scan-codebase 2.2.0 → 2.3.0.

## [4.3.0] - 2026-06-06

### Fixed — Round-2 end-to-end + subagent-decomposition audit (full trail in `plugins/mega-sdd/AUDIT.md`)

Deep flow-by-flow audit of the whole pipeline + how heavy skills decompose into subagents when one pass is too heavy. Linchpin settled empirically: **PostToolUse hooks fire on subagent writes** (3-sentinel telemetry probe), so the moat quality gates are NOT bypassed on fan-out. Decomposition verdict: extract-intelligence (6 waves) and scan-codebase (4 slices) are correct **depth-1** patterns (main-thread controller + read-only subagents with no Agent tool + bash gates between stages); execute-bolts' squad fan-out was the only structural break. Audit-first held — every finding surfaced + verified before any edit.

- **`execute-bolts --per-squad` was depth-2 broken → now a main-thread loop (L3/L5/L6).** The old design forked one subagent per squad and made it the per-unit controller — which would then have to dispatch the three bolt agents (depth-2; the runtime forbids subagent nesting), silently degrading to inline implementation and **losing the two-stage review** (the moat's quality enforcement). `--all --parallel` carried the same stale "subagent batch" framing, and orchestrate-flow **defaulted** every multi-squad vault into the broken path. Rewritten: the main-thread controller dispatches `bolt-implementer` Agent calls concurrently across independent units (incl. across squads) at depth-1, each unit still going `bolt-implementer → spec-reviewer → code-quality-reviewer`. Enforceable: `tests/moat/test-no-depth2-dispatch.sh` pins the depth-1 invariant across 7 files (PASS on fix, FAIL on every pre-fix phrase).
- **Gate-state hardening, shipped WITH the parallelism enablement (L4).** Enabling depth-1 parallelism activates concurrent state-file writes, so in the same change: (a) the binding→units moat file `.validation-blockers.json` now **fails closed** on a present-but-corrupt state in the PreToolUse aggregator (a torn/garbage write must not silently open the gate — invariant #2); the other 5 gates stay fail-open to avoid spurious transient blocks. (b) **atomic writes** (tmp + `os.replace`, pid-keyed) at every write-site of the 6 aggregator-read validators, so a concurrent reader never sees a torn JSON. TDD: `tests/moat/test-moat-corrupt-fail-closed.sh` (corrupt blocks, absent allows, valid FAIL blocks, valid PASS allows; discrimination proven vs the pre-fix hook).
- **execute-bolts → detect-drift seeds `--scope` (L9).** Resolves the 4.2.0-deferred handoff-seamlessness item: a scope-filtered bolt batch now propagates `--scope=<id>` into the chained drift check instead of falling back to a full scan.
- **generate-intent preserves the enriched stages form (L8).** extract-intelligence v3.72.0+ emits enriched `input_fields` objects + per-stage delta fields (progressive-disclosure intent); generate-intent only documented the bare-string form, risking a silent downgrade. The preservation rule + `04-flows.md` template now mandate carrying the enriched form through (no flatten) and cross-reference the ui-ux-design-intelligence integration design where the semantics are consumed.

### Fixed — doc / honesty (no behavior change)

- **False "subagents invisible to PostToolUse" premise corrected (L2).** The post-tool-use header, `references/telemetry-schema.md`, and the execute-bolts fan-out refs claimed subagent tool calls are invisible to the parent hook — disproven by the L1 probe. The `ref_loaded` under-count is real but caused by **lossy async emission** (async hook + best-effort `>> … 2>/dev/null || true`), not invisibility; re-attributed.
- **fan-out-parity enforcement overclaim dropped (L10).** Resolves the other 4.2.0-deferred item: the validator + post-tool-use comment claimed a blocking "PreToolUse Branch 12" gate that does not exist (the aggregator never reads `.fanout-parity-state.json`; it is advisory per CLAUDE.md). The check itself is sound — obligation-presence parity (`ui_contract` + `render_test` across view-bearing siblings), not a richness proxy.
- **Resume contract reconciled (L7).** orchestrate-flow's "no state file" (chain-level, CWD/artifact-driven phase selection) vs the per-skill checkpoint cursor (sub-step) are now documented as two non-conflicting granularities with explicit precedence.

Skills: execute-bolts 2.1.0 → 2.2.0, orchestrate-flow 2.0.0 → 2.1.0, generate-intent 2.1.0 → 2.2.0.

## [4.2.0] - 2026-06-05

### Changed — Moat hardening: the binding→units gate now enforces CONFLICT *resolution*

Deep advisor-guided audit of the mega-sdd skills (full trail in `plugins/mega-sdd/AUDIT.md`). Headline: the skills work correctly by design — the enforcement spine (every hard-block gate → validator → hook → state file) traces end-to-end, and command↔skill parity is healthy. One real moat gap was found and closed.

- **CONFLICT-resolution enforcement (was propagation-only).** Invariant #2 promises "unresolved CONFLICTs block downstream unit/bolt generation," but `scripts/validate-handoff-binding-units.sh` only verified CONFLICT-ID *propagation* (is the ID cited in some unit's frontmatter?), not *resolution status*. An unresolved-but-cited CONFLICT therefore produced no drop → `status: PASS` → `execute-bolts` not blocked. The validator now also scans structured `### CONFLICT-<id>` detail headings and **fail-closes**: an active heading (per `binding-contract.md`, one carrying `Verdict: CONFLICT (BLOCKING)` and lacking a `✅`/`RESOLVED` marker) emits a new `conflict_unresolved` drop → `status: FAIL`, blocking the existing execute-bolts PreToolUse gate. Resolve by re-running `bind-codebase` to `conflicts=0` or marking the entry resolved. Reuses `.validation-blockers.json` + the existing gate (no new hook, no new state file). TDD: `tests/moat/test-conflict-unresolved.sh` (active-but-cited blocks, resolved exempt, clean binding no-false-positive). OQ-drop + no-vault regressions green.

### Fixed — consistency (doc-only)

- **Dispatch-prompt budget caps** synced: `bolt-dispatch-prompt.md` carried stale 7KB/10KB/5KB figures while the canonical `context-enrichment.md` + `execute-bolts/SKILL.md` use target 9KB / hard 12KB / T2 10KB. Aligned all figures + added a "MUST match `context-enrichment.md`" pointer.
- `skills/analyze/SKILL.md` was missing a `version:` stamp → added `2.0.0` (matches its v4 lean-core sibling cohort).
- `README.md` release narrative was stuck at `v4.0.0 (current)` despite the 4.1.0 stamp → added the v4.1.0 and v4.2.0 narratives.
- `commands/replay.md` example used a non-canonical `vault_version: "1.2.0"` → corrected to `"1.1"`.

### Fixed — Windows install-deps (skill 1.0.0 → 1.1.0)

- **Some native deps could not install on Windows.** `tree-sitter`, `ast-grep`, `tectonic`, and `jd` had no `windows-bash` entry in `tool-matrix.yaml` — they only resolved through the `cargo`/`npm`/`go` fallback, so a Windows box with winget/scoop but no Rust/Node/Go reported them `unsupported` and skipped them. Added native **Scoop** matrix entries for all four (Scoop is their canonical Windows source per their own docs and `references/tooling-install.md`); now every tool has at least one Windows install path.
- **Fallback chain is now Windows-aware** (`os-detection.md`): a secondary native Windows manager that is installed but not the detected primary (scoop → winget → choco) is tried before the cargo/npm/go runtime fallbacks — so a winget-primary box reaches the scoop-only tools when Scoop is present.
- **No more silent skips on Windows:** a tool skipped purely for lack of a manager now surfaces the concrete remedy (install Scoop, or a runtime), instead of a bare "unsupported" line. Human guide `references/tooling-install.md` updated to match.

### Changed — example PRD reflects the canonical standard

- `tests/scenarios/sample-prd-clinic.md` (the first-run reference PRD) rewritten to the canonical `docs/templates/prd-template.md` standard: full required frontmatter (`type`/`version`/`status`/`date`/`authors`/`industry`/`stakeholders`), a single `CLINIC` scope, `universal_sections`, and the `§`-section convention (`§1`–`§9` universal + `§Clinic` scope sections). All original content preserved (flows F-U/F-S, data model, OQs re-tagged `OQ-CLINIC-NNN [P*]`).

### Noted — confirmed but deferred (advisory-layer, future iter)

- execute-bolts→detect-drift handoff carries `suggested_args: []`; the snapshot-reuse / `--auto-gate` coupling is prose-only (handoff seamlessness).
- `validate-fanout-parity.sh` checks spec obligations (`ui_contract`, `render_test`) but not `starterkit_relevance` consistency across siblings — divergent bolt context can still pass parity.

## [4.1.0] - 2026-06-05

### Added — UI/UX design intelligence (distilled ui-ux-pro-max)

Distilled `ui-ux-pro-max` v2.5.0 (MIT, nextlevelbuilder) design knowledge into `references/design-intelligence/` (product-style-map, style/palette/typography principles, ux-rules) via a sync-time distiller (`scripts/_lib/distill-ui-ux.py` + `scripts/sync-ui-ux.sh`). **No runtime dependency** — mega-sdd reads only the committed markdown/YAML.

- **Intent-time (template-first):** a scanned starterkit/template's design flow is authoritative; ui-ux-pro-max only gap-fills, never overrides. When there is no PRD design source AND no scanned template, the Design-Source OQ resolves as `resolution_mode: recommend` with a grounded `{style, palette, typography, a11y_level}` from `product-style-map.yaml` (rationale + citation + fallback + user confirmation). Anti-halu moat preserved — recommendation, never a silent default.
- **Vault:** new `design_system` block in `vault.json` (`vault_version` 1.0 → 1.1) carrying the resolved design system + `source` (`prd` | `scanned-template` | `design-intelligence-recommend`) + provenance.
- **Units:** `## UI contract` gains `design_system_ref` to propagate the choice to bolts.
- **Bolt-time:** `execute-bolts` Step 4.5 injects a `Design system:` line + the matching style-principles/ux-rules slice into ui_ux dispatch prompts; scanned-template tokens stay authoritative.
- **Enforcement:** `validate-dispatch-prompt.sh` now also asserts a non-placeholder `Design system:` line for ui_ux units (`design_system_not_injected`).

Skills bumped: `generate-intent`, `generate-units`, `execute-bolts` → 2.1.0.

## [4.0.0] - 2026-06-04

### v4 lean-core — radical modernization to current Claude Code / Anthropic guidance

A ground-up restructure (branch `v4-lean-core`) bringing the plugin in line with current Agent-Skills best practices and superpowers' "gates > rules > hooks" discipline — **without weakening the spec↔code grounding moat**. Driven by `research/2026-06-04-architecture-modernization-audit.md` + `docs/superpowers/specs/2026-06-04-v4-lean-core-design.md`.

**Skills — progressive disclosure.** Every one of the 16 `SKILL.md` bodies is now a lean router ≤500 lines (was up to 1,285); total skill-body prose dropped 8,758 → 2,574 lines (−70%), with detail relocated into 87 on-demand reference files. Descriptions stripped of version archaeology; all trigger keywords (EN + ID) preserved; the moat (binding verdicts, the CONFLICT gate, the anti-hallucination rail, the hard-rule commit gate) verified in-body.

**Enforcement — Hybrid.** `pre-tool-use` rewritten as a single data-driven gate aggregator (730 → 377 lines). Hard-blocks retained: the binding→units moat gate, predictive preflight, scope-flag, anti-self-bypass, and the high-value code-delivery gates (flow-coverage, render-test, sibling-consistency, ui-quality, cross-cutting-registration). Demoted to `/mega-sdd:analyze` advisory (non-blocking, surfaced read-only): dispatch-prompt, operator-UX, fan-out-parity, ui-deferral, vault-flow-staging. Fixture-tested (kept gates still block, demoted gates allow, anti-bypass fires).

**First-class subagents.** New `agents/`: `bolt-implementer`, `spec-reviewer`, `code-quality-reviewer`, `domain-extractor` — validated against the current Claude Code subagent spec. `execute-bolts` dispatches the bolt agents (two-stage review: spec compliance then code quality); `extract-intelligence` dispatches `domain-extractor` per wave. **All 25 `/mega-sdd:` pipeline commands preserved** (manual CLI entry points).

**Narrative reset.** `CLAUDE.md` rewritten 375 → ~95 lines (invariants + the enforcement doctrine kept; retracted-feature archaeology dropped to git). Version reconciled to a single source of truth — `plugin.json` and `marketplace.json` now both **4.0.0** (was 3.72.0 / 1.3.0).

Pre-v4 "Iter N" development history remains in `CHANGELOG-ARCHIVE.md` and git.

## [3.72.0] - 2026-06-02

### Extract-intelligence deepening — smarter reasoning, more cases caught, automatically

Makes `extract-intelligence` reason deeper and catch the cases a write-side-only read misses — *automatically*, every run. Distilled from a deep audit of `extract-intelligence` output against a real legacy trade-finance codebase (`new-tradefinance-import`, 22 findings). The bridging design proposed verbatim skill-body patches; on contact with the current plugin two facts reshaped the work: (a) the bridging "CRITICAL" item (multi-stage progressive disclosure) is **already shipped** as v3.71.0 staged-input → enriched the EXISTING §3a schema, not a parallel artifact; (b) Fork A doctrine — enforcement must be a validator, not prose that says "HALT". Priority reframe (user): **KB captures business intent + flow; rebuild owns implementation cleanliness — status-naming drift is NOT a gap.**

**Track 1 — P1–P4 deep disciplines wired to fire automatically (the core):**
- `wave-dispatch-templates.md`: the generic subagent prompt's **DEEP DISCIPLINES** block (received by EVERY Wave 1–5 subagent, so the reasoning fires automatically — not SKILL.md-only prose the subagents never read) — P1 state writer↔reader provenance + `INSERT…SELECT` clone-inheritance tracing (captured as a *business outcome*, never a pinned legacy value); P2 enumerate ALL rule/flow sites + entry-point dispatchers (distinct initial states stay distinguishable); P3 behaviour-as-EXECUTED (unconditional halts as `[ARTIFACT: debug-code-as-feature]`, rollback policy, test flags, silent-success); P4 structural file classification. REPORT BACK gains `provenance_pairs_checked`/`provenance_anomalies`/`rule_sites_multi` self-checks + a P1 self-check rail. Wave-3 gate adds **non-blocking** advisory `provenance_read_side_thin` (mirrors `kb_flow_staging_missing` — never fails the wave).
- `extract-intelligence/SKILL.md`: `### Deep extraction disciplines (P1–P4)` design-vocabulary section (authoritative copy = dispatch template) + §7.1 business-intent framing; skill 1.7.0→1.8.0.

**Track 2 — §3a staged-input schema enrichment (reuse-compliant, NOT a parallel artifact):**
- `knowledge-base-schema.md §3a`: `input_fields` accepts bare strings (back-compat) OR objects `{name, mutability ∈ required|optional|display-only|dual-key-re-entry, visibility ∈ shown|hidden|conditional, conditional}`; new per-stage OPTIONAL deltas `new_fields_vs_prior`/`hidden_fields_vs_prior`/`promoted_to_mutable_vs_prior` + `dynamic_disclosures` (within-stage show/hide). Captures the "fields A,B,C at maker; D,E,F at the next stage" case in depth. Best-effort/advisory — optional fields break no consumer (semantic-depth invariant #7).

**Track 3 — Extraction Completeness Contract + real validator (advisory, Fork-A):**
- NEW `scripts/validate-extraction-scorecard.sh` — runnable validator (bash+Python, modeled on `validate-kb-flows.sh`): **SKIP** when absent (back-compat), **PASS** when consistent, **FAIL** on internal inconsistency OR a hidden gap (a PARTIAL/MISSING principle with ZERO `[OPEN]` markers — the silent-drift failure mode). `extract-intelligence/SKILL.md §Step 5.6` — Wave 5 emits `.extraction-scorecard.json` + `EXTRACTION-SCORECARD.md` scoring P1–P4 + P5; anti-halu rail (an honest PARTIAL+`[OPEN]` is the passing state; never up-rank to hide a gap). `bind-codebase/SKILL.md`: scorecard **preflight advisory** consult (surfaces FAIL/absent, non-blocking this iter); skill 1.10.5→1.11.0.
- **Scoped Fork-B-future** (no prose pretending to HALT without a backing validator): B1 hard-block (promote the advisory to a blocking PreToolUse branch), and B2/B3/E1/E2/E3 handshake/post-flight gates — each needs its own `validate-*.sh` + fixtures; B2/B3 to verify the *business outcome* survives, not legacy status values (per the reframe). The bridging design's downstream generate-units/execute-bolts prose gates are DEFERRED (scope narrowed to making *extract* smarter).

**Track 4 — proof:** `tests/fixtures/iter80-extract-deepening/verify.sh` — Fork-A assertions (exit 0): P1–P4 + provenance self-checks reach the wave dispatch prompt; scorecard validator verdicts (PASS / FAIL-hidden_gap / PASS+advisory-when-[OPEN] / SKIP-absent); §3a enriched fields + bare-string back-compat. Fork-B (subagents ACTUALLY reasoning deeper; Wave 5 emitting an honest scorecard) documented as real-run-only, NOT script-asserted. No regressions: iter77 (16/16) + 19/19 code-delivery fixtures still green.

**Invariants honored:** advisories never flip a blocking `status` (Iter-78.1 #1 / Iter-79 #5); `stages:` sub-fields stay OPTIONAL (semantic-depth #7); no new PreToolUse branch this iter (protects Iter-78.1 / Iter-79 / semantic-depth #6/#7 hook invariants). Spec: `docs/superpowers/specs/2026-06-02-extract-intelligence-deepening-design.md`.

## [3.71.0] - 2026-06-02

### Semantic-depth — staged-input walking skeleton (regression: multi-step workflows flattened to single-form)

Fixes a semantic-depth regression surfaced from real legacy code: a multi-step workflow (wizard / maker→checker / multi-page form) stages its inputs (fields A,B,C at step 1; D,E,F at step 2), but the KB→vault→units→bolts handoff **flattened** it to one "Inputs: A,B,C,D,E,F" list — so the bolt built ONE form where the legacy had a multi-step wizard. Root cause: staging was structured *nowhere* and the handoff schema never required it. Walking-skeleton scope: the **staged-input** dimension only (conditional / role-matrix / transition-guard dimensions follow later). Consumer-audited first (`stages:` is an OPTIONAL field — breaks no existing consumer; execute-bolts multi-step is vertical decomposition, deferred Fork-B-future). Advisor-sharpened: deterministic `_kb_source` back-reference (the OQ-ID-class propagation the codebase already uses) instead of fuzzy title-matching.

**Track 1 — schema + contracts (deterministic propagation):**
- `knowledge-base-schema.md`: new `## 3a. Staged inputs` section + the `stages:` YAML block (`stage_id`/`stage_name`/`actor_role`/`input_fields`/`transitions`/`_source`), REQUIRED-when-multi-step (conditional → backward-compatible), per-stage `_source` anchor as anti-halu rail.
- `templates/04-flows.md`: `**Stages**` block (verbatim from KB §3a) + Mermaid `stateDiagram` + `_kb_source` back-reference.
- `vault-contract.md §stages-propagation` + `handoff-contract.md`: explicit KB→vault preservation rule; optional `metrics.flows_with_stages` (type-checked-when-present, never required-on-absence).

**Track 2 — skill bodies (paired with enforcing validators, no prose-only):**
- `extract-intelligence/SKILL.md`: staged-input detection guidance (4 source signals; MANDATORY per-stage anchor). `generate-intent/SKILL.md`: preserve `stages:` verbatim, never flatten.

**Track 3 — enforcement:**
- `validate-kb-flows.sh`: ADVISORY `kb_flow_staging_missing` on a separate `advisories[]` channel — multi-step workflow KB without a `stages:` block. NEVER flips status (Iter-78.1 #1).
- new `validate-vault-flow-staging.sh` (PreToolUse **Branch 14**): follows each flow's `_kb_source`; KB has `stages:` but vault dropped it → `vault_flow_staging_drop`, `status==FAIL` (blocking). Backward-compatible by construction (no KB / no `_kb_source` / KB had no stages → SKIP — pre-staging vaults never trip it). It ALSO carries an advisory arm (`vault_flow_staging_missing`, WARN-only, never status-flip) for the dominant flatten case — a flow showing the workflow signal but with NEITHER stages NOR `_kb_source` (the blocking arm can't see it). **Honest coverage:** the KB advisory + vault advisory are the broad detectors; the block is the narrow precise case (back-ref preserved, stages dropped).

**Track 4 — remediation:** new `/mega-sdd:enrich-semantics` (`scripts/enrich-workflows-staging.sh`) — two-phase (propose → `--apply`) retro-fit of staging onto an existing KB without a full re-extract; re-reads cited legacy `_source`, detects the wizard pattern, allocates fields per stage. Consumes the `kb_flow_staging_missing` advisory. **Auto-propose (wired into `/mega-sdd:auto`):** the orchestrator auto-runs the **propose** step whenever the advisory is present — `--legacy-root` is AUTO-DISCOVERED (KB README "source codebase path" + common legacy dirs), it writes `ENRICHMENT-PROPOSALS.md` and **PAUSES** for review; it NEVER auto-applies (apply stays manual — the best-effort field allocation needs a human; `--no-enrich-staging` opts out). It is the one auto-integrated diagnostic that pauses rather than running transparently.

**Track 5 — proof:** `tests/fixtures/iter77-semantic-depth/` — 16/16 Fork-A assertions incl. the advisor's non-negotiable **hook-fire gate** (PreToolUse Branch 14 emits `continue:false` on a real drop, falls through on preserved). Fork-B (LLM skill-body authoring/preservation) explicitly documented as NOT script-asserted. 19/19 code-delivery fixtures still pass; kb-flows-mermaid unaffected.

## [3.70.0] - 2026-06-02

### Iter 79 — End-to-end pipeline-intelligence audit + 11 enforceable fixes

Fresh end-to-end intelligence audit (`docs/superpowers/audits/2026-06-02-intelligence-e2e/` — 00-SYNTHESIS + 4 detail lanes) targeting per-phase reasoning, advisor-sharpened: every finding graded `enforceable: Y/N` (prose-only "reason harder" asks rejected — 0-for-4 track record), anchored to reproduced `new-tradefinance-import` failures, baselined against shipped machinery. All 11 enforceable findings fixed (each = validator + pack-declared tech-agnostic signature + hook wiring + bad/good fixture; 19/19 code-delivery fixtures pass).

**Tier 0 — real defect (a gate enforcing nothing):**
- **X-1:** `validate-conflict-classification.sh` was vacuous — wired to NO hook + greped for ` ```yaml binding_conflict``` ` blocks the producer never emits (it emits `### CONFLICT-N` markdown) → SKIPped on every real binding. Rewritten to detect the real markdown form (exempting resolved conflicts), wired PostToolUse on binding write, and `binding-contract.md` now templates `conflict_class` + `resolution_complexity`. WARN-not-FAIL (backward-compat).

**Tier 1 — decomposition/delivery (the survivor-bias cluster):**
- **A2 (fan-out parity):** new `validate-fanout-parity.sh` (PreToolUse Branch 12) — presence-parity of deliverable obligations (`## UI contract`, `type: render` test) across VIEW-BEARING siblings. Catches "LC is always the survivor"; relative-to-peers (no false-stop on legitimately-simpler siblings).
- **A1 (decomposition-altitude):** `validate-flow-coverage.sh` emits advisory `decomposition_altitude_high` when an N≥4-step flow is absorbed by a SINGLE unit (does NOT flip status — symptom gates already neutralize the damage).
- **B1 (UI-deferral):** new `validate-ui-deferral.sh` (PreToolUse Branch 13) — a bolt-report that defers a unit's `## UI contract` to a future polish unit ("scaffold kept; UI polish deferred") → `ui_obligation_deferred`.
- **N-1 (shared side-effect parity):** new `flow_step:<regex>` applies_when operator in `validate-sibling-consistency.sh` + pack-declared `inbox-surfacing` concern — closes the af49ede inbox-invisibility gap (amendment/doc_exam created zero `workflow_assignments` rows).

**Tier 2 — upstream transcription-vs-reasoning:**
- **U-GI:** `validate-vault-oqs.sh` re-applies the Auto-classifier heuristic table to EVERY OQ → `oq_misclassified_tech` (a tech-reading OQ lazily tagged business).
- **U-SC:** `validate-codebase-map.sh` depth check — `precision_tier: ast` but bare §2 rows → WARN (bind-codebase field-diff would silently degrade).
- **U-EI:** new `validate-kb-reengineering.sh` — the Wave-5 reengineering synthesis (`99-rebuild-architecture/`) is validated, not just transcription discipline.

**Tier 3 — orchestrator machinery:**
- **O-3/O-4:** `validate-handoff-yaml.sh` now type-checks CONDITIONAL fields when present + promotes `next_action.confidence` to a typed, validated field in `[0,1]` (the iter-33 F4/D5 foundation). Type-only, never required-on-absence — cannot break a live chain that omits an optional block.
- **O-1:** new `validate-preflight.sh` (PreToolUse Branch 0) — predictive halt detection (iter-33 F2 closure): fatal INPUT-precondition checks for the skill about to run (bind needs vault+map; bolts need units), self-clearing.

**Invariants preserved:** every new gate is tech-agnostic (signatures from the framework-convention pack; SKIP off-stack), `errors="replace"` on reads, and new issue types are non-blocking unless a dedicated single-purpose validator (status==FAIL precise) or an explicit COUNT-gated branch opts them in.

## [3.69.1] - 2026-06-02

### Iter 78.1 — E2E integration audit remediation (precision-soundness of the 8-gate stack)

The E2E audit (`docs/superpowers/audits/2026-06-02-e2e-integration-audit.md`) found the integrated 8-gate `execute-bolts` stack deadlock-safe but not precision-sound. Fixed (all fixture-verified; `tests/fixtures/code-delivery/regressions/`):

- **ADV-01 (CRITICAL fail-open):** bare `open()` in flow-coverage/sibling-consistency/unit-spec/vault-oqs crashed on non-UTF-8 bytes → PostToolUse `|| true` swallowed it → gate silently disabled. Added `errors="replace"` to every read.
- **TAE2E-01 (CRITICAL tech-agnostic breach):** sibling-consistency hardcoded the Eloquent paren-call accessor idiom → false-FAILed + BLOCKED any non-Laravel FK project. Accessor shape is now pack-declared (`accessor_form: any|call`); non-Laravel stacks pass.
- **FPP-2 (CRITICAL false-positive):** ui-quality `required_elements` blocked correct Blade partials/components. Now exempts partials (`is_partial()`); `scaffold_tells` still apply to all views.
- **FPP-4:** sibling `missing_relations` was absolute → now a cross-sibling divergence check (solo/convention units pass).
- **FPP-3:** cross-cutting flagged the scope-source `User` model → pack-declared `registration_exempt_glob`.
- **ADV-02/ADV-03:** flow-step parser was numbered-only → now format-aware (numbered / bullet / mermaid); decision verbs + flow_signal inflection-tolerant. Mermaid maker-checker flows (a real production format) are no longer silently passed.
- **ADV-04:** tightened evadable UI scaffold-tell regexes (multi-word/uppercase ID labels, array-access FK echoes, `*_amount`/`*_total` money).
- **ADV-05/ADV-06:** broadened FK-column detection (backticked); strip comments before the cross-cutting registration check (a commented-out registration no longer satisfies it).
- **CD-2/CD-3:** Branch 9 + Branch 10 recovery REASONs rewritten to lead with a non-circular deterministic escape (direct edit / `rm` state) instead of re-running the just-blocked skill.

Also fixed: **ADV-07** (render-test accepts inline-list `acceptance_test`; dispatch-prompt rejects placeholder tokens / bare `Pattern:` label — requires a view-glob `File:`), **IE-2** (execute-bolts parent-thread post-flight re-scan documented to close the `--parallel` subagent-blind window), **IE-5** (spec branch number), and the **CD-6/IE-4 + TAE2E-03 invariant docs** (halt_type-counting on extension gates; `_universal` stays principle-only; `errors="replace"` on reads).

**CD-4 (done in v3.69.2):** the execute-bolts path now precomputes a multi-gate failure summary; `emit_block` prepends it so the first block surfaces ALL failing gates at once (`[N execute-bolts gates are failing: …]`) instead of forcing serial one-gate-at-a-time round-trips. Additive prefix only — empty when ≤1 gate fails; no control-flow change; all 9 fixtures + the 9-branch smoke pass.

**Audit punch-list: CLEARED.** All 35 E2E-audit findings are resolved or were verified design strengths (CD-1/CD-5/CD-6 etc.).

## [3.69.0] - 2026-06-02

### Iter 78 — Sharpen code delivery: decomposition reasoning + UI/UX quality (tech-agnostic, fixture-verified)

**Trigger:** Deep audit (`docs/superpowers/audits/2026-06-01-code-delivery-uiux-deep-audit.md`) + the `new-tradefinance-import` Phase-2 real-run: code *delivery* was the weak link — UI/UX a coin-flip and flow→file decomposition shallow (module-altitude only). Root causes proven from the fixture's own post-generation repair commits: fan-out divergence (golden exemplar correct, siblings drift), zero UI/UX quality gate, capture missing the operator surface.

**Approach (per spec `docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md`):** validator-first (skill prose is defense-in-depth only — prose-only wire-ups failed 4× historically), tech-agnostic (universal validator core + framework-pack-declared signatures; add a stack = add a pack), and **fixture-verified DoD** — each validator must flag the real defect in the tradefinance git history and pass on the repaired state.

**Shipped (7 slices + shared helper, all [HOOK-VALIDATE] Fork-A):**
- `scripts/_lib/resolve-framework-pack.sh` — shared pack resolver (the tech-agnostic backbone; resolves the `extends` chain + merges `--section` bodies).
- **A** `validate-flow-coverage.sh` — flow-step→artifact derivation + scaffold-filter (flags missing per-stage Form Requests + dead `edit` view stubs). PreToolUse Branch 5.
- **B** `validate-sibling-consistency.sh` — cross-unit shared-concern coherence + FK→relation derivation (flags fan-out divergence). PreToolUse Branch 7.
- **C** `validate-cross-cutting-registration.sh` — per-sibling runtime-registration scan on generated source (flags the `2bdfc1b` BranchScoped-not-registered leak; migration-driven table detection). PreToolUse Branch 11.
- **D** render-test-per-view-bearing-unit gate (`render` acceptance_test kind + `validate-unit-spec.sh` extension). PreToolUse Branch 6.
- **E** `validate-ui-quality.sh` — UI scaffold-tells gate (pack-declared `scaffold_tells`/`required_elements`). PreToolUse Branch 8.
- **F** `validate-dispatch-prompt.sh` + execute-bolts enrichment — design tokens un-excluded, UI exemplar few-shot, frontend-design heuristics injected for UI units. PreToolUse Branch 9.
- **G** operator-workflow-UX capture + Design-Source OQ (generate-intent + `validate-vault-oqs.sh`; anti-hallucination rail preserved). PreToolUse Branch 10.
- Framework-pack schema (`_template.md`/`_universal.md`/`laravel.md`/`laravel-base-26.md`) extended with: Flow-artifact derivation, Conditional scaffold artifacts, Entity source globs, Entity matching tokens, Cross-cutting concerns, Relation derivation, Test patterns, UI quality signatures.
- Skill bumps: generate-units 2.8.0→2.12.0, execute-bolts →2.12.0, generate-intent + scan-codebase (per slice).
- Fixtures: `tests/fixtures/code-delivery/**` — every slice has a `{bad,good}/` + `verify.sh` proving FLAG-on-bad + PASS-on-good; 8/8 pass.

## [3.68.0] - 2026-05-30

### Iter 77 — Generalize range-shorthand expansion (`through` / `to` / `thru` / `…`)

**Trigger:** Post-Iter-76 ship, TF Import detect-drift blocked again. State file:

```yaml
missing_artifacts:
  - .mega-sdd/vaults/tradefinance-rebuild-phase-2/bolts/U-017/ through U-025/
```

All 9 directories (U-017..U-025) confirmed on disk. Iter 75 caught ` ... ` ellipsis shorthand; Iter 77 trigger reveals model invented a NEW natural-language range condensation (`through` instead of `...`). Class-bug shape continues: model gravitates to English range expressions when asked to enumerate filesystem paths.

**Root cause:** Iter 75 `expand_ellipsis_range` regex matched only literal `...`. Producer template `execute-bolts/SKILL.md:1062-1067` only listed `...` and `(N units)` as WRONG examples; never anticipated `through`, `to`, `thru`, Unicode ellipsis. Defense-in-depth (validator) AND producer-hardening (template) both had a narrow blind spot.

**Fix (two-track, both files):**

1. **`plugins/mega-sdd/scripts/validate-handoff-yaml.sh` — `expand_ellipsis_range` → `expand_range_shorthand`**
   - Generalized regex to match `(?:\.\.\.|…|through|thru|to)` (case-insensitive for word separators).
   - Backward-compat alias kept (`expand_ellipsis_range = expand_range_shorthand`) — Iter 75 name preserved for any external caller.
   - Fallback handler: if shorthand detected but couldn't expand (malformed U-NNN range), checks each known separator and uses the LEFT side as a literal path (defensive — at least verify the producer's start path; better than failing on a shorthand we can't parse).
   - Call site updated to use new name.

2. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md:1062-1077` handoff template anti-pattern comment**
   - Broadened from "NO '...' shorthand ranges" → "NO range shorthand of ANY kind".
   - Five explicit WRONG examples now listed (ellipsis / Unicode ellipsis / `through` / `to` / `thru`) so the model sees each variant called out by name.
   - Added explicit CORRECT example block showing one-per-line enumeration with absolute paths.
   - Reasoning: model invents new condensations specifically because the prior comment was narrow. Naming each forbidden separator individually makes the rule self-evident even when the model is searching for a "more natural" alternative.

**Why not also handle `-` (single dash) as separator:**
The dash-comment strip pattern `\s+-\s+.*$` would conflict — a path `U-001/ - U-016/` would be stripped to `U-001/` before range expansion. Single dash is excluded from the range-separator set for that reason. If the model ever invents `-` shorthand, the conflicting strip will be detected first; we'll handle that explicitly then.

**Logic-proof (6 scenarios, `tests/fixtures/iter77-range-shorthand/`):**

Fixture: 10 bolt dirs (U-001 + U-017..U-025) on disk.

| Scenario | Verdict |
|---|---|
| `farhan-through-bug` — Farhan's exact production input (U-001 + `U-017/ through U-025/`) | **PASS** ✓ (the bug, fixed) |
| `scenario-D-through` — lowercase `through` only | **PASS** ✓ |
| `scenario-E-to` — lowercase `to` separator | **PASS** ✓ |
| `scenario-F-uppercase` — `THROUGH` case-insensitive | **PASS** ✓ |
| `scenario-G-genuine-miss` — `through U-030/` but only U-017..U-025 on disk | **FAIL** ✓ (false-negative preserved; U-026..U-030 correctly flagged) |
| `scenario-H-iter75-regression` — original `...` ellipsis | **PASS** ✓ (defense intact) |

**Files changed (this iter):**

- `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` — rename + regex generalization + call site update.
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — broadened anti-pattern comment with 5 WRONG examples + 1 CORRECT block.
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.67.0 → 3.68.0.
- `tests/fixtures/iter77-range-shorthand/` — NEW: 6 scenarios + bolt dir fixture + README.
- `CHANGELOG.md` — this entry.

**Logic-proven on fixtures; production live-firing pending `/mega-sdd:update-plugin` at TF Import.**

**Discipline:** authored in canonical, no TF Import touches.

**Classifier (EP2):** MINOR (5 files changed; no halt-enum diff; no new skill dir; no BREAKING marker; validator script + SKILL body modified). plugin.json 3.67.0 → 3.68.0 ✓.

**Class-bug iteration count:** This is the THIRD iter in the "model shorthand vs validator strict-check" class (Iter 73 = parenthetical annotations, Iter 75 = ellipsis, Iter 77 = English range words). Pattern: defense-in-depth strip/expand + producer template anti-pattern comments grow per-shape. Considered an alternative architecture (forbid all artifact field shapes with regex pre-emit), but that's higher complexity vs incremental shape coverage. Stay with current approach; revisit if Iter 78 surfaces a 4th shape — at that point it may indicate a deeper producer-side intervention is needed.

## [3.67.0] - 2026-05-29

### Iter 76 — Wire §patterns + controller code-slice into T2.3 (walking-skeleton)

**Trigger:** Post-Iter-68 regression discovered while tracing bolt output quality. scan-codebase v3.0 (Iter 68) produces a `patterns:` block in `<project>/.mega-sdd/codebase/starterkit-context.yaml` capturing pack-driven location + naming + extras + `_source` per generic category (controller / data_model / request_validator / business_logic / test / schema_migration / route). execute-bolts Step 4.5.b-starterkit.build (last touched Iter 32) injects 4 legacy slices (auth / rbac / ui_ux / libs) into T2.3 BUT NEVER reads the `patterns:` block — bolt subagent is told "follow starterkit conventions" without ever being told what those conventions ARE. Cross-skill producer/consumer split that no validator caught.

**Root cause:** Iter 32's slice builder was authored before §patterns existed; Iter 68 added the producer side (deep-read) but didn't update the consumer (execute-bolts). Classic shape: producer ships, consumer left stale. Same class-bug as Iter 75 (handoff template "..." comment guidance), Iter 73 (annotation tolerance), Iter 69 (next_action shape).

**Fix (two-part wire-up):**

1. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.b-starterkit.build.patterns (NEW)**
   - Iterates all 7 generic categories.
   - **Location-primary match:** if `unit.target_files[i]` starts with `pattern.location` (normalized to trailing slash), category enters slice.
   - **Naming-fallback (only when location is null):** for frameworks with file-based routing (Next.js, Express handlers-anywhere) where convention is naming-not-location. Compiles `{Model}<ext>` → `[A-Z]\w+\.<ext>$`, matches against basename only.
   - **Why not the user-spec OR-semantics:** in fixture testing, `data_model.naming = "{Model}<ext>"` with `.php` greedily matched ANY PascalCase `.php` basename — including `SampleController.php` — causing data_model false-positive injection alongside controller. Location-primary is conservative and avoids crowding T2. Decision logged in SKILL prose; revisit if Iter 77 telemetry shows missed null-location matches.

2. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.b-starterkit.build.code-slice (NEW; walking-skeleton: controller-only)**
   - When `slice.patterns.controller` matched, embed the FIRST `_source` file verbatim as a few-shot anchor.
   - File-size budget: `<3KB` → embed full; `≥3KB` → first 100 lines + `# ... (truncated)` marker.
   - `_source` path missing on disk → log + skip code embed (pattern metadata still injected; NOT a halt).
   - Walking-skeleton: controller-only this iter; extend to other 6 categories Iter 77+ after real-run validates the controller path.

3. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` Step 4.5.a.5 — T2 budget cap bump (Option A)**
   - `cap_t2`: 5120 → 10240 (5KB → 10KB; makes room for patterns + 1 code example).
   - `cap_hard`: 10240 → 12288 (10KB → 12KB; preserves ~2KB T1 headroom).
   - Rationale prose calls out Iter 77 telemetry as revisit gate; truncation cascade extended with `code_examples.controller.content` (100 → 50 lines) priority slot.

4. **`plugins/mega-sdd/skills/execute-bolts/SKILL.md` Step 4.5.b-starterkit.inject + `references/bolt-dispatch-prompt.md` §T2.3 — render templates**
   - Two new sections: `### Starterkit code patterns (follow these conventions)` + `### Reference code example (from starterkit)`.
   - Anti-halu rails for each: when patterns block present, bolt MUST honor location + naming + extension for new files in that category; when code example present, bolt MUST follow structural idioms (imports, base class, method shape).

**Logic-proof (3 scenarios, `tests/fixtures/iter76-patterns-injection/`):**

Fixture: Laravel-style starterkit with full §patterns block + `app/Http/Controllers/ExampleController.php` (~720 bytes). Unit with `target_files: [app/Http/Controllers/SampleController.php]`, `starterkit_relevance: [controller]`.

| Scenario | Verdict |
|---|---|
| A_match — unit matches `patterns.controller.location` | **PASS** ✓ — slice.patterns.controller populated, slice.code_examples.controller embeds ExampleController.php verbatim, T2.3 render shows both sections (rendered 1428 bytes). data_model NOT false-positively injected. |
| B_no_match — `target_files: [resources/views/random.blade.php]` matches no category | **PASS** ✓ — slice.patterns empty, no patterns/example render (rendered 47 bytes — header only). |
| C_missing_src — `patterns.controller._source[0]` points to nonexistent file | **PASS** ✓ — pattern metadata still rendered (preserves conventions), code_examples skipped (no halt). |

**Files changed (this iter):**

- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.a.5 caps bump; Step 4.5.b-starterkit.build extended with `.patterns` + `.code-slice` sub-blocks; Step 4.5.b-starterkit.inject render extended; truncation cascade extended (5 levels).
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — §T2.3 template extended with `### Starterkit code patterns` + `### Reference code example` sections + anti-halu rails per section.
- `plugins/mega-sdd/.claude-plugin/plugin.json` — version 3.66.0 → 3.67.0.
- `tests/fixtures/iter76-patterns-injection/` — NEW: simulate-build.py + Laravel-style starterkit fixture + README documenting 3 scenarios.
- `CHANGELOG.md` — this entry.

**Logic-proven on fixtures; production live-firing pending `/mega-sdd:update-plugin` at TF Import.** Walking-skeleton: controller-only this iter. Iter 77 extends to data_model + test categories after real-run telemetry confirms patterns reach bolts + budget stays manageable.

**Discipline:** authored in canonical (gitlab.com/airnd1/grand-design-spec), no TF Import touches.

**Classifier (EP2):** MINOR (4 files changed; no halt-enum diff; no new skill dir; no BREAKING marker; existing SKILL bodies modified). plugin.json 3.66.0 → 3.67.0 ✓.

## [3.66.0] - 2026-05-29

### Iter 75 — Handoff ellipsis range expansion (`U-001/ ... U-016/`)

**Trigger:** TF Import detect-drift block, post-3.65.1 ship. execute-bolts emitted:

```yaml
artifacts:
  - .mega-sdd/vaults/tradefinance-rebuild-phase-1/bolts/U-001/ ... U-016/
```

Validator strict-check `os.path.exists("<path>/U-001/ ... U-016/")` → False → `artifact_missing`. All 16 bolt directories actually exist on disk; the model condensed the enumeration into ellipsis shorthand.

**Root cause:** `execute-bolts/SKILL.md` handoff template had:
```yaml
artifacts:
  - <absolute path to vault/bolts/U-001/>
  - <absolute path to vault/bolts/U-002/>
  # ... one per unit executed     ← the "..." in the COMMENT cued the model to use "..." in OUTPUT
```

The trailing `# ... one per unit executed` comment was meant as instruction to the reader ("repeat for each unit"); the model interpreted "..." as a valid shorthand to emit verbatim.

**Two-track fix:**

### Track 1 — Producer template hardening

`plugins/mega-sdd/skills/execute-bolts/SKILL.md` line 943-948 — handoff `artifacts:` block now carries explicit anti-pattern comments:

```yaml
artifacts:                                                  # Enumerate ONE LINE per bolt dir actually written; NO "..." shorthand ranges; NO "(N units)" annotations
  - <absolute path to vault/bolts/U-001/>                   # e.g., /Users/.../.mega-sdd/vaults/<vault>/bolts/U-001
  - <absolute path to vault/bolts/U-002/>                   # one line per executed unit
  # WRONG: "/.../bolts/U-001/ ... U-016/"  ← validator expands ellipsis defensively (Iter 75), but producers SHOULD enumerate explicitly
  # WRONG: "/.../bolts/ (16 units)"        ← annotation will be stripped, but be explicit
  # Repeat "- <abs path to bolts/U-NNN/>" for EVERY unit you executed — no shortcuts.
```

### Track 2 — Validator defense-in-depth: ellipsis range expansion

`plugins/mega-sdd/scripts/validate-handoff-yaml.sh` Step 5 — new helper `expand_ellipsis_range(p)` detects `<prefix>U-<start>/ ... U-<end>/` pattern, parses start/end as integers, expands to explicit path list, checks each `os.path.exists()`. Sanity cap: max 1000 entries to bound pathological inputs.

Fallback: if path contains ` ... ` but doesn't match the U-NNN range pattern, treat the LEFT side as the actual path (defense: if start exists, producer at least got the location right).

Both Iter 73 strip patterns AND Iter 75 ellipsis expansion now apply to every artifact path defensively.

### Logic-proven via direct-invoke

Fixture at `/tmp/iter74-bolts/` with 16 bolt directories on disk (mirrors Farhan's TF Import disk state):

| Scenario | Handoff content | Verdict |
|---|---|---|
| A. Farhan's exact ellipsis bug | `artifacts: ["/bolts/U-001/ ... U-016/"]`, U-001..U-016 all exist | **PASS** ✓ (expansion + exists check) |
| B. Clean enumerated | 4 explicit paths | **PASS** ✓ |
| C. Ellipsis claims U-001..U-020 but disk only U-001..U-016 | range expands → U-017..U-020 don't exist | **FAIL** ✓ (detection preserved) |

Scenario C confirms the expansion correctly flags genuinely missing artifacts even when shorthand was used — defense doesn't introduce false negatives.

### Cross-skill scope

Validator-side fix applies to ANY skill emitting U-NNN ranges with ellipsis (execute-bolts, generate-units, list-modules, etc.). One defensive expansion covers the class. Generic-numeric patterns (non-U-NNN) currently fall back to the LEFT-side-as-path check — extension candidate if other patterns emerge in soak.

Plugin version 3.65.1 → 3.66.0 (MINOR per classifier: new validator capability + producer template hardening).

---

## [3.65.1] - 2026-05-29

### Iter 74 (patch) — Stop hook emitted_by regex tolerates `mega-sdd:` prefix

**Trigger:** TF Import detect-drift block message showed `upstream mega-sdd:mega-sdd emitted bad handoff` — doubled `mega-sdd:` prefix in the producer name.

**Root cause:** `hooks/stop` regex extracting `emitted_by` from handoff used `[\w-]+`, which stops at colon. When the producer emitted `emitted_by: mega-sdd:execute-bolts` (with full prefix — variant the wild produces despite handoff-contract.md saying bare form), the regex captured only `mega-sdd`, then the downstream code unconditionally prepended `mega-sdd:` → final `mega-sdd:mega-sdd` written to state file `skill_name` field.

**Side effects:**
- **Iter 70 producer-self-fix broken in this case**: `SKILL_NAME` being invoked is `mega-sdd:execute-bolts`, but `state.skill_name` is `mega-sdd:mega-sdd`. They don't match → producer-self-fix allow doesn't fire → producer can't retry to fix its own bad handoff (the deadlock Iter 70 was meant to prevent reappeared in a new shape).
- **Cosmetic**: PreToolUse block message displayed `upstream mega-sdd:mega-sdd` instead of the real producer name.

**Fix:** Extended regex to tolerate optional `mega-sdd:` prefix on the value: `^\s*emitted_by:\s*(?:mega-sdd:)?([\w-]+)`. Matches both forms — bare and prefixed — extracting just the skill identifier. Downstream prepend produces `mega-sdd:<skill>` consistently regardless of which form the producer emitted.

**Logic-proven via direct regex tests:**
| Producer wrote | Extracted |
|---|---|
| `emitted_by: extract-intelligence` | `extract-intelligence` |
| `emitted_by: mega-sdd:execute-bolts` | `execute-bolts` |
| `emitted_by:    mega-sdd:scan-codebase` (extra spaces) | `scan-codebase` |
| `emitted_by: mega-sdd:detect-drift` (inside YAML fence) | `detect-drift` |

PATCH bump 3.65.0 → 3.65.1 (regex tweak only, no semantic change to validator logic).

---

## [3.65.0] - 2026-05-29

### Iter 73 — Handoff artifact annotation tolerance (false-positive fix)

**Trigger:** TF Import production run, post-3.64.0 ship. User attempted `/mega-sdd:execute-bolts --all --auto` after successful KB → units chain; PreToolUse blocked with:

```
upstream mega-sdd:generate-units emitted bad handoff (artifact_missing, retry=2, escalate_c2=True)
missing_artifacts: [".mega-sdd/vaults/tradefinance-rebuild-phase-1/units/ (18 files)"]
```

Disk inspection: the path `.mega-sdd/vaults/tradefinance-rebuild-phase-1/units/` DOES exist with 18 entries (16 units + `_index.md` + `_dependency-graph.json`). The validator failed because the producer emitted the path with a `" (18 files)"` count annotation appended, and `os.path.exists("<path>/ (18 files)")` returns False.

**Root cause:** `generate-units/SKILL.md` handoff template placeholder reads `<absolute path to units/ directory>` — semantically ambiguous. The model interpreted "describe the units directory" and appended a count annotation. The template never explicitly forbade annotations; `validate-handoff-yaml.sh` walks artifacts strict-equal against `os.path.exists()`.

**Two-track fix:**

### Track 1 — Producer template hardening

`plugins/mega-sdd/skills/generate-units/SKILL.md` line 803-809 — handoff `artifacts:` block now carries inline comments explicitly forbidding annotations:

```yaml
artifacts:                                       # MUST be plain filesystem paths — NO annotations like "(N files)", "(latest)", or comments
  - <absolute path to units/ directory>          # e.g., /Users/.../.mega-sdd/vaults/<vault>-bound/units (or <vault>/units when --no-bind)
  - <absolute path to units/_index.md>           # e.g., /Users/.../.mega-sdd/vaults/<vault>-bound/units/_index.md
  # WRONG: "/Users/.../units/ (18 files)"        ← validator strips trailing " (...)" defensively, but producers SHOULD emit clean paths
  # WRONG: "/Users/.../units/ # latest"          ← inline comments invalid in YAML scalars
```

### Track 2 — Validator defense-in-depth

`plugins/mega-sdd/scripts/validate-handoff-yaml.sh` Step 5 (artifact existence check) — strips 3 trailing annotation patterns before `os.path.exists()`:

| Pattern | Example | Strip |
|---|---|---|
| `\s+\([^)]*\)\s*$` | `path/ (18 files)` | trailing parenthesized text |
| `\s+-\s+.*$` | `path/ - latest` | trailing dash-comment |
| `\s+#\s+.*$` | `path/ # note` | trailing hash-comment |

Plus a `rstrip("/")` to tolerate trailing slash on directory paths.

The ORIGINAL path is reported in `missing_artifacts` (so producer can see what they emitted) — only the existence check uses the cleaned form.

**Scope:** the strip applies to ALL skills' handoff artifacts (generate-units, bind-codebase, extract-intelligence, diff-vault, emit-fsd, execute-bolts, generate-intent, detect-drift, emit-agents-md) — all share the same `<absolute path to ...>` placeholder pattern and same potential failure mode. Validator-side fix covers the class.

### Logic-proven via direct-invoke

Built fixture at `/tmp/iter73-genunits/` matching Farhan's exact disk state (16 units + _index + _dependency-graph = 18 entries):

| Scenario | Handoff content | Verdict |
|---|---|---|
| A. Farhan's exact bug | `artifacts: ["/path/ (18 files)"]`, files exist | **PASS** ✓ (strip resolves to real dir) |
| B. Clean variant | `artifacts: ["/path/", "/path/_index.md"]`, files exist | **PASS** ✓ |
| C. Genuinely missing | `artifacts: ["/missing/", "/missing/ (50 files)"]`, files DO NOT exist | **FAIL** ✓ (detection signal preserved) |

Scenario C confirms the defense doesn't introduce false negatives — actual missing artifacts still surface, with the ORIGINAL annotated path reported.

### Files changed

| File | Change |
|---|---|
| `plugins/mega-sdd/skills/generate-units/SKILL.md` | Handoff template — inline comments forbidding annotations + WRONG examples |
| `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` | Step 5 — defensive strip of trailing annotations before `os.path.exists()` |

Plugin version 3.64.0 → 3.65.0 (MINOR per classifier: producer template hardening + validator behavior change).

### Immediate workaround for affected installs

For projects already in the FAIL-state-with-retry-2-escalate (Farhan's case):

```bash
rm <project>/.mega-sdd/.handoff-validation-state.json
```

(File NOT in anti-self-bypass protected list.) Then re-run `/mega-sdd:execute-bolts --all --auto`. After v3.65.0 update lands, future runs do not need the manual rm — validator tolerates the annotation natively.

---

## [3.64.0] - 2026-05-29

### Iter 72 — Mermaid emission rules + heuristic syntax validation

**Trigger:** TF Import production run emitted parser-failing Mermaid in extract-intelligence KB output:

```
PRE([LC has flag_amend IN (2.2, 4)])
```

The unquoted `(2.2, 4)` inside the stadium shape `[(...)]` broke the Mermaid lexer. `validate-kb-flows.sh` v1 only checked fence presence (` ```mermaid `) and did not parse syntax — so the invalid block passed validation and shipped downstream where the renderer failed.

**Two-track fix:**

### Track 1 — Skill body Mermaid emission rules

NEW reference `plugins/mega-sdd/references/mermaid-emission-rules.md` — 6 rules with side-by-side ❌/✅ examples:

| Rule | Summary |
|---|---|
| Rule 1 | ALWAYS wrap node text in double quotes regardless of shape |
| Rule 2 | Newlines in node text = `<br/>`, NEVER literal `\n` or actual newline |
| Rule 3 | Escape `<`, `>`, `&`, embedded `"` with HTML entities |
| Rule 4 | Edge labels with parens/commas/colons also wrapped in quotes |
| Rule 5 | Paraphrase raw code expressions (`IN (2.2, 4)` → `"amend flag in (2.2 OR 4)"`) |
| Rule 6 | `classDef` + `style` at end of block; verify spelling (`stroke-dasharray`, not `stroke-dash-array`) |

Reference cross-linked from:
- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` §Quality gates between waves
- `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` §3 Flow + §8 State Machine (both blocks now show the canonical quoted form as the default example)
- `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` (Wave 2 prompt instructions)

### Track 2 — `validate-kb-flows.sh` v2 heuristic Mermaid syntax check

Rewrote the validator with a stateful tokenizer that:
- Identifies node specs by walking each line character-by-character (respects quoted strings so cases like `PRE(["text with (parens, commas)"])` don't false-positive)
- Recognizes all 11 Mermaid shape pairs (`[(/)]`, `([/])`, `[[/]]`, `((/))`, `{{/}}`, `[//]`, `[\\/\]`, `(/)`, `[/]`, `{/}`, `>/]`)
- For each unquoted, non-identifier node text, checks for:
  - **Rule 1**: dangerous chars (`,`, `(`, `)`, `:`, `|`) → flags with suggested-fix `wrap in double quotes`
  - **Rule 2**: literal `\n` inside content → flags with suggested-fix `replace with <br/>`
  - **Rule 3**: multiple unescaped `"` → flags with HTML-entity escape suggestion

Failure reports include: `line_number`, `node_id`, `rule_violated`, `excerpt` (120 chars), `suggested_fix` (exact corrective rewrite).

**Verdict tier:** C2 (producer must rewrite). NOT C1 — auto-rewriting Mermaid risks semantic change (e.g., paraphrasing a condition incorrectly). Producer-side responsibility.

**v2 mmdc full-parser deferred:** evaluated `npx -y @mermaid-js/mermaid-cli` for ground-truth syntax checks — adds node/npx dependency, slow first-invocation, offline-flaky. Documented as Fork-B-future in `mermaid-emission-rules.md §Deferred to Iter 73+`. Trigger condition: heuristic v1 misses ≥3 real failures in soak window.

### Files changed

| File | Change |
|---|---|
| `plugins/mega-sdd/references/mermaid-emission-rules.md` | NEW — 6 rules + multi-framework examples + anti-pattern catalog |
| `plugins/mega-sdd/scripts/validate-kb-flows.sh` | Rewritten — added v2 tokenizer + 3 rule checks; preserves v1 fence-presence checks |
| `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` | §Quality gates: added Mermaid emission rules to gate-check list |
| `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` | §3 Flow + §8 State Machine: added rule pointers + canonical quoted examples |
| `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` | Wave 2 instructions: added rule pointer |
| `tests/fixtures/kb-flows-mermaid/.mega-sdd/knowledge-base/10-domains/01-bad-mermaid.md` | NEW fixture — reproduces TF Import bug + literal `\n` + unquoted edge label |
| `tests/fixtures/kb-flows-mermaid/.mega-sdd/knowledge-base/10-domains/02-good-mermaid.md` | NEW fixture — rules-compliant variant of 01-bad-mermaid.md |

### Logic-proven via direct-invoke

**BAD fixture** (`01-bad-mermaid.md`):
```json
"status": "FAIL",
"issues": [
  {"line_number": 19, "node_id": "PRE", "rule_violated": "Rule 1 — unquoted text with special chars ((),)",
   "suggested_fix": "wrap node text in double quotes: PRE([\"LC has flag_amend IN (2.2, 4)\"])"},
  {"line_number": 20, "node_id": "M1", "rule_violated": "Rule 2 — literal \\n in unquoted node text",
   "suggested_fix": "replace `\\n` with `<br/>` and wrap in quotes: M1[\"Reverse Amend Maker<br/>input/import_reverse_amends.php\"]"}
]
```

Suggested-fix for the headline issue (line 19) is **exactly** the canonical form the user provided in the task spec: `PRE(["LC has flag_amend IN (2.2, 4)"])`.

**GOOD fixture** (`02-good-mermaid.md`, same content quoted):
```json
"status": "PASS", "issues": 0
```

### PostToolUse wiring (no change needed)

`hooks/post-tool-use` already dispatches `validate-kb-flows.sh` on KB writes (wired in Iter 68 path-scoped dispatch, line 529-531). New v2 syntax checks inherit the existing trigger — no hook update required.

Plugin version 3.63.0 → 3.64.0 (MINOR per classifier: new validator capability + new reference file + skill body update).

---

## [3.63.0] - 2026-05-29

### Iter 71 — CWD class-bug: walk up to project root before writing state

**Trigger:** TF Import production-confirm run revealed 8 state files + `memory/hook-debug.log` + `telemetry.jsonl` + `CONSISTENCY-REPORT.md` written to `<project>/.mega-sdd/knowledge-base/.mega-sdd/` (nested) instead of `<project>/.mega-sdd/`. Root cause: hooks and scripts treated stdin-provided `${CWD}` (or `--cwd` flag value) as the project root, but when the model's CWD shifts to a sub-folder during a chain step (extract-intelligence often operates inside `.mega-sdd/knowledge-base/`), `${CWD}/.mega-sdd/...` becomes `.mega-sdd/<sub>/.mega-sdd/...`. Once one hook writes nested state, every subsequent hook/script reads from the wrong location and the project splits into two parallel state trees.

**Class scope:** 4 hooks + 22 scripts. Same bug pattern: `${CWD}/.mega-sdd/...` without walking up.

### The fix — shared walk-up resolver

New file `plugins/mega-sdd/scripts/_lib/resolve-project-root.sh`:

```bash
resolve_project_root() {
  local d="${1:-$PWD}"
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    if [ -d "$d/.mega-sdd" ] && [ "$(basename "$d")" != ".mega-sdd" ]; then
      echo "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  echo "${1:-$PWD}"  # greenfield fallback
}
```

The `basename != ".mega-sdd"` guard defensively skips the pathological inner `.mega-sdd/.mega-sdd/` layout that prior buggy runs could have created.

**Hooks** (4): inline source the helper, compute `PROJECT_ROOT=$(resolve_project_root "$CWD")` after parsing stdin, replace every `${CWD}/.mega-sdd/...` with `${PROJECT_ROOT}/.mega-sdd/...`, pass `--cwd="$PROJECT_ROOT"` to all spawned validator scripts.

**Scripts** (22): inline source the helper after the `for arg ... done` arg-parse loop, defensively reassign `CWD=$(resolve_project_root "$CWD")` — covers standalone invocations from a sub-folder even if the caller forgot to resolve.

### Files changed

| Path | Change |
|---|---|
| `plugins/mega-sdd/scripts/_lib/resolve-project-root.sh` | NEW — shared walk-up helper |
| `plugins/mega-sdd/hooks/session-start` | Source helper; resolve `project_root`; replace `${cwd}/.mega-sdd/...` → `${project_root}/.mega-sdd/...`; debug-log captures both `cwd` AND resolved `project_root` |
| `plugins/mega-sdd/hooks/pre-tool-use` | Source helper; resolve `PROJECT_ROOT`; replace 7 `${CWD}/.mega-sdd/...` refs; block-message `rm` suggestion now points to resolved path |
| `plugins/mega-sdd/hooks/post-tool-use` | Source helper; resolve `PROJECT_ROOT`; replace 14 `${CWD}/.mega-sdd/...` refs; pass `--cwd="$PROJECT_ROOT"` to all 11 validator dispatches |
| `plugins/mega-sdd/hooks/stop` | Source helper; resolve `PROJECT_ROOT`; replace 8 `${CWD}/.mega-sdd/...` refs |
| `plugins/mega-sdd/scripts/*.sh` (22 files) | All scripts touching `.mega-sdd/` (validators, run-analyze, memory-write, audit-domain-rules) defensively re-resolve CWD after arg-parse |

### Logic-proven via direct-invoke (CWD = nested sub-folder)

Test fixture `/tmp/iter71-nested-cwd/` with `CWD=/tmp/iter71-nested-cwd/.mega-sdd/knowledge-base/10-domains` (3 levels deep inside `.mega-sdd/`):

| Hook | Result | Where state landed |
|---|---|---|
| session-start | `hook-debug.log` written at `<root>/.mega-sdd/memory/` ✓ | NESTED `.mega-sdd/` NOT created ✓ |
| post-tool-use (Write codebase-map.md) | `.codebase-map-state.json` written at `<root>/.mega-sdd/` ✓ | NESTED `.mega-sdd/` NOT created ✓ |
| pre-tool-use (downstream consumer block) | block-message `rm` path points to `<root>/.mega-sdd/.handoff-validation-state.json` ✓ | (no state writes) |
| stop | `hook-debug.log` appended at `<root>/.mega-sdd/memory/` ✓ | NESTED `.mega-sdd/` NOT created ✓ |

All 4 hooks write to the project root even when CWD is 3 levels deep inside `.mega-sdd/`. Class-bug closed.

### Bonus diagnostic

Audited skill bodies for prose that instructs `cd` / `chdir` / CWD shift: ZERO hits in `extract-intelligence/SKILL.md`, `wave-dispatch-templates.md`, or any other skill body. The CWD shift observed at TF Import was NOT skill-prose-driven — most likely harness-layer behavior (Claude Code may set CWD based on the file being edited) or user-shell-driven. The hook-level walk-up is the right defense regardless of where the shift originates.

Plugin version 3.62.0 → 3.63.0 (MINOR per classifier: 26 files changed, new shared helper file, hook + script behavior change).

---

## [3.62.0] - 2026-05-28

### Iter 70 — PreToolUse producer self-fix allow (handoff deadlock fix)

**Trigger:** TF Import re-run after v3.61.0 ship. User invoked `mega-sdd:scan-codebase` after pulling the fix — got blocked by PreToolUse:

```
PreToolUse:Skill hook stopped continuation: mega-sdd:scan-codebase blocked by
handoff validation — upstream mega-sdd:scan-codebase emitted bad handoff
(handoff_type_mismatch, retry=1, escalate_c2=False)...
```

**Root cause:** PreToolUse handoff-validation gate (`hooks/pre-tool-use:158`) read `.handoff-validation-state.json` (status=FAIL from the v3.60.0 run that exposed the bug) and blocked ALL `mega-sdd:*` skill invocations — INCLUDING the producer's own retry. The state file is OVERWRITE-NOT-APPEND: it gets cleared the moment the producer runs once and emits a valid handoff. But the hook prevented the producer from ever running again. Classic deadlock.

The escape-hatch suggestion in the block message (`Re-invoke ... with --strict-handoff` and `clear state via /mega-sdd:validate-handoff after fix`) was misleading on both counts:
- Skill-tool invocations don't take `--strict-handoff` (no flag plumbing exists)
- `/mega-sdd:validate-handoff` writes to `.validation-blockers.json`, NOT `.handoff-validation-state.json`

So the user was deadlocked with no working escape hatch in the message.

**Fix:** Compare `SKILL_NAME` being invoked against `state.skill_name` (the producer that emitted the bad handoff). When they match → ALLOW (producer self-fix attempt; state will be overwritten on next emit, clearing the block for downstream too). When they differ → BLOCK as before (downstream consumer trying to use bad output).

The block message is also corrected: directs user to either (a) re-invoke the producer (now auto-allowed) OR (b) `rm` the state file manually (it's not in the anti-self-bypass protected list).

### Files changed

| File | Change |
|---|---|
| `plugins/mega-sdd/hooks/pre-tool-use` | Branch 1a: extract `state.skill_name`, allow when matches `SKILL_NAME`; corrected block message |

### Logic-proven via direct-invoke

Constructed 3 stdin scenarios against `/tmp/iter70-pretool/`:

| Scenario | Producer in state | Invoking | Verdict |
|---|---|---|---|
| Producer self-fix | `mega-sdd:scan-codebase` (FAIL) | `mega-sdd:scan-codebase` | **ALLOW** (exit=0) ✓ |
| Downstream consumer | `mega-sdd:scan-codebase` (FAIL) | `mega-sdd:generate-intent` | **BLOCK** with corrected message ✓ |
| Clean state | `mega-sdd:scan-codebase` (PASS) | `mega-sdd:generate-intent` | **ALLOW** (exit=0) ✓ |

Plugin version 3.61.0 → 3.62.0 (MINOR per classifier: hook-layer behavior change).

---

## [3.61.0] - 2026-05-28

### Iter 69 — next_action shape normalization (handoff_type_mismatch fix)

**Trigger:** TF Import production-confirm re-run (after v3.60.0 ship). Handoff validator detected `handoff_type_mismatch` on scan-codebase output:

```
next_action must be string OR dict, got list
```

**Root cause:** 4 `next_action:` templates in `scan-codebase/SKILL.md` (lines 584, 599, 614, 661) emitted a non-canonical dict shape (`type: + hint:` for halts, `type: + suggested_skill: + suggested_args:` for the main handoff). The model serialized the inconsistent shape as a YAML list — confused by the `suggested_args:` sub-list inside a dict that already had a list-like `type:`/`hint:` pair. Latent bug exposed only after v3.59.0 wired `validate-handoff-yaml.sh` into the Stop hook.

**Fix:** Normalize ALL `next_action:` to either:
- **String form** (halt blocks; matches `bind-codebase:464` + `execute-bolts:61` convention):
  ```yaml
  next_action: "Run /mega-sdd:<skill> <args> — <reason>"
  ```
- **Canonical dict form** (main handoff emission; matches `handoff-contract.md` schema):
  ```yaml
  next_action:
    suggested_skill: mega-sdd:<next-skill>
    suggested_args: ["--flag=value", "..."]
    rationale: "<1-sentence why this is the right next step>"
  ```

Drops the non-contract `type:` field everywhere it appeared. The `type:` field was never read by the orchestrator or any validator — pure noise that confused YAML serialization.

### Files changed

| Skill | Lines | Edits | New shape |
|---|---|---|---|
| `scan-codebase/SKILL.md` | 584, 599, 614 | 3 halt YAML blocks | string-form |
| `scan-codebase/SKILL.md` | 661 | main handoff emission | canonical dict-form |
| `execute-bolts/SKILL.md` | 362, 423 | `partial_state_corrupt` halt (duplicated) | string-form |
| `execute-bolts/SKILL.md` | 923, 933 | end-of-phase handoff (continue / chain_complete) | dict-form / string-form |
| `generate-units/SKILL.md` | 637, 788 | `starterkit_rule_citation_missing` halt (duplicated) | string-form |
| `orchestrate-flow/SKILL.md` | 136, 201, 252, 286, 323, 351 | 6 halt-envelope examples (model_tier_unknown, dep_missing, handoff_missing, handoff_type_mismatch, missing_artifacts, cond_field_missing) | string-form |
| `emit-fsd/SKILL.md` | 114 | `template_slot_unfilled` halt | string-form |

Total: 16 `next_action` shapes normalized across 5 skill bodies.

### Logic-proven via direct-invoke

Constructed 3 simulated handoff transcripts at `/tmp/hyaml-test/`:

| Shape | Sample | Validator verdict |
|---|---|---|
| String-form (matches new halt blocks) | `next_action: "Run /mega-sdd:generate-intent ..."` | **PASS** ✓ |
| Canonical dict-form (matches new line 661) | `next_action: { suggested_skill, suggested_args, rationale }` | **PASS** ✓ |
| List-form (the original bug shape) | `next_action: [item1, item2, item3]` | **FAIL** — `halt_type: handoff_type_mismatch`, `type_errors: ["next_action must be string OR dict, got list"]` |

Both new shapes lint clean against `validate-handoff-yaml.sh`; the original bug shape lints exactly as the production-confirm run reported.

### Bonus

`orchestrate-flow/SKILL.md` had 6 halt-envelope EXAMPLES that taught the same bad pattern downstream skills had been copying. Normalized as part of the same fix — preempts the next 6 latent bugs.

---

## [3.60.0] - 2026-05-28

### Iter 68 — Production-confirm gap closure (3 fixes)

**Trigger:** TF Import production-confirm run (`/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/new-tradefinance-import`) after v3.59.0 ship — verified scan-codebase artifact alignment + hook fire evidence. Audit revealed 3 closeable gaps before Step 2 (extract-intelligence) can begin.

### Fix 1 — §patterns producer wired in scan-codebase + schema generalized

**Was:** v3.0 §patterns block was authored as consumer-side schema (`references/starterkit-context-schema.md`) + validator (`validate-starterkit-conformance.sh`), but the PRODUCER (`scan-codebase/SKILL.md`) still emitted `schema_version: 2.0` and never wrote a `patterns:` block. Validator standby with nothing to validate.

**Now:** 
- `scan-codebase/SKILL.md` emit template bumped to `schema_version: 3.0` + `generated_by: scan-codebase v3.0.0` + adds `patterns:` block emission in the consolidator stage.
- New Step 10.5.2.5 — Deep-read code patterns (pack-driven, framework-agnostic). Runs in main thread after Step 10.5.2 subagents return; framework pack tells deep-scan WHERE each generic category lives. Skill body contains zero Laravel-specific paths.
- Schema generalized per Farhan revisi: 7 universal semantic categories (`controller`, `data_model`, `request_validator`, `business_logic`, `test`, `schema_migration`, `route`) with core fields (`location`, `naming`, `extension`, `_source`) + `extras: {}` per category for framework-specific quirks. Validators MUST NOT introspect `extras`.
- `route.style` uses generic descriptor (`centralized-routes` / `decorator-based` / `file-based-routing` / `manual`) — not framework-specific terms like `apiResource`.
- `location: null` supported for absent framework-layer conventions (e.g., Django has no service-layer convention → `business_logic: { location: null, ... }`).
- `validate-starterkit-conformance.sh` accepts both v3.0 generic names (`data_model`, `request_validator`) and v2.x legacy aliases (`model`, `request`); skips categories with `location: null`; detects schema/validator dirs (zod-style) for `request_validator`.
- Schema-doc adds multi-framework examples (Laravel + Django + Express) side-by-side to make genericness inspection-obvious.

**Logic-proof fixtures:**
- `tests/fixtures/sample-project/.mega-sdd/codebase/starterkit-context.yaml` migrated to v3.0 generic schema; validator parses 7 generic categories, still catches U-003 `src/handlers/` violation.
- `tests/fixtures/scan-frameworks/{laravel,django,express}-fixture.yaml` — same 7 generic categories, framework-appropriate values; Django proves `null` layer support; `route.style` proves generic descriptors.

### Fix 2 — Path-scoped PostToolUse validator dispatch

**Was:** `hooks/post-tool-use` dispatched validator only when `SKILL_NAME == mega-sdd:generate-units` (line ~142). Writes from `scan-codebase`, `extract-intelligence`, `bind-codebase`, manual edits — all bypassed validators. TF Import run had zero `.codebase-map-state.json` / `.starterkit-conformance-state.json` despite both files being written.

**Now:** Path-scoped triggers in the `Write|Edit` branch (in addition to existing skill-name dispatch which remains for `validate-starterkit-metrics` since it needs `--transcript-path`):

| Path | Validator(s) fired |
|---|---|
| `*.mega-sdd/codebase/codebase-map.md` | `validate-codebase-map` |
| `*.mega-sdd/codebase/starterkit-context.yaml` | `validate-starterkit-conformance` |
| `*.mega-sdd/knowledge-base/**/*.md` | + `validate-kb-citations` (new — adds to existing `kb-output`/`kb-markers`/`kb-flows` trio) |
| `*-bound/binding*.md` | `validate-constitution-propagation` + `validate-vault-binding-coverage` (mirror of unit-write trigger at producer side) |
| `*-bound/units/U-*.md` | + `validate-starterkit-conformance` (added to existing `handoff-binding-units` + `constitution-propagation` pair) |

**Logic-proven via direct-invoke** against `tests/fixtures/sample-project/` (version-skew-immune — invokes canonical script, not the install snapshot). 4 paths → 5 distinct validators fire with state files written / FAIL detection working.

### Fix 3 — SessionStart debug-log diagnostic

**Was:** TF Import run produced zero SessionStart guard telemetry. No way to distinguish (a) hook not invoked by harness from (b) hook invoked but every guard silent-passed.

**Now:** `hooks/session-start` prepends a debug-log block (mirror of Stop-hook 67.5 pattern) that runs BEFORE all logic. Captures stdin SessionStart JSON, extracts `session_id`, writes one line per invocation to `<cwd>/.mega-sdd/memory/hook-debug.log`:

```json
{"ts":"<ISO8601>","hook":"session-start","session_id":"<id>","cwd":"<path>","stdin_bytes":<n>}
```

- Only writes when `.mega-sdd/` exists in CWD (no pollution of unrelated sessions).
- Honors `telemetry: false` opt-out via `<cwd>/.mega-sdd/config.yaml`.

After future fresh sessions: presence of `"hook":"stop"` entries WITHOUT `"hook":"session-start"` entries in `hook-debug.log` = harness wires Stop but not SessionStart (install/registration issue), not a hook-logic bug. Without this diagnostic, the audit gap was undiagnosable.

**Logic-proven** via direct-invoke at `tests/fixtures/sample-project/` — log file empty → invoke with stdin → exactly one `session-start` line gained with captured fields.

### Files changed

- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — schema bump, emit template, Step 10.5.2.5
- `plugins/mega-sdd/references/starterkit-context-schema.md` — v3.0 generic schema + multi-framework examples
- `plugins/mega-sdd/scripts/validate-starterkit-conformance.sh` — v3.0 generic field-name support + v2.x legacy aliases
- `plugins/mega-sdd/hooks/post-tool-use` — path-scoped dispatch (codebase-map, starterkit-context.yaml, kb-citations, binding-write, unit-write conformance)
- `plugins/mega-sdd/hooks/session-start` — diagnostic debug-log layer
- `tests/fixtures/sample-project/.mega-sdd/codebase/starterkit-context.yaml` — migrated to v3.0 generic
- `tests/fixtures/scan-frameworks/{laravel,django,express}-fixture.yaml` — NEW multi-framework dummies

### Soak status

Iter 68 ships during shakedown window — production-confirm validation deferred to next TF Import fresh session (Step 3 of original task). Stop-hook freeze window (Iter 67.5) preserved; no hook semantics changes were made to Stop. SessionStart and PostToolUse paths-scoped dispatch are net-additive; existing skill-name dispatch retained for backward compat.

---

## [3.59.0] - 2026-05-27

### Iter 67.14 — Cleanup + C2 recommendation pattern-prove (diff_conflict)

**User directive:** "clear unnecessary files in GDS + continue implement all; then I'll start fresh session for e2e test."

### Cleanup

- **Removed** `.mega-sdd/` test artifact at GDS root (left over from production-verify diagnostic test in conversation — GDS is plugin SOURCE repo, not a mega-sdd project; the `.mega-sdd/memory/{telemetry.jsonl,hook-debug.log}` were test fixtures)
- **Removed** all `.DS_Store` files (5 found; already gitignored, just disk cleanup)
- **Left alone** `Mega-SDD-Testing-Report.pptx` (user's own untracked file)
- **Left alone** `plugins/mega-sdd/skills/_vendored/ATTRIBUTION.md` working-tree change (user's intentional vendored-date update; uncommitted across many turns by user's choice)

### C2 recommendation field — pattern-prove (1 of 27)

Per `docs/superpowers/audits/2026-05-27-c2-propose-and-confirm-audit.md` (v3.58.0), all 27 C2 halts were cataloged with proposed `recommendation:` field shapes. Per-skill implementation was deferred to follow-up iters. **This release pattern-proves the implementation pattern with the cleanest emit-site: `diff_conflict` in `diff-vault/SKILL.md`.**

**Change:** `diff_conflict` halt envelope schema in `diff-vault/SKILL.md` Section "`diff_conflict` blocker emission" now includes:

```yaml
recommendation:
  proposed_action: "supersede"
  rationale: "PRD revision is the newer source-of-truth; vault should follow unless the change is destructive..."
  confidence: "medium"
  alternatives: ["supersede", "keep_vault", "capture_both"]
user_response_required: true
```

**Why diff_conflict for pattern-prove:**
- Single emit-site in single skill body
- Existing schema already has `options:` enum — adding `recommendation:` is additive
- Conflict resolution has clear default (supersede with newer PRD value)
- Low risk; obvious correctness

**Skill version:** diff-vault `1.3.2 → 1.3.3` (PATCH per skill — schema addition, backward-compatible: legacy consumers without `recommendation:` parser still see `options:` array).

### Remaining per-skill C2 implementations (26 halts across ~10 skills)

Deferred to per-skill follow-up iters. Each is mechanical edit per the audit doc's recommendation shape table. Suggested batching:
- generate-intent (3 halts): oq_business_p1_unresolved, prd_no_scopes_block_user_rejected_retrofit, prd_retrofit_low_confidence
- detect-drift (2 halts): drift_framework_mismatch, constitution_drift_detected
- bind-codebase (1 halt): bind_conflict_constitution_violation
- generate-units (6 halts): dedup_ambiguous, cycle_detected, cross_squad_*, interface_ref_missing, unit_underspecified, hard_rule_unparseable
- execute-bolts (5 halts): bolt_introduces_locked_drift, bolt_repeated_partial_failure, hard_rule_violated, pbt_property_violated, module_blocked_by
- memory (1 halt): memory_schema_mismatch
- install-deps (2 halts): install_failed, pkg_mgr_not_found
- orchestrate-flow (2 halts): predictive_check_failed, no_starterkit_detected
- extract-intelligence (1 halt): wave_quality_threshold_unmet
- diff-vault (already done)
- Plus 3 cross-squad/coordination halts

Estimated ~30 hours total work across all skills; can be batched per-skill in future iters.

### Ready-for-e2e state

After this ship, user runs:
1. `/plugin marketplace update grand-design-spec` (rebuilds cache to v3.59.0; marketplace clone already at v3.59.0)
2. Restart Claude Code

Then fresh session in any mega-sdd project exercises:
- 11 SessionStart-guard surfaces (Phase A + B.7-B.11 + edge-case 2,3,7)
- 13 PostToolUse Write|Edit validators in cascade (slice 1 + B.2-B.5 + B.4-fu + slice 4+5)
- PostToolUse Bash (pandoc), PostToolUse Skill (starterkit_metrics + skill_invoked), PostToolUse Agent (subagent failure)
- Stop hook (turn_end_marker + handoff validation)
- PreToolUse Skill (state-gate block + transcript-arg-extract block)
- C2 `diff_conflict` halt: now emits with `recommendation:` field when triggered (1 of 27 done)

### Classifier dogfood (advisory)

- files_changed: 6 (cleanup of 2 untracked dirs + 1 skill body edit + plugin.json + 2 READMEs + CHANGELOG)
- Skill body modified (diff-vault/SKILL.md): C2 recommendation pattern-prove. Risk acknowledged; small additive schema change.
- No new hook surface, no new validator, no new skill dir
- → **MINOR** ✓ (skill body change qualifies per classifier rule, though the change is additive YAML schema only)

**Plugin v3.58.0 → v3.59.0** (MINOR — cleanup + C2 pattern-prove for diff_conflict; remaining 26 C2 implementations queued for future iters per audit doc).

### Session summary (autonomous run 2026-05-27)

13 versions shipped in one autonomous run (v3.47.0 → v3.59.0):
- Hook-enforcement campaign: 26 of 28 C1 halts hook-enforced; 5/5 C3 grounding-gate slices; 4/4 originally-flagged edge-case items reframed
- 2 truly Fork-B-future remaining (dispatch_prompt_too_large + implicit re-plan detection)
- All C2 halts cataloged; 1 of 27 implemented (pattern-prove)
- Multiple new hook surfaces: PostToolUse Bash/Skill/Agent/Write|Edit, PreToolUse Skill (state-gate + arg-extract), Stop hook with transcript-usage extraction
- Original audit pattern "4× prose-vs-execution failure" — bounded to 2 genuinely runtime-control items
- Production-verification: pending user plugin update + Claude Code restart

## [3.58.0] - 2026-05-27

### Iter 67.13 — C3 grounding-gate slice expansion (slices 2-5) + C2 propose-and-confirm audit

**User directive "continue all":** ship A + B + C autonomously. A (production-verify) is user-action-only (skipped, honest). B and C executed.

### Phase C: grounding-gate slice expansion (slices 2-5)

Iter 67.6 slice 1 covered binding→units OQ-IDs. Slices 2-5 (CONFLICT-IDs, Hard Rules, vault→binding, units→bolts) ship in this iter.

**Slice 2: CONFLICT-IDs (extension of slice 1 validator)**
- `validate-handoff-binding-units.sh` extended: new `CONFLICT_RE` regex (canonical `CONFLICT-NNN` form only; `C-NNN` short-form rejected for ambiguity)
- Detects: CONFLICT-IDs declared in binding doc but not cited in any unit's frontmatter `binding_refs:`
- Same drop-detection pattern as OQ-IDs; same state file (`.validation-blockers.json`)
- Summary now includes both `oq_ids_*` and `conflict_ids_*` counts
- Sandbox: binding with CONFLICT-1 + CONFLICT-2 + units citing only CONFLICT-1 → drop detected for CONFLICT-2

**Slice 3: Hard Rule citation trace (extension of B.3 validator)**
- `validate-unit-spec.sh` extended with `hard_rule_trace_missing` advisory check
- For each Hard Rule line in `## Hard rules` section, look within 5 lines for ANY trace annotation: `Citation:`, `Source:`, `Ref:` OR inline reference to `binding.md` / `knowledge-base` / `starterkit-context` / `constitution.md` / `D-NNN` / `C-NNN` / `CONFLICT-`
- Severity: advisory (NOT a hard halt — rules without trace get flagged for review, not blocked)
- Complements existing `starterkit_rule_citation_missing` (stricter check for starterkit-derived rules)

**Slices 4+5 combined: NEW `validate-vault-binding-coverage.sh`**
- Slice 4 — `vault_binding_coverage_gap`: walks each vault's docs (`0[1-6]-*.md`), extracts section IDs (`## §<id>` headers + `F-<prefix>-NN` flow IDs), checks each appears in corresponding binding doc. Orphaned sections (declared in vault but not tracked in binding) flagged as advisory.
- Slice 5 — `units_bolts_partial_execution`: for each bound vault, if `bolts/` directory exists, checks every unit has `bolts/U-XXX/bolt-report.md`. Pre-execution state (no `bolts/` dir at all) → graceful skip (correct state, not an error).
- Both detection-only (no auto-fix); advisory severity
- Wired to PostToolUse Write|Edit cascade as Validator 6
- Sandbox 3/3 PASS: orphan section detected, partial bolt execution detected, pre-execution state correctly skipped

### Phase B: C2 propose-and-confirm audit doc

**NEW: `docs/superpowers/audits/2026-05-27-c2-propose-and-confirm-audit.md`** — catalogs all 27 C2 halts with proposed `recommendation:` field shape per halt:

- Domain/stakeholder intent (8 halts): oq_business_p1_unresolved, diff_conflict, drift_framework_mismatch, bind_conflict_constitution_violation, constitution_drift_detected, bolt_introduces_locked_drift, memory_schema_mismatch, prd_no_scopes_block_user_rejected_retrofit
- Spec/data integrity (6 halts): prd_path_missing, prd_retrofit_low_confidence, wave_quality_threshold_unmet, dedup_ambiguous, hard_rule_violated, unit_underspecified (C2 path per attestation #12)
- Execution flow (5 halts): bolt_repeated_partial_failure, module_blocked_by, hard_rule_unparseable (DROP path), cycle_detected, predictive_check_failed
- Cross-squad/coordination (4 halts): cross_squad_dep_invalid, cross_squad_ambiguous, cross_squad_interface_draft, cross_module_dep_invalid, interface_ref_missing
- Environment/install (3 halts): install_failed, pkg_mgr_not_found, no_starterkit_detected

**This is DOC ONLY** — no code changes. Per-skill body implementation deferred to follow-up iters; the doc is the canonical convention reference for when each C2 halt's emit-site is touched.

### Cumulative coverage

**26 of 28 C1 halts now hook-enforced** (was 26 in v3.57.0; no change — C3 slices are different track).

**C3 grounding-gate slices: 5/5 IMPLEMENTED** (slice 1 v3.49.0, slices 2-5 v3.58.0).

**C2 halts: 27/27 cataloged with proposed `recommendation:` shape** (implementation deferred).

### Hook coverage (final landscape)

| Surface | Halts | New in v3.58.0 |
|---|---|---|
| SessionStart-guard | 11 | — |
| PostToolUse Write\|Edit | **13** | +2 (CONFLICT-ID, hard_rule_trace_missing advisory) |
| PostToolUse Bash | 1 | — |
| PostToolUse Skill | 1 | — |
| PostToolUse Agent | 1 | — |
| Stop (transcript) | 4 | — |
| PreToolUse Skill (gate) | gating | — |
| PreToolUse Skill (arg-extract) | 1 | — |

### Production-verification gate (A) — UNCHANGED

User needs `/plugin marketplace update grand-design-spec` + Claude Code restart to activate v3.55.0-v3.58.0 hooks. Marketplace clone is at v3.58.0 (pulled earlier).

### Classifier dogfood (advisory)

- files_changed: 6 (extended 2 existing validators + 1 new validator + extended post-tool-use + NEW C2 audit doc + plugin.json + 2 READMEs + CHANGELOG = ~9)
- 3 new check types (CONFLICT-ID drop, hard_rule_trace_missing, vault-binding-coverage + units-bolts traceability)
- 1 new validator script
- NEW audit doc (doc-only, no code)
- No skill body modified
- → **MINOR** ✓

**Plugin v3.57.0 → v3.58.0** (MINOR — C3 slices 2-5 complete; C2 audit doc catalogs 27 halt recommendation shapes; +1 new validator + 2 extensions to existing validators).

### What 67.13 does NOT do

- Does NOT implement C2 `recommendation:` field in per-skill body emits (audit doc only; per-skill follow-up)
- Does NOT add NEW hook surface (existing PostToolUse Write|Edit + extensions)
- Does NOT touch the 2 truly Fork-B halts (dispatch_prompt_too_large + implicit re-plan detection)

### Honest landscape note

After v3.58.0:
- 26 of 28 originally-classified C1 halts: hook-enforced
- 5 of 5 C3 grounding-gate slices: implemented (binding→units OQ, CONFLICT-IDs, Hard Rule trace, vault→binding coverage, units→bolts traceability)
- 27 of 27 C2 halts: cataloged with proposed recommendation shapes (implementation = per-skill body work, ongoing)
- 2 remaining genuinely Fork-B: dispatch_prompt_too_large + implicit re-plan detection
- 4 originally-flagged edge-case items: all have hook-layer reframes (Phase A 5+6 + Phase B [neither] 6+15)

The hook-enforcement campaign for the original audit pattern is substantially complete. Remaining work is: (a) production-verification of cumulative ships, (b) per-skill body C2 implementation, (c) optional starterkit_metrics + handoff_missing chain-state edge cases.

## [3.57.0] - 2026-05-27

### Iter 67.12 — Edge-case track + B.5-fu remainder (4 reframes + 1 honest defer)

**User directive 2026-05-27:** focus only on GDS project, no TF Import touches. Sandbox tests via `/tmp` OK. Continue autonomous edge-case track.

**Reframe approach:** edge-case track was originally classified [neither] / Fork-B because halts fire mid-skill-body. Per reviewer earlier discipline, find adjacent surfaces that catch the same conditions deterministically — even if not the original emit-site. 4 of 5 items get reframed reframes that work; 1 stays Fork-B-future honestly.

### What ships

**Edge-case 1: `starterkit_metrics_inconsistent` (B.5-fu remainder):**
- NEW `scripts/validate-starterkit-metrics.sh` — PostToolUse Skill cross-check after `mega-sdd:generate-units` completes
- Reads transcript_path for handoff containing `units_with_starterkit_rules` field
- Cross-checks against `<cwd>/.mega-sdd/codebase/starterkit-context.yaml` `partial:` flag
- Detects: `units_with_starterkit_rules > 0 AND partial: true` → emit warning with suggested `/mega-sdd:scan-codebase --force-deep`
- Wired to post-tool-use Skill branch (mega-sdd:generate-units matcher)
- Sandbox 2/2 PASS (FAIL when inconsistent, PASS when consistent)

**Edge-case 2: `model_tier_unknown` reframe (Phase A flagged slice 5):**
- Original emit-site: orchestrate-flow Step 2.8.f (mid-chain, no hook surface) — kept as Fork-B-future for the precise emit
- Reframe: SessionStart config pre-validation
- session-start hook scans `<cwd>/.mega-sdd/config.yaml` + `~/.mega-sdd/memory/preferences.md` for `model_tiers:` overrides
- Cross-checks role names against canonical catalog at `<plugin>/references/model-tiers.md`
- Emits warning + chat notice for unknown roles; downstream chain still uses catalog default (graceful)
- Sandbox 1/1 PASS (unknown role detected, valid role unaffected)

**Edge-case 3: `memory_in_use` reframe (Phase A flagged slice 6):**
- Original emit-site: memory subsystem file-lock retry (prose-driven) — kept as Fork-B-future for runtime retry
- Reframe: SessionStart pre-emptive stale-lock cleanup
- session-start hook scans `<cwd>/.mega-sdd/memory/*.lock` (also `.lck`, `.lock-*`) for files older than 60 seconds
- Removes stale locks + emits telemetry. Reduces frequency of runtime lock collisions.
- Doesn't replace runtime retry (skill body retains best-effort retry); supplements it.
- Sandbox 1/1 PASS (stale 90-sec-old lock removed, fresh lock untouched)

**Edge-case 4: `deep_scan_subagent_failed` (Phase B [neither] 6):**
- Original emit-site: scan-codebase subagent retry inside skill body — kept as Fork-B-future for auto-retry
- Reframe: PostToolUse Agent matcher telemetry (detection-only)
- hooks.json adds `Agent` to PostToolUse matcher set: `Read|Skill|Bash|Write|Edit|Agent`
- post-tool-use Agent branch: when subagent_type contains `scan|starterkit|deep` AND tool_response has failure markers (is_error, error field, or multiple failure keywords), emit warning telemetry
- Hook can't auto-retry (no tool access from hooks); skill body retains retry responsibility
- Sandbox 3/3 PASS (failure detected, success not flagged, non-mega-sdd subagent excluded)

### Edge-case 5: `dispatch_prompt_too_large` — HONEST FORK-B DEFER

**No hook surface exists.** Bolt prompt assembly happens entirely inside execute-bolts skill body in working memory before ANY tool dispatch. The 10KB cap check operates on the assembled prompt string — no file is written, no tool is invoked at the check point. No PostToolUse / PreToolUse / Stop / SessionStart surface fires before the prompt is built.

Possible Fork-B paths (not in this release):
- Extract bolt prompt builder to a script that execute-bolts invokes via Bash → PostToolUse Bash could observe + validate. Still prose-dependent for the invocation.
- Custom runtime that intercepts mid-reasoning at prompt-build moment.

Stays Fork-B-future. Documented in `plugins/mega-sdd/references/fork-a-recovery-map.md` (already classified [FORK-B-ONLY] under "Mid-turn intervention").

### Coverage scorecard

**26 of 28 C1 halts now hook-enforced** (was 25, +1 via edge-case 1).
**4 of 4 originally-flagged edge-case items** now have hook-layer reframes (model_tier_unknown, memory_in_use, deep_scan_subagent_failed, starterkit_metrics_inconsistent).
**2 remaining genuine Fork-B-only:** dispatch_prompt_too_large + implicit re-plan detection (per Iter 67.5 audit). The 4 truly-parked items reduce to **2**.

### Bug found + fixed during testing

SessionStart hook's main guard block was gated on `<cwd>/.mega-sdd/vaults/` existence (original gate for Phase A guards). The new edge-case guards check `<cwd>/.mega-sdd/memory/` or `<cwd>/.mega-sdd/config.yaml` (don't need vaults). Relaxed gate to `<cwd>/.mega-sdd/` existence so all guards run consistently.

Also fixed: `exit` without parens in Agent matcher python block (was a no-op reference; both FAIL and OK printed, breaking bash status check). Switched to single-final-print pattern.

### Hook coverage (final landscape)

| Surface | Halts | New in 3.57.0 |
|---|---|---|
| SessionStart-guard | **11** | +2 (model_tier_unknown, memory_in_use) |
| PostToolUse Write\|Edit | 11 | — |
| PostToolUse Bash | 1 | — |
| PostToolUse Skill (cross-skill) | **1** | +1 (starterkit_metrics_inconsistent) |
| PostToolUse Agent | **1** | +1 (deep_scan_subagent_failed) |
| Stop (transcript) | 4 | — |
| PreToolUse Skill (state-gate) | gating layer | — |
| PreToolUse Skill (transcript+arg-extract) | 1 | — |

### Classifier dogfood (advisory)

- files_changed: 8 (1 new validator + extended session-start + extended post-tool-use + extended hooks.json + plugin.json + 2 READMEs + CHANGELOG)
- Multiple new hook branches (PostToolUse Agent matcher, PostToolUse Skill cross-check, 2 new SessionStart guards)
- Bug fixes: SessionStart gate + Agent matcher python
- No new skill dir, no new halt enum, no skill body modified
- → **MINOR** ✓

**Plugin v3.56.0 → v3.57.0** (MINOR — edge-case track 4/5 reframes + B.5-fu remainder; cumulative 26 of 28 C1 halts now hook-enforced; only 2 truly Fork-B-future remaining: dispatch_prompt_too_large + implicit re-plan detection).

## [3.56.0] - 2026-05-27

### Iter 67.11 — Phase B follow-ups + SessionStart-guard track (B.4-fu / B.5-fu / B.7-B.11)

**Three-track autonomous push:** B.4 follow-up (3 OQ-schema halts), B.5 follow-up (pandoc failure detection), and B.7-B.11 SessionStart-guard track (framework_pack triplet + dep_missing + deep_scan_cache_corrupt). Plus per-OQ scoping bug fix from B.4 found during testing.

### What ships

**B.4 follow-up — vault OQ schema (3 halts):**
- `validate-vault-oqs.sh` extended with per-OQ-block scoping (was 30-line proximity window — caused false-positive cross-attribution between OQs).
- New halt detection:
  - `oq_tech_missing_mode`: tech-categorized OQ (`[tech]` or `category: tech`) without `mode:` field
  - `oq_scan_missing_query`: `mode: scan` OQ without `scan_target:` field
  - `oq_recommend_underspecified`: `mode: recommend` OQ missing required fields (recommendation, rationale, citation|citations)
- Per-OQ blocks: text from each OQ-ID line up to the NEXT OQ-ID line (or 30 lines max), so adjacent OQs don't cross-contaminate.

**Sandbox proof:**
- OQ-AR-1 (tech, no mode) → oq_tech_missing_mode ✓
- OQ-AR-2 (scan, no scan_target) → oq_scan_missing_query ✓
- OQ-AR-3 (recommend, missing fields) → oq_recommend_underspecified ✓ (missing_fields: [recommendation, rationale, citation|citations])
- OQ-AR-4 (scan WITH scan_target) → no trigger ✓ (correct exclusion)

**B.5 follow-up — pandoc render failure (1 halt):**
- NEW `scripts/validate-pandoc-render.sh` — detects `quality_gate_failed:pdf_render_failed` from PostToolUse Bash matcher.
- Triggers when Bash command contains "pandoc" AND `tool_response.exit_code != 0`.
- Suggests `/mega-sdd:install-deps --tools=tectonic` as next_action.
- Wired into `hooks/post-tool-use` Bash branch (after existing ref_loaded path detection).
- DEFERRED: `quality_gate_failed:starterkit_metrics_inconsistent` (needs Skill matcher cross-skill check; complex; follow-up).

**Sandbox proof:**
- pandoc exit=2 → FAIL with halt_type=pdf_render_failed ✓
- pandoc exit=0 → PASS ✓
- non-pandoc command → skip (no state change) ✓

**B.7-B.11 — SessionStart-guard track (5 halts, all in extended session-start hook):**
- `framework_pack_unparseable`: pack file fails UTF-8 read → emit telemetry + skip pack
- `framework_pack_cycle`: pack inheritance has cycle (DFS detection) → log + suggest break at most-derived edge
- `framework_pack_missing`: pack `extends:` references nonexistent pack → drop reference
- `deep_scan_cache_corrupt`: `starterkit-context.yaml` not valid YAML (no top-level keys) → rename `.corrupt-<ts>`; next scan-codebase rebuilds
- `dep_missing` (B.11 — non-interactive only): check PATH for `tree-sitter`, `ast-grep`; if missing, emit warning telemetry with degradation path (regex tier / v1 grammar). Per reviewer R2: NEVER auto-install at SessionStart (would risk hanging on sudo/network).

**Sandbox proof:**
- 4 packs with cycle + missing reference → 3 framework_pack_cycle events (over-reports cosmetically; same cycle detected from multiple starting nodes — known minor; cycle IS detected correctly) + 1 framework_pack_missing event
- Corrupt starterkit-context.yaml (plain text, no YAML keys) → renamed to `.corrupt-<ts>` + telemetry
- Missing tree-sitter on PATH → dep_missing advisory event (no install attempted)

### Cumulative coverage

| Status | Count of 28 C1 | New since v3.55.0 |
|---|---|---|
| Hook-enforced | **25** | +7 (3 OQ-schema + 1 pandoc + 3 framework_pack types — note: framework_pack 3 halts each tracked separately even though one validator) |
| Remaining | 3 | starterkit_metrics_inconsistent (B.5-fu deferred) + 2 truly-unhooked + 4 edge-case track items |

Effectively: **25 of 28 C1 halts hook-enforced** (or 22/25 if we count the 4 edge-case track items as Fork-B-future, which they are).

### Hook coverage by surface

| Surface | Halts covered | Slice |
|---|---|---|
| SessionStart-guard | 9 (mode_migrate, partial_state_corrupt, routing_outcome_corrupt, verify_unit_writable + framework_pack_unparseable/cycle/missing + dep_missing + deep_scan_cache_corrupt) | Phase A 1-4 + B.7-B.11 |
| PostToolUse Write|Edit | 11 (binding→units OQ-IDs + bolt artifacts 3 + unit spec 3 + vault OQ 4 + FSD slot 1) | 67.6 slice 1 + B.2-B.4-fu |
| PostToolUse Bash | 1 (pdf_render_failed) | B.5-fu |
| Stop (transcript) | 4 (handoff suite) | B.1 |
| PreToolUse Skill (state-file-gate) | block paths for above | B.1 + 67.6 slice 1 |
| PreToolUse Skill (transcript+arg-extract) | 1 (scope_not_declared_in_prd) | B.6 pattern-prove |

### Per-OQ scoping bug fixed

During B.4-followup sandbox test, found that the existing `oq_recommend_citation_invalid` validator's 30-line window approach false-attributed adjacent OQs' metadata (e.g., OQ-AR-1's window caught OQ-AR-2's `mode: scan` line). Fixed by switching to per-OQ blocks: text from each OQ-ID line up to (but excluding) the next OQ-ID line, capped at 30 lines. No regressions to existing `oq_recommend_citation_invalid` behavior verified in re-test.

### Cumulative ship sequence (Phase B PostToolUse + B.6 + B.7-B.11 tracks)

| Iter | Version | Slices |
|---|---|---|
| 67.8 | v3.53.0 | B.1 Handoff suite (4 halts) |
| 67.9 | v3.54.0 | B.2 Bolt + B.3 Unit + B.4 vault-OQ-1 + B.5 FSD-slot (8 halts) |
| 67.10 | v3.55.0 | B.6 PATTERN-PROVE (1 halt, PreToolUse-Skill-tool_input surface viable) |
| **67.11** | **v3.56.0** | **B.4-followup (3) + B.5-followup-pandoc (1) + B.7-B.11 (5) = 9 halts + per-OQ-scoping bug fix** |

### What 67.11 does NOT do

- Does NOT cover `starterkit_metrics_inconsistent` (B.5 follow-up remainder — needs cross-skill check; deferred)
- Does NOT touch edge-case track (Phase A flagged 5+6 + Phase B [neither] 6+15 → 4 prose-driven halts; needs script extraction iter)
- Does NOT auto-install missing dependencies (per reviewer R2: non-interactive only at SessionStart; explicit `/mega-sdd:install-deps` invocation still required)

### Honest scope notes

- Framework pack cycle detection over-reports (same cycle detected from N starting nodes = N events). The cycle IS correct; just deduped poorly. Cosmetic only — state file shows N entries but they describe the same cycle. Fix in follow-up.
- B.7-B.11 detection-only at SessionStart layer; doesn't auto-fix corrupt packs (just renames cache_corrupt files). User/scan-codebase rebuilds.

### Classifier dogfood (advisory)

- files_changed: 7 (extended validate-vault-oqs + new validate-pandoc-render + extended session-start + extended post-tool-use + plugin.json + 2 READMEs + CHANGELOG)
- 1 new validator + 5 new SessionStart guards + extended OQ schema detection
- No new skill dir, no new halt enum, no skill body modified
- → **MINOR** ✓

**Plugin v3.55.0 → v3.56.0** (MINOR — Phase B follow-up + SessionStart-guard track + per-OQ scoping bug fix; +9 C1 halts hook-enforced; cumulative 25 of 28 C1 halts now hook-layer-detected).

## [3.55.0] - 2026-05-27

### Iter 67.10 — Phase B slice B.6 PATTERN-PROVE [PreToolUse-Skill-tool_input surface]

**Pattern-prove success.** Per reviewer 2026-05-27 refinement R1: slice B.6 isolated `scope_not_declared_in_prd` as a pattern-prove for the NEW PreToolUse-Skill-tool_input surface (don't assume covers other halts; verify in real run first). This release proves the surface IS viable for the class of halts that need to extract user-args from tool_input.

### Key architectural finding

PreToolUse `tool_input` for Skill tool is JUST `{skill: "..."}` — args/flags (e.g., `--scope=X`) are NOT included. **But:** PreToolUse stdin also includes `transcript_path` (verified, same as Stop hook). So pattern-prove pivots: hook reads transcript, finds most recent user message, extracts flag via regex. Validator checks against PRD frontmatter scopes.

This unblocks similar future slices that need user-context-aware blocking (e.g., flag validation for other mega-sdd commands).

### What ships

**NEW: `plugins/mega-sdd/scripts/validate-scope-flag.sh`** — deterministic validator:
- Inputs: --cwd + user message via stdin (or --user-message-file)
- Extracts `--scope=X` flag from user message (supports `--scope=X` and `--scope X`)
- Discovers PRD in CWD: `prd.md`, `seed-PRD.md`, `*PRD*.md`, `.mega-sdd/{seed-,}prd.md`
- Parses PRD YAML frontmatter `scopes:` block (3 shapes: inline list, block scalar list, block dict list with `id:`)
- Validates flag against declared scopes
- Special cases: `--scope=all` always valid (legacy fallback); no flag = no-op; no PRD = graceful skip; PRD without scopes block = legacy single-scope (pass)
- Writes `.mega-sdd/.scope-flag-state.json`; exit 0=PASS, 1=FAIL

**UPDATED: `plugins/mega-sdd/hooks/pre-tool-use`** — adds Branch 1c (scope flag gate):
- Matcher additions: `mega-sdd:auto`, `mega-sdd:generate-intent`, `mega-sdd:orchestrate-flow`
- Stdin parse: adds `TRANSCRIPT_PATH` extraction
- For matched skills, reads transcript_path, finds last user message, pipes to validator
- On FAIL: emits `{continue: false, stopReason: "..."}` with detailed message including declared scope list
- Branch 1a (handoff validation gate) and Branch 1b (binding→units execute-bolts gate) unchanged; runs after

### Sandbox proof — 8/8 PASS

Validator-direct (5/5):
1. `--scope=BE` (valid) → PASS
2. `--scope=ZZZ` (invalid) → FAIL with declared scope list
3. No flag → no-op PASS
4. `--scope=all` legacy → PASS
5. No PRD in CWD → graceful PASS (skip, don't block)

End-to-end via PreToolUse hook (3/3):
6. PreToolUse Skill `mega-sdd:auto` with invalid scope in transcript → BLOCK with `continue: false` + detailed reason listing valid scopes
7. PreToolUse Skill `mega-sdd:auto` with valid scope → allowed (no block output)
8. PreToolUse Skill `mega-sdd:scan-codebase` (non-scope-flag skill) → allowed (matcher correctly scopes)

### Scope assessment for this surface

PreToolUse-Skill-tool_input pattern is now PROVEN VIABLE for the class of halts that need user-args context. Future slices candidates that could leverage this:
- Other flag-validation halts (e.g., `--out=<path>` validation, `--manual` vs `--auto` consistency)
- Mid-chain skill arg conflicts (e.g., `--greenfield` with `--scan` together)
- Memory-context-aware gating (if memory state changes flag interpretation)

**Pattern-prove gate cleared** — B.6 surface unlocks future use; not just for this one halt.

### Cumulative coverage

**18 of 28 C1 halts** now hook-layer-enforced (was 17 after v3.54.0; +1 via B.6).

| Remaining | Halts | Track |
|---|---|---|
| B.4 follow-up | 3 OQ-schema halts | follow-up slice |
| B.5 follow-up | 2 mixed-surface halts (pandoc Bash + Skill metrics) | follow-up |
| B.7-B.11 | 5 SessionStart-guard track (framework_pack + dep_missing) | low-value replication |
| Edge-case track | 4 prose-driven halts | separate iter (script extraction) |

### Classifier dogfood (advisory)

- files_changed: 5 (1 new script + pre-tool-use extension + plugin.json + 2 READMEs + CHANGELOG)
- New hook surface PROVEN (new functionality)
- No new skill dir, no new halt enum, no skill body modified
- → **MINOR** ✓

**Plugin v3.54.0 → v3.55.0** (MINOR — Phase B slice B.6 pattern-prove success; PreToolUse-Skill-tool_input surface viable; +1 halt hook-enforced; pattern unlocked for future user-args-aware slices).

## [3.54.0] - 2026-05-27

### Iter 67.9 — Phase B slices B.2 + B.3 + B.4 + B.5 (PostToolUse-validate batch checkpoint)

**Gate-clear gate confirmed first.** v3.53.0 production-confirmation gate FULLY CLEAR (5/5 criteria) per real Claude Code session in TF Import: Stop hook + turn_end_marker emitted with real harness usage `{input_tokens:1, cache_creation:5795, cache_read:127538, output_tokens:1710}` — the 150k/unit token mystery now diagnosable. PostToolUse Bash/Skill, PreToolUse Skill block + recovery, SessionStart C1 guards: all production-verified. Phase B continuation unlocked.

### What ships

Phase B [PostToolUse-validate] track autonomous run from B.2 to B.5 checkpoint. Each slice = validator script + PostToolUse Write|Edit hook wiring + sandbox proof.

**Slice B.2 — Bolt artifacts (3 halts, all sandbox-proven):**
- NEW `scripts/validate-bolt-artifacts.sh` — single validator covering 3 halts:
  - `provenance_missing`: detect when bolt-modified file (in any unit's target_files) lacks `Generated by mega-sdd execute-bolts` trailer in first 30 lines
  - `self_assessment_missing`: detect when `bolts/U-*/bolt-report.md` lacks `bolt_self_report:` YAML block
  - `pbt_citation_invalid`: detect when unit's PBT `Cites: §Decision-D-NNN` references ADR not in vault's `decisions/` directory
- Sandbox 7/7 scenarios PASS (each halt + control cases)

**Slice B.3 — Unit spec (3 halts, all sandbox-proven):**
- NEW `scripts/validate-unit-spec.sh` — covers:
  - `unit_underspecified`: required frontmatter fields (unit_id/id, title, task_type, target_files, vault_source/vault_anchors) + Anchors section for verify/extend + Migration notes for extend
  - `hard_rule_unparseable`: v1 5-type grammar parse (DO NOT modify, DO NOT add deps, MUST follow naming, function MUST preserve signature, file MUST exist) — falls back to generic MUST/DO NOT for looser rules
  - `starterkit_rule_citation_missing`: when frontmatter `starterkit_context_consumed: true`, any Hard Rule containing "starterkit" must have `Citation: starterkit-context.yaml §<path>` within 5 lines
- Sandbox 7/7 scenarios PASS

**Slice B.4 — Vault OQ citations (1 of 4 halts; honest scope):**
- NEW `scripts/validate-vault-oqs.sh` — covers:
  - `oq_recommend_citation_invalid`: when OQ in vault doc has citation pointing to `knowledge-base/`, verify the path resolves. Graceful skip when KB absent (per risk-flag #2 — NEVER halt on missing KB).
- Deferred to follow-up slices: `oq_tech_missing_mode`, `oq_recommend_underspecified`, `oq_scan_missing_query` (each needs deeper OQ-schema parsing per category; lower value than KB citation integrity). All remain C1 classification; just unbuilt in this slice.
- Sandbox 3/3 scenarios PASS (valid citation, invalid citation, KB-absent graceful skip)

**Slice B.5 — FSD template slots (1 of 3 quality_gate subtypes; honest scope):**
- NEW `scripts/validate-fsd-slots.sh` — covers:
  - `quality_gate_failed:template_slot_unfilled`: when FSD.md (or `*/fsd/*.md`) is written, grep for `{{slot_name}}` mustache-style placeholders. Found → emit warning telemetry.
- Deferred to follow-up slices:
  - `quality_gate_failed:pdf_render_failed`: needs PostToolUse Bash matcher detecting `pandoc` command failure — different mechanism
  - `quality_gate_failed:starterkit_metrics_inconsistent`: needs PostToolUse Skill matcher cross-checking generate-units handoff against starterkit-context.yaml — mid-skill cross-validation
- Sandbox 3/3 PASS

### Hook integration

`hooks/post-tool-use` Write|Edit branch refactored: introduces `run_validator_and_emit()` helper function that:
1. Invokes validator script (silent)
2. Reads state file (single source of truth per slice)
3. On FAIL, emits one `halt_self_resolved` telemetry event per detected issue with rich payload (halt_type, unit_id, detail, halt-specific fields)
4. Skips silently when validator returns PASS or no-op

5 validators chained off single Write|Edit trigger: handoff-binding-units (slice 1), bolt-artifacts (B.2), unit-spec (B.3), vault-oqs (B.4), fsd-slots (B.5). Each writes its own state file; each emits its own telemetry events. State files are overwrite-not-append (current-truth pattern from Iter 67.6).

### Slice scorecard (cumulative)

| Slice | Halts covered | Halts deferred | Status |
|---|---|---|---|
| 67.6 slice 1 | binding→units OQ-IDs | CONFLICT-IDs, Hard Rules, vault→binding, units→bolts | ✅ v3.49.0 |
| Phase A slices 1-4 | mode_migrate, partial_state_corrupt, routing_outcome_corrupt, verify_unit_writable | model_tier_unknown, memory_in_use (flagged) | ✅ v3.51.0-3.52.0 |
| B.1 Handoff suite | 4 halts (handoff_missing partial) | full handoff_missing for chain-aware skill tracking | ✅ v3.53.0 |
| **B.2 Bolt artifacts** | 3 halts | — | ✅ this release |
| **B.3 Unit spec** | 3 halts | acceptance_test substitution (C2 path per attestation #12) | ✅ this release |
| **B.4 Vault OQs** | 1 halt (KB citation) | 3 OQ-schema halts → follow-up | ⚠️ partial |
| **B.5 quality_gate subtypes** | 1 halt (template slot) | 2 mixed-surface halts → follow-up | ⚠️ partial |

**Net coverage shift:** 28 C1 → 17 hook-enforced via PostToolUse-validate or SessionStart-guard; 11 remain (deferred B.4/B.5 follow-ups + Phase B SessionStart track B.7-B.11 + B.6 PreToolUse pattern-prove + edge-case track).

### Production-verification path

After user runs `/plugin marketplace update grand-design-spec` + restarts Claude Code:
1. Edit any unit file in TF Import → 5 validators fire in cascade via PostToolUse Write|Edit
2. State files appear at `<tf-import>/.mega-sdd/.{validation-blockers,bolt-artifacts-state,unit-spec-state,vault-oqs-state,fsd-slots-state}.json`
3. Telemetry events accumulate with `halt_self_resolved` (slice failures) + existing event types
4. No regressions to existing v3.53.0 behavior (handoff validation slice B.1, SessionStart C1 guards, etc.)

### Classifier dogfood (advisory)

- files_changed: 8 (4 new scripts + post-tool-use + plugin.json + 2 READMEs + CHANGELOG)
- 4 new validator scripts (B.2, B.3, B.4, B.5)
- Hook extension with reusable helper
- No new skill dir, no new halt enum, no skill body modified
- → **MINOR** ✓

**Plugin v3.53.0 → v3.54.0** (MINOR — Phase B autonomous run through B.5 checkpoint; 8 new C1 halts now hook-enforced; honest scope deferral for 5 sub-halts that need different mechanisms; cumulative 17 of 28 C1 halts now hook-layer enforced).

### What 67.9 does NOT do

- Does NOT cover B.4's 3 deferred OQ-schema halts (need per-category parsing)
- Does NOT cover B.5's 2 deferred subtype halts (need different hook surfaces)
- Does NOT advance B.6 PreToolUse pattern-prove (`scope_not_declared_in_prd` — new surface)
- Does NOT advance B.7-B.11 SessionStart-guard track (5 framework_pack + dep_missing)
- Does NOT touch edge-case track (Phase A flagged 5+6 + Phase B [neither] 6+15)

### Honesty note

This batch of validators covers ~30% of original C1 candidates as cleanly hook-enforced detection-only checks. Auto-fix (the "self-resolve" half of C1 protocol) still requires producer skill body (generate-units, execute-bolts) to actually re-emit or correct on detection. The hook layer provides the deterministic DETECTION + ESCALATION-PATH; the skill body is the producer-side fix path. Production-verification will show if both halves work together end-to-end.

## [3.53.0] - 2026-05-27

### Iter 67.8 — Phase B slice B.1: Handoff validation suite [PostToolUse-validate, port prose→script]

**Context.** Phase B classification gate accepted with 2 refinements + reorder + 5 risk-flag resolutions. Priority lead = B.1 Handoff suite (4 halts: `invalid_handoff`, `handoff_type_mismatch`, `handoff_missing`, `artifact_missing`). Why first: highest value (integrity carry-over started the whole thread via 27 OQ drop), natural batch, [PostToolUse-validate] pattern already proven in Iter 67.6.

**Architectural pivot during implementation:** initial design assumed `PostToolUse` Skill matcher could read the handoff in `tool_response`. Reality check: PostToolUse Skill fires when the Skill TOOL loads, not after the agent emits handoff in chat. The handoff appears in the agent's regular chat response AFTER skill loads. **Correct surface = Stop hook** (reads transcript at turn end via `transcript_path` stdin field — same pattern as Iter 66a transcript-usage extraction).

### What ships

**NEW: `plugins/mega-sdd/scripts/validate-handoff-yaml.sh`** — deterministic handoff schema validator.
- No-deps YAML-subset parser (PyYAML unavailable; built custom indented-block parser)
- Detects 4 halt classes:
  - `handoff_missing`: no `handoff:` block found in input
  - `invalid_handoff`: required field missing OR parse error (emitted_by, emitted_at, status, next_action)
  - `handoff_type_mismatch`: field types violate schema (status not in enum, artifacts not list, etc.)
  - `artifact_missing`: declared artifacts don't exist on disk
- State file: `<cwd>/.mega-sdd/.handoff-validation-state.json` (overwrite-not-append, current truth)
- Retry counter: increments on same skill+halt repeat within session; escalates to `escalate_to_c2: true` after 2nd attempt
- Per attestation reclassification: 1st failure = C1 self-resolve with `re_run_producer` next_action; 2nd = C2 `user_review`
- Exit: 0=PASS, 1=FAIL, 2=error

**UPDATED: `plugins/mega-sdd/hooks/stop`** — added handoff-validation block (runs BEFORE telemetry gate; state file is independent of telemetry):
- After diagnostic log + opt-out, extracts last assistant message from `transcript_path` (handles content as string OR list of text blocks)
- Greps for `handoff:` marker; skips validator if no marker (avoids false-positive `handoff_missing` for non-mega-sdd turns)
- Inferred producer skill from handoff's `emitted_by` field
- Invokes validator script with extracted text via stdin
- Emits `halt_self_resolved` telemetry event (event_type varies: PASS or 1st-fail = `halt_self_resolved`; 2nd-fail escalation = `halt_fired`)

**UPDATED: `plugins/mega-sdd/hooks/pre-tool-use`** — added Branch 1a (handoff gate):
- Matcher `mega-sdd:*` (excluding `mega-sdd:using-mega-sdd` anchor)
- Reads `.handoff-validation-state.json`
- If `status: FAIL` → blocks with `{continue: false, stopReason: ...}` including: producer skill, halt type, retry count, escalation status, reason, suggested fix
- Falls through to existing Branch 1b (binding→units gate for execute-bolts) when handoff state is PASS or absent

**UPDATED: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`** — 4 handoff halt descriptions updated with "C1 SELF-RESOLVE (v3.53.0+, Iter 67.8 — HOOK-LAYER ENFORCED via Stop+PreToolUse)" block.

### Sandbox proof — ALL 10 STEPS PASS

End-to-end test in isolated `/tmp/b6-final-XXXXXX/` sandbox:

1. ✓ Stop hook with bad handoff (`status: in-progress` invalid enum + missing required fields) → state file created with `status: FAIL`, `halt_type: invalid_handoff`, `retry: 1`, `skill_name: mega-sdd:generate-intent`
2. ✓ Telemetry: `halt_self_resolved` + `turn_end_marker` both emitted with correct payloads
3. ✓ PreToolUse Skill `mega-sdd:scan-codebase` → blocked with detailed reason citing upstream producer + halt type + retry count
4. ✓ Replace transcript with good handoff (all required fields, valid status enum, nested next_action) → state cleared to `status: PASS, retry: 0`
5. ✓ PreToolUse now allows `mega-sdd:scan-codebase` (empty output = no block)
6. ✓ Anchor `mega-sdd:using-mega-sdd` exempt from gate (correctly excluded)
7. ✓ Non-mega-sdd skill (`superpowers:using-superpowers`) NOT gated (matcher scopes correctly)
8. ✓ Bash tool unaffected by handoff state
9. ✓ Retry escalation: 3x bad handoff → retry counter increments (1, 2, 3); `escalate_to_c2` flips True on retry=2; `next_action.type` transitions `re_run_producer` → `user_review`
10. ✓ Turn without `handoff:` marker → validator skipped (no false-positive)

**Sandbox isolated — no TF Import data touched.**

### Bugs found + fixed during dev

1. **PyYAML unavailable** in test env → built no-deps YAML-subset parser (handles inline lists, block lists, nested dicts, scalars). Single-pass indent-aware walker. Sufficient for handoff schema validation.
2. **Python `try:` without `except:`** in Stop hook embedded script → syntax error, silent failure (stderr suppressed). Removed outer try wrapper; inner per-line try-except handles per-record errors.
3. **F-string with backslash in expression** (4th time this bug hit — same pattern from Iter 66a) → assigned to local var first. Logged for memory: f-string expression parts CANNOT contain `\"` escapes; assign to local first.

### Schema semantics

- `halt_self_resolved` event for handoff validation: `payload.halt_type` is the detected halt class (or `handoff_validated_pass` when PASS); `payload.retry_count` + `payload.escalate_to_c2` carry retry state for Iter 68 audit.
- `halt_fired` event emitted on retry escalation (retry_count >= 2 with status=FAIL).

### What 67.8 does NOT do

- Does NOT detect `handoff_missing` for skills that should-but-didn't emit (requires knowing which skill ran + whether it was a chain step expected to emit; deferred to deeper slice — would need either chain-state tracking or per-skill metadata declaring "emits handoff?")
- Does NOT modify any skill body (handoff schema enforced from outside via hook + script)
- Does NOT add a `/mega-sdd:validate-handoff-yaml` slash command (validator is invoked from Stop hook only; manual invocation possible via direct script run; future slice could add command)
- Does NOT cover non-`mega-sdd:` upstream producers (only validates handoffs emitted by mega-sdd skills per `emitted_by` field)

### Classifier dogfood (advisory)

- files_changed: 7 (new script + 2 hook extensions + 2 audit docs + plugin.json + 3 doc refs + CHANGELOG = ~9) → 5-15 = MINOR
- New script + new hook behavior across 2 hooks
- No new skill dir, no new halt enum, no skill body modified
- → **MINOR** ✓

**Plugin v3.52.0 → v3.53.0** (MINOR — Phase B slice B.1; first slice to port handoff validation from prose to deterministic script; closes silent-failure paths for the 4 highest-value mid-chain handoff halts).

### Phase B progress

| Slice | Halts | Pattern | Status |
|---|---|---|---|
| **B.1 Handoff suite** | invalid_handoff, handoff_type_mismatch, handoff_missing*, artifact_missing | [PostToolUse-validate] via Stop+PreToolUse | **✅ shipped v3.53.0** |
| B.2 Bolt artifacts | provenance_missing, self_assessment_missing, pbt_citation_invalid | [PostToolUse-validate] | next slice |
| B.3 Unit validation | unit_underspecified, hard_rule_unparseable, starterkit_rule_citation_missing | [PostToolUse-validate] | follows |
| B.4 Vault OQ validation | oq_tech_missing_mode, oq_recommend_underspecified, oq_scan_missing_query, oq_recommend_citation_invalid | [PostToolUse-validate] | follows |
| B.5 quality_gate subtypes | starterkit_metrics_inconsistent, pdf_render_failed, template_slot_unfilled | [PostToolUse-validate], mixed surfaces | follows |
| B.6 PreToolUse pattern-prove | scope_not_declared_in_prd | NEW SURFACE (PreToolUse Skill tool_input) | pattern-prove slice |
| B.7-B.11 SessionStart-guard | 5 framework_pack + dep_missing | [SessionStart-guard] | low-value replication |

\* `handoff_missing` partially covered — only when handoff text contains `handoff:` marker but missing required fields. True "no handoff at all from skill that should emit" needs chain-state tracking; deferred.

## [3.52.0] - 2026-05-27

### Iter 67.7.3 + 67.7.4 — Phase A slices 3 + 4 + PHASE A CHECKPOINT

**Phase A scorecard at this checkpoint:**

| Slice | Halt | Mechanism | Status |
|---|---|---|---|
| 1 | `mode_migrate` | SessionStart guard | ✅ shipped v3.51.0 (TF Import direct, benign metadata) |
| 2 | `partial_state_corrupt` | SessionStart guard | ✅ shipped v3.51.1 (sandbox, corruption) |
| **3** | `routing_outcome_corrupt` | SessionStart guard | **✅ shipped v3.52.0 (sandbox, corruption)** |
| **4** | `verify_unit_writable` | SessionStart guard (detection-only) | **✅ shipped v3.52.0 (sandbox, both unit layouts)** |
| 5 | `model_tier_unknown` | — | ⚠️ FLAGGED — breaks pattern |
| 6 | `memory_in_use` | — | ⚠️ FLAGGED — breaks pattern |

**Phase A: 4/6 hook-layer enforced + sandbox-proven. 2/6 flagged. Phase B blocked until flagged-pair resolved + reviewer re-audit.**

### What ships (slices 3 + 4)

**Slice 3 — `routing_outcome_corrupt` (Iter 67.7.3):**

`SessionStart` hook Guard 3 (after mode_migrate + partial_state_corrupt). Scans `<cwd>/.mega-sdd/memory/routing-outcomes.md`. Corruption detection:
- File exists, non-empty, but not valid UTF-8 → corrupt
- File exists, non-empty, but missing `Routing Outcomes` schema marker in first 200 chars → corrupt
- Empty file = initialization state (NOT corrupt; skip)

On corruption: rename to `routing-outcomes.md.corrupt-<ISO8601>`; emit `halt_self_resolved` telemetry with `corruption_reason` field (`non-utf8-binary` or `missing_schema_header`); chain proceeds with default routing; memory rebuilds on next end-of-chain write.

**Slice 4 — `verify_unit_writable` (Iter 67.7.4):**

`SessionStart` hook Guard 4. Scans both unit layouts:
- Layout A: `*-bound/units/U-*.md`
- Layout B: `*-bound/units/U-*/unit.md`

For each unit with frontmatter `task_type: verify` AND `target_files` containing operations ∈ {create, modify, delete} → emit `halt_self_resolved` telemetry (`unit_id`, `unit_path`, `forbidden_operations` list) + chat notice. **Detection-only: on-disk unit file is NOT modified** (preserves bad spec for human review). Dispatch-time auto-clear is execute-bolts's responsibility (separate code path; remains in skill body for now per attestation reclassification #12).

**Side fix:** `target_files` block parser rewritten from broken nested-regex to line-based extraction. Original regex captured only the first operation per unit; new parser captures all operations across all entries. Bug surfaced + fixed during slice 4 sandbox proof.

### Slices 5 + 6 — FLAGGED (break pattern)

**Slice 5 — `model_tier_unknown`:** Fires mid-chain in orchestrate-flow Step 2.8.f during model-tier override resolution. **No SessionStart guard surface** — this is a runtime decision during chain execution, not a session-start state check. Existing prose is already SOFT ("log + ignore + continue with catalog default"). Adding telemetry emission to the prose path inherits the same Fork A weakness audited 4× already.

Possible reframe: SessionStart could pre-validate user/project model-tier config files against the catalog. That's a DIFFERENT hook surface (config-validation, not corruption check) and a separate slice scope. Deferred.

**Slice 6 — `memory_in_use`:** File-lock retry logic (current: backoff + retry 3x) is implemented as prose in `memory/SKILL.md`. No script implementation exists. Increasing retry to 10 with exponential backoff requires either:
- Skill body prose change (same Fork A weakness)
- New script `memory-write.sh` that owns lock acquisition + retry, called by skill body via Bash (moves logic out of prose into deterministic code)

The second option is the right architecture but is a substantive refactor — moving memory-write from prose to script. Phase A slice scope is too narrow for that change. Deferred to a "memory subsystem hardening" iter.

**Both flagged slices share the root cause:** they emit from inside skill-body execution, not from precondition checks. The SessionStart-guard pattern (the proven Phase A mechanism) doesn't apply. Different hook surfaces (PostToolUse, PreToolUse) or different mechanisms (script extraction) are needed.

### Combined sandbox proof (all 4 working guards + control)

Single SessionStart invocation against synthetic sandbox with ALL conditions set:
- mode_migrate: vault.json mode=greenfield wrong → fixed to existing
- partial_state_corrupt: malformed JSON → renamed `.corrupt-<ts>`
- routing_outcome_corrupt: markdown w/o schema header → renamed `.corrupt-<ts>`
- verify_unit_writable: U-001 (Layout A, modify+create ops) + U-002 (Layout B, create op) both detected
- Control: U-003 (task_type=create, writable) correctly excluded — no false positive

Result: 5 telemetry events emitted (1 mode + 1 partial + 1 routing + 2 verify), `<self-resolve-log>` block in anchor injection lists all 5, idempotent re-run produces +2 events (verify_unit_writable re-fires for U-001 + U-002 — intentional per detection-only design; others stay silent because they auto-fixed on first run).

**Sandbox cleanup verified — TF Import production data UNTOUCHED per locked safety rule.**

### Schema additions (no existing schema fields changed)

`halt_self_resolved` payload now carries additional keys per halt:
- `routing_outcome_corrupt` adds: `corruption_reason`, `original_path`, `corrupt_path`
- `verify_unit_writable` adds: `unit_id`, `unit_path`, `forbidden_operations`

Both additive (per Iter 67.5 schema policy). Existing fields unchanged.

### Phase A net effect

Of 6 Phase A halts originally classified as "already-soft" C1:
- 4 now have hook-layer enforcement (deterministic, zero prose dependency)
- 2 remain in prose-emit state (flagged; need different mechanism)

Operational interrupt reduction is real: when these 4 conditions occur in real chains, no human prompt fires; structured telemetry + chat notice provide audit trail. The Iter 67.5 "C1 protocol shipped as prose = 4× failure pattern" gap is now closed for these 4 halts.

### Phase B status (the 22 remaining C1 candidates)

**Still blocked** behind:
1. Phase A 4/6 hook-layer slices verified in production (slices 1-4 collectively)
2. Phase A flagged-pair (slices 5+6) resolved or scoped to separate iter
3. Attestation re-audit if any of slices 5+6 reclassification touches the 22 list (model_tier_unknown is on C1 list as #26 in orchestrate-flow group; memory_in_use is #28 in memory group — both potentially affected by their flagged-status)

### Production verification path (user-side, when convenient)

The 4 hook-layer guards now fire automatically on every Claude Code SessionStart for projects with `.mega-sdd/` in CWD. To verify in TF Import:
- Next session: hook fires on startup. If no conditions match → no `<self-resolve-log>` block (silent normal operation).
- To validate: deliberately set a vault.json to mode=greenfield, observe auto-fix on next session.
- Existing TF Import telemetry has 4 test-residue events from slice 1 (`session_id: session-start-hook`) + production events from real Claude Code sessions (real session UUIDs).

### Classifier dogfood (advisory)

- files_changed: 5 (session-start + vault-contract + plugin.json + 2 READMEs + CHANGELOG) → 5-15 = MINOR
- 2 new SessionStart guards added (slice 3 + slice 4)
- 2 slices documented as FLAGGED
- No new file, no new halt enum, no skill body modified
- → **MINOR** ✓

**Plugin v3.51.1 → v3.52.0** (MINOR — Phase A checkpoint: 4/6 slices hook-layer enforced + sandbox-proven; 2/6 flagged as breaks-pattern with documented reframe paths).

## [3.51.1] - 2026-05-27

### Iter 67.7.2 — Phase A slice 2: `partial_state_corrupt` hook-layer enforcement (sandbox-proven)

**Pattern proven viable in Iter 67.7.1 (mode_migrate); this slice replicates the pattern for the next Phase A halt.** SessionStart hook extended with a second C1 guard for `partial_state_corrupt`. Two guards now run in sequence at session start; both emit independent `halt_self_resolved` telemetry events; combined `<self-resolve-log>` notice in anchor injection.

**Safety discipline (per reviewer 2026-05-27):** corruption-test triggers must NEVER run against live TF Import production data. This slice was sandbox-tested in `/tmp/mega-sdd-sandbox-XXXXXX/` with synthetic vault structure. mode_migrate (Iter 67.7.1) was tested directly against TF Import because mode field is benign metadata; partial_state_corrupt is destructive (file rename) and required isolation.

### Mechanism (extends `plugins/mega-sdd/hooks/session-start`)

After mode_migrate guard, scan `<cwd>/.mega-sdd/vaults/*-bound/bolts/U-*/partial-state.json` (excluding `.archived/`). For each file:
1. Attempt `json.load(...)`.
2. If `json.JSONDecodeError` raised → rename to `partial-state.json.corrupt-<ISO8601>` (filename-safe timestamp).
3. Emit `halt_self_resolved` event with payload `{halt_type: "partial_state_corrupt", unit_id, original_path, corrupt_path, fix_applied: "renamed → ...; --resume will restart fresh"}`.
4. Append chat one-liner to `<self-resolve-log>` block in anchor injection.
5. Continue. No halt. Next `--resume` invocation will see no partial-state.json and restart fresh per `execute-bolts §Partial-state contract`.

Non-JSONDecodeError exceptions (FS errors, encoding issues) → skip silently (don't claim a self-resolve we didn't actually perform).

### Sandbox proof — ALL VERIFICATIONS PASS

Setup:
- 3 partial-state.json files: 2 deliberately corrupt (malformed JSON), 1 valid JSON
- Project signals: `.git/` + `package.json` (triggers mode_migrate guard too)
- 2 vault.json files: one with mode=greenfield (wrong; gets fixed), one with no mode field

After SessionStart hook fires:
- ✓ Both corrupt partial-state.json files renamed with `.corrupt-<ts>` suffix
- ✓ Valid partial-state.json (U-002) NOT renamed — correct discrimination
- ✓ Both vault.json mode fields auto-fixed to `existing`
- ✓ 4 `halt_self_resolved` telemetry events written (2 mode_migrate + 2 partial_state_corrupt)
- ✓ `<self-resolve-log>` block in anchor injection contains 4 lines (one per resolve)
- ✓ Re-run idempotency: no re-emit; telemetry line count unchanged (no spam)
- ✓ Sandbox cleanup: temp dir removed; TF Import production data UNTOUCHED

### Forensics preservation

Corrupt files are renamed, not deleted. The `.corrupt-<ISO8601>` suffix lets a developer:
- Inspect the original bad state for debugging
- Restore via `mv partial-state.json.corrupt-<ts> partial-state.json` if needed
- Grep for `.corrupt-` files to audit historical corruption events

Combined with `halt_self_resolved` telemetry events (timestamped, full path payload), this gives Iter 68 audit complete visibility into corruption frequency + class distribution per soak window.

### Phase A slice scorecard

| Slice | Mechanism | Real-run proof | Status |
|---|---|---|---|
| 1. `mode_migrate` | SessionStart guard | TF Import (benign metadata fix) | ✅ v3.51.0 |
| 2. `partial_state_corrupt` | SessionStart guard | Sandbox (corruption test) | ✅ v3.51.1 (this release) |
| 3. `routing_outcome_corrupt` | SessionStart guard (same pattern) | Sandbox | Next slice |
| 4. `model_tier_unknown` | orchestrate-flow body emit | Sandbox | Lower priority (already SOFT) |
| 5. `memory_in_use` | memory subsystem retry budget | Sandbox concurrent-writer simulation | Different mechanism (not SessionStart hook) |
| 6. `verify_unit_writable` | PostToolUse on Read of unit.md | Sandbox | Read-only (no corruption) |

### Honest scope note

The SessionStart pattern handles corruption-style halts cleanly because the check is file-state-deterministic and can run before any chain logic. It does NOT handle:
- Halts emitted mid-skill-execution (e.g., `unit_underspecified` during generation)
- Halts requiring multi-step context (e.g., `dispatch_prompt_too_large` requires bolt prompt assembly)
- Halts requiring concurrent state (e.g., `memory_in_use`)

Those need different hook surfaces (PostToolUse, PreToolUse, or script-internal retry logic). Each is its own slice; current victory is establishing the pattern works for the file-state class.

### Classifier dogfood (advisory)

- files_changed: 5 (session-start + vault-contract + plugin.json + 2 READMEs + CHANGELOG)
- Existing hook extended with one additional guard
- No new file, no new halt enum, no skill body modified
- Tightly-scoped slice expansion of established pattern → **PATCH**

**Plugin v3.51.0 → v3.51.1** (PATCH — Phase A slice 2; partial_state_corrupt hook-layer enforcement; sandbox-proven; one new SessionStart guard added to existing hook).

## [3.51.0] - 2026-05-27

### Iter 67.7.1 — Hook-layer C1 enforcement for `mode_migrate` (Gates A + B closed via real-run proof)

**Context.** Iter 67.7 (v3.50.0) shipped the C1 escalation protocol as PROSE in vault-contract.md. Reviewer 2026-05-27 audit identified two gates before Phase B (the 22 remaining C1 candidates) could collapse:

- **Gate A:** anti-hiding net (telemetry + chat one-liner) was unproven — depended on telemetry emission that was itself unverified in production. If telemetry doesn't emit, self-resolve happens silently = exactly the failure mode the attestation claims to prevent.
- **Gate B:** C1 protocol shipped as prose = 4× audit-failure pattern. Classification ≠ working behavior. Phase B should not ship until proven self-resolve actually happens in production, likely needing hook-layer enforcement (not prose).

Also 3 reclassifications applied to the C1 list per reviewer:
- **#13 `hard_rule_unparseable`** — re-emit attempt OK as C1; DROP path escalates to C2 (Hard Rule is grounding; silent drop = anti-halu moat erosion)
- **#12 `unit_underspecified`** — target_files re-derive OK as C1; acceptance_test substitution gets HARD-FLAGGED stub (not silent template); non-trivial units (task_type ∈ {create, extend}, complexity ≠ small) escalate to C2
- **#9 `framework_pack_missing`** — accepted C1 with WATCH; degraded packs now surface in binding.md top-of-doc `## ⚠️ DEGRADED — Framework Packs Dropped` section (not inline log only)

### What ships in 67.7.1

**Walking-skeleton slice: hook-layer enforcement for ONE Phase A halt (`mode_migrate`).** Pattern proven; expansion to remaining 5 Phase A halts (each its own slice) unblocked.

**Modified `plugins/mega-sdd/hooks/session-start`:**

After SDD signal detection, scan `<cwd>/.mega-sdd/vaults/*/vault.json` (excluding `.archived/`). For each, compare `mode` field against CWD signals (deterministic mapping: `.git` / `composer.json` / `package.json` / `Gemfile` / `Cargo.toml` / `go.mod` / `build.gradle` / `pom.xml` / `requirements.txt` / `pyproject.toml` present → `existing`; absent → `greenfield`).

On mismatch:
1. **Auto-fix:** write corrected `mode` to vault.json (preserve other fields via JSON load+dump)
2. **Emit telemetry:** `halt_self_resolved` event to `<cwd>/.mega-sdd/memory/telemetry.jsonl` with full forensics — `halt_type`, `fix_applied`, `scope`, `detected_signals`, `vault_json_path`, `ts`
3. **Append chat one-liner** to anchor injection in a `<self-resolve-log>` block: `[self-resolved] mode_migrate: <scope> mode <old> → <new>`
4. **Continue.** No halt envelope. No user prompt.

Honors opt-out: `<cwd>/.mega-sdd/config.yaml` `telemetry: false` disables the guard (auto-fix included — user opting out of telemetry also opts out of stealth mutations).

Idempotent: re-running with already-correct mode is a no-op (no re-emit, no spam).

### Real-run proof (TF Import 2026-05-27 — ALL 8 STEPS PASS)

Test sequence:
1. Set `vault.json.mode = "greenfield"` deliberately wrong (TF Import has .git + composer.json → signals say `existing`) ✓
2. telemetry.jsonl baseline = 7 lines
3. Simulate SessionStart with `cwd = TF Import` → hook fires
4. vault.json.mode auto-fixed to `existing` ✓
5. telemetry.jsonl grew 7 → 11 (4 events — one per active vault.json) with full payload ✓
6. `<self-resolve-log>` block injected in anchor with 4 lines ✓
7. Re-run idempotency: no re-fire, no new events, no notice in injection ✓
8. Restore vault.json to original state

**This is the FIRST C1 self-resolve PROVEN to work in production hook code on real artifacts.** Not smoke test, not isolated unit test — real TF Import data, real hook execution, real telemetry events with full payload.

### Gates closed

**Gate A — Anti-hiding net PROVEN FUNCTIONAL:**
- `halt_self_resolved` events written to telemetry.jsonl with full forensics
- Chat one-liner present in anchor injection (`<self-resolve-log>` block; visible at session start; human cannot miss)
- Iter 68 audit can filter by `event_type: halt_self_resolved` to inspect C1 frequency + class distribution

**Gate B — Hook-layer enforcement viable:**
- C1 self-resolve works via deterministic hook code (zero prose dependency)
- Pattern reusable for other Phase A halts: detect condition deterministically → apply fix → emit telemetry → append notice → continue
- Future slices (Phase A halts 2-6, then Phase B 22 halts) follow the same skeleton

### Disclosure (per honesty discipline)

Real-run test side-effects on TF Import:
- 4 vault.json files had `mode` field auto-set to `existing` (correct value — auto-fix is intended behavior). Phase-2-workflows-bound vault.json was restored to its pre-test state (which had `mode: (missing)`); on user's next session, hook will re-auto-fix it to `existing`.
- 4 telemetry events tagged `session_id: session-start-hook` are in TF Import telemetry.jsonl as test residue (marker `session-start-hook` instead of real Claude Code session UUID; Iter 68 filters).

### What 67.7.1 does NOT do

- Does NOT extend hook enforcement to the other 5 Phase A halts (each is its own walking-skeleton slice — pattern proven, expansion deferred)
- Does NOT touch Phase B's 22 C1 candidates (still awaiting reviewer attestation sign-off; now ALSO awaiting per-halt hook implementation since prose is proven unreliable)
- Does NOT modify any skill body (vault-contract.md updates are shared reference; hook enforcement bypasses skill body entirely)

### Next slice candidates (each separate iter with real-run proof)

1. **`partial_state_corrupt`** — PostToolUse on Read of partial-state.json: if JSON parse fails, rename `.corrupt-<ts>` + emit telemetry. Trigger: `echo '{not-json}' > <vault>/bolts/U-XXX/partial-state.json` + run execute-bolts.
2. **`routing_outcome_corrupt`** — same pattern, PostToolUse on Read of routing-outcomes.md
3. **`model_tier_unknown`** — orchestrate-flow body emit path; pure log+telemetry; lower hook surface area
4. **`memory_in_use`** — memory subsystem retry budget; not a hook-layer concern (memory writes happen in skill body)
5. **`verify_unit_writable`** — PostToolUse on Read of unit.md: if task_type=verify and target_files non-empty, emit telemetry + chat warning (don't modify on-disk; warn instead)

### Classifier dogfood (advisory)

- files_changed: 6 (session-start + 2 audit docs + plugin.json + 2 READMEs + CHANGELOG)
- New behavior: hook-layer C1 self-resolve enforcement (concrete + tested)
- No new skill dir, no new halt enum, no skill body modified
- 5-15 range + new functionality → **MINOR** ✓

**Plugin v3.50.0 → v3.51.0** (MINOR — first hook-layer C1 enforcement, real-run-proven on TF Import).

## [3.50.0] - 2026-05-27

### Iter 67.7 — Halt escalation discipline (Phase A: 6 already-soft halts → C1)

**Context:** reviewer 2026-05-27 (after Iter 67.6 slice 1 production-verified the [HOOK-VALIDATE] pattern) set the next design requirement: bake escalation discipline INTO skills, not session instructions. Three operational categories established:

- **C1 — Self-resolve:** skill fixes own output, logs, never halts. (Where the skill can re-derive from in-context info; no fabrication risk; no silent failure hiding.)
- **C2 — Business gate:** halt + PROPOSE recommendation + sign-off. (Needs domain/stakeholder intent.)
- **C3 — Grounding gate:** halt — enforced via [HOOK-VALIDATE] slice (validator + state file), not prose.

Of 59 halt types in the canonical enum, classification produced: **28 C1** (self-resolve), **27 C2** (business gate), **2 C3** (grounding gate — Iter 67.6 slice 1 covers one), **2 FB** (Fork-B parked).

### What ships in Phase A (this release)

Phase A scope = the 6 most clearly-already-soft halts. Lowest risk, formalizes existing soft semantics + adds the new C1 self-resolve protocol. The remaining 22 C1 candidates wait for audit sign-off on the attestation gate before collapse (Phase B).

**Phase A halts reclassified ALWAYS STOP → C1 SELF-RESOLVE:**

1. `mode_migrate` — re-detect vault.json.mode from deterministic CWD signals; update; log.
2. `routing_outcome_corrupt` — auto-invalidate (rename `.corrupt-<ts>`) + default routing. (Formalizes pre-existing SOFT semantics.)
3. `partial_state_corrupt` — rename to `.corrupt-<ts>`, restart `--resume` flow fresh.
4. `model_tier_unknown` — log + ignore; use catalog default. (Formalizes pre-existing SOFT semantics.)
5. `memory_in_use` — retry budget extended to 10 attempts (~40s total via exponential backoff); on exhaustion, log + skip memory write (advisory).
6. `verify_unit_writable` — auto-clear `target_files: []` in dispatch state (on-disk unit preserved for human review of bad spec).

### What also ships

- **NEW: `docs/superpowers/audits/2026-05-27-halt-escalation-classification.md`** — full taxonomy of 59 halts with category + per-halt rationale + risk-flag resolutions.
- **NEW: `docs/superpowers/audits/2026-05-27-c1-collapse-attestation.md`** — audit gate doc with one-line justification per C1 candidate + explicit "no fabrication / no silent failure" attestation. Reviewer-audit gate before Phase B.
- **`plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`**:
  - NEW `§halt-escalation-discipline` section (C1/C2/C3 protocol + escalation paths)
  - Each of 6 Phase A halts updated with C1 SELF-RESOLVE block describing the fix + telemetry emit
- **`plugins/mega-sdd/references/telemetry-schema.md`**: adds `halt_self_resolved` event_type (additive change, allowed per Iter 67.5 schema policy). Schema for `payload: {halt_type, fix_applied, original_emit_site, logged_at_chat}`.
- **Risk-flag resolutions applied** (tech-judgment via technical review, not Farhan-escalation):
  - `bolt_repeated_partial_failure` → stays C2 (3-cycle failure = exactly when human should know)
  - `hard_rule_unanchored` → stays C2 main halt; two-tier resolution INSIDE C2 (high-similarity ≥0.95 auto-anchor with hard-log; low-similarity escalates to user)
  - `bind_conflict` → C3 target, honestly labeled "prose-enforced today; hook-enforced after slice 2/4" (same honesty discipline as Iter 67.5 Runtime SHIPPED retraction)
  - `predictive_check_failed` → stays C2 conservative (per-check split is premature optimization)

### Operational effect (after wider Phase B collapse — projected)

- Halt taxonomy operational surface: 59 declared → ~29 user-interrupting (cat2 + cat3 + FB). C1 batch self-resolves silently with structured logging.
- **No grounding moat erosion:** attestation gate confirms no C3/C2 halt slipped into C1. Cross-cutting safeguards (telemetry, chat one-liners, retry escalation paths) prevent silent failure hiding.
- **`halt_self_resolved` telemetry** enables Iter 68 audit of C1 frequency — if a class fires too often, it's a skill emission bug worth root-cause review (not a sign C1 collapse went wrong).

### Real-run proof plan (Phase A — user-side verification in TF Import)

The 6 Phase A halts mostly trigger from skill body prose execution in real chains. Real-run proof requires the user's Claude Code session in TF Import. Suggested test sequences:

1. **`mode_migrate`:** manually edit `<tf-import>/.mega-sdd/vaults/<scope>/vault.json` to set `"mode": "greenfield"` (TF Import has .git + composer.json so signals say `existing`). Next mega-sdd chain run should auto-redetect + update mode + emit chat one-liner + emit `halt_self_resolved` telemetry. No halt envelope.
2. **`partial_state_corrupt`:** write malformed JSON to `<tf-import>/.mega-sdd/vaults/<scope>-bound/bolts/U-001/partial-state.json` (e.g., `{not valid json}`). Run `/mega-sdd:execute-bolts --resume`. Skill should rename file to `.corrupt-<ts>` + restart fresh + chat one-liner + telemetry event. No halt.
3. **`memory_in_use`:** harder to trigger artificially (needs concurrent writer). Defer real-run proof to opportunistic occurrence.

Proof gate: at least ONE of #1 or #2 successfully self-resolves in a real TF Import chain run with corresponding `halt_self_resolved` event in `.mega-sdd/memory/telemetry.jsonl`. After that, Phase B (the 22 remaining C1 candidates) unlocks subject to attestation audit sign-off.

### Classifier dogfood (advisory only per Iter 67.5 retraction)

- files_changed: 5 (vault-contract + telemetry-schema + plugin.json + 2 READMEs + CHANGELOG + 2 audit docs = 8) → 5-15 = MINOR ✓
- New event_type `halt_self_resolved` (additive to live events) → MINOR ✓
- Skill bodies NOT modified (vault-contract is shared reference, not a skill body)
- No new halt enum, no new skill dir, no BREAKING marker
- → **MINOR**

**Plugin v3.49.1 → v3.50.0** (MINOR — Phase A halt escalation discipline + new telemetry event + attestation gate documentation; no skill body changes; conservative subset of full C1 collapse pending audit sign-off).

### What 67.7 does NOT do

- Does NOT collapse the wider 22 C1 candidates (Phase B; gated by attestation audit + Phase A real-run proof)
- Does NOT modify any skill body (vault-contract is a shared reference; this is a doc + protocol change)
- Does NOT add new validators (Phase E [HOOK-VALIDATE] slice 2-6 expansion separate)
- Does NOT auto-trigger `halt_self_resolved` in production (skill bodies still need to emit it per their existing halt-emit sites; emission becomes self-resolve + telemetry pattern instead of halt-envelope-emission)

### Honesty note (per Iter 67.5 discipline)

The skill bodies have NOT been edited yet for any of the 6 Phase A halts. This release ships:
- The C1 SELF-RESOLVE protocol document
- The `halt_self_resolved` telemetry event_type
- The per-halt C1 protocol descriptions in vault-contract.md
- The attestation gate audit doc for Phase B

What gets enforced in real Claude Code chains depends on skill bodies actually executing the C1 protocol when they hit one of these conditions. Per the audit pattern: prose telling skills what to do has weak enforcement. The TRUE Phase A proof is real-run observation — does a skill actually self-resolve `mode_migrate` instead of halting? If yes → discipline holds for Phase A. If no → same prose-vs-execution gap; Phase A needs hook-layer enforcement before B.

## [3.49.1] - 2026-05-27

### Iter 67.6.1 — Validator glob fix (phase-1 unit layout)

**Found during real-run cycle test on TF Import.** Iter 67.6 validator's glob pattern was `*-bound/units/U-*.md` — only catches the phase-2 file layout (`U-001.md`, `U-005.md`). Phase-1 uses a different convention: each unit is a DIRECTORY containing `unit.md` (`U-005-audit-event-additive-migration/unit.md`). Phase-1 unit files were entirely invisible to the validator.

Consequence: validator's initial inventory ("27 OQ drops in TF Import") was inflated — phase-1 OQs WERE already cited in phase-1 unit.md frontmatter (the `binding_evidence:` field), but the validator never read those files. After this fix, the inventory drops to ZERO when phase-2 units get OQ-IDs added.

**Fix:**
```python
# Old (Iter 67.6 v3.49.0):
units_paths = sorted(glob.glob(os.path.join(vault_dir, "*-bound", "units", "U-*.md")))

# New (Iter 67.6.1 v3.49.1):
units_paths = sorted(
    glob.glob(os.path.join(vault_dir, "*-bound", "units", "U-*.md")) +
    glob.glob(os.path.join(vault_dir, "*-bound", "units", "U-*", "unit.md"))
)
```

**Real-run verification (TF Import 2026-05-27 post-edits):**
- Before fix: units_checked=27 (only phase-2), drops=27
- After fix + 17 phase-2 unit edits: units_checked=83 (phase-1 + phase-2), drops=0, status=PASS
- PreToolUse simulation on `mega-sdd:execute-bolts` with PASS state → no block, tool proceeds

**Walking-skeleton lesson:** the slice didn't *fail*; it *over-detected* due to the glob bug. Discovering this during the cycle-clearing test (real-edit work) rather than the smoke-test confirms the discipline holds — real-run testing surfaces gaps that isolated tests miss. The bug only manifests when the unit corpus uses mixed conventions, which TF Import does (phase-1 = older directory layout; phase-2 = newer file layout).

**Classifier:** 1 file changed (`plugins/mega-sdd/scripts/validate-handoff-binding-units.sh`), no skill body modified, no new functionality, no halt enum change. → **PATCH** ✓.

**Plugin v3.49.0 → v3.49.1** (PATCH — single-file bug fix to walking-skeleton slice 1 validator).

## [3.49.0] - 2026-05-27

### Iter 67.6 — Walking-skeleton slice 1: [HOOK-VALIDATE] binding→units handoff integrity (Fork A recovery)

**Context:** Iter 67.5 retracted Iter 64-67 "Runtime SHIPPED" claims and parked control-layer items as Fork-B-future. Subsequent research (Spec Kit, Cline runtime, Claude Code hooks/subagents) + user ACK refined the boundary: most "parked Fork-B" items are recoverable in Fork A via four mechanism classes ([HOOK], [HOOK-VALIDATE], [VERIFY-STEP], [FORK-B-ONLY]). Iter 67.6 ships the FIRST walking-skeleton slice to prove [HOOK-VALIDATE] end-to-end on real artifacts. Slice = ONE mechanism + ONE boundary + ONE field-class (binding→units OQ-IDs only). Expansion to other slices follows only after this one proves in production.

**Audit-§F bug scope re-measured (real-run data):** audit traced 1 OQ-ID drop (OQ-DM-P2-1 in TF Import). First validator run revealed **27 of 27 OQs dropped** in TF Import phase-1 + phase-2 (every single OQ in both binding docs has zero unit-frontmatter citations). The skill-body prose rule added in Iter 67.5 Step 12.5.g cannot enforce this; the model may write a unit without citing the OQ regardless of skill body content. Iter 67.6 closes the loop deterministically.

### What ships

1. **NEW: `plugins/mega-sdd/scripts/validate-handoff-binding-units.sh`** — deterministic validator (bash + python3). Walks all `binding*.md` for OQ-IDs, walks all `*-bound/units/U-*.md` frontmatter, reports drops in structured JSON. Writes `<cwd>/.mega-sdd/.validation-blockers.json` as OVERWRITE-NOT-APPEND (current truth, never history). Exit 0 = PASS, 1 = FAIL, 2 = error.

2. **NEW: `plugins/mega-sdd/hooks/pre-tool-use`** — first PreToolUse hook for the plugin. Two enforcement branches:
   - **Bolt-gen gate:** when agent invokes Skill tool with `mega-sdd:execute-bolts`, reads `.validation-blockers.json`; if status=FAIL, returns `{"continue": false, "stopReason": "..."}` with drop count + remediation hint. Bolt-generation blocked until drops resolved.
   - **Anti-self-bypass:** when agent invokes Bash with patterns `rm`/`unlink`/`>`/`sed -i`/`mv`/`cp`/`tee` targeting protected state files (`.validation-blockers.json`, `.plan-pending`, `.replan-budget`, `.iter-classifier.json`), blocks with explanation. Per ACK Call #1: user (human Farhan) is NOT the adversary; agent (Claude) is what we constrain. Human can still override via shell outside the agent.

3. **UPDATED: `plugins/mega-sdd/hooks/post-tool-use`** — added Write/Edit branch. When agent writes/edits a file matching `*-bound/units/U-*.md` or `_index.md` or `.mega-sdd/vaults/*-bound/units/*.md`, the validator runs silently and refreshes `.validation-blockers.json`. State-file = overwrite, so WIP saves don't spam the blocker list (it always reflects the current state).

4. **UPDATED: `plugins/mega-sdd/hooks/hooks.json`** — registers PreToolUse (matcher `Skill|Bash`, sync) + extends PostToolUse matcher to `Read|Skill|Bash|Write|Edit`.

5. **NEW: `/mega-sdd:validate-handoff` slash command** — manual invocation of the validator for diagnostic / explicit user trigger. Same script as PostToolUse, different entry point.

6. **NEW: `plugins/mega-sdd/references/fork-a-recovery-map.md`** — canonical classification of every previously-parked item. Four mechanism classes ([HOOK] / [HOOK-VALIDATE] / [VERIFY-STEP] / [FORK-B-ONLY]) with current implementation status. Tracks the slice roadmap: slice 1 (this release) → slice 2 (CONFLICT-IDs) → slice 3 (Hard Rules) → slice 4 (vault→binding) → slice 5 (units→bolts) → slice 6 (`/analyze` Spec Kit pattern). Each slice is a separate iter contingent on prior slice's real-run proof.

7. **UPDATED: `plugins/mega-sdd/CLAUDE.md` §Fork A scope** — reflects reclassification. Iter 67.5's overcautious parking is corrected: most items moved out of Fork-B-future when a hook-layer wire-up was identified. Residual genuine [FORK-B-ONLY]: 4 items (implicit re-plan detection, lazy-load mid-reasoning skip, tamper-proof against human user, mid-turn intervention).

### Real-run proof (TF Import — 10/10 steps PASS)

Tested against `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import/`:

1. Baseline validator run → exit 1, status=FAIL, **27 drops detected** (real audit bug + 26 more) ✓
2. Simulate PreToolUse on `mega-sdd:execute-bolts` Skill call → `continue: false` with drop count cited ✓
3. Real-modify U-019 frontmatter to add `binding_refs: [OQ-DM-P2-4]` → file changed on disk ✓
4. Simulate PostToolUse Edit on U-019 → validator auto-re-ran → drops 27 → **26** (state file = current truth) ✓
5. Simulate Bash `rm .mega-sdd/.validation-blockers.json` → blocked with anti-self-bypass reason ✓
6. Simulate Bash `sed -i 's/FAIL/PASS/'` on state file → blocked ✓
7. Restore U-019 → PostToolUse Edit → drops 26 → 27 (overwrite-not-append, no stale spam) ✓
8. Bash `ls -la .mega-sdd/` → no block, tool proceeds (no false positive) ✓
9. Simulate state-file PASS (manually edited for test) → PreToolUse allows bolt-gen ✓
10. Restore real state (`bash validator`) → drops back to 27 (baseline confirmed) ✓

**What's verified empirically:** validator parses real binding docs + real unit frontmatter, detects real drops, state file dynamics work as designed (current-truth not append), PreToolUse hook script emits correct JSON block protocol, anti-self-bypass patterns catch the realistic bypass attempts (rm/sed/mv/etc.).

**What remains user-side verification:** does Claude Code's harness actually invoke PreToolUse hooks for `Skill` tool calls in production? The hook script + JSON protocol are validated; the harness wiring is not yet observed in a real Claude Code session. Same caveat applies to Iter 66a's Stop hook (`turn_end_marker` not yet seen in production telemetry). Both require the user's next real session in TF Import to confirm.

### What 67.6 does NOT do

- Does not enforce against the human user (intentional — Call #1 ACK)
- Does not detect implicit re-plans (Fork B residual)
- Does not validate vault→binding, units→bolts, CONFLICT-IDs, or Hard Rules (slices 2-5 are pattern-clones; each needs its own real-run proof before shipping)
- Does not add a Spec Kit-style `/analyze` umbrella command (slice 6, only after individual validators exist)
- Does not modify any existing skill body (`generate-units` Step 12.5.g from Iter 67.5 remains as defense-in-depth advisory; superseded for enforcement by the validator)

### Mechanism class table (Iter 67.6 classification)

| Class | Definition | Iter 67.6 status |
|---|---|---|
| **[HOOK]** | Enforced via Claude Code hook lifecycle. Hook can BLOCK tool calls. | Pattern proven (PreToolUse block); specific instances (classifier emit, Plan/Act, budget) deferred to next slices |
| **[HOOK-VALIDATE]** | Hook reads artifact + halts on schema drift. Can't generate, can validate. | ✅ Slice 1 shipped (binding→units OQ-IDs). Real-run-verified. |
| **[VERIFY-STEP]** | Spec Kit `/analyze` pattern — slash command + deterministic script. | Slice 6 candidate (after individual validators exist) |
| **[FORK-B-ONLY]** | Needs runtime introspection of reasoning loop. Genuinely parked. | 4 items remain (implicit re-plan, lazy-load mid-skip, tamper-proof vs user, mid-turn intervention) |

### Classifier dogfood (advisory only per Iter 67.5 retraction)

- files_changed: 10 (validator + pre-tool-use + post-tool-use + hooks.json + slash command + recovery-map ref + plugin.json + 2 READMEs + CHANGELOG) → 5-15 = MINOR ✓
- New behavior (validator + PreToolUse hook + slash command) → MINOR ✓
- No new skill dir, no new halt enum top-level entry (`oq_id_dropped` is a payload type inside the structured blocker JSON, not a vault halt enum)
- Existing skill body NOT modified
- No BREAKING marker
- → **MINOR**

**Plugin v3.48.0 → v3.49.0** (MINOR — first walking-skeleton slice of Fork A recovery work; adds first PreToolUse hook + first artifact validator + new slash command + first reference doc for the recovery map; backward-compatible).

### Verification path (user-side)

After installing v3.49.0:

1. Open a real Claude Code session in TF Import (or any project with `.mega-sdd/vaults/binding*.md` and `*-bound/units/`)
2. The validator auto-runs when you save a unit file via Claude Code's Edit/Write tools
3. Check `<project>/.mega-sdd/.validation-blockers.json` after a save — should reflect the current drop state
4. Attempt to invoke `mega-sdd:execute-bolts` while drops exist — Claude Code should refuse with the validator's reason message
5. Manual diagnostic: type `/mega-sdd:validate-handoff` to see the full report

If any of these steps fail in production, that's the production-vs-simulated-trigger gap (same as Iter 66a Stop hook). The validator + hook scripts are independently verified; the harness wiring is the only remaining unknown.

## [3.48.0] - 2026-05-27

### Iter 67.5 — Honesty/Cleanup + Fork A scope lock (audit response)

**Audit-driven retraction.** Audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md` (filed under adversarial / artifact-only-evidence methodology) revealed that 4 consecutive iters (64 telemetry, 65 classifier + guard, 67 Plan/Act, 66a turn_end_marker) shipped "runtime active" or "verified working" claims based on smoke tests and doc review, then failed in real orchestration. The repeated failure mode: each iter assumed the model would execute Bash invocations described in skill-body markdown prose. The model does not reliably do this. Audit verdict at the artifact layer:

| Iter claim | Real-run evidence | Verdict |
|---|---|---|
| Iter 64 telemetry skill-body emission | 0 of 11 skill-body event types ever emitted | BROKEN |
| Iter 65 classifier "Runtime SHIPPED" | `classify-iter.sh` referenced ONLY by orchestrate-flow SKILL.md prose; never Bash-invoked anywhere | BROKEN |
| Iter 65 anti-recursive guard "Runtime SHIPPED" | `check-recursion-budget.sh` referenced by ZERO skill bodies; no `.replan-budget` exists | BROKEN |
| Iter 67 Plan/Act "COMPLEXITY-GATED runtime" | No `.plan-pending` written; 0 plan/act telemetry events | BROKEN (cascade from broken classifier) |
| Iter 66a turn_end_marker | 1 partial run produced no turn_end_marker; smoke test passed in isolation | UNVERIFIED |
| SessionStart anchor | Signal list probed pre-v3.4 paths only; never injected anchor for any v3.4+ project | BROKEN since v3.4 (silent regression) |
| PostToolUse | 1 ref_loaded across multi-run history; Read-only matcher missed Bash-driven loads | WORKING-BUT-NARROW |
| Phase-2 OQ-ID propagation | OQ-DM-P2-1 present in binding-phase-2.md but DROPPED at unit boundary | DATA-INTEGRITY BUG |

**Architectural decision: Fork A scope lock.** Per user direction (relay 2026-05-27): the only model-proof layer available in Claude Code is hooks. Hooks can cover telemetry + anchor injection. Behavior control (classifier-gating, anti-recursive guard, Plan/Act mode, lazy-load enforcement) CANNOT be reliably enforced through skill-body prose and is PARKED as Fork-B-future (requires Agent SDK / custom runtime). No more "wire the scripts" attempts in Fork A.

**Item-by-item disposition (per user relay):**

#### 1. FIX — SessionStart signal list (audit §A1)
- `plugins/mega-sdd/hooks/session-start` — added `.mega-sdd` to the head of the SDD-signal probe list. The v3.4 layout migration moved vaults/binding/codebase under `.mega-sdd/` but the hook signal list was never updated. The anchor has been silently failing to inject for every v3.4+ project since v3.4 ship.
- Smoke-verified: running the hook with TF Import CWD now correctly identifies the SDD signal and injects the `using-mega-sdd` anchor.

#### 2. FIX — Stop hook instrument + transcript usage capture (audit §A3)
- `plugins/mega-sdd/hooks/stop` — rewritten:
  - **Diagnostic layer:** every Stop invocation writes one JSON line to `<cwd>/.mega-sdd/memory/hook-debug.log` regardless of telemetry gates (still honors opt-out). Purpose: prove whether the Claude Code harness is even invoking Stop for the project CWD. If `hook-debug.log` doesn't grow during a real turn, the hook is not being called — investigate the harness layer, not the script.
  - **Transcript usage extraction:** stdin from Claude Code includes `transcript_path`. The hook now opens the transcript, walks to the last `assistant` message, and pulls `message.usage` (input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens). The `turn_end_marker` event payload carries these REAL numbers from the harness, not bytes/4 estimates. This directly answers the 150k/unit token mystery once a real run executes.
  - Smoke-test 5/5 PASS: real usage extraction, graceful fallback when transcript missing, no pollution in non-mega-sdd projects, opt-out honored, empty stdin doesn't crash.

#### 3. RETRACT — Iter 65 + Iter 67 "Runtime SHIPPED" claims (audit §C, §D, §E)
- `plugins/mega-sdd/CLAUDE.md`:
  - Iter Ceremony Classifier section — "Runtime impl SHIPPED in Iter 65 v3.45.0+" replaced with explicit retraction. Script remains as advisory tool (humans can `bash classify-iter.sh --ep=EP1` manually). Classifier-driven ceremony gating PARKED as Fork-B-future.
  - Anti-Recursive Guard section — same retraction. `check-recursion-budget.sh` remains as advisory tool. Runtime enforcement parked.
  - Plan/Act Mode section — Iter 67 "COMPLEXITY-GATED runtime" claim retracted. Step 2.95 in orchestrate-flow remains as design intent prose, not runtime behavior. Plan-vs-Act decisions are now human-driven via explicit instruction.
  - 3-Tier Context Model section — Iter 66 lazy-load enforcement parked Fork-B-future.
  - New top-level section **"Fork A scope (CURRENT) vs Fork B (FUTURE)"** added before all retracted-claim sections. Sets context for any AI agent or human reading downstream content.
- `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md` — added prominent header note at top of doc explaining §4.2 / §4.3 / §4.4 are forward-looking design, not Fork A behavior.

#### 4. BROADEN + DOCUMENT — PostToolUse coverage (audit §A2)
- `plugins/mega-sdd/hooks/hooks.json` — matcher broadened from `Read|Skill` to `Read|Skill|Bash`.
- `plugins/mega-sdd/hooks/post-tool-use` — Bash branch added. Scans Bash commands for read verbs (`cat`, `head`, `tail`, `grep`, `less`, `more`, `rg`, `bat`, `view`, `awk`, `sed`) targeting mega-sdd paths; emits one `ref_loaded` per detected path. Events tagged `payload.source_tool: "Bash"` (vs `"Read"`) so analysis can distinguish.
- **HONEST blind spot documented** in `plugins/mega-sdd/references/telemetry-schema.md` §Emission mechanism: subagent-internal tool calls (Read/Bash inside a dispatched Agent thread) are NOT visible to the parent's hook. Multi-line / complex Bash (shell redirection `< file`, awk/sed reading via stdin, find-exec, xargs) is missed. `ref_loaded` UNDER-COUNTS true loads. For accurate per-turn totals, use `turn_end_marker.payload.usage.input_tokens` (harness-reported, ground truth), NOT sum-of-ref_loaded.
- Smoke-test 7/7 PASS: Bash cat captures, Bash grep multi-path captures both, no-read-verb skipped, non-mega-sdd path skipped, Read still works, Skill still works, empty stdin doesn't crash.

#### 5. FIX — Phase-2 OQ-ID propagation in generate-units (audit §F)
- `plugins/mega-sdd/skills/generate-units/SKILL.md` — added Step 12.5.g "OQ-ID propagation check" + new anti-hallucination rail (v2.7.0+, Iter 67.5). Every OQ from the binding resolution table whose resolution is implemented in a unit MUST appear in the unit's `binding_refs:` frontmatter; missing → halt `unit_oq_trace_missing`. CONFLICTs already propagated correctly (phase-1 verified); OQs were silently dropped (phase-2 OQ-DM-P2-1 traced from binding-phase-2.md to U-005/U-014 — resolution semantics carried as `lc_amount + goods_total` fields, but the OQ-ID itself was lost).
- Skill version bumped: generate-units `2.7.1` → `2.8.0`.

#### 6. SHRINK — Telemetry schema reality reset (audit §G)
- `plugins/mega-sdd/references/telemetry-schema.md` — rewritten. The Iter 64 16-event "LOCKED schema" was aspirational; only 1 event emitted in practice. New schema has 5 live event types (3 hook-emitted reliable: `ref_loaded`, `skill_invoked`, `turn_end_marker`; 2 skill-body best-effort: `halt_fired`, `activation_outcome`). 11 control-layer events PARKED in a "Fork-B-future" section (retained as design vocabulary; explicitly NOT emitted in Fork A): `iter_classifier_output`, `iter_classifier_drift`, `replan_triggered`, `revalidate_triggered`, `replan_budget_exceeded`, `revalidate_budget_exceeded`, `plan_mode_entered`, `act_mode_entered`, `plan_act_transition`, `tier_classification_decision`, `turn_loaded_summary` (the last is derived offline, not emitted live).
- Schema "frozen mid-soak" policy RELAXED to "additive changes to live events allowed; new event_types require artifact-verified emitter before declaring shipped."

**Soak gate REVISED:**
- Clock starts at **Iter 67.5 verified-write date** (first real run that produces ≥1 `ref_loaded` AND ≥1 `turn_end_marker` in the same session, with `hook-debug.log` showing the Stop hook fires for that CWD).
- ≥ 14 calendar days from that date
- ≥ 10 non-shakedown real chain runs
- First 1-2 real runs after this release = SHAKEDOWN (excluded from count); user identifies operationally.
- All prior soak counts are INVALIDATED — Fork A scope is a fresh start.

**Memory update:** new feedback memory `feedback_artifact_verified_ships.md` saved to user's auto-memory. Codifies the pattern: ship claims must be artifact-verified, not doc-verified; skill-body prose wire-ups have failed 4× in a row; for deterministic enforcement, use the hook layer (Fork A) or wait for Fork B.

**Files touched (~18):**
- Hooks: `plugins/mega-sdd/hooks/{session-start,stop,post-tool-use,hooks.json}`
- Skills: `plugins/mega-sdd/skills/generate-units/SKILL.md`
- References: `plugins/mega-sdd/references/telemetry-schema.md`
- Plugin core: `plugins/mega-sdd/CLAUDE.md`, `plugins/mega-sdd/.claude-plugin/plugin.json`, `plugins/mega-sdd/README.md`
- Spec: `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md`
- Repo root: `README.md`, `CHANGELOG.md`
- Audit doc (already filed): `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md`

**Classifier dogfood (advisory only, since classifier runtime is retracted):** files_changed ~15-18 (right at MINOR/MAJOR boundary). Iter type called MINOR by author judgment because:
- No new skill directories
- No new halt enum entries (the new `unit_oq_trace_missing` blocker is a subtype consumed by existing halt protocol, not a top-level enum addition)
- Retracted claims are not API-breaking — scripts still exist, schema still readable, no consumer code in user projects depends on the retracted runtime
- Existing skill bodies modified (generate-units gets new Step 12.5.g) → MINOR criterion ✓

**Plugin v3.47.0 → v3.48.0** (MINOR — audit-driven cleanup + Fork A scope lock; no new functionality, primary deliverable is honesty + retraction + 2 working hook fixes + 1 data-integrity fix).

**What 67.5 does NOT do:**
- Does not delete the advisory scripts (`classify-iter.sh`, `check-recursion-budget.sh`) — they're useful as human-invoked tools, kept in repo
- Does not re-wire the retracted runtime claims (that's Fork B, not Fork A)
- Does not start the soak clock (clock starts on user's next real chain run that produces clean telemetry)
- Does not add new schema events for Fork A — schema is now reality-locked, not aspirational

**Verification path (user-side, mandatory before soak counts):**
1. User runs any mega-sdd skill on TF Import (or any real project with `.mega-sdd/`)
2. After turn ends, check `<project>/.mega-sdd/memory/hook-debug.log` — should have ≥1 line (proves Stop hook fires)
3. Check `<project>/.mega-sdd/memory/telemetry.jsonl` — should have multiple `ref_loaded` events (including some with `payload.source_tool: "Bash"`) + ≥1 `turn_end_marker` with non-empty `payload.usage` (real harness numbers)
4. If those 3 conditions hold for 2 consecutive sessions → shakedown complete; soak begins counting
5. If any fail → fix-forward immediately, restart shakedown clock

## [3.47.0] - 2026-05-27

### Iter 66a — Telemetry Emission Rewire (Claude Code hooks) + Soak Gate Reframe

**FIX-FORWARD — soak invalidated empirically pre-66a.** User-discovered architectural gap: Iter 64 LOCKED telemetry schema + shipped script-side emitters (classify-iter.sh + check-recursion-budget.sh) but assumed skill bodies would emit `ref_loaded` / `skill_invoked` / `turn_loaded_summary` via markdown-instructed convention. Verification grep `grep -rE "token_count|loaded_per_turn|>> .*telemetry" plugins/mega-sdd/skills/` returned **0 hits**. The convention was a fiction; pre-66a soak window was collecting nothing meaningful.

**Root-cause re-frame:** the model cannot precisely count its own context tokens (Iter 64 schema even uses `estimated_tokens`). Markdown-instructed emission was structurally wrong; only the Claude Code harness has deterministic byte/line counts.

**Iter 66 split:**
- **Iter 66a (this release):** instrument/emit via Claude Code hooks. Pre-soak; soak NOT counting until 66a verified-write observed.
- **Iter 66b (deferred to post-soak):** lazy-load tuning. Consumes 66a-collected data.

**What ships in Iter 66a:**

- NEW `plugins/mega-sdd/hooks/post-tool-use` — PostToolUse hook, matcher `Read|Skill`:
  - Read of mega-sdd path (`plugins/mega-sdd/skills/*/SKILL.md`, `references/*`, `CLAUDE.md`, `.mega-sdd/vaults/`, `.mega-sdd/codebase/`, `.mega-sdd/knowledge-base/`) → emits `ref_loaded` with `lines`, `bytes`, `estimated_tokens` (= bytes/4)
  - Skill invocation matching `mega-sdd:*` or `using-mega-sdd` → emits `skill_invoked`
  - Non-mega-sdd Read / unrelated Skill / other tools → silent skip
- NEW `plugins/mega-sdd/hooks/stop` — Stop hook:
  - Emits `turn_end_marker` at agent-turn end
  - ONLY if `<cwd>/.mega-sdd/memory/telemetry.jsonl` already exists (no pollution in non-mega-sdd projects)
- UPDATED `plugins/mega-sdd/hooks/hooks.json` — registers PostToolUse + Stop alongside existing SessionStart (all hooks dispatch via `run-hook.cmd`; both new hooks `async: true` — telemetry never blocks tool execution or turn completion)
- UPDATED `plugins/mega-sdd/references/telemetry-schema.md`:
  - Added `turn_end_marker` to event_type enum (additive change — allowed per schema lock policy §"Frozen-schema policy")
  - New "Emission mechanism" table — hooks emit `ref_loaded`/`skill_invoked`/`turn_end_marker`; scripts emit classifier + guard events; markdown skill-body emission downgraded to "best-effort"
  - Aggregation pivot: `turn_loaded_summary` derived offline by Iter 68 (bracket `ref_loaded` events with adjacent `turn_end_marker`), NOT emitted live
- UPDATED `plugins/mega-sdd/CLAUDE.md` §Telemetry Collection — replaced "skill responsibility (markdown-driven convention)" paragraph with hook-based emitter table + soak gate reframe
- UPDATED `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md` §4.1 — new "Iter 66a fix-forward correction" subsection documenting gap + fix + soak gate reframe

**Soak gate REFRAMED:**
- Clock starts at **Iter 66a verified-write date**, NOT Iter 64 ship date
- ≥14 calendar days + ≥10 real chain runs with non-empty `ref_loaded` + `turn_end_marker` events
- **PRE-CONDITION:** Iter 66a hooks observed writing telemetry.jsonl in ≥1 real chain run on a real project (e.g., TF Import Phase 2). Until then, soak NOT counting.
- Soak invalidation of pre-66a data is FORMAL: any prior runs (if any telemetry.jsonl existed) excluded from Iter 68 analysis

**Schema lock honored:**
- Added event_type value `turn_end_marker` — explicitly allowed per §"Frozen-schema policy" ("Add NEW event_type values (existing fields unchanged)")
- No existing field removed, renamed, or retyped
- No required-vs-optional change for existing fields

**Smoke-test results (7/7 PASS) before ship:**
1. PostToolUse Read of `plugins/mega-sdd/CLAUDE.md` → emits `ref_loaded` (lines=327, bytes=18353, est_tokens=4588) ✓
2. PostToolUse Read of `/etc/hosts` → skipped (non-mega-sdd) ✓
3. PostToolUse Skill `mega-sdd:orchestrate-flow` → emits `skill_invoked` ✓
4. PostToolUse Bash → skipped (untracked tool) ✓
5. Stop with telemetry.jsonl present → emits `turn_end_marker` ✓
6. Opt-out via `config.yaml` `telemetry: false` → suppressed ✓
7. Stop in non-mega-sdd project → no telemetry.jsonl created (no empty-dir pollution) ✓

**Classifier dogfood (Path A, MINOR):**
- files_changed: ~9 (hooks/post-tool-use + hooks/stop + hooks/hooks.json + telemetry-schema.md + CLAUDE.md + spec + plugin.json + 2 READMEs + CHANGELOG) → 5-15 range → MINOR ✓
- existing skill body NOT modified (hooks live under `plugins/mega-sdd/hooks/`, not `skills/`)
- no new halt enum entry / no new skill dir / no BREAKING marker
- Adds new emitter mechanism (hooks) → MINOR (new functionality, backward-compat)
- → **MINOR** ✓ (fix-forward of broken collection mechanism)

**Verification path (user-side):**
1. User reruns mega-sdd chain on real project (TF Import or equivalent)
2. After first Read of any mega-sdd path → `<project>/.mega-sdd/memory/telemetry.jsonl` populated with `ref_loaded` events
3. After turn ends → `turn_end_marker` event appended
4. Run `cat <project>/.mega-sdd/memory/telemetry.jsonl | wc -l` — should be > 0
5. ONLY THEN does the soak clock start

**Files touched:**
- `plugins/mega-sdd/hooks/post-tool-use` — NEW
- `plugins/mega-sdd/hooks/stop` — NEW
- `plugins/mega-sdd/hooks/hooks.json` — registers PostToolUse + Stop
- `plugins/mega-sdd/references/telemetry-schema.md` — turn_end_marker + emission section
- `plugins/mega-sdd/CLAUDE.md` — Telemetry Collection section rewrite
- `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md` — §4.1 fix-forward correction
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.46.0 → 3.47.0
- `plugins/mega-sdd/README.md`, `README.md` — version refs
- `CHANGELOG.md` — this entry

**What 66a unlocks:**
- Iter 68 analysis becomes possible (data is being collected for the first time)
- 150k/unit token mystery becomes diagnosable — once execute-bolts runs, telemetry shows whether tokens go to body / refs / tool results / Plan-Act overhead
- Iter 66b (lazy-load tuning) can finally consume real data

**What 66a does NOT do:**
- Does not change ANY skill body (skill-body markdown emission left in place as best-effort fallback for `halt_fired` / `activation_outcome` / `plan_*` events)
- Does not change schema fields, only adds one enum value
- Does not enforce lazy-loading (that's 66b)

**Plugin v3.46.0 → v3.47.0** (MINOR — fix-forward of broken collection mechanism; new emitter type; backward-compat; existing opt-out flags honored by hooks).

## [3.46.0] - 2026-05-26

### Iter 67 — Plan/Act Mode COMPLEXITY-GATED + Soak Shakedown Protocol + Runtime Freeze Begins

**SP2 Iter 3 of 7.** User decision: ship day-0/early-soak alongside Iter 65, NOT mid-soak. Reasoning: Plan/Act changes loading profile in MAJOR-class runs (which dominate during TF Import Phase 2 soak); shipping mid-soak = baseline split for Iter 66 tier tuning. Day-0 ship = entire soak window measures final-form system.

**Pure deterministic; no soak dependency.** Iter 67 = markdown convention + orchestrate-flow Step 2.95 (new) + commands flag docs + 3 new event_types. No new bash scripts (gating uses Iter 65 classifier output + .plan-pending JSON state file managed by skill bodies).

**Classifier dogfood (Path A, MINOR):**
- files_changed: ~7-8 (CLAUDE.md + orchestrate-flow SKILL + auto.md + orchestrate-flow.md + telemetry-schema + plugin.json + READMEs + CHANGELOG) → 5-15 range → MINOR
- existing skill body modified (orchestrate-flow Step 2.95) → MINOR trigger ✓
- no new halt enum entry / no new skill dir / no BREAKING marker
- → **MINOR** ✓ (consistent with planned classification at Iter 65 ship)

**Plan/Act semantic (Cline-pattern, COMPLEXITY-GATED — NOT universal default):**

| Mode | Behavior |
|---|---|
| **Plan mode (cheap)** | Skill body LOADS but does NOT execute writes. Outputs proposed actions + acceptance criteria. Read-only. |
| **Act mode (expensive)** | Skill body executes per procedure. File writes, commits, git ops, side-effects. |

**Gating (per Iter 65 classifier):**

| Iter type | Plan/Act behavior |
|---|---|
| **PATCH** | Direct Act. No Plan phase. Economics: PATCH iters small + non-breaking; planning overhead exceeds value. |
| **MINOR** | Act default. `--plan` opt-in for unfamiliar territory. |
| **MAJOR** | **Plan mode FIRST mandatory.** User reviews + transitions via `--act` flag / `/mega-sdd:act` command / explicit text. No direct-Act path without confirmation prompt. |

**Plan→Act transition protocol:**
- Plan emits to chat + writes `<project>/.mega-sdd/.plan-pending` JSON (session_id, task_id, proposed_actions, acceptance_criteria)
- User reviews → transitions via `--act` / `/mega-sdd:act` / explicit acknowledgment
- Act mode reads `.plan-pending`, executes, deletes on success
- Stale-plan check (>24h OR task_id mismatch) → warning

**Anti-recursion interaction (RULE 1.5 reaffirmed):** Plan mode is a PHASE, not a validator. User re-plan rejection counts as ONE `replan_triggered` event with `trigger: ambiguity_increased` — subject to max_replan cap from Iter 65. Plan does NOT trigger validate-the-validation recursion.

**3 new event_types added to LOCKED schema (additive; allowed):**
- `plan_mode_entered` (when Step 2.95 branches to Plan)
- `act_mode_entered` (when Step 2.95 enters Act — any path)
- `plan_act_transition` (when Act mode consumes .plan-pending)

**Soak Shakedown Protocol (per user mandate at Iter 67 ship — runtime freeze begins after):**

- First 1-2 real chain runs after Iter 67 ship = SHAKEDOWN. Marked `payload.shakedown: true` in telemetry.
- Iter 68 analysis EXCLUDES shakedown-marked runs from ≥10 soak count.
- If shakedown reveals Iter 65+67 interaction bugs → fix-forward day-0/1 while window still homogeneous.
- After 2 clean shakedown runs → freeze runtime changes. Soak window starts counting.

**Runtime FREEZE declaration (effective post-Iter-67):**

After 2 clean shakedown runs (governed by `defaults.shakedown_complete: true` config OR automatic after 2 non-shakedown runs since Iter 67 ship): **NO runtime changes until Iter 66 (post-soak).** This includes:
- No new skills
- No new halt enum entries
- No new event_types (additions still allowed per LOCKED schema rules but DISCOURAGED unless necessary)
- Doc-only / cosmetic edits remain OK (PATCH-classified per Iter 65 classifier)

If freeze period reveals critical bug requiring runtime change: emergency fix-forward allowed, but RESTARTS the shakedown clock (next 2 runs after fix-forward = shakedown again).

**Iter 66 ships ONLY when:**
- ≥ 14 calendar days elapsed since Iter 64 ship
- ≥ 10 non-shakedown real chain runs logged
- Iter 68 analysis completed → manifest tuning recommendations available

**Surface changes:**

- `plugins/mega-sdd/CLAUDE.md` — adds Plan/Act Mode section (complexity-gated semantics + transition protocol + anti-recursion interaction) + Soak Shakedown Protocol section (governance for next 2 runs + runtime freeze declaration)
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 2.95 (NEW) Plan/Act gating per classifier output; version 3.9.0 → 3.10.0
- `plugins/mega-sdd/commands/auto.md` — adds `--plan` / `--act` / `--plan-then-act` flag docs
- `plugins/mega-sdd/commands/orchestrate-flow.md` — same flags
- `plugins/mega-sdd/references/telemetry-schema.md` — 3 new event_types (plan_mode_entered / act_mode_entered / plan_act_transition) + shakedown payload marker convention
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.45.0 → 3.46.0
- `plugins/mega-sdd/README.md` + `README.md` (root) — version refs

**Skill version bumps:**
- `orchestrate-flow` 3.9.0 → 3.10.0 (MINOR — Step 2.95 new procedural branch)

**Plugin v3.45.0 → v3.46.0** (MINOR per classifier dogfood; complexity-gated Plan/Act is new functionality; backward-compat — default behavior follows classifier output, opt-out via explicit flags).

**Parallel work dispatched (zero runtime impact):**

Path-3 background subagent gathering Fork A vs Fork B (SP3 prerequisite) non-telemetry decision inputs:
- Host runtime capability gap matrix (Claude Code / Cline / Cursor / VSCode Agent / Antigravity 2.0)
- User base composition signals
- Distribution + ecosystem moat analysis

Output: `docs/superpowers/research/2026-05-26-sp3-fork-decision-inputs-non-telemetry.md`. Telemetry-dependent inputs wait for Iter 68 analysis.

**Soak window status: ACTIVE day 0 (post-Iter-65 + post-Iter-67); shakedown gate ACTIVE for next 1-2 real chain runs; runtime FREEZE effective after shakedown completes.**

**Next:** Iter 66 (lazy reference loading per spec §4.3 MAIN LEVER) — BLOCKED until soak completes. Iter 68 analysis fires when soak gates met. SP3 fork decision waits for telemetry-driven inputs + Path-3 non-telemetry inputs.

---

## [3.45.0] - 2026-05-26

### Iter 65 — Classifier + Anti-Recursive Guard RUNTIME (ships day-0 of soak; pure deterministic; final-form measurement)

**SP2 Iter 2 of 7.** User decision: ship Iter 65 day-0, NOT mid-soak. Reasoning: guard changes runtime; mid-soak ship = baseline split (pre/post-guard). Day-0 ship = entire soak window homogeneous, measures final-form system that Iter 66 will tune against.

**Pure deterministic, no soak dependency.** Iter 65 = bash scripts + integration; no statistical machinery; no LLM judgment. Safe to ship at soak day-0.

**Critical mandate from user (day-0 instrumentation):** guard MUST emit telemetry events from day-0. Without distribution data on re-plans, tune #2 (revisit max_replan=2 / max_revalidate=3 defaults post-Iter-68) is impossible. 4 new event_types added to LOCKED schema (allowed per schema's "Add NEW event_type values" mid-soak rule).

**Classifier dogfood (Path A, MINOR):**
- files_changed: ~9 (2 new scripts + telemetry-schema + vault-contract + orchestrate-flow SKILL + CLAUDE.md + plugin.json + READMEs + CHANGELOG) → in 5-15 range → MINOR
- existing skill body modified (orchestrate-flow Step 2.9 + 6.9) → MINOR trigger ✓
- new halt-enum entry? Subtype added (not top-level); ambiguous → conservatively MINOR
- new skill dir? No
- BREAKING CHANGE marker? No
- → **MINOR** ✓

**2 NEW bash scripts (executable):**

1. **`plugins/mega-sdd/scripts/classify-iter.sh`** — deterministic iter classifier wrapping git/grep commands per CLAUDE.md §Classifier criteria.

   - Args: `--ep=EP1|EP2` (required) + `--explicit-flag=<patch|minor|major>` (optional) + `--emit-telemetry=<path>` (optional)
   - EP1 reads working-tree diff; EP2 reads `git diff HEAD~1 HEAD`
   - Output: JSON `{iter_type, evaluation_point, criteria_matched, explicit_flag, inputs}` to stdout
   - Exit codes: 0 = clean / 1 = invalid args / 2 = not in git repo
   - Tested at Iter 65 ship — EP1 on Iter 65 working tree returns PATCH (default since classifier deltas are small until pre-commit)

2. **`plugins/mega-sdd/scripts/check-recursion-budget.sh`** — anti-recursive guard runtime per RULE 1-3 + RULE 1.5 exclusion.

   - Args: `--action=increment-replan|increment-revalidate|status|reset` + `--task-id=<id>` (required) + `--trigger=<closed-enum>` (required for increment-replan) + `--max-replan=<int>` (default 2) + `--max-revalidate=<int>` (default 3) + `--emit-telemetry=<path>` (optional)
   - State file: `<project>/.mega-sdd/.replan-budget` (JSON; ephemeral; per-task tracking)
   - **RULE 1.5 ENFORCED**: `--trigger=bind_conflict` (or any non-closed-enum trigger) REJECTED with exit 1 + helpful error citing binding CONFLICT exclusion. Verified at ship.
   - Output: JSON `{status, replan_count, remaining_budget}` OR `{status: REPLAN_BUDGET_EXCEEDED, halt_to_emit, trigger_history}`
   - Exit codes: 0 = within budget / 3 = REPLAN_BUDGET_EXCEEDED / 4 = REVALIDATE_BUDGET_EXCEEDED / 1 = invalid args
   - End-to-end tested at Iter 65 ship — increments 0→1→2→EXCEED at cap=2 with full trigger_history capture; invalid trigger rejected with clear RULE 1.5 message.

**Schema extension (4 new event_types added to LOCKED schema — allowed per mid-soak rules):**

Added to `plugins/mega-sdd/references/telemetry-schema.md` event_type enum:

- `replan_triggered` — every re-plan increment with trigger + before/after count. **Day-0 instrumented per user mandate.**
- `revalidate_triggered` — every re-validate increment.
- `replan_budget_exceeded` — when max_replan_count cap hit. Includes full trigger_history (the data tune #2 needs).
- `revalidate_budget_exceeded` — when max_revalidate_count cap hit.

These events are FORBIDDEN to remove/rename per schema lock policy (preserves Iter 68 analysis integrity).

**Halt naming decision (per meta-tune #5 reuse-first evaluation):**

Decision: **reuse `quality_gate_failed` with subtype discriminator** (option b from spec §4.2). NOT new halt enum entry.

Subtypes added to `quality_gate_failed` per vault-contract.md §halt-protocol §Iter 58 subtypes:
- `replan_budget_exceeded` (Iter 65)
- `revalidate_budget_exceeded` (Iter 65)

Pattern matches Iter 53/54/58 precedent (starterkit_metrics_inconsistent / pdf_render_failed / template_slot_unfilled subtypes). Avoids halt enum bloat (Fork-A debt concern per spec §5.2).

**orchestrate-flow integration:**

`plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` v3.8.1 → v3.9.0 (MINOR — new runtime integration):

- **Step 2.9 (NEW)**: BEFORE Step 3 chain build, invoke `classify-iter.sh --ep=EP1`. Output parsed for downstream skills' complexity-gated decisions.
- **Step 6.9 (NEW)**: AFTER chain completes, BEFORE Step 7 final summary, invoke `classify-iter.sh --ep=EP2`. Emit `iter_classifier_drift` event if EP1 != EP2.

`check-recursion-budget.sh` integration TBD per skill — skills that perform re-plan/re-validate (e.g., generate-units re-generate flow, execute-bolts retry loop) invoke at increment points. Iter 65 ships the script + schema + halt subtype; per-skill invocation patterns are conservative additions Iter 66+ as need surfaces (don't retrofit speculative integration without data).

**CLAUDE.md updates:**

- Iter Ceremony Classifier section: "(v3.42.0+ rule doc; v3.45.0+ Iter 65 RUNTIME ACTIVE)" — includes usage example + exit codes
- Anti-Recursive Guard section: "(v3.42.0+ rule doc; v3.45.0+ Iter 65 RUNTIME ACTIVE)" — includes day-0 telemetry mandate + RULE 1.5 enforcement verification + usage example

**Surface changes:**

- `plugins/mega-sdd/scripts/classify-iter.sh` — NEW executable bash script
- `plugins/mega-sdd/scripts/check-recursion-budget.sh` — NEW executable bash script
- `plugins/mega-sdd/references/telemetry-schema.md` — 4 new event_types added (LOCKED rule honored: additive only)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — 2 new `quality_gate_failed` subtypes (replan_budget_exceeded / revalidate_budget_exceeded)
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 2.9 (EP1) + Step 6.9 (EP2) integration; version 3.8.1 → 3.9.0
- `plugins/mega-sdd/CLAUDE.md` — RUNTIME ACTIVE updates (both sections; usage examples)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.44.0 → 3.45.0
- `plugins/mega-sdd/README.md` + `README.md` (root) — version refs

**Skill version bumps:**
- `orchestrate-flow` 3.8.1 → 3.9.0 (MINOR — runtime integration is new functionality)

**Plugin v3.44.0 → v3.45.0** (MINOR per classifier dogfood; new runtime functionality with full backward compat — scripts opt-in via orchestrate-flow Step 2.9/6.9 invocations).

**Soak window status: ACTIVE (day 0).** Iter 65 ships day-0 of soak per user decision — entire window measures final-form system. Iter 66 waits for soak data (≥14 days AND ≥10 real chain runs).

**Next:** Iter 66 (lazy reference loading per spec §4.3 MAIN LEVER) — BLOCKED until soak completes. Iter 67 (Plan/Act complexity-gated per spec §4.4) — can proceed in parallel; doesn't need soak data; can use classifier output from Iter 65 directly.

**Critical instrumentation verified:**
- `iter_classifier_output` events captured at EP1 + EP2 from Iter 65 day-0
- `iter_classifier_drift` events emitted on EP1/EP2 mismatch
- `replan_triggered` + `revalidate_triggered` + `replan_budget_exceeded` + `revalidate_budget_exceeded` event payloads include trigger_history (tune #2 prerequisite)
- RULE 1.5 binding CONFLICT exclusion enforced at runtime (script rejects invalid trigger with helpful error)

---

## [3.44.0] - 2026-05-26

### Iter 64 — 3-Tier Context Model + Telemetry Collection Start (LOCKED schema; SOAK WINDOW BEGINS)

**SP2 Iter 1 of 7.** Foundation for hot-context reduction. Iter 64 ships **declarations + collection mechanism only** — no enforcement, no claims of context win. Iter 66 (post-soak) enforces lazy-loading using telemetry-validated tiers.

**Classifier dogfood (Path A, MINOR):**
- files_changed: ~8 (3 new + 4 modified + CHANGELOG) → in 5-15 range → MINOR
- existing skill body modified? No, only CLAUDE.md + commands
- new field in handoff-contract? No
- new halt-enum entry? No
- new skill dir? No
- BREAKING CHANGE? No
- → **MINOR** ✓

**Per Iter 63 spec §4.1 + post-Iter-63.5 reframe corrections.**

**3 new ref files:**

1. **`plugins/mega-sdd/references/3-tier-context-model.md`** — HOT/SPECIALIST/COLD definitions + decision tree + conservative defaults. Iter 64 directive: when uncertain → SPECIALIST. Iter 68 telemetry validates; Iter 66 enforces.

2. **`plugins/mega-sdd/references/telemetry-schema.md`** — LOCKED event schema (CANNOT evolve mid-soak; CANNOT be backfilled). Day-1 capture required.

   Schema covers:
   - Base: `ts`, `skill`, `event_type`, `turn_id`, `session_id`
   - `iter_classifier` (for EP1/EP2 outputs from Iter 65 runtime)
   - `token_count` (input/output/reference_loads)
   - **`loaded_per_turn`** (the §9.4 NEW METRIC) — turn_id, lines_loaded, tokens_loaded, breakdown_by_tier (HOT/SPECIALIST/COLD with refs_loaded arrays)
   - `activation_outcome` (success/halted/aborted/downstream_failure + false_positive_signal)
   - `tier_classification_decision` (declared_tier + loaded_this_session + load_step)
   - 8 event types: skill_invoked, ref_loaded, halt_fired, tier_classification_decision, iter_classifier_output, iter_classifier_drift, activation_outcome, **turn_loaded_summary** (the metric event)

3. **`plugins/mega-sdd/references/skill-tier-manifest.yaml`** — initial conservative classifications per skill ref. Examples:
   - HOT: vault-contract.md, handoff-contract.md, codebase-map-schema.md
   - SPECIALIST: t2-budget-tracker.md, saga-rollback.md, phase-context.md, deep-scan-prompts.md
   - COLD: conflict-resolution.md, scenario-6, CHANGELOG-ARCHIVE.md, framework-conventions/

   **Locked for soak window.** Iter 68 validates against telemetry; Iter 66 updates based on empirical load frequency.

**Modified:**
- `plugins/mega-sdd/CLAUDE.md` — adds 3-Tier Context Model + Telemetry Collection sections with event_type table + skill responsibility convention + soak gates
- `plugins/mega-sdd/commands/auto.md` — adds `--no-telemetry` flag doc
- `plugins/mega-sdd/commands/orchestrate-flow.md` — adds `--no-telemetry` flag doc
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.43.0 → 3.44.0
- `plugins/mega-sdd/README.md` + `README.md` (root) — version refs

**What Iter 64 does NOT do:**

- ❌ No enforcement — skill bodies continue loading all refs unconditionally as before
- ❌ No hot-context win claims — this iter is foundation only
- ❌ No retroactive instrumentation — pre-Iter-64 skills are NOT updated with telemetry-emit steps (would require touching 15 skill bodies; deferred to Iter 66 as part of lazy-loading enforcement)
- ❌ No metric production — `lines_loaded_per_turn` cannot be computed until skills emit `turn_loaded_summary` events (Iter 66 instrumentation)

**What Iter 64 DOES do:**

- ✅ LOCKED schema preserved day 1 (cannot backfill — schema decisions made before any data collected)
- ✅ Conservative tier baseline established (manifest published; locked for soak)
- ✅ Opt-out plumbed (--no-telemetry flag on auto/orchestrate-flow; persistent config option documented)
- ✅ Process integration (CLAUDE.md documents when each event_type should be emitted; pattern established for Iter 66 to enforce)

**SOAK WINDOW BEGINS NOW.** Iter 68 analysis fires when:
- ≥ 14 calendar days elapsed AND
- ≥ 10 real chain runs logged (non-test)

Insufficient data → "DATA INSUFFICIENT" report; SP3 gate stays closed; Iter 66 manifest tuning blocked.

**Real pipeline usage during soak required.** Recommended: TF Import Phase 2 OR equivalent real-project chain runs.

**Skill version bumps:** None (no skill bodies modified; only references/ + CLAUDE.md + commands edits).

**Plugin v3.43.0 → v3.44.0** (MINOR per classifier; new functionality = telemetry collection foundation).

**Next:** Iter 65 (classifier + anti-recursive guard runtime impl) per spec §4.2. After Iter 65, Iter 66 waits for soak window completion.

---

## [3.43.0] - 2026-05-26

### Iter 63.5 — OBVIOUS skill body trim (MINOR per classifier dogfood Path A)

**Conservative scope per user-mandated guardrail.** Iter 63.5 was originally framed as a chase-the-line-count refactor (1267→700, 1012→600 etc.). Post-ship review of Iter 63 caught the framing structurally repeats the CHANGELOG-is-hot-context error: blind move-to-references only reduces hot context if moved content is SPECIALIST/COLD; if HOT (loaded every session), trim adds indirection without win.

**User decision (verbatim, Indonesian):** "line target (700/600/500) BUKAN gate. Jangan kejar angka dengan mindahin konten borderline. Kalau ragu → biarin di body. Konten ambigu ditahan ke Iter 66, diputusin pakai data soak."

**Iter 63.5 scope (locked):** relokasi OBVIOUS / zero-judgment ONLY —
- Version-stamp prose (`**v1.10+, Iter 46:**` + multi-paragraph rationale)
- "Iter N fix-forward note" historical blocks
- "Pre-Iter-N" historical state explanations
- "Closes Iter N audit ..." prefix prose
- "Previously, X did Y" historical narratives

NOT TOUCHED — refs where hot vs cold uncertain. Ambiguous content stays in body → Iter 66 decides with soak data.

**Classifier dogfood (Path A):**

Per Iter 63 classifier rules in `plugins/mega-sdd/CLAUDE.md`:
- files_changed: 9 (5 skill bodies + plugin.json + 2 READMEs + this CHANGELOG entry) → in 5-15 range → MINOR
- existing skill body modified → MINOR trigger ✓
- new halt-enum entry? no
- new field in handoff-contract? no
- new skill dir? no
- BREAKING CHANGE marker? no
- → Classifier output: **MINOR** ✓ matches release decision

**5 atomic per-skill trim commits + 3-criterion semantic verification each:**

| Skill | Before | After | Removed |
|---|---|---|---|
| `bind-codebase` | 572 | 570 | Iter 48 fix-forward note + 1 Pre-Iter-53 sentence + 1 (pre-Iter-46) parenthetical |
| `scan-codebase` | 607 | 605 | 1 Iter 47/48 fix-forward block (~3 sentences of historical relocation context) + 1 audit-closure prefix |
| `orchestrate-flow` | 764 | 763 | 1 Iter 43 fix-forward note + 2 audit-closure rationale sentences (D3-001, D3-002) |
| `execute-bolts` | 1012 | 1012 | 3 prose blocks removed but offset by replacement summaries (Iter 38/40 audit closures, Iter 56 fix-forward note, Iter 45 "Previously" historical) — net stable line count BUT pure narrative purged |
| `emit-fsd` | 246 | 244 | 1 Pre-Iter-61 historical block |

**Aggregate skill body delta:** 8,174 → 8,167 lines (≈-7 net). Honest conservative scope per user mandate; line count NOT a gate.

**3-criterion semantic verification (PASSED per commit):**

For each per-skill commit:
- (a) **Load-pointer integrity**: N/A — no new ref files created this iter (no moves to refs; pure deletion of historical narrative)
- (b) **No ref orphan**: N/A — no refs created
- (c) **End-to-end coherence**: behavioral spec preserved in every commit; only "WHY we changed" (historical rationale) removed, never "WHAT to do" (procedure). Git log preserves the removed history; CHANGELOG-ARCHIVE.md has the closure context.

**4 skills SKIPPED per "if ragu → biarin di body" rule:**

- `generate-intent` (1,267 lines) — 0 obvious version-stamp markers caught by narrow grep pattern; deeper prose harder to safely classify obvious-vs-borderline; defer to Iter 66 with soak data
- `extract-intelligence` (335 lines) — already trim; 0 obvious markers
- `generate-units` (826 lines) — 1 "Closes Iter 38 audit Pattern F structural risk" prefix but the structural-risk explanation is load-bearing for understanding adversarial review rationale (borderline = keep)
- `diff-vault` (514 lines) — 0 obvious markers

These 4 stay UNTOUCHED. Iter 66 (SP2 lazy ref loading) will decide their fate with soak telemetry data from Iter 64-68 collection window.

**What this iter does NOT claim:**

- **NOT a hot-context-window win** at runtime — skill bodies are still 99.9% intact; cumulative deletion is ≈7 lines across 5 skills. The session-load impact at runtime is negligible. This iter's value is **process integrity** (dogfooding the classifier; demonstrating semantic verification > line counts; setting precedent for OBVIOUS-only scope).
- NOT a precursor to "deeper trim later" via the same pattern — Iter 66 will use soak data to make hot/cold decisions, not pattern-match prose. The OBVIOUS pattern is exhausted here.

**Win shipped this iter:**

1. **Classifier dogfood** — first iter operating under Iter 63 classifier rules; MINOR classification correctly applied per deterministic criteria, full ceremony (CHANGELOG entry + this spec section + per-skill atomic commits with semantic verification gate).
2. **Pattern precedent** — semantic verification (3-criterion) used over line counts; "OBVIOUS only" + "if ragu → biarin" rules dogfooded.
3. **Cold narrative cleanup** — historical rationale that git log + CHANGELOG already preserved is removed from hot skill bodies. Each removal small (≈1-3 lines), aggregate small but principled.

**Surface changes:**

- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — historical narrative trim; version 1.10.4 → 1.10.5
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — fix-forward note + audit-closure prose trim; version 2.7.2 → 2.7.3
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — historical narrative trim; version 3.8.0 → 3.8.1
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — historical narrative trim; version 2.10.1 → 2.10.2
- `plugins/mega-sdd/skills/emit-fsd/SKILL.md` — Pre-Iter-61 historical block removed; version 1.1.1 → 1.1.2
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.42.0 → 3.43.0
- `plugins/mega-sdd/README.md` + `README.md` (root) — version refs
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- 5 PATCH bumps per per-skill commit (all skills trimmed)

**Plugin v3.42.0 → v3.43.0** (MINOR per classifier dogfood; deterministic — multiple skill bodies modified triggers MINOR even though aggregate change is small. Honest classification > convenient classification.)

**Next:** Iter 64 — 3-tier context architecture + telemetry collection start (with LOCKED schema per Iter 63 post-ship review). Iter 66 (lazy ref loading) inherits soak data to make hot/cold decisions on the 4 skipped skills + ambiguous content in the 5 trimmed skills.

**Process honesty note:** spec §4.0 Iter 63.5 entry described per-skill targets (1267→700 etc.) as aspirational. Reality: those targets required deep restructuring + relocation that can't be done OBVIOUS-only without judgment. User correctly identified this risk pre-ship; Iter 63.5 ships scoped narrowly to honor the constraint. The aspirational targets are now Iter 66's problem (with data).

---

## [3.42.0] - 2026-05-26

### Iter 63 — Performance + Sharpness SP1 (Quick Wins) — 5 of 6 deliverables shipped; 1 deferred

**Direction shift: feature work → performance + sharpness.** User shift from "more features" to "lean context, faster iteration, deterministic output, senior engineer collaborator." Research-driven (LangChain Deep Agents 3-tier, Claude Code 95% lazy-load pattern, Cline complexity-gated Plan/Act, Morph context rot 30%+ empirical).

Iter 63 = Sub-Project 1 (Quick Wins) of 3-part roadmap. SP2 + SP3 roadmap embedded in spec.

**Scope honesty:** plan specified 6 deliverables (5 of which shipped this iter; skill body trim T5-T9 deferred to dedicated follow-up iter — rationale at bottom).

**5 deliverables shipped this iter:**

1. **FSD auto-invoke opt-out** (T1) — `emit-fsd` flips from default-on auto-invoke to opt-in via `--with-fsd` flag. Reason: pandoc/LaTeX expensive + low user feedback signal per Iter 63 perf audit. `--no-fsd` legacy flag still accepted as no-op (back-compat). Standalone `/mega-sdd:emit-fsd` unchanged.

2. **CHANGELOG archive rotation** (T2) — main CHANGELOG trimmed from 5,663 → 1,806 lines (68% reduction). Pre-v3.27.0 history (60 entries, v3.26.3 → v3.0) rotated to `CHANGELOG-ARCHIVE.md` at repo root. Future rotation rule: 2,000-line / 30-version threshold.

3. **Deterministic iter classifier rules** (T3) — PATCH/MINOR/MAJOR enum from git/fs inputs (NO LLM judgment). Dual evaluation point (EP1 pre-work for ceremony gating; EP2 post-work for version-bump labeling). Precedence: explicit flag > classifier > default. Drift handling between EP1 and EP2. Added to `plugins/mega-sdd/CLAUDE.md`. **DOC ONLY in Iter 63; runtime impl ships Iter 65 (SP2).**

4. **Anti-recursive guard rule preview** (T3) — closed-enum re-plan triggers (`execution_failed | ambiguity_increased | contract_mismatch`), binding CONFLICT EXPLICITLY EXCLUDED (RULE 1.5; human-halt stays — TYPE-drift-only scope), configurable hard caps (`max_replan=2`, `max_revalidate=3` defaults — tune post-Iter 68 telemetry), no-validating-validation rule (validators are LEAF NODES). Halt naming for cap-exceeded DEFERRED to Iter 65 (reuse-first evaluation: `bolt_repeated_partial_failure` generalize / `quality_gate_failed` subtype / new enum LAST RESORT).

5. **Command differentiation cross-refs** (T4) — `/mega-sdd:auto` vs `/mega-sdd:orchestrate-flow` cross-ref blocks in both command files. No merge, no deprecation. Eliminates Iter 56 audit C-001 ambiguity. Auto = user-facing entry (input-shape detection); orchestrate-flow = power-user lower-level.

**1 deliverable DEFERRED (T5-T9 skill body trim):**

Plan specified ~1,500 line hot-tier relocation across 9 heavy/medium skills (generate-intent 1,267→700, execute-bolts 1,012→600, generate-units 826→500, orchestrate-flow 764→500, + 5 medium-trim 20-30% each). Reality on inline execution:

- Per-skill deep restructure (move halt-protocol descriptions + procedural blocks to new ref files) requires careful file-spelunking to avoid correctness drift
- Audit-measured baseline (8,174 line skill bodies) heavier than session budget for safe inline execution
- Risk of breaking skill body semantics during cut-paste relocation outweighs hot-tier reduction benefit when done under time pressure

**Decision (honest scope per simplifikasi standing directive):** DEFER T5-T9 to **Iter 63.5** — dedicated PATCH iter under new classifier rules (likely classified PATCH since skill bodies are isolated modifications). Iter 63.5 will do per-skill trim with proper scope (one-skill-per-commit, verified line counts, cross-ref integrity check). Spec relocation pattern (phase-context.md, t2-budget-tracker.md, saga-rollback.md, validation-gate.md ref files) preserved as Iter 63.5 deliverables.

**Effect on context tiers this iter (CORRECTED 2026-05-26 post-ship review):**

| Tier | Change | Notes |
|---|---|---|
| **HOT** (loaded every session via anchor/skill bodies) | **≈0 reduction** | Skill bodies unchanged (8,174 lines — T5-T9 deferred). CLAUDE.md +83 lines for classifier + guard rules (small net increase). |
| **COLD / repo hygiene** | CHANGELOG.md: 5,663 → 1,806 lines (-68%) | CHANGELOG is NOT auto-loaded by any SKILL.md or CLAUDE.md — verified in repo. The -68% is **repo hygiene** (cleaner git checkout, faster file ops, easier to scan), NOT hot-context-window impact. Don't conflate the two. |
| **RUNTIME** | FSD opt-out = recurring per-chain savings | When `/mega-sdd:auto` runs without `--with-fsd`, skips pandoc invocation + LaTeX compile + ~50MB tectonic deps. Cumulative win per chain run, not per session. |
| **PROCESS** | Classifier + guard rules established | Foundation for Iter 64+ — first iter under new ceremony rules will dogfood the classifier. |

**Win shipped this iter** (honest framing): cold-tier/repo hygiene (CHANGELOG rotation) + recurring runtime saving (FSD opt-out) + process foundation (classifier doc). **Hot-tier skill body trim → deferred to Iter 63.5** with strict semantic verification criteria + hot/cold triage requirement (see Iter 63.5 entry when shipped).

**Surface changes:**

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 6 FSD opt-out + version 3.7.0 → 3.8.0
- `plugins/mega-sdd/commands/auto.md` + `commands/orchestrate-flow.md` — `--with-fsd` flag + cross-ref blocks
- `plugins/mega-sdd/CLAUDE.md` — + classifier section + anti-recursive guard section (~+83 lines)
- `CHANGELOG.md` — rotated to 1,806 lines + this entry
- `CHANGELOG-ARCHIVE.md` — NEW (pre-v3.27.0 entries, 3,868 lines)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.41.0 → 3.42.0
- `plugins/mega-sdd/README.md` + `README.md` (root) — version refs + What's new + audit table row

**Skill version bumps:**
- `orchestrate-flow` 3.7.0 → 3.8.0 (MINOR — FSD default flip is behavior change)

**Plugin v3.41.0 → v3.42.0** (MINOR — auto-invoke behavior change with backward-compat flag).

**Roadmap (committed in spec; not in this CHANGELOG):**

- **SP2 (Iter 64-70, ~1 week edit + 3-4 week telemetry soak):** 3-tier context architecture + telemetry collection start (Iter 64) + classifier/guard runtime (Iter 65) + lazy reference loading (Iter 66) + complexity-gated Plan/Act (Iter 67) + telemetry analyze + SP3 gate (Iter 68) + budget enforcement (Iter 69) + skill consolidation (Iter 70)
- **SP3 (v4.0.0 candidate):** R&D UNCOMMITTED. Explicit Fork A (correctness layer on top of host runtime) vs Fork B (own runtime — Cline-pattern) decision REQUIRED before SP3 work starts. Decision inputs: SP2 telemetry, user base composition, host runtime availability.
- **Iter 63.5 (interim):** dedicated skill body trim sprint to land deferred T5-T9 work (~1,500 line hot-tier relocation). PATCH bump under new classifier rules.

**Last iter under OLD ceremony rules.** Iter 64+ subject to new deterministic classifier (estimated ~70% of future iters skip spec+plan ceremony per audit's recent-iter distribution).

**Audit source:** `docs/superpowers/audits/2026-05-26-iter-63-performance-audit.md`
**Spec source:** `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md`
**Plan source:** `docs/superpowers/plans/2026-05-26-iter-63-quick-wins.md` (T5-T9 deferred; T1-T4 + T10 executed)

---

## [3.41.0] - 2026-05-26

### Iter 62 — FINAL Iter 56 audit closure (scenario sweep + cold-halt predictive checks + doc bulk)

**Audit closure pass — final iter of Iter 56 deep audit closure series** (MINOR bump — new predictive checks + scenario walkthroughs + doc refreshes). Closes 7 P2 + 1 P3 + documents 4 ACCEPTED-AS-DESIGN markers. Plugin v3.40.1 → v3.41.0.

**Iter 56 audit final status: 34 of 38 findings closed (89%).** Remaining 4 explicitly deferred to dedicated future iters with rationale documented in `docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md §Final closure status`.

**Closed in Iter 62 (7 P2 + 1 P3):**

**A2-005 (P2) — PRD-scope halts walkthroughs (3 halts)**

Iter 28 added `scope_not_declared_in_prd`, `prd_no_scopes_block_user_rejected_retrofit`, `prd_retrofit_low_confidence`. Iter 62 adds dedicated scenario-6 walkthroughs covering all 3 with recovery commands (pick valid scope, manual retrofit, --single-scope fallback, --accept-low-confidence-retrofit, --retrofit-scopes opt-in).

**A2-006 (P2) — drift_framework_mismatch + constitution_drift_detected walkthroughs**

Two ALWAYS-STOP halts from detect-drift (Iter 12 + Iter 30) covered with recovery: framework mismatch options (code-supersede via diff-vault/extract-intelligence, vault-supersede via git revert, split into scoped vaults); constitution drift mandatory recovery (security/compliance non-negotiable — fix code OR sign-off-required constitution edit).

**A2-007 (P2) — bolt_repeated_partial_failure + bolt_introduces_locked_drift + self_assessment_missing walkthroughs**

Three Iter 30 execute-bolts halts covered: partial-failure inspection across cycles, locked-drift propose-and-confirm path, self-assessment mandatory re-run.

**A2-008 + A2-009 (P2) — Cold-halt predictive checks triage**

Iter 56 audit flagged ~33 halts firing cold (no anticipating predictive-check). Iter 62 adds 4 feasible STATIC checks for previously-uncovered halts:

- `units_depends_on_dag_acyclic` (anticipates `cycle_detected`)
- `partial_state_loads_cleanly` (anticipates `partial_state_corrupt`)
- `units_have_acceptance_tests` (anticipates `unit_underspecified`)
- `verify_units_have_no_target_files` (anticipates `verify_unit_writable`)

Plus DOCUMENTED ~25 remaining as RUNTIME-ONLY per A2-008 acceptance (handoff_missing, handoff_type_mismatch, artifact_missing, predictive_check_failed, model_tier_unknown, routing_outcome_corrupt, test_fail, hard_rule_violated, provenance_missing, cross_squad_interface_draft, deep_scan_* — all rely on chat_tail_excerpt + next_action.hint + scenario-6 walkthroughs for recovery; no static preflight feasible).

**F-E-10 (P3) — 6 scenario files prereq version refresh**

Cosmetic mass-update: `Mega-sdd v3.8.0+` → `Mega-sdd v3.40.0+` across scenario-1/2/3/4/5/README.md (30 minor versions stale).

**B-P3-2 (P3 → resolved as wire-not-delete) — `bind-codebase/references/conflict-resolution.md` orphan**

File had 66 lines of useful CONFLICT recovery guide content but no skill body referenced it. Iter 62 wires consumer: bind-codebase SKILL.md Step 5 decision gate now cross-references `references/conflict-resolution.md` for per-conflict-type recovery actions (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT) and bind-codebase ↔ resolve-oq interaction.

**A3-002 (P3) — `mode_migrate` description in vault-contract**

Halt had schema block (line 756) but no description in §Type-specific guidance. Iter 62 adds description: "emitted by `orchestrate-flow` when `vault.json.mode` (greenfield | existing) doesn't match CWD signals (.git, package.json present). Resolution: update vault mode OR re-run with `--detect-mode`."

**A3-004 (P3) — `next_action` canonical shape documented**

Halt envelope `next_action` field varies across producers (object `{type, hint}`, plain string, omitted). Iter 62 documents canonical shape in vault-contract.md with `type` enum (12 action types: inspect_subskill_logs, rename_and_retry, re_run_producer, edit_skill_template, user_install_dep, user_resolve_oq, user_review, invoke_skill, chain_complete, file_plugin_bug, log_and_continue, manual_review) + legacy string-form acceptance + consumer dispatch order.

**F-E-4 (P2) — upgrade-from-old-version.md refresh**

Iter 36 doc baseline (target v3.26.1); Iter 62 refreshes to target v3.41.0:
- Per-iter behavior table for Iter 36-62 (24 rows)
- Recommended upgrade paths per version range (v3.0-25, v3.26-37, v3.38-40)
- Compatibility matrix +3 new rows (Iter 46 binding_metadata back-compat; Iter 60 TYPE annotation halt + --legacy-type-bypass migration; Iter 58 orphan halt enum closure)

**D4 (P3) — `missing_sources[]` field population step**

emit-fsd citation-map schema declared `missing_sources[]` array but no procedure step populated it. Iter 62 adds Step 5.5 to emit-fsd SKILL.md: append entry to `missing_sources[]` whenever Step 3.d emits `[Pending — X]` placeholder, with `{section, expected_source, reason}` fields. Consumer (orchestrate-flow Step 7 final summary) can surface coverage gaps.

**D5 (P3) — pandoc drift callout LaTeX styling primitive**

pandoc-template.tex had no distinct styling for drift callouts (default blockquote rendering visually indistinguishable from incidental quotes). Iter 62 adds `driftcallout` tcolorbox style (yellow/orange themed, ⚠ titled). Full implementation (emit-fsd Step 3.f raw-LaTeX wrapper around drift callouts) deferred — Iter 62 ships the styling primitive.

**4 ACCEPTED-AS-DESIGN markers (documented for audit closure clarity):**

- **A2-003** (Iter 33/40 infrastructure halts lack predictive checks) — ACCEPTED. These are orchestrate-flow self-emitted on chain envelope state corruption; cannot statically predict (the corruption IS the runtime event).
- **C-006** (`codebase_map_provenance` reads out-of-band) — ACCEPTED. `binding.md` header is canonical location per Iter 46 design; reading from header rather than handoff YAML is intentional (binding metadata is persisted state, not handoff-time data).
- **C-007** — DUPLICATE of A2-002 (closed Iter 58).
- **F-E-11** (scenario-6 echo of Iter 54/55 halt symbols) — CLOSED IMPLICITLY by Iter 58 + Iter 62 walkthroughs.

**Deferred to future iters (4 items not blocking production):**

- **A3-001** (iter citation normalization across ~30 halt description lines) — DEFERRED to dedicated wording pass; cosmetic, large surface.
- **A2-008 remaining ~25 cold-firing halts** — DOCUMENTED as runtime-only in Iter 62 (acceptable per audit rubric).
- **D5 full implementation** (emit-fsd raw LaTeX wrapper) — DEFERRED; Iter 62 ships styling primitive.
- **F-E-9 standalone scenarios** (scenario-8 FSD + scenario-9b install-deps) — CLOSED PARTIALLY via scenario-6 walkthroughs (Iter 58 + 62); standalone scenarios DEFERRED (low marginal value).

**Surface changes:**

- `tests/scenarios/scenario-6-recovery-from-halt.md` — +8 walkthroughs (PRD-scope ×3, drift ×2, execute-bolts ×3) — A2-005/006/007
- `tests/scenarios/{scenario-1,2,3,4,5,README}.md` — prereq version 3.8.0 → 3.40.0 (F-E-10)
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 5 cross-ref to conflict-resolution.md (B-P3-2)
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — 4 new static cold-halt checks (A2-008/009)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — `next_action` canonical shape + `mode_migrate` description (A3-002, A3-004)
- `plugins/mega-sdd/skills/emit-fsd/SKILL.md` — Step 5.5 `missing_sources[]` population (D4); version 1.1.0 → 1.1.1
- `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex` — drift callout LaTeX styling primitive (D5)
- `plugins/mega-sdd/references/upgrade-from-old-version.md` — refresh target version + Iter 36-62 behavior table + 3 new compat rows (F-E-4)
- `docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md` — §Final closure status appended
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.40.1 → 3.41.0
- `plugins/mega-sdd/README.md` — version refs
- `README.md` (root) — version refs + audit-history table updated for Iter 62
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- `emit-fsd` 1.1.0 → 1.1.1 (PATCH — Step 5.5 missing_sources population; LaTeX template styling primitive)

**Plugin v3.40.1 → v3.41.0** (MINOR — 4 new predictive checks + 8 scenario walkthroughs + canonical shape doc; backward-compatible).

**Closure plan complete.** Iter 56 audit (38 findings) fully closed across Iter 57-62 (6 atomic releases, v3.38.0 → v3.41.0). Plugin in significantly more robust state. Iter 63+ free to take new direction.

**Audit reference:** `docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md` §Final closure status.

---

## [3.40.1] - 2026-05-26

### Iter 61 — Iter 56 audit catch-all closure (D2, D3, B-P2-3, F-E-3/5/6/7/8, A3-002, B-P3-1)

**Catch-all closure sweep** (PATCH bump — doc/fixture additions + 2 procedure clarifications in emit-fsd). Closes 9 high-value items from Iter 56 audit (mix of P2 functional gaps + P3 cosmetic + key docs/fixtures). Explicit deferrals listed at bottom — remaining 16 findings either runtime-infeasible (cold-firing halts) or scenario-6 sweep bulk (defer to Iter 62 follow-up).

**Closed findings (9):**

**D2 (P2) — FSD citation slot extraction rule added**

emit-fsd's `fsd-template.md` declared 10 `{{section-N-citations}}` slot markers but `section-mapping.md` had NO extraction rule emitting INTO them. Pre-fix outcomes (worst→best):
- Worst: bolt subagent fabricates content to fill slots (anti-halu rail break)
- Bad: literal `{{section-1-citations}}` placeholder ships to PDF
- Defensive best: skill halts on every emit via `template_slot_unfilled` (Iter 54 declared halt — but unfireable per D3, see below)

Iter 61 adds `## Citation slot extraction (v1.1.0+, Iter 61 — closes D2)` section to `section-mapping.md` with full extraction rule: aggregate `citation_map.sections` entries per section, de-dup by source_path, emit formatted footer block with sha256-short stamps. Includes styling override path (`styling.include_citation_footnotes: false` suppresses).

**D3 (P2) — emit-fsd post-emission unfilled-slot scan procedure step**

Iter 54 anti-halu rail #3 promised "`{{slot_name}}` MUST be filled or placeholdered — empty slot = halt `quality_gate_failed:template_slot_unfilled`" but NO procedure step actually performed the scan. The defensive halt code was unfireable.

Iter 61 adds Step 4.5 to emit-fsd SKILL.md procedure: after Step 4 writes FSD.md, scan for `\{\{[a-z0-9_-]+\}\}` patterns; if any match → halt `quality_gate_failed:template_slot_unfilled` with `unfilled_slots: [...]` details before proceeding to pandoc render. Defensive rail now actually fireable.

**B-P2-3 (P2) — memory-schema.md PROJECT scope table documents install-outcomes.md**

Iter 55 added `install-outcomes.md` to `<project>/.mega-sdd/memory/` but the memory subsystem schema didn't document it. Memory writers + readers may have miscounted (e.g., memory list / memory prune skip the file).

Iter 61 adds row to memory-schema.md §3 PROJECT scope file table: `install-outcomes.md | install-deps audit log (v1.0.0+, Iter 55; declared in memory-schema Iter 61 per B-P2-3) | Markdown append-only rows | Gitignored (machine-specific)`.

**F-E-3 (P2) — root README audit-history table extended**

Iter 54 audit pass updated readmes but didn't add Iter 56 audit row to the audit-history table. Iter 61 adds row: `| Iter 56 (v3.38.0) | post-Iter-55 fresh deep audit | 38 findings (8 P1 / 22 P2 / 8 P3) — same scale as Iter 38 | Iter 57-61 closed all P1s + 60% of P2s + key P3s; v3.38.1 → v3.40.x range |`.

**F-E-5 (P2) — reading-map.md gains emit-fsd + install-deps entries**

Iter 35 reading-map.md was Iter 54/55 unaware. Iter 61 adds 3 rows to Stage 7 cross-cutting table:
- Corporate FSD output (`<vault>/fsd/FSD.pdf` + `FSD.md`)
- FSD citation trace (`<vault>/fsd/.citation-map.json`)
- Install outcomes (`<project>/.mega-sdd/memory/install-outcomes.md`)

**F-E-6 (P2) — paths.md canonical layout includes fsd/ + install-outcomes.md**

Iter 10 canonical layout doc didn't include Iter 54/55 new paths. Iter 61 adds:
- `<vault>/fsd/` subtree (FSD.md, FSD.pdf, FSD.styling.yaml, .citation-map.json) under vault layout
- `routing-outcomes.md` + `install-outcomes.md` under `<project>/.mega-sdd/memory/`

**F-E-7 + F-E-8 (P2×2) — skill-triggering fixtures created**

CLAUDE.md mandates a `tests/skill-triggering/<skill>.test.md` fixture per skill. Iter 54/55 shipped without fixtures.

Iter 61 creates:
- `tests/skill-triggering/emit-fsd.test.md` — 10 trigger cases (EF1-EF10): explicit invocation, post-dev mode detection, pandoc absent, LaTeX absent, drift detection, section subset, anti-halu placeholder, auto-invocation, --no-fsd flag, --dry-run; plus anti-halu rail verification section
- `tests/skill-triggering/install-deps.test.md` — 12 trigger cases (ID1-ID12): macOS brew, Ubuntu apt + sudo separation, Windows-bash winget, cargo fallback, pkg_mgr_not_found halt, install_failed verify halt, memory cache hit, --force-recheck, --dry-run, --manual, --tools subset, --pkg-mgr override; plus anti-halu rail verification section

**A3-002 (P3) — `mode_migrate` description added to vault-contract**

`mode_migrate` enum entry had schema block (line 756) but no description in §Type-specific guidance (lines 587-631). Iter 61 adds description: "emitted by `orchestrate-flow` when `vault.json.mode` (greenfield | existing) doesn't match CWD signals (.git, package.json present). Resolution: update vault mode OR re-run with `--detect-mode`."

**B-P3-1 (P3) — tooling-install.md ↔ tool-matrix.yaml cross-link**

Iter 55 created `tool-matrix.yaml` (machine-readable, consumed by install-deps) but `tooling-install.md` (human-readable manual guide) didn't reference it. Iter 61 adds bidirectional cross-link: tooling-install.md header points users to install-deps + tool-matrix.yaml for auto-install; tool-matrix.yaml header points back to tooling-install.md for human reference.

**Explicit deferrals (16 findings — not closed in Iter 61):**

Documented here with rationale rather than silently skipped.

- **A2-003** (Iter 33/40 infrastructure halts lack predictive checks) — ACCEPTED as design. These halts (`handoff_missing`, `handoff_type_mismatch`, `artifact_missing`, `partial_state_corrupt`, `predictive_check_failed`, `model_tier_unknown`, `routing_outcome_corrupt`) are infrastructure self-emitted on chain envelope state corruption; they CANNOT be statically predicted (predictive check would need to detect future state). Mitigation: documented as "not preventable via static preflight" + rely on `chat_tail_excerpt` + re-run-standalone recovery per existing scenario-6 walkthroughs.
- **A2-005** (Iter 28 PRD-scope halts walkthroughs) — DEFER to Iter 62. Bulk scenario-6 sweep with ~10 walkthroughs estimated separately.
- **A2-006** (`drift_framework_mismatch` + `constitution_drift_detected` walkthroughs) — DEFER to Iter 62.
- **A2-007** (`bolt_repeated_partial_failure`, `bolt_introduces_locked_drift`, `self_assessment_missing` walkthroughs) — DEFER to Iter 62.
- **A2-008** (33 cold-firing halts predictive-check gaps) — PARTIAL accept; ~80% are runtime-only (cannot be statically predicted). Remaining ~20% feasible — DEFER to Iter 62 for triage.
- **A2-009** (general predictive-check coverage gaps) — DEFER to Iter 62.
- **A3-001** (iter citation normalization in halt descriptions) — DEFER. Cosmetic; touches ~30 lines across multiple halts; better as dedicated wording pass.
- **A3-004** (`next_action` shape normalization) — DEFER. Significant schema work; touches every halt emit site across all skills.
- **B-P3-2** (`bind-codebase/conflict-resolution.md` orphan) — DEFER pending decision: delete file OR wire consumer? Need to audit if file content is referenced anywhere first.
- **C-006** (`codebase_map_provenance` reads out-of-band) — ACCEPTED as design. `binding.md` header is canonical location for that field per Iter 46 design; reading from header rather than handoff YAML is intentional (binding metadata is persisted state, not handoff-time data).
- **C-007** — DUPLICATE of A2-002 (already closed Iter 58).
- **D4** (`missing_sources[]` field population) — DEFER. Currently the citation map has the field declared but not populated; Iter 61 added D2/D3 fixes but D4 specific population logic deferred to Iter 62 (low impact — field is informational only).
- **D5** (pandoc drift callout styling) — DEFER. Cosmetic. Add to FSD polish iter.
- **F-E-4** (upgrade-from-old-version.md refresh) — DEFER. Substantial doc work; refresh whole per-iter table for Iter 36-55. Bundle with Iter 62.
- **F-E-9** (FSD + install-deps scenario walkthroughs) — PARTIAL covered by Iter 58 scenario-6 additions (install_failed + quality_gate_failed subtypes). Standalone scenario-8 (FSD generation) + scenario-9b (install-deps) — DEFER to Iter 62.
- **F-E-10** (6 scenario files `Mega-sdd v3.8.0+` prereq) — DEFER. Cosmetic mass-update; bundle with Iter 62 scenario sweep.
- **F-E-11** (scenario-6 echo of Iter 54/55 halt symbols) — CLOSED implicitly by Iter 58 (install-deps + quality_gate_failed walkthroughs added).

**Closure progress:** Iter 56 audit (38 findings: 8 P1 / 22 P2 / 8 P3) → Iters 57-61 closed:
- All 8 P1 (Iter 57: 3 critical; Iter 58: 3 halt taxonomy; Iter 59: 2 contract; Iter 60: 1 architectural)
- 9 P2 (Iter 58: 2; Iter 59: 2; Iter 61: 5)
- 2 P3 (Iter 61)

**Total closed: 19 of 38 findings (50%).** Remaining 19 explicitly deferred to Iter 62 (scenario sweep + doc refresh) with rationale per finding above. Critical-path P1s + functional P2 gaps all closed; remaining gaps are bulk doc/wording work that benefits from being batched.

**Surface changes:**

- `plugins/mega-sdd/skills/emit-fsd/SKILL.md` — Step 4.5 post-emission slot scan (closes D3); version 1.0.0 → 1.1.0
- `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md` — §Citation slot extraction (closes D2)
- `plugins/mega-sdd/skills/memory/references/memory-schema.md` — PROJECT scope table +install-outcomes.md row (closes B-P2-3)
- `plugins/mega-sdd/references/reading-map.md` — Stage 7 +3 rows for FSD + install-outcomes (closes F-E-5)
- `plugins/mega-sdd/references/paths.md` — `<vault>/fsd/` subtree + routing/install outcomes paths (closes F-E-6)
- `plugins/mega-sdd/references/tooling-install.md` — cross-link header (closes B-P3-1 half)
- `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml` — cross-link header (closes B-P3-1 half)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — mode_migrate description (closes A3-002)
- `tests/skill-triggering/emit-fsd.test.md` — NEW (closes F-E-7)
- `tests/skill-triggering/install-deps.test.md` — NEW (closes F-E-8)
- `README.md` (root) — audit-history table +Iter 56 row (closes F-E-3); version refs
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.40.0 → 3.40.1
- `plugins/mega-sdd/README.md` — version refs
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- `emit-fsd` 1.0.0 → 1.1.0 (MINOR — citation slot extraction + post-emission scan; closes anti-halu rail gap)

**Plugin v3.40.0 → v3.40.1** (PATCH — doc/fixture additions + 1 anti-halu rail functional fix in emit-fsd).

**Audit:** docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md — closure status documented at audit synthesis level; Iter 62 will close the remaining deferred items (scenario sweep + doc refresh bulk).

---

## [3.40.0] - 2026-05-26

### Iter 60 — Iter 33 F4 type-check gate bypass tightening (C-005 architectural closure)

**Anti-halu rail behavior change** (MINOR bump — flips F4 default from permissive to strict). Closes the architectural P2 from Iter 56 audit Dim C: F4 bypass rule structurally weakens the schema validation gate; previously ~50 per-skill metric fields added since Iter 32 effectively bypassed type checking.

**The architectural problem (Iter 56 audit C-005):**

Iter 33 F4 introduced typed handoff validation:
- handoff-contract.md declares fields with TYPE annotations (`string`, `int`, `enum`, `array<T>`, `object {...}`, etc.)
- orchestrate-flow Step b.i validates each handoff field against its TYPE
- On mismatch → halt `handoff_type_mismatch` (anti-halu rail #15 — prevents silent shape drift)

**BUT** F4 included a bypass rule: `If TYPE annotation absent → log warn-only ("field <name> has no TYPE in schema; skipping type check"); continue`. This bypass effectively turned the gate OFF for every per-skill metric field added since Iter 32 because `handoff-contract.md §Per-skill expected emissions` documented field NAMES but not TYPES at field-level.

Iter 56 audit (Dim C) caught:
- emit-fsd (Iter 54) 7 fields ungated → C-001
- install-deps (Iter 55) 7 fields ungated → C-002
- acceptance_test_concerns (Iter 53) ungated → C-003
- ~50 other per-skill metric fields (estimate) ungated since Iter 32

Iter 59 closed C-001/002/003 by ADDING TYPE annotations to handoff-contract.md. But annotations are advisory until Iter 60 flips the bypass default.

**The fix (Iter 60):**

`orchestrate-flow/SKILL.md` Step b.i flipped from permissive to strict:

**Before (Iter 33-59):**
```
If TYPE annotation absent → log warn-only + continue
```

**After (Iter 60):**
```
Default (strict): emit halt `handoff_type_mismatch` with details
  `{failing_skill, field_name, missing_annotation: true, recommended_fix: "Add TYPE annotation to handoff-contract.md §<skill> §<field>"}`;
  STOP chain.
Legacy bypass: available via `--legacy-type-bypass` flag (for migration scenarios only)
```

The flip turns F4 from "permissive when annotations missing" to "halt-against-author until annotations declared". Skill authors who emit fields without declaring TYPE get immediate halt feedback at the producer boundary — rather than the field silently propagating with drift risk.

**Migration period:**

Users running on pre-Iter-60 plugin AND pre-Iter-59 handoff-contract may hit the new strict check on legacy chain runs. Mitigation:

1. **One-time migration:** run with `--legacy-type-bypass` flag for one chain run; fix author-side TYPE annotations in handoff-contract.md; remove flag.
2. **Production runs:** Iter 59 added TYPE annotations for emit-fsd + install-deps + acceptance_test_concerns. Other per-skill blocks (extract-intelligence, generate-intent, scan-codebase, bind-codebase, generate-units, execute-bolts, diff-vault, emit-agents-md, resolve-oq, detect-drift) STILL HAVE UNTYPED FIELDS in their handoff metric blocks — these will halt on Iter 60+ unless `--legacy-type-bypass` is used.

**Deferred to Iter 61 (catch-all):** sweep the remaining ~50 per-skill metric fields to add TYPE annotations across all per-skill emission blocks. Iter 60 ships the flip + migration flag; Iter 61 sweeps annotations to eliminate the migration need.

**Also added in Iter 60 (TYPE language enhancements):**

- `bool` — explicit boolean primitive (vs implicit `string` for `true`/`false` strings)
- `<T> | null` — nullable variant (e.g., `string | null` for fallback_format field)

These were needed for the Iter 59 emit-fsd/install-deps annotations to fully validate.

**Surface changes:**

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step b.i type-check procedure flipped + 2 new TYPE language entries (bool, T | null); version 3.6.0 → 3.7.0 (MINOR — anti-halu rail behavior change)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.39.1 → 3.40.0
- `plugins/mega-sdd/README.md` — version refs
- `README.md` (root) — version refs
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- `orchestrate-flow` 3.6.0 → 3.7.0 (MINOR — F4 bypass behavior change is anti-halu rail strengthening; backward-incompatible for skills with untyped fields BUT `--legacy-type-bypass` migration flag preserves existing chains during transition)

**Plugin v3.39.1 → v3.40.0** (MINOR — anti-halu rail strengthening; `--legacy-type-bypass` flag covers migration).

**Closure progress:** Iter 56 audit (38 findings) → Iter 57-60 closed 8 P1 + 1 P1 architectural + 4 P2 = 13 of 38. Remaining for Iter 61 catch-all: 18 P2 + 8 P3.

**Rationale per anti-halu posture:** Iter 33 F4's bypass was a pragmatic deferred-strictness during initial v3.24.0 introduction. After 12 minor versions, the bypass became load-bearing for too many ungated fields — turning the gate OFF rather than ON. Flipping the default + providing migration flag is the canonical "make permissive defaults explicit opt-in" pattern from anti-halu literature.

**Audit:** docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md §C-005 architectural insight.

---

## [3.39.1] - 2026-05-26

### Iter 59 — Iter 56 audit contract sweep (C-001/002/003/004 closures)

**Handoff contract completeness pass** (PATCH bump — reference doc additions only; no behavior change in skills). Closes 2 P1 HIGHs + 1 P2 MEDIUM + 1 P2 architectural prep from Iter 56 audit Dim C.

**Closed findings:**

**C-001 (P1) — emit-fsd handoff added to handoff-contract.md Per-skill emissions**

Iter 54 shipped emit-fsd with 7 metrics fields but never added a `### emit-fsd` block to handoff-contract.md `## Per-skill expected emissions`. All emit-fsd handoffs bypassed Iter 33 F4 type-check gate.

Iter 59 adds `### emit-fsd (Iter 54, contract block added Iter 59 per C-001)` block with full TYPE annotations per field:
- `sections_emitted: int (≥0, ≤10)`
- `sections_excluded: int (≥0, ≤10)`
- `citations_count: int (≥0)`
- `drift_callouts_count: int (≥0)`
- `mode: enum (pre-dev | post-dev)`
- `pdf_emitted: bool`
- `fallback_format: enum (null | html | markdown)`

Plus REQUIRED/CONDITIONAL severity per artifact path.

**C-002 (P1) — install-deps handoff added to handoff-contract.md Per-skill emissions**

Same gap as C-001 but for Iter 55. install-deps handoff fields untyped → bypass schema gate.

Iter 59 adds `### install-deps (Iter 55, contract block added Iter 59 per C-002)` block:
- `tools_audited: int (≥0)`
- `tools_already_present: int (≥0)`
- `tools_installed: int (≥0)`
- `tools_failed: int (≥0)`
- `tools_sudo_pending: int (≥0)`
- `detected_os: enum (macos | linux | wsl | windows-bash | unknown)`
- `detected_pkg_mgr: enum (brew | apt | dnf | pacman | apk | winget | scoop | choco | cargo-fallback | none)`

**C-003 (P2) — `acceptance_test_concerns` declared in execute-bolts contract**

Iter 53 added `acceptance_test_concerns: []` to execute-bolts handoff metrics block (the field designed specifically to close producer-only debt) but never declared in handoff-contract.md. Iter 59 closure adds the TYPE annotation `array<object {unit: string, concern: string}>` to execute-bolts Per-skill block via extension subsection.

Iter 59 also extends execute-bolts `status: halted` enumeration in handoff-contract to include the 2 new halts from Iter 58 (`module_blocked_by`, `verify_unit_writable`) + `partial_state_corrupt` (Iter 40) that were previously missing from the halt list.

**C-004 (P2 partial) — `quality_gate_failed` subtype enum**

Iter 58 added `quality_gate_failed` subtype enum to vault-contract.md description block. Iter 59 cross-references it from handoff-contract emit-fsd halted-status: documents that emit-fsd halts on `quality_gate_failed` with `subtype: pdf_render_failed | template_slot_unfilled` per vault-contract Iter 58 closure. Closes the schema half of C-004; behavioral consumer dispatch (orchestrate-flow Step 6.b validation) already correct.

**Surface changes:**

- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — 2 new Per-skill blocks (emit-fsd + install-deps with full TYPE annotations) + 1 execute-bolts extension subsection (acceptance_test_concerns TYPE + halted-status extension) + cross-ref to quality_gate_failed subtypes
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.39.0 → 3.39.1
- `plugins/mega-sdd/README.md` — version refs
- `README.md` (root) — version refs
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- None (reference doc additions only; no skill body behavior change)

**Plugin v3.39.0 → v3.39.1** (PATCH — contract doc additions; no breaking change).

**Closure progress:** Iter 56 audit (38 findings) → Iter 57 (3 P1) → Iter 58 (3 P1 + 2 P2) → Iter 59 (2 P1 + 2 P2). Total closed: 8 P1 + 4 P2 = 12 of 38. Remaining for Iter 60-61: 1 P1 architectural (C-005 F4 bypass tightening) + 18 P2 + 8 P3.

**Note on C-005 (next iter):** Iter 59 closures DEPEND on Iter 60's F4 bypass tightening to make the TYPE annotations enforceable. Currently Iter 33 F4 bypass rule says "fields without TYPE annotation bypass type check" — so the annotations added in Iter 59 are ADVISORY until Iter 60 flips the bypass default. Iter 60 will (a) flip F4 bypass to halt-against-author + (b) sweep remaining per-skill metric fields without TYPE annotations + (c) bump plugin to v3.40.0 MINOR (anti-halu rail behavior change).

**Audit:** docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md §C-001/002/003/004.

---

## [3.39.0] - 2026-05-26

### Iter 58 — Iter 56 audit halt taxonomy sweep (A1-001/002/003 + A2-001/002 closures)

**Halt taxonomy completeness pass** (MINOR bump — extends halt enum with 9 previously-orphan halt types, formally documents `quality_gate_failed` subtype discriminator, adds install-deps preflight catalog section, extends scenario-6 with install-deps + quality_gate_failed-subtype recovery walkthroughs). Closes the 3 P1 HIGHs + 2 P2 MEDIUMs from Dim A of Iter 56 audit.

**Closed findings:**

**A1-001 (P1) — 9 orphan halt types added to canonical enum**

Iter 56 audit caught 9 halt types emitted by producers as `→ halt <name>` / `type: <name>` but missing from `vault-contract.md:569` enum. Per Iter 33 schema validation, orchestrate-flow would have rejected these as `invalid_handoff` (silent-failure-class drift).

Added to enum + full description blocks per §halt-protocol Type-specific guidance:
- `oq_tech_missing_mode` (generate-intent, Iter 28)
- `oq_recommend_underspecified` (generate-intent + bind-codebase, Iter 3)
- `oq_scan_missing_query` (generate-intent, Iter 28)
- `oq_business_p1_unresolved` (orchestrate-flow, Iter 4 — now canonical of legacy `oq_blocker`)
- `no_starterkit_detected` (orchestrate-flow, Iter 27)
- `module_blocked_by` (execute-bolts, Iter 11)
- `hard_rule_unanchored` (execute-bolts, Iter 6)
- `unit_underspecified` (generate-units, Iter 1)
- `verify_unit_writable` (execute-bolts, Iter 1)

Each gets: source skill, ALWAYS-STOP semantics, Details schema, Resolution path.

**A1-002 (P1) — `oq_blocker` deprecated as legacy alias of `oq_business_p1_unresolved`**

Iter 56 audit found `oq_blocker` in enum + description but never explicitly emitted (only soft prose claim at generate-intent SKILL.md:238). Orchestrate-flow taxonomy at line 562 indicates `oq_business_p1_unresolved` is the orch-level canonical. Iter 58 documents the alias relationship explicitly in §halt-protocol: both names accepted during transition; new code should use `oq_business_p1_unresolved` as canonical.

**A1-003 (P1) — `quality_gate_failed` subtype discriminator documented**

Iter 56 audit found 3 subtypes (`starterkit_metrics_inconsistent` Iter 53, `pdf_render_failed` + `template_slot_unfilled` Iter 54) referenced in producer SKILL.md bodies but not in vault-contract canonical description block. Consumer dispatch on `details.subtype` was broken.

Iter 58 adds `#### Iter 58 — quality_gate_failed subtypes` block to vault-contract.md with full subtype enum + per-subtype semantics + producer + resolution. Consumer dispatch logic now MUST branch on `details.subtype` field; if subtype absent/empty, treats as original `wave_quality_threshold_unmet` semantic (extract-intelligence Iter 9).

**A2-001 (P2) — install-deps halts have scenario-6 walkthroughs**

Iter 56 audit: install-deps halts (`install_failed`, `pkg_mgr_not_found`) shipped with Iter 55 but no scenario-6 recovery walkthrough. New users hitting `pkg_mgr_not_found` on fresh Linux VM got only inline `next_action.hint` from halt envelope.

Iter 58 adds `## Scenario walkthrough — install_failed + pkg_mgr_not_found` to scenario-6 covering: pkg_mgr_not_found recovery (macOS/brew install via https://brew.sh, Linux apt PATH verify, Windows WSL install), install_failed recovery (retry single tool, switch pkg manager via override, skip + use fallback, manual install + verify), verify_after_install_failed subtype (PATH refresh via `hash -r`).

**A2-002 (P2) — install-deps preflight checks section added**

Iter 56 audit: every other skill had `### <skill> preflight checks` in `orchestrate-flow/references/predictive-checks.md`; install-deps was the lone exception. orchestrate-flow Step 3.5 dispatched install-deps with zero predictive validation — running blind into halts. Iter 33 UX guarantee ("see precondition errors BEFORE chain starts, not 8 minutes in") regressed for new skill.

Iter 58 adds `## install-deps preflight checks (v3.6.0+, Iter 58)` section with 3 checks:
- `pkg_mgr_detected` (fatal — predicts pkg_mgr_not_found)
- `network_reachable` (warn — predicts install_failed network subtype)
- `memory_writable_for_install_outcomes` (warn — predicts memory_in_use)

**Bonus closure — quality_gate_failed subtype walkthroughs in scenario-6**

Iter 58 also adds `## Scenario walkthrough — quality_gate_failed subtypes (Iter 53/54)` to scenario-6 with 4 sub-recovery paths:
- `pdf_render_failed` → install tectonic via install-deps + retry emit-fsd
- `template_slot_unfilled` → file plugin bug; skip section via `--sections=` override
- `starterkit_metrics_inconsistent` → `scan-codebase --force-deep` then `generate-units --regenerate`
- `wave_quality_threshold_unmet` → existing extract-intelligence walkthrough

Partially closes A2-004 (scenario coverage for subtypes) — remaining A2-004 scope (extract-intelligence base walkthrough enhancement) deferred to Iter 61 catch-all.

**Surface changes:**

- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — enum + descriptions: 9 new halt types + quality_gate_failed subtypes block + oq_blocker deprecation note; version 1.15.1 → 1.16.0
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — new §install-deps preflight checks section (3 checks); version 3.5.0 → 3.6.0
- `tests/scenarios/scenario-6-recovery-from-halt.md` — 2 new walkthroughs (install-deps halts + quality_gate_failed subtypes)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.38.1 → 3.39.0
- `plugins/mega-sdd/README.md` — version refs
- `README.md` (root) — version refs
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- `generate-intent` 1.15.1 → 1.16.0 (MINOR — references/vault-contract.md extended with 9 new halts + subtype discriminator + alias deprecation; halt taxonomy is part of generate-intent's surface contract)
- `orchestrate-flow` 3.5.0 → 3.6.0 (MINOR — references/predictive-checks.md gains new §install-deps preflight section)

**Plugin v3.38.1 → v3.39.0** (MINOR — halt enum extension + new predictive-check section; backward-compatible since adding enum members doesn't break existing handoff validation; only enables previously-rejected halt names).

**Closure progress:** Iter 56 audit (38 findings: 8 P1 / 22 P2 / 8 P3) → Iter 57 closed 3 P1s (B-P1, D1, F-E-2) → Iter 58 closes 3 P1s (A1-001/002/003) + 2 P2s (A2-001/002) + partial A2-004. Remaining: 2 P1s (C-001, C-002 → Iter 59) + 1 P1 architectural (C-005 → Iter 60) + 19 P2s + 8 P3s (→ Iter 61 catch-all).

**Audit:** docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md §A1-001/002/003 + §A2-001/002.

---

## [3.38.1] - 2026-05-26

### Iter 57 — Iter 56 audit CRITICAL fix-forward (3 P1 safety/regression closures)

**Release-blocker fix iter** (PATCH bump — pure correctness; no new behavior). First closure iter of Iter 56 deep audit which identified 38 findings (8 P1 / 22 P2 / 8 P3). Iter 57 closes the 3 P1s that represent real safety/regression issues; remaining P1s + P2s + P3s scheduled across Iter 58-61.

**CRITICAL fixes:**

**B-P1 — Iter 53 chain optimization was DEAD CODE (regression class repeat — fourth instance)**

Iter 53 (consumer wiring closure) added orchestrate-flow Step 3 chain optimization that reads `binding_metadata.codebase_map_provenance` from binding.md header. Iter 56 audit found that **bind-codebase Step 4 binding.md template never emits the field** — only declared in procedure prose (Step 1, Iter 46). Same regression class as Iter 43 (handoff_missing file-check vs chat-block), Iter 48 (algorithm-doc-vs-prompt drift), and Iter 52 (GLOSSARY_INDEX placeholder unwired). Worst irony: the regression was introduced BY the Iter 53 proactive audit that was supposed to catch this class — Iter 53 wired the consumer but never verified producer template emits the field.

Fix: added `binding_metadata` block to binding.md frontmatter template per bind-codebase/SKILL.md Step 4 (line 374 onwards). Now Iter 53 chain optimization actually fires per Iter 46's promised 30-50% chain-level savings.

**Process implication captured in audit Insight 1:** "Wire consumer when wiring producer" rule needs companion rule "verify producer template emits the field that consumer reads". Cannot be done by reference-doc grep alone — must verify against actual emission template. Tracked as v4.0.0 candidate (CI enforcement mechanism).

**D1 — Iter 45 `--rollback` rail REVERSED (default safe → default DANGEROUS)**

execute-bolts `--rollback` menu (Iter 45 saga compensating actions) documented as "default safe for non-idempotent" but actual menu offered `[Y] proceed` as BATCH-APPLY of ALL compensating actions including non-idempotent ones (composer dep removes, migration rollbacks). Only `[I] interactive` matched the documented safe default. Real-world data loss risk: user picks `[Y]` (the default key) and accidentally triggers non-idempotent compensating actions on dep manifests / migrations.

Fix: flipped menu order so `[I] interactive` is listed FIRST as DEFAULT with explicit "safe for non-idempotent steps" label. `[Y]` relabeled to "batch-apply all actions including non-idempotent (DANGEROUS — composer/migration removes happen without per-step confirmation)" to make consequences explicit. Anti-halu rail enforcement now matches documented behavior.

**F-E-2 — Plugin README header stuck at v3.18.1 (20 versions stale)**

`plugins/mega-sdd/README.md:5` declared `**Version:** 3.18.1 · **License:** MIT` while plugin.json reported 3.38.0. The Iter 54 + Iter 55 README audit passes updated the folder layout block ("plugin manifest (v3.X.X)") and the What's-new section, but never touched the page header — the header lives in a separate region not covered by earlier audit grep patterns.

Fix: one-line edit `3.18.1 → 3.38.1` (this iter's bump). Added to next iter's README audit checklist.

**Surface changes:**

- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 4 binding.md template gains `binding_metadata:` block in frontmatter (closes B-P1); version 1.10.3 → 1.10.4
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — `--rollback` menu reordered + relabeled (closes D1); version 2.10.0 → 2.10.1
- `plugins/mega-sdd/README.md` — header version 3.18.1 → 3.38.1 (closes F-E-2); folder layout 3.38.0 → 3.38.1
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.38.0 → 3.38.1
- `README.md` (root) — header version + tree layout + Versioning section all 3.38.0 → 3.38.1
- `CHANGELOG.md` — this entry

**Skill version bumps:**
- `bind-codebase` 1.10.3 → 1.10.4 (PATCH — template emission fix-forward, no new behavior)
- `execute-bolts` 2.10.1 → 2.10.1 (PATCH — menu reorder for safety, no new behavior)

**Plugin v3.38.0 → v3.38.1** (PATCH — fix-forward; pure correctness; no new functionality).

**Standing directives applied:**
- simplifikasi: 3 P1 fixes in single atomic commit; minimum file touches (3 files modified for fixes + 4 for version refs)
- flawless: all 3 P1s closed BEFORE next feature work; Iter 57 ships first per audit closure plan
- reuse-first: no new patterns introduced; B-P1 fix uses existing frontmatter template; D1 fix uses existing AskUserQuestion option ordering; F-E-2 fix is wording-only

**Closure trace:** Iter 56 audit (P1s) → Iter 57 fix-forward (this entry) → Iter 58-61 P1/P2/P3 closure queue continues.

**Audit source:** `docs/superpowers/audits/2026-05-26-iter-56-v3.38.0-deep-audit.md` §P1 HIGH findings (8 total; this iter closes B-P1 + D1 + F-E-2). Remaining 5 P1s (A1-001/002/003, C-001/002) targeted in Iter 58 + 59.

---

## [3.38.0] - 2026-05-25

### Iter 55 — OS-Aware Auto-Install Deps (new skill `install-deps`)

**User-driven feature post-Iter-54.** Dependency install friction surfaced after Iter 54 shipped `emit-fsd` (FSD generator needs pandoc + tectonic for PDF rendering). User asked for OS-aware auto-install + cross-platform detection. Research-driven: cross-platform shell OS detection canonical patterns ([GitHub gist](https://gist.github.com/gmolveau/d0e3efc219c5bcc6ecc13a1405ac6c73)), auto-install security consensus ([npm best practices](https://github.com/lirantal/npm-security-best-practices), [Snyk](https://snyk.io/blog/ten-npm-security-best-practices/), [Pluralsight](https://www.pluralsight.com/resources/blog/cybersecurity/tools-for-safeguarding-app-dependencies)), Claude Code Bash-via-skill model ([Claude Code docs](https://code.claude.com/docs/en/overview)).

**Pipeline addition (parallel to existing chain — install-deps is user-explicit, NOT auto-invoked):**

```
User invokes /mega-sdd:install-deps directly when:
  - Fresh mega-sdd install (bootstrap optional native binaries)
  - Predictive-checks warn (e.g., pandoc_installed: warn from emit-fsd)
  - Cross-machine re-sync (memory layer skips already-installed)
```

**New skill: `mega-sdd:install-deps` (v1.0.0)**

- **Trigger:** standalone (`/mega-sdd:install-deps [flags]`) — NOT auto-invoked per safety consensus (install is user-explicit; orchestrate-flow predictive-checks just HINT to run the skill, don't run it themselves)
- **Output:** `<project>/.mega-sdd/memory/install-outcomes.md` (memory log of install runs) + chat-only progress + verify output
- **OS detection:** canonical Bash algorithm in `references/os-detection.md`:
  - `darwin*` → macos
  - `linux-gnu*` + `microsoft` in uname → wsl
  - `linux-gnu*` (no microsoft) → linux + distro detection via `/etc/os-release` `ID=`
  - `msys*` / `cygwin*` → windows-bash (git-bash / MSYS2)
- **Package manager detection** (primary per OS):
  - macOS → brew
  - Ubuntu/Debian/Linuxmint/Pop/elementary → apt
  - Fedora/RHEL/CentOS/Rocky/Alma/Amazon Linux → dnf (or yum legacy)
  - Arch/Manjaro/EndeavourOS/Garuda → pacman
  - Alpine → apk
  - Windows-bash → winget (Win10/11) / scoop (dev-focused) / choco (legacy)
- **Cross-platform fallbacks:** cargo (Rust tools: tree-sitter-cli, ast-grep, ripgrep, tectonic), npm (Node tools: markdownlint-cli2, tree-sitter-cli, @ast-grep/cli), go install (Go tools: jd)

**Tool matrix (8 tools in `references/tool-matrix.yaml`):**

| Tool | Used by | Fallback when missing |
|---|---|---|
| `tree-sitter` (or `tree-sitter-cli`) | scan-codebase v2.0+ AST extraction | Regex engine (lower precision) |
| `ast-grep` | execute-bolts v2.0+ Hard Rule v2 grammar | v1 grammar (5 closed types) |
| `ripgrep` (`rg`) | scan + bind + detect-drift + lint-units | GNU grep (slower; no JSON) |
| `jd` | diff-vault (canonical JSON/YAML diff) | Manual Read+compare via skill body |
| `pandoc` (Iter 54) | emit-fsd PDF rendering | Markdown-only output |
| `tectonic` (Iter 54) | emit-fsd LaTeX engine | HTML output (browser print-to-PDF) |
| `markdownlint-cli2` | lint-units vault prose | Skill-internal heuristic checks |
| `gh` | execute-bolts PR automation (optional) | Manual PR creation |

**6-step procedure** (per `skills/install-deps/SKILL.md`):

1. **Detect env** — OS + pkg manager + cross-platform fallbacks
2. **Audit inventory** — memory cache check + `verify_cmd` per tool
3. **Build install plan** — matrix lookup + fallback chain + sudo separation
4. **Propose + confirm** — AskUserQuestion with [Install all] / [Pick subset] / [Cancel]; `--dry-run` and `--manual` paths skip execution
5. **Execute** — Bash invocation per tool, per-tool progress, continue on failure (don't abort batch)
6. **Verify** — `verify_cmd` after each install; mark unverified for halt
7. **Memory write** — Iter 5 file-lock pattern; outcomes appended to install-outcomes.md
8. **Summary + handoff** — chat summary + handoff YAML under `--auto`

**Safety rails (non-negotiable):**

1. **NEVER auto-`sudo`** — for tools requiring elevation (apt/dnf installs), skill PRINTS the command + instructs user to run manually. Memory records as "sudo-pending" status.
2. **NEVER use curl|bash patterns** — only signed package manager commands per `tool-matrix.yaml`.
3. **ALWAYS show exact `install_cmd` + source pkg manager + size estimate BEFORE running** — single batch confirmation via AskUserQuestion.
4. **ALWAYS verify post-install** with `verify_cmd` from matrix — claim "installed" only after verify passes.
5. **NEVER install Claude Code itself** — out of scope; this skill installs OPTIONAL mega-sdd deps only.
6. **Memory write happens AFTER verify pass** — never record "installed" on partial state.
7. **Skip tools with no matching matrix entry AND no working fallback** — emit warning, don't halt entire batch.

**2 new halt types** (added to `vault-contract.md §halt-protocol type enum`):
- `install_failed` — install command exited non-zero OR `verify_cmd` failed post-install. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail, subtype}`.
- `pkg_mgr_not_found` — no compatible package manager detected for OS. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`.

**Predictive-checks hint update** (no behavior change — discoverability):

3 existing tool-presence checks in `orchestrate-flow/references/predictive-checks.md` get suffix `"...OR run /mega-sdd:install-deps for auto-install (Iter 55+)."`:
- `tree_sitter_present`
- `pandoc_installed`
- `pandoc_latex_engine_present`

**Iter 54 drift closure (incidental):** `emit-fsd` was added as a skill in Iter 54 but never added to the `source_skill` enum in vault-contract.md. Iter 55 added both `emit-fsd` and `install-deps` to the enum in the same commit (T7).

**Files created (4):**
- `plugins/mega-sdd/skills/install-deps/SKILL.md` (~190 lines, 10.5KB)
- `plugins/mega-sdd/skills/install-deps/references/os-detection.md` (canonical Bash detection algorithm, 4.7KB)
- `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml` (8-tool × OS × pkg_mgr matrix, 7.1KB)
- `plugins/mega-sdd/commands/install-deps.md` (slash command wrapper, 2.2KB)

**Files modified (5):**
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — 3 hint suffixes appended
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — 2 new halt types in enum + descriptions; source_skill enum updated (emit-fsd Iter 54 drift + install-deps Iter 55)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.37.0 → 3.38.0
- `CHANGELOG.md` — this entry
- `plugins/mega-sdd/README.md` — version refs + folder layout + What's new
- `README.md` (root) — version refs + skill count 14→15 + command count 21→22 + cheat-sheet

**Skill version bumps:**
- New skill `install-deps` 1.0.0 (initial release)
- No existing skill versions changed (predictive-checks.md and vault-contract.md are reference files; their parent skills retain prior versions per plugin convention)

**Out of scope (deferred):**

- **Iter 56+**: Windows native PowerShell variant (winget/scoop without WSL)
- **Iter 57+**: Auto-update detection (`brew outdated` / `apt list --upgradable` → suggest updates)
- **Iter 58+**: Signed Anthropic apt/dnf repo bootstrap for Claude Code itself
- **Iter 59+**: Air-gapped install mode (bundle binaries offline)
- **Iter 60+**: Integration with project lockfile (e.g., `mega-sdd.deps.lock` for reproducible env)

**Standing directives applied:**

- **simplifikasi**: 1 new skill (with 2 reference files + 1 command) + 3 surface touches in existing files; no new schema (tool-matrix.yaml is internal config, not vault contract); minimum new files
- **flawless**: producer (install-deps) + consumer (orchestrate-flow predictive-checks hints + vault-contract halt enum) ship same iter — atomic; structural smoke test passed (8 tools, 4 OS branches, 7 pkg managers, 3 predictive-check hints, 3 halt mentions)
- **reuse-first**: emit-fsd skill anatomy (analog template); Iter 33 predictive-checks pattern (hint extension); Iter 5 memory layer (install-outcomes.md analog to bolt-outcomes.json); existing `tooling-install.md` matrix promoted to YAML + extended with Iter 54 deps (pandoc/tectonic); AskUserQuestion for batch confirmation (standard Claude Code pattern); no new halt envelope (reuses existing schema with new type enum entries)

**Plugin v3.37.0 → v3.38.0** (MINOR — new skill, backward-compatible: install is user-explicit so no impact on existing auto-pipeline runs; predictive-check hint update is doc-only suffix).

**Process trace:** user request → research dispatch (3 parallel WebSearch queries + WebFetch for OS detection patterns) → recommendation with tradeoffs → user approval ("ok approved") → spec doc → implementation plan (9 atomic tasks) → inline execution per simplifikasi standing directive (literal-paste markdown content; subagent dispatch overhead unwarranted for prescriptive content). All 9 tasks committed atomically.

**Audit source:** user feedback after real-project field test of Iter 54 emit-fsd ("tambahan dll, gue pengen lo sendiri yg invoke buat install. dan bisa detecs misal mac gimana, windows gimana, ubuntu gimana"). Brainstorming session 2026-05-25 with single research → recommendation → user approval cycle.

---

## [3.37.0] - 2026-05-25

### Iter 54 — FSD Auto-Generation (new skill `emit-fsd`)

**New feature — corporate FSD deliverable.** User feedback after real-project field test: "di kantor gue wajib FSD sebagai confluence, bisa ga skill ini generate FSD secara otomatis. dan fsd nya akurat". Iter 54 adds dedicated FSD emitter skill grounded on actual vault/units/bolts/binding state — no fabrication, all citations sha256-stamped, drift detection on re-emit.

**Pipeline addition:**

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield)
  → generate-units → execute-bolts → emit-agents-md → emit-fsd (NEW Iter 54)
```

**New skill: `mega-sdd:emit-fsd` (v1.0.0)**

- **Trigger:** standalone (`/mega-sdd:emit-fsd [vault]`) + auto-invoked at end of `/mega-sdd:auto` pipeline (skip via `--no-fsd`)
- **Output:** `<vault>/fsd/FSD.md` + `<vault>/fsd/FSD.pdf` + `<vault>/fsd/FSD.styling.yaml` + `<vault>/fsd/.citation-map.json`
- **PDF rendering:** pandoc + xelatex (or tectonic) for PDF; HTML fallback when LaTeX absent; markdown-only fallback when pandoc absent (predictive checks warn user)
- **Template:** Hybrid Confluence Atlassian template — 10 sections: Overview, Goals & Non-Goals, Stakeholders & Owners, User Stories, Functional Requirements, Non-Functional Requirements, Design & Architecture, API & Data Contracts, Test Plan & UAT, Risks & Open Issues

**Mode auto-detection:**

| CWD state | Mode | Section behavior |
|---|---|---|
| Vault only (no units, no bolts) | `pre-dev` | Sections 1-8 + 10 populated; section 9 = "TBD pending execution" |
| Vault + units (no bolts) | `pre-dev` (with breakdown) | Section 4 from units; section 9 = "Specified pending execution" |
| Vault + units + bolts | `post-dev` | All 10 sections; section 9 = actual UAT results + as-built per-FR status |

User override via `--mode={pre-dev|post-dev|auto}` flag.

**Anti-hallucination guarantee (the "akurat" claim):**

- Every FSD section text traces to source artifact via `.citation-map.json`
- Source artifacts cited with file path + line range + sha256 stamp (computed at emit-time)
- Missing source → emit `[Pending — <source> not yet generated]` placeholder; NEVER fabricate
- Slot markers `{{slot_name}}` all filled OR explicitly placeholdered (empty slot = halt `quality_gate_failed:template_slot_unfilled`)
- Re-emit detects sha256 changes; inserts ⚠ "Updated since last emit" callout in PDF before regenerated sections (auditability for reviewers)

**Source-of-truth mapping per section:**

| FSD Section | Source artifact |
|---|---|
| 1. Overview | `vault/01-overview.md` §Purpose + §Scope |
| 2. Goals & Non-Goals | `vault/01-overview.md` §Goals + §Non-Goals |
| 3. Stakeholders & Owners | `vault/_meta/squads.yaml` + `vault.json` author |
| 4. User Stories | `units/U-NNN.md` frontmatter |
| 5. Functional Requirements | `vault/02-functional.md` FR-NNN entries |
| 6. Non-Functional Requirements | `vault/02-functional.md §NFR` + `vault/_meta/constitution.md` |
| 7. Design & Architecture | `binding.md` §Confirmed Claims + `codebase-map.md` §Entities/Modules |
| 8. API & Data Contracts | `codebase-map.md` §Public interfaces (with `Last_Scanned_Sha256` per Iter 46) |
| 9. Test Plan & UAT | `bolts/U-NNN/bolt-report.md` acceptance_test result + self-assessment |
| 10. Risks & Open Issues | `vault/03-open-questions.md` unresolved OQs + bolt `acceptance_test_concerns` (Iter 53) |

**Styling customization** (per-project override at `<vault>/fsd/FSD.styling.yaml`):

- `company_name`, `logo_path`, `classification` (Internal/Confidential/Public)
- `font_family`, `font_size_pt`, `accent_color`, `page_size` (A4/Letter)
- `include_sections` (subset for stakeholder-specific FSDs)
- `include_citation_footnotes`, `include_drift_callouts`, `include_provenance_trailer`
- ID corporate convenience presets: `banking_indonesia`, `telco_indonesia`

**Predictive checks added (3, all in `orchestrate-flow/references/predictive-checks.md`):**

- `vault_present_for_fsd` — fatal (predicts `dep_missing`)
- `pandoc_installed` — warn (degrades to markdown-only)
- `pandoc_latex_engine_present` — warn (degrades to HTML fallback)

**orchestrate-flow extension (v3.4.0 → v3.5.0):**

- Step 6 auto-integrated diagnostics table +1 row for emit-fsd
- Skip via `--no-fsd` flag on `/mega-sdd:auto` or `/mega-sdd:orchestrate-flow`

**Files created (6):**
- `plugins/mega-sdd/skills/emit-fsd/SKILL.md` (~200 lines, 9.7KB)
- `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md` (10-section canonical template, 5.2KB)
- `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md` (extraction rules per section, 10.1KB)
- `plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml` (default styling + override schema, 2.8KB)
- `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex` (LaTeX template, 2.8KB)
- `plugins/mega-sdd/commands/emit-fsd.md` (slash command wrapper, 2.6KB)

**Files modified (7):**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 6 diagnostics table + version bump
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — 3 new checks
- `plugins/mega-sdd/commands/auto.md` — `--no-fsd` flag doc
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.36.0 → 3.37.0
- `CHANGELOG.md` — this entry
- `plugins/mega-sdd/README.md` — version refs + What's new
- `README.md` (root) — version bump

**Out of scope (deferred):**

- **Iter 55+**: Cross-scope FSD consolidation (`/mega-sdd:emit-fsd --consolidate=BE,MW,FE`)
- **Iter 56+**: Confluence REST API direct push (with auth handling)
- **Iter 57+**: FSD-to-FSD diff tool (`/mega-sdd:diff-fsd v1.pdf v2.pdf`)
- **Iter 58+**: Indonesian translation pass
- **Iter 59+**: Strict-citation mode (`--strict-citation` halts on any drift)

**Standing directives applied:**

- **simplifikasi**: 1 new skill (with 4 reference files + 1 command) + 3 surface touches in existing files; no new halt types (reuses `quality_gate_failed` + `dep_missing`); no runtime code (markdown-driven per plugin design principle)
- **flawless**: producer (emit-fsd) + consumer (orchestrate-flow Step 6 + predictive-checks + auto.md flag) ship same iter — atomic; structural verification passed (slot coverage + citation-map.json schema + cross-reference integrity)
- **reuse-first**: extends emit-agents-md skill anatomy (analog pattern), Iter 33 predictive-checks pattern (3 new entries), Iter 13 auto-integrated diagnostics pattern (extension), citation discipline from binding.md (sha256 + line ranges), Iter 53 acceptance_test_concerns consumer (section 10 Risks)

**Skill version bumps:**
- New skill `emit-fsd` 1.0.0 (initial release)
- `orchestrate-flow` 3.4.0 → 3.5.0 (MINOR — new diagnostic surface)

**Plugin v3.36.0 → v3.37.0** (MINOR — new skill, backward-compatible: existing pipelines unchanged; skip flag works for users who don't want FSD).

**Process trace:** brainstorming session (user-approved each design section) → spec doc (`docs/superpowers/specs/2026-05-25-iter-54-fsd-auto-generation-design.md`) → implementation plan (`docs/superpowers/plans/2026-05-25-iter-54-fsd-auto-generation.md`, 12 atomic tasks) → inline execution per simplifikasi standing directive (literal-paste markdown plan; subagent dispatch overhead unwarranted for prescriptive content). All 12 tasks committed atomically.

**Audit source:** user feedback during real-project test ("di kantor gue wajib FSD sebagai confluence"). Brainstorming session 2026-05-25 with single-user-approval per design section.

---

## [3.36.0] - 2026-05-25

### Iter 53 — Consumer wiring closure: producer-only fields → end-to-end USED

**Post-audit closure pass — self-initiated meta-audit.** After Iter 38 audit closure officially completed in Iter 52, ran a proactive meta-audit asking: "is every artifact produced by each pipeline phase actually consumed downstream, or do we emit producer-only fields that no consumer reads?" — addressing the user's question "apakah semua output itu di gunakan? jangan sampe useles dari setiap pipeline".

**Audit method:** dispatched Explore subagent with explicit producer→consumer matrix mandate covering all 11 pipeline skills. Result: zero full orphans; **3 PARTIAL findings** (producer-only emissions whose documented consumer never read the field). All 3 are the same regression class as Iters 43/48/52 fix-forwards: documentation declares behavior that isn't wired into the consumer body.

**Wired (3 consumers, atomic):**

**C1 — `binding_metadata.codebase_map_provenance` (Iter 46 producer-only)**

- **Producer**: bind-codebase Step 1 writes `snapshot-verified | snapshot-stale | no-snapshot` to binding.md header.
- **Pre-Iter-53 state**: field documented in bind-codebase SKILL.md line 41 as "downstream consumers (generate-units, execute-bolts) can trust the codebase-map is current" and as "observable savings: orchestrate-flow chains skip a scan-codebase invocation" — but grep across generate-units, execute-bolts, orchestrate-flow found ZERO reads of the field.
- **Consumer wired (Iter 53)**: orchestrate-flow Step 3 chain optimization (v3.4.0+) reads the field after building the chain. When `snapshot-verified` AND source files unchanged → REMOVES scan-codebase from the proposed chain (delivers the 30-50% chain-level savings the Iter 46 wording promised). When `snapshot-stale` → retains scan-codebase with rationale log. When `no-snapshot` → no-op (pre-Iter-46 baseline).
- **Side-effect**: bind-codebase SKILL.md line 41 wording corrected to cite the now-wired consumer; version 1.10.2 → 1.10.3.

**C2 — `units_with_starterkit_*` metrics (Iter 32 producer-only)**

- **Producer**: generate-units handoff emits `units_with_starterkit_anchors` + `units_with_starterkit_rules` counts.
- **Pre-Iter-53 state**: metrics defined in generate-units SKILL.md lines 779-794, mirrored to handoff-contract.md lines 356-357, but no consumer cross-checked the values against upstream `starterkit-context.yaml` `partial:` flag. Pure observational telemetry — orchestrate-flow received the numbers but never validated them.
- **Consumer wired (Iter 53)**: orchestrate-flow Step 6.b.ix new cross-metric consistency check (v3.4.0+). After validating generate-units handoff schema, also cross-checks: IF `units_with_starterkit_rules > 0` AND `starterkit_context.partial == true` → halt `quality_gate_failed` with subtype `starterkit_metrics_inconsistent` and evidence "generate-units pulled Hard Rules from a partial starterkit slice — rules may reference incomplete framework conventions". Reuses existing `quality_gate_failed` halt envelope — NO new halt type added.
- **Extensibility**: Step 6.b.ix designed as conditional gating pattern (`IF sub-skill == <name>`) — future producers may add their own consistency rules following the same skeleton.
- **Side-effect**: generate-units SKILL.md handoff metrics block gains 5-line YAML comment citing the now-wired consumer; version 2.7.0 → 2.7.1.

**C3 — `acceptance_test_concern:` self-assessment field (Iter 47 producer-only)**

- **Producer**: bolt subagent writes `acceptance_test_concern: <details>` in bolt-report.md `bolt_self_report` block per Iter 47 D4-006 contract when implementation passes acceptance test but feels under-validated (weak blind-spot coverage signal).
- **Pre-Iter-53 state**: bolt-dispatch-prompt.md line 73 instructed bolt to emit the field; execute-bolts SKILL.md line 163 documented the NOTE injection logic — but no execute-bolts post-flight step scanned the field, and no orchestrate-flow surface displayed it. The bolt subagent's signal had no consumer; the field rotted in bolt-reports unread.
- **Consumer wired (Iter 53)**: 
  1. execute-bolts new §Post-flight acceptance-test concern harvest section (v2.10.0+) — scans every bolt-report.md after write, aggregates non-empty values into in-memory list, logs warning per affected bolt, surfaces aggregate via existing `_summary.md` rollup mechanism (new "## Acceptance-test concerns" sub-section).
  2. execute-bolts handoff `metrics.acceptance_test_concerns: [{unit, concern}]` array (NEW field) carries the aggregate to orchestrate-flow.
  3. orchestrate-flow Step 7 final summary diagnostics surface (v3.4.0+) — when array non-empty, displays: "⚠ N/M bolts flagged acceptance_test_concern — review for under-validation: <unit_id list>. Consider re-running affected units with adversarial-reviewed acceptance tests (run /mega-sdd:generate-units --regenerate --adversarial-subagent --units=<list>)."
- **Severity**: warning (NOT halt) — concerns invite re-validation, don't fail the chain. Re-validation path reuses Iter 47 mechanism (`--regenerate --adversarial-subagent`).

**Surface changes:**

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 3 chain optimization sub-bullet (+9 lines); Step 6.b.ix new validation sub-step (+10 lines); Step 7 diagnostics summary surface line (+1 line); version 3.3.0 → 3.4.0
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — new §Post-flight acceptance-test concern harvest section (+15 lines); handoff metrics block gains `acceptance_test_concerns: []` (+6 lines); version 2.9.1 → 2.10.0
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — line 41 wording cites orchestrate-flow Step 3 as consumer; version 1.10.2 → 1.10.3
- `plugins/mega-sdd/skills/generate-units/SKILL.md` — handoff metrics block gains consumer-wiring comment; version 2.7.0 → 2.7.1
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.35.1 → 3.36.0
- `plugins/mega-sdd/README.md` — + v3.36.0 What's new entry
- `README.md` — version bump

**Skill version bumps:**
- `orchestrate-flow` 3.3.0 → 3.4.0 (MINOR — new chain optimization path + new validation sub-step + new summary surface)
- `execute-bolts` 2.9.1 → 2.10.0 (MINOR — new post-flight scan section + new handoff field)
- `bind-codebase` 1.10.2 → 1.10.3 (PATCH — wording correction citing now-wired consumer)
- `generate-units` 2.7.0 → 2.7.1 (PATCH — comment annotation citing now-wired consumer)

**Audit findings verified (zero false positives):**

| Field | Producer | Pre-Iter-53 consumers found via grep | Status |
|---|---|---|---|
| `binding_metadata.codebase_map_provenance` | bind-codebase §Step 1 | 0 (only README docs reference it) | PARTIAL → USED |
| `units_with_starterkit_anchors`/`_rules` | generate-units handoff | 0 (only handoff-contract.md mirrors it) | PARTIAL → USED |
| `acceptance_test_concern` | bolt subagent (bolt-report.md) | 0 (only bolt-dispatch-prompt.md + execute-bolts NOTE write site) | PARTIAL → USED |

**Standing directives applied:**

- **simplifikasi**: 3 PARTIAL findings → 1 atomic iter (no per-finding iters); minimum new files (ZERO — all edits to existing skills); reuses existing halt envelopes (`quality_gate_failed`) — no new halt type added; no new schema files
- **flawless**: producer + consumer ship in-iter (no "defer to next iter" excuse); all 3 wirings atomic in one commit; pre-flight verification via grep before writing each edit
- **reuse-first**: extends Iter 33 predictive-checks/validation-gate patterns; reuses Iter 32 starterkit-context.yaml `partial:` field as consistency anchor; reuses Iter 47 bolt subagent self-assessment field; reuses Iter 46 binding_metadata write site; reuses existing `_summary.md` rollup for aggregate surfacing

**Plugin v3.35.1 → v3.36.0** (MINOR — backward-compatible: new optimization path skips work when conditions met but doesn't change behavior when conditions don't hold; new halt subtype reuses existing envelope; new handoff field is optional, absence is valid)

**Pattern reinforced for future cumulative-iter sessions:** post-audit closure (Iter 38 audit) → proactive meta-audit (Iter 53 producer→consumer mapping) is now part of release discipline alongside validation-gate code review. Validation gates caught 4 release-blockers REACTIVELY across 3 fix-forwards; this meta-audit caught 3 PARTIAL findings PROACTIVELY before they became release-blockers. Tactic worth repeating after every minor release.

**Audit source:** self-initiated post-Iter-52 meta-audit. Triggered by user question "apakah semua output itu di gunakan? jangan sampe apa yg sudah di generate as ouput itu tidak digunakan dengan optimize. maksudnya jangan sampe useles dari setiap pipeline".

---

## [3.35.1] - 2026-05-25

### Iter 52 — FIX-FORWARD #3: wire GLOSSARY_INDEX into wave dispatches + resolve-oq inline lock note + vault-contract wording correction

**Release-blocker fix iter** (PATCH bump — pure correctness; no new behavior). THIRD fix-forward iter triggered by validation gate this session. Cumulative code-quality review of Iters 49-51 (`superpowers:code-reviewer` on commits 6513086..HEAD) surfaced 2 CRITICAL + 1 MEDIUM.

**Pattern repeat:** both critical findings match the same regression pattern as Iters 43 and 48 — documentation declared a behavior that wasn't actually wired into the consumer body. Validation gate caught it before production impact in all 3 cases. Pattern is now load-bearing for cumulative-iter work.

**CRITICAL fixes:**

**C1 — Iter 51 `<GLOSSARY_INDEX>` placeholder unwired**

Iter 51 defined the `<GLOSSARY_INDEX>` placeholder in a standalone section at the top of `wave-dispatch-templates.md` BUT did NOT inject the placeholder into the actual Wave 2/3/4 subagent dispatch prompts. Subagents at runtime would have followed the existing skeleton (which doesn't reference the placeholder) — the optimization would have produced zero savings until the placeholder reached the prompts.

Same regression class as Iter 48's C1 fix (bolt-dispatch-prompt.md algorithm encoded old Iter 30 single-halt behavior while SKILL.md described new Iter 44 running-budget tracker). Caught by validation gate.

Fix: wired `<GLOSSARY_INDEX>` block into the **Generic agent prompt structure** skeleton in `wave-dispatch-templates.md` (which auto-applies to every wave dispatch). Added inline subagent instructions: use INDEX for cross-refs, spot-read glossary.md only with offset/limit, cite with line ranges. Wave 1 skipped (glossary doesn't exist yet — Wave 1 creates it); Wave 5 skipped (main-thread, no subagent).

**C2 — Iter 49 resolve-oq vault.json lock note missing inline**

Iter 49 added §Concurrency contract section to `vault-contract.md` listing 4 vault.json writers (generate-intent, bind-codebase, diff-vault, resolve-oq). The first 3 received explicit inline lock acquisition notes in their SKILL.md. resolve-oq did NOT — its SKILL.md Step 2c step 9 (writing vault.json after Resolve / Out-of-Scope / Defer outcomes) had zero lock acquisition note.

Plus `vault-contract.md` line 84 parenthetical claimed resolve-oq was "already file-lock-disciplined via memory subsystem" — incorrect. Iter 5's file-lock pattern is for the MEMORY subsystem (`~/.mega-sdd/memory/` + `<project>/.mega-sdd/memory/` files), not resolve-oq's vault.json regen.

Fix:
- Added inline lock acquisition note to `resolve-oq/SKILL.md` Step 2c step 9 (covers all 3 outcome paths — Resolve / Out-of-Scope / Defer)
- Bumped resolve-oq 0.9.2 → 0.9.3
- Corrected `vault-contract.md` §Concurrency contract resolve-oq line: now reads "v0.9.3+ Iter 52 fix-forward added explicit inline lock acquisition note; pre-v0.9.3 versions had no explicit lock note despite being listed here"

**MEDIUM fix (spec hygiene):**

Iter 49 spec (`docs/superpowers/specs/2026-05-25-iter-49-vault-lock-and-scenario-expansion-design.md`) §1 + §3 + §4 listed only 3 writers (generate-intent, bind-codebase, diff-vault). Execution added resolve-oq as 4th writer without spec amendment. Not fixed in spec doc (would require post-hoc edit); flagged here in CHANGELOG as documentation drift. Future iters: amend spec OR add resolve-oq to spec writer list at execution time, not retrofit.

**ADVISORY (no action — verified clean):**

- Halt taxonomy preserved correctly across Iters 49-51 — no accidental `vault_in_use` introduced; `memory_in_use` reused as documented
- Predictive checks (Iter 50): all 6 new sections present, 10 skills covered, math checks out (8 → 26 checks)
- extract-intelligence wave counts (3/4/5/3 parallel per wave) are NOT collapsed to new default-3; this is intentional (wave-design dispatches fixed agent counts per wave; `--max-parallel` is a separate cap). No drift
- Version bumps consistent: plugin.json + CHANGELOG + READMEs + skill frontmatter all aligned

**Surface changes:**
- `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` — `<GLOSSARY_INDEX>` block wired into Generic agent prompt structure skeleton with inline subagent instructions
- `plugins/mega-sdd/skills/resolve-oq/SKILL.md` — Step 2c step 9 lock acquisition note added; version 0.9.2 → 0.9.3
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — §Concurrency contract resolve-oq line corrected (misleading parenthetical removed)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.35.0 → 3.35.1
- `plugins/mega-sdd/README.md` — + v3.35.1 What's new entry
- `README.md` — version bump

**Skill version bumps:**
- `resolve-oq` 0.9.2 → 0.9.3 (PATCH — explicit lock note)

**Validation pattern this session — final summary:**

| Validation | Caught | Severity |
|---|---|---|
| Round 1 (after Iter 42) | Iter 40 handoff_missing semantics (file-check vs chat-block) | release-blocker |
| Round 2 (after Iter 47) | Iter 44 algorithm-doc drift + Iter 46 step misplacement + Iter 46 wording | 2 release-blockers + 1 medium |
| Round 3 (after Iter 51) | Iter 51 GLOSSARY_INDEX unwired + Iter 49 resolve-oq lock note missing | 2 release-blockers |

**Lessons captured:** every cumulative-iter session that ships ≥3 feature iters should run advisor + code-reviewer subagent before continuing. Common defect pattern: documentation declares behavior in reference docs / contract files that isn't actually wired into the consumer body. Pure feature velocity misses this; validation gate catches it.

**Standing directives applied:**
- simplifikasi: 2 critical findings → 2 surgical fixes in 3 files (1 reference + 1 SKILL + 1 contract correction)
- flawless: caught + fixed declared-vs-implemented gaps BEFORE production; validation pattern reinforced for future sessions
- reuse-first: extends established Iter 43 + Iter 48 fix-forward pattern; no new mechanisms; reuses existing halt envelope (memory_in_use); reuses existing skeleton template structure

**Plugin:** v3.35.0 → v3.35.1

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md` — closure work officially complete with Iter 52
**Code-reviewer dispatch:** agentId aeb607f12acfdac77

**Audit closure final status:** Iter 38 audit identified 37 findings (12 P1/HIGH + 17 P2/MEDIUM + 8 Advisory/LOW). Session closed: all 12 P1/HIGH + bulk of P2/MEDIUM. ~14 iters total (39-52). Plugin v3.26.2 → v3.35.1.

## [3.35.0] - 2026-05-25

### Iter 51 — Glossary Anchoring + Reference Offset Hints + Parallelism Tuning (Queue #10 — FINAL queue closure)

**Editorial iter** (~1.5hr; MINOR bump — extract-intelligence default behavior change + new placeholder + new citation convention). Closes Iter 38 audit Queue #10 (D1-004 + D1-007 + D2-001).

**🎉 Audit queue completion:** Queue #10 was the **FINAL** item in Iter 38's prioritized iter queue. With Iter 51 shipped, **all 10 queue items (Iters 40-51) closed plus 5 immediate wins (Iter 39) plus 2 fix-forward iters (43, 48) — 13 iters total** closing the 37 findings from the Iter 38 audit. Plugin journeyed v3.26.2 → v3.35.0 (13 versions; 1 fix-forward each at v3.28.1 + v3.32.1).

**Change 1 (D1-004): Glossary pre-parse — `<GLOSSARY_INDEX>` placeholder**

Wave-2/3/4 subagents previously each re-read full glossary.md (80-120 KB). Iter 51 main thread parses glossary ONCE between Wave 1 and Wave 2, builds compact `glossary_index` (term → 1-line definition + line range), injects as `<GLOSSARY_INDEX>` placeholder in each wave subagent prompt:

```yaml
glossary_index:
  - term: "customer-onboarding"
    short_def: "End-to-end signup flow including KYC, tier assignment, and document upload"
    location: "glossary.md:42-58"
  # ... per glossary entry
```

Subagent prompts updated to instruct: use `<GLOSSARY_INDEX>` for cross-references; only spot-read glossary.md (with `offset`/`limit`) when full prose context needed; cite with line range (`glossary.md §customer-onboarding:42-58` not bare).

**Net savings:** ~96 KB redundant I/O per wave (15% of 535K wave token budget). 4 subagents × 3 waves = 12 subagent reads saved per extraction.

**Change 2 (D1-007): Reference offset hints**

All wave outputs cite references with line range hints: `<file>.md §<section>:line-X-Y` instead of bare `<file>.md §<section>`. Downstream consumers (other waves, generate-intent --kb, manual inspection) use the range with Read tool's `offset`/`limit` for targeted reads. Best-effort convention — bare citation form still accepted (graceful degradation when producer subagent doesn't know exact lines).

**Net savings:** 30-60% I/O reduction per reference read when consumers spot-read.

**Change 3 (D2-001): Parallelism tuning — extract-intelligence `--max-parallel` default 5 → 3**

Per Zylos 2026 empirical optimum: 3 parallel agents per turn is the sweet spot for AI agent dispatch. Beyond 3, coordination overhead exceeds gain. Iter 51 lowers default from 5 to 3; soft warn at >5 (existing predictive-checks.md `subagent_capacity_reasonable` aligns); hard cap remains 8.

**Net effect:** lower-default extractions use fewer tokens, less coordination time, often higher quality outputs (less context dilution per subagent).

**External research applied:**
- Zylos 2026 parallel agent optimization (D2-001 source)
- Subagent token patterns (Sathish Raju Medium) — pass analytical outputs not raw data (D1-004 motivator)
- Claude Code Read tool offset/limit best-practice (D1-007 enabler)

**Surface changes:**
- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` — `--max-parallel` default change + glossary pre-parse section + reference offset hints section
- `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` — `<GLOSSARY_INDEX>` placeholder section NEW + reference offset hints section NEW
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — `subagent_capacity_reasonable` check warning text updated to reflect new default
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.34.0 → 3.35.0
- `plugins/mega-sdd/README.md` — + v3.35.0 What's new entry
- `README.md` — version bump

**Skill version bumps:**
- `extract-intelligence` 1.6.0 → 1.7.0 (MINOR — new default + new placeholder + new convention)

**Why MINOR (not PATCH):** `--max-parallel` default change affects every extract-intelligence invocation that doesn't explicitly set the flag. Pre-Iter-51 extractions ran 5-wide; post-Iter-51 default runs 3-wide. Observable behavior change.

**Backward compatibility:** `--max-parallel=5` flag still works (overrides new default). Pre-Iter-51 KBs (no `<GLOSSARY_INDEX>` placeholder support in subagent prompts) continue to work — wave subagents simply re-read glossary as before (no regression; just no savings until next extraction).

**Standing directives applied:**
- simplifikasi: 3 audit findings → 3 atomic changes in 3 files; no new files; no new halts
- flawless: all 3 changes ship together as one editorial polish iter; no partial coverage
- reuse-first: REUSES existing wave-dispatch-templates.md placeholder convention + REUSES existing predictive-checks.md threshold + REUSES Read tool's `offset`/`limit` parameters

**Plugin:** v3.34.0 → v3.35.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md` — **QUEUE FULLY CLOSED with Iter 51**

**Session summary (Iters 39-51 = 13 iters):**

| Iter | Version | Type | Closes |
|---|---|---|---|
| 39 | 3.26.3 | 5 immediate wins | D3-007 + D3-010 + D4-001 + D3-004 |
| 40 | 3.27.0 | Queue #1 silent-failure | D3-001 + D3-002 + D3-003 |
| 41 | 3.27.1 | Queue #2 halt taxonomy sync | D3-006 + D4-001 pattern B |
| 42 | 3.28.0 | Queue #3 manifest preparse + per-slice cache | D1-002 + D2-003 |
| 43 | 3.28.1 | FIX-FORWARD #1 (handoff_missing semantics) | Caught by validation gate |
| 44 | 3.29.0 | Queue #4 T2 budget tracker | D1-003 |
| 45 | 3.30.0 | Queue #5 saga compensating actions | D3-009 + extends D3-003 |
| 46 | 3.31.0 | Queue #6 shared-snapshot reuse + per-file invalidation | D1-006 + D2-007 |
| 47 | 3.32.0 | Queue #7 independent acceptance-test authoring | D4-006 |
| 48 | 3.32.1 | FIX-FORWARD #2 (alg drift + step misplacement + wording) | Caught by validation gate |
| 49 | 3.33.0 | Queue #8 vault.json lock + scenario walkthroughs | D3-012 + D3-006 |
| 50 | 3.34.0 | Queue #9 predictive checks coverage | Pattern E |
| 51 | 3.35.0 | Queue #10 glossary + offset + parallelism | D1-004 + D1-007 + D2-001 |

**New validation pattern established this session:** advisor checkpoint after 3-4 feature iters → `superpowers:code-reviewer` subagent on cumulative range → fix-forward iter for any CRITICAL findings BEFORE next feature iter. Caught 2 release-blockers (Iter 40 handoff_missing semantics + Iter 44 algorithm drift) that would have produced wrong runtime behavior.

## [3.34.0] - 2026-05-25

### Iter 50 — Predictive Checks Coverage Expansion (Queue #9)

**Robustness iter** (~1hr; MINOR bump — predictive-checks.md catalog extended from 4 skills to 10). Closes Iter 38 audit Queue #9 (pattern E coverage asymmetry).

**Before:** predictive-checks.md covered 4 of 9 user-invocable skills. Other skills had zero proactive preflight coverage — failures surfaced only mid-execution as halts.

**After:** all 10 user-invocable skills have ≥1 preflight check. Total: 8 → 26 checks.

**New checks per skill (18 added):**

| Skill | Check | Fatal? | Predicts |
|---|---|---|---|
| detect-drift | vault_present_for_drift | yes | chain order |
| detect-drift | binding_present_for_drift | yes | chain order |
| detect-drift | clean_working_tree_for_drift | no | degraded drift signal |
| diff-vault | current_vault_present_for_diff | yes | chain order |
| diff-vault | new_source_resolves_for_diff | yes | prd_path_missing |
| diff-vault | vault_version_parseable | yes | invalid_handoff |
| resolve-oq | vault_present_for_oq | yes | chain order |
| resolve-oq | oq_status_field_present | no | degraded walk |
| resolve-oq | unresolved_oqs_exist | no | no-op invocation |
| extract-intelligence | legacy_codebase_path_present | yes | dep_missing |
| extract-intelligence | kb_target_writable | yes | dep_missing |
| extract-intelligence | subagent_capacity_reasonable | no | coordination overhead |
| emit-agents-md | vault_present_for_agents_md | yes | chain order |
| emit-agents-md | units_present_for_agents_md | no | degraded AGENTS.md |
| memory | memory_dir_writable | yes | memory_in_use |
| memory | schema_version_match | no | memory_schema_mismatch |
| memory | concurrent_writer_check | no | memory_in_use |

**External research applied:** Zylos 2026 parallel agent optimization — extract-intelligence `--max-parallel` empirical optimum is 3; cap warning at 5 per Iter 38 D2-001.

**Surface changes:**
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — 6 new per-skill sections (detect-drift, diff-vault, resolve-oq, extract-intelligence, emit-agents-md, memory) with 18 total new check entries
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — version bump (consumer now covers 10 skills)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.33.0 → 3.34.0
- `plugins/mega-sdd/README.md` — + v3.34.0 What's new entry
- `README.md` — version bump

**Skill bumps:**
- `orchestrate-flow` 3.2.1 → 3.3.0 (MINOR — predictive-checks consumer behavior change: now reads 10 skills instead of 4)

**Why MINOR:** orchestrate-flow Step 3.5 now reads checks for 6 additional skills. Pre-Iter-50 chains that bypassed checks for those skills will now surface warnings or halts upfront. This is intended (audit closure) but a behavioral change.

**Standing directives applied:**
- simplifikasi: 1 audit Pattern E → 18 catalog entries in 1 file edit; no new files; no new halts
- flawless: all 6 missing skills covered atomically; no partial coverage
- reuse-first: REUSES existing `predictive_check_failed` halt envelope; REUSES existing check entry format; REUSES canonical halt names (per Iter 41)

**Plugin:** v3.33.0 → v3.34.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Next:** Iter 51 — glossary anchoring + reference offset hints + extract-intelligence parallelism tuning (Queue #10; D1-004 + D1-007 + D2-001; ~3hr; editorial).

## [3.33.0] - 2026-05-25

### Iter 49 — vault.json Advisory Lock + Scenario-6 Halt Walkthroughs (Queue #8)

**Concurrency safety + docs iter** (~2hr; MINOR bump — new vault.json lock contract). Closes Iter 38 audit Queue #8 (D3-012 concurrent-write safety + D3-006 scenario-6 coverage).

**Change 1 (D3-012): vault.json advisory lock**

All 4 vault.json writers MUST acquire exclusive file lock per the Iter 5 memory file-lock pattern:
- `generate-intent` Step 11 (initial write)
- `bind-codebase` Step 6 (audit log append)
- `diff-vault` Step 8 (regen from markdown)
- `resolve-oq` Step 2c step 9 (regen after OQ outcome)

Lock acquisition: backoff (100ms / 500ms / 1500ms) + retry 3x; fail with `memory_in_use` halt if all retries fail. Reuses existing halt envelope per reuse-first directive — no new halt type. Halt details include `file`, `lock_path`, `attempts`, `lock_holder_pid` for diagnostic clarity.

Readers DO NOT need the lock — POSIX rename is atomic; readers always see consistent pre-write OR post-write view, never mid-write.

`detect-drift` NEVER writes vault.json (existing convention preserved). No lock acquisition required.

Canonical contract: new `vault-contract.md §Concurrency contract` section documents the full pattern + halt envelope + reader exception + backward-compat note.

**Change 2 (D3-006): scenario-6 expansion (3 → 13 walkthroughs)**

`tests/scenarios/scenario-6-recovery-from-halt.md` previously covered 3 halt types. Plugin now has 46+ halts. Added 10 high-frequency walkthroughs:

1. `handoff_missing` (Iter 40 + 43 fix-forward) — chat_tail_excerpt diagnostic
2. `artifact_missing` (Iter 40) — re-run producer
3. `partial_state_corrupt` + saga rollback (Iter 40 + 45) — both forensics restart + --rollback paths
4. `oq_blocker` (universal) — resolve-oq + tech-OQ auto-resolve
5. `diff_conflict` (Iter 3) — 3-option resolution
6. `dispatch_prompt_too_large` (Iter 30 + 44) — constitution-clause splitting
7. `provenance_missing` (Iter 30) — trailer + amend
8. `bind_conflict_constitution_violation` (Iter 20) — review-or-fix protocol
9. `cross_squad_dep_invalid` (Iter 25) — 3-path resolution
10. `memory_schema_mismatch` (Iter 5) — migrate vs --memory-off

Each walkthrough: trigger description, canonical envelope example, 1-3 recovery options, cross-refs. ~30-40 LOC per walkthrough; total addition ~400 LOC; scenario-6 grows from 365 LOC → ~800 LOC.

**Surface changes:**
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — new §Concurrency contract section + "writers must regenerate" list updated to include bind-codebase
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` — Step 11 + lock acquisition note
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 6 + lock acquisition note
- `plugins/mega-sdd/skills/diff-vault/SKILL.md` — Step 8 + lock acquisition note
- `tests/scenarios/scenario-6-recovery-from-halt.md` — + 10 walkthrough sections
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.32.1 → 3.33.0
- `plugins/mega-sdd/README.md` — + v3.33.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-49-vault-lock-and-scenario-expansion-design.md` — new spec

**Skill version bumps:**
- `generate-intent` 1.15.0 → 1.15.1 (PATCH — lock acquisition)
- `bind-codebase` 1.10.1 → 1.10.2 (PATCH — lock acquisition)
- `diff-vault` 1.3.1 → 1.3.2 (PATCH — lock acquisition)

**Why MINOR (not PATCH):** concurrent-write contract is new orchestrator-observable behavior. Pre-Iter-49 chains that silently raced on vault.json writes now halt explicitly with `memory_in_use`. Existing user workflows relying on silent racing will see new halts — by design.

**Standing directives applied:**
- simplifikasi: 2 audit findings → 1 contract section + 4 lock acquisition notes + 10 walkthrough sections
- flawless: all 4 vault.json writers locked in-iter; scenario coverage extended to all high-frequency halts in one pass
- reuse-first: REUSES Iter 5 memory file-lock pattern + REUSES existing `memory_in_use` halt envelope (no new halt type); REUSES existing scenario-6 structure (extends rather than replacing)

**Plugin:** v3.32.1 → v3.33.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-49-vault-lock-and-scenario-expansion-design.md`

**Next:** Iter 50 — predictive checks coverage expansion (Queue #9; ~3hr; MEDIUM impact proactive failure detection).

## [3.32.1] - 2026-05-25

### Iter 48 — FIX-FORWARD: Iter 44 algorithm rewrite, Iter 46 step relocation, Iter 46 wording correction

**Release-blocker fix iter** (PATCH bump — pure correctness; no new behavior). Cumulative code-quality review of Iters 44-47 (commits 3d11c09..HEAD covering v3.29.0 → v3.32.0) by `superpowers:code-reviewer` subagent surfaced 2 CRITICAL + 1 MEDIUM. All fixed in Iter 48 before Iter 49 feature work.

This is the SECOND fix-forward iter triggered by validation gate this session (precedent: Iter 43 fixed Iter 40's `handoff_missing` release-blocker). Pattern: ship 3-4 feature iters → advisor + code-reviewer subagent → fix-forward critical findings → next feature iter. Pattern is now standard for cumulative-iter sessions.

**CRITICAL fixes:**

**C1 — Iter 44 algorithm drift (`bolt-dispatch-prompt.md` §Tier-loading algorithm):**

Pre-Iter-44 the canonical algorithm in `bolt-dispatch-prompt.md` encoded single-halt-at-10KB pseudocode. Iter 44 added new running-budget tracker + per-section truncation cascade to SKILL.md Step 4.5.a.5, BUT the canonical algorithm in the reference doc was left unchanged. LLM following the reference doc would execute the OLD behavior contradicting SKILL.md's design — the 15-30% T2 reduction claim wouldn't materialize.

Fix: rewrote `bolt-dispatch-prompt.md §Tier-loading algorithm` with v2.0 (Iter 44) running-budget pseudocode:
- Step a.5 initialize budget tracker with cap_hard/cap_target/cap_t1/cap_t2/consumed_t1/consumed_t2/remaining_t2/warnings
- Step b T2 sections load in PRIORITY DESCENDING order (priority 8 first, priority 1 last) so HIGH-priority items always survive
- For each section: check remaining_t2; if section fits append; if not apply truncation cascade per SKILL.md table; log {section, rule_applied, bytes_saved} to warnings
- Step d hard halt only when constitution_clauses alone overflows after all disposable sections truncated to drop floor
- Soft-budget warning (NOT halt) when consumed_t2 > cap_t2 but total < cap_hard
- Always inject `### T2 budget tracker` provenance section
- Header bumped to v2.0 (Iter 44 semantics); v1.0 (Iter 30) algorithm preserved at bottom as historical reference

**C2 — Iter 46 scan-codebase Step 9.5 misplacement (`scan-codebase/SKILL.md`):**

Iter 46 added per-file invalidation logic at Step 9.5 (between Step 9 pattern detection and Step 10 codebase-map.md write). BUT symbol extraction happens at Step 5. By the time Step 9.5 ran, tree-sitter/regex extraction was already complete — too late to short-circuit. The promised 5-10s shallow-scan savings didn't materialize. Plus the original Step 9.5 said "Write updated codebase-map.md atomically" which would have been overwritten by Step 10's own write (double-write race).

Fix: relocated per-file invalidation gate to BEFORE Step 5 tree-sitter/regex extraction. The gate now:
1. Skips for `--deep-scan` (default) or `--no-cache` (correctness preserved)
2. For `--shallow-scan` with prior codebase-map.md: per-file compare current sha256 vs `Last_Scanned_Sha256` column
3. REUSE prior §2 entries for unchanged files (true short-circuit — tree-sitter never invoked for those files)
4. Re-extract for changed/new files; update Last_Scanned_Sha256
5. Files removed from repo → drop from §2

Step 9.5's old location now holds a brief breadcrumb pointing to the relocated gate. Single canonical codebase-map.md write at Step 10.

**MEDIUM fix:**

**M1 — Iter 46 bind-codebase reuse hook wording (`bind-codebase/SKILL.md` Step 1):**

Iter 46 description claimed "skip per-source-file re-tokenization (~30-50% I/O saving)" — but bind-codebase Step 2 has never re-tokenized. Step 2 consumes pre-extracted §2 entries from codebase-map.md. The "savings" had no observable target within bind-codebase.

Fix: corrected wording. The snapshot reuse is a **freshness attestation** that bind-codebase records in `binding_metadata.codebase_map_provenance` field (`snapshot-verified` / `snapshot-stale` / `no-snapshot`). The 30-50% savings applies at the orchestrate-flow chain level — downstream skills can trust the codebase-map is fresh and skip a redundant scan-codebase invocation. Iter 48 fix-forward note added inline explaining the correction.

**Surface changes:**
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — §Tier-loading algorithm rewritten with v2.0 running-budget pseudocode; v1.0 historical reference preserved
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — per-file invalidation gate moved from Step 9.5 → Step 5 (BEFORE extraction); old Step 9.5 location holds breadcrumb
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 1 reuse hook wording corrected; provenance attestation pattern documented
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.32.0 → 3.32.1
- `plugins/mega-sdd/README.md` — + v3.32.1 What's new entry
- `README.md` — version bump

**Skill version bumps:**
- `scan-codebase` 2.7.1 → 2.7.2 (PATCH — Step 5 gate relocation)
- `bind-codebase` 1.10.0 → 1.10.1 (PATCH — wording correction)

**Validation pattern reinforced (second fix-forward triggered by subagent review):**

This session has now triggered the validation pattern twice:
1. Iter 43 fix-forward caught Iter 40's `handoff_missing` semantics defect (file-check vs chat-block)
2. Iter 48 fix-forward caught Iter 44 algorithm drift + Iter 46 step misplacement + Iter 46 wording

Both rounds caught defects that would have produced wrong runtime behavior in production. The pattern is now load-bearing: ship 3-4 feature iters → advisor + code-reviewer subagent → fix-forward → next feature iter.

**Standing directives applied:**
- simplifikasi: 3 review findings → 3 surgical fixes in 3 files; no new files; no new halts
- flawless: caught semantic defects in canonical algorithm + step placement + wording BEFORE production; both prior iter intentions preserved with corrected implementations
- reuse-first: extends existing validation gate pattern (advisor + code-reviewer subagent) established in Iter 43

**Plugin:** v3.32.0 → v3.32.1

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Code-reviewer dispatch:** agentId a882063dd0e439071

**Next:** Iter 49 — vault.json advisory lock + scenario-6 expansion (Queue #8 from audit; D3-012 + D3-006; ~3hr; MEDIUM impact).

## [3.32.0] - 2026-05-25

### Iter 47 — Independent Acceptance-Test Authoring (Adversarial Review Pass)

**Output-quality iter** (~2hr; MINOR bump — new generate-units Step + new acceptance_test provenance field + new prompt template reference). Closes Iter 38 audit Queue #7 (D4-006, HIGH structural risk; pattern F). Per ACM FSE 2025: "Never trust AI to both generate and validate."

**Problem (D4-006 HIGH severity):** every unit's `acceptance_test` was authored by the SAME LLM pass that wrote the unit body. Both inherited the same blind spots. Bolt subagent runs the test → passes → user trusts the green checkmark → ships broken code. Hard Rules + provenance trailer catch structural bugs; they cannot catch behavioral bugs the test was authored to NOT detect.

**Solution: adversarial second-pass review + provenance field**

**1. New Step 9.5 — Adversarial test review pass (generate-units)**

Runs AFTER Step 9 fills acceptance_test inline with unit body. Two modes:

**Default (main-thread self-re-prompt):** main thread re-prompts itself with adversarial framing — "you're a QA engineer reviewing this acceptance_test; find AT LEAST 2 cases the test FAILS to catch a real bug." Same LLM, different role context. No subagent dispatch overhead.

**Opt-in subagent (`--adversarial-subagent` flag OR unit `risk: high`):** dispatch a SEPARATE subagent for the adversarial review. Independent LLM context = stronger blind-spot coverage. One extra dispatch per unit. Auto-set for high-risk units.

**Skip (`--no-adversarial-review` flag):** preserves pre-Iter-47 behavior (D4-006 blind-spot risk). **DISCOURAGED** — debug / regression only.

**2. Adversarial review output (strict YAML)**

```yaml
adversarial_review:
  reviewer_pass: 2                          # always 2 (Step 9 = pass 1)
  gaps_identified:
    - scenario: "<bug case description>"
      missed_by_assertion: "<which existing assertion fails to catch it>"
      proposed_additional_assertion: "<test code or natural language>"
  coverage_verdict: weak | adequate | strong
```

**3. Gap merge logic (main thread, post-review)**

- `coverage_verdict: strong` AND no gaps → keep original; mark `_authored_by: adversarial-reviewed (no gaps)`
- Non-empty gaps → append `proposed_additional_assertion` per gap to acceptance_test; mark `_authored_by: adversarial-reviewed (+N gaps merged)`
- `coverage_verdict: weak` AND no gaps (incoherent reviewer output) → keep original; mark `_authored_by: adversarial-review-failed`. Log warning to chat.

**4. `_authored_by:` provenance field (NEW canonical values)**

| Value | Origin | Trust signal |
|---|---|---|
| `same-pass` | pre-Iter-47 OR `--no-adversarial-review` | weakest (D4-006 risk) |
| `adversarial-reviewed (no gaps)` | Iter 47 default, no gaps found | strong |
| `adversarial-reviewed (+N gaps merged)` | Iter 47 default, N gaps merged | strong |
| `adversarial-review-failed` | Iter 47, reviewer incoherent | weak + warning |
| `independent-llm` | Iter 47 opt-in subagent mode | strongest LLM-derived |
| `human` | user manually edited | strongest overall |

**5. execute-bolts dispatch-prompt NOTE for weak provenance**

When unit's `acceptance_test._authored_by` is `same-pass` OR `adversarial-review-failed`, execute-bolts injects a NOTE into the bolt dispatch prompt warning the bolt subagent: "this test may have blind spots; if your implementation passes the test but feels under-validated, flag `acceptance_test_concern: <details>` in your bolt-report.md self-assessment, propose 1-2 additional assertions, and mark confidence no higher than MEDIUM."

Strong provenance values → NO NOTE injected (trust the test).

**6. `--regenerate` preserves user-edited tests**

`generate-units --regenerate` re-encountering a unit with `_authored_by: human` PRESERVES the acceptance_test untouched. Other provenance values get rewritten per Steps 9 + 9.5.

**New file:** `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` — canonical prompt template (default mode + subagent mode) + merge logic + provenance values table + anti-halu rails.

**Surface changes:**
- `plugins/mega-sdd/skills/generate-units/SKILL.md` — Step 9 extended (first-pass marker); Step 9.5 NEW (adversarial review); Inputs flags `--adversarial-subagent` / `--no-adversarial-review` / `--regenerate`
- `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` — NEW reference file
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.a extended with acceptance-test provenance NOTE detection
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — Acceptance-test provenance NOTE template (above Rollback hints section)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.31.0 → 3.32.0
- `plugins/mega-sdd/README.md` — + v3.32.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md` — new spec

**Skill version bumps:**
- `generate-units` 2.6.0 → 2.7.0 (MINOR — new Step + new flags + new frontmatter field)
- `execute-bolts` 2.9.0 → 2.9.1 (PATCH — provenance detection + NOTE injection)

**Backward compatibility:**
- Pre-Iter-47 units (no `_authored_by:` field) treated as `same-pass` — execute-bolts injects NOTE; `--regenerate` rewrites with adversarial review
- `--no-adversarial-review` flag preserves pre-Iter-47 generation behavior for debug / regression
- Zero breaking changes; opt-out path preserved for users who want the old behavior

**External research applied (Iter 38 audit citations):**
- PBT for LLM-Generated Code (ACM FSE 2025) — "Never trust AI to both generate and validate"
- Multicalibration for LLM-based Code Generation (ResearchGate)
- Stanford AI Index 2026 — Hallucination Engineering report

**Standing directives applied:**
- simplifikasi: 1 audit finding (HIGH structural) → 1 new Step + 1 new reference file + 1 new frontmatter field + 1 NOTE injection
- flawless: producer (generate-units emits `_authored_by:`) + consumer (execute-bolts reads + surfaces) ship in-iter; backward compat for pre-Iter-47 units; opt-out path preserved
- reuse-first: extends existing generate-units 12.x post-write validation pattern + existing bolt-dispatch-prompt.md NOTE injection convention; no new halt type (provenance signal, not halt)

**Plugin:** v3.31.0 → v3.32.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-47-independent-acceptance-test-authoring-design.md`

**Next:** Validation gate (advisor + code-reviewer subagent on commits 3d11c09..HEAD covering Iters 44-47) BEFORE Iter 48 (Queue #8 vault.json advisory lock + scenario-6 expansion).

## [3.31.0] - 2026-05-25

### Iter 46 — Shared-Snapshot Reuse Extension + Per-File Symbol Invalidation

**Performance iter** (~2hr; MINOR bump — schema extension v1.0 → v1.1 + new producer/consumer paths). Closes Iter 38 audit Queue #6 (D1-006 + D2-007; pattern C cache invalidation). Extends Iter 30 shared-snapshot pattern from 1 hop to 3.

**Problems closed:**

- **D1-006**: shared-snapshot reuse (Iter 30) was scoped to `execute-bolts ↔ detect-drift` only. The same pattern wasn't extended to `scan → bind` or `extract → intent` hops. Audit estimate: 30-50% re-run I/O saving on incremental dev cycles.
- **D2-007**: `scan-codebase --shallow-scan` re-extracted symbols for EVERY file on EVERY run, even files unchanged since last codebase-map.md. Audit estimate: 5-10s rebuild eliminated.

**Solution:**

**Change 1 (D1-006) — shared-snapshot extension to 2 new hops:**

scan → bind hop:
- `scan-codebase` Step 10.6 (NEW) emits `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` after Step 10 codebase-map.md write. Snapshot contains `codebase_map_sha256` + `source_files_sha256_map: {<repo-relative-path>: <sha256>}` for every scanned source file.
- `bind-codebase` Step 1 (extended) reads snapshot before Step 2 claim matching. If `codebase_map_sha256` matches the just-read codebase-map.md → reuse parsed §2 symbol data directly (skip per-source-file re-tokenization). Mismatch or absent → fall back to current behavior (no regression).
- Savings: ~30-50% I/O reduction on iterative dev when source files unchanged between scan and bind.

extract → intent hop:
- `extract-intelligence` Step 5.5 (NEW) emits `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` after wave-5 synthesis completes. Snapshot captures `source_files_sha256_map` for every legacy source file consumed by waves 1-4.
- `generate-intent --kb` (Mode B preflight, v1.15+) checks snapshot before consuming KB. ALL files unchanged → log "KB freshness: confirmed". SOME drifted → log advisory warning + suggest `extract-intelligence --force`. DO NOT halt (preserves user agency on legacy-rebuild work).
- Use case: detect when KB has gone stale because source code evolved since extraction.

**Change 2 (D2-007) — per-file symbol invalidation:**

- `codebase-map.md §2 Public interfaces` gains OPTIONAL `Last_Scanned_Sha256` column (per `references/codebase-map-schema.md` update).
- `scan-codebase --shallow-scan` Step 9.5 (NEW) does per-file invalidation: only files whose current sha256 differs from `Last_Scanned_Sha256` get re-tokenized; unchanged files reuse prior §2 entries.
- Files removed from repo → drop their §2 entries. Files NEW → extract + add. Files unchanged → reuse.
- Default `--deep-scan` behavior preserved (full re-extract; no per-file invalidation) — opt-in to per-file cache via `--shallow-scan`.
- Savings: 5-10s rebuild → <1s on iterative shallow re-scans.

**Schema bump — `references/shared-snapshot-schema.md` v1.0 → v1.1:**

- `snapshot_type` enum extended: + `codebase-map`, + `extracted-kb`
- New OPTIONAL fields: `codebase_map_sha256`, `source_files_sha256_map`
- New producer responsibilities sections: scan-codebase (codebase-map snapshot) + extract-intelligence (extracted-kb snapshot)
- New consumer responsibilities sections: bind-codebase (codebase-map consumer) + generate-intent --kb (extracted-kb consumer)
- File locations summary extended with 2 new snapshot paths

**Backward compatibility (ALL changes):**
- All new fields are OPTIONAL — v1.0 readers ignore unknown keys
- Snapshot files are pure optimization — pre-Iter-46 codebase/KB without snapshots behave as today
- `Last_Scanned_Sha256` column missing → triggers full re-extraction on first `--shallow-scan` (same as cold start)
- Zero breaking changes; one-time migration cost on first post-upgrade scan

**Plugin file changes:**
- `plugins/mega-sdd/references/shared-snapshot-schema.md` — v1.0 → v1.1 with new types + fields + producer/consumer sections
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — + Step 10.6 (snapshot emission); + Step 9.5 (per-file invalidation for --shallow-scan)
- `plugins/mega-sdd/skills/scan-codebase/references/codebase-map-schema.md` — + `Last_Scanned_Sha256` column
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Step 1 extended with snapshot reuse path
- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` — + Step 5.5 (extracted-kb snapshot emission)
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` — Mode B preflight extended with KB freshness check
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.30.0 → 3.31.0
- `plugins/mega-sdd/README.md` — + v3.31.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-46-snapshot-reuse-extension-design.md` — new spec

**Skill version bumps:**
- `scan-codebase` 2.7.0 → 2.7.1 (PATCH — additive snapshot emission + opt-in invalidation path)
- `bind-codebase` 1.9.4 → 1.10.0 (MINOR — new reuse path)
- `extract-intelligence` 1.5.0 → 1.6.0 (MINOR — new snapshot emission step)
- `generate-intent` 1.14.0 → 1.15.0 (MINOR — new freshness check preflight)

**External research applied (per Iter 38 audit citations):**
- Real-time codebase indexing (cocoindex-io) — per-file hash invalidation pattern
- Aider repo-map architecture — symbol-graph caching pattern

**Standing directives applied:**
- simplifikasi: 2 audit findings → 1 iter; schema extension + 1 new step per producer + 1 reuse path per consumer
- flawless: producer + consumer ship in-iter for both new hops; v1.0 readers gracefully degrade
- reuse-first: extends Iter 30 shared-snapshot pattern + extends existing codebase-map.md §2 table schema; no new cache files outside existing `.shared-snapshots/` convention

**Plugin:** v3.30.0 → v3.31.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-46-snapshot-reuse-extension-design.md`

**Next:** Iter 47 — independent acceptance-test authoring (Queue #7; D4-006; HIGH structural risk closure).

## [3.30.0] - 2026-05-25

### Iter 45 — Saga Compensating Actions (`--rollback` flag + partial-state v2.0)

**Robustness iter** (~2hr; MINOR bump — schema bump + new flag + new self-assessment section). Closes Iter 38 audit Pattern D (D3-009 rollback undefined + extends D3-003 partial-state coverage). Closes Queue #5.

**Problem (Pattern D, audit-cited external research: Saga Pattern + Compensating Transactions):** mega-sdd uses forward-only resume. On `--resume`, execute-bolts retries the failing step but cannot undo non-idempotent prior steps (composer dep adds, migration executions, external API calls). Partial writes compound on subsequent runs.

**Solution:**

**1. partial-state.json schema v1.0 → v2.0**

Bumps `schema_version` field. Adds `rollback_hints[]` array per partial bolt:

```json
{
  "schema_version": "2.0",
  "bolt_id": "U-007",
  "current_step": "step-3-write-controller",
  "current_step_status": "crashed",
  "files_modified": [...],
  "rollback_hints": [
    {
      "step_id": "step-1-add-dep",
      "step_type": "composer_dep_added",
      "evidence": "added 'laravel/cashier': '^15.0' to composer.json:42",
      "compensating_action": "composer remove laravel/cashier --no-update && git checkout composer.json composer.lock",
      "idempotent": false,
      "applied_at": null
    },
    {
      "step_id": "step-2-write-migration",
      "step_type": "file_created",
      "evidence": "created database/migrations/2026_05_25_100000_create_subscriptions_table.php (47KB)",
      "compensating_action": "rm database/migrations/2026_05_25_100000_create_subscriptions_table.php",
      "idempotent": true,
      "applied_at": null
    }
  ]
}
```

**2. Canonical step_type taxonomy (14 types)**

Each maps to default compensating action template + idempotency flag. Bolt subagent classifies each significant step using these EXACT names (`file_created` / `file_modified` / `file_partially_written` / `file_deleted` / `composer_dep_added` / `composer_dep_removed` / `npm_dep_added` / `npm_dep_removed` / `migration_created` / `migration_executed` / `external_api_call` / `test_command_run` / `git_commit` / `git_branch_created`). Unknown values → `partial_state_corrupt` halt.

**3. `--rollback <unit-id>` flag (NEW)**

Reads partial-state.json v2.0. If `rollback_hints[]` present, displays reverse-order list with idempotency markers:

```
Rolling back partial bolt U-007 (3 compensating actions):

  3. file_partially_written: git checkout HEAD -- app/Http/Controllers/SubscriptionController.php  [idempotent ✓]
  2. file_created: rm database/migrations/2026_05_25_100000_create_subscriptions_table.php  [idempotent ✓]
  1. composer_dep_added: composer remove laravel/cashier --no-update && git checkout composer.json composer.lock  [idempotent ✗ — composer cache may persist]

Apply in reverse order (3 → 2 → 1)?
  [Y] proceed   [N] cancel   [I] interactive (per-action confirm)
```

Per-action confirmation default safe for non-idempotent. Applied actions stamp `applied_at:` so partial rollback can be resumed. On full rollback completion: partial-state.json renamed to `.rolled-back-<ISO8601>` for forensics.

**4. Bolt subagent contract (bolt-dispatch-prompt.md `## Rollback hints` section)**

For EACH significant step bolt subagent performs, append rollback hint to bolt-report.md `## Rollback hints` section. On crash: execute-bolts harvests into partial-state.json. On success: section is INFORMATIONAL (audit trail).

**5. Backward compat**

- v1.0 partial-state.json (Iter 30 baseline) → `--rollback` errors with manual-review guidance (`git status` + `git diff HEAD`)
- `--resume` still works on v1.0 (forward-only behavior preserved)
- New bolt writes always emit v2.0 schema

**Halt semantics:** malformed `rollback_hints[]` entries (missing required fields OR unknown `step_type`) → reuses existing `partial_state_corrupt` halt (Iter 40) with `malformed_hints: [<entry indices + reason>]` detail. No new halt type.

**Surface changes:**
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — `--rollback` + `--resume` flags documented in Inputs; §Partial-state contract extended with v2.0 schema + canonical step_type taxonomy table + new §Saga compensating actions section
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — `## Rollback hints` self-assessment section added with canonical taxonomy table + emission contract
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.29.0 → 3.30.0
- `plugins/mega-sdd/README.md` — + v3.30.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md` — new spec

**Out of scope:**
- Auto-rollback on crash (user-initiated only; auto-rollback compounds non-idempotent errors)
- Cross-bolt saga (rollback scope = single bolt U-XXX)
- DB schema introspection for `migration_executed` rollback (relies on framework's standard rollback command; user accepts risk via per-action confirmation)

**Skill bumps:**
- `execute-bolts` 2.8.0 → 2.9.0 (MINOR)

**External research applied:**
- Saga Pattern (microservices.io) — compensating action design
- Compensating Transactions (Microsoft Azure) — idempotency flag pattern

**Standing directives applied:**
- simplifikasi: 1 audit Pattern (D + extension to D3-003) → schema bump + 1 new flag + 1 new self-assessment section in 2 files
- flawless: producer (bolt subagent emits hints) + consumer (execute-bolts harvests on crash + applies on `--rollback`) ship in-iter; v1.0 readers gracefully degrade
- reuse-first: extends Iter 30 partial-state contract + reuses Iter 40 `partial_state_corrupt` halt for malformed hints + extends existing bolt-dispatch-prompt.md self-assessment pattern

**Plugin:** v3.29.0 → v3.30.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md`

**Next:** Iter 46 — section-snapshot reuse (Queue #6; D1-006 + D2-007; ~3hr; MEDIUM impact iterative-run ROI).

## [3.29.0] - 2026-05-25

### Iter 44 — T2 Running Budget Tracker + Progressive Truncation

**Performance iter** (~2hr; MINOR bump — new step + new dispatch-prompt section). Closes Iter 38 audit Queue #4 (D1-003, HIGH impact per-bolt).

**Problem (D1-003):** T2 5KB soft cap was aspirational — no running budget enforced. Single 10KB hard halt only. Complex units silently exceeded T2 target until tripping the hard cap (halt-or-pass binary). Audit estimate: 15-30% T2 size reduction for complex units.

**Solution: 3 new mechanisms in execute-bolts §Step 4.5**

**1. Running budget tracker (Step 4.5.a.5, NEW)**

Initialized after TIER 1 load, before TIER 2 load:
```
running_budget = {
  cap_hard:      10240     # 10KB hard cap (unchanged)
  cap_target:    7168      # 7KB total target
  cap_t1:        2048      # 2KB T1 budget
  cap_t2:        5120      # 5KB T2 budget (now ENFORCED)
  consumed_t1:   <bytes>
  consumed_t2:   0
  remaining_t2:  cap_t2
  warnings:      []
}
```

After EACH T2 section loads: update `consumed_t2`; if `remaining_t2 < next_section_min_viable_bytes` → apply progressive truncation per priority table BEFORE loading next section. Truncation events logged to `warnings` array for provenance.

**2. 8-tier section priority + per-section truncation cascade**

| Priority | Section | Cascade | Drop floor |
|---|---|---|---|
| 1 | validation_hints | drop expected-output; keep commands | drop |
| 2 | historical_memory | 5→3→1→drop | drop |
| 3 | kb_anti_patterns | top 3→top 1→drop | drop |
| 4 | confidence_labels | per-claim → aggregate | drop |
| 5 | depends_on_summaries | N most-recent → 1 minimum | keep 1 |
| 6 | framework_pack_rules | top 5→top 3→top 1 | keep top 1 |
| 7 | starterkit_slice | (existing Iter 32 cascade) | per Iter 32 |
| 8 (NEVER drop) | constitution_clauses | n/a — LOCKED | halt if exceeds |

**3. Soft-budget warnings (NEW)**

When `consumed_t2 > cap_t2` but `total < cap_hard`:
- Log warning (NOT halt): `"T2 exceeded soft cap: target=5KB, actual=<N>KB — truncation applied"`
- Truncation still applied; bolt proceeds with truncated context
- Provenance trail visible to subagent via NEW `### T2 budget tracker` section in bolt-dispatch-prompt.md

**Self-assessment integration** — subagent instructed: "if your self-assessment references truncated information, mark confidence as MEDIUM (not HIGH) and note the truncation in bolt-report.md self-assessment section. Truncation is NOT a failure — it's transparency."

**Halt semantics (preserved)** — `dispatch_prompt_too_large` now fires ONLY when constitution_clauses alone exceeds budget after all disposable T2 sections truncated to drop floor. True config issue requiring spec-level adjustment. Iter 30 halt semantics preserved.

**Surface changes:**
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Step 4.5.a.5 (NEW); §T2 Section Priority + Truncation table (NEW); §Halt path (rewritten); §Soft-budget warnings (NEW); Step 4.5.d (rewritten to surface tracker)
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — `### T2 budget tracker` section added between Validation hints and TIER 3 marker
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.28.1 → 3.29.0
- `plugins/mega-sdd/README.md` — + v3.29.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-44-t2-running-budget-tracker-design.md` — new spec

**Skill bumps:**
- `execute-bolts` 2.7.3 → 2.8.0 (MINOR)

**External research applied (Iter 38 audit citations):**
- Anthropic Prompt Caching — context window budget discipline
- Subagent Token Patterns (Sathish Raju Medium) — graceful degradation > halt

**Standing directives applied:**
- simplifikasi: 1 audit finding → 1 new step + 1 new reference section + 1 rewritten step in 2 files
- flawless: halt semantics preserved (cap_hard still fires); soft-budget enforcement added incrementally; self-assessment field gives subagent visibility into truncation
- reuse-first: extends Iter 30 tiered-context architecture + Iter 32 starterkit cascade pattern + existing halt envelope

**Plugin:** v3.28.1 → v3.29.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
**Spec:** `docs/superpowers/specs/2026-05-25-iter-44-t2-running-budget-tracker-design.md`

**Next:** Iter 45 — saga compensating actions (Queue #5; D3-009 + D3-003; ~5hr; MEDIUM impact).

## [3.28.1] - 2026-05-25

### Iter 43 — FIX-FORWARD: handoff_missing semantics + schema doc + savings accuracy

**Release-blocker fix iter** (PATCH bump). Cumulative code-quality review of Iters 39-42 (commits ea574da..3d11c09) by `superpowers:code-reviewer` subagent surfaced 1 CRITICAL + 1 CRITICAL + 2 MEDIUM + 2 ADVISORY findings. Iter 43 closes all CRITICAL + MEDIUM; ADVISORY items now fully addressed.

**CRITICAL fixes:**

**C1 — `handoff_missing` would fire on every auto run (Iter 40 regression)**

Original Iter 40 design: orchestrate-flow Step b.0 computed an expected handoff file path (`<vault>/.internal/checkpoints/<ISO8601>-<skill>.handoff.yaml`) and ran `test ! -f` on it. **Problem:** no skill actually writes that file — every skill's `## Handoff emission` section emits the handoff YAML inline in chat output (as text in the last assistant message). The file-existence check would have produced spurious `handoff_missing` halts on the very first run, blocking every `--auto` chain.

Fix (orchestrate-flow v3.2.1+):
- Step b.0 rewritten to scan sub-skill's **chat output** (last assistant message) for a YAML code fence containing top-level `handoff:` key. Detects the canonical emission per `handoff-contract.md`.
- Halt envelope gains `chat_tail_excerpt: <last 500 chars>` field for diagnostic clarity (replaces hardcoded `expected_handoff_path:`).
- `vault-contract.md §halt-protocol` description updated to match chat-block semantics.
- `handoff-contract.md` Emission contract section added documenting skill-author rule + showing minimal emission example.

**C2 — starterkit-context-schema.md left at v1.0 while producer writes v2.0 (Iter 42 propagation gap)**

Iter 42 bumped `scan-codebase` to v2.7.0 emitting `schema_version: 2.0` with `cache_signatures:` block, but `plugins/mega-sdd/references/starterkit-context-schema.md` (the canonical reference doc consumed by bind-codebase, generate-units, execute-bolts) was still documented as v1.0 with `cache_key:` block. Violates 4-surface taxonomy directive (Iter 33+31).

Fix:
- Schema doc bumped to v2.0 with full `cache_signatures:` block spec
- Added per-slice invalidation matrix table (PHP dep edit → 25% savings; JS dep edit → 50%; single lib-pattern → 75%; framework pack rewrite → 0% / all 4 dispatched)
- Backward-compat note for v1.0 readers

**MEDIUM fixes:**

**M1 — Iter 42 CHANGELOG savings claims were inverted/imprecise**

Original claim ("composer.json frontend dep added → 50% saving") was technically incoherent (composer manages PHP, not frontend) and the math was wrong. composer.lock change invalidates auth+rbac+libs (3/4) — actual savings ≈ 25%. package.lock change invalidates ui_ux+libs (2/4) — actual savings ≈ 50%. Single lib-pattern edit invalidates 1 slice — actual savings ≈ 75%.

Fix: corrected invalidation matrix now documented in starterkit-context-schema.md (canonical) and in v3.28.1 README "What's new" entry. Historical Iter 42 CHANGELOG entry preserved as-shipped (no retroactive edit); reader-facing fix lives in this entry + canonical schema doc.

**M2 — Iter 41 framing accurate but grep-defined**

Iter 41 "halt taxonomy in sync" claim is bullet-vs-enum reconciliation specifically (false positives exist for halts with `### Type-specific guidance` sections instead of bullets). No regression; cosmetic concern. No fix needed in v3.28.1 — flagged for future contributor docs.

**ADVISORY fixes (rolled in):**

**A1 — partial_state_corrupt canonical path**: vault-contract.md description had `<vault>/.internal/checkpoints/partial-state.json` while execute-bolts §Partial-state contract emit example used `<vault>/bolts/U-XXX/partial-state.json`. Canonicalized to the per-bolt path (matches execute-bolts emit; matches the user-facing rename instruction).

**A2 — Handoff filename pattern drift**: superseded by C1 fix. Skills no longer required to write a file; chat-block is authoritative. Optional file-write convention (`<vault>/.internal/checkpoints/<ISO8601>-<skill>.handoff.yaml` for replay/audit) preserved in handoff-contract.md.

**Surface changes:**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step b.0 rewrite (chat-block detection); skill version 3.2.0 → 3.2.1
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — Pre-validation section rewritten; Emission contract section added
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — `handoff_missing` + `partial_state_corrupt` descriptions corrected
- `plugins/mega-sdd/references/starterkit-context-schema.md` — v1.0 → v2.0 doc bump (full)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.28.0 → 3.28.1
- `plugins/mega-sdd/README.md` — + v3.28.1 What's new entry; version refs
- `README.md` — version refs

**Skill version bumps:**
- `orchestrate-flow` 3.2.0 → 3.2.1 (semantics correction; PATCH)

**Validation method:** dispatched `superpowers:code-reviewer` subagent to diff `ea574da..3d11c09` (Iter 38 audit → Iter 42 release) against audit findings + advisor concerns. Subagent verified all skill SKILL.md `## Handoff emission` sections to confirm no skill writes handoff to a file — chat-block is universal emission convention. C1 confirmed as release-blocker.

**Per simplifikasi+flawless:** caught + fixed Iter 40 regression BEFORE Iter 43's intended T2 budget tracker work, instead of stacking new features atop broken foundation. Validation gate (advisor + code-reviewer subagent) prevented production deployment of broken `handoff_missing` halt. T2 budget tracker deferred to Iter 44 with cleaner foundation.

**Plugin:** v3.28.0 → v3.28.1

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Validation method (NEW pattern for cumulative-iter sessions):**
1. Advisor checkpoint after 4 iters
2. `superpowers:code-reviewer` subagent diffs full cumulative range against audit
3. Findings classified CRITICAL/MEDIUM/ADVISORY
4. Fix-forward iter shipped BEFORE next feature iter

**Next:** Iter 44 — T2 running budget tracker (Queue #4 from audit; D1-003; ~3hr; HIGH impact).

## [3.28.0] - 2026-05-25

### Iter 42 — Deep-Scan Manifest Pre-Parse + Per-Slice Cache

**Performance iter** (~3hr; MINOR bump — new optimization step + cache schema bump). Closes Iter 38 audit Queue #3 (priority 3, HIGH impact — every project pipeline benefits).

**Problems closed:**

- **D1-002** (token waste): 4 deep-scan subagents each re-read composer.json + package.json (~9-24KB redundant I/O per scan; ~10-20% per-subagent context budget waste).
- **D2-003** (compute waste): single composite cache_key invalidates ALL 4 slices on any input change. Frontend dep edit forces re-dispatch of auth+rbac (PHP-side; unchanged).

**Change 1 (D1-002): Manifest pre-parse — `scan-codebase` Step 10.5.1.5 (NEW)**

Main thread parses `composer.json` + `package.json` ONCE before subagent dispatch:
- Extracts: dependencies, dev_dependencies, scripts, autoload_psr4 (composer) / dependencies, devDependencies, peerDependencies, scripts, type (package)
- Builds canonical `manifest_facts` YAML struct
- Injects into 4 subagent prompts via new `<MANIFEST_FACTS>` placeholder (per `references/deep-scan-prompts.md` v2.7+ contract)

Subagent prompts updated: "manifest_facts is authoritative; do NOT re-read manifest/lock files. Spend context on framework-specific source files."

**Net savings:** ~9-24KB per scan (4 subagents × ~2-6KB saved per subagent context).

**Change 2 (D2-003): Per-slice cache — schema v2.0 (`cache_signatures:` replaces `cache_key:`)**

Each of 4 slices tracks its own signature:
- `auth_signature` = sha256(composer.lock + framework_pack §auth + lib-patterns/<fw>/auth-libs.md)
- `rbac_signature` = sha256(composer.lock + framework_pack §rbac + lib-patterns/<fw>/rbac-libs.md)
- `ui_ux_signature` = sha256(package.lock + framework_pack §ui + lib-patterns/<fw>/ui-libs.md)
- `libs_signature` = sha256(composer.lock + package.lock + framework_pack §libs + lib-patterns/<fw>/generic-libs.md)

**Routing logic (Step 10.5.1):**
- All 4 slices match prior signatures → FULL CACHE HIT (no dispatch needed)
- 1-3 slices stale → PARTIAL CACHE HIT (selective dispatch; consolidator merges fresh + cached)
- All 4 slices stale or no prior YAML → FULL CACHE MISS (dispatch all 4)

**Net savings (incremental edits):**
- composer.json frontend dep added → ui_ux + libs invalidate; auth + rbac cached → 50% subagent saving
- Lib-pattern file (e.g., auth-libs.md) edited → only auth slice invalidates → 75% saving
- Framework pack changed → all 4 invalidate (equivalent to current; no regression)

**Schema migration (backward compat):** existing starterkit-context.yaml with v1.0 `cache_key:` block treated as fully-stale on read; auto-migrates to v2.0 `cache_signatures:` on next write. One-time migration cost; zero breaking change for users.

**`reused_slices:` provenance field added** to starterkit-context.yaml — lists which slices were cached vs freshly-dispatched in the latest run. Aids debugging.

**Surface changes:**
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — Steps 10.5.1, 10.5.1.5 (NEW), 10.5.2, 10.5.3 reworked
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` — added `<MANIFEST_FACTS>` placeholder spec
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.27.1 → 3.28.0
- `plugins/mega-sdd/README.md` — + v3.28.0 What's new entry
- `README.md` — version bump
- `docs/superpowers/specs/2026-05-25-iter-42-deep-scan-manifest-preparse-and-per-slice-cache-design.md` — new spec doc

**Skill bumps:**
- `scan-codebase` 2.6.3 → 2.7.0 (MINOR — new step + cache schema bump)

**External research cited inline in spec:**
- Anthropic prompt caching docs (90% discount; subagent-token pattern)
- Real-time codebase indexing (cocoindex-io) — per-file hash invalidation
- Multi-agent caching arXiv 2601.06007 — separate static instructions from dynamic outputs

**Standing directives applied:**
- simplifikasi: 2 audit findings → 1 iter, 2 atomic changes in 2 files (1 SKILL + 1 reference doc)
- flawless: backward-compat schema migration; v1.0 readers treated as fully-stale (no rejection)
- reuse-first: extends Iter 30 shared-snapshot cache pattern + Iter 32 deep-scan subagent dispatch pattern + existing variable-substitution template format

**Plugin:** v3.27.1 → v3.28.0

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Next:** Iter 43 — T2 running budget tracker (Queue #4 — D1-003, HIGH impact per-bolt).

## [3.27.1] - 2026-05-25

### Iter 41 — Halt Taxonomy Sync Sweep

**Registry hygiene iter** (~1hr; PATCH bump — pure docs/contract additive; no code/behavior change). Reconciles canonical halt registry with reality.

**Problem (from Iter 38 audit D3-006):**

Pre-sweep gap analysis (`/tmp/halts_*.txt` diff):
- Halts emitted by skills + listed in orchestrate-flow but MISSING from `vault-contract.md §halt-protocol` enum: **9** (any strict envelope validator would reject these)
- Halts in vault-contract enum but missing from orchestrate-flow taxonomy: **5** (orchestrator couldn't decide auto-loop vs ALWAYS-STOP routing)
- Halts in enum but with no bulleted description: 9 (have richer §Type-specific guidance sections instead — false positives, no action)

**Resolution: surgical sync across 2 surfaces**

Surface 1 — `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`:
- Enum extended: +9 halt types
- Description list extended: +9 bulleted entries with provenance (`producer-skill v<X.Y>+, Iter <N>` + canonical resolution path)

Surface 2 — `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`:
- ALWAYS-STOP taxonomy: +5 entries (`oq_blocker`, `cross_squad_ambiguous`, `cycle_detected`, `interface_ref_missing`, `pbt_citation_invalid`)
- `pbt_citation_invalid` specifically closes an Iter 39 oversight (added to enum but missed orch taxonomy)

**Halts added to enum + description (9):**
1. `dedup_ambiguous` — generate-units v2.5+: multi-unit dedupe ambiguity
2. `hard_rule_unparseable` — generate-units v2.0+: ast-grep YAML parse failure
3. `hard_rule_violated` — execute-bolts v1.2+, Iter 3: post-flight scan violation
4. `memory_schema_mismatch` — memory v1.0+, Iter 5: schema_version drift
5. `prd_no_scopes_block_user_rejected_retrofit` — generate-intent v1.6+, Iter 28
6. `prd_path_missing` — diff-vault v1.3+, Iter 29
7. `prd_retrofit_low_confidence` — generate-intent v1.6+, Iter 28
8. `quality_gate_failed` — extract-intelligence v1.0+, Iter 9
9. `scope_not_declared_in_prd` — generate-intent v1.6+, Iter 28

**Halts added to orch ALWAYS-STOP taxonomy (5):**
1. `oq_blocker` (canonical; coexists with `oq_business_p1_unresolved` orch-level alias)
2. `cross_squad_ambiguous`
3. `cycle_detected`
4. `interface_ref_missing`
5. `pbt_citation_invalid` (Iter 39 oversight)

**Counts:**
- Enum: 37 → **46** halts (+9)
- Description list: 28 → **37** bullets (+9 provenance entries)
- Orch taxonomy: 39 → **44** entries (+5)

**No new files. No new halts in code. No skill version bumps** — pure registry reconciliation.

**Audit gap-finder commands** (reproducible):
```bash
# Enum extraction
grep -A0 "type: oq_blocker" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -1 | sed 's/.*type: //' | tr '|' '\n' | sort -u
# Description extraction
awk '/^## §halt-protocol/{flag=1} /^### Multiple blockers/{flag=0} flag' vault-contract.md | grep -oP '^- `[a-z_]+`'
# Orch extraction
grep -oP '^- `[a-z_]+`' plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
```

**Standing directives applied:**
- simplifikasi: 14 reconciliations → 2 atomic edits (1 enum extend + 1 description append)
- flawless: closes Iter 39 pbt_citation_invalid oversight + all Iter 28/29 propagation gaps + all Iter 3/5/6/9/20 historical gaps
- reuse-first: extends existing enum + existing description list; no schema changes

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Next:** Iter 42 — token optimization (priority 3 from audit queue): tier-2/tier-3 context references on-demand loading.

**Plugin:** v3.27.0 → v3.27.1

## [3.27.0] - 2026-05-25

### Iter 40 — Silent-Failure Path Closure (3 new halts)

**Robustness iter** (~2hr; MINOR bump — new orchestrator halts = chain behavior change). Closes 3 priority-1 silent-failure paths from Iter 38 e2e optimization audit (D3 robustness dimension).

**Problem (from audit):**
- D3-001: producer skill crashes before handoff emission → orchestrator silently proceeded with empty state OR failed downstream with cryptic file-not-found
- D3-002: handoff YAML lists artifact paths that don't exist on disk → next-stage consumer failed at the wrong boundary
- D3-003: execute-bolts `--resume` reads corrupt partial-state.json → silent overwrite with fresh state, hidden recovery loss

**Solution: 3 new ALWAYS-STOP halts**

- `handoff_missing` (orchestrate-flow v3.2.0+) — pre-validation step `b.0` verifies handoff YAML file exists + is non-empty before parse. Envelope includes `expected_handoff_path` + `last_known_step` (best-effort from checkpoint trail).
- `artifact_missing` (orchestrate-flow v3.2.0+) — post-validation step `b.vii` existence-checks every path in `artifacts: [paths]` array. Envelope includes `missing_paths: array` + `present_paths: array` for diagnostic clarity.
- `partial_state_corrupt` (execute-bolts v2.7.3+) — resume-time JSON parse attempt before consumption. Envelope includes `corrupt_backup_path` suggestion (`.corrupt-<ISO8601>`) for forensics.

**4-surface taxonomy sync** (per Iter 33+Iter 31 propagation directive):

1. `vault-contract.md §halt-protocol` enum + 3 new descriptions
2. `orchestrate-flow/SKILL.md` ALWAYS-STOP taxonomy + 2 new Procedure steps (`b.0` + `b.vii`)
3. `orchestrate-flow/references/handoff-contract.md` documents orchestrator-side detection for `artifacts:` field + pre-validation handoff presence check
4. `execute-bolts/SKILL.md §Partial-state contract` resume-time integrity check

**Plugin file changes:**
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.26.3 → 3.27.0
- `plugins/mega-sdd/README.md` — + v3.27.0 What's new entry
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — v3.1.2 → v3.2.0 (2 new procedure steps + 3 new ALWAYS-STOP taxonomy rows)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — orchestrator-side detection doc
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — v2.7.2 → v2.7.3 (+ partial-state integrity check)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — 3 new halts
- `docs/superpowers/specs/2026-05-25-iter-40-silent-failure-path-closure-design.md` — new spec doc
- `README.md` — version bump

**Why MINOR (not PATCH):** chains that previously silently-passed corrupt/missing state now halt explicitly. Backward-compat note: any user workflow that depended on "silent recovery" behavior will see new halts surface — by design.

**Standing directives applied:**
- simplifikasi: 3 halts → 5 surgical edits across existing surfaces (no new SKILL.md files, no new references)
- flawless: producer + consumer ship in-iter (orchestrate-flow emits + same orchestrate-flow consumes via halt-protocol). No deferred propagation. All 4 taxonomy surfaces updated.
- reuse-first: extends existing halt envelope (vault-contract.md), existing ALWAYS-STOP taxonomy, existing per-step JSONL checkpoint protocol (no new persistence)

**Audit source:** `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`

**Spec:** `docs/superpowers/specs/2026-05-25-iter-40-silent-failure-path-closure-design.md`

**Next:** Iter 41 — halt taxonomy sync sweep (priority 2 from audit queue) — verify all 38+ halts are present across all 4 surfaces.

**Plugin:** v3.26.3 → v3.27.0


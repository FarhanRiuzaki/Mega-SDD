> ⚠️ **v1.0 migration in progress.** This repo is being renamed from `grand-design-spec` to `mega-sdd`. The full revamp adds Spec-Driven Development (intent → units → bolts pipeline). See `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md`.

<div align="center">

# grand-design-spec

### Turn a PRD into a grounded knowledge base for AI dev tools.

*Bridge between **Inception** and **Construction** in your AI dev lifecycle (AI-DLC).*
*Anti-hallucination · Source-cited · Gap-honest.*

</div>

---

## What is this?

> **Without it**: every dev session re-reads the PRD, re-derives architecture, AI bakes different assumptions into the code.
> **With it**: PRD → 7-file vault → AI dev tools cite it → grounded code, less halu.

```mermaid
flowchart LR
    User([User]) -->|writes brief or attaches| Input[PRD / BRD / Figma<br/>or free-text brief]
    Input --> Flow{flow<br/>orchestrator}
    Flow -->|from-prompt v0.15| Seed[(seed-PRD.md)]
    Seed --> GDS[grand-design-spec]
    Flow -->|with PRD| GDS
    GDS --> Vault[(Vault<br/>7 .md + vault.json)]
    Vault -->|grounded context| AI[AI Dev Tools<br/>Claude Code · Cursor]
    AI -->|HITL review| Code([Shipped Code])

    Vault -.->|resolve-oq| Vault
    Vault -.->|vault-diff| Vault
    Vault -.->|drift-detect| Vault

    style Vault fill:#fef3c7,stroke:#d97706,stroke-width:3px
    style Seed fill:#fde68a,stroke:#d97706
    style Input fill:#dbeafe,stroke:#2563eb
    style Flow fill:#e9d5ff,stroke:#7e22ce,stroke-width:2px
    style Code fill:#d1fae5,stroke:#059669
```

| | |
|---|---|
| **Who runs it** | IT Architect or Developer (one command via `flow`) → Developer consumes via AI tools |
| **When** | Anytime — start from a brief, an attached PRD, or after a stakeholder meeting / PRD revision |
| **Output** | 7 markdown files + `vault.json` manifest: anti-halu, source-cited, gap-honest |
| **Mode** | Human-in-the-loop — stakeholders triage OQs; devs approve AI code citing vault. `flow` orchestrates skills with `--auto` for logistics; substance prompts always interactive |

---

## What's in the box

| Slash command | Use when | Skill |
|---------------|----------|-------|
| `/grand-design-spec:flow` ⭐ (v0.14, chains all v0.15) | "Do the next thing" — inspects state, proposes a chain, runs sub-skills with `--auto`. v0.15 chains all applicable skills by default. | lifecycle orchestrator |
| `/grand-design-spec:from-prompt` 🆕 (v0.15) | No PRD doc — just a free-text brief. Skill runs adaptive Q&A, writes seed-PRD.md as source for grand-design-spec | brief → seed-PRD elaborator |
| `/grand-design-spec:grand-design-spec` | Initial vault from PRD/BRD/Figma (or seed-PRD.md from from-prompt) | vault generator |
| `/grand-design-spec:resolve-oq` | Stakeholder meeting answered some OQs | OQ resolver |
| `/grand-design-spec:vault-diff` | PRD got a new version | vault evolution |
| `/grand-design-spec:drift-detect` | `mode=existing` — reconcile against live codebase | vault ↔ code drift |
| `/grand-design-spec:update` | Pull latest plugin from `origin/main` and refresh cache | plugin maintenance |

The four lifecycle skills share the vault as state. `flow` orchestrates them — inspects CWD, proposes a chain (e.g., "vault-diff → resolve-oq for new P1s"), confirms once, runs the chain in `--auto` mode while preserving every anti-halu rail. They all preserve OQ tag identity, ADR `D-XXX` numbering, and Changelog history across rounds. `update` is a maintenance command (no vault interaction).

> **See it before you install** → [`examples/`](./examples/) ships a sample PRD (a fictional leave-management web app called "TimeOff") that you can run through the skill to produce a reference vault. Read [`examples/README.md`](./examples/README.md) for the walkthrough.

---

## Quick start

Inside Claude Code, paste these two lines:

```text
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install grand-design-spec@grand-design-spec
```

Then in any session, pick whichever entry point matches your situation:

**A. You have a PRD/BRD doc** — attach it and let `flow` drive:

```text
You: /grand-design-spec:flow
     [attach PRD.pdf]
```

**B. You only have an idea** (no PRD yet) — type a free-text brief:

```text
You: /grand-design-spec:flow
     I want to build a leave-management web app for a 50-person team.
     Mobile + web, integrates with our HRIS, manager approval flow.
```

**C. Direct invocation** (skip orchestration, run one skill at a time):

```text
You: pecah PRD ini buat dev team
     [attach PRD.pdf]
```

`flow` is the recommended entry point — it inspects your CWD, proposes the right chain (e.g., `from-prompt → grand-design-spec → resolve-oq`), confirms once, and runs everything in `--auto` mode. Substance prompts (per-OQ resolutions, conflict choices) still pause for you. Anti-halu rails preserved at every step.

---

## How to install

### Option 1 — Claude Code (recommended)

Run inside Claude Code:

```text
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install grand-design-spec@grand-design-spec
```

The naming format is `<plugin>@<marketplace>` — both happen to be `grand-design-spec`.

#### Pin to a specific version

For team installs, pin to a tag so everyone gets the same version. Replace `<tag>` with a published release tag (see GitLab → Tags for the current list, e.g. `v0.6.0`):

```text
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git#<tag>
/plugin install grand-design-spec@grand-design-spec
```

To upgrade later, the easiest path is the bundled command:

```text
/grand-design-spec:update
```

It pulls `origin/main` (fast-forward only) and shows you the version diff, then prompts you to run the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. You can also do both steps manually:

```text
/plugin marketplace update grand-design-spec
/plugin install grand-design-spec@grand-design-spec
```

#### Non-interactive (CLI / CI)

```bash
claude plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
claude plugin install grand-design-spec@grand-design-spec
```

#### Share with your whole team via the project repo

```bash
claude plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git --scope project
```

This writes the marketplace declaration into `.claude/settings.json`. Anyone cloning your project gets prompted to install on first trust.

### Option 2 — Private GitLab repo

If the marketplace lives on a private repo, set a token so background updates work too:

```bash
export GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
```

Manual installs use your existing git credential helper, so whatever already works for `git clone` works here.

### Option 3 — Claude.ai / Claude Desktop

The `/plugin` flow is Claude-Code-only. For the web/desktop app:

1. Download the skill folder at `plugins/grand-design-spec/skills/grand-design-spec/` (contains `SKILL.md` + `references/`).
2. Zip that folder.
3. In Claude.ai → **Customize → Skills → + → Create skill** → upload the ZIP.

> Skills uploaded to Claude.ai are private to your account.

### Option 4 — Claude API

Available in beta with the code execution tool. Use the same skill folder as Option 3. See [Skills API Quickstart](https://docs.claude.com).

---

## How to use

Once installed, just talk to Claude Code normally. Each skill triggers on intent — paraphrases work. Common phrases:

| Skill | Trigger examples |
|-------|------------------|
| `flow` ⭐ (recommended) | "/grand-design-spec:flow" / "do the next thing" / "what should we run next?" |
| `from-prompt` 🆕 | Free-text brief in any session (auto-detected by `flow` Rule 0) — e.g. "I want to build a leave-management app, mobile + web, HRIS integration…" |
| `grand-design-spec` | "Pecah PRD ini buat dev team" / "Spec out this feature" / "Buat dev handoff" / "Prepare context for AI-assisted dev" |
| `resolve-oq` | "Resolve open questions" / "Walk through OQ list" / "Tackle the P1 blockers" |
| `vault-diff` | "PRD updated" / "PRD versi baru" / "Regenerate vault from new PRD" |
| `drift-detect` | "Drift detect" / "Vault vs code" / "Check codebase against vault" |

### What happens with `flow`

```
1. You invoke /grand-design-spec:flow.
   Optionally: attach a PRD/BRD/Figma OR type a free-text brief
   (orchestrator auto-detects which mode you're in).

2. flow inspects your CWD:
     - No vault + brief detected → from-prompt → grand-design-spec → resolve-oq
     - No vault + PRD attached    → grand-design-spec → resolve-oq
     - Vault exists + new PRD     → vault-diff → resolve-oq
     - Vault exists + mode=existing + codebase → drift-detect
     - Vault exists + open OQs    → resolve-oq

3. flow proposes the chain, confirms once, then runs each sub-skill
   with --auto for logistical prompts (output paths, scopes, batches).
   Substance prompts still interactive:
     - Per-OQ Resolve / OOS / Defer / Skip
     - Conflict resolution (vault-diff)
     - Drift action choices
     - Q&A elaboration in from-prompt (≤10 questions)

4. Each sub-skill emits a structured `blocker` artifact when it can't
   proceed (unresolved P1 in non-interactive mode, diff_conflict, etc.).
   flow halts the chain on blocker — no silent failures.

5. Final state: 7 markdown files + vault.json in your output folder,
   plus any companion artifacts (VAULT-DIFF.md, DRIFT-REPORT.md,
   DRIFT-ACTIONS.md, seed-PRD.md if from-prompt ran).
```

### Sample session — `flow` with prompt-input (v0.15)

```
You:    /grand-design-spec:flow
        I want to build a leave-management web app for a 50-person team.
        Mobile + web, integrates with our HRIS, manager approval flow.

flow:   No vault detected. Free-text brief detected (Rule 0).
        Proposed chain: from-prompt → grand-design-spec → resolve-oq.
        Confirm? [Y/n]
You:    Y

flow:   [from-prompt] Running adaptive Q&A. I'll skip topics already in
        your brief. Max 10 questions.
        Q1: Approval depth — single-step (manager only) or multi-step
            (manager → HR → CEO for >5 days)?
You:    Multi-step: manager always, HR for >5 days, no CEO.

        [...8 more questions on auth, edge cases, success metrics, etc.]

flow:   [from-prompt] Wrote ./seed-PRD.md (verbatim brief + 9 Q&A + body).
        [grand-design-spec] Project shape: web-app (inferred). Confirm? [Y/n]
You:    Y

flow:   [grand-design-spec] Generated 7 files + vault.json into
        ./leave-management-spec/. 14 Open Questions (4 P1, 7 P2, 3 P3).
        [resolve-oq] Resolution scope? (p1-only / p1-then-p2 / all / by-cat / single)
You:    p1-only

        [walks 4 P1 OQs interactively]

flow:   Chain complete. Vault at v1.1.
        4/4 P1 resolved · 10 OQs remain (P2/P3) · run resolve-oq again later.
```

### Sample session — `flow` with PRD attachment

```
You:    /grand-design-spec:flow
        [attach PRD.pdf]

flow:   No vault detected. PRD attached.
        Proposed chain: grand-design-spec → resolve-oq.
        Confirm? [Y/n]
You:    Y

flow:   [grand-design-spec] Output folder? (default: ./my-product-spec/)
You:    [enter]

flow:   Project shape: web-app (inferred). Confirm? [Y/n]
You:    Y

        [reads PRD, generates 7 files + vault.json]

flow:   12 Open Questions (5 P1, 5 P2, 2 P3).
        [resolve-oq] Walk P1 first? [Y/n]
You:    Y

        [walks 5 P1 OQs interactively]

flow:   Chain complete. Top remaining: 5 P2 in tech-stack section.
```

---

## What you get

```
<your-output-folder>/
├── 00-index.md          Navigation, exec summary, project readiness,
│                        reading paths by role, glossary, OQ roll-up
├── 01-overview.md       What, who, why, success metrics
├── 02-architecture.md   Components, relations, API contracts
├── 03-data-model.md     Entities (DBML), relations, constraints
├── 04-flows.md          User flows + system flows + Definition of Done
├── 05-decisions.md      ADR-lite — technical decisions with explicit source
├── 06-constraints.md    Technical, business, and non-functional requirements
└── vault.json           Machine-readable manifest: entities, flows, ADRs, OQs
                         (with status + priority), source docs. Markdown stays
                         human-authoritative; JSON is a derived index for AI dev
                         tools (Claude Code, Cursor) that load context fast.
```

Every numbered doc (`01–06`) follows the same shape:

| Section | Purpose |
|---------|---------|
| **TL;DR header** | 1 line in `compact` mode (default), 3 lines in `full` mode: what / for whom / when to read |
| **Body** | The actual content, grounded in PRD |
| **Sources** | Citations to PRD section / Figma frame / uploaded file |
| **Out of Scope** | What this doc explicitly does NOT cover |
| **Open Questions** | Tagged `OQ-{DOC_CODE}-{N}` with priority P1/P2/P3 |

> **v0.6 — design-system coverage (when sources have it)**: if your PRD, Figma URL, or uploaded tokens file explicitly contains UI components, design tokens, a11y standards, or voice/brand rules, the vault adds two extra sections — `02-architecture.md > UI components & patterns` and `06-constraints.md > Design system`. If sources are silent on these (most non-UI and many UI projects), the vault omits them entirely. Skill never prompts for design-system sources and never defaults to industry standards.

---

## After generation: resolving the Open Questions

A vault is a **gap-honest** document — it surfaces every unanswered question as a tagged `OQ-{DOC}-{N}` entry with `P1|P2|P3` priority. The intended workflow:

1. Generate the vault with `grand-design-spec` (or let `flow` chain it for you).
2. Bring the P1 Open Questions to your stakeholders (PM, BO, Architect, Compliance).
3. Run `/grand-design-spec:resolve-oq` directly, or just run `/grand-design-spec:flow` again — v0.15 chains `resolve-oq` by default whenever the vault has open OQs.

```text
You: /grand-design-spec:resolve-oq

Skill: Vault detected at ./mega-rencana-spec (v1.0).
       53 Open Questions: 13 P1, 29 P2, 11 P3.
       Resolution scope? (p1-only / p1-then-p2 / all-priorities / by-category / single-oq)
You:   p1-only

Skill: [walks through 13 P1 OQs one by one]
       For each: shows OQ + asks Resolve / Out of Scope / Defer / Skip.
       Captured answers land in the right doc (e.g., new ADR in 05-decisions, field constraint in 03-data-model).

Skill: Done. Vault now at v1.1.
       Resolved 9 · Out of Scope 2 · Deferred 2 · Skipped 0 · Still open 0 (P1).
       29 P2 + 11 P3 remain — re-run resolve-oq when you have answers.
```

**What `resolve-oq` does to the vault**:
- Marks resolved OQs as `[x]` with a pointer to where the answer landed.
- Promotes substantial answers into target sections (new `D-XXX` ADRs, new field constraints, new flow steps) — preserving the OQ tag as audit trail.
- Bumps vault version (`v1.0 → v1.1`) + appends a Changelog entry.
- Refuses "answer all OQs for me" — the skill captures **stakeholder** input, not Claude's guesses. Offers `Defer` instead.

---

## When the PRD revises: `vault-diff`

PRDs change. New stakeholder asks come in, edge cases get specified, scope shifts. The naive answer ("delete vault, regenerate from new PRD") wipes every resolved OQ, every ADR rationale, every Changelog entry — turning the vault back into a draft. Run `/grand-design-spec:vault-diff` instead — or `/grand-design-spec:flow` with the new PRD attached, and the orchestrator chains `vault-diff → resolve-oq` automatically (v0.15 default-on chaining).

```text
You: /grand-design-spec:vault-diff

Skill: Vault detected at ./mega-rencana-spec (v1.1).
       Path to new PRD?
You:   /Users/.../PRD_Mega_Rencana_v1.1.pdf

Skill: Diff scope? (full / oq-only / specific-docs)
You:   full

Skill: [reads both vault state + new PRD, computes structured diff]
       Wrote VAULT-DIFF.md to vault dir.
       Summary:
         Auto-resolved OQs: 4
         New OQs: 6
         Added: 2 flows, 1 decision
         Changed: 3 flows, 1 entity
         Removed (annotated): 1 flow
         CONFLICTS requiring user input: 2 Resolved-OQ + 1 Decision

       Walking conflicts first...

Skill: Resolved-OQ conflict #1: OQ-DC-2 (idempotency).
       Vault v1.1 resolved as 24h TTL (D-010, source: stakeholder meeting).
       New PRD §X.Y says 7-day TTL (per security review).
       Options: Supersede / Keep vault / Capture both / Skip
You:   Supersede

Skill: [walks remaining conflicts + auto-resolved OQs + added/changed/removed]
       Apply approved changes? (Y/N)
You:   Y

Skill: Done. Vault now at v1.2.
       Changelog updated. VAULT-DIFF.md retained for offline reference.
       6 new OQs introduced — run resolve-oq next round to capture answers.
```

**Hard guarantees**:
- Removed content is **annotated**, not deleted. Vault retains history.
- Conflicts surface to the user — skill never auto-decides between vault and new PRD.
- OQ identifiers, flow IDs, ADR `D-XXX` numbers are stable across diffs.
- Git safety: skill recommends commit-before-diff so the round is rollback-able.
- Refuses "auto-resolve all conflicts" — conflicts exist precisely because they need human judgment.

---

## When the code drifts: `drift-detect` (mode=existing only)

For revamp / extension projects, the vault is the target spec and the codebase is current reality. They drift apart silently — a field gets renamed in code without updating vault; a flow ships with a new step that violates a vault decision; a new endpoint lands without an ADR. By the time anyone notices in code review or production, fixing the drift is expensive. Run `/grand-design-spec:drift-detect` directly, or invoke `flow` from inside the codebase root — v0.15 chains `drift-detect` whenever the vault is `mode=existing` and a sibling codebase is detected.

```text
You: /grand-design-spec:drift-detect

Skill: Vault detected at ./mega-rencana-spec (v1.2, mode=existing). ✓
       Codebase root?
You:   /Users/.../m-smile-backend/

Skill: Detected Laravel 11 + PHP. Default scope dirs:
       app/ · database/migrations/ · routes/ · app/Jobs/ · app/Models/
       Use these? (y / customize)
You:   y

Skill: Drift scope? (full / schema-only / flows-only / decisions-only / single-doc)
You:   full

Skill: [scans 1,247 files in scope, ~2 min]
       Wrote DRIFT-REPORT.md.

       Findings:
         Decision violations:    3 (medium confidence)
         Decision unwritten:     2 (high)
         Schema drift (high):    7
         Flow drift (high):      4
         Confirmed matches:    34
       Total: 50 findings, 34 confirmed matches.

       PRIORITY-1 to review first:
         D-007 — source account filter only excludes 2 of 5 statuses.
         Idempotency strategy implemented but no ADR.
         monthly_failed_debit table missing in migrations.

       Walk findings interactively now? (y / save report only)
You:   y

Skill: [walks each finding, captures user choices into DRIFT-ACTIONS.md]
       Done. Action list:
         Code-side actions: 8 (assign to engineering)
         Vault-side actions: 5 (edit directly or via resolve-oq)
         Deferred: 3
```

**Hard guarantees**:
- **Direction-neutral**: every finding presents *"vault says X, code does Y"* — skill never picks a side.
- **Confidence-rated**: every finding is `high`, `medium`, or `low`. Low-confidence findings carry "verify manually" caveats.
- **No code execution**: skill writes reports. It never opens PRs, writes migrations, or modifies the vault directly. All actions captured for deliberate human follow-up via `DRIFT-ACTIONS.md`.
- **Decision violations surface PRIORITY-1**: these are the highest-impact drifts (compliance / architectural debt).
- **Heuristic, not static analysis**: false positives + false negatives both happen. Treat findings as triggers for review, not verdicts.

---

## Why use this

### The three failure modes it prevents

1. **Devs (or AI agents) interpret ambiguity as license to invent.**
   When the PRD is silent on a detail, the implementer fills it with "industry best practice" — which often doesn't match business intent. By the time anyone notices, the feature is built wrong.

2. **Architects can't review effectively.**
   The PRD is too business-focused. The Figma is visual-only. There's no structured artifact at architecture-review depth, so reviews become vibes-based.

3. **The ChatGPT-to-Claude prompt-engineering round-trip wastes time.**
   Without a PRD, you'd type a brief into ChatGPT, refine it through 10+ turns, paste the result into Claude, then re-prompt to get a structured spec. v0.15's `from-prompt` collapses that into a single in-Claude flow: brief → ≤10-question Q&A → seed-PRD → vault.

This plugin produces an artifact that:
- An IT Architect can review in **under 60 minutes**
- A developer (human or AI) can implement against **without inventing requirements**
- Surfaces **every gap** in the source material as a tagged, prioritized question
- Stays in sync as the PRD revises (`vault-diff`), as stakeholder meetings answer OQs (`resolve-oq`), and as the codebase drifts (`drift-detect`) — all chained automatically by `flow`

### Anti-hallucination guarantees

- **No invented entities, fields, endpoints, decisions, or behaviors.** Every non-trivial claim cites a PRD section, Figma frame, or source file.
- **Push-back built in.** If you say "just guess the rest", the skill refuses and offers to mark unknowns as Open Questions instead.
- **Open Question tagging.** Every gap gets `OQ-{DOC_CODE}-{N}` with priority P1/P2/P3 for stakeholder triage.
- **Verbatim brief capture in `from-prompt`.** When you input a free-text brief, `from-prompt` quotes it verbatim into `seed-PRD.md` — no paraphrasing, no "I think you meant…". Q&A answers also captured verbatim. Body sections cite the brief or specific Q&A turns. seed-PRD then becomes a normal source artifact for `grand-design-spec`, so the same anti-halu rails apply downstream.
- **Unified `blocker` envelope (v0.14).** When any sub-skill can't proceed in non-interactive mode, it emits a structured YAML `blocker` artifact with `type` (`oq_blocker` / `diff_conflict` / `drift_framework_mismatch` / etc.), context, and resolver owner — so `flow` halts the chain cleanly and downstream runners can route to ticketing / Slack / on-call. (Replaces v0.11's `OQ_BLOCKER`-only protocol.)
- **vault.json kept in sync.** Every regeneration / `resolve-oq` / `vault-diff` round updates the JSON manifest so AI consumers see the same state as humans reading markdown.
- **Reading paths by role.** Architect, Developer, QA, PM, and UI/UX each get a recommended reading order in `00-index.md`.
- **`flow` preserves rails by composition.** The orchestrator never touches content — it only inspects state, proposes chains, and dispatches sub-skills with `--auto` for logistics. Every per-OQ choice, conflict resolution, and substance decision still flows through the sub-skill's interactive prompts.

### Project shapes supported

The skill is general-purpose. It infers the shape from your PRD, then confirms with you:

| Shape | When to use |
|-------|-------------|
| `mobile-app` | Mobile-first product with backend (e.g. mobile banking, e-wallet) |
| `web-app` | Web-based product with backend (e.g. SaaS dashboard) |
| `api-only` | Backend service with no own UI (microservice, internal API) |
| `multi-platform` | Web + Mobile + Backend |
| `data-pipeline` | ETL / batch processing, no user UI |
| `custom` | Anything else (CLI, SDK, browser ext, IoT firmware, …) |

---

## How it works (workflow)

### `flow` — lifecycle orchestrator (v0.14, default-on chaining v0.15)

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Inspect CWD | Detects vault presence, vault mode (`new`/`existing`), open OQs, sibling codebase, free-text brief in user prompt |
| 1 | Apply 7-rule decision matrix | Rule 0: prompt detected → `from-prompt → grand-design-spec → resolve-oq` · Rule 1: no vault + PRD → `grand-design-spec → resolve-oq` · Rule 2: vault + new PRD → `vault-diff → resolve-oq` · Rule 4: vault + open OQs → `resolve-oq` · Rule 5: vault + mode=existing + codebase → `drift-detect` · Rules 3/6: edge cases. Rules 1/2/4/5/6 are default-on in v0.15 — every applicable lifecycle step chains automatically. |
| 2 | Propose chain | Echoes the proposed chain back to the user with one-line rationale per sub-skill |
| 3 | Confirm once | Single Y/n. After approval, runs the entire chain without re-prompting on logistics |
| 4 | Dispatch with `--auto` | Each sub-skill runs in `--auto` mode: logistical prompts auto-default, substance prompts (per-OQ choices, conflict resolutions, Q&A turns) still pause for user input |
| 5 | Halt on `blocker` | If any sub-skill emits a structured `blocker` artifact (unresolved P1, diff conflict, framework mismatch, etc.), `flow` halts the chain and surfaces the artifact for human resolution |
| 6 | Present | Final state summary: artifacts written, vault version, blockers raised, next-run hints |

### `from-prompt` — brief → seed-PRD elaborator (v0.15)

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Capture brief | User's free-text brief stored verbatim — no paraphrasing |
| 1 | Topic coverage scan | Internal map of which standard PRD topics (problem, users, success, scope, integrations, constraints, etc.) the brief already covers |
| 2 | Adaptive Q&A | Asks only uncovered topics. Hard cap: ≤10 questions. Skips anything explicit in brief. Always interactive — `--auto` does not bypass substance prompts here. |
| 3 | Body generation | Composes seed-PRD.md body sections with explicit citations: each claim points to "brief" or "Q&A turn N" |
| 4 | Write seed-PRD.md | Output: verbatim brief + Q&A transcript + cited body. Becomes a normal source artifact for `grand-design-spec` |
| 5 | Hand off | Returns path to seed-PRD.md so `grand-design-spec` (or `flow`) can pick up from there |

### `grand-design-spec` — vault generation (v0.10+ supports `--auto`)

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Output path setup | Skill asks for folder, validates, auto-creates. With `--auto`: defaults to project-name slug |
| 0.5 | Mode flag | `new` (greenfield) or `existing` (live codebase to reconcile). For `new`, also captures `mode_migrate_after` — the trigger event that flips the vault to `existing` (e.g., "first commit on main") |
| 0.6 | PRD status | `final` (signed-off) or `draft` (still in flux) — drives gap-handling behavior |
| 0.7 | Output mode | `compact` (default — table-first, ~40% lighter) or `full` (prose-rich for non-technical reviewers) |
| 1 | Inventory & read | Lists uploaded files (or reads seed-PRD.md from `from-prompt`), routes each to right reader; tries Figma MCP if URL given |
| 2 | Extract before writing | Builds internal map of components / entities / flows / decisions / gaps; also detects design-system flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) from sources |
| 3 | Generate 7 files + vault.json | Uses templates in `references/templates/` as scaffolds. Writes `vault.json` manifest alongside, with entities / flows / ADRs / OQs indexed for AI consumers |
| 4 | Self-check | Verifies grounding, readability, simplicity, output integrity, and markdown ↔ vault.json consistency |
| 5 | Present | Surfaces top P1 Open Questions for triage; points to companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) — or `flow` chains them automatically |

### `resolve-oq` — Open Questions resolution (v0.4+ supports `--auto` for logistics)

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Vault location | Auto-detects vault in CWD or asks; verifies 7 files + OQ roll-up exist |
| 0.5 | Resume detection | Detects prior resolution rounds via Changelog; offers continue or fresh start |
| 0.6 | Resolution scope | `p1-only` / `p1-then-p2` / `all-priorities` / `by-category` / `single-oq` |
| 1 | Parse OQ list | Reads all 6 numbered docs + roll-up; builds work queue based on scope |
| 2 | Loop per OQ | Per OQ: Resolve / Out of Scope / Defer / Skip; auto-classifies destination by tag prefix |
| 3 | Update metadata | Bumps vault version, appends Changelog entry with resolved/OOS/deferred counts |
| 4 | Self-check | Every queue item ended in an outcome; cross-refs resolve; tags preserved |
| 5 | Present | Stats summary + top remaining P1 blockers with tags |

### `vault-diff` — vault evolution across PRD revisions (v0.3+ supports `--auto`; conflicts emit `blocker` and pause)

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Inputs | Vault path + new source path(s); git safety check (commit-before-diff recommended) |
| 0.5 | Diff scope | `full` / `oq-only` / `specific-docs` |
| 1 | Read both states | Old vault (7 files) + new source (PDF/DOCX/MD); old source if available for precision |
| 2 | Re-extract | Build internal model from new source per same logic as `grand-design-spec` Step 2 |
| 3 | Compute diff | Per axis: entities, flows, decisions, OQs, constraints, design-system. 8 outcome categories |
| 4 | Generate diff report | Writes `VAULT-DIFF.md` artifact with conflicts at top, then auto-resolved OQs, added/changed/removed |
| 5 | Interactive walkthrough | Conflicts first (user decides Supersede / Keep / Both); then batch-confirm safe categories |
| 6 | Apply changes | Edit vault files; mark removed content with banner (don't delete); preserve all IDs |
| 7 | Update metadata | Bump vault version (patch or minor), append Changelog, update PRD source reference |
| 8 | Self-check | No silent drops, conflicts had user input, IDs unique, removed content retained |
| 9 | Present | Stats summary, conflicts deferred, path to `VAULT-DIFF.md` |

### `drift-detect` — vault vs codebase reconciliation (mode=existing only; v0.3+ supports `--auto` — skips interactive walkthrough, writes `DRIFT-REPORT.md` only)

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Inputs | Vault path + codebase path; verify `mode=existing`; git safety note |
| 0.5 | Drift scope | `full` / `schema-only` / `flows-only` / `decisions-only` / `single-doc` |
| 1 | Read vault | Read relevant docs based on scope; build vault-side model |
| 1.5 | Framework detection | Heuristic detect (Laravel / Rails / Spring / Express / Django / Flutter / etc.); propose default scope dirs |
| 2 | Scan codebase | Grep + Read across scope dirs: migrations, models, routes, jobs, ADR-related keywords, OQ tags |
| 3 | Compute drift | 8 outcome categories with confidence ratings (high / medium / low) |
| 4 | Generate report | Writes `DRIFT-REPORT.md` with Decision violations / unwritten at top |
| 5 | Interactive walkthrough | Optional; per finding: action choices captured into `DRIFT-ACTIONS.md` (Code-side / Vault-side / Deferred) |
| 6 | Update metadata | Append Changelog noting drift session (no version bump unless vault is also edited) |
| 7 | Self-check | Every finding rated, decision findings PRIORITY-1, no code execution |
| 8 | Present | Stats summary, PRIORITY-1 findings, path to artifacts |

---

## Customization

Defaults match a specific stack convention (PHP/Laravel + JS ecosystem, DBML for schema). To adapt:

- **Change schema format** → edit `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md` → "File-by-file content guide" → `03-data-model.md`
- **Pre-fill known components/stack** → edit `plugins/grand-design-spec/skills/grand-design-spec/references/templates/02-architecture.md`
- **Add org-specific terms** → edit `plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md` Glossary

---

## Repository structure

```
grand-design-spec/                            # marketplace repo root
├── .claude-plugin/
│   └── marketplace.json                      # marketplace catalog
├── plugins/
│   └── grand-design-spec/                    # the plugin
│       ├── .claude-plugin/plugin.json        # plugin manifest
│       ├── commands/                         # user-typeable slash commands
│       │   ├── flow.md                       # → orchestrator skill (v0.14)
│       │   ├── from-prompt.md                # → brief→seed-PRD skill (v0.15)
│       │   ├── grand-design-spec.md          # → main vault generator skill
│       │   ├── resolve-oq.md                 # → OQ resolver skill
│       │   ├── vault-diff.md                 # → vault evolution skill
│       │   ├── drift-detect.md               # → vault ↔ code drift skill
│       │   └── update.md                     # plugin maintenance: git pull + cache nudge
│       ├── skills/
│       │   ├── flow/                         # orchestrator skill (v0.14, chains all v0.15)
│       │   │   └── SKILL.md
│       │   ├── from-prompt/                  # brief→seed-PRD elaborator (v0.15)
│       │   │   └── SKILL.md
│       │   ├── grand-design-spec/            # main skill — vault generation
│       │   │   ├── SKILL.md
│       │   │   └── references/
│       │   │       ├── vault-contract.md     # shared schema + OQ + ID + halt-protocol (v0.13/v0.14)
│       │   │       └── templates/*.md        # 7 scaffolds (compact/full markers, v0.13)
│       │   ├── resolve-oq/                   # companion skill — OQ resolution
│       │   │   └── SKILL.md
│       │   ├── vault-diff/                   # companion skill — vault evolution
│       │   │   └── SKILL.md
│       │   └── drift-detect/                 # companion skill — vault vs codebase
│       │       └── SKILL.md
│       ├── README.md                         # plugin-level README
│       └── LICENSE
├── examples/                                 # sample PRD + reference vault
│   ├── README.md
│   └── timeoff/
│       ├── PRD-Examples.pdf
│       └── vault/                            # 7-file reference output
├── docs/superpowers/                         # spec + plan artifacts (v0.13+)
│   ├── specs/                                # audit findings, design docs
│   └── plans/                                # implementation plans
├── README.md                                 # this file (marketplace-level)
├── CONTRIBUTING.md                           # versioning + commit conventions (v0.13)
├── LICENSE                                   # MIT
├── CHANGELOG.md
└── .gitignore
```

---

## Contributing

Issues and PRs welcome. High-leverage contributions:

- Language support beyond ID/EN
- New template variants for additional domains
- Integrations with PRD tools (Notion, Confluence, Linear)
- Sample PRDs for testing edge cases

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md). Latest: **v0.15.0** — adds `/grand-design-spec:from-prompt` for prompt-input mode (eliminates ChatGPT-to-Claude round-trip — type a brief, skill runs ≤10-question Q&A, writes seed-PRD.md as source for the existing pipeline). `flow` orchestrator gains Rule 0 (auto-chain from-prompt → grand-design-spec → resolve-oq when prompt detected) and shifts Rules 1, 2, 4, 5, 6 from opt-in/conditional chaining to default-on — every flow invocation now naturally walks the lifecycle to its endpoint. Anti-halu rails preserved by composition. Earlier highlights: v0.14 introduced the flow orchestrator + `--auto` flag + unified `blocker` envelope; v0.13 closed audit findings + extracted shared `vault-contract.md`; v0.11 introduced `vault.json` + halt protocol + mode-migration trigger.

## License

MIT — see [LICENSE](./LICENSE).

# grand-design-spec

> **Turn a PRD + Figma into a 7-file dev handoff folder that no one needs to guess at.**

A Claude Code plugin marketplace that ships three paired skills covering the full vault lifecycle:

- **`grand-design-spec`** — converts product/business documents into a structured 7-file vault. Anti-hallucination by construction: every claim cites its source; gaps become tagged Open Questions, never guesses.
- **`resolve-oq`** — interactive resolver that walks the Open Questions roll-up after a stakeholder meeting, captures answers, and updates the vault with a version bump + Changelog. Answers go where they belong (e.g., new ADR in `05-decisions.md`); OQ identifiers are preserved as audit trail.
- **`vault-diff`** — evolves the vault when the PRD/BRD source revisions. Computes structured diff (added / changed / removed / conflicts), surfaces Resolved-OQ-vs-new-PRD conflicts for explicit user resolution, and applies approved changes without losing prior OQ history or ADR provenance. The naive alternative ("delete and regenerate") destroys every captured decision — this skill makes vaults survive past sprint 1.

---

## Quick start

Inside Claude Code, paste these two lines:

```text
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install grand-design-spec@grand-design-spec
```

Then in any session:

```text
You: pecah PRD ini buat dev team
     [attach PRD.pdf]
```

The skill takes over from there — asks you a few questions, then writes 7 markdown files into the folder you choose. That's it.

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

For team installs, pin to a tag so everyone gets the same version:

```text
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git#v0.6.0
/plugin install grand-design-spec@grand-design-spec
```

To upgrade later:

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

Once installed, just talk to Claude Code normally. The skill triggers automatically on phrases like:

| Trigger phrase | Language |
|----------------|----------|
| "Pecah PRD ini buat dev team" | ID |
| "Spec out this feature" | EN |
| "Buat dev handoff dari PRD ini" | ID |
| "Translate this BRD into architecture docs" | EN |
| "Prepare context for AI-assisted dev" | EN |
| "Siapkan context buat AI dev" | ID |

Or paraphrases — the skill matches intent, not exact wording.

### What happens next

```
1. You attach the PRD/BRD (PDF, DOCX, MD, TXT).
   Optionally: drop a Figma URL.

2. Claude asks a few quick questions:
     - Output folder path?
     - Implementation mode? (`new` greenfield / `existing` codebase)
     - PRD status? (`final` signed-off / `draft` still in flux)
     - **Output mode?** (`compact` default — table-first, ~40% lighter / `full` — prose-rich for non-technical reviewers)
     - Project shape? (mobile-app / web-app / api-only / …)
     - If `draft` and gap count > 10: proceed or clarify first?
       (`final` skips this — every gap auto-routes to Open Questions.)

3. Claude reads the source, extracts components / entities / flows / gaps,
   and writes 7 markdown files into your folder.

4. Claude surfaces the top P1 Open Questions for you to resolve
   with your PO before dev starts.
```

### Sample session

```
You:    Help me pecah PRD ini buat dev team. PRD-nya gue attach.
        [attach PRD.pdf]

Skill:  Output folder path? (default: my-product-spec/)
You:    my-product-spec/

Skill:  Project shape: detected `web-app` from PRD. Confirm?
You:    Ya.

Skill:  [reads PRD]
        [identifies 12 gaps in PRD]
        Gap list > 10 — proceed atau klarifikasi dulu?
You:    Lanjut, semua gap masuk Open Questions.

Skill:  [generates 7 files into my-product-spec/]
        Done. 12 Open Questions across 6 docs.
        Top blockers: 5 P1 items in tech stack and PRD inconsistencies.
        See 00-index.md → Open Questions roll-up.
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
└── 06-constraints.md    Technical, business, and non-functional requirements
```

Every numbered doc (`01–06`) follows the same shape:

| Section | Purpose |
|---------|---------|
| **TL;DR header** | 3 lines: what / for whom / when to read |
| **Body** | The actual content, grounded in PRD |
| **Sources** | Citations to PRD section / Figma frame / uploaded file |
| **Out of Scope** | What this doc explicitly does NOT cover |
| **Open Questions** | Tagged `OQ-{DOC_CODE}-{N}` with priority P1/P2/P3 |

> **v0.6 — design-system coverage (when sources have it)**: if your PRD, Figma URL, or uploaded tokens file explicitly contains UI components, design tokens, a11y standards, or voice/brand rules, the vault adds two extra sections — `02-architecture.md > UI components & patterns` and `06-constraints.md > Design system`. If sources are silent on these (most non-UI and many UI projects), the vault omits them entirely. Skill never prompts for design-system sources and never defaults to industry standards.

---

## After generation: resolving the Open Questions

A vault is a **gap-honest** document — it surfaces every unanswered question as a tagged `OQ-{DOC}-{N}` entry with `P1|P2|P3` priority. The intended workflow:

1. Generate the vault with `grand-design-spec`.
2. Bring the P1 Open Questions to your stakeholders (PM, BO, Architect, Compliance).
3. Run `/grand-design-spec:resolve-oq` to walk through the OQ list interactively and capture the answers back into the vault.

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

PRDs change. New stakeholder asks come in, edge cases get specified, scope shifts. The naive answer ("delete vault, regenerate from new PRD") wipes every resolved OQ, every ADR rationale, every Changelog entry — turning the vault back into a draft. Run `/grand-design-spec:vault-diff` instead.

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

## Why use this

### The two failure modes it prevents

1. **Devs (or AI agents) interpret ambiguity as license to invent.**
   When the PRD is silent on a detail, the implementer fills it with "industry best practice" — which often doesn't match business intent. By the time anyone notices, the feature is built wrong.

2. **Architects can't review effectively.**
   The PRD is too business-focused. The Figma is visual-only. There's no structured artifact at architecture-review depth, so reviews become vibes-based.

This skill produces an artifact that:
- An IT Architect can review in **under 60 minutes**
- A developer (human or AI) can implement against **without inventing requirements**
- Surfaces **every gap** in the source material as a tagged, prioritized question

### Anti-hallucination guarantees

- **No invented entities, fields, endpoints, decisions, or behaviors.** Every non-trivial claim cites a PRD section, Figma frame, or source file.
- **Push-back built in.** If you say "just guess the rest", the skill refuses and offers to mark unknowns as Open Questions instead.
- **Open Question tagging.** Every gap gets `OQ-{DOC_CODE}-{N}` with priority P1/P2/P3 for stakeholder triage.
- **Reading paths by role.** Architect, Developer, QA, PM, and UI/UX each get a recommended reading order in `00-index.md`.

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

### `grand-design-spec` — vault generation

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Output path setup | Skill asks for folder, validates, auto-creates |
| 0.5 | Mode flag | `new` (greenfield) or `existing` (live codebase to reconcile) |
| 0.6 | PRD status | `final` (signed-off) or `draft` (still in flux) — drives gap-handling behavior |
| 0.7 | Output mode | `compact` (default — table-first, ~40% lighter) or `full` (prose-rich for non-technical reviewers) |
| 1 | Inventory & read | Lists uploaded files, routes each to right reader; tries Figma MCP if URL given |
| 2 | Extract before writing | Builds internal map of components / entities / flows / decisions / gaps |
| 3 | Generate 7 files | Uses templates in `references/templates/` as scaffolds |
| 4 | Self-check | Verifies grounding, readability, simplicity, output integrity |
| 5 | Present | Surfaces top P1 Open Questions for you to triage with PO |

### `resolve-oq` — Open Questions resolution

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

### `vault-diff` — vault evolution across PRD revisions

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
│       ├── skills/
│       │   ├── grand-design-spec/            # main skill — vault generation
│       │   │   ├── SKILL.md
│       │   │   └── references/templates/*.md # 7 scaffolds
│       │   ├── resolve-oq/                   # companion skill — OQ resolution
│       │   │   └── SKILL.md
│       │   └── vault-diff/                   # companion skill — vault evolution
│       │       └── SKILL.md
│       ├── README.md                         # plugin-level README
│       └── LICENSE
├── README.md                                 # this file (marketplace-level)
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

See [CHANGELOG.md](./CHANGELOG.md). Latest: **v0.6.0** — adds optional design-system coverage (UI components, tokens, a11y, voice/brand) when sources explicitly contain it. Strict source-mirror — never inferred from project shape, never defaulted to industry standards.

## License

MIT — see [LICENSE](./LICENSE).

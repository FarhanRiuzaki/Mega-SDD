# grand-design-spec

> **Turn a PRD + Figma into a 7-file dev handoff folder that no one needs to guess at.**

A Claude Code plugin marketplace that ships **`grand-design-spec`** — a skill that converts product/business documents into structured architecture specs ready for engineering teams (human or AI).

It is **anti-hallucination by construction**: every claim cites its source. If the PRD doesn't say it, the skill won't write it — it goes into a tagged Open Question instead.

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
     - **PRD status?** (`final` signed-off / `draft` still in flux)
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

| Step | Phase | What happens |
|------|-------|--------------|
| 0 | Output path setup | Skill asks for folder, validates, auto-creates |
| 1 | Inventory & read | Lists uploaded files, routes each to right reader; tries Figma MCP if URL given |
| 2 | Extract before writing | Builds internal map of components / entities / flows / decisions / gaps |
| 3 | Generate 7 files | Uses templates in `references/templates/` as scaffolds |
| 4 | Self-check | Verifies grounding, readability, simplicity, output integrity |
| 5 | Present | Surfaces top P1 Open Questions for you to triage with PO |

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
│       ├── skills/grand-design-spec/         # the skill itself
│       │   ├── SKILL.md
│       │   └── references/templates/*.md     # 7 scaffolds
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

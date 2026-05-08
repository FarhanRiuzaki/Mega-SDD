# grand-design-spec

A Claude skill that converts PRD/BRD documents and Figma designs into a 7-file **grand design** folder, structured for handoff to development teams (human or AI).

The skill is **anti-hallucination by construction**: every claim must cite its source. Ambiguities become Open Questions, not guesses. "Out of Scope" is always explicit.

---

## Why this exists

When a Product team hands a PRD + Figma to engineers, two things often happen:

1. **The dev team interprets ambiguity as license to invent.** Especially when AI dev agents are in the loop — they fill gaps with "best practice defaults" that often don't match the business intent.
2. **Architects can't review effectively.** The PRD is too business-focused, the Figma is visual-only. There's no structured artifact at architecture-review depth.

This skill produces a 7-file artifact that:
- An IT Architect can review in <60 minutes.
- A developer (or AI dev agent) can implement against without inventing requirements.
- Surfaces **every gap** in the source material as a tagged, prioritized Open Question.

## Project shapes supported

The skill is general-purpose and adapts to your project shape. Pre-templated shapes:

- **`mobile-app`** — Mobile UI + Backend + Integrations (e.g. mobile banking, e-wallet)
- **`web-app`** — Web Frontend + Backend + Integrations (e.g. SaaS dashboard)
- **`api-only`** — Backend service with no own UI (e.g. microservice, internal API)
- **`multi-platform`** — Web + Mobile + Backend (e.g. cross-platform SaaS)
- **`data-pipeline`** — ETL/batch processing, no user UI (e.g. reconciliation engine, reporting job)
- **`custom`** — Any other shape (CLI tool, library/SDK, browser extension, IoT firmware, etc.) — skill asks user to describe layers.

The skill **infers** shape from the PRD content during extract phase, then **confirms** with the user before generating files.

---

## Output structure

```
<your-output-folder>/
├── 00-index.md          Navigation + Executive Summary + Project Readiness Status
│                        + Reading paths by role + Glossary + Open Questions roll-up
├── 01-overview.md       What, who, why, success metrics
├── 02-architecture.md   Components, relations, API contracts
├── 03-data-model.md     Entities (DBML), relations, constraints
├── 04-flows.md          User flows + system flows + Definition of Done per flow
├── 05-decisions.md      ADR-lite: technical decisions with explicit source
└── 06-constraints.md    Technical, business, non-functional requirements
```

Every numbered doc (`01–06`) contains:

- A **TL;DR header** (3 lines: what / for whom / when to read)
- The body content
- A **Sources** section (citations to PRD/Figma)
- An **Out of Scope** section (or `TBD - confirm with PO`)
- An **Open Questions** section (tagged `OQ-{DOC_CODE}-{N}` and prioritized P1/P2/P3)

---

## How it works (workflow)

1. **Step 0 — Output path setup.** Skill asks the user for an output folder path, validates it, and auto-creates it.
2. **Step 1 — Inventory and read.** Skill lists uploaded files (PDF/DOCX/MD/TXT) and routes each to the right reader. If a Figma URL is provided, it tries Figma MCP; otherwise asks the user how to proceed.
3. **Step 2 — Extract before writing.** Skill builds an internal map of components, entities, flows, decisions, and gaps. If gaps > 10, asks user before continuing.
4. **Step 3 — Generate 7 files.** Uses templates in `references/templates/` as scaffolds.
5. **Step 4 — Self-check.** Verifies grounding, readability (EN/ID convention, anti-AI-tone, glossary, cross-ref budget), simplicity, output integrity.
6. **Step 5 — Present.** Surfaces top blockers (P1 Open Questions) for the user to resolve before dev starts.

---

## Installation

### Claude Code (personal — available across all projects)

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills

# Via SSH (requires SSH key configured on GitHub)
git clone git@gitlab.com:airnd1/grand-design-spec.git

# Or via HTTPS (works without SSH setup)
git clone https://gitlab.com/airnd1/grand-design-spec.git
```

### Claude Code (project-scoped — committed to a specific repo)

```bash
cd /path/to/your/project
mkdir -p .claude/skills
cd .claude/skills

# Via SSH
git clone git@gitlab.com:airnd1/grand-design-spec.git

# Or via HTTPS
git clone https://gitlab.com/airnd1/grand-design-spec.git
```

### Claude.ai / Claude Desktop (web/desktop)

1. Download or zip the `grand-design-spec/` folder.
2. In Claude.ai, go to **Customize → Skills**.
3. Click **+ → Create skill** and upload the ZIP.

> Custom skills uploaded to Claude.ai are private to your account.

### Claude API

Available in beta for API users with the code execution tool. See [Skills API Quickstart](https://docs.claude.com).

---

## Usage

Once installed, just describe what you want. The skill triggers automatically when you say things like:

- "Help me break down this PRD for the dev team"
- "Spec out this feature for backend"
- "Prepare dev handoff docs from this PRD + Figma"
- "Translate this BRD into architecture docs"

Then attach the PRD (PDF preferred), provide the Figma URL if available, and answer the few clarifying questions the skill asks (output path, gap-handling preference, etc.).

### Example

```
You: Help me pecah PRD ini buat dev team. PRD-nya gue attach.
[Attach PRD.pdf]

Skill: Output folder path? (default: my-product-spec/)
You: my-product-spec/

Skill: Akan dibuat di /your/path/my-product-spec/ — lanjut?
You: Ya.

Skill: [reads PRD]
       [identifies 12 gaps in PRD]
       Gap list >10 — proceed atau klarifikasi dulu?
You: Lanjut, semua gap masuk Open Questions.

Skill: [generates 7 files]
       Done. 12 Open Questions across 6 docs.
       Top blockers: 5 P1 items in tech stack and PRD inconsistencies.
```

---

## Anti-hallucination guarantees

- **No invented entities, fields, endpoints, decisions, or behaviors.** Every non-trivial claim cites a PRD section, Figma frame, or other source.
- **Push-back built in.** If the user says "just guess the rest", the skill refuses and offers to mark unknowns as Open Questions instead.
- **Open Question tagging.** Every gap is tagged `OQ-{DOC_CODE}-{N}` with priority P1/P2/P3 for stakeholder triage.
- **Reading paths by role.** Architect, Developer, QA, PM, and UI/UX each get a recommended reading order in `00-index.md`.

---

## Folder structure of this skill

```
grand-design-spec/
├── README.md                       (this file)
├── LICENSE                         MIT
├── .gitignore
├── SKILL.md                        Skill instructions for Claude
└── references/
    └── templates/                  Scaffolds the skill fills in at generation time
        ├── 00-index.md
        ├── 01-overview.md
        ├── 02-architecture.md
        ├── 03-data-model.md
        ├── 04-flows.md
        ├── 05-decisions.md
        └── 06-constraints.md
```

---

## Customization

The skill defaults match a specific stack & convention (PHP/Laravel + JS ecosystem, DBML for schema). To adapt to your stack:

- Edit `SKILL.md` → "File-by-file content guide" → `03-data-model.md` to change the default schema format.
- Edit `references/templates/02-architecture.md` to pre-fill known components or stack.
- Edit `references/templates/00-index.md` Glossary to include your org-specific terms.

---

## Contributing

Issues and PRs welcome. Particularly useful contributions:

- New language support beyond ID/EN
- Additional template variants (e.g. for non-banking domains)
- Integrations with PRD tools (Notion, Confluence)
- Test cases with sample PRDs

---

## License

MIT — see [LICENSE](./LICENSE).

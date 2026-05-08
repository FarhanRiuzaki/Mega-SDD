---
name: grand-design-spec
version: 0.3.0
description: Break down PRD/BRD and Figma into 7 markdown files for dev team handoff. Triggers — "spec out this feature", "buat dev handoff", "pecah PRD ini buat dev", or paraphrases for dev / AI dev context.
---

# Grand Design Spec Generator

Converts PRD/BRD + Figma into 7 markdown files inside a user-specified folder, optimized for **anti-hallucination dev handoff** — meaning a downstream dev (human or AI) can implement from these docs without inventing requirements.

## When to use this skill

Trigger this skill for any of the following user requests, **whether stated literally or paraphrased**:

- "Break down this PRD for the dev team" / "pecah PRD ini buat dev"
- "Spec out this feature" / "buat dev handoff"
- "Prepare context for AI-assisted dev" / "siapkan context buat AI dev"
- "Translate business requirements into architecture docs"
- "Convert PRD + Figma into dev-ready specifications"
- Any request to take a product/business document and produce structured dev specs

The skill is **anti-hallucination by construction**: every claim cites its source, ambiguities become Open Questions (not guesses), Out of Scope is always explicit.

## Core principle

> **Berlandaskan PRD/uploaded docs. Jangan ngarang bebas.**
> **If it is not explicit in the source, it does NOT go in the body. It goes in Open Questions.**

This applies to every doc. No "industry best practice" insertions, no "probably they meant X" guesses, no filler sentences. The source documents (PRD/BRD/Figma/uploaded files) are the ONLY ground truth. If the source is silent, the answer is "Open Question", not Claude's prior knowledge.

## Simplicity policy

**Default: as simple as possible.** Each doc should be the shortest version that still answers what its readers need. Cut anything that doesn't earn its place.

**Exception: `04-flows.md` may be complete-wajar.** Flows describe step-by-step behavior with branching, error paths, and Definition of Done — completeness matters more than terseness. Length proportional to PRD complexity is fine here; for other docs, terseness wins.

## Project Shape Registry

This skill is **general-purpose** — it works for any kind of project, not just mobile banking. Project shape determines the sub-sections inside `02-architecture.md` and `04-flows.md`, and the reading paths inside `00-index.md`.

The skill **infers** the project shape from PRD content during Step 2 (extract), then **confirms** it with the user before generating files.

### Pre-templated shapes (most common)

| Shape | When to use | Layers (for `02-architecture.md`) | Flow types (for `04-flows.md`) | Roles (for `00-index.md` reading paths) |
|-------|-------------|-----------------------------------|--------------------------------|----------------------------------------|
| `mobile-app` | Mobile-first product with backend (e.g. M-Smile, e-wallet) | Mobile / Frontend, Backend, Integrations | User flows (mobile), Backend / system flows, Cross-cutting | Architect, Mobile Dev, BE Dev, QA, PM, UI/UX |
| `web-app` | Web-based product (SaaS, dashboard) with backend | Web Frontend, Backend, Integrations | User flows (web), Backend / system flows, Cross-cutting | Architect, FE Dev, BE Dev, QA, PM, UI/UX |
| `api-only` | Backend service with no own UI (microservice, internal API, webhook handler) | Backend, Integrations | Backend / system flows, Consumer-facing flows (when external clients hit the API) | Architect, BE Dev, QA, PM, External integrator |
| `multi-platform` | Has web + mobile + backend (e.g. Arygas-style) | Web Frontend, Mobile, Backend, Integrations | User flows (web), User flows (mobile), Backend / system flows, Cross-cutting | Architect, FE Dev, Mobile Dev, BE Dev, QA, PM, UI/UX |
| `data-pipeline` | ETL, batch processing, no user-facing UI (e.g. reconciliation engine, reporting job) | Source connectors, Processors, Sinks, Integrations | Pipeline flows, Error/recovery flows, Operational flows | Architect, Data Engineer, QA, PM, Data analyst |

### Custom fallback

If the project doesn't fit any of the 5 pre-templated shapes:

- Use shape `custom`.
- Skill MUST ask user to describe layers/components and roles in their own words.
- Generated sub-sections must derive from the user's description, not invented.

> Examples of custom shapes: CLI tool, library/SDK, browser extension, embedded system, hybrid mobile-cli, IoT device firmware.

### Inference rules (Step 2)

When extracting from PRD, infer shape using these heuristics:

- PRD mentions "mobile app", "M-Smile", "iOS", "Android", "push notification" → likely `mobile-app` or `multi-platform`
- PRD mentions "web", "browser", "dashboard", "SaaS" + backend → likely `web-app`
- PRD describes API endpoints/integrations only, no UI → likely `api-only`
- PRD covers both web and mobile UIs explicitly → `multi-platform`
- PRD describes batch jobs, scheduled processors, no user-facing UI flows → `data-pipeline`
- None of the above → `custom`, ask user

If inference confidence is low (e.g. PRD ambiguous, mentions both mobile and web casually), skill MUST present its inference with reasoning and ask user to confirm or override.

---

## Inputs

The user typically provides one or more of:

- **PRD/BRD file**: PDF (priority), DOCX, MD, or TXT. Location auto-detected per environment (sandbox: `/mnt/user-data/uploads/`; local Claude Code: ask user or use CWD). See Step 1.
- **Figma URL**: Use Figma MCP if connected. Run `tool_search(query="figma")` to check. If no Figma MCP and no screenshots, ASK the user before proceeding — do not guess UI structure.
- **Output folder path**: user MUST specify (see Step 0). Skill never assumes a path silently.
- **Optional context**: existing system docs, tech stack constraints, prior architecture decisions.

If critical inputs are missing or unclear, **ask before generating**. Better 5 upfront questions than 7 docs of guesses.

---

## Workflow

### Step 0: Output path setup (MANDATORY, before any generation)

Skill MUST get an explicit output folder path from the user before generating any file.

1. **Ask** the user for the output folder path. Suggest a sensible default derived from the PRD project name (slug-cased).
   - If `ask_user_input_v0` is available, use it with options like `["Pakai default '<slug>/'", "Custom path", "Cancel"]`.
   - Otherwise ask plainly: *"Output folder path? (default: `<slug>/`)"*

2. **Detect runtime environment** sebelum resolve path:
   - Run `pwd && uname -a 2>/dev/null` (or equivalent platform check).
   - **Sandbox detection**: pwd is `/` and `/mnt/user-data` exists → Claude.ai / Desktop sandbox (Linux container).
   - **Local detection**: pwd is user's project dir, no `/mnt/user-data` → Claude Code on Mac/Linux/Windows.

3. **Resolve & sanity-check** path against environment:
   - **Relative path** (e.g. `mega-rencana-spec/`):
     - Sandbox → resolve to `/mnt/user-data/outputs/<path>`
     - Local → resolve to `<CWD>/<path>`
   - **Absolute path**:
     - Sandbox + path starts with `/Users/`, `/home/<not-claude>/`, `C:\`, `D:\`, or `~/` (non-resolvable) → **REJECT**. Tell user: *"Path ini terlihat seperti filesystem local Mac/Windows, tapi gue running di container Linux Anthropic. Kalau gue create, foldernya cuma ada di container ini (ephemeral, bakal hilang abis session). Pilihan: (a) ganti ke path valid di container, e.g. `/mnt/user-data/outputs/<your-folder>/`, atau (b) pakai Claude Code di Mac/Windows lo untuk akses native filesystem."*
     - Local + path starts with `/mnt/` or `/home/claude` → **REJECT**. Tell user: *"Path ini terlihat seperti container Anthropic. Lo running di local environment. Kasih path local lo, contoh `/Users/<you>/projects/<folder>/`."*
     - Otherwise → use as-is.
   - **Forbidden patterns**: whitespace at edges, control chars, `..` traversal out of writable area → reject + ask again.

4. **Recheck before creating**:
   - Echo the **fully-resolved absolute path** back: *"Akan dibuat di: `<resolved-absolute-path>` — lanjut?"*
   - If folder exists and non-empty: *"Folder sudah ada dan berisi file. Overwrite, append, atau cancel?"* — never silently overwrite.

5. **Auto-create** the folder once user confirms:
   - **Mac / Linux / WSL / Git Bash**: `mkdir -p <resolved-path>`
   - **Windows native cmd.exe** (modern, ≥ Windows 7): `mkdir <resolved-path>` (auto-creates parents)
   - **Windows PowerShell**: `New-Item -ItemType Directory -Path <resolved-path> -Force`
   - Verify creation succeeded (`ls -la <resolved-path>` or `dir <resolved-path>`) before proceeding.

6. **Persist** the resolved path explicitly. After Step 0 confirmation:
   - Echo a state line: `OUTPUT_DIR=<resolved-absolute-path>`.
   - In every subsequent file write (Step 3, Step 5), prefix the file path with **exactly** this `OUTPUT_DIR`. Do NOT default back to `/mnt/user-data/outputs/grand-design/` if the user picked something else.
   - Re-echo `OUTPUT_DIR=...` at the start of each major step as a reminder to self.

> Skill never proceeds to Step 0.5 without a confirmed, created `OUTPUT_DIR`.

### Step 0.5: Implementation mode flag (MANDATORY, after path setup)

The vault is a **lock against requirements** (PRD/BRD), not against existing codebase. This skill does NOT read the codebase. The mode flag is **metadata** that instructs downstream AI dev consumers (Claude Code, Cursor) how to behave when reading the vault.

1. **Ask** the user (use `ask_user_input_v0` if available):
   - **`new`** — greenfield project, no existing codebase to reconcile with.
   - **`existing`** — extending or modifying a live codebase. Downstream AI consumers must verify with user before touching existing code.

2. **Persist mode flag** explicitly:
   - Echo: `IMPLEMENTATION_MODE=new | existing`
   - This flag is recorded in `00-index.md` Vault Lock Status section.
   - This flag drives downstream consumer instructions in `00-index.md` "Implementation Notes for AI Consumers" section.

3. **Do NOT ask for codebase path, repo URL, or existing entity names.** That is the job of downstream AI dev consumer when it reads the vault. This skill stays focused on the requirement → vault transformation.

> Skill never proceeds to Step 1 without a confirmed `IMPLEMENTATION_MODE`.

### Step 1: Inventory and read

1. **Identify input file location** based on environment detected in Step 0:
   - **Sandbox** (Claude.ai / Desktop): list `/mnt/user-data/uploads/`.
   - **Local** (Claude Code on Mac/Linux/Windows): assume CWD or **ask user** explicitly: *"Where are the PRD/BRD files? (e.g. `./prd.pdf`, `~/Downloads/`, or absolute path)"*. Do NOT assume a path silently.

2. For each file, route to the right reader:
   - PDF → use `pdf-reading` skill (or platform PDF tool)
   - DOCX → use `docx` skill (or platform DOCX tool)
   - MD / TXT → read directly

3. **For Figma URLs** (if PRD references one):
   - Run `tool_search(query="figma")` to check if Figma MCP tools are loaded.
   - If found (e.g. `Figma:get_design_context`, `Figma:get_screenshot`, `Figma:get_metadata`), use them with the URL/`node-id` to fetch frame info.
   - If MCP not loaded but available in registry: optionally call `search_mcp_registry(["figma"])` then `suggest_connectors([directoryUuid])` to prompt user to connect.
   - If user declines connection / no MCP / no screenshots → **ask user**: *"Figma not accessible. Skip dan rely PRD only, atau lo kasih screenshots manual?"* Do NOT invent UI structure from imagination.

4. **Read every input fully**. No skimming. The whole point is grounding.

### Step 2: Extract before writing

Before generating any markdown, build an internal map of:

- **Product**: what / who / why
- **Project shape**: infer from PRD content per the Project Shape Registry. Default candidates: `mobile-app`, `web-app`, `api-only`, `multi-platform`, `data-pipeline`, or `custom`.
- **Components**: explicit system parts mentioned, grouped by inferred layers
- **Data entities**: names, fields, relations
- **Flows**: user journeys, system processes
- **Decisions**: technical choices stated with rationale
- **Constraints**: technical, business, regulatory, non-functional
- **Gaps**: every ambiguity → goes to Open Questions, never to body

**Confirm project shape with user**:

- Present inferred shape + reasoning: *"Berdasarkan PRD, gue infer shape = `<shape>`. Reasoning: <2-3 reason>. Confirm atau override?"*
- If user overrides → use new shape.
- If shape = `custom` (no clear fit) → ask user: *"Project shape gak fit ke 5 shape pre-templated. Lo describe layers (e.g. 'CLI tool, ada engine + plugin system') dan roles (e.g. 'developer + admin') yang ada."*
- Persist shape: `PROJECT_SHAPE=<shape>`. This drives sub-section structure in Step 3.

If the gap list is large (>10 items), stop and ask user whether to proceed or get clarification first.

### Step 3: Generate 7 files

Output to the **resolved output folder from Step 0** (referred to as `<OUTPUT_DIR>` below):

```
<OUTPUT_DIR>/
├── 00-index.md          ← Navigation + Vault Lock + Implementation Notes for AI Consumers + OQ roll-up
├── 01-overview.md       ← What, who, why, success criteria
├── 02-architecture.md   ← Components by layer (Mobile/Backend/Integration), API contracts
├── 03-data-model.md     ← Entities, relations, constraints (DBML preferred)
├── 04-flows.md          ← User flows + system flows (per-layer addressable) + per-flow Definition of Done
├── 05-decisions.md      ← ADR-style: context → decision → consequences
└── 06-constraints.md    ← Technical, business, non-functional
```

> Vault structure is the same regardless of `IMPLEMENTATION_MODE`. The mode flag drives content of `00-index.md` "Implementation Notes for AI Consumers" section, not the file count.

Use templates in `references/templates/` as scaffolds. **Resolve the path relative to the SKILL.md location**:

- Claude Code personal: `~/.claude/skills/grand-design-spec/references/templates/<name>.md`
- Claude Code project: `<project-root>/.claude/skills/grand-design-spec/references/templates/<name>.md`
- Claude.ai upload: relative to where the skill is mounted in the sandbox (typically `/mnt/skills/user/grand-design-spec/references/templates/`)

Read the relevant template via `view` or platform read tool, **then** fill it in based on extracted facts.

### Step 4: Self-check before delivery

Verify every doc has:

**Grounding & anti-halu:**
- [ ] No invented entities, fields, endpoints, decisions, or behaviors. Setiap claim bisa di-cite ke PRD/Figma/uploaded docs.
- [ ] **Sources** section filled (cite PRD section, Figma frame, atau other input).
- [ ] **Out of Scope** section filled (write `TBD - confirm with PO` kalau genuinely unknown — never leave empty).
- [ ] **Open Questions** section filled. Tagged `OQ-{DOC_CODE}-{N}` + prioritized P1/P2/P3.

**Readability (architect/PM/QA review-ready):**
- [ ] **TL;DR header** ada di tiap doc 01–06 (3-baris format).
- [ ] EN/ID convention konsisten — code term EN, prose ID, gak campur dalam 1 kalimat.
- [ ] Read-aloud test: paragraf pertama tiap doc gak sounds like AI translation.
- [ ] First-use acronym/jargon di-define inline; istilah lintas-doc ada di Glossary `00-index.md`.
- [ ] Cross-ref ≤ 2 per section.
- [ ] `00-index.md` punya: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.

**Simplicity:**
- [ ] Doc 01, 02, 03, 05, 06: as simple as possible. Cut filler.
- [ ] Doc 04 (flows): boleh lengkap-wajar tapi gak padding.
- [ ] Bisa dibaca dalam <10 menit per doc oleh architect.

**Output integrity:**
- [ ] All files written to `<OUTPUT_DIR>` (not the default sandbox path).
- [ ] Folder structure matches the 7-file spec.
- [ ] Language matches source (PRD ID → docs ID; PRD EN → docs EN).

### Step 5: Present

Use `present_files` to deliver the folder. In the chat message:

1. Summary: total docs, total Open Questions count.
2. **List of Open Questions (top blockers)** — these are what the user must resolve before dev starts.
3. Brief note on which sections are most likely to need stakeholder review.

Do NOT pad with "I have created..." preamble. Just deliver and surface blockers.

---

## File-by-file content guide

### Length & simplicity policy

- **Default: as simple as possible**, since audience includes IT Architect review, PM, Business Owner, UI/UX, QA — not just engineers.
- **Exception**: `04-flows.md` boleh lengkap wajar (flow detail, branching, error paths, DoD).
- Cut filler. If a sentence doesn't earn its place, delete it.
- No padding to look thorough. No amputation to look minimal. Length follows content needed, not a target.

### Readability standards (mandatory for all 7 files)

These rules ensure docs are reviewable by humans across roles, not just AI dev agents.

**EN/ID convention** (PRD bahasa Indonesia → docs bahasa Indonesia):
- Code-level terms tetap EN: entity names (`mega_rencana_account`), field names (`source_account_id`), types (`bigint`, `varchar`), enum values (`active | dormant`), HTTP methods, protocol names, framework names.
- Prose narrative tetap ID. Jangan campur EN/ID dalam satu kalimat prose kecuali untuk reference ke code term.
- Hindari hybrid awkward: ❌ "Status MUST be active" → ✅ "Status harus `active`".
- Hindari direct-translate dari AC: ❌ "Sistem dapat melakukan pembayaran full akumulasi autodebet dan rekening tidak ditutup" → ✅ "Sistem bayar full akumulasi → rekening tetap aktif."

**Anti-AI-tone**:
- Baca paragraf out-loud secara mental. Kalau sounds like AI translation atau robotic, rewrite jadi natural conversational ID.
- Hindari hedging berlebihan ("dapat", "mungkin", "kemungkinan") kecuali memang ambiguous (lalu masuk Open Questions).
- Pakai kalimat aktif, pendek, direct.

**Glossary policy**:
- First-use acronym/jargon di setiap doc → define inline pertama kali muncul (e.g. "DBML (Database Markup Language)").
- `00-index.md` wajib punya section **Glossary** untuk istilah lintas-doc: DBML, ADR, FK, NFR, RTO, RPO, MPIN, CIF, OTP, SLO, parameterized, dan istilah produk-spesifik dari PRD.

**Cross-reference budget**:
- Max 2 cross-ref ke section/doc lain per section.
- Kalau lebih dari 2 dibutuhkan, inline informasi penting-nya, atau buat appendix di akhir doc.
- Cross-ref harus self-contained: pembaca tidak perlu open file lain untuk paham konteks dasar.

**Date format convention**:
- `Last updated:` → `YYYY-MM-DD` (precision matters; reviewer needs to know if doc is 1 day vs 30 days old).
- Decision dates, PRD versions, sprint/milestone refs → `YYYY-MM` (sprint/version-level granularity, per project convention).

**Per-doc TL;DR (mandatory header for docs 01–06)**:
Tiap doc 01–06 mulai dengan blok 3 baris:
```markdown
> **TL;DR**: <1 kalimat: doc ini berisi apa>.
> **Untuk siapa**: <role pembaca utama, e.g. Architect / Dev / QA / PM>.
> **Baca kalau**: <kondisi kapan dokumen ini relevan, e.g. "lo lagi review struktur sistem">.
```

### 00-index.md

Required sections, **dalam urutan ini**:

1. **Project header** — nama project + 1 kalimat product description.
2. **Executive Summary** — 3–4 kalimat: what + why + current state of project.
3. **Project Readiness Status** — quick checklist:
   - PRD: complete / draft / pending
   - Figma: complete / pending review / not consumed
   - Tech stack: defined / TBD
   - Sign-off: X/Y stakeholders
   - Open Questions count: P1 / P2 / P3
4. **Reading paths by role** — guide untuk pembaca per peran:
   - Architect: 02 → 03 → 05 → 06
   - Dev (FE/BE): 02 → 03 → 04
   - QA: 04 (focus DoD)
   - PM / Business Owner: 00 → 01 → 05
5. **Reading order** (full sequence dengan 1-line purpose per doc).
6. **Anti-hallucination rules** untuk dev/dev-AI.
7. **Glossary** — istilah & singkatan lintas-doc.
8. **Open Questions roll-up** — categorized, sorted P1→P2→P3 within each (lihat "Mandatory section template").
9. **Source documents** — files konsumsi.
10. **Last updated** — YYYY-MM-DD.

### 01-overview.md

- **TL;DR header** (3 baris)
- **Product**: 2–3 kalimat max
- **Target users / personas**: hanya yang PRD sebut
- **Problem & motivation**: business problem
- **Success criteria**: KPI/metrics — hanya kalau PRD specify, else → Open Questions

### 02-architecture.md

- **TL;DR header**
- **System overview**: 1-paragraph high-level + diagram (text/ASCII), all layers in one view.
- **By component layer** — sub-sections **derived from `PROJECT_SHAPE`** (Step 2). Use the layers from the Project Shape Registry. Each role can deep-link to its relevant section.
  - Example for `mobile-app`: `### Mobile / Frontend`, `### Backend`, `### Integrations`
  - Example for `api-only`: `### Backend`, `### Integrations`
  - Example for `multi-platform`: `### Web Frontend`, `### Mobile`, `### Backend`, `### Integrations`
  - Example for `data-pipeline`: `### Source connectors`, `### Processors`, `### Sinks`, `### Integrations`
  - For `custom`: use layers from user's description.
- **API contracts** (only if applicable to shape; e.g. `library/sdk` may have public API contracts but no HTTP endpoints): endpoint, method, req/res shape, error code — hanya yang explicit di PRD atau directly derivable. Else → Open Questions. Group endpoints under their consuming layer.
- **Tech stack**: hanya yang stated/constrained. Group per layer.

> **Why per-layer**: vault dipakai oleh multiple consumers. Per-layer sub-sections bikin mereka bisa langsung scroll/anchor ke section relevan tanpa baca semua. Reading paths di `00-index.md` bisa pointer ke `02-architecture.md#<layer-anchor>` directly.

### 03-data-model.md

- **TL;DR header**
- Format default: **DBML**. Fall back to entity tables kalau DBML tidak fit.
- Per entity: name, purpose, key fields + types, mandatory/optional
- Relations: 1-1, 1-N, M-N, dengan FK direction
- Constraints: uniqueness, indexes, soft-delete, audit fields — hanya yang specified

### 04-flows.md

> **Exception to simplicity policy**: doc ini boleh lengkap-wajar.

- **TL;DR header**
- **By flow type** — sub-sections **derived from `PROJECT_SHAPE`** (Step 2). Use flow types from the Project Shape Registry.
  - Example for `mobile-app`: `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`
  - Example for `api-only`: `### Backend / system flows`, `### Consumer-facing flows` (when external clients hit the API)
  - Example for `multi-platform`: `### User flows (web)`, `### User flows (mobile)`, `### Backend / system flows`, `### Cross-cutting flows`
  - Example for `data-pipeline`: `### Pipeline flows`, `### Error/recovery flows`, `### Operational flows`
  - For `custom`: use flow categories from user's description.
- For each flow:
  - Numbered steps. Reference Figma frame kalau ada.
  - **Per-flow Definition of Done**: observable behavior. Bullet list per flow.
- For cross-cutting flows (or any flow that involves multiple layers), explicit handoff points: e.g. "Mobile sends to BE → BE responds → Mobile renders".

> **Why per-type**: same rationale as `02-architecture.md`. Multiple consumers, deep-link navigation. QA pakai DoD per flow, layer-specific dev focus on their flow type.

### 05-decisions.md

- **TL;DR header**
- ADR-lite format:

```markdown
### D-001: <short decision title>
**Context**: <kenapa decision ini perlu>
**Decision**: <apa yang diputuskan>
**Consequences**: <implications, trade-offs>
**Source**: <PRD §X / explicit user instruction / meeting note>
```

Hanya decision dengan source eksplisit. PRD silent → bukan ADR, jadi Open Question.

### 06-constraints.md

- **TL;DR header**
- **Technical constraints**: stack lock-ins, infra limits, integration boundaries
- **Business constraints**: timeline, budget, regulatory, compliance, contractual
- **NFR**: performance, scalability, security, availability, observability — hanya yang PRD/stakeholder sebut

---

## Mandatory section template (every doc 01–06)

Append at the bottom of every numbered doc:

```markdown
---

## Sources
- PRD §X.Y (page Z)
- Figma: <frame-name or URL fragment>
- <other inputs>

## Out of Scope
- <explicit non-goals>
- <if unknown: "TBD - confirm with PO">

## Open Questions
- [ ] **OQ-{DOC_CODE}-{N}** [P{1|2|3}]: <ambiguity, with what's needed to resolve it>
- [ ] **OQ-{DOC_CODE}-{N+1}** [P{1|2|3}]: <next ambiguity>
```

### Open Question tagging convention

Every Open Question MUST have a unique tag and priority marker.

**Tag format**: `OQ-{DOC_CODE}-{N}` where:

| Doc | Code |
|-----|------|
| `01-overview.md` | `OV` |
| `02-architecture.md` | `AR` |
| `03-data-model.md` | `DM` |
| `04-flows.md` | `FL` |
| `05-decisions.md` | `DC` |
| `06-constraints.md` | `CN` |

`N` is sequential within each doc (1, 2, 3 …). Tags are stable identifiers — once assigned, do not renumber when adding new questions.

**Priority levels**:

- **P1 — Sprint-0 blocker**: Must be answered before any coding starts. Examples: tech stack, API contracts, source-data inconsistencies, missing sign-off, regulatory/compliance scope.
- **P2 — Feature blocker**: Blocks a specific feature/flow but not the whole project. Examples: edge-case behavior, channel mapping for notifications, max value limits.
- **P3 — Refinement**: Useful to clarify but project can move without it. Examples: future-proofing, optimization details, optional analytics.

### 00-index.md Open Questions roll-up structure

The roll-up in `00-index.md` aggregates all OQs from docs 01–06. Structure:

```markdown
## Open Questions roll-up

> Total: **{N} Open Questions** dari 6 doc. Diurutkan per kategori, sorted by priority within each.

### {Category 1 — e.g. Inkonsistensi PRD} (PRIORITY-1)
- [ ] **OQ-DM-1** [P1]: <text> `[03-data-model.md]`
- [ ] **OQ-FL-1** [P1]: <text> `[04-flows.md]`

### {Category 2 — e.g. Tech stack & arsitektur} (PRIORITY-1)
- [ ] **OQ-AR-1** [P1]: <text> `[02-architecture.md]`
...
```

Categorize by topic (not by doc), with overall priority of the category as the section header. Within each category, list questions sorted P1 → P2 → P3.

---

## Quality bar

- **Grounded**: setiap claim non-trivial cite source (PRD/Figma/uploaded). Berlandaskan dokumen, bukan prior knowledge.
- **Honest about gaps**: prefer Open Questions over guesses. Lebih baik 50 OQ jujur daripada 5 jawaban karangan.
- **Simple**: as simple as possible (kecuali flows). Cut adverbs, hedges, filler.
- **Human-readable**: docs harus reviewable oleh architect, PM, business owner, QA — bukan cuma AI dev.
- **Predictable structure**: consistent headings sehingga reviewer bisa skim cepat.
- **Language match**: output language follows input language. EN/ID convention strict (code EN, prose ID).

## When to push back on the user

- Inputs missing critical sections (e.g. no flows in PRD) → ask before generating
- Figma URL given but no MCP and no screenshots → ask
- PRD is contradictory → surface contradictions, ask which is canonical
- User says "just guess the rest" → refuse politely, explain that the whole point of this skill is to NOT guess. Offer to mark unknowns as Open Questions instead.

---

## References

- `references/templates/` — scaffolds for each of the 7 files. Read these before drafting.

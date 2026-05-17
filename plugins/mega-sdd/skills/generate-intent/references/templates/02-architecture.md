---
type: prose
doc_id: 02-architecture
vault_version: "{{VAULT_VERSION}}"
aliases: [Architecture, Arch, System Architecture]
tags: ["vault/{{PROJECT_SLUG}}", "doc/architecture"]
---

# 02 — Architecture

> **TL;DR**: System components, how they connect, and the API surface they expose. Organized **per layer** according to PROJECT_SHAPE (mobile-app / web-app / api-only / multi-platform / data-pipeline / custom) so each role can deep-link to their relevant section.
> **Audience**: IT Architect, Tech Lead, and per-layer dev roles (Mobile, FE, BE, Data, etc.).
> **Read when**: you're reviewing system structure, or about to implement a specific part of the system.

> **Note**: TL;DR placeholders shown in English. At runtime, render them in the PRD's language.

## System overview

<1-paragraph high-level: this product consists of [layer A], [layer B], [layer C] connected via [protocol]. The diagram below shows the high-level flow.>

```
[ASCII / text diagram showing all layers and their connections, adjusted to PROJECT_SHAPE]

Example for mobile-app:
  Mobile (FE)                      Backend                    External
  ───────────                      ────────                   ────────
  Mobile App   ──── HTTPS ────►  API Service  ────────►  External System / Host
                                       │                       
                                       └────────────►  3rd-party SDKs (analytics, etc.)

Example for api-only:
  External clients ──── HTTPS ────► API Service ──────► Database
                                          │
                                          └─────────► Message Queue

Example for data-pipeline:
  Source(s) ──extract──► Processor ──transform──► Sink(s)
                              │
                              └──► Error/DLQ
```

---

## By component layer

> Sub-sections derived from `PROJECT_SHAPE` (see [[00-index]] Vault Lock Status).
> Replace section headers below with the layers relevant to this project's shape.
>
> Common layer sets:
> - mobile-app: Mobile / Frontend, Backend, Integrations
> - web-app: Web Frontend, Backend, Integrations
> - api-only: Backend, Integrations
> - multi-platform: Web Frontend, Mobile, Backend, Integrations
> - data-pipeline: Source connectors, Processors, Sinks, Integrations
> - custom: layers per user description

### {Layer 1, e.g. "Backend"}

| Component | Purpose | Source |
|-----------|---------|--------|
| <component name> | <1-line> | <PRD §X> |

**Tech stack ({this layer})**: <only if stated>
**Patterns / conventions**: <e.g. business logic engines, scheduler/cron jobs — only if applicable>

### {Layer 2, e.g. "Mobile / Frontend" — only if applicable}

| Component | Purpose | Source |
|-----------|---------|--------|
| <component name> | <1-line> | <PRD §X> |

**State management & navigation**: <only if PRD specifies, else → Open Questions>
**Client-side validation rules**: <list explicit ones from AC>
**Tech stack ({this layer})**: <only if stated>

#### UI components & patterns

> **Conditional**: appears only if `HAS_UI_COMPONENTS=true` from Step 2 (an explicit source named the components). Does not appear from shape inference or prior knowledge. For `multi-platform`, this sub-section appears independently per layer (Web / Mobile) based on per-layer source coverage.

| Component | Purpose | Variants | Source |
|-----------|---------|----------|--------|
| `<ComponentName>` | <1-line purpose> | `<variant1 | variant2>` | Figma `<frame-name>` / tokens.json `<key-path>` / PRD §<X.Y> |

**Patterns** (when-to-use rules — guide voice. Only state rules with explicit source):

- **<Pattern title>**: <when-to-use, sourced from PRD / Figma annotation / user instruction>.
- **<Next pattern>**: <text>.

> Cross-ref: tokens used here → [[06-constraints#Design System]]. Flow steps that show this component → cross-ref to the flow ID in [[04-flows]].

**Source**: <list all Figma frames, tokens files, PRD sections used for this sub-section>

### {Layer 3, e.g. "Integrations"}

| External system | Direction | Protocol | Purpose | Source |
|-----------------|-----------|----------|---------|--------|
| <system> | sync \| async | <REST/SOAP/MQ/SDK> | <what for> | <PRD §X> |

**Auth & integration patterns**: <e.g. OAuth, JWT, API key — only if stated, else → Open Questions>

### {Add more layers as needed for the PROJECT_SHAPE}

---

## API contracts

> Group endpoints under their consuming layer. Only include contracts explicitly stated or directly derivable from AC. Anything else → Open Questions.
> If `PROJECT_SHAPE=library/sdk` or `PROJECT_SHAPE=cli-tool`, replace this section with "Public API surface" or "CLI commands" as appropriate.

### {Group 1, e.g. "Mobile-facing endpoints" / "Public API" / "CLI commands"}

#### `<METHOD> /path/to/endpoint` (or `function(args)` for library, `command --flag` for CLI)

**Purpose**: <1 line>
**Auth**: <required / public / role-based — if applicable>

<!-- full-only -->
**Request / Input**:
```json
{
  "field": "type — note"
}
```

**Response / Output (success)**:
```json
{
  "field": "type — note"
}
```
<!-- /full-only -->

**Errors / Failure modes**:
- `400` / `<error type>` — <when>
- `404` / `<error type>` — <when>

**Source**: PRD §<X.Y>

---

### {Group 2, only if applicable, e.g. "Backend-internal / system endpoints", "Webhook inbound"}

<repeat structure>

<!-- compact-mode rendering: replace JSON request/response blocks with a table row in a per-group endpoints table:
| Endpoint | Method | Purpose | Auth | Errors | Source |
|----------|--------|---------|------|--------|--------|
-->

---

## Sources

- PRD §<X.Y>
- Figma: <frame-name>

## Out of Scope

- <e.g. "Real-time sync via WebSocket — not in v1">
- <if unknown: "TBD - confirm with PO">

## Open Questions

- [ ] **OQ-AR-1** [P{1|2|3}]: <e.g. "BE tech stack — language and framework not stated in PRD">
- [ ] **OQ-AR-2** [P{1|2|3}]: <e.g. "Auth method for endpoint X not specified">

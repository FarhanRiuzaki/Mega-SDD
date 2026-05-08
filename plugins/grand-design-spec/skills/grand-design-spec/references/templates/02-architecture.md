# 02 — Architecture

> **TL;DR**: Komponen sistem, bagaimana mereka saling terhubung, dan operasi API yang dibutuhkan. Disusun **per layer** sesuai PROJECT_SHAPE (mobile-app / web-app / api-only / multi-platform / data-pipeline / custom) supaya tiap role bisa langsung jump ke section relevan.
> **Untuk siapa**: IT Architect, Tech Lead, dan dev role per layer (Mobile, FE, BE, Data, dst).
> **Baca kalau**: lo lagi review struktur sistem, atau mau implement bagian sistem tertentu.

## System overview

<1 paragraf high-level: produk ini terdiri dari [layer A], [layer B], [layer C] yang saling terhubung via [protocol]. Diagram below show high-level flow.>

```
[ASCII / text diagram showing all layers and their connections, sesuaikan dengan PROJECT_SHAPE]

Example for mobile-app:
  Mobile (FE)                      Backend                    External
  ───────────                      ────────                   ────────
  Mobile App   ──── HTTPS ────►  API Service  ────────►  External System / Host
                                       │                       
                                       └────────────►  3rd-party SDKs (analytics, dst)

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

> Sub-sections derived from `PROJECT_SHAPE` (lihat 00-index.md Vault Lock Status).
> Replace section headers below with layers yang relevan untuk shape project ini.
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

> **Conditional**: muncul hanya kalau `HAS_UI_COMPONENTS=true` di Step 2 (ada source eksplisit yang nyebut component). Tidak muncul karena shape inference atau prior knowledge. Untuk `multi-platform`, sub-section ini muncul independently per layer (Web / Mobile) berdasarkan per-layer source coverage.

| Component | Purpose | Variants | Source |
|-----------|---------|----------|--------|
| `<ComponentName>` | <1-line purpose> | `<variant1 | variant2>` | Figma `<frame-name>` / tokens.json `<key-path>` / PRD §<X.Y> |

**Patterns** (when-to-use rules — guide voice. Only state rules with explicit source):

- **<Pattern title>**: <when-to-use, sourced from PRD / Figma annotation / user instruction>.
- **<Next pattern>**: <text>.

> Cross-ref: tokens used here → `06-constraints.md#design-system`. Flow steps that show this component → cross-ref ke flow ID di `04-flows.md`.

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

**Errors / Failure modes**:
- `400` / `<error type>` — <when>
- `404` / `<error type>` — <when>

**Source**: PRD §<X.Y>

---

### {Group 2, only if applicable, e.g. "Backend-internal / system endpoints", "Webhook inbound"}

<repeat structure>

---

## Sources

- PRD §<X.Y>
- Figma: <frame-name>

## Out of Scope

- <e.g. "Real-time sync via WebSocket — not in v1">
- <if unknown: "TBD - confirm with PO">

## Open Questions

- [ ] **OQ-AR-1** [P{1|2|3}]: <e.g. "Tech stack BE — bahasa & framework belum disebut PRD">
- [ ] **OQ-AR-2** [P{1|2|3}]: <e.g. "Auth method for endpoint X not specified">

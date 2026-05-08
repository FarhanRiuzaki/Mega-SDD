# grand-design-spec (plugin)

A Claude Code plugin that bundles the **`grand-design-spec`** skill — converts a PRD/BRD + Figma into a 7-file dev handoff folder with anti-hallucination guarantees.

## What this plugin does

When triggered, the skill takes a product/business document (and optionally a Figma URL) and produces 7 markdown files inside a folder you choose:

```
<your-output-folder>/
├── 00-index.md          Navigation + Executive Summary + Project Readiness
├── 01-overview.md       What, who, why, success metrics
├── 02-architecture.md   Components, relations, API contracts
├── 03-data-model.md     Entities (DBML), relations, constraints
├── 04-flows.md          User flows + system flows + Definition of Done
├── 05-decisions.md      ADR-lite: technical decisions with explicit source
└── 06-constraints.md    Technical, business, non-functional requirements
```

Every claim cites its source. Ambiguities become tagged Open Questions (`OQ-{DOC_CODE}-{N}`) with priority P1/P2/P3. Out of Scope is always explicit. No invented entities, fields, endpoints, or behaviors.

## Trigger phrases

The skill activates automatically when you say things like:

- "Help me break down this PRD for the dev team" / "pecah PRD ini buat dev"
- "Spec out this feature" / "buat dev handoff"
- "Prepare context for AI-assisted dev" / "siapkan context buat AI dev"
- "Translate this BRD into architecture docs"
- Any request to convert a product/business document into structured dev specs

Then attach the PRD (PDF preferred) and answer the few clarifying questions the skill asks (output path, project shape, gap-handling preference).

## Project shapes supported

The skill is general-purpose. Pre-templated shapes:

- `mobile-app` — Mobile UI + Backend + Integrations
- `web-app` — Web Frontend + Backend + Integrations
- `api-only` — Backend service with no own UI
- `multi-platform` — Web + Mobile + Backend
- `data-pipeline` — ETL/batch processing, no user UI
- `custom` — Any other shape (CLI, SDK, browser extension, IoT, etc.)

The skill **infers** shape from PRD content during the extract phase, then **confirms** with the user before generating files.

## Install

This plugin ships through the `grand-design-spec` marketplace (this same repository):

```text
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install grand-design-spec@grand-design-spec
```

See the [marketplace README](../../README.md) for version pinning, private repo auth, and Claude.ai / Claude API installation paths.

## License

MIT — see [LICENSE](../../LICENSE).

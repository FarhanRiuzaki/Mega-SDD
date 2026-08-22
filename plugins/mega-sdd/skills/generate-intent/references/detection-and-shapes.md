# generate-intent — Detection edge cases + Project Shape Registry

## Contents
- Mode A/B detection edge cases
- Inputs (what the user provides)
- Project Shape Registry
- Inference rules (Step 2)

## Mode A/B detection edge cases

The deterministic detection table lives in the SKILL body (Mode A / B detection rules). These are the boundary cases it resolves:

- **Quoted single word** (`"buildTodoCLI"`) — Rule 4 matches (wrapped in quotes) → Mode B. The user explicitly quoted the input; treat it as a brief.
- **Looks-like-path but doesn't exist** (`./missing.md`) — Rule 2 fails (file doesn't resolve) but Rule 3 catches the `.md` extension → Mode A. Warn: `"File ./missing.md not found. Treating as Mode A path. To use free-text, wrap in quotes or use --from-prompt."` and offer to abort.
- **Bare single word** (`prd`) — Rule 5 matches (no path separator, no extension) → Mode B. If the user actually meant a path, ask them to provide an extension (`prd.md`) or relative path (`./prd`).
- **Flag + positional conflict** (`--from-prompt "build X" ./prd.md`) — Rule 1 wins → Mode B. The trailing `./prd.md` is ignored. Warn: `"--from-prompt set; ignoring positional ./prd.md. Provide just the brief or just a path, not both."`

When detection is ambiguous (Rule 3 with a missing file, Rule 6 with multiple candidates), the skill always confirms with the user before proceeding. Detect silently only when high-confidence.

## Inputs (what the user provides)

The user typically provides one or more of:

- **PRD/BRD file:** PDF (priority), DOCX, MD, or TXT. Location auto-detected per environment (sandbox: `/mnt/user-data/uploads/`; local Claude Code: ask the user or use CWD). See Step 1.
- **Figma URL:** use Figma MCP if connected. To check whether Figma MCP tools are loaded — Claude Code: `ToolSearch` with `query: "figma"`; Claude.ai sandbox: `tool_search(query="figma")`. If no Figma MCP and no screenshots, ASK the user before proceeding — do not guess UI structure.
- **Output folder path:** the user MUST specify (Step 0). The skill never assumes a path silently.
- **Optional context:** existing system docs, tech stack constraints, prior architecture decisions.

If critical inputs are missing or unclear, **ask before generating**. Better 5 upfront questions than 7 docs of guesses.

## Project Shape Registry

This skill is **general-purpose** — it works for any kind of project, not just mobile banking. Project shape determines the sub-sections inside `vault.md ## Architecture` and `flows.md`. The skill **infers** the shape from PRD content during Step 2 (extract), then **confirms** it with the user before generating files.

### Pre-templated shapes (most common)

| Shape | When to use | Layers (for `vault.md ## Architecture`) | Flow types (for `flows.md`) | Roles (deep-link anchors) |
|-------|-------------|-----------------------------------|--------------------------------|----------------------------------------|
| `mobile-app` | Mobile-first product with backend (e.g. M-Smile, e-wallet) | Mobile / Frontend, Backend, Integrations | User flows (mobile), Backend / system flows, Cross-cutting | Architect, Mobile Dev, BE Dev, QA, PM, UI/UX |
| `web-app` | Web-based product (SaaS, dashboard) with backend | Web Frontend, Backend, Integrations | User flows (web), Backend / system flows, Cross-cutting | Architect, FE Dev, BE Dev, QA, PM, UI/UX |
| `api-only` | Backend service with no own UI (microservice, internal API, webhook handler) | Backend, Integrations | Backend / system flows, Consumer-facing flows (when external clients hit the API) | Architect, BE Dev, QA, PM, External integrator |
| `multi-platform` | Has web + mobile + backend (e.g. Arygas-style) | Web Frontend, Mobile, Backend, Integrations | User flows (web), User flows (mobile), Backend / system flows, Cross-cutting | Architect, FE Dev, Mobile Dev, BE Dev, QA, PM, UI/UX |
| `data-pipeline` | ETL, batch processing, no user-facing UI (e.g. reconciliation engine, reporting job) | Source connectors, Processors, Sinks, Integrations | Pipeline flows, Error/recovery flows, Operational flows | Architect, Data Engineer, QA, PM, Data analyst |

### Custom fallback

If the project doesn't fit any of the 5 pre-templated shapes:

- Use shape `custom`.
- The skill MUST ask the user to describe layers/components and roles in their own words.
- Generated sub-sections must derive from the user's description, not be invented.

> Examples of custom shapes: CLI tool, library/SDK, browser extension, embedded system, hybrid mobile-cli, IoT device firmware.

## Inference rules (Step 2)

When extracting from the PRD, infer shape using these heuristics:

- PRD mentions "mobile app", "M-Smile", "iOS", "Android", "push notification" → likely `mobile-app` or `multi-platform`.
- PRD mentions "web", "browser", "dashboard", "SaaS" + backend → likely `web-app`.
- PRD describes API endpoints/integrations only, no UI → likely `api-only`.
- PRD covers both web and mobile UIs explicitly → `multi-platform`.
- PRD describes batch jobs, scheduled processors, no user-facing UI flows → `data-pipeline`.
- None of the above → `custom`, ask the user.

If inference confidence is low (e.g. PRD ambiguous, mentions both mobile and web casually), the skill MUST present its inference with reasoning and ask the user to confirm or override.

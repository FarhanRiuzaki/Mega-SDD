# Artifact publisher → AI-gateway (brainstorm-approved design)

**Status:** DRAFT — design approved in chat 2026-08-17; implementation gated on user review of this spec.
**Decisions locked in brainstorm:** (1) topology = office AI gateway, MCP lives there, flow developer → Claude Code (mega-sdd) → gateway; (2) **PUSH model** — mega-sdd is the active side, auto-updates, gateway passively receives; (3) cadence = **Stop-hook debounced** (telemetry pattern: async, fail-open, no-change → no push); (4) payload = **ALL artifacts** (graph, vault, binding, units, KB, codebase-map, symbol index) — internal network + authorized MCP assumed (user to confirm with infra); (5) transport = **plain HTTPS POST, NOT MCP** (publisher is Stop-hook script-plane: deterministic, zero-token, headless-safe; MCP lives on the READ side); (6) **no auto-registration in the plugin's `.mcp.json`** — the gateway URL is office-specific; teams get the same auto-UX by committing a project-scope `.mcp.json` in each office repo.

## What we build (plugin side only)

1. **`scripts/publish-artifacts.sh`** — deterministic publisher:
   - Collects: `.mega-sdd/graph.json`, `vaults/*/` (7 docs, binding.md, `bound/`, `units/`, `bolts/_summary.md`), knowledge-base, `codebase/codebase-map.md`, symbol index.
   - Emits `manifest.json`: `project_id` (normalized git remote), `vault`, `git_head`, `generated_at`, sha256 per file, `graph_meta` (the graph's `_meta.source_hashes` — staleness honesty).
   - Sends ONLY files whose sha changed since the last push (local stamp `.mega-sdd/.publish-state.json`) as tar.gz + the FULL manifest (gateway self-heals from the manifest).
   - Exit 0 ALWAYS on network failure (fail-open): queue in `.publish-state.json`, retry next trigger, one log line.
2. **Stop-hook leg** — reuses the existing artifact-change detection + debounce; async; inert unless `publish.gateway_url` is configured.
3. **Credentials — mega-code first (office reality: devs log in via the `mega-code` CLI with their NIP; it owns token provisioning).** Publisher probe ladder, first hit wins: (1) env `MEGA_SDD_PUBLISH_URL`/`MEGA_SDD_PUBLISH_TOKEN` (mega-code-as-launcher sets them when starting `claude`); (2) credential file `~/.mega-code/megasdd-publish.json` (`{"gateway_url":…, "token":…}` — mega-code-as-login-utility writes it); (3) generic fallback `.mega-sdd/config.yaml` `publish.*` / plugin `userConfig` (non-office users). No hit → publisher inert. Token never logged; 401 → fail-open + queue + one log line "re-run mega-code login" (rotation/expiry is mega-code's job). **No PII in artifacts:** the manifest carries no NIP — the gateway attributes the push from the token it minted per NIP at login.
4. **Ingest contract + team guide** — `docs/mega-sdd/gateway-mcp-guide.md` (shipped with this spec) is the contract the office team builds the gateway + MCP against.

## Contracts

- **Idempotent ingest**: same sha set → no-op. Storage keyed `project_id`/`vault` @ `git_head`, latest-wins.
- **Read-only + honesty**: external consumers read verdicts as INFORMATION — the moat's gates live only inside mega-sdd; staleness metadata always shipped; the gateway MCP must never mutate.
- **Rejected on record**: MCP-client push (dependency + model-plane for a machine-to-machine job); git-pull transport (user wants active push, near-realtime); bundling the gateway MCP in plugin `.mcp.json` (office-specific URL in a public plugin; env-expansion contractually undocumented — the context7 keyless precedent).

## Tests (when implementation starts)
Manifest determinism · delta-by-sha · fail-open (dead endpoint → rc 0 + queue) · inert-without-config · token-never-logged · debounce (no change → no push) · tar contents match manifest.

## Non-goals
The gateway ingest service and the MCP server itself (the office team's build, per the guide). Cross-project reuse queries from mega-sdd sessions (future, once the office registers the read-side MCP in project repos).

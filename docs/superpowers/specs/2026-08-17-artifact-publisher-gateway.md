# Artifact publisher → AI-gateway (brainstorm-approved design)

**Status:** DRAFT — design approved in chat 2026-08-17; implementation gated on user review of this spec.
**Decisions locked in brainstorm:** (1) topology = office AI gateway, MCP lives there, flow developer → Claude Code (mega-sdd) → gateway; (2) **PUSH model** — mega-sdd is the active side, auto-updates, gateway passively receives; (3) cadence = **Stop-hook debounced** (telemetry pattern: async, fail-open, no-change → no push); (4) payload = **ALL artifacts** (graph, vault, binding, units, KB, codebase-map, symbol index) — internal network + authorized MCP assumed (user to confirm with infra); (5) transport = **plain HTTPS POST, NOT MCP** (publisher is Stop-hook script-plane: deterministic, zero-token, headless-safe; MCP lives on the READ side); (6) **no auto-registration in the plugin's `.mcp.json`** — the gateway URL is office-specific; teams get the same auto-UX by committing a project-scope `.mcp.json` in each office repo.

## What we build (plugin side only)

1. **`scripts/publish-artifacts.sh`** — deterministic publisher:
   - Collects: `.mega-sdd/graph.json`, `vaults/*/` (7 docs, binding.md, `bound/`, `units/`, `bolts/_summary.md`), knowledge-base, `codebase/codebase-map.md`, symbol index.
   - Emits `manifest.json`: `project_id` (normalized git remote), `vault`, `git_head`, `generated_at`, sha256 per file, `graph_meta` (the graph's `_meta.source_hashes` — staleness honesty), and OPTIONAL `work_dir` (BASENAME of the working folder only, never a full path — approved 2026-08-20 on the gateway team's request as a telemetry JOIN-HINT for the :8002 human reader; NEVER an identity key, `project_id` stays canonical).
   - Sends ONLY files whose sha changed since the last push (local stamp `.mega-sdd/.publish-state.json`). **Wire format (pinned 2026-08-20 with the gateway team, their option (b)):** one raw `Content-Type: application/gzip` body — a tar.gz whose FIRST entry at the tar root is the FULL `manifest.json`, followed by the changed files at their manifest paths. No multipart, zero new deps both sides (`curl --data-binary` on ours, streaming raw + shell `tar` on theirs).
   - Exit 0 ALWAYS on network failure (fail-open): queue in `.publish-state.json`, retry next trigger, one log line.
2. **Stop-hook leg** — reuses the existing artifact-change detection + debounce; async; inert unless `publish.gateway_url` is configured.
3. **Credentials — read what mega-code already provisions (source-verified against `mega-code@0.5.0` on npm, 2026-08-20).** mega-code is an EXTERNAL npm CLI: `login` (LDAP, NIP+password) stores/refreshes tokens; `install` writes `~/.claude/settings.json` with `env.ANTHROPIC_BASE_URL=<gateway>` + `apiKeyHelper: "mega-code get-token"`. The publisher therefore needs ZERO new provisioning: **URL** = `$ANTHROPIC_BASE_URL` (settings env is injected into the Claude Code process; the Stop-hook inherits it) with the ingest at `$ANTHROPIC_BASE_URL/mega-sdd/ingest`; **token** = `mega-code get-token` (bounded subprocess, same accessor apiKeyHelper uses; refresh/expiry is mega-code's internal job). Probe ladder: (1) `ANTHROPIC_BASE_URL` set AND `mega-code` on PATH AND `get-token` exit 0 → office path; (2) generic override env `MEGA_SDD_PUBLISH_URL`/`MEGA_SDD_PUBLISH_TOKEN` (CI/testing); (3) `.mega-sdd/config.yaml` `publish.*` (non-office). No hit / `get-token` non-zero → publisher inert or queue with one log line "run mega-code login". Attribution per NIP happens at the gateway (token is minted per NIP); no PII in artifacts. Superseded on the record: the earlier `~/.mega-code/megasdd-publish.json` credential-file design (invented before reading the source — unnecessary).
4. **Ingest contract + team guide** — `docs/mega-sdd/gateway-mcp-guide.md` (shipped with this spec) is the contract the office team builds the gateway + MCP against.

## Contracts

- **Idempotent ingest**: same sha set → no-op. Storage keyed `project_id`/`vault` @ `git_head`, latest-wins.
- **Read-only + honesty**: external consumers read verdicts as INFORMATION — the moat's gates live only inside mega-sdd; staleness metadata always shipped; the gateway MCP must never mutate.
- **Rejected on record**: MCP-client push (dependency + model-plane for a machine-to-machine job); git-pull transport (user wants active push, near-realtime); bundling the gateway MCP in plugin `.mcp.json` (office-specific URL in a public plugin; env-expansion contractually undocumented — the context7 keyless precedent).

## Tests (when implementation starts)
Manifest determinism · delta-by-sha · fail-open (dead endpoint → rc 0 + queue) · inert-without-config · token-never-logged · debounce (no change → no push) · tar contents match manifest.

## Non-goals
The gateway ingest service and the MCP server itself (the office team's build, per the guide). Cross-project reuse queries from mega-sdd sessions (future, once the office registers the read-side MCP in project repos).

## Architect decisions on the gateway team's consolidation (2026-08-20)

Their architecture doc (ingest + indexer + file-store-as-truth + SQLite derived index + MCP + :8002 human reader, Fastify middleware placement) is APPROVED. Decisions on their 4 blockers: (1) `work_dir` manifest field = optional, basename-only, join-hint never identity; (2) :8002 approved as read-only human consumer under the IDENTICAL honesty contract as MCP; (3) `/data` layout approved, retention = current + 5 snapshots per project/vault + daily prune, push cap 413 = 50 MB compressed (a bundle near that cap is a publisher bug, not a cap problem); (4) v1 access boundary = internal-confidential mirroring scm (all authenticated employee tokens read all projects, everything audit-logged per token; per-repo ACL deliberately deferred — the index's `project_id` key makes it retrofittable). Plus one added rule: **indexer failure must never fail ingest** — the file-store write completes the contract (200); the index is derived and rebuilds in the background.

# Graph code layer — scan output as queryable knowledge (design)

**Status:** DESIGN APPROVED by the user 2026-08-21 ("gas semua", phase 1 + phase 2 in one release). Target: **v6.20.0**. Pairs with the publisher spec `2026-08-17-artifact-publisher-gateway.md`.

**User mandate (verbatim intent):** *"data scan codebase juga harus masuk ke graph sebagai fungsi mapping — di dalam codebase itu apa saja fungsinya dan untuk apa"*, and the purpose behind it: *"data graph project itu bisa sebagai source knowledge untuk gue tanya-tanya sebagai knowledge AI."* The graph is not a picture — it is the **answer substrate** for questions asked through the gateway MCP.

## 0. Field-test finding that triggered this (2026-08-20, `laravel-recon-gsd`)

The first publisher field test produced nothing at the gateway. Root cause, proven by timestamps: the session's Stop hooks fired `16:42:02Z` / `16:44:40Z`; the `6.19.2` plugin cache landed `16:55:49Z`. The newest cached version at test time was `6.18.0`, which contains **no publisher script and no Stop leg** (publisher shipped in 6.19.0). The test ran 13 minutes before the code existed.

Three real blockers sat behind it, and the second is what this spec fixes:

1. Session not mega-code-managed (`~/.claude/settings.json` carries no `apiKeyHelper`/`ANTHROPIC_BASE_URL`, `~/.mega-code/` absent) → office rung correctly inert per v6.19.1.
2. **The project had no vault** → `build-graph.sh` emitted a 0-node shell and the publisher exited on `if not vaults: sys.exit(0)`. A scan-stage project produced no knowledge at all, even though `reuse-index.yaml` already held 145 mapped symbols with purposes.
3. Local `mega-code` is **0.2.0**, which has no `install` subcommand (`login`/`logout`/`get-token` only). The v6.19.1 condition (a) — `apiKeyHelper` basename = mega-code — can never be satisfied by that version. **Open question for the mega-code team: what version do office laptops carry?** If 0.2.0, the office rung never arms in the field.

### 0b. Evidence from a real office `settings.json` (supplied 2026-08-21)

A live office laptop's file confirms the office rung's inputs and exposed one Windows defect:

```jsonc
"apiKeyHelper": "\"C:\\Users\\<nip>\\AppData\\Roaming\\npm\\mega-code.cmd\" get-token",
"env": { "ANTHROPIC_BASE_URL": "http://10.202.171.20:8001", "NO_PROXY": "10.202.171.20,…" }
```

- Condition (a) holds — the quoted-absolute-path form with a `.cmd` basename is exactly the case dispositioned as latent at v6.19.1 (round MINOR-5/6); the same string mints the token, so signature and mint cannot name different binaries.
- Condition (b) holds — `http://` is accepted (scheme required, TLS not; this is an internal IP).
- **Defect found and fixed (v6.20.0):** the rung's cheap precondition was `command -v mega-code`. On Windows the installed artifact is `mega-code.cmd`; if no extensionless wrapper is on PATH, the probe fails and the office rung stays disarmed on a laptop whose settings are perfect. Now probes `mega-code` / `mega-code.cmd` / `mega-code.exe` (shell builtins, no fork). Pinned by test arms w1–w3 built from this exact shape.
- Corp proxy is set for everything else but `NO_PROXY` lists the gateway IP, so the ingest POST bypasses it. A laptop missing that `NO_PROXY` entry would route the push through `corpproxy` — fail-open means it queues rather than breaking anything, but it is the first thing to check if a specific laptop never lands a push.
- Ingest URL for the field test: `http://10.202.171.20:8001/mega-sdd/ingest`.

## 1. The two layers

| Layer | Answers | Sources |
|---|---|---|
| **Vault** (existing) | *what was INTENDED* — claims, units, flows, OQ, modules | `vaults/*/vault.json`, `binding.json`, `units/*.md`, `_meta/modules.yaml`, `knowledge-base/**` |
| **Code** (this spec) | *what ACTUALLY exists and what it is for* — functions, their purpose, where they live | `codebase/reuse-index.yaml` |

The layers join on a node type that already exists: **`code_anchor`** (id = repo-relative file path), which `binding.json` claims already point at via `implements`. Symbols attach to the same node, so no new file-node type is introduced (reuse over new surface).

## 2. Phase 1 — code layer

**Source: `codebase/reuse-index.yaml` only.** Its entries carry `signature`, `purpose`, `purpose_confidence`, `_source: path:line` (+ `class` for methods) grouped by category (`helpers`, `model_api`, `services`, `commands`).

**Two shapes exist in the wild and BOTH must parse** (found while implementing; a parser that reads one silently yields an empty code layer on the other):

| | `references/reuse-index-schema.md` (documented) | what deep-scan actually emits |
|---|---|---|
| root | categories at top level | nested under `reuse_index:` |
| entry | block mapping (`- name:` / `path:` / …) | inline flow mapping `{ signature: …, _source: … }` |
| anchor | `path:` + optional `line:` | `_source: "path:line"` |
| `truncated` | top level, inline `{helpers: false, …}` | inside `reuse_index:`, may be a nested block |

The builder uses a dedicated line parser (not `load_yaml`): the hand-rolled fallback flattens the category mapping, losing which category an entry belongs to. Only the four known category names are accepted as categories, so a stray nested list elsewhere in the file cannot leak in as symbols. Truthiness for `truncated` treats `false`/`0`/`no` as not-truncated — a scan that capped nothing writes `false`, not absence. **Open for a later round (not this release):** the schema doc and the emitter disagree; one of them should move.

**Node `symbol`**
- **id:** `sym:<relpath>#<name>` — `name` = the signature up to `(`, `static ` stripped. Line-independent by design: a line-keyed id would churn on every edit above the symbol and defeat delta-by-sha. On collision (overload), append `~<line>`.
- **attrs:** `signature`, `purpose`, `purpose_confidence`, `category`, `class` (when present), `line`.
- **source:** `{artifact: .mega-sdd/codebase/reuse-index.yaml, field: reuse_index.<category>[]}`.

**Edge `symbol --defined_in--> code_anchor`** (confidence = the symbol's `purpose_confidence`, uppercased to the graph's convention: `stated` → `VERIFIED`, `inferred` → `INFERRED`). The `code_anchor` node is created if binding did not already create it.

**Rejected on record — `codebase/symbol-index.json` as a node source.** It is the structural ast-grep tier: `{name, kind, file, line, signature, lang}` with **no purpose**. Emitting thousands of purposeless nodes inflates the graph without adding answerable knowledge (no-gimmick rule). It stays a published artifact for the gateway's own `reuse_candidates` tool; it is not graph input.

### Honesty rules (each is a defect if omitted)

1. **`purpose_confidence` is non-strippable.** Most real entries are `inferred`, not `stated`. A purpose rendered on a bank dashboard without its confidence marker is the same fabrication class as an unmarked KB `[INFERRED]`, and it lands on a surface we do not control. Pinned by test here and added to the gateway guide's marker table so their renderer is contractually obliged to show it.
2. **Truncation must be visible.** `reuse_index.truncated` is a dict that is truthy when the scan capped a category. `_meta.code_layer.truncated` carries it (same rule already used by `build-dispatch-prompt.sh:2247` — `any(bool(v) for v in trunc.values())`), so `:8002` cannot present a partial map as complete.
3. **`reuse-index.yaml` is NOT added to the publish set.** `graph.json` carries its derived nodes; shipping both gives the gateway indexer two sources of truth for one fact.

## 3. Phase 2 — cross-layer edges (what makes it answerable)

- **`unit --touches--> code_anchor`** from unit frontmatter `target_files[].path`. Confidence `VERIFIED` (the unit declares it); `operation` (`create`/`modify`/`none`) rides as an edge attribute. Entries with `operation: none` are skipped.
- **`claim --implements--> code_anchor`** already exists — no change; it is what makes the join work.

**Parser hazard (must be handled, else the edges are silently empty on half the fleet):** `target_files` is a block list of *inline flow mappings* — `- { path: src/x.ts, operation: modify }`. With PyYAML present these parse to dicts; the hand-rolled fallback parser (`load_yaml`, used whenever PyYAML is absent — the common case on system python3) yields the raw **string** `"{ path: src/x.ts, operation: modify }"`. The builder must accept both shapes. Tested on both paths via the existing `MEGA_SDD_FORCE_YAML_FALLBACK=1` lever.

With phase 2 in place the graph answers cross-layer questions in one hop: *"which unit touches the function that does matching?"* → `symbol` → `code_anchor` ← `unit`; *"is the claim behind this file CONFIRMED?"* → `code_anchor` ← `claim.verdict`.

## 4. Publisher — scan-only projects publish

- **Stop leg gate:** `[ -d .mega-sdd/vaults ]` → `[ -d .mega-sdd/vaults ] || [ -f .mega-sdd/graph.json ]`.
- **Script:** `if not vaults: sys.exit(0)` → when no vault exists, perform **one** push under the reserved sentinel vault **`_codebase`** carrying only the `SHARED` set (`graph.json`, `knowledge-base/**`, `codebase/codebase-map.md`, `codebase/symbol-index.json`). The multi-vault path is untouched; `SHARED` already rides inside every vault push, so no new collection logic.
- Delta-by-sha, manifest completeness, fail-open, size cap: unchanged. State keys on the vault name, so `_codebase` gets its own delta bucket.

**Cross-team contract item (must be confirmed by the gateway team, not assumed):** runbook §2 makes `vault` a required field, and their store is keyed `project_id`/`vault` with retention `current` + 5 **per project/vault**. `_codebase` is a sibling vault carrying no design docs. They must confirm (a) retention tolerates it, (b) `:8002/project/<work_dir>` renders a vault with a graph but no vault docs as the code-map layer rather than a broken design vault.

## 5. Migration — old graphs must not go stale-blind

`query-graph.sh` derives its freshness check from `_meta.source_glob` **inside the graph file**, so a graph built before this release carries the old glob list and would never notice `reuse-index.yaml`. Therefore: bump `generated_by` to `build-graph@1.1.0` and make the query-side freshness check **also rebuild when `_meta.generated_by` differs from the current builder version**. Without this, existing projects silently keep a code-layer-less graph forever.

## 6. Two interop mismatches with the runbook (report to the gateway team; no code change here)

1. **Symbol index path.** We write `codebase/symbol-index.json`; runbook §7 names `symbols/index.json`. Manifest paths are stored verbatim, so it 200s either way — but if their indexer keys on path, `reuse_candidates` finds nothing.
2. **`project_id` shape.** Runbook §2's example keeps the host (`scm.bankmegadev.com/grup/repo`); their §8 sed keeps the host for ssh form and **strips** it for https form — internally inconsistent. Ours keeps the host in both (matching their own §2 example). Since `project_id` is the store key, one rule must be agreed or a repo's artifacts split across two keys.

## 7. Tests

`tests/graph-impact/test-code-layer.sh` — **23 arms, mutation-proved ×4** (stripped `purpose_confidence` / line-keyed anchor / no `operation:none` skip / no builder-version rebuild each turned ≥1 arm red): symbols emitted per category · quoted commas survive the inline-mapping split · `purpose_confidence` on every node, `defined_in` confidence mirrors it · name rule for callables vs console signatures · id stable under a line shift while `line` still tracks · **the join** (`symbol` → `code_anchor` ← `claim` ∧ ← `unit`, one id) · `touches` with `operation` carried and `operation: none` skipped · identical output under `MEGA_SDD_FORCE_YAML_FALLBACK=1` · truncation visible / `false` not read as truncated · id-only `flows` degrades instead of aborting · stale-builder graph rebuilt on query · **both reuse-index shapes** (documented schema form + emitted form).

`tests/publisher/test-publish-artifacts.sh` — 33 → **41 arms**, mutation-proved ×2 (restored vault-less bail-out / shipped `reuse-index.yaml` each turned arms red): `_codebase` sentinel push (c1–c4: pushes once, manifest `vault == "_codebase"` with files ⊆ SHARED and no `reuse-index.yaml`, nothing-publishable → zero POST, vault-bearing path unchanged) and the real-office-settings arms (w1–w3, §0b).

## 8. Non-goals

Server-side rendering/query of the new node types (gateway team). Making `symbol-index.json` a node source (rejected §2). Re-scanning code inside the builder — the graph stays **derived, never authored**: if the scan did not record it, the graph does not invent it.

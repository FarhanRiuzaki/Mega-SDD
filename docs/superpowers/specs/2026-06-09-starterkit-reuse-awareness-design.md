# Starterkit Reuse-Awareness — function/method/service/command reuse for bolts

**Status:** Design approved 2026-06-09
**Plugin target:** v4.3.0 → v4.4.0
**Type:** Feature (producer + consumer in-iter — no producer-only ship)
**Predecessor context:** Starterkit-Aware Deep Scan (`docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md`) — this design extends that feature's deep-scan stage with a fifth slice.

---

## Background and motivation

The Starterkit-Aware Deep Scan feature (`scan-codebase` deep-scan stage → `.mega-sdd/codebase/starterkit-context.yaml`) successfully captures **which** libraries a starterkit uses (auth / rbac / ui / libs), **where** its conventions live (directory layout, naming, code exemplars), and ships those to `generate-units` (Anchors + Hard Rules) and `execute-bolts` (T2 context slice).

It does **not** capture the starterkit's own callable API surface: the helper functions, model methods / scopes / traits, service / action classes, and artisan commands that already exist in the project. The deep-scan `libs:[]` slice lists package names + versions + `usage_hint` file paths, but never enumerates the specific functions exported from those files or from the starterkit's first-party code.

Consequence: the `bolt-implementer` agent is told *which library to use* and *which pattern to follow*, but is never told *which existing functions it can call*. It receives anchored file paths, not a function inventory. So when a unit needs (say) a permission check, the implementer writes a fresh implementation instead of calling the existing `User::hasRole()`; when it needs currency formatting it re-derives logic instead of calling the existing `format_currency()` helper. This is not an agent-intelligence failure — it is a data-flow gap. The implementer can only reuse what it has been told exists.

User goal: when mega-sdd encounters a project with an existing starterkit, executed bolts should **reuse the starterkit's existing functions, model methods, services, and commands** instead of reinventing them — across all four asset types, framework-agnostically (Laravel is the reference example).

This design closes the gap with a **hybrid** mechanism (chosen over a pure static catalog or pure JIT discovery): scan builds a compact **reuse index** as the grounding artifact; `generate-units` attaches per-unit reuse *candidates*; `execute-bolts` injects the relevant slice and enforces a **reuse-first lookup** (read the real function before reimplementing); a post-flight **advisory** check flags probable duplication. The index keeps lookups cheap and targeted; the mandatory JIT read keeps reuse accurate and fresh; the gate + justification trail keeps reinvention honest.

---

## §1 Architecture overview

`scan-codebase` deep-scan stage gains a **fifth parallel subagent** (`reuse-extractor`) alongside the existing four (auth / rbac / ui-ux / libs). It reads the starterkit's first-party code via pack-driven globs and AST/grep queries, and returns a structured slice that the consolidator writes to a new sibling artifact `.mega-sdd/codebase/reuse-index.yaml` (separate concern from `starterkit-context.yaml`, separately cacheable, can grow large independently).

The handoff carries a `reuse_index:` pointer block forward. `generate-units` reads `reuse-index.yaml`, matches index entries to each unit by domain / keyword / `target_files` overlap, and attaches a capped `reuse_candidates:` list to the unit (plus a Hard Rule when a high-confidence candidate exists). `execute-bolts` carries `unit.reuse_candidates` in T1 (small + critical) and injects the relevant `reuse-index` slice in T2 (budget-tracked). The `bolt-implementer` agent runs a **reuse-first protocol** before writing each capability, and records a `reuse_decisions:` block in its self-assessment. A post-flight advisory duplication check compares newly-written symbols against the index and surfaces warnings (non-blocking) in execute-bolts output and `/mega-sdd:analyze`.

### Skill / file version bumps

- `scan-codebase` — minor bump (new reuse-extractor subagent + reuse-index emission)
- `generate-units` — minor bump (new Step 7.7.e + `reuse_candidates` derivation)
- `execute-bolts` — minor bump (reuse slice injection + post-flight advisory check)
- `bolt-implementer.md` agent — reuse-first protocol added to system prompt
- Plugin — v4.3.0 → v4.4.0 (`plugin.json` + `marketplace.json` in sync)

### New plugin files

1. `plugins/mega-sdd/references/reuse-index-schema.md` — canonical `reuse-index.yaml` schema + anti-halu rails
2. `plugins/mega-sdd/skills/scan-codebase/references/reuse-extractor.md` — the fifth subagent's dispatch prompt + per-asset extraction rules + pack-driven discovery + caching
3. Reuse-pattern entries added to the Laravel framework convention pack (globs/queries for helpers, model API, services/actions, commands) + generic fallback

---

## §2 Components

### 2.1 The reuse-extractor subagent

Dispatched in the same parallel batch as the existing four deep-scan subagents (so total wall-clock is unchanged when slices run concurrently). It reads first-party code only (not vendor/node_modules) using the tool-preference ladder already established: tree-sitter → ast-grep → ripgrep/regex fallback. Discovery locations and query shapes are **pack-driven**:

| Asset type | Laravel-pack discovery (reference) | Generic fallback |
|---|---|---|
| Helpers / utils | `app/Helpers/**`, `app/Support/**`, composer `autoload.files` | top-level functions + static util methods in `src/`/`lib/` utility dirs |
| Model API | `app/Models/**` → public methods, `scope*` methods, `use` traits | classes under `models/`/`entities/` → public methods |
| Services / actions | `app/Services/**`, `app/Actions/**`, `app/Domain/**` → public entrypoints | classes under `services/`/`actions/`/`usecases/` → public methods |
| Artisan / CLI commands | `app/Console/Commands/**` → `$signature` property | declared CLI command registrations |

Each entry captures **signature + one-line purpose + `_source` file:line only — never a function body**. Purpose is derived from the symbol's docblock/first comment when present, else inferred conservatively from name + signature (and marked as inferred). Per-category cap (default 300) with an explicit overflow note when exceeded.

### 2.2 reuse-index.yaml canonical schema

```yaml
schema_version: "1.0"
generated_from: "<git sha or content signature used for caching>"
generated_at: "<from handoff timestamp, never fabricated>"
truncated: { helpers: false, model_api: false, services: false, commands: false }

helpers:
  - name: format_currency
    kind: global_helper            # global_helper | util_method
    path: app/Helpers/money.php
    signature: "format_currency(int $amount, string $currency = 'IDR'): string"
    purpose: "Format integer minor-units into a localized currency string"
    purpose_confidence: stated     # stated | inferred
    _source: "app/Helpers/money.php:42-58"

model_api:
  - model: "App\\Models\\User"
    path: app/Models/User.php
    methods:
      - "hasRole(string|Role $role): bool   @88"
    scopes:
      - "scopeActive(Builder $q): Builder    @120"
    traits: ["HasRoles", "HasAuditLog"]
    _source: "app/Models/User.php"

services:
  - class: "App\\Services\\CreateOrderService"
    path: app/Services/CreateOrderService.php
    entrypoints:
      - "handle(OrderData $d): Order   @30"
    purpose: "Create an order with stock reservation + invoice"
    purpose_confidence: inferred
    _source: "app/Services/CreateOrderService.php:30-95"

commands:
  - signature: "sync:catalog {--force}"
    class: "App\\Console\\Commands\\SyncCatalog"
    path: app/Console/Commands/SyncCatalog.php
    purpose: "Re-sync product catalog from upstream"
    purpose_confidence: stated
    _source: "app/Console/Commands/SyncCatalog.php"
```

**Anti-halu rails:** every entry MUST carry `_source` file:line; an entry with no verifiable source is dropped, not emitted. `purpose_confidence: inferred` marks purposes not backed by a docblock. No bodies are stored (signatures only) — this bounds size and avoids stale-copy drift.

### 2.3 Pack reuse-pattern entries

The Laravel convention pack gains a `reuse_discovery:` block (globs + query hints per asset type). Unknown frameworks fall back to the generic table in §2.1. This keeps the feature framework-agnostic and lets the index improve per-pack over time without touching the skill.

---

## §3 Data flow + caching

```
scan-codebase (deep-scan stage)
  ├─ auth / rbac / ui-ux / libs  → starterkit-context.yaml   (unchanged)
  └─ reuse-extractor             → reuse-index.yaml          (NEW)
        helpers[] · model_api[] · services[] · commands[]
            │  handoff: reuse_index: { path, counts, truncated }
            ▼
generate-units  (Step 7.7.e)
  read reuse-index.yaml → match to unit (domain/keyword/target_files)
  → unit.reuse_candidates: [ {name, path, signature, purpose} ]   (capped ~10-15)
  → high-confidence candidate ⇒ Hard Rule: "MUST evaluate reuse of <X> before implementing <Y>"
            │
            ▼
execute-bolts  (context-enrichment)
  T1: unit.reuse_candidates (fast-path hint) + reuse-index.yaml PATH (always)
  T2: relevant reuse-index slice (budget-tracked ≤10KB)
            │
            ▼
bolt-implementer  (reuse-first protocol — runs isolated; only the prompt + Read/Grep)
  per capability:  (1) check reuse_candidates hint
                   (2) SCAN the full reuse-index.yaml for the capability about to be written
                   (3) grep/READ the real function at its _source
                   (4) reuse it  OR  record reimplemented+reason in self-assessment
  → self-assessment.reuse_decisions: [ {candidate, decision, reason?} ]
            │
            ▼
post-flight (advisory)
  heuristic: new symbol ≈ index entry (name + signature shape) → WARN (non-blocking)
  surfaced in execute-bolts output + /mega-sdd:analyze
```

### 3.1 Caching

`reuse-index.yaml` is cached by the same lock/content-signature mechanism the other deep-scan slices use. Lock files + first-party source signature unchanged → reuse cached index (0s). Changed → reuse-extractor re-runs. The index is independent of `starterkit-context.yaml` so a change in one does not force re-extraction of the other.

### 3.2 generate-units candidate matching (fast-path hint, not the primary surface)

Matching is heuristic and conservative: an index entry becomes a candidate for a unit when its name/purpose keywords overlap the unit's title/description/domain, or its `path` overlaps the unit's `target_files` prefix. Candidates are ranked by overlap strength and capped (~10-15) to protect the T1 budget. No match ⇒ no `reuse_candidates` block (absence is valid, never fabricated).

**Critical framing:** these pre-matched candidates are a *fast-path hint*, **not** the bolt's primary reuse surface. What a bolt actually needs to reuse is only known at code-writing time, not at unit-generation time — a unit titled "Create leave request" will not keyword-match a `format_currency()` helper even when its implementation needs one. So per-unit matching deliberately optimizes precision (a few obviously-relevant hits surfaced cheaply in T1), and the **full `reuse-index.yaml` is the bolt's primary lookup surface at write time** (see §4.1–§4.2). This is the design's answer to low cross-cutting recall: never bound reuse to keyword matching done before the need exists.

### 3.3 unit-schema.md change

New optional frontmatter field `reuse_candidates` (list of `{name, path, signature, purpose}`). Absent when no candidates matched. Documented in `generate-units/references/unit-schema.md`.

---

## §4 execute-bolts integration

### 4.1 Context enrichment

`context-enrichment.md` adds three things to the bolt-dispatch prompt:

1. `unit.reuse_candidates` to T1 — the fast-path hint (part of the unit, small + decision-critical).
2. The **`reuse-index.yaml` path** to T1 — always present (even when no candidates matched). The `bolt-implementer` runs isolated with no session history, so it only has what is in the prompt; it does have Read/Grep, so the path lets it scan the *full* index for whatever it is about to write. This is what makes the full index the primary lookup surface rather than the pre-matched candidate subset.
3. The matched `reuse-index` slice to T2 — filtered by the unit's candidates + `target_files`, budget-tracked under the existing ≤10KB T2 ceiling. When the slice would exceed budget it is truncated with an explicit "+N more in reuse-index.yaml — read it directly" note (no silent drop); the index path from (2) is the escape hatch for the long tail.

### 4.2 bolt-implementer reuse-first protocol (GATE, prose)

Added to `agents/bolt-implementer.md`. Before implementing any capability the agent MUST:

1. Check the `reuse_candidates` hint, **and scan the full `reuse-index.yaml`** (at the path handed in T1) for an existing function/method/service/command that covers the capability about to be written. The pre-matched candidates are a hint, not the boundary — cross-cutting helpers will frequently be absent from the per-unit candidate list and present only in the full index.
2. If a plausible match exists, **read the actual function** (grep/Read at the cited `_source`) before writing anything — signatures alone are not enough to commit to reuse.
3. **Reuse it** if it fits — OR, if writing fresh, **record the reason** in `reuse_decisions` (what was considered, why not reused).

This is a self-checked gate (per the plugin's *gates > rules > hooks* doctrine), not a hook: whether the agent *considered* reuse cannot be proven deterministically, but the decision trail makes unjustified reinvention visible.

### 4.3 Self-assessment addition

The bolt self-assessment template gains `reuse_decisions: [ {candidate, decision: reused|not_applicable|reimplemented, reason?} ]`. `reimplemented` without a `reason` is itself a finding the post-flight check flags.

### 4.4 Post-flight advisory duplication check

A non-blocking validator runs after the bolt writes code: for each newly-introduced symbol it compares name similarity + signature shape against `reuse-index` entries; a probable match emits a WARNING (with both `_source` locations) in the execute-bolts output and contributes a finding to `/mega-sdd:analyze`'s `CONSISTENCY-REPORT.md`. It never HALTs the bolt and is never wired to a PreToolUse hook (heuristic → false-positive risk → must not block legitimate work, and must not grow the hot-path gate surface).

---

## §5 Halt protocol + error handling

This feature adds **no new blocking halts.** Error/empty conditions are handled gracefully:

| Condition | Behavior |
|---|---|
| No framework detected / deep-scan skipped | reuse-extractor does not run; `reuse-index.yaml` absent; downstream treats absence as "no candidates" (valid) |
| reuse-extractor finds nothing reusable | emits empty sections; downstream proceeds without candidates |
| Per-category cap exceeded | `truncated.<cat>: true` + overflow note; bolt told to read `reuse-index.yaml` directly for the long tail |
| `reuse-index.yaml` missing at generate-units/execute-bolts | log_and_continue; no candidates attached (no fabrication) |
| Candidate path no longer exists at bolt time | bolt skips that candidate, notes it in `reuse_decisions` |

### Anti-halu rails (new)

1. No index entry without a verifiable `_source` file:line.
2. No function bodies stored — signatures only (prevents stale-copy drift).
3. Inferred purposes marked `purpose_confidence: inferred`.
4. Absence of candidates is represented by omission, never by an invented entry.
5. Post-flight duplication findings cite both `_source` locations so the user can verify.

---

## §6 Testing

### 6.1 Trigger tests
- `scan-codebase.test.md`: reuse-extractor dispatched when framework ≥ MEDIUM; not dispatched when no framework.
- `generate-units.test.md`: `reuse_candidates` attached when index entries match a unit; omitted when none match.
- `execute-bolts.test.md`: reuse slice present in dispatch when `unit.reuse_candidates` exists.

### 6.2 Scenario test (one full-pipeline integration)
A fixture starterkit containing: one global helper, one model with a method + scope + trait, one service class, one artisan command. Assert: each appears in `reuse-index.yaml` with `_source`; a unit whose domain matches the helper gets it in `reuse_candidates`; the dispatched bolt prompt contains the helper slice.

### 6.3 Extraction fixtures
Per-asset-type Laravel fixtures (helper file, model, service, command) asserting correct signature + `_source` capture and correct `purpose_confidence` (stated vs inferred).

### 6.4 Anti-halu fixtures
- Entry with no resolvable source → dropped, not emitted.
- Function with a body change but same signature → index unchanged (signatures only).

### 6.5 Field test
The user's actual starterkit: run scan → confirm helpers/model API/services/commands are catalogued; run a unit known to need an existing helper → confirm the bolt reuses it (or records a justified `reuse_decisions` entry).

---

## Acceptance criteria

1. `reuse-index.yaml` is produced (when a framework is detected) with all four asset-type sections, every entry carrying `_source`.
2. The reuse-extractor adds **no new serialized stage** — it runs inside the existing parallel deep-scan batch and is 0s on cache hit. (It may extend the batch's max-duration, since it scans the widest surface of any slice and can become the batch's slowest agent — acceptable; wall-clock is bounded by the slowest agent, not the sum.)
3. `generate-units` attaches `reuse_candidates` to units whose domain matches index entries, capped, never fabricated.
4. The dispatched bolt prompt carries the unit's `reuse_candidates` (T1) + relevant index slice (T2 within budget).
5. `bolt-implementer` performs a reuse-first read and emits `reuse_decisions`; reimplementation despite a fitting candidate carries a recorded reason.
6. Post-flight duplication check surfaces probable reinvention as a **warning** (never a block) with both `_source` locations.
7. Feature is framework-agnostic: Laravel pack drives reference discovery; generic fallback works for an unknown framework.
8. No new blocking hook; hot-path PreToolUse surface unchanged.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Large starterkit → huge index → token blowup | signatures-only + per-category cap + per-unit candidate cap + budget-tracked T2 slice with truncation note |
| Heuristic candidate matching misses a relevant function | bolt still has the reuse-first instruction + can read `reuse-index.yaml` directly; index path is always handed off |
| Inferred purposes mislead the implementer | `purpose_confidence: inferred` flag; the implementer reads the real function before reuse |
| Post-flight false positives annoy users | advisory-only, never blocking; cites both sources so the user dismisses quickly |
| Reuse-first gate ignored by the agent (prose ≠ enforcement) | `reuse_decisions` audit trail makes unjustified reinvention visible in the bolt artifact + `/mega-sdd:analyze` |

---

## Out of scope (deferred)

- Call-graph / cross-reference analysis ("function X is used in 17 places").
- Auto-refactoring of pre-existing duplication in the starterkit.
- Deep per-pack reuse discovery for non-Laravel frameworks (generic fallback only this iter).
- A blocking duplication gate (explicitly chosen against — advisory only).
- Reuse of vendor/third-party-package internal functions (first-party starterkit code only).

---

## Spec self-review checklist

- [x] No placeholders / TBDs remain.
- [x] Schema in §2.2 matches the data-flow references in §3–§4.
- [x] Enforcement level (gate + advisory, no new hook) is consistent across §1, §4, §5, acceptance.
- [x] Scope is one implementation plan (producer slice + 3 consumer touchpoints + advisory check).
- [x] Anti-halu rails enumerated and consistent with the plugin's 5 invariants.
- [x] Full `reuse-index.yaml` is the bolt's primary lookup surface; per-unit candidates are a fast-path hint only (§3.2, §4.1, §4.2).

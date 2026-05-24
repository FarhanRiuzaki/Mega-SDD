# Iter 35 — Reading Map + Phase Discoverability (with audit closure)

**Status:** Design approved 2026-05-24 (autonomous-execute mode)
**Plugin target:** v3.25.0 → v3.26.0
**Iter type:** Feature iter — ~5-7hr
**Predecessor:** Iter 34 v3.25.0 dynamic model selection
**User directive:** "semua harus di dasrkan simplipikasi dan flawless" (simplification + flawless)

---

## Background

User field-tested the legacy-rebuild pipeline (extract-intelligence → execute-bolts) and surfaced two UX gaps:

1. **Phase discoverability**: vault only contains Phase 1; user confused about how to access Phase 2 plan. The plan exists at `<KB>/99-rebuild-architecture/suggested-phasing.md` but the vault never tells the user this.

2. **Foldering map**: user wants a clear "at pipeline stage X, read file Y at location Z" guide. Current `paths.md` is implementer-facing (where each skill writes); needs an inverse user-facing reader-guide.

Plus deep audit found: 1 stale prose line in `scan-codebase/SKILL.md` line 37 documenting an obsolete default path.

Per simplification + flawless directive: this iter ships all 3 fixes in one pass. No deferrals. Atomic commits where surfaces must sync.

---

## §1 Architecture (minimal additions)

**New files: 1** (per simplification — `paths.md` is implementer-facing; `reading-map.md` is the user-facing inverse).

| Path | Responsibility |
|---|---|
| `plugins/mega-sdd/references/reading-map.md` | NEW — user-facing pipeline-stage-to-location guide. One file. Indexed by phase. Cross-references paths.md (implementer view). |

**Modified files (concentrated; no sprawl):**

| Path | Change |
|---|---|
| `plugins/mega-sdd/skills/scan-codebase/SKILL.md` | Fix line 37 stale prose (`repo root` → `.mega-sdd/codebase/codebase-map.md`) |
| `plugins/mega-sdd/skills/generate-intent/SKILL.md` | + `--phase=N` flag (Step 0.X) + write `phase` + `phase_total` to vault.json + write §Phase context to 00-index.md header |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | + `phase: int` + `phase_total: int` fields in vault.json schema |
| `plugins/mega-sdd/skills/execute-bolts/SKILL.md` | end-of-chain `next_action.hint` mentions Phase N+1 when vault.phase < vault.phase_total |
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | end-of-chain summary: surface phase context if vault has phase field |
| `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` | + "Reading guide" cross-ref to reading-map.md |
| `plugins/mega-sdd/README.md` | "What's new in v3.26.0" subsection |
| `README.md` (repo root) | version 3.25.0 → 3.26.0 (3 spots) |
| `CHANGELOG.md` | + [3.26.0] entry |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | 3.25.0 → 3.26.0 |
| `tests/skill-triggering/generate-intent.test.md` | + 2 cases (GI-PH1 phase=1 default + GI-PH2 phase=2 explicit) |

**Skill version bumps:**
- `scan-codebase` 2.6.1 → 2.6.2 (doc fix only; patch)
- `generate-intent` 1.13.0 → 1.14.0 (new flag + vault.json schema extension)
- `execute-bolts` 2.7.0 → 2.7.1 (end-of-chain hint mentions phase)
- `orchestrate-flow` 3.1.0 → 3.1.1 (chain summary surfaces phase)
- `using-mega-sdd` 1.3.2 → 1.3.3 (reading-map cross-ref)

**Plugin:** v3.25.0 → v3.26.0

---

## §2 The reading-map.md (one file; user-facing)

Single-file structure to keep simplicity:

```markdown
# Reading Map — Where to Look at Each Pipeline Stage

> **Companion to `paths.md`**: paths.md tells skills WHERE to write; this doc tells users WHERE to read.
>
> **Convention**: ⭐ marks the primary entry-point per stage. Read that first.

## Pre-pipeline (your inputs)

| What | Where | Read when |
|---|---|---|
| Project requirements | `<project>/prd.md` (your file) | Before any mega-sdd run |
| Legacy codebase | `<project>/legacy-code/` OR `old-reference/_source/` | Before extract-intelligence |

## Stage 1 — After extract-intelligence (legacy-rebuild only)

Path root: `<project>/.mega-sdd/knowledge-base/`

| What | Where | Read when |
|---|---|---|
| ⭐ Roll-up + critical findings | `README.md` | Start here |
| Per-domain extraction (11-section template) | `10-domains/<domain>.md` | Understanding what legacy did |
| Cross-domain flows | `20-workflows/<workflow>.md` | Tracing user journeys |
| Legacy data model | `30-data-model/conceptual-erd.md` | As-is data shape |
| Business rules | `40-business-rules/<rule>.md` | Per-rule detail |
| Integrations | `50-integrations/<integration>.md` | External system contracts |
| ⭐ **Phased rebuild plan (Phase 1/2/3+)** | `99-rebuild-architecture/suggested-phasing.md` | Planning Phase 2+ work |
| Proposed new ERD | `99-rebuild-architecture/suggested-erd.md` | Target data shape |
| What's locked vs free to redesign | `99-rebuild-architecture/data-mutation-policy.md` | ERD freedom decisions |
| Module dependency graph | `99-rebuild-architecture/module-dependency-graph.md` | Build ordering |

## Stage 2 — After generate-intent

Path root: `<project>/.mega-sdd/vaults/<slug>/`

| What | Where | Read when |
|---|---|---|
| ⭐ Vault entrypoint + Phase context | `00-index.md` | Start here every session |
| Feature scope (Phase N) | `01-overview.md` | What you're building NOW |
| Components + APIs | `02-architecture.md` | Component contracts |
| Data shape | `03-data-model.md` | Per-entity fields + relations |
| User flows | `04-flows.md` | Happy paths + edge cases |
| Decisions log | `05-decisions.md` | Why decisions were made |
| Constraints | `06-constraints.md` | NFRs + compliance + technical |
| Project rules | `constitution.md` (v1.8+, if present) | Security/compliance/anti-patterns |
| Open questions | `vault.json` `oqs[]` | What needs answering |
| Phase manifest | `vault.json` `phase` + `phase_total` | Which phase this vault covers (v3.26+) |

## Stage 3 — After scan-codebase

Path root: `<project>/.mega-sdd/codebase/`

| What | Where | Read when |
|---|---|---|
| ⭐ Codebase map | `codebase-map.md` | Understanding existing code |
| Starterkit context (v3.23+) | `starterkit-context.yaml` | Your stack's auth/RBAC/UI patterns |

## Stage 4 — After bind-codebase

Path root: `<project>/.mega-sdd/vaults/<slug>/`

| What | Where | Read when |
|---|---|---|
| ⭐ Implementation State Map | `binding.md` §Implementation State Map | What's IMPLEMENTED / NEW / PARTIAL |
| Per-claim binding evidence | `binding.md` body | Why each claim was classified |

## Stage 5 — After generate-units

Path root: `<project>/.mega-sdd/vaults/<slug>/units/`

| What | Where | Read when |
|---|---|---|
| ⭐ Unit roll-up | `_index.md` | All units + their dependencies |
| Atomic work unit | `U-XXX.md` (per unit) | Specific task before bolt execution |
| Squad partition | `_meta/squads.yaml` (multi-squad) | Team coordination |

## Stage 6 — After execute-bolts

Path root: `<project>/.mega-sdd/vaults/<slug>/bolts/`

| What | Where | Read when |
|---|---|---|
| ⭐ Batch roll-up | `_summary.md` | Overall outcome |
| Per-unit outcome | `U-XXX/bolt-report.md` | Specific bolt's tests + commits + drift |
| Dispatch context (debugging) | `U-XXX/dispatch-prompt.md` | What the AI executor saw |
| Pre/post snapshots | `U-XXX/preflight.json` + `postflight.json` | Drift detection input |

## Stage 7 — Cross-cutting + interop

| What | Where | Read when |
|---|---|---|
| ⭐ Tool-agnostic AI context | `<repo-root>/AGENTS.md` | Other AI tools (Continue, Cursor, Aider) consume this |
| Pipeline run history | `.mega-sdd/memory/outcomes.md` | "What did past runs do" |
| Routing learning (v3.24+) | `.mega-sdd/memory/routing-outcomes.md` | What chain works for this project shape |
| Project decisions | `.mega-sdd/memory/decisions.md` | OQ resolutions across runs |
| Project conventions | `.mega-sdd/memory/conventions.md` | Detected naming/structure conventions |
| Drift report (after detect-drift) | `<vault>/DRIFT-REPORT.md` | Code-vs-vault divergence |
| Vault diff (after diff-vault) | `<vault>/VAULT-DIFF.md` | Cross-revision vault changes |

## Phase 2+ workflow (after Phase 1 completes)

When Phase 1 vault's bolts complete:

1. Read `<KB>/99-rebuild-architecture/suggested-phasing.md` §Phase 2
2. Run `/mega-sdd:generate-intent --kb=<KB> --phase=2` to bootstrap Phase 2 vault (v3.26+)
3. Pipeline proceeds: bind-codebase → generate-units → execute-bolts (for Phase 2 scope)
4. Repeat for Phase 3+

`vault.json.phase` tells you which phase the current vault represents. `00-index.md` §Phase context surfaces this at the top of the vault for at-a-glance discovery.

## E2E one-liner

`legacy-code/ → KB (.mega-sdd/knowledge-base/) → vault per phase (.mega-sdd/vaults/<slug-phase-N>/) → bind+units+bolts inside that vault → AGENTS.md (repo root) for interop`

## See also

- `paths.md` — implementer-facing per-skill write paths (this doc's inverse)
- `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` — KB structure spec
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — vault structure spec
```

That's ONE file covering the whole pipeline reading map. ~120 LOC. Reuses existing path conventions; doesn't introduce new structure.

---

## §3 Phase discoverability (atomic — all surfaces in one commit)

### 3.1 vault.json schema extension

Add 2 fields to vault.json (in `vault-contract.md §schema`):

```yaml
phase: <int>          # NEW v1.14.0+ Iter 35 — which phase this vault represents (1, 2, 3...)
phase_total: <int>    # NEW v1.14.0+ Iter 35 — total phases planned per suggested-phasing.md (1 if not legacy-rebuild)
```

Default values when fields absent (back-compat): `phase: 1, phase_total: 1` (treat as single-phase project).

### 3.2 generate-intent `--phase=N` flag

- Default: `--phase=1`
- When `--kb=<path>` AND `--phase=N`: read `<KB>/99-rebuild-architecture/suggested-phasing.md` §Phase N section → scope vault to that phase's deliverables
- When `--phase=1` (default): generate vault from KB's Phase 1 scope (current behavior)
- vault.json gets `phase: N` + `phase_total` (parsed from suggested-phasing.md by counting `## Phase` sections)

### 3.3 00-index.md §Phase context block

generate-intent writes this block at top of `00-index.md` after the existing header:

```markdown
## Phase context (v3.26+)

**Phase:** N of M (e.g., "1 of 3")

**This vault covers:** <1-line summary parsed from suggested-phasing.md §Phase N "scope" or "deliverables">

**Upcoming phases:**
- Phase N+1: <1-line summary parsed from suggested-phasing.md §Phase N+1>
- Phase N+2: <1-line summary parsed from suggested-phasing.md §Phase N+2>
- ...

**To start the next phase** (after this phase's bolts complete):

```bash
/mega-sdd:generate-intent --kb=<KB-path> --phase=N+1
```

**Full phased plan:** `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md`
```

When `phase_total: 1` (greenfield / single-phase project), omit the Upcoming phases + To start the next phase blocks; just show "Phase: 1 of 1".

### 3.4 execute-bolts end-of-chain hint

When chain completes successfully AND vault.phase < vault.phase_total:

```yaml
next_action:
  type: continue_to_next_phase
  hint: "Phase <N> complete. Next: Phase <N+1>. To bootstrap: /mega-sdd:generate-intent --kb=<KB> --phase=<N+1>. Plan: .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase <N+1>"
```

### 3.5 orchestrate-flow chain summary

At end-of-chain (Step 7 emit final summary), if vault has `phase` field, append:

```
Phase <N> of <M> complete. To start Phase <N+1>: see .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md or run /mega-sdd:generate-intent --kb=<KB> --phase=<N+1>.
```

---

## §4 Audit closure (1 stale prose fix)

`plugins/mega-sdd/skills/scan-codebase/SKILL.md` line 37:

```diff
- `codebase-map.md` written to repo root (or CWD if outside repo). Idempotent — overwrites prior map.
+ `codebase-map.md` written to `.mega-sdd/codebase/codebase-map.md` (v3.4+ canonical per `plugins/mega-sdd/references/paths.md`). Override via `--out=<path>` flag. Idempotent — overwrites prior map.
```

Bump scan-codebase 2.6.1 → 2.6.2 (patch).

---

## §5 Halt protocol + testing

### 5.1 No new halts

Iter 35 introduces NO new halt types. `--phase=N` validates against parsed `phase_total`; out-of-range → error message with concrete suggestion (no halt-protocol envelope needed since this is invocation-time validation, not chain-time halt).

### 5.2 Trigger tests (2 new cases)

**`tests/skill-triggering/generate-intent.test.md`** under `## Iter 35 — Phase discoverability (v1.14+, v3.26+)`:

- **GI-PH1**: Legacy-rebuild + `--phase=1` (default). Verify vault.json gets `phase: 1`, `phase_total: <N>` (parsed from suggested-phasing.md). 00-index.md §Phase context shows "Phase 1 of N" + lists upcoming phases.
- **GI-PH2**: Legacy-rebuild + `--phase=2`. Verify vault.json gets `phase: 2`. 00-index.md scope reflects Phase 2 deliverables from suggested-phasing.md. Vault content scoped to Phase 2 only (not all phases mixed).

---

## §6 Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| suggested-phasing.md format varies across KBs (parsing breaks) | Medium | Parse defensively: count `## Phase` headers; if zero found → fallback `phase: 1, phase_total: 1` + log "no phasing detected in KB; treating as single-phase" |
| User runs `--phase=2` without Phase 1 vault existing yet | Low | Generate Phase 2 vault anyway; print warning "Phase 1 vault not detected at `.mega-sdd/vaults/`; Phase 2 may reference unbuilt Phase 1 dependencies" |
| `phase` field absent in old vaults (pre-v3.26.0) | High | Default treatment: missing field = `phase: 1, phase_total: 1`. Back-compat by construction. |
| reading-map.md drifts from actual file locations over time | Medium | Cross-references paths.md (single source of truth for write locations). Iter contributors update reading-map.md when they touch paths.md (codified in adding-new-skills protocol — out of scope for Iter 35 to enforce; trust convention) |

---

## Acceptance criteria

1. Plugin v3.25.0 → v3.26.0
2. `plugins/mega-sdd/references/reading-map.md` created (~120 LOC) covering all 7 pipeline stages + Phase 2+ workflow + E2E one-liner + cross-refs
3. scan-codebase 2.6.1 → 2.6.2 (line 37 prose fixed)
4. generate-intent 1.13.0 → 1.14.0 (`--phase=N` flag + writes phase to vault.json + writes §Phase context to 00-index.md)
5. vault-contract.md schema extends with `phase` + `phase_total` fields
6. execute-bolts 2.7.0 → 2.7.1 (end-of-chain hint references Phase N+1 when applicable)
7. orchestrate-flow 3.1.0 → 3.1.1 (chain summary surfaces phase context)
8. using-mega-sdd 1.3.2 → 1.3.3 (reading-map cross-ref)
9. 2 new trigger tests (GI-PH1 default phase=1, GI-PH2 explicit phase=2)
10. Back-compat preserved: missing `phase` field → default `phase: 1, phase_total: 1`
11. CHANGELOG + READMEs updated

---

## Out of scope (genuinely deferred — kept narrow per simplification)

- AGENTS.md move into `.mega-sdd/` — intentional design exception per tool-interop standard; not changing
- Phased rebuild auto-chaining (Phase 1 → Phase 2 → Phase 3 in one run) — user-driven phase transitions preferred; auto-chain risks user not reviewing intermediate state
- reading-map.md enforcement (e.g., catalog check that every file in paths.md is in reading-map.md) — convention for now; can codify later if drift surfaces

---

## Spec self-review

- [x] No TBD/TODO/vague markers
- [x] 1 new file (reading-map.md) — meets simplification directive
- [x] All 3 deliverables (audit + reading-map + phase discoverability) ship in ONE iter — meets flawless directive (no "Phase 2 later")
- [x] vault.json schema extension + 00-index.md write + handoff hint + chain summary all in one iter (atomic per surface) — meets flawless directive
- [x] Back-compat preserved for old vaults
- [x] 5 skill version bumps (one per modified skill); plugin bumped
- [x] Standing directives applied: simplification (1 new file), flawless (3 problems in 1 iter, atomic commits), reuse-first (reading-map cross-refs paths.md instead of duplicating), propagation-within-iter (schema + writer + consumer all ship together)

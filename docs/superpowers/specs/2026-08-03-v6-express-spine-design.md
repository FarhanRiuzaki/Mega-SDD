# v6 — the Express Spine: speed with hard gates

**Date:** 2026-08-03
**Status:** P1 v5.34.0 · P2 v5.35.0 · P3 v5.36.0 · P4 SHIPPED v6.0.0 (194b1b3, CI green, suite 202) — THE EXPRESS SPINE IS THE DEFAULT AND THE SURFACE IS 3 VERBS + 4 ONE-TIMERS; P5 COMPLETE (2026-08-10) — both arms MEASURED + PUBLISHED (README §"Measured: classic vs express spine"): to first acceptance-backed bolt, express net 1h44m52s vs classic 1h53m17s (−7%) and 18.6M vs 28.2M cost-weighted (−34%); the "<10 min" target FAILED and is published as failed; full-run figures disclosed as not task-class comparable (7 chore vs 10 feature units, 8 in-run fix rounds incl. a panel-caught Critical); runbook `research/2026-08-04-p5-measurement-runbook.md` (conventions amended 2026-08-10, both arms re-extracted identically). THE v6 MANDATE'S PHASES ARE ALL CLOSED.
**Research grounding:** `research/2026-08-03-v6-express-spine-best-practices.md` (2026-08-03, 4 lanes: SDD landscape / Anthropic guidance / context-engineering evidence / verification-speed economics). Every spine element CONFIRMED against the 2025–2026 evidence base; amendments A1–A7 from that document are folded into the rails below.
**Mandate (operator, 2026-08-03, verbatim goals):** "tujuan utamanya skills ini itu standarisasi code, reuse code, percepatan development, dan anti fabricated. yang paling utama itu speed development dengan standar yg udah di set atau hard gate." — a MAJOR update; cut everything that does not serve these four. **Speed is the tie-breaker; the hard gates are non-negotiable.**

**Field evidence driving this:** on `training-nextjs`, scan alone cost ~25 minutes + 3.1M cost-equiv tokens before a single line of code; the full PRD→code path fronts 1–2 hours of ceremony. Plain Claude Code starts delivering in minutes with comparable output for small/mid features. v6's honest answer: *match that start speed, keep the proof.*

## North star

> **PRD in → proven code out, in minutes.** Everything on the default path must serve standarisasi / reuse / speed / anti-fabrication. Everything else becomes ON-DEMAND or is deleted.

Target (measured, not aspirational — P5 measures it on training-nextjs): **PRD → first delivered bolt < 10 minutes** on a mid-size brownfield repo, with all gates live.

## The v6 default pipeline (the spine) — 2 steps before code

Operator refinement (2026-08-03): scan→intent→bind→oq→units as SEPARATE processes is
itself the burden — each phase pays dispatch + context reload + confirmation + handoff.
The VALUE lives in the artifacts, not the phase boundaries. v6 keeps the artifacts and
merges the processes:

```
/mega-sdd <prd>
  1. GROUND (script, seconds, zero model tokens)
       manifest sniff → framework pack resolve; build-symbol-index.sh.
       NO codebase-map, NO deep-scan (both on-demand).
  2. PLAN   (ONE model phase — absorbs intent + bind + oq + units)
       pass 1 (bind): extract claims from the PRD as an internal working table;
         per claim query the symbol index + targeted file reads →
         CONFIRMED/CONFLICT/OQ + anchors → EMIT `binding.md` (compact — the SAME
         artifact + grammar the CONFLICT gate and validators read today).
       gate stop: all P0 OQs batched into ONE AskUserQuestion; P1–P3 auto-defer,
         RECORDED in the artifact (never silent). CONFLICT still BLOCKS.
       pass 2 (units): generate unit contracts with the binding context still
         warm — no handoff, no context reload between bind and units.
       For large PRDs PLAN self-slices per scope INTERNALLY; slicing is an
       implementation detail, never a public phase.
  3. BOLTS  (unchanged) implement → acceptance → B1–B4 → risk-tiered review.
```

Old-phase essence map: scan → GROUND (script); intent → PLAN's internal claims table
(vault docs = emission); bind → PLAN pass 1 (the `binding.md` ARTIFACT survives —
moat invariant 1 demands the verdict artifact, not a separate phase); resolve-oq →
a gate condition inside PLAN (one batched prompt); units → PLAN pass 2.

> **Realization note (P4, 2026-08-04):** PLAN is REALIZED as the express chain
> segment (one upfront confirmation, inline Skill dispatch, warm context) — not as
> a structural single-skill merge, which is rejected on the record in §P4.4.

Human documents (vault docs, PRD/FSD/SIT/UAT) are **emissions on demand** (`/mega-sdd:emit …`), derived from the ledger + binding + units + code — never stations on the code path. (This completes the v5 direction "docs as dynamic emissions" instead of half-keeping the vault in the middle.)

## Keep — the four goals' load-bearing parts (unchanged behavior)

- **Anti-fabricated:** the 5 invariants, CONFLICT gate, B1–B4, anti-self-bypass, recompute-at-gate, halt taxonomy, no-fabrication→OQ. Byte-for-byte.
- **Standarisasi:** framework packs, Hard-rules grammar, standards-reviewer lens, postflight mechanical-rule recompute.
- **Reuse:** symbol-index + dispatch `symbol_slice` + diff-scoped dup sweep + the code-quality lens evidence block.
- **Speed already shipped:** sync lane, `--changed-only`, debounce, scoped analyze, `--lean`, Windows-safe hooks.

## Cut / demote (with the honest reason)

| Surface | v6 fate | Reason vs the four goals |
|---|---|---|
| `scan-codebase` full inventory (120KB map + deep-scan subagents + starterkit deep context) | **Demoted to on-demand.** GROUND = manifest sniff + symbol-index only. The map derives on demand when an emission or a human asks. | Its two real consumers are bind (replaced by claim-scoped queries) and reuse (already served by the index, in seconds, zero model tokens). 25 min + 27% of scan cost bought inventory, not delivery. |
| Vault as 7 human docs mid-path | **Replaced by the claims ledger** (one terse file) as the CONSUMPTION plane. Vault docs = emission for human rendering (`full` mode); the compact markdown stays the authoring/verification substrate — honest realization in §P4.2. | Downstream consumes claims+anchors, not architecture prose + mermaid. |
| Full-vault bind sweep | **Claim-scoped bind (D3).** Fail-closed: index query → targeted read → still ungrounded ⇒ OQ, never a guess. | A 5-claim feature paid for 40 claims. |
| OQ ceremony (interactive per-OQ walkthrough) | **Only P0 blocks.** P1–P3 auto-defer with disclosure in the ledger. | Speed; anti-fabrication is preserved by the defer being RECORDED, never silent. |
| Advisor legs, analyze-parallelism, list-modules, emit-agents-md in-chain | **Opt-in only** (the `--lean` cuts become the default; `--full` restores). | Advisory, re-runnable, not delivery. |
| Review panel 5 lenses on every unit | **Risk-tiered by default** (already designed; v6 makes the low tier = 1 lens the common case). | Speed; high-risk units keep the full blind panel. |
| 5.x deprecation aliases (the ~20 folded commands) | **Removed in v6** — allowed: demoted in the 5.0 MAJOR, removal permitted in the following major after telemetry review (policy clause). | Surface weight; the 3-verb surface stands. |
| PageRank-class inventory analytics | already removed (D1) | — |

## Hard design rails (carried from hard-won lessons)

1. **Gates > rules > hooks** unchanged; no gate weakened in the name of speed — speed comes from cutting *inventory*, never *verification*.
2. **Claim-scoped bind is fail-closed:** an ungroundable claim becomes OQ/CONFLICT, never CONFIRMED-by-absence. The binding contract (verdict grammar, anchors, provenance) is unchanged — only its RETRIEVAL is scoped.
3. **The ledger is the AI plane; docs are the human plane.** Ledger stays terse and machine-checked; no human-prose creep back onto the path.
4. **Deterministic work in scripts** (ground, index, derive) — model tokens only where judgment lives (claims, verdicts, code).
5. **Sync compatibility:** the sync lane keys on the ledger + binding the same way it keyed on the vault; existing vault projects get a one-time `migrate` derive (vault → ledger), read-side compatible.
6. **(A1) PLAN anti-rot protocol:** binding contract + Hard rules anchored at context START; running verdict table maintained at context END; raw evidence reads shed after each claim's verdict lands (self-slice = compact the evidence, keep the verdicts). If a pass runs long, escalate to factored per-claim re-verification in clean context — never silently degrade. (Context-rot literature: degradation starts well before the window limit; mid-context is the dead zone.)
7. **(A2) The merge is safe BECAUSE the pass never grades itself:** binding.md + units are validated by scripts (recompute-at-gate) and fresh-context review — the independent grader, per the "agent doing the work isn't the one grading it" doctrine.
8. **(A3) Query, never inject:** GROUND's index is a navigation substrate the PLAN pass queries; never front-loaded wholesale. Index rows route to targeted reads; verdicts anchor to READ evidence, not index rows.
9. **(A4) Protect the acceptance test:** authored/frozen before implementation; the implementer may not modify it; the gate recomputes against the frozen test. (59.4% of SWE-bench Verified failures were defective tests — a weak test is a fabrication vector.)
10. **(A5) Deterministic risk router:** the review tier is chosen by deterministic evidence (paths touched, diff size, security surface), never the model's self-assessment; the low tier's single lens is spec-conformance sitting on top of the executed acceptance test.
11. **(A6) Deferred OQs must re-surface:** auto-deferred P1–P3 OQs are RECORDED in the artifact AND re-listed in the delivery report; a defer that never resurfaces is a silent assumption.

## Phasing (each phase = spec section → implement → tests → dual-blind round → ship)

- **P1 — claims ledger + claim-scoped bind (D3 core).** ✅ **SHIPPED v5.34.0** (2026-08-03, behind `--express`; deep dual-blind round — disclosure below). Deliverable delivered: bind works from ledger + completeness sweep + index with zero map load.
- **P2 — GROUND step + express default.** ✅ **SHIPPED v5.35.0** (2026-08-03; deep dual-blind round — disclosure below). scan demoted (on-demand map seam); the front door defaults to the spine; `--classic` / `spine: classic` restores scan-first verbatim.
- **P3 — OQ auto-defer + risk-tier default + lean-by-default diagnostics.** ✅ **SHIPPED v5.36.0** (2026-08-04; dual-blind round — disclosure below; advisor legs kept default-on, the stated rail-1 deviation).
- **P4 — surface cull.** ✅ **SHIPPED v6.0.0** (2026-08-04, 194b1b3; deep dual-blind round — disclosure below). Alias removal per policy (telemetry review discharged, honestly scoped); relocate-then-delete for the dangling-8; emit-lane source repair (modern-vault FSD/PRD); PLAN merge + vault-as-emission rejected on the record.
- **P5 — measure.** End-to-end wall-clock + cost-weighted tokens on training-nextjs, before/after, published in the README. The <10-minute claim lives or dies here. **(A7) Protocol:** endpoint = acceptance-VERIFIED bolt (never first diff); human-wait time explicitly in or out of the clock; speed paired with a quality counterweight (revert/rework); same repo, comparable task class; never self-reported. (METR RCT: devs were 19% slower while believing +20% faster — perception is inadmissible.)

Version: **6.0.0** at P4 (the breaking-surface release); P1–P3 ship as 5.x pre-major tranches where back-compatible, behind `--express` until P2 flips the default.

## Non-goals

- No weakening of any gate (mandate: "standar yg udah di set atau hard gate").
- No rebuild of what native Claude Code covers (agentic search/LSP stay native).
- The doc pack (PRD/FSD/SIT/UAT emissions incl. SEOJK UAT) is NOT cut — it moves fully to on-demand, same quality bar.

---

## P1 — claims ledger + claim-scoped bind (design, 2026-08-03)

Ships as **5.34.0**, behind `--express`. Deliverable: bind produces a byte-compatible `binding.md` from **ledger + symbol-index + targeted source reads, with zero codebase-map load**. Nothing outside the express lane changes behavior.

### P1.1 The claims ledger — `<vault>/claims-ledger.json`

**Script-derived, never model-written** (`scripts/derive-claims-ledger.sh`), honoring the md-authoritative rail: the vault markdown stays the single grammar; the ledger is a derived index of it, exactly like `vault.json` — a PURE derive lane with NO patch surface at all: every run is a full overwrite reconstructed from the markdown (anti-laundering by reconstruction; E1 re-derives on every express bind, so a hand-edited ledger never survives to be consumed).

**The ledger is a SKELETON, never the claim boundary (round-folded — the round's ship-blocker):** a template-conformant vault carries claims the deterministic grammar cannot see (named-H2 component sections, prose constraints, naming conventions). Express bind therefore runs a MANDATORY model completeness sweep over the vault docs (small — the express saving is the map, not the vault) and APPENDS the missed claims with ids continuing each doc's ordinal stream; the `binding-contract.md` claim-categories table is the sweep's checklist, and every category with vault content must yield ≥1 claim or an explicit empty-category note. Without the sweep, express narrows what gets VERIFIED — the cut the mandate forbids.

Schema (terse, machine-checked):

```json
{
  "schema": 1,
  "generated_by": "derive-claims-ledger@1.0.0",
  "generated_at": "<ISO>",
  "vault": "<vault path>",
  "doc_shas": {"01-overview.md": "<sha256>", "...": "..."},
  "claims": [
    {
      "id": "C-DM-01",
      "type": "entity|flow|decision|component|constraint|mode",
      "text": "<verbatim from the vault doc>",
      "source": "03-data-model.md:42",
      "hints": {"symbols": ["LeaveRequest", "leave_request"], "terms": ["cuti"]}
    }
  ]
}
```

- **Extraction is deterministic**, reusing the shared `_lib/vault_md.py` grammar: DBML `Table` + `// Purpose:` (03 → entity, grammar-marginal shapes fail LOUD with exit 2 — never silently narrowed), `### F-*-NNN:` (04 → flow), `### D-NNN:` (05 → decision), `## §<id>` sections (any doc 01–06 → component), NFR table rows (06 → constraint), implementation mode from the 00-index Vault Lock SECTION (id `C-MODE-01`). A cross-count guard against the shared lib makes a grammar fork exit 2 on a clean lib parse.
- **IDs**: `C-<DOCCODE>-<NN>` (`MODE` for the lock claim), per-doc ordinal — deterministic given the vault bytes; the `vault` field records the SLUG (never the caller's path argument), so abs/rel invocation cannot change the artifact's bytes. Stability across vault edits is the SAME class as today's model-minted ids (none guaranteed); the `--paths` fallback condition "vault regenerated → full re-bind" already covers renumbering.
- `source` is exactly `NN-name.md:LINE` (the `make-bound.sh` `SRC_RE` form) so BIND annotations keep working.
- `hints` are **advisory retrieval seeds** (name-case variants, endpoint terms), NEVER a retrieval boundary.
- Registrations: `references/paths.md` layout + per-skill table; `hooks/stop` + `hooks/post-tool-use` prune lists (derived output); state_probes NOT in P1 (express is flag-driven; routing lands in P2).

### P1.2 Claim-scoped bind (`bind-codebase --express`)

Procedure lives in a new `bind-codebase/references/express-bind.md` (one level deep); SKILL.md gains the flag row + a short section. Per ledger claim, the **fail-closed retrieval ladder**:

1. **Index query** — `scripts/query-symbol-index.sh` (its first real consumer) by each hint symbol/name variant, then by target dir.
2. **Targeted Read** of candidate files at the returned anchors — **verdicts anchor to READ evidence, not index rows** (rail A3).
3. **Collision sweep** (moat-critical, round-hardened): for entity/component/naming claims, TWO mandatory legs — a repo-WIDE index name-query AND one bounded repo-wide Grep (the index covers only tracked files with covered extensions; the Grep leg closes untracked/uncovered surfaces); a hit outside the claim's expected home is evaluated as potential CONFLICT, never skipped.
4. **Bounded repo Grep** for claim terms when 1–3 are silent.
5. Still ungrounded ⇒ **OQ (or CONFLICT when evidence contradicts), never CONFIRMED-by-absence** (rail 2).

Boundary posture (why this passes the seed-not-boundary obligation that killed the precomputed slice): the searchable universe is the **entire repo** (index is repo-wide; Grep/Read unrestricted) — nothing is removed from searchable, so there is no slice whose recall needs proving. The codebase-map is simply **not read** (ground truth is the source itself).

- **Index freshness is the controller's step** (R2 lesson): express Step 0.x runs `build-symbol-index.sh` when the index is absent or `head_commit` ≠ HEAD (seconds). ast-grep missing (rc 3) ⇒ **fall back to the standard full-read bind with a one-line note** — never a silently degraded express.
- **Tech-OQ scan resolution** in express cites actual files (`phpunit.xml:1`) via manifest/index probes instead of map§ — already the template's citation form.
- **Vault text**: claim text comes verbatim from the ledger (script-derived from the vault), satisfying the "no paraphrasing" rail; the model reads specific vault lines only when a verdict needs surrounding context.
- `--paths` composes: `--paths` keeps selecting WHICH claims re-verdict (anchor reverse-index, active CONFLICTs always), `--express` selects HOW evidence is retrieved for the affected set.
- Steps 2.5–2.12 (state classification, hard rules, constitution, advisor) unchanged.

### P1.3 Byte-compat obligations (the frozen grammar)

The express lane emits the IDENTICAL `binding.md` grammar — specifically the load-bearing surfaces mapped 2026-08-03: frontmatter `binding_metadata.codebase_map_provenance` (indent-optional) + `head` (indent-REQUIRED), the `## Implementation State Map` 6-column table with the closed `[reason:]` enum trailing in the Anchor cell, 4-field `## Confirmed Claims` lines, canonical `### CONFLICT-N` headings with structural resolution markers, the H2 OQ-section heading substrings (`Tech-OQ Auto-Resolved` / `Open Questions` / …), ` + ` multi-anchor separator, `- **Vault claim**:` / `- **Claim**:` detail lines. Express adds ONE additive frontmatter key `binding_metadata.retrieval: express-index@<head8>` — line-regex parsers are proven blind to unknown keys. `codebase_map:` keeps the canonical path; provenance uses the existing closed enum (`no-snapshot` when no map exists — chain optimization then keeps scan, which is correct until P2).

### P1.4 P1 proof tests

1. **Ledger determinism**: fixture vault → ledger; re-derive byte-identical (minus `generated_at`); malformed vault → honest exit 2; `source` matches `SRC_RE`.
2. **Grammar byte-compat**: an express-shaped `binding.md` fixture (incl. the `retrieval:` key) through the FULL chain — stamp → derive-binding-json → validate-binding-json → validate-handoff-binding-units → make-bound (refuses on CONFLICT, produces `bound/` when clean); binding.json equality with/without the additive key.
3. **Seed-not-boundary (reachability arm)**: fixture repo where the colliding symbol lives OUTSIDE the claim's expected dir; `query-symbol-index.sh --name=<entity>` MUST surface it; prose pins that express-bind.md mandates the collision sweep + the fail-closed ladder + never-CONFIRMED-by-absence.
4. **Flag parity**: `--express` present in front-door hint + §Flag handling (forwarded verbatim, the `--converge` pattern) + orchestrate-flow §Flags + bind SKILL — keeping the ghost-flag guard green.
5. **Fallback honesty**: index rc 3 ⇒ standard-bind fallback prose pin.

---

## P2 — GROUND step + express default (design, 2026-08-03)

Ships as **5.35.0**. The front door defaults to the spine: GROUND (script) replaces scan-as-phase in every default chain, and `bind-codebase` hops dispatch with `--express` by default. Opt-out restores today's behavior exactly: `--classic` flag (front door + orchestrate-flow, forwarded verbatim) or persistent `spine: classic` in `.mega-sdd/config.yaml` (probe cloned from `profile:` — top-level, first-match-wins, default `express`). **Demote ≠ delete:** scan-codebase stays fully invocable — it is the ONLY map producer (`derive-codebase-map.sh` is an assembler over a model-written delta, not a standalone deriver), the on-demand map seam, and the sync lane's producer on map-bearing projects.

### P2.1 GROUND = the probe engine, extended — not a new phase

Anti-fork doctrine: the sniff lives in `_lib/state_probes.py` (the ONE probe engine routing + preflight + session-start already share), surfaced by `derive-state.sh` — which is ALREADY the zero-token script step at front-door Lane 0 step 1. A thin `scripts/ground.sh` wrapper gives the verb a name: `derive-state.sh` (extended) + `build-symbol-index.sh`. Two spawns, seconds, zero model tokens.

New in the engine:
- **`MANIFEST_SIGNALS` widened** to the ecosystems the pack registry + scan Step 2 already enumerate (`*.csproj`/`*.sln` globs, `Package.swift`, `mix.exs`, `pubspec.yaml`, `Pipfile`, `build.gradle.kts`, `build.sbt`) — today a .NET repo with two `ready` packs still halts `no_starterkit_detected`.
- **`probe_framework_pack()` — the genuinely new piece:** a deterministic manifest→pack matcher executing the `detection_signature` frontmatter every pack already carries (data-complete, code-absent — the mapping ran model-side in scan Step 8.5 until now). Precedence via a new OPTIONAL `detection_priority:` frontmatter key (default 100; lower wins — starterkit variants and meta-frameworks set lower; linted by `validate-pack.sh`), because `extends:` depth cannot encode remix>express. No match → `_universal`, same as today. Result lands in `derived.framework_pack`.
- **`probe_symbol_index()`**: `{present, head_commit, matches_head}` — the change-signal substrate for express-born projects.
- **`probe_spine()`**: the config read.
- `resolve-framework-pack.sh` gains a **`state.json` `derived.framework_pack` source, deliberately ORDERED BELOW the scan artifacts** (starterkit-context.yaml / codebase-map win when scan ran — deep-scan-verified detection outranks the sniff; express-born projects have neither and land on the state source; never a second sniff — one matcher, one grammar), cache meta bumped `packres-v2` with the state file in the `-nt` validity loop.

GROUND must NOT: write `starterkit-context.yaml` (cache-keyed deep-scan artifact — a script stub reads as a false warm cache and a Hard-rule citation trap), or move `build-symbol-index.sh` out of execute-bolts batch setup (bolt commits land after GROUND; the batch rebuild keeps `symbol_slice` honest).

### P2.2 Chains without scan (the flip)

- `finish()` in the state engine appends `--express` to every `bind-codebase` hop (the lean-injection pattern — one site) unless spine=classic.
- `prd_no_vault`: `[generate-intent <prd>, bind-codebase --express, generate-units]` — no scan hop, no `--scan=` arg.
- `vault_no_map`: redefined → `[bind-codebase --express, generate-units]` (as written it becomes an unreachable trap once the map never exists).
- Starterkit Modes A/B collapse into the scan-free shape (Mode C was always scan-free); the "scan di depan" rationale row is rewritten, not just the table — the fabrication risk it guarded ("vault gen'd without code awareness") is now carried by intent's index-grounding + bind --express verification instead of a 25-minute inventory phase.
- Deep-chain matrix + Lane 1 directory route: scan hops dropped under express; `--classic` renders today's rows verbatim.

### P2.3 The resurrect-vectors (each closed explicitly)

1. **`validate-preflight.sh` FATAL `binding_input_map_missing`** — the one map-hard gate with no carve-out: gains `--express` awareness (the PreToolUse hook forwards it when the bind dispatch args carry `--express`); vault arm stays FATAL.
2. **chain-optimization `no-snapshot` → "keep scan"** (chain-execution) — express stamps `no-snapshot` ALWAYS, so this branch would re-add scan to every express chain: branch now keys on the lane (`binding_metadata.retrieval` present ⇒ scan stays out; classic keeps today's logic).
3. **generate-units Step 0.5 auto-run** of scan under `--auto` — must not fire when the map is intentionally absent (express binding present ⇒ proceed).
4. **generate-intent brownfield prompt** ("Run scan-codebase first?") — deleted; map-less brownfield is the default branch. `--scan=` stays for classic/map-present runs.

### P2.4 The oq_gate trap (map 1's blocker-class finding)

Tech-OQ `scan_query` is keyed literally on `codebase-map §…`; without a map at intent time those P1 OQs stay open and `oq_gate` inserts an interactive `resolve-oq` BEFORE bind — a hard stop on the default path. Fix that preserves the gate's meaning (chosen over exempting `resolution_mode: scan` from the count, which weakens it): **the intent Step 3.5 classifier + bind Step 2.6 resolve `tech/scan` OQs from `state.json` (manifests, framework_pack) + symbol-index queries + targeted file probes**, citing real `file:line`; `vault-contract` re-words `scan_query` to name probe targets, not map sections. Same auto-resolve confidence rules; no gate arithmetic changes.

### P2.5 Sync on express-born projects (no map, ever)

Today all four change-signal links are map-gated — an express-born project NEVER hears "code moved" and `/sync` reports a false all-clear. Fixes:
- Dirty journal gate (post-tool-use) re-keys from map-presence to `.mega-sdd/codebase/` presence.
- `derived.change_signal` gains `index_stamp_matches_head` (from `probe_symbol_index`); session-start staleness notice + Lane 0 status view fire on EITHER map-stale OR index-stale OR dirty rows.
- Mode D guard accepts (map present OR index present) + binding.
- Changed-set producer for map-less Mode D: new `scripts/derive-changed-paths.sh` — `git diff --name-only <index.head_commit>..HEAD` ∪ dirty-journal rows → `<vault>/.sync-changed-paths.txt` (same consumer contract: `detect-drift --scope=@`, `bind-codebase --paths=@ --express`). Map-bearing projects keep `scan-codebase --changed-only` unchanged.

### P2.6 Honest degradations (recorded, never silent)

- execute-bolts loses BOTH pattern-signature legs on express-born projects (no starterkit-context, no map §6) — the dispatch builder's existing `omit(...)` records it; the enrichment doc states the new truth.
- emit-fsd renders `[Pending — codebase-map.md not yet generated]` rows — already honest; the on-demand answer is "run `/mega-sdd:scan-codebase` when you want the map".
- Guard 7 / shared-snapshot / scan SKILL prose updated to the demoted reality.

### P2.7 P2 proof tests

1. Chain renders: default express (no scan hop, `--express` on bind) per position; `--classic`/`spine: classic` renders today's rows byte-for-byte; fixtures for prd_no_vault / vault_no_map / Mode D both breeds.
2. `probe_framework_pack`: fixture manifests per ecosystem (incl. `*.csproj` glob + laravel-base-26>laravel + remix>express precedence + `_universal` fallback); parity with the resolver source #0.
3. oq_gate: a tech/scan OQ vault + no map must NOT land `oq_gate` on the express path (classifier re-key), and MUST still gate under classic-with-no-map as today.
4. Sync signals: express-born fixture (index present, HEAD moved) → change_signal fires, Mode D proposed, `derive-changed-paths.sh` writes the changed set; map-bearing fixture unchanged.
5. Resurrect-vector pins: preflight express carve-out; chain-optimization branch; units Step 0.5; intent prompt gone.
6. validate-pack lints `detection_priority` when present.

---

## P3 — OQ auto-defer + deterministic risk-tier + lean-by-default diagnostics (design, 2026-08-04)

Ships as **5.36.0**. Three halves, each with its fork decision stated.

### P3.1 Terminology mapping (kills a standing ambiguity)

The v6 prose said "P0 blocks; P1–P3 defer" — but **P0 has never existed in the OQ grammar** (`OQ_PRIORITY_RE` is `P[123]`; `by_priority` is a closed P1/P2/P3 dict; nothing ever writes P0). The repo's **P1 = "Sprint-0 blocker"** IS the v6 prose's "P0". Mapping, binding from here on: **the BLOCKING tier = P1** (asked, batched); **the DEFER tier = P2/P3** (auto-defer, recorded). Fork A-ii chosen over minting a real P0: the gate (`pending_p0_p1` counts open P1s) needs ZERO arithmetic change, no vault migration, no grammar widening — the work is entirely in the producer. Docstrings/routing notes gain the honesty note; the field name `pending_p0_p1` stays (renaming breaks consumers).

### P3.2 The OQ flow under express (the default)

When the chain routes `resolve-oq` (oq_gate) under the express spine + `--auto`:

1. **Blocking tier (P1) — ONE batched AskUserQuestion**: up to 4 OQs per call (the tool's cap — the per-question shape keeps the existing 4-slot + Other contract and the keterangan rules verbatim); >4 open P1s chunk into ceil(N/4) sequential calls, disclosed upfront ("N blocker, K prompt"). The interview-pattern consolidation: all human decisions in one stop, not N stops.
2. **Defer tier (P2/P3) — auto-defer, RECORDED, never silent**: the shipped Defer plumbing verbatim (`[ ]` + `**Deferred (v{X.Y})**` marker, `status: deferred`, `defer_to: stakeholder` via the derive `--patch` lane — the deriver never parses defer_to from markdown, so event-only recording is INCOMPLETE (round-folded), script-stamped `deferred_at`) with a MECHANICAL reason — `auto-deferred (P2, express) — bukan blocker delivery pertama; muncul lagi di delivery report`. The invariant-#5 clause ("recorded state may never be defaulted") is amended to permit the mechanical reason STRING while the defer FACT stays fully recorded — the disclosure is the point, and fabrication risk is zero (no content is invented, a decision is postponed on the record).
3. **The interactivity rails re-scope, not die**: "the walk stays interactive on EVERY OQ" + "'answer all OQs for me' → refuse" now govern (a) the BLOCKING tier always, and (b) EVERY tier when resolve-oq is invoked standalone/explicitly or under classic — the interactive walk is unchanged there. Auto-defer applies ONLY on the chain-routed express path.

**A6 re-surfacing (three additive surfaces, all pure reads of `vault.json status == deferred`):** `resolve-oq` handoff `metrics.items_deferred` upgraded from a count to an id list (tag, priority, reason); execute-bolts `_summary.md` gains `## Deferred open questions (N)`; the orchestrate final summary (Step 9 AND the --deep appendix, modeled on the acceptance-test-concerns bullet) lists them with the re-run command (`/mega-sdd:resolve-oq`). A defer that never resurfaces is a silent assumption — these are the resurface.

### P3.3 Deterministic risk router (A5) + the 1-lens common case

Fork B-i: tier resolves PRE-dispatch from unit-declared evidence (no topology change); "diff size" is proxied by declared `target_files` count — the real-diff variant (post-L0 tier resolution) is explicitly DEFERRED with its contradiction noted (review-panel.md:27 "resolve BEFORE dispatch").

- **New `scripts/resolve-review-tier.sh`** — the first machine evaluation of the six risk signals (previously model-judged prose): reads unit frontmatter (`target_files[].path/.operation`, `risk:`, `mutability:`, `binding_refs:`, `task_type:`), the GROUND-resolved pack's `auth_hints`/`authz_hints` globs (nothing in scripts/ read them before), and the body vocabulary list. Prints `{"tier", "signals_fired": [...], "signals_evaluated": [...]}`. Override chain unchanged (`--review-panel=` > config > auto); a forced-minimal-with-signals warning stays.
- **Status pin (round-folded):** express auto-defers alone NEVER flip the resolve-oq handoff to `paused` — a fully-executed batched walk ends `completed` (else the chain would stop after resolve-oq on every express run).
- **Predicate rewrite making `minimal` reachable** (it was near-unreachable — the `no operation: create` clause excluded every create/extend-with-new-file unit): `minimal` (spec lens only) = `task_type: verify` OR (≤2 target files AND zero risk signals). The dropped clause's protection is carried by the signals themselves + the executed acceptance test + L0 gates under every tier (the research-validated pairing: the 1 lens sits ON TOP of executed evidence, never instead of it). Tier NAMES stay `minimal|standard|full` (test-pinned).
- **Audit trail**: bolt-report `## Review panel` now REQUIRES `signals_fired[]` beside the tier — a LOW-tier default is defensible only with the router's evidence on the record.
- The six signals themselves are UNCHANGED — no security-surface weakening; the change is WHO evaluates them (script, not model) and the minimal predicate.

### P3.4 Lean-by-default diagnostics — WITH one deliberate spec deviation

**Deviation, stated:** the v6 cut table listed "advisor legs" in the opt-in-only row. **P3 keeps the advisor legs DEFAULT-ON.** Rail 1 ("speed cuts inventory, never verification") outranks the cut table: the advisor hunts false-CONFIRMED — it IS verification, and it is precisely the recall safety-net for claim-scoped express retrieval. It is also cheap post-P7 (slice-first bundle). What goes lean-by-default is the ADVISORY DIAGNOSTICS only:

- Under the express spine: `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md` are SKIPPED in-chain (each re-runnable on demand; `--full` restores for a run); the Stop-hook auto-analyze aggregate fires only under `spine: classic` or an explicit `profile: full` in config. Classic renders today's behavior verbatim.
- `--lean` (advisor cut) stays an opt-in profile exactly as shipped; the "Lean NEVER touches" list survives intact (review-panel tiering is now profile-INDEPENDENT — deterministic script — so that clause stays true by construction).
- P5 measures whether the advisor's cost justifies revisiting the deviation; until measured, verification stays.

### P3.5 P3 proof tests

1. Router fixtures: verify-unit → minimal; ≤2-file clean create → minimal (the newly-reachable case); auth-glob / manifest / ≥4-files / vocab / `risk: critical` / §B-clause → full; signals_fired echoed; override chain honored; tier names unchanged (wired test stays green).
2. OQ pins: batched-P1 prompt shape + chunking rule; auto-defer records marker+status+reason+defer_to; rails re-scoped (standalone walk unchanged); A6 surfaces present (metrics id-list, `_summary` section, Step 9 + appendix bullets).
3. Lean default: express chain skips diagnostics / classic keeps them; Stop-aggregate condition pinned; `--full` restore.

## P4 — 6.0.0 surface cull + docs-on-demand completion (design, 2026-08-04)

Ships as **6.0.0** — the breaking-surface release the phasing plan reserved. The break is the **typed alias surface only**; every artifact grammar, gate, hook contract, and the classic spine ship byte-compatible. Four deliverables: (A) alias removal with content relocation, (B) docs-on-demand completion — an honest realization record plus the emit-lane repair, (C) README + the 5.x→6.0.0 migration guide, (D) the PLAN-merge decision record.

### P4.0 Telemetry review (the policy clause, discharged)

CLAUDE.md policy: a demoted pipeline command may be removed "only in the FOLLOWING major after telemetry review." Review performed 2026-08-04 on the only telemetry corpus available (this repo's `.mega-sdd/memory/telemetry.jsonl` — ~22k events since 2026-05-27, the blackbox + live-dev corpus). **Honest instrument scope (round-folded):** the corpus's event classes are ref-loads, halt markers, and turn/subagent markers — it has NO channel that records typed slash-command invocations, so "zero alias strings in the corpus" is absence-of-instrument, not evidence-of-absence, and is not claimed as usage evidence. The review is discharged on its procedural substance: the aliases spent the full 5.x cycle demoted with a printed deprecation notice, the only known field installs (two office laptops, v5.9.0) cross the major via `update-plugin` and are covered by the migration guide (C), and every typed legacy form still routes as plain text after removal (zero hard breakage for a habituated user). Verdict: removal proceeds.

### P4.1 Alias cull (24 files) — relocate first, delete second

The 24 `DEPRECATED (5.x alias)` files split into two populations with different blast radii (census 2026-08-04):

- **Safe-16** (a live `skills/<name>/` backs them): only the typed slash form dies; natural-language routing + Skill dispatch survive untouched. `analyze`, `bind-codebase`, `detect-drift`, `diff-vault`, `emit-agents-md`, `emit-fsd`, `emit-prd`, `emit-sit`, `execute-bolts`, `extract-intelligence`, `generate-intent`, `generate-units`, `graph`, `orchestrate-flow`, `resolve-oq`, `scan-codebase`.
- **Dangling-8** (no backing skill): `analyze-parallelism`, `auto`, `enrich-semantics`, `lint-units`, `list-modules`, `migrate-rules`, `replay`, `validate-handoff`. Seven of the eight carry the ONLY copy of an operative procedure — several surviving scripts cite the command file as their spec (`replay.sh` "extracted from commands/replay.md", `list-modules.sh`, `migrate-v1-rules.sh`). Deleting without relocation would mint eight new instances of the phantom-command defect `AUDIT.md:298` already adjudicated.

**Relocation map (before any deletion):**

| Alias file | Judgment content | New home |
|---|---|---|
| `lint-units.md` (107 ln) | §Step 1b `--changed-only` scope-set (changed ∪ dependents + honest full-sweep fallback), cross-unit grounding checks, halt roster | `skills/orchestrate-flow/references/diagnostics-procedures.md` (NEW — the chain rows at `chain-execution.md:183-186` are its only invoker) |
| `analyze-parallelism.md` (62 ln) | over-coupling interpretation, exit-code halts, "never suggest the halting form" rail (test-pinned) | same NEW ref (chain row :184; cross-cited from `execute-bolts/references/batch-and-fanout.md`) |
| `list-modules.md` (58 ln) | `--mark-dod=<module>` interactive flow (sole home) | same NEW ref (chain row :185; cited by `batch-and-fanout.md:41`, `modules-schema.md:243`) |
| `enrich-semantics.md` (29 ln) | the `--semantic=staged-input` / `--apply` two-phase contract (10 runtime citers incl. a chain pause) | same NEW ref (chain pause :196) — extract-intelligence + vault-staging validators re-point here |
| `validate-handoff.md` (101 ln) | drop-type resolution table (§Scope relocates VERBATIM — the round verified it against the current validator: slice 2 ✅ matches shipped behavior; an earlier census note claiming `AUDIT.md:226` recorded it stale was itself wrong and is retracted) | `skills/bind-codebase/references/handoff-validation.md` (NEW; bind owns the binding grammar) |
| `replay.md` (98 ln) | snapshot grounding + severity table (`replay.sh:4,:257` cite it as spec) | `skills/execute-bolts/references/replay.md` (NEW) |
| `migrate-rules.md` (61 ln) | the 6-step v1→v2 transform (the shell script is detector-only and defers to this prose) | `skills/execute-bolts/references/migrate-rules.md` (NEW — its script already lives under execute-bolts) |
| `analyze.md` (71 ln) | auto/manual mode split, `--fresh`, "Scoped by default" (test-pinned in both planes) | merge into `skills/analyze/SKILL.md` (skill exists) |
| `auto.md` (17 ln) | nothing — the `--stop-after`→`--to=` render exception is already duplicated at `orchestrate-flow/SKILL.md` + `handoff-contract.md:396` | no relocation |

**Reference rewrite buckets** (runtime surfaces only; dated records — specs/plans/audits/research/CHANGELOG — stay verbatim per the in-repo doctrine `test-2a2d-chain-parallel.sh:93-95`): R1 front door `/mega-sdd`, R2 `/mega-sdd:sync`, R3 `/mega-sdd:emit <doc>` (mechanical for the emit family — `emit-uat` already lives alias-free, the proven end-state), R4 Skill-dispatch prose (`mega-sdd:<name>`), R5 relocated-reference pointers. Hard sites: 2 live PreToolUse deny strings (`hooks/pre-tool-use:504,518` → point at `scripts/validate-handoff-binding-units.sh` + `/mega-sdd`), ~14 validator advisory strings (`validate-kb-flows.sh`, `validate-vault-flow-staging.sh`, `run-preflight-scan.sh`, `migrate-v1-rules.sh`), the always-loaded `skills/graph/SKILL.md` description (phantom slash form), both READMEs, `upgrade-from-old-version.md`. Manifests need nothing (`plugin.json` has no `commands` array; marketplace lists none). The user-level front-door wrapper (`~/.claude/commands/mega-sdd.md`) is untouched.

**Test plan for the cull:** `tests/surface/test-p6-front-door.sh` §C (the "exactly 24 aliases" contract) is REWRITTEN into the 6.0.0 contract — zero `DEPRECATED (5.x alias)` files exist, the kept-7 enumerate exactly, and no runtime surface (skills/ + commands/ + hooks/ + scripts/ + top-level references/) names a dead `/mega-sdd:<alias>` slash form (the census's phantom-command sweep, now a standing pin). Two hard-abort guards (`test-4d-contract-truth.sh:34`, `test-2a2d-chain-parallel.sh:26`) and 7 assertion pins re-point to the relocated homes — each pinned CONTRACT survives; only its address changes.

### P4.2 Docs-on-demand completion — the honest record + the emit repair

**Realization record.** The cut-table line "Vault as 7 human docs mid-path → replaced by the claims ledger" is DELIVERED in its load-bearing sense, and the remainder is deliberately refused:

- *Consumption* left the docs in P1–P3: bind retrieves ledger + targeted reads (zero whole-vault load), diagnostics + agents-md skip in-chain, FSD opt-in, scan on-demand. Nothing bulk-reads the 7 docs on the express path.
- *Production* is already the terse plane: `OUTPUT_MODE: compact` (the default) writes tables + DoD + citations, no narrative scaffolding; `full` remains the on-demand human rendering.
- *Removing the docs themselves is REJECTED* (census 2026-08-04): the vault markdown is the **verification substrate** — the drift baseline `detect-drift` diffs against code, the OQ authoring surface `resolve-oq` edits, the byte-copy source of `bound/` (`make-bound.sh` exit 3 without it), the sha256 target of citation discipline (`build-citation-map.sh`), the anchor space of every unit's `vault_source`, and the single grammar (`_lib/vault_md.py`) both derive scripts + validators share. Cutting it cuts verification, not inventory — rail 1 forbids exactly this. The ledger remains the CONSUMPTION plane; the markdown remains the AUTHORING plane (md-authoritative rail, P1.1 unchanged).

**The emit repair (the real completion gap).** Census finding: `build-fsd-core.sh` sources §5 FR + §6 NFR from `02-functional.md` and §10 from `03-open-questions.md`; `build-prd-core.sh` §6 likewise — file names from an older vault generation that today's `generate-intent` (and every template + fixture) never produces, so on every modern vault those sections emit `[Pending — …]` slots. "Docs on demand" is only complete if the on-demand docs actually derive from what exists. Repair, bounded to source re-pointing (modern-first, legacy name kept as read-side fallback so old vaults keep working):

- §6 NFR → `06-constraints.md ## Non-functional requirements` (the pipe table `vault_md.py` already parses).
- §10 / PRD §6 OQs → the `00-index.md` OQ roll-up / `vault.json open_questions[]` (the derived mirror).
- §5 FR table → enumerate `04-flows.md` `### F-*` (+ per-flow DoD) joined with unit `implements` + the existing `binding.md` per-line verdict scan — flows are the modern vault's functional enumeration (SIT already builds from exactly this).
- Citation strings + `[Pending]` keterangan updated to name the real sources; `.citation-map.json` entries follow automatically (it resolves whatever the builders cite).

Plus one latent-defect fix from the census: `vault_md.parse_rollup_categories` matches only `## Open Questions roll-up` while the template emits `## Open Questions (roll-up)` — the parser accepts both forms (one-line + test); category fallback on template-shaped vaults starts working.

Held (recorded, not done): `doc_shas` in the ledger stays write-only — E1 re-derives the ledger on every express bind, so staleness has no consumer today; wiring a staleness gate is P5-measurement-driven, not speculative.

### P4.3 README + migration guide (5.x → 6.0.0)

- `plugins/mega-sdd/README.md`: the alias table rows become a **migration table** (old typed form → the 6.0.0 way: front-door phrase / `sync` / `emit <doc>` / natural language); the surface statement becomes "3 public verbs + 4 maintenance one-timers — nothing else."
- `plugins/mega-sdd/references/upgrade-from-old-version.md` gains the 6.0.0 section: what broke (typed aliases), what did not (artifacts, gates, classic spine, legacy read-side paths — deliberately KEPT, they are one glob each), the office-floor path (v5.9.0 → `/mega-sdd:update-plugin` → reload), and the alias→verb map.
- Root `README.md` command examples sweep to the 6.0.0 forms.

### P4.4 PLAN-merge decision record

The spine diagram's "PLAN (ONE model phase absorbing intent+bind+oq+units)" is **realized as the express chain segment**, not as a structural skill merge — and the merge is REJECTED for 6.0.0 with reasons on the record: (1) the gates key on per-Skill dispatch (preflight, binding→units, anti-self-bypass matchers) — re-keying them is a moat-surface rewrite bought with zero verification gain; (2) the sync lane and partial re-runs REQUIRE the standalone verbs (re-bind without re-intent, units --reconcile without either); (3) the chain already delivers the merge's substance — ONE upfront confirmation, inline Skill dispatch in the same context (no subagent handoff, no context reload; the MAST 36.9% handoff-loss finding applies to lossy handoffs, which the inline chain does not perform), binding context warm at units time; (4) the residual cost is skill-body loads (~200 lean lines each), addressable later without a breaking change. The pipeline diagram gains a one-line realization note; nothing else moves.

### P4.5 P4 proof tests

1. Surface contract: zero alias files; kept-7 exact; phantom-slash sweep over runtime surfaces green (the rewritten `test-p6-front-door.sh`).
2. Relocation parity: every test-pinned clause (`--changed-only` scope-set, "never suggest the halting form", `--fresh` + "Scoped by default", `whitelist-scan`, `--express` hint, `dirender ke --to=`) asserts at its NEW address.
3. Emit repair: modern-vault fixture emits FSD §5/§6/§10 + PRD §6 with real content (no `[Pending — 02-functional…]`); legacy-name fallback still honored; rollup-heading both-forms parse.
4. Hook strings: the two deny remediations name only living surfaces.

## Round disclosure

### P4 round (2026-08-04, dual-blind)

Two blind agents (code lane: live emit-fixture attacks + hook drives + relocation audit; doc/contract lane: CLAUDE.md/README/spec-honesty + relocation fidelity). **6 blockers (3+3, one shared) + 13 majors + minors — ALL folded or dispositioned:**

- **BLOCKER (code): the §5 flows fallback FABRICATED citations** — `FR_TPL` hardcodes `[Source: vault/02-functional.md:…]`, so every modern FSD stamped a nonexistent file with 04-flows line numbers, then `build-citation-map.sh` failed its own `citation_unresolvable` gate on exactly the vault shape the repair was built for. Fold: the flows branch rewrites the Source path + the `FR-` id prefix in the rendered detail; the proof test now pins the per-FR stamps (the round also named the test's blind spot — it had never inspected them).
- **BLOCKER (code): staging skew** — the index held only the 24 deletions while all four relocation homes were untracked; a bare commit would have shipped the cull with ZERO relocation. Fold: everything added together at commit time (this disclosure's commit).
- **BLOCKER (both lanes): the RC's own surface test red** — the upgrade guide's migration sentence quoted a dead typed form verbatim and tripped the new zero-phantom sweep. Fold: the guide rephrases (the sweep stays absolute — no exemption list).
- **BLOCKER (doc): CLAUDE.md described the culled surface** in five places ("every other command file is a deprecation alias that keeps resolving"; `/mega-sdd:analyze` as the advisory surface). Fold: the living contract now states the 7-file surface + the completed policy ladder + the relocate-then-delete precedent.
- **BLOCKER (doc): the advertised new-user walkthrough taught the dead surface** — `tests/scenarios/README.md` (linked from both READMEs as the chooser) verified installs by `/mega-sdd:auto` autocomplete and listed 12+ removed names. Fold: swept to the 6.0.0 surface; a banner marks older per-scenario walkthroughs (typed legacy text still routes).
- **MAJOR (code): verdict/claim fabrication** — the flows branch promoted the prose word "OQ" to a binding verdict and extracted claim `C-12` from the token `SEC-12`. Fold: a verdict is accepted only from a line that also carries a word-bounded claim id. **MAJOR: flow-id prefix collision** (`F-U-001` matched inside `F-U-001-B` via the digit-only guard → false "Implemented"). Fold: `(?![\w-])` suffix guard + drop-not-truncate heading ids. **MAJOR: `FR-F-*` heading mangling** — folded with the citation fix. **MINOR: DoD DOTALL over-capture** (description swallowed the mermaid body) — folded.
- **MAJOR (code): the rollup-heading widening reaches `validate-vault-oqs`** — the newly-live `(roll-up)` branch lets roll-up headings mint categories on template-shaped vaults. First fold attempt (enum normalization) was itself REVERTED by the suite: the derive fixture pins free-text categories ("PRD inconsistencies") flowing into vault.json — roll-up categories are a free-text contract, not an enum. Final disposition: free-text stays; **disclosed behavior change** — a bracketless OQ under a `Tech*` roll-up heading now receives its category, so one without `resolution_mode` surfaces `oq_tech_missing_mode`, a TRUE positive per the validator's own documented intent ("startswith('tech') tolerates a roll-up-header form") and ADVISORY only (vault-oqs is hook-demoted, never blocking). Repo fixtures byte-identical (A/B verified by the round + the derive suite).
- **MAJOR (doc): the telemetry-review verdict overstated a structurally blind corpus** — no event class records typed command invocations, so "zero recorded alias invocations" was absence-of-instrument framed as evidence-of-absence. Fold: §P4.0 + CHANGELOG + the upgrade guide now state the honest instrument scope; the review stands on its procedural substance (full-cycle demotion notice, the v5.9.0 field floor covered by the migration guide, typed text still routing after removal).
- **MAJOR (doc): the spec cited a correction that never happened** — "§Scope relocates CORRECTED, AUDIT.md:226 records it stale" was inherited from a census error (the line is blank; the relocation is verbatim and verified current). Fold: retracted in place — the prose-asserts-closed-breach class our own round doctrine names.
- **MAJOR (doc): version archaeology I introduced myself** — "6.0.0" narration in ~10 runtime-prose sites incl. the front door's always-loaded description (CLAUDE.md bans time-sensitive info there). Fold: de-archaeology sweep — runtime surfaces carry the functional statement only; versions live in CHANGELOG/spec/upgrade guide. **MAJORS (doc): routing violations** (bare cross-skill `modules-schema.md` cite; `tooling-install.md` left with no first-level route — now routed from install-deps), a dead `§Auto-invocation matrix` anchor, the checkpoint-protocol resume section teaching a per-skill typed form, and a phantom `/mega-sdd:audit-rules` stamp (a form that NEVER existed) in every generated gap report — all folded.
- **Dispositioned, not changed:** (a) ~25 validator `next_action` strings now carry bare skill names — model-facing, and bare names route (the two USER-facing hook denies + the CI-recipe prompt were made concrete instead); (b) `tests/integration/` + `tests/skill-triggering/` narrative fixtures keep typed forms — they remain semantically valid because typed legacy text still routes, per the using-mega-sdd rule; (c) NFR rows sourced from 06-constraints render under the template's "Other Constitution Constraints" heading with an honest `_Dari 06-constraints_` label — heading text is template-frozen; (d) repo-only citations (audits/, spec names) in relocated refs stay as provenance.
- **Held attacks (both lanes, verified clean):** relocation fidelity for all 24 files clause-by-clause (zero operative loss; only `## References` link lists dropped), hooks.json byte-identical, anti-self-bypass blocked all three forgery routes live, recompute-at-gate overwrote a planted forged state, deny truncation pointer survives JSON encoding and names a living surface, all 12 changed skill frontmatters valid + keyword-complete + version-bumped, 71+ relative links resolve, repo fixtures' derive outputs byte-identical.

**P4 lessons:** (1) a template a fallback reuses is part of the fallback's blast radius — grep the TEMPLATE for hardcoded source paths before re-pointing a builder; (2) a proof test written by the author inherits the author's blind spots — the round must attack the test's assertions, not just the code; (3) when you widen a dead parser branch, everything downstream of the field it populates is new behavior — enumerate the field's consumers before shipping the widening; (4) migration prose that QUOTES a dead form verbatim will trip your own phantom sweep — teach with placeholders.

### P3 round (2026-08-04, dual-blind)

Two blind agents (code lane live-fixture attacks on the router + Stop-hook matrix; doc/contract lane). **3 blockers + majors, ALL folded:**

- **BLOCKER (code): security-shaped units landed `minimal`** — case-sensitive fnmatch (`**/auth*` never matched `Auth/LoginController.php`) + derived words (`authentication` ⊄ `auth`); the deleted `no operation: create` clause had been the backstop for exactly these units. Fold: case-folded globs + basename/segment legs, derived-form stems, plural suffixes; 8 negative-recall fixtures pin the class.
- **BLOCKER (doc): the Stop-hook rewrite landed with its own parity test red** (`test-e-lean-profile.sh` pinned "hostile spelling ≠ lean" = aggregate fires; new semantics = opt-in) — caught pre-push. Fold: the test now proves the OPT-IN matrix (absent/leanish → skip; full/classic → fire; lean always wins).
- **MAJORs folded:** vocab list drift from the doc it implements (sandi/autentikasi missing — the S7-TIER-5 motivating sentence regressed to minimal); zero-target-files/BOM/inline-flow parse-misses treated as "small" (now `standard` + `parse_note`, unknown ≠ low); `defer_to: stakeholder` unrecordable via the prescribed event-only mechanics (patch lane now mandated); the paused-status trap (one pin: express auto-defers end `completed`); 4 operative references contradicting the SKILL body (the P2 standing-round class AGAIN — auto-memory-handoff --auto table, interactive-walk §Defer invariant clause + Esc atomicity, chain-execution phase note, project-config default); composite-id false positive (C-B-001); execute-bolts version bump.
- **Held:** resurface loop closure (deferred OQs re-enter the standalone walk), oq_gate arithmetic untouched, handoff validator tolerant of the id-list metrics shape, CI discovery, batching cap claims, blind-dispatch rails.

**Lesson (3rd occurrence → the round rule is now: grep the touched skills' FULL references/ trees for the changed concept BEFORE the round, and run every EXECUTING test that names the edited file):** fix-in-body-not-operative-reference recurred despite the P2 rule; the parity-test breakage shows edited hooks need their executing tests run pre-round, not post.

### P2 round (2026-08-03, dual-blind, deep)

Two blind general-purpose agents (code lane, live mktemp experiments; doc/contract lane). **3 SHIP-BLOCKERS + 13 MAJORs; ALL folded pre-ship:**

- **BLOCKER (code, REPRODUCED end-to-end): GROUND destroyed its own sync baseline.** `ground.sh` rebuilt the symbol index at Lane 0 — re-stamping `head_commit` to HEAD BEFORE `derive-changed-paths.sh` consumed the old stamp as its diff baseline — so the flagship express-born sync derived an EMPTY changed set and reconciled nothing (false "in sync"). Fold: GROUND defers the rebuild while `derived.position == maintenance_sync` (bind E0 rebuilds after the re-verdict — the correct stamp-advance point) + the producer prefers the probe-time stamp from state.json.
- **BLOCKER (code, REPRODUCED): substring markers misrouted mainstream repos into the Hard-rule surface.** `"next" ⊂ "i18next"/"next-themes"` routed React/Vite AND Laravel repos onto Next.js conventions, propagating through the resolver into every downstream validator. Fold: word-boundary matching for bare single-word markers (structured markers keep substring); both directions pinned.
- **BLOCKER (doc): the express-born changed-set producer silently narrowed the changed set** vs the scan `--changed-only` contract it claimed parity with — no working-tree leg, no consumed-file re-union, re-entry clobbered the durable set narrower. Fold: porcelain leg + consumed re-union + union-with-existing + rotate-only-after-successful-write (a failed write no longer consumes the journal — also a code-lane MAJOR, REPRODUCED with an unwritable vault).
- **MAJORs folded:** the session-start index-staleness leg was DEAD CODE behind a map-only outer gate (REPRODUCED — the exact silence it claimed to fix); classic-parity breach + Mode D livelock (fresh map + briefly-stale index triggered sync forever → the substrate rule: the index leg counts only when it is the ONLY substrate, and index-only Mode D is express-spine territory); express dead-end on ast-grep-less machines (the Windows floor) → unviable-express renders CLASSIC loudly; quotepath (unicode paths entered the set C-quoted — the repo's own documented lesson); operative references un-swept while SKILL bodies were fixed (chain-execution Mode A/B table, the session-injected anchor skill, oq-resolution's deferred-OQ leg, defensive-generation's Step 0.5 matrix — the P1 round's mirror class, again); spec↔impl drift (resolver source order); the script hop's rc-3 routing undocumented; version bumps missing; tool-config-only pyproject resolving `_universal`; spring-on-gradle undisclosed; predictive carve-out flag-only vs flag-or-spine.
- **Held:** the moat surfaces (CONFLICT gate, B1–B4, verdict grammar) untouched by the tranche; preflight vault arm FATAL on both lanes; single-site injection; carve-out precedence symmetric (`--express` beats classic config, `--no-express` beats express config); packres-v2 busting; greenfield chains never gain `--express`; CI discovery of the new suite.

**Lesson recorded (2nd occurrence — now a standing round rule):** fix-lands-in-the-SKILL-body-but-not-the-operative-reference is a recurring fold class; every tranche touching a skill MUST grep its full `references/` tree for the demoted concept before the round, not after.

### P1 round (2026-08-03, dual-blind, deep — moat-touching)

Two blind general-purpose agents (code lane with live mktemp experiments; doc/contract lane), run in parallel read-only over the pre-round commits. **1 SHIP-BLOCKER + 8 MAJORs found; ALL folded pre-ship** (fold commit follows the pre-round commit):

- **SHIP-BLOCKER (doc lane): the ledger silently narrowed the claim universe.** Template-conformant vaults carry ZERO `## §` headings (components live in named-H2 sections, constraints in prose bullets) — express would have bound only the deterministic subset, and a "Must use Laravel 11"-vs-Express.js contradiction would get NO verdict, invisible to the gate. Fold: the ledger is a SKELETON — express runs a mandatory model completeness sweep over the (small) vault docs with the binding-contract claim-categories table as its checklist, appending missed claims; per-category coverage or an explicit empty note is required. The narrowing was exactly the cut-verification sin the mandate forbids.
- **MAJOR (code): collision sweep overclaimed "global by construction"** — the index covers only tracked files with covered extensions; once rung 2 confirmed the expected home, a collision in untracked/`.vue`/template surfaces was never sought (a concrete false-CONFIRMED path). Fold: two mandatory legs — index query AND bounded repo Grep; the universe disclosure corrected.
- **MAJOR (code): mode claim harvested from the first matching line anywhere in 00-index** (a prose decoy line beat the Vault Lock). Fold: section-scoped scan; decoy arm pinned.
- **MAJOR (code): grammar-marginal DBML silently dropped entities** (non-ASCII table names; one-line `Table x { … }` desyncing the depth tracker for every LATER table) — and the cross-count guard was blind because the shared lib shares the same misses (exact equality catches forks, never shared misses). Fold: both shapes fail LOUD (exit 2) with line-numbered messages.
- **MAJOR (code): determinism break** — the ledger embedded the raw `--vault` argument (abs vs rel invocation → byte-different artifacts + machine-path leak). Fold: the `vault` field records the slug; abs/rel/trailing-slash arm pinned.
- **MAJOR (doc): predictive-checks `binding_input_complete` (fatal) would falsely halt a mapless express chain.** Fold: express carve-out — vault.json arm stays fatal, map arm skipped under `--express`.
- **MAJOR (doc): replacing Step 1 dropped scope_metadata propagation + the KB scorecard preflight.** Fold: E2.3 restores both explicitly.
- **MAJOR (doc): `--paths` + `--express` composition underspecified** — the prior binding.md read looked forbidden ("ledger only"), and prior-binding ids vs ledger ids are different id spaces (mixed-id State Map / double-count risk). Fold: prior binding = sanctioned read; match by `source` then verbatim text; unmatchable affected claim ⇒ full re-bind.
- **MAJOR (doc): provenance precedence pointed the wrong way** — auto-memory-handoff (the per-skill operative reference, which WINS by the precedence rule) would let a compliant model stamp `snapshot-verified` on an express bind. Fold: the express override lives in auto-memory-handoff itself.
- MINORs folded in the same pass: field-diff read-evidence variant in binding-contract; `regex_tier` never minted in express (no tier signal exists); unknown-rc-≠-pass catch-alls on E0/E1; exit-2 keterangan no longer misdiagnoses template-conformant/greenfield vaults; guard message no longer blames the script for vault defects; paths.md gitignore/multi-dev rows; sibling-ref link form; anchor-attribute syntax + dev-archaeology phrasing removed; spec↔impl drift corrected (mode source, § scope, slug field, no-patch-lane wording).
- **Held attacks worth recording:** the CONFLICT gate, binding grammar, and fail-closed exits held everything both lanes threw (live: moat gate fired on the express-shaped CONFLICT fixture; make-bound refused; corrupt-index rc 3; duplicate-id exit 2; CRLF/unicode-text/105-claim arms clean). Forged-ledger laundering is neutralized by E1's unconditional re-derive (doctrine: no new hook surface for a promptable rail). Zero-claims semantics converge with the standard lane's greenfield path.

Lesson recorded for P2: "parity with an equally-blind validator" is a vacuous coverage proof — parity means SHARED misses pass both. Coverage claims need a positive obligation (the completeness sweep + category checklist), not equivalence to another scanner.

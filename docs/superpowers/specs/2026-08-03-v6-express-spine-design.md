# v6 — the Express Spine: speed with hard gates

**Date:** 2026-08-03
**Status:** P1 SHIPPED v5.34.0 (96923c0) · P2 SHIPPED v5.35.0 (68273bd + 96ab87b, CI green, suite 200) — THE EXPRESS SPINE IS THE DEFAULT; P3–P5 awaiting per-phase gas
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
| Vault as 7 human docs mid-path | **Replaced by the claims ledger** (one terse file). Vault docs = emission. | Downstream consumes claims+anchors, not architecture prose + mermaid. |
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
- **P3 — OQ auto-defer + risk-tier default + lean-by-default diagnostics.**
- **P4 — surface cull** (alias removal per policy + docs-on-demand completion + README/major migration guide).
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

## Round disclosure

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

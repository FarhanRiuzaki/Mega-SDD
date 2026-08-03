# v6 — the Express Spine: speed with hard gates

**Date:** 2026-08-03
**Status:** DESIGN — research-grounded, awaiting per-phase gas
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

- **P1 — claims ledger + claim-scoped bind (D3 core).** The biggest and riskiest; touches the binding moat, so the round is mandatory and deep. Deliverable: bind works from ledger+index with zero map load.
- **P2 — GROUND step + express default.** scan demoted; map derive-on-demand; front door defaults to the spine.
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

## Round disclosure

*(per phase, filled AFTER each round runs — never pre-written)*

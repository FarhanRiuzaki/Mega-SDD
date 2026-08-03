# v6 — the Express Spine: speed with hard gates

**Date:** 2026-08-03
**Status:** DESIGN — awaiting per-phase gas
**Mandate (operator, 2026-08-03, verbatim goals):** "tujuan utamanya skills ini itu standarisasi code, reuse code, percepatan development, dan anti fabricated. yang paling utama itu speed development dengan standar yg udah di set atau hard gate." — a MAJOR update; cut everything that does not serve these four. **Speed is the tie-breaker; the hard gates are non-negotiable.**

**Field evidence driving this:** on `training-nextjs`, scan alone cost ~25 minutes + 3.1M cost-equiv tokens before a single line of code; the full PRD→code path fronts 1–2 hours of ceremony. Plain Claude Code starts delivering in minutes with comparable output for small/mid features. v6's honest answer: *match that start speed, keep the proof.*

## North star

> **PRD in → proven code out, in minutes.** Everything on the default path must serve standarisasi / reuse / speed / anti-fabrication. Everything else becomes ON-DEMAND or is deleted.

Target (measured, not aspirational — P5 measures it on training-nextjs): **PRD → first delivered bolt < 10 minutes** on a mid-size brownfield repo, with all gates live.

## The v6 default pipeline (the spine)

```
/mega-sdd <prd>
  1. GROUND   (script, seconds)  manifest sniff → framework pack resolve;
                                 build-symbol-index.sh (full-repo, deterministic).
                                 NO full codebase-map, NO deep-scan, NO model tokens.
  2. CLAIMS   (model, terse)     extract claims from the PRD into ONE terse
                                 AI-plane ledger (id | claim | type | target
                                 surface) — never a 7-doc human vault.
  3. BIND     (claim-scoped)     per claim: query the symbol index + targeted
                                 file reads → CONFIRMED/CONFLICT/OQ + anchors.
                                 The CONFLICT gate BLOCKS, unchanged (this is D3,
                                 finally as the default — not map-load binding).
  4. UNITS                       PR-sized contracts: acceptance criteria + Hard
                                 rules from the framework pack (standarisasi) +
                                 the reuse slice injected (symbol_slice).
  5. BOLTS                       implement → acceptance test → B1–B4 gates →
                                 review (risk-tiered: low = 1 lens, high = panel).
```

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

## Phasing (each phase = spec section → implement → tests → dual-blind round → ship)

- **P1 — claims ledger + claim-scoped bind (D3 core).** The biggest and riskiest; touches the binding moat, so the round is mandatory and deep. Deliverable: bind works from ledger+index with zero map load.
- **P2 — GROUND step + express default.** scan demoted; map derive-on-demand; front door defaults to the spine.
- **P3 — OQ auto-defer + risk-tier default + lean-by-default diagnostics.**
- **P4 — surface cull** (alias removal per policy + docs-on-demand completion + README/major migration guide).
- **P5 — measure.** End-to-end wall-clock + cost-weighted tokens on training-nextjs, before/after, published in the README. The <10-minute claim lives or dies here.

Version: **6.0.0** at P4 (the breaking-surface release); P1–P3 ship as 5.x pre-major tranches where back-compatible, behind `--express` until P2 flips the default.

## Non-goals

- No weakening of any gate (mandate: "standar yg udah di set atau hard gate").
- No rebuild of what native Claude Code covers (agentic search/LSP stay native).
- The doc pack (PRD/FSD/SIT/UAT emissions incl. SEOJK UAT) is NOT cut — it moves fully to on-demand, same quality bar.

## Round disclosure

*(per phase, filled AFTER each round runs — never pre-written)*

# v5 execution spec — P0→P10 (v4.92.0 → v5.4.0)

**Date:** 2026-07-19 · **Research basis:** [`research/2026-07-19-v5-architecture-research.md`](../../../research/2026-07-19-v5-architecture-research.md) (6 angles + auditor, verdict PROCEED) · **User mandates (locked):** 3 human docs PRD/FSD/SIT as dynamic emissions; OQ/analysis stays in-skill; start-anywhere; generated-code accuracy WAJIB (pas, expert-dev, zero over-engineering) as mechanism; frozen: 5 invariants, blind panel, gate grammars, keterangan, Mermaid; no format migration.

## The 10 decisions — resolved

1. **Verb mechanics:** colon-commands stay (`/mega-sdd`, `/mega-sdd:sync`, `/mega-sdd:emit`) — no `$ARGUMENTS` subverb parsing risk. Maintenance one-timers (migrate-paths, install-deps, update-plugin, memory) remain typed commands outside the pipeline surface, tier-2 description diet, auto-PROPOSED by the front door when state demands them.
2. **Alias lifetime:** all 24 deprecated commands resolve for the whole 5.x cycle; removal decided at P10 from measured telemetry, never assumption. `plugins/mega-sdd/CLAUDE.md` amended: *pipeline commands may be demoted to aliases in a major; removed only in the following major after telemetry review.*
3. **Binding RECERTIFY trigger:** `changed-paths(head..HEAD) ∩ claim-anchor-paths` intersection. Non-empty → FAIL (moat blocks, keterangan). HEAD mismatch + empty intersection → WARN. Legacy binding without `head` → WARN (v4 never REJECTED). Shipped in P0.
4. **Language ownership after terse:** emitters own the Indonesian narrative end-to-end. Terse AI-plane notation is quoted verbatim in code spans with an Indonesian gloss — never translated in place (output-language Tier-1 discipline extended). Verbatim-extraction survives only where markers ride ([VERIFIED]/[INFERRED]/[OPEN] into reverse-PRD).
5. **SIT sign-off (vetoable — bank-team call):** P5 ships paper-out placeholder-literal rows (slot-grammar-enforced; model-filled sign-off = fabricated record = blocked). The attested `uat-results.yaml` round-trip (B1 `--attest` pattern) is a P10 candidate behind field demand.
6. **Doc placement:** `<vault>/{prd,fsd,sit}/` siblings — zero migration (emit-fsd already writes `<vault>/fsd/`). `docs/` consolidation rejected: migration cost, zero function.
7. **DEMOTE under --auto (vetoable):** always a C2 halt with keterangan — never unconfirmed (it burns generate-intent tokens and replaces the user's artifact with a different vault). One AskUserQuestion, then proceed.
8. **derive-state vs validate-preflight:** both survive on ONE shared probe library (`_lib/state_probes.py`): derive-state.sh renders the routing digest; validate-preflight keeps the FATAL role. Structural fix for probe re-divergence.
9. **Flake/blocking policy (uniform across B2/B4/L0):** one bounded auto-retry, then halt. SIT count parsing: detect-never-impose — parse common runner outputs; unknown runners record raw output as evidence without fabricated counts.
10. **Multi-scope SIT:** one merged SIT, per-scope sections; sign-off table per scope; ids carry the scope (`TS-BE-001`).

## Phase plan (each = one green commit, both trees; marketplace == plugin always)

| Phase | Ver | Ships | Guard |
|---|---|---|---|
| P0 | 4.92.0 | binding RECERTIFY at gate (§decision 3), has_vault probe unification, external-map provenance WARN at bind (`codebase_map_provenance: unverified-external`), exit-2 rewording for external authors | fixtures lack `head` → WARN lane keeps every existing test green; blackbox stays green |
| P1 | 4.93.0 | `_lib/state_probes.py` + `derive-state.sh` → `state.json`; routing-rules becomes a decision table over the digest; --resume/session-start/auto consume it | parity test: script digest == prose-probe outcomes on all routing fixtures |
| P2 | 4.94.0 | adoption verdict vocabulary (CERTIFIED / CERTIFIED_DEGRADED / DEMOTE / REJECTED + keterangan) mapped onto existing validators; input sniffer; foreign-SDD globs (`.specify`, `.kiro/specs`, OpenSpec); DEMOTE lanes | fixture set: every v4-authored artifact must certify (REJECTED forbidden) |
| P3 | 4.95.0 | emit-core factor-out of emit-fsd's 8-step spine; citation-map/drift/slot scripts gain `--doc` | FSD byte-parity fixture — output byte-identical before/after |
| P4 | 4.96.0 | B4 `run-acceptance-tests.sh` + `acceptance.json` (hook-guarded evidence), L0 syntax floor rung, anchor-freshness preflight | commit-keyed: legacy bolts never retro-block |
| P5 | 4.97.0 | emit-sit (TS-NNN ← F-NNN, traceability matrix, script evidence, sign-off slots), emit-prd (reverse, marker-preserving), doc-control maturity block + `refresh-doc-stamps.sh` | slot-grammar blocks model-filled sign-off; [Pending] discipline |
| **P6** | **5.0.0** | front door + 3 verbs + 24 aliases, anchor rewrite, description diet, UserPromptExpansion matcher extension, CLAUDE.md amendment | matcher change SAME commit; 18 trigger tests + anchor-diet retuned |
| P7 | 5.1.x | **REORDERED by measurement (`research/2026-07-19-p7-seed-budget-baseline.md`, advisor counsel: cost-units not bytes).** 5.1.0 seeding-budget lib (instrument first). 5.1.1 advisor evidence-bundle (`build-advisor-bundle.sh` — the FRESH-1.0x whole-map paste is the top real-dollar lever). 5.1.2 kb-claims. 5.1.x bind-map = **grep-on-demand** (the precomputed bind-slice is DROPPED — recall-completeness unprovable). 5.1.x-last/deferred bound/ retirement (refusal re-homed FIRST). oq-queue CHECKED OFF (`all-priorities` already collapsed it). | legacy bound/ dirs inert-OK; **bundle = seed never boundary, enforced by the seed-not-boundary CONFLICT test** (contradiction outside the bundle still lands CONFLICT); advisor keeps Read/Grep to expand past the seed |
| P8 | 5.2.0 | terse vault/unit/binding templates, emitter narrative-synthesis switch, output-language amendment | pin audits per template BEFORE cuts; A/B token measurement HERE |
| P9 | 5.3.0 | reuse gate (`reuse_decisions:` + base..head scan + justified-reimplement escape), dep-authorization (`allowed_new_deps`), consensus escalation | advisory-first, blocking after field soak; WARN for pre-v5 units |
| P10 | 5.4.0 | FSD §9 slim + SIT pointer, first-party cost-weighted telemetry table, alias-cull decision from telemetry, optional uat-results.yaml | telemetry decides, not assumption |

## Migration guarantees (binding)

v4 artifacts readable forever; adoption may never REJECT a v4 shape (CERTIFIED_DEGRADED floor via the upgrade-guide conservative-default matrix). New blocking gates commit-keyed (B1 read-obligation precedent). Terse applies to NEW emissions only; consumers read both shapes. MSmile first v5 contact = derive-state + sync, never re-emission; fork-AB plugin cache re-pinned per phase. The 5.0.0 breaking change is the command-surface contract ONLY.

## Sequencing discipline (auditor's three hard edges)

1. Emitter narrative-synthesis (P3/P5) must exist BEFORE the verbose vault prose it replaces is cut (P8).
2. B4 acceptance evidence (P4) before emit-sit (P5) — SIT's executed column reads `acceptance.json`.
3. make-bound refusal re-homed before bound/ retirement (P7); front-door matcher extension lands in the SAME commit as the verb collapse (P6).

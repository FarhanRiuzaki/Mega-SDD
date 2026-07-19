# v5 architecture research — start-anywhere, 3 human docs, terse AI plane, the WAJIB accuracy bar

**Date:** 2026-07-19 · **Trigger:** v5 major-update direction (user): skill mocked as token-hungry; newcomers face cognitive load starting from intent; team should read only final docs (PRD/FSD/SIT); "akurasi code itu WAJIB — pas, expert dev, no over-engineering"; OQ/analysis stays in-skill. · **Method:** 6 research angles (5 internal, file:line-verified at v4.91.0 + 1 external competitive scan) + architecture auditor (workflow `wf_4602d8d2-db3`; full angle outputs in its journal).

**Auditor verdict: PROCEED TO SPEC.** The striking result: v5 is mostly **consolidation, not invention** — the state engine unifies four verified-divergent probe surfaces into one script; adoption gates are ~80% verdict-remapping on existing validators; the emission engine, citation stamping, recompute-at-gate, and keterangan contracts all exist and generalize. The two genuinely new surfaces (SIT with script-derived executed evidence; the adoption vocabulary) have **no competitor equivalent** (Angle 6: spec-kit, Kiro, OpenSpec, BMAD scanned).

---

## 1. HOT: a live moat hole found during research (fix in P0, before any v5 work)

`validate-handoff-binding-units.sh` (the 506-line moat validator that opens the execute-bolts gate) parses binding.md CONFLICT-heading **structure only** — zero git provenance/freshness checks (grep-verified: no `rev-parse`, no `binding_metadata` read). A hand-authored or stale binding.md with no active CONFLICT headings yields PASS and **opens the moat**. Freshness exists only as prose (bind Step 1) and an advisory session-start notice — neither runs at the gate. Fix: a deterministic RECERTIFY check at the gate (binding_metadata.head vs HEAD, with the trigger semantics = open decision #3). Ships as **P0 / v4.92.0** together with three smaller verified divergences: `has_vault()` probe unification (a 7-file vault without vault.json is invisible to orchestrate-flow yet passes preflight), external-map FM WARN surfacing at bind time, and exit-2 rewording for externally-authored artifacts.

## 2. Token truth (measured, field scale — MSmile audit)

- 100.7M raw intent→units ≈ **21.1M cost-units ≈ $317**; cache_read is 91.9% of raw @0.1x — raw overstates real cost **4.76x**.
- The real drivers: **standing-context residency** (16.5K→325K monotonic over ~250 turns) and **subagent seeding** (12 subagents = 50.3M of 100.7M; three OQ passes alone 15.6M). Reference re-loads are a red herring (0.16%).
- Always-on surface: ~19.5KB (command listing 10,680B + skill descriptions 8,796B) + 3,212B anchor per startup.
- **v5 net estimate: 2–4M cost-units saved per field-scale run (~10–20%) + always-on cut ~3.5K tokens/session.** The dominant levers are slice-first (P7) + terse plane (P8); the 3-doc emitters are roughly **cost-neutral** (evidence tables script-derived ≈ 0 output tokens by construction). Honesty: baseline decomposition + byte counts are measured; every savings figure is an estimate to be A/B-measured at P8.

## 3. Entry matrix + adoption gates (start-anywhere)

Verified asymmetry at v4.91.0: **input artifacts are rejected without an adoption story** (external codebase-map fails writer-provenance frontmatter with no certify lane; foreign SDD artifacts — spec-kit `.specify`, Kiro `.kiro/specs`, OpenSpec — have zero recognition; non-.md/.pdf/.docx PRDs dead-end) while **mid-pipeline trust artifacts are over-trusted** (the §1 binding hole; foreign KB freshness unchecked). v5 inverts neither: **certify inputs** (verdict vocabulary CERTIFIED / CERTIFIED_DEGRADED / DEMOTE-to-lower-rung / REJECTED, every verdict with keterangan; input sniffer; DEMOTE lane offers e.g. foreign-vault → PRD-rung re-ingest) and **recertify trust artifacts** deterministically. Rule: a v4-authored artifact may never be REJECTED (migration guarantee). State engine: `derive-state.sh` → `state.json` — the 10-probe routing inspection becomes ONE script consumed by front door, --resume, session-start, and (via shared lib) validate-preflight, so probe sets can never re-diverge (open decision #8 on preflight's FATAL role).

## 4. The 3 human docs (PRD / FSD / SIT)

- **emit-core**: factor emit-fsd's proven 8-step spine (mode detect → drift-check script → per-section loop with [Pending] discipline → slot scan → script citation-stamping → render) into a shared engine; FSD **byte-parity fixture pins current output before any generalization** (invariant-3 guard).
- **emit-prd** (missing today): reverse-capable from KB/map/vault; **[VERIFIED]/[INFERRED]/[OPEN] markers carried verbatim** into the PRD (marker-preservation as an extraction rule — no fabrication); user journeys emit Mermaid.
- **emit-sit** (new): 5 sections — scope, **TS-NNN test scenarios derived 1:1 from F-*-NNN flows** (Mermaid embedded verbatim + DoD), test-case matrix from `acceptance_test[]`, executed evidence from bolt-report/postflight.json/B2 batch-suite (script-derived, unfakeable), bank-style sign-off. **Sign-off body rows are enforced placeholder-literal by the slot-grammar check — a model-filled sign-off row is a fabricated record**, the worst possible failure in a bank context.
- **Maturity + freshness**: script-owned doc-control block (parser-invisible, stamp-binding precedent) with maturity ladders (PRD draft-from-legacy→reviewed→final; FSD pre→post; SIT planned→partial→executed); `refresh-doc-stamps.sh` refreshes state stamps at phase boundaries for ~0 tokens; full re-emission on demand.
- Per user mandate: docs are **outputs, not decision surfaces** — OQ/analysis stays in-skill; resolutions flow into the next emission.

## 5. Surface collapse (the 5.0.0 breaking change)

27 commands → **3 public verbs**: `/mega-sdd` (state-engine front door; status folds in; adoption dispatch), `/mega-sdd:sync`, `/mega-sdd:emit prd|fsd|sit`. 24 deprecation aliases keep filenames resolving for one major cycle (~45-byte descriptions); internal skills get a two-tier description diet; the anchor's natural-language lanes compress to one rule ("any SDD phrase → front door"). **The breaking change of 5.0.0 is the command-surface contract — NOT artifact shapes; every v4 artifact stays readable forever.** REWORK (moat): the front-door verb must join the UserPromptExpansion gate matcher in the same commit; every gated phase stays Skill-dispatched, never Agent-offloaded.

## 6. Slice-first + terse AI plane (the token thesis)

Wholesale loads remaining and their script-digest replacements: **retire `bound/`** (generate-units consumes vault docs once + binding.json slices; make-bound's CONFLICT refusal re-homes BEFORE retirement), **bind-slice** (per-claim candidate-evidence digest replaces in-context codebase-map), **advisor evidence-bundles** (verdict set + sha-stamped anchor excerpts + symbol index instead of whole-corpus re-read; bundle = seed, never boundary), **oq-queue** (single-pass OQ landing — three passes cost 15.6M at field scale), **kb-claims** digest, and the **reading-manifest pattern** (each consumer gets a script-generated manifest naming exactly what it may load). Terse plane: trims ride behind per-template pin audits + the P8 A/B measurement; every gate-parsed grammar (OQ lines, D-/F- headings, Mermaid bodies, DoD, Stages, Vault Lock, Anchors/Hard-rules/Migration-notes) survives untouched.

## 7. The WAJIB accuracy bar → mechanisms (Angle 5)

Today's gaps vs "akurasi WAJIB, pas, expert dev": over-engineering findings are advisory; nothing verifies compile/syntax beyond acceptance_test; reuse is prompt-time only; the accuracy loop doesn't close into evidence. v5 mechanisms (all deterministic, commit-keyed so legacy bolts never retro-block):

- **B4 — `run-acceptance-tests.sh` + `acceptance.json`**: re-executes each `acceptance_test[]` after the bolt commit; evidence artifact hook-guarded like postflight; SIT's executed-evidence column reads it.
- **L0 syntax floor**: zero-config `php -l`/`py_compile`/`node --check`/`ruby -c` over changed files.
- **Reuse gate**: machine-parseable `reuse_decisions:` YAML in bolt-report + all-category base..head scan; `reuse_unjustified` halt with a justified-reimplement escape.
- **Dep-authorization** (anti-over-engineering): optional `allowed_new_deps: []` in unit schema; B3-style manifest diff per commit; unlisted new dependency → `dep_unauthorized` (degrades to WARN when the key is absent — v4 units).
- **Anchor-freshness preflight** — stale anchors caught before dispatch, not after.
- All new halts join the existing taxonomy with Indonesian keterangan.

## 8. Competitive scan (Angle 6, primary sources)

spec-kit/Kiro/OpenSpec/BMAD: none emit a script-derived SIT/test-evidence doc; none have an adoption-verdict vocabulary; start-anywhere is folder-convention-based (no certification). Worth stealing: OpenSpec's "converge"-shaped certifier framing for adoption; token-budget's reading-manifest `/scope` pattern for slice-first. Worth publishing: **first-party per-run cost-weighted telemetry** stamped into the chain-end summary (answers the mockery with numbers no competitor publishes).

## 9. Phasing (auditor) — each phase one green commit, risk-ascending

| Phase | Ver | Ships |
|---|---|---|
| P0 moat pre-work | 4.92.0 | binding RECERTIFY at gate (§1), probe unification, map-FM WARN, exit-2 rewording |
| P1 state engine | 4.93.0 | derive-state.sh + state.json; routing consumes the digest |
| P2 adoption gates | 4.94.0 | verdict vocabulary + keterangan, input sniffer, foreign-SDD globs, DEMOTE lanes |
| P3 emission engine | 4.95.0 | emit-core factor-out; FSD byte-parity is the gate |
| P4 accuracy floor | 4.96.0 | B4 acceptance evidence, L0 syntax rung, anchor-freshness |
| P5 the 3 docs | 4.97.0 | emit-sit, emit-prd (reverse, marker-preserving), maturity stamps |
| **P6 surface collapse** | **5.0.0** | front door + 3 verbs + 24 aliases + anchor rewrite + matcher extension |
| P7 slice-first | 5.1.0 | bound/ retirement, bind-slice, advisor bundles, oq-queue |
| P8 terse plane | 5.2.0 | terse templates + A/B token measurement |
| P9 enforcement ceiling | 5.3.0 | reuse gate, dep-authorization (advisory-first, blocking after soak) |
| P10 closeout | 5.4.0 | FSD §9 slim + SIT pointer, telemetry table, alias-cull by measured usage |

Migration guarantees: v4 shapes never REJECTED; aliases live one major cycle; new gates commit-keyed; MSmile first contact = derive-state + sync (never re-emission); fork-AB cache re-pinned per phase.

## 10. The 10 open decisions for the spec

1. Front-door verb mechanics ($ARGUMENTS subverbs vs colon-commands) + where maintenance one-timers land. 2. Alias lifetime + the CLAUDE.md "never delete a pipeline command" amendment. 3. Binding RECERTIFY trigger: raw HEAD mismatch vs changed-paths∩claim-anchors; PASS-or-WARN on empty intersection. 4. Human-language ownership after terse (emitters own Indonesian narrative end-to-end; quoted-source rule on terse notation). 5. SIT sign-off round-trip: paper-only vs attested `uat-results.yaml` (B1 --attest pattern). 6. Doc placement: `<vault>/{prd,fsd,sit}/` sibling vs `<vault>/docs/`. 7. DEMOTE under --auto: ever unconfirmed, or always C2 halt. 8. derive-state vs validate-preflight duality. 9. One flake/blocking policy across B2/B4/L0. 10. Multi-scope SIT: per-scope vs merged.

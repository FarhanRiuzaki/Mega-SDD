# P7 seed-budget baseline — the measured ranking that orders slice-first

**Date:** 2026-07-19 · **Ships in:** v5.1.0 (P7 instrument) · **Instrument:** `scripts/_lib/seeding_budget.py` (counter/enforcer) + `scripts/measure-seeds.sh` (per-consumer enumerator + ranker) · **Basis:** advisor counsel — *measure first, let bytes rank the work; every subsequent cut carries a before/after from the same tool.*

## Why this exists

The v5 research estimated the slice-first savings but flagged every figure as "an estimate to be A/B-measured." This is that ruler. It answers the "boros token" mockery in bytes no competitor publishes, and — more importantly — it **orders** the P7 work by measured seed size instead of by the spec's listing order. It is a counter, never a framework (WAJIB "pas"): no tokenizer dependency, no network, deterministic. Token figures are `ceil(bytes/4)` — a ranking/budget rule-of-thumb, NOT a billing number (real cost is cache-weighted cost-units per the v5 research).

## The baseline (measured, v5.0.0)

Ranked by bytes, on the blackbox pipeline vault (real codebase-map from the fixture's PHP signatures + the laravel framework pack):

| consumer | bytes | ~tokens | share | note |
|---|---|---|---|---|
| **bind-codebase** | 41,138 | 10,285 | **56.9%** | vault + codebase-map + framework-pack (+KB when present) |
| **phase-advisor** | 12,495 | 3,124 | 17.3% | checklist + draft binding + map + vault (+KB) |
| generate-units | 10,779 | 2,695 | 14.9% | bound/ (annotated 7-doc copy) + binding.md + binding.json |
| resolve-oq | 7,928 | 1,982 | 11.0% | the vault (re-read per pass unless `all-priorities`) |

Reproduce: `bash plugins/mega-sdd/scripts/measure-seeds.sh --vault <vault> --pack <matched-pack.md>` (also emitted live as blackbox stage **S12.7**, so CI re-measures every run). `--json` gives the telemetry record (P10 cost-weighted table substrate).

**Honest omissions** (counted as 0, surfaced, never invented): the KB when absent; the domain-extractor's per-wave legacy source slice and any live subagent draft (vary per run). At **field scale** the codebase-map dwarfs the pack (v5 research MSmile: subagent seeding = 50.3M of 100.7M cost-units; the map is seeded into BOTH bind and the advisor), so bind-codebase's real-world share is *higher* than 57%, not lower.

## What the instrument surfaced (that reordered the plan)

1. **bind-codebase is the dominant seed (≥57%), and its two biggest movable components are the whole codebase-map and the whole framework pack (13–33 KB, always loaded entire).** Both are seeded into the advisor too. → **bind-slice + advisor-bundle is P7 item #1** (the codebase-map/pack → per-claim candidate-evidence slices + sha-stamped bundles).
2. **generate-units' bound/ portion is a ~2× copy of the vault docs — low absolute bytes, and its derivation is already 0 model-tokens (script lane).** Its cost is architectural, not tokens, yet it is the only P7 item that touches the moat belt. → **bound/ retirement is LAST (or deferred)**, per the advisor.
3. **resolve-oq's multi-pass re-read is already collapsed** by `all-priorities` (one walk, P1→P2→P3; SKILL Step 0.6). The stakeholder walk is inherently interactive and cannot be collapsed further without breaking no-fabrication. → **oq-queue = verify-then-check-off, do NOT rebuild** (rebuilding is the over-engineering the WAJIB bar forbids).

## The cache-economics correction (why bytes were the wrong unit)

Ranking by **bytes** put bind-codebase #1. But bytes are the wrong unit: a FRESH
subagent seed is paid at full 1.0x, while a RESIDENT main-context load is cached
at ~0.1x after turn 1 (research §2: cache_read is 91.9% of raw at 0.1x; subagent
seeding is the largest real-dollar bucket, 50.3M of 100.7M). Re-ranked by
**cost-units = tokens × cache-weight** (instrument `--weight fresh|resident`):

| consumer | cache | cost-units | share | why |
|---|---|---|---|---|
| **phase-advisor** | fresh 1.0x | — | **top** | dispatched fresh; the whole-map paste was paid in full |
| bind-codebase | resident 0.1x | — | 2nd | map/pack cached after turn 1 |
| generate-units / resolve-oq | resident 0.1x | — | low | cached |

So the **phase-advisor seed is the top real-dollar lever AND the safe one** — the
advisor already has Read/Grep/Glob, so "seed not boundary" is mechanical, not a
pledge. That reordered P7: advisor-bundle first; the bind-map *precomputed* slice
is **dropped entirely** (its seed-not-boundary test can't distinguish slice-
regression from inherent bind limits — the tell that it is the wrong shape); the
safe bind-map lever is a *later* grep-on-demand commit (full map stays on disk,
nothing removed from searchable → moat safe by construction, measured on its own
cache profile).

## The measured P7 order (5.1.x, per-item commits)

- **5.1.0** — instrument + baseline (shipped).
- **5.1.1** — **advisor evidence-bundle** (`build-advisor-bundle.sh`): the dispatch
  passes a compact sha-stamped SEED (verdicts + anchors + map/vault/KB **paths**)
  instead of the whole-map paste; the advisor Greps the on-disk map past it. Ships
  the seed-not-boundary CONFLICT test + the instrument's cost-unit weighting. (shipped)
- **5.1.2** — kb-claims digest (the legacy-rebuild KB seed; fresh where it seeds subagents).
- **5.1.x (later)** — bind-map **grep-on-demand** (NOT a precomputed slice): bind
  Greps/Reads the on-disk map per claim instead of holding it whole in context;
  nothing removed from searchable, so no recall-completeness proof needed.
- **5.1.x (last / deferred)** — bound/ retirement (refusal re-homed as a standalone
  gate FIRST; state.json binding-clean signal must already carry "ready for units";
  generate-units task_type reconstructed from binding.json alone).
- oq-queue — checked off by measurement; no code.

## The phase invariant (binding on EVERY slice change)

This restates the user's original hard rule: *a more token-efficient artifact WITHOUT losing the sharpness of the gates.* Every slice/bundle is a **seed the consumer expands from — never a cap.** The failure mode is silent and it is a moat regression: a slice that hides the one piece of evidence which would flip a claim to CONFLICT yields a false CONFIRMED, and **no existing gate catches it** (the input changed, not the gate — binding.json comes out clean and every downstream gate correctly passes it).

Therefore every bind-slice/advisor-bundle/kb-claims commit MUST ship a **seed-not-boundary test**: a claim whose conflicting evidence sits *outside* the initial slice must still land CONFLICT. If it lands CONFIRMED, the slice broke the moat — that test, not the suite passing, is the gate for the change. bind-slice must fall back to the full map when a claim is unresolved by its slice; the advisor bundle must never be the advisor's horizon.

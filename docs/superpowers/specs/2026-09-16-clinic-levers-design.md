# Clinic levers after 8.0.0 — design spec (PROPOSAL, needs paid measurement runs)

**Status:** SPEC ONLY — nothing built. Source: `research/2026-09-15-v8-p3-report.md §2f` (rule-D dissection of the clean clinic lite 7.38.0 run) + `§5` (criterion (b) FAIL thin: mean implementer in-flight 2.38 of cap 4, idle-without-implementer 25 %, Critical 1 open). Owner rule (runbook §3-lanjutan D): *"kalau klinik masih <2,5 → bedah ulang dengan metode yang sama, TANPA lever baru di sesi itu"* → the dissection is done (§2f); the levers below are the next session's work and **every one is measured on xs (n ≥ 2) before the clinic is touched once**. No lever ships on prose alone (evidence-first rule).

## 1. What still serializes (MEASURED, §2f)

| # | Serializer | Evidence | Share of the residual |
|---|---|---|---|
| S1 | Controller top-up per **burst**, not per implementer return | 7 bursts 17–22 min apart; `derive-ready-units.sh` called 5× at burst edges; ready units waited U-005 15.9 m · U-008 16.0 m · U-012 17.6 m · U-013 **22.0 m** · U-016 15.5 m · U-019 21.2 m · U-014 8.2 m = **≈117 unit-min**; U-006 (no deps) dispatched at 39.5 m with a slot free since 25.7 m | = the 25 % idle |
| S2 | `plan` DAG depth 5 ≈ critical path ≈ bolt-stage | U-001→U-002→U-013→U-020→U-021: Σ impl 69.6 m + ≈10 m/hop review tail ≈ 120 m vs bolt-stage 129.7 m; hub units U-001/U-002/U-013; fat units U-008 74.9 m (2 fix rounds), U-016 28.9 m, U-015 27.9 m | with perfect top-up EST bolt-stage 100–108 m, in-flight EST ≈ 3.0 — the ceiling for THIS DAG; floor = 308.8 impl-min / 4 = 77 m |
| S3 | PRE-CODE 42m39s → 1h05m37s | `plan` 56 m: ±10 m reading validator SOURCE for grammar, 13 m writing 22 units sequentially (±25 s/unit), ±20 m adversarial Explore review of 5 risk:high units, 8 m tail | swallowed the −18 m bolt-stage gain → DONE flat |

## 2. Levers (each = one commit, one xs measurement, its own row in the CHANGELOG)

**L1 — deterministic top-up per implementer return (S1).** Today the lite clause (`batch-and-fanout.md` P3 rule (1)) is prose: "after EVERY implementer return … run `derive-ready-units.sh` and top up". The controller still batched. Mechanical form, no new surface: `derive-ready-units.sh` gains `--emit-dispatch-plan` that prints the exact ordered list of ready units to dispatch NOW (cap − in-flight, per `vault_layouts.inflight_units` + `parallel_max`), and the execute-bolts procedure makes that list the ONLY dispatch source after a return (the controller copies it, never composes a burst). Pin: a fixture with 3 ready units, 1 in flight, cap 4 → plan = 3; with 4 in flight → plan = 0 + reason. Measured target on xs: ready-wait Σ → < 10 % of bolt-stage (xs has 5–6 units, little headroom — the xs run proves the mechanism fires on every return, the clinic proves the minutes). Not a hook: a missed top-up is a cost, not a moat breach.

**L2 — PLAN rail for DAG depth + unit size (S2).** `validate-unit-spec.sh` gains an ADVISORY (never an issue) `dag_shape_advisory`: (a) DAG depth > 4 → name the critical path (unit ids + Σ estimated steps); (b) a hub unit (≥ 3 direct dependents) → name it; (c) a unit with > 6 implementation steps or > 4 target files → "split candidate". `plan-procedure.md` step 5 reads the advisory and splits BEFORE presenting (same discipline as `xs_body_advisory`). The size proxy stays `_lib/unit_tier.py` (one proxy everywhere). Pin: fixture DAG depth 5 + one hub → both named; depth 3 → silent. Measured target: clinic critical path ≤ 4 hops, no unit > 30 m impl (EST: bolt-stage floor 77 m + tails).

**L3 — `plan` PRE-CODE diet (S3).** (a) a compact grammar reference `skills/plan/references/unit-grammar-cheatsheet.md` (≤ 120 lines: the fields each validator parses, with the regex it uses — generated FROM the validators by a script + parity pin so it cannot drift) so the model stops reading validator source; (b) unit writing in ONE batched Write per module (procedure text; the validators re-check the batch); (c) the adversarial risk:high review dispatched as ONE parallel fan-out (one message, N Explore agents) instead of serially. Measured target on xs: `plan` wall −30 % (xs plan today ≈ 20 m; clinic 56 m → EST ≤ 35 m).

## 3. Measurement protocol (runbook amendment #5 applies)

1. Cache the tree at the lever's commit; xs scenario = the same 3-screen fixture/prd/lane/model as run #2 (`benchmarks/results/p3/xs-lite-7.38.0-run2`); chain `p3-chain-xs.sh` (net-aware, rule C: pre-dispatch death → fresh attempt ≤ 3; post-dispatch → same-session resume labelled TERCEMAR).
2. Per lever, **n = 2 clean xs runs**; extract with `p3-done-endpoints.py` + `p3-parallelism.py` + `p3-ship-verdict.py`; compare to run #2 (DONE 1h11m02s; F.4 trailer run DONE 59m18s n=1).
3. Only if L1 fires on every return (xs) and L2/L3 hit their targets → clinic ONCE (`P0_FLAGS=--lite … p0-clinic-arm3 … reset --hard b915556`) and judge criterion (b) again: in-flight ≥ 2.5 AND idle < 20 % AND acceptance full AND Critical 0 → `--lite` default (`derived.lane` default = lite, `--classic` opt-out) in 9.0.0; otherwise stays opt-in and the dissection repeats (no new lever that session).
4. **Cost EST (from §4 cost table):** xs ≈ $50/run → 3 levers × 2 = $300; clinic ≈ $180–215 → **≈ $500–520 total**, ≈ 8–10 wall hours of runs. This is the owner's budget call — the reason nothing here is built yet.

## 4. Deliberately not done

Building any lever before its xs measurement; raising `parallel_max` (measured: the cap was never the limiter — 3 root units idle 39–221 min); touching the panel/F-07 gate (0 rejections in 7.38.0); a hook for top-up (cost, not moat).

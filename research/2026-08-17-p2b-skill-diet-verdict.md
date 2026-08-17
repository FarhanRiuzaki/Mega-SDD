# P2b — hot-SKILL byte diet: EVALUATED, REJECTED (on the record)

**Context:** tranche P2b of the 2026-08-17 token-lard audit (P1 = v6.13.0 measurement + hygiene; P2a = v6.14.0 halt-registry family split). The audit estimated 12–18k tok/run from dieting the 5 hot SKILL.md bodies (execute-bolts 44.9KB, generate-units 27.1KB, bind-codebase 26.4KB, generate-intent 25.3KB, orchestrate-flow 24.2KB ≈ 37k tok of bodies per full express run).

## What the read-through found

Full read of `execute-bolts/SKILL.md` (the extreme case: 197 lines, 230 B/line, 527 loads in the telemetry window) + a structured read of `generate-units/SKILL.md` §Procedure:

1. **The density IS the content.** Nearly every paragraph is a round-caught, load-bearing pin: exit-code→halt maps (preflight scan codes 2–8, dispatch-builder codes 0/1/2/4), the `--parallel` per-unit commit-range semantics ("a sibling's finding must never be attributed to this unit"), detect-after commit topology, forged-baseline threat notes, pre-loop-abort vs fail-fast distinctions. These are exactly the sentences whose absence past rounds proved dangerous (the "prose-only gap" class is cited *inside* the file at Step 0).
2. **Progressive disclosure is already executed.** Both skills are router-shaped: heavy detail (state tables, halt YAMLs, schemas, templates, budget cascades) already lives in references with explicit open-conditions ("open X ONLY when a probe is missing"; "load ONLY when a halt fires"). The v6.2.0–6.6.0 skills-audit phases and the v4 lean-core rewrite took this win years-of-iterations ago; what remains inline is the part those same audits deliberately KEPT.
3. **Safe residual is small.** Genuinely relocatable without eroding pins: rare-flag long-form descriptions (`--rollback`, `--module`, `--squad`, PBT flags) and the T1/T2/T3 tier prose that duplicates `context-enrichment.md`'s spec — ~2–4KB total across all five skills (~0.5–1k tok/run), against relocation-regression risk in the hottest gated path in the plugin. Today's own rounds (P1 collateral-orphan MAJOR; P2a subtype-dismemberment BLOCKER) are the measured cost profile of exactly this operation class.

## Verdict

**Do not run the diet.** By the standing no-gimmick rule (justify buys vs cost) and the moat-takeout amendment (evidence per item): the estimated win collapsed from 12–18k to ~0.5–1k tok/run on inspection, while the risk class stayed BLOCKER-shaped. The audit's F1 estimate assumed line-density masked movable content; reading the content falsified that assumption. Recording the rejection so the next audit does not re-litigate it without new evidence.

## What still moves the needle (unchanged, all gated)

- **P3 — advisor scoping/tier** (measured ~124k input tok per bind on opus): USER decision, ideally after findings-per-bind telemetry accumulates under the P1 ruler.
- **Fork flip for scan/bind** (fork-READY since v5.15.0): needs the user's 2 interactive runs.
- **c1 batch re-scan consumer trace**: runnable any time; cut only if the trace proves no inter-batch consumer.
- If skill-body cost ever matters again, the honest lever is **architecture (fork/offload), not prose relocation**.

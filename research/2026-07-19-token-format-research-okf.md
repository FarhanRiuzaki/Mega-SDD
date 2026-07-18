# Token-format research — journals, OKF, and what actually saves tokens without dulling the moat

**Date:** 2026-07-19 · **Trigger:** "research journal tentang efficiency token dan token optimize, research OKF untuk knowledge format — kalau ada format yang lebih efisien khususnya token TANPA merubah sharpness skills mega-sdd" · **Mode:** research-only (hard rule: no code changes)

**Method:** two adversarially-verified workflows — (1) external deep-research: 104 agents, 22 sources fetched, 110 claims extracted, 25 verified by 3-vote adversarial panels (24 confirmed, 1 refuted, 0 unverified); (2) internal format census: 6 agents over every artifact class + a consumption map (which skill loads which artifact, how often, and who writes it), every claim grounded file:line.

---

## TL;DR verdict

1. **Format migration is the wrong lever.** TOON, compact-JSON, and LLMLingua-style compression each fail the sharpness constraint on the evidence — and TOON's savings *invert to a cost* on mega-sdd's data shape. **Rejected.**
2. **OKF validates mega-sdd's current format.** "OKF" in the knowledge-format space is **Google Cloud's Open Knowledge Format v0.1** (draft, June 2026): deliberately *"a directory of markdown files with YAML frontmatter."* That is byte-for-byte the substrate mega-sdd already uses. The emerging industry standard landed on your "asumsi" — the format assumption is now independently validated, not challenged.
3. **The real, evidence-backed token lever is WHO WRITES, not WHAT FORMAT.** Output tokens cost 5x input; cache-reads cost 0.1x. The census found the model re-typing content a script could derive — eliminating those double-writes saves more than any format change could, with **zero** sharpness loss (and in two cases a sharpness *gain*).
4. **Second lever: placement, not compression.** Peer-reviewed work (LongLLMLingua, Lost-in-the-Middle) shows comprehension hinges on the *density and position* of key information — load-bearing content early and intact. That is a structure discipline inside the existing Markdown format, free to apply.

---

## Part 1 — External research (adversarially verified)

### 1.1 What OKF actually is

- **Open Knowledge Format v0.1** — Google Cloud, announced 2026-06-12/13, draft spec in [`GoogleCloudPlatform/knowledge-catalog`](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md). NOT the Open Knowledge Foundation, NOT a compression scheme.
- Physical format, verbatim from the spec: *"The format is intentionally minimal: a directory of markdown files with YAML frontmatter"*; *"If you can cat a file, you can read OKF."* One mandatory frontmatter field (`type`), reserved filenames (`index.md`, `log.md`), cross-link rules. Goals: enrichment agents write, consumption agents read/traverse, cross-org knowledge exchange.
- The 451-line spec makes **zero** token-efficiency claims (grep-verified). The Google blog explicitly rules out compact serialization: *"No complex compression scheme, no new runtime, no required SDK... Just markdown."*
- **Mapping to mega-sdd:** vault files already carry YAML frontmatter with a `type` key; `00-index.md` already plays the `index.md` role; the KB is already a typed markdown directory. Adopting OKF would be a *convention alignment for interop* (worth watching if OKF gains tooling/adoption — it is a 5-week-old draft), **not** a token-economics play.

### 1.2 TOON — why it is disqualified as a gate-artifact format

TOON (spec v3.3) is a lossless re-encoding of the JSON data model (YAML-style nesting + CSV-style tabular rows with `[N]`/`{fields}` headers). Verified findings, largely from TOON's **own** benchmark pages (admissions against interest):

| Data shape | TOON vs alternative | Verdict |
|---|---|---|
| Uniform flat arrays | −58.8% vs formatted JSON | Its sweet spot — but CSV is *still smaller* (+5.9%) |
| Mixed-structure data | −21.9% vs formatted JSON; **+14.7% MORE than compact JSON** | mega-sdd's shape ≈ here |
| Deeply nested config | **+11.1% more than compact JSON** (620 vs 558 tok) | inverts to a cost |
| Truncation-integrity detection | **0/4 detected** (CSV and XML: 4/4) | direct disqualifier |

- Accuracy advantage is within noise, model-dependent, and disputed: TOON's own 4-model/209-question suite shows ±1–2pt swings (loses on Gemini); an independent 34-model community benchmark measured TOON 66.9% vs JSON 78.7% on filtering; arXiv 2605.29676 found ~9pp accuracy cost in agentic settings. The headline claim "no measured accuracy loss" was **refuted 1-2** in adversarial verification.
- The 0/4 truncation-detection failure matters specifically for mega-sdd: gates exist to detect exactly this class of artifact tampering/truncation. A format that hides truncation from the model is anti-moat.
- Residual niche: TOON/CSV could in principle serve uniform-array *sidecars* (vault.json arrays, graph.json) — but Part 2 shows those should exit the model-write lane entirely, making their on-disk format token-irrelevant.

### 1.3 Prompt compression (LLMLingua family) — powerful, and inapplicable

- LLMLingua (EMNLP 2023): up to 20x reduction on redundant few-shot CoT prompts with ~1.5pt accuracy loss. LLMLingua-2 (ACL 2024 Findings): 2–5x with near-intact in-domain QA. LongLLMLingua (ACL 2024): **+21.4% accuracy with ~4x fewer tokens** — via question-aware compression *plus reordering* against position bias.
- But: compression is a **model-driven pipeline** (small LM computing per-token self-information + budget controller), not a static format. On disk the artifact stops being human/gate-auditable Markdown — a direct conflict with citation discipline.
- Precision cost is real and lands exactly on mega-sdd's moat: 500xCompressor retains only 62–73% of capability; Amazon Science (EMNLP 2025 Findings) shows SOTA compressors *"fail to preserve key details"*; groundedness drops of ~30–50pts on citation-critical tasks.
- The compression-paradox preprint (2603.23527, medium confidence — single-author, non-peer-reviewed): aggressive truncation exploded DeepSeek outputs 56x when mid-prompt instructions were destroyed vs 5x when critical content sat early. Provider-specific (Claude outputs *shortened* under compression in 2505.00019), but the structural lesson is corroborated: **instruction survival and early placement moderate everything**, and input-token count alone is an invalid efficiency metric.

### 1.4 The evaluation framework any future format change must pass

From EMNLP 2025 Findings (2503.19114), verbatim: judge on *"(i) downstream task performance, (ii) grounding in the input context, and (iii) information preservation"* — besides compression ratio. This maps 1:1 onto mega-sdd: task performance = bolt/gate correctness, grounding = citation discipline, information preservation = binding-verdict precision. Any proposal that only cites input-token savings is unfalsifiable marketing by this framework.

### 1.5 Caveats the verification panel attached

- Every token count in the literature uses GPT-family tokenizers (o200k_base), not Claude's — absolute numbers differ for mega-sdd.
- No study tested the exact scenario (citation-bearing, verdict-table knowledge artifacts under format change); mega-sdd conclusions are one honest analogical step from adjacent evidence.
- OKF is a v0.1 draft with unproven adoption; TOON spec/benchmarks are actively changing. Figures verified live 2026-07-18/19.

---

## Part 2 — Internal census: where mega-sdd's tokens actually go

Cost lanes (from `TOKEN-COST-REPORT.md`, Opus price ratios): **output ×5, cache_creation ×1.25, input ×1, cache_read ×0.1**. Raw token counts overstate real cost 3.65x. Three findings reframe the question:

1. **The always-on lane is already tiny** (post-v4.43.0 anchor diet): session-start injects ~2.7KB routing core + capped instinct block; all blocking gates read state files in the script lane (zero model tokens).
2. **The scary-looking JSON is free.** The 26 `.*-state.json` files, `telemetry.jsonl` (5.6MB), `graph.json`, postflight/batch evidence — all script-written, script-read. High syntax% (45–78%) is irrelevant: format of script-lane files costs nothing. **Do not "clean up" the free lane.**
3. **The expensive lane is model-writes and per-bolt re-injection.** Measured syntax share of real vault content is modest (01–06 files: 15–30% — mostly content, little format fat). The fat is elsewhere: double-writes and re-emitted boilerplate.

### 2.1 Model double-writes a script could derive (the big lever)

| # | Double-write | Today | Saving (output lane, ×5) | Sharpness effect |
|---|---|---|---|---|
| W1 | `bound/` vault copy | model re-types the ENTIRE vault + `<!-- BIND: -->` annotations; the gate signal is `bound/` *existence only* (SKILL.md:83) | **~10–25k output tok/bind** — largest single win | None — content becomes byte-identical by construction |
| W2 | `binding.json` | model re-emits the same claims it just rendered in the binding.md State Map; the md→json parser **already exists** (`validate-binding-json.sh:18-44`) | ~70–90 tok/claim → ~3.5–4.5k out tok on a 50-claim bind, per bind AND per `--paths` re-bind | Parity gate becomes tautological — the divergence failure class *disappears*. Watch: `resolve-oq --binding` writes `resolution:` into the json |
| W3 | `.citation-map.json` | model hand-transcribes sha256 strings | ~1–1.5k out tok per FSD emit | **Sharpness GAIN** — a fabricated hash currently passes undetected; script-computed cannot lie |
| W4 | `preflight.json` | model captures the pre-flight Hard-rule snapshot (postflight is already script-written and forge-guarded) | ~100–250 out tok/Hard-rule unit | **Sharpness GAIN** — closes the forgeable-baseline hole in the B1 diff |
| W5 | `vault.json` | model writes the derived index of the 7 md files (vault-contract.md:91 mirror rules are already stated mechanically) | ~300 (small vault) → ~2.5k+ (48-OQ vault) out tok, × every resolve-oq/diff-vault round | **Riskiest** — OQ status/category extraction is best-effort prose parsing; defer behind W1–W4 |

### 2.2 Re-emitted static boilerplate (medium lever)

- `00-index.md` template spine (~120 lines: Anti-hallucination rules, AI-consumer notes, halt-YAML examples, generic glossary rows) — **zero gate/hook/test greps these sections** (verified). ~2–2.5k out tok per vault, 55% of 00-index. They exist for third-party AI consumers reading the vault standalone (Cursor etc.) — a diet must keep that story (e.g. one pointer to a static reference file shipped with the vault).
- `binding.md` fixed boilerplate (banner + structural-marker explainer + enum legend, ~2.3KB) re-emitted per bind and per re-bind → ~575 out tok each. Caution: the enum legend is the **keterangan contract at Tier-3** — a diet needs the legend story preserved (pointer + halt-time rendering), not just deleted.
- Conflicts summary table: machine-invisible by design (validators read only `### CONFLICT-N` headings) and a documented split-brain hazard — droppable.
- Bolt dispatch fixed boilerplate (~3KB halt vocabulary/self-report/rollback schema per dispatch, re-logged to `dispatch-prompt.md`) → move into the bolt-implementer agent's system prompt (precedent exists: commit format already lives there).

### 2.3 Unit-spec fat (multiplied per-bolt AND per-lens)

- Gate-inert frontmatter keys — zero grep hits in scripts/ or hooks/: `grounding_evidence` block (schema itself says "not enforced downstream"), `superpowers_skills`, `estimated_complexity`, `mutability.rebuild_freedom` sub-map. ~150–200 out tok/unit at write + ~600–900 input-equivalents per full-tier bolt attempt.
- Acceptance criteria written **three times** (frontmatter `acceptance_test` + `## Acceptance criteria` body + `ears:` restating `expects:`). Constraint: verify+HIGH units must keep marker-bearing body criteria (A1 gate reads the body).
- Lens-slice diet: non-spec lenses could drop `## Goal`/`## Context`/`## Out of scope` (~200–400 tok × 3–4 lenses) — spec lens keeps the full body, so requirement coverage is intact; quality lens loses some scope-creep context (trade-off to judge at spec time).

### 2.4 The sharpness inventory (frozen — any "optimization" here dulls a gate)

Exact-regex-parsed by hooks/gates/tests, verified file:line: flow headings `### F-*-NNN` + mandatory mermaid fence; `stages:`/`stage_id`/`actor_role` keys + `_kb_source`; col-0 `- [ ]` DoD checkboxes; OQ tag/priority/checkbox grammar + `OQ-DESIGN*` shape; maker→checker vocabulary; DBML `Table` blocks; `knowledge-base/`-prefixed citations; `[VERIFIED]/[INFERRED]/[OPEN]` + `[LOCKED]/[INTENT]/[ARTIFACT]` marker pairs with same-line citations; `### CONFLICT-N` detail headings; the 6-column Implementation State Map; Hard-rules grammar (B1 engine); `ADD/KEEP/REMOVE` tokens; `target_files` path/operation shape; `feat(U-XXX):` commit grammar. **The blind review panel stays blind** — "do not save tokens by sharing context between lenses" is the anti-rubber-stamp rail.

---

## Part 3 — Convergent recommendations (ranked, research-only)

```mermaid
flowchart TD
    Q["Proposal: 'more token-efficient format'"] --> A{Does it change WHO writes\nthe artifact?}
    A -- "model → script\n(W1–W4)" --> S1["ADOPT CANDIDATE\n5x-lane saving, sharpness ≥ equal\n(two cases: sharpness GAIN)"]
    A -- no --> B{Does it change the on-disk\nserialization (TOON/compact-JSON/\ncompressed blobs)?}
    B -- yes --> R1["REJECT\nTOON: 0/4 truncation detection,\nsavings invert on this data shape;\ncompression: 30–50pt groundedness drops,\nkills auditability"]
    B -- no --> C{Does it delete content\nno gate/consumer reads?\n(boilerplate, inert keys)}
    C -- yes --> S2["ADOPT CANDIDATE\nverify zero grep hits first;\nkeep keterangan + standalone-consumer story"]
    C -- no --> D{Does it move load-bearing\ncontent earlier / denser?}
    D -- yes --> S3["ADOPT CANDIDATE\npeer-reviewed comprehension lever\n(position + density)"]
    D -- no --> R2["REJECT — fails the 3-axis test\n(task perf, grounding, info preservation)"]
```

Priority order if this research graduates to a spec (per release cadence: research → spec → phased ship):

1. **P1 — Script-derive batch (W1–W4):** `bound/` copy, `binding.json`, `.citation-map.json` hashes, `preflight.json`. Biggest saving, zero-to-negative sharpness risk (W3/W4 strengthen the moat). W5 (`vault.json`) deferred until W1–W4 prove out.
2. **P2 — Boilerplate diet:** 00-index spine, binding.md legend (keterangan-preserving), conflicts table, dispatch boilerplate → system prompt.
3. **P3 — Unit diet:** drop gate-inert frontmatter keys; de-triplicate acceptance criteria (A1-aware); optional lens-slice trim.
4. **P4 — Placement discipline:** author-time rule that verdicts/hard rules/citations sit early and dense in every artifact (Lost-in-the-Middle-driven; zero token cost, comprehension gain).
5. **Watchlist — OKF v0.1:** no action now; if it gains validators/adoption, a thin convention alignment (mandatory `type`, `index.md` naming) buys interop cheaply since the substrate already matches.
6. **Rejected:** TOON migration, compact-JSON re-serialization of prose artifacts, LLMLingua-style compressed artifacts, any cut to the sharpness inventory or the blind panel.

**Measurement gate (standing doctrine):** any shipped change from this list must be judged on the 3-axis framework — gate correctness, citation grounding, information preservation — with token delta measured cost-weighted (×5 output), never raw input count. The fork-A/B machinery (#18, `scripts/measure-fork-tokens.sh`) is the existing harness to extend.

---

## Sources (external, verified live 2026-07-18/19)

Prompt compression: arXiv 2310.05736 (LLMLingua, EMNLP 2023) · 2403.12968 (LLMLingua-2, ACL 2024 Findings) · 2310.06839 (LongLLMLingua, ACL 2024) · 2410.12388 (survey) · 2408.03094 (500xCompressor, ACL 2025) · 2503.19114 (Amazon Science 3-axis eval, EMNLP 2025 Findings) · 2603.23527 (compression paradox — non-peer-reviewed, medium confidence) · 2505.00019 (provider-specific output-length effects).
TOON: github.com/toon-format/toon + spec v3.3 · toonformat.dev/guide/benchmarks · improvingagents.com community benchmarks · arXiv 2601.12014, 2605.29676, 2603.03306.
OKF: GoogleCloudPlatform/knowledge-catalog `okf/SPEC.md` (v0.1 draft) · Google Cloud blog "How the Open Knowledge Format can improve data sharing".

Internal evidence: file:line citations throughout Part 2 from the 6-agent census (full structured output in session workflow journal `wf_10fdeb83-8bd`).

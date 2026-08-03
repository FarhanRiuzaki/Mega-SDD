# Express bind (`--express`) — claim-scoped retrieval, zero map load

The v6 P1 lane (spec `docs/superpowers/specs/2026-08-03-v6-express-spine-design.md §P1`).
`--express` changes **retrieval only**: WHERE evidence comes from. The verdict grammar,
the CONFLICT gate, Steps 2.5–2.12, and Steps 3–6 are the standard skill body, unchanged.
The emitted `binding.md` is byte-compatible with every parser and gate.

## Contents

- [What changes vs the standard lane](#what-changes-vs-the-standard-lane)
- [Step E0 — index freshness (controller step)](#step-e0)
- [Step E1 — derive the claims ledger](#step-e1)
- [Step E2 — load the ledger, not the vault](#step-e2)
- [Step E3 — the per-claim retrieval ladder (fail-closed)](#step-e3)
- [Verdict + state semantics under express](#verdict--state-semantics)
- [Frontmatter + audit recording](#frontmatter--audit-recording)
- [Fallback to the standard lane (honest, never silent)](#fallback)
- [Context discipline (anti-rot)](#context-discipline)
- [Anti-hallucination rails (express-specific)](#express-rails)

## What changes vs the standard lane

| Surface | Standard | Express |
|---|---|---|
| Claim enumeration | model reads all 7 vault docs | `claims-ledger.json` (script-derived, verbatim text + `NN-name.md:LINE` source) |
| Primary ground truth | `codebase-map.md` (loaded whole) | the source files themselves, reached via symbol-index queries + targeted Reads |
| codebase-map.md | required input (halt when missing) | **not read at all** (zero map load; not required) |
| KB consultation | when the map is silent | when the retrieval ladder is silent — same marker/tier semantics |
| Everything else | Steps 2.5–2.12, 3–6 | identical |

Boundary posture (the moat argument): the searchable universe stays the **entire
repo** — the symbol index is repo-wide and unsliced, `Grep`/`Read` are unrestricted,
so nothing is removed from searchable. There is no precomputed slice whose recall
would need proving (the shape the repo already rejected); the ladder below is a
*search order*, never a boundary.

## Step E0 — index freshness (controller step) {#step-e0}

Freshness is THIS controller's job, once per bind — never per claim (the R2 lesson).

1. Probe `.mega-sdd/codebase/symbol-index.json`. Present AND its `head_commit`
   == `git rev-parse HEAD` → fresh, proceed.
2. Absent or stale → **Run** `bash <plugin>/scripts/build-symbol-index.sh --cwd=<project-root>`
   (seconds; atomic).
3. Exit **3** (ast-grep not installed) or **4** (build failed) → **fall back to the
   standard lane** (§Fallback). Never proceed express against an absent/stale index.

## Step E1 — derive the claims ledger {#step-e1}

**Run** `bash <plugin>/scripts/derive-claims-ledger.sh --vault <vault>`.

- Exit 0 → `<vault>/claims-ledger.json` written (deterministic; the markdown stays
  authoritative — never hand-edit the ledger).
- Exit 2 (vault grammar mismatch / zero claims) → **fall back to the standard lane**
  (§Fallback) — a vault the deriver cannot read is exactly the case the whole-doc
  lane exists for.
- Exit 3 (vault unreadable) → the usual `bind_inputs_missing` halt, same as standard.

## Step E2 — load the ledger, not the vault {#step-e2}

Read `claims-ledger.json` ONLY. Do not read the 7 vault docs whole; do not read
`codebase-map.md` at all. Claim `text` is verbatim vault text via the script
(satisfies the "no paraphrasing" rail); `source` is the exact `NN-name.md:LINE`
`make-bound.sh` needs. When a verdict genuinely needs surrounding vault context
(e.g. an ambiguous constraint row), Read THAT vault doc at THAT line range —
targeted, never whole-file-by-default.

## Step E3 — the per-claim retrieval ladder (fail-closed) {#step-e3}

Per ledger claim, in order, stopping at the first rung that yields decisive evidence:

1. **Index query** — **Run** `bash <plugin>/scripts/query-symbol-index.sh --cwd=<root>
   --name=<variant>` for each `hints.symbols` variant (entities) or the leading
   `hints.terms` (flows/decisions); optionally `--dir=` for the claim's expected home.
   Index rows are POINTERS, never evidence.
2. **Targeted Read** of the candidate files at the returned `file:line` anchors.
   **Verdicts anchor to READ evidence only** — an index row alone can never mint
   CONFIRMED (rail A3: query, never inject).
3. **Collision sweep (moat-critical, entities/components/naming claims)** — one
   repo-WIDE `--name=<primary symbol>` query with NO `--dir`/`--file` filter. The
   index is unsliced, so this sweep is global by construction. EVERY hit outside
   the claim's expected home is Read and evaluated: contradicting → **CONFLICT**
   (the pre-existing-collision class), never skipped because it is "elsewhere".
4. **Bounded repo Grep** — when 1–3 are silent, up to 2 `Grep` queries over the
   repo for the claim's terms (routes, config keys, and dynamic constructs live
   outside the symbol index). Hits → Read → evaluate.
5. **KB consultation** — when 1–4 are silent and a KB is present (`--no-kb` skips),
   the standard Step 2 marker/tier semantics apply unchanged.
6. **Still ungrounded ⇒ verdict per claim type, never CONFIRMED-by-absence:**
   - contradicting evidence found anywhere → **CONFLICT**;
   - no evidence + claim describes NEW work → CONFIRMED with State `NEW`, Anchor `—`
     (same as standard: NEW is a plan statement, not an existence assertion);
   - no evidence + claim ASSERTS something exists/holds in the code → **OQ**
     (Anchor `—`), with the honest note that the ladder found nothing.

## Verdict + state semantics under express {#verdict--state-semantics}

- Verdict tokens, blocking rules, CONFLICT detail-block grammar: unchanged
  (`references/binding-contract.md`).
- **Step 2.5 field-level diff**: computed from the READ entity source directly —
  the ledger carries the vault field set (`fields[]`), the Read supplies the code
  field set. A field diff is allowed ONLY when the entity's source file was
  actually Read this run; file unreachable → `UNKNOWN`/low, Field diff `n/a`
  (never inferred from index signatures — a signature is one line, not a field set).
- **`[reason:]` tokens**: `truncated_section` cannot occur (there is no capped map
  in this lane); `ambiguous_match` / `dynamic` / `regex_tier` / `kb_confirmed`
  keep their standard meanings. A claim the index cannot see because its language
  has no ast-grep pack (extracted at regex tier) uses `[reason: regex_tier]` on
  low-confidence anchors, exactly as the standard lane does.
- **Tech-OQ scan resolution (2.6)**: scan targets resolve via manifest files,
  index queries, and targeted Reads; `Citations` are real `file:line` (already the
  template's form). A map§ scan hint from the generator (e.g. `codebase-map
  §test_frameworks`) is re-targeted to its underlying ground truth (the manifest /
  config file) — never answered from a map this lane did not read.
- **2.12 advisor pass**: unchanged and NOT skipped. `build-advisor-bundle.sh`
  already records `codebase_map_present: false` honestly when no map exists. The
  dispatch prompt additionally names `.mega-sdd/codebase/symbol-index.json` +
  `<vault>/claims-ledger.json` as evidence surfaces; the advisor's `missed_match`
  sweep greps the repo SOURCE (its horizon was never the bundle).
- **`--paths` composition**: `--paths` keeps selecting WHICH claims re-verdict
  (anchor reverse-index; active CONFLICTs always re-validated; carried_forward
  provenance — `references/binding-contract.md §Claim-scoped re-bind`); `--express`
  selects HOW the affected set retrieves evidence.

## Frontmatter + audit recording {#frontmatter--audit-recording}

- `codebase_map:` keeps the canonical path (`.mega-sdd/codebase/codebase-map.md`)
  — parsers fall back to it; the lane simply did not read it.
- `binding_metadata.codebase_map_provenance: no-snapshot` — ALWAYS, in express.
  The closed enum is untouched; `no-snapshot` is the honest value (this binding
  attests nothing about map freshness because it read no map). Chain optimization
  then keeps `scan-codebase` in future chains — correct until P2 changes routing.
- `binding_metadata.head`: unchanged (current `git rev-parse HEAD`).
- **One additive key**: `binding_metadata.retrieval: express-index@<head8>` where
  `<head8>` is the symbol index's `head_commit` first 8 chars. Line-regex parsers
  are blind to unknown frontmatter keys (proven by the P1 grammar test); the key
  is provenance for humans + the round, load-bearing for nothing.
- Step 6 audit event summary appends `retrieval=express`.

## Fallback to the standard lane (honest, never silent) {#fallback}

Triggers: index exit 3/4 (E0), ledger exit 2 (E1). Action: run the standard
skill body (whole-vault read + codebase-map as primary ground truth — the map
missing then halts `bind_inputs_missing` exactly as standard). Record BOTH:

- one keterangan line in chat — "express fallback: <alasan singkat> — bind berjalan
  di lane standar (map utuh)";
- `retrieval=standard-fallback(<reason>)` in the Step 6 audit event summary, and
  NO `binding_metadata.retrieval` key in the frontmatter (that key attests
  express retrieval — a fallback run must not carry it).

A degraded-but-labeled-express run does not exist: the run is either express
(index + ladder) or standard (map) — never a hybrid that would blur what the
verdicts were grounded on.

## Context discipline (anti-rot) {#context-discipline}

The A1 rail, applied to this pass: keep the LEDGER and the RUNNING VERDICT TABLE
(claim id → verdict/state/anchor/confidence) live; **shed raw file-read content
after each claim's verdict lands** — the verdict row + its anchor is the durable
residue, the read bytes are not. Never accumulate whole-file reads across claims.
On a large ledger, process claims in vault-doc order and emit the State Map
incrementally — the artifact, not the context, is the memory.

## Anti-hallucination rails (express-specific) {#express-rails}

- An index row is a pointer, never evidence — no verdict cites the index.
- The collision sweep is NOT optional and NOT scoped: entity/component/naming
  claims always get the repo-wide name query, even after rung 2 confirmed the
  expected home ("found where expected" does not prove "absent elsewhere").
- Ungrounded ⇒ OQ / CONFLICT per E3.6 — CONFIRMED-by-absence is the failure
  class this ladder exists to prevent; when in doubt between OQ and CONFIRMED,
  it is OQ.
- Fallback is loud (chat keterangan + audit token) — a silent lane switch is a
  provenance lie.
- The ledger is derived state: never hand-edit it, never "fix" a claim by editing
  `claims-ledger.json` — fix the vault markdown and re-derive.

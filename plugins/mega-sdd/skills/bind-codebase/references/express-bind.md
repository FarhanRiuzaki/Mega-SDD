# Express bind (`--express`) — claim-scoped retrieval, zero map load

The claim-scoped retrieval lane (design contract: `docs/superpowers/specs/2026-08-03-v6-express-spine-design.md §P1`).
`--express` changes **retrieval only**: WHERE evidence comes from. The verdict grammar,
the CONFLICT gate, Steps 2.5–2.12, and Steps 3–6 are the standard skill body, unchanged.
The emitted `binding.md` is byte-compatible with every parser and gate.

## Contents

- What changes vs the standard lane
- Step E0 — index freshness (controller step)
- Step E1 — derive the claims ledger
- Step E2 — ledger skeleton + completeness sweep + scope
- Step E3 — the per-claim retrieval ladder (fail-closed)
- Verdict + state semantics under express
- Frontmatter + audit recording
- Fallback to the standard lane (honest, never silent)
- Context discipline (anti-rot)
- Anti-hallucination rails (express-specific)

## What changes vs the standard lane

| Surface | Standard | Express |
|---|---|---|
| Claim enumeration | model reads all 7 vault docs | `claims-ledger.json` skeleton + a model **completeness sweep** of the vault docs (§E2 — the ledger is never the claim boundary) |
| Primary ground truth | `codebase-map.md` (loaded whole) | the source files themselves, reached via symbol-index queries + targeted Reads |
| codebase-map.md | required input (halt when missing) | **not read at all** (zero map load; not required) |
| KB consultation | when the map is silent | when the retrieval ladder is silent — same marker/tier semantics |
| Everything else | Steps 2.5–2.12, 3–6 | identical |

Boundary posture (the moat argument): the searchable universe stays the **entire
repo** — `Grep`/`Read` are unrestricted, so nothing is removed from searchable,
and the ladder below is a *search order*, never a boundary. Be precise about the
index itself: it covers **git-tracked files with a covered extension** — NOT
untracked files, not extensions outside its map (`.vue`, templates, configs).
That is exactly why the collision sweep (E3.3) carries a mandatory Grep leg and
why rung 4 exists: the index accelerates search; only Grep/Read close it.

## Step E0 — index freshness (controller step)

Freshness is this controller's job, once per bind — never per claim (a per-claim
re-probe is the per-item spawn-fan-out regression class this repo has shipped
fixes for twice).

1. Probe `.mega-sdd/codebase/symbol-index.json`. Present AND its `head_commit`
   == `git rev-parse HEAD` → fresh, proceed.
2. Absent or stale → **Run** `bash <plugin>/scripts/build-symbol-index.sh --cwd=<project-root>`
   (seconds; atomic).
3. Exit **3** (ast-grep not installed), **4** (build failed), or **any other
   non-zero** (unknown rc ≠ pass) → **fall back to the standard lane**
   (§Fallback). Never proceed express against an absent/stale index.

## Step E1 — derive the claims ledger

**Run** `bash <plugin>/scripts/derive-claims-ledger.sh --vault <vault>`.

- Exit 0 → `<vault>/claims-ledger.json` written (deterministic; the markdown stays
  authoritative — never hand-edit the ledger).
- Exit 2 (vault outside the ledger grammar / zero extractable claims) → **fall
  back to the standard lane** (§Fallback) — a vault the deriver cannot read is
  exactly the case the whole-doc lane exists for. (A claimless greenfield vault
  then lands on the standard lane's `claims_total == 0` path — a deliberate
  recorded skip, not an error.)
- Exit 3 (vault unreadable) → the usual `bind_inputs_missing` halt, same as standard.
- **Any other exit** (no python3, signal, unknown) → fall back to the standard
  lane — an unknown rc is never treated as pass.

## Step E2 — ledger skeleton + completeness sweep + scope

1. Read `claims-ledger.json`. Claim `text` is verbatim vault text via the script
   (satisfies the "no paraphrasing" rail); `source` is the exact `NN-name.md:LINE`
   `make-bound.sh` needs.
2. **Completeness sweep (MANDATORY — the ledger is a SKELETON, never the claim
   boundary).** Read the 7 vault docs (they are small — the express saving is the
   codebase-map, not the vault) and enumerate claim-bearing statements the ledger
   grammar cannot see: named-H2 component sections (a template vault has NO `## §`
   headings), API-contract rows, prose constraints ("Must use Laravel 11"),
   stack lock-ins, naming conventions. Each uncovered statement becomes an
   APPENDED claim: id continues that doc's ordinal stream (`C-AR-05`, …), `text`
   verbatim, `source` = `NN-name.md:LINE`. The full claim-categories table in
   `binding-contract.md` (vault section → claim type) is the sweep's checklist —
   every category with vault content MUST yield ≥1 claim or an explicit
   this-category-is-empty note in the bind summary. Skipping the sweep narrows
   what gets VERIFIED — the exact cut the v6 mandate forbids.
3. **Scope (scoped vaults).** Read `vault.json`; when it carries `scope` /
   `scope_metadata`, constrain claim validation to the scope's sections and
   propagate `scope_metadata` into the `binding.md` header + the handoff `scope:`
   block exactly as the standard Step 1 does (`auto-memory-handoff.md`). A KB
   present (legacy-rebuild lane) still gets the advisory extraction-scorecard
   preflight — express replaces retrieval, not those rails.
4. Do NOT read `codebase-map.md` at all.

## Step E3 — the per-claim retrieval ladder (fail-closed)

Per ledger claim, in order, stopping at the first rung that yields decisive evidence:

1. **Index query** — **Run** `bash <plugin>/scripts/query-symbol-index.sh --cwd=<root>
   --name=<variant>` for each `hints.symbols` variant (entities) or the leading
   `hints.terms` (flows/decisions); optionally `--dir=` for the claim's expected home.
   Index rows are POINTERS, never evidence.
2. **Targeted Read** of the candidate files at the returned `file:line` anchors.
   **Verdicts anchor to READ evidence only** — an index row alone can never mint
   CONFIRMED (rail A3: query, never inject).
3. **Collision sweep (moat-critical, entities/components/naming claims)** — two
   legs, BOTH mandatory: (a) one repo-WIDE `--name=<primary symbol>` index query
   with NO `--dir`/`--file` filter; (b) one bounded repo-wide `Grep` for the
   primary symbol name — the index sees only tracked files with covered
   extensions, and "found where expected" does not prove "absent elsewhere"
   (untracked files, `.vue`/templates/configs live outside it). EVERY hit outside
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

## Verdict + state semantics under express

- Verdict tokens, blocking rules, CONFLICT detail-block grammar: unchanged
  (`binding-contract.md`).
- **Step 2.5 field-level diff**: computed from the READ entity source directly —
  the ledger carries the vault field set (`fields[]`), the Read supplies the code
  field set. A field diff is allowed ONLY when the entity's source file was
  actually Read this run; file unreachable → `UNKNOWN`/low, Field diff `n/a`
  (never inferred from index signatures — a signature is one line, not a field set).
- **`[reason:]` tokens**: `truncated_section` cannot occur (there is no capped map
  in this lane); `ambiguous_match` / `dynamic` / `kb_confirmed` keep their
  standard meanings. **Never mint `regex_tier` in this lane** — there is no
  engine-tier signal without the map, and "the index returned no rows" is
  indistinguishable from "the symbol does not exist"; evidence found only via
  Grep/Read anchors normally, and real match ambiguity uses `ambiguous_match`.
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
- **`--paths` composition** (`binding-contract.md §Claim-scoped re-bind`):
  `--paths` keeps selecting WHICH claims re-verdict; `--express` selects HOW the
  affected set retrieves evidence. Three explicit rules:
  1. The PREVIOUS `binding.md` is a **sanctioned read** in this composition —
     it is the anchor reverse-index's only source ("read the ledger, not the
     vault" never forbids it).
  2. Prior-binding claim ids and ledger ids are DIFFERENT id spaces. Match
     prior↔ledger claims by `source` (`NN-name.md:LINE`) first, verbatim `text`
     second; the State Map is written in LEDGER ids.
  3. Any AFFECTED claim that cannot be matched to a ledger claim → **full
     re-bind fallback** (the same one-line-note fallback the contract already
     defines) — never a guessed mapping, never a mixed-id State Map.

## Frontmatter + audit recording

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

## Fallback to the standard lane (honest, never silent)

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

## Context discipline (anti-rot)

The A1 rail, applied to this pass: keep the LEDGER and the RUNNING VERDICT TABLE
(claim id → verdict/state/anchor/confidence) live; **shed raw file-read content
after each claim's verdict lands** — the verdict row + its anchor is the durable
residue, the read bytes are not. Never accumulate whole-file reads across claims.
On a large ledger, process claims in vault-doc order and emit the State Map
incrementally — the artifact, not the context, is the memory.

## Anti-hallucination rails (express-specific)

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

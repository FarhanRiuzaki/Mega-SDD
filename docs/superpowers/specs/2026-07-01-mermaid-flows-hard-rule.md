# Spec — Mermaid-flows hard rule: every generated process/flow is a Mermaid diagram

**Status:** accepted
**Date:** 2026-07-01
**Driver:** user hard rule — *"setiap proses flow apapun itu dari hasil generate harus berbentuk/format Mermaid"* (every process/flow mega-sdd generates, whatever it is, must be emitted as a Mermaid diagram — no raw ASCII arrows, no prose-only flow).
**Supersedes / subsumes:** god-review finding **L7** (`research/2026-07-01-god-review-extract-intelligence.md` §L7 — `validate-kb-flows.sh` §8 State Machine accepts raw ASCII transitions).

---

## 1. The invariant

> **Any flow mega-sdd *generates* as a durable artifact is a Mermaid diagram.** A flow expressed as a prose step-list, an ASCII arrow chain, or a free-form diagram is a defect that its stage's validator FAILs.

"Flow" = an ordered/branching representation of process or state: a system/user flow (`04-flows.md` `F-xxx`), a KB §3 system flow, a KB §8 state machine. The Mermaid diagram is not decoration bolted onto a prose flow — **the Mermaid diagram *is* the flow** (design decision, §3).

This is an **advisory-tier** contract, consistent with every existing flow check: the validator returns `FAIL`, the PostToolUse hook surfaces it non-blocking (tier **C2** — producer must rewrite; never auto-rewritten, per `references/mermaid-emission-rules.md`). It does not become a hard block at the bind→units CONFLICT gate; the moat's blocking rail is unchanged.

## 2. Scope

### In scope (surfaces that *generate* a flow artifact)

| Surface | File | Current state | This spec |
|---|---|---|---|
| KB §3 System Flow | `extract-intelligence` → `knowledge-base-schema.md` §3 | Mermaid **enforced** — `validate-kb-flows.sh` FAILs non-mermaid ASCII (`:314-323`) | no change (already correct — the reference model) |
| KB §8 State Machine | `extract-intelligence` → schema §8 | **GAP (L7)** — non-N/A §8 with transitions but no mermaid fence returns PASS (`validate-kb-flows.sh:358-360`) | **Inc-1**: FAIL non-mermaid, mirroring §3 |
| Vault flows | `generate-intent` → `templates/04-flows.md` `F-xxx` | Prose **numbered `Steps:`** are the flow; Mermaid only for the staged `stateDiagram` (multi-step). `validate-flow-coverage.sh` parses *either* prose OR mermaid | **Inc-2**: Mermaid flowchart mandatory per flow; new `validate-vault-flows.sh` FAILs a prose-only flow |

### Inherited (write flows into an in-scope surface — no new gate, contract note only)

- **`detect-drift`** — when it appends a "Missing in vault" flow to `04-flows.md` (`report-format.md`), that appended flow follows the `04-flows.md` Mermaid contract. detect-drift reads flow steps by **LLM reasoning** (no script parser — confirmed: no drift script in `scripts/`, `SKILL.md:56` builds an internal model), so it reads the Mermaid nodes/edges the same way it read prose. Near-zero blast.
- **`diff-vault`** — same: any flow it writes into a vault doc is Mermaid.

### Out of scope

- **Drift / diff *reports*** themselves (`DRIFT-REPORT.md`, diff report) — these are findings lists, not generated flows. A finding that *names* a flow ID is not a flow.
- **`graph`** — emits a dependency/impact graph (`graph.json` + views), not a process flow.
- **`emit-fsd`** — does not author flows; it renders vault content. If `04-flows.md` is Mermaid, the FSD inherits it. No change here.

## 3. Design decision — Mermaid *is* the flow (not Mermaid + prose)

For `04-flows.md`, the mandatory Mermaid flowchart **replaces** the prose numbered `Steps:`; it is not added alongside them. Rationale:

1. **The rule bans prose flows.** Keeping a numbered step-sequence keeps exactly the artifact being banned.
2. **Dual-source drift (decisive).** `validate-flow-coverage.sh` is numbered-first: `if numbered-steps … elif mermaid-edges …` (`:643-661`). If a flow carried BOTH, coverage parses the prose steps and *ignores* the Mermaid — the mandated diagram would ship unvalidated and free to drift from the steps coverage actually reads. Making Mermaid the single step-source removes that drift. Under this spec, with prose steps gone, `validate-flow-coverage.sh` falls to its existing Mermaid-edge branch (`:660-661`) — already implemented, no rewrite (verify the edge branch yields the input-accepting steps its module assertion needs).
3. **Metadata stays.** `Actor/Trigger`, `Preconditions`, `Postconditions`, `Definition of Done`, `Source`, and the staged `stages:` YAML block are flow *attributes*, not the flow — they remain. Only the numbered `Steps:` list becomes the Mermaid flowchart. Cross-cutting handoff points (layer A → layer B) render as flowchart edges/subgraphs.

## 3b. Render correctness — the diagram must actually render (two layers)

A Mermaid *mandate* is worthless if the emitted Mermaid does not render. A field scan proved the always-on Rule 1–3 tokenizer is only a **subset** of what renders: header-less edge fragments and `[placeholder]` blocks pass the quoting checks yet fail with mermaid's "No diagram type detected". Two complementary layers close this:

- **Layer 1 — zero-dep heuristic (always-on gate).** Beyond Rule 1–3 (node-text quoting), the shared tokenizer now enforces **Rule 0 (structural)**: every ` ```mermaid ` block must open with a recognized diagram-type declaration (`flowchart`/`stateDiagram-v2`/…), else `mermaid_no_diagram_type`; an empty block → `mermaid_empty_block`. Ground-truthed against `mermaid.parse()`: catches the most common real render-breaker with **zero** false positives on valid diagrams, no dependency. Lives in `_lib/mermaid_syntax.py check_diagram_type`, wired into `validate-kb-flows.sh` (§3+§8) and `validate-vault-flows.sh`.
- **Layer 2 — opt-in real-parser ground truth (`verify-mermaid.sh`).** Runs the real mermaid grammar (`mermaid.parse()`, headless — **no Chromium**) over every block via `_lib/mermaid_parse_oracle.mjs`, catching every render-breaker the heuristic cannot (reserved-word `end` nodes, unterminated shapes, bad transition labels, …). **Best-effort:** needs Node + the `mermaid` package (resolved from a local/global install or the bundled mermaid-cli); absent → clean **SKIP**, never blocks. For CI / on-demand, not the per-write hook. The mermaid min build pulls a DOM (DOMPurify) dependency that throws *after* grammar validation on valid input, so the oracle classifies by error text (grammar markers → real error; DOM-only → grammar OK).

Heuristic (stricter, defensive style — e.g. always-quote) and parser (lenient, render ground truth) answer different questions and may disagree on style-only cases; that is expected. Both are **advisory** (never a hard block).

### Inc-1 — L7: KB §8 State Machine Mermaid gate  *(self-contained; ship first)*

`validate-kb-flows.sh:358-360`, the `elif has_transitions:` branch, currently returns `PASS` ("consider mermaid fence for consistency"). Change it to FAIL, mirroring the §3 branch (`:314-323`):

- emit `issues[] { halt_type: "kb_flow_not_mermaid", section: "8", detail: "state transitions not in ```mermaid fence" }`
- append `checks[] { check: "sec8_state_machine_fence", status: "FAIL", detail: "has state transitions but not in mermaid fence" }`

`has_na` (N/A → SKIP) and `has_mermaid` (→ syntax check) branches are unchanged. Do not hostage this to the vault redesign.

**Fixture (red→green):** a §8 with `A --> B --> C` transitions and no ` ```mermaid ` fence must return `status: FAIL`; the same §8 inside a ` ```mermaid stateDiagram ` fence must return `PASS`.

### Inc-2 — Vault `04-flows.md` Mermaid mandate  *(design-heavy)*

1. **Shared syntax lib.** Extract the Rule 1–3 Mermaid syntax tokenizer (`check_mermaid_syntax` + `extract_mermaid_blocks` + `find_node_specs`, `validate-kb-flows.sh:77-278`) into a single shared module both KB-flows and vault-flows validators call. Do **not** re-implement it in a second validator (that re-commits the one-codebase-divergence class the god-review keeps flagging, and violates reuse-over-new-surface). Preferred: `scripts/_lib/mermaid-syntax.py` sourced by both; `validate-kb-flows.sh` behavior must be byte-for-byte unchanged after extraction (pinned by its existing fixtures).
2. **New validator `validate-vault-flows.sh`.** Parallel to `validate-kb-flows.sh`. For each `### F-{prefix}-NNN` flow entry in `04-flows.md`: assert a ` ```mermaid ` fence exists within the entry body; run the shared syntax checker on it. A flow entry with a numbered `Steps:` list (or ASCII arrows) and no Mermaid fence → `FAIL` `vault_flow_not_mermaid` with the flow ID + line. Entries explicitly `_None detected_`/`N/A` → SKIP. Output `<cwd>/.mega-sdd/.vault-flows-state.json`; exit 0=PASS/SKIP, 1=FAIL, 2=error — same contract as `validate-kb-flows.sh`.
3. **Template.** In `templates/04-flows.md`, replace the numbered `**Steps:**` blocks (all three flow-type sections) with a mandatory ` ```mermaid flowchart ` block per flow, keeping `Actor/Trigger`, `Preconditions`, `Postconditions`, `Definition of Done`, `Source`, and the staged `stages:`/state-diagram blocks. Point the author at `references/mermaid-emission-rules.md`.
4. **Wire it.** Invoke `validate-vault-flows.sh` from `post-tool-use` on `04-flows.md` writes, next to `validate-vault-flow-staging.sh` (`post-tool-use:660`), advisory/non-blocking — same tier as `validate-kb-flows.sh`.
5. **flow-coverage.** Verify (fixture) that with prose steps removed, `validate-flow-coverage.sh` uses its Mermaid-edge branch and still derives input-accepting steps. Change only if the fixture proves a gap.

**Fixtures (red→green):** a `04-flows.md` flow with prose numbered steps and no Mermaid → `validate-vault-flows.sh` FAILs; the same flow as a ` ```mermaid flowchart ` → PASS. Audit `tests/fixtures/code-delivery/**/04-flows.md` for prose-step flows and convert any that are run through the new validator, inside the same red→green (do not leave the suite red).

### Inc-3 — Doc propagation  *(cheap)*

- `references/mermaid-emission-rules.md` — widen the opening scope line to name every in-scope flow surface (KB §3, KB §8, vault `04-flows.md` flows) and "any future flow-emitting skill." State it in present tense; do **not** import the "Iter 72 / v3.64.0 / Fork-B-future" archaeology into the scope statement (that is the L11 version-archaeology class).
- `detect-drift/references/report-format.md` + `diff-vault/references/report-format.md` — one line each: a flow appended to `04-flows.md` is authored as a Mermaid flowchart per the `04-flows.md` contract.
- `generate-intent` flow-emission guidance (`SKILL.md`, `references/vault-contract.md`, `references/generation-guide.md`) — where they describe the `04-flows.md` flow, state the flow body is a Mermaid diagram (not prose steps).

## 5. Non-goals

- No full-render (`mmdc` → SVG, needs Chromium) in any automated gate — too heavy/offline-flaky. Render ground truth is the headless `mermaid.parse()` opt-in in `verify-mermaid.sh` (§3b Layer 2), not browser rendering.
- No hard block. The mandate is advisory C2, identical to every existing flow check.
- No change to `graph`, `emit-fsd`, or drift/diff *reports*.
- No auto-rewrite of prose→Mermaid (semantic-change risk; producer fixes).

## 6. Rollout

- Version: plugin-level SemVer bump on `plugins/mega-sdd/.claude-plugin/plugin.json`; `.claude-plugin/marketplace.json` **must** match. Per-skill `version:` bumps for `extract-intelligence` (Inc-1 gate), `generate-intent` (Inc-2 template), and any skill whose reference text changes (Inc-3). CHANGELOG entry.
- Tests named `test-*.sh` / `*.test.sh` so CI (`.github/workflows/tests.yml`) auto-discovers them.
- Ship order: Inc-1 → Inc-2 → Inc-3, each green before the next. Full suite green + `validate-pack.sh --all` + `--check-registry` before commit. Adversarial review before presenting the diff.

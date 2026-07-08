# Spec — Output language: default Indonesian-mix (extensible)

**Status:** draft · awaiting reviewer approval
**Type:** behavior change (runtime output language) — requires spec + test updates + reviewer ack per `plugins/mega-sdd/CLAUDE.md`
**Grounded on:** 5-mapper surface audit `wf_e736aeeb-af9` (2026-06-29)
**Tracking:** task #28

## Goal

Make mega-sdd's **runtime output** default to **Indonesian, mixing English technical terms per context** — so an Indonesian team gets native-language explanations out of the box, without each member relying on their personal `CLAUDE.md`. Non-Indonesian users stay fully served (all technical tokens remain English; one phrase switches the language), and the mechanism extends to **any** language with zero new code.

## User-approved decisions (locked)

1. **Scope = narration + human reports.** Localize: run-time chat narration; FSD body prose; recommendations. Stay English: vault structural fields, `AGENTS.md`, `vault.json` / `binding.md` structure, all Tier-1 tokens.
2. **Config = anchor default + chat override, no config file.** Default `id` baked into the always-injected anchor; switch in-conversation ("use English" / "pakai bahasa X"). Not persistent across sessions by design (lightest touch).
3. **No i18n catalogs.** The model is natively multilingual; we steer it with a policy + a do-not-translate list, not externalized string tables.

### Language precedence (the make-or-break — encodes "non-ID users stay served")
The policy resolves output language in this strict order, highest first:
1. **Explicit request this session** ("use English", "pakai bahasa Jawa") — wins over everything until changed.
2. **The language the user is writing in** — if their message is in English, narrate in English; in another language, mirror it.
3. **Indonesian default** — only for short / ambiguous / mixed-or-tokenless input (`gas`, `go`, `next`, `lanjut`, `ok`).

Tier-1 technical tokens stay English in **all** cases. This ordering is what serves non-ID users: an English-writing user gets English by rule (2), never a wall of Indonesian.

**Known limit (no-config consequence, surface to user):** the anchor re-injects "default id" on every compaction. A consistently-English user self-heals — each English message re-asserts English via rule (2). The residual edge: a non-ID user whose *first message after a compaction* is a bare continuation (`go`) briefly gets Indonesian until their next contentful message. The user chose "not persistent across sessions"; this extends that choice to "not persistent across compaction." Acceptable for the lightest-touch design; documented so it isn't a surprise.

**Second known limit (all-in-one greenfield):** if `generate-intent` creates `.mega-sdd/` and then `generate-units`/`execute-bolts` run *before any compaction*, those downstream skills are anchorless for that stretch (the anchor only re-injects at the next session start / compaction). They still narrate fine — generate-intent's own session set the language — and it self-heals at the first compaction. Noted so the coverage story stays honest.

## Core model — 3 tiers

Every output string falls in exactly one tier:

| Tier | What | Language |
|---|---|---|
| **1 — Frozen** | structural / machine-parsed tokens (full census → `references/output-language.md`) | **English always** |
| **2 — Narration** | run-time chat: announcements, halt/propose-confirm prose, recommendations, progress, questions | **Indonesian-mix (default)** |
| **3 — Artifact** | emitted docs | **per-audience:** FSD body prose + recommendations → ID; `AGENTS.md` / `vault.json` / `binding` structure → EN; **quoted/cited source content → source language** (citation fidelity) |

**Tier-1 do-not-translate list** (from the census — these are English words in machine-parsed positions, the highest accidental-translation risk; every one is parser- or test-pinned):

- Verdicts `CONFIRMED` / `CONFLICT` / `OQ`; IDs `C-NNN` / `CONFLICT-N` / `OQ-N` / `OQ-AR-N` / `FR-N` / `BR-N` / `D-N` / `F-N`.
- Implementation-State enum `IMPLEMENTED` / `PARTIAL_FIELDS_*` / `NEW` / `UNKNOWN`; confidence `high|medium|low` + `HIGH|MEDIUM|LOW`; `task_type` `create|extend|verify`; OQ `category` `business|tech` + `resolution_mode`; validator `PASS|FAIL`; mode `new|existing`; drift verdicts `KEEP_VAULT|KEEP_CODE|DEFER|SPLIT`.
- **Model-authored enums that read like prose but are validator-pinned** (caught in adversarial review — the *model* writes these, so the "script-emitted stays English" carve-out does NOT cover them): extraction scorecard `COVERED|PARTIAL|MISSING` + `overall_status` `PASS|PARTIAL|FAIL` (`validate-extraction-scorecard.sh`); handoff `status` (`validate-handoff-yaml.sh`); bolt verdicts incl. lowercase `pass|passed|ok` (`validate-bolt-artifacts.sh`). Elevated risk because the scorecard is authored by `extract-intelligence`, which this feature instructs to narrate in Indonesian.
- Mutability `[LOCKED]/[INTENT]/[ARTIFACT]`; confidence markers `[VERIFIED]/[INFERRED]/[OPEN]`; OQ priority `P1/P2` + status `[~]/[ ]/[x]`.
- Halt-escalation tiers `C1/C2/C3`; halt-type vocabulary (`conflict_unresolved`, `missing_*`, `test_fail`, `bind_conflict`, …); telemetry event/marker strings (`turn_end_marker`, `subagent_end_marker`, `halt_self_resolved`) + all telemetry/JSON/frontmatter **field names**.
- Anti-halu placeholders `[Pending — X]` / `_None detected_`; citation `sha256:` stamp + `[Source: <path>]`; generator directives `<!-- compact-skip -->` / `<!-- full-only -->`; `generated_by:` marker; status `draft|locked`.
- Doc **structural spine** parsed by validators/wikilinks: section headers (`## Purpose`, `## NFR`, `^FR-\d+`, `Implementation State Map`, `Open Questions`, `## Conflicts` / `### CONFLICT`, the KB 11-section header spine), `[[doc#Header]]` wikilink targets, DBML `Table … { }` blocks, KB `stages:` YAML + mermaid enums.
- Skill names, `/mega-sdd:*` command names, file/state-file paths, glyphs `✓ ⏸ ⛔`, the `CLEAR-<scope>` confirmation sentinel.
- **Script-emitted output stays English** (`list-modules.sh`, `analyze-parallelism.sh`, `query-graph.sh` — their labels/headers/JSON are asserted by executable `.sh` tests). Scripts are not localized; only model-generated prose is.

## What changes

### 1. The control seam (the actual default-flip)
**Grep-corrected scope (the spec's earlier "9 skills" = all directive-*carriers*; only 3 carry the *output* clause):**
- **Rewrite the 3 chat-output clauses** that today say *"chat prompts adapt to the user's language at runtime"* → the new default: **`generate-intent/SKILL.md:11`**, **`generate-intent/references/from-prompt-mode.md:11`**, **`generate-intent/references/vault-contract.md:603`**. Keep "reasons in English" + "generated docs match the input language" (unchanged). New output clause: *"narrate in Indonesian + English technical terms by default; precedence = explicit request > the language the user writes in > Indonesian; keep Tier-1 tokens verbatim English (→ `references/output-language.md`)."*
- **Add a policy sentence to the 4 greenfield entry points that have NO chat-language directive today** — **`orchestrate-flow/SKILL.md`**, **`extract-intelligence/SKILL.md`**, **`scan-codebase/SKILL.md`**, **`install-deps/SKILL.md`**. Each can be the *first* mega-sdd skill in a repo with no `.mega-sdd/` signal (`session-start` exits L75-76 → no anchor), so they must carry the default themselves. (Their hardcoded English "Announce at start:" examples stay as illustrative templates — the directive governs runtime language; a hardcoded ID string couldn't mirror an English user.) **`scan-codebase` is the corrected addition** (caught in adversarial review): it *creates* `codebase-map.md`, so on direct invocation (`scan codebase ini`, `init mega-sdd`) none of the anchor signals exist yet → it is anchorless, not a bound-session skill. **`install-deps`** (`pasang tools`) is the same anchorless class.
- **Deliberately leave the bound-session artifact-content clauses untouched** (`bind-codebase`, `generate-units`, `execute-bolts`, `detect-drift`, `resolve-oq`, `diff-vault`): they run only AFTER a vault exists (`.mega-sdd/` present → L1 anchor injected), and their *"recorded in the vault's existing language"* clause is the **correct Tier-3 per-audience behavior**, not a chat clause. Adding pointers there would spend hot-path tokens for no gain.

### 2. Anchor policy block (always injected, survives compaction)
Insert a `## Output language` block at `using-mega-sdd/SKILL.md:44` — **above** the `ANCHOR-CORE ends` marker (:45) so `session-start` re-injects it on startup/resume/clear/compact. ~+82 tokens/inject. Content: the default-ID policy **stating the precedence order** (explicit request > input language > ID default) + "structural tokens stay English (list → `plugins/mega-sdd/references/output-language.md`)" + the switch phrase. **`tests/anchor-diet/test-lean-anchor.sh` passes unchanged** — it asserts only kept-triggers + that specific detail headings are trimmed; it has no max-size cap and no "forbid stray additions" guard, so the new `## Output language` heading (not in its trimmed-detail list) doesn't trip it. *(Corrected in review: an earlier draft wrongly said this test "must" be updated.)*

**Anchor is CWD-gated — not the universal carrier.** `session-start` (verified L75-76) injects the anchor **only when an SDD signal exists in CWD** (`.mega-sdd/` etc.); no signal → `exit 0`, no anchor. So **greenfield `generate-intent` from a PRD in a fresh repo — a primary use case — gets no anchor**, and the policy reaches it only through the skill's own directive (change #1). Consequence for batching: **L1 (anchor) and L2 (control seam) are together the atomic "default ships" unit** — L1 carries warm/bound sessions, L2 carries direct/greenfield invocation; neither alone is complete. L2 is therefore not secondary cleanup.

### 3. New reference `plugins/mega-sdd/references/output-language.md` (EN, structural)
Houses the exhaustive Tier-1 do-not-translate list + the Tier-3 per-artifact table. Loaded on demand; itself an English directive doc (it mandates Indonesian but is not itself translated). Gets a `## Contents` ToC (>100 lines likely).

### 4. Tier-3 pointers (collapsed in L3 implementation — see note)
**Discriminating test (sharper than the original skill list): does the skill author *new prose into a plugin-owned standalone artifact*, or write into vault content / machine structure?** Only the former gets a Tier-3 pointer.
- **IN — `emit-fsd`** (FSD body prose; *the* core of L3 — it also flattens PRD/constitution excerpts, so it carries the **quoted-content fidelity note**: never translate a flattened source excerpt or a `[Source: sha256:…]` citation — reinforces invariant #3) and **`analyze`** (`CONSISTENCY-REPORT.md` analysis/recommendation prose).
- **OUT (corrected from the original list) — `detect-drift`, `resolve-oq`, `bind-codebase`:** they record into **vault content** (drift rationale, OQ resolution answers, verbatim-from-vault `binding.md` claims) → stays the vault's language; what they *say to the user* is Tier-2 chat, already governed by the anchor. Adding an artifact-language directive would brush the "don't translate vault docs" scope boundary.
- **OUT — `lint-units`:** not a prose-emitting skill (it is `commands/lint-units.md` + a framework-pack `_lint.md`), so it has no artifact prose to localize. Removed from the list (the original spec's "lint" reference was inaccurate).
- **Still OUT — `generate-units`** (machine unit specs; chat covered by the anchor) and **`emit-agents-md`** (AGENTS.md stays EN).
- **Census correction (mandatory, part of L3):** the shipped `output-language.md` Tier-3 row that read *"Recommendations / analysis prose (analyze, lint, drift, bind recs) → Indonesian"* is reworded to the surface split above — otherwise it is "prose that lies" (claims drift/bind artifact recs are ID while those skills are deliberately left vault-language, and names a non-existent `lint` emitter).

### 5. FSD nuance
FSD **body prose + headings the plugin authors** → Indonesian; **quoted/flattened source content** (PRD excerpts, constitution clauses, binding quotes) → **source language** (citation discipline — never translate a cited quote); the structural spine (`§` headers parsed by `section-mapping.md`, `[Source: sha256:…]`) → English.

## Switch & extensibility
- Default `id` (anchor). User says "use English" / "pakai bahasa Inggris" / "pakai bahasa Jawa" → model mirrors. Any language works because the model is multilingual and Tier-1 stays English regardless — no catalog, no code per language.
- Reasoning language is **unchanged** (English internally); only *output* language changes. These are independent.

## Test impact
- **Unchanged (verified green):** `tests/anchor-diet/test-lean-anchor.sh` — no max-size cap, the new heading isn't in its trimmed-detail list, so it passes as-is. (No update needed; an earlier draft wrongly listed it.)
- **Unchanged (and why safe):** every CI-hard `.sh` pin asserts a **Tier-1 token or script-emitted string**, all of which **stay English** — so localization cannot break them. `*.test.md` / `scenarios/*.md` are **not CI-executed** (soft pins; update opportunistically, not blocking).
- **New (REQUIRED — contract demands a test for a behavior change; without it the default can silently revert and the DNT list can drift).** A new `.sh` test pinning:
  - (a) the anchor `## Output language` block names **Indonesian** *and* states the **precedence order** (explicit > input language > ID default);
  - (b) `references/output-language.md` contains the full **Tier-1 enum families** — `CONFIRMED`/`CONFLICT`/`OQ`, `IMPLEMENTED`/`NEW`/`UNKNOWN`, `create|extend|verify`, `[VERIFIED]`/`[INFERRED]`/`[OPEN]`, `KEEP_VAULT`/`KEEP_CODE`/`DEFER`/`SPLIT`, `PASS`/`FAIL`;
  - (c) the canonical default-ID clause is present in the **3 generate-intent output-clause files** and a policy sentence in **orchestrate-flow + extract-intelligence** (the named change-#1 files), and the precedence keyword appears in each.

## Implementation batches (each: verify → apply → adversarial review → full CI → present)
- **L1 — Spine:** new `references/output-language.md` (DNT list + artifact table) + anchor `## Output language` block (with precedence) + `test-lean-anchor.sh` update + the new REQUIRED pin test. *(Carries warm/bound sessions; NOT sufficient alone — greenfield has no anchor.)*
- **L2 — Control seam:** rewrite the **3** generate-intent output clauses + add a policy sentence to the **2** anchorless greenfield entry points (orchestrate-flow, extract-intelligence); leave the 6 artifact clauses. *(Carries direct/greenfield invocation. **L1+L2 together = the atomic "default ships" unit;** ship them as a pair, not L1-then-maybe-L2.)*
- **L3 — Tier-3 pointers (shipped collapsed):** `emit-fsd` (the spine — FSD prose + quoted-content fidelity note) + `analyze` (report prose) one-line pointers, **plus the mandatory census correction**. `detect-drift` / `resolve-oq` / `bind-codebase` / `lint-units` were dropped from the original list after the discriminating test (above) showed they write vault content / are not prose emitters.

## Non-goals
- No persistent per-project language config (chat override only — user's choice).
- No translation of vault docs beyond their existing "PRD's-language" behavior (out of chosen scope).
- No translation of any Tier-1 token, script output, or machine-interop artifact.
- No change to internal reasoning language.

## Risks
- **Over-translation of enums fails *closed*, not silently — and that's the safety net.** If the model emits `task_type: verifikasi` into an *artifact*, the artifact validators (`validate-unit-spec.sh`, `validate-pack`, the vault/binding gates) **reject it loudly** — a hard FAIL, not a silent moat breach. The artifact-level validators **are** the real Tier-1 enforcement, which matters because the DNT list is loaded on demand and may not be in context at output time. **Verified (2026-06-29, read-only):** `validate-unit-spec.sh:169` asserts `task_type in ("verify","extend")` (literal); `validate-conflict-classification.sh` matches `CONFLICT-N`/`C-NNN`; `validate-kb-markers.sh:95,141` matches `[VERIFIED]`/`[INFERRED]` per-claim — each fails closed on a translated token. The Tier-1-bearing artifacts (unit spec, conflict/binding, KB) are gate-protected; this is the backstop, not the DNT prose. The genuinely unguarded surface is **Tier-2 chat narration**, where a mistranslated token is **cosmetic** (no parser reads chat), not a moat failure. So: moat-bearing positions are gate-protected; the localized surface is the cosmetic one. The DNT list + EN-token policy is the *first* line (reduce errors); the validators are the *backstop* (catch the rest).
- **Anchor token creep** — mitigated by pushing the list to an on-demand ref; only ~82 tok added to the hot path.
- **Citation fidelity** — quoted source content must never be translated; called out in the FSD nuance + Tier-3 rule.
- **Compaction revert for non-ID users** — covered under "Known limit" in the precedence section; self-heals for consistently-non-ID writers, one-message edge otherwise.

> **Amendment (2026-07-08 — the keterangan contract, user-mandated).** A live run was blocked by a human-facing prompt that showed only a code (an OQ tag / enum) with no explanation — unanswerable. `references/output-language.md` gains **§Prompt surfaces (AskUserQuestion / halt menus)**: every interactive surface MUST carry (1) the actual question/claim text — an ID alone is never a question; (2) source citation + one line of why-asked; (3) per-option keterangan — Tier-1 enum codes stay English as LABELS but every option carries a mandatory Tier-2 description of what choosing it does + consequence (a bare code or a literal `description: ...` placeholder is a violation); (4) exactly ONE recommended default with a one-line reason when one exists. Root fix: the halt displayer (`references/halt-protocol.md §Consumer dispatch`) — the single surface ALL halts funnel through — gains a mandatory step 0 that renders a plain-language keterangan block (resolve the tag to the quoted question/claim, why the chain stopped, glossed options) BEFORE the envelope YAML; previously the chat was mandated to show ONLY the raw YAML + a one-line hint, which is exactly where the user got a bare `OQ-AR-1`. Template fixes across 20 surfaces (audited 2026-07-08: a 3-reader fan-out inventoried 50 prompts — 1 BARE-CODE + 12 PARTIAL; a 2-reviewer adversarial round then caught 6 FURTHER missed surfaces — standalone execute-bolts halts, emit-agents-md's overwrite menu, the retrofit-review menu, the bolt-time TBD:OQ prompt, the diff_conflict producer template, a third `p1-only` default — plus 4 fabricated-UX glosses that asserted mechanics the plugin does not implement; the contract now names fabricated UX as a violation class worse than a bare code): resolve-oq (resume/scope/action-menu keterangan; the contradictory scope default unified on `all-priorities`; stakeholder Defer made ALWAYS reachable — it was unreachable in greenfield; CONFLICT menu gains the evidence anchor + prior-call slot; recommend-mode alternatives' descriptions made mandatory-and-grounded), bind_conflict/diff_conflict envelope schemas gain rationale/`{code, keterangan}` options, binding.md template gains the 4-enum legend + rationale'd Suggested action, diff-vault (git-safety/P1-P2 gloss/version-bump prompts), generate-units PARTIAL_FIELDS_SURPLUS review template AUTHORED (was an unwritten "prompt fires"), memory review ACCEPT/REJECT/DEFER consequences, extract-intelligence per-wave + twice-failed-gate menus defined, orchestrate-flow Run/Edit/Cancel + drift-gate CRITICAL/HIGH finding detail + MAJOR-without-plan + mode_migrate defaults. Pinned by `tests/interaction-keterangan/test-oq-prompt-keterangan.sh`.

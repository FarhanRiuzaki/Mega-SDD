# Code style playbook per tech stack — design spec

**Status:** APPROVED by owner 2026-09-16 ("gas spec + R1, OPEN-1 ya, OPEN-2 ikuti kode sekitar"). R1 ships as 8.1.0; R2 (24 packs + lint wajib) is a separate release.
**Research:** `research/2026-09-16-code-style-playbook-research.md` (klausul→permukaan, sensus kanal, tabel toolchain). Team input verbatim: `research/2026-09-16-team-feedback-java-code-style.md`.
**Doctrine:** gates > rules > hooks — this whole spec is a **style rule, never a gate** (F.5: no comment-counting validator, no `HARD_RULE` on comments). Evidence-first: the generic rule already measured −54 % ex-provenance comment lines (8.0.1); the per-stack delta earns its bytes by preventing L0 lint-gate collisions, not by restating the rule.

## 1. Owner decisions (closed)

| Item | Decision | Wording that lands |
|---|---|---|
| OPEN-1 doc-block licence | **YES** — extend from "a toolchain reads it" to **"or public API that crosses a module/team boundary"**; the delete test still governs the CONTENT (contract the signature cannot say, never the signature restated) | Iron Rule 6 + `_universal.md §Comment conventions` |
| OPEN-2 comment language | **Follow the surrounding code** — the file's existing comments, then its siblings'; a codebase with none → English (identifiers are English already); never two languages in one file | Iron Rule 6 + `_universal.md` |
| OPEN-3 channel | T2 `code_style_slice`, priority **7b** (after `framework_pack_rules` = 7a), ladder all → first two → first bullet, **floor = first bullet kept** (the doc-tool + read-by line is the lint-collision preventer — same "keep top 1" discipline as 7a) | builder + `context-enrichment.md` |
| OPEN-4 R2 rollout | one release (8.2.0), one commit per language family, lint switched to required in the last commit | R2 — out of this spec's build scope |
| OPEN-5 naming clause home | new paragraph **"Names do the explaining"** in `bolt-implementer.md §Code organization`; Rule 6 stays a comment rule | commit 1 |
| (new) `_universal.md` slice | **`_universal.md` does NOT carry `## Code style`** — the generic rule is agent-carried (Rule 6); a universal slice would re-send Rule 6 on every packless dispatch and drag pack prose into the framework-less golden corpus | research §6 R2 amended |
| (new) skeleton slots | **4** (tool + read by / skip / write / names) — the research's 5th slot "comment language" is generic → Rule 6, not the pack | `_template.md` |

## 2. The standard — `## Code style (self-documenting)` in every pack

Pack section = **stack delta only**. Generic rule lives ONCE in `agents/bolt-implementer.md` Iron Rule 6 (+ `_universal.md §Comment conventions` as the human-readable mirror). Skeleton (verbatim in `_template.md`):

```markdown
## Code style (self-documenting)   <!-- stack DELTA over Iron Rule 6 / _universal §Comment conventions — never restate the generic rule -->

> Consumed by `build-dispatch-prompt.sh` (T2 `code_style_slice`, priority 7b — `- ` bullets
> only; MOST-SPECIFIC pack wins, no chain merge; ladder all → first two → first bullet, the
> first bullet is the floor) for `bolt-implementer`, and by the controller inside the
> standards-lens slice. A STYLE rule, never a gate (F.5). ≤ 6 bullets, ≤ 1 200 bytes of
> bullets, at most ONE bad/good pair, ONLY what is specific to this stack.

- **Doc-comment tool**: <tool> — **read by**: <CONCRETE toolchain consumers + the config that turns them on, or `none by default`>. A full block only where one of these reads it, or on public API that crosses a module/team boundary.
- **Skip**: <this stack's vocabulary for members that never get a doc block>.
- **Write**: <the non-obvious contract in this stack's terms>.
- **Names carry the meaning**: <2–3 stack-idiomatic examples>.
```

Authoring rules: `read by` facts are **web-verified at authoring** (install-deps lesson: upstream facts rot) and the pack's `last_verified_against:` is bumped; no cross-framework tokens (Check 5); bullets single-paragraph (continuation lines indented are joined by the builder).

**First filled pack (R1): `spring.md`** — facts verified 2026-09-16 via Context7: Checkstyle `MissingJavadocMethod` default scope `public`, `@Override` exempt, accessors exempt only with `allowMissingPropertyJavadoc=true`; springdoc reads class/method/parameter Javadoc into OpenAPI descriptions when `therapi-runtime-javadoc` (+ `-scribe` annotation processor) is on the classpath and `springdoc.enable-javadoc` (default true).

## 3. Channel — T2 `code_style_slice` (builder contract)

- Source: `pack_section("Code style")` → **first hit only** (most-specific pack). `_universal.md` never carries it.
- Parse: `- ` / `* ` bullets; an indented continuation line joins the preceding bullet.
- Render: `## Code style (from <pack>.md §Code style — stack delta over Iron Rule 6; a style rule, not a gate)` + bullets; overflow line `(+N more — Tier 3: read the full pack §Code style)`.
- Ladder (priority 7b, stepped after 7a in the same pass): L0 all bullets → L1 first two → L2 first bullet (floor, never `""`). `unit_tier xs`: held at floor like `framework_pack_rules` (§1b "muatan, bukan bukti").
- Absent → `omit("code_style_slice", …)` with the chain named; `PACK_UNRESOLVED` → the UNKNOWN-not-empty wording (same discipline as `## Forbidden patterns`).
- EMIT order (template order): after `## Framework pack rules`, before `## Constitution clauses`.
- Spec surfaces updated in the same commit: `context-enrichment.md` table row 7b (+ never-`""` list, §XS emission table), `bolt-dispatch-prompt.md` block + Contents; `review-panel.md` standards slice = naming/location/idiom/**code-style**; `standards-reviewer.md` ground truth #2 names it.
- Pins: `plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh` `PRI` gains `code_style_slice: 7`; `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` D3 marker `## Code style` + D4 non-empty-reason rule; new `tests/comment-diet/test-code-style-slice.sh` (spring fixture → section present, first bullet survives at xs floor, packless → omitted with reason, no chain merge); dispatch-parity golden **regenerated** — legitimate change: every framework-less fixture gains one `sections_omitted` row (`code_style_slice`), nothing else.

## 4. Generic rule refinements (commit 1)

`agents/bolt-implementer.md`:
- Iron Rule 6: skip-list gains "non-public members with a self-explanatory name" and "overrides whose contract lives on the interface/base"; allow-list gains "a side effect, thread-safety or an exception the name does not imply", `FIXME`; tag example gains `@throws`; the docblock licence gets OPEN-1; new sentence for OPEN-2 (comment language).
- `## Code organization`: paragraph **Names do the explaining** (boolean predicate form, verb-first methods, plural collections, the vague names; "the urge to comment WHAT is a rename").
- `## Before reporting back: self-review`: **Comments** check (delete test; doc blocks only where read / boundary-crossing; no name needed a comment).
`references/framework-conventions/_universal.md §Comment conventions`: mirror of the three additions; the per-stack bullet now points at `## Code style` as the pack's home.
`agents/code-quality-reviewer.md` comment-what shapes: `@param`/`@return`/`@throws` restating the signature; a doc block on a non-public member with a self-explanatory name. "Missing docs" stays never-a-finding.
Pins: `tests/comment-diet/test-comment-why-rule.sh` n–s.

## 5. Pack kit (commit 2)

- `_template.md`: §2 skeleton inserted after `## Forbidden patterns`.
- `README.md` (packs): §Adding a new pack step 2 names the section + the web-verify rule; Files table unchanged.
- `_lint.md`: "Recommended now, REQUIRED from 8.2.0 (R2)" paragraph after Check 3; `validate-pack.sh` `_known_headers` gains `Code style` (Check 3b typo lint — no new violation class in R1).
- `spring.md`: filled section (§2), `last_verified_against: 2026-09-16`.
- Pin: `tests/per-stack-packs/test-code-style-section.sh` — every pack that carries the section has the 4 bold labels + `read by`, ≤ 6 bullets, ≤ 1 200 bytes of bullets; `spring.md` MUST carry it; `_template.md` carries the skeleton; `_universal.md` MUST NOT; `validate-pack.sh spring.md` clean; registry stays fresh.

## 6. Release + measurement

- **8.1.0** = commits 1–3 + CHANGELOG/bump; suite both trees + CI green; push GitHub (scm PENDING — office VPN).
- **No new measurement run here** (our xs/clinic scenarios are Laravel/TS). Evidence gate for "done": the team's next Java run on ≥ 8.1.0 (`claude plugin marketplace update` + `claude plugin update` first) → `benchmarks/scripts/p3-comment-ratio.py` per class (docblock / provenance / rest) + count of L0 lint reds caused by a missing doc comment (target 0) + 3-file spot check. Ask the team for the plugin version of the original run and 3 old bolt files for the before column.
- **R2 (8.2.0)**: 24 packs filled from research §4 (each `read by` web-verified), `_lint.md` Check 2 required + new label check, registry regen, `test-code-style-section.sh` extends to every `pack_tier: full` pack.
- **R3 (optional)**: `emit-agents-md` §Section 4 rows *Comment rule* + *Code style* (from the active pack) for non-mega-sdd sessions.

## 7. Deliberately not done

Comment-counting validator or gate (F.5); `HARD_RULE forbidden_pattern` on doc comments (would make a style rule a gate); merging `## Code style` across the pack chain (delta = one owner); a universal slice (duplication of Rule 6); per-language paragraphs inside Rule 6 (agent file stays lean); a measurement run on a non-Java scenario to "prove" a Java fix.

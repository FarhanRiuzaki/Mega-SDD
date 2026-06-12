# Documentation Efficiency Audit — 2026-06-11

**Scope**: user-facing docs — `README.md` (557 lines), `plugins/mega-sdd/README.md` (219), `tests/scenarios/README.md` (108), scenario files.
**Verdict**: the docs are comprehensive but fail the efficiency test on three counts: (1) **five facts are wrong today** (version drift proves the duplication problem is real, not theoretical), (2) **the same content is maintained in 2–3 places** with divergent copies, and (3) **~40% of the root README serves the maintainer, not the reader** (version archaeology, internal audit jargon). None of this needs more writing — it needs deletion and single-sourcing.

## The yardstick (what "efficient but on-point" means)

Distilled from [Diátaxis](https://diataxis.fr/start-here/), [Google's developer-doc style guide](https://developers.google.com/style/highlights), and README best-practice consensus ([freeCodeCamp](https://www.freecodecamp.org/news/how-to-write-a-good-readme-file/), [jehna/readme-best-practices](https://github.com/jehna/readme-best-practices)):

1. **One doc mode per page** (Diátaxis): tutorial / how-to / reference / explanation don't mix. A README is a *router* — orient, quick-start, link out. Depth lives in the page that owns it.
2. **Single source of truth per fact.** Every duplicated table/list WILL drift (this audit found it already has). Link, don't copy.
3. **Optimize time-to-first-success.** The newcomer's question is "how do I get one working result" — everything between them and that answer is cost.
4. **Inverted pyramid + scannability.** Most important first; short paragraphs; readers scan.
5. **No version archaeology in living docs.** Release narrative belongs in CHANGELOG — the same rule `plugins/mega-sdd/CLAUDE.md` already enforces for skill descriptions.
6. **Every section must answer a reader question.** A section that answers "what did we build and how proud are we" is for the maintainer, not the reader.

## Findings

### A. Wrong today (fix immediately — these mislead readers right now)

| # | Where | What's wrong | Fix |
|---|---|---|---|
| A1 | `README.md:400` | "Currently **4.10.0**" — actual is 4.20.1 | Delete the version + feature claim from the sentence entirely (it duplicates the header badge; that's WHY it drifted) |
| A2 | `README.md:347` vs `:486` | "26 slash commands" vs "25 slash commands" in the same file (actual: 26) | State the count in ONE place, or drop the number |
| A3 | `tests/scenarios/scenario-1:10`, `scenario-2:10` | "Mega-sdd v3.40.0+ installed" — a v3-era pin in v4.20 docs | "Mega-sdd installed ([install check](README.md))" — no version pin |
| A4 | `tests/scenarios/README.md:104` | Version check `cat plugins/mega-sdd/.claude-plugin/plugin.json` only works inside THIS repo — a user in their own project gets file-not-found | Replace with `/plugin` (works everywhere) |
| A5 | `tests/scenarios/README.md:47` | `brew install …` as the recommended path — macOS-only, contradicts `/mega-sdd:install-deps` guidance everywhere else | Replace with `/mega-sdd:install-deps` + link to tooling-install.md |

### B. Duplicated sources of truth (the drift engine)

| # | Content | Copies | Already diverged? |
|---|---|---|---|
| B1 | Anti-hallucination defense list | root README (18 items) + plugin README (19 items) | **Yes** — different counts, different wording |
| B2 | Scenario chooser table | root README (7 rows) + plugin README (11) + scenarios README (14) | **Yes** — three different row sets |
| B3 | Install instructions | root + plugin + scenarios READMEs | **Yes** — A5 above |
| B4 | Update instructions | root + plugin READMEs | Not yet |
| B5 | Command reference | root "Other commands" table + plugin command table + root cheat-sheet | Partially (A2) |

**Rule going forward** (single owner per fact; everyone else links with one teaser line): scenarios table → `tests/scenarios/README.md` · command reference + defense list + optional-tools table + memory → plugin README · install/update/uninstall → **root README** (the landing page owns time-to-first-success; tutorials like Scenario 0 may inline commands as part of the learning path) · release history → CHANGELOG.md.

### C. Bloat — serves the maintainer, not the reader

| # | Where | Problem | Recommendation |
|---|---|---|---|
| C1 | `README.md:199` (§6 "Audit-driven evolution") | ~280 words of v4.4→v4.20 release narrative — version archaeology in a living doc | Cut to 2 sentences ("every major version closes a structured audit; full trail in CHANGELOG/AUDIT.md") + links |
| C2 | plugin README "What's new" | **17 version entries, ~1,100 words** — a second changelog | Keep latest 2–3, link CHANGELOG. (Drift-prone by design: every release edits two files.) |
| C3 | Root README 18-item defense list | Items 11–18 are internal audit vocabulary ("de-vacuoused conflict-classification gate", "FMEA", "producer→consumer matrix") — meaningless to a reader deciding whether to use the tool | 6 reader-meaningful layers + one link to the full list (plugin README or a reference doc) |
| C4 | Root README overall (557 lines) | Mixes marketing + tutorial routing + reference (halt types, folder layout, flags) + explanation + changelog narrative — every Diátaxis mode on one page | Target ≤250 lines: pitch → start-from-zero → quick start → why (short) → pipeline diagram → links. Reference detail moves to plugin README / references/ |
| C5 | Mermaid pipeline diagram (~95 lines) | Genuinely good explanation, but with C1–C3 around it the page is a wall | Keep — it earns its space once the rest shrinks |

### D. Gaps (small, cheap, high-value)

| # | Missing | Why it matters |
|---|---|---|
| D1 | Uninstall / disable instructions | A standard reader task; absence reads as lock-in |
| D2 | "Which doc do I read?" line at top of each README | One sentence per doc stating its job prevents re-bloat (each doc's scope becomes testable) |

## Remediation order

1. **A1–A5** — five one-line fixes, zero risk. *(~10 min)*
2. **B2/B3/B4** — de-duplicate tables/install to single owners + links. *(~30 min)*
3. **C1–C3** — the big deletions (≈350 lines net across both READMEs). *(~45 min)*
4. **C4 restructure + D1/D2** — reshape root README as a router. *(~45 min)*

Expected result: root README 557 → ~250 lines, plugin README 219 → ~140, **zero duplicated facts**, every doc one Diátaxis mode.

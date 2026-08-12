# Playwright embed — MCP bundling, /slice verb, UAT automated-evidence lane, interactive design lens

**Date:** 2026-08-12
**Status:** P1 SHIPPED v6.8.0 (2026-08-12, 64dfdd0, CI green, suite 221/221) — implementation round 0B/5M/8m ALL folded (4-verb doc sweep, --rounds + paths.md on-record, compact-core anchor guard C1b/C2b); registration smoke check (/mcp on fresh enable) + office npx cold-cache verification = PENDING USER. P2 (D2 UAT evidence) + P3 (D3 design lens) NOT started. Design provenance: user-approved §1–§5 dialog 2026-08-12; D2 shape corrected post-approval against the emit-uat moat (§D2 header note); 4-lens blind recon folded pre-implementation (3 BLOCKER roots + 8 MAJOR + 10 minor — §Recon disclosure)
**Source:** USER mandate — "gue pengen embed playwright di mega-sdd"; Q&A locked: hybrid MCP+script; `/mega-sdd:slice` standalone verb (user decision, on record); UAT generate+run+attach; design lens interactive upgrade.
**Version plan:** P1 = 6.8.0 (D0+D1, SHIPPED); P2 (D2) and P3 (D3) each take the next free minor at their own ship time (renumbered once already: 6.9.0 went to the Context7 embed, spec `2026-08-12-context7-embed.md`); every phase ships through the full cadence (spec → proof tests → blind round → fold → both-tree suite → ship).

## Why (no-gimmick justification)

1. **"Install mega-sdd → Playwright otomatis ada"** — the plugin already *consumes* browsers opportunistically (`scripts/capture-views.sh` tries system Chrome then `npx playwright`); bundling the official Playwright MCP closes the loop: zero-setup browser tooling for every install, CONFIRMED mechanism (`.mcp.json` at plugin root auto-registers on enable; tool-search deferred by default so context cost is names-only; per-server disable via `/mcp` keeps it non-coercive).
2. **Slicing is a real, frequent task class** at the user's org (Figma/web reference → UI code) that today has NO mega-sdd entry with zero vault barrier. `/slice` reuses the existing design-intelligence corpus (`ui-design-heuristics.md`, `design-intelligence/{style-principles,ux-rules}.md`) and the framework packs — no new design knowledge is authored.
3. **UAT evidence** — the SEOJK berita acara lane is deliberately anti-fabrication (`execution_fabricated` gate); an automated Playwright run produces the one thing prose cannot: replayable, auditor-verifiable machine evidence. The lane makes the honest surface RICHER without touching the human capture moat.
4. **Design lens ceiling** — the render gap is already documented in `review-panel.md §Live-app capture`; interaction states (hover/focus/error) are the cheapest missing input for ceiling judgment.

**Trade-off on record — deliberate surface growth (recon BLOCKER 1).** `/slice` is a NEW verb after the v6.0.0 surface cull (3 verbs + 4 one-timers). The user chose the standalone verb over embedding in the bolt loop, explicitly. Verb ADDITION sits outside the demotion ladder (which governs alias/removal only), so P1 amends the growth on-record, in the same commit as the new file — never a test loosened after the fact:
- `plugins/mega-sdd/CLAUDE.md` — BOTH "exactly 7 files, nothing else" sentences (§Architecture + §Authoring standards) → 4 verbs / 8 files, citing this spec + the user decision.
- `tests/surface/test-p6-front-door.sh` §C2 — count 7→8 AND `slice.md` added to the kept-file roster (so the next cull round treats it as pinned, not a stray).
- `commands/mega-sdd.md` "three public verbs" blockquote + README wherever it repeats the count.

**Containment (unchanged):** `/slice` is **command-invocation only** — NO free-text census keywords, NO anchor-core routing line, body-only mention in `using-mega-sdd` (the delta-bullet precedent, below the `ANCHOR-CORE` marker); routing surfaces (`orchestrate-flow`, `commands/mega-sdd.md`) do NOT auto-route free text to it.

## Shared degradation doctrine (binding for every D)

Playwright availability is NEVER load-bearing. Ladder: Playwright MCP (interactive) → system Chrome headless (static) → `npx playwright` CLI (static) → graceful SKIP with a stated reason. **No gate anywhere may depend on a browser being present.**

Two DISTINCT unavailability rungs, both named (recon MAJOR — the office case is the design case):
1. **Browser binary absent** (~130MB Chromium): never bundled, never auto-installed — `install-deps` DETECTS and OFFERS (`npx playwright install chromium`), the human decides (Chrome detect-only doctrine, extended).
2. **MCP server itself unavailable**: `npx -y @playwright/mcp@0.0.79` (the §D0 pin) must fetch the *package* from the npm registry on cold cache — on the gov network that may be blocked; offline = the server fails to start; CrowdStrike taxes the npx→node spawn chain at every session start; Windows `"command": "npx"` stdio spawn (cmd shim, Git Bash floor) is UNVERIFIED until run on the user's office machine. A failed server start degrades to the static rungs; the office mitigation for repeated startup failures is the `/mcp` per-server disable. **P1 ships with a verification step on the user's office machine** (npx cold + warm cache, Git Bash) before the floor version is raised.

## D0 — Packaging: bundle the Playwright MCP (P1)

- NEW `plugins/mega-sdd/.mcp.json`:
  ```json
  {
    "mcpServers": {
      "playwright": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@playwright/mcp@0.0.79", "--headless", "--isolated"]
      }
    }
  }
  ```
  - **Version PINNED exact, never `@latest`** (install-deps audit lesson: registry facts rot; a bump is a deliberate release decision, not a surprise at the user's session start). Web-verified at P1 implementation (2026-08-12): `0.0.79` latest on registry.npmjs.org (Node >=18); `--headless` + `--isolated` flags confirmed at github.com/microsoft/playwright-mcp. `--isolated` (in-memory profile) added beyond the draft JSON: the user runs parallel sessions on one tree, and persistent profiles cannot be shared between concurrent instances.
  - One server, stdio, no `env`, no `alwaysLoad` (deferred tool-search keeps context cost to names only).
  - The pin joins the release checklist in `plugins/mega-sdd/CLAUDE.md §Versioning` (reviewed at each bump, like marketplace.json parity) — a second registry-rot surface needs a cadence hook (recon minor).
  - P1 ship-gate includes a one-time **registration smoke check**: the server appears in `/mcp` on a fresh enable (the "auto-registers" claim gets exercised once, not just asserted).
- **NO new tool-matrix row** (recon MAJOR fold — decision): a row would bump the ==10 pins in BOTH layers of `test-tool-matrix.sh`, need a defaults-group + `used_by` resolution, and its `verify_cmd` would have to be an exec-probe (`npx playwright --version` auto-fetches from the registry when absent — exactly the v5.8.0→5.9.0 unbounded-probe class). Instead, follow the **Chrome precedent exactly** (a detect-only notes line, no row): `install-deps` SKILL gains a detect-and-offer paragraph — probe the Playwright browser cache path (filesystem check, offline, bounded), offer `npx playwright install chromium`, never auto-run. Pinned by a doc test, zero matrix churn.
- Docs: README + `install-deps` SKILL note the bundled server, the first-use download, and the `/mcp` per-server disable.
- **Proof tests (P1):** `.mcp.json` shape pin (valid JSON, exactly one server key `playwright`, version regex forbids `@latest`/floating tags); install-deps detect-and-offer doc pin (offer-only wording); p6 §C2 amended pin (8 files + roster) ships in the same commit as `slice.md`.

## D1 — `/mega-sdd:slice` — standalone slicing verb (P1)

**Entry:** NEW `commands/slice.md` (thin CLI entry, `install-deps.md` pattern: description + argument-hint frontmatter, body dispatches the skill) → NEW skill `skills/slice-design/` (SKILL.md + `references/slice-procedure.md`). Inputs, at least one required:
- `--figma=<url>` — consumed via the user's own Figma MCP when present; absent → ask for an exported image instead (never scrape).
- `--url=<web>` — reference site, captured via Playwright MCP.
- `--image=<path>` — exported design file.
- `--rounds=<n>` — compare-round override, hard cap 3 (cap semantics unchanged; recorded post-draft at P1, same on-record style as `--isolated`).

**Loop (cap: 3 compare rounds, then report honestly):**
1. Reference intake → component inventory (≤3 clarifying questions max — where in the repo, which route, which framework — with keterangan per the OQ rule).
2. Implement following the ACTIVE framework pack + the design-intelligence corpus (REUSE: `ui-design-heuristics.md`, `design-intelligence/{style-principles,ux-rules}.md`). If a vault exists, its `design_system` tokens are an optional enrichment — **`/slice` NEVER writes the vault or binding**; it is a code-emission verb only.
3. Render via Playwright MCP against a dev-server URL (`.mega-sdd/config.yaml` `preview_url:` or operator-supplied) → screenshot → model-judged compare vs reference (NO pixel-diff dependency — no new tooling) → iterate.
4. Emit `slice-report.md` under the mega-sdd output root — `.mega-sdd/slices/<slug>/slice-report.md` (recon minor: plugin artifacts never land in the user's source tree; `references/paths.md` gains the `slices/` entry + a slice-design per-skill row): files created, reference mapping, remaining deltas (honest), and — when MCP/browser/server was absent — the literal statement that the render was NOT verified. Code generation still happens without a browser; only the compare loop degrades.

**Dev-server ownership (binding, recon MAJOR):** the dev server is OPERATOR-owned — `/slice` NEVER starts, installs, or backgrounds a server process (the unbounded-spawn class; also a zombie hazard under Git Bash/EDR). Unreachable `preview_url` → compare rounds = 0 + the honest-skip statement, mirroring `capture-views.sh`'s "start it, then re-run" contract. The sentence is pinned by a D1 contract test.

**Proof tests (P1):** trigger fixture `slice.test.md` (command fires; free-text slicing prose does NOT); contract pins — description census-free (delta-lane 9a/9b/9c precedent), no-vault-write pin, cap-3 + honest-skip wording pins, never-starts-a-server pin, report-location pin; **anchor-core budget guard with a DEFINED method** (recon minor: the carried 3587/3600 figure reproduces nowhere — the new test captures the byte length of the awk-extracted `ANCHOR-CORE` region of `using-mega-sdd/SKILL.md` as a baseline constant; any growth fails until deliberately re-baselined).

## D2 — emit-uat: automated-evidence lane (P2)

> **Shape correction vs the approved dialog design (flagged):** the dialog said *"status 'executed' di berita acara HANYA dari evidence pack"*. That collides with the emit-uat moat pin #1 — *execution results are NEVER model-authored; xlsx + berita acara are the HUMAN capture surfaces* (`execution_fabricated` gate) — and with SEOJK semantics (a Playwright run is not user acceptance). Corrected shape: automated results live in their OWN script-rendered annex; the human execution cells stay human. The user's intent (no fabricated "executed" claims; real evidence in the doc) is preserved and strengthened.

**IDs ride the existing grammar** (recon MAJOR): scenario ids are `UAT-NNN` / multi-scope `UAT-<SCOPE>-NNN`, paired 1:1 with SIT `TS-*` ids — spec files are `<vault>/uat/e2e/UAT-001.spec.ts`, evidence dirs `<vault>/uat/evidence/UAT-001/<run-ts>/` (run-stamped subdirs: a later run never overwrites the audit trail; the annex reads the newest). No new id scheme.

**Generation — explicit labor split (recon MAJOR; "the script maps Aksi rows" was wrong — step rows are model-authored Indonesian prose with no selectors):**
- NEW `scripts/build-uat-e2e.sh` deterministically emits ONE skeleton per scenario from SCAFFOLD data (scenario id, flow id, title, step count), every step `test.fixme('<Aksi text> — manual')` by default. It also writes `<vault>/uat/e2e/.gitignore` (`node_modules/`, `test-results/`) — evidence packs themselves are commit-intended (they ARE the auditor record).
- Selector/route substitution is a MODEL step gated by a deterministic lint: every non-fixme action line MUST carry a `// source: <path>:<line>` anchor; `build-uat-e2e.sh --check` resolves each anchor against the real file (citation-map style) — an unresolvable anchor reverts that step to fixme. Zero-invented-selector is a GATE, not prose.
- Generation stamps the source `UAT.md` + `.uat-scaffold.md` sha256 into each spec file header.

**Execution:** NEW `scripts/uat-run.sh` (offered — needs `preview_url` + Node): self-contained Playwright setup under `uat/e2e/` — **never mutates the target repo's `package.json`**. **P2 field amendments (live-proven at implementation, recorded per the field-patch policy):** `uat/e2e/` gets its OWN `package.json` pinning `@playwright/test` EXACT (a dep-less repo cannot resolve `@playwright/test` from the npx cache — proven live; the pin joins the CLAUDE.md §Versioning registry-rot checklist); first run provisions `node_modules` via a BOUNDED `npm install` rung (fail → SKIP); an installed-package↔browser-build mismatch ("Executable doesn't exist") is a provisioning SKIP, never fail-count evidence; unreadable/unstamped result.json renders `UNREADABLE — jalankan ulang` (fail closed). The run is process-GROUP bounded (killpg on timeout — no orphaned browsers); runs `npx playwright test` with `</dev/null` and a **bounded timeout (default 120s, `--timeout=<sec>` — the `run-acceptance-tests.sh` convention; a hang is never possible)**; writes `evidence/UAT-NNN/<run-ts>/{result.json, screenshots/, trace.zip}`. `result.json` carries the executed spec file's sha256 + the generation-source shas. Missing prereqs (no Node / no browser / no URL / server down / registry blocked / timeout) → SKIP with reason.

**Evidence is a guarded artifact class (recon BLOCKER 3):** `<vault>/uat/evidence/**/result.json` joins the anti-self-bypass write-guard roster (`uat-run.sh` is the sole writer; direct + common programmatic writes hook-denied). **Honest scope (round-corrected):** the §5 gate recomputes the RENDER of result.json, not the evidence itself — result.json integrity rests on this write-guard, whose documented os.replace/variable-indirection residual is load-bearing here (unlike B1's git/fs ground-truth recompute); the renderer adds a written_by/run_ts sanity floor (mismatch → UNREADABLE, fail closed). Without this, a forged result.json launders fabricated "Pass" rows through the legitimate render path — the prose-asserts-closed-breach class. Proof arms land in BOTH test trees (main-CI-red lesson).

**The annex — region grammar pinned (recon BLOCKER 2):**
- A NUMBERED heading: `## 5. Lampiran — Eksekusi Otomatis (pre-UAT)`, placed after §4 — the numbered form closes §4 in the shipped `check_execution` parser (the only section-transition is `^## (\d+)\.`) and fits the citation-map `## N.` grammar (§4's zero-source-footer precedent covers a section citing no vault artifacts).
- Template slot `{{annex_eksekusi_otomatis}}` is ALWAYS present and ALWAYS filled (so the Step 4.5 `{{slot}}` scan never sees a hole and the emission-engine `[Pending]` rule is not deviated from): the script-rendered table (scenario id → run status → evidence paths → STALE marker) when evidence exists, else the literal line `_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._`.
- Renderer: `build-uat-e2e.sh --annex` recomputes the table from `result.json` on disk (recompute-at-gate doctrine, B1 precedent) — the model NEVER types annex rows. **Staleness (recon MAJOR):** evidence whose stamped shas don't match the current doc renders a literal `STALE — bukti dari versi dokumen sebelumnya, jalankan ulang` marker, never presented as current.
- `build-uat-scaffold.sh check_execution()` extends to treat §5 as script-owned (a model-filled annex row = `execution_fabricated`) — and because BOTH check paths share `check_execution()` (the `--check-execution` invocation AND the Step-0 default-mode re-emit guard), a legitimately-filled annex passes BOTH (proof arm: annex-bearing UAT.md with clean human cells → exit 0 — the attack-own-proof-test-assertions lesson).

**Re-emit shape (recon MAJOR — evidence always arrives AFTER first emit):** annex refresh is an ANNEX-ONLY script operation (`build-uat-e2e.sh --annex` rewrites §5 in place), NOT a full model re-emission: no maturity change (a human-set `ready-for-uat` rung is never demoted), Step 6.6 xlsx render NOT triggered (no version proliferation while testers fill the previous workbook), and the change-note grammar gains one derived case — `Lampiran eksekusi otomatis diperbarui — <n> skenario` (from result.json, never free prose) — recorded via the existing stamp lane.

**Named files (recon MAJOR — the closed inventories this touches):** `uat-template.md` (annex slot), `uat-sections.md` (section map + annex rules), `emit-uat/SKILL.md` (Step 3 assembly, Step 4.5 scan, Outputs block, halt list), `references/paths.md` (uat/ subtree gains `e2e/` + `evidence/`), `references/halt-protocol.md` (**adds the missing `execution_fabricated` registry row** — pre-existing gap: the canonical subtype enum lists sibling `signoff_fabricated` but never admitted `execution_fabricated`; the row names the classic §2–§4 regions AND §5), `build-uat-scaffold.sh`, plus the two new scripts. Teacher↔template parity (p12) gets an annex arm.

**Human surfaces untouched:** xlsx workbook + berita acara + sign-off cells remain the SEOJK record; xlsx exit-3 REFUSE unweakened.

**Proof tests (P2):** generation arms (skeleton per scenario, all-fixme default, anchor-lint: resolvable anchor kept / unresolvable reverts to fixme / zero-anchor non-fixme line → fail); uat-run graceful-skip arms (no node / no browser / no URL / server down / registry blocked / **timeout → SKIP never hang**); evidence-guard arms in BOTH trees (Write/Edit of result.json denied; Bash-forged result.json → annex refuses); annex arms (forged annex row → gate fires; evidence present → rows byte-match result.json; no evidence → literal placeholder line; **legit annex → both check paths pass**; stale shas → STALE marker); re-emit arms (annex-only refresh leaves maturity + xlsx untouched); teacher-parity annex arm.

## D3 — Design lens: interactive capture (P3)

- The execute-bolts CONTROLLER (not the lens) may use Playwright MCP tools directly — when available — to capture **interaction states** (hover/focus/form-error) + breakpoints into `<bolt-dir>/views` as a NAMED EXTENSION of the `capture-views.sh` contract (recon minor: the old naming would collide across routes): files are `<slug>-<state>-<width>.png` (state ∈ `hover|focus|error|base`), and the controller synthesizes the same JSON `{skipped,...,shots:[...]}` record the script emits, so the lens consumes ONE contract regardless of rung.
- `review-panel.md §Live-app capture` gains the MCP rung at the TOP of the existing ladder (MCP interactive → system Chrome static → npx static → SKIP).
- `design-reviewer` input contract notes the new capture classes; judgment doctrine unchanged: **capture never a gate**; a lens with no render says so.
- The known-open `--out=<bolt-dir>/views` → `lens-inputs/` move stays open and is NOT bundled here (carried in `context-enrichment.md §Known open`).
- **Proof tests (P3):** review-panel doc pins (ladder order, never-a-gate wording); naming-contract + JSON-record pins in review-panel/design-reviewer.

## Non-goals

- No auto-install of browsers, ever (offer-only via install-deps).
- No new tool-matrix row (Chrome notes-line precedent; the ==10 pins stay).
- No pixel-diff / visual-regression dependency (model-judged compare; YAGNI).
- `/slice` never writes vault/binding; it is not a scan/bind alias and never enters the census; it never starts a server.
- UAT human execution / sign-off cells are never auto-filled — moat pin intact and EXTENDED, not weakened.
- No replacement of the user's Figma MCP (consumed if present; image fallback otherwise).
- No new halt TYPES; anything new rides existing `quality_gate_failed` subtypes / SKIP reasons.
- Core verbs, binding chain, and gates untouched except the named files above.

## Open constraints for implementation (binding rules, not TBDs)

1. Exact `@playwright/mcp` version + headless flag + `playwright install` command: **web-verify at P1 implementation**, then PIN (registry-rot lesson); the pin joins the CLAUDE.md §Versioning release checklist.
2. Anchor budget: the D1 test defines the reproducible method (byte length of the awk-extracted `ANCHOR-CORE` region, baseline constant in the test); the anchor core does NOT grow for `/slice`.
3. Windows arms: every new script gets the `</dev/null` + resolve-python + Git Bash path-semantics + **bounded-timeout** treatment; nothing spawns unbounded probes (v5.8.0→5.9.0 lesson). `.mcp.json` is NOT a script — its Windows behavior (npx cmd shim, cold-cache fetch, CrowdStrike) is verified on the user's office machine at P1 (§Shared degradation doctrine rung 2).
4. `uat-run.sh` invocation form for a repo WITHOUT Playwright in its own deps (self-contained `npx` run) is proven by a live arm at P2, not assumed.

## Recon disclosure (4 blind lenses, pre-commit — all folded)

3 BLOCKER roots: (1) the exactly-7 command-surface pin (test-p6 §C2 + CLAUDE.md ×2 + mega-sdd.md blockquote) had no scheduled amendment — now a named P1 deliverable, same-commit, on-record; (2) an unnumbered annex heading parses as still-inside-§4 → false `BA_FILLED`/`SIGNOFF` halts + permanent Step-0 re-emit refusal — now a numbered `## 5.` heading + both-check-paths extension + false-positive proof arm; (3) `result.json` was unguarded — forged evidence would launder through the legitimate render path — now a hook-guarded artifact class (B1/B4 precedent) with both-tree arms. MAJORs folded: tool-matrix row REPLACED by the Chrome notes-line precedent (==10 pins + verify_cmd registry-fetch hazard avoided); the script-maps-Aksi claim corrected to an explicit script/model labor split gated by a deterministic anchor lint; re-emit/versioning interaction defined (annex-only refresh, no maturity demotion, no xlsx proliferation, derived change-note); evidence staleness stamped + rendered; the closed file inventories (template slots, section map, paths.md, Outputs, halt registry) named; the MCP package-fetch rung named with an office verification step; bounded timeout on `uat-run.sh`; dev-server ownership pinned. Minors: `UAT-NNN` id grammar (S-XX invented nothing), run-stamped evidence dirs, `.gitignore`, halt-protocol registry row, slice-report under `.mega-sdd/slices/`, anchor-budget counting method, `.mcp.json` release-checklist hook + registration smoke check, D3 naming/JSON-record contract.

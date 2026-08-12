# Playwright Embed P2 (v6.10.0) Implementation Plan — UAT automated-evidence lane

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship spec §D2 of `docs/superpowers/specs/2026-08-12-playwright-embed-design.md` — Playwright spec generation per UAT scenario, an offered bounded run producing an auditor evidence pack, and a script-owned §5 annex in UAT.md whose content can never be model-fabricated.

**Architecture:** One shared renderer (`scripts/_lib/uat_annex.py`) is the single source of §5 truth — `build-uat-e2e.sh --annex` WRITES its output, `check_execution()` RECOMPUTES it and byte-compares (B1 recompute-at-gate precedent). `result.json` becomes a hook-guarded evidence class (sole writer `uat-run.sh`, run-* precedent). Everything degrades to SKIP-with-reason; the human capture surfaces (§2 cells, xlsx, berita acara, sign-off) are untouched.

**Tech Stack:** bash + python3 (resolve-python), Playwright via `npx playwright test` (self-contained config, target repo's package.json never touched).

## Global Constraints

- Spec of record: `2026-08-12-playwright-embed-design.md §D2` (recon-hardened). IDs = `UAT-NNN` / `UAT-<SCOPE>-NNN` (never S-XX). Annex heading = EXACTLY `## 5. Lampiran — Eksekusi Otomatis (pre-UAT)` (parser is `^## (\d+)\.`-keyed; APPENDED after §4, never inserted before).
- Moat pins intact: execution results NEVER model-authored; §2/§3/§4 checks unchanged; xlsx/berita-acara/sign-off untouched; no new halt TYPES (`execution_fabricated` gains violation code `ANNEX_FORGED`).
- Bounded everything: `uat-run.sh` mirrors `run-acceptance-tests.sh` (default 120s, `--timeout=<sec>` integer-validated, `</dev/null`, stdin=DEVNULL, fail CLOSED, atomic tmp+os.replace, `written_by` stamp).
- Hook guard tandem rule: the Write/Edit elif AND the Bash `PROTECTED` roster AND the `GUARD_SKIP` prot regex change in the SAME edit (a solo PROTECTED edit is inert). Write/Edit regex is vault-prefix-anchored (S6 EB-VAL-7); deny messages 841 + 1033 extended to name `uat-run.sh`. Guard tests build fixtures OUTSIDE the repo (plugin-dev-mode exemption) and assert reason text + `"permissionDecision": "deny"` together.
- p12 hazards: never write the literal `| 1 | <Aksi> | <Expected Result> |` in SKILL/template; preserve `OWNED by \`references/uat-sections.md §Section 2\`` and `adds no rules of its own` verbatim; the §5 pair REQUIRES a new p12 arm.
- Evidence layout must not contain path segments named `tests/`, `examples/`, `fixtures/` (guard exemption hole — run dirs are UTC timestamps, safe by construction).
- §5 is backward-compatible: `check_execution` §5 branch fires ONLY when a `## 5.` heading exists (pre-6.10.0 docs pass untouched).
- Repo rules: never `git add -A`; suites `</dev/null`; both-tree suite after ALL edits; trailers `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01JRFsor81mkZxbmivABixCy`.

---

### Task 1: `scripts/_lib/uat_annex.py` — the shared §5 renderer (single source of truth)

**Files:**
- Create: `plugins/mega-sdd/scripts/_lib/uat_annex.py`
- Create: `tests/uat-e2e/test-uat-annex-render.sh`

**Interfaces:**
- Produces: `render_annex(vault_dir: str) -> str` — deterministic §5 body (heading line through last content line, no trailing blank); consumed by Task 4 (`--annex` writer) and Task 5 (`check_execution` byte-compare).
- Contract: NO evidence dirs → returns heading + blank + the literal `_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._`. Evidence present → heading + blank + table `| Skenario | Status | Run | Bukti |` with one row per `evidence/UAT-*/` (NEWEST run-ts subdir), Status from result.json `status` field (`Pass`/`Fail`/`Skip` counts as `<p>/<f>/<s>`), Run = the run-ts, Bukti = relative evidence dir path; a row whose result.json `uat_md_sha256` ≠ current UAT.md sha renders Status as `STALE — bukti dari versi dokumen sebelumnya, jalankan ulang`. Malformed/unreadable result.json → row Status `UNREADABLE — jalankan ulang` (fail closed, never guessed). Rows sorted by scenario id.

- [ ] **Step 1: Write the failing test** — `tests/uat-e2e/test-uat-annex-render.sh` (sibling header style, `</dev/null`, resolve-python). Arms: (a) no-evidence render == placeholder literal; (b) one Pass evidence pack → table row with status/run/bukti; (c) sha mismatch → STALE literal in the row; (d) corrupt result.json → UNREADABLE; (e) determinism — two renders byte-equal; (f) newest-run-wins with two run-ts dirs. Fixture = mktemp vault dir with `uat/UAT.md` + `uat/evidence/UAT-001/<ts>/result.json` shapes.
- [ ] **Step 2: Run — expect FAIL** (module absent).
- [ ] **Step 3: Implement `uat_annex.py`** — pure stdlib; `ANNEX_HEADING = "## 5. Lampiran — Eksekusi Otomatis (pre-UAT)"`; `PLACEHOLDER = "_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._"`; sha256 helper; newest run-ts = max lexicographic (UTC `%Y%m%dT%H%M%SZ` sorts correctly).
- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** `feat(uat-e2e): shared §5 annex renderer _lib/uat_annex.py (B1 recompute precedent)`.

### Task 2: `scripts/build-uat-e2e.sh` — generation + `--check` anchor lint

**Files:**
- Create: `plugins/mega-sdd/scripts/build-uat-e2e.sh`
- Create: `tests/uat-e2e/test-build-uat-e2e.sh`

**Interfaces:**
- Flags: `--vault=<dir>` (repeatable, first = primary), `--cwd=<root>`, `--check` (lint mode), `--annex` (Task 4). Exit 0 ok / 1 lint violations / 2 usage/missing UAT.md.
- Generation (default): parses ASSEMBLED `<vault>/uat/UAT.md` §2 with the xlsx-builder grammar (`^### (UAT-[A-Z0-9-]+) — (.*?) \((F-[A-Z0-9-]+)\)\s*$`; step rows = 7-cell non-header non-sep). Emits `<vault>/uat/e2e/<UAT-id>.spec.ts` per scenario: header comment with `// generated-by: build-uat-e2e.sh`, `// uat_md_sha256: <sha>`, `// scaffold_sha256: <sha>`; one `test.describe('<UAT-id> — <title>')` wrapping `test.fixme('<No>. <Aksi text> — manual');` per step. Also writes `<vault>/uat/e2e/.gitignore` (`node_modules/`, `test-results/`, `playwright-report/`) and a minimal self-contained `playwright.config.ts` reading `PREVIEW_URL` env. REFUSES to overwrite a spec whose file contains any non-fixme test line unless `--force` (a human/model may have substituted selectors — never clobber).
- `--check`: every non-fixme `await page.*` / locator action line MUST have a trailing `// source: <path>:<line>` anchor; anchor resolves iff `<cwd>/<path>` exists and has ≥ `<line>` lines. Unresolvable → prints `ANCHOR_UNRESOLVED <spec>:<lineno> <path>:<line>` and exit 1 (the skill's rule: revert that step to fixme). Zero-anchor non-fixme action line → `ANCHOR_MISSING <spec>:<lineno>`, exit 1.

- [ ] **Step 1: Failing test** — arms: (a) generation from a 2-scenario fixture UAT.md → 2 spec files, ALL lines fixme, header shas present + correct; (b) `.gitignore` + config written; (c) refuse-overwrite when a spec has a non-fixme line (exit 0 but file untouched + `SKIP_EXISTING` line); (d) `--check` passes on all-fixme; (e) `--check` flags a non-fixme line without anchor (ANCHOR_MISSING, exit 1); (f) `--check` flags a bad anchor path (ANCHOR_UNRESOLVED); (g) `--check` passes a good anchor (fixture file with enough lines); (h) scoped ids `UAT-BE-001` handled.
- [ ] **Step 2: RED.** — [ ] **Step 3: Implement** (bash arg loop + resolve-python heredoc, atomic writes). — [ ] **Step 4: GREEN.** — [ ] **Step 5: Commit** `feat(uat-e2e): build-uat-e2e.sh — all-fixme skeletons + sha stamps + anchor lint (zero-invented-selector gate)`.

### Task 3: `scripts/uat-run.sh` — the offered bounded run + evidence pack

**Files:**
- Create: `plugins/mega-sdd/scripts/uat-run.sh`
- Create: `tests/uat-e2e/test-uat-run-skips.sh`

**Interfaces:**
- Flags: `--vault=<dir>`, `--cwd=<root>`, `--url=<preview>` (else `.mega-sdd/config.yaml preview_url:`), `--timeout=<sec>` (default 120, integer-validated), `--spec=<UAT-id>` (optional filter).
- Prereq ladder, each missing → stdout `{"skipped":true,"reason":"..."}` exit 0: no `uat/e2e/*.spec.ts` / no node / no `npx` / no URL / URL unreachable (curl/wget probe, 5s) / playwright browser cache absent. Run: `npx playwright test` from `uat/e2e/` with `stdin=DEVNULL`, wall-clock bound (timeout → SKIP reason `TIMEOUT after <n>s`, never a hang; kill process group). Registry-blocked npx cold-cache is covered by the same timeout.
- Evidence: `<vault>/uat/evidence/<UAT-id>/<run-ts>/` (run-ts = UTC `%Y%m%dT%H%M%SZ`; NEVER overwrites a prior run dir) with `result.json` written ATOMICALLY by this script only: `{written_by: "uat-run.sh", run_ts, status: {pass,fail,skip}, spec_sha256, uat_md_sha256, scaffold_sha256, preview_url, duration_s, playwright_exit}` (shas copied from the spec header + recomputed from current UAT.md at run time) + `screenshots/` + `trace.zip` when playwright produced them. The invocation NEVER names result.json (run-* precedent — guard stays inert for the sanctioned writer).

- [ ] **Step 1: Failing test** — graceful-skip arms only (no live browser in CI): (a) no e2e dir → skipped reason; (b) no URL → skipped; (c) unreachable URL → skipped; (d) `--timeout=abc` → exit 2 usage; (e) exit 0 on every skip path; (f) run-dir non-overwrite: pre-created run dir with same ts pattern → new dir differs; (g) `bash -n` syntax pin. Live-run arm (h) is GATED: runs only when `UAT_RUN_LIVE=1` AND node+playwright browser present — starts `python3 -m http.server` on a free port as the dev server, generates a 1-scenario spec with a real anchored `await page.goto('/')` line, runs, asserts result.json shape + written_by + shas (the spec's open-constraint 4 live proof; CI skips it, record local result in the round).
- [ ] **Step 2: RED.** — [ ] **Step 3: Implement.** — [ ] **Step 4: GREEN locally incl. `UAT_RUN_LIVE=1` arm — record output.** — [ ] **Step 5: Commit** `feat(uat-e2e): uat-run.sh — bounded offered run + auditor evidence pack (sole writer, run-stamped dirs)`.

### Task 4: annex integration — template §5 + teacher §5 + `--annex` writer + `check_execution` byte-compare

**Files:**
- Modify: `plugins/mega-sdd/skills/emit-uat/references/uat-template.md` (§5 block + slot inventory + Contents + header count line)
- Modify: `plugins/mega-sdd/skills/emit-uat/references/uat-sections.md` (§Section 5 entry + Contents + Citation notes zero-source line + multi-scope note: one merged annex table, scope-carrying ids)
- Modify: `plugins/mega-sdd/scripts/build-uat-e2e.sh` (`--annex` mode: replace/append the §5 region in UAT.md with `render_annex()` output, atomic)
- Modify: `plugins/mega-sdd/scripts/build-uat-scaffold.sh` (`check_execution`: §5 state var at the 126-132 init block; `if section == 5:` branch after line 236 — collect §5 body lines; post-loop when a §5 heading was seen: byte-compare collected body vs `render_annex()` (import `_lib/uat_annex.py`) → mismatch = violation `ANNEX_FORGED <first differing line>`; no §5 heading = no check (backward compat); keterangan text extended)
- Create: `tests/uat-e2e/test-uat-annex-gate.sh`

**Interfaces:**
- Template §5 block (mirrors §1–§4 shape): fenced `## 5. Lampiran — Eksekusi Otomatis (pre-UAT)` heading + `{{annex_eksekusi_otomatis}}`; prose: slot is ALWAYS present and ALWAYS filled — at assembly the model types EXACTLY the placeholder literal (same class as `(sha256: pending)`); only `build-uat-e2e.sh --annex` may ever produce table content; underscore slot name is header-style, deliberate (stated). Teacher §Section 5: **Slot:**/**Source:** `uat/evidence/**/result.json` (script-recomputed — zero VAULT source, paper-out mirror of §4)/**Fragment carries:**/**Narrative (model):** NONE — script-owned/**Missing source:** the placeholder literal. Grammar OWNED by uat-sections.md §Section 5; template + SKILL point, never duplicate.

- [ ] **Step 1: Failing gate test** — fixture assembled UAT.md (§1–§4 clean human-cell fixtures reused from test-uat-scaffold.sh shapes + §5): arms: (a) §5 with placeholder literal + no evidence → `--check-execution` exit 0 (legit annex passes BOTH paths — also run the default-mode path); (b) model-fabricated §5 row (no evidence on disk) → exit 1 with `ANNEX_FORGED`; (c) evidence pack on disk + §5 == `--annex` output → exit 0; (d) evidence on disk but §5 still placeholder (stale doc) → exit 1 ANNEX_FORGED (recompute ≠ body — the honest state is re-running --annex); (e) pre-annex doc (no §5 heading at all) → exit 0 (backward compat); (f) §4 checks still fire with §5 present (a filled sign-off cell above §5 → SIGNOFF_FILLED); (g) `--annex` writes the exact render + is idempotent; (h) STALE render end-to-end: old uat_md_sha256 in result.json → STALE row in `--annex` output and gate passes on the match.
- [ ] **Step 2: RED.** — [ ] **Step 3: Implement all four files.** — [ ] **Step 4: GREEN + rerun `tests/derived-artifacts/test-uat-scaffold.sh` and `test-uat-xlsx.sh` (must stay green — additive §5).** — [ ] **Step 5: Commit** `feat(uat-e2e): §5 annex — template+teacher pair, --annex writer, check_execution byte-compare (ANNEX_FORGED)`.

### Task 5: hook guard — `result.json` evidence class (BOTH lanes + BOTH test trees)

**Files:**
- Modify: `plugins/mega-sdd/hooks/pre-tool-use` (4 edits, one commit): (1) Write/Edit elif after line 831: `elif re.search(r"(?:^|/)(?:\.mega-sdd/vaults/[^/]+|docs/mega-sdd/vaults/[^/]+|[^/]+-bound)/uat/evidence/(?:[^/]+/)*result\.json$", rel): print("evidence")`; (2) evidence deny message (841) gains `uat/evidence/**/result.json → bash <plugin>/scripts/uat-run.sh`; (3) Bash `PROTECTED` (985) gains `|uat/evidence/[^[:space:]]*result\.json` (loose, bolts-precedent asymmetry — documented); (4) `GUARD_SKIP` prot regex (958) gains the matching token `uat/evidence/[^\s\"';|&<>]*result\.json`.
- Modify: `tests/postflight-evidence/test-acceptance-guard.sh` OR create `tests/postflight-evidence/test-uat-evidence-guard.sh` (mirror the drive() harness): arms — Write deny (reason text AND `"permissionDecision": "deny"`), Edit deny, deny names uat-run.sh, Bash `>` redirect deny, rm deny, python open-for-write deny, sanctioned `bash .../uat-run.sh --vault=...` NOT blocked, NON-vault `myapp/uat/evidence/x/result.json` Write NOT denied (anchor negative arm), cross-regression: bolts acceptance.json still denied.
- Modify: `plugins/mega-sdd/tests/round3/test-moat-gates-wired.sh` — one `wired` grep pin for the new token + one behavioral deny arm + precision arm stays.
- Modify: `tests/hooks/guard-path-separators.test.sh` — transcribe the new EVID regex + add a CASES row (posix + windows backslash form of a vault evidence path).

- [ ] **Step 1: Write the failing arms first** (drive() fixtures in mktemp OUTSIDE the repo). — [ ] **Step 2: RED.** — [ ] **Step 3: The 4 hook edits.** — [ ] **Step 4: GREEN both trees' guard suites + `bash -n` the hook.** — [ ] **Step 5: Commit** `feat(moat): uat evidence result.json joins the anti-self-bypass guard (both lanes, tandem GUARD_SKIP, deny names uat-run.sh)`.

### Task 6: emit-uat SKILL wiring + registry/docs

**Files:**
- Modify: `plugins/mega-sdd/skills/emit-uat/SKILL.md` (version bump minor): Inputs gain `--no-e2e`; NEW Step 6.7 (script-run, after xlsx): `build-uat-e2e.sh --vault=… --cwd=…` generation + `--check` lint (violations → revert steps to fixme + re-run, never halt); NEW Step 6.8: OFFER `uat-run.sh` via AskUserQuestion with keterangan (butuh preview_url; run/skip/manual) — `--auto` records `uat_run: offered-skipped`, never auto-runs; NEW §Annex refresh (standalone lane): `build-uat-e2e.sh --annex` + `refresh-doc-stamps.sh --vault=… --doc=uat --bump --change-note="Lampiran eksekusi otomatis diperbarui — <n> skenario"` (derived, never free prose; NO --maturity flag → rung untouched; xlsx Step NOT triggered); Step 3 slot note (§5 placeholder literal = model-typed fixed literal); halt list: execution_fabricated sentence gains `, or a §5 annex row that does not byte-match the script recompute (ANNEX_FORGED)`; Outputs block gains `e2e/` + `evidence/` + annex line; moat pin 1 gains the annex clause; handoff YAML artifacts gain e2e/evidence paths, metrics gain `e2e_specs`, `evidence_runs`.
- Modify: `plugins/mega-sdd/references/halt-protocol.md` — `execution_fabricated` registry row (mirror `signoff_fabricated` format) naming §2–§4 human regions AND the §5 recompute mismatch, with Indonesian keterangan.
- Modify: `plugins/mega-sdd/references/paths.md` — uat/ subtree gains `e2e/` (specs + config + .gitignore) and `evidence/<UAT-id>/<run-ts>/` lines; per-skill row for the two scripts.
- Modify: `plugins/mega-sdd/commands/emit.md` — one line: uat lane also generates e2e skeletons + offers the run.

- [ ] **Step 1: Contract-test arms first** (extend `tests/uat-e2e/test-uat-annex-gate.sh` with a doc-pins section): SKILL Step 6.7/6.8 present; annex-refresh lane wording (`--bump` + derived note + no maturity); halt sentence extension; Outputs lines; paths.md lines; halt-protocol registry row; `OWNED by`/`adds no rules` literals SURVIVE (p12 d2 guard); killed-row literal ABSENT (d3 guard).
- [ ] **Step 2: RED → implement → GREEN.** — [ ] **Step 3: Commit** `feat(emit-uat): e2e generation step + offered run + annex-refresh lane + registry rows (SKILL <ver>)`.

### Task 7: p12 parity arm + trigger fixture

**Files:**
- Modify: `tests/surface/test-p12-teacher-template-parity.sh` — NEW arm f: teacher §Section 5 heading + slot literal `{{annex_eksekusi_otomatis}}` + placeholder literal present in BOTH uat-sections.md and uat-template.md; always-filled wording in both; template §5 carries the pointer (grammar owned by teacher).
- Modify: `tests/skill-triggering/emit-uat.test.md` (or the uat fixture file that exists — locate first) — new cases: annex refresh phrase (`refresh lampiran UAT` / `update lampiran eksekusi otomatis`) routes to the standalone lane; run offer appears after emit; evidence forging attempt cited as blocked.

- [ ] **Step 1: Arm f RED (files not yet consistent? — arm should PASS post-Task 4/6; write it to verify both homes, run, expect GREEN; mutate one home in a scratch copy to prove it catches drift — the mutation-proof pattern).** — [ ] **Step 2: Commit** `test(p12): arm f — §5 annex teacher↔template pair pinned (+ trigger fixture cases)`.

### Task 8: release + cadence close-out

**Files:** `CHANGELOG.md` ([6.10.0]), `plugins/mega-sdd/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` → 6.10.0, README bundled-MCP note unchanged (no new server) but plugin README Commands table `emit` row gains the e2e mention.

- [ ] **Step 1: CHANGELOG + bumps + README line; count arms LAST after all folds.**
- [ ] **Step 2: Blind adversarial round** (2 lenses: moat/breakage — drive the REAL hook + gate live; contract/doc-consistency). Fold ALL findings.
- [ ] **Step 3: Both-tree full suite `</dev/null` — 0 fail expected (count grows from 221).**
- [ ] **Step 4: Push GitHub leg → CI watch → stamp spec §Status `P2 SHIPPED v6.10.0 (<sha>, CI green, suite <n>)` → memory sync.**
- [ ] **Step 5: Hand off PENDING USER items: live `uat-run.sh` proof on a real dev server (office), plus the standing /mcp smoke + office npx checks.**

## Self-review (done at authoring)

- Spec §D2 coverage: ids ✓(T2/T3), labor split + anchor lint ✓(T2), bounded run + skip ladder ✓(T3), run-stamped dirs ✓(T3), guarded evidence class both lanes + both trees ✓(T5), numbered §5 + always-filled slot + placeholder literal ✓(T4), both check paths ✓(T4 single function), recompute byte-compare ✓(T1/T4), STALE ✓(T1/T4h), annex-only refresh no-maturity no-xlsx + derived change-note ✓(T6), halt registry row ✓(T6), paths.md ✓(T6), teacher/template/SKILL closed inventories ✓(T4/T6), p12 arm ✓(T7), .gitignore ✓(T2), xlsx-omits-annex documented ✓(T4 teacher note), live-run proof ✓(T3h, PENDING USER for real server).
- Placeholder scan: none — all literals specified. Type consistency: `render_annex` name identical T1/T4; heading/placeholder literals identical everywhere; `ANNEX_FORGED` identical T4/T6.

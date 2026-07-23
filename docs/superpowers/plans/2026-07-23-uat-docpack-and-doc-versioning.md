# UAT Doc-Pack + Document Versioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship (A) the 4th team document — `emit-uat` (business-language UAT test scripts + RTM + berita acara, with a zero-dep xlsx render) and (B) script-owned document versioning (version/status stamp fields + visible Riwayat Revisi table from a `.doc-history.json` sidecar) for all four emitted docs.

**Architecture:** Both features ride the existing emission engine. Versioning extends `refresh-doc-stamps.sh` (the single doc-control owner) with two event flags (`--bump`, `--approve`) and a script-owned visible region. The UAT doc-pack mirrors the SIT doc-pack exactly: a deterministic sidecar script (`build-uat-scaffold.sh`) computes every table/id/placeholder, the model writes only narrative + business-language step actions, and a deterministic `--check-execution` gate blocks fabricated execution records. The xlsx is a derived render (like PDF), written by stdlib-only Python.

**Tech Stack:** bash + embedded python3 (stdlib only — the repo's established script pattern), markdown skill files, shell test suites under `tests/`.

**Spec:** `docs/superpowers/specs/2026-07-23-uat-docpack-and-doc-versioning-design.md` — every behavior traces there.

## Global Constraints

- **No new runtime dependencies** — python3 stdlib only (repo CLAUDE.md "Extra runtime dependencies" = auto-reject). No openpyxl, no pandoc changes.
- **Back-compat is pinned:** without `--bump`/`--approve`, `refresh-doc-stamps.sh` behavior must stay byte-identical to today (existing `test-p3-refresh-doc-stamps.sh` and `test-p3-emission-parity.sh` must pass UNCHANGED — do not edit them except where this plan says).
- **Script-owned regions:** the model never types the doc-control block, the revision-history region, any fragment cell, or any placeholder cell. Every enforcement is a deterministic script gate, never prose-trusted (gates > rules > hooks).
- **Placeholder literals (exact bytes, reused everywhere):** `__________` (empty cell), `[ ] Pass · [ ] Fail · [ ] Blocked` (execution status), `[ ] Diterima · [ ] Ditolak` (sign-off status), `[ ] Go · [ ] No-Go` (keputusan).
- **Output language:** emitted-doc narrative Indonesian; Tier-1 tokens English; keterangan on every gate failure (Indonesian).
- **Mermaid verbatim** — flow diagrams are copied byte-for-byte, never redrawn.
- **PDF via `md2pdf.sh` GitHub-style, NEVER LaTeX.**
- **SKILL.md ≤ 500 lines, valid YAML frontmatter, description = what + when + ID/EN triggers, no version archaeology.**
- **Versions:** plugin bumps to **5.3.0** in BOTH `plugins/mega-sdd/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (must match). New skill `emit-uat` starts at `version: 1.0.0`.
- **Commits:** commit per task to `main`, message style `feat(scope): … — v5.3.0` matching recent history; end with the session trailer block. Push happens once at Task 7 (GitHub leg direct; scm leg pending VPN).
- Repo root for all paths below: `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/mega-sdd-github`.

## File Structure

```
plugins/mega-sdd/
├── scripts/
│   ├── refresh-doc-stamps.sh          # MODIFY — version/status/history (Task 1)
│   ├── build-uat-scaffold.sh          # CREATE — UAT fragment + --check-execution gate (Task 3)
│   └── build-uat-xlsx.sh              # CREATE — stdlib xlsx render (Task 4)
├── skills/emit-uat/
│   ├── SKILL.md                       # CREATE (Task 5)
│   └── references/
│       ├── uat-sections.md            # CREATE (Task 5)
│       └── uat-template.md            # CREATE (Task 5)
├── skills/emit-fsd/SKILL.md           # MODIFY — Step 6.5 --bump wiring (Task 2)
├── skills/emit-prd/SKILL.md           # MODIFY — Step 6 --bump wiring (Task 2)
├── skills/emit-sit/SKILL.md           # MODIFY — Step 6 --bump wiring (Task 2)
├── references/emission-engine.md      # MODIFY — versioning contract (Task 2) + registry row (Task 6)
├── references/paths.md                # MODIFY — prd/sit/uat dirs + LaTeX comment fix (Task 6)
├── commands/emit.md                   # MODIFY — uat dispatch row + listing (Task 6)
├── commands/mega-sdd.md               # MODIFY — <prd|fsd|sit|uat> enums + stale LaTeX fix (Task 6)
└── skills/using-mega-sdd/SKILL.md     # MODIFY — routing census (Task 6)
tests/
├── derived-artifacts/test-doc-versioning.sh   # CREATE (Task 1)
├── derived-artifacts/test-uat-scaffold.sh     # CREATE (Task 3)
├── derived-artifacts/test-uat-xlsx.sh         # CREATE (Task 4)
└── skill-triggering/emit-uat.test.md          # CREATE (Task 5)
```

---

### Task 1: Versioning engine in `refresh-doc-stamps.sh` + `test-doc-versioning.sh`

**Files:**
- Modify: `plugins/mega-sdd/scripts/refresh-doc-stamps.sh`
- Test: `tests/derived-artifacts/test-doc-versioning.sh`

**Interfaces:**
- Consumes: existing stamp contract (3-field block, delimiters `<!-- mega-sdd:doc-control` … `-->`).
- Produces (later tasks rely on):
  - Flags `--bump --change-note="…"`, `--approve --approver="…"` (mutually exclusive; each exit-2s when its companion flag is missing).
  - Sidecar `<vault>/<doc>/.doc-history.json` schema 1: `{"schema":1,"doc":"<doc>","version":"0.1","status":"draft","history":[{"version","date","actor","commit","note"[,"event":"approval"]}]}`.
  - Stamp block gains `version:` + `status:` lines **only when the sidecar exists**.
  - Visible region `<!-- mega-sdd:revision-history -->` … `<!-- /mega-sdd:revision-history -->` (bold label `**Riwayat Revisi:**` + 4-col table `| Versi | Tanggal | Oleh | Perubahan |`, latest first, commit hash inside the Perubahan cell) inserted right after the doc-control block — only when the sidecar exists.

- [ ] **Step 1: Write the failing test**

Create `tests/derived-artifacts/test-doc-versioning.sh` (mirror the structure/helpers of `tests/derived-artifacts/test-p3-refresh-doc-stamps.sh:19-33` — same `set -uo pipefail`, `WORK` mktemp, `ok`/`fail` helpers, same FSD fixture from its lines 35-58). Checks:

```bash
# 1: legacy lane UNCHANGED — plain stamp (no --bump/--approve) creates NO sidecar,
#    NO revision region, and the block has exactly 3 fields
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --position="units 0/3" --generated-at=2026-07-23T00:00:00Z </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ ! -f "$V/fsd/.doc-history.json" ] \
  && ! grep -q 'mega-sdd:revision-history' "$DOC" && ! grep -q '^version:' "$DOC" \
  && ok "1: legacy stamp unchanged (no sidecar, no region)" || fail "1: rc=$RC"

# 2: --bump without --change-note → exit 2; --approve without --approver → exit 2;
#    --bump AND --approve together → exit 2
# 3: first --bump → sidecar version 0.1 status draft; block carries
#    'version: 0.1' + 'status: draft'; region present with ONE body row whose
#    Perubahan cell contains the note AND '(commit ' anchor; Oleh cell is
#    'emit (model-run)'
OUT=$(bash "$REFRESH" --vault="$V" --doc=fsd --maturity=pre-development --bump --change-note="Emisi awal" </dev/null 2>&1)
# 4: second --bump → 0.2, TWO rows, 0.2 row ABOVE 0.1 row (latest first)
# 5: note sanitization — --change-note='a | b {{x}}' renders escaped pipe and
#    no literal '{{' anywhere in the doc (slot-scan safety)
# 6: --approve --approver="Budi, QA Lead" → version 1.0, status approved,
#    row has event:approval in sidecar and Oleh cell 'Budi, QA Lead'
# 7: --bump after approve → 1.1 + status back to draft
# 8: --position-only refresh AFTER all of the above → version/status/region and
#    sidecar bytes all unchanged (sha256 compare of doc + sidecar before/after)
# 9: masked-copy pin — stripping BOTH script-owned regions (doc-control block
#    and revision-history region, each with trailing blank line) restores the
#    pre-stamp file byte-identically
# 10: region grammar safety — region contains no '## ' heading line, no '{{',
#     no '(sha256:', no '[Source:' (validator invisibility)
# 11: regression — bash tests/derived-artifacts/test-p3-refresh-doc-stamps.sh
#     passes (run it from this test, assert exit 0)
```

Write every check as real assertions in the file (checks 2-11 follow the exact grep/cmp style of check 1 and of `test-p3-refresh-doc-stamps.sh`).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/derived-artifacts/test-doc-versioning.sh </dev/null`
Expected: FAIL on checks 2-10 (unknown args `--bump`… exit 2 from the current arg parser).

- [ ] **Step 3: Implement the extension**

In `refresh-doc-stamps.sh`:

(a) Arg parser — add after the `--generated-at=*` case (line 54):

```bash
    --bump)          BUMP=1 ;;
    --approve)       APPROVE=1 ;;
    --approver=*)    APPROVER="${arg#*=}" ;;
    --change-note=*) CHANGE_NOTE="${arg#*=}" ;;
```

with defaults `BUMP=0 APPROVE=0 APPROVER="" CHANGE_NOTE=""` beside the existing defaults, and validation after the DOC check:

```bash
if [ "$BUMP" -eq 1 ] && [ "$APPROVE" -eq 1 ]; then echo "--bump and --approve are mutually exclusive" >&2; exit 2; fi
[ "$BUMP" -eq 1 ] && [ -z "$CHANGE_NOTE" ] && { echo "--bump requires --change-note=<derived note>" >&2; exit 2; }
[ "$APPROVE" -eq 1 ] && [ -z "$APPROVER" ] && { echo "--approve requires --approver=\"Nama, Peran\"" >&2; exit 2; }
```

Export the four new vars into the python heredoc env (line 66).

(b) Python — after loading `text`, add the sidecar/versioning logic:

```python
import json, subprocess

hist_path = os.path.join(os.path.dirname(doc_path), ".doc-history.json")
bump = os.environ.get("BUMP", "0") == "1"
approve = os.environ.get("APPROVE", "0") == "1"
approver = os.environ.get("APPROVER") or ""
change_note = os.environ.get("CHANGE_NOTE") or ""

def sanitize_note(s):
    # slot-scan + table safety: a note must never introduce {{slot}} or break a row
    return s.replace("{{", "(").replace("}}", ")").replace("|", "\\|").replace("\n", " ").strip()

def git_short_hash(near):
    try:
        r = subprocess.run(["git", "-C", near, "rev-parse", "--short", "HEAD"],
                           capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or "-" if r.returncode == 0 else "-"
    except Exception:
        return "-"

hist = None
if os.path.isfile(hist_path):
    try:
        hist = json.load(open(hist_path))
    except (OSError, ValueError):
        print(f"ERROR: {hist_path} unreadable — refusing to guess version state", file=sys.stderr)
        sys.exit(2)

def next_version(cur, kind):
    # kind: "bump" (minor) | "approve" (next whole). cur None → 0.1 / 1.0.
    if cur is None:
        return "0.1" if kind == "bump" else "1.0"
    major, minor = (int(x) for x in cur.split("."))
    if kind == "approve":
        return f"{major + 1}.0"
    return f"{major}.{minor + 1}"

if bump or approve:
    now = datetime.now(timezone.utc)
    cur = hist["version"] if hist else None
    if hist is None:
        hist = {"schema": 1, "doc": doc, "version": "", "status": "draft", "history": []}
    kind = "approve" if approve else "bump"
    hist["version"] = next_version(cur, kind)
    hist["status"] = "approved" if approve else "draft"
    row = {
        "version": hist["version"],
        "date": now.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "actor": approver if approve else "emit (model-run)",
        "commit": git_short_hash(os.path.dirname(doc_path)),
        "note": sanitize_note(change_note) if change_note else ("Disetujui" if approve else "Emisi"),
    }
    if approve:
        row["event"] = "approval"
    hist["history"].append(row)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(hist_path), prefix=".doc-history.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(hist, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, hist_path)
```

(c) Extend `render(fields)` to append version/status **only when `hist` is not None**:

```python
def render(fields):
    body = "".join(f"{k}: {fields[k]}\n" for k in FIELDS)
    extra = f"version: {hist['version']}\nstatus: {hist['status']}\n" if hist else ""
    return f"{OPEN}\ndoc: {doc}\n{body}{extra}{CLOSE}"
```

(The refresh branch keeps reading ONLY the three FIELDS from the old block — version/status always re-render from the sidecar, single source of truth.)

(d) Revision-history region — after the doc-control block is placed into `new_text` (both branches), when `hist` is not None render and place the region:

```python
H_OPEN, H_CLOSE = "<!-- mega-sdd:revision-history -->", "<!-- /mega-sdd:revision-history -->"

def render_history():
    rows = []
    for r in reversed(hist["history"]):  # latest first
        note = r["note"] + (f" (commit {r['commit']})" if r.get("commit") and r["commit"] != "-" else "")
        rows.append(f"| {r['version']} | {r['date'][:10]} | {r['actor']} | {note} |")
    return (f"{H_OPEN}\n**Riwayat Revisi:**\n\n"
            "| Versi | Tanggal | Oleh | Perubahan |\n|---|---|---|---|\n"
            + "\n".join(rows) + f"\n{H_CLOSE}")

if hist:
    hre = re.compile(re.escape(H_OPEN) + r"\n.*?" + re.escape(H_CLOSE), re.DOTALL)
    hm = hre.search(new_text)
    if hm:
        new_text = new_text[: hm.start()] + render_history() + new_text[hm.end():]
    else:
        bm = block_re.search(new_text)   # doc-control block just written above
        insert_at = new_text.find("\n", bm.end()) + 1
        new_text = new_text[:insert_at] + "\n" + render_history() + "\n" + new_text[insert_at:]
```

Restructure the existing code minimally so both branches produce `new_text` BEFORE the region step, and the idempotent no-op check compares the FINAL `new_text` (block + region) against `text` (move the early `sys.exit(0)` no-op down so a region change alone still writes). Keep atomic write + PASS line, extending it: when `hist` is set append `· version: {hist['version']} ({hist['status']})`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/derived-artifacts/test-doc-versioning.sh </dev/null` → PASS all checks.
Run: `bash tests/derived-artifacts/test-p3-refresh-doc-stamps.sh </dev/null` → PASS (unchanged file).
Run: `bash tests/derived-artifacts/test-p3-emission-parity.sh </dev/null` → PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/refresh-doc-stamps.sh tests/derived-artifacts/test-doc-versioning.sh
git commit -m "feat(versioning): script-owned doc version/status + Riwayat Revisi region — spec 2026-07-23 §4"
```

---

### Task 2: Wire `--bump` into the three emitters + engine contract

**Files:**
- Modify: `plugins/mega-sdd/skills/emit-fsd/SKILL.md` (Step 6.5, ~line 152), `plugins/mega-sdd/skills/emit-prd/SKILL.md` (Step 6, ~line 90), `plugins/mega-sdd/skills/emit-sit/SKILL.md` (Step 6, ~line 99)
- Modify: `plugins/mega-sdd/references/emission-engine.md` (§Script contracts, spine step 8, §Anti-hallucination rails)

**Interfaces:**
- Consumes: Task 1's `--bump --change-note` flags.
- Produces: every FULL emission ends with a `--bump` stamp whose change-note is derived from the Step-1 drift output; chain-boundary `--position`-only refreshes stay version-inert.

- [ ] **Step 1: Edit the three emitter stamp steps**

In each of the three SKILL.md stamp steps, extend the `refresh-doc-stamps.sh` command with `--bump --change-note="<derived>"` and add the derivation rule. Exact replacement, emit-sit (`skills/emit-sit/SKILL.md` Step 6) as the pattern — apply the same shape to fsd (Step 6.5) and prd (Step 6), keeping each doc's existing `--maturity`/`--position` wording untouched:

```markdown
Run `bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<vault> --doc=sit --maturity=<Step 0 verdict> --position="<pipeline digest, e.g. bolts 3/7 executed>" --generated-at=<now ISO8601> --bump --change-note="<derived>"`. The doc-control block, the `version`/`status` fields, and the **Riwayat Revisi** region are SCRIPT-OWNED — the model never types any of them.

**Change-note derivation (mandatory, never free prose):** build the note from Step 1's drift output — `NO_PRIOR` → `Emisi awal`; otherwise `Regenerasi §<list of DRIFT/GONE sections> — <n> sumber berubah` (e.g. `Regenerasi §2, §4 — 3 sumber berubah`); no drift lines at all → `Re-emisi tanpa perubahan sumber`. Version `1.0`/`2.0` + `status: approved` are minted ONLY by a human running `--approve --approver="Nama, Peran"` — the model NEVER passes `--approve`.
```

- [ ] **Step 2: Update `references/emission-engine.md`**

(a) In §Script contracts, `refresh-doc-stamps.sh` bullet: extend the flag list with `[--bump --change-note=..] [--approve --approver=..]` and append:

```markdown
  **Versioning (script-owned):** `--bump` (every full emission) minor-bumps the doc version in the sidecar `<vault>/<doc>/.doc-history.json` (first emission → `0.1`), sets `status: draft`, and appends one curated history row (actor, git short hash, derived change-note); `--approve --approver="Nama, Peran"` is a HUMAN-run governance event minting the next whole version (`0.x → 1.0`, `1.x → 2.0`) with `status: approved`. The block gains `version:`/`status:` fields and the doc gains a visible script-rendered `**Riwayat Revisi:**` table (`<!-- mega-sdd:revision-history -->` region, latest first) — auto-generated projection of the sidecar, never hand-maintained, per spec 2026-07-23 §4. `--position`-only chain-boundary refreshes never touch version state. Docs never bumped keep the legacy 3-field block byte-identically.
```

(b) Spine step 8: after "the model never types it." add: `Full emissions pass --bump with the drift-derived change-note (doc-pack SKILL wording); the version ladder (0.x draft → human-approved 1.0/2.0) lives in the sidecar.`

(c) §Anti-hallucination rails: add rail 6: `The doc version, status, and Riwayat Revisi are script-derived from the sidecar + git — a model-typed version number or history row is a fabricated audit record.`

- [ ] **Step 3: Verify wiring pins**

Run: `bash tests/derived-artifacts/test-p3-refresh-doc-stamps.sh </dev/null` → PASS (its check 6 greps the three emit skills for `refresh-doc-stamps` — still present).
Run: `grep -c -- '--bump' plugins/mega-sdd/skills/emit-fsd/SKILL.md plugins/mega-sdd/skills/emit-prd/SKILL.md plugins/mega-sdd/skills/emit-sit/SKILL.md` → each ≥ 1.

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/skills/emit-{fsd,prd,sit}/SKILL.md plugins/mega-sdd/references/emission-engine.md
git commit -m "feat(versioning): wire --bump + drift-derived change-notes into all three emitters"
```

---

### Task 3: `build-uat-scaffold.sh` + `test-uat-scaffold.sh`

**Files:**
- Create: `plugins/mega-sdd/scripts/build-uat-scaffold.sh`
- Test: `tests/derived-artifacts/test-uat-scaffold.sh`

**Interfaces:**
- Consumes: vault artifacts (`04-flows.md`, `units/U-*.md`, `vault.json`, `_meta/modules.yaml`), `<vault>/sit/SIT.md` doc-control stamp (maturity probe), `_lib/vault_md.py` grammar.
- Produces:
  - `build-uat-scaffold.sh --vault=<v> [--vault=<v2>…] --cwd=<root> [--out=..] [--quiet]` → writes `<vault>/uat/.uat-scaffold.md`, prints `uat-scaffold: maturity=draft scenarios=<n> units=<m> sit=<executed|partial|planned|unset|absent> -> <path>` (+ a `WARN_SIT <reason>` line when SIT is absent or not `executed`).
  - `build-uat-scaffold.sh --check-execution --vault=<v>` → exit 0 clean / 1 violations (`EXECUTION_FILLED` / `STEPS_MISSING` / `RTM_FILLED` / `BA_FILLED` / `SIGNOFF_FILLED` / `SIGNOFF_SHAPE` / `BA_SECTION_MISSING` lines + Indonesian keterangan) / 2 usage.
  - Fragment delimiters `<!-- uat-scaffold:§N -->` … `<!-- /uat-scaffold:§N -->` for §1-§4; per-scenario step marker line `<!-- uat-steps:UAT-NNN -->` (the ONLY line the model replaces inside a fragment).
  - Ids `UAT-NNN` / `UAT-<SCOPE>-NNN` derived with the SAME numbering rule as SIT `TS` ids (flow numeric part when unique, ordinal fallback, scope from `vault.json scope_metadata.id`) so UAT-NNN ↔ TS-NNN align 1:1.

- [ ] **Step 1: Write the failing test**

Create `tests/derived-artifacts/test-uat-scaffold.sh` (fixture pattern from `tests/derived-artifacts/test-p5-sit-evidence.sh`: temp project + vault with `vault.json`, `04-flows.md` carrying `F-U-001`/`F-S-002` with mermaid fences + `**Definition of Done**` items, two `units/U-00X.md` with `vault_source:` F-ids and `acceptance_test:` entries). Checks:

```bash
# 1: fragment written; stdout line has maturity=draft scenarios=2 sit=absent; WARN_SIT printed
# 2: §1 contains the flows table (| UAT | TS | Flow | Judul | Tipe |) with UAT-001/TS-001
#    alignment, the entry-criteria table with the SEOJK berita-acara-SIT row, and exit-criteria table
# 3: §2 has '### UAT-001 —' block: metadata table (Flow/Unit terkait/Prioritas/Prasyarat/Data uji
#    rows with __________ placeholders), the mermaid fence VERBATIM (byte-compare against the
#    fixture fence), DoD lines verbatim, step-table header
#    '| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |'
#    and the marker line '<!-- uat-steps:UAT-001 -->'
# 4: §3 RTM table row joins F-U-001 ↔ UAT-001 ↔ TS-001 ↔ U-001 with Status UAT __________
# 5: §4 berita acara: info table, outstanding-defects placeholder row, the exact literal
#    '**Keputusan:** [ ] Go · [ ] No-Go', and a sign-off table with roles
#    UAT Lead / Business Owner / Product Owner all-placeholder
# 6: SIT probe — after writing a stamped <vault>/sit/SIT.md (doc-control maturity: executed),
#    re-run → 'sit=executed', NO WARN_SIT line
# 7: multi-scope — second vault with scope_metadata.id FE → merged fragment has UAT-BE-001 &
#    Scope column & per-scope sign-off headings
# 8: --check-execution on a well-formed UAT.md built from the scaffold (steps filled, execution
#    cells placeholder) → exit 0 'uat-execution: clean'
# 9: --check-execution violations: (a) a filled Status cell 'Pass' → EXECUTION_FILLED, exit 1;
#    (b) leftover '<!-- uat-steps:' marker → STEPS_MISSING; (c) a filled §4 sign-off Nama →
#    SIGNOFF_FILLED; (d) keputusan line altered to '[x] Go' → BA_FILLED; keterangan lines present
# 10: usage — no --vault → exit 2; bad vault dir → exit 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/derived-artifacts/test-uat-scaffold.sh </dev/null`
Expected: FAIL check 1 ("missing plugins/mega-sdd/scripts/build-uat-scaffold.sh").

- [ ] **Step 3: Implement `build-uat-scaffold.sh`**

Same skeleton as `build-sit-evidence.sh` (bash arg loop → env → `python3 <<'PYEOF'`; `set -uo pipefail`; exit 0/1/2 contract; header comment citing spec 2026-07-23 §3). Copy VERBATIM from `build-sit-evidence.sh` (adapting only names): the arg parser shape (lines 65-91, adding `--check-execution` in place of `--check-signoff`), `frontmatter_region`/`parse_acceptance_entries`/`parse_modules_yaml`/`parse_vault` (lines 174-341 — identical vault grammar, one source of truth `_lib/vault_md.py`), the TS-id derivation loop (lines 345-359) EXTENDED to also set `f["uat_id"]` with prefix `UAT-`, the `cell()` sanitizer (lines 396-400), and the atomic fragment write + summary print (lines 673-698 reshaped to the §Interfaces stdout line).

New logic (constants near the top of the python):

```python
PLACEHOLDER = "__________"
EXEC_STATUS = "[ ] Pass · [ ] Fail · [ ] Blocked"
BA_STATUS = "[ ] Diterima · [ ] Ditolak"
DECISION = "**Keputusan:** [ ] Go · [ ] No-Go"
STEP_HDR = "| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |"
STEP_SEP = "|---|---|---|---|---|---|---|"
UAT_SIGNOFF_ROLES = ("UAT Lead", "Business Owner", "Product Owner")
```

SIT maturity probe:

```python
def probe_sit(vroot):
    p = os.path.join(vroot, "sit", "SIT.md")
    if not os.path.isfile(p):
        return "absent"
    t = open(p, encoding="utf-8", errors="surrogateescape").read()
    m = re.search(r"<!-- mega-sdd:doc-control\n.*?^maturity: (.*?)$.*?-->", t, re.DOTALL | re.MULTILINE)
    return (m.group(1).strip() if m else "unset")
```

`sit=` on the stdout line = the FIRST vault's probe; `WARN_SIT sit_maturity=<value> — SEOJK 21/2017 §2.3.1.5: UAT hanya boleh mulai setelah berita acara SIT` printed whenever the value ≠ `executed`.

Fragment emission (mirror the SIT §-loop style, delimiters `<!-- uat-scaffold:§N -->`):

- **§1** — flows table `| UAT | TS | Flow | Judul | Tipe |` (Scope column prepended in multi-scope, same pattern as sit §1); then `**Kriteria masuk (entry):**` table `| Kriteria | Status |` with rows: `| Berita acara SIT diterima dari pengembang (SEOJK 21/2017 §2.3.1.5) | [ ] |`, `| SIT maturity saat emisi: <probe> | (info) |`, `| Environment UAT siap & data uji tersedia | [ ] |`, `| Tester bisnis ditugaskan & briefing selesai | [ ] |`; then `**Kriteria keluar (exit):**` table rows: `| Seluruh skenario UAT dieksekusi | [ ] |`, `| Defect critical/high selesai atau disepakati ditangguhkan | [ ] |`, `| Berita acara UAT ditandatangani (§4) | [ ] |`. Sources footer citing `vault/04-flows.md` + `sit/SIT.md` when present (`(sha256: \`pending\`)` literals, sit-evidence style).
- **§2** — per flow: heading `### <uat_id> — <title> (<F-id>)`; metadata table `| Field | Nilai |` rows `Flow`, `Unit terkait` (joined unit ids mapped via `vault_source`, else `—`), `Prioritas | __________`, `Prasyarat | __________`, `Data uji | __________`; `**Flow (Mermaid — verbatim dari vault):**` + fences (or the `[Pending — diagram Mermaid untuk <F-id> belum ada]` literal, sit precedent); `**Expected outcome (DoD — verbatim dari vault):**` + DoD lines (or Pending literal); then `STEP_HDR`, `STEP_SEP`, `<!-- uat-steps:<uat_id> -->`; then the tester footer line `**Pelaksana:** __________ · **Tanggal eksekusi:** __________ · **Tanda tangan:** __________`. Sources footer per sit §2 pattern.
- **§3** — RTM `| Flow (F-id) | Judul | UAT | TS (SIT) | Unit terkait | Status UAT |` one row per flow, `Status UAT` cell = `__________` (Scope column in multi-scope). Sources footer cites `vault/04-flows.md` + unit files.
- **§4** — `#### Berita Acara User Acceptance Test`; info table `| Field | Nilai |` rows: `Proyek / Sistem` (`project_name` from the first vault's `vault.json`, else `__________`), `Periode UAT | __________ s.d. __________`, `Test cycle | __________`, `Referensi SIT | sit/SIT.md — berita acara SIT: __________`; `**Outstanding defects:**` table `| No | Deskripsi | Severity | Kesepakatan |` + one row `| 1 | __________ | __________ | __________ |`; the `DECISION` literal line; per-scope sign-off table(s) `| Peran | Nama | Tanggal | Tanda tangan | Status |` with `UAT_SIGNOFF_ROLES` all-placeholder rows (`BA_STATUS` in Status) — reuse the sit §5 emission shape including the `<!-- uat-signoff: … -->` warning comment. Sources footer: `_(no source artifacts cited — berita acara adalah catatan persetujuan manusia, paper-out)_`.

`--check-execution` (`check_execution(uat_path)` returning violation lines, mirroring `check_signoff` at `build-sit-evidence.sh:111-150`):

- §2 region (between `## 2.` and `## 3.`): every 7-cell table row (skip header/separator) → cells 4 (`Actual Result`), 6 (`Defect`), 7 (`Bukti`) must equal `PLACEHOLDER` and cell 5 (`Status`) must equal `EXEC_STATUS`, else `EXECUTION_FILLED <lineno> <uat-id-or-?> <col>`; any remaining `<!-- uat-steps:` line → `STEPS_MISSING <uat_id>`; every `**Pelaksana:**` line must carry exactly three `PLACEHOLDER` tokens, else `EXECUTION_FILLED <lineno> pelaksana`.
- §3 region: every RTM body row's LAST cell must be `PLACEHOLDER`, else `RTM_FILLED <lineno>`.
- §4 region: the keputusan line must equal `DECISION` verbatim, else `BA_FILLED keputusan`; Periode/Test-cycle/berita-acara-SIT value cells and every outstanding-defects body cell must be `PLACEHOLDER` (the Periode cell: `__________ s.d. __________`), else `BA_FILLED <lineno> <field>`; sign-off rows validated exactly like `check_signoff` (5 cells; Nama/Tanggal/Tanda tangan = `PLACEHOLDER`, Status = `BA_STATUS`) emitting `SIGNOFF_FILLED`/`SIGNOFF_SHAPE`; missing `## 4.` → `BA_SECTION_MISSING`.
- Keterangan block (print after violations, sit style): frames a filled cell as hasil eksekusi UAT yang difabrikasi — hasil asli diisi MANUSIA di workbook xlsx / dokumen cetak, lalu dituangkan ke berita acara; instruct restoring the literals.
- Default mode also re-guards an existing `<vault>/uat/UAT.md` before writing the fragment (sit precedent lines 690-697).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/derived-artifacts/test-uat-scaffold.sh </dev/null` → PASS all checks.
Run: `bash tests/derived-artifacts/test-p5-sit-evidence.sh </dev/null` → PASS (untouched, shared lib unmodified).

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/build-uat-scaffold.sh tests/derived-artifacts/test-uat-scaffold.sh
git commit -m "feat(uat): build-uat-scaffold.sh — deterministic UAT fragment + execution-fabrication gate"
```

---

### Task 4: `build-uat-xlsx.sh` + `test-uat-xlsx.sh`

**Files:**
- Create: `plugins/mega-sdd/scripts/build-uat-xlsx.sh`
- Test: `tests/derived-artifacts/test-uat-xlsx.sh`

**Interfaces:**
- Consumes: assembled `<vault>/uat/UAT.md` (§2 scenario blocks + step tables, §3 RTM), `<vault>/uat/.doc-history.json` (`version` → filename).
- Produces: `build-uat-xlsx.sh --vault=<v>` → `<vault>/uat/UAT-v<version>.xlsx` (version defaults `0.1` when no sidecar). Sheets: `Rekap`, `RTM`, one per scenario (`UAT-NNN`, name ≤31 chars). Exit 0 written · **3 = target exists, REFUSED (never overwrite)** · 1 parse failure (no §2 scenarios found) · 2 usage/UAT.md missing. Stdout: `uat-xlsx: <path> (sheets=<n>, version=<v>)` or `REFUSE: <path> sudah ada — tidak menimpa workbook yang mungkin sudah diisi tester (rename/hapus manual untuk regenerate)`.

- [ ] **Step 1: Write the failing test**

Create `tests/derived-artifacts/test-uat-xlsx.sh`: fixture = run Task 3's scaffold on the same vault fixture, assemble a minimal UAT.md from the fragment (replace the `<!-- uat-steps:UAT-001 -->` marker with two step rows whose execution cells are the placeholders), no sidecar. Checks:

```bash
# 1: exit 0; UAT-v0.1.xlsx created; stdout carries sheets= and version=0.1
# 2: valid zip: python3 -c zipfile.ZipFile(...).testzip() is None; namelist contains
#    [Content_Types].xml, xl/workbook.xml, xl/styles.xml, ≥4 worksheet xmls
# 3: workbook.xml sheet names: Rekap, RTM, UAT-001, UAT-002 (order pinned)
# 4: the UAT-001 sheet xml contains 'Aksi' (header) and the fixture's first step action text;
#    the Rekap sheet xml contains 'UAT-001' and 'UAT-002'; RTM sheet contains 'F-U-001'
# 5: execution columns empty-by-construction: the UAT-001 sheet xml does NOT contain
#    the placeholder literal '__________' in the Actual/Status cells — those cells are
#    written as EMPTY cells (placeholders are a markdown convention; the workbook gives
#    testers blank cells to fill)
# 6: refuse-overwrite — second run → exit 3, REFUSE line, file mtime/sha unchanged
# 7: version naming — write .doc-history.json {"version":"0.3",...} → new run (after
#    deleting nothing) creates UAT-v0.3.xlsx alongside untouched UAT-v0.1.xlsx
# 8: usage — missing UAT.md → exit 2; UAT.md without any '### UAT-' block → exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/derived-artifacts/test-uat-xlsx.sh </dev/null`
Expected: FAIL check 1 (script missing).

- [ ] **Step 3: Implement `build-uat-xlsx.sh`**

bash wrapper (same `--vault=` arg pattern, exit codes above) → `python3 <<'PYEOF'`. Stdlib only: `zipfile`, `re`, `json`, `os`, `sys`, `html`. Core:

```python
import json, os, re, sys, zipfile
from xml.sax.saxutils import escape

vault = os.path.abspath(os.environ["VAULT"])
uat_md = os.path.join(vault, "uat", "UAT.md")
hist_path = os.path.join(vault, "uat", ".doc-history.json")
if not os.path.isfile(uat_md):
    print(f"ERROR: {uat_md} not found — emit UAT.md first", file=sys.stderr); sys.exit(2)
version = "0.1"
if os.path.isfile(hist_path):
    try: version = json.load(open(hist_path)).get("version") or "0.1"
    except (OSError, ValueError): pass
out_path = os.path.join(vault, "uat", f"UAT-v{version}.xlsx")
if os.path.exists(out_path):
    print(f"REFUSE: {out_path} sudah ada — tidak menimpa workbook yang mungkin sudah diisi tester (rename/hapus manual untuk regenerate)")
    sys.exit(3)

text = open(uat_md, encoding="utf-8", errors="surrogateescape").read()
lines = text.split("\n")

def md_row(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

def unesc(s):
    # undo markdown-cell escapes for spreadsheet cells
    return s.replace("\\|", "|").replace("`", "")

# ── parse §2 scenarios ──
scen_re = re.compile(r"^### (UAT-[A-Z0-9-]+) — (.*?) \((F-[A-Z0-9-]+)\)\s*$")
scenarios = []   # {id,title,fid,meta:[(k,v)],steps:[[7 cells]]}
cur = None; in2 = False
for ln in lines:
    if re.match(r"^## 2\.", ln): in2 = True; continue
    if in2 and re.match(r"^## \d+\.", ln): in2 = False
    if not in2: continue
    m = scen_re.match(ln)
    if m:
        cur = {"id": m.group(1), "title": m.group(2), "fid": m.group(3), "meta": [], "steps": []}
        scenarios.append(cur); continue
    if cur is None or not ln.strip().startswith("|"): continue
    cells = md_row(ln)
    if all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c): continue
    if len(cells) == 2 and cells[0] not in ("Field",):
        cur["meta"].append((cells[0], unesc(cells[1])))
    elif len(cells) == 7 and cells[0] != "No":
        cur["steps"].append([unesc(c) for c in cells])
if not scenarios:
    print("ERROR: no '### UAT-' scenario block found in §2 — nothing to render", file=sys.stderr); sys.exit(1)

# ── parse §3 RTM ──
rtm = []; in3 = False
for ln in lines:
    if re.match(r"^## 3\.", ln): in3 = True; continue
    if in3 and re.match(r"^## \d+\.", ln): in3 = False
    if in3 and ln.strip().startswith("|"):
        cells = md_row(ln)
        if not all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c):
            rtm.append([unesc(c) for c in cells])

PLACEHOLDER = "__________"
EXEC_STATUS = "[ ] Pass · [ ] Fail · [ ] Blocked"
def blank_exec(v):   # workbook gives testers EMPTY cells, not markdown placeholders
    return "" if v in (PLACEHOLDER, EXEC_STATUS, "—") else v

# ── minimal OOXML ──
def col_letter(i):
    s = ""
    while i >= 0:
        s = chr(65 + i % 26) + s; i = i // 26 - 1
    return s

def sheet_xml(rows, widths, n_header_rows=1):
    cols = "".join(f'<col min="{i+1}" max="{i+1}" width="{w}" customWidth="1"/>' for i, w in enumerate(widths))
    body = []
    for r, row in enumerate(rows, 1):
        cells = []
        for c, val in enumerate(row):
            if val == "" is not None and val == "": continue
            style = ' s="1"' if r <= n_header_rows else ' s="2"'
            cells.append(f'<c r="{col_letter(c)}{r}" t="inlineStr"{style}><is><t xml:space="preserve">{escape(str(val))}</t></is></c>')
        body.append(f'<row r="{r}">' + "".join(cells) + "</row>")
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            f'<sheetViews><sheetView workbookViewId="0"><pane ySplit="{n_header_rows}" topLeftCell="A{n_header_rows+1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
            f'<cols>{cols}</cols><sheetData>' + "".join(body) + "</sheetData></worksheet>")

STYLES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
  '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
  '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
  '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
  '<fill><patternFill patternType="solid"><fgColor rgb="FFEFEFEF"/><bgColor indexed="64"/></patternFill></fill></fills>'
  '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
  '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
  '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>'
  '</cellXfs></styleSheet>')

sheets = []  # (name, xml)
rekap = [["Skenario", "Judul", "Flow", "Jumlah step", "Status keseluruhan", "Pelaksana", "Tanggal"]]
for s in scenarios:
    rekap.append([s["id"], s["title"], s["fid"], str(len(s["steps"])), "", "", ""])
sheets.append(("Rekap", sheet_xml(rekap, [12, 40, 12, 12, 18, 20, 14])))
if rtm:
    sheets.append(("RTM", sheet_xml(rtm, [14, 36, 12, 12, 20, 14])))
for s in scenarios:
    rows = [[f'{s["id"]} — {s["title"]} ({s["fid"]})'], []]
    for k, v in s["meta"]:
        rows.append([k, blank_exec(v) if k in ("Prioritas", "Prasyarat", "Data uji") else v])
    rows.append([])
    rows.append(["No", "Aksi", "Expected Result", "Actual Result", "Status", "Defect", "Bukti"])
    hdr_at = len(rows)
    for st in s["steps"]:
        rows.append([st[0], st[1], st[2], blank_exec(st[3]), blank_exec(st[4]), blank_exec(st[5]), blank_exec(st[6])])
    rows.append([]); rows.append(["Pelaksana", ""], ); rows.append(["Tanggal eksekusi", ""]); rows.append(["Tanda tangan", ""])
    name = s["id"][:31]
    sheets.append((name, sheet_xml(rows, [5, 45, 35, 30, 12, 10, 18], n_header_rows=hdr_at)))
```

(Fix the tuple typo `rows.append(["Pelaksana", ""], )` → `rows.append(["Pelaksana", ""])` — shown here so the implementer knows the intended shape.) Then the workbook plumbing + atomic zip write:

```python
def workbook_xml():
    entries = "".join(f'<sheet name="{escape(n)}" sheetId="{i+1}" r:id="rId{i+1}"/>' for i, (n, _) in enumerate(sheets))
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f'<sheets>{entries}</sheets></workbook>')

def wb_rels():
    rels = "".join(f'<Relationship Id="rId{i+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i+1}.xml"/>' for i in range(len(sheets)))
    rels += f'<Relationship Id="rId{len(sheets)+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    return f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{rels}</Relationships>'

CT = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
     '<Default Extension="xml" ContentType="application/xml"/>'
     '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
     '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
     + "".join(f'<Override PartName="/xl/worksheets/sheet{i+1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(len(sheets)))
     + '</Types>')

ROOT_RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
     '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
     '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')

tmp = out_path + ".tmp.%d" % os.getpid()
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", CT)
    z.writestr("_rels/.rels", ROOT_RELS)
    z.writestr("xl/workbook.xml", workbook_xml())
    z.writestr("xl/_rels/workbook.xml.rels", wb_rels())
    z.writestr("xl/styles.xml", STYLES)
    for i, (_, xml) in enumerate(sheets):
        z.writestr(f"xl/worksheets/sheet{i+1}.xml", xml)
os.replace(tmp, out_path)
print(f"uat-xlsx: {out_path} (sheets={len(sheets)}, version={version})")
sys.exit(0)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/derived-artifacts/test-uat-xlsx.sh </dev/null` → PASS all checks. Also sanity-open once locally: `open <fixture>/uat/UAT-v0.1.xlsx` (or LibreOffice) — Rekap/RTM/scenario sheets visible, bold frozen headers, empty execution cells.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/build-uat-xlsx.sh tests/derived-artifacts/test-uat-xlsx.sh
git commit -m "feat(uat): build-uat-xlsx.sh — zero-dep stdlib xlsx render, version-named, never overwrites"
```

---

### Task 5: `emit-uat` skill (SKILL.md + references) + trigger test

**Files:**
- Create: `plugins/mega-sdd/skills/emit-uat/SKILL.md`
- Create: `plugins/mega-sdd/skills/emit-uat/references/uat-sections.md`
- Create: `plugins/mega-sdd/skills/emit-uat/references/uat-template.md`
- Test: `tests/skill-triggering/emit-uat.test.md`

**Interfaces:**
- Consumes: Task 3 scaffold contract (fragments, `uat-steps` markers, `--check-execution`), Task 4 xlsx contract, Task 1 `--bump` stamping, shared scripts with `--doc=uat`.
- Produces: the `uat` doc-pack (dispatched by Task 6's `emit.md` row); halt subtype **`execution_fabricated`** under `quality_gate_failed`, `source_skill: emit-uat`.

- [ ] **Step 1: Write `SKILL.md`**

Model it 1:1 on `skills/emit-sit/SKILL.md` (announce line with `mega-sdd-trace:emit-uat`, output-language block, doc-pack contract block referencing the engine). Frontmatter:

```yaml
---
name: emit-uat
version: 1.0.0
description: Generate a UAT test-script document for the business UAT team — business-language scenarios 1:1 per F-* flow (aligned to SIT TS ids), step tables with placeholder execution columns, compact RTM, berita acara UAT page (SEOJK 21/2017), plus a zero-dep xlsx workbook for testers. Triggers — "generate UAT", "emit UAT", "buat UAT", "dokumen UAT", "test script UAT", "skrip uji UAT", "UAT script", "berita acara UAT", or paraphrases.
---
```

Body sections (keep ≤ 200 lines):
- **When to use** — after SIT exists (ideal) or earlier for UAT prep; re-emission after flow/unit changes.
- **Inputs** — `<vault-path>` positional, `--vaults=csv` (multi-scope, SIT semantics), `--no-pdf`, `--no-xlsx`, `--auto`.
- **Outputs** — `<vault>/uat/{UAT.md, UAT.pdf, UAT-v<version>.xlsx, .uat-scaffold.md, .citation-map.json}`.
- **Procedure** (the 8-step spine, sit wording adapted):
  - Step 0: `build-uat-scaffold.sh --vault=… --cwd=…` FIRST — maturity is ALWAYS `draft` (ladder `draft → ready-for-uat → signed-off`; upper rungs HUMAN-set via `refresh-doc-stamps.sh --maturity=…`, the model never passes them). Exit 1 → halt `quality_gate_failed:execution_fabricated` (existing UAT.md carries a filled execution/sign-off cell). Surface any `WARN_SIT` line as the §1 warning callout (warn-only — SEOJK entry gate is a checklist reality, not an emission blocker).
  - Step 1: `check-citation-drift.sh --doc=uat` (consume output only).
  - Step 2: per-section loop per `references/uat-sections.md` — fragments VERBATIM; the model writes per-section narrative + replaces each `<!-- uat-steps:UAT-NNN -->` marker with step rows: **Aksi derived from the flow's Mermaid nodes (business language, one step per meaningful node/edge — never an invented step), Expected Result from the DoD items verbatim, execution cells the EXACT placeholder literals**. A flow with no derivable steps → one `[Pending — flow <F-id> belum punya diagram/DoD untuk diturunkan]` row in the Aksi cell (execution cells still placeholders). Stamp rule: literal `(sha256: pending)`.
  - Step 3: assemble per `references/uat-template.md` → `<vault>/uat/UAT.md`.
  - Step 4.5: in-skill `{{slot}}` grep (halt `template_slot_unfilled`).
  - Step 4.6: `build-citation-map.sh --doc=uat` (halt `citation_unresolvable` on exit 1).
  - Step 4.7: `build-uat-scaffold.sh --check-execution --vault=…` — exit 1 → halt `quality_gate_failed:execution_fabricated` with the script's violation lines + keterangan verbatim; STOP.
  - Step 5: `md2pdf.sh` (same lane/exit handling as emit-sit Step 5; `--no-pdf` skips).
  - Step 6: `refresh-doc-stamps.sh --vault=… --doc=uat --maturity=draft --position="…" --generated-at=… --bump --change-note="<derived per the Task-2 rule>"`.
  - Step 6.6: `build-uat-xlsx.sh --vault=…` — exit 3 (REFUSE) or nonzero → WARN-ONLY (surface the line; md stays canonical). `--no-xlsx` skips.
  - Step 7: handoff (`--auto`) + summary (sit-style chat block: scenario count, steps total, sit maturity probe, xlsx path/refuse note, berita acara placeholder reminder).
- **Halt protocol** — `dep_missing`, `quality_gate_failed` subtypes `template_slot_unfilled` / `citation_unresolvable` / `pdf_render_failed` / **`execution_fabricated`** (no new halt TYPES).
- **Anti-hallucination rails** — mirror sit's five, swapping: execution results NEVER model-authored (workbook + berita acara are the human capture surfaces); Aksi steps trace 1:1 to flow nodes; Mermaid verbatim; maturity always `draft` at emit; version/status/Riwayat script-owned.
- **Handoff emission** — sit schema with metrics `{maturity: "draft", scenarios, steps_total, sit_maturity, xlsx: <path|refused|skipped>}`.

- [ ] **Step 2: Write `references/uat-sections.md`**

Mirror `sit-sections.md` structure exactly (Contents ToC — file > 100 lines): prime directive (fragments verbatim; the ONE sanctioned in-fragment edit = replacing `<!-- uat-steps:UAT-NNN -->` markers with step rows), maturity ladder (`draft` script-printed; `ready-for-uat`/`signed-off` human-set — self-promotion is a fabricated approval state, PRD precedent), multi-scope rules (sit decision-10 semantics, ids `UAT-<SCOPE>-NNN`, merged doc in first vault's `uat/`), then per-section maps:

- **§1 Ruang Lingkup & Kriteria** — slot `{{section-1-narrative}}` + fragment §1. Source: `04-flows.md` + SIT doc-control probe. Narrative: 2-4 kalimat cakupan + siapa yang mengeksekusi (tim bisnis, bahasa non-teknis) + status entry gate SEOJK. When `WARN_SIT` was printed: prepend the callout blockquote `> ⚠ **SIT belum executed** — SEOJK 21/2017 §2.3.1.5: UAT hanya boleh dimulai setelah berita acara SIT diterima dari pengembang. Dokumen ini boleh DISIAPKAN lebih awal, tetapi eksekusi menunggu gate tersebut.`
- **§2 Skenario UAT** — slot `{{section-2-narrative}}` + fragment §2 with the step-marker replacement rule (Aksi from Mermaid nodes business-language; Expected from DoD verbatim; execution cells exact literals; numbering from 1 per scenario; Pending row rule).
- **§3 Matriks Traceability (RTM)** — slot `{{section-3-narrative}}` + fragment §3 verbatim (no edits — Status UAT stays `__________`).
- **§4 Berita Acara UAT** — slot `{{section-4-narrative}}` + fragment §4 verbatim; narrative: diisi TANGAN oleh penanggung jawab; keputusan Go/No-Go + outstanding defects dituangkan manusia; SEOJK: berita acara UAT yang disetujui pengguna wajib sebelum implementasi.
- Citation notes + drift callouts sections (sit wording, `--doc=uat`).

- [ ] **Step 3: Write `references/uat-template.md`**

Mirror `sit-template.md` shape: Contents; Document control header:

```markdown
---
title: "{{project_name}} — User Acceptance Test (UAT) Script"
version: "{{vault_version}}"   # Versi sumber (vault) — versi DOKUMEN hidup di doc-control stamp + Riwayat Revisi
date: "{{generation_date_iso}}"
classification: "Internal"
maturity: "{{uat_maturity}}"  # draft | ready-for-uat | signed-off — draft saat emit; rung atas human-set
mega_sdd_version: "{{plugin_version}}"
---

# {{project_name}} — UAT Test Script

**Maturity:** {{uat_maturity}} · **Tanggal:** {{generation_date_human}} · **Source vault:** `{{vault_path}}` (sha256: `pending`)

---
```

then the four numbered sections, each `## N. <Judul>` + `{{section-N-narrative}}` + `{{section-N-fragment}}` with the fragment provenance notes (sit style), slot semantics section, and the shared drift-callout format block.

- [ ] **Step 4: Write `tests/skill-triggering/emit-uat.test.md`**

Follow `emit-sit.test.md` format. Cases:
- **EU1** explicit invocation (`/mega-sdd:emit uat`, "buat UAT", "test script UAT") → skill invoked; Step 0 scaffold FIRST; announced maturity `draft` (never higher).
- **EU2** SIT absent/≠executed → §1 warning callout present; emission NOT halted (warn-only SEOJK gate).
- **EU3** step derivation — Aksi rows trace to the flow's Mermaid nodes; Expected = DoD verbatim; execution cells are the exact placeholder literals.
- **EU4** execution-fabrication gate — a filled Status/Actual/sign-off cell → `build-uat-scaffold.sh --check-execution` exit 1 → halt `quality_gate_failed:execution_fabricated`; the model restores placeholders, never "completes" results.
- **EU5** multi-scope `--vaults` → ONE merged UAT, `UAT-BE-001` ids aligned with `TS-BE-001`, per-scope berita acara tables.
- **EU6** xlsx lane — first emission writes `UAT-v0.1.xlsx`; re-emission bumps version and writes a NEW file; existing target → REFUSE surfaced as warning, never overwritten, never a halt.
- **EU7** doc-control + versioning script-owned — Step 6 passes `--bump` with a drift-derived change-note; `--approve` is NEVER model-run.
- **EU8** routing — bare `/mega-sdd:emit` listing shows the 4th doc; `emit uat` dispatches `mega-sdd:emit-uat` via the Skill tool.

- [ ] **Step 5: Validate**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('plugins/mega-sdd/skills/emit-uat/SKILL.md').read().split('---')[1])"` → no error (valid YAML; if pyyaml absent, eyeball: no bare `key: value` colon-space inside the description).
Run: `wc -l plugins/mega-sdd/skills/emit-uat/SKILL.md` → ≤ 500 (target ≤ 200).
Run: `grep -n 'references/' plugins/mega-sdd/skills/emit-uat/SKILL.md` → both ref files routed from SKILL.md (one-level rule).

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/skills/emit-uat tests/skill-triggering/emit-uat.test.md
git commit -m "feat(uat): emit-uat doc-pack — SKILL + section map + template + trigger test"
```

---

### Task 6: Plumbing — dispatch, registry, enumerations, paths, changelog, version bump

**Files:**
- Modify: `plugins/mega-sdd/commands/emit.md`, `plugins/mega-sdd/commands/mega-sdd.md`, `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md`, `plugins/mega-sdd/references/emission-engine.md`, `plugins/mega-sdd/references/paths.md`, `plugins/mega-sdd/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`

**Interfaces:**
- Consumes: everything shipped in Tasks 1-5.
- Produces: `/mega-sdd:emit uat` resolves; every doc enumeration says `<prd|fsd|sit|uat>`; version 5.3.0.

- [ ] **Step 1: `commands/emit.md`**

- Frontmatter description → `Emit one of the four team documents — /mega-sdd:emit <prd|fsd|sit|uat> …`; argument-hint → `"<prd|fsd|sit|uat> …"`.
- Dispatch table: add row `| \`uat\` | \`mega-sdd:emit-uat\` | UAT test script untuk tim bisnis (skenario 1:1 F-*, berita acara, xlsx) | \`<vault>/uat/UAT.md\` (+ PDF/xlsx) |` and change both `prd|fsd|sit` literals in the prose (dispatch + unknown-positional lines) to `prd|fsd|sit|uat`.
- No-arg listing: change "probe the three doc paths" → four; add listing line `- UAT  <vault>/uat/UAT.md  — maturity: <draft|ready-for-uat|signed-off> (generated_at: …)`; closing hint → `<prd|fsd|sit|uat>`.

- [ ] **Step 2: `commands/mega-sdd.md`**

- Line 6 surface note: `/mega-sdd:emit <prd|fsd|sit>` → `<prd|fsd|sit|uat>` (and "the three team documents" → "the four team documents").
- Chain-boundary row (~line 111): `--doc=<fsd\|prd\|sit>` → `--doc=<fsd\|prd\|sit\|uat>`.
- Stale-LaTeX fix (~line 107): `(**OPT-IN** — requires \`--with-fsd\` flag; expensive pandoc/LaTeX deps)` → `(**OPT-IN** — requires \`--with-fsd\` flag; pandoc + Chrome md2pdf render)`.
- Add one proposal row under the emit-sit proposal row: `| At chain end | \`emit-uat\` **MENTION** (one line, never auto-run) when SIT.md exists | "Tim UAT butuh test script? \`/mega-sdd:emit uat\` menghasilkan skenario bisnis 1:1 dari flow + berita acara" |`

- [ ] **Step 3: `skills/using-mega-sdd/SKILL.md`**

Line ~21: `/mega-sdd:emit <prd|fsd|sit>` → `<prd|fsd|sit|uat>`. In the trigger census (line ~57 area), extend the emit entry's keyword list with `UAT`, `test script`, `skrip uji`, `berita acara UAT`.

- [ ] **Step 4: `references/emission-engine.md` registry + sidecar scripts**

- §Doc-pack registry: add row `| \`uat\` | \`emit-uat\` (SKILL.md + references/uat-sections.md + uat-template.md) — UAT-NNN ← F-NNN business scenarios aligned to SIT TS ids, placeholder-literal execution columns + berita acara (\`build-uat-scaffold.sh\`), zero-dep xlsx render (\`build-uat-xlsx.sh\`) | LIVE (5.3.0) |`.
- §Doc-pack sidecar scripts: add the `build-uat-scaffold.sh` bullet (fragment + `--check-execution` = the UAT lane's fabrication gate, `execution_fabricated`) and `build-uat-xlsx.sh` bullet (derived render, version-named `UAT-v<version>.xlsx`, exit-3 REFUSE contract, warn-only lane).
- Maturity-ladder cell in §What a doc-pack supplies: append `; UAT draft → ready-for-uat → signed-off`.

- [ ] **Step 5: `references/paths.md`**

In the vault tree after the `fsd/` block: fix `│   │   ├── FSD.pdf   # Rendered PDF (pandoc + LaTeX)` → `# Rendered PDF (md2pdf.sh — GitHub-style, never LaTeX)` and add sibling dirs:

```
│   │   ├── prd/                                   # PRD output (emit-prd): PRD.md, PRD.pdf, .citation-map.json, .doc-history.json
│   │   ├── sit/                                   # SIT output (emit-sit): SIT.md, SIT.pdf, .sit-evidence.md, .citation-map.json, .doc-history.json
│   │   ├── uat/                                   # UAT output (emit-uat): UAT.md, UAT.pdf, UAT-v<version>.xlsx, .uat-scaffold.md, .citation-map.json, .doc-history.json
```

(and add `.doc-history.json` to the fsd/ listing).

- [ ] **Step 6: CHANGELOG + version bump**

- `CHANGELOG.md`: new `## [5.3.0] - 2026-07-23` entry (Keep-a-Changelog style like 5.2.7): **Added** — emit-uat doc-pack (scaffold gate `execution_fabricated`, xlsx render, SEOJK berita acara), doc versioning engine (sidecar, `--bump`/`--approve`, Riwayat Revisi region); **Changed** — emitters pass `--bump`, enumerations `<prd|fsd|sit|uat>`; **Fixed** — stale pandoc+LaTeX comments in paths.md + mega-sdd.md. Reference the spec path.
- `plugins/mega-sdd/.claude-plugin/plugin.json` line 3 + `.claude-plugin/marketplace.json` line 13: `"5.2.7"` → `"5.3.0"` (both, lockstep).

- [ ] **Step 7: Verify + commit**

Run: `grep -rn 'prd|fsd|sit' plugins/mega-sdd/commands plugins/mega-sdd/skills/using-mega-sdd | grep -v 'prd|fsd|sit|uat'` → no remaining three-doc enums (deprecated alias files excepted — leave those untouched).
Run: `grep -n '"version"' plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json` → both `5.3.0`.

```bash
git add -A
git commit -m "feat(uat+versioning): dispatch, registry, enumerations, paths, changelog — v5.3.0"
```

---

### Task 7: Full verification + release push

**Files:** none new — verification only.

- [ ] **Step 1: Run the new + adjacent tests**

```bash
for t in test-doc-versioning test-p3-refresh-doc-stamps test-p3-emission-parity test-p5-sit-evidence test-uat-scaffold test-uat-xlsx; do
  bash tests/derived-artifacts/$t.sh </dev/null || echo "FAILED: $t"
done
bash tests/blackbox/test-blackbox-pipeline.sh </dev/null
```

Expected: every line PASS, no `FAILED:` output. Blackbox unaffected (no hook changes) — if it asserts doc enumerations, update its expectation to include `uat`.

- [ ] **Step 2: Run BOTH full suite trees in background** (memory lesson: CI runs both; local top-level alone is not green proof)

Run the repo's full suite runner(s) as background Bash with `</dev/null`, then the `tests/` tree runner if separate. Wait for completion; every test green. Fix any fallout (likely: a suite test that enumerates skills/commands counts — update expected counts for the new skill).

- [ ] **Step 3: Push**

```bash
git push origin main          # dual-leg; scm leg fails without VPN — expected
git push https://github.com/FarhanRiuzaki/Mega-SDD.git main   # ensure GitHub leg lands
```

Report: suite results, scm-leg status (pending VPN → user runs `git push origin main` later).

---

## Self-Review (done at plan-write time)

- **Spec coverage:** §3.1-3.6 → Tasks 3/4/5/6; §4.1-4.4 → Tasks 1/2; §5 → Task 6; §7 acceptance criteria 1-3 → Tasks 3/4/5 tests, 4-5 → Task 1 tests, 6 → Tasks 2/7. Spec's §3.2 RTM "FR" column is realized as F-id + Unit linkage (the pipeline's actual requirement anchors — FR ids are not reliably derivable from the vault; noted as a deliberate refinement, not a gap).
- **Placeholder scan:** none — every step carries code, exact strings, or an exact copy-source (file:line) instruction.
- **Type consistency:** placeholder literals, delimiter names, flag names, exit codes, and id schemes are defined once in Global Constraints / Task interfaces and reused verbatim across Tasks 3-5.

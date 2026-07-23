# /mega-sdd:emit-uat Trigger + Behavior Test

P5 — business-facing UAT test-script emitter on the shared emission engine (`--doc=uat`). Unfakeable execution/sign-off record via `scripts/build-uat-scaffold.sh --check-execution`; paper-out berita acara UAT (SEOJK 21/2017 §2.3.1.5); maturity ALWAYS `draft` at emit (upper rungs human-set); zero-dep tester workbook via `scripts/build-uat-xlsx.sh`.

## Trigger cases

### EU1: Explicit invocation → scaffold first, maturity draft
- **Setup:** vault + units with `04-flows.md` carrying F-* flows + DoD
- **Prompt:** `/mega-sdd:emit uat` (or "buat UAT" / "test script UAT" / "dokumen UAT")
- **Expect:** Skill invoked; Step 0 runs `build-uat-scaffold.sh --vault=… --cwd=…` FIRST (writes `.uat-scaffold.md`, prints `uat-scaffold: maturity=draft …`); announced maturity is `draft` — NEVER higher (the model never self-promotes; `ready-for-uat`/`signed-off` are human-set via `refresh-doc-stamps.sh --maturity=…`); UAT.md + .citation-map.json written to `<vault>/uat/`

### EU2: SIT absent / ≠ executed → §1 warning, not halted
- **Setup:** vault with flows but no `sit/SIT.md`, or a SIT whose doc-control maturity ≠ `executed`
- **Prompt:** "emit UAT"
- **Expect:** scaffold prints `WARN_SIT …`; §1 narrative opens with the SIT-not-executed callout block quote (`> ⚠ **SIT belum executed** — SEOJK 21/2017 §2.3.1.5 …`); emission is NOT halted (the berita-acara-SIT entry gate is warn-only — preparing UAT scripts early is legitimate)

### EU3: Step derivation — Aksi ↔ Mermaid nodes, Expected = DoD verbatim
- **Setup:** vault `04-flows.md` has `F-U-001` with a Mermaid body + DoD items
- **Expect:** §2 carries `### UAT-001 — … (F-U-001)` with the flow's Mermaid fence VERBATIM (never redrawn) + DoD items verbatim as expected outcomes; the `<!-- uat-steps:UAT-001 -->` marker is replaced with step rows whose Aksi traces 1:1 to the flow's Mermaid nodes (business language, one step per meaningful node), Expected Result = DoD verbatim, and execution cells are the EXACT placeholder literals (`__________` for Actual Result / Defect / Bukti; `[ ] Pass · [ ] Fail · [ ] Blocked` for Status). A flow with nothing to derive → ONE `[Pending — flow <F-id> belum punya diagram/DoD untuk diturunkan]` Aksi row (execution cells still placeholders)

### EU4: Execution-fabrication gate (the SEOJK record gate)
- **Setup:** an emitted UAT.md whose §2 Actual Result / Status cell, §3 Status UAT, or §4 sign-off/keputusan cell was filled (e.g. `| 1 | Login | … | Berhasil | [x] Pass | — | screenshot |`)
- **Prompt:** `/mega-sdd:emit uat` (re-emission — Step 0 guard) OR Step 4.7 during emission
- **Expect:** `build-uat-scaffold.sh --check-execution` exits 1 with `EXECUTION_FILLED` / `RTM_FILLED` / `BA_FILLED` / `SIGNOFF_FILLED` (or `STEPS_MISSING` for an unreplaced marker) + keterangan; halt `quality_gate_failed:execution_fabricated`; NO render; the model NEVER "completes" the result — it restores the placeholder literals (`__________`, `[ ] Pass · [ ] Fail · [ ] Blocked`, `[ ] Diterima · [ ] Ditolak`, `[ ] Go · [ ] No-Go`)

### EU5: Multi-scope merged UAT (decision 10)
- **Setup:** two vaults with `scope_metadata.id: BE` / `FE`
- **Prompt:** `/mega-sdd:emit uat --vaults=<v1>,<v2>`
- **Expect:** the skill translates `--vaults=v1,v2` into repeated `--vault=` for the script; ONE merged UAT; ids `UAT-BE-001` aligned 1:1 with `TS-BE-001` (SIT); Scope column in §1/§3; per-scope berita-acara sign-off tables (`### Sign-off — Scope BE`); merged in the first vault's `uat/`

### EU6: xlsx lane — first write, version bump, never overwrite
- **Setup (a):** first emission, no existing workbook
- **Expect (a):** Step 6.6 `build-uat-xlsx.sh --vault=…` writes `UAT-v0.1.xlsx` (version from `.doc-history.json`, default `0.1`)
- **Setup (b):** re-emission after a `--bump` version rise
- **Expect (b):** a NEW `UAT-v<newversion>.xlsx` is written
- **Setup (c):** the target `UAT-v<version>.xlsx` already exists
- **Expect (c):** exit 3 REFUSE surfaced as a WARNING line (tester may have filled it); never overwritten, never a halt; `--no-xlsx` skips the render entirely

### EU7: Doc-control + versioning script-owned
- **Expect:** Step 6 runs `refresh-doc-stamps.sh --doc=uat --maturity=draft … --bump --change-note="<drift-derived>"` (change-note: `Emisi awal` on `NO_PRIOR`, else `Regenerasi §… — <n> sumber berubah`, else `Re-emisi tanpa perubahan sumber`); the model never types the `<!-- mega-sdd:doc-control -->` block, the `version`/`status` fields, or the Riwayat Revisi region; `--approve` is NEVER model-run (whole-version bump + `signed-off`/`ready-for-uat` are human governance)

### EU8: Routing — emit verb dispatch
- **Setup:** the 5.0.0 `emit` command surface
- **Expect:** the bare `/mega-sdd:emit` maturity listing shows the 4th doc (UAT) alongside PRD/FSD/SIT (maturity from its doc-control stamp, `belum pernah di-emit` when absent); `/mega-sdd:emit uat` dispatches `mega-sdd:emit-uat` via the **Skill tool** (never the Agent tool — the doc-pack gates key on Skill calls), remaining args passed through unchanged

## Pass criteria

All EU1–EU8 per `skills/emit-uat/SKILL.md` Procedure. §1–§4 tables/RTM/berita-acara byte-identical to the `.uat-scaffold.md` fragment blocks (model adds narrative + §2 step rows only). Announced maturity is `draft` on every path.

## Anti-halu rail verification

- Execution results / RTM status / sign-off cells never model-authored; a filled cell = fabricated record → deterministic `execution_fabricated` halt (`--check-execution`), not a prose-trusted check
- §2 Aksi rows trace 1:1 to the flow's Mermaid nodes; a flow with nothing to derive gets one `[Pending — …]` row, never invented steps
- Mermaid verbatim; DoD verbatim as Expected Result
- Citations stamped by `build-citation-map.sh --doc=uat`; the model writes only `(sha256: pending)`
- Maturity ALWAYS `draft` at emit; `version` / `status` / Riwayat Revisi script-owned (`refresh-doc-stamps.sh`)

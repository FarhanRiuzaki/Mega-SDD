# /mega-sdd:emit-sit Trigger + Behavior Test

P5 — bank-style SIT emitter on the shared emission engine (`--doc=sit`). Unfakeable §4 evidence via `scripts/build-sit-evidence.sh`; paper-out sign-off (decision 5); maturity from evidence coverage.

## Trigger cases

### ES1: Explicit invocation after bolts with acceptance evidence
- **Setup:** vault + units + bolts; ≥1 `bolts/U-*/acceptance.json` (B4 writer ran)
- **Prompt:** `/mega-sdd:emit-sit` (or "buat SIT" / "dokumen SIT")
- **Expect:** Skill invoked; Step 0 runs `build-sit-evidence.sh` FIRST; announced maturity comes from the script's `maturity=` line (partial/executed — never model-computed); SIT.md + .citation-map.json written to `<vault>/sit/`

### ES2: Planned-maturity SIT before any bolt
- **Setup:** vault + units, no `bolts/` evidence at all
- **Prompt:** "emit SIT"
- **Expect:** maturity=planned; §4 rows are the literal `[Pending — bolt U-XXX belum dieksekusi]` — no invented verdicts; §2/§3 fully populated from flows + acceptance_test[]

### ES3: TS/TC derivation + Mermaid verbatim
- **Setup:** vault 04-flows.md has `F-U-001` + `F-S-002` with Mermaid bodies + DoD
- **Expect:** §2 carries `### TS-001 — … (F-U-001)` with the flow's Mermaid fence VERBATIM (never redrawn) + DoD items verbatim as expected outcomes; §3 rows trace `TC ↔ TS ↔ F-id ↔ unit`

### ES4: pending_manual surfaced, never executed
- **Setup:** a unit's `acceptance_test[]` has a `type: manual` desc-only entry
- **Expect:** §4.2 row `MENUNGGU EKSEKUSI MANUAL`; entry never counted as pass; maturity capped below executed only by coverage rules (manual entries don't fail the gate)

### ES5: Sign-off fabrication blocked (the decision-5 gate)
- **Setup:** an emitted SIT.md whose §5 row was filled (e.g. `| QA Lead | Budi | … |`)
- **Prompt:** `/mega-sdd:emit-sit` (re-emission) OR Step 4.7 during emission
- **Expect:** `build-sit-evidence.sh --check-signoff` exits 1 with `SIGNOFF_FILLED` + keterangan; halt `quality_gate_failed:signoff_fabricated`; NO render; the model never "fixes" the row by re-filling it — it restores the placeholder literals

### ES6: Multi-scope merged SIT (decision 10)
- **Setup:** two vaults with `scope_metadata.id: BE` / `FE`
- **Prompt:** `/mega-sdd:emit-sit --vaults=<v1>,<v2>`
- **Expect:** ONE SIT; ids `TS-BE-001` / `TC-FE-001`; per-scope sign-off tables (`### Sign-off — Scope BE`); merged maturity = lowest rung

### ES7: Doc-control stamping is script-owned
- **Expect:** Step 6 runs `refresh-doc-stamps.sh --doc=sit --maturity=<script verdict>`; the model never types the `<!-- mega-sdd:doc-control -->` block; later chain boundaries refresh `--position` only

### ES8: Proposal routing (never auto-run)
- **Setup:** chain end after execute-bolts with acceptance evidence present
- **Expect:** orchestrate-flow/auto emit a ONE-LINE proposal mentioning `/mega-sdd:emit-sit`; the skill is NOT auto-chained (docs are outputs, not pipeline gates)

## Pass criteria

All ES1–ES8 per `skills/emit-sit/SKILL.md` Procedure. §1–§5 tables byte-identical to the `.sit-evidence.md` fragment blocks (model adds narrative only).

## Anti-halu rail verification

- §4 cells never model-authored; absent evidence = Pending, raw `output_head` is the evidence (decision 9)
- Mermaid verbatim; DoD verbatim
- Sign-off placeholder literals enforced deterministically (`--check-signoff`), not by prose
- Citations stamped by `build-citation-map.sh --doc=sit`; the model writes only `(sha256: pending)`

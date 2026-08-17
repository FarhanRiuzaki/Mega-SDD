# Halt guidance — emit family

Per-type guidance for halts emitted by: emit-* doc lane (citation, sign-off, automated-execution evidence).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### pdf_render_failed

- `pdf_render_failed` — emit-fsd: pandoc exited non-zero during PDF render in §Step 5.3. Details include `pandoc_stderr_tail` (last 500 chars). Resolution: inspect md2pdf stderr; md2pdf uses pandoc+Chrome (GitHub style, never LaTeX) and falls back to HTML without Chrome — install pandoc/mmdc via `/mega-sdd:install-deps`, re-run emit-fsd.

### template_slot_unfilled

- `template_slot_unfilled` — emit-fsd: an FSD-template slot marker `{{slot_name}}` remained unfilled in `FSD.md` output (internal bug — section-mapping.md missing extraction rule for the slot). Resolution: file plugin bug; meanwhile run emit-fsd with `--sections=<subset>` to skip the affected section.

### citation_unresolvable

- `citation_unresolvable` — emit-fsd: `scripts/build-citation-map.sh` exited 1, for either (or both) of two causes: FSD.md cites a source path that does not resolve to an existing file (fabricated or stale citation), OR a leftover `pending` sha256 stamp sits outside code fences with no resolvable path candidate before it. Details carry the script's verbatim output lines — `UNRESOLVED <section> <path>` (one per unresolvable citation) and `LEFTOVER <lineno>: <line>` (one per orphaned pending stamp). Resolution: correct the citation to a real artifact (or remove/repair the orphaned stamp) OR run the producing phase (scan-codebase / bind-codebase / generate-units / execute-bolts), then re-run emit-fsd.

### signoff_fabricated

- `signoff_fabricated` — emit-sit: a §5 Sign-off body row in `SIT.md` carries non-placeholder text in the Nama / Tanggal / Tanda-tangan / Status cells, detected deterministically by `scripts/build-sit-evidence.sh --check-signoff` (exit 1). Details carry the script's verbatim `SIGNOFF_*` lines + keterangan. A model/AI-filled sign-off row is a FABRICATED RECORD (paper-out): approval is written by hand on the printed document. Resolution: restore the placeholder literals (`__________` cells; `[ ] Diterima · [ ] Ditolak` status), re-run emit-sit. The emitter NEVER "fixes" a row by re-filling it. (The `template_slot_unfilled` / `citation_unresolvable` / `pdf_render_failed` subtypes above are shared by all three doc-pack emitters — emit-fsd / emit-prd / emit-sit — via the emission engine.)

### execution_fabricated

- `execution_fabricated` — emit-uat: a §2 execution cell / tester footer, §3 RTM status, or §4 berita-acara/sign-off cell carries non-placeholder text, OR the §5 automated-evidence annex body does not byte-match the script recompute from on-disk `result.json` (`ANNEX_FORGED` — `_lib/uat_annex.py` recomputes the RENDER; result.json integrity rests on the write guard), detected deterministically by `scripts/build-uat-scaffold.sh --check-execution` (exit 1). Details carry the script's verbatim violation lines (`EXECUTION_FILLED` / `EXECUTION_SHAPE` / `STEPS_MISSING` / `RTM_FILLED` / `BA_FILLED` / `SIGNOFF_FILLED` / `SIGNOFF_SHAPE` / `BA_SECTION_MISSING` / `ANNEX_FORGED`) + keterangan. A model/AI-filled execution result is a FABRICATED TEST RECORD (SEOJK context): real UAT results are captured by HUMANS in the xlsx workbook / berita acara; the §5 annex is rendered ONLY by `build-uat-e2e.sh --annex` from evidence `uat-run.sh` (sole hook-guarded writer) produced. Resolution: restore the placeholder literals (§2–§4) / re-run `--annex` (§5), re-run emit-uat. The emitter NEVER "completes" a result.

### marker_stripped

- `marker_stripped` — emit-prd: a PRD line citing a knowledge-base claim lost (or upgraded) that claim's `[VERIFIED]/[INFERRED]/[OPEN]` confidence marker, detected deterministically by `scripts/check-prd-markers.sh` (exit 1). Details carry the script's verbatim `MARKER_STRIPPED` / `MARKER_UPGRADED` / `MARKER_MISSING` lines + keterangan. An `[INFERRED]`/`[OPEN]` claim presented as fact is fabrication (invariant 5). Resolution: restore the marker verbatim from the cited KB claim on each flagged line, re-run the check / emit-prd.

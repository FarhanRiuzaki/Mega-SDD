# diff-vault Trigger + Behavior Test

Manual-run fixture for `diff-vault` skill.

## Trigger cases

### DV1: Explicit with new PRD path
- **Prompt:** `/mega-sdd:diff-vault ./new-prd.md`
- **Expect:** Skill invocation; compares against existing vault in CWD

### DV2: Natural English
- **Prompt:** `PRD updated, regenerate vault from new PRD`
- **Expect:** Skill invocation

### DV3: Natural Indonesian
- **Prompt:** `PRD versi baru, update vault dong`
- **Expect:** Skill invocation

### DV4: Auto-route from orchestrate-flow (PRD newer than vault)
- **Setup:** existing vault, `prd.md` mtime newer than `vault.json` mtime
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes diff-vault as first step (overrides other proposals)

### DV5: Delta lane — ticket-scale chat brief against an owned vault
- **Setup:** existing BOUND vault whose `03-data-model.md` owns entity `nasabah`; no new PRD file
- **Prompt:** `/mega-sdd "tambah kolom npwp di form nasabah"`
- **Expect:** front door proposes the DELTA chain — `diff-vault --from-prompt` → claim-scoped re-bind (`--paths=@<vault>/.delta-changed-paths.txt`) → `generate-units --reconcile` → stale/new bolts; NOT a new vault via generate-intent Mode B

### DV6: Delta lane — over-cap brief halts, nothing applied
- **Setup:** as DV5 but the brief describes 4 new entities + 2 new flows
- **Prompt:** `/mega-sdd "bikin modul deposito: produk, bunga, rollover, penalti, form pembukaan, flow pencairan"`
- **Expect:** diff-vault Step 3 halts `delta_too_large` (ALWAYS STOP, even --auto); vault untouched; options full_lane / split_ticket / cancel each with keterangan; full_lane routes to `generate-intent --from-prompt`

### DV7: Delta lane — unbound vault falls through (exit 3)
- **Setup:** vault exists but NO `binding.json` (never bound)
- **Prompt:** `/mega-sdd "tambah kolom npwp di form nasabah"` → user picks the delta option
- **Expect:** diff-vault applies the patch; `derive-delta-paths.sh` exits 3; NO scoped bind hop — the router proposes the normal chain rows (no fabricated `--paths`)

### DV8: Greenfield brief unchanged (guard)
- **Setup:** NO vault in CWD
- **Prompt:** `/mega-sdd "build a clinic appointment system"`
- **Expect:** Mode B unchanged — `generate-intent --from-prompt` chain; the delta lane NEVER fires without an existing owned vault

## Behavior checks

### B1: Structured diff produced
- Output: `DIFF.md` (or similar) at vault parent dir
- Lists added / changed / removed sections
- Each entry cites old vault line + new PRD section

### B2: Resolved-OQ preservation
- **Setup:** vault has resolved OQ (OQ-001 with stakeholder answer in changelog), new PRD contradicts it
- **Expect:** Skill emits `blocker` (type=`diff_conflict`) — does NOT silently overwrite resolved decision

### B3: ADR vs new PRD conflict surfacing
- **Setup:** vault has ADR explicitly choosing approach X, new PRD suggests approach Y
- **Expect:** Skill emits `blocker` (type=`diff_conflict`), pauses for user resolution

### B4: --auto flag respects blockers
- Even with `--auto`, conflict blockers ALWAYS pause and surface to user
- Logistical prompts (e.g., "apply this addition?") are auto-confirmed

### B5: Vault version bump on apply
- After approved diff: `vault.json` version increments, changelog entry added, OQ identity preserved

### B6: From-prompt provenance (delta lane)
- **Setup:** DV5 flow, apply clean
- **Expect:** report header `New source: chat brief (--from-prompt)` + `prd_sha256_changed: n/a`; `prd_sha256`/`prd_path_at_generation` NOT re-baselined; `source_documents[]` gains an APPENDED `type: brief` entry (PRD entry not replaced); Small bump only

## Pass criteria

All trigger cases invoke skill. Conflict blockers surface (never silent), version bump and changelog on apply. Delta lane: propose-first (a bare "tambah kolom X" with no mega-sdd intent routes nowhere), cap always stops, fail-closed edges route per routing-rules §Delta lane detail.

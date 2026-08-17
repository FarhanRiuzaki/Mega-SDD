# Halt guidance — intent-and-vault family

Per-type guidance for halts emitted by: generate-intent · diff-vault · resolve-oq (vault birth + evolution).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### oq_blocker

**`oq_blocker`** — emitted by `generate-intent` (when generation surfaces a P1 that would block downstream tasks) or by AI consumers reading the vault non-interactively. The `tag` is the OQ identifier. `priority` is always `P1` (lower priorities don't halt).

### diff_conflict

**`diff_conflict`** — emitted by `diff-vault` Step 5 when a Resolved-OQ conflict or Decision conflict requires stakeholder input. `tag` is the OQ or ADR ID. `priority` is `n/a` (conflicts aren't priority-tagged). `conflict_old`, `conflict_new`, `options` are required.

Registry one-liner (absorbed, same type):

- `diff_conflict` — diff-vault: Resolved-OQ or Decision conflict requires stakeholder input. ALWAYS STOP (user resolves via diff-vault interactive walk). Emitted by `diff-vault`.

### delta_too_large

- `delta_too_large` — diff-vault (`--from-prompt` cap, Step 3): a chat-brief delta exceeds the ticket-scale cap (new entities+flows > 2, changed rows > 12, any new scope, or a major scope shift) — an epic may not masquerade as a delta. ALWAYS STOP; nothing applied, vault untouched. Keterangan: brief ini terlalu besar untuk delta lane — pilih `full_lane` (vault/epic baru via generate-intent), `split_ticket` (pecah jadi beberapa tiket kecil di bawah cap, jalankan delta lane per tiket), atau `cancel` (batal; vault tidak berubah). Emitted by `diff-vault`.

### oq_recommend_citation_invalid

- `oq_recommend_citation_invalid` — generate-intent: OQ recommendation cites non-existent KB section. ALWAYS STOP.

### prd_no_scopes_block_user_rejected_retrofit

- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chose cancel. ALWAYS STOP. Resolution: user manually retrofits PRD OR re-runs with single-scope fallback.

### prd_path_missing

- `prd_path_missing` — diff-vault: `vault.json.prd_path_at_generation` points to non-existent PRD file. ALWAYS STOP. Resolution: user restores the PRD at the recorded path OR regenerates the vault with the current PRD.

### prd_retrofit_low_confidence

- `prd_retrofit_low_confidence` — generate-intent: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP. Resolution: user reviews and accepts anyway / chooses single-scope fallback / cancels.

### scope_not_declared_in_prd

- `scope_not_declared_in_prd` — generate-intent: `--scope=<id>` flag references a scope ID that's not in the PRD's `scopes:` frontmatter block. ALWAYS STOP. Resolution: user picks a valid scope from PRD's declared list OR cancels.

### oq_tech_missing_mode

- `oq_tech_missing_mode` — generate-intent: PRD declares technical OQ but `resolution_mode` field missing on the OQ entry (can't classify as `tech / scan` vs `tech / recommend`). ALWAYS STOP. Resolution: user adds `resolution_mode: scan` or `resolution_mode: recommend` to the OQ entry; re-run generate-intent. Source skill: `generate-intent`. *(Field grammar is the §Updated OQ schema — `resolution_mode`, not the pre-v-fix `mode`.)*

### oq_scan_missing_query

- `oq_scan_missing_query` — generate-intent: an OQ marked `resolution_mode: scan` lacks the `scan_query` field that tells `bind-codebase` Tech-OQ auto-resolver what to grep for. ALWAYS STOP. Details `{oq_id}`. Resolution: user adds `scan_query: codebase-map §<section>` or `scan_query: <file-pattern>` to the OQ entry. Source skill: `generate-intent`.

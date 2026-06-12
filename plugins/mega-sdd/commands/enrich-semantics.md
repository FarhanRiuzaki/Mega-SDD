---
description: Retro-fit staged-input semantics onto an existing knowledge base without a full re-extract. Re-reads cited legacy _source, detects the multi-step wizard / maker-checker pattern, and PROPOSES a `stages:` block per workflow for review (two-phase; --apply patches only after you accept).
argument-hint: --vault=<path> [--legacy-root=<path>] --semantic=staged-input [--apply]
---

> **Auto integration:** `/mega-sdd:auto` runs this step automatically in **propose** mode whenever a KB carries a `kb_flow_staging_missing` advisory — it writes `ENRICHMENT-PROPOSALS.md` and PAUSES for your review (never auto-applies). `--legacy-root` is OPTIONAL: when omitted it is auto-discovered from the KB README's "source codebase path" + common legacy dirs (`old-reference/`, `legacy/`, …). Pass `--legacy-root` explicitly to override. Disable the auto step with `--no-enrich-staging` on `auto`.

Run the semantic-depth enrichment helper `plugins/mega-sdd/scripts/enrich-workflows-staging.sh` to retro-fit staged-input structure onto a knowledge base whose workflows were extracted before staged-input capture existed (the flattened "single Inputs list" that makes bolts build a single form instead of a multi-step wizard).

User arguments: $ARGUMENTS

**Walking-skeleton scope:** only `--semantic=staged-input`. Other semantic-depth dimensions (conditional logic, role matrices, transition guards) are not yet supported by this helper.

**Two-phase — never auto-apply (discipline: "jangan auto-apply tanpa konfirmasi"):**

1. **Propose (default — no `--apply`).** Run the script with `--vault=<path> --legacy-root=<path> --semantic=staged-input`. It:
   - scans KB workflows that lack a `stages:` block,
   - re-reads their cited legacy `_source` files under `--legacy-root`,
   - detects the staged-input pattern (hidden `step`/`stage` field, step request param, ≥2 stage-conditional branches, ≥2 `<form>` blocks),
   - allocates fields read within each stage's conditional block,
   - writes `<vault>/ENRICHMENT-PROPOSALS.md` with a candidate `## 3a` `stages:` block per workflow.
   - It also surfaces any workflow `validate-kb-flows.sh` already flagged with the `kb_flow_staging_missing` advisory.
   Then SHOW the user `ENRICHMENT-PROPOSALS.md` and STOP. The candidate roles / field-to-stage allocation / triggers are best-effort and explicitly marked `# REVIEW`.

2. **Apply (only after the user reviews + accepts).** Re-run with the same args plus `--apply`. It patches each KB workflow file in-place (inserts `## 3a. Staged inputs` + the `stages:` block) and propagates the block into any vault `04-flows.md` flow whose `_kb_source` already cites that KB workflow (deterministic match). After applying, re-save `04-flows.md` so `validate-vault-flow-staging.sh` confirms the staging was not dropped.

**Safety:** the helper never edits legacy source. Point `--legacy-root` at the legacy codebase you are rebuilding FROM (read-only). Do NOT run `--apply` against production KB data without reviewing the proposals first. (Per project rule, do not point this at the trade-finance import session's KB except in that session.)

# JIT bind per wave + quarantine — the pre-flight 3.9 / 3.10 procedures

Loaded by `execute-bolts` SKILL.md pre-flight 3.9 / 3.10 ONLY when one of them
triggers (3.9: the run is lite — front-door `--lite` or `derived.lane: lite` — OR a unit in the wave carries `## Claims` /
`existing_interfaces`; 3.10: a DEFER-class halt fires on a unit). A default classic
greenfield wave never reads this file. Spec: `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md`
Appendix F2–F4 (JIT bind) and F6c (quarantine); audit
`research/2026-09-10-p0-interaction-audit.md` §C (which halts wait for a human).

## Contents

- [3.9 JIT bind per wave](#39-jit-bind-per-wave-spec-app-f2f4)
- [3.9b The BOLTS gate denied a dispatch](#39b-the-bolts-gate-denied-a-dispatch-state-anchor-spec-2026-09-25-8)
- [3.10 Quarantine instead of parking](#310-quarantine-instead-of-parking-w1-zero-idle-spec-app-f6c)

## 3.9 JIT bind per wave (spec App. F2–F4)

Three script calls per wave, never hand-written verdicts. Every path below is a
script; the model's only judgment is the ladder E3 verdict on `text` claims.

0. **Index first — conditional, per bind (state anchor, spec 2026-09-25 §9).** When the wave
   carries `symbol` claims and `.mega-sdd/codebase/symbol-index.json` is absent, its
   `head_commit` ≠ HEAD (an earlier wave committed), or its recorded dirty map differs from
   the current one on the wave's scope (the rule `rebind-units.sh` applies), run
   `bash <plugin-root>/scripts/build-symbol-index.sh --cwd=<root>` BEFORE step 1 (exit 3 = no
   ast-grep → proceed; symbol claims stay OQ). Otherwise the writer stamps every unit with
   an index-sourced verdict `null` (`index_stale` / `dirty_index`) and each first dispatch is
   denied. Never per bolt.

1. **Derive the wave's claim set — ONE call per wave.**
   `bash <plugin-root>/scripts/derive-unit-claims.sh --cwd=<root> --vault=<vault> --units=U-001,…`
   Writes `<vault>/bolts/_wave-claims.json` (one stable file, overwritten per
   wave; the FULL head and the wave's `dirty` capture recorded inside) from `target_files` (create ⇒ must-not-exist;
   modify/delete ⇒ must-exist), `## Anchors`, `existing_interfaces`, and
   `## Claims`. stdout is one JSON line `{"jit_bind": {units, fs_claims,
   symbol_claims, text_claims, out}}` — **`symbol_claims=text_claims=0` means
   the wave costs ZERO model tokens; say so in the report** (the measured no-op).
2. **Verdict + write — one call per unit, the sole writer.**
   `bash <plugin-root>/scripts/write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --claims=<vault>/bolts/_wave-claims.json`
   - `fs_*` claims are verdicted by the script from the filesystem; `symbol`
     claims from `.mega-sdd/codebase/symbol-index.json` (in the expected file →
     CONFIRMED; only elsewhere → CONFLICT collision; nowhere → OQ; index absent
     → OQ with the reason). Nothing for the model to do.
   - **Stale line-range anchors are repaired by the writer, never by hand (`research/2026-09-15-v8-p3-report.md §5`).** A `## Anchors` range that no longer fits the file is re-verdicted against the anchor's *authoring snapshot* (the commit that introduced that token into the unit file): **R1-shift** when the authored lines exist verbatim, uniquely, at another offset; **R2-clamp** when the file is byte-identical to the snapshot and EITHER the range overshoots EOF by exactly one line (the trailing-newline miscount — the live class: clinic U-008 / xs U-006) OR the range is a whole-file anchor (`<file>:1-N`, any overshoot — lines past EOF never existed, so lines 1..n ARE what the author read; e.g. `login/page.tsx:1-25` on an unchanged 22-line file). Both record `repair: {from, to, rule, reference, content_sha256}` on the claim (+ `repairs[]` in `binding.json`) and rewrite the unit's `## Anchors` token, so the next bind sees it fit. Changed content, a non-unique match, a PARTIAL range (start > 1) overshooting by more than one line, or no snapshot ⇒ **CONFLICT** — resolve via `resolve-oq --binding` (KEEP_CODE + a hand-corrected anchor is still the human path for those). Never pre-empt the writer by editing an anchor to make a claim pass.
   - For each `text` claim run the express-bind ladder E3 VERBATIM
     (`bind-codebase/references/express-bind.md §Step E3`: index → targeted
     Read → collision sweep two legs → bounded grep → KB → ungrounded ⇒
     OQ/CONFLICT, **never CONFIRMED-by-absence**). Write your verdicts to a
     temp JSON `{"<claim-id>": {"verdict", "state", "anchor", "confidence",
     "evidence"}}` and re-run the writer with `--verdicts=<file>`. The writer
     REFUSES (exit 3) a CONFIRMED without an anchor, a verdict outside
     CONFIRMED|CONFLICT|OQ, and a `--resolve` on a non-CONFLICT claim.
   - **In-range anchors go through the content ladder (D22):** a block whose content changed
     since it was bound is CONFIRMED only when it moved verbatim (R1-shift repair), changed
     only through THIS unit's own bolt commits (`IMPLEMENTED_BY_UNIT`), or still contains the
     anchor line's backticked label (`ANCHOR CHANGED (verify before use)` in the dispatch
     prompt); anything else is **CONFLICT `anchor_content_drift`** → the same
     `binding_conflict` halt below. Never edit an anchor to make a claim pass.
   - **The stamp is honest (state anchor §3):** `based_on_sha` is the oldest SHA behind the
     verdicts, or `null` with a `null_cause`. The writer re-derives the unit's claims with the
     SAME parser (`_lib/unit_claims.py`) and REFUSES (exit 3) when they drifted since the
     capture, or when a `--verdicts` pass reads a different claims file than its first pass.
   - Output `<vault>/bolts/U-XXX/binding.json` is hook-guarded evidence
     (the same PreToolUse evidence-deny as preflight/postflight/acceptance):
     Write/Edit/Bash to it is denied; only the writer changes it.
3. **Gate — unit-scoped, the same hook.**
   `bash <plugin-root>/scripts/validate-handoff-binding-units.sh --cwd=<root> --units=U-001,…`
   FAIL with `conflict_unresolved` drops ⇒ **halt `binding_conflict`** —
   ALWAYS STOP for those units (this is one of the three halts allowed to
   wait for a human, §3.10). Keterangan for the human: *klaim unit bertentangan
   dengan kode — pilih KEEP_VAULT / KEEP_CODE / SPLIT lewat `resolve-oq
   --binding`, yang menulis balik via `write-unit-binding.sh --resolve=<claim-id>=<pilihan> --by=user`; file binding.json ter-guard hook, jangan
   diedit.* Units without CONFLICT proceed; a CONFLICT unit's dependents are
   skipped with the reason. The PreToolUse gate re-runs this validator with
   `--units=<unit>` on every `bolt-implementer` dispatch — a hand dispatch
   cannot bypass it.

`sync --full-bind` runs the same three calls over EVERY unit of the vault
(the adoption / BA-QA audit sweep — "apakah kode sinkron dengan spec").

**3.9 runs on every layout-3 vault** too (not only under `--lite` / `lane: lite`): a
plan-born vault's units are gated per unit at dispatch.

## 3.9b The BOLTS gate denied a dispatch (state anchor, spec 2026-09-25 §8)

Every `bolt-implementer` dispatch re-checks the unit's binding (`binding-freshness` leg of
the PreToolUse aggregator). It denies only a move that landed AFTER this wave's 3.9 — a
fix round after a teammate commit, a mid-wave sibling commit, a pull during the run. Read
the reason in the deny, then:

| Deny | What you do |
|---|---|
| `binding_stale`, `diverged`, `stamp_unreachable`, `unit_changed_since_bind`, `binding_legacy`, `binding_absent`, `binding_unparseable`, `stamp_null` (`index_stale` / `dirty_index` / `evidence_off_line`) | **3.9b:** `bash <plugin-root>/scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=U-XXX` (it rebuilds a stale index first and captures per unit — `bolts/U-XXX/_claims.json`); run E3 for its `text_pending` claims with `--claims=<that file>`; rebuild `dispatch-prompt.md` with `build-dispatch-prompt.sh`; re-dispatch. A re-bind that yields CONFLICT → the `binding_conflict` halt |
| `stamp_null` (`writer_capture_moved`) | HOLD while a moved path belongs to another unit whose implementer is still running; then 3.9b |
| `uncommitted_in_scope` | **Never `git stash`, never commit, restore or reset edits you did not make** (the wave commit rail denies stash anyway). (i) a listed path is in the `target_files` of another unit whose implementer is running → HOLD this unit (no re-bind, no attempt spent); re-check when that implementer returns, then 3.9b. (ii) otherwise → quarantine (§3.10) with `--halt=binding_stale`, the question listing the paths: a human commits or discards them, then RETRY |
| `rebind_exhausted` | quarantine with `--halt=binding_stale` — one 3.9b at this HEAD already failed; never a second one |
| `dispatch_prompt_stale`, `dispatch_prompt_missing`, `unit_identity_conflict`, `unit_identity_foreign`, `unit_ambiguous` | rebuild the prompt with `build-dispatch-prompt.sh` and dispatch with its pointer; never a re-bind |
| classic `stamp_unreachable` | re-run `bind-codebase` for that vault (or `/mega-sdd:sync`); never 3.9b |
| `not_evaluated` | a human halt (one screen, keterangan): fix git access (`git config --global --add safe.directory <root>`, a wedged `index.lock`, fsmonitor), then re-dispatch |

A deny spends no attempt. The one-re-bind bound is a mechanism: a 3.9b writes
`rebind_head`, and a second deny at the same HEAD arrives as `rebind_exhausted`.

## 3.10 Quarantine instead of parking (W1 zero-idle, spec App. F6c)

Only three halts may stop the run and wait for a human: `binding_conflict` /
`bind_conflict`, `hard_rule_violated`, and OQ P1 business — plus one exception the
owner kept blocking as CONFLICT-like: `bolt_introduces_locked_drift`
(a bolt touched a LOCKED entity; pure-pause, override-only, never proposed). Every other
DEFER-class halt on a unit (L0 trio, B1–B4 evidence, `review_critical_unresolved`,
`test_fail` after the retry budget, `ambiguous_spec`, `anchor_missing`,
`dispatch_prompt_too_large`, `commit_rejected_by_hook`, `binding_stale` (the state-anchor
gate after its one 3.9b, §3.9b), …) is RECORDED and the wave continues:

```
bash <plugin-root>/scripts/write-unit-quarantine.sh --cwd=<root> --vault=<vault> \
  --unit=U-XXX --halt=<halt_type> --reason="<one line>" [--envelope=<halt yaml file>] \
  --dependents=<units skipped via depends_on>
```

- The gate still blocks THAT unit (its evidence is never written); its
  dependents are skipped with the reason; the wave continues.
- `compute-unit-staleness.sh` reports such units as `status: quarantined`
  (the record outranks a bolt-report).
- `_summary.md` MUST carry a **Karantina** table — unit · halt · reason ·
  dependents skipped · the ONE question. Render `quarantine.json`'s `question`
  object VERBATIM: its `text`, `source`, and the three options RETRY / MANUAL /
  DROP each with its `keterangan` (Indonesian; never collapse them to bare
  enums). The human answers once, at the end, never mid-run.
- Release after the answer: `write-unit-quarantine.sh --cwd=<root> --vault=<vault> --unit=U-XXX --release --by=user`
  (RETRY / MANUAL); a DROP is recorded as an OQ so the requirement is not
  lost silently.

The three BLOCKING halts keep the one-screen shape in
`references/propose-and-confirm-prompt.md §One-screen halt`.

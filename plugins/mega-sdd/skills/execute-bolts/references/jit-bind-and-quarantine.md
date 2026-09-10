# JIT bind per wave + quarantine — the pre-flight 3.9 / 3.10 procedures

Loaded by `execute-bolts` SKILL.md pre-flight 3.9 / 3.10 ONLY when one of them
triggers (3.9: the run is lite — front-door `--lite` or `derived.lane: lite` — OR a unit in the wave carries `## Claims` /
`existing_interfaces`; 3.10: a DEFER-class halt fires on a unit). A default v7
greenfield wave never reads this file. Spec: `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md`
Appendix F2–F4 (JIT bind) and F6c (quarantine); audit
`research/2026-09-10-p0-interaction-audit.md` §C (which halts wait for a human).

## 3.9 JIT bind per wave (spec App. F2–F4)

Three script calls per wave, never hand-written verdicts. Every path below is a
script; the model's only judgment is the ladder E3 verdict on `text` claims.

1. **Derive the wave's claim set — ONE call per wave.**
   `bash <plugin-root>/scripts/derive-unit-claims.sh --cwd=<root> --vault=<vault> --units=U-001,…`
   Writes `<vault>/bolts/_wave-claims.json` (one stable file, overwritten per
   wave, head recorded inside) from `target_files` (create ⇒ must-not-exist;
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
   - For each `text` claim run the express-bind ladder E3 VERBATIM
     (`bind-codebase/references/express-bind.md §Step E3`: index → targeted
     Read → collision sweep two legs → bounded grep → KB → ungrounded ⇒
     OQ/CONFLICT, **never CONFIRMED-by-absence**). Write your verdicts to a
     temp JSON `{"<claim-id>": {"verdict", "state", "anchor", "confidence",
     "evidence"}}` and re-run the writer with `--verdicts=<file>`. The writer
     REFUSES (exit 3) a CONFIRMED without an anchor, a verdict outside
     CONFIRMED|CONFLICT|OQ, and a `--resolve` on a non-CONFLICT claim.
   - Output `<vault>/bolts/U-XXX/binding.json` is hook-guarded evidence
     (the same PreToolUse evidence-deny as preflight/postflight/acceptance):
     Write/Edit/Bash to it is denied; only the writer changes it.
3. **Gate — unit-scoped, the same hook.**
   `bash <plugin-root>/scripts/validate-handoff-binding-units.sh --cwd=<root> --units=U-001,…`
   FAIL with `conflict_unresolved` drops ⇒ **halt `binding_conflict`** —
   ALWAYS STOP for those units (this is one of the three halts allowed to
   wait for a human, §3.10). Keterangan for the human: *klaim unit bertentangan
   dengan kode — pilih KEEP_VAULT / KEEP_CODE / SPLIT lewat `resolve-oq
   --binding`, yang menulis balik via `write-unit-binding.sh --resolve
   <claim-id>=<pilihan> --by=user`; file binding.json ter-guard hook, jangan
   diedit.* Units without CONFLICT proceed; a CONFLICT unit's dependents are
   skipped with the reason. The PreToolUse gate re-runs this validator with
   `--units=<unit>` on every `bolt-implementer` dispatch — a hand dispatch
   cannot bypass it.

`sync --full-bind` runs the same three calls over EVERY unit of the vault
(the adoption / BA-QA audit sweep — "apakah kode sinkron dengan spec").

## 3.10 Quarantine instead of parking (W1 zero-idle, spec App. F6c)

Only three halts may stop the run and wait for a human: `binding_conflict` /
`bind_conflict`, `hard_rule_violated`, and OQ P1 business — plus one exception the
owner kept blocking as CONFLICT-like (2026-09-10): `bolt_introduces_locked_drift`
(a bolt touched a LOCKED entity; pure-pause, override-only, never proposed). Every other
DEFER-class halt on a unit (L0 trio, B1–B4 evidence, `review_critical_unresolved`,
`test_fail` after the retry budget, `ambiguous_spec`, `anchor_missing`,
`dispatch_prompt_too_large`, `commit_rejected_by_hook`, …) is RECORDED and the
wave continues:

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

# Legacy idioms — RPG / AS400 (IBM i)

Extraction-side idiom sheet (7.26.0, spec 2026-09-05-kb-verify-lane-design.md
Fase 4). Consumed by `domain-extractor` and `claim-verifier` dispatches when
the census `stacks` include any of `rpg / rpgle / rpg-copy / dds` — the
controller adds a `READ ALSO:` line pointing here. Every rule below is a
FIELD-PROVEN failure mode from the 2026-09-05 Host-AS400 audit (8 wrong claims,
2 money-direction), not theory. This is NOT a framework-conventions pack (those
target the rebuild stack); it teaches how to READ the legacy correctly.

## Contents

- Fixed-format mechanics (the false-negative traps)
- Semantics traps (the wrong-claim classes)
- Files, dictionaries, encoding
- Site inventory (what derive-site-census.sh extracts)

## Fixed-format mechanics (the false-negative traps)

1. **Opcode glued to factor 2.** `WRITERDDFLOT` = `WRITE` + `RDDFLOT`. A spaced
   grep (`WRITE RDDFLOT`) finds NOTHING and proves nothing. Search glued
   (`WRITERDDFLOT`, `UPDATRTLLOG`, `CHAINTLTX`) or read the region directly.
   **Absence-by-grep is not absence** — the audit's own lane A mis-declared a
   live output file dead on exactly this.
2. **Column 7 `*` = comment / dead code.** Whole retired subsystems live
   commented in place (a ~200-line dead GL path sat inside the Host mainline).
   A claim built on a col-7-`*` line documents history, not behavior — always
   check the comment column before citing.
3. **I-spec DS overlays are NOT cleared between reads.** A failed `CHAIN` leaves
   the previous record's values in every overlay array — "lookup miss" often
   means "stale data used", not "no-op".
4. **Indicators are reused across files.** `*IN10` can mean found/not-found for
   five different CHAINs in one program — track WHICH statement last set the
   indicator, never assume it belongs to the nearest file.
5. **`H` (half-adjust) column decides round vs truncate.** `DIV` without `H`
   TRUNCATES. Never write "rounding" (pembulatan) for a truncating loop — for a
   [LOCKED] interest formula that word choice changes regression numbers.

## Semantics traps (the wrong-claim classes)

6. **Negative guards: derive the truth table.** `TLXGTN IFNE 'Y'` means the
   block runs when NOT 'Y' — i.e. **'Y' = bypass**. The audit's worst
   inversions were all this class. For every `IFNE`/`ANDNE`/`ORNE` guard, write
   out which branch executes on which value before claiming semantics.
7. **`RETRN` without `*INLR` = stateful program.** Files stay open, variables
   and record buffers survive across CALLs — evaluate statement ORDER per call
   (a tier check before its CHAIN reads the PREVIOUS call's record). Behavior
   is history-dependent; document as-executed, not the author's comment.
8. **External data areas** (`*NAMVAR DEFN` + `IN`/`OUT`, or `U DS`): control
   fields with no DDS in the source set. Never guess their layout — the
   container is a data area, cite the DEFN/IN site and raise an `[OPEN]` with a
   `probe-glob:` for the missing artifact.
9. **`CALL` parameter mismatch is silent.** Caller and callee declare parm
   length/decimals independently (by reference); a `(11,2)` passed into a
   `(15,2)` is the classic decimal-data corruption. When documenting a CALL
   contract, read BOTH sides' parm definitions.
10. **`EXCPT` vs `WRITE`:** both are output ops; a WRITE-site sweep that checks
    only one misses the other.

## Files, dictionaries, encoding

11. **`REF(...)`/`REFFLD(...)` chase to *FREF dictionary files.** Most DDS
    fields are referenced (`R`) — their type/length/COLHDG/VALUES live in the
    field-reference file (TLFREF/GLFREF/…), not in the file's own DDS. When a
    *FREF is on disk, "type unknown" is a false [OPEN]; when it is missing,
    raise the OQ WITH a `probe-glob:` so its arrival is detected.
12. **`FORMAT(X)` borrows another file's record format** — the field
    composition lives in file X's DDS; the *FREF gives per-field types but NOT
    the format's field order. Scope the [OPEN] precisely.
13. **Encoding:** exports may be EBCDIC/CP-x — census rows carry
    `"encoding": "non-utf8"` (derive-extract-census probe). Convert before
    reading; never cite mojibake.

## Site inventory (what derive-site-census.sh extracts)

Write-class opcodes `WRITE|UPDAT|EXCPT` (glued target = record format) and
`CALL '<pgm>'` literals, on non-col-7-`*` lines, per census file. The census
gate requires every site cited (±2 lines or inside a cited range) — a write
site you did not document FAILs `site_uncovered`; the honest fix is a citation
or an `[OPEN]`, never deletion of the site.

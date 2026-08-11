# Developer-experience survey — Mega-SDD pre/post optimization

**Status: PENDING HUMAN VALIDATION — zero responses collected. Nothing in the
benchmark report scores this axis; fabricating responses is prohibited.**

Audience: developers who used the plugin at v6.1.1-or-earlier AND at v6.6.0+
(the office Windows fleet qualifies once updated from the v5.9.0 floor).
Collect per respondent, scale **1 = Very Poor … 10 = Excellent**, one column per
era (BEFORE = ≤6.1.1, AFTER = ≥6.6.0):

| # | Dimension | Question (ID) | BEFORE | AFTER |
|---|---|---|---|---|
| 1 | Skill discoverability | Seberapa mudah menemukan skill/perintah yang tepat untuk tugasmu? | | |
| 2 | Ease of understanding | Seberapa mudah memahami apa yang sedang dilakukan pipeline dan kenapa? | | |
| 3 | Ease of execution | Seberapa lancar menjalankan chain end-to-end tanpa tersandung? | | |
| 4 | Cognitive load (inverted: 10 = ringan) | Seberapa ringan beban mengingat flag/urutan/aturan? | | |
| 5 | Confidence in output | Seberapa yakin hasil (binding/units/docs) benar tanpa dicek ulang manual? | | |
| 6 | Perceived speed | Seberapa cepat terasa dari permintaan sampai hasil? | | |

Free-text (wajib): (a) satu hal yang paling membaik; (b) satu hal yang memburuk
atau masih menyebalkan; (c) fitur yang hilang.

**Protocol:** ≥3 respondents before the axis is scored; report median per
dimension; respondents answer BEFORE-columns from memory of the old version —
label the result RECALL-BIASED in the report if collected retroactively.
Results land in `../results/comparison/dx-survey-results.json` (absent until
collected).

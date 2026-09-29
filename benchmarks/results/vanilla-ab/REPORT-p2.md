## Scenario `brownfield`

### Runs

| arm | run | status | time to review-ready (min) | wall (min) | API time (min) | silence >5 m (min, proxy idle) | tokens total | tokens input (uncached) | tokens output | tokens cache read | cost (USD) | tool calls | subagent dispatches | interaction points | distinct files read | markdown lines added outside .mega-sdd/ | process artefact lines committed (.mega-sdd/) | code + test lines added | task completion (0-1) | acceptance criteria pass rate | Critical findings | Important findings | blind rubric score (0-100) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| vanilla | brownfield/vanilla-2 | clean | 21.89 | 22.12 | 18.19 | 0.00 | 13,150,575 | 144 | 134,056 | 12,760,141 | 7.28 | 74 | 0 | 0 | 1 | 53 | 0 | 3,424 | 1.00 | 1.00 | 0 | 0 | 93 |
| vanilla | brownfield/vanilla-3 | clean | 19.10 | 19.35 | 16.01 | 0.00 | 11,210,864 | 134 | 118,585 | 10,852,150 | 6.46 | 69 | 0 | 0 | 1 | 51 | 0 | 3,173 | 1.00 | 1.00 | 0 | 0 | 91 |
| vanilla | brownfield/vanilla-4 | clean | 18.88 | 19.17 | 16.68 | 0.00 | 9,103,025 | 114 | 119,188 | 8,752,097 | 5.99 | 62 | 0 | 0 | 2 | 45 | 0 | 3,294 | 1.00 | 1.00 | 0 | 0 | 91 |
| vanilla | brownfield-p2/vanilla-5 | clean | 17.52 | 17.80 | 15.36 | 0.00 | 11,843,104 | 138 | 114,031 | 11,488,923 | 6.50 | 75 | 0 | 0 | 3 | 67 | 0 | 3,201 | 1.00 | 1.00 | 0 | 0 | 93 |
| guarded | brownfield-p2/guarded-1 | clean | 46.68 | 47.84 | 94.87 | 0.00 | 60,019,072 | 1,452 | 570,050 | 56,745,586 | 33.96 | 973 | 75 | 0 | 124 | 0 | 13,458 | 4,077 | 1.00 | 1.00 | 0 | 0 | 92 |
| guarded | brownfield-p2/guarded-2 | clean | 67.50 | 68.60 | 99.93 | 0.00 | 94,484,290 | 1,562 | 614,990 | 91,055,190 | 42.45 | 1,040 | 70 | 0 | 107 | 0 | 14,370 | 4,096 | 1.00 | 1.00 | 0 | 0 | 93 |
| guarded | brownfield-p2/guarded-3 | clean | 55.36 | 56.54 | 107.07 | 0.00 | 105,129,117 | 1,636 | 590,486 | 101,796,929 | 43.60 | 1,088 | 61 | 0 | 154 | 0 | 13,562 | 3,446 | 0.92 | 0.92 | 0 | 1 | 82 |
| guarded-inline | brownfield-p2/guarded-inline-1 | clean | 51.10 | 52.21 | 41.25 | 0.00 | 69,154,988 | 476 | 281,201 | 67,908,863 | 25.38 | 271 | 4 | 0 | 12 | 0 | 8,260 | 3,216 | 1.00 | 1.00 | 0 | 0 | 93 |
| guarded-inline | brownfield-p2/guarded-inline-2 | clean | 50.88 | 52.30 | 41.16 | 0.00 | 68,610,922 | 450 | 281,173 | 67,419,486 | 25.08 | 252 | 3 | 0 | 7 | 0 | 8,907 | 3,551 | 1.00 | 1.00 | 0 | 0 | 91 |
| guarded-inline | brownfield-p2/guarded-inline-3 | clean | 44.21 | 45.29 | 37.69 | 0.00 | 52,724,076 | 392 | 261,030 | 51,634,750 | 20.88 | 226 | 3 | 0 | 16 | 0 | 7,385 | 3,054 | 1.00 | 1.00 | 0 | 0 | 90 |

### Summary (clean runs only)

| metric | vanilla median [min–max] (n) | guarded median [min–max] (n) | guarded-inline median [min–max] (n) | guarded / vanilla | guarded-inline / vanilla | verdict vs vanilla |
|---|---|---|---|---|---|---|
| time to review-ready (min) | 18.99 [17.52–21.89] (4) | 55.36 [46.68–67.50] (3) | 50.88 [44.21–51.10] (3) | 2.92× | 2.68× | guarded: WORSE; guarded-inline: WORSE |
| wall (min) | 19.26 [17.80–22.12] (4) | 56.54 [47.84–68.60] (3) | 52.21 [45.29–52.30] (3) | 2.94× | 2.71× | guarded: WORSE; guarded-inline: WORSE |
| API time (min) | 16.34 [15.36–18.19] (4) | 99.93 [94.87–107.07] (3) | 41.16 [37.69–41.25] (3) | 6.11× | 2.52× | guarded: WORSE; guarded-inline: WORSE |
| silence >5 m (min, proxy idle) | 0.00 [0.00–0.00] (4) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | guarded: OVERLAP; guarded-inline: OVERLAP |
| tokens total | 11,526,984.00 [9,103,025–13,150,575] (4) | 94,484,290 [60,019,072–105,129,117] (3) | 68,610,922 [52,724,076–69,154,988] (3) | 8.20× | 5.95× | guarded: WORSE; guarded-inline: WORSE |
| tokens input (uncached) | 136.00 [114–144] (4) | 1,562 [1,452–1,636] (3) | 450 [392–476] (3) | 11.49× | 3.31× | guarded: WORSE; guarded-inline: WORSE |
| tokens output | 118,886.50 [114,031–134,056] (4) | 590,486 [570,050–614,990] (3) | 281,173 [261,030–281,201] (3) | 4.97× | 2.37× | guarded: WORSE; guarded-inline: WORSE |
| tokens cache read | 11,170,536.50 [8,752,097–12,760,141] (4) | 91,055,190 [56,745,586–101,796,929] (3) | 67,419,486 [51,634,750–67,908,863] (3) | 8.15× | 6.04× | guarded: WORSE; guarded-inline: WORSE |
| cost (USD) | 6.48 [5.99–7.28] (4) | 42.45 [33.96–43.60] (3) | 25.08 [20.88–25.38] (3) | 6.55× | 3.87× | guarded: WORSE; guarded-inline: WORSE |
| tool calls | 71.50 [62–75] (4) | 1,040 [973–1,088] (3) | 252 [226–271] (3) | 14.55× | 3.52× | guarded: WORSE; guarded-inline: WORSE |
| subagent dispatches | 0.00 [0–0] (4) | 70 [61–75] (3) | 3 [3–4] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | guarded: WORSE; guarded-inline: WORSE |
| interaction points | 0.00 [0–0] (4) | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | guarded: OVERLAP; guarded-inline: OVERLAP |
| distinct files read | 1.50 [1–3] (4) | 124 [107–154] (3) | 12 [7–16] (3) | 82.67× | 8.00× | guarded: WORSE; guarded-inline: WORSE |
| markdown lines added outside .mega-sdd/ | 52.00 [45–67] (4) | 0 [0–0] (3) | 0 [0–0] (3) | 0.00× | 0.00× | guarded: BETTER; guarded-inline: BETTER |
| process artefact lines committed (.mega-sdd/) | 0.00 [0–0] (4) | 13,562 [13,458–14,370] (3) | 8,260 [7,385–8,907] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | guarded: WORSE; guarded-inline: WORSE |
| code + test lines added | 3,247.50 [3,173–3,424] (4) | 4,077 [3,446–4,096] (3) | 3,216 [3,054–3,551] (3) | 1.26× | 0.99× | guarded: WORSE; guarded-inline: OVERLAP |
| task completion (0-1) | 1.00 [1.00–1.00] (4) | 1.00 [0.92–1.00] (3) | 1.00 [1.00–1.00] (3) | 1.00× | 1.00× | guarded: OVERLAP; guarded-inline: OVERLAP |
| acceptance criteria pass rate | 1.00 [1.00–1.00] (4) | 1.00 [0.92–1.00] (3) | 1.00 [1.00–1.00] (3) | 1.00× | 1.00× | guarded: OVERLAP; guarded-inline: OVERLAP |
| Critical findings | 0.00 [0–0] (4) | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | guarded: OVERLAP; guarded-inline: OVERLAP |
| Important findings | 0.00 [0–0] (4) | 0 [0–1] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | guarded: OVERLAP; guarded-inline: OVERLAP |
| blind rubric score (0-100) | 92.00 [91–93] (4) | 92 [82–93] (3) | 91 [90–93] (3) | 1.00× | 0.99× | guarded: OVERLAP; guarded-inline: OVERLAP |

### Absolute targets (reported beside the relative verdict, never instead of it)

| target | vanilla | guarded | guarded-inline |
|---|---|---|---|
| review_ready_min ≤ 120 | PASS (median 18.99) | PASS (median 55.36) | PASS (median 50.88) |


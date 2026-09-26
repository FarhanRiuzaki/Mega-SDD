## Scenario `xs`

### Runs

| arm | run | status | time to review-ready (min) | wall (min) | API time (min) | silence >5 m (min, proxy idle) | tokens total | tokens input (uncached) | tokens output | tokens cache read | cost (USD) | tool calls | subagent dispatches | interaction points | distinct files read | markdown lines added outside .mega-sdd/ | process artefact lines committed (.mega-sdd/) | code + test lines added | task completion (0-1) | acceptance criteria pass rate | Critical findings | Important findings | blind rubric score (0-100) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| vanilla | vanilla-1 | clean | 3.17 | 3.40 | 3.01 | 0.00 | 1,006,328 | 42 | 21,708 | 933,280 | 1.03 | 33 | 0 | 0 | 0 | 11 | 0 | 741 | 1.00 | 1.00 | 0 | 0 | 96 |
| lite | lite-1 | clean | 20.22 | 20.55 | 40.95 | 0.00 | 21,346,708 | 600 | 207,177 | 20,227,200 | 11.90 | 375 | 21 | 0 | 46 | 0 | 48,182 | 906 | 0.92 | 0.92 | 0 | 2 | 89 |
| vanilla | vanilla-2 | clean | 5.72 | 5.95 | 4.43 | 0.00 | 1,609,866 | 58 | 31,378 | 1,513,345 | 1.45 | 38 | 0 | 0 | 0 | 27 | 0 | 1,042 | 1.00 | 1.00 | 0 | 0 | 95 |
| lite | lite-2 | clean | 15.11 | 18.92 | 29.02 | 0.00 | 17,132,978 | 412 | 163,632 | 16,268,525 | 9.83 | 273 | 17 | 0 | 38 | 0 | 3,797 | 656 | 0.92 | 0.92 | 0 | 2 | 84 |
| lite | lite-3 | clean | 23.05 | 23.35 | 30.93 | 0.00 | 20,215,289 | 472 | 180,466 | 19,225,230 | 11.29 | 304 | 19 | 0 | 38 | 0 | 40,335 | 922 | 0.92 | 0.92 | 0 | 2 | 80 |
| vanilla | vanilla-3 | clean | 3.13 | 3.36 | 2.73 | 0.00 | 762,785 | 34 | 19,811 | 696,204 | 0.91 | 27 | 0 | 0 | 0 | 0 | 0 | 700 | 1.00 | 1.00 | 0 | 0 | 95 |

### Summary (clean runs only)

| metric | vanilla median [min–max] (n) | lite median [min–max] (n) | lite / vanilla | verdict vs vanilla |
|---|---|---|---|---|
| time to review-ready (min) | 3.17 [3.13–5.72] (3) | 20.22 [15.11–23.05] (3) | 6.38× | lite: WORSE |
| wall (min) | 3.40 [3.36–5.95] (3) | 20.55 [18.92–23.35] (3) | 6.04× | lite: WORSE |
| API time (min) | 3.01 [2.73–4.43] (3) | 30.93 [29.02–40.95] (3) | 10.28× | lite: WORSE |
| silence >5 m (min, proxy idle) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | n/a (vanilla = 0) | lite: OVERLAP |
| tokens total | 1,006,328 [762,785–1,609,866] (3) | 20,215,289 [17,132,978–21,346,708] (3) | 20.09× | lite: WORSE |
| tokens input (uncached) | 42 [34–58] (3) | 472 [412–600] (3) | 11.24× | lite: WORSE |
| tokens output | 21,708 [19,811–31,378] (3) | 180,466 [163,632–207,177] (3) | 8.31× | lite: WORSE |
| tokens cache read | 933,280 [696,204–1,513,345] (3) | 19,225,230 [16,268,525–20,227,200] (3) | 20.60× | lite: WORSE |
| cost (USD) | 1.03 [0.91–1.45] (3) | 11.29 [9.83–11.90] (3) | 10.96× | lite: WORSE |
| tool calls | 33 [27–38] (3) | 304 [273–375] (3) | 9.21× | lite: WORSE |
| subagent dispatches | 0 [0–0] (3) | 19 [17–21] (3) | n/a (vanilla = 0) | lite: WORSE |
| interaction points | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | lite: OVERLAP |
| distinct files read | 0 [0–0] (3) | 38 [38–46] (3) | n/a (vanilla = 0) | lite: WORSE |
| markdown lines added outside .mega-sdd/ | 11 [0–27] (3) | 0 [0–0] (3) | 0.00× | lite: OVERLAP |
| process artefact lines committed (.mega-sdd/) | 0 [0–0] (3) | 40,335 [3,797–48,182] (3) | n/a (vanilla = 0) | lite: WORSE |
| code + test lines added | 741 [700–1,042] (3) | 906 [656–922] (3) | 1.22× | lite: OVERLAP |
| task completion (0-1) | 1.00 [1.00–1.00] (3) | 0.92 [0.92–0.92] (3) | 0.92× | lite: WORSE |
| acceptance criteria pass rate | 1.00 [1.00–1.00] (3) | 0.92 [0.92–0.92] (3) | 0.92× | lite: WORSE |
| Critical findings | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | lite: OVERLAP |
| Important findings | 0 [0–0] (3) | 2 [2–2] (3) | n/a (vanilla = 0) | lite: WORSE |
| blind rubric score (0-100) | 95 [95–96] (3) | 84 [80–89] (3) | 0.88× | lite: WORSE |

### Absolute targets (reported beside the relative verdict, never instead of it)

| target | vanilla | lite |
|---|---|---|
| review_ready_min ≤ 60 | PASS (median 3.17) | PASS (median 20.22) |


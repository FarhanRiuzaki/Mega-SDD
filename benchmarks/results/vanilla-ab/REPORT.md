## Scenario `clinic`

### Runs

| arm | run | status | time to review-ready (min) | wall (min) | API time (min) | silence >5 m (min, proxy idle) | tokens total | tokens input (uncached) | tokens output | tokens cache read | cost (USD) | tool calls | subagent dispatches | interaction points | distinct files read | markdown lines added outside .mega-sdd/ | process artefact lines committed (.mega-sdd/) | code + test lines added | task completion (0-1) | acceptance criteria pass rate | Critical findings | Important findings | blind rubric score (0-100) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| lite | lite-1 | not clean: processes=1 keys=['outage_sleep'] purity=PASS mega-sdd 8.8.1 loaded from mega-sdd@inline | 55.93 | 255.24 | 107.94 | 199.31 | 57,182,309 | 1,396 | 587,067 | 54,342,234 | 31.78 | 929 | 82 | 0 | 153 | 0 | 125,407 | 5,963 | belum diukur | belum diukur | belum diukur | belum diukur | belum diukur |
| lite | lite-2 | clean | 93.89 | 94.22 | 309.24 | 0.00 | 190,478,922 | 3,216 | 1,082,120 | 185,279,819 | 73.27 | 1,777 | 115 | 0 | 249 | 0 | 126,463 | 10,597 | 0.90 | 0.90 | 0 | 3 | 85 |
| vanilla | vanilla-1 | clean | 30.02 | 30.35 | 22.18 | 0.00 | 13,117,426 | 172 | 164,050 | 12,721,897 | 7.68 | 98 | 0 | 0 | 2 | 78 | 0 | 6,561 | 1.00 | 1.00 | 0 | 2 | 89 |
| vanilla | vanilla-2 | clean | 35.81 | 36.03 | 23.49 | 0.00 | 13,653,175 | 176 | 164,077 | 13,254,938 | 7.81 | 114 | 0 | 0 | 0 | 95 | 0 | 5,886 | 1.00 | 1.00 | 0 | 1 | 90 |
| lite | lite-3 | clean | 70.55 | 70.91 | 176.05 | 0.00 | 90,381,557 | 2,580 | 1,034,554 | 85,130,624 | 53.29 | 1,702 | 126 | 0 | 246 | 41 | 123,824 | 9,147 | 1.00 | 1.00 | 0 | 2 | 85 |
| vanilla | vanilla-3 | clean | 25.50 | 25.86 | 20.47 | 0.00 | 9,203,957 | 140 | 144,760 | 8,856,095 | 6.29 | 81 | 0 | 0 | 1 | 57 | 0 | 5,045 | 1.00 | 1.00 | 0 | 2 | 90 |
| lite | lite-4 | clean | 64.98 | 65.41 | 184.85 | 0.00 | 146,867,064 | 3,034 | 1,098,621 | 141,250,876 | 67.33 | 2,043 | 134 | 0 | 377 | 0 | 123,683 | 12,447 | 0.90 | 0.90 | 0 | 2 | 87 |

### Summary (clean runs only)

| metric | vanilla median [min–max] (n) | lite median [min–max] (n) | lite / vanilla | verdict vs vanilla |
|---|---|---|---|---|
| time to review-ready (min) | 30.02 [25.50–35.81] (3) | 70.55 [64.98–93.89] (3) | 2.35× | lite: WORSE |
| wall (min) | 30.35 [25.86–36.03] (3) | 70.91 [65.41–94.22] (3) | 2.34× | lite: WORSE |
| API time (min) | 22.18 [20.47–23.49] (3) | 184.85 [176.05–309.24] (3) | 8.33× | lite: WORSE |
| silence >5 m (min, proxy idle) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | n/a (vanilla = 0) | lite: OVERLAP |
| tokens total | 13,117,426 [9,203,957–13,653,175] (3) | 146,867,064 [90,381,557–190,478,922] (3) | 11.20× | lite: WORSE |
| tokens input (uncached) | 172 [140–176] (3) | 3,034 [2,580–3,216] (3) | 17.64× | lite: WORSE |
| tokens output | 164,050 [144,760–164,077] (3) | 1,082,120 [1,034,554–1,098,621] (3) | 6.60× | lite: WORSE |
| tokens cache read | 12,721,897 [8,856,095–13,254,938] (3) | 141,250,876 [85,130,624–185,279,819] (3) | 11.10× | lite: WORSE |
| cost (USD) | 7.68 [6.29–7.81] (3) | 67.33 [53.29–73.27] (3) | 8.77× | lite: WORSE |
| tool calls | 98 [81–114] (3) | 1,777 [1,702–2,043] (3) | 18.13× | lite: WORSE |
| subagent dispatches | 0 [0–0] (3) | 126 [115–134] (3) | n/a (vanilla = 0) | lite: WORSE |
| interaction points | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | lite: OVERLAP |
| distinct files read | 1 [0–2] (3) | 249 [246–377] (3) | 249.00× | lite: WORSE |
| markdown lines added outside .mega-sdd/ | 78 [57–95] (3) | 0 [0–41] (3) | 0.00× | lite: BETTER |
| process artefact lines committed (.mega-sdd/) | 0 [0–0] (3) | 123,824 [123,683–126,463] (3) | n/a (vanilla = 0) | lite: WORSE |
| code + test lines added | 5,886 [5,045–6,561] (3) | 10,597 [9,147–12,447] (3) | 1.80× | lite: WORSE |
| task completion (0-1) | 1.00 [1.00–1.00] (3) | 0.90 [0.90–1.00] (3) | 0.90× | lite: OVERLAP |
| acceptance criteria pass rate | 1.00 [1.00–1.00] (3) | 0.90 [0.90–1.00] (3) | 0.90× | lite: OVERLAP |
| Critical findings | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | lite: OVERLAP |
| Important findings | 2 [1–2] (3) | 2 [2–3] (3) | 1.00× | lite: OVERLAP |
| blind rubric score (0-100) | 90 [89–90] (3) | 85 [85–87] (3) | 0.94× | lite: WORSE |

### Absolute targets (reported beside the relative verdict, never instead of it)

| target | vanilla | lite |
|---|---|---|
| review_ready_min ≤ 120 | PASS (median 30.02) | PASS (median 70.55) |

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
| classic | classic-1 | clean | 41.79 | 42.13 | 47.83 | 0.00 | 55,425,364 | 682 | 280,907 | 53,887,717 | 22.52 | 456 | 30 | 0 | 60 | 124 | 39,455 | 816 | 0.92 | 0.92 | 0 | 2 | 77 |
| classic | classic-2 | clean | 36.66 | 36.97 | 46.34 | 0.00 | 53,982,555 | 706 | 268,946 | 52,491,148 | 21.87 | 452 | 32 | 0 | 46 | 0 | 39,712 | 1,166 | 0.92 | 0.92 | 0 | 3 | 87 |
| classic | classic-3 | clean | 38.53 | 38.91 | 49.63 | 0.00 | 52,221,585 | 702 | 291,321 | 50,588,496 | 22.47 | 469 | 36 | 0 | 66 | 0 | 40,267 | 1,183 | 0.92 | 0.92 | 0 | 0 | 82 |

### Summary (clean runs only)

| metric | vanilla median [min–max] (n) | classic median [min–max] (n) | lite median [min–max] (n) | classic / vanilla | lite / vanilla | verdict vs vanilla |
|---|---|---|---|---|---|---|
| time to review-ready (min) | 3.17 [3.13–5.72] (3) | 38.53 [36.66–41.79] (3) | 20.22 [15.11–23.05] (3) | 12.15× | 6.38× | classic: WORSE; lite: WORSE |
| wall (min) | 3.40 [3.36–5.95] (3) | 38.91 [36.97–42.13] (3) | 20.55 [18.92–23.35] (3) | 11.44× | 6.04× | classic: WORSE; lite: WORSE |
| API time (min) | 3.01 [2.73–4.43] (3) | 47.83 [46.34–49.63] (3) | 30.93 [29.02–40.95] (3) | 15.89× | 10.28× | classic: WORSE; lite: WORSE |
| silence >5 m (min, proxy idle) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: OVERLAP |
| tokens total | 1,006,328 [762,785–1,609,866] (3) | 53,982,555 [52,221,585–55,425,364] (3) | 20,215,289 [17,132,978–21,346,708] (3) | 53.64× | 20.09× | classic: WORSE; lite: WORSE |
| tokens input (uncached) | 42 [34–58] (3) | 702 [682–706] (3) | 472 [412–600] (3) | 16.71× | 11.24× | classic: WORSE; lite: WORSE |
| tokens output | 21,708 [19,811–31,378] (3) | 280,907 [268,946–291,321] (3) | 180,466 [163,632–207,177] (3) | 12.94× | 8.31× | classic: WORSE; lite: WORSE |
| tokens cache read | 933,280 [696,204–1,513,345] (3) | 52,491,148 [50,588,496–53,887,717] (3) | 19,225,230 [16,268,525–20,227,200] (3) | 56.24× | 20.60× | classic: WORSE; lite: WORSE |
| cost (USD) | 1.03 [0.91–1.45] (3) | 22.47 [21.87–22.52] (3) | 11.29 [9.83–11.90] (3) | 21.82× | 10.96× | classic: WORSE; lite: WORSE |
| tool calls | 33 [27–38] (3) | 456 [452–469] (3) | 304 [273–375] (3) | 13.82× | 9.21× | classic: WORSE; lite: WORSE |
| subagent dispatches | 0 [0–0] (3) | 32 [30–36] (3) | 19 [17–21] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: WORSE; lite: WORSE |
| interaction points | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: OVERLAP |
| distinct files read | 0 [0–0] (3) | 60 [46–66] (3) | 38 [38–46] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: WORSE; lite: WORSE |
| markdown lines added outside .mega-sdd/ | 11 [0–27] (3) | 0 [0–124] (3) | 0 [0–0] (3) | 0.00× | 0.00× | classic: OVERLAP; lite: OVERLAP |
| process artefact lines committed (.mega-sdd/) | 0 [0–0] (3) | 39,712 [39,455–40,267] (3) | 40,335 [3,797–48,182] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: WORSE; lite: WORSE |
| code + test lines added | 741 [700–1,042] (3) | 1,166 [816–1,183] (3) | 906 [656–922] (3) | 1.57× | 1.22× | classic: OVERLAP; lite: OVERLAP |
| task completion (0-1) | 1.00 [1.00–1.00] (3) | 0.92 [0.92–0.92] (3) | 0.92 [0.92–0.92] (3) | 0.92× | 0.92× | classic: WORSE; lite: WORSE |
| acceptance criteria pass rate | 1.00 [1.00–1.00] (3) | 0.92 [0.92–0.92] (3) | 0.92 [0.92–0.92] (3) | 0.92× | 0.92× | classic: WORSE; lite: WORSE |
| Critical findings | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: OVERLAP |
| Important findings | 0 [0–0] (3) | 2 [0–3] (3) | 2 [2–2] (3) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: WORSE |
| blind rubric score (0-100) | 95 [95–96] (3) | 82 [77–87] (3) | 84 [80–89] (3) | 0.86× | 0.88× | classic: WORSE; lite: WORSE |

### Absolute targets (reported beside the relative verdict, never instead of it)

| target | vanilla | classic | lite |
|---|---|---|---|
| review_ready_min ≤ 60 | PASS (median 3.17) | PASS (median 38.53) | PASS (median 20.22) |


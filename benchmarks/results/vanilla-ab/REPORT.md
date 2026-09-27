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
| routed | routed-1 | clean | 22.73 | 23.58 | 19.09 | 0.00 | 10,945,030 | 168 | 137,869 | 10,517,061 | 6.95 | 85 | 1 | 0 | 3 | 35 | 0 | 5,275 | 1.00 | 1.00 | 0 | 0 | 90 |
| routed | routed-2 | clean | 26.59 | 27.37 | 22.96 | 0.00 | 20,143,526 | 240 | 163,112 | 19,620,930 | 9.79 | 185 | 1 | 0 | 9 | 54 | 0 | 7,561 | 1.00 | 1.00 | 0 | 0 | 91 |
| routed | routed-3 | clean | 29.64 | 30.57 | 23.05 | 0.00 | 18,109,030 | 232 | 166,565 | 17,601,049 | 9.30 | 141 | 1 | 0 | 30 | 51 | 0 | 5,067 | 1.00 | 1.00 | 0 | 0 | 91 |
| vanilla-day2 | vanilla-4 | clean | 30.98 | 31.28 | 22.79 | 0.00 | 15,548,267 | 196 | 167,915 | 15,140,624 | 8.30 | 158 | 0 | 0 | 0 | 98 | 0 | 6,027 | 1.00 | 1.00 | 0 | 0 | 91 |

### Summary (clean runs only)

| metric | vanilla median [min–max] (n) | lite median [min–max] (n) | routed median [min–max] (n) | vanilla-day2 median [min–max] (n) | lite / vanilla | routed / vanilla | vanilla-day2 / vanilla | verdict vs vanilla |
|---|---|---|---|---|---|---|---|---|
| time to review-ready (min) | 30.02 [25.50–35.81] (3) | 70.55 [64.98–93.89] (3) | 26.59 [22.73–29.64] (3) | 30.98 [30.98–30.98] (1) | 2.35× | 0.89× | 1.03× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| wall (min) | 30.35 [25.86–36.03] (3) | 70.91 [65.41–94.22] (3) | 27.37 [23.58–30.57] (3) | 31.28 [31.28–31.28] (1) | 2.34× | 0.90× | 1.03× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| API time (min) | 22.18 [20.47–23.49] (3) | 184.85 [176.05–309.24] (3) | 22.96 [19.09–23.05] (3) | 22.79 [22.79–22.79] (1) | 8.33× | 1.04× | 1.03× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| silence >5 m (min, proxy idle) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | lite: OVERLAP; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens total | 13,117,426 [9,203,957–13,653,175] (3) | 146,867,064 [90,381,557–190,478,922] (3) | 18,109,030 [10,945,030–20,143,526] (3) | 15,548,267 [15,548,267–15,548,267] (1) | 11.20× | 1.38× | 1.19× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens input (uncached) | 172 [140–176] (3) | 3,034 [2,580–3,216] (3) | 232 [168–240] (3) | 196 [196–196] (1) | 17.64× | 1.35× | 1.14× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens output | 164,050 [144,760–164,077] (3) | 1,082,120 [1,034,554–1,098,621] (3) | 163,112 [137,869–166,565] (3) | 167,915 [167,915–167,915] (1) | 6.60× | 0.99× | 1.02× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens cache read | 12,721,897 [8,856,095–13,254,938] (3) | 141,250,876 [85,130,624–185,279,819] (3) | 17,601,049 [10,517,061–19,620,930] (3) | 15,140,624 [15,140,624–15,140,624] (1) | 11.10× | 1.38× | 1.19× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| cost (USD) | 7.68 [6.29–7.81] (3) | 67.33 [53.29–73.27] (3) | 9.30 [6.95–9.79] (3) | 8.30 [8.30–8.30] (1) | 8.77× | 1.21× | 1.08× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| tool calls | 98 [81–114] (3) | 1,777 [1,702–2,043] (3) | 141 [85–185] (3) | 158 [158–158] (1) | 18.13× | 1.44× | 1.61× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| subagent dispatches | 0 [0–0] (3) | 126 [115–134] (3) | 1 [1–1] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | lite: WORSE; routed: WORSE; vanilla-day2: INSUFFICIENT |
| interaction points | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | lite: OVERLAP; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| distinct files read | 1 [0–2] (3) | 249 [246–377] (3) | 9 [3–30] (3) | 0 [0–0] (1) | 249.00× | 9.00× | 0.00× | lite: WORSE; routed: WORSE; vanilla-day2: INSUFFICIENT |
| markdown lines added outside .mega-sdd/ | 78 [57–95] (3) | 0 [0–41] (3) | 51 [35–54] (3) | 98 [98–98] (1) | 0.00× | 0.65× | 1.26× | lite: BETTER; routed: BETTER; vanilla-day2: INSUFFICIENT |
| process artefact lines committed (.mega-sdd/) | 0 [0–0] (3) | 123,824 [123,683–126,463] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| code + test lines added | 5,886 [5,045–6,561] (3) | 10,597 [9,147–12,447] (3) | 5,275 [5,067–7,561] (3) | 6,027 [6,027–6,027] (1) | 1.80× | 0.90× | 1.02× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| task completion (0-1) | 1.00 [1.00–1.00] (3) | 0.90 [0.90–1.00] (3) | 1.00 [1.00–1.00] (3) | 1.00 [1.00–1.00] (1) | 0.90× | 1.00× | 1.00× | lite: OVERLAP; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| acceptance criteria pass rate | 1.00 [1.00–1.00] (3) | 0.90 [0.90–1.00] (3) | 1.00 [1.00–1.00] (3) | 1.00 [1.00–1.00] (1) | 0.90× | 1.00× | 1.00× | lite: OVERLAP; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| Critical findings | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | lite: OVERLAP; routed: OVERLAP; vanilla-day2: INSUFFICIENT |
| Important findings | 2 [1–2] (3) | 2 [2–3] (3) | 0 [0–0] (3) | 0 [0–0] (1) | 1.00× | 0.00× | 0.00× | lite: OVERLAP; routed: BETTER; vanilla-day2: INSUFFICIENT |
| blind rubric score (0-100) | 90 [89–90] (3) | 85 [85–87] (3) | 91 [90–91] (3) | 91 [91–91] (1) | 0.94× | 1.01× | 1.01× | lite: WORSE; routed: OVERLAP; vanilla-day2: INSUFFICIENT |

### Absolute targets (reported beside the relative verdict, never instead of it)

| target | vanilla | lite | routed | vanilla-day2 |
|---|---|---|---|---|
| review_ready_min ≤ 120 | PASS (median 30.02) | PASS (median 70.55) | PASS (median 26.59) | PASS (median 30.98) |

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
| routed-v1 | routed-1 | clean | 3.33 | 3.68 | 3.24 | 0.00 | 2,163,556 | 62 | 22,008 | 2,070,623 | 1.42 | 41 | 0 | 0 | 0 | 0 | 0 | 493 | 1.00 | 1.00 | 0 | 0 | 96 |
| routed-v1 | routed-2 | clean | 2.37 | 2.73 | 2.43 | 0.00 | 1,003,719 | 34 | 17,028 | 928,289 | 0.99 | 26 | 0 | 0 | 0 | 0 | 0 | 526 | 1.00 | 1.00 | 0 | 0 | 95 |
| routed-v1 | routed-3 | clean | 2.29 | 2.64 | 2.08 | 0.00 | 751,480 | 26 | 14,821 | 680,756 | 0.88 | 23 | 0 | 0 | 0 | 0 | 0 | 502 | 1.00 | 1.00 | 0 | 0 | 93 |
| routed | routed-4 | clean | 2.69 | 3.04 | 2.64 | 0.00 | 1,479,546 | 44 | 18,097 | 1,394,156 | 1.18 | 32 | 0 | 0 | 0 | 0 | 0 | 582 | 1.00 | 1.00 | 0 | 0 | 94 |
| routed | routed-5 | clean | 2.65 | 3.04 | 2.73 | 0.00 | 1,307,107 | 40 | 18,899 | 1,220,474 | 1.16 | 28 | 0 | 0 | 0 | 0 | 0 | 565 | 1.00 | 1.00 | 0 | 0 | 94 |
| routed | routed-6 | clean | 2.41 | 2.83 | 2.65 | 0.00 | 1,021,684 | 34 | 15,798 | 946,740 | 0.98 | 25 | 0 | 0 | 0 | 0 | 0 | 529 | 1.00 | 1.00 | 0 | 0 | 93 |
| vanilla-day2 | vanilla-4 | clean | 3.68 | 3.89 | 3.16 | 0.00 | 1,178,329 | 48 | 22,857 | 1,104,207 | 1.09 | 34 | 0 | 0 | 0 | 15 | 0 | 845 | 1.00 | 1.00 | 0 | 0 | 94 |

### Summary (clean runs only)

| metric | vanilla median [min–max] (n) | classic median [min–max] (n) | lite median [min–max] (n) | routed median [min–max] (n) | routed-v1 median [min–max] (n) | vanilla-day2 median [min–max] (n) | classic / vanilla | lite / vanilla | routed / vanilla | routed-v1 / vanilla | vanilla-day2 / vanilla | verdict vs vanilla |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| time to review-ready (min) | 3.17 [3.13–5.72] (3) | 38.53 [36.66–41.79] (3) | 20.22 [15.11–23.05] (3) | 2.65 [2.41–2.69] (3) | 2.37 [2.29–3.33] (3) | 3.68 [3.68–3.68] (1) | 12.15× | 6.38× | 0.84× | 0.75× | 1.16× | classic: WORSE; lite: WORSE; routed: BETTER; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| wall (min) | 3.40 [3.36–5.95] (3) | 38.91 [36.97–42.13] (3) | 20.55 [18.92–23.35] (3) | 3.04 [2.83–3.04] (3) | 2.73 [2.64–3.68] (3) | 3.89 [3.89–3.89] (1) | 11.44× | 6.04× | 0.89× | 0.80× | 1.14× | classic: WORSE; lite: WORSE; routed: BETTER; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| API time (min) | 3.01 [2.73–4.43] (3) | 47.83 [46.34–49.63] (3) | 30.93 [29.02–40.95] (3) | 2.65 [2.64–2.73] (3) | 2.43 [2.08–3.24] (3) | 3.16 [3.16–3.16] (1) | 15.89× | 10.28× | 0.88× | 0.81× | 1.05× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| silence >5 m (min, proxy idle) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (3) | 0.00 [0.00–0.00] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: OVERLAP; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens total | 1,006,328 [762,785–1,609,866] (3) | 53,982,555 [52,221,585–55,425,364] (3) | 20,215,289 [17,132,978–21,346,708] (3) | 1,307,107 [1,021,684–1,479,546] (3) | 1,003,719 [751,480–2,163,556] (3) | 1,178,329 [1,178,329–1,178,329] (1) | 53.64× | 20.09× | 1.30× | 1.00× | 1.17× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens input (uncached) | 42 [34–58] (3) | 702 [682–706] (3) | 472 [412–600] (3) | 40 [34–44] (3) | 34 [26–62] (3) | 48 [48–48] (1) | 16.71× | 11.24× | 0.95× | 0.81× | 1.14× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens output | 21,708 [19,811–31,378] (3) | 280,907 [268,946–291,321] (3) | 180,466 [163,632–207,177] (3) | 18,097 [15,798–18,899] (3) | 17,028 [14,821–22,008] (3) | 22,857 [22,857–22,857] (1) | 12.94× | 8.31× | 0.83× | 0.78× | 1.05× | classic: WORSE; lite: WORSE; routed: BETTER; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| tokens cache read | 933,280 [696,204–1,513,345] (3) | 52,491,148 [50,588,496–53,887,717] (3) | 19,225,230 [16,268,525–20,227,200] (3) | 1,220,474 [946,740–1,394,156] (3) | 928,289 [680,756–2,070,623] (3) | 1,104,207 [1,104,207–1,104,207] (1) | 56.24× | 20.60× | 1.31× | 0.99× | 1.18× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| cost (USD) | 1.03 [0.91–1.45] (3) | 22.47 [21.87–22.52] (3) | 11.29 [9.83–11.90] (3) | 1.16 [0.98–1.18] (3) | 0.99 [0.88–1.42] (3) | 1.09 [1.09–1.09] (1) | 21.82× | 10.96× | 1.13× | 0.96× | 1.06× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| tool calls | 33 [27–38] (3) | 456 [452–469] (3) | 304 [273–375] (3) | 28 [25–32] (3) | 26 [23–41] (3) | 34 [34–34] (1) | 13.82× | 9.21× | 0.85× | 0.79× | 1.03× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| subagent dispatches | 0 [0–0] (3) | 32 [30–36] (3) | 19 [17–21] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| interaction points | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: OVERLAP; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| distinct files read | 0 [0–0] (3) | 60 [46–66] (3) | 38 [38–46] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| markdown lines added outside .mega-sdd/ | 11 [0–27] (3) | 0 [0–124] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 15 [15–15] (1) | 0.00× | 0.00× | 0.00× | 0.00× | 1.36× | classic: OVERLAP; lite: OVERLAP; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| process artefact lines committed (.mega-sdd/) | 0 [0–0] (3) | 39,712 [39,455–40,267] (3) | 40,335 [3,797–48,182] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| code + test lines added | 741 [700–1,042] (3) | 1,166 [816–1,183] (3) | 906 [656–922] (3) | 565 [529–582] (3) | 502 [493–526] (3) | 845 [845–845] (1) | 1.57× | 1.22× | 0.76× | 0.68× | 1.14× | classic: OVERLAP; lite: OVERLAP; routed: BETTER; routed-v1: BETTER; vanilla-day2: INSUFFICIENT |
| task completion (0-1) | 1.00 [1.00–1.00] (3) | 0.92 [0.92–0.92] (3) | 0.92 [0.92–0.92] (3) | 1.00 [1.00–1.00] (3) | 1.00 [1.00–1.00] (3) | 1.00 [1.00–1.00] (1) | 0.92× | 0.92× | 1.00× | 1.00× | 1.00× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| acceptance criteria pass rate | 1.00 [1.00–1.00] (3) | 0.92 [0.92–0.92] (3) | 0.92 [0.92–0.92] (3) | 1.00 [1.00–1.00] (3) | 1.00 [1.00–1.00] (3) | 1.00 [1.00–1.00] (1) | 0.92× | 0.92× | 1.00× | 1.00× | 1.00× | classic: WORSE; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| Critical findings | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: OVERLAP; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| Important findings | 0 [0–0] (3) | 2 [0–3] (3) | 2 [2–2] (3) | 0 [0–0] (3) | 0 [0–0] (3) | 0 [0–0] (1) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | n/a (vanilla = 0) | classic: OVERLAP; lite: WORSE; routed: OVERLAP; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |
| blind rubric score (0-100) | 95 [95–96] (3) | 82 [77–87] (3) | 84 [80–89] (3) | 94 [93–94] (3) | 95 [93–96] (3) | 94 [94–94] (1) | 0.86× | 0.88× | 0.99× | 1.00× | 0.99× | classic: WORSE; lite: WORSE; routed: WORSE; routed-v1: OVERLAP; vanilla-day2: INSUFFICIENT |

### Absolute targets (reported beside the relative verdict, never instead of it)

| target | vanilla | classic | lite | routed | routed-v1 | vanilla-day2 |
|---|---|---|---|---|---|---|
| review_ready_min ≤ 60 | PASS (median 3.17) | PASS (median 38.53) | PASS (median 20.22) | PASS (median 2.65) | PASS (median 2.37) | PASS (median 3.68) |


"""uat_annex.py — the SINGLE source of UAT §5 annex truth.

`build-uat-e2e.sh --annex` WRITES render_annex()'s output into UAT.md;
`build-uat-scaffold.sh check_execution()` RECOMPUTES the same render and
byte-compares the document's §5 body against it (violation `ANNEX_FORGED`).
One renderer, two consumers (shared-module pattern of `_lib/postflight_rules.py`).

HONEST SCOPE (round-corrected): this recomputes the RENDER of result.json,
never the evidence itself — result.json integrity rests on the anti-self-bypass
WRITE GUARD (sole writer uat-run.sh), whose documented os.replace /
variable-indirection residual is therefore load-bearing here (unlike B1, whose
gate recomputes from git/fs ground truth and overwrites a forged artifact).
The written_by/run_ts sanity floor below narrows, but does not close, that
residual. Spec: 2026-08-12-playwright-embed-design.md §D2.

Contract (deterministic; every row derived from on-disk evidence, never prose):
- No `<vault>/uat/evidence/UAT-*/` dirs → heading + blank + PLACEHOLDER literal.
- Evidence present → heading + blank + intro line + blank + a 4-column table,
  one row per scenario id (sorted), reading ONLY the NEWEST run-ts subdir
  (UTC %Y%m%dT%H%M%SZ — lexicographic max == newest).
- result.json whose uat_md_sha256 != the CURRENT UAT.md sha renders the STALE
  literal in its Status cell (evidence from an older doc version is never
  presented as current).
- Malformed/unreadable result.json → UNREADABLE literal (fail closed).
"""

import hashlib
import json
import os

ANNEX_HEADING = "## 5. Lampiran — Eksekusi Otomatis (pre-UAT)"
PLACEHOLDER = (
    "_Belum ada eksekusi otomatis — lampiran ini terisi setelah "
    "uat-run.sh dijalankan._"
)
STALE = "STALE — bukti dari versi dokumen sebelumnya, jalankan ulang"
UNREADABLE = "UNREADABLE — jalankan ulang"
TABLE_HEADER = "| Skenario | Status | Run | Bukti |"
TABLE_SEP = "|---|---|---|---|"
INTRO = (
    "Hasil eksekusi Playwright pre-UAT (bukan pengganti eksekusi UAT oleh "
    "user — lihat §2). Tabel ini di-render ulang dari `result.json` oleh "
    "`build-uat-e2e.sh --annex`; baris tidak pernah ditulis manual."
)


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def render_annex(vault_dir):
    """Return the full §5 body (heading through last line, no trailing \n)."""
    uat_md = os.path.join(vault_dir, "uat", "UAT.md")
    ev_root = os.path.join(vault_dir, "uat", "evidence")
    current_sha = _sha256(uat_md) if os.path.isfile(uat_md) else None

    scenario_ids = []
    if os.path.isdir(ev_root):
        for name in os.listdir(ev_root):
            if name.startswith("UAT-") and os.path.isdir(os.path.join(ev_root, name)):
                scenario_ids.append(name)
    scenario_ids.sort()

    lines = [ANNEX_HEADING, ""]
    if not scenario_ids:
        lines.append(PLACEHOLDER)
        return "\n".join(lines)

    lines.extend([INTRO, "", TABLE_HEADER, TABLE_SEP])
    for sid in scenario_ids:
        runs = sorted(
            d for d in os.listdir(os.path.join(ev_root, sid))
            if os.path.isdir(os.path.join(ev_root, sid, d))
        )
        if not runs:
            continue
        newest = runs[-1]
        ev_dir = "evidence/{}/{}".format(sid, newest)
        result_path = os.path.join(ev_root, sid, newest, "result.json")
        status = UNREADABLE
        try:
            with open(result_path, encoding="utf-8") as f:
                data = json.load(f)
            # writer-stamp sanity (round fold): a result.json missing the sole
            # writer's stamp or whose run_ts does not match its dir is treated
            # UNREADABLE (fail closed) — a cheap floor UNDER the hook guard,
            # not a substitute for it (see the module docstring's honest note).
            if data.get("written_by") != "uat-run.sh" or data.get("run_ts") != newest:
                raise ValueError("writer stamp / run_ts mismatch")
            st = data["status"]
            counts = "{}/{}/{}".format(
                int(st["pass"]), int(st["fail"]), int(st["skip"])
            )
            if current_sha is not None and data.get("uat_md_sha256") != current_sha:
                status = STALE
            else:
                status = counts
        except (OSError, ValueError, KeyError, TypeError):
            status = UNREADABLE
        lines.append("| {} | {} | {} | `{}` |".format(sid, status, newest, ev_dir))
    return "\n".join(lines)

"""prd_sniff — v8 P2 DOCS re-source (spec 2026-09-10 App. D): on a layout-3
vault (no `## Overview` / `## Architecture` prose), FSD §1/§2 and PRD §1/§3
read the PRD FILE directly. Deterministic heading-NAME matching (EN + ID
synonyms, case-insensitive, numbered headings tolerated) — a section the PRD
does not carry is None (the caller renders `[Pending — PRD §<name>]`), never
a paraphrase. The slug rule is byte-identical to validate-plan-coverage.sh so
a requirement heading here cross-references a unit's `prd_source` verbatim.

    sniff(md) -> {
      "background": {"heading", "body", "line"} | None,
      "goals": ..., "scope": ..., "out_of_scope": ...,
      "requirements": [{"heading", "slug", "body", "line", "level"}, ...],
    }
"""
import re

SYNONYMS = {
    "background": ("background", "latar belakang", "pendahuluan", "introduction",
                   "overview", "ringkasan", "executive summary", "summary",
                   "ringkasan eksekutif", "context", "konteks", "problem",
                   "masalah", "product", "produk"),
    "goals": ("goals", "goal", "tujuan", "objectives", "objective", "sasaran",
              "success criteria", "kriteria sukses", "success metrics"),
    "scope": ("scope", "ruang lingkup", "lingkup", "in scope", "cakupan"),
    "out_of_scope": ("out of scope", "out-of-scope", "non-goals", "non goals",
                     "di luar lingkup", "tidak termasuk", "batasan"),
    "requirements": ("requirements", "requirement", "functional requirements",
                     "kebutuhan", "kebutuhan fungsional", "fitur", "features",
                     "feature", "fungsional", "halaman", "pages", "screens", "layar"),
}
# meta sections that are never a requirement row (mirrors validate-plan-coverage's set)
_META = ("background", "latar belakang", "goals", "tujuan", "scope", "ruang lingkup",
         "sources", "sumber", "data model", "model data", "nfr", "non-functional",
         "non functional", "open questions", "pertanyaan terbuka", "glossary",
         "changelog", "version", "versi", "alur", "flows", "flow")


def slug(s):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.strip().lower())).strip("-")


def _norm(title):
    # drop numbering / section marks: `1.`, `1)`, `(1)`, `§1.`, `§6.1`, `§Clinic.1`
    t = re.sub(r"^\s*(?:§\s*)?(?:\(?(?:[A-Za-z]+\.)?\d+(?:\.\d+)*[.)]?\)?\s+)?", "", title.strip())
    t = re.sub(r"\s+", " ", t).strip().lower()
    return t.rstrip(":").strip()


def sections(md):
    """[(level, title, body, line_no)] for every H1–H4 heading; body = text to
    the next heading of the SAME or higher level (deeper headings stay inside)."""
    lines = (md or "").splitlines()
    heads = []
    for i, ln in enumerate(lines):
        m = re.match(r"^(#{1,4})[ \t]+(.+?)\s*$", ln)
        if m:
            heads.append((len(m.group(1)), m.group(2).strip(), i))
    out = []
    for k, (lvl, title, i) in enumerate(heads):
        j = len(lines)
        for lvl2, _, i2 in heads[k + 1:]:
            if lvl2 <= lvl:
                j = i2
                break
        out.append((lvl, title, "\n".join(lines[i + 1:j]).strip(), i + 1))
    return out


def _match(title, key):
    t = _norm(title)
    return any(t == syn or t.startswith(syn + " ") or t.startswith(syn + ":")
               for syn in SYNONYMS[key])


def sniff(md):
    secs = sections(md)
    # a PRD that numbers its top sections as H1 (`# §1. Executive Summary`)
    # has ≥2 H1s — then H1 IS the section level; a lone H1 is the document title.
    min_lvl = 1 if sum(1 for l, _, _, _ in secs if l == 1) >= 2 else 2
    out = {"background": None, "goals": None, "scope": None,
           "out_of_scope": None, "requirements": []}
    for key in ("background", "goals", "scope", "out_of_scope"):
        for lvl, title, body, ln in secs:
            if lvl >= min_lvl and _match(title, key):
                out[key] = {"heading": title, "body": body, "line": ln}
                break
    # requirements: the children of a requirements-class heading; when the PRD
    # has no such parent, every H2 that is not a meta section and not a flow id
    # heading counts as ONE requirement (the shape of a screen-per-heading PRD).
    parent = None
    for lvl, title, body, ln in secs:
        if lvl >= min_lvl and _match(title, "requirements") and not _norm(title).startswith(("halaman ", "page ")):
            parent = (lvl, title, ln)
            break
    rows = []
    if parent:
        plvl, ptitle, pln = parent
        pend = len((md or "").splitlines()) + 1
        for lvl, title, body, ln in secs:
            if ln <= pln:
                continue
            if lvl <= plvl:
                pend = ln
                break
        for lvl, title, body, ln in secs:
            if pln < ln < pend and lvl == plvl + 1:
                rows.append({"heading": title, "slug": slug(title), "body": body, "line": ln, "level": lvl})
        if not rows:
            body = next(b for l, t, b, n in secs if n == pln)
            rows.append({"heading": ptitle, "slug": slug(ptitle), "body": body, "line": pln, "level": plvl})
    else:
        oos_line = out["out_of_scope"]["line"] if out["out_of_scope"] else None
        oos_end = None
        if oos_line:
            for lvl, title, body, ln in secs:
                if ln > oos_line and lvl <= 2:
                    oos_end = ln
                    break
        for lvl, title, body, ln in secs:
            if lvl != max(min_lvl, 2) and not (min_lvl == 1 and lvl == 1):
                continue
            t = _norm(title)
            if any(t == m or t.startswith(m + " ") for m in _META):
                continue
            if re.match(r"^f-[a-z]-\d+", t) or any(_match(title, k) for k in ("background", "goals", "scope", "out_of_scope")):
                continue
            if oos_line and oos_line <= ln < (oos_end or 10**9):
                continue
            rows.append({"heading": title, "slug": slug(title), "body": body, "line": ln, "level": lvl})
    out["requirements"] = rows
    return out


def quote(body, max_lines=12):
    """The first non-empty lines of a section body, verbatim (never rewritten)."""
    ls = [l for l in (body or "").splitlines() if l.strip()]
    return "\n".join(ls[:max_lines]).strip() or None

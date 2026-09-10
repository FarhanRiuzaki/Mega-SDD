"""unit_tier — the size proxy behind `unit_tier: xs` (size-weighted spec
2026-08-23 §1a, A1 option i, approved 2026-09-05), shared verbatim by
`resolve-review-tier.sh` (the router: xs = tier "minimal" AND size_small) and
`validate-unit-spec.sh` (v8 P1 F1(e): the `xs_body_advisory` over the SAME
class of unit). One implementation so the router and the advisory can never
disagree about what "small" means (B1 precedent: shared _lib, byte-identical).

size_proxy(fm, body) -> dict(n_accept, n_steps, n_reqs, size_small)
  n_accept  entries under `acceptance_test:` — (?m) WITHOUT (?s): the block
            stops at the next column-0 key (under DOTALL `[ \t]+.*` swallows
            the rest of the frontmatter and binding_refs inflate the count).
  n_steps   numbered items in `## Implementation steps` (None = no section).
  n_reqs    bullets in `## Requirements` on legacy units (None = no section).
  size_small  acceptance 1..2 AND at least one work-item section AND every
            present section within 1..3. Absent/empty/unparsed structure is
            never small — unknown never lowers a tier.
"""
import re


def _section_items(body, names, item_rx):
    # returns None when no named section exists; else the item count
    parts = re.split(r"(?m)^(##\s+.*)$", body)
    for i in range(1, len(parts), 2):
        head = parts[i].lstrip("#").strip().lower()
        head = re.sub(r"\s*\(.*\)\s*$", "", head)
        if head in names:
            sect = parts[i + 1] if i + 1 < len(parts) else ""
            return len(re.findall(item_rx, sect))
    return None


def size_proxy(fm, body):
    acc_m = re.search(r"(?m)^acceptance_test:[ \t]*\n((?:[ \t]+[^\n]*\n?)*)", fm)
    n_accept = len(re.findall(r"(?m)^[ \t]+-[ \t]", acc_m.group(1))) if acc_m else 0
    n_steps = _section_items(body, {"implementation steps"}, r"(?m)^\s*\d+[.)]\s")
    n_reqs = _section_items(body, {"requirements"}, r"(?m)^\s*[-*]\s")
    size_small = (1 <= n_accept <= 2
                  and not (n_steps is None and n_reqs is None)
                  and (n_steps is None or 1 <= n_steps <= 3)
                  and (n_reqs is None or 1 <= n_reqs <= 3))
    return {"n_accept": n_accept, "n_steps": n_steps, "n_reqs": n_reqs,
            "size_small": size_small}

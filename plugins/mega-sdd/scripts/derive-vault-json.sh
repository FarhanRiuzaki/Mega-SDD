#!/usr/bin/env bash
# derive-vault-json.sh — deterministic generator (W5): <vault>/vault.json is
# DERIVED from the 7 vault markdown files, never hand-written or model-emitted.
# HYBRID three-lane contract (spec 2026-07-19-batch2-derive-and-diet.md, W5):
#   DERIVE lane        — structural mirrors from md (entities / flows / adrs /
#                        open_questions skeletons / summary / Vault Lock enums).
#                        md is authoritative for existence — EXCEPT entries
#                        carrying defer_to: binding (no md home; preserved+WARN).
#   CARRY-FORWARD lane — at-generation pins (prd_sha256, prd_path_at_generation,
#                        constitution_hash/constitution_version, legacy mode,
#                        scope/scope_metadata/title, …) + EVERY prior key the
#                        deriver does not own, verbatim (unknown-key tolerance).
#   PATCH lane         — --patch <file.json>: model-authored values only
#                        (metadata, source_documents, design_system_flags,
#                        advisor, per-OQ scan_query/recommendation/rationale/
#                        scan_citations/fallback_if_wrong/defer_to). Setting a
#                        derived key exits 2 (anti-laundering).
#   --event '<json>'   — append ONE changelog event under the same lock
#                        (bind Step 6, resolve-oq round events).
# Shares its md grammar with validate-vault-oqs.sh via _lib/vault_md.py
# (two-validators-one-grammar; the W2 binding_md.py precedent).
# constitution_hash/constitution_version are CARRIED FORWARD like prd_sha256
# (at-generation pin; recompute would silently re-baseline a hand-edited
# constitution) — computed fresh ONLY when absent (initial generation); a WARN
# fires when the carried hash differs from the current constitution.md (free
# drift telemetry — the enforced halt stays binding.md-anchored in detect-drift).
# run-analyze.sh's entities/OQ count-sync checks stay UNTOUCHED as independent
# loose-parse cross-checks of this deriver.
# Exit 0 = derived (ONE PASS line; WARNs to stderr); 2 = derive/parse/patch
# error, vault.json NOT written — on an md-grammar mismatch: mega-sdd-authored
# docs = an authoring bug (fix the markdown write and re-run); externally-
# authored vault docs = not a bug, the grammar was never adopted (v5 adoption
# lane) — fix manually per the generate-intent templates or re-generate via
# the pipeline; 3 = usage / unreadable vault; 4 =
# vault.json.lock held after backoff (skill maps to the memory_in_use halt —
# keterangan envelope stays at the skill layer, verbatim).
set -u
VAULT=""; PATCH=""; EVENT=""
while [ $# -gt 0 ]; do case "$1" in
  --vault) VAULT="$2"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;;
  --patch) PATCH="$2"; shift 2;; --patch=*) PATCH="${1#*=}"; shift;;
  --event) EVENT="$2"; shift 2;; --event=*) EVENT="${1#*=}"; shift;;
  *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: derive-vault-json.sh --vault <dir> [--patch <file.json>] [--event '<json>']" >&2; exit 3; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT" >&2; exit 3; }
[ -f "$VAULT/00-index.md" ] || { echo "FAIL: $VAULT/00-index.md missing — not a vault (00-index is mandatory)" >&2; exit 3; }
if [ -n "$PATCH" ] && [ ! -f "$PATCH" ]; then echo "FAIL: --patch file not found: $PATCH" >&2; exit 3; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

V_VAULT="$VAULT" V_PATCH="$PATCH" V_EVENT="$EVENT" python3 <<'PYEOF'
import hashlib, json, os, re, sys, time
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md

vault = os.environ["V_VAULT"]
patch_path = os.environ.get("V_PATCH") or ""
event_raw = os.environ.get("V_EVENT") or ""
js_path = os.path.join(vault, "vault.json")
lock_path = os.path.join(vault, "vault.json.lock")

DOCS = ["00-index.md", "01-overview.md", "02-architecture.md",
        "03-data-model.md", "04-flows.md", "05-decisions.md",
        "06-constraints.md"]
LOCK_KEYS = ["vault_version", "project_shape", "implementation_mode",
             "prd_status", "output_mode", "mode_migrate_after"]
# Keys the deriver OWNS (the allowlist is of what it owns, NOT of what it
# preserves — every unknown prior key survives verbatim).
DERIVED_TOP = set(LOCK_KEYS) | {
    "entities", "flows", "adrs", "open_questions", "open_questions_summary",
    "constitution_hash", "constitution_version", "generated_at",
}
DERIVED_OQ = {
    "tag", "priority", "doc", "status", "category", "resolution_mode",
    "classification_confidence", "text", "resolution", "out_of_scope_reason",
    "deferred_reason", "resolver_owner", "resolved_at", "deferred_at",
}
KEY_ORDER = [
    "vault_version", "generated_at", "title", "phase", "phase_total",
    "project_shape", "implementation_mode", "mode", "prd_status",
    "output_mode", "mode_migrate_after", "scope", "scope_metadata",
    "prd_sha256", "prd_path_at_generation", "constitution_version",
    "constitution_hash", "source_documents", "design_system_flags",
    "design_system", "advisor", "entities", "flows", "adrs",
    "open_questions", "open_questions_summary", "changelog",
]

def warn(msg):
    print("WARN:", msg, file=sys.stderr)

# ── 1. Advisory lock (script-held; vault-contract.md §Concurrency contract) ──
fd = None
for attempt in range(4):
    try:
        fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(fd, str(os.getpid()).encode())
        break
    except FileExistsError:
        if attempt < 3:
            time.sleep((0.1, 0.5, 1.5)[attempt])
if fd is None:
    try:
        holder = open(lock_path, encoding="utf-8", errors="replace").read().strip() or "unknown"
    except Exception:
        holder = "unknown"
    print(f"FAIL: {lock_path} held after 3 backoff retries (holder pid: {holder}). "
          f"Another mega-sdd writer is updating vault.json. If NO concurrent run is "
          f"active and the lock mtime is >30s old it is orphaned — rm the lock file "
          f"and re-run.", file=sys.stderr)
    sys.exit(4)

try:
    # ── 2. Read the docs + parse (errors → exit 2, fs untouched) ──
    docs = {}
    for fn in DOCS:
        p = os.path.join(vault, fn)
        if os.path.isfile(p):
            docs[fn] = open(p, encoding="utf-8", errors="replace").read()

    errors = []
    entities = vault_md.parse_data_model(docs.get("03-data-model.md", ""), errors)
    flows = vault_md.parse_flows(docs.get("04-flows.md", ""), errors)
    adrs = vault_md.parse_adrs(docs.get("05-decisions.md", ""), errors)
    skeletons = []
    seen_tags = {}
    for fn in DOCS[1:]:
        for oq in vault_md.parse_open_questions(fn, docs.get(fn, ""), errors):
            if oq["tag"] in seen_tags:
                errors.append(
                    f"duplicate OQ tag across docs: {oq['tag']} "
                    f"({seen_tags[oq['tag']]} and {fn})"
                )
                continue
            seen_tags[oq["tag"]] = fn
            skeletons.append(oq)
    rollup_cats = vault_md.parse_rollup_categories(docs["00-index.md"])
    for oq in skeletons:
        if not oq.get("category") and oq["tag"] in rollup_cats:
            # bracket-first precedence; legacy fallback = roll-up header text
            oq["category"] = rollup_cats[oq["tag"]]
    lock_vals = vault_md.parse_vault_lock(docs["00-index.md"])

    if errors:
        for e in errors:
            print("FAIL:", e)
        print(
            "KETERANGAN: artefak tidak cocok dengan grammar mega-sdd — kalau ini "
            "file hasil tulis eksternal, itu bukan bug: grammar-nya memang belum "
            "diadopsi (lane adopsi datang di v5); perbaiki manual mengikuti "
            "template vault generate-intent, atau re-generate via pipeline."
        )
        sys.exit(2)

    # ── 3. Cross-count guard (anti-silent-empty; independent loose parse) ──
    loose = {
        "entities": len(re.findall(r"^[Tt]able\s+\w",
                                   docs.get("03-data-model.md", ""), re.M)),
        "flows": len(re.findall(r"^###\s+F-", docs.get("04-flows.md", ""), re.M)),
        "adrs": len(re.findall(r"^###\s+D-", docs.get("05-decisions.md", ""), re.M)),
    }
    loose_oq_tags = set()
    for fn in DOCS[1:]:
        for line in docs.get(fn, "").splitlines():
            if re.match(r"^-\s*\[", line):
                m = vault_md.OQ_TAG_RE.search(line)
                if m:
                    loose_oq_tags.add(m.group(0))
    parsed = {"entities": len(entities), "flows": len(flows),
              "adrs": len(adrs), "oqs": len(skeletons)}
    loose["oqs"] = len(loose_oq_tags)
    for cls in ("entities", "flows", "adrs", "oqs"):
        if abs(parsed[cls] - loose[cls]) > 2:
            print(f"FAIL: cross-count guard tripped on {cls} — loose count "
                  f"{loose[cls]} vs parsed {parsed[cls]} (delta > 2). The md "
                  f"grammar the deriver reads diverges from the loose scan — "
                  f"fix the markdown structure, never hand-edit vault.json.")
            print(
                "KETERANGAN: artefak tidak cocok dengan grammar mega-sdd — kalau "
                "ini file hasil tulis eksternal, itu bukan bug: grammar-nya memang "
                "belum diadopsi (lane adopsi datang di v5); perbaiki manual "
                "mengikuti template vault generate-intent, atau re-generate via "
                "pipeline."
            )
            sys.exit(2)

    # ── 4. Prior + patch + event (validation before any assembly) ──
    prior = {}
    if os.path.isfile(js_path):
        try:
            prior = json.load(open(js_path, encoding="utf-8"))
        except Exception as e:
            print(f"FAIL: prior vault.json unparseable ({e}) — refusing to "
                  f"clobber the carry-forward source; fix or remove it and re-run.")
            sys.exit(2)
        if not isinstance(prior, dict):
            print("FAIL: prior vault.json is not a JSON object")
            sys.exit(2)

    patch = {}
    if patch_path:
        try:
            patch = json.load(open(patch_path, encoding="utf-8"))
        except Exception as e:
            print(f"FAIL: --patch is not valid JSON ({e})")
            sys.exit(2)
        if not isinstance(patch, dict):
            print("FAIL: --patch must be a JSON object")
            sys.exit(2)

    event = None
    if event_raw:
        try:
            event = json.loads(event_raw)
        except Exception as e:
            print(f"FAIL: --event is not valid JSON ({e})")
            sys.exit(2)
        if not isinstance(event, dict) or "event" not in event:
            print("FAIL: --event must be a JSON object containing an 'event' key")
            sys.exit(2)

    prior_oqs = [e for e in (prior.get("open_questions") or [])
                 if isinstance(e, dict)]
    prior_by_tag = {}
    for e in prior_oqs:
        t = e.get("tag") or e.get("id")
        if t:
            prior_by_tag[t] = e
    skeleton_tags = {oq["tag"] for oq in skeletons}

    for k in patch:
        if k == "open_questions":
            continue
        if k in DERIVED_TOP:
            print(f"FAIL: --patch sets derived key '{k}' — the markdown is the "
                  f"single grammar; edit the vault docs and re-run (anti-laundering).")
            sys.exit(2)
    patch_oqs = patch.get("open_questions") or {}
    if patch_oqs and not isinstance(patch_oqs, dict):
        print("FAIL: --patch open_questions must be an object keyed by OQ tag")
        sys.exit(2)
    for tag, entry in patch_oqs.items():
        if not isinstance(entry, dict):
            print(f"FAIL: --patch open_questions['{tag}'] must be an object")
            sys.exit(2)
        if tag in skeleton_tags:
            bad = sorted(set(entry) & DERIVED_OQ)
            if bad:
                print(f"FAIL: --patch sets derived per-OQ key(s) {bad} on {tag} "
                      f"— those mirror the markdown; edit the vault docs and re-run.")
                sys.exit(2)
        else:
            prior_e = prior_by_tag.get(tag) or {}
            if entry.get("defer_to") != "binding" and prior_e.get("defer_to") != "binding":
                print(f"FAIL: --patch names unknown OQ tag '{tag}' (not in the "
                      f"markdown skeleton and not a defer_to: binding entry).")
                sys.exit(2)

    # ── 5. Assemble ──
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    out = {}
    # carry-forward lane: every prior key the deriver does not own, verbatim
    for k, v in prior.items():
        if k not in DERIVED_TOP and k != "open_questions":
            out[k] = v
    # patch lane: authored top-level keys (patch > prior)
    for k, v in patch.items():
        if k != "open_questions":
            out[k] = v
    # derive lane: the six Vault Lock values (md wins; absent label → per-key
    # carry-forward + WARN — never a fabricated enum)
    for key in LOCK_KEYS:
        if key in lock_vals:
            out[key] = lock_vals[key]
        elif key in prior:
            out[key] = prior[key]
            warn(f"Vault Lock label for '{key}' missing in 00-index.md — "
                 f"carried forward from prior vault.json")
    # constitution pin: carry forward like prd_sha256 (at-generation semantics);
    # compute fresh ONLY when absent (initial generation)
    const_path = os.path.join(vault, "constitution.md")
    cur_hash = None
    const_md = None
    if os.path.isfile(const_path):
        const_bytes = open(const_path, "rb").read()
        cur_hash = hashlib.sha256(const_bytes).hexdigest()
        const_md = const_bytes.decode("utf-8", errors="replace")
    if "constitution_hash" in prior:
        out["constitution_hash"] = prior["constitution_hash"]
        if cur_hash and prior["constitution_hash"] != cur_hash:
            warn("constitution.md content differs from the pinned "
                 "constitution_hash (at-generation pin carried forward — "
                 "drift telemetry only; detect-drift owns the enforced halt)")
    elif cur_hash:
        out["constitution_hash"] = cur_hash
    if "constitution_version" in prior:
        out["constitution_version"] = prior["constitution_version"]
    elif const_md is not None and "constitution_hash" not in prior:
        vm = (re.search(r"^\*\*Version\*\*\s*:\s*(.+)$", const_md, re.M)
              or re.search(r"^constitution_version:\s*[\"']?([^\"'\n]+)", const_md, re.M))
        if vm:
            out["constitution_version"] = vm.group(1).strip()

    # per-OQ merge: derived skeleton ⊕ per-tag prior (non-derived keys)
    # ⊕ per-tag patch; timestamps script-stamped on status TRANSITION only
    merged = []
    for skel in skeletons:
        tag = skel["tag"]
        entry = {k: v for k, v in skel.items() if v is not None}
        p = prior_by_tag.get(tag, {})
        for k, v in p.items():
            if k not in DERIVED_OQ and k != "id" and k not in entry:
                entry[k] = v
        if "resolver_owner" not in entry and p.get("resolver_owner") is not None:
            entry["resolver_owner"] = p["resolver_owner"]
        pt = patch_oqs.get(tag)
        if pt:
            entry.update(pt)
        prior_status = p.get("status")
        if entry.get("status") == "resolved":
            if prior_status == "resolved":
                if p.get("resolved_at"):
                    entry["resolved_at"] = p["resolved_at"]
            else:
                entry["resolved_at"] = now
        if entry.get("status") == "deferred":
            if prior_status == "deferred":
                if p.get("deferred_at"):
                    entry["deferred_at"] = p["deferred_at"]
            else:
                entry["deferred_at"] = now
        merged.append(entry)
    # binding-deferred orphans: preserved with WARN, never dropped by
    # md-authoritative existence (amendment §2); other md-absent tags drop
    dropped = []
    handled = set(skeleton_tags)
    for e in prior_oqs:
        t = e.get("tag") or e.get("id")
        if not t or t in handled:
            continue
        handled.add(t)
        if e.get("defer_to") == "binding":
            entry = dict(e)
            pt = patch_oqs.get(t)
            if pt:
                entry.update(pt)
            merged.append(entry)
            warn(f"OQ {t} has no markdown home (defer_to: binding) — preserved")
        else:
            dropped.append(t)
    for t, pt in patch_oqs.items():
        if t in handled:
            continue
        # validated above: only defer_to: binding entries reach here
        entry = dict(pt)
        entry.setdefault("tag", t)
        if entry.get("status") == "deferred" and "deferred_at" not in entry:
            entry["deferred_at"] = now
        merged.append(entry)
        warn(f"OQ {t} created from --patch with no markdown home "
             f"(defer_to: binding) — preserved on future derives")
    if dropped:
        warn(f"{len(dropped)} prior OQ tag(s) absent from the markdown were "
             f"dropped (md-authoritative existence): {', '.join(dropped)}")

    out["entities"] = entities
    out["flows"] = flows
    out["adrs"] = adrs
    out["open_questions"] = merged
    out["open_questions_summary"] = vault_md.summarize_oqs(merged)

    # ── 6. --event changelog append (same lock) ──
    if event is not None:
        log = out.get("changelog")
        if log is None:
            log = []
        if not isinstance(log, list):
            print("FAIL: prior changelog is not a list — cannot append the event")
            sys.exit(2)
        log = list(log)
        log.append(event)
        out["changelog"] = log

    # ── 7. generated_at: preserved when content is otherwise identical (W2
    # idempotency — keeps build-citation-map's sha256(vault.json) doc-control
    # stamp stable across no-op derives); fresh UTC stamp only on real change ──
    out["generated_at"] = now
    if prior.get("generated_at"):
        a = {k: v for k, v in out.items() if k != "generated_at"}
        b = {k: v for k, v in prior.items() if k != "generated_at"}
        if a == b:
            out["generated_at"] = prior["generated_at"]

    # ── 8. Canonical key order (deterministic, prior-order independent —
    # byte-identical idempotent re-derives) + atomic write ──
    ordered = {}
    for k in KEY_ORDER:
        if k in out:
            ordered[k] = out[k]
    for k in sorted(out):
        if k not in ordered:
            ordered[k] = out[k]
    tmp = js_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(ordered, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, js_path)
    print(f"PASS: derived vault.json ({len(entities)} entities, {len(flows)} "
          f"flows, {len(adrs)} adrs, {len(merged)} oqs)")
    sys.exit(0)
finally:
    try:
        os.close(fd)
    except Exception:
        pass
    try:
        os.remove(lock_path)
    except Exception:
        pass
PYEOF

#!/usr/bin/env bash
# publish-artifacts.sh — the artifact publisher (spec
# docs/superpowers/specs/2026-08-17-artifact-publisher-gateway.md).
#
# Pushes mega-sdd artifacts (graph, vault docs, binding, units, KB,
# codebase-map, symbol index) to the office AI gateway's PASSIVE ingest:
#   POST <url>/mega-sdd/ingest  ·  Bearer <token>  ·  raw application/gzip
#   body = tar.gz with manifest.json as the FIRST root entry, then the
#   CHANGED files at their .mega-sdd/-relative paths (wire format pinned
#   2026-08-20 with the gateway team — no multipart, zero new deps).
#
# FAIL-OPEN BY CONTRACT: this script NEVER blocks the pipeline. Every
# network/credential failure exits 0 (state untouched → the next trigger
# retries). Delta-by-sha via .mega-sdd/.publish-state.json; the manifest is
# always FULL (gateway self-heals; a {"missing":[...]} response evicts those
# paths from state so the next push resends them).
#
# Credential probe ladder (first hit wins):
#   1. MEGA_SDD_PUBLISH_URL + MEGA_SDD_PUBLISH_TOKEN   (explicit override — CI/testing)
#   2. mega-code-MANAGED session (apiKeyHelper=mega-code in ~/.claude/settings.json,
#      URL from that same file's env.ANTHROPIC_BASE_URL AND the process env must
#      match it — the session is actually routed there; token `mega-code get-token`)
#   3. .mega-sdd/config.yaml publish.gateway_url/.token (generic fallback)
#   none → inert exit 0. The token is NEVER echoed/logged.
# Usage: publish-artifacts.sh --cwd=<project-root>
set -u

CWD=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    *) echo "usage: publish-artifacts.sh --cwd=<project-root>" >&2; exit 2 ;;
  esac
done
[ -n "$CWD" ] || { echo "usage: --cwd required" >&2; exit 2; }
MS="$CWD/.mega-sdd"
[ -d "$MS" ] || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_RESOLVER="$SCRIPT_DIR/_lib/resolve-python.sh"
# v6.19.2 governance: the manifest carries the plugin's own version so the
# gateway can audit the version floor per NIP/project. Fail-open to "".
PLUGIN_JSON_PATH="$SCRIPT_DIR/../.claude-plugin/plugin.json"
resolve_py() {
  # Lazy — called only when a rung can actually arm (round MINOR-7: a per-Stop
  # python spawn on machines that will never publish is the v5.8.0 spawn-tax
  # class). Round MINOR-8: MEGA_SDD_PY may be two words ("py -3") — the
  # resolver contract says expand it UNQUOTED; probe the first word only.
  [ -n "${MEGA_SDD_PY:-}" ] && return 0
  if [ -f "$PY_RESOLVER" ]; then . "$PY_RESOLVER"; mega_sdd_python || return 1; else MEGA_SDD_PY=python3; fi
  command -v ${MEGA_SDD_PY%% *} >/dev/null 2>&1
}

# ── credentials (probe ladder; first hit wins, fall-through; inert without them) ──
GATEWAY_URL=""; TOKEN=""; MEGA_CODE_CMD="mega-code"
if [ -n "${MEGA_SDD_PUBLISH_URL:-}" ] && [ -n "${MEGA_SDD_PUBLISH_TOKEN:-}" ]; then
  GATEWAY_URL="$MEGA_SDD_PUBLISH_URL"; TOKEN="$MEGA_SDD_PUBLISH_TOKEN"
fi
# v6.20.0 (evidence: a real office settings.json, 2026-08-21): on Windows the
# installed artifact is `mega-code.cmd` in the npm dir — `command -v mega-code`
# alone can miss it, which would silently disarm the office rung on a laptop
# whose settings are perfectly configured. Probe all three names (shell builtin,
# no fork) before spending the python spawn.
have_mega_code() {
  command -v mega-code >/dev/null 2>&1 || command -v mega-code.cmd >/dev/null 2>&1 \
    || command -v mega-code.exe >/dev/null 2>&1
}
if [ -z "$GATEWAY_URL" ] && have_mega_code && resolve_py; then
  # Office path — arms ONLY when THIS SESSION is mega-code-managed (v6.19.1 +
  # round MAJOR-2). Three conditions, all from/against ~/.claude/settings.json
  # (the file `mega-code install` writes):
  #   (a) apiKeyHelper's command basename is mega-code — the management
  #       signature; binary-on-PATH alone never arms (a vanilla-Claude session
  #       must never POST the per-NIP token anywhere);
  #   (b) the destination is settings env.ANTHROPIC_BASE_URL — never the
  #       process env, so URL + token share one source of truth; AND
  #   (c) the PROCESS env ANTHROPIC_BASE_URL equals that settings URL — the
  #       session is routed through that gateway RIGHT NOW. A provisioned
  #       machine running a vanilla/overridden session (ANTHROPIC_API_KEY
  #       export, --settings, project-settings override) fails (c) → silent.
  # Deliberate redirection = rung 1. Any parse error / missing piece → empty
  # → fall through (fail-closed for the token, fail-open for the pipeline).
  # get-token runs INSIDE the python pass with subprocess timeout=10 (round
  # M4) using the SAME helper command the signature named (round MINOR-6).
  PROBE=$($MEGA_SDD_PY - <<'PY' 2>/dev/null
import json, os
try:
    p = os.path.join(os.path.expanduser("~"), ".claude", "settings.json")
    s = json.load(open(p, encoding="utf-8-sig"))
    h = str(s.get("apiKeyHelper", "")).strip()
    if h.startswith('"'):                  # quoted absolute path (may hold spaces)
        first = h[1:].split('"', 1)[0]
    else:
        first = h.split()[0] if h.split() else ""
    base = os.path.basename(first).lower()
    if base in ("mega-code", "mega-code.exe", "mega-code.cmd"):
        url = str((s.get("env") or {}).get("ANTHROPIC_BASE_URL", "")).strip()
        env_url = os.environ.get("ANTHROPIC_BASE_URL", "").strip()
        if url.startswith(("https://", "http://")) and url.rstrip("/") == env_url.rstrip("/"):
            print(url + "\t" + first)
except Exception:
    pass
PY
)
  if [ -n "$PROBE" ]; then
    IFS=$'\t' read -r GATEWAY_URL MEGA_CODE_CMD <<< "$PROBE"
    TOKEN="__MEGA_CODE_GET_TOKEN__"
  fi
fi
if [ -z "$GATEWAY_URL" ] && [ -f "$MS/config.yaml" ]; then
  # SCOPED to the publish: block only (round M1: an unscoped sed grabbed the
  # first token: anywhere in the file — another service's secret was sent
  # as the gateway bearer). awk: keys are read ONLY while inside publish:.
  GATEWAY_URL=$(awk '/^publish:/{inb=1;next} /^[^[:space:]]/{inb=0} inb&&/^[[:space:]]+gateway_url:/{sub(/^[[:space:]]+gateway_url:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$MS/config.yaml")
  TOKEN=$(awk '/^publish:/{inb=1;next} /^[^[:space:]]/{inb=0} inb&&/^[[:space:]]+token:/{sub(/^[[:space:]]+token:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$MS/config.yaml")
fi
[ -n "$GATEWAY_URL" ] && [ -n "$TOKEN" ] || exit 0
GATEWAY_URL="${GATEWAY_URL%/}"

command -v curl >/dev/null 2>&1 || exit 0
command -v git  >/dev/null 2>&1 || exit 0
resolve_py || exit 0

# ── identity ─────────────────────────────────────────────────────────────────
GIT_HEAD=$(git -C "$CWD" rev-parse HEAD 2>/dev/null) || exit 0
REMOTE=$(git -C "$CWD" remote get-url origin 2>/dev/null || echo "")
WORK_DIR_BASE=$(basename "$CWD")

# ── everything else in one python pass (collect → delta → manifest → tar → POST per vault) ──
CWD="$CWD" MS="$MS" GATEWAY_URL="$GATEWAY_URL" MEGA_SDD_TOKEN="$TOKEN" \
GIT_HEAD="$GIT_HEAD" REMOTE="$REMOTE" WORK_DIR_BASE="$WORK_DIR_BASE" \
MEGA_CODE_CMD="$MEGA_CODE_CMD" PLUGIN_JSON_PATH="$PLUGIN_JSON_PATH" \
$MEGA_SDD_PY - <<'PYEOF'
import hashlib, json, os, subprocess, sys, tarfile, tempfile, glob, io, datetime

ms   = os.environ["MS"]
url  = os.environ["GATEWAY_URL"] + "/mega-sdd/ingest"
token = os.environ["MEGA_SDD_TOKEN"]          # env only — never printed
if token == "__MEGA_CODE_GET_TOKEN__":
    # office path (round M4): bounded HERE — subprocess timeout works on every
    # platform, unlike the shell timeout ladder (empty on stock macOS). Round
    # MINOR-6: mint with the SAME helper command the settings signature named.
    try:
        gt = subprocess.run([os.environ.get("MEGA_CODE_CMD", "mega-code"), "get-token"],
                            capture_output=True, text=True, timeout=10)
        token = gt.stdout.strip() if gt.returncode == 0 else ""
    except Exception:
        token = ""
    if not token:
        sys.exit(0)                        # inert: not logged in — fail-open
head = os.environ["GIT_HEAD"]
remote = os.environ["REMOTE"]
work_dir = os.environ["WORK_DIR_BASE"]
plugin_version = ""
try:                                       # governance: version-floor audit signal
    plugin_version = str(json.load(open(os.environ.get("PLUGIN_JSON_PATH", ""),
                                        encoding="utf-8-sig")).get("version", ""))
except Exception:
    pass

def norm_project_id(r):
    # Round M3: strip credentials/userinfo (a https remote can embed user:pass —
    # it must NEVER reach the manifest), drop ssh ports (same repo via ssh:2222
    # and https must land on ONE project_id), handle scp-like git@host:path,
    # and give remote-less repos a per-folder bucket instead of one shared one.
    r = r.strip()
    for p in ("ssh://", "https://", "http://", "git://"):
        if r.startswith(p): r = r[len(p):]
    first = r.split("/", 1)[0]
    if "@" in first:                       # userinfo (incl. embedded creds) — drop
        r = r.split("@", 1)[1]
    head, _, rest = r.partition("/")
    if ":" in head:
        h, p2 = head.split(":", 1)
        if p2.isdigit():                   # ssh port — drop
            head = h
        else:                              # scp-like host:path
            head, rest = h, (p2 + ("/" + rest if rest else ""))
    r = (head + ("/" + rest if rest else "")).rstrip("/")
    r = r.removesuffix(".git")
    return r or ("local/" + work_dir)

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(65536), b""): h.update(c)
    return h.hexdigest()

def rel_files(patterns):
    out = {}
    for pat in patterns:
        for p in glob.glob(os.path.join(ms, pat), recursive=True):
            if os.path.isfile(p) and not os.path.islink(p):   # round MINOR-6: never
                out[os.path.relpath(p, ms)] = p               # follow/ship symlinks
    return out

SHARED = ["graph.json", "knowledge-base/**/*", "codebase/codebase-map.md", "codebase/symbol-index.json"]
state_path = os.path.join(ms, ".publish-state.json")
try:
    state = json.load(open(state_path))
except Exception:
    state = {}

vaults = [d for d in sorted(glob.glob(os.path.join(ms, "vaults", "*"))) if os.path.isdir(d)]
if vaults:
    vault_specs = [(os.path.basename(d), [f"vaults/{os.path.basename(d)}/*.md",
                                          f"vaults/{os.path.basename(d)}/binding*.md",
                                          f"vaults/{os.path.basename(d)}/bound/**/*",
                                          f"vaults/{os.path.basename(d)}/units/*.md",
                                          f"vaults/{os.path.basename(d)}/bolts/_summary.md",
                                          f"vaults/{os.path.basename(d)}/vault.json"])
                   for d in vaults]
else:
    # v6.20.0: a scan-stage project has no vault but DOES have a code layer
    # (graph.json symbols + codebase-map). It publishes once under the reserved
    # sentinel vault `_codebase` carrying only SHARED — the gateway keys its
    # store project_id/vault, so this is a sibling vault, not a collision.
    if not rel_files(SHARED):
        sys.exit(0)                      # genuinely nothing to publish
    vault_specs = [("_codebase", [])]

graph_meta = {}
try:
    graph_meta = {"source_hashes": json.load(open(os.path.join(ms, "graph.json"))).get("_meta", {}).get("source_hashes", {})}
except Exception:
    pass

changed_any = False
for vault, extra in vault_specs:
    files = rel_files(SHARED)
    files.update(rel_files(extra))
    manifest_files = {rp: sha(ap) for rp, ap in sorted(files.items())}
    prev = state.get(vault, {})
    delta = [rp for rp, s in manifest_files.items() if prev.get(rp) != s]
    if not delta:
        continue
    changed_any = True
    manifest = {"schema": "mega-sdd-publish/1", "project_id": norm_project_id(remote),
                "vault": vault, "git_head": head,
                "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "files": manifest_files, "graph_meta": graph_meta, "work_dir": work_dir,
                "plugin_version": plugin_version}
    with tempfile.NamedTemporaryFile(suffix=".tgz", delete=False) as tf:
        bundle = tf.name
    with tarfile.open(bundle, "w:gz") as tar:
        mb = json.dumps(manifest, indent=1).encode()
        ti = tarfile.TarInfo("manifest.json"); ti.size = len(mb)
        tar.addfile(ti, io.BytesIO(mb))                     # FIRST root entry (pinned wire format)
        for rp in delta:
            tar.add(files[rp], arcname=rp)
    cap_mb = int(os.environ.get("MEGA_SDD_PUBLISH_MAX_MB", "25"))
    if os.path.getsize(bundle) > cap_mb * 1024 * 1024:
        # Round MINOR-5: the gateway cap is 25 MB and a near-cap bundle is a
        # publisher bug by contract — never hammer the network with it.
        os.unlink(bundle)
        print(f"[publish] {vault}: bundle exceeds {cap_mb} MB cap — NOT sent (publisher bug; report this)")
        continue
    # Round M2: the bearer goes via a 0600 header FILE (curl -H @file), never
    # argv — `ps` on a shared host must not read the per-NIP token.
    hfd, hpath = tempfile.mkstemp()
    try:
        os.write(hfd, ("Authorization: Bearer " + token).encode()); os.close(hfd)
        os.chmod(hpath, 0o600)
        r = subprocess.run(["curl", "-sS", "--max-time", "60", "-o", "-", "-w", "\n%{http_code}",
                            "-X", "POST", "-H", "Content-Type: application/gzip",
                            "-H", "@" + hpath,
                            "--data-binary", "@" + bundle, url],
                           capture_output=True, text=True, timeout=90)
        body, _, code = r.stdout.rpartition("\n")
        code = code.strip() or "network-error"
    except Exception:
        code = "network-error"; body = ""
    finally:
        os.unlink(hpath)
        os.unlink(bundle)
    if code == "200":
        newstate = dict(manifest_files)
        try:                                                 # self-heal: evict server-reported missing
            for m in json.loads(body or "{}").get("missing", []):
                newstate.pop(m, None)
        except Exception:
            pass
        state[vault] = newstate
        print(f"[publish] {vault}: {len(delta)} file(s) → gateway OK")
    elif code == "413":
        print(f"[publish] {vault}: gateway rejected size (413) — publisher bug; report; NOT retried blindly")
    elif code == "401":
        print(f"[publish] {vault}: token rejected (401) — run `mega-code login`; queued for retry")
    else:
        print(f"[publish] {vault}: gateway unreachable ({code}) — queued for retry")

if changed_any:
    tmp = state_path + ".tmp." + str(os.getpid())   # round MINOR-7: parallel-session safe
    json.dump(state, open(tmp, "w"), indent=1)
    os.replace(tmp, state_path)
PYEOF
exit 0

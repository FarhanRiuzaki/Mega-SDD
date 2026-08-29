"""plugin_meta.py — provenance stamps for every artifact writer (F-26, spec 2026-08-30 §3.4).

The field audit (HOST-AS400, 36 units) could not attribute a single evidence
artifact to the plugin version that produced it: the run straddled 7.6.0 and
7.8.0, `dispatch-prompt.md` carried a stamp but preflight / postflight /
acceptance / findings / every state file carried none, and durations were
recorded nowhere. Every audit finding then had to be attributed by hand.

One helper, imported by every writer:

    sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])   # or the script's _lib
    import plugin_meta
    artifact.update(plugin_meta.stamp(script_dir))        # plugin_version + written_at

`plugin_version()` walks UP from the calling script's directory to the first
`.claude-plugin/plugin.json` (the plugin root — scripts/ and scripts/_lib/ both
resolve to the same file) and reads its `version`. Never raises: an unreadable
manifest stamps "unknown", which is itself the honest record.
"""
import json
import os
from datetime import datetime, timezone


def plugin_root(start_dir):
    """First ancestor of start_dir (inclusive) holding .claude-plugin/plugin.json, or None."""
    d = os.path.abspath(start_dir or ".")
    for _ in range(8):
        if os.path.isfile(os.path.join(d, ".claude-plugin", "plugin.json")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return None


def plugin_version(start_dir=None):
    """The plugin's `version` from plugin.json, or "unknown"."""
    root = plugin_root(start_dir or os.path.dirname(os.path.abspath(__file__)))
    if not root:
        return "unknown"
    try:
        with open(os.path.join(root, ".claude-plugin", "plugin.json")) as f:
            v = json.load(f).get("version")
        return str(v) if v else "unknown"
    except (OSError, ValueError):
        return "unknown"


def now_iso():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def stamp(start_dir=None, duration_ms=None):
    """The provenance dict to merge into an artifact: plugin_version + written_at
    (+ duration_ms when the writer measured an execution)."""
    out = {"plugin_version": plugin_version(start_dir), "written_at": now_iso()}
    if duration_ms is not None:
        out["duration_ms"] = int(duration_ms)
    return out

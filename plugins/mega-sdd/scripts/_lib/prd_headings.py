"""prd_headings.py — the PRD heading census, the `prd_source` ref grammar and the coverage-state freshness, ONE
implementation for validate-plan-coverage.sh, validate-unit-spec.sh (prd_source_unresolvable), validate-preflight.sh
and run-analyze.sh: a ref resolves in one of them exactly when it resolves in the other. Pure — reads files only.

parse(path, rel) → {"file", "lines", "heads", "hidden", "refusals", "shadows"}. `heads` = every H1-H6 in document
order as CommonMark parses them: ATX with 0-3 leading spaces ('##Name' too — fail closed), setext, both inside a
blockquote / list item; an <h1>-<h6> tag anywhere on a line outside code (its attributes may wrap). Each head carries a
GitHub-style UNIQUE slug (x, x-1 … in document order). Hidden (never headings): YAML frontmatter at the top of the file
(a mapping: `key:` lines, `#` comments, indented values, '- ' items under an empty key — prose breaks it),
```/~~~ fences and <!-- --> comments (each ended by its closer — '<!-->' closes itself — or by its list item /
blockquote). A fence / comment that looks FORGOTTEN hides nothing (forgotten(); `refusals`); a hidden block holding a
heading + text is listed in `shadows`. Raw HTML blocks hide nothing (fail closed). census() picks the anchors.
"""
import glob, hashlib, html, json, os, re, unicodedata

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
ATX_CM = re.compile(r"^ {0,3}#{1,6}(?:[ \t]|$)")  # CommonMark's ATX rule (paragraph state)
ATX = re.compile(r"^ {0,3}(#{1,6})(?=[ \t]|$)(.*)$|^ {0,3}(#{2,3})(?=[^#\s])(.*)$")  # + '##Name': fail closed
H23 = re.compile(r"^ {0,3}#{2,3}(?:[ \t]+\S|[^#\s])")  # an H2/H3-shaped line
SECTION_H = re.compile(r"^ {0,3}#{2,3}[ \t]*[§\d]")      # ... carrying a section number
HASH_LANGS = set(("text txt plain plaintext bash sh shell zsh fish console terminal shell-session ps1 powershell pwsh python "
                  "py python3 ruby rb perl pl r yaml yml toml ini cfg conf config properties env dotenv dockerfile docker "
                  "makefile make cmake markdown md mdx gfm diff patch nginx apache elixir ex exs julia jl coffee tcl awk sed "
                  "gitignore hcl terraform tf nix crystal log output raw none").split()) | {""}  # '## x' is content there
YAML_TOP = re.compile(r"^[^\s#:\-\]}][^:]*:(?:[ \t]+(.*))?$")  # a top-level `key: value` / `key:` line of a YAML mapping
UNDERLINE = re.compile(r"^ {0,3}(=+|-+)[ \t]*$")
THEMATIC = re.compile(r"^ {0,3}(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})$")
ITEM = re.compile(r" {0,3}(?:[-*+]|(\d{1,9})[.)])(?=[ \t]|$)")
ORDERED = re.compile(r"^ {0,3}\d{1,9}[.)](?:[ \t]|$)")
MARKERS = re.compile(r"^(?:[ \t]*(?:>|[-*+]|\d{1,9}[.)])(?=[ \t]|$))+[ \t]*")  # blockquote / list-item markers
NORM = re.compile(r"(?i)\b(must(?!-have)|shall|required|mandatory|tidak boleh|dilarang|(?:di|me|meng|ber|ke|berke)?(?:wajib|harus)(?:kan|an|nya|lah)?)\b")
MOSCOW = re.compile(r"(?i)^[*_`\[(]*(?:must|should|could|won'?t)(?:[- ]have)?[*_`\])]*$")
TABLE_SEP = re.compile(r"^[ \t]*\|?[ \t]*:?-{2,}:?[ \t]*(?:\|[ \t]*:?-{2,}:?[ \t]*)*\|?[ \t]*$")
# CommonMark HTML blocks: type 1 (and its end), 3-5 (end marker), 6 (block tag), 7 (a lone complete tag)
HTML1 = re.compile(r"(?i)^ {0,3}<(?:pre|script|style|textarea)(?=[\s>]|$)")
HTML_ENDS = ((HTML1, re.compile(r"(?i)</(?:pre|script|style|textarea)\s*>")), (re.compile(r"^ {0,3}<\?"), re.compile(r"\?>")),
             (re.compile(r"^ {0,3}<![A-Za-z]"), re.compile(r">")), (re.compile(r"^ {0,3}<!\[CDATA\["), re.compile(r"\]\]>")))
HTML6 = re.compile(r"(?i)^ {0,3}</?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|"
                   r"details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|"
                   r"html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|"
                   r"summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?=[\s>]|/>|$)")
_ATTR = r"""(?:\s+[A-Za-z_:][\w.:-]*(?:\s*=\s*(?:[^\s"'=<>`]+|'[^']*'|"[^"]*"))?)"""
HTML7 = re.compile(r"^ {0,3}(?:<(?!(?i:pre|script|style|textarea)\b)[A-Za-z][A-Za-z0-9-]*%s*\s*/?>|</[A-Za-z][A-Za-z0-9-]*\s*>)\s*$" % _ATTR)
HTML_HEAD = re.compile(r"(?i)<h([1-6])(?=[\s>/])([^>]*)>")
HTML_OPEN = re.compile(r"(?i)<h[1-6](?:\s[^<>]*)?$")  # an <hN whose attributes wrap to the next line
CODESPAN = re.compile(r"(`+)(?:(?!\1).)*?\1")
INLINE_TAG = re.compile(r"(?i)</?(?:a|span|br|img|b|i|em|strong|code|sup|sub|small|u|s|mark|kbd|font|ins|del)(?:\s[^<>]*)?/?>")
TAG_ID = re.compile(r"""(?i)\b(?:id|name)\s*=\s*["']?([^"'\s>]+)""")
F_ID = re.compile(r"(?<![\w-])(F-[A-Z]+-\d+\w*(?:[.-][A-Za-z0-9]+)*)(?!\w)")
SEC = re.compile(r"^(?:§\s*)?((?:[A-Za-z][\w-]*\.)?\d+(?:\.\d+)*|(?<=§)[A-Za-z][\w-]*)\.?(?=[\s:)]|$)")
REF_RE = re.compile(r"^(.+?\.md)(?:#(\S+)|:(\d+))$")  # `<file>.md#<fragment>` | `<file>.md:<line>` (the file may hold spaces)
COVERS_RE = re.compile(r"\[\s*covers:\s*([^\]]+?)\s*\]", re.I)  # an OQ's explicit decision binding: [covers: <ref>, …]
PREAMBLE = "(text before the first heading)"  # the synthetic anchor of text that precedes every heading

def split_lines(text):
    """CommonMark line split: only \\n, \\r\\n and \\r end a line (never U+2028, \\x0b, \\x0c — str.splitlines does)."""
    text = text[1:] if text.startswith("\ufeff") else text
    lines = re.split(r"\r\n|\r|\n", text)
    return lines[:-1] if lines and lines[-1] == "" else lines

def slug(s):  # Unicode letters kept (a CJK heading is not the empty slug), accents folded
    s = "".join(c for c in unicodedata.normalize("NFKD", s.strip().lower()) if not unicodedata.combining(c))
    return re.sub(r"-+", "-", re.sub(r"[\W_]+", "-", s)).strip("-")

def ascii_slug(s):  # the pre-shared ASCII rule (kept as an alias so older refs still resolve)
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.strip().lower())).strip("-")

def unescape(t):  # heading text as CommonMark renders it: backslash escapes and entities resolved
    return html.unescape(re.sub(r"\\([!-/:-@\[-`{-~])", r"\1", t))

def norm(s):
    """Whole-heading comparison key (never a substring rule): trailing {#id} dropped; escapes / entities resolved; curly
    quotes / dashes / NBSP folded; emoji (+ variation selectors, ZWJ, skin tones, keycaps), emphasis and code markers
    dropped; whitespace collapsed; case and a trailing ?/:/!/. ignored."""
    s = unescape(re.sub(r"[ \t]*\{#[^}]*\}[ \t]*$", "", s))
    s = s.translate({0x2018: "'", 0x2019: "'", 0x201c: '"', 0x201d: '"', 0x2013: "-", 0x2014: "-", 0xa0: " "})
    s = "".join(c for c in s if unicodedata.category(c) not in ("So", "Cf", "Me") and not 0xfe0e <= ord(c) <= 0xfe0f
                and not 0x1f3fb <= ord(c) <= 0x1f3ff)
    s = re.sub(r"\s+", " ", re.sub(r"[*_`]", "", s)).strip().lower()
    return s.rstrip("?:!.").strip()

def unnumbered(text):  # '1. Users' / '§5. Rules' / '2) Goals' → the name without its section number, else None
    m = SEC.match(text)
    return norm(text[m.end():].lstrip(" \t:).-–—")) if m else None

def states_requirement(b):
    """PARSER use only (a forgotten fence/comment): a line in b states a MUST/SHALL/WAJIB/HARUS/… requirement — not
    negated, not a question, not a table header or a MoSCoW label. It can only make the parser census MORE."""
    for k, ln in enumerate(b):
        if "|" in ln and k + 1 < len(b) and "|" in b[k + 1] and TABLE_SEP.match(b[k + 1]): continue
        for sent in re.split(r"(?<=[.!?])\s+|\s*\|\s*", ln):
            if re.sub(r"\([^()]*\)", "", sent).rstrip(" *_`\"'").endswith("?") or MOSCOW.match(sent.strip()): continue
            if any(re.findall(r"\w+", sent[:m.start()].lower())[-1:] not in (["not"], ["tidak"], ["bukan"], ["tanpa"], ["no"])
                   for m in NORM.finditer(sent)): return True
    return False

def item(s, col):  # a list-item marker at column `col` → its content column, else None
    t = s[col:]; m = ITEM.match(t)
    if not m or THEMATIC.match(t): return None
    rest = t[m.end():]; sp = len(rest) - len(rest.lstrip(" "))
    return col + m.end() + (1 if not rest.strip() or sp > 4 else sp)

def cont(s, stack):  # → (how many containers of `stack` the line continues, the column its content starts at)
    col = 0
    for k, c in enumerate(stack):
        if c == ">":
            m = re.match(r" {0,3}>", s[col:])
            if not m: return k, col
            col += m.end(); col += s[col:col + 1] == " "
        elif s[col:].strip():
            if col + len(s[col:]) - len(s[col:].lstrip(" ")) < c: return k, col
            col = c
    return len(stack), col

def inner(L, sp):  # the content lines of a span (container prefixes stripped; a comment's own text included)
    kind, i, j, how, _, stack, col = sp
    b = [L[x][cont(L[x], stack)[1]:] for x in range(i + 1, j if how != "eof" else len(L))]
    if kind == "comment":
        b.insert(0, L[i][col:][L[i][col:].index("<!--") + 4:])
        if how == "closed" and j > i: b.append(L[j][cont(L[j], stack)[1]:].split("-->", 1)[0])
    return b

def forgotten(L, sp):  # → why this fence / comment is a forgotten closer (it hides nothing), else None
    kind, i, j, how, info, stack, col = sp; b = inner(L, sp)
    if how == "eof": return "no closer before the end of the file"
    if kind == "fence":
        f = FENCE.match(L[i][col:]); c = re.escape(f.group(1)[0])
        if any(re.match(r"^ {0,3}%s{%d,}[ \t]*[^ \t%s]" % (c, len(f.group(1)), c), x) for x in b):
            return "another fence opener before its closer"
        if any(SECTION_H.match(x) for x in b): return "a numbered section heading inside"
        if info not in HASH_LANGS and any(H23.match(x) for x in b): return "a heading inside a '%s' block" % info
    elif j > i:
        if any("<!--" in x for x in b): return "another '<!--' before its '-->'"
        if sum(1 for x in b if FENCE.match(x)) % 2: return "its '-->' sits inside a code fence"
        if how == "closed" and L[j].split("-->", 1)[1].strip(): return "text follows its '-->' (an arrow, not a closer)"
    h = next((x for x, t in enumerate(b) if H23.match(t)), None)
    if h is not None and states_requirement(b[h + 1:]): return "a heading and a requirement inside"
    return None

def _html_end(L, i, stack, r, end):  # → the last line of the HTML block opened at line i
    depth, j = len(stack), i
    while True:
        seg = r if j == i else L[j][cont(L[j], stack)[1]:]
        if end is not None and end.search(seg): return j
        if j + 1 >= len(L): return j
        k2, c2 = cont(L[j + 1], stack)
        if k2 < depth or (end is None and not L[j + 1][c2:].strip()): return j
        j += 1

def blocks(lines):
    """One CommonMark-shaped pass → (hidden {idx: frontmatter|fence|comment}, refusals, content {idx: text after its
    blockquote / list-item prefixes}, meta {idx: (container stack, opened a container)}, html {idx of a raw HTML block:
    True on the line that opens it}, shadows [idx of a hidden block holding a heading + text])."""
    L = [l.expandtabs(4) for l in lines]; n = len(L); hidden, refusals, text, i0, content = {}, [], set(), 0, {}
    s = next((k for k in range(n) if L[k].strip()), None)  # frontmatter: the file's first non-blank line, a YAML mapping
    if s is not None and L[s].strip() == "---":
        seq = False  # YAML: a column-0 '- ' item only follows a `key:` with no inline value; any other text is no YAML
        for j in range(s + 1, n):
            t = L[j]; k = YAML_TOP.match(t)
            if t.strip() in ("---", "..."):
                if any(YAML_TOP.match(x) for x in L[s + 1:j]): hidden.update((x, "frontmatter") for x in range(s, j + 1)); i0 = j + 1
                break
            if k: seq = not (k.group(1) or "").split(" #")[0].strip()
            elif t.strip() and t[:1] not in " \t#]}" and not (seq and re.match(r"^-(?:[ \t]|$)", t)): break
    def refuse(sp, why): refusals.append((sp[1], "%s: %s" % ("```" if sp[0] == "fence" else "<!--", why)))
    spans, stack, para, i, meta, htm = [], [], False, i0, {}, {}
    while i < n:
        s = L[i]; k, col = cont(s, stack); whole = k == len(stack)
        if not whole:
            r = s[col:]
            if para and r.strip() and not (ATX_CM.match(r) or FENCE.match(r) or THEMATIC.match(r) or HTML6.match(r)
                                            or re.match(r" {0,3}(?:>|<!--)", r) or item(r, 0) is not None
                                            or any(rx.match(r) for rx, _ in HTML_ENDS)):
                meta[i] = (tuple(stack), False); i += 1; continue  # a lazy paragraph continuation: the containers stay open
            stack = stack[:k]
        opened = False
        while True:
            m = re.match(r" {0,3}>", s[col:])
            if m: stack = stack + [">"]; col += m.end(); col += s[col:col + 1] == " "; opened = True; continue
            w = item(s, col)
            if w is None: break
            mm = ITEM.match(s[col:])  # an empty item or an ordered one not starting at 1 cannot interrupt a paragraph
            if para and whole and not opened and (not s[col + mm.end():].strip() or (mm.group(1) and int(mm.group(1)) != 1)): break
            stack, col, opened = stack + [w], w, True
        r = s[col:]; content[i] = r; meta[i] = (tuple(stack), opened); m = FENCE.match(r); depth, j, how = len(stack), i, "eof"
        code = not para and len(r) - len(r.lstrip(" ")) >= 4 and r.strip()  # indented code: no block starts in it
        if i not in text and not code and not re.match(r" {0,3}<!--", r):
            end = next((e for rx, e in HTML_ENDS if rx.match(r)), None)
            if end is not None or HTML6.match(r) or (not (para and whole and not opened) and HTML7.match(r)):
                j = _html_end(L, i, stack, r, end)
                for x in range(i, j + 1):
                    htm[x] = x == i
                    if x > i: content[x] = L[x][cont(L[x], stack)[1]:]; meta[x] = (tuple(stack), False)
                para, i = False, j + 1; continue
        if i not in text and not code and m and not (m.group(1)[0] == "`" and "`" in m.group(2)):  # a ``` info string holds no backtick
            closer = re.compile(r"^ {0,3}%s{%d,}[ \t]*$" % (re.escape(m.group(1)[0]), len(m.group(1))))
            for j in range(i + 1, n + 1):
                if j == n: break
                k2, c2 = cont(L[j], stack)
                if k2 < depth: how = "container"; break
                if closer.match(L[j][c2:]): how = "closed"; break
            sp = ["fence", i, j, how, (m.group(2).split() or [""])[0].lower(), stack, col]
        elif i not in text and not code and re.match(r" {0,3}<!--", r):
            seg = r[r.index("<!--"):]  # CommonMark checks the end on the opening line too: '<!-->' / '<!--->' close it
            while "-->" not in seg:
                j += 1
                if j >= n: break
                k2, c2 = cont(L[j], stack)
                if k2 < depth: how = "container"; break
                seg = L[j][c2:]
            else: how = "closed"
            sp = ["comment", i, j, how, "", stack, col]
        else:
            para = bool(r.strip()) and not (code or ATX_CM.match(r) or THEMATIC.match(r) or (para and UNDERLINE.match(r))); i += 1; continue
        why = forgotten(L, sp)
        if why:  # its opener is text; a sample holding sections keeps its closer from opening a new fence
            refuse(sp, why); text.add(i); para = True; i += 1
            if sp[0] == "fence" and how == "closed" and sp[4] in HASH_LANGS and why.startswith(("a numbered", "a heading and")):
                text.add(j)
            continue
        spans.append(sp); para, i = False, (j + 1 if how == "closed" else j)
    # a later fence with no closer / read as another opener: the pairing shifted, a closer went missing before it —
    # so every earlier closed fence holding an H2/H3 may be the one that lost it (refused: no new hidden range)
    shift = min((x for x, w in refusals if w.startswith(("```: no closer", "```: another fence opener"))), default=-1)
    shadows = []
    for sp in spans:
        b = inner(L, sp)
        if sp[0] == "fence" and sp[1] < shift and any(H23.match(x) for x in b):
            refuse(sp, "a later fence lost its pair (no closer / another opener), so this one may have")
            continue
        hidden.update((k, sp[0]) for k in range(sp[1], sp[2] + (sp[3] == "closed")))
        if any(H23.match(x) and any(y.strip() and not H23.match(y) for y in b[k + 1:k + 3]) for k, x in enumerate(b)):
            shadows.append(sp[1])
    return hidden, sorted(refusals), content, meta, htm, shadows

def _clean(t):  # heading text without inline tags (<a id=x></a>, <br>, <b> …) → (text, the tags' id/name values)
    ids = [x for tag in INLINE_TAG.findall(t) for x in TAG_ID.findall(tag)]
    return re.sub(r"\s+", " ", INLINE_TAG.sub("", t)).strip(), ids

def headings(lines, hidden, content, meta, htm):
    """Every H1-H6 as {level, text, raw, idx (first line), last (last line), ids}, in document order."""
    out = []
    def plain(x):  # a raw-HTML line is searched with its list / blockquote markers stripped (fail closed)
        t = content.get(x, lines[x]); return MARKERS.sub("", t) if x in htm else t
    def M(x): return meta.get(x, ((), False))  # a line of a fence refused after the pass: top level
    for i, raw in enumerate(lines):
        if i in hidden: continue
        ln = plain(i); m = ATX.match(ln)
        if m:
            h, t = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
            t = re.sub(r"(?:^|[ \t]+)#+[ \t]*$", "", t.strip()).strip(); x = re.search(r"\{#([^}\s]+)\}[ \t]*$", t)
            t, ids = _clean(t)
            out.append({"level": len(h), "text": unescape(t), "raw": t, "idx": i, "last": i, "ids": ids + ([x.group(1)] if x else [])})
            continue
        seg, k = CODESPAN.sub(lambda c: " " * len(c.group(0)), ln), i
        while HTML_OPEN.search(seg) and k + 1 < len(lines) and k - i < 10 and lines[k + 1].strip() and k + 1 not in hidden:
            k += 1; seg += " " + plain(k)  # <h2\n  id="x">: the tag's attributes wrap
        found = False
        for hm in HTML_HEAD.finditer(seg):
            lvl, close, t, j = hm.group(1), re.compile(r"(?i)</h%s\s*>" % hm.group(1)), seg[hm.end():], k
            while not close.search(t) and j + 1 < len(lines) and j - i < 10 and lines[j + 1].strip() and j + 1 not in hidden:
                j += 1; t += " " + plain(j)
            t = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]*>", " ", close.split(t)[0]))).strip()
            x = re.search(r"""\bid\s*=\s*["']?([^"'\s>]+)""", hm.group(2))
            out.append({"level": int(lvl), "text": t, "raw": t, "idx": i, "last": j, "ids": [x.group(1)] if x else []}); found = True
        u = UNDERLINE.match(ln)
        if found or not u or M(i)[1]: continue
        st, par, j = M(i)[0], [], i - 1  # the paragraph (same containers) a setext underline turns into a heading
        while j >= 0 and j not in hidden and not htm.get(j) and M(j)[0] == st:  # (inside raw HTML too: fail closed)
            c = plain(j)
            if not c.strip() or any(r.match(c) for r in (ATX, UNDERLINE, THEMATIC, FENCE)) or HTML_HEAD.search(c): break
            par.insert(0, j)
            if M(j)[1]: break  # the line that opened this container starts the paragraph
            j -= 1
        if not par:  # a lone '3. Name' over an underline reads as a heading (fail closed; CommonMark: an item + a rule)
            j = i - 1; t = lines[j][cont(lines[j].expandtabs(4), list(st))[1]:].strip() if j >= 0 else ""
            if (j >= 0 and j not in hidden and M(j)[1] and M(j)[0][:-1] == st and ORDERED.match(t)
                    and (j == 0 or not lines[j - 1].strip() or ATX.match(plain(j - 1)))):
                t = _clean(t)[0]; out.append({"level": 1 if u.group(1)[0] == "=" else 2, "text": unescape(t), "raw": t, "idx": j, "last": i, "ids": []})
            continue
        texts = [plain(p).strip() for p in par]
        if any(TABLE_SEP.match(texts[k]) and "|" in texts[k - 1] for k in range(1, len(texts))): continue  # a table
        t, ids = _clean(" ".join(texts))
        out.append({"level": 1 if u.group(1)[0] == "=" else 2, "text": unescape(t), "raw": t, "idx": par[0], "last": i, "ids": ids})
    return out

def parse(path, rel):
    """One source file → {file, lines, heads, hidden, refusals, shadows}; heads carry slug (unique), ids, alias (older
    slug rules), name, f_id, sec and line (1-based)."""
    lines = split_lines(open(path, encoding="utf-8", errors="replace").read())
    hidden, refusals, content, meta, htm, shadows = blocks(lines)
    heads, seen = headings(lines, hidden, content, meta, htm), {}
    for h in heads:
        text = h.pop("text"); bare = re.sub(r"[ \t]*\{#[^}]*\}[ \t]*$", "", text); base = slug(bare); s = base
        while s in seen:  # github-slugger: x, x-1, x-2 …
            seen[base] += 1; s = "%s-%d" % (base, seen[base])
        seen[s] = 0
        f, sec = F_ID.search(text), SEC.match(text)
        h.update(heading=text, slug=s, line=h["idx"] + 1, ids=[slug(x) for x in h["ids"]], name=norm(text),
                 alias={ascii_slug(bare), slug(re.sub(r"[ \t]*\{#[^}]*\}[ \t]*$", "", h.pop("raw")))} - {base},
                 f_id=f.group(1) if f else None, sec=sec.group(1).lower() if sec else None)
    return {"file": rel, "lines": lines, "heads": heads, "hidden": hidden, "refusals": refusals, "shadows": shadows}

def census(doc):
    """→ (anchors, containers) of one parsed file. A heading is a CONTAINER when it has no text of its own and at least
    one sub-heading: its sub-headings are censused in its place. Anchors = every other non-empty H1-H3, every H4-H6
    whose parent is a censused container, and PREAMBLE when visible text precedes the first heading. An anchor's `end`
    (1-based) is the line before the next heading of its level or H1-H3; an H4+ line inside an anchor belongs to it."""
    L, hid = doc["lines"], doc["hidden"]; hs = [h for h in doc["heads"] if h["heading"]]
    hl = {x for h in doc["heads"] for x in range(h["idx"], h["last"] + 1)}
    def text(a, b): return any(L[x].strip() and x not in hl and hid.get(x) not in ("comment", "frontmatter")
                               and not THEMATIC.match(L[x]) and not FENCE.match(L[x]) for x in range(a, b))  # a marker is no text
    first = hs[0]["idx"] if hs else len(L); anchors, containers, par = [], [], []
    if text(0, first):
        anchors.append({"level": 0, "heading": PREAMBLE, "slug": "", "line": 1, "end": first, "name": norm(PREAMBLE),
                        "sec": None, "idx": 0, "last": -1, "ids": [], "alias": set(), "f_id": None})
    for k, h in enumerate(hs):
        nxt = hs[k + 1]["idx"] if k + 1 < len(hs) else len(L)
        while par and par[-1][0] >= h["level"]: par.pop()
        cand = h["level"] <= 3 or bool(par and par[-1][1])
        box = cand and k + 1 < len(hs) and hs[k + 1]["level"] > h["level"] and not text(h["last"] + 1, nxt)
        par.append((h["level"], box))
        if box: containers.append(h)
        elif cand:
            h["end"] = next((x["idx"] for x in hs[k + 1:] if x["level"] <= max(h["level"], 3)), len(L)); anchors.append(h)
    return anchors, containers

def resolve_frag(doc, frag):
    """The heads a `#<fragment>` names — first tier that hits: unique slug · explicit id ({#id}, html id / a name) ·
    an older slug rule (ASCII, raw text) · a whole F-<X>-<NNN> id (F-U-001 is not F-U-001-B / F-U-001a). >1 = ambiguous."""
    s = slug(frag or "")
    if not s: return []
    for tier in (lambda h: h["slug"] == s, lambda h: s in h["ids"], lambda h: s in h["alias"]):
        hit = [h for h in doc["heads"] if tier(h)]
        if hit: return hit
    return [h for h in doc["heads"] if h["f_id"] and re.search(r"(?<![\w.-])%s(?![\w.-])" % re.escape(h["f_id"].lower()), frag.lower())]

def rel_path(p, cwd):
    """A path (absolute, or relative to cwd — ./ and ../ normalised) → relative to the real cwd; directories resolved."""
    p = os.path.normpath(p if os.path.isabs(p) else os.path.join(cwd, p.replace("\\", "/")))
    p = os.path.join(os.path.realpath(os.path.dirname(p)), os.path.basename(p))
    return os.path.relpath(p, os.path.realpath(cwd)).replace("\\", "/")

def exact_case(cwd, p):
    """True when every component of `p` (relative to cwd, or absolute) exists with exactly this case — a
    case-insensitive filesystem otherwise opens docs/prd.md for docs/PRD.md."""
    cur = "/" if os.path.isabs(p) else os.path.realpath(cwd)
    for part in [x for x in p.replace("\\", "/").split("/") if x not in ("", ".")]:
        if part == "..": cur = os.path.dirname(cur); continue
        try:
            if part not in os.listdir(cur): return False
        except OSError:
            return False
        cur = os.path.join(cur, part)
    return True

def vault_key(cwd, vault):
    return os.path.relpath(os.path.realpath(vault), os.path.realpath(cwd)).replace("\\", "/")

def _read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f: return f.read()
    except OSError:
        return None

def kb_sources(kb):
    """(module files, grammar) of a KB dir: modules/*.prd.md (PRD-kontrak), else 10-domains/**/*.md (numbered tree)."""
    m = sorted(glob.glob(os.path.join(kb, "modules", "*.prd.md")))
    return (m, "prd-kontrak") if m else (sorted(glob.glob(os.path.join(kb, "10-domains", "**", "*.md"), recursive=True)), "numbered-tree")

def expected_sources(cwd, vault):
    """The files a vault's coverage run must census (cwd-relative), from the vault's own pins — never from the last run:
    a KB-born vault (pin = <kb>/README.md) → every KB module; else the pinned PRD (context.md frontmatter / vault.json
    prd_path_at_generation) + every `type: brief` source document (a diff-vault delta seed-PRD); no .md pin → every .md
    source document. None when the vault names no source."""
    try: vj = json.loads(_read(os.path.join(vault, "vault.json")) or "{}")
    except Exception: vj = {}
    vj = vj if isinstance(vj, dict) else {}
    fm = re.match(r"^---\r?\n(.*?)\r?\n---", _read(os.path.join(vault, "context.md")) or "", re.S)
    pin = fm and re.search(r"^prd_path_at_generation:[ \t]*['\"]?([^'\"\n]*?)['\"]?[ \t]*$", fm.group(1), re.M)
    pin = pin.group(1).strip() if pin else vj.get("prd_path_at_generation")
    sd = [d for d in vj.get("source_documents") or [] if isinstance(d, dict) and isinstance(d.get("path"), str)]
    md = lambda p: p.lower().endswith(".md")
    if isinstance(pin, str) and os.path.basename(pin) == "README.md" and kb_sources(os.path.join(cwd, os.path.dirname(pin)))[0]:
        out = kb_sources(os.path.join(cwd, os.path.dirname(pin)))[0]
    elif isinstance(pin, str) and md(pin):
        out = [pin] + [d["path"] for d in sd if str(d.get("type", "")).lower() == "brief" and md(d["path"])]
    else:
        out = [d["path"] for d in sd if md(d["path"])]
    return sorted({rel_path(p, cwd) for p in out}) or None

def plan_vaults(cwd):
    """Every plan-born vault carrying units (context.md present, not a migrated layout-2 vault)."""
    return [d for d in sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*")))
            if os.path.isfile(os.path.join(d, "context.md")) and not os.path.isdir(os.path.join(d, "_meta", "archive", "layout2"))
            and (glob.glob(os.path.join(d, "units", "U-*.md")) or glob.glob(os.path.join(d, "units", "U-*", "unit.md")))]

def unit_refs(vault):
    """[(unit file, [prd_source refs], superseded?)] — scalar, flow list or block list."""
    out = []
    for uf in sorted(glob.glob(os.path.join(vault, "units", "U-*.md")) + glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))):
        t = _read(uf) or ""; fm = re.match(r"^---\r?\n(.*?)\r?\n---", t, re.S)
        if not fm: continue
        fm, refs = fm.group(1), []
        sup = bool(re.search(r"^status:[ \t]*['\"]?superseded\b", fm, re.M | re.I))
        m = re.search(r"^prd_source:[ \t]*(.*)$", fm, re.M)
        if m:
            head = m.group(1).strip()
            if head.startswith("["): refs = [x.strip().strip("'\"") for x in head.strip("[]").split(",") if x.strip()]
            elif head: refs = [head.strip("'\"")]
            else:
                for ln in split_lines(fm[m.end():]):
                    if re.match(r"^\s*-\s+", ln): refs.append(re.sub(r"^\s*-\s+", "", ln).strip().strip("'\""))
                    elif ln.strip(): break
        out.append((os.path.relpath(uf, vault).replace("\\", "/"), refs, sup))
    return out

def visible(text):
    """[(line no, line)] of a context.md, a fenced / commented / <script>/<style>/<template> line blanked ('')."""
    out, skip = [], None
    for n, ln in enumerate(split_lines(text or ""), 1):
        if skip:
            skip = None if skip.search(ln) else skip; out.append((n, "")); continue
        fm, cm = FENCE.match(ln), re.match(r"^ {0,3}<!--", ln)
        hm = re.match(r"(?i)^ {0,3}<(script|style|template)(?=[\s>]|$)", ln)
        if fm: skip = re.compile(r"^ {0,3}%s{%d,}[ \t]*$" % (re.escape(fm.group(1)[0]), len(fm.group(1))))
        elif cm and "-->" not in ln[ln.index("<!--"):]: skip = re.compile("-->")
        elif hm and not re.search(r"(?i)</%s\s*>" % hm.group(1), ln): skip = re.compile(r"(?i)</%s\s*>" % hm.group(1))
        out.append((n, "" if fm or cm or hm else ln))
    return out

def read_oqs(vault):
    """The vault's OQs — from context.md `## Open Questions` (visible lines only; the markdown is the source), else
    vault.json when there is no context.md. Each: {tag, status, resolved_by, text, origin, resolution, …, covers[]}."""
    md = _read(os.path.join(vault, "context.md"))
    if md is None:
        try: oqs = [o for o in json.loads(_read(os.path.join(vault, "vault.json")) or "{}").get("open_questions", []) if isinstance(o, dict)]
        except Exception: return []
        rows = ["%s %s" % (o.get("text") or "", o.get("origin") or "") for o in oqs]
    else:
        import sys
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import vault_md
        sec = vault_md.v3_sections("\n".join(ln for _, ln in visible(md))).get("open questions", "")
        oqs = vault_md.parse_open_questions("context.md", sec, [])
        rows = [ln for ln in sec.splitlines() if vault_md.OQ_LINE_RE.match(ln)]
    for o, row in zip(oqs, rows):
        o["covers"] = [r.strip() for g in COVERS_RE.findall(row) for r in g.split(",") if r.strip()]
    return oqs

def exclusion_lines(ctx_text):
    """→ (section lines [(line no, text)], near-miss headers [(line no, text)]) of context.md `## Coverage exclusions`
    (an ATX H2, exact name): hidden lines are blank; H3+ stay inside; the next H1/H2 ends it. A near miss = any other
    heading (any level, setext too) named coverage exclusion(s) / exclusions (a number, '(…)' or a ':' aside)."""
    out, near, sec, prev = [], [], False, ""
    for n, ln in visible(ctx_text):
        h = re.match(r"^ {0,3}(#{1,6})[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$", ln)
        t = h.group(2) if h else prev if UNDERLINE.match(ln) and prev.strip() and not MARKERS.match(prev) else None
        prev = ln
        if t is None:
            if sec: out.append((n, ln))
            continue
        exact = bool(h) and h.group(1) == "##" and t.strip().lower() == "coverage exclusions"
        k = re.sub(r"\s*\([^)]*\)\s*$|^(?:§?\s*\d+(?:\.\d+)*[.)]?\s+)|[:.]\s*$", "", t.strip().lower()).strip()
        if not exact and k in ("coverage exclusions", "coverage exclusion", "exclusions"): near.append((n if h else n - 1, (ln if h else t).strip()))
        if exact or (h and len(h.group(1)) <= 2): sec = exact
        elif sec: out.append((n, ln))
    return out, near

def digest(cwd, vault, sources):
    """What a coverage verdict depends on: the source files, the context.md `## Coverage exclusions` line TEXTS, the OQs
    (tag / status / text / origin / covers / outcome) and every unit's prd_source refs + superseded flag. Unit status /
    body edits, flows and other context.md sections — and a line moving — do not change it."""
    h = hashlib.sha256()
    for s in sources:
        raw = None
        try:
            with open(os.path.join(cwd, s), "rb") as f: raw = f.read()
        except OSError:
            pass
        h.update(("S %s %s\n" % (s, hashlib.sha256(raw).hexdigest() if raw is not None else "-")).encode())
    h.update(json.dumps([ln for _, ln in exclusion_lines(_read(os.path.join(vault, "context.md")))[0]], ensure_ascii=False).encode())
    h.update(json.dumps([[o.get(k) for k in ("tag", "status", "resolved_by", "text", "origin", "covers", "resolution", "out_of_scope_reason")]
                         for o in read_oqs(vault)], ensure_ascii=False).encode())
    h.update(json.dumps(unit_refs(vault), ensure_ascii=False).encode())
    return h.hexdigest()

def coverage_verdict(cwd, vaults):
    """(passed, why, missing) of .mega-sdd/.plan-coverage-state.json for execute-bolts: every plan-born vault in `vaults`
    needs a PASS entry whose digest still matches and whose census holds every source the vault now pins
    (expected_sources — a revised PRD, an added KB module). Never recomputes the census. `missing` = the state or an
    entry is absent / stale — what a plan hop earlier in the same chain produces."""
    try:
        with open(os.path.join(cwd, ".mega-sdd", ".plan-coverage-state.json"), encoding="utf-8") as f: d = json.load(f)
    except FileNotFoundError:
        return False, "missing (a skipped census is not a pass)", True
    except Exception:
        d = None
    if not isinstance(d, dict): return False, "unreadable", False
    if not vaults:
        g = d.get("gaps") if isinstance(d.get("gaps"), list) else []
        return d.get("status") == "PASS", "%s (%d gap(s))" % (str(d.get("status"))[:20], len(g)), False
    ents = d.get("vaults") if isinstance(d.get("vaults"), dict) else {}
    bad, missing = [], False
    for v in vaults:
        key = vault_key(cwd, v); e = ents.get(key); exp = expected_sources(cwd, v)
        if not isinstance(e, dict):
            bad.append("missing for %s" % key); missing = True
        elif e.get("status") != "PASS":
            heads = [re.sub(r"\s+", " ", str(x))[:60] for x in (e.get("gap_headings") or [])]
            bad.append("FAIL for %s (%s gap(s)%s)" % (key, e.get("gaps", "?"), (": " + "; ".join(heads[:3]) + (" …" if len(heads) > 3 else "")) if heads else ""))
        elif exp and not set(exp) <= set(e.get("sources") or []):
            bad.append("stale for %s (the run censused %s, the vault now pins %s — re-run validate-plan-coverage.sh on them)"
                       % (key, ", ".join(e.get("sources") or []) or "nothing", ", ".join(exp))); missing = True
        elif e.get("digest") != digest(cwd, v, e.get("sources") or []):
            bad.append("stale for %s (its PRD, context.md exclusions / OQs or units changed since the gate ran — re-run "
                       "validate-plan-coverage.sh)" % key); missing = True
    return not bad, "; ".join(bad) or "PASS", missing

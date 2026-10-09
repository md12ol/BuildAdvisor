"""Builds the PLAYER handbook of one mod from the full docs site:

    python docs_site/build_player_handbook.py                       # both mods -> <project>/<Mod>/Handbook.html
    python docs_site/build_player_handbook.py --mod LootAdvisor --out some/dir/Handbook.html

Source: docs_site/mods_docs.html (the full private version; never edited here). Each install folder gets its own
handbook: a short shared chapter (Script Extender, mod manager, what is in the folder, using both mods) plus that mod's
chapter. One handbook per mod rather than one for both, because a player downloads one mod: the file then only
describes what they installed and stays half the size.

Removed from the source: the roadmap, every "For the developer" fold, the "Current status" logs, the
"not yet checked in game" / "planned" pills, the dev toggle, and screenshots that show a save's character name or
the old internal mod name (replaced by a clean shot from Media/ or dropped). Every rewrite rule must still match the
source; a rule that no longer matches is reported, so a changed mods_docs.html is noticed.

The result is self-contained (images are embedded, no web fonts) and is checked with LootAdvisor/tools/leak_scan.py's
patterns plus the extra list BANNED; any hit fails the run (exit 1) and nothing is written.
"""
import argparse
import base64
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BA = os.path.dirname(HERE)                      # this BuildAdvisor checkout
DESKTOP = os.path.dirname(BA)                   # the folder with the side-by-side repos
SRC = os.path.join(HERE, "mods_docs.html")
LEAK_SCAN = os.path.join(DESKTOP, "LootAdvisor", "tools")

MODS = {
    "BuildAdvisor": {"name": "Build Advisor", "chapter": "buildadvisor", "key": "F7", "other": "Loot Advisor",
                     "other_repo": "https://github.com/md12ol/LootAdvisor", "repo": "https://github.com/md12ol/BuildAdvisor",
                     "tagline": "The strongest build for your character, starred in the game's own menus: character "
                                "creation, Withers' respec and every level-up.",
                     "facts": [("Hotkey", "<kbd>F7</kbd> advisor window"), ("For", "every player, any character"),
                               ("Needs", "Script Extender v20 or newer")]},
    "LootAdvisor": {"name": "Loot Advisor", "chapter": "lootadvisor", "key": "F6", "other": "Build Advisor",
                    "other_repo": "https://github.com/md12ol/BuildAdvisor", "repo": "https://github.com/md12ol/LootAdvisor",
                    "tagline": "The right gear for your build, and where to find it: rainbow frames, rainbow map "
                               "markers, an item list and a live Sets page in your browser.",
                    "facts": [("Hotkey", "<kbd>F6</kbd> item list"), ("For", "the 7 origin characters"),
                              ("Needs", "Script Extender v20 or newer")]},
}

SE_URL = "https://github.com/Norbyte/bg3se"
BG3MM_URL = "https://github.com/LaughingLeader/BG3ModManager"
# PENDING: the label of the F6 window's Sets page button (the mod change is in progress; confirm the exact text)
SETS_BUTTON = "Open Sets page"

# ------------------------------------------------------------------------------------------------ rewrite rules
# (mod or None for both, regex, replacement). Every rule must match at least once.
RULES = [
    # --- Build Advisor
    ("BuildAdvisor", r'<div class="note warn">\s*<p><b>New version, not yet checked in the game\.</b>.*?</div>',
     '<div class="note"><p><b>Every choice is marked.</b> Stars on every named choice, rainbow outlines on tiles and '
     'spell icons, and targets on the ability rows. If a menu ever looks wrong, untick <i>Highlight in game menus</i> '
     'in the advisor window: the window keeps showing the full plan.</p></div>'),
    ("BuildAdvisor", r'\s*<p class="muted">Stars on race, class and subclass names, the point-buy targets and the skill '
                     r'picker were confirmed in the game earlier\..*?</p>', ""),
    ("BuildAdvisor", r" A walk took about 6 ms before the outlines were added; the new time is measured in the in-game "
                     r"check\.", ""),
    ("BuildAdvisor", r"<li><b>Confirmed in the running game:</b>.*?</li>",
     "<li>The newest marks (background, deity, feat choices, tile and spell outlines, level-up ability targets) have "
     "had the least testing. If one looks wrong, untick <i>Highlight in game menus</i>; the window still shows the "
     "plan.</li>"),
    # --- Loot Advisor
    ("LootAdvisor", r'<span class="lbl">Map label \(new layout\)</span>', '<span class="lbl">Map label</span>'),
    ("LootAdvisor", r' \(planned, see the <a href="#roadmap">Roadmap</a>\)', " (planned)"),
    ("LootAdvisor", r"Before release: scoring every item", "How the advice was made: scoring every item"),
    ("LootAdvisor", r"<b>Community consensus\.</b>", "<b>Community picks.</b>"),
    ("LootAdvisor", r">Settings and the dev toggle<", ">Settings<"),
    ("LootAdvisor", r"\s*<tr><td><code>Dev</code></td>.*?</tr>", ""),
    ("LootAdvisor", r'\s*<div class="note">\s*<p><b>Dev toggle:.*?</div>', ""),
    ("LootAdvisor", r"\s*<li><b>Not yet checked in the game:</b>.*?</li>", ""),
    ("LootAdvisor", r"The list for the Dark Urge in Act 3, Baldur's Gate: 29 items, 8 marked on the map\.",
     "The list for the Dark Urge in Act 3, Baldur's Gate: 29 items, 2 marked on the map, the nearest six on top."),
    # --- both: pills that only make sense to the developer
    (None, r'\s*<span class="pill (?:unv|plan)">[^<]*</span>', ""),
]

# figures, found by the zoom button's aria-label: keep after painting over boxes, replace from Media/, or drop
# (a dropped figure's caption is kept as a paragraph when "keep_caption" is set)
FIGURES = {
    "Enlarge: item frames": {"cover": [(0, 0, 1000, 62), (0, 283, 1000, 311)]},      # internal labels in the image
    "Enlarge: map markers compared": {"cover": [(0, 0, 1100, 33)]},                   # old internal mod name
    "Enlarge: item list window": {"media": ("LootAdvisor", "Screenshot_5_item_list_F6.jpg"),
                                  "crop": (384, 112, 2072, 1146), "width": 1400},     # old shot shows a save's name
    "Enlarge: not covered message": {"drop": True},                                   # old mod name, a hireling name
    "Enlarge: legend": {"drop": True, "keep_caption": True},                          # old shot shows a save's name
    "Enlarge: Sets page": {"drop": True},                                             # save's name; page redesigned
}

# words a player handbook must not contain (on top of leak_scan.py's patterns)
BANNED = [r"A[u]topilot", r"\bdeveloper\b", r"not yet checked", r"in-game check", r"\bRoadmap\b", r"\bprivate\b",
          r"\bsession\b", r"HAND[O]FF", r"\.lua\b", r"dev toggle", r"!la_dev", r"\bDebug\b", r"Current status",
          r"\bC[l]aude\b", r"mods_docs", r"[A-Z]:\\Users", r"\bdecision \d", r"\bthe author\b", r"helm"]
# private save / campaign names: leak_scan.hits() checks them (name hashes of BG3Tools tools/public_text.py)
# player-facing file names that are fine (removed before the leak patterns run)
ALLOWED = [r"\b(?:LootAdvisor|BuildAdvisor)\.pak\b", r"\bmodsettings\.lsx\b", r"\bHandbook\.html\b",
           r"\bINSTALL\.md\b", r"Page[/\\]Sets\.html", r"\bLootAdvisor\s+folder", r"\bMedia[/\\]", r"github\.com/[\w./-]+"]


def apply_rules(html, mod, misses):
    for i, (m, rx, rep) in enumerate(RULES):
        if m not in (None, mod):
            continue
        html, n = re.subn(rx, rep, html, flags=re.S)
        if n == 0 and m is not None:
            misses.append("rule %d (%s) did not match: %s" % (i, m, rx[:70]))
    return html


def webp_data(im, q=82):
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=q, method=6)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def fix_figures(html, misses, media_dir=None):
    from PIL import Image
    seen = set()

    def one(m):
        fig = m.group(0)
        label = re.search(r'aria-label="([^"]+)"', fig)
        rule = FIGURES.get(label.group(1)) if label else None
        if not rule:
            return fig
        seen.add(label.group(1))
        if rule.get("media"):
            mod, name = rule["media"]
            path = os.path.join(media_dir or os.path.join(DESKTOP, mod, mod, "Media"), name)
            if not os.path.isfile(path):
                misses.append("media file missing, figure dropped: %s" % path)
                return ""
            im = Image.open(path).convert("RGB")
            # the Media copy is the full 2560x1600 shot
            if rule.get("crop"):
                im = im.crop(rule["crop"])
            w = rule.get("width", im.width)
            im = im.resize((w, round(im.height * w / im.width)), Image.Resampling.LANCZOS)
            fig = re.sub(r'src="data:[^"]+"', 'src="%s"' % webp_data(im), fig)
            fig = re.sub(r'width="\d+" height="\d+"', 'width="%d" height="%d"' % im.size, fig)
            return fig
        if rule.get("drop"):
            cap = re.search(r"<figcaption>(.*?)</figcaption>", fig, re.S)
            if rule.get("keep_caption") and cap:
                return '<p class="prose">%s</p>' % cap.group(1)
            return ""
        if rule.get("cover"):
            src = re.search(r'src="data:image/\w+;base64,([^"]+)"', fig)
            im = Image.open(io.BytesIO(base64.b64decode(src.group(1)))).convert("RGB")
            for box in rule["cover"]:
                im.paste(im.getpixel((box[0] + 2, box[3] + 1)) if box[3] + 1 < im.height else (16, 15, 13), box)
            fig = fig.replace(src.group(0), 'src="%s"' % webp_data(im))
        return fig

    html = re.sub(r'<figure class="shot[^"]*">.*?</figure>', one, html, flags=re.S)
    # a pair that lost a figure keeps working as a grid; an empty pair is removed
    html = re.sub(r'<div class="pair">\s*</div>', "", html)
    return html, seen


def chapter(src, cid):
    m = re.search(r'<section class="chapter" id="%s".*?</section>' % cid, src, re.S)
    if not m:
        raise SystemExit("chapter %s not found in %s" % (cid, SRC))
    return m.group(0)


def clean_chapter(sec, mod, misses):
    sec = re.sub(r'\s*<details class="dev">.*?</details>', "", sec, flags=re.S)
    # the dated status log (and the "Planned" line under it) up to the next h3 or the end of the chapter
    sec, n = re.subn(r'\s*<h3 id="\w+-status">.*?(?=<h3 |</section>)', "\n    ", sec, flags=re.S)
    if not n:
        misses.append("no status block found in %s" % mod)
    sec = apply_rules(sec, mod, misses)
    sec = re.sub(r'<a href="#(?:roadmap|a[u]topilot)">(.*?)</a>', r"\1", sec)
    return sec


def toc(sec):
    items = re.findall(r'<h3 id="([\w-]+)">(.*?)</h3>', sec, re.S)
    return [(i, re.sub(r"<[^>]+>", "", t).strip()) for i, t in items]


def shared_chapter(mod):
    d = MODS[mod]
    page = view = ""
    if mod == "LootAdvisor":
        page = ("<tr><td class=\"nw\"><code>Page/Sets.html</code></td><td>A copy of the Sets page. Opened from this "
                "folder it tells you to load a save once and gives the path of the live page that the mod writes "
                "(see <a href=\"#la-page\">The Sets page</a>).</td></tr>")
        view = """
      <h3 id="sets-view">Viewing the Sets page next to the game</h3>
      <ul class="prose">
        <li><b>From the game:</b> press <kbd>F6</kbd>, then <b>%(btn)s</b> in the item list. Or open your bookmark of the page (load a save once first; the mod writes the page then).</li>
        <li><b>Two monitors:</b> play in <i>Borderless Window</i> (the game's Video settings) and keep the browser on the second monitor. The page follows the game by itself.</li>
        <li><b>One monitor:</b> open the Steam overlay browser (<kbd>Shift</kbd>+<kbd>Tab</kbd>, then the web browser) and open the page there, or switch to your browser with <kbd>Alt</kbd>+<kbd>Tab</kbd> (smoothest in <i>Borderless Window</i>).</li>
      </ul>""" % {"btn": SETS_BUTTON}
    return """
    <section class="chapter" id="before" aria-labelledby="before-h">
      <div class="chapter-head"><h2 id="before-h">Before you start</h2></div>
      <div class="prose">
        <p class="lede">%(name)s is a Script Extender mod. Install Script Extender once, then the mod, and it works from the next game start.</p>
      </div>
      <h3 id="se">Script Extender and a mod manager</h3>
      <ol class="steps">
        <li>Get <a href="%(bg3mm)s">BG3 Mod Manager</a> (free). In it, choose <i>Tools &gt; Download and Extract the Script Extender</i>. That installs <a href="%(se)s">BG3 Script Extender</a> (version 20 or newer) in one click. Script Extender is a separate community project and is not included with this mod.</li>
        <li>Drag <code>%(mod)s.pak</code> into BG3 Mod Manager (or <i>File &gt; Import Mod</i>), move %(name)s to the active mods list, then <i>Save Load Order</i> and <i>Export Load Order to Game</i>.</li>
        <li>Start the game. If a <b>Mod Verification</b> dialog lists %(name)s, tick it and choose Start Game.</li>
      </ol>
      <p class="prose">Installing by hand works too: copy the pak to <code>%%LOCALAPPDATA%%\\Larian Studios\\Baldur's Gate 3\\Mods\\</code> and enable it in the load order (a mod manager is the safe way to edit <code>modsettings.lsx</code>). The chapter below has the details for %(name)s.</p>
      <h3 id="folder">What is in this folder</h3>
      <div class="tw"><table>
        <thead><tr><th>File</th><th>What it is</th></tr></thead>
        <tbody>
          <tr><td class="nw"><code>%(mod)s.pak</code></td><td>The mod. This is the only file the game needs.</td></tr>
          <tr><td class="nw"><code>INSTALL.md</code></td><td>The install steps in short.</td></tr>
          <tr><td class="nw"><code>Handbook.html</code></td><td>This handbook. It works offline.</td></tr>
          %(page)s
          <tr><td class="nw"><code>Media/</code></td><td>The banner, thumbnail, logo marks and screenshots, for sharing or a mod page. The game does not need them.</td></tr>
        </tbody>
      </table></div>%(view)s
      <h3 id="both">Using it with %(other)s</h3>
      <div class="prose">
        <p>Build Advisor and Loot Advisor are separate mods; each works on its own. Installed together, Loot Advisor uses the build you picked in Build Advisor for each character, so the items it recommends match the build you follow. %(other)s is at <a href="%(other_repo)s">%(other_repo)s</a>.</p>
        <p>Both read the game and never change your character. Treat them as a guide with spoilers: they name builds, item locations and the story choices that open or close them.</p>
      </div>
    </section>
""" % {"name": d["name"], "mod": mod, "other": d["other"], "other_repo": d["other_repo"], "page": page, "view": view,
       "se": SE_URL, "bg3mm": BG3MM_URL}


def build(mod, src, media_dir=None):
    d = MODS[mod]
    misses = []
    style = re.search(r"<style>.*?</style>", src, re.S).group(0)
    style = re.sub(r"/\*.*?\*/", "", style, flags=re.S)                     # no internal notes, even in CSS
    style = re.sub(r"\.g-ap \{[^}]*\}\s*", "", style).replace(", .g-ap", "")  # the private tool's mark
    style = re.sub(r"\n\s*\n", "\n", style)
    script = re.search(r'<div class="lb" id="lb".*?</script>', src, re.S).group(0)
    sec = clean_chapter(chapter(src, d["chapter"]), mod, misses)
    sec, seen = fix_figures(sec, misses, media_dir)
    entries = toc(sec)
    shared = shared_chapter(mod)
    shared_toc = toc(shared)
    nav = "\n".join('            <li><a href="#%s">%s</a></li>' % e for e in entries)
    snav = "\n".join('            <li><a href="#%s">%s</a></li>' % e for e in shared_toc)
    mnav = "".join('<li><a href="#%s">%s</a></li>' % e for e in entries)
    facts = "".join("<dt>%s</dt><dd>%s</dd>" % f for f in d["facts"])
    glyph = "g-ba" if mod == "BuildAdvisor" else "g-la"
    html = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>%(name)s Handbook</title>
<meta name="description" content="How to install and use %(name)s, a Baldur's Gate 3 Script Extender mod.">
%(style)s
</head>
<body>
<div class="shell">
  <aside class="toc" aria-label="Contents">
    <a class="brand" href="#top">%(name)s<span>Player handbook</span></a>
    <nav>
      <ol>
        <li><a class="top" href="#start">Start here</a></li>
        <li><a class="top" href="#before">Before you start</a>
          <ol>
%(snav)s
          </ol>
        </li>
        <li><a class="top" href="#%(cid)s"><span class="glyph %(glyph)s" aria-hidden="true"></span>%(name)s</a>
          <ol>
%(nav)s
          </ol>
        </li>
      </ol>
    </nav>
  </aside>

  <main id="top">
    <details class="toc-mobile">
      <summary>Contents</summary>
      <nav aria-label="Contents (mobile)">
        <ol>
          <li><a href="#start">Start here</a></li>
          <li><a href="#before">Before you start</a></li>
          <li><a href="#%(cid)s">%(name)s</a><ol>%(mnav)s</ol></li>
        </ol>
      </nav>
    </details>

    <header class="hero" id="start">
      <span class="eyebrow">Baldur's Gate 3 &middot; Script Extender mod &middot; Patch 8</span>
      <h1>%(name)s Handbook</h1>
      <p>%(tagline)s</p>
      <div class="mods" style="grid-template-columns: minmax(0, 1fr)">
        <a class="mod-card" href="#%(cid)s">
          <h2><span class="glyph %(glyph)s" aria-hidden="true"></span>%(name)s</h2>
          <dl>%(facts)s</dl>
        </a>
      </div>
      <div class="note">
        <p><b>New here?</b> Read <a href="#before">Before you start</a> to install Script Extender and the mod, then <a href="#%(cid)s">%(name)s</a> for what you see in the game. The mod is free; source and updates: <a href="%(repo)s">%(repo)s</a>.</p>
      </div>
    </header>
%(shared)s
    %(sec)s

    <footer class="foot">
      <p>Baldur's Gate 3 is a game by Larian Studios; screenshots show the mod running in the game. Script Extender and BG3 Mod Manager are separate community projects. %(name)s is free and not made or endorsed by Larian Studios.</p>
    </footer>
  </main>
</div>

%(script)s
</body>
</html>
""" % {"name": d["name"], "style": style, "snav": snav, "nav": nav, "mnav": mnav, "cid": d["chapter"],
       "glyph": glyph, "tagline": d["tagline"], "facts": facts, "repo": d["repo"], "shared": shared, "sec": sec,
       "script": script}
    for k in FIGURES:
        if mod == "LootAdvisor" and k not in seen:
            misses.append("figure rule not used: %s" % k)
    # internal links that point at removed parts
    for ref in set(re.findall(r'href="#([\w-]+)"', html)):
        if not re.search(r'id="%s"' % re.escape(ref), html):
            misses.append("broken link #%s" % ref)
    return html, misses


# ------------------------------------------------------------------------------------------------ leak check
def visible_text(html):
    t = re.sub(r"<style>.*?</style>|<script>.*?</script>", " ", html, flags=re.S)
    attrs = re.findall(r'(?:alt|aria-label|title|content)="([^"]*)"', t)
    t = re.sub(r'src="data:[^"]+"', "", t)
    t = re.sub(r"<[^>]+>", " ", t)
    import html as h
    return h.unescape(t + "\n" + "\n".join(attrs))


def leak_check(html):
    text = visible_text(html)
    for rx in ALLOWED:
        text = re.sub(rx, " ", text)
    hits = []
    try:
        sys.path.insert(0, LEAK_SCAN)
        import leak_scan
        hits += [("%s" % n, s) for n, s in leak_scan.hits(text)]
    except ImportError:
        print("  note: %s not found, only the handbook's own word list is checked" % LEAK_SCAN)
    for rx in BANNED:
        hits += [("banned word", m.group(0)) for m in re.finditer(rx, text, re.I)]
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mod", choices=sorted(MODS), action="append")
    ap.add_argument("--out", help="output file (only with one --mod)")
    ap.add_argument("--media", help="Media/ folder to take replacement screenshots from (default: the install folder's)")
    a = ap.parse_args()
    mods = a.mod or sorted(MODS)
    if a.out and len(mods) != 1:
        raise SystemExit("--out needs exactly one --mod")
    src = open(SRC, encoding="utf-8").read()
    bad = 0
    for mod in mods:
        html, misses = build(mod, src, a.media)
        for m in misses:
            print("  WARNING %s: %s" % (mod, m))
        hits = leak_check(html)
        for n, s in hits:
            print("  LEAK %s: %s: %r" % (mod, n, s))
        if hits:
            bad += 1
            continue
        out = a.out or os.path.join(DESKTOP, mod, mod, "Handbook.html")
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(html)
        print("Handbook %s: %s (%.2f MB, leak check 0 hits)" % (mod, out, os.path.getsize(out) / 1e6))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

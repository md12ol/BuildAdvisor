"""Renders the branding pages to PNG with headless Edge/Chrome (Chrome DevTools Protocol, stdlib + Pillow).

    python branding/src/render.py                 -> every option / mod / format, then the contact sheet
    python branding/src/render.py 2 la banner     -> one option (1-3), mod (ba|la|all), format (or all)

Pages: branding/src/option{1,2,3}.html?mod=..&fmt=..  Output: branding/<Mod>/option{n}_<fmt>.png
Small formats (marks, wordmark) are drawn at 4x and downsampled, on a transparent background.
Uses a throw-away browser profile in %TEMP%; fonts come from Google Fonts at render time.
"""
import base64
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                                "LootAdvisor", "tools", "sets_artifact"))
from screens import WS, js  # noqa: E402  (minimal CDP websocket client already in the project)

SRC = os.path.dirname(os.path.abspath(__file__))
BR = os.path.dirname(SRC)
BROWSERS = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Google\Chrome\Application\chrome.exe"]
PORT = 9341
DIRS = {"ba": "BuildAdvisor", "la": "LootAdvisor"}
# fmt: (css width, css height, scale, transparent, output size, output name)
FMTS = {
    "banner": (1920, 1080, 1, False, None, "banner"),
    "thumb": (1024, 1024, 1, False, None, "thumb"),
    "docs": (1600, 400, 1, False, None, "docs"),
    "sets": (1440, 240, 1, False, None, "sets"),
    "mark": (128, 128, 4, True, (128, 128), "mark128"),
    "marksm": (64, 64, 4, True, (64, 64), "mark64"),
    "wordmark": (256, 64, 4, True, (256, 64), "wordmark"),
}


def render(ws, opt, mod, fmt):
    w, h, sc, transp, out_size, out_name = FMTS[fmt]
    ws.call("Emulation.setDeviceMetricsOverride", width=w, height=h, deviceScaleFactor=sc, mobile=False)
    ws.call("Emulation.setDefaultBackgroundColorOverride",
            color={"r": 0, "g": 0, "b": 0, "a": 0} if transp else {"r": 12, "g": 10, "b": 8, "a": 1})
    url = "file:///%s?mod=%s&fmt=%s" % (os.path.join(SRC, "option%d.html" % opt).replace("\\", "/"), mod, fmt)
    ws.call("Page.navigate", url=url)
    t0 = time.time()
    while time.time() - t0 < 30:
        time.sleep(0.2)
        if js(ws, "window.__ready === true"):
            break
    else:
        print("   ! not ready:", opt, mod, fmt)
    time.sleep(0.2)
    r = ws.call("Page.captureScreenshot", format="png")
    im = Image.open(io.BytesIO(base64.b64decode(r["data"]))).convert("RGBA")
    if out_size:
        im = im.resize(out_size, Image.LANCZOS)
    else:
        im = im.convert("RGB")
    d = os.path.join(BR, DIRS[mod])
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, "option%d_%s.png" % (opt, out_name))
    im.save(p, optimize=True)
    print("  ", os.path.relpath(p, BR), im.size)


def main():
    a = sys.argv[1:]
    opts = [int(a[0])] if a and a[0] != "all" else [1, 2, 3]
    mods = [a[1]] if len(a) > 1 and a[1] != "all" else ["ba", "la"]
    fmts = [a[2]] if len(a) > 2 and a[2] != "all" else list(FMTS)
    exe = next((b for b in BROWSERS if os.path.exists(b)), None)
    if not exe:
        sys.exit("no Edge/Chrome found")
    prof = tempfile.mkdtemp(prefix="br_render_")
    proc = subprocess.Popen([exe, "--headless=new", "--remote-debugging-port=%d" % PORT, "--user-data-dir=" + prof,
                             "--allow-file-access-from-files", "--hide-scrollbars", "--no-first-run",
                             "--disable-extensions", "--force-color-profile=srgb", "about:blank"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        page = None
        for _ in range(60):
            try:
                tabs = json.load(urllib.request.urlopen("http://127.0.0.1:%d/json" % PORT, timeout=2))
                page = next(t for t in tabs if t.get("type") == "page")
                break
            except Exception:
                time.sleep(0.3)
        ws = WS(page["webSocketDebuggerUrl"])
        ws.call("Page.enable")
        ws.call("Runtime.enable")
        for opt in opts:
            for mod in mods:
                for fmt in fmts:
                    if fmt == "sets" and mod != "la":
                        continue
                    render(ws, opt, mod, fmt)
    finally:
        proc.terminate()
    if not a:
        import contact_sheet
        contact_sheet.main()


if __name__ == "__main__":
    main()

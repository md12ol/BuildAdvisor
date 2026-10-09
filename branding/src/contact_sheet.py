"""Builds branding/options_overview.png: every option (columns) for every mod (rows), all formats, labelled.

    python branding/src/contact_sheet.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

SRC = os.path.dirname(os.path.abspath(__file__))
BR = os.path.dirname(SRC)
F = r"C:\Windows\Fonts"
OPTS = [
    ("Option 1 \u00b7 Gilded Panel", "The game's own UI language: dark leather, double gold frame, emblem in a gold-rimmed icon plate, real shots in ruled frames."),
    ("Option 2 \u00b7 Astrolabe", "Near-black, a glowing sigil, Cinzel capitals; one proof image seen through a round lens with an engraved dial."),
    ("Option 3 \u00b7 Cinematic", "A full-bleed game scene fading to black, a Cormorant film title, the mod's own UI floating over it; medallion monograms."),
]
MODS = [("BuildAdvisor", "Build Advisor", "gold \u00b7 star + level-up chevron"),
        ("LootAdvisor", "Loot Advisor", "prism \u00b7 rainbow gem / diamond"),
        ("Autopilot", "Autopilot", "ember red \u00b7 hex + nav arrow \u00b7 private")]
CW, GAP, M = 900, 44, 60
BG, INK, INK2, RULE = (13, 11, 9), (239, 228, 204), (160, 148, 128), (91, 74, 51)
PANELS = [(30, 26, 22), (58, 44, 28)]   # game window panel colours the marks must read on


def font(name, size):
    try:
        return ImageFont.truetype(os.path.join(F, name), size)
    except OSError:
        return ImageFont.load_default()


def fit(im, w):
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def main():
    t_big, t_mid, t_lab, t_small = font("palab.ttf", 64), font("palab.ttf", 40), font("segoeuib.ttf", 20), font("segoeui.ttf", 19)
    W = M * 2 + 3 * CW + 2 * GAP
    # measure
    row_h = {}
    for d, _, _ in MODS:
        h = 64 + round(1080 * CW / 1920) + 18 + 424
        if d == "LootAdvisor":
            h += 18 + 26 + round(240 * CW / 1440)
        row_h[d] = h + 60
    H = 320 + sum(row_h.values()) + 40
    sheet = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((M, 50), "BG3 mods \u2014 branding options", font=t_big, fill=INK)
    dr.text((M, 130), "Build Advisor \u00b7 Loot Advisor \u00b7 Autopilot (private).  Each column is one option, used the same way by all three mods; "
            "each mod keeps its own identity colour.", font=font("segoeui.ttf", 24), fill=INK2)
    for i, (name, desc) in enumerate(OPTS):
        x = M + i * (CW + GAP)
        dr.text((x, 200), name, font=t_mid, fill=(232, 196, 120))
        line, ly = "", 252
        for w in desc.split():
            if dr.textlength(line + " " + w, font=t_small) > CW - 10:
                dr.text((x, ly), line.strip(), font=t_small, fill=INK2); line, ly = "", ly + 24
            line += " " + w
        dr.text((x, ly), line.strip(), font=t_small, fill=INK2)
    y = 320
    for d, label, ident in MODS:
        dr.line((M, y, W - M, y), fill=RULE, width=2)
        dr.text((M, y + 14), label, font=t_mid, fill=INK)
        dr.text((M + dr.textlength(label, font=t_mid) + 24, y + 30), ident, font=t_small, fill=INK2)
        for i in range(3):
            x = M + i * (CW + GAP)
            p = lambda n: os.path.join(BR, d, "option%d_%s.png" % (i + 1, n))
            yy = y + 64
            b = fit(Image.open(p("banner")).convert("RGB"), CW)
            sheet.paste(b, (x, yy))
            dr.text((x + 8, yy + 6), "banner 1920\u00d71080", font=t_lab, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
            yy += b.height + 18
            th = fit(Image.open(p("thumb")).convert("RGB"), 370)
            sheet.paste(th, (x, yy))
            dr.text((x + 8, yy + 6), "thumb 1024", font=t_lab, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
            rx, rw = x + 388, CW - 388
            dc = fit(Image.open(p("docs")).convert("RGB"), rw)
            sheet.paste(dc, (rx, yy))
            dr.text((rx + 6, yy + 4), "docs header 1600\u00d7400", font=t_lab, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
            # marks on the two game panel colours, actual size
            my = yy + dc.height + 16
            ph = 136
            for k, pc in enumerate(PANELS):
                py = my + k * (ph + 8)
                dr.rectangle((rx, py, rx + rw, py + ph), fill=pc)
                cx = rx + 14
                for n in ("mark128", "mark64", "wordmark"):
                    im = Image.open(p(n)).convert("RGBA")
                    sheet.paste(im, (cx, py + (ph - im.height) // 2), im)
                    cx += im.width + 18
            dr.text((x, yy + 380), "marks 128 / 64, wordmark 256×64\non two game panel tones →", font=t_small, fill=INK2)
            yy += 424
            if d == "LootAdvisor":
                yy += 18
                dr.text((x, yy), "Sets page header 1440\u00d7240", font=t_lab, fill=INK2)
                s = fit(Image.open(p("sets")).convert("RGB"), CW)
                sheet.paste(s, (x, yy + 26))
        y += row_h[d]
    out = os.path.join(BR, "options_overview.png")
    sheet.save(out, optimize=True)
    print(out, sheet.size)


if __name__ == "__main__":
    main()

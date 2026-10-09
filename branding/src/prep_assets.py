"""Crops the real screenshots / recording frames used by the branding pages into branding/src/assets/.

    python branding/src/prep_assets.py

Sources (read only): LootAdvisor/shots and LootAdvisor/artifact/screens.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SHOTS = os.path.join(os.path.dirname(ROOT), "LootAdvisor", "shots")   # ../LootAdvisor/shots next to this repo
A = os.path.join(HERE, "assets")


def crop(src, box, name, q=92):
    im = Image.open(src).convert("RGB")
    if box:
        im = im.crop(box)
    p = os.path.join(A, name)
    if name.endswith(".jpg"):
        im.save(p, quality=q, subsampling=0)
    else:
        im.save(p)
    print(name, im.size)


def s(n):
    return os.path.join(SHOTS, n)


# Loot Advisor
crop(s("15_inventory_rainbow_zoom.png"), None, "la_inv.png")
crop(s("29_astarion_minimap_zoom.png"), None, "la_minimap.png")
crop(s("34_astarion_tooltip_crop.png"), None, "la_tooltip.png")
crop(s("53_entrance_marker_label_crop.png"), None, "la_marker.png")
crop(s("63_list_window_round3_crop.png"), None, "la_list.png")
crop(s("22_all_item_frames_rainbow.png"), (745, 300, 1730, 1170), "la_scene.jpg")      # paperdoll + bag grid
crop(s("22_all_item_frames_rainbow.png"), (1225, 320, 1715, 1170), "la_grid.jpg")      # bag grid only
crop(s("68_wu_page_chrome.png"), (340, 125, 2200, 1540), "la_sets.jpg")                # page only, no browser chrome
# Build Advisor (no screenshot of its window exists; the window is rebuilt in HTML from Window.lua + Builds.lua)
crop(s("74_wu_game_astarion_selected.png"), (270, 230, 2050, 1231), "ba_scene.jpg")   # Astarion in the Undercity
crop(s("22_all_item_frames_rainbow.png"), (238, 330, 715, 1215), "ba_charpanel.jpg")  # level 12 sheet, ability scores
crop(s("22_all_item_frames_rainbow.png"), (745, 40, 2560, 1170), "la_wide.jpg")       # inventory, paperdoll, cave, minimap
crop(s("34_gloves_cell_rainbow_x5.png"), None, "la_cell.png")                          # one rainbow cell, x5

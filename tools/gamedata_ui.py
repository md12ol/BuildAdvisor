"""Game data behind Build Advisor's in-menu labels (read-only; used by tools/check_hl.py).

Reads the game's own files straight from the paks (LootAdvisor/tools/pak.py) plus the cached English
localization (LootAdvisor/data/cache/loca_english.json) and resolved stats (stats_resolved.json):

  ClassDescriptions, Races, Backgrounds, Gods, Feats + FeatDescriptions, Progressions, PassiveLists, SpellLists,
  SkillLists, AbilityLists (Shared, Gustav, GustavX; later packs override earlier ones by UUID).

Library:
    gd = load()                  # GameData
    gd.labels                    # {english UI label: set of kinds} - every name a creation / level-up list can show
    gd.class_levels(name)        # [(level, progression dict)] for a class or subclass Name ("Wizard", "EvocationSchool")
    gd.selectors_text(sel)       # human readable selector ("choose 2 of: Fire Bolt, ...")

CLI:  python tools/gamedata_ui.py [ClassName ...]   prints the per-level choices of those classes (default: all)
"""
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LA_TOOLS = os.path.join(os.path.dirname(ROOT), "LootAdvisor", "tools")   # ../LootAdvisor next to this repo
CACHE = os.path.join(os.path.dirname(ROOT), "LootAdvisor", "data", "cache")
sys.path.insert(0, LA_TOOLS)
from pak import Pak, GAME_DATA  # noqa: E402

PAKS = ["Shared.pak", "Gustav.pak", "GustavX.pak"]
FILES = {
    "class": "ClassDescriptions/ClassDescriptions.lsx",
    "race": "Races/Races.lsx",
    "background": "Backgrounds/Backgrounds.lsx",
    "god": "Gods/Gods.lsx",
    "feat": "Feats/Feats.lsx",
    "featdesc": "Feats/FeatDescriptions.lsx",
    "progression": "Progressions/Progressions.lsx",
    "passivelist": "Lists/PassiveLists.lsx",
    "spelllist": "Lists/SpellLists.lsx",
    "skilllist": "Lists/SkillLists.lsx",
    "abilitylist": "Lists/AbilityLists.lsx",
    "origin": "Origins/Origins.lsx",
}
SKILLS = ["Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception", "History", "Insight", "Intimidation",
          "Investigation", "Medicine", "Nature", "Perception", "Performance", "Persuasion", "Religion",
          "Sleight of Hand", "Stealth", "Survival"]
ABILITIES = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]


MODULES = ["Shared", "SharedDev", "Gustav", "GustavDev", "GustavX"]


def _module_rank(path):
    """later modules override earlier ones (Public/<Module>/...)"""
    parts = path.split("/")
    return MODULES.index(parts[1]) if len(parts) > 1 and parts[1] in MODULES else -1


def _nodes(xml_bytes, node_id):
    root = ET.fromstring(xml_bytes)
    for n in root.iter("node"):
        if n.get("id") == node_id:
            yield n


def _attrs(node):
    out = {}
    for a in node.findall("attribute"):
        out[a.get("id")] = a.get("handle") if a.get("type") == "TranslatedString" else a.get("value")
    return out


def _children(node, child_id):
    """attributes of every descendant node with this id (e.g. Progression > SubClasses > SubClass)"""
    return [_attrs(n) for n in node.iter("node") if n is not node and n.get("id") == child_id]


class GameData:
    def __init__(self):
        with open(os.path.join(CACHE, "loca_english.json"), encoding="utf-8") as f:
            self.loca = json.load(f)
        with open(os.path.join(CACHE, "stats_resolved.json"), encoding="utf-8") as f:
            self.stats = json.load(f)
        self.raw = {k: {} for k in FILES}  # kind -> {uuid: attrs}
        node_ids = {"class": "ClassDescription", "race": "Race", "background": "Background", "god": "God",
                    "feat": "Feat", "featdesc": "FeatDescription", "progression": "Progression",
                    "passivelist": "PassiveList", "spelllist": "SpellList", "skilllist": "SkillList",
                    "abilitylist": "AbilityList", "origin": "Origin"}
        for pk in PAKS:
            p = Pak(os.path.join(GAME_DATA, pk))
            try:
                for e in p.entries:
                    if not e.name.startswith("Public/") or not e.name.endswith(".lsx"):
                        continue
                    for kind, suffix in FILES.items():
                        if e.name.endswith("/" + suffix):
                            data = p.read(e)
                            for n in _nodes(data, node_ids[kind]):
                                a = _attrs(n)
                                if kind == "progression":
                                    a["_subclasses"] = [c.get("Object") for c in _children(n, "SubClass")]
                                if kind == "feat":
                                    a["_req"] = a.get("Requirements")
                                a["_rank"] = _module_rank(e.name)
                                uid = a.get("UUID") or a.get("Name")
                                self.raw[kind][uid] = a
            finally:
                p.close()
        self._build_labels()

    # ------------------------------------------------------------------ text
    def text(self, handle):
        if not handle:
            return None
        h = handle.split(";")[0]
        t = self.loca.get(h)
        return t.strip() if isinstance(t, str) else None

    def stat_name(self, stat_id):
        s = self.stats.get(stat_id)
        return self.text(s.get("DisplayName")) if s else None

    def _build_labels(self):
        L = {}

        def add(label, kind):
            if label:
                L.setdefault(label, set()).add(kind)
        self.class_by_name = {}
        for a in self.raw["class"].values():
            self.class_by_name[a.get("Name")] = a
            add(self.text(a.get("DisplayName")), "class" if not a.get("ParentGuid") else "subclass")
            add(self.text(a.get("ShortName")), "subclass-short")
        for a in self.raw["race"].values():
            add(self.text(a.get("DisplayName")), "race")
        for a in self.raw["background"].values():
            add(self.text(a.get("DisplayName")), "background")
        for a in self.raw["god"].values():
            add(self.text(a.get("DisplayName")), "deity")
        for a in self.raw["featdesc"].values():
            add(self.text(a.get("DisplayName")), "feat")
        for s in SKILLS:
            add(s, "skill")
        for s in ABILITIES:
            add(s, "ability")
        # every spell / passive that a selector list or a progression can offer
        self.passive_lists = {u: [x for x in re.split(r"[,;]", a.get("Passives") or "") if x]
                              for u, a in self.raw["passivelist"].items()}
        self.spell_lists = {u: [x for x in re.split(r"[,;]", a.get("Spells") or "") if x]
                            for u, a in self.raw["spelllist"].items()}
        for ids in self.passive_lists.values():
            for pid in ids:
                add(self.stat_name(pid), "passive")
        for ids in self.spell_lists.values():
            for sid in ids:
                add(self.stat_name(sid), "spell")
        for a in self.raw["progression"].values():
            for pid in (a.get("PassivesAdded") or "").split(";"):
                if pid:
                    add(self.stat_name(pid), "feature")
        self.labels = L

    # ------------------------------------------------------------------ progressions
    def class_levels(self, name):
        c = self.class_by_name.get(name)
        if not c:
            return []
        table = c.get("ProgressionTableUUID")
        rows = [a for a in self.raw["progression"].values() if a.get("TableUUID") == table]
        rows.sort(key=lambda a: (int(a.get("Level") or 0), a.get("Name") or ""))
        return [(int(a.get("Level") or 0), a) for a in rows]

    def list_names(self, uid, spells):
        ids = (self.spell_lists if spells else self.passive_lists).get(uid, [])
        return [self.stat_name(i) or i for i in ids]

    def selectors_text(self, sel):
        out = []
        for part in [p for p in (sel or "").split(";") if p]:
            m = re.match(r"(\w+)\((.*)\)", part.strip())
            if not m:
                out.append(part)
                continue
            fn, args = m.group(1), [x.strip() for x in m.group(2).split(",")]
            if fn in ("SelectSpells", "AddSpells"):
                names = self.list_names(args[0], True)
                n = args[1] if fn == "SelectSpells" and len(args) > 1 else "all"
                out.append("%s %s: %s" % (fn, n, ", ".join(names)))
            elif fn in ("SelectPassives", "ReplacePassives"):
                out.append("%s %s: %s" % (fn, args[1] if len(args) > 1 else "?", ", ".join(self.list_names(args[0], False))))
            else:
                out.append(part)
        return out


def load():
    return GameData()


def main(argv):
    gd = load()
    names = argv[1:] or sorted(gd.class_by_name)
    for nm in names:
        print("=" * 20, nm, "=", gd.text(gd.class_by_name.get(nm, {}).get("DisplayName")))
        for lv, a in gd.class_levels(nm):
            mc = " (multiclass)" if (a.get("IsMulticlass") or "").lower() == "true" else ""
            pas = [gd.stat_name(p) or p for p in (a.get("PassivesAdded") or "").split(";") if p]
            sel = gd.selectors_text(a.get("Selectors"))
            feat = " FEAT" if (a.get("AllowImprovement") or "").lower() == "true" else ""
            print("  L%-2d %s%s%s  passives=%s" % (lv, a.get("Name"), mc, feat, pas))
            for s in sel:
                print("        ", s[:400])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

"""Checks every Build Advisor highlight label against the game's own data (developer tool, never shipped).

  python tools/check_hl.py            report + exit 1 on any unknown label or plan error
  python tools/check_hl.py -v         also list every level's choices and what the plan stars

1. LABELS (hard): every string the mod stars - each level's `hl`, the swap spells, `bg`, `deity`, the first race,
   the start class, every level's class and the creation skills - must be an exact English UI label of the game
   (class / subclass / race / background / deity / feat / spell / passive / skill names from ClassDescriptions,
   Races, Backgrounds, Gods, FeatDescriptions, the spell and passive lists and the stats DisplayNames, resolved
   through loca_english.json). "Agonizing Blast" fails, "Agonising Blast" passes.
2. PLAN (hard): each label must be something the game offers at that character level for that class level
   (class, subclass grid, spell / passive selectors of the class and subclass, the prepare pool of prepared casters,
   feats on feat levels and the chosen feat's own sub-choices, skills); no pick may repeat an earlier pick or a spell
   the plan already gets for free (always-prepared oath / domain spells); a selector may not get more picks than it
   allows; a feat with an ability choice needs the level's `asi`; ASI totals must match (+2, or +1 for half feats);
   no ability above 20.
3. COVERAGE (warning, listed): a spell or passive selector that gets fewer stars than the number of picks it asks
   for - the plan is incomplete there.
"""
import os
import re
import sys

import lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import gamedata_ui  # noqa: E402

BUILDS = os.path.join(ROOT, "Mods", "BuildAdvisor", "ScriptExtender", "Lua", "Shared", "Builds.lua")
AB = {"STR": "Strength", "DEX": "Dexterity", "CON": "Constitution", "INT": "Intelligence", "WIS": "Wisdom",
      "CHA": "Charisma"}
PREPARERS = {"Cleric", "Druid", "Paladin"}


def lua_to_py(v):
    if lupa.lua_type(v) == "table":
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [lua_to_py(v[k]) for k in sorted(keys)]
        return {k: lua_to_py(v[k]) for k in keys}
    return v


def load_builds():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    with open(BUILDS, encoding="utf-8") as f:
        lua.execute(f.read())
    ba = lua.globals().BA
    return lua_to_py(ba.Builds), lua_to_py(ba.Origins)


def parse_selectors(sel):
    out = []
    for part in [p.strip() for p in (sel or "").split(";") if p.strip()]:
        m = re.match(r"(\w+)\((.*)\)", part)
        if m:
            out.append((m.group(1), [x.strip() for x in m.group(2).split(",")]))
    return out


class Checker:
    def __init__(self, gd):
        self.gd = gd
        self.cls_uuid = {a.get("UUID"): a for a in gd.raw["class"].values()}
        self.sub_by_label = {}  # subclass display / short name -> class attrs
        for a in gd.raw["class"].values():
            if a.get("ParentGuid"):
                for h in (a.get("DisplayName"), a.get("ShortName")):
                    t = gd.text(h)
                    if t:
                        self.sub_by_label[t] = a
        self.feat_by_label = {}
        for d in gd.raw["featdesc"].values():
            f = gd.raw["feat"].get(d.get("FeatId"))
            if f:
                self.feat_by_label[gd.text(d.get("DisplayName"))] = f
        self.skill_lists = {u: [x for x in re.split(r"[,;]", a.get("Skills") or "") if x]
                            for u, a in gd.raw["skilllist"].items()}

    def skills_of(self, uid):
        return [re.sub(r"(?<=[a-z])(?=[A-Z])", " ", s.strip()).replace("Sleight Of Hand", "Sleight of Hand")
                for s in self.skill_lists.get(uid, [])]

    def rows(self, class_name, level, multiclass):
        rows = [a for lv, a in self.gd.class_levels(class_name) if lv == level]
        if level == 1 and not self.cls_by_name(class_name).get("ParentGuid"):
            want = "true" if multiclass else None
            pick = [a for a in rows if (a.get("IsMulticlass") or "").lower() == (want or "")]
            rows = pick or rows
        if rows:  # the same level defined in two modules: the later module wins
            top = max(a.get("_rank", 0) for a in rows)
            rows = [a for a in rows if a.get("_rank", 0) == top]
        return rows

    def race_offer(self, label):
        """selectors of a race (and its parent race) at level 1: [(kind, names, count)]"""
        gd = self.gd
        races = [a for a in gd.raw["race"].values() if gd.text(a.get("DisplayName")) == label]
        out = []
        seen = set()
        for r in races:
            chain = [r]
            parent = gd.raw["race"].get(r.get("ParentGuid"))
            if parent:
                chain.append(parent)
            for a in chain:
                t = a.get("ProgressionTableUUID")
                for row in gd.raw["progression"].values():
                    if row.get("TableUUID") != t or row.get("Level") != "1" or row.get("UUID") in seen:
                        continue
                    seen.add(row.get("UUID"))
                    for fn, args in parse_selectors(row.get("Selectors")):
                        if fn == "SelectSpells":
                            out.append(("race spell", gd.list_names(args[0], True), int(args[1] or 0)))
                        elif fn == "SelectSkills":
                            out.append(("race skill", self.skills_of(args[0]), int(args[1] or 0)))
                        elif fn == "SelectPassives":
                            out.append(("race passive", gd.list_names(args[0], False), int(args[1] or 0)))
        return out

    def cls_by_name(self, n):
        return self.gd.class_by_name.get(n, {})

    def level_offer(self, cls, k, multiclass, sub_attrs, chosen_feat):
        """what the game offers at class level k: list of (kind, labels, count) + prepare pool + granted + feats"""
        gd = self.gd
        offer = {"selectors": [], "subclasses": [], "feat": False, "granted": set(), "prepare": set(),
                 "abilities": None}
        rows = self.rows(cls, k, multiclass)
        if sub_attrs:
            rows = rows + self.rows(sub_attrs.get("Name"), k, False)
        for a in rows:
            if (a.get("AllowImprovement") or "").lower() == "true":
                offer["feat"] = True
            for su in a.get("_subclasses") or []:
                c = self.cls_uuid.get(su)
                if c:
                    offer["subclasses"] += [t for t in (gd.text(c.get("DisplayName")), gd.text(c.get("ShortName"))) if t]
            for fn, args in parse_selectors(a.get("Selectors")):
                if fn == "SelectSpells":
                    offer["selectors"].append(("spell", gd.list_names(args[0], True), int(args[1] or 0)))
                elif fn in ("SelectPassives",):
                    offer["selectors"].append(("passive", gd.list_names(args[0], False), int(args[1] or 0)))
                elif fn in ("SelectSkills",):
                    offer["selectors"].append(("skill", self.skills_of(args[0]), int(args[1] or 0)))
                elif fn == "SelectSkillsExpertise":
                    offer["selectors"].append(("expertise", self.skills_of(args[0]), int(args[1] or 0)))
                elif fn == "AddSpells":
                    names = gd.list_names(args[0], True)
                    if "AlwaysPrepared" in args or cls not in PREPARERS:
                        offer["granted"].update(names)
                    else:
                        offer["prepare"].update(names)
        if offer["feat"] and chosen_feat:
            f = self.feat_by_label[chosen_feat]
            for fn, args in parse_selectors(f.get("Selectors")):
                if fn == "SelectSpells":
                    offer["selectors"].append(("feat spell", gd.list_names(args[0], True), int(args[1] or 0)))
                elif fn == "SelectPassives":
                    offer["selectors"].append(("feat passive", gd.list_names(args[0], False), int(args[1] or 0)))
                elif fn == "SelectSkills":
                    offer["selectors"].append(("feat skill", self.skills_of(args[0]), int(args[1] or 0)))
                elif fn == "SelectAbilities":
                    offer["abilities"] = int(args[1] or 0) if args[1] != "" else 1
        return offer


def main(argv):
    verbose = "-v" in argv
    gd = gamedata_ui.load()
    ck = Checker(gd)
    builds, origins = load_builds()
    labels = gd.labels
    unknown, errors, warnings = [], [], []
    total = 0

    def need(label, where):
        nonlocal total
        total += 1
        if label not in labels:
            close = [x for x in labels if x.lower().replace("z", "s") == label.lower().replace("z", "s")]
            unknown.append("%s: %r%s" % (where, label, ("  (game: %r)" % close[0]) if close else ""))

    for b in builds:
        bid = b["id"]
        need(b["races"][0], bid + " race")
        need(b["start"], bid + " start")
        for s in b.get("skills") or []:
            need(s, bid + " skills")
        if b.get("bg"):
            need(b["bg"], bid + " background")
        else:
            errors.append("%s: no `bg` (background label)" % bid)
        if b.get("deity"):
            need(b["deity"], bid + " deity")
        if b["start"] == "Cleric" and not b.get("deity"):
            errors.append("%s: starts as Cleric but has no `deity`" % bid)
        for s in b.get("raceHl") or []:
            need(s, bid + " race choice")
        rsel = ck.race_offer(b["races"][0])
        for kind, names, n in rsel:
            got = [s for s in (b.get("raceHl") or []) if s in names]
            if len(got) < n:
                warnings.append("%s: %s (%s) x%d, %d starred" % (bid, kind, b["races"][0], n, len(got)))
        for s in b.get("raceHl") or []:
            if not any(s in names for kind, names, n in rsel):
                errors.append("%s: race choice %r is not offered by %s" % (bid, s, b["races"][0]))
        for i, lv in enumerate(b["levels"], 1):
            need(lv["cls"], "%s L%d class" % (bid, i))
            for s in lv.get("hl") or []:
                need(s, "%s L%d" % (bid, i))
            sw = lv.get("swap")
            if sw:
                need(sw.get("out"), "%s L%d swap out" % (bid, i))
                need(sw.get("into"), "%s L%d swap in" % (bid, i))

        # ---------------------------------------------------------- plan audit
        subs = {}
        for lv in b["levels"]:
            for s in lv.get("hl") or []:
                a = ck.sub_by_label.get(s)
                if a:
                    parent = ck.cls_uuid.get(a.get("ParentGuid"), {}).get("Name")
                    if parent == lv["cls"]:
                        subs.setdefault(parent, a)
        counts, known, granted, prepared = {}, set(), set(), set()
        score = {k: (b["base"][k] + (2 if b["plus2"] == k else 1 if b["plus1"] == k else 0)) for k in AB}
        for i, lv in enumerate(b["levels"], 1):
            cls = lv["cls"]
            counts[cls] = counts.get(cls, 0) + 1
            k = counts[cls]
            hl = list(lv.get("hl") or [])
            feats = [s for s in hl if s in ck.feat_by_label]
            sub = subs.get(cls)
            off = ck.level_offer(cls, k, i > 1 and k == 1, sub, feats[0] if feats else None)
            where = "%s L%d (%s %d)" % (bid, i, cls, k)
            if verbose:
                print(where, "| hl:", hl)
                for kind, names, n in off["selectors"]:
                    print("    %s x%d: %s" % (kind, n, ", ".join(names)[:300]))
            granted |= off["granted"]
            prep_pool = set()
            if cls in PREPARERS:
                for kk in range(1, k + 1):
                    prep_pool |= ck.level_offer(cls, kk, i > 1 and kk == 1 and k == 1, None, None)["prepare"]
            if len(feats) > 1:
                errors.append("%s: two feats %s" % (where, feats))
            if feats and not off["feat"]:
                errors.append("%s: feat %s but this is not a feat level" % (where, feats))
            if off["feat"] and not feats:
                errors.append("%s: feat level without a feat in hl" % where)
            # ability raises
            asi = lv.get("asi") or {}
            if off["abilities"] is not None:
                want = 2 if feats and feats[0] == "Ability Improvement" else 1
                if sum(asi.values()) != want:
                    errors.append("%s: %s needs `asi` totalling +%d (has %s)" % (where, feats[0], want, asi or "none"))
            elif asi:
                errors.append("%s: `asi` %s but no ability choice at this level" % (where, asi))
            for ab, n in asi.items():
                score[ab] += n
                if score[ab] > 20:
                    errors.append("%s: %s would reach %d (max 20)" % (where, ab, score[ab]))
            # every label must be offered somewhere at this level
            used = {}
            for s in hl:
                if s == cls or s in feats:
                    continue
                if sub and s in (ck.gd.text(sub.get("DisplayName")), ck.gd.text(sub.get("ShortName")))                         and (s in off["subclasses"] or k == 1):
                    continue
                hits = [j for j, (kind, names, n) in enumerate(off["selectors"]) if s in names]
                if hits:
                    kind = off["selectors"][hits[0]][0]
                    if kind in ("spell", "passive", "feat spell", "feat passive") and s in known:
                        errors.append("%s: %r was already picked earlier" % (where, s))
                    if kind in ("spell", "feat spell") and s in granted - off["granted"]:
                        errors.append("%s: %r is already granted for free (always prepared)" % (where, s))
                    for j in hits:
                        used[j] = used.get(j, 0) + 1
                    if kind not in ("skill", "expertise", "feat skill"):
                        known.add(s)
                    continue
                if s in prep_pool:
                    if s in granted:
                        errors.append("%s: %r prepared but it is always prepared already" % (where, s))
                    elif s in prepared:
                        errors.append("%s: %r was already prepared earlier" % (where, s))
                    prepared.add(s)
                    continue
                errors.append("%s: %r is not offered at this level" % (where, s))
            sw = lv.get("swap")
            if sw:
                pool = set()
                for kk in range(1, k + 1):
                    for kind, names, n in ck.level_offer(cls, kk, False, sub, None)["selectors"]:
                        if kind == "spell":
                            pool.update(names)
                if sw.get("into") not in pool:
                    errors.append("%s: swap into %r is not a %s spell" % (where, sw.get("into"), cls))
                if sw.get("into") in known:
                    errors.append("%s: swap into %r is already known" % (where, sw.get("into")))
                if sw.get("out") not in known:
                    errors.append("%s: swap out %r was never picked" % (where, sw.get("out")))
                known.discard(sw.get("out"))
                known.add(sw.get("into"))
            for j, (kind, names, n) in enumerate(off["selectors"]):
                got = used.get(j, 0)
                if kind in ("skill", "expertise", "feat skill"):
                    if got < n and i > 1:
                        warnings.append("%s: %s x%d, %d starred" % (where, kind, n, got))
                    continue
                if got > n and n > 0:
                    # the same name can sit in two overlapping lists (e.g. Warlock invocations); count once
                    if sum(1 for x in hl if x in names) > n:
                        errors.append("%s: %d picks for a %s selector of %d" % (where, got, kind, n))
                elif got < n:
                    warnings.append("%s: %s selector x%d, only %d starred (%s...)" % (where, kind, n, got,
                                                                                   ", ".join(names[:6])))
    for o, info in origins.items():
        for bid in info["builds"]:
            if bid not in {b["id"] for b in builds}:
                errors.append("origin %s -> unknown build %s" % (o, bid))

    print("Build Advisor highlight check: %d builds, %d labels checked against %d game labels" %
          (len(builds), total, len(labels)))
    print("\nUNKNOWN LABELS: %d" % len(unknown))
    for u in unknown:
        print("  " + u)
    print("\nPLAN ERRORS: %d" % len(errors))
    for e in errors:
        print("  " + e)
    print("\nCOVERAGE WARNINGS: %d" % len(warnings))
    for w in warnings:
        print("  " + w)
    return 1 if unknown or errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

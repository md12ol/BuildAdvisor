/* Shared data and builders for option1/2/3.html.  URL: optionN.html?mod=ba|la&fmt=banner|thumb|docs|mark|marksm|wordmark|sets */
(function () {
  const q = new URLSearchParams(location.search);
  const MOD = q.get("mod") || "la";
  const FMT = q.get("fmt") || "banner";

  const MODS = {
    ba: {
      name: "Build Advisor", mono: "BA", hotkey: "F7",
      eyebrow: "Baldur's Gate 3 · Script Extender mod",
      tag: "The strongest build, starred in every menu.",
      short: "Every level-up, already planned.",
      feats: ["Stars on the right picks in the game's own menus", "A level 1–12 plan for 16 top Patch 8 builds", "Character creation, Withers' respec, every level-up"],
      ring: ["Creation", "Respec", "Level up", "Party"],
    },
    la: {
      name: "Loot Advisor", mono: "LA", hotkey: "F6",
      eyebrow: "Baldur's Gate 3 · Script Extender mod",
      tag: "The right gear for your build, and where to find it.",
      short: "Best-in-slot, marked on your map.",
      feats: ["Rainbow frames on the items that suit your build", "Rainbow map markers that lead you to them", "An F6 item list and a live Sets page"],
      ring: ["Frames", "Markers", "Item list", "Sets page"],
    },
  };

  let uid = 0;
  function emblem(mod, size, small) {
    const id = "g" + (++uid);
    const cls = "emb" + (small ? " small" : "");
    if (mod === "la") {
      return `<div class="${cls}" style="--s:${size}px"><div class="gem"><div class="rim"></div><div class="rim2"></div><div class="core"></div><div class="facet"></div><div class="table"></div></div></div>`;
    }
    if (mod === "ba") {
      const sw = small ? 11 : 7.5;
      return `<div class="${cls}" style="--s:${size}px"><svg viewBox="0 0 100 100">
        <defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff3cf"/><stop offset=".45" stop-color="#e8b85a"/><stop offset="1" stop-color="#8a5f1c"/></linearGradient></defs>
        <path d="M50 3 Q56 34 86 39 Q56 44 50 75 Q44 44 14 39 Q44 34 50 3Z" fill="url(#${id})" stroke="rgba(30,18,4,.85)" stroke-width="1.6" stroke-linejoin="round"/>
        <path d="M50 14 Q53 34 72 39 Q53 41 50 39Z" fill="rgba(255,255,255,.45)"/>
        <path d="M27 96 L50 80 L73 96" fill="none" stroke="rgba(30,18,4,.85)" stroke-width="${sw + 3}" stroke-linecap="round" stroke-linejoin="round"/>
        <path d="M27 96 L50 80 L73 96" fill="none" stroke="url(#${id})" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>
      </svg></div>`;
    }
    return "";
  }

  /* ---- Build Advisor window: Astarion levelling to 9 on the "thx" build (Shared/Builds.lua, Client/Window.lua) ---- */
  const THX = [
    ["Ranger", "Favoured Enemy: Bounty Hunter or Mage Breaker; Natural Explorer: any; Skills: Stealth, Perception"],
    ["Ranger", "Fighting Style: Archery; Spells: Hunter's Mark, Ensnaring Strike"],
    ["Ranger", "Gloom Stalker"],
    ["Ranger", "Feat: Sharpshooter"],
    ["Ranger", "Extra Attack; Spell: Pass Without Trace"],
    ["Fighter", "Fighting Style: Two-Weapon Fighting"],
    ["Fighter", "Action Surge"],
    ["Fighter", "Battle Master; Manoeuvres: Precision Attack, Menacing Attack, Trip Attack"],
    ["Rogue", "Expertise: Stealth, Perception"],
    ["Rogue", "Cunning Action"],
    ["Rogue", "Thief (Fast Hands = extra bonus action)"],
    ["Rogue", "Feat: Ability Improvement +2 DEX (or Alert)"],
  ];
  function baWindow(o) {
    o = o || {};
    const cur = 9;
    const rows = THX.map((r, i) => {
      const lv = i + 1;
      if (o.planFrom && lv < o.planFrom) return "";
      const cls = lv === cur ? "cur" : lv < cur ? "past" : "";
      return `<tr class="${cls}"><td>${lv}</td><td>${r[0]}</td><td>${r[1]}</td></tr>`;
    }).join("");
    return `<div class="imgui" style="--fs:${o.fs || 19}px;--w:${o.w || 760}px">
      <div class="tb">Build Advisor<span class="x">✕</span></div>
      <div class="bd">
        ${o.compact ? "" : `<div class="grey">Hotkey: F7 toggles this window. Recommended options are marked with a star (*) in the game menus.</div>`}
        <div class="combo"><div class="box">[Recommended] Gloom Stalker 5 / Battle Master 3 / Thief 4 (dual hand crossbows)  (S+)</div><span>Build</span></div>
        <div class="cbs"><span class="cb"><i></i>Show all builds</span><span class="cb"><i>✔</i>Highlight in game menus</span><span class="cb"><i>✔</i>Auto-open</span></div>
        <div class="sep"></div>
        <div class="gold">Mode: Level Up -&gt; character level 9</div>
        <div>Astarion - High Elf - Ranger [Gloom Stalker] 5 / Fighter [Battle Master] 3</div>
        <div class="sept">Gloom Stalker 5 / Battle Master 3 / Thief 4</div>
        <div class="gold">Tier S+ - Ranged: 4 hand-crossbow shots every turn, best sustained damage</div>
        ${o.compact || o.noWhy ? "" : `<div>Thief's Fast Hands = a second bonus action; each bonus action fires the off-hand hand crossbow.</div>`}
        <div class="sept">DO THIS NOW</div>
        <div class="green">Level 9: take a level in Rogue</div>
        <ul class="green"><li>Expertise: Stealth, Perception</li></ul>
        <div class="sept">Your current choices</div>
        <ul class="green"><li>[OK] Race: High Elf (locked for this origin)</li><li>[OK] Class this level: Rogue</li>${o.compact ? "" : `<li>[OK] DEX 18 (plan &gt;= 17)</li>`}</ul>
        <div class="hdr">Full level 1-12 plan</div>
        <table>${rows}</table>
      </div></div>`;
  }
  function baMenu(o) {
    o = o || {};
    const items = o.items || [["Barbarian"], ["Fighter"], ["Ranger"], ["Rogue", 1], ["Warlock"], ["Wizard"]];
    return `<div class="menu" style="--fs:${o.fs || 22}px;--w:${o.w || 300}px">${o.label ? `<div class="lab">${o.label}</div>` : ""}${items.map(i =>
      `<div class="it${i[1] ? " on" : ""}">${i[1] ? '<span class="star">★</span>' : ""}${i[0]}</div>`).join("")}</div>`;
  }

  const FONTS = ['400 20px "Alegreya"', 'italic 400 20px "Alegreya"', '700 20px "Alegreya SC"', '500 20px "Alegreya SC"',
    '700 20px "Alegreya Sans SC"', '600 20px "Cinzel"', '700 20px "Cinzel"', '600 20px "Cormorant Garamond"', '700 20px "Cormorant Garamond"',
    'italic 500 20px "Cormorant Garamond"', '400 20px "IBM Plex Mono"', '600 20px "IBM Plex Mono"'];
  /* clipped Build Advisor windows (.clip > div > .imgui): start the visible part at line data-from[data-idx], keep the title bar */
  function clips() {
    document.querySelectorAll(".clip").forEach(c => {
      const inner = c.firstElementChild, tb = inner.querySelector(".tb"), from = inner.querySelectorAll(c.dataset.from)[+(c.dataset.idx || 0)];
      if (!from || !tb) return;
      const cut = from.getBoundingClientRect().top - tb.getBoundingClientRect().bottom - 6;
      inner.querySelector(".bd").style.marginTop = -cut + "px";
    });
  }
  async function ready(after) {
    document.body.getBoundingClientRect();
    try { await Promise.race([Promise.all(FONTS.map(f => document.fonts.load(f))), new Promise(r => setTimeout(r, 12000))]); } catch (e) { }
    try { await document.fonts.ready; } catch (e) { }
    clips();
    if (after) after();
    await Promise.all([...document.images].map(i => i.complete ? 0 : new Promise(r => { i.onload = i.onerror = r; })));
    try { await document.fonts.ready; } catch (e) { }
    await new Promise(r => setTimeout(r, 150));
    window.__ready = true;
  }

  window.BR = { MOD, FMT, M: MODS[MOD], MODS, emblem, baWindow, baMenu, ready, THX };
})();

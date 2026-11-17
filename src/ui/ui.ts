import { GU, KILLER_MOVES, PATH_COLORS, PATH_NAMES, type GuDef } from '../data/gu';
import { ITEMS, RECIPES, SHOPS } from '../data/items';
import { MAP_H, MAP_W, POIS, TILE } from '../world/world';
import type { NPC } from '../world/world';
import {
  ESSENCE_COLORS, ESSENCE_NAMES, isStarving, occupancy, RANK_NAMES, shapeCells, STAGE_NAMES, canPlace,
} from '../game/aperture';
import { Game, gradeOf } from '../game/game';

type PanelKind = 'aperture' | 'bag' | 'craft' | 'shop' | 'elder' | 'caravan' | 'map' | 'help';

const $ = <T extends HTMLElement = HTMLElement>(sel: string, root: ParentNode = document) => root.querySelector(sel) as T;
const esc = (s: string) => s.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

export class UI {
  root = $('#ui');
  panel: PanelKind | null = null;
  panelData: { shop?: string; npc?: NPC } = {};
  sel: number | null = null; // selected Gu uid in aperture editor
  rot = 0;
  hover: { x: number; y: number } | null = null;
  shopTab: 'gu' | 'items' | 'sell' = 'gu';
  private miniT = 0;
  private fogCanvas = document.createElement('canvas');
  private baseCanvas = document.createElement('canvas');

  constructor(public game: Game) {
    game.onToast = (m, k) => this.toast(m, k);
    game.onChange = () => { if (this.panel) this.renderPanel(); };
    game.onNpc = npc => this.openNpc(npc);
    this.buildHud();
    this.root.addEventListener('click', e => this.onClick(e));
    this.root.addEventListener('pointerover', e => this.onHover(e));
    window.addEventListener('keydown', e => {
      if (!this.game.world || $('#title')) return;
      const k = e.key.toLowerCase();
      if (k === 'tab' || k === 'i') { e.preventDefault(); this.toggle('aperture'); }
      else if (k === 'b') this.toggle('bag');
      else if (k === 'c') this.toggle('craft');
      else if (k === 'm') this.toggle('map');
      else if (k === 'q') this.game.absorbStone();
      else if (k === 'r' && this.panel === 'aperture') { this.rot = (this.rot + 1) % 4; this.renderPanel(); }
      else if (k === 'escape') this.close();
    });
  }

  // ------------------------------------------------------------------ title
  showTitle() {
    this.game.paused = true;
    const has = this.game.hasSave();
    const el = document.createElement('div');
    el.id = 'title';
    el.innerHTML = `
      <div class="title-card">
        <div class="title-cn">蛊 · 南疆</div>
        <h1>Gu Wilds</h1>
        <div class="subtitle">A Gu Master survival tale of the Southern Border</div>
        ${has ? `<button class="btn big" data-act="continue">Continue Journey</button>` : ''}
        <input id="pname" maxlength="16" placeholder="Your name" value="Shi Mo" />
        <button class="btn big gold" data-act="newgame">${has ? 'New Journey (overwrites)' : 'Begin Journey'}</button>
        <div class="hint">Move: WASD / drag on the left of the screen · Gu attack automatically<br/>
        E/Space: interact · Tab: Aperture · B: Bag · C: Craft · M: Map · Q: absorb primeval stone</div>
      </div>`;
    document.body.appendChild(el);
    el.addEventListener('click', e => {
      const act = (e.target as HTMLElement).closest('[data-act]')?.getAttribute('data-act');
      if (act === 'continue') {
        if (this.game.load()) { el.remove(); this.start(); this.toast(`Welcome back, ${this.game.p.name}.`, 'gold'); }
        else this.toast('Save could not be loaded.', 'bad');
      } else if (act === 'newgame') {
        const name = ($('#pname') as HTMLInputElement).value.trim() || 'Shi Mo';
        const res = this.game.newGame(name);
        el.remove();
        this.start();
        this.ceremony(res.grade, res.aptitude);
      }
    });
  }

  private ceremony(grade: string, apt: number) {
    const g = this.game;
    const starter = g.p.gu.map(x => GU[x.defId].name).join(' and ');
    this.modal(`
      <h2>Aperture Awakening Ceremony</h2>
      <p>On the clan's sacred day, the elders release a <b>Hope Gu</b> into your body. Light pours into your belly — your aperture opens.</p>
      <div class="grade grade-${grade}">Grade ${grade} aptitude<br/><small>${Math.round(apt * 100)}% primeval sea</small></div>
      <p>The clan grants you <b>${starter}</b> and 30 primeval stones. Gu must be fed or they will starve and die.</p>
      <p class="muted">Survive. Hunt. Refine Gu. Advance your cultivation. Somewhere in the northwest lies an unclaimed inheritance…</p>
      <button class="btn gold" data-act="close-modal">Step out into the world</button>`);
  }

  start() {
    this.game.paused = false;
    this.baseCanvas.width = MAP_W; this.baseCanvas.height = MAP_H;
    this.fogCanvas.width = MAP_W; this.fogCanvas.height = MAP_H;
    this.baseCanvas.getContext('2d')!.putImageData(this.game.world.minimapBase!, 0, 0);
    this.refreshFog();
    $('#hud').style.display = '';
  }

  // ------------------------------------------------------------------ HUD
  private buildHud() {
    const hud = document.createElement('div');
    hud.id = 'hud';
    hud.style.display = 'none';
    hud.innerHTML = `
      <div class="bars">
        <div class="cult" id="cult"></div>
        <div class="bar hp"><div class="fill"></div><div class="shield"></div><span></span></div>
        <div class="bar ess"><div class="fill"></div><span></span></div>
        <div class="bar hun"><div class="fill"></div><span></span></div>
      </div>
      <div class="topc"><div id="clock"></div><div id="zone"></div></div>
      <div class="topr">
        <canvas id="mini" width="120" height="120" data-act="open-map"></canvas>
        <div id="stones" data-act="absorb" title="Absorb a primeval stone (Q)"></div>
      </div>
      <div id="toasts"></div>
      <div class="dock">
        <button class="btn round" data-act="open-aperture" title="Aperture (Tab)">窍<small>Aperture</small></button>
        <button class="btn round" data-act="open-bag" title="Bag (B)">囊<small>Bag</small></button>
        <button class="btn round" data-act="open-craft" title="Craft & Refine (C)">炼<small>Refine</small></button>
        <button class="btn round" data-act="open-help" title="Guide">?<small>Guide</small></button>
      </div>
      <div class="actions">
        <button class="btn round absorb" data-act="absorb">元<small>Absorb</small></button>
        <button class="btn round action" id="actbtn" data-act="action">·</button>
      </div>
      <div id="panel" class="panel hidden"></div>
      <div id="modal" class="modal hidden"></div>`;
    this.root.appendChild(hud);
    const actbtn = $('#actbtn');
    actbtn.addEventListener('pointerdown', e => { e.stopPropagation(); this.game.input.actionPressed = true; });
  }

  updateHud(dt: number) {
    const g = this.game;
    if (!g.world || !g.p) return;
    const p = g.p;
    const pct = (v: number, m: number) => `${Math.max(0, Math.min(100, (v / m) * 100))}%`;
    const set = (sel: string, w: string, txt: string) => {
      const b = $(sel);
      (b.querySelector('.fill') as HTMLElement).style.width = w;
      (b.querySelector('span') as HTMLElement).textContent = txt;
    };
    set('.bar.hp', pct(p.hp, g.maxHp), `HP ${Math.ceil(p.hp)}/${Math.round(g.maxHp)}`);
    ($('.bar.hp .shield') as HTMLElement).style.width = g.build.stats.shield ? pct(g.shield, g.maxHp) : '0%';
    set('.bar.ess', pct(p.essence, g.maxEssence), `Essence ${Math.floor(p.essence)}/${Math.round(g.maxEssence)}`);
    ($('.bar.ess .fill') as HTMLElement).style.background = ESSENCE_COLORS[p.rank];
    set('.bar.hun', pct(p.hunger, 100), `Hunger ${Math.ceil(p.hunger)}`);
    $('#cult').innerHTML = `<b>${esc(p.name)}</b> · ${RANK_NAMES[p.rank]} ${STAGE_NAMES[p.stage]} <span class="muted">(${gradeOf(p.aptitude)})</span>`;
    const tod = g.tod;
    const phase = tod < 0.04 ? 'Dawn' : tod < 0.58 ? 'Day' : tod < 0.68 ? 'Dusk' : 'Night';
    const hours = Math.floor(((tod * 24) + 6) % 24);
    $('#clock').innerHTML = `${phase === 'Night' ? '☾' : '☀'} Day ${g.day + 1} · ${String(hours).padStart(2, '0')}:00 ${phase}`;
    const z = g.zone;
    const poi = POIS.find(pp => pp.zone === z);
    $('#zone').textContent = poi ? poi.name : z === 'deep' ? 'Deep Wilderness — dangerous' : z === 'wall' ? 'Regional Wall' : 'Southern Border Wilds';
    $('#zone').className = z === 'forbidden' ? 'danger' : z === 'village' || z === 'city' ? 'safe' : '';
    $('#stones').innerHTML = `◆ ${p.stones} <small>primeval stones</small>`;
    const ab = $('#actbtn');
    const label = g.interact?.label ?? '·';
    if (ab.textContent !== label) ab.textContent = label;
    ab.classList.toggle('live', !!g.interact);
    this.miniT -= dt;
    if (this.miniT <= 0) { this.miniT = 0.5; this.refreshFog(); this.drawMinimap(); }
  }

  private refreshFog() {
    const g = this.game;
    if (!g.world?.minimapBase) return;
    const base = g.world.minimapBase.data;
    const img = new ImageData(MAP_W, MAP_H);
    const ex = g.world.explored;
    for (let i = 0; i < ex.length; i++) {
      if (ex[i]) { img.data[i * 4] = base[i * 4]; img.data[i * 4 + 1] = base[i * 4 + 1]; img.data[i * 4 + 2] = base[i * 4 + 2]; img.data[i * 4 + 3] = 255; }
      else { img.data[i * 4] = 14; img.data[i * 4 + 1] = 14; img.data[i * 4 + 2] = 22; img.data[i * 4 + 3] = 255; }
    }
    this.fogCanvas.getContext('2d')!.putImageData(img, 0, 0);
  }

  private drawMinimap() {
    const c = $('#mini') as HTMLCanvasElement;
    const m = c.getContext('2d')!;
    const p = this.game.p;
    const span = 70; // tiles shown
    const tx = p.x / TILE, ty = p.y / TILE;
    m.imageSmoothingEnabled = false;
    m.fillStyle = '#0e0e16'; m.fillRect(0, 0, 120, 120);
    m.drawImage(this.fogCanvas, tx - span / 2, ty - span / 2, span, span, 0, 0, 120, 120);
    const s = 120 / span;
    for (const poi of POIS) {
      if (!this.game.world.explored[poi.ty * MAP_W + poi.tx]) continue;
      const x = (poi.tx - tx + span / 2) * s, y = (poi.ty - ty + span / 2) * s;
      m.fillStyle = poi.zone === 'forbidden' ? '#ff4d6d' : poi.zone === 'ruins' ? '#ffd76b' : '#fff';
      m.fillRect(x - 2, y - 2, 4, 4);
    }
    m.fillStyle = '#ff0'; m.fillRect(58, 58, 4, 4);
  }

  // ------------------------------------------------------------------ toasts / modal
  toast(msg: string, kind: 'info' | 'good' | 'bad' | 'gold' = 'info') {
    const box = $('#toasts');
    if (!box) return;
    const t = document.createElement('div');
    t.className = 'toast ' + kind;
    t.textContent = msg;
    box.appendChild(t);
    while (box.children.length > 5) box.firstChild?.remove();
    setTimeout(() => t.classList.add('out'), 3600);
    setTimeout(() => t.remove(), 4200);
  }

  modal(html: string) {
    const m = $('#modal');
    m.innerHTML = `<div class="modal-card">${html}</div>`;
    m.classList.remove('hidden');
    this.game.paused = true;
  }

  // ------------------------------------------------------------------ panels
  toggle(kind: PanelKind) { if (this.panel === kind) this.close(); else this.open(kind); }

  open(kind: PanelKind, data: UI['panelData'] = {}) {
    this.panel = kind; this.panelData = data;
    if (kind !== 'aperture') this.sel = null;
    this.game.paused = true;
    $('#panel').classList.remove('hidden');
    this.renderPanel();
  }

  close() {
    this.panel = null; this.sel = null;
    $('#panel').classList.add('hidden');
    if ($('#modal').classList.contains('hidden')) this.game.paused = false;
    this.game.save();
  }

  openNpc(npc: NPC) {
    if (npc.role === 'merchant') { this.shopTab = 'gu'; this.open('shop', { shop: npc.shop, npc }); }
    else if (npc.role === 'elder') this.open('elder', { npc });
    else this.open('caravan', { npc });
  }

  renderPanel() {
    const el = $('#panel');
    const titles: Record<PanelKind, string> = {
      aperture: 'Aperture 空窍', bag: 'Bag 行囊', craft: 'Craft & Gu Refinement 炼蛊', shop: 'Trade 交易',
      elder: 'Cultivation 修行', caravan: 'Caravan 商队', map: 'Southern Border 南疆', help: 'Gu Master Guide',
    };
    let body = '';
    switch (this.panel) {
      case 'aperture': body = this.apertureHtml(); break;
      case 'bag': body = this.bagHtml(); break;
      case 'craft': body = this.craftHtml(); break;
      case 'shop': body = this.shopHtml(); break;
      case 'elder': body = this.elderHtml(); break;
      case 'caravan': body = this.caravanHtml(); break;
      case 'map': body = '<canvas id="bigmap" width="440" height="440"></canvas><div class="muted">Unexplored land stays dark. Regional Walls (violet) seal the Southern Border from the other regions.</div>'; break;
      case 'help': body = this.helpHtml(); break;
      default: return;
    }
    const scroll = el.querySelector('.panel-body')?.scrollTop ?? 0;
    el.innerHTML = `<div class="panel-head"><h2>${titles[this.panel]}</h2><button class="btn x" data-act="close">✕</button></div><div class="panel-body">${body}</div>`;
    const pb = el.querySelector('.panel-body');
    if (pb) pb.scrollTop = scroll;
    if (this.panel === 'map') this.drawBigMap();
  }

  private guMini(def: GuDef, rot = 0) {
    const cells = shapeCells(def, rot);
    const w = Math.max(...cells.map(c => c[0])) + 1, h = Math.max(...cells.map(c => c[1])) + 1;
    let s = `<span class="mini-shape" style="grid-template-columns:repeat(${w},8px);grid-template-rows:repeat(${h},8px)">`;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const on = cells.some(c => c[0] === x && c[1] === y);
      s += `<i style="${on ? `background:${PATH_COLORS[def.path]}` : ''}"></i>`;
    }
    return s + '</span>';
  }

  private apertureHtml() {
    const g = this.game, p = g.p, size = g.apSize;
    const occ = occupancy(size, p.placed, p.gu);
    const build = g.build;
    const selInst = this.sel != null ? p.gu.find(x => x.uid === this.sel) : undefined;
    // preview cells
    const preview = new Map<number, boolean>();
    if (selInst && this.hover) {
      const ok = canPlace(size, p.placed, p.gu, selInst.defId, this.hover.x, this.hover.y, this.rot, selInst.uid);
      for (const [cx, cy] of shapeCells(GU[selInst.defId], this.rot)) {
        const x = this.hover.x + cx, y = this.hover.y + cy;
        if (x < size && y < size) preview.set(y * size + x, ok);
      }
    }
    const anchors = new Map<number, number>();
    for (const pl of p.placed) anchors.set(pl.uid, -1);
    let grid = `<div class="ap-grid" style="--n:${size}">`;
    for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
      const uid = occ[y * size + x];
      let style = '', label = '', cls = 'cell';
      if (uid) {
        const inst = p.gu.find(gg => gg.uid === uid)!;
        const def = GU[inst.defId];
        style = `background:${PATH_COLORS[def.path]}`;
        if (anchors.get(uid) === -1) { anchors.set(uid, y * size + x); label = `<b>${esc(abbr(def.name))}</b>`; }
        if (build.inactive.has(uid)) cls += ' starving';
        if (uid === this.sel) cls += ' selected';
        // borders between different Gu
        const same = (nx: number, ny: number) => nx >= 0 && ny >= 0 && nx < size && ny < size && occ[ny * size + nx] === uid;
        if (same(x + 1, y)) cls += ' jr';
        if (same(x, y + 1)) cls += ' jb';
      }
      const pv = preview.get(y * size + x);
      if (pv !== undefined) cls += pv ? ' pv-ok' : ' pv-bad';
      grid += `<div class="${cls}" data-act="cell" data-x="${x}" data-y="${y}" style="${style}">${label}</div>`;
    }
    grid += '</div>';

    const unplaced = p.gu.filter(gg => !p.placed.some(pl => pl.uid === gg.uid));
    const pouch = unplaced.length
      ? unplaced.map(inst => this.guCard(inst.uid, 'select')).join('')
      : '<div class="muted">All your Gu are refined into your aperture.</div>';

    let selBox = '<div class="muted">Tap a Gu in your pouch, then tap a cell to place it. Tap a placed Gu to move it. Adjacent Gu form synergies.</div>';
    if (selInst) {
      const def = GU[selInst.defId];
      const placed = p.placed.some(pl => pl.uid === selInst.uid);
      selBox = `<div class="selbox">
        <div class="row">${this.guMini(def, this.rot)} <b>${esc(def.name)}</b> <span class="tag" style="background:${PATH_COLORS[def.path]}">${PATH_NAMES[def.path]}</span> <span class="tag">R${def.rank}</span></div>
        <div class="muted">${esc(def.desc)}</div>
        <div class="row gap">
          <button class="btn" data-act="rotate">⟳ Rotate (R)</button>
          ${placed ? `<button class="btn" data-act="unplace">Return to pouch</button>` : ''}
          <button class="btn" data-act="feed" data-uid="${selInst.uid}">Feed (${ITEMS[def.food].name} ×${g.count(def.food)})</button>
          <button class="btn" data-act="deselect">Done</button>
        </div></div>`;
    }

    const atk = build.attacks.map(a => `<li class="${a.isKiller ? 'km' : ''}"><b>${esc(a.name)}</b> — ${a.kind}${a.count ? '×' + a.count : ''} · ${a.damage.toFixed(1)} dmg · ${a.cooldown.toFixed(2)}s · ${a.cost.toFixed(1)} essence · range ${Math.round(a.kind === 'nova' ? a.radius ?? a.range : a.range)}${a.slow ? ` · slow ${Math.round(a.slow * 100)}%` : ''}</li>`).join('') || '<li class="muted">No attack Gu active — you cannot fight!</li>';
    const st = build.stats;
    const stats = [
      st.armor && `Armor ${st.armor}`, st.maxHp && `+${st.maxHp} HP`, st.shield && `Shield ${st.shield}`,
      st.damageMult && `+${Math.round(st.damageMult * 100)}% dmg`, st.hpRegen && `+${st.hpRegen} HP/s`,
      st.moveSpeed && `+${Math.round(st.moveSpeed * 100)}% speed`, st.reveal && `Reveal +${st.reveal}`,
    ].filter(Boolean).join(' · ') || 'none';
    const codex = KILLER_MOVES.map(km => {
      const active = build.killerMoves.includes(km);
      const parts = km.requires.map(r => {
        const own = p.gu.some(gg => gg.defId === r);
        return `<span class="${own ? 'own' : ''}">${esc(GU[r].name)}</span>`;
      }).join(' + ');
      return `<li class="${active ? 'active' : ''}"><b>${active ? '✦ ' : ''}${esc(km.name)}</b> <span class="tag">R${km.minRank}+</span><br/><small>${parts} — must touch in the aperture</small><br/><small class="muted">${esc(km.desc)}</small></li>`;
    }).join('');

    return `
      <div class="ap-top">
        <div>
          <div class="ap-info">${RANK_NAMES[p.rank]} aperture · ${size}×${size} · <span style="color:${ESSENCE_COLORS[p.rank]}">${ESSENCE_NAMES[p.rank]} essence</span></div>
          ${grid}
        </div>
        <div class="ap-side">${selBox}</div>
      </div>
      <h3>Gu Pouch (unplaced)</h3><div class="cards">${pouch}</div>
      <h3>Active Gu Combination</h3><ul class="list">${atk}</ul>
      <div class="muted">Passives: ${stats}</div>
      ${build.synergies.length ? `<h3>Synergies</h3><ul class="list syn">${build.synergies.map(s => `<li>${esc(s)}</li>`).join('')}</ul>` : ''}
      <h3>Killer Move Codex 杀招</h3><ul class="list codex">${codex}</ul>`;
  }

  private guCard(uid: number, act: 'select' | 'sell') {
    const g = this.game;
    const inst = g.p.gu.find(x => x.uid === uid)!;
    const def = GU[inst.defId];
    const hunger = isStarving(inst) ? `<span class="bad">Starving!</span>` : inst.daysUnfed >= def.feedEvery - 1 ? `<span class="warn">Hungry</span>` : '<span class="good">Fed</span>';
    const locked = def.rank > g.p.rank ? `<span class="bad">Rank ${def.rank} — too high</span>` : '';
    const btn = act === 'select'
      ? `<button class="btn sm" data-act="select" data-uid="${uid}">${this.sel === uid ? 'Selected' : 'Place'}</button>`
      : `<button class="btn sm" data-act="sellgu" data-uid="${uid}">Sell ◆${Math.floor(def.price * 0.4)}</button>`;
    return `<div class="card ${this.sel === uid ? 'sel' : ''}" style="border-color:${PATH_COLORS[def.path]}">
      <div class="row">${this.guMini(def)} <b>${esc(def.name)}</b></div>
      <div class="small">R${def.rank} · ${PATH_NAMES[def.path]} · ${def.role}</div>
      <div class="small">Eats ${ITEMS[def.food].name} every ${def.feedEvery}d · ${hunger} ${locked}</div>
      ${btn}</div>`;
  }

  private bagHtml() {
    const g = this.game;
    const inv = Object.entries(g.p.inventory).filter(([, v]) => v > 0);
    const rows = inv.map(([id, n]) => {
      const d = ITEMS[id];
      const edible = d.food || d.heal;
      const gu = Object.values(GU).filter(gg => gg.food === id && g.p.gu.some(x => x.defId === gg.id)).map(gg => gg.name);
      return `<div class="item"><i class="dot" style="background:${d.color}"></i><b>${esc(d.name)}</b> ×${n}
        <span class="small muted">${esc(d.desc)}${gu.length ? ` <span class="good">Food for: ${esc(gu.join(', '))}</span>` : ''}</span>
        ${edible ? `<button class="btn sm" data-act="eat" data-id="${id}">Eat</button>` : ''}</div>`;
    }).join('') || '<div class="muted">Your bag is empty.</div>';
    const p = g.p;
    return `<div class="muted">◆ ${p.stones} primeval stones · Kills ${p.kills} · Hunger ${Math.ceil(p.hunger)}/100</div>${rows}`;
  }

  private craftHtml() {
    const g = this.game;
    const rows = RECIPES.map(r => {
      const why = g.canCraft(r);
      const needs = Object.entries(r.needs).map(([k, v]) => `<span class="${g.count(k) >= v ? 'good' : 'bad'}">${v} ${ITEMS[k].name}</span>`);
      if (r.stones) needs.push(`<span class="${g.p.stones >= r.stones ? 'good' : 'bad'}">◆${r.stones}</span>`);
      if (r.guInput) needs.push(`<span class="${g.p.gu.some(x => x.defId === r.guInput) ? 'good' : 'bad'}">${GU[r.guInput].name}</span>`);
      if (r.nearFire) needs.push(`<span class="${g.nearFire() ? 'good' : 'bad'}">near fire</span>`);
      if (r.minRank) needs.push(`<span class="${g.p.rank >= r.minRank ? 'good' : 'bad'}">rank ${r.minRank}</span>`);
      return `<div class="item"><b>${esc(r.name)}</b><span class="small muted">${esc(r.desc)}</span><span class="small">${needs.join(' · ')}</span>
        <button class="btn sm ${why ? 'off' : 'gold'}" data-act="craft" data-id="${r.id}" title="${why ?? ''}">${r.output.gu ? 'Refine' : 'Make'}</button></div>`;
    }).join('');
    return `<div class="muted">Gu refinement may fail; higher aptitude improves success.</div>${rows}`;
  }

  private shopHtml() {
    const g = this.game;
    const shop = SHOPS[this.panelData.shop ?? 'village'];
    const tabs = `<div class="tabs">${(['gu', 'items', 'sell'] as const).map(t => `<button class="btn sm ${this.shopTab === t ? 'gold' : ''}" data-act="tab" data-id="${t}">${{ gu: 'Buy Gu', items: 'Buy Goods', sell: 'Sell' }[t]}</button>`).join('')}</div>`;
    let body = '';
    if (this.shopTab === 'gu') {
      body = shop.gu.map(id => {
        const d = GU[id];
        return `<div class="item">${this.guMini(d)}<b>${esc(d.name)}</b> <span class="tag" style="background:${PATH_COLORS[d.path]}">R${d.rank} ${PATH_NAMES[d.path]}</span>
          <span class="small muted">${esc(d.desc)} Eats ${ITEMS[d.food].name}.</span>
          <button class="btn sm ${g.p.stones >= d.price ? 'gold' : 'off'}" data-act="buygu" data-id="${id}">◆${d.price}</button></div>`;
      }).join('');
    } else if (this.shopTab === 'items') {
      body = shop.items.map(id => {
        const d = ITEMS[id];
        return `<div class="item"><i class="dot" style="background:${d.color}"></i><b>${esc(d.name)}</b> <span class="small">(have ${g.count(id)})</span>
          <span class="small muted">${esc(d.desc)}</span>
          <button class="btn sm" data-act="buyitem" data-id="${id}" data-n="1">◆${d.price * 2}</button>
          <button class="btn sm" data-act="buyitem" data-id="${id}" data-n="5">×5 ◆${d.price * 10}</button></div>`;
      }).join('');
    } else {
      const items = Object.entries(g.p.inventory).filter(([, n]) => n > 0).map(([id, n]) => {
        const d = ITEMS[id];
        return `<div class="item"><i class="dot" style="background:${d.color}"></i><b>${esc(d.name)}</b> ×${n}
          <button class="btn sm" data-act="sellitem" data-id="${id}" data-n="1">Sell ◆${d.price}</button>
          <button class="btn sm" data-act="sellitem" data-id="${id}" data-n="${n}">All ◆${d.price * n}</button></div>`;
      }).join('');
      const gu = g.p.gu.map(x => this.guCard(x.uid, 'sell')).join('');
      body = `<h3>Goods</h3>${items || '<div class="muted">Nothing to sell.</div>'}<h3>Gu</h3><div class="cards">${gu}</div>`;
    }
    return `<div class="muted">${esc(shop.name)} · You have ◆${g.p.stones}</div>${tabs}${body}`;
  }

  private elderHtml() {
    const g = this.game, p = g.p;
    const cost = g.cultivationCost();
    return `
      <p><b>${RANK_NAMES[p.rank]} ${STAGE_NAMES[p.stage]}</b> · Grade ${gradeOf(p.aptitude)} aptitude (${Math.round(p.aptitude * 100)}%)</p>
      <div class="bar prog"><div class="fill" style="width:${Math.min(100, p.cultivation)}%;background:${ESSENCE_COLORS[p.rank]}"></div><span>Cultivation ${Math.floor(p.cultivation)}%</span></div>
      <p class="muted">Sit in seclusion and absorb primeval stones to warm and nourish your aperture walls. Each session costs ◆${cost} and some time.
      At Peak Stage, a breakthrough expands your aperture to the next rank: more grid space, stronger essence, and higher-rank Gu.</p>
      <div class="row gap">
        <button class="btn gold ${p.stones >= cost ? '' : 'off'}" data-act="cultivate">Cultivate (◆${cost})</button>
        <button class="btn" data-act="rest">Rest until dawn</button>
      </div>
      <h3>Aperture by rank</h3>
      <ul class="list">${[1, 2, 3, 4, 5].map(r => `<li class="${r === p.rank ? 'active' : ''}">Rank ${r}: ${3 + r}×${3 + r} grid · <span style="color:${ESSENCE_COLORS[r]}">${ESSENCE_NAMES[r]}</span> essence</li>`).join('')}</ul>`;
  }

  private caravanHtml() {
    const npc = this.panelData.npc!;
    const dest = this.game.world.poi(npc.dest!);
    return `<p>The caravan travels the road to <b>${esc(dest.name)}</b>. Fee: ◆15. The journey takes a third of a day.</p>
      <p class="muted">${esc(dest.desc)}</p>
      <button class="btn gold" data-act="travel" data-id="${dest.id}">Travel to ${esc(dest.name)}</button>`;
  }

  private helpHtml() {
    return `<ul class="list">
      <li><b>Move</b> with WASD or by dragging on the left side of the screen. Your Gu attack <b>automatically</b> when enemies are in range, consuming primeval essence.</li>
      <li><b>Aperture</b>: a grid inside you. Place Gu in it to activate them. Bigger ranks mean bigger grids.</li>
      <li><b>Synergy</b>: support Gu (Liquor Worm, Spider Silk…) empower attack Gu they touch. Same-path Gu touching each other resonate for +15% damage.</li>
      <li><b>Killer moves</b>: certain Gu touching each other unlock powerful combined attacks. See the codex in the Aperture panel.</li>
      <li><b>Feeding</b>: every Gu eats a specific food every few days at dawn. Hungry Gu stop working; 3 days later they die.</li>
      <li><b>Survival</b>: watch Hunger. Night is dark and dangerous; build a campfire (Refine panel) and cook meat.</li>
      <li><b>Primeval stones</b> (◆) are money and essence. Tap ◆ or press Q to absorb one and restore essence in a fight.</li>
      <li><b>Cultivate</b> with the Clan Elder to rank up. Use the caravan to reach Shang Clan City for rarer Gu.</li>
      <li><b>Regional Walls</b> seal the Southern Border on the north, west and east. Mortals cannot pass.</li>
      <li>The <b>Myriad Beast Mire</b> (southwest) is forbidden ground ruled by a Beast King. The <b>ruins</b> (northwest) hide an inheritance.</li>
    </ul>`;
  }

  private drawBigMap() {
    const c = $('#bigmap') as HTMLCanvasElement;
    if (!c) return;
    const m = c.getContext('2d')!;
    m.imageSmoothingEnabled = false;
    m.drawImage(this.fogCanvas, 0, 0, 440, 440);
    const s = 440 / MAP_W;
    m.font = 'bold 11px sans-serif'; m.textAlign = 'center';
    for (const poi of POIS) {
      if (!this.game.world.explored[poi.ty * MAP_W + poi.tx]) continue;
      m.fillStyle = poi.zone === 'forbidden' ? '#ff4d6d' : poi.zone === 'ruins' ? '#ffd76b' : '#fff';
      m.fillRect(poi.tx * s - 3, poi.ty * s - 3, 6, 6);
      m.strokeStyle = '#000'; m.lineWidth = 3;
      m.strokeText(poi.name, poi.tx * s, poi.ty * s - 6); m.fillText(poi.name, poi.tx * s, poi.ty * s - 6);
    }
    const p = this.game.p;
    m.fillStyle = '#ff0'; m.beginPath(); m.arc((p.x / TILE) * s, (p.y / TILE) * s, 4, 0, 7); m.fill();
    m.fillStyle = 'rgba(200,190,255,0.9)';
    m.fillText('Central Continent ▲', 220, 14);
    m.save(); m.translate(10, 220); m.rotate(-Math.PI / 2); m.fillText('Western Desert', 0, 0); m.restore();
    m.save(); m.translate(432, 220); m.rotate(Math.PI / 2); m.fillText('Eastern Sea', 0, 0); m.restore();
  }

  // ------------------------------------------------------------------ events
  private onHover(e: Event) {
    if (this.panel !== 'aperture' || this.sel == null) return;
    const cell = (e.target as HTMLElement).closest('[data-act="cell"]') as HTMLElement | null;
    if (!cell) return;
    const x = +cell.dataset.x!, y = +cell.dataset.y!;
    if (this.hover && this.hover.x === x && this.hover.y === y) return;
    this.hover = { x, y };
    this.renderPanel();
  }

  private onClick(e: Event) {
    const t = (e.target as HTMLElement).closest('[data-act]') as HTMLElement | null;
    if (!t) return;
    const act = t.dataset.act!;
    const g = this.game;
    const id = t.dataset.id!;
    const uid = t.dataset.uid ? +t.dataset.uid : -1;
    switch (act) {
      case 'close': this.close(); break;
      case 'close-modal': $('#modal').classList.add('hidden'); if (!this.panel) g.paused = false; break;
      case 'open-aperture': this.toggle('aperture'); break;
      case 'open-bag': this.toggle('bag'); break;
      case 'open-craft': this.toggle('craft'); break;
      case 'open-help': this.toggle('help'); break;
      case 'open-map': this.toggle('map'); break;
      case 'absorb': g.absorbStone(); break;
      case 'action': g.doAction(); break;
      case 'select': this.sel = this.sel === uid ? null : uid; this.rot = 0; this.renderPanel(); break;
      case 'deselect': this.sel = null; this.hover = null; this.renderPanel(); break;
      case 'rotate': this.rot = (this.rot + 1) % 4; this.renderPanel(); break;
      case 'unplace': if (this.sel != null) { g.unplaceGu(this.sel); this.sel = null; this.renderPanel(); } break;
      case 'feed': g.feedGu(uid); break;
      case 'cell': {
        const x = +t.dataset.x!, y = +t.dataset.y!;
        const size = g.apSize;
        const occ = occupancy(size, g.p.placed, g.p.gu);
        const here = occ[y * size + x];
        if (this.sel != null && (here === 0 || here === this.sel)) {
          if (g.placeGu(this.sel, x, y, this.rot)) { this.sel = null; this.hover = null; }
          else this.toast("It doesn't fit there.", 'bad');
          this.renderPanel();
        } else if (here) {
          this.sel = here;
          this.rot = g.p.placed.find(pl => pl.uid === here)?.rot ?? 0;
          this.renderPanel();
        }
        break;
      }
      case 'eat': g.eat(id); break;
      case 'craft': g.craft(id); break;
      case 'tab': this.shopTab = id as UI['shopTab']; this.renderPanel(); break;
      case 'buygu': g.buyGu(id); break;
      case 'sellgu': g.sellGu(uid); break;
      case 'buyitem': g.buyItem(id, +(t.dataset.n ?? 1)); break;
      case 'sellitem': g.sellItem(id, +(t.dataset.n ?? 1)); break;
      case 'cultivate': g.cultivate(); break;
      case 'rest': {
        g.restUntilDawn();
        this.close();
        this.toast('You rest in safety until dawn.', 'good');
        break;
      }
      case 'travel': g.travel(id); this.close(); break;
    }
  }
}

function abbr(name: string) {
  const w = name.replace(/ Gu$/, '').split(' ');
  return w.length === 1 ? w[0].slice(0, 5) : w.map(s => s[0]).join('').slice(0, 4);
}

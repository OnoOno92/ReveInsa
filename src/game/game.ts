import { Input } from '../core/input';
import { clamp, mulberry32, randInt } from '../core/rng';
import { ENEMIES, spawnTable, type EnemyDef } from '../data/enemies';
import { GU, PATH_COLORS } from '../data/gu';
import { ITEMS, RECIPES, SHOPS, type Recipe } from '../data/items';
import { MAP_H, MAP_W, NODE_INFO, POIS, TILE, World, type NPC, type ResNode } from '../world/world';
import {
  apertureSize, canPlace, computeBuild, ESSENCE_COLORS, findFreeSpot, isStarving, STAGE_NAMES,
  type Build, type GuInstance, type PlacedGu,
} from './aperture';

export const DAY_SECONDS = 300; // real seconds per in-game day
const SAVE_KEY = 'reveinsa_save_v1';

export interface PlayerData {
  name: string;
  x: number; y: number;
  hp: number; essence: number; hunger: number;
  rank: number; stage: number; cultivation: number; aptitude: number;
  stones: number;
  inventory: Record<string, number>;
  gu: GuInstance[];
  placed: PlacedGu[];
  nextUid: number;
  kills: number;
}

interface SaveData {
  v: 1; seed: number; time: number; player: PlayerData;
  depleted: Array<[number, number, number]>; flags: Record<string, number>;
  campfires: Campfire[]; explored: string;
}

export interface Enemy {
  def: EnemyDef; x: number; y: number; hp: number; maxHp: number;
  atkT: number; rangedT: number; slowT: number; slowAmt: number; flash: number;
  wanderA: number; wanderT: number; aggro: boolean; home?: { x: number; y: number };
}
interface Projectile {
  x: number; y: number; vx: number; vy: number; damage: number; life: number; size: number; color: string;
  friendly: boolean; pierce: number; slow: number; hit: Set<Enemy>;
}
interface Pickup { x: number; y: number; item?: string; count: number; stones?: number; t: number }
interface Effect {
  kind: 'text' | 'ring' | 'line' | 'burst'; x: number; y: number; x2?: number; y2?: number;
  text?: string; color: string; t: number; life: number; r?: number;
}
export interface Campfire { x: number; y: number; until: number }

export type Interactable =
  | { kind: 'node'; node: ResNode; label: string }
  | { kind: 'npc'; npc: NPC; label: string }
  | { kind: 'sign'; text: string; label: string };

export class Game {
  world!: World;
  p!: PlayerData;
  build!: Build;
  time = 0.15; // days (fractional = time of day)
  flags: Record<string, number> = {};
  campfires: Campfire[] = [];
  enemies: Enemy[] = [];
  projectiles: Projectile[] = [];
  pickups: Pickup[] = [];
  effects: Effect[] = [];
  timers = new Map<string, number>();
  shield = 0;
  lastHurt = -99;
  clock = 0; // real seconds since start
  paused = true;
  facing = 0;
  moving = false;
  interact: Interactable | null = null;
  actionCd = 0;
  spawnT = 0;
  saveT = 0;
  revealT = 0;
  absorbCd = 0;
  wallWarnT = 0;
  zoom = 1;
  rng = mulberry32(Date.now() & 0xffffffff);

  onToast: (msg: string, kind?: 'info' | 'good' | 'bad' | 'gold') => void = () => {};
  onChange: () => void = () => {};
  onNpc: (npc: NPC) => void = () => {};
  onDeath: () => void = () => {};

  private ctx: CanvasRenderingContext2D;
  private dark = document.createElement('canvas');
  private dctx = this.dark.getContext('2d')!;
  W = 0; H = 0; dpr = 1;

  constructor(public canvas: HTMLCanvasElement, public input: Input) {
    this.ctx = canvas.getContext('2d')!;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  resize() {
    this.dpr = Math.min(2, window.devicePixelRatio || 1);
    this.W = window.innerWidth; this.H = window.innerHeight;
    this.canvas.width = this.W * this.dpr; this.canvas.height = this.H * this.dpr;
    this.canvas.style.width = this.W + 'px'; this.canvas.style.height = this.H + 'px';
    this.dark.width = this.canvas.width; this.dark.height = this.canvas.height;
    this.zoom = clamp(Math.min(this.W, this.H) / 620, 0.75, 1.6);
  }

  // ------------------------------------------------------------------ lifecycle
  hasSave() { try { return !!localStorage.getItem(SAVE_KEY); } catch { return false; } }

  newGame(name: string, seed = (Math.random() * 1e9) | 0): { grade: string; aptitude: number } {
    this.world = new World(seed);
    this.world.buildMinimapBase();
    const r = this.rng;
    const aptitude = Math.round((0.42 + r() * 0.42) * 100) / 100; // C..A grade
    const vc = this.world.poiCenter('village');
    this.p = {
      name, x: vc.x, y: vc.y + TILE * 1.5, hp: 100, essence: 0, hunger: 80,
      rank: 1, stage: 0, cultivation: 0, aptitude, stones: 30,
      inventory: { meat: 2, moon_orchid: 4, herb: 4, rice_ball: 2, wood: 2 },
      gu: [], placed: [], nextUid: 1, kills: 0,
    };
    this.time = 0.12; this.flags = {}; this.campfires = [];
    this.resetTransient();
    const starter = this.addGu('moonlight', true);
    void starter;
    this.addGu(r() < 0.5 ? 'stone_skin' : 'vitality_leaf', true);
    this.rebuild();
    this.p.hp = this.maxHp; this.p.essence = this.maxEssence;
    this.world.reveal(this.p.x, this.p.y, 14);
    this.save();
    return { grade: gradeOf(aptitude), aptitude };
  }

  load(): boolean {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return false;
      const s = JSON.parse(raw) as SaveData;
      this.world = new World(s.seed);
      this.world.buildMinimapBase();
      this.p = s.player; this.time = s.time; this.flags = s.flags ?? {}; this.campfires = s.campfires ?? [];
      const byId = new Map(this.world.nodes.map(n => [n.id, n]));
      for (const [id, regrow, hp] of s.depleted ?? []) { const n = byId.get(id); if (n) { n.regrowDay = regrow; n.hp = hp; } }
      if (s.explored) {
        const bin = atob(s.explored);
        for (let i = 0; i < bin.length && i < this.world.explored.length; i++) this.world.explored[i] = bin.charCodeAt(i);
      }
      this.resetTransient();
      this.rebuild();
      return true;
    } catch (e) {
      console.error('load failed', e);
      return false;
    }
  }

  save() {
    if (!this.world) return;
    const depleted: Array<[number, number, number]> = [];
    for (const n of this.world.nodes) if (n.regrowDay > 0 || n.hp < NODE_INFO[n.type].hp) depleted.push([n.id, n.regrowDay, n.hp]);
    let bin = '';
    const ex = this.world.explored;
    for (let i = 0; i < ex.length; i++) bin += String.fromCharCode(ex[i]);
    const s: SaveData = {
      v: 1, seed: this.world.seed, time: this.time, player: this.p, depleted, flags: this.flags,
      campfires: this.campfires, explored: btoa(bin),
    };
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(s)); } catch { /* storage unavailable */ }
  }

  deleteSave() { try { localStorage.removeItem(SAVE_KEY); } catch { /* ignore */ } }

  private resetTransient() {
    this.enemies = []; this.projectiles = []; this.pickups = []; this.effects = []; this.timers.clear();
    this.shield = 0; this.lastHurt = -99;
    this.spawnBoss();
  }

  // ------------------------------------------------------------------ derived stats
  get maxHp() { return 100 + (this.p.rank - 1) * 40 + this.p.stage * 8 + this.build.stats.maxHp; }
  get maxEssence() {
    const base = 40 * Math.pow(1.7, this.p.rank - 1) * (1 + this.p.stage * 0.2);
    return base * (0.5 + this.p.aptitude) + this.build.stats.maxEssence;
  }
  get essenceRegen() { return this.maxEssence * 0.012 * (0.5 + this.p.aptitude) * (1 + this.build.stats.essenceRegen); }
  get moveSpeed() { return 150 * (1 + this.build.stats.moveSpeed); }
  get day() { return Math.floor(this.time); }
  get tod() { return this.time - Math.floor(this.time); }
  get isNight() { const t = this.tod; return t > 0.68 || t < 0.04; }
  get darkness() {
    const t = this.tod;
    if (t < 0.04) return 0.82 * (1 - t / 0.04);
    if (t < 0.58) return 0;
    if (t < 0.68) return 0.82 * ((t - 0.58) / 0.1);
    return 0.82;
  }
  get apSize() { return apertureSize(this.p.rank); }
  get zone() { return this.world.zoneAt(this.p.x, this.p.y); }

  rebuild() {
    this.build = computeBuild(this.p.rank, this.p.placed, this.p.gu);
    this.shield = Math.min(this.shield, this.build.stats.shield);
    if (this.p) { this.p.hp = Math.min(this.p.hp, this.maxHp); this.p.essence = Math.min(this.p.essence, this.maxEssence); }
  }

  // ------------------------------------------------------------------ inventory / gu ops
  count(item: string) { return this.p.inventory[item] ?? 0; }
  addItem(item: string, n = 1) { this.p.inventory[item] = this.count(item) + n; if (this.p.inventory[item] <= 0) delete this.p.inventory[item]; }

  addGu(defId: string, autoPlace = false): GuInstance {
    const inst: GuInstance = { uid: this.p.nextUid++, defId, daysUnfed: 0 };
    this.p.gu.push(inst);
    if (autoPlace && GU[defId].rank <= this.p.rank) {
      const spot = findFreeSpot(this.apSize, this.p.placed, this.p.gu, defId);
      if (spot) this.p.placed.push({ uid: inst.uid, ...spot });
    }
    return inst;
  }

  removeGu(uid: number) {
    this.p.gu = this.p.gu.filter(g => g.uid !== uid);
    this.p.placed = this.p.placed.filter(p => p.uid !== uid);
  }

  placeGu(uid: number, x: number, y: number, rot: number): boolean {
    const inst = this.p.gu.find(g => g.uid === uid);
    if (!inst) return false;
    const def = GU[inst.defId];
    if (def.rank > this.p.rank) { this.onToast(`${def.name} is rank ${def.rank}. Your aperture cannot sustain it yet.`, 'bad'); return false; }
    if (!canPlace(this.apSize, this.p.placed, this.p.gu, inst.defId, x, y, rot, uid)) return false;
    this.p.placed = this.p.placed.filter(p => p.uid !== uid);
    this.p.placed.push({ uid, x, y, rot });
    this.rebuild(); this.onChange();
    return true;
  }

  unplaceGu(uid: number) {
    this.p.placed = this.p.placed.filter(p => p.uid !== uid);
    this.rebuild(); this.onChange();
  }

  feedGu(uid: number): boolean {
    const inst = this.p.gu.find(g => g.uid === uid);
    if (!inst) return false;
    const def = GU[inst.defId];
    if (this.count(def.food) <= 0) { this.onToast(`No ${ITEMS[def.food].name} to feed ${def.name}.`, 'bad'); return false; }
    this.addItem(def.food, -1);
    inst.daysUnfed = 0;
    this.rebuild(); this.onChange();
    return true;
  }

  eat(item: string) {
    const d = ITEMS[item];
    if (!d || this.count(item) <= 0 || (!d.food && !d.heal)) return;
    this.addItem(item, -1);
    if (d.food) this.p.hunger = Math.min(100, this.p.hunger + d.food);
    if (d.heal) this.p.hp = clamp(this.p.hp + d.heal, 1, this.maxHp);
    this.onToast(`Ate ${d.name}.`);
    this.onChange();
  }

  absorbStone() {
    if (this.p.stones <= 0 || this.absorbCd > 0) return;
    if (this.p.essence >= this.maxEssence - 0.5) { this.onToast('Your aperture is already full of essence.'); return; }
    this.p.stones--;
    this.p.essence = Math.min(this.maxEssence, this.p.essence + this.maxEssence * 0.35);
    this.absorbCd = 0.8;
    this.fx({ kind: 'ring', x: this.p.x, y: this.p.y, r: 30, color: ESSENCE_COLORS[this.p.rank], life: 0.5 });
    this.onChange();
  }

  nearFire() {
    if (this.world.isSafe(this.p.x, this.p.y)) return true;
    return this.campfires.some(c => (c.x - this.p.x) ** 2 + (c.y - this.p.y) ** 2 < 110 ** 2);
  }

  canCraft(r: Recipe): string | null {
    for (const [k, v] of Object.entries(r.needs)) if (this.count(k) < v) return `Need ${v} ${ITEMS[k].name}`;
    if (r.stones && this.p.stones < r.stones) return `Need ${r.stones} primeval stones`;
    if (r.guInput && !this.p.gu.some(g => g.defId === r.guInput)) return `Need a ${GU[r.guInput].name}`;
    if (r.nearFire && !this.nearFire()) return 'Must be near a fire';
    if (r.minRank && this.p.rank < r.minRank) return `Requires rank ${r.minRank}`;
    return null;
  }

  craft(id: string) {
    const r = RECIPES.find(x => x.id === id);
    if (!r) return;
    const why = this.canCraft(r);
    if (why) { this.onToast(why, 'bad'); return; }
    for (const [k, v] of Object.entries(r.needs)) this.addItem(k, -v);
    if (r.stones) this.p.stones -= r.stones;
    if (r.guInput) {
      // consume an unplaced one first if possible
      const cands = this.p.gu.filter(g => g.defId === r.guInput);
      const pick = cands.find(g => !this.p.placed.some(pp => pp.uid === g.uid)) ?? cands[0];
      this.removeGu(pick.uid);
    }
    if (r.output.item) { this.addItem(r.output.item, r.output.count ?? 1); this.onToast(`Made ${ITEMS[r.output.item].name}.`, 'good'); }
    if (r.output.gu) {
      const success = r.guInput ? 0.85 : 0.75 + this.p.aptitude * 0.2;
      if (this.rng() < success) {
        this.addGu(r.output.gu);
        this.onToast(`Refinement succeeded: ${GU[r.output.gu].name}!`, 'gold');
      } else {
        this.onToast('Refinement failed... the materials dissipated.', 'bad');
      }
    }
    if (r.output.place === 'campfire') {
      this.campfires.push({ x: this.p.x + Math.cos(this.facing) * 30, y: this.p.y + Math.sin(this.facing) * 30, until: this.time + 1 });
      this.onToast('Campfire lit. It will burn for one day.', 'good');
    }
    this.rebuild(); this.onChange(); this.save();
  }

  buyGu(defId: string) {
    const d = GU[defId];
    if (this.p.stones < d.price) { this.onToast('Not enough primeval stones.', 'bad'); return; }
    this.p.stones -= d.price;
    this.addGu(defId, true);
    this.onToast(`Bought ${d.name}.`, 'good');
    this.rebuild(); this.onChange(); this.save();
  }
  sellGu(uid: number) {
    const inst = this.p.gu.find(g => g.uid === uid);
    if (!inst) return;
    const v = Math.floor(GU[inst.defId].price * 0.4);
    this.removeGu(uid);
    this.p.stones += v;
    this.onToast(`Sold ${GU[inst.defId].name} for ${v} stones.`);
    this.rebuild(); this.onChange(); this.save();
  }
  buyItem(id: string, n = 1) {
    const cost = ITEMS[id].price * 2 * n;
    if (this.p.stones < cost) { this.onToast('Not enough primeval stones.', 'bad'); return; }
    this.p.stones -= cost; this.addItem(id, n); this.onChange();
  }
  sellItem(id: string, n = 1) {
    n = Math.min(n, this.count(id));
    if (n <= 0) return;
    this.addItem(id, -n); this.p.stones += ITEMS[id].price * n; this.onChange();
  }

  /** Cultivation: pour primeval stones into the aperture to advance stage/rank. */
  cultivationCost() { return 10 * this.p.rank * this.p.rank; }
  cultivate() {
    const cost = this.cultivationCost();
    if (this.p.rank >= 5 && this.p.stage >= 3 && this.p.cultivation >= 100) { this.onToast('You stand at the peak of mortality. The path to Gu Immortal is not yet open.', 'gold'); return; }
    if (this.p.stones < cost) { this.onToast(`Cultivation needs ${cost} primeval stones.`, 'bad'); return; }
    this.p.stones -= cost;
    this.p.cultivation += 20 + this.p.aptitude * 30;
    this.advanceTime(0.05);
    if (this.p.cultivation >= 100) {
      this.p.cultivation = 0;
      if (this.p.stage < 3) {
        this.p.stage++;
        this.onToast(`Breakthrough! ${STAGE_NAMES[this.p.stage]}.`, 'gold');
      } else if (this.p.rank < 5) {
        this.p.rank++; this.p.stage = 0;
        this.onToast(`Your aperture expands — Rank ${this.p.rank}! Primeval essence turns ${['', 'green copper', 'red steel', 'white silver', 'yellow gold', 'purple crystal'][this.p.rank]}.`, 'gold');
        this.fx({ kind: 'ring', x: this.p.x, y: this.p.y, r: 120, color: ESSENCE_COLORS[this.p.rank], life: 1.2 });
      }
    }
    this.rebuild();
    this.p.essence = this.maxEssence;
    this.onChange(); this.save();
  }

  travel(dest: string) {
    const fee = 15;
    if (this.p.stones < fee) { this.onToast(`The caravan charges ${fee} primeval stones.`, 'bad'); return; }
    this.p.stones -= fee;
    const c = this.world.poiCenter(dest);
    this.p.x = c.x; this.p.y = c.y + TILE * 2;
    this.advanceTime(0.3);
    this.enemies = this.enemies.filter(e => e.def.boss);
    this.projectiles = []; this.pickups = [];
    this.world.reveal(this.p.x, this.p.y, 16);
    this.onToast(`The caravan arrives at ${this.world.poi(dest).name}. Time passes on the road.`, 'good');
    this.onChange(); this.save();
  }

  /** Skip time forward, processing every dawn crossed (Gu feeding etc). */
  advanceTime(days: number) {
    const target = this.time + days;
    while (Math.floor(target) > this.day) { this.time = this.day + 1; this.onNewDay(); }
    this.time = target;
  }

  restUntilDawn() {
    this.advanceTime(this.day + 1.02 - this.time);
    this.p.hp = this.maxHp; this.p.essence = this.maxEssence;
    this.p.hunger = Math.max(0, this.p.hunger - 15);
    this.enemies = this.enemies.filter(e => e.def.boss);
  }

  // ------------------------------------------------------------------ main update
  update(dt: number) {
    this.clock += dt;
    if (this.paused) return;
    dt = Math.min(dt, 0.05);
    const p = this.p;
    const prevDay = this.day;
    this.time += dt / DAY_SECONDS;
    if (this.day !== prevDay) this.onNewDay();

    // movement
    const mv = this.input.move();
    this.moving = mv.x !== 0 || mv.y !== 0;
    if (this.moving) this.facing = Math.atan2(mv.y, mv.x);
    const tile = this.world.tileAt(Math.floor(p.x / TILE), Math.floor(p.y / TILE));
    const terrainMult = tile === 6 ? 0.6 : tile === 8 ? 1.15 : tile === 1 ? 0.55 : 1;
    const sp = this.moveSpeed * terrainMult * (p.hunger <= 0 ? 0.8 : 1);
    this.moveCircle(p, mv.x * sp * dt, mv.y * sp * dt, 11, false);

    // regional wall flavour
    this.wallWarnT -= dt;
    if (this.wallWarnT <= 0) {
      const tx = Math.floor(p.x / TILE), ty = Math.floor(p.y / TILE);
      for (const [dx, dy] of [[0, -1], [-1, 0], [1, 0]]) if (this.world.tileAt(tx + dx, ty + dy) === 7) {
        this.onToast(this.world.wallName(p.x, p.y) + '. Only a Gu Immortal could pass.', 'info');
        this.wallWarnT = 8; break;
      }
    }

    // survival stats
    p.hunger = Math.max(0, p.hunger - dt * (100 / (DAY_SECONDS * 1.1)));
    const safe = this.world.isSafe(p.x, p.y);
    let regen = 0.25 + this.build.stats.hpRegen + (safe ? 3 : 0);
    if (p.hunger <= 0) regen = -1.5;
    p.hp = Math.min(this.maxHp, p.hp + regen * dt);
    p.essence = Math.min(this.maxEssence, p.essence + this.essenceRegen * (safe ? 2 : 1) * dt);
    if (this.clock - this.lastHurt > 3 && this.build.stats.shield > 0)
      this.shield = Math.min(this.build.stats.shield, this.shield + this.build.stats.shield * 0.15 * dt);
    if (p.hp <= 0) { this.die('You starved.'); return; }

    // reveal map
    this.revealT -= dt;
    if (this.revealT <= 0) { this.world.reveal(p.x, p.y, 9 + this.build.stats.reveal); this.revealT = 0.25; }

    this.absorbCd = Math.max(0, this.absorbCd - dt);
    this.actionCd = Math.max(0, this.actionCd - dt);
    this.findInteractable();
    if (this.input.consume('e') || this.input.consume(' ') || this.input.actionPressed) this.doAction();

    this.updateSpawns(dt);
    this.updateEnemies(dt);
    this.updateCombat(dt);
    this.updateProjectiles(dt);
    this.updatePickups(dt);
    for (const e of this.effects) e.t += dt;
    this.effects = this.effects.filter(e => e.t < e.life);
    this.campfires = this.campfires.filter(c => c.until > this.time);

    this.saveT += dt;
    if (this.saveT > 15) { this.saveT = 0; this.save(); }
    this.input.endFrame();
  }

  private moveCircle(o: { x: number; y: number }, dx: number, dy: number, r: number, enemy: boolean) {
    const blocked = (x: number, y: number) => {
      for (const [ox, oy] of [[-r, -r], [r, -r], [-r, r], [r, r]]) {
        const px = x + ox * 0.8, py = y + oy * 0.8;
        if (this.world.isSolidAt(px, py)) return true;
        if (enemy && this.world.isSafe(px, py)) return true;
      }
      return false;
    };
    if (!blocked(o.x + dx, o.y)) o.x += dx;
    if (!blocked(o.x, o.y + dy)) o.y += dy;
    return true;
  }

  private onNewDay() {
    const lines: string[] = [];
    for (const inst of [...this.p.gu]) {
      const def = GU[inst.defId];
      inst.daysUnfed++;
      if (inst.daysUnfed >= def.feedEvery) {
        if (this.count(def.food) > 0) { this.addItem(def.food, -1); inst.daysUnfed = 0; }
        else if (inst.daysUnfed >= def.feedEvery + 3) {
          this.removeGu(inst.uid);
          lines.push(`${def.name} starved to death!`);
        } else if (inst.daysUnfed > def.feedEvery) {
          lines.push(`${def.name} is starving (needs ${ITEMS[def.food].name}).`);
        }
      }
    }
    this.rebuild();
    this.onToast(`Day ${this.day + 1} dawns.`, 'gold');
    for (const l of lines) this.onToast(l, 'bad');
    if (this.flags.bearKingDied && this.day - this.flags.bearKingDied >= 5) { delete this.flags.bearKingDied; this.spawnBoss(); }
    this.onChange();
    this.save();
  }

  private die(reason: string) {
    const p = this.p;
    const lost = Math.floor(p.stones / 2);
    p.stones -= lost;
    const keep: Record<string, number> = {};
    for (const [k, v] of Object.entries(p.inventory)) if (v > 1) keep[k] = Math.floor(v / 2);
    p.inventory = keep;
    const vc = this.world.poiCenter('village');
    p.x = vc.x; p.y = vc.y + TILE * 1.5;
    p.hp = this.maxHp * 0.6; p.hunger = Math.max(p.hunger, 40); p.essence = this.maxEssence * 0.3;
    this.enemies = this.enemies.filter(e => e.def.boss);
    this.projectiles = [];
    this.advanceTime(0.25);
    this.onToast(`${reason} Your clan carried you home. Lost ${lost} stones and half your supplies.`, 'bad');
    this.onDeath();
    this.onChange(); this.save();
  }

  // ------------------------------------------------------------------ interaction
  private findInteractable() {
    const p = this.p;
    let best: Interactable | null = null, bestD = 60 * 60;
    for (const npc of this.world.npcs) {
      const d = (npc.x - p.x) ** 2 + (npc.y - p.y) ** 2;
      if (d < bestD) { bestD = d; best = { kind: 'npc', npc, label: npc.role === 'merchant' ? 'Trade' : npc.role === 'elder' ? 'Cultivate' : 'Travel' }; }
    }
    if (!best) for (const n of this.world.nodesNear(p.x, p.y, 52)) {
      if (n.regrowDay > this.time) continue;
      if (n.type === 'chest' && this.flags.ruinsLooted) continue;
      const d = (n.x - p.x) ** 2 + (n.y - p.y) ** 2;
      if (d < bestD) {
        bestD = d;
        const label = { tree: 'Chop', rock: 'Mine', bush: 'Pick', orchid: 'Pick', jade: 'Mine', chest: 'Inherit' }[n.type];
        best = { kind: 'node', node: n, label };
      }
    }
    if (!best) for (const s of this.world.signs) if ((s.x - p.x) ** 2 + (s.y - p.y) ** 2 < bestD) best = { kind: 'sign', text: s.text, label: 'Read' };
    this.interact = best;
  }

  doAction() {
    const it = this.interact;
    if (!it || this.actionCd > 0) return;
    this.actionCd = 0.35;
    if (it.kind === 'npc') { this.onNpc(it.npc); return; }
    if (it.kind === 'sign') { this.onToast(it.text); return; }
    const n = it.node;
    if (n.type === 'chest') { this.lootInheritance(); return; }
    n.hp--;
    this.fx({ kind: 'burst', x: n.x, y: n.y - 10, color: n.type === 'tree' ? '#a77b4f' : '#ccc', life: 0.3 });
    if (n.hp > 0) return;
    const r = this.rng;
    const drop = (item: string, c: number) => { if (c > 0) this.pickups.push({ x: n.x + (r() - 0.5) * 20, y: n.y + (r() - 0.5) * 20, item, count: c, t: 0 }); };
    switch (n.type) {
      case 'tree': drop('wood', randInt(r, 2, 3)); break;
      case 'rock': drop('stone', randInt(r, 1, 3)); if (r() < 0.06) drop('jade_shard', 1); if (r() < 0.15) this.pickups.push({ x: n.x, y: n.y, count: 0, stones: randInt(r, 1, 3), t: 0 }); break;
      case 'bush': drop('berries', randInt(r, 1, 3)); if (r() < 0.4) drop('herb', 1); break;
      case 'orchid': drop('moon_orchid', 1); if (r() < 0.3) drop('herb', 1); break;
      case 'jade': drop('jade_shard', randInt(r, 1, 2)); drop('stone', 1); break;
    }
    n.hp = NODE_INFO[n.type].hp;
    n.regrowDay = this.time + NODE_INFO[n.type].regrow;
  }

  private lootInheritance() {
    this.flags.ruinsLooted = 1;
    const c = this.world.poiCenter('ruins');
    this.p.stones += 150;
    const pool = ['moon_glow', 'thunder_bead', 'four_flavors', 'fire_ember'];
    const g = pool[Math.floor(this.rng() * pool.length)];
    this.addGu(g);
    this.addItem('jade_shard', 3);
    this.fx({ kind: 'ring', x: c.x, y: c.y, r: 160, color: '#ffd76b', life: 1.5 });
    this.onToast(`You received the Nameless Inheritance: 150 primeval stones and ${GU[g].name}!`, 'gold');
    this.onChange(); this.save();
  }

  // ------------------------------------------------------------------ enemies
  private spawnBoss() {
    if (!this.world || this.flags.bearKingDied) return;
    if (this.enemies.some(e => e.def.boss)) return;
    const c = this.world.poiCenter('forbidden');
    this.enemies.push(this.makeEnemy('bear_king', c.x, c.y, { x: c.x, y: c.y }));
  }

  private makeEnemy(id: string, x: number, y: number, home?: { x: number; y: number }): Enemy {
    const def = ENEMIES[id];
    const scale = 1 + this.day * 0.04; // world grows more dangerous over time
    const hp = def.boss ? def.hp : def.hp * scale;
    return { def, x, y, hp, maxHp: hp, atkT: 0, rangedT: 1 + this.rng() * 2, slowT: 0, slowAmt: 0, flash: 0, wanderA: this.rng() * 7, wanderT: 0, aggro: false, home };
  }

  private updateSpawns(dt: number) {
    this.spawnT -= dt;
    // despawn far enemies
    this.enemies = this.enemies.filter(e => e.def.boss || (e.x - this.p.x) ** 2 + (e.y - this.p.y) ** 2 < 1500 ** 2);
    if (this.spawnT > 0) return;
    this.spawnT = 1.3;
    const danger = this.world.dangerAt(this.p.x, this.p.y);
    const cap = Math.round((this.isNight ? 12 : 7) + danger * 8);
    if (this.enemies.length >= cap) return;
    for (let attempt = 0; attempt < 6; attempt++) {
      const a = this.rng() * Math.PI * 2, d = 560 + this.rng() * 300;
      const x = this.p.x + Math.cos(a) * d, y = this.p.y + Math.sin(a) * d;
      if (this.world.isSolidAt(x, y) || this.world.isSafe(x, y)) continue;
      const zone = this.world.zoneAt(x, y);
      const table = spawnTable(zone, this.isNight, this.world.dangerAt(x, y)).filter(t => t[1] > 0);
      if (!table.length) continue;
      const total = table.reduce((s, t) => s + t[1], 0);
      let roll = this.rng() * total, pick = table[0][0];
      for (const [id, w] of table) { roll -= w; if (roll <= 0) { pick = id; break; } }
      const pack = pick.includes('wolf') && pick !== 'thunder_wolf' ? randInt(this.rng, 1, 3) : 1;
      for (let i = 0; i < pack; i++) this.enemies.push(this.makeEnemy(pick, x + i * 20, y + i * 14));
      return;
    }
  }

  private updateEnemies(dt: number) {
    const p = this.p;
    const safe = this.world.isSafe(p.x, p.y);
    for (const e of this.enemies) {
      e.flash = Math.max(0, e.flash - dt);
      e.atkT -= dt; e.rangedT -= dt;
      if (e.slowT > 0) e.slowT -= dt;
      const dx = p.x - e.x, dy = p.y - e.y, d = Math.hypot(dx, dy) || 1;
      const leash = e.home ? Math.hypot(e.x - e.home.x, e.y - e.home.y) > 500 : false;
      e.aggro = !safe && d < e.def.aggro * (this.isNight ? 1.25 : 1) && !(e.home && Math.hypot(p.x - e.home.x, p.y - e.home.y) > 650);
      const speed = e.def.speed * (e.slowT > 0 ? 1 - e.slowAmt : 1);
      let mx = 0, my = 0;
      if (e.aggro) {
        if (e.def.ranged && d < e.def.ranged.range * 0.6) { mx = -dx / d; my = -dy / d; }
        else if (!e.def.ranged || d > e.def.ranged.range * 0.8) { mx = dx / d; my = dy / d; }
        if (e.def.ranged && d < e.def.ranged.range && e.rangedT <= 0) {
          e.rangedT = e.def.ranged.cd;
          const sp = e.def.ranged.speed;
          this.projectiles.push({ x: e.x, y: e.y, vx: (dx / d) * sp, vy: (dy / d) * sp, damage: e.def.ranged.damage * (1 + this.day * 0.03), life: e.def.ranged.range / sp + 0.2, size: 6, color: e.def.ranged.color, friendly: false, pierce: 0, slow: 0, hit: new Set() });
        }
        if (d < e.def.radius + 14 && e.atkT <= 0) {
          e.atkT = e.def.attackCd;
          this.hurtPlayer(e.def.damage * (e.def.boss ? 1 : 1 + this.day * 0.03), e.def.name);
        }
      } else {
        if (leash && e.home) { const hx = e.home.x - e.x, hy = e.home.y - e.y, hl = Math.hypot(hx, hy) || 1; mx = hx / hl; my = hy / hl; }
        else {
          e.wanderT -= dt;
          if (e.wanderT <= 0) { e.wanderT = 1.5 + this.rng() * 2.5; e.wanderA = this.rng() < 0.4 ? NaN : this.rng() * Math.PI * 2; }
          if (!isNaN(e.wanderA)) { mx = Math.cos(e.wanderA) * 0.4; my = Math.sin(e.wanderA) * 0.4; }
        }
      }
      this.moveCircle(e, mx * speed * dt, my * speed * dt, e.def.radius * 0.8, true);
    }
    // separation
    for (let i = 0; i < this.enemies.length; i++) for (let j = i + 1; j < this.enemies.length; j++) {
      const a = this.enemies[i], b = this.enemies[j];
      const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy), min = a.def.radius + b.def.radius;
      if (d > 0 && d < min) { const push = (min - d) / 2 / d; a.x -= dx * push; a.y -= dy * push; b.x += dx * push; b.y += dy * push; }
    }
  }

  hurtPlayer(dmg: number, _src: string) {
    if (this.paused) return;
    this.lastHurt = this.clock;
    let d = dmg;
    if (this.shield > 0) { const a = Math.min(this.shield, d); this.shield -= a; d -= a; }
    d = d * 30 / (30 + this.build.stats.armor);
    if (d <= 0) return;
    this.p.hp -= d;
    this.fx({ kind: 'text', x: this.p.x, y: this.p.y - 24, text: '-' + Math.ceil(d), color: '#ff5252', life: 0.8 });
    if (this.p.hp <= 0) this.die(`You were slain by a ${_src}.`);
  }

  private damageEnemy(e: Enemy, dmg: number, slow = 0) {
    e.hp -= dmg; e.flash = 0.12;
    if (slow > 0) { e.slowT = 1.6; e.slowAmt = Math.max(e.slowT > 0 ? e.slowAmt : 0, slow); }
    this.fx({ kind: 'text', x: e.x + (this.rng() - 0.5) * 16, y: e.y - e.def.radius - 6, text: String(Math.round(dmg)), color: '#fff', life: 0.6 });
    e.aggro = true;
  }

  private killEnemy(e: Enemy) {
    const r = this.rng;
    for (const dr of e.def.drops) if (r() < dr.chance) this.pickups.push({ x: e.x + (r() - 0.5) * 24, y: e.y + (r() - 0.5) * 24, item: dr.item, count: randInt(r, dr.min, dr.max), t: 0 });
    const st = randInt(r, e.def.stones[0], e.def.stones[1]);
    if (st > 0) this.pickups.push({ x: e.x, y: e.y, count: 0, stones: st, t: 0 });
    if (e.def.guDrop && r() < e.def.guDrop.chance) {
      const g = e.def.guDrop.pool[Math.floor(r() * e.def.guDrop.pool.length)];
      this.addGu(g);
      this.onToast(`You captured a wild ${GU[g].name}!`, 'gold');
    }
    this.p.kills++;
    this.fx({ kind: 'burst', x: e.x, y: e.y, color: e.def.color, life: 0.5 });
    if (e.def.boss) {
      this.flags.bearKingDied = this.day || 1;
      this.onToast(`The ${e.def.name} has fallen! The mire trembles.`, 'gold');
    }
    this.onChange();
  }

  // ------------------------------------------------------------------ auto combat
  private nearestEnemy(x: number, y: number, range: number, exclude?: Set<Enemy>): Enemy | null {
    let best: Enemy | null = null, bd = range * range;
    for (const e of this.enemies) {
      if (e.hp <= 0 || exclude?.has(e)) continue;
      const d = (e.x - x) ** 2 + (e.y - y) ** 2;
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }

  private updateCombat(dt: number) {
    const p = this.p;
    const safe = this.world.isSafe(p.x, p.y);
    for (const h of this.build.heals) {
      const t = (this.timers.get(h.key) ?? 0) - dt;
      if (t <= 0 && p.hp < this.maxHp * 0.7 && p.essence >= h.cost) {
        p.essence -= h.cost; p.hp = Math.min(this.maxHp, p.hp + h.amount);
        this.fx({ kind: 'text', x: p.x, y: p.y - 30, text: '+' + h.amount, color: '#7CFC8a', life: 0.9 });
        this.fx({ kind: 'ring', x: p.x, y: p.y, r: 26, color: '#7CFC8a', life: 0.5 });
        this.timers.set(h.key, h.cooldown);
      } else this.timers.set(h.key, Math.max(0, t));
    }
    if (safe) return;
    for (const a of this.build.attacks) {
      let t = (this.timers.get(a.key) ?? 0) - dt;
      if (t <= 0) {
        const target = this.nearestEnemy(p.x, p.y, a.kind === 'nova' ? (a.radius ?? a.range) : a.range);
        if (target && p.essence >= a.cost) {
          p.essence -= a.cost;
          this.fire(a, target);
          t = a.cooldown;
        } else t = 0.1;
      }
      this.timers.set(a.key, t);
    }
    // remove the dead
    const dead = this.enemies.filter(e => e.hp <= 0);
    if (dead.length) { for (const e of dead) this.killEnemy(e); this.enemies = this.enemies.filter(e => e.hp > 0); }
  }

  private fire(a: Build['attacks'][number], target: Enemy) {
    const p = this.p;
    const ang = Math.atan2(target.y - p.y, target.x - p.x);
    const shoot = (angle: number) => {
      const sp = a.speed ?? 400;
      this.projectiles.push({ x: p.x, y: p.y, vx: Math.cos(angle) * sp, vy: Math.sin(angle) * sp, damage: a.damage, life: a.range / sp + 0.1, size: a.size ?? 6, color: a.color, friendly: true, pierce: a.pierce ?? 0, slow: a.slow ?? 0, hit: new Set() });
    };
    if (a.isKiller) this.fx({ kind: 'text', x: p.x, y: p.y - 40, text: a.name, color: '#ffd76b', life: 1.1 });
    switch (a.kind) {
      case 'projectile': shoot(ang); break;
      case 'fan': {
        const n = a.count ?? 3, s = a.spread ?? 0.5;
        for (let i = 0; i < n; i++) shoot(ang - s / 2 + (n === 1 ? s / 2 : (s * i) / (n - 1)));
        break;
      }
      case 'nova': {
        const r = a.radius ?? 100;
        for (const e of this.enemies) if ((e.x - p.x) ** 2 + (e.y - p.y) ** 2 < (r + e.def.radius) ** 2) this.damageEnemy(e, a.damage, a.slow ?? 0);
        this.fx({ kind: 'ring', x: p.x, y: p.y, r, color: a.color, life: 0.45 });
        break;
      }
      case 'chain': {
        const hit = new Set<Enemy>();
        let cur: Enemy | null = target, fx = p.x, fy = p.y;
        for (let i = 0; i < (a.count ?? 3) && cur; i++) {
          this.damageEnemy(cur, a.damage * (1 - i * 0.1), a.slow ?? 0);
          this.fx({ kind: 'line', x: fx, y: fy, x2: cur.x, y2: cur.y, color: a.color, life: 0.25 });
          hit.add(cur); fx = cur.x; fy = cur.y;
          cur = this.nearestEnemy(fx, fy, 150, hit);
        }
        break;
      }
    }
  }

  private updateProjectiles(dt: number) {
    const p = this.p;
    for (const pr of this.projectiles) {
      pr.x += pr.vx * dt; pr.y += pr.vy * dt; pr.life -= dt;
      if (this.world.isSolidAt(pr.x, pr.y) && this.world.tileAt(Math.floor(pr.x / TILE), Math.floor(pr.y / TILE)) !== 0) pr.life = 0;
      if (pr.life <= 0) continue;
      if (pr.friendly) {
        for (const e of this.enemies) {
          if (e.hp <= 0 || pr.hit.has(e)) continue;
          if ((e.x - pr.x) ** 2 + (e.y - pr.y) ** 2 < (e.def.radius + pr.size) ** 2) {
            this.damageEnemy(e, pr.damage, pr.slow);
            pr.hit.add(e);
            if (pr.pierce-- <= 0) { pr.life = 0; break; }
          }
        }
      } else if ((p.x - pr.x) ** 2 + (p.y - pr.y) ** 2 < (12 + pr.size) ** 2) {
        this.hurtPlayer(pr.damage, 'ranged attack');
        pr.life = 0;
      }
    }
    this.projectiles = this.projectiles.filter(pr => pr.life > 0);
  }

  private updatePickups(dt: number) {
    const p = this.p;
    const mag = 60 + this.build.stats.pickup;
    for (const k of this.pickups) {
      k.t += dt;
      const dx = p.x - k.x, dy = p.y - k.y, d = Math.hypot(dx, dy);
      if (k.t > 0.3 && d < mag) { const s = 360 * dt / (d || 1); k.x += dx * Math.min(1, s); k.y += dy * Math.min(1, s); }
      if (d < 16 && k.t > 0.3) {
        if (k.stones) { p.stones += k.stones; this.fx({ kind: 'text', x: p.x, y: p.y - 20, text: `+${k.stones} 元石`, color: '#9be7ff', life: 0.8 }); }
        if (k.item) { this.addItem(k.item, k.count); this.fx({ kind: 'text', x: p.x, y: p.y - 20, text: `+${k.count} ${ITEMS[k.item].name}`, color: '#ffe9a8', life: 0.8 }); }
        k.t = -999;
        this.onChange();
      }
    }
    this.pickups = this.pickups.filter(k => k.t >= 0 && k.t < 120);
  }

  fx(e: Omit<Effect, 't'>) { this.effects.push({ ...e, t: 0 }); }

  // ------------------------------------------------------------------ rendering
  render() {
    const g = this.ctx;
    const { W, H, dpr, zoom } = this;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.fillStyle = '#0b0b12';
    g.fillRect(0, 0, W, H);
    if (!this.world) return;
    const p = this.p;
    const camX = p.x - W / 2 / zoom, camY = p.y - H / 2 / zoom;
    g.setTransform(dpr * zoom, 0, 0, dpr * zoom, -camX * dpr * zoom, -camY * dpr * zoom);
    g.imageSmoothingEnabled = false;
    const viewW = W / zoom, viewH = H / zoom;

    // terrain chunks
    const CH = 16 * TILE;
    const c0x = Math.floor(camX / CH), c1x = Math.floor((camX + viewW) / CH);
    const c0y = Math.floor(camY / CH), c1y = Math.floor((camY + viewH) / CH);
    for (let cy = c0y; cy <= c1y; cy++) for (let cx = c0x; cx <= c1x; cx++) {
      if (cx < 0 || cy < 0 || cx * 16 >= MAP_W || cy * 16 >= MAP_H) continue;
      g.drawImage(this.world.getChunk(cx, cy), cx * CH, cy * CH);
    }

    // y-sorted drawables
    const draws: Array<{ y: number; f: () => void }> = [];
    const pad = 64;
    const vis = (x: number, y: number) => x > camX - pad && x < camX + viewW + pad && y > camY - pad && y < camY + viewH + pad;
    const nodes = this.world.nodesNear(p.x, p.y, Math.max(viewW, viewH));
    for (const n of nodes) if (vis(n.x, n.y)) draws.push({ y: n.y, f: () => this.drawNode(g, n) });
    for (const npc of this.world.npcs) if (vis(npc.x, npc.y)) draws.push({ y: npc.y, f: () => this.drawNpc(g, npc) });
    for (const s of this.world.signs) if (vis(s.x, s.y)) draws.push({ y: s.y, f: () => this.drawSign(g, s.x, s.y) });
    for (const c of this.campfires) if (vis(c.x, c.y)) draws.push({ y: c.y, f: () => this.drawFire(g, c.x, c.y) });
    for (const e of this.enemies) if (vis(e.x, e.y)) draws.push({ y: e.y, f: () => this.drawEnemy(g, e) });
    draws.push({ y: p.y, f: () => this.drawPlayer(g) });
    draws.sort((a, b) => a.y - b.y);

    for (const k of this.pickups) if (vis(k.x, k.y)) this.drawPickup(g, k);
    for (const d of draws) d.f();

    // projectiles
    for (const pr of this.projectiles) {
      g.fillStyle = pr.color;
      g.shadowColor = pr.color; g.shadowBlur = 10;
      if (pr.friendly) {
        const a = Math.atan2(pr.vy, pr.vx);
        g.save(); g.translate(pr.x, pr.y); g.rotate(a);
        g.beginPath(); g.arc(0, 0, pr.size, -1.2, 1.2); g.arc(-pr.size * 0.5, 0, pr.size * 0.85, 1.1, -1.1, true); g.fill();
        g.restore();
      } else { g.beginPath(); g.arc(pr.x, pr.y, pr.size, 0, 7); g.fill(); }
      g.shadowBlur = 0;
    }

    // effects
    for (const e of this.effects) {
      const k = e.t / e.life;
      g.globalAlpha = 1 - k;
      if (e.kind === 'text') {
        g.fillStyle = e.color; g.font = 'bold 13px sans-serif'; g.textAlign = 'center';
        g.strokeStyle = 'rgba(0,0,0,0.7)'; g.lineWidth = 3;
        g.strokeText(e.text!, e.x, e.y - k * 24); g.fillText(e.text!, e.x, e.y - k * 24);
      } else if (e.kind === 'ring') {
        g.strokeStyle = e.color; g.lineWidth = 4 * (1 - k) + 1;
        g.beginPath(); g.arc(e.x, e.y, (e.r ?? 40) * (0.3 + k * 0.7), 0, 7); g.stroke();
      } else if (e.kind === 'line') {
        g.strokeStyle = e.color; g.lineWidth = 3; g.shadowColor = e.color; g.shadowBlur = 12;
        g.beginPath(); g.moveTo(e.x, e.y);
        const segs = 5;
        for (let i = 1; i < segs; i++) {
          const t = i / segs;
          g.lineTo(e.x + (e.x2! - e.x) * t + (Math.random() - 0.5) * 14, e.y + (e.y2! - e.y) * t + (Math.random() - 0.5) * 14);
        }
        g.lineTo(e.x2!, e.y2!); g.stroke(); g.shadowBlur = 0;
      } else if (e.kind === 'burst') {
        g.fillStyle = e.color;
        for (let i = 0; i < 6; i++) { const a = i * 1.047; g.fillRect(e.x + Math.cos(a) * k * 20 - 2, e.y + Math.sin(a) * k * 20 - 2, 4, 4); }
      }
      g.globalAlpha = 1;
    }

    this.renderDarkness(camX, camY);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);

    // joystick
    const st = this.input.stick;
    if (st.active) {
      g.globalAlpha = 0.35; g.fillStyle = '#fff';
      g.beginPath(); g.arc(st.ox, st.oy, this.input.maxRadius, 0, 7); g.fill();
      g.globalAlpha = 0.7;
      const dx = st.x - st.ox, dy = st.y - st.oy, l = Math.hypot(dx, dy), m = Math.min(l, this.input.maxRadius) / (l || 1);
      g.beginPath(); g.arc(st.ox + dx * m, st.oy + dy * m, 24, 0, 7); g.fill();
      g.globalAlpha = 1;
    }
  }

  private renderDarkness(camX: number, camY: number) {
    const a = this.darkness;
    if (a <= 0.01) return;
    const d = this.dctx, { dpr, zoom } = this;
    d.setTransform(1, 0, 0, 1, 0, 0);
    d.globalCompositeOperation = 'source-over';
    d.clearRect(0, 0, this.dark.width, this.dark.height);
    d.fillStyle = `rgba(6,8,24,${a})`;
    d.fillRect(0, 0, this.dark.width, this.dark.height);
    d.globalCompositeOperation = 'destination-out';
    const light = (x: number, y: number, r: number, flicker = 0) => {
      const sx = (x - camX) * zoom * dpr, sy = (y - camY) * zoom * dpr, sr = (r + flicker) * zoom * dpr;
      const grd = d.createRadialGradient(sx, sy, sr * 0.2, sx, sy, sr);
      grd.addColorStop(0, 'rgba(0,0,0,1)'); grd.addColorStop(1, 'rgba(0,0,0,0)');
      d.fillStyle = grd; d.beginPath(); d.arc(sx, sy, sr, 0, 7); d.fill();
    };
    light(this.p.x, this.p.y, 150 + this.build.stats.lightRadius);
    for (const c of this.campfires) light(c.x, c.y, 230, Math.sin(this.clock * 9) * 6);
    for (const poi of POIS) if (poi.zone === 'village' || poi.zone === 'city') {
      const c = this.world.poiCenter(poi.id); light(c.x, c.y, poi.r * TILE * 1.1);
    }
    for (const pr of this.projectiles) if (pr.friendly) light(pr.x, pr.y, 40);
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.drawImage(this.dark, 0, 0);
  }

  private drawNode(g: CanvasRenderingContext2D, n: ResNode) {
    const avail = n.regrowDay <= this.time;
    const { x, y } = n;
    g.fillStyle = 'rgba(0,0,0,0.25)';
    g.beginPath(); g.ellipse(x, y + 4, 12, 5, 0, 0, 7); g.fill();
    switch (n.type) {
      case 'tree':
        g.fillStyle = '#5a3b22'; g.fillRect(x - 3, y - 14, 6, 18);
        if (avail) {
          g.fillStyle = '#2f5a2a'; g.beginPath(); g.arc(x, y - 22, 15, 0, 7); g.fill();
          g.fillStyle = '#3d7535'; g.beginPath(); g.arc(x - 4, y - 26, 10, 0, 7); g.fill();
        }
        break;
      case 'rock':
        if (!avail) break;
        g.fillStyle = '#8a8a8a'; g.beginPath(); g.ellipse(x, y - 4, 12, 9, 0, 0, 7); g.fill();
        g.fillStyle = '#a5a5a5'; g.beginPath(); g.ellipse(x - 3, y - 7, 6, 4, 0, 0, 7); g.fill();
        break;
      case 'jade':
        if (!avail) break;
        g.fillStyle = '#6c7a72'; g.beginPath(); g.ellipse(x, y - 4, 12, 9, 0, 0, 7); g.fill();
        g.fillStyle = '#9ff0cf'; g.beginPath(); g.moveTo(x - 2, y - 16); g.lineTo(x + 4, y - 6); g.lineTo(x - 5, y - 4); g.fill();
        break;
      case 'bush':
        g.fillStyle = '#2e6b34'; g.beginPath(); g.arc(x, y - 6, 10, 0, 7); g.fill();
        if (avail) { g.fillStyle = '#d8336b'; for (let i = 0; i < 4; i++) g.fillRect(x - 6 + i * 4, y - 10 + (i % 2) * 5, 3, 3); }
        break;
      case 'orchid':
        if (!avail) break;
        g.fillStyle = '#3d6b3a'; g.fillRect(x - 1, y - 10, 2, 10);
        g.fillStyle = '#cfe4ff'; g.shadowColor = '#bcd8ff'; g.shadowBlur = this.isNight ? 14 : 4;
        for (let i = 0; i < 5; i++) { const a = i * 1.256; g.beginPath(); g.arc(x + Math.cos(a) * 4, y - 12 + Math.sin(a) * 4, 3, 0, 7); g.fill(); }
        g.shadowBlur = 0;
        break;
      case 'chest': {
        const looted = !!this.flags.ruinsLooted;
        g.fillStyle = '#5c5246'; g.fillRect(x - 16, y - 10, 32, 14);
        g.fillStyle = looted ? '#444' : '#d4a93a'; g.shadowColor = '#ffd76b'; g.shadowBlur = looted ? 0 : 18;
        g.beginPath(); g.arc(x, y - 18, 7, 0, 7); g.fill(); g.shadowBlur = 0;
        break;
      }
    }
    if (this.interact?.kind === 'node' && this.interact.node === n) {
      g.strokeStyle = 'rgba(255,240,180,0.9)'; g.lineWidth = 2;
      g.beginPath(); g.ellipse(x, y + 4, 16, 7, 0, 0, 7); g.stroke();
    }
  }

  private drawNpc(g: CanvasRenderingContext2D, n: NPC) {
    const col = n.role === 'merchant' ? '#d4a93a' : n.role === 'elder' ? '#7fb3d5' : '#a0785a';
    g.fillStyle = 'rgba(0,0,0,0.3)'; g.beginPath(); g.ellipse(n.x, n.y + 6, 10, 4, 0, 0, 7); g.fill();
    g.fillStyle = col; g.beginPath(); g.moveTo(n.x - 10, n.y + 6); g.lineTo(n.x + 10, n.y + 6); g.lineTo(n.x + 6, n.y - 12); g.lineTo(n.x - 6, n.y - 12); g.fill();
    g.fillStyle = '#f1d6b8'; g.beginPath(); g.arc(n.x, n.y - 17, 6, 0, 7); g.fill();
    if (n.role === 'caravan') { g.fillStyle = '#6b4a2b'; g.fillRect(n.x + 12, n.y - 8, 22, 14); g.fillStyle = '#333'; g.beginPath(); g.arc(n.x + 16, n.y + 7, 4, 0, 7); g.arc(n.x + 30, n.y + 7, 4, 0, 7); g.fill(); }
    g.font = 'bold 11px sans-serif'; g.textAlign = 'center'; g.fillStyle = '#fff';
    g.strokeStyle = 'rgba(0,0,0,0.7)'; g.lineWidth = 3;
    g.strokeText(n.name, n.x, n.y - 28); g.fillText(n.name, n.x, n.y - 28);
  }

  private drawSign(g: CanvasRenderingContext2D, x: number, y: number) {
    g.fillStyle = '#5a3b22'; g.fillRect(x - 2, y - 16, 4, 18);
    g.fillStyle = '#a77b4f'; g.fillRect(x - 12, y - 22, 24, 10);
  }

  private drawFire(g: CanvasRenderingContext2D, x: number, y: number) {
    g.fillStyle = '#4a3422'; g.fillRect(x - 10, y - 2, 20, 4);
    const f = Math.sin(this.clock * 12) * 2;
    g.fillStyle = '#ff9a3c'; g.shadowColor = '#ff9a3c'; g.shadowBlur = 20;
    g.beginPath(); g.moveTo(x - 7, y); g.quadraticCurveTo(x, y - 22 - f, x + 7, y); g.fill();
    g.fillStyle = '#ffe08a'; g.beginPath(); g.moveTo(x - 3, y); g.quadraticCurveTo(x, y - 12 + f, x + 3, y); g.fill();
    g.shadowBlur = 0;
  }

  private drawPickup(g: CanvasRenderingContext2D, k: Pickup) {
    const bob = Math.sin(this.clock * 4 + k.x) * 2;
    if (k.stones) {
      g.fillStyle = '#9be7ff'; g.shadowColor = '#9be7ff'; g.shadowBlur = 8;
      g.beginPath(); g.moveTo(k.x, k.y - 8 + bob); g.lineTo(k.x + 5, k.y + bob); g.lineTo(k.x, k.y + 6 + bob); g.lineTo(k.x - 5, k.y + bob); g.fill();
      g.shadowBlur = 0;
    } else if (k.item) {
      g.fillStyle = ITEMS[k.item].color; g.strokeStyle = 'rgba(0,0,0,0.5)'; g.lineWidth = 1;
      g.beginPath(); g.arc(k.x, k.y + bob, 5, 0, 7); g.fill(); g.stroke();
    }
  }

  private drawEnemy(g: CanvasRenderingContext2D, e: Enemy) {
    const r = e.def.radius;
    g.fillStyle = 'rgba(0,0,0,0.3)'; g.beginPath(); g.ellipse(e.x, e.y + r * 0.6, r, r * 0.4, 0, 0, 7); g.fill();
    const face = Math.atan2(this.p.y - e.y, this.p.x - e.x);
    g.save(); g.translate(e.x, e.y);
    const flip = Math.cos(face) < 0 ? -1 : 1;
    g.scale(flip, 1);
    if (e.def.faction === 'demonic') {
      g.fillStyle = e.flash > 0 ? '#fff' : e.def.color;
      g.beginPath(); g.moveTo(-10, 8); g.lineTo(10, 8); g.lineTo(6, -10); g.lineTo(-6, -10); g.fill();
      g.fillStyle = '#e8c8a8'; g.beginPath(); g.arc(0, -15, 6, 0, 7); g.fill();
      g.fillStyle = '#ff3366'; g.fillRect(-1, -24, 2, 4);
    } else {
      g.fillStyle = e.flash > 0 ? '#fff' : e.def.color;
      g.beginPath(); g.ellipse(0, 0, r, r * 0.65, 0, 0, 7); g.fill();
      g.beginPath(); g.ellipse(r * 0.8, -r * 0.3, r * 0.45, r * 0.38, 0, 0, 7); g.fill();
      g.fillStyle = e.aggro ? '#ff4040' : '#ffd040';
      g.fillRect(r * 0.95, -r * 0.45, 3, 3);
      if (e.def.id === 'thunder_wolf') { g.strokeStyle = '#e3d0ff'; g.lineWidth = 2; g.beginPath(); g.moveTo(r * 0.6, -r * 0.7); g.lineTo(r * 0.8, -r * 1.1); g.lineTo(r, -r * 0.7); g.stroke(); }
      if (e.def.boss) { g.fillStyle = '#ffcc33'; g.fillRect(r * 0.5, -r * 0.9, r * 0.6, 4); }
    }
    g.restore();
    if (e.hp < e.maxHp || e.def.boss) {
      const w = e.def.boss ? 70 : 28;
      g.fillStyle = 'rgba(0,0,0,0.6)'; g.fillRect(e.x - w / 2, e.y - r - 12, w, 4);
      g.fillStyle = '#e74c3c'; g.fillRect(e.x - w / 2, e.y - r - 12, w * Math.max(0, e.hp / e.maxHp), 4);
      if (e.def.boss) {
        g.font = 'bold 12px serif'; g.textAlign = 'center'; g.fillStyle = '#ffcc33';
        g.fillText(e.def.name, e.x, e.y - r - 16);
      }
    }
  }

  private drawPlayer(g: CanvasRenderingContext2D) {
    const p = this.p;
    const bob = this.moving ? Math.sin(this.clock * 12) * 1.5 : 0;
    const ec = ESSENCE_COLORS[p.rank];
    g.fillStyle = 'rgba(0,0,0,0.3)'; g.beginPath(); g.ellipse(p.x, p.y + 8, 11, 4, 0, 0, 7); g.fill();
    // essence aura
    g.globalAlpha = 0.25 + 0.1 * Math.sin(this.clock * 3);
    g.fillStyle = ec; g.beginPath(); g.arc(p.x, p.y - 6, 20, 0, 7); g.fill();
    g.globalAlpha = 1;
    // shield
    if (this.shield > 1) {
      g.strokeStyle = 'rgba(100,190,255,0.6)'; g.lineWidth = 2;
      g.beginPath(); g.arc(p.x, p.y - 6, 18, 0, 7); g.stroke();
    }
    // robe
    g.fillStyle = '#2d3e50';
    g.beginPath(); g.moveTo(p.x - 9, p.y + 7 + bob); g.lineTo(p.x + 9, p.y + 7 + bob); g.lineTo(p.x + 6, p.y - 10 + bob); g.lineTo(p.x - 6, p.y - 10 + bob); g.fill();
    g.fillStyle = ec; g.fillRect(p.x - 7, p.y - 2 + bob, 14, 3);
    // head
    g.fillStyle = '#f1d6b8'; g.beginPath(); g.arc(p.x, p.y - 15 + bob, 6, 0, 7); g.fill();
    g.fillStyle = '#1b1b1b'; g.beginPath(); g.arc(p.x, p.y - 18 + bob, 6, Math.PI, 0); g.fill();
    g.fillRect(p.x - 1.5, p.y - 26 + bob, 3, 4);
    // facing hint: orbiting Gu motes
    let i = 0;
    for (const pl of this.p.placed) {
      const inst = this.p.gu.find(gg => gg.uid === pl.uid);
      if (!inst) continue;
      const a = this.clock * 1.6 + (i * Math.PI * 2) / Math.max(1, this.p.placed.length);
      g.fillStyle = isStarving(inst) ? '#555' : PATH_COLORS[GU[inst.defId].path];
      g.beginPath(); g.arc(p.x + Math.cos(a) * 22, p.y - 8 + Math.sin(a) * 9, 2.6, 0, 7); g.fill();
      i++;
    }
  }
}

export function gradeOf(apt: number) {
  return apt >= 0.8 ? 'A' : apt >= 0.6 ? 'B' : apt >= 0.4 ? 'C' : 'D';
}

export { SHOPS, RECIPES };

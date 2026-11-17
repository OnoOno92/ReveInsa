import { Noise2D, mulberry32, hash2 } from '../core/rng';
import type { Zone } from '../data/enemies';

export const TILE = 32;
export const MAP_W = 220;
export const MAP_H = 220;

export const T = {
  DeepWater: 0, Water: 1, Sand: 2, Grass: 3, Forest: 4, Mountain: 5, Swamp: 6,
  Wall: 7, Road: 8, Floor: 9, Ruin: 10, Corrupt: 11, CityWall: 12, House: 13,
} as const;
export type Tile = typeof T[keyof typeof T];

const SOLID = new Set<number>([T.DeepWater, T.Mountain, T.Wall, T.CityWall, T.House]);

export const TILE_COLORS: Record<number, string> = {
  [T.DeepWater]: '#1d4e6e', [T.Water]: '#2f7aa0', [T.Sand]: '#d8c98f', [T.Grass]: '#5f8f3e',
  [T.Forest]: '#3f6b2f', [T.Mountain]: '#6b6259', [T.Swamp]: '#4a5a34', [T.Wall]: '#8a7cc9',
  [T.Road]: '#b59a6a', [T.Floor]: '#9c9283', [T.Ruin]: '#7b7468', [T.Corrupt]: '#4a3448',
  [T.CityWall]: '#5a5550', [T.House]: '#8c3b2e',
};

export interface POI { id: string; name: string; zone: Zone; tx: number; ty: number; r: number; desc: string }

export const POIS: POI[] = [
  { id: 'village', name: 'Shi Lan Village', zone: 'village', tx: 110, ty: 172, r: 9,
    desc: 'A small righteous-path clan village. Safe haven, merchant and clan elder.' },
  { id: 'city', name: 'Shang Clan City', zone: 'city', tx: 168, ty: 46, r: 13,
    desc: 'The great trading city of the Shang clan. Rare Gu are sold here.' },
  { id: 'ruins', name: 'Nameless Inheritance Ruins', zone: 'ruins', tx: 46, ty: 58, r: 11,
    desc: 'Remains of a long-dead Gu Master. Demonic cultivators prowl here.' },
  { id: 'forbidden', name: 'Myriad Beast Mire', zone: 'forbidden', tx: 42, ty: 168, r: 24,
    desc: 'A forbidden area. A Beast King rules the mire.' },
];

export type NodeType = 'tree' | 'rock' | 'bush' | 'orchid' | 'jade' | 'chest';
export const NODE_INFO: Record<NodeType, { name: string; hp: number; regrow: number }> = {
  tree: { name: 'Tree', hp: 3, regrow: 2 },
  rock: { name: 'Rock', hp: 3, regrow: 3 },
  bush: { name: 'Berry Bush', hp: 1, regrow: 1 },
  orchid: { name: 'Moon Orchid', hp: 1, regrow: 2 },
  jade: { name: 'Jade Vein', hp: 4, regrow: 4 },
  chest: { name: 'Inheritance Altar', hp: 1, regrow: 99999 },
};

export interface ResNode { id: number; type: NodeType; x: number; y: number; hp: number; regrowDay: number }

export interface NPC { id: string; name: string; role: 'elder' | 'merchant' | 'caravan'; shop?: string; poi: string; x: number; y: number; dest?: string }

export interface Sign { x: number; y: number; text: string }

const CHUNK = 16; // tiles per render chunk

export class World {
  tiles = new Uint8Array(MAP_W * MAP_H);
  zones: Zone[] = new Array(MAP_W * MAP_H);
  danger = new Float32Array(MAP_W * MAP_H);
  shade = new Float32Array(MAP_W * MAP_H);
  nodes: ResNode[] = [];
  nodeBuckets = new Map<number, ResNode[]>();
  npcs: NPC[] = [];
  signs: Sign[] = [];
  explored = new Uint8Array(MAP_W * MAP_H);
  private chunkCache = new Map<number, HTMLCanvasElement>();
  minimapBase: ImageData | null = null;

  constructor(public seed: number) {
    this.generate();
  }

  idx(tx: number, ty: number) { return ty * MAP_W + tx; }
  inBounds(tx: number, ty: number) { return tx >= 0 && ty >= 0 && tx < MAP_W && ty < MAP_H; }
  tileAt(tx: number, ty: number): number { return this.inBounds(tx, ty) ? this.tiles[this.idx(tx, ty)] : T.Wall; }
  isSolidTile(tx: number, ty: number) { return SOLID.has(this.tileAt(tx, ty)); }
  isSolidAt(px: number, py: number) { return this.isSolidTile(Math.floor(px / TILE), Math.floor(py / TILE)); }
  zoneAt(px: number, py: number): Zone {
    const tx = Math.floor(px / TILE), ty = Math.floor(py / TILE);
    return this.inBounds(tx, ty) ? this.zones[this.idx(tx, ty)] : 'wall';
  }
  dangerAt(px: number, py: number): number {
    const tx = Math.floor(px / TILE), ty = Math.floor(py / TILE);
    return this.inBounds(tx, ty) ? this.danger[this.idx(tx, ty)] : 1;
  }
  isSafe(px: number, py: number) { const z = this.zoneAt(px, py); return z === 'village' || z === 'city'; }
  poi(id: string) { return POIS.find(p => p.id === id)!; }
  poiCenter(id: string) { const p = this.poi(id); return { x: (p.tx + 0.5) * TILE, y: (p.ty + 0.5) * TILE }; }

  /** Which regional wall the point is closest to (for flavour text). */
  wallName(px: number, py: number): string {
    const tx = px / TILE, ty = py / TILE;
    const dN = ty, dW = tx, dE = MAP_W - tx;
    if (dN <= dW && dN <= dE) return 'Regional Wall — beyond lies the Central Continent';
    if (dW <= dE) return 'Regional Wall — beyond lies the Western Desert';
    return 'Regional Wall — beyond lies the Eastern Sea';
  }

  private set(tx: number, ty: number, t: number) { if (this.inBounds(tx, ty)) this.tiles[this.idx(tx, ty)] = t; }

  private generate() {
    const elev = new Noise2D(this.seed);
    const moist = new Noise2D(this.seed + 101);
    const detail = new Noise2D(this.seed + 202);
    const vil = this.poi('village');

    // 1. Base terrain
    for (let ty = 0; ty < MAP_H; ty++) {
      for (let tx = 0; tx < MAP_W; tx++) {
        let e = elev.fbm(tx / 38, ty / 38, 5);
        const m = moist.fbm(tx / 30 + 50, ty / 30 + 50, 4);
        // South coast falls into the sea
        const southFall = Math.max(0, (ty - (MAP_H - 14)) / 14);
        e -= southFall * 0.6;
        let t: number = T.Grass;
        if (e < 0.30) t = T.DeepWater;
        else if (e < 0.35) t = T.Water;
        else if (e < 0.38) t = T.Sand;
        else if (e > 0.70) t = T.Mountain;
        else if (m > 0.66 && e < 0.48) t = T.Swamp;
        else if (m > 0.52) t = T.Forest;
        this.tiles[this.idx(tx, ty)] = t;
        this.shade[this.idx(tx, ty)] = detail.value(tx * 0.15, ty * 0.15) * 0.1 - 0.05 + hash2(tx, ty, this.seed) * 0.025;
      }
    }

    // 2. Regional walls: north (Central Continent), west (Western Desert), east (Eastern Sea)
    for (let ty = 0; ty < MAP_H; ty++) {
      for (let tx = 0; tx < MAP_W; tx++) {
        const wob = Math.floor(detail.value(tx * 0.2, ty * 0.2) * 2);
        if (ty < 3 + wob || tx < 3 + wob || tx >= MAP_W - 3 - wob) this.set(tx, ty, T.Wall);
        if (ty >= MAP_H - 3) this.set(tx, ty, T.DeepWater);
      }
    }

    // 3. Points of interest
    for (const p of POIS) {
      for (let dy = -p.r - 3; dy <= p.r + 3; dy++) {
        for (let dx = -p.r - 3; dx <= p.r + 3; dx++) {
          const tx = p.tx + dx, ty = p.ty + dy;
          if (!this.inBounds(tx, ty) || this.tileAt(tx, ty) === T.Wall) continue;
          const d = Math.hypot(dx, dy);
          const edge = p.r + (detail.value(tx * 0.3, ty * 0.3) - 0.5) * (p.id === 'forbidden' ? 8 : 2);
          if (d > edge) continue;
          if (p.id === 'village') this.set(tx, ty, d < p.r - 3 ? T.Floor : T.Grass);
          else if (p.id === 'city') this.set(tx, ty, T.Floor);
          else if (p.id === 'ruins') this.set(tx, ty, hash2(tx, ty, 7) < 0.6 ? T.Ruin : T.Grass);
          else if (p.id === 'forbidden') {
            const cur = this.tileAt(tx, ty);
            if (cur === T.DeepWater || cur === T.Water) this.set(tx, ty, T.Swamp);
            else if (cur !== T.Mountain || d < p.r - 6) this.set(tx, ty, hash2(tx, ty, 9) < 0.35 ? T.Swamp : T.Corrupt);
          }
        }
      }
    }

    // City wall ring with 4 gates
    const city = this.poi('city');
    for (let a = 0; a < Math.PI * 2; a += 0.01) {
      const tx = Math.round(city.tx + Math.cos(a) * city.r), ty = Math.round(city.ty + Math.sin(a) * city.r);
      const gate = Math.abs(tx - city.tx) <= 1 || Math.abs(ty - city.ty) <= 1;
      if (!gate) this.set(tx, ty, T.CityWall);
    }

    // 4. Roads
    this.road(vil.tx, vil.ty, city.tx, city.ty, 2);
    const ruins = this.poi('ruins');
    this.road(vil.tx, vil.ty, ruins.tx, ruins.ty, 1);
    this.road(city.tx, city.ty, ruins.tx, ruins.ty, 1);
    const forb = this.poi('forbidden');
    this.road(vil.tx, vil.ty, forb.tx + 18, forb.ty, 1);

    // 5. Houses
    const houses = (p: POI, spots: Array<[number, number]>) => {
      for (const [dx, dy] of spots) for (let y = 0; y < 2; y++) for (let x = 0; x < 3; x++) this.set(p.tx + dx + x, p.ty + dy + y, T.House);
    };
    houses(vil, [[-6, -5], [3, -5], [-6, 3], [4, 3]]);
    houses(city, [[-9, -7], [-3, -8], [4, -7], [-9, 5], [5, 5], [-3, 7], [7, -2], [-10, -1]]);

    // 6. Zones + danger
    for (let ty = 0; ty < MAP_H; ty++) {
      for (let tx = 0; tx < MAP_W; tx++) {
        const i = this.idx(tx, ty);
        const dv = Math.hypot(tx - vil.tx, ty - vil.ty);
        this.danger[i] = Math.min(1, dv / 150);
        let z: Zone = this.danger[i] > 0.62 ? 'deep' : 'wild';
        if (this.tiles[i] === T.Wall) z = 'wall';
        for (const p of POIS) {
          const d = Math.hypot(tx - p.tx, ty - p.ty);
          const r = p.id === 'forbidden' ? p.r + 2 : p.r;
          if (d <= r) { z = p.zone; if (p.zone === 'forbidden') this.danger[i] = 1; }
        }
        this.zones[i] = z;
      }
    }

    // 7. NPCs
    const at = (p: POI, dx: number, dy: number) => ({ x: (p.tx + dx + 0.5) * TILE, y: (p.ty + dy + 0.5) * TILE });
    this.npcs.push({ id: 'v_elder', name: 'Clan Elder Shi', role: 'elder', poi: 'village', ...at(vil, -2, -1) });
    this.npcs.push({ id: 'v_merchant', name: 'Merchant Lan', role: 'merchant', shop: 'village', poi: 'village', ...at(vil, 2, -1) });
    this.npcs.push({ id: 'v_caravan', name: 'Caravan Master', role: 'caravan', poi: 'village', dest: 'city', ...at(vil, 0, 3) });
    this.npcs.push({ id: 'c_elder', name: 'Cultivation Chamber', role: 'elder', poi: 'city', ...at(city, -3, 0) });
    this.npcs.push({ id: 'c_merchant', name: 'Shang Clan Steward', role: 'merchant', shop: 'city', poi: 'city', ...at(city, 3, 0) });
    this.npcs.push({ id: 'c_caravan', name: 'Shang Caravan', role: 'caravan', poi: 'city', dest: 'village', ...at(city, 0, 4) });
    for (const n of this.npcs) this.clearAround(Math.floor(n.x / TILE), Math.floor(n.y / TILE), T.Floor);

    // 8. Resource nodes
    const r = mulberry32(this.seed + 999);
    let id = 1;
    for (let ty = 4; ty < MAP_H - 4; ty++) {
      for (let tx = 4; tx < MAP_W - 4; tx++) {
        const t = this.tileAt(tx, ty);
        const z = this.zones[this.idx(tx, ty)];
        if (z === 'village' || z === 'city') continue;
        const v = r();
        let type: NodeType | null = null;
        const nearMountain = this.isNear(tx, ty, T.Mountain, 2);
        const nearWater = this.isNear(tx, ty, T.Water, 2);
        if (t === T.Forest) type = v < 0.2 ? 'tree' : v < 0.235 ? 'bush' : null;
        else if (t === T.Grass) type = v < 0.03 ? 'tree' : v < 0.05 ? 'bush' : v < (nearMountain ? 0.12 : 0.06) ? 'rock' : (nearWater && v < 0.085) ? 'orchid' : null;
        else if (t === T.Sand) type = v < 0.03 ? 'rock' : null;
        else if (t === T.Swamp) type = v < 0.04 ? 'orchid' : v < 0.07 ? 'bush' : null;
        else if (t === T.Corrupt) type = v < 0.04 ? 'orchid' : v < 0.06 ? 'jade' : v < 0.1 ? 'tree' : null;
        else if (t === T.Ruin) type = v < 0.05 ? 'rock' : v < 0.065 ? 'jade' : null;
        if (type === 'rock' && nearMountain && r() < 0.08) type = 'jade';
        if (!type) continue;
        const x = (tx + 0.2 + r() * 0.6) * TILE, y = (ty + 0.2 + r() * 0.6) * TILE;
        this.addNode({ id: id++, type, x, y, hp: NODE_INFO[type].hp, regrowDay: 0 });
      }
    }
    // Inheritance altar at the ruins
    this.clearAround(ruins.tx, ruins.ty, T.Ruin);
    this.addNode({ id: 900000, type: 'chest', x: (ruins.tx + 0.5) * TILE, y: (ruins.ty + 0.5) * TILE, hp: 1, regrowDay: 0 });

    // 9. Signs
    const vc = this.poiCenter('village');
    this.signs.push({ x: vc.x + 5 * TILE, y: vc.y - 9 * TILE, text: 'North: Shang Clan City' });
    this.signs.push({ x: vc.x - 7 * TILE, y: vc.y - 4 * TILE, text: 'West: Myriad Beast Mire — FORBIDDEN' });
  }

  private clearAround(tx: number, ty: number, t: number) {
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) this.set(tx + dx, ty + dy, t);
  }

  private isNear(tx: number, ty: number, t: number, r: number) {
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) if (this.tileAt(tx + dx, ty + dy) === t) return true;
    return false;
  }

  private road(ax: number, ay: number, bx: number, by: number, width: number) {
    const n = new Noise2D(this.seed + ax * 7 + by);
    const steps = Math.ceil(Math.hypot(bx - ax, by - ay) * 2);
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const px = ax + (bx - ax) * t, py = ay + (by - ay) * t;
      const nx = -(by - ay), ny = bx - ax, nl = Math.hypot(nx, ny) || 1;
      const off = (n.fbm(t * 4, 0.5, 3) - 0.5) * 22 * Math.sin(Math.PI * t);
      const cx = Math.round(px + (nx / nl) * off), cy = Math.round(py + (ny / nl) * off);
      for (let dy = -width + 1; dy < width; dy++) for (let dx = -width + 1; dx < width; dx++) {
        const cur = this.tileAt(cx + dx, cy + dy);
        if (cur === T.Wall || cur === T.CityWall || cur === T.House || cur === T.Floor) continue;
        this.set(cx + dx, cy + dy, T.Road);
      }
    }
  }

  private bucketKey(tx: number, ty: number) { return Math.floor(ty / 8) * 1000 + Math.floor(tx / 8); }
  private addNode(n: ResNode) {
    this.nodes.push(n);
    const k = this.bucketKey(Math.floor(n.x / TILE), Math.floor(n.y / TILE));
    let b = this.nodeBuckets.get(k);
    if (!b) this.nodeBuckets.set(k, (b = []));
    b.push(n);
  }

  nodesNear(px: number, py: number, radius: number): ResNode[] {
    const out: ResNode[] = [];
    const t0x = Math.floor((px - radius) / TILE / 8), t1x = Math.floor((px + radius) / TILE / 8);
    const t0y = Math.floor((py - radius) / TILE / 8), t1y = Math.floor((py + radius) / TILE / 8);
    for (let by = t0y; by <= t1y; by++) for (let bx = t0x; bx <= t1x; bx++) {
      const b = this.nodeBuckets.get(by * 1000 + bx);
      if (b) for (const n of b) if ((n.x - px) ** 2 + (n.y - py) ** 2 <= radius * radius) out.push(n);
    }
    return out;
  }

  reveal(px: number, py: number, radiusTiles: number) {
    const cx = Math.floor(px / TILE), cy = Math.floor(py / TILE);
    const r = Math.ceil(radiusTiles);
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
      if (dx * dx + dy * dy > radiusTiles * radiusTiles) continue;
      const tx = cx + dx, ty = cy + dy;
      if (this.inBounds(tx, ty)) this.explored[this.idx(tx, ty)] = 1;
    }
  }

  // ---------------- Rendering helpers ----------------
  getChunk(cx: number, cy: number): HTMLCanvasElement {
    const key = cy * 1000 + cx;
    let c = this.chunkCache.get(key);
    if (c) return c;
    c = document.createElement('canvas');
    c.width = c.height = CHUNK * TILE;
    const g = c.getContext('2d')!;
    for (let y = 0; y < CHUNK; y++) for (let x = 0; x < CHUNK; x++) {
      const tx = cx * CHUNK + x, ty = cy * CHUNK + y;
      if (!this.inBounds(tx, ty)) { g.fillStyle = '#111'; g.fillRect(x * TILE, y * TILE, TILE, TILE); continue; }
      this.drawTile(g, tx, ty, x * TILE, y * TILE);
    }
    this.chunkCache.set(key, c);
    return c;
  }

  private drawTile(g: CanvasRenderingContext2D, tx: number, ty: number, x: number, y: number) {
    const t = this.tileAt(tx, ty);
    const s = this.shade[this.idx(tx, ty)];
    g.fillStyle = shadeColor(TILE_COLORS[t], s);
    g.fillRect(x, y, TILE, TILE);
    const h = hash2(tx, ty, 31);
    switch (t) {
      case T.Grass:
      case T.Forest:
        g.fillStyle = shadeColor(TILE_COLORS[t], s + 0.12);
        for (let i = 0; i < 3; i++) {
          const gx = x + hash2(tx, ty, i) * 28 + 2, gy = y + hash2(ty, tx, i) * 28 + 2;
          g.fillRect(gx, gy, 2, 4);
        }
        break;
      case T.Water:
      case T.DeepWater:
        if (h < 0.3) { g.fillStyle = 'rgba(255,255,255,0.12)'; g.fillRect(x + h * 20, y + 12, 10, 2); }
        break;
      case T.Mountain:
        g.fillStyle = shadeColor('#4e4740', s);
        g.beginPath(); g.moveTo(x + 2, y + TILE); g.lineTo(x + 16, y + 4 + h * 8); g.lineTo(x + 30, y + TILE); g.fill();
        g.fillStyle = 'rgba(255,255,255,0.15)';
        g.beginPath(); g.moveTo(x + 12, y + 10 + h * 8); g.lineTo(x + 16, y + 4 + h * 8); g.lineTo(x + 20, y + 10 + h * 8); g.fill();
        break;
      case T.Wall: {
        const grd = g.createLinearGradient(x, y, x + TILE, y + TILE);
        grd.addColorStop(0, 'rgba(200,190,255,0.5)'); grd.addColorStop(1, 'rgba(110,90,200,0.2)');
        g.fillStyle = grd; g.fillRect(x, y, TILE, TILE);
        g.fillStyle = 'rgba(255,255,255,0.18)'; g.fillRect(x + ((tx + ty) % 4) * 8, y, 2, TILE);
        break;
      }
      case T.Floor:
        g.strokeStyle = 'rgba(0,0,0,0.12)'; g.strokeRect(x + 0.5, y + 0.5, TILE - 1, TILE - 1);
        break;
      case T.Ruin:
        g.strokeStyle = 'rgba(0,0,0,0.25)';
        g.beginPath(); g.moveTo(x + h * 30, y); g.lineTo(x + 16, y + 16); g.lineTo(x + 30 - h * 10, y + TILE); g.stroke();
        break;
      case T.Corrupt:
        if (h < 0.25) { g.fillStyle = 'rgba(160,60,160,0.35)'; g.beginPath(); g.arc(x + 16, y + 16, 4 + h * 20, 0, 7); g.fill(); }
        break;
      case T.Swamp:
        if (h < 0.4) { g.fillStyle = 'rgba(30,60,40,0.5)'; g.beginPath(); g.ellipse(x + 16, y + 16, 10, 5, 0, 0, 7); g.fill(); }
        break;
      case T.Road:
        if (h < 0.3) { g.fillStyle = 'rgba(0,0,0,0.1)'; g.fillRect(x + h * 24, y + h * 24, 4, 3); }
        break;
      case T.CityWall:
        g.fillStyle = '#6e6862'; g.fillRect(x + 1, y + 1, 14, 14); g.fillRect(x + 17, y + 17, 14, 14);
        g.fillStyle = '#4b4743'; g.fillRect(x + 17, y + 1, 14, 14); g.fillRect(x + 1, y + 17, 14, 14);
        break;
      case T.House:
        g.fillStyle = '#6e2a20'; g.fillRect(x, y + 20, TILE, 12);
        g.fillStyle = 'rgba(255,255,255,0.08)'; g.fillRect(x, y + 4, TILE, 3);
        break;
    }
  }

  buildMinimapBase() {
    const img = new ImageData(MAP_W, MAP_H);
    for (let i = 0; i < MAP_W * MAP_H; i++) {
      const c = hexToRgb(TILE_COLORS[this.tiles[i]]);
      img.data[i * 4] = c[0]; img.data[i * 4 + 1] = c[1]; img.data[i * 4 + 2] = c[2]; img.data[i * 4 + 3] = 255;
    }
    this.minimapBase = img;
  }
}

export function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function shadeColor(hex: string, amt: number): string {
  const [r, g, b] = hexToRgb(hex);
  const f = (v: number) => Math.max(0, Math.min(255, Math.round(v + amt * 255)));
  return `rgb(${f(r)},${f(g)},${f(b)})`;
}

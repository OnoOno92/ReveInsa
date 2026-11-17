// The aperture is a backpack-style grid. Gu occupy shaped cells; adjacency
// between Gu produces auras, path resonance and killer moves.
import { GU, KILLER_MOVES, type AttackSpec, type GuDef, type KillerMoveDef, type StatSpec } from '../data/gu';

export interface GuInstance { uid: number; defId: string; daysUnfed: number }
export interface PlacedGu { uid: number; x: number; y: number; rot: number }

export const RANK_NAMES = ['', 'Rank 1', 'Rank 2', 'Rank 3', 'Rank 4', 'Rank 5'];
export const STAGE_NAMES = ['Initial Stage', 'Middle Stage', 'Upper Stage', 'Peak Stage'];
// Primeval essence colour per rank (green copper, red steel, white silver, yellow gold, purple crystal)
export const ESSENCE_COLORS = ['', '#3fae6a', '#c0392b', '#dfe6e9', '#f1c40f', '#8e44ad'];
export const ESSENCE_NAMES = ['', 'Green Copper', 'Red Steel', 'White Silver', 'Yellow Gold', 'Purple Crystal'];

export function apertureSize(rank: number) { return 3 + rank; } // rank1 = 4x4 ... rank5 = 8x8

export function shapeCells(def: GuDef, rot: number): Array<[number, number]> {
  let cells = def.shape.map(([x, y]) => [x, y] as [number, number]);
  for (let i = 0; i < ((rot % 4) + 4) % 4; i++) cells = cells.map(([x, y]) => [-y, x] as [number, number]);
  const mx = Math.min(...cells.map(c => c[0])), my = Math.min(...cells.map(c => c[1]));
  return cells.map(([x, y]) => [x - mx, y - my] as [number, number]);
}

export function occupancy(size: number, placed: PlacedGu[], gu: GuInstance[], ignoreUid = -1): Int32Array {
  const occ = new Int32Array(size * size);
  for (const p of placed) {
    if (p.uid === ignoreUid) continue;
    const inst = gu.find(g => g.uid === p.uid);
    if (!inst) continue;
    for (const [cx, cy] of shapeCells(GU[inst.defId], p.rot)) {
      const x = p.x + cx, y = p.y + cy;
      if (x >= 0 && y >= 0 && x < size && y < size) occ[y * size + x] = p.uid;
    }
  }
  return occ;
}

export function canPlace(size: number, placed: PlacedGu[], gu: GuInstance[], defId: string, x: number, y: number, rot: number, ignoreUid = -1): boolean {
  const occ = occupancy(size, placed, gu, ignoreUid);
  for (const [cx, cy] of shapeCells(GU[defId], rot)) {
    const px = x + cx, py = y + cy;
    if (px < 0 || py < 0 || px >= size || py >= size) return false;
    if (occ[py * size + px] !== 0) return false;
  }
  return true;
}

/** uid -> set of adjacent uids (orthogonal neighbours) */
export function adjacency(size: number, placed: PlacedGu[], gu: GuInstance[]): Map<number, Set<number>> {
  const occ = occupancy(size, placed, gu);
  const adj = new Map<number, Set<number>>();
  for (const p of placed) adj.set(p.uid, new Set());
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const a = occ[y * size + x];
    if (!a) continue;
    const check = (nx: number, ny: number) => {
      if (nx >= size || ny >= size) return;
      const b = occ[ny * size + nx];
      if (b && b !== a) { adj.get(a)?.add(b); adj.get(b)?.add(a); }
    };
    check(x + 1, y); check(x, y + 1);
  }
  return adj;
}

export interface AttackSkill extends AttackSpec { key: string; name: string; isKiller: boolean }
export interface HealSkill { key: string; name: string; amount: number; cooldown: number; cost: number }

export interface Build {
  attacks: AttackSkill[];
  heals: HealSkill[];
  stats: Required<StatSpec>;
  synergies: string[];
  killerMoves: KillerMoveDef[];
  inactive: Set<number>; // uids not functioning (starving)
}

const emptyStats = (): Required<StatSpec> => ({
  armor: 0, maxHp: 0, hpRegen: 0, maxEssence: 0, essenceRegen: 0, moveSpeed: 0,
  damageMult: 0, shield: 0, lightRadius: 0, reveal: 0, pickup: 0,
});

function addStats(into: Required<StatSpec>, s?: StatSpec) {
  if (!s) return;
  for (const k of Object.keys(s) as Array<keyof StatSpec>) into[k] += s[k] ?? 0;
}

export function isStarving(inst: GuInstance) { return inst.daysUnfed > GU[inst.defId].feedEvery; }

export function computeBuild(rank: number, placed: PlacedGu[], gu: GuInstance[]): Build {
  const size = apertureSize(rank);
  const stats = emptyStats();
  const synergies: string[] = [];
  const inactive = new Set<number>();
  const active = placed.filter(p => {
    const inst = gu.find(g => g.uid === p.uid);
    if (!inst) return false;
    if (isStarving(inst)) { inactive.add(p.uid); return false; }
    return true;
  });
  const defOf = (uid: number) => GU[gu.find(g => g.uid === uid)!.defId];
  const adj = adjacency(size, active, gu);

  // Passive stats
  for (const p of active) addStats(stats, defOf(p.uid).stats);

  // Attacks with auras + path resonance
  const attacks: AttackSkill[] = [];
  const heals: HealSkill[] = [];
  for (const p of active) {
    const def = defOf(p.uid);
    if (def.heal) heals.push({ key: 'h' + p.uid, name: def.name, ...def.heal });
    if (!def.attack) continue;
    const a: AttackSkill = { ...def.attack, key: 'a' + p.uid, name: def.name, isKiller: false };
    let dmgMult = 1, cdMult = 1, costMult = 1;
    let resonance = 0;
    for (const n of adj.get(p.uid) ?? []) {
      const nd = defOf(n);
      if (nd.aura) {
        dmgMult += nd.aura.damageMult ?? 0;
        cdMult += nd.aura.cooldownMult ?? 0;
        costMult += nd.aura.costMult ?? 0;
        if (nd.aura.slow) a.slow = Math.max(a.slow ?? 0, nd.aura.slow);
        if (nd.aura.rangeAdd) a.range += nd.aura.rangeAdd;
        synergies.push(`${nd.name} empowers ${def.name}`);
      }
      if (nd.path === def.path && n !== p.uid) resonance++;
    }
    if (resonance > 0) {
      dmgMult += 0.15 * resonance;
      synergies.push(`${def.name}: ${def.path} path resonance ×${resonance} (+${15 * resonance}% dmg)`);
    }
    a.damage *= dmgMult;
    a.cooldown *= Math.max(0.3, cdMult);
    a.cost *= Math.max(0.2, costMult);
    attacks.push(a);
  }

  // Killer moves: all required Gu present and connected
  const killerMoves: KillerMoveDef[] = [];
  for (const km of KILLER_MOVES) {
    if (rank < km.minRank) continue;
    const members: number[] = [];
    let ok = true;
    for (const req of km.requires) {
      const p = active.find(pp => defOf(pp.uid).id === req && !members.includes(pp.uid));
      if (!p) { ok = false; break; }
      members.push(p.uid);
    }
    if (!ok) continue;
    // connectivity among members via adjacency (members may connect through each other only)
    const seen = new Set<number>([members[0]]);
    const stack = [members[0]];
    while (stack.length) {
      const u = stack.pop()!;
      for (const v of adj.get(u) ?? []) if (members.includes(v) && !seen.has(v)) { seen.add(v); stack.push(v); }
    }
    if (seen.size !== members.length) continue;
    killerMoves.push(km);
    addStats(stats, km.stats);
    if (km.attack) attacks.push({ ...km.attack, key: 'k' + km.id, name: km.name, isKiller: true });
  }

  for (const a of attacks) a.damage *= 1 + stats.damageMult;
  return { attacks, heals, stats, synergies, killerMoves, inactive };
}

/** Find any free spot for a Gu (used when auto-placing new Gu). */
export function findFreeSpot(size: number, placed: PlacedGu[], gu: GuInstance[], defId: string): { x: number; y: number; rot: number } | null {
  for (let rot = 0; rot < 4; rot++)
    for (let y = 0; y < size; y++) for (let x = 0; x < size; x++)
      if (canPlace(size, placed, gu, defId, x, y, rot)) return { x, y, rot };
  return null;
}

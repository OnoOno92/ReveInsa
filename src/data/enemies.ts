export type Zone = 'village' | 'city' | 'wild' | 'deep' | 'ruins' | 'forbidden' | 'wall';

export interface Drop { item: string; chance: number; min: number; max: number }

export interface EnemyDef {
  id: string;
  name: string;
  faction: 'beast' | 'demonic';
  hp: number;
  speed: number;
  damage: number;
  attackCd: number;
  radius: number;
  color: string;
  aggro: number;
  drops: Drop[];
  stones: [number, number];
  guDrop?: { pool: string[]; chance: number };
  ranged?: { range: number; speed: number; damage: number; cd: number; color: string };
  boss?: boolean;
}

export const ENEMIES: Record<string, EnemyDef> = {
  wolf: {
    id: 'wolf', name: 'Grey Wolf', faction: 'beast', hp: 30, speed: 115, damage: 6, attackCd: 1, radius: 13,
    color: '#7d7d7d', aggro: 260, stones: [0, 1],
    drops: [{ item: 'meat', chance: 0.7, min: 1, max: 1 }, { item: 'pelt', chance: 0.4, min: 1, max: 1 }],
  },
  boar: {
    id: 'boar', name: 'Wild Boar', faction: 'beast', hp: 65, speed: 85, damage: 10, attackCd: 1.3, radius: 16,
    color: '#5b3a29', aggro: 180, stones: [0, 2],
    drops: [{ item: 'meat', chance: 1, min: 1, max: 2 }, { item: 'bone', chance: 0.5, min: 1, max: 1 }],
  },
  night_wolf: {
    id: 'night_wolf', name: 'Shadow Wolf', faction: 'beast', hp: 48, speed: 140, damage: 9, attackCd: 0.9, radius: 13,
    color: '#2c2c44', aggro: 340, stones: [1, 3],
    drops: [{ item: 'meat', chance: 0.6, min: 1, max: 1 }, { item: 'pelt', chance: 0.6, min: 1, max: 1 }],
  },
  thunder_wolf: {
    id: 'thunder_wolf', name: 'Thunder Crown Wolf', faction: 'beast', hp: 150, speed: 125, damage: 16, attackCd: 1, radius: 17,
    color: '#6b5bd6', aggro: 320, stones: [4, 9],
    drops: [{ item: 'thunder_crystal', chance: 0.8, min: 1, max: 2 }, { item: 'pelt', chance: 0.8, min: 1, max: 2 }],
    ranged: { range: 220, speed: 300, damage: 10, cd: 2.4, color: '#d9c7ff' },
  },
  demonic_master: {
    id: 'demonic_master', name: 'Demonic Gu Master', faction: 'demonic', hp: 80, speed: 90, damage: 8, attackCd: 1.2, radius: 13,
    color: '#7a1f3d', aggro: 300, stones: [8, 20],
    drops: [{ item: 'wine', chance: 0.3, min: 1, max: 2 }, { item: 'moon_orchid', chance: 0.3, min: 1, max: 3 }],
    guDrop: { pool: ['moonlight', 'stone_skin', 'spider_silk', 'wind_blade', 'liquor_worm', 'jade_bone'], chance: 0.18 },
    ranged: { range: 260, speed: 340, damage: 9, cd: 1.6, color: '#ff6b9a' },
  },
  poison_toad: {
    id: 'poison_toad', name: 'Mire Poison Toad', faction: 'beast', hp: 110, speed: 70, damage: 14, attackCd: 1.2, radius: 18,
    color: '#3f6b2a', aggro: 220, stones: [3, 6],
    drops: [{ item: 'herb', chance: 0.8, min: 1, max: 3 }, { item: 'bone', chance: 0.5, min: 1, max: 2 }],
    ranged: { range: 180, speed: 220, damage: 12, cd: 2.8, color: '#9cff57' },
  },
  bear_king: {
    id: 'bear_king', name: 'Mire Bear King', faction: 'beast', hp: 900, speed: 95, damage: 28, attackCd: 1.4, radius: 30,
    color: '#3b2516', aggro: 380, stones: [80, 140], boss: true,
    drops: [{ item: 'beast_core', chance: 1, min: 1, max: 1 }, { item: 'meat', chance: 1, min: 4, max: 6 }, { item: 'bone', chance: 1, min: 3, max: 5 }],
    guDrop: { pool: ['bear_strength', 'fire_ember', 'jade_skin'], chance: 0.5 },
  },
};

// Spawn weights by zone and time of day.
export function spawnTable(zone: Zone, night: boolean, danger: number): Array<[string, number]> {
  switch (zone) {
    case 'wild':
      return night
        ? [['night_wolf', 4], ['wolf', 3], ['boar', 1], ...(danger > 0.5 ? [['thunder_wolf', 1]] as Array<[string, number]> : [])]
        : [['wolf', 4], ['boar', 3], ...(danger > 0.6 ? [['demonic_master', 1]] as Array<[string, number]> : [])];
    case 'deep':
      return night
        ? [['night_wolf', 4], ['thunder_wolf', 2], ['boar', 1]]
        : [['wolf', 3], ['boar', 3], ['thunder_wolf', 1], ['demonic_master', 1]];
    case 'ruins':
      return [['demonic_master', 5], ['night_wolf', night ? 2 : 0]];
    case 'forbidden':
      return [['poison_toad', 4], ['thunder_wolf', 2], ['night_wolf', night ? 3 : 1]];
    default:
      return [];
  }
}

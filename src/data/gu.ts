// Gu definitions. Each Gu occupies a shape inside the aperture grid.
// Placement + adjacency drives synergies and killer moves (see game/aperture.ts).

export type DaoPath =
  | 'moon' | 'strength' | 'earth' | 'water' | 'fire' | 'wood'
  | 'wind' | 'lightning' | 'information' | 'enslavement';

export const PATH_COLORS: Record<DaoPath, string> = {
  moon: '#9ecbff',
  strength: '#c0743a',
  earth: '#b39b6b',
  water: '#3fa7d6',
  fire: '#ef5b3c',
  wood: '#5cb85c',
  wind: '#8fe3c8',
  lightning: '#c9a6ff',
  information: '#f2d36b',
  enslavement: '#d16ba5',
};

export const PATH_NAMES: Record<DaoPath, string> = {
  moon: 'Moon Path', strength: 'Strength Path', earth: 'Earth Path', water: 'Water Path',
  fire: 'Fire Path', wood: 'Wood Path', wind: 'Wind Path', lightning: 'Lightning Path',
  information: 'Information Path', enslavement: 'Enslavement Path',
};

export type GuRole = 'attack' | 'defense' | 'support' | 'heal' | 'passive' | 'utility';

export interface AttackSpec {
  kind: 'projectile' | 'fan' | 'nova' | 'chain';
  damage: number;
  cooldown: number; // seconds
  range: number;    // px
  cost: number;     // primeval essence per cast
  speed?: number;   // projectile speed
  count?: number;   // fan projectiles / chain jumps
  spread?: number;  // fan spread in radians
  pierce?: number;
  slow?: number;    // 0..1 slow applied on hit
  radius?: number;  // nova radius
  size?: number;    // projectile radius
  color: string;
}

export interface StatSpec {
  armor?: number;
  maxHp?: number;
  hpRegen?: number;
  maxEssence?: number;
  essenceRegen?: number; // multiplier add, 0.2 = +20%
  moveSpeed?: number;    // multiplier add
  damageMult?: number;   // multiplier add to all attacks
  shield?: number;
  lightRadius?: number;
  reveal?: number;       // minimap reveal radius in tiles
  pickup?: number;       // loot magnet radius px
}

export interface AuraSpec {
  // Applied to every ATTACK Gu orthogonally adjacent to this Gu.
  damageMult?: number;
  cooldownMult?: number; // e.g. -0.15 => 15% faster
  costMult?: number;     // e.g. -0.2 => 20% cheaper
  slow?: number;
  rangeAdd?: number;
}

export interface HealSpec { amount: number; cooldown: number; cost: number }

export interface GuDef {
  id: string;
  name: string;
  path: DaoPath;
  rank: number;
  role: GuRole;
  shape: Array<[number, number]>;
  desc: string;
  food: string;      // item id it eats
  feedEvery: number; // days between feedings
  price: number;     // base price in primeval stones
  attack?: AttackSpec;
  stats?: StatSpec;
  aura?: AuraSpec;
  heal?: HealSpec;
}

const G = (d: GuDef) => d;

export const GU_LIST: GuDef[] = [
  // ---------------- Rank 1 ----------------
  G({
    id: 'moonlight', name: 'Moonlight Gu', path: 'moon', rank: 1, role: 'attack',
    shape: [[0, 0]], food: 'moon_orchid', feedEvery: 3, price: 25,
    desc: 'Fires a pale crescent of moonlight at the nearest foe. The most common attack Gu in the Southern Border.',
    attack: { kind: 'projectile', damage: 10, cooldown: 0.9, range: 240, cost: 1.5, speed: 420, size: 7, color: '#bfe0ff' },
  }),
  G({
    id: 'wind_blade', name: 'Wind Blade Gu', path: 'wind', rank: 1, role: 'attack',
    shape: [[0, 0], [0, 1]], food: 'herb', feedEvery: 2, price: 40,
    desc: 'Condenses a thin blade of wind that pierces through two foes.',
    attack: { kind: 'projectile', damage: 8, cooldown: 1.2, range: 290, cost: 1.8, speed: 560, pierce: 2, size: 5, color: '#a8f5dc' },
  }),
  G({
    id: 'liquor_worm', name: 'Liquor Worm', path: 'wood', rank: 1, role: 'support',
    shape: [[0, 0], [1, 0]], food: 'wine', feedEvery: 2, price: 45,
    desc: 'Refines primeval essence. Adjacent attack Gu deal +30% damage and cost 20% less essence.',
    aura: { damageMult: 0.3, costMult: -0.2 },
  }),
  G({
    id: 'spider_silk', name: 'Spider Silk Gu', path: 'enslavement', rank: 1, role: 'support',
    shape: [[0, 0]], food: 'meat', feedEvery: 2, price: 35,
    desc: 'Coats adjacent attacks in sticky silk: hits slow enemies by 35%.',
    aura: { slow: 0.35 },
  }),
  G({
    id: 'stone_skin', name: 'Stone Skin Gu', path: 'earth', rank: 1, role: 'defense',
    shape: [[0, 0], [0, 1]], food: 'stone', feedEvery: 3, price: 30,
    desc: 'Hardens the skin like rock. +4 armor.',
    stats: { armor: 4 },
  }),
  G({
    id: 'black_boar', name: 'Black Boar Gu', path: 'strength', rank: 1, role: 'passive',
    shape: [[0, 0], [0, 1], [1, 1]], food: 'meat', feedEvery: 2, price: 45,
    desc: 'Grants the strength of a black boar. +30 max HP, +10% damage.',
    stats: { maxHp: 30, damageMult: 0.1 },
  }),
  G({
    id: 'vitality_leaf', name: 'Vitality Leaf Gu', path: 'wood', rank: 1, role: 'heal',
    shape: [[0, 0]], food: 'herb', feedEvery: 2, price: 30,
    desc: 'Restores 18 HP when you are wounded (6s cooldown).',
    heal: { amount: 18, cooldown: 6, cost: 4 },
  }),
  G({
    id: 'water_shield', name: 'Water Shield Gu', path: 'water', rank: 1, role: 'defense',
    shape: [[0, 0], [1, 0]], food: 'herb', feedEvery: 3, price: 50,
    desc: 'A film of water absorbs up to 25 damage and slowly reforms.',
    stats: { shield: 25 },
  }),
  G({
    id: 'earth_ear', name: 'Earth Communication Ear Grass', path: 'information', rank: 1, role: 'utility',
    shape: [[0, 0]], food: 'herb', feedEvery: 4, price: 35,
    desc: 'Listens through the earth. Reveals a much wider area of the map and widens your night vision.',
    stats: { reveal: 10, lightRadius: 60 },
  }),
  G({
    id: 'jade_bone', name: 'Jade Bone Gu', path: 'earth', rank: 1, role: 'utility',
    shape: [[0, 0]], food: 'stone', feedEvery: 4, price: 30,
    desc: 'Lightens the bones. +12% move speed and a wider loot pickup radius.',
    stats: { moveSpeed: 0.12, pickup: 40 },
  }),

  // ---------------- Rank 2 ----------------
  G({
    id: 'moon_glow', name: 'Moon Glow Gu', path: 'moon', rank: 2, role: 'attack',
    shape: [[0, 0], [1, 0], [0, 1], [1, 1]], food: 'moon_orchid', feedEvery: 3, price: 160,
    desc: 'A full moon blade that pierces through 3 foes.',
    attack: { kind: 'projectile', damage: 24, cooldown: 1.4, range: 270, cost: 3.5, speed: 380, pierce: 3, size: 12, color: '#d9ecff' },
  }),
  G({
    id: 'thunder_bead', name: 'Thunder Bead Gu', path: 'lightning', rank: 2, role: 'attack',
    shape: [[0, 0], [1, 0], [1, 1]], food: 'thunder_crystal', feedEvery: 4, price: 170,
    desc: 'Lightning leaps between up to 3 enemies.',
    attack: { kind: 'chain', damage: 18, cooldown: 1.8, range: 230, cost: 4, count: 3, color: '#e3d0ff' },
  }),
  G({
    id: 'fire_ember', name: 'Fire Ember Gu', path: 'fire', rank: 2, role: 'attack',
    shape: [[0, 0], [1, 0], [2, 0], [1, 1]], food: 'meat', feedEvery: 2, price: 150,
    desc: 'Erupts in a ring of flame around you, burning all nearby foes.',
    attack: { kind: 'nova', damage: 20, cooldown: 2.6, range: 110, radius: 110, cost: 4, color: '#ff8a4c' },
  }),
  G({
    id: 'jade_skin', name: 'White Jade Gu', path: 'earth', rank: 2, role: 'defense',
    shape: [[0, 0], [1, 0], [2, 0]], food: 'stone', feedEvery: 3, price: 140,
    desc: 'Skin like white jade. +9 armor, +20 max HP.',
    stats: { armor: 9, maxHp: 20 },
  }),
  G({
    id: 'four_flavors', name: 'Four Flavors Liquor Worm', path: 'wood', rank: 2, role: 'support',
    shape: [[0, 0], [1, 0], [0, 1]], food: 'wine', feedEvery: 2, price: 200,
    desc: 'A refined liquor worm. Adjacent attack Gu: +50% damage, 15% faster, 25% cheaper.',
    aura: { damageMult: 0.5, cooldownMult: -0.15, costMult: -0.25 },
  }),

  // ---------------- Rank 3 ----------------
  G({
    id: 'bear_strength', name: 'Bear Strength Gu', path: 'strength', rank: 3, role: 'passive',
    shape: [[0, 0], [1, 0], [0, 1], [1, 1]], food: 'meat', feedEvery: 2, price: 420,
    desc: 'The might of a mountain bear. +80 max HP, +25% damage.',
    stats: { maxHp: 80, damageMult: 0.25 },
  }),
  G({
    id: 'thunder_crown', name: 'Thunder Crown Gu', path: 'lightning', rank: 3, role: 'attack',
    shape: [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1]], food: 'thunder_crystal', feedEvery: 3, price: 480,
    desc: 'A crown of thunder that arcs across 5 enemies.',
    attack: { kind: 'chain', damage: 34, cooldown: 2.0, range: 260, cost: 7, count: 5, color: '#f0e2ff' },
  }),
];

export const GU: Record<string, GuDef> = Object.fromEntries(GU_LIST.map(g => [g.id, g]));

// ---------------- Killer moves ----------------
// Active when every required Gu is placed AND they form one connected group in the aperture.
export interface KillerMoveDef {
  id: string;
  name: string;
  requires: string[];
  minRank: number;
  desc: string;
  attack?: AttackSpec;
  stats?: StatSpec;
}

export const KILLER_MOVES: KillerMoveDef[] = [
  {
    id: 'boar_stone_body', name: 'Boar Stone Body', requires: ['black_boar', 'stone_skin'], minRank: 1,
    desc: 'Strength and earth fuse: +5 armor and a ground stomp that shakes nearby foes.',
    stats: { armor: 5 },
    attack: { kind: 'nova', damage: 16, cooldown: 4, range: 95, radius: 95, cost: 5, color: '#c9a36b' },
  },
  {
    id: 'moon_shadow_web', name: 'Moon Shadow Web', requires: ['moonlight', 'spider_silk'], minRank: 1,
    desc: 'Silk-laced crescents fan out in threes, slowing all they touch.',
    attack: { kind: 'fan', damage: 9, cooldown: 2.2, range: 250, cost: 4, count: 3, spread: 0.5, speed: 400, slow: 0.5, size: 6, color: '#e7d6ff' },
  },
  {
    id: 'crescent_tide', name: 'Crescent Tide', requires: ['moonlight', 'moon_glow', 'liquor_worm'], minRank: 2,
    desc: 'A tide of seven moon blades sweeps the field.',
    attack: { kind: 'fan', damage: 16, cooldown: 3.5, range: 300, cost: 10, count: 7, spread: 1.0, speed: 440, pierce: 2, size: 9, color: '#cfe8ff' },
  },
  {
    id: 'thunderwind_lance', name: 'Thunderwind Lance', requires: ['wind_blade', 'thunder_bead'], minRank: 2,
    desc: 'Wind carries the thunder: a storm arc jumping across 6 enemies.',
    attack: { kind: 'chain', damage: 30, cooldown: 3, range: 300, cost: 9, count: 6, color: '#b6fff0' },
  },
  {
    id: 'verdant_flame', name: 'Verdant Flame Rebirth', requires: ['fire_ember', 'vitality_leaf'], minRank: 2,
    desc: 'Wood feeds fire: a huge flame ring, and the ashes heal you (+1.5 HP/s).',
    stats: { hpRegen: 1.5 },
    attack: { kind: 'nova', damage: 38, cooldown: 5, range: 150, radius: 150, cost: 10, color: '#ffb347' },
  },
];

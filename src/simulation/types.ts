import type {
  InventoryState,
  BiomeDefinition,
  ResourceDrop,
  ResourceNode,
  SurvivalRole,
  UnitCargo,
  UnitTask,
  PlacedCampfire,
  WorldDecoration,
  ResourceAmounts,
  TechnologyId,
} from './survivalTypes';

export type Vec2 = {
  x: number;
  y: number;
};

export type GamePhase = 'playing' | 'paused' | 'victory' | 'defeat';

export type TotemState = {
  position: Vec2;
  dragTarget: Vec2 | null;
  destination: Vec2 | null;
  moving: boolean;
  isCarried: boolean;
  commandRadius: number;
  dangerRadius: number;
  bondEnergy: number;
};

export type UnitState = {
  id: string;
  position: Vec2;
  role: SurvivalRole;
  hasShield: boolean;
  health: number;
  maxHealth: number;
  healingProgressSeconds: number;
  state:
    | 'follow-totem'
    | 'formation'
    | 'seeking-task'
    | 'gathering'
    | 'collecting-drop'
    | 'combat'
    | 'fleeing'
    | 'looting-corpse'
    | 'hunting'
    | 'returning-to-totem'
    | 'idle';
  cargo: UnitCargo;
  task: UnitTask;
  cancelledTargetId: string | null;
  actionProgressSeconds: number;
  attackCooldownRemainingSeconds: number;
  attackLockRemainingSeconds: number;
  withdrawAfterAttack: boolean;
};

export type UnitCorpse = {
  id: string;
  formerUnitId: string;
  position: Vec2;
};

export type BarbarianState = {
  id: string;
  position: Vec2;
  spawnPosition: Vec2;
  patrolCenter: Vec2;
  patrolTarget: Vec2;
  patrolRadius: number;
  patrolWaitRemainingSeconds: number;
  patrolStep: number;
  returningToSpawn: boolean;
  health: number;
  maxHealth: number;
  isAlive: boolean;
  respawnRemainingSeconds: number;
  attackProgressSeconds: number;
  targetUnitId: string | null;
  alertedUnitIds: string[];
  alertSoundedThisEncounter: boolean;
  spawnCycle: number;
};

export type AnimalState = {
  id: string;
  kind: 'rabbit';
  position: Vec2;
  spawnPosition: Vec2;
  homeCenter: Vec2;
  homeRadius: number;
  patrolTarget: Vec2;
  health: number;
  maxHealth: number;
  isAlive: boolean;
  respawnRemainingSeconds: number;
  attackProgressSeconds: number;
  spawnCycle: number;
};

export type BarbarianCorpse = {
  id: string;
  barbarianId: string;
  position: Vec2;
  loot: ResourceAmounts;
};

export type DetectionAlert = {
  id: string;
  detectorKind: 'minion' | 'barbarian';
  detectorId: string;
  position: Vec2;
  ageSeconds: number;
  durationSeconds: number;
  playSound: boolean;
};

export type WeatherCloudPhase = 'approaching' | 'raining' | 'departing';

export type WeatherCloudState = {
  id: string;
  position: Vec2;
  targetBiomeInstanceId: string;
  phase: WeatherCloudPhase;
  phaseElapsedSeconds: number;
  rainRemainingSeconds: number;
};

export type WeatherState = {
  nextCloudInSeconds: number;
  nextCloudIndex: number;
  clouds: WeatherCloudState[];
};

export type SimulationEffect = {
  id: string;
  kind: 'damage-flash' | 'heal-crosses' | 'attack-lunge';
  targetId: string;
  position: Vec2;
  ageSeconds: number;
  durationSeconds: number;
};

export type MinionPurchaseCounts = {
  gatherer: number;
  lumberjack: number;
  hunter: number;
  guardian: number;
  artisan: number;
};

export type ProgressionState = {
  level: number;
  experience: number;
  experienceToNextLevel: number;
  technologyPoints: number;
  unlockedTechnologies: TechnologyId[];
};

export type GameState = {
  version: 16;
  seed: string;
  tick: number;
  phase: GamePhase;
  totem: TotemState;
  units: UnitState[];
  corpses: UnitCorpse[];
  barbarians: BarbarianState[];
  animals: AnimalState[];
  barbarianCorpses: BarbarianCorpse[];
  /** Monotonic counters used to give purchased minions unique ids, never for pricing. */
  purchaseCounts: MinionPurchaseCounts;
  progression: ProgressionState;
  biomes: BiomeDefinition[];
  resources: ResourceNode[];
  decorations: WorldDecoration[];
  drops: ResourceDrop[];
  nextDropId: number;
  campfires: PlacedCampfire[];
  nextCampfireId: number;
  inventory: InventoryState;
  effects: SimulationEffect[];
  nextEffectId: number;
  alerts: DetectionAlert[];
  nextAlertId: number;
  weather: WeatherState;
};

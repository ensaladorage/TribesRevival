import type { Vec2 } from './types';

export const RESOURCE_TYPES = ['food', 'wood', 'stone', 'spark', 'gold'] as const;
export type ResourceType = (typeof RESOURCE_TYPES)[number];
export const BIOME_RESOURCE_TYPES = ['food', 'wood', 'stone', 'spark'] as const;

export const CAMPFIRE_WOOD_COST = 2;
export const CAMPFIRE_HEALING_RADIUS = 15;
export const MAX_ACTIVE_CAMPFIRES = 2;
export const CAMPFIRE_LIFETIME_SECONDS = 120;
export const CAMPFIRE_TOTEM_MAX_DISTANCE = 30;

export type SpecializationItem = 'axe' | 'bow' | 'sword' | 'hammer';
export type TechnologyId = 'artisan' | 'shield';

export const BIOME_IDS = ['clearing', 'meadow', 'forest', 'rocky', 'ruins'] as const;
export const RESOURCE_BIOME_IDS = ['meadow', 'forest', 'rocky', 'ruins'] as const;
export type BiomeId = (typeof BIOME_IDS)[number] | 'great-fire';

export const SURVIVAL_ROLES = [
  'explorer',
  'gatherer',
  'lumberjack',
  'hunter',
  'guardian',
  'artisan',
] as const;
export type SurvivalRole = (typeof SURVIVAL_ROLES)[number];

export type ResourceAmounts = Record<ResourceType, number>;

export function createEmptyResourceAmounts(): ResourceAmounts {
  return {
    food: 0,
    wood: 0,
    stone: 0,
    spark: 0,
    gold: 0,
  };
}

export type ResourceNode = {
  id: string;
  type: ResourceType;
  source: 'berry-bush' | 'tree' | 'stone-vein' | 'ruin' | 'twigs';
  biome: BiomeId;
  biomeInstanceId?: string;
  isSecondary: boolean;
  interactionRadius: number;
  position: Vec2;
  amount: number;
  maxAmount: number;
  gatherRate: number;
  /** Amount produced by a completed gather action; defaults to the node amount gathered. */
  yieldAmount?: number;
};

export type DecorativeKind = 'grass' | 'mushroom' | 'flower';
export type FlowerColor = 'yellow' | 'blue' | 'gray' | 'pink';

export type WorldDecoration = {
  id: string;
  kind: DecorativeKind;
  flowerColor?: FlowerColor;
  biome: BiomeId;
  biomeInstanceId: string;
  position: Vec2;
  scale: number;
};

export type ResourceDrop = {
  id: string;
  type: ResourceType;
  sourceNodeId: string | null;
  position: Vec2;
  amount: number;
};

export type InventoryState = {
  amounts: ResourceAmounts;
};

export type PlacedCampfire = {
  id: string;
  position: Vec2;
  healingRadius: number;
  remainingLifetimeSeconds: number;
};

export type UnitCargo = {
  amounts: ResourceAmounts;
  capacity: number;
};

export type TaskKind =
  | 'idle'
  | 'gather'
  | 'collect-drop'
  | 'return-to-totem'
  | 'combat'
  | 'flee'
  | 'loot-corpse'
  | 'hunt';

export type TaskCause =
  | 'resource-found'
  | 'resource-call-received'
  | 'resource-depleted'
  | 'over-capacity'
  | 'no-valid-resource'
  | 'totem-moved'
  | 'cargo-dropped'
  | 'drop-found'
  | 'drop-collected'
  | 'drop-empty'
  | 'animal-found'
  | 'corpse-found'
  | 'corpse-looted'
  | 'threat-nearby'
  | 'combat-ended'
  | 'action-complete';

export type UnitTask = {
  kind: TaskKind;
  targetResourceId: string | null;
  targetEntityId?: string | null;
  destination: Vec2 | null;
  cause: TaskCause;
};

export type BiomeDefinition = {
  id: BiomeId;
  instanceId: string;
  isDecorativeOnly: boolean;
  displayName: string;
  movementMultiplier: number;
  visibleResourceTypes: readonly ResourceType[];
  region: {
    x: number;
    y: number;
    size: number;
    shape: 'circle';
  };
};

export type SurvivalWorldBlueprint = {
  seed: string;
  biomes: readonly BiomeDefinition[];
  resources: readonly ResourceNode[];
  decorations: readonly WorldDecoration[];
};

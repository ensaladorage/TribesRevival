import { createSeededRandom } from './seededRandom';
import type {
  BiomeDefinition,
  BiomeId,
  DecorativeKind,
  FlowerColor,
  ResourceNode,
  ResourceType,
  SurvivalWorldBlueprint,
  WorldDecoration,
} from './survivalTypes';
import { BIOME_RESOURCE_TYPES, RESOURCE_BIOME_IDS } from './survivalTypes';
import type { AnimalState, BarbarianState, Vec2 } from './types';
import {
  BARBARIAN_ATTACK_COOLDOWN_SECONDS,
  BARBARIAN_MAX_HEALTH,
} from './survivalCombat';

export const DEFAULT_SURVIVAL_SEED = 'totem-tribes-hito-2a';
const WORLD_SIZE = 160;
type BiomeResourceType = (typeof BIOME_RESOURCE_TYPES)[number];

type BiomeTemplate = {
  displayName: string;
  movementMultiplier: number;
  visibleResourceTypes: readonly ResourceType[];
  primaryResourceType: BiomeResourceType | null;
};

export const BIOME_DEFINITIONS: Readonly<Record<BiomeId, BiomeTemplate>> = {
  clearing: {
    displayName: 'Claro',
    movementMultiplier: 1,
    visibleResourceTypes: ['wood'],
    primaryResourceType: null,
  },
  meadow: {
    displayName: 'Pradera',
    movementMultiplier: 1,
    visibleResourceTypes: ['food'],
    primaryResourceType: 'food',
  },
  forest: {
    displayName: 'Bosque',
    movementMultiplier: 0.8,
    visibleResourceTypes: ['wood'],
    primaryResourceType: 'wood',
  },
  rocky: {
    displayName: 'Pedregal',
    movementMultiplier: 0.65,
    visibleResourceTypes: ['stone'],
    primaryResourceType: 'stone',
  },
  ruins: {
    displayName: 'Ruinas',
    movementMultiplier: 0.75,
    visibleResourceTypes: ['spark'],
    primaryResourceType: 'spark',
  },
  'great-fire': {
    displayName: 'Gran Hoguera',
    movementMultiplier: 1,
    visibleResourceTypes: [],
    primaryResourceType: null,
  },
};

export type BiomeGenerationConfig = {
  totalBiomes: number;
  minRadius: number;
  maxRadius: number;
  minimumBiomeGap: number;
  maxPlacementAttempts: number;
  minResourceNodesPerBiome: number;
  maxResourceNodesPerBiome: number;
  secondaryChance: number;
  secondaryAmountMultiplier: number;
  worldPadding: number;
  startingBiomeRadius: number;
  startingResourceExclusionRadius: number;
  decorativeBiomeCount: number;
  decorativeBiomeMinRadius: number;
  decorativeBiomeMaxRadius: number;
  activeResourceTypes?: readonly ResourceType[];
};

export const DEFAULT_BIOME_GENERATION_CONFIG: BiomeGenerationConfig = {
  totalBiomes: 10,
  minRadius: 6,
  maxRadius: 12,
  minimumBiomeGap: 0.5,
  maxPlacementAttempts: 160,
  minResourceNodesPerBiome: 1,
  maxResourceNodesPerBiome: 3,
  secondaryChance: 0.38,
  secondaryAmountMultiplier: 0.4,
  worldPadding: 4,
  startingBiomeRadius: 12,
  startingResourceExclusionRadius: 2,
  decorativeBiomeCount: 0,
  decorativeBiomeMinRadius: 3,
  decorativeBiomeMaxRadius: 5,
};

/** At least half of the generated clearings, including the starting clearing, hold emergency twigs. */
export const TWIG_CLEARING_COVERAGE = 0.5;
export const TWIG_NODE_YIELD = 2;

/**
 * The first playable survival slice only exposes berry bushes. The other
 * biome types remain part of the deterministic map so later milestones can
 * activate their resource tables without changing world generation.
 */
export const HITO_2A_GENERATION_CONFIG: BiomeGenerationConfig = {
  ...DEFAULT_BIOME_GENERATION_CONFIG,
  activeResourceTypes: ['food'],
};

/**
 * Hito 2C.2 keeps the map readable while the playable resource set is small:
 * only berry bushes are functional, and the starting meadow has a safe ring
 * around the totem so the player must move before gathering.
 */
export const HITO_2C_GENERATION_CONFIG: BiomeGenerationConfig = {
  ...HITO_2A_GENERATION_CONFIG,
  totalBiomes: 10,
  minRadius: 7,
  maxRadius: 11,
  minimumBiomeGap: 0.5,
  maxPlacementAttempts: 320,
  minResourceNodesPerBiome: 1,
  maxResourceNodesPerBiome: 3,
  secondaryChance: 0.38,
  startingBiomeRadius: 5,
  startingResourceExclusionRadius: 12,
  decorativeBiomeCount: 12,
  decorativeBiomeMinRadius: 3,
  decorativeBiomeMaxRadius: 5,
};

/**
 * Hito 3 activates the complete resource catalogue. Wood is playable through
 * the existing lumberjack role; stone and spark remain visible and
 * serializable until a playable artisan/specialist is introduced.
 */
export const HITO_3_GENERATION_CONFIG: BiomeGenerationConfig = {
  ...HITO_2C_GENERATION_CONFIG,
  activeResourceTypes: BIOME_RESOURCE_TYPES,
};

const RESOURCE_AMOUNT_RANGES: Readonly<Record<(typeof BIOME_RESOURCE_TYPES)[number], readonly [number, number]>> = {
  food: [1, 1],
  wood: [1, 1],
  stone: [1, 1],
  spark: [1, 1],
};

const RESOURCE_SOURCES: Readonly<Record<(typeof BIOME_RESOURCE_TYPES)[number], ResourceNode['source']>> = {
  food: 'berry-bush',
  wood: 'tree',
  stone: 'stone-vein',
  spark: 'ruin',
};

const RESOURCE_INTERACTION_RADII: Readonly<Record<(typeof BIOME_RESOURCE_TYPES)[number], number>> = {
  food: 1.45,
  wood: 1.35,
  stone: 1.35,
  spark: 1.3,
};

function roundPosition(value: number): number {
  return Math.round(value * 100) / 100;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function randomPointInCircle(
  random: ReturnType<typeof createSeededRandom>,
  center: { x: number; y: number },
  radius: number,
  innerRadius = 0,
): { x: number; y: number } {
  const angle = random.nextFloat(0, Math.PI * 2);
  const distance = Math.sqrt(random.nextFloat(innerRadius ** 2, radius ** 2));
  return {
    x: roundPosition(center.x + Math.cos(angle) * distance),
    y: roundPosition(center.y + Math.sin(angle) * distance),
  };
}

function randomPointOutsideArea(
  random: ReturnType<typeof createSeededRandom>,
  center: { x: number; y: number },
  radius: number,
  innerRadius: number,
  exclusionCenter: { x: number; y: number },
  exclusionRadius: number,
): { x: number; y: number } {
  let point = randomPointInCircle(random, center, radius, innerRadius);
  for (let attempt = 0; attempt < 64; attempt += 1) {
    if (Math.hypot(point.x - exclusionCenter.x, point.y - exclusionCenter.y)
      >= exclusionRadius) {
      return point;
    }
    point = randomPointInCircle(random, center, radius, innerRadius);
  }
  return point;
}

type PlacedBiome = {
  id: BiomeId;
  x: number;
  y: number;
  radius: number;
  isResourceBiome: boolean;
  isStartingArea: boolean;
};

function canPlaceBiome(candidate: PlacedBiome, placed: readonly PlacedBiome[], gap: number): boolean {
  return placed.every((other) => {
    const distance = Math.hypot(candidate.x - other.x, candidate.y - other.y);
    return distance + 0.0001 >= candidate.radius + other.radius + gap;
  });
}

export function createBiomeRegions(
  seed = DEFAULT_SURVIVAL_SEED,
  config: BiomeGenerationConfig = DEFAULT_BIOME_GENERATION_CONFIG,
): BiomeDefinition[] {
  const random = createSeededRandom(`${seed}:biomes`);
  const resourceBiomeCount = Math.max(
    Math.ceil(config.totalBiomes),
    RESOURCE_BIOME_IDS.length,
  );
  const decorativeBiomeCount = Math.max(Math.floor(config.decorativeBiomeCount), 0);
  const biomeCount = resourceBiomeCount + decorativeBiomeCount + 1;
  const radiusMin = Math.max(config.minRadius, 2);
  const radiusMax = Math.max(config.maxRadius, radiusMin);
  const padding = Math.max(config.worldPadding, 0);
  const minimumGap = Math.max(config.minimumBiomeGap, 0);
  const placed: PlacedBiome[] = [];

  return Array.from({ length: biomeCount }, (_, index) => {
    const isStartingArea = index === 0;
    const resourceIndex = index - 1;
    const isResourceBiome = resourceIndex >= 0 && resourceIndex < resourceBiomeCount;
    const isDecorativeOnly = !isResourceBiome;
    const biome: BiomeId = isStartingArea || !isResourceBiome
      ? 'clearing'
      : resourceIndex < RESOURCE_BIOME_IDS.length
        ? RESOURCE_BIOME_IDS[resourceIndex]
        : RESOURCE_BIOME_IDS[random.nextInt(0, RESOURCE_BIOME_IDS.length - 1)];
    let selected: PlacedBiome | undefined;

    if (isStartingArea) {
      selected = {
        id: biome,
        x: 80,
        y: 80,
        radius: Math.min(
          Math.max(config.startingBiomeRadius, 2),
          radiusMin - 0.1,
        ),
        isResourceBiome: false,
        isStartingArea: true,
      };
    } else {
      for (let attempt = 0; attempt < Math.max(config.maxPlacementAttempts, 1); attempt += 1) {
        const radius = isDecorativeOnly
          ? random.nextFloat(
            Math.max(config.decorativeBiomeMinRadius, 2),
            Math.max(config.decorativeBiomeMaxRadius, config.decorativeBiomeMinRadius, 2),
          )
          : random.nextFloat(radiusMin, radiusMax);
        const candidate = {
          id: biome,
          x: random.nextFloat(padding + radius, WORLD_SIZE - padding - radius),
          y: random.nextFloat(padding + radius, WORLD_SIZE - padding - radius),
          radius,
          isResourceBiome,
          isStartingArea: false,
        };
        if (canPlaceBiome(candidate, placed, minimumGap)) {
          selected = candidate;
          break;
        }
      }
    }

    if (!selected) {
      throw new Error(
        `Unable to place biome ${biome} without overlapping another biome; reduce totalBiomes, radius, or decorativeBiomeCount`,
      );
    }

    placed.push(selected);

    return {
      id: biome,
      instanceId: `biome-${String(index + 1).padStart(2, '0')}`,
      isDecorativeOnly,
      displayName: BIOME_DEFINITIONS[biome].displayName,
      movementMultiplier: BIOME_DEFINITIONS[biome].movementMultiplier,
      visibleResourceTypes: BIOME_DEFINITIONS[biome].visibleResourceTypes,
      region: {
        x: roundPosition(clamp(selected.x, padding + selected.radius, WORLD_SIZE - padding - selected.radius)),
        y: roundPosition(clamp(selected.y, padding + selected.radius, WORLD_SIZE - padding - selected.radius)),
        size: roundPosition(selected.radius * 2),
        shape: 'circle' as const,
      },
    };
  });
}

export function createResourceNodes(
  seed = DEFAULT_SURVIVAL_SEED,
  config: BiomeGenerationConfig = DEFAULT_BIOME_GENERATION_CONFIG,
  biomes = createBiomeRegions(seed, config),
): ResourceNode[] {
  const random = createSeededRandom(`${seed}:resources`);
  const twigRandom = createSeededRandom(`${seed}:twig-clearings`);
  const treeYieldRandom = createSeededRandom(`${seed}:tree-yields`);
  const activeResourceTypes = new Set(
    (config.activeResourceTypes ?? BIOME_RESOURCE_TYPES)
      .filter((type): type is BiomeResourceType => BIOME_RESOURCE_TYPES.includes(type as BiomeResourceType)),
  );
  let nodeNumber = 1;

  const resourceNodes = biomes.flatMap((biome) => {
    if (biome.isDecorativeOnly) return [];
    const template = BIOME_DEFINITIONS[biome.id];
    const primaryResourceType = template.primaryResourceType;
    if (!primaryResourceType || !activeResourceTypes.has(primaryResourceType)) return [];

    const secondaryTypes = [...activeResourceTypes]
      .filter((type) => type !== primaryResourceType);
    const nodeCount = random.nextInt(
      Math.max(0, Math.floor(config.minResourceNodesPerBiome)),
      Math.max(
        Math.max(0, Math.floor(config.minResourceNodesPerBiome)),
        Math.floor(config.maxResourceNodesPerBiome),
      ),
    );

    return Array.from({ length: nodeCount }, (_, index) => {
      const isSecondary = secondaryTypes.length > 0
        && index > 0
        && random.nextFloat() < config.secondaryChance;
      const type = isSecondary
        ? secondaryTypes[random.nextInt(0, secondaryTypes.length - 1)]
        : primaryResourceType;

      const [minimumAmount, maximumAmount] = RESOURCE_AMOUNT_RANGES[type];
      const primaryAmount = random.nextInt(minimumAmount, maximumAmount);
      const maxAmount = isSecondary
        ? Math.max(
          1,
          Math.floor(primaryAmount * clamp(config.secondaryAmountMultiplier, 0, 0.99)),
        )
        : primaryAmount;
      const startingExclusionRadius = Math.max(config.startingResourceExclusionRadius, 0);
      const resourcePosition = randomPointOutsideArea(
        random,
        { x: biome.region.x, y: biome.region.y },
        biome.region.size / 2,
        0,
        { x: 80, y: 80 },
        startingExclusionRadius,
      );

      return {
        id: `resource-${String(nodeNumber++).padStart(3, '0')}`,
        type,
        source: RESOURCE_SOURCES[type],
        biome: biome.id,
        biomeInstanceId: biome.instanceId,
        isSecondary,
        interactionRadius: RESOURCE_INTERACTION_RADII[type],
        position: resourcePosition,
        amount: maxAmount,
        maxAmount,
        gatherRate: 1,
        ...(type === 'wood' && RESOURCE_SOURCES[type] === 'tree'
          ? { yieldAmount: treeYieldRandom.nextInt(2, 3) }
          : {}),
      };
    });
  });

  const clearings = biomes.filter((biome) => biome.id === 'clearing');
  const startingClearing = clearings.find((biome) => (
    Math.abs(biome.region.x - 80) < 0.01 && Math.abs(biome.region.y - 80) < 0.01
  )) ?? clearings[0];
  const requiredTwigClearings = Math.ceil(clearings.length * TWIG_CLEARING_COVERAGE);
  const shuffledOtherClearings = clearings.filter((biome) => biome !== startingClearing);
  for (let index = shuffledOtherClearings.length - 1; index > 0; index -= 1) {
    const swapIndex = twigRandom.nextInt(0, index);
    [shuffledOtherClearings[index], shuffledOtherClearings[swapIndex]] = [
      shuffledOtherClearings[swapIndex],
      shuffledOtherClearings[index],
    ];
  }
  const twigClearings = [
    ...(startingClearing ? [startingClearing] : []),
    ...shuffledOtherClearings.slice(
      0,
      Math.max(requiredTwigClearings - (startingClearing ? 1 : 0), 0),
    ),
  ];
  const twigNodes = twigClearings.map((biome) => {
    const maximumOffset = Math.max(biome.region.size / 2 - 0.8, 0.75);
    const position = randomPointInCircle(
      twigRandom,
      { x: biome.region.x, y: biome.region.y },
      maximumOffset,
      Math.min(1, maximumOffset * 0.5),
    );
    return {
      id: `resource-${String(nodeNumber++).padStart(3, '0')}`,
      type: 'wood' as const,
      source: 'twigs' as const,
      biome: biome.id,
      biomeInstanceId: biome.instanceId,
      isSecondary: true,
      interactionRadius: 1.2,
      position,
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
      yieldAmount: TWIG_NODE_YIELD,
    };
  });

  return [...resourceNodes, ...twigNodes];
}

export const INITIAL_BARBARIAN_COUNT = 5;
export const INITIAL_RABBIT_COUNT = 6;
export const BARBARIAN_PATROL_RADIUS = 3.5;
export const BARBARIAN_PATROL_SPEED = 1;
export const BARBARIAN_PATROL_WAIT_MIN_SECONDS = 2;
export const BARBARIAN_PATROL_WAIT_MAX_SECONDS = 4;
export const RABBIT_RESPAWN_SECONDS = 30;

export function createBarbarianStates(seed: string): BarbarianState[] {
  const random = createSeededRandom(`${seed}:barbarian-spawns`);
  const spawns: Vec2[] = [];
  for (let index = 0; index < INITIAL_BARBARIAN_COUNT; index += 1) {
    let position: Vec2 | null = null;
    for (let attempt = 0; attempt < 500; attempt += 1) {
      const candidate = {
        x: roundPosition(random.nextFloat(10, WORLD_SIZE - 10)),
        y: roundPosition(random.nextFloat(10, WORLD_SIZE - 10)),
      };
      const clearOfTotem = Math.hypot(candidate.x - 80, candidate.y - 80) >= 24;
      const clearOfOthers = spawns.every((other) => (
        Math.hypot(candidate.x - other.x, candidate.y - other.y) >= 18
      ));
      if (clearOfTotem && clearOfOthers) {
        position = candidate;
        break;
      }
    }
    if (!position) throw new Error('Unable to place deterministic barbarian spawns');
    spawns.push(position);
  }

  return spawns.map((position, index) => ({
    id: `barbarian-${String(index + 1).padStart(2, '0')}`,
    position: { ...position },
    spawnPosition: { ...position },
    patrolCenter: { ...position },
    patrolTarget: { ...position },
    patrolRadius: BARBARIAN_PATROL_RADIUS,
    patrolWaitRemainingSeconds: random.nextFloat(
      BARBARIAN_PATROL_WAIT_MIN_SECONDS,
      BARBARIAN_PATROL_WAIT_MAX_SECONDS,
    ),
    patrolStep: 0,
    returningToSpawn: false,
    health: BARBARIAN_MAX_HEALTH,
    maxHealth: BARBARIAN_MAX_HEALTH,
    isAlive: true,
    respawnRemainingSeconds: 0,
    attackProgressSeconds: BARBARIAN_ATTACK_COOLDOWN_SECONDS,
    targetUnitId: null,
    alertedUnitIds: [],
    alertSoundedThisEncounter: false,
    spawnCycle: 0,
  }));
}

export function createRabbitStates(seed: string, biomes: readonly BiomeDefinition[]): AnimalState[] {
  const meadows = biomes.filter((biome) => biome.id === 'meadow' && !biome.isDecorativeOnly);
  if (meadows.length === 0) return [];
  const random = createSeededRandom(`${seed}:rabbit-spawns`);
  return Array.from({ length: INITIAL_RABBIT_COUNT }, (_, index) => {
    const biome = meadows[index % meadows.length];
    const homeCenter = { x: biome.region.x, y: biome.region.y };
    const homeRadius = Math.max(biome.region.size / 2 - 0.8, 0.5);
    const position = randomPointInCircle(random, homeCenter, homeRadius);
    return {
      id: `rabbit-${String(index + 1).padStart(2, '0')}`,
      kind: 'rabbit' as const,
      position,
      spawnPosition: { ...position },
      homeCenter,
      homeRadius,
      patrolTarget: randomPointInCircle(random, homeCenter, homeRadius),
      health: 2,
      maxHealth: 2,
      isAlive: true,
      respawnRemainingSeconds: 0,
      attackProgressSeconds: 0,
      spawnCycle: 0,
    };
  });
}

type DecorationWeight = {
  kind: DecorativeKind;
  weight: number;
};

type DecorationRule = {
  distribution: readonly DecorationWeight[];
  minimum: number;
  maximum: number;
};

const DECORATION_RULES: Readonly<Record<BiomeId, DecorationRule>> = {
  // Ground vegetation is intentionally ordered by abundance: grass, flowers, mushrooms.
  clearing: {
    distribution: [
      { kind: 'grass', weight: 60 },
      { kind: 'flower', weight: 25 },
      { kind: 'mushroom', weight: 15 },
    ],
    minimum: 8,
    maximum: 12,
  },
  meadow: {
    distribution: [
      { kind: 'grass', weight: 60 },
      { kind: 'flower', weight: 25 },
      { kind: 'mushroom', weight: 15 },
    ],
    minimum: 9,
    maximum: 14,
  },
  forest: {
    distribution: [
      { kind: 'grass', weight: 58 },
      { kind: 'flower', weight: 27 },
      { kind: 'mushroom', weight: 15 },
    ],
    minimum: 8,
    maximum: 12,
  },
  rocky: {
    distribution: [],
    minimum: 0,
    maximum: 0,
  },
  ruins: {
    distribution: [],
    minimum: 0,
    maximum: 0,
  },
  'great-fire': {
    distribution: [{ kind: 'grass', weight: 100 }],
    minimum: 2,
    maximum: 4,
  },
};

const FLOWER_COLORS: readonly FlowerColor[] = ['yellow', 'blue', 'gray', 'pink'];

function createDecorationKinds(
  count: number,
  distribution: readonly DecorationWeight[],
  random: ReturnType<typeof createSeededRandom>,
): DecorativeKind[] {
  const totalWeight = distribution.reduce((sum, entry) => sum + entry.weight, 0);
  const allocations = distribution.map((entry) => {
    const exact = count * entry.weight / totalWeight;
    return {
      ...entry,
      count: Math.floor(exact),
      remainder: exact - Math.floor(exact),
    };
  });

  let remaining = count - allocations.reduce((sum, entry) => sum + entry.count, 0);
  while (remaining > 0) {
    const candidate = allocations
      .filter((entry) => entry.kind !== 'mushroom' || entry.count < 2)
      .sort((first, second) => second.remainder - first.remainder)[0];
    if (!candidate) break;
    candidate.count += 1;
    candidate.remainder = 0;
    remaining -= 1;
  }

  const kinds = allocations.flatMap((entry) => Array.from({ length: entry.count }, () => entry.kind));
  for (let index = kinds.length - 1; index > 0; index -= 1) {
    const swapIndex = random.nextInt(0, index);
    [kinds[index], kinds[swapIndex]] = [kinds[swapIndex], kinds[index]];
  }
  return kinds;
}

export function createWorldDecorations(
  seed = DEFAULT_SURVIVAL_SEED,
  biomes = createBiomeRegions(seed),
): WorldDecoration[] {
  const random = createSeededRandom(`${seed}:decorations`);
  let decorationNumber = 1;

  return biomes.flatMap((biome) => {
    const rule = DECORATION_RULES[biome.id];
    const count = random.nextInt(rule.minimum, rule.maximum);
    const radius = Math.max(biome.region.size / 2 - 1.2, 0);
    const kinds = createDecorationKinds(count, rule.distribution, random);

    return kinds.map((kind) => {
      const flowerColor = kind === 'flower'
        ? FLOWER_COLORS[random.nextInt(0, FLOWER_COLORS.length - 1)]
        : undefined;
      return {
        id: `decoration-${String(decorationNumber++).padStart(3, '0')}`,
        kind,
        ...(flowerColor ? { flowerColor } : {}),
        biome: biome.id,
        biomeInstanceId: biome.instanceId,
        position: randomPointInCircle(
          random,
          { x: biome.region.x, y: biome.region.y },
          radius,
          Math.min(1.5, radius),
        ),
        scale: roundPosition(random.nextFloat(1.26, 1.62)),
      };
    });
  });
}

export function createSurvivalBlueprint(
  seed = DEFAULT_SURVIVAL_SEED,
  config: BiomeGenerationConfig = DEFAULT_BIOME_GENERATION_CONFIG,
): SurvivalWorldBlueprint {
  const biomes = createBiomeRegions(seed, config);
  return {
    seed,
    biomes,
    resources: createResourceNodes(seed, config, biomes),
    decorations: createWorldDecorations(seed, biomes),
  };
}

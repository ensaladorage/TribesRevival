import { describe, expect, it } from 'vitest';
import {
  BIOME_IDS,
  BIOME_RESOURCE_TYPES,
  RESOURCE_BIOME_IDS,
  type ResourceNode,
  type UnitCargo,
} from './survivalTypes';
import {
  BIOME_DEFINITIONS,
  DEFAULT_BIOME_GENERATION_CONFIG,
  HITO_2C_GENERATION_CONFIG,
  HITO_3_GENERATION_CONFIG,
  TWIG_CLEARING_COVERAGE,
  TWIG_NODE_YIELD,
  createResourceNodes,
  createSurvivalBlueprint,
} from './survivalCatalog';
import { createSeededRandom } from './seededRandom';
import {
  addToCargo,
  canRoleGatherResource,
  chooseCollectDropTask,
  chooseGatherTask,
  collectDrop,
  gatherFromNode,
} from './survivalRules';
import { createEmptyResourceAmounts } from './survivalTypes';

const EMPTY_CARGO: UnitCargo = {
  amounts: createEmptyResourceAmounts(),
  capacity: 4,
};

describe('survival design contracts', () => {
  it('generates the same resource blueprint for the same seed', () => {
    expect(createSurvivalBlueprint('same-seed')).toEqual(createSurvivalBlueprint('same-seed'));
    expect(createSurvivalBlueprint('same-seed')).not.toEqual(createSurvivalBlueprint('other-seed'));
    const firstRandom = createSeededRandom('seed');
    const secondRandom = createSeededRandom('seed');
    expect([firstRandom.nextUint(), firstRandom.nextUint(), firstRandom.nextUint()])
      .toEqual([secondRandom.nextUint(), secondRandom.nextUint(), secondRandom.nextUint()]);
  });

  it('generates valid, unique resource nodes covering every resource type and biome', () => {
    const nodes = createResourceNodes('validation-seed');
    const ids = new Set(nodes.map((node) => node.id));
    const types = new Set(nodes.map((node) => node.type));
    const validationBiomes = createSurvivalBlueprint('validation-seed').biomes;
    expect(nodes.length).toBeGreaterThanOrEqual(10);
    expect(ids.size).toBe(nodes.length);
    expect(types).toEqual(new Set(BIOME_RESOURCE_TYPES));
    expect(nodes.every((node) => node.amount > 0 && node.amount <= node.maxAmount)).toBe(true);
    expect(nodes.every((node) => node.gatherRate > 0)).toBe(true);
    expect(nodes.some((node) => node.isSecondary)).toBe(true);
    expect(validationBiomes.filter((biome) => !biome.isDecorativeOnly)).toHaveLength(10);
    expect(new Set(validationBiomes.map((biome) => biome.id)))
      .toEqual(new Set(BIOME_IDS));
    expect(validationBiomes.every(
      (biome) => biome.region.shape === 'circle',
    )).toBe(true);
    for (let firstIndex = 0; firstIndex < validationBiomes.length; firstIndex += 1) {
      for (let secondIndex = firstIndex + 1; secondIndex < validationBiomes.length; secondIndex += 1) {
        const first = validationBiomes[firstIndex];
        const second = validationBiomes[secondIndex];
        expect(Math.hypot(first.region.x - second.region.x, first.region.y - second.region.y))
          .toBeGreaterThanOrEqual((first.region.size + second.region.size) / 2 + 0.49);
      }
    }
  });

  it('keeps biome population configurable without losing biome coverage', () => {
    const config = {
      ...DEFAULT_BIOME_GENERATION_CONFIG,
      totalBiomes: 8,
    };
    const blueprint = createSurvivalBlueprint('compact-map', config);

    expect(blueprint.biomes.filter((biome) => !biome.isDecorativeOnly)).toHaveLength(8);
    expect(new Set(blueprint.biomes.map((biome) => biome.id))).toEqual(new Set(BIOME_IDS));
  });

  it('keeps the Hito 2C.2 starting area clear and guarantees emergency twigs in half of all clearings', () => {
    const blueprint = createSurvivalBlueprint('hito-2c-2', HITO_2C_GENERATION_CONFIG);

    expect(blueprint.biomes.filter((biome) => !biome.isDecorativeOnly)).toHaveLength(10);
    const berryNodes = blueprint.resources.filter((resource) => resource.source === 'berry-bush');
    const twigNodes = blueprint.resources.filter((resource) => resource.source === 'twigs');
    expect(berryNodes.length).toBeGreaterThan(0);
    expect(berryNodes.every((resource) => resource.type === 'food')).toBe(true);
    expect(twigNodes.length).toBeGreaterThan(0);
    expect(twigNodes.every((resource) => (
      resource.type === 'wood'
      && resource.amount === 1
      && resource.yieldAmount === TWIG_NODE_YIELD
    ))).toBe(true);
    const clearings = blueprint.biomes.filter((biome) => biome.id === 'clearing');
    const suppliedClearings = new Set(twigNodes.map((node) => node.biomeInstanceId));
    expect(suppliedClearings.size).toBeGreaterThanOrEqual(
      Math.ceil(clearings.length * TWIG_CLEARING_COVERAGE),
    );
    expect(suppliedClearings.has(
      clearings.find((biome) => biome.region.x === 80 && biome.region.y === 80)?.instanceId,
    )).toBe(true);
    expect(new Set(twigNodes.map((node) => node.biomeInstanceId)).size).toBe(twigNodes.length);
    expect(berryNodes.every((resource) => (
      Math.hypot(resource.position.x - 80, resource.position.y - 80)
        >= HITO_2C_GENERATION_CONFIG.startingResourceExclusionRadius
    ))).toBe(true);
    expect(blueprint.decorations.every((decoration) => (
      decoration.kind === 'grass' || decoration.kind === 'flower' || decoration.kind === 'mushroom'
    ))).toBe(true);
    expect(blueprint.biomes.filter((biome) => biome.isDecorativeOnly)).toHaveLength(13);
    expect(new Set(blueprint.biomes.filter((biome) => !biome.isDecorativeOnly).map((biome) => biome.id)))
      .toEqual(new Set(RESOURCE_BIOME_IDS));
    expect(berryNodes.every((resource) => (
      !blueprint.biomes.find((biome) => biome.id === resource.biome)?.isDecorativeOnly
    ))).toBe(true);
    expect(blueprint.decorations).toEqual(
      createSurvivalBlueprint('hito-2c-2', HITO_2C_GENERATION_CONFIG).decorations,
    );
    expect(blueprint.decorations.some((decoration) => decoration.kind === 'mushroom')).toBe(true);
    expect(blueprint.decorations.some((decoration) => decoration.kind === 'flower')).toBe(true);
    expect(blueprint.decorations.filter((decoration) => decoration.kind === 'flower')
      .every((decoration) => decoration.flowerColor)).toBe(true);

    for (let firstIndex = 0; firstIndex < blueprint.biomes.length; firstIndex += 1) {
      for (let secondIndex = firstIndex + 1; secondIndex < blueprint.biomes.length; secondIndex += 1) {
        const first = blueprint.biomes[firstIndex];
        const second = blueprint.biomes[secondIndex];
        expect(Math.hypot(first.region.x - second.region.x, first.region.y - second.region.y))
          .toBeGreaterThanOrEqual((first.region.size + second.region.size) / 2 + HITO_2C_GENERATION_CONFIG.minimumBiomeGap - 0.01);
      }
    }
  });

  it('activates trees, stone veins, and luminous ruins for Hito 3', () => {
    const blueprint = createSurvivalBlueprint('hito-3-resources', HITO_3_GENERATION_CONFIG);
    const repeatedBlueprint = createSurvivalBlueprint('hito-3-resources', HITO_3_GENERATION_CONFIG);

    expect(blueprint).toEqual(repeatedBlueprint);
    expect(new Set(blueprint.resources.map((resource) => resource.type)))
      .toEqual(new Set(BIOME_RESOURCE_TYPES));

    const primaryResources = [
      { biome: 'forest', type: 'wood', source: 'tree' },
      { biome: 'rocky', type: 'stone', source: 'stone-vein' },
      { biome: 'ruins', type: 'spark', source: 'ruin' },
    ] as const;

    for (const expected of primaryResources) {
      expect(blueprint.resources.some((resource) => (
        resource.biome === expected.biome
        && resource.type === expected.type
        && resource.source === expected.source
        && resource.amount > 0
      ))).toBe(true);
    }

    const treeNodes = blueprint.resources.filter((resource) => resource.source === 'tree');
    expect(treeNodes.length).toBeGreaterThan(0);
    expect(treeNodes.every((resource) => (
      resource.yieldAmount === 2 || resource.yieldAmount === 3
    ))).toBe(true);

    const twigNodes = blueprint.resources.filter((resource) => resource.source === 'twigs');
    expect(twigNodes.length).toBeGreaterThan(0);
    expect(twigNodes.every((resource) => resource.type === 'wood')).toBe(true);
  });

  it('distributes ground decoration as grass, flowers, then mushrooms', () => {
    const blueprint = createSurvivalBlueprint('decoration-distribution');
    const groundBiomes = blueprint.biomes
      .filter((biome) => biome.id === 'clearing' || biome.id === 'meadow' || biome.id === 'forest');
    const decorationsByBiome = new Map(
      groundBiomes.map((biome) => [
        biome.instanceId,
        blueprint.decorations.filter((decoration) => decoration.biomeInstanceId === biome.instanceId),
      ]),
    );
    const totalCounts = { grass: 0, flower: 0, mushroom: 0 };

    for (const decorations of decorationsByBiome.values()) {
      const mushrooms = decorations.filter((decoration) => decoration.kind === 'mushroom');
      expect(mushrooms.length).toBeLessThanOrEqual(2);
      for (const decoration of decorations) {
        if (decoration.kind === 'grass' || decoration.kind === 'flower' || decoration.kind === 'mushroom') {
          totalCounts[decoration.kind] += 1;
          expect(decoration.scale).toBeGreaterThanOrEqual(1.26);
          expect(decoration.scale).toBeLessThanOrEqual(1.62);
        } else {
          expect(decoration.scale).toBeGreaterThanOrEqual(1.05);
          expect(decoration.scale).toBeLessThanOrEqual(1.35);
        }
      }
    }

    expect(totalCounts.grass).toBeGreaterThan(totalCounts.flower);
    expect(totalCounts.flower).toBeGreaterThan(totalCounts.mushroom);
  });

  it('gives each active resource biome one to three nodes including its own resource', () => {
    const config = {
      ...DEFAULT_BIOME_GENERATION_CONFIG,
      totalBiomes: 10,
      activeResourceTypes: BIOME_RESOURCE_TYPES,
    };
    const blueprint = createSurvivalBlueprint('resource-biome-rules', config);

    for (const biome of blueprint.biomes.filter((candidate) => !candidate.isDecorativeOnly)) {
      const nodes = blueprint.resources.filter((resource) => (
        Math.hypot(
          resource.position.x - biome.region.x,
          resource.position.y - biome.region.y,
        ) <= biome.region.size / 2
      ));
      expect(nodes.length).toBeGreaterThanOrEqual(1);
      expect(nodes.length).toBeLessThanOrEqual(3);
      const ownType = BIOME_DEFINITIONS[biome.id].primaryResourceType;
      expect(ownType).not.toBeNull();
      expect(nodes.some((node) => node.type === ownType)).toBe(true);
    }
  });

  it('keeps normal role affinity explicit while allowing every role to gather twigs', () => {
    expect(canRoleGatherResource('gatherer', 'food')).toBe(true);
    expect(canRoleGatherResource('gatherer', 'wood')).toBe(false);
    expect(canRoleGatherResource('explorer', 'wood')).toBe(false);
    expect(canRoleGatherResource('lumberjack', 'stone')).toBe(false);
    for (const role of ['gatherer', 'lumberjack', 'hunter'] as const) {
      expect(canRoleGatherResource(role, 'stone', 'stone-vein')).toBe(false);
      expect(canRoleGatherResource(role, 'spark', 'ruin')).toBe(false);
    }
    for (const role of ['explorer', 'gatherer', 'lumberjack', 'hunter', 'guardian', 'artisan'] as const) {
      expect(canRoleGatherResource(role, 'wood', 'twigs')).toBe(true);
    }
    expect(canRoleGatherResource('gatherer', 'wood', 'tree')).toBe(false);
  });

  it('extends resource detection by exactly five percent', () => {
    const resource = {
      id: 'resource-detection-test',
      type: 'food' as const,
      source: 'berry-bush' as const,
      biome: 'meadow' as const,
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 90.4, y: 80 },
      amount: 2,
      maxAmount: 2,
      gatherRate: 1,
    };
    const input = {
      role: 'gatherer' as const,
      unitPosition: { x: 80, y: 80 },
      totemPosition: { x: 80, y: 80 },
      commandRadius: 10,
      cargo: EMPTY_CARGO,
      resources: [resource],
    };

    expect(chooseGatherTask(input).kind).toBe('gather');
    expect(chooseGatherTask({
      ...input,
      resources: [{ ...resource, position: { x: 90.6, y: 80 } }],
    }).kind).toBe('idle');
  });

  it('never gathers more than a node owns', () => {
    const node: ResourceNode = {
      id: 'resource-test',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 1, y: 1 },
      amount: 2,
      maxAmount: 2,
      gatherRate: 1,
    };

    const result = gatherFromNode(node, 10);
    expect(result.gathered).toBe(2);
    expect(result.node.amount).toBe(0);
    expect(node.amount).toBe(2);
  });

  it('respects cargo capacity and collects a drop without negative resources', () => {
    const loaded = addToCargo(EMPTY_CARGO, 'food', 10);
    expect(loaded.accepted).toBe(4);
    expect(loaded.cargo.amounts.food).toBe(4);

    const collected = collectDrop({
      id: 'drop-capacity-test',
      type: 'food',
      sourceNodeId: 'resource-test',
      position: { x: 1, y: 1 },
      amount: 1,
    }, {
      food: -3,
      wood: 1,
      stone: 0,
      spark: 0,
      gold: 0,
    });
    expect(collected.collected).toBe(1);
    expect(collected.drop.amount).toBe(0);
    expect(collected.inventory).toEqual({ food: 1, wood: 1, stone: 0, spark: 0, gold: 0 });
  });

  it('selects a valid nearby task and falls back to idle when none exists', () => {
    const resources: ResourceNode[] = [{
      id: 'task-berry-bush',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 84, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
    }];
    const task = chooseGatherTask({
      role: 'gatherer',
      unitPosition: { x: 80, y: 80 },
      totemPosition: { x: 80, y: 80 },
      commandRadius: 10,
      cargo: EMPTY_CARGO,
      resources,
    });

    expect(task.kind).toBe('gather');
    expect(task.cause).toBe('resource-found');
    expect(task.targetResourceId).not.toBeNull();

    const noTask = chooseGatherTask({
      role: 'explorer',
      unitPosition: { x: 80, y: 80 },
      totemPosition: { x: 80, y: 80 },
      commandRadius: 10,
      cargo: EMPTY_CARGO,
      resources,
    });
    expect(noTask).toEqual({
      kind: 'idle',
      cause: 'no-valid-resource',
      targetResourceId: null,
      destination: null,
    });
  });

  it('does not route a full cargo back to the totem', () => {
    const cargo: UnitCargo = {
      amounts: { food: 4, wood: 0, stone: 0, spark: 0, gold: 0 },
      capacity: 4,
    };
    const task = chooseGatherTask({
      role: 'gatherer',
      unitPosition: { x: 80, y: 80 },
      totemPosition: { x: 80, y: 80 },
      commandRadius: 10,
      cargo,
      resources: [],
    });

    expect(task).toEqual({
      kind: 'idle',
      cause: 'over-capacity',
      targetResourceId: null,
      destination: null,
    });
  });

  it('assigns a nearby drop to any free unit and adds it to inventory', () => {
    const drop = {
      id: 'drop-test',
      type: 'food' as const,
      sourceNodeId: 'resource-test',
      position: { x: 84, y: 80 },
      amount: 1,
    };
    const task = chooseCollectDropTask({
      unitPosition: { x: 80, y: 80 },
      drops: [drop],
      commandRadius: 10,
    });
    const collected = collectDrop(drop, createEmptyResourceAmounts());

    expect(task.kind).toBe('collect-drop');
    expect(task.targetResourceId).toBe(drop.id);
    expect(chooseCollectDropTask({
      unitPosition: { x: 80, y: 80 },
      drops: [drop],
      commandRadius: 10,
      reservedTargetIds: new Set([drop.id]),
    }).kind).toBe('idle');
    expect(chooseCollectDropTask({
      unitPosition: { x: 80, y: 80 },
      drops: [{ ...drop, position: { x: 90.4, y: 80 } }],
      commandRadius: 10,
    }).kind).toBe('collect-drop');
    expect(chooseCollectDropTask({
      unitPosition: { x: 80, y: 80 },
      drops: [{ ...drop, position: { x: 90.6, y: 80 } }],
      commandRadius: 10,
    }).kind).toBe('idle');
    expect(collected.inventory.food).toBe(1);
    expect(collected.drop.amount).toBe(0);
  });
});

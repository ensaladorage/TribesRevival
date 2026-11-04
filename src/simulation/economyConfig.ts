import { createSeededRandom } from './seededRandom';
import type {
  ResourceAmounts,
  ResourceCost,
  ResourceNode,
  ResourceType,
  SpecializationItem,
  ToolId,
} from './survivalTypes';
import type { ToolLevels } from './types';

export const MAX_PLAYABLE_MINIONS = 8;
export const STARTING_MINION_COUNT = 2;
export const MAX_TOOL_LEVEL = 10;

const EMPTY_COST: ResourceCost = {};
const FOOD_RECRUITMENT_COSTS = [2, 3, 3, 4, 4, 4] as const;
const SPECIALIZATION_COSTS = [2, 3, 3, 4, 4] as const;

type SpecializationDefinition = {
  resource: ResourceType;
  costs: readonly number[];
  maximumActive: number;
};

export const SPECIALIZATION_ECONOMY: Readonly<Record<SpecializationItem, SpecializationDefinition>> = {
  axe: { resource: 'wood', costs: SPECIALIZATION_COSTS, maximumActive: 5 },
  bow: { resource: 'wood', costs: SPECIALIZATION_COSTS, maximumActive: 5 },
  hammer: { resource: 'wood', costs: SPECIALIZATION_COSTS, maximumActive: 5 },
  sword: { resource: 'gold', costs: SPECIALIZATION_COSTS, maximumActive: 5 },
  mage: { resource: 'spark', costs: [2], maximumActive: 1 },
};

export const SHIELD_ECONOMY = {
  resource: 'gold' as const,
  costs: SPECIALIZATION_COSTS,
};

export type ToolEffect = {
  gatherSpeedPercent?: number;
  bonusResourceChance?: number;
  guardianDamageBonus?: number;
};

export type ToolUpgrade = {
  level: number;
  cost: ResourceCost;
  effect: ToolEffect;
};

const TOOL_COSTS: readonly ResourceCost[] = [
  {},
  { stone: 1 }, { stone: 2 }, { stone: 3 }, { stone: 4 }, { stone: 5 },
  { stone: 6 }, { stone: 7 }, { stone: 8, spark: 1 }, { stone: 9, spark: 1, gold: 1 },
  { stone: 10, spark: 2, gold: 2 },
] as const;
const GATHER_SPEED_PERCENTAGES = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5] as const;
const BONUS_RESOURCE_CHANCES = [0, 0, 0.5, 1, 1.5, 2, 5, 10, 15, 20, 30] as const;

function createGatherToolUpgrades(): readonly ToolUpgrade[] {
  return TOOL_COSTS.map((cost, level) => ({
    level,
    cost,
    effect: {
      gatherSpeedPercent: GATHER_SPEED_PERCENTAGES[level] ?? 0,
      bonusResourceChance: BONUS_RESOURCE_CHANCES[level] ?? 0,
    },
  }));
}

export const TOOL_UPGRADES: Readonly<Record<ToolId, readonly ToolUpgrade[]>> = {
  axe: createGatherToolUpgrades(),
  hammer: createGatherToolUpgrades(),
  sword: TOOL_COSTS.map((cost, level) => ({
    level,
    cost,
    effect: { guardianDamageBonus: level * 0.25 },
  })),
};

function countIndex(activeCount: number, costs: readonly number[]): number {
  return Math.min(Math.max(Math.floor(activeCount), 0), costs.length - 1);
}

function oneResourceCost(resource: ResourceType, amount: number): ResourceCost {
  return amount > 0 ? { [resource]: amount } : EMPTY_COST;
}

export function getGathererRecruitmentCost(activePopulation: number): ResourceCost {
  const index = Math.max(Math.floor(activePopulation) - STARTING_MINION_COUNT, 0);
  return oneResourceCost('food', FOOD_RECRUITMENT_COSTS[countIndex(index, FOOD_RECRUITMENT_COSTS)] ?? 0);
}

export function getSpecializationCost(item: SpecializationItem, activeTargetCount: number): ResourceCost {
  const definition = SPECIALIZATION_ECONOMY[item];
  return oneResourceCost(
    definition.resource,
    definition.costs[countIndex(activeTargetCount, definition.costs)] ?? 0,
  );
}

export function getSpecializationLimit(item: SpecializationItem): number {
  return SPECIALIZATION_ECONOMY[item].maximumActive;
}

export function getShieldCost(equippedGuardians: number): ResourceCost {
  return oneResourceCost(
    SHIELD_ECONOMY.resource,
    SHIELD_ECONOMY.costs[countIndex(equippedGuardians, SHIELD_ECONOMY.costs)] ?? 0,
  );
}

export function getToolUpgrade(tool: ToolId, level: number): ToolUpgrade | null {
  const normalizedLevel = Math.floor(level);
  return TOOL_UPGRADES[tool][normalizedLevel] ?? null;
}

export function getToolUpgradeCost(tool: ToolId, nextLevel: number): ResourceCost | null {
  return getToolUpgrade(tool, nextLevel)?.cost ?? null;
}

export function getToolEffect(tool: ToolId, level: number): ToolEffect {
  return getToolUpgrade(tool, Math.min(Math.max(Math.floor(level), 0), MAX_TOOL_LEVEL))?.effect ?? {};
}

export function canAffordCost(amounts: ResourceAmounts, cost: ResourceCost): boolean {
  return Object.entries(cost).every(([resource, amount]) => (
    amounts[resource as ResourceType] >= (amount ?? 0)
  ));
}

export function getMissingResources(amounts: ResourceAmounts, cost: ResourceCost): ResourceCost {
  return Object.entries(cost).reduce<ResourceCost>((missing, [resource, amount]) => {
    const typedResource = resource as ResourceType;
    const required = amount ?? 0;
    const difference = Math.max(required - amounts[typedResource], 0);
    return difference > 0 ? { ...missing, [typedResource]: difference } : missing;
  }, {});
}

export function spendCost(amounts: ResourceAmounts, cost: ResourceCost): boolean {
  if (!canAffordCost(amounts, cost)) return false;
  for (const [resource, amount] of Object.entries(cost)) {
    amounts[resource as ResourceType] -= amount ?? 0;
  }
  return true;
}

export function getGatherActionDurationMultiplier(tool: 'axe' | 'hammer', level: number): number {
  return 1 + (getToolEffect(tool, level).gatherSpeedPercent ?? 0) / 100;
}

export function rollsToolBonusResource(input: {
  seed: string;
  tick: number;
  unitId: string;
  nodeId: string;
  tool: 'axe' | 'hammer';
  level: number;
}): boolean {
  const chance = getToolEffect(input.tool, input.level).bonusResourceChance ?? 0;
  if (chance <= 0) return false;
  return createSeededRandom(
    `${input.seed}:tool-bonus:${input.tick}:${input.unitId}:${input.nodeId}:${input.tool}`,
  ).nextFloat() < chance / 100;
}

export function getResourceNodeTier(node: Pick<ResourceNode, 'tier'>): 1 | 2 {
  return node.tier === 2 ? 2 : 1;
}

export function isResourceNodeToolRequirementMet(
  node: Pick<ResourceNode, 'source' | 'tier'>,
  levels: ToolLevels,
): boolean {
  return !(node.source === 'stone-vein' && getResourceNodeTier(node) === 2)
    || levels.hammer >= 5;
}

import type { UnitState, Vec2 } from './types';
import type {
  ResourceAmounts,
  ResourceDrop,
  ResourceNode,
  ResourceType,
  SpecializationItem,
  SurvivalRole,
  TaskCause,
  UnitCargo,
  UnitTask,
} from './survivalTypes';

const ROLE_RESOURCE_AFFINITY: Readonly<Record<SurvivalRole, readonly ResourceType[]>> = {
  explorer: [],
  gatherer: ['food'],
  lumberjack: ['wood'],
  hunter: [],
  guardian: [],
  artisan: ['stone', 'spark'],
};

export const RESOURCE_DETECTION_RANGE_MULTIPLIER = 1.05;

/** Global living-minion cap, regardless of role. */
export const MAX_PLAYABLE_MINIONS = 8;

/** Starting roster size used as the baseline for total-population pricing. */
export const STARTING_MINION_COUNT = 2;

/** Maximum living minions allowed for each specialist role. */
export const MAX_MINIONS_PER_TYPE = 5;

/** Cost progression applied to the relevant active population count. */
export const GATHERER_RECRUITMENT_COSTS: readonly number[] = [2, 3, 3, 4, 4, 4];

/**
 * Pricing is based on active minions beyond the supplied baseline. Gatherers
 * use the global roster size with the starting population as baseline;
 * specialists use their own role count with no baseline.
 */
export function getMinionPurchaseCost(activeMinions: number, startingMinions = 0): number {
  const normalizedActiveCount = Math.max(Math.floor(activeMinions), 0);
  const normalizedStartingCount = Math.max(Math.floor(startingMinions), 0);
  const normalizedCount = Math.max(normalizedActiveCount - normalizedStartingCount, 0);
  return GATHERER_RECRUITMENT_COSTS[
    Math.min(normalizedCount, GATHERER_RECRUITMENT_COSTS.length - 1)
  ] ?? GATHERER_RECRUITMENT_COSTS[GATHERER_RECRUITMENT_COSTS.length - 1];
}

export function getSpecializationRole(item: SpecializationItem): SurvivalRole {
  if (item === 'axe') return 'lumberjack';
  if (item === 'bow') return 'hunter';
  if (item === 'hammer') return 'artisan';
  return 'guardian';
}

export function countUnitsWithRole(
  units: readonly Pick<UnitState, 'role'>[],
  role: SurvivalRole,
): number {
  return units.reduce((count, unit) => count + (unit.role === role ? 1 : 0), 0);
}

/** The last gatherer is protected from lumberjack conversion. */
export function canConvertLastGathererToLumberjack(
  units: readonly Pick<UnitState, 'role'>[],
): boolean {
  return countUnitsWithRole(units, 'gatherer') > 1;
}

/**
 * Autonomous work is resolved from highest to lowest priority. Combat is
 * reserved for the enemy system; resource and drop selection are active in
 * Hito 2A. Totem pickup remains an external interruption handled by the
 * simulation input layer, so it always cancels autonomous work first.
 */
export const AUTONOMOUS_TASK_PRIORITY = {
  enemy: 3,
  resource: 2,
  drop: 1,
} as const;

export function getResourceDetectionRadius(commandRadius: number): number {
  return Math.max(commandRadius, 0) * RESOURCE_DETECTION_RANGE_MULTIPLIER;
}

function positiveWholeAmount(amount: number): number {
  return Number.isFinite(amount) ? Math.max(Math.floor(amount), 0) : 0;
}

export function totalResourceAmount(amounts: ResourceAmounts): number {
  return Object.values(amounts).reduce((total, amount) => total + positiveWholeAmount(amount), 0);
}

export function canRoleGatherResource(
  role: SurvivalRole,
  type: ResourceType,
  source?: ResourceNode['source'],
): boolean {
  if (source === 'twigs') return type === 'wood';
  return ROLE_RESOURCE_AFFINITY[role].includes(type);
}

export function gatherFromNode(
  node: ResourceNode,
  requestedAmount: number,
): { node: ResourceNode; gathered: number } {
  const gathered = Math.min(positiveWholeAmount(requestedAmount), positiveWholeAmount(node.amount));
  return {
    node: {
      ...node,
      amount: positiveWholeAmount(node.amount - gathered),
    },
    gathered,
  };
}

export function addToCargo(
  cargo: UnitCargo,
  type: ResourceType,
  requestedAmount: number,
): { cargo: UnitCargo; accepted: number } {
  const freeCapacity = Math.max(cargo.capacity - totalResourceAmount(cargo.amounts), 0);
  const accepted = Math.min(positiveWholeAmount(requestedAmount), freeCapacity);
  const amounts = { ...cargo.amounts };
  amounts[type] += accepted;

  return {
    cargo: { ...cargo, amounts },
    accepted,
  };
}

export function collectDrop(
  drop: ResourceDrop,
  inventory: ResourceAmounts,
): { drop: ResourceDrop; inventory: ResourceAmounts; collected: number } {
  // A physical drop is always one resource. Keep collection defensive so
  // malformed/legacy aggregate drops cannot bypass that game-wide contract.
  const collected = drop.amount > 0 ? 1 : 0;
  const nextInventory = { ...inventory };
  nextInventory[drop.type] = positiveWholeAmount(nextInventory[drop.type]) + collected;

  return {
    drop: { ...drop, amount: 0 },
    inventory: nextInventory,
    collected,
  };
}

function distanceSquared(first: Vec2, second: Vec2): number {
  const dx = first.x - second.x;
  const dy = first.y - second.y;
  return dx * dx + dy * dy;
}

function task(
  kind: UnitTask['kind'],
  cause: TaskCause,
  targetResourceId: string | null,
  destination: Vec2 | null,
): UnitTask {
  return { kind, cause, targetResourceId, destination };
}

export function chooseGatherTask(input: {
  role: SurvivalRole;
  unitPosition: Vec2;
  totemPosition: Vec2;
  commandRadius: number;
  cargo: UnitCargo;
  resources: readonly ResourceNode[];
  reservedTargetIds?: ReadonlySet<string>;
  excludedTargetId?: string | null;
}): UnitTask {
  if (totalResourceAmount(input.cargo.amounts) >= input.cargo.capacity) {
    return task('idle', 'over-capacity', null, null);
  }

  const radiusSquared = getResourceDetectionRadius(input.commandRadius) ** 2;
  const candidates = input.resources
    .filter((resource) => (
      resource.amount > 0
      && canRoleGatherResource(input.role, resource.type, resource.source)
      && resource.id !== input.excludedTargetId
      && !input.reservedTargetIds?.has(resource.id)
      && distanceSquared(resource.position, input.unitPosition) <= radiusSquared
    ))
    .sort((first, second) => {
      const distanceDifference = distanceSquared(input.unitPosition, first.position)
        - distanceSquared(input.unitPosition, second.position);
      return distanceDifference || first.id.localeCompare(second.id);
    });

  const target = candidates[0];
  if (!target) return task('idle', 'no-valid-resource', null, null);

  return task('gather', 'resource-found', target.id, target.position);
}

export function chooseCollectDropTask(input: {
  unitPosition: Vec2;
  drops: readonly ResourceDrop[];
  commandRadius: number;
  reservedTargetIds?: ReadonlySet<string>;
  excludedTargetId?: string | null;
}): UnitTask {
  const radiusSquared = getResourceDetectionRadius(input.commandRadius) ** 2;
  const target = input.drops
    .filter((drop) => (
      drop.amount > 0
      && drop.id !== input.excludedTargetId
      && !input.reservedTargetIds?.has(drop.id)
      && distanceSquared(drop.position, input.unitPosition) <= radiusSquared
    ))
    .sort((first, second) => {
      const distanceDifference = distanceSquared(input.unitPosition, first.position)
        - distanceSquared(input.unitPosition, second.position);
      return distanceDifference || first.id.localeCompare(second.id);
    })[0];

  if (!target) return task('idle', 'no-valid-resource', null, null);
  return task('collect-drop', 'drop-found', target.id, target.position);
}

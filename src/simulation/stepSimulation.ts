import type { InputAction } from '../input/actions';
import { createUnitState } from './createInitialState';
import type { AnimalState, BarbarianState, GameState, UnitState, Vec2 } from './types';
import { createSeededRandom } from './seededRandom';
import {
  chooseCollectDropTask,
  chooseGatherTask,
  canRoleGatherResource,
  canConvertLastGathererToLumberjack,
  collectDrop,
  countUnitsWithRole,
  gatherFromNode,
  getResourceDetectionRadius,
  getMinionPurchaseCost,
  getSpecializationRole,
  MAX_PLAYABLE_MINIONS,
  MAX_MINIONS_PER_TYPE,
  STARTING_MINION_COUNT,
  totalResourceAmount,
} from './survivalRules';
import {
  createEmptyResourceAmounts,
  CAMPFIRE_HEALING_RADIUS,
  CAMPFIRE_LIFETIME_SECONDS,
  CAMPFIRE_TOTEM_MAX_DISTANCE,
  MAX_ACTIVE_CAMPFIRES,
  CAMPFIRE_WOOD_COST,
  RESOURCE_TYPES,
} from './survivalTypes';
import type { ResourceType, TaskCause, UnitTask } from './survivalTypes';
import {
  ANIMAL_ATTACK_STATS,
  BARBARIAN_ATTACK_COOLDOWN_SECONDS,
  BARBARIAN_ATTACK_DAMAGE,
  BARBARIAN_ATTACK_RANGE,
  BARBARIAN_DETECTION_RADIUS,
  BARBARIAN_MOVEMENT_SPEED,
  BARBARIAN_RESPAWN_SECONDS,
  COMBAT_ALERT_DURATION_SECONDS,
  CAMPFIRE_HEAL_INTERVAL_SECONDS,
  DAMAGE_FLASH_DURATION_SECONDS,
  HEAL_EFFECT_DURATION_SECONDS,
  MINION_ATTACK_STATS,
  MINION_THREAT_DETECTION_RADIUS,
  dealDamage,
  healCombatant,
} from './survivalCombat';
import type { AttackStats, CombatantKind } from './survivalCombat';
import {
  RABBIT_RESPAWN_SECONDS,
  BARBARIAN_PATROL_SPEED,
  BARBARIAN_PATROL_WAIT_MIN_SECONDS,
  BARBARIAN_PATROL_WAIT_MAX_SECONDS,
} from './survivalCatalog';
import { updateWeather } from './weatherSystem';
import { PROGRESSION_BALANCE, awardExperience, unlockTechnology } from './progression';

export const WORLD_SIZE = 160;
export const UNIT_SPEED = 8;
export const TOTEM_CHASE_SPEED = UNIT_SPEED * 1.5;
export const HUNTER_COMBAT_SPEED = 6;
export const HUNTER_TOTEM_LEASH_RADIUS = 10;
export const FORMATION_RADIUS = 4;
export const RECRUITMENT_RADIUS = 15;
export const TOTEM_EDGE_PADDING = 2;
export const FORMATION_TOLERANCE = 0.08;
export const GATHER_ACTION_DURATION_SECONDS = 1.5;
export const TOTEM_NO_STOP_RADIUS = 2;
export const UNIT_COLLISION_RADIUS = 0.45;
export const UNIT_ACTOR_SEPARATION = 0.94;
export const TOTEM_CLEARANCE_EPSILON = 0.02;
const ATTACK_LUNGE_DURATION_SECONDS = 0.22;

export type StepSimulationOptions = {
  enableSurvival?: boolean;
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function clampWorldPosition(position: Vec2): Vec2 {
  return {
    x: clamp(position.x, TOTEM_EDGE_PADDING, WORLD_SIZE - TOTEM_EDGE_PADDING),
    y: clamp(position.y, TOTEM_EDGE_PADDING, WORLD_SIZE - TOTEM_EDGE_PADDING),
  };
}

export function projectWithinRadius(position: Vec2, center: Vec2, radius: number): Vec2 {
  const dx = position.x - center.x;
  const dy = position.y - center.y;
  const distance = Math.hypot(dx, dy);
  if (distance <= radius || distance < 1e-8) return { ...position };
  return clampWorldPosition({
    x: center.x + (dx / distance) * radius,
    y: center.y + (dy / distance) * radius,
  });
}

function moveTowards(position: Vec2, destination: Vec2, distance: number): boolean {
  const dx = destination.x - position.x;
  const dy = destination.y - position.y;
  const length = Math.hypot(dx, dy);

  if (length <= distance || length === 0) {
    position.x = destination.x;
    position.y = destination.y;
    return true;
  }

  position.x += (dx / length) * distance;
  position.y += (dy / length) * distance;
  return false;
}

function formationTarget(state: GameState, index: number): Vec2 {
  const unitCount = Math.max(state.units.length, 1);
  const angle = (index / unitCount) * Math.PI * 2;
  return {
    x: state.totem.position.x + Math.cos(angle) * FORMATION_RADIUS,
    y: state.totem.position.y + Math.sin(angle) * FORMATION_RADIUS,
  };
}

export function projectRecruitmentPosition(position: Vec2, totemPosition: Vec2): Vec2 {
  return projectWithinRadius(position, totemPosition, RECRUITMENT_RADIUS);
}

function stableHash(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

/** Repositions a minion outside the totem's no-stop circle; movement paths may cross it. */
export function projectOutsideTotemClearance(position: Vec2, totemPosition: Vec2, discriminator = ''): Vec2 {
  const dx = position.x - totemPosition.x;
  const dy = position.y - totemPosition.y;
  const distance = Math.hypot(dx, dy);
  const requiredDistance = TOTEM_NO_STOP_RADIUS + TOTEM_CLEARANCE_EPSILON;
  if (distance >= requiredDistance) return { ...position };
  const angle = distance > 1e-8
    ? Math.atan2(dy, dx)
    : (stableHash(discriminator) / 0xffffffff) * Math.PI * 2;
  return clampWorldPosition({
    x: totemPosition.x + Math.cos(angle) * requiredDistance,
    y: totemPosition.y + Math.sin(angle) * requiredDistance,
  });
}

function moveUnitTowards(state: GameState, unit: UnitState, destination: Vec2, distance: number): boolean {
  const safeDestination = projectOutsideTotemClearance(destination, state.totem.position, unit.id);
  const reached = moveTowards(unit.position, safeDestination, distance);
  if (reached) {
    Object.assign(unit.position, projectOutsideTotemClearance(unit.position, state.totem.position, unit.id));
  }
  return reached;
}

function separatePair(first: Vec2, second: Vec2, minDistance: number, seed: string): void {
  let dx = second.x - first.x;
  let dy = second.y - first.y;
  let distance = Math.hypot(dx, dy);
  if (distance >= minDistance) return;
  if (distance < 1e-8) {
    const angle = (stableHash(seed) / 0xffffffff) * Math.PI * 2;
    dx = Math.cos(angle);
    dy = Math.sin(angle);
    distance = 1;
  }
  const adjustment = (minDistance - distance) * 0.5;
  const nx = dx / distance;
  const ny = dy / distance;
  first.x -= nx * adjustment;
  first.y -= ny * adjustment;
  second.x += nx * adjustment;
  second.y += ny * adjustment;
}

function resolveActorSpacing(state: GameState): void {
  const units = [...state.units].sort((first, second) => first.id.localeCompare(second.id));
  const barbarians = state.barbarians
    .filter((barbarian) => barbarian.isAlive)
    .sort((first, second) => first.id.localeCompare(second.id));
  const constrainUnit = (unit: UnitState): void => {
    const safePosition = unit.role === 'hunter' && unit.task.kind === 'combat'
      ? projectWithinRadius(unit.position, state.totem.position, Math.min(
        state.totem.commandRadius,
        HUNTER_TOTEM_LEASH_RADIUS,
      ))
      : unit.position;
    Object.assign(unit.position, safePosition);
  };
  for (const unit of units) {
    constrainUnit(unit);
  }

  for (let pass = 0; pass < 8; pass += 1) {
    for (let firstIndex = 0; firstIndex < units.length; firstIndex += 1) {
      const first = units[firstIndex];
      for (let secondIndex = firstIndex + 1; secondIndex < units.length; secondIndex += 1) {
        const second = units[secondIndex];
        separatePair(first.position, second.position, UNIT_ACTOR_SEPARATION, `${first.id}:${second.id}`);
        constrainUnit(first);
        constrainUnit(second);
      }
      for (const barbarian of barbarians) {
        separatePair(first.position, barbarian.position, UNIT_ACTOR_SEPARATION, `${first.id}:${barbarian.id}`);
        constrainUnit(first);
      }
    }
    for (let firstIndex = 0; firstIndex < barbarians.length; firstIndex += 1) {
      for (let secondIndex = firstIndex + 1; secondIndex < barbarians.length; secondIndex += 1) {
        separatePair(
          barbarians[firstIndex].position,
          barbarians[secondIndex].position,
          UNIT_ACTOR_SEPARATION,
          `${barbarians[firstIndex].id}:${barbarians[secondIndex].id}`,
        );
      }
    }
  }
  for (const unit of units) {
    constrainUnit(unit);
  }
}

function combatApproachPoint(state: GameState, unit: UnitState, target: BarbarianState, range: number): Vec2 {
  const attackers = state.units
    .filter((candidate) => candidate.task.kind === 'combat' && candidate.task.targetEntityId === target.id)
    .sort((first, second) => first.id.localeCompare(second.id));
  const slot = Math.max(attackers.findIndex((candidate) => candidate.id === unit.id), 0);
  const count = Math.max(attackers.length, 1);
  const phase = (stableHash(target.id) / 0xffffffff) * Math.PI * 2;
  const angle = phase + (slot / count) * Math.PI * 2;
  const radius = Math.max(0.6, range - 0.12);
  const attackPosition = {
    x: target.position.x + Math.cos(angle) * radius,
    y: target.position.y + Math.sin(angle) * radius,
  };
  return unit.role === 'hunter'
    ? projectWithinRadius(attackPosition, state.totem.position, Math.min(
      state.totem.commandRadius,
      HUNTER_TOTEM_LEASH_RADIUS,
    ))
    : attackPosition;
}

function idleTask(cause: TaskCause = 'no-valid-resource'): UnitTask {
  return {
    kind: 'idle',
    targetResourceId: null,
    destination: null,
    cause,
  };
}

function setTaskState(unit: UnitState, task: UnitTask): void {
  unit.task = task;
  unit.actionProgressSeconds = 0;
  if (task.kind !== 'combat') unit.withdrawAfterAttack = false;
  if ((task.kind === 'gather' || task.kind === 'collect-drop')
    && task.targetResourceId !== unit.cancelledTargetId) {
    unit.cancelledTargetId = null;
  }
  unit.state = task.kind === 'gather'
    ? 'seeking-task'
    : task.kind === 'collect-drop'
      ? 'collecting-drop'
        : task.kind === 'combat'
          ? 'combat'
          : task.kind === 'flee'
            ? 'fleeing'
            : task.kind === 'loot-corpse'
              ? 'looting-corpse'
              : task.kind === 'hunt'
                ? 'hunting'
      : task.kind === 'return-to-totem'
        ? 'returning-to-totem'
        : 'idle';
}

function resourceForTask(state: GameState, unit: UnitState) {
  if (!unit.task.targetResourceId) return undefined;
  return state.resources.find((resource) => resource.id === unit.task.targetResourceId);
}

function addEffect(
  state: GameState,
  kind: GameState['effects'][number]['kind'],
  targetId: string,
  position: Vec2,
  durationSeconds: number,
): void {
  state.effects.push({
    id: `effect-${String(state.nextEffectId++).padStart(4, '0')}`,
    kind,
    targetId,
    position: { ...position },
    ageSeconds: 0,
    durationSeconds,
  });
}

function updateEffects(state: GameState, deltaSeconds: number): void {
  for (const effect of state.effects) effect.ageSeconds += deltaSeconds;
  state.effects = state.effects.filter((effect) => effect.ageSeconds < effect.durationSeconds);
}

function updateAlerts(state: GameState, deltaSeconds: number): void {
  for (const alert of state.alerts) alert.ageSeconds += deltaSeconds;
  state.alerts = state.alerts.filter((alert) => alert.ageSeconds < alert.durationSeconds);
}

function updateMinionAttackCooldowns(state: GameState, deltaSeconds: number): void {
  for (const unit of state.units) {
    unit.attackCooldownRemainingSeconds = Math.max(
      unit.attackCooldownRemainingSeconds - deltaSeconds,
      0,
    );
    unit.attackLockRemainingSeconds = Math.max(
      unit.attackLockRemainingSeconds - deltaSeconds,
      0,
    );
  }
}

function patrolWaitSeconds(seed: string, id: string, cycle: number, step: number): number {
  const random = createSeededRandom(`${seed}:${id}:patrol-wait:${cycle}:${step}`);
  return random.nextFloat(BARBARIAN_PATROL_WAIT_MIN_SECONDS, BARBARIAN_PATROL_WAIT_MAX_SECONDS);
}

export function applyDamageToUnit(
  state: GameState,
  unitId: string,
  amount: number,
  sourceKind: CombatantKind,
): number {
  const unit = state.units.find((candidate) => candidate.id === unitId);
  if (!unit) return 0;

  const result = dealDamage(sourceKind, 'minion', unit, amount);
  unit.health = result.health;
  if (result.damageApplied > 0) {
    addEffect(
      state,
      'damage-flash',
      unit.id,
      unit.position,
      DAMAGE_FLASH_DURATION_SECONDS,
    );
  }
  if (result.defeated) {
    state.corpses.push({
      id: `corpse-${String(state.corpses.length + 1).padStart(3, '0')}`,
      formerUnitId: unit.id,
      position: { ...unit.position },
    });
    state.units.splice(state.units.indexOf(unit), 1);
    if (state.units.length === 0) state.phase = 'defeat';
  }
  return result.damageApplied;
}

function campfireForUnit(state: GameState, unit: UnitState): GameState['campfires'][number] | null {
  return state.campfires
    .filter((campfire) => {
      const radius = campfire.healingRadius ?? CAMPFIRE_HEALING_RADIUS;
      const distance = Math.hypot(
        unit.position.x - campfire.position.x,
        unit.position.y - campfire.position.y,
      );
      return distance <= radius;
    })
    .sort((first, second) => first.id.localeCompare(second.id))[0] ?? null;
}

function updateCampfireHealing(state: GameState, deltaSeconds: number): void {
  for (const unit of state.units) {
    const campfire = campfireForUnit(state, unit);
    if (
      !campfire
      || unit.health >= unit.maxHealth
      || state.inventory.amounts.food < 1
    ) {
      unit.healingProgressSeconds = 0;
      continue;
    }

    unit.healingProgressSeconds += deltaSeconds;
    if (unit.healingProgressSeconds + 1e-9 < CAMPFIRE_HEAL_INTERVAL_SECONDS) continue;

    unit.healingProgressSeconds -= CAMPFIRE_HEAL_INTERVAL_SECONDS;
    const result = healCombatant(unit, 1);
    if (result.healingApplied <= 0) continue;

    unit.health = result.health;
    state.inventory.amounts.food -= 1;
    addEffect(
      state,
      'heal-crosses',
      unit.id,
      unit.position,
      HEAL_EFFECT_DURATION_SECONDS,
    );
  }
}

function updateCampfireLifetimes(state: GameState, deltaSeconds: number): void {
  for (const campfire of state.campfires) {
    campfire.remainingLifetimeSeconds = Math.max(
      campfire.remainingLifetimeSeconds - deltaSeconds,
      0,
    );
  }
  const maxDistanceSquared = CAMPFIRE_TOTEM_MAX_DISTANCE ** 2;
  state.campfires = state.campfires.filter((campfire) => {
    const dx = campfire.position.x - state.totem.position.x;
    const dy = campfire.position.y - state.totem.position.y;
    return campfire.remainingLifetimeSeconds > 0 && dx * dx + dy * dy <= maxDistanceSquared;
  });
}

function isWithinTotemIdleRadius(state: GameState, position: Vec2): boolean {
  const dx = position.x - state.totem.position.x;
  const dy = position.y - state.totem.position.y;
  const radius = Math.max(state.totem.commandRadius, FORMATION_RADIUS);
  return dx * dx + dy * dy <= radius * radius;
}

function dropPositionNear(
  state: GameState,
  position: Vec2,
  unitId: string,
  sourceNodeId: string | null,
  type: string,
  dropIndex: number,
): Vec2 {
  const random = createSeededRandom(
    `${state.seed}:drop:${state.tick}:${unitId}:${sourceNodeId ?? 'free'}:${type}`,
  );
  const angle = random.nextFloat(0, Math.PI * 2) + dropIndex * 2.399963229728653;
  const distance = 1.5;
  return clampWorldPosition({
    x: position.x + Math.cos(angle) * distance,
    y: position.y + Math.sin(angle) * distance,
  });
}

function dropResourceAtPosition(
  state: GameState,
  position: Vec2,
  unitId: string,
  sourceNodeId: string | null,
  type: ResourceType,
  amount: number,
): void {
  const wholeAmount = Math.max(Math.floor(amount), 0);
  if (wholeAmount <= 0) return;

  for (let dropIndex = 0; dropIndex < wholeAmount; dropIndex += 1) {
    state.drops.push({
      id: `drop-${String(state.nextDropId++).padStart(5, '0')}`,
      type,
      sourceNodeId,
      position: dropPositionNear(state, position, unitId, sourceNodeId, type, dropIndex),
      amount: 1,
    });
  }
}

function dropCargoAtPosition(
  state: GameState,
  unit: UnitState,
  position: Vec2,
  sourceNodeId: string | null,
): void {
  const amounts = unit.cargo.amounts;
  for (const type of RESOURCE_TYPES) {
    const amount = Math.max(Math.floor(amounts[type]), 0);
    if (amount <= 0) continue;
    dropResourceAtPosition(state, position, unit.id, sourceNodeId, type, amount);
  }

  unit.cargo = {
    ...unit.cargo,
    amounts: createEmptyResourceAmounts(),
  };
  setTaskState(unit, idleTask('cargo-dropped'));
}

function returnToTotemTask(state: GameState, index: number, cause: TaskCause): UnitTask {
  return {
    kind: 'return-to-totem',
    targetResourceId: null,
    destination: formationTarget(state, index),
    cause,
  };
}

function resourceApproachPosition(unitPosition: Vec2, resource: GameState['resources'][number]): Vec2 {
  const dx = unitPosition.x - resource.position.x;
  const dy = unitPosition.y - resource.position.y;
  const distance = Math.hypot(dx, dy);
  const radius = Math.max(resource.interactionRadius, 0.1);
  if (distance < 0.001) {
    return {
      x: resource.position.x + radius,
      y: resource.position.y,
    };
  }

  return {
    x: resource.position.x + (dx / distance) * radius,
    y: resource.position.y + (dy / distance) * radius,
  };
}

function reservedTargetIds(
  state: GameState,
  unit: UnitState,
  taskKind: 'gather' | 'collect-drop',
): ReadonlySet<string> {
  return new Set(
    state.units
      .filter((other) => other.id !== unit.id && other.task.kind === taskKind)
      .map((other) => other.task.targetResourceId)
      .filter((targetId): targetId is string => targetId !== null),
  );
}

function dispatchResourceCall(state: GameState, caller: UnitState): boolean {
  const detectionRadiusSquared = getResourceDetectionRadius(state.totem.commandRadius) ** 2;
  const alreadyAssigned = reservedTargetIds(state, caller, 'gather');
  const nearbyUnusableResources = state.resources
    .filter((resource) => {
      const dx = resource.position.x - caller.position.x;
      const dy = resource.position.y - caller.position.y;
      return resource.amount > 0
        && !canRoleGatherResource(caller.role, resource.type, resource.source)
        && resource.id !== caller.cancelledTargetId
        && !(caller.task.kind === 'gather' && caller.task.targetResourceId === resource.id)
        && !alreadyAssigned.has(resource.id)
        && (dx * dx) + (dy * dy) <= detectionRadiusSquared;
    })
    .sort((first, second) => {
      const firstDx = first.position.x - caller.position.x;
      const firstDy = first.position.y - caller.position.y;
      const secondDx = second.position.x - caller.position.x;
      const secondDy = second.position.y - caller.position.y;
      const distanceDifference = (firstDx * firstDx) + (firstDy * firstDy)
        - ((secondDx * secondDx) + (secondDy * secondDy));
      return distanceDifference || first.id.localeCompare(second.id);
    });

  for (const resource of nearbyUnusableResources) {
    const responder = state.units
      .filter((candidate) => (
        candidate.id !== caller.id
        && (candidate.task.kind === 'idle' || candidate.task.kind === 'return-to-totem')
        && totalResourceAmount(candidate.cargo.amounts) === 0
        && candidate.cancelledTargetId !== resource.id
        && canRoleGatherResource(candidate.role, resource.type, resource.source)
      ))
      .sort((first, second) => {
        const firstDx = first.position.x - resource.position.x;
        const firstDy = first.position.y - resource.position.y;
        const secondDx = second.position.x - resource.position.x;
        const secondDy = second.position.y - resource.position.y;
        const distanceDifference = (firstDx * firstDx) + (firstDy * firstDy)
          - ((secondDx * secondDx) + (secondDy * secondDy));
        return distanceDifference || first.id.localeCompare(second.id);
      })[0];

    if (!responder) continue;

    setTaskState(responder, {
      kind: 'gather',
      targetResourceId: resource.id,
      destination: { ...resource.position },
      cause: 'resource-call-received',
    });
    return true;
  }

  return false;
}

function distanceBetween(first: Vec2, second: Vec2): number {
  return Math.hypot(first.x - second.x, first.y - second.y);
}

function entityTask(
  kind: UnitTask['kind'],
  cause: TaskCause,
  targetEntityId: string | null,
): UnitTask {
  return {
    kind,
    cause,
    targetResourceId: null,
    targetEntityId,
    destination: null,
  };
}

function recordDetectionAlert(
  state: GameState,
  detectorKind: 'minion' | 'barbarian',
  detectorId: string,
  position: Vec2,
  playSound: boolean,
): void {
  state.alerts.push({
    id: `alert-${String(state.nextAlertId++).padStart(5, '0')}`,
    detectorKind,
    detectorId,
    position: { ...position },
    ageSeconds: 0,
    durationSeconds: COMBAT_ALERT_DURATION_SECONDS,
    playSound,
  });
}

function nearestBarbarian(
  unit: UnitState,
  barbarians: readonly BarbarianState[],
  radius: number,
): BarbarianState | null {
  return barbarians
    .filter((barbarian) => barbarian.isAlive
      && distanceBetween(unit.position, barbarian.position) <= radius)
    .sort((first, second) => (
      distanceBetween(unit.position, first.position) - distanceBetween(unit.position, second.position)
      || first.id.localeCompare(second.id)
    ))[0] ?? null;
}

function nearestUnit(
  barbarian: BarbarianState,
  units: readonly UnitState[],
  radius: number,
): UnitState | null {
  return units
    .filter((unit) => distanceBetween(unit.position, barbarian.position) <= radius)
    .sort((first, second) => (
      distanceBetween(first.position, barbarian.position)
      - distanceBetween(second.position, barbarian.position)
      || first.id.localeCompare(second.id)
    ))[0] ?? null;
}

function approachPoint(position: Vec2, target: Vec2, range: number): Vec2 {
  const dx = position.x - target.x;
  const dy = position.y - target.y;
  const distance = Math.hypot(dx, dy);
  if (distance <= range || distance < 0.001) return { ...position };
  return {
    x: target.x + (dx / distance) * range,
    y: target.y + (dy / distance) * range,
  };
}

function moveToSeededPatrolPoint(
  seed: string,
  id: string,
  cycle: number,
  step: number,
  center: Vec2,
  radius: number,
): Vec2 {
  const random = createSeededRandom(`${seed}:${id}:patrol:${cycle}:${step}`);
  const angle = random.nextFloat(0, Math.PI * 2);
  const distance = Math.sqrt(random.nextFloat(0, radius ** 2));
  return clampWorldPosition({
    x: center.x + Math.cos(angle) * distance,
    y: center.y + Math.sin(angle) * distance,
  });
}

function deterministicLoot(state: GameState, barbarian: BarbarianState) {
  const random = createSeededRandom(
    `${state.seed}:barbarian-loot:${barbarian.id}:${barbarian.spawnCycle}`,
  );
  const loot = createEmptyResourceAmounts();
  loot.gold = random.nextInt(1, 2);
  loot.food = random.nextInt(0, 2);
  loot.wood = random.nextInt(0, 1);
  return loot;
}

function defeatBarbarian(state: GameState, barbarian: BarbarianState): void {
  if (!barbarian.isAlive) return;
  awardExperience(
    state.progression,
    PROGRESSION_BALANCE.experiencePerBarbarianDefeated,
  );
  barbarian.health = 0;
  barbarian.isAlive = false;
  barbarian.respawnRemainingSeconds = BARBARIAN_RESPAWN_SECONDS;
  barbarian.targetUnitId = null;
  state.alerts = state.alerts.filter((alert) => (
    alert.detectorKind !== 'barbarian' || alert.detectorId !== barbarian.id
  ));
  state.barbarianCorpses.push({
    id: `corpse-${barbarian.id}-${barbarian.spawnCycle}`,
    barbarianId: barbarian.id,
    position: { ...barbarian.position },
    loot: deterministicLoot(state, barbarian),
  });
}

function defeatRabbit(state: GameState, animal: AnimalState): void {
  if (!animal.isAlive) return;
  awardExperience(
    state.progression,
    PROGRESSION_BALANCE.experiencePerRabbitDefeated,
  );
  animal.health = 0;
  animal.isAlive = false;
  animal.respawnRemainingSeconds = RABBIT_RESPAWN_SECONDS;
  const random = createSeededRandom(
    `${state.seed}:rabbit-loot:${animal.id}:${animal.spawnCycle}`,
  );
  dropResourceAtPosition(state, animal.position, animal.id, animal.id, 'food', random.nextInt(1, 2));
}

function updateRespawnsAndFauna(state: GameState, deltaSeconds: number): void {
  for (const barbarian of state.barbarians) {
    if (barbarian.isAlive) continue;
    barbarian.respawnRemainingSeconds = Math.max(
      barbarian.respawnRemainingSeconds - deltaSeconds,
      0,
    );
    if (barbarian.respawnRemainingSeconds < 1e-9) barbarian.respawnRemainingSeconds = 0;
    if (barbarian.respawnRemainingSeconds > 0) continue;
    barbarian.isAlive = true;
    barbarian.health = barbarian.maxHealth;
    barbarian.position = { ...barbarian.spawnPosition };
    barbarian.patrolTarget = { ...barbarian.spawnPosition };
    barbarian.patrolStep = 0;
    barbarian.returningToSpawn = false;
    barbarian.patrolWaitRemainingSeconds = patrolWaitSeconds(
      state.seed,
      barbarian.id,
      barbarian.spawnCycle + 1,
      barbarian.patrolStep,
    );
    barbarian.attackProgressSeconds = BARBARIAN_ATTACK_COOLDOWN_SECONDS;
    barbarian.targetUnitId = null;
    barbarian.alertedUnitIds = [];
    barbarian.alertSoundedThisEncounter = false;
    barbarian.spawnCycle += 1;
  }

  for (const animal of state.animals) {
    if (!animal.isAlive) {
      animal.respawnRemainingSeconds = Math.max(
        animal.respawnRemainingSeconds - deltaSeconds,
        0,
      );
      if (animal.respawnRemainingSeconds < 1e-9) animal.respawnRemainingSeconds = 0;
      if (animal.respawnRemainingSeconds > 0) continue;
      animal.isAlive = true;
      animal.health = animal.maxHealth;
      animal.position = { ...animal.spawnPosition };
      animal.patrolTarget = moveToSeededPatrolPoint(
        state.seed,
        animal.id,
        animal.spawnCycle + 1,
        animal.spawnCycle + 1,
        animal.homeCenter,
        animal.homeRadius,
      );
      animal.spawnCycle += 1;
      continue;
    }

    if (distanceBetween(animal.position, animal.patrolTarget) <= 0.2) {
      animal.patrolTarget = moveToSeededPatrolPoint(
        state.seed,
        animal.id,
        animal.spawnCycle,
        state.tick,
        animal.homeCenter,
        animal.homeRadius,
      );
    }
    moveTowards(animal.position, animal.patrolTarget, 1.2 * deltaSeconds);
  }
}

function reserveCorpseIds(state: GameState, unit: UnitState): ReadonlySet<string> {
  return new Set(state.units
    .filter((other) => other.id !== unit.id && other.task.kind === 'loot-corpse')
    .map((other) => other.task.targetEntityId)
    .filter((id): id is string => id !== null && id !== undefined));
}

function chooseCorpseTask(state: GameState, unit: UnitState): UnitTask | null {
  const reserved = reserveCorpseIds(state, unit);
  const radius = getResourceDetectionRadius(state.totem.commandRadius);
  const corpse = state.barbarianCorpses
    .filter((candidate) => totalResourceAmount(candidate.loot) > 0
      && !reserved.has(candidate.id)
      && distanceBetween(unit.position, candidate.position) <= radius)
    .sort((first, second) => (
      distanceBetween(unit.position, first.position) - distanceBetween(unit.position, second.position)
      || first.id.localeCompare(second.id)
    ))[0];
  return corpse ? entityTask('loot-corpse', 'corpse-found', corpse.id) : null;
}

function chooseRabbit(state: GameState, unit: UnitState): AnimalState | null {
  if (unit.role !== 'hunter') return null;
  const radius = getResourceDetectionRadius(state.totem.commandRadius);
  return state.animals
    .filter((animal) => animal.isAlive && distanceBetween(unit.position, animal.position) <= radius)
    .sort((first, second) => (
      distanceBetween(unit.position, first.position) - distanceBetween(unit.position, second.position)
      || first.id.localeCompare(second.id)
    ))[0] ?? null;
}

function chooseCombatTarget(state: GameState, unit: UnitState): BarbarianState | null {
  const currentTarget = state.barbarians.find((barbarian) => (
    barbarian.isAlive
    && barbarian.id === unit.task.targetEntityId
    && distanceBetween(unit.position, barbarian.position) <= MINION_THREAT_DETECTION_RADIUS
  ));
  if (currentTarget) return currentTarget;

  return state.barbarians
    .filter((barbarian) => barbarian.isAlive
      && distanceBetween(unit.position, barbarian.position) <= MINION_THREAT_DETECTION_RADIUS)
    .sort((first, second) => {
      const firstEngagers = state.units.filter((candidate) => (
        candidate.id !== unit.id
        && candidate.task.kind === 'combat'
        && candidate.task.targetEntityId === first.id
      )).length;
      const secondEngagers = state.units.filter((candidate) => (
        candidate.id !== unit.id
        && candidate.task.kind === 'combat'
        && candidate.task.targetEntityId === second.id
      )).length;
      return firstEngagers - secondEngagers
        || distanceBetween(unit.position, first.position) - distanceBetween(unit.position, second.position)
        || first.id.localeCompare(second.id);
    })[0] ?? null;
}

function applyMinionAttack(
  state: GameState,
  unit: UnitState,
  target: BarbarianState | AnimalState,
  stats: AttackStats,
  targetKind: 'barbarian' | 'animal',
): boolean {
  unit.attackCooldownRemainingSeconds = stats.cooldownSeconds;
  if (unit.role === 'hunter') unit.attackLockRemainingSeconds = ATTACK_LUNGE_DURATION_SECONDS;
  addEffect(state, 'attack-lunge', unit.id, target.position, ATTACK_LUNGE_DURATION_SECONDS);
  const result = dealDamage('minion', targetKind, target, stats.damage);
  target.health = result.health;
  if (targetKind === 'barbarian' && result.damageApplied > 0) {
    addEffect(state, 'damage-flash', target.id, target.position, DAMAGE_FLASH_DURATION_SECONDS);
  }
  if (result.defeated) {
    if (targetKind === 'barbarian') defeatBarbarian(state, target as BarbarianState);
    else defeatRabbit(state, target as AnimalState);
  }
  return result.defeated;
}

function updateConflict(state: GameState, deltaSeconds: number): void {
  updateRespawnsAndFauna(state, deltaSeconds);

  for (const barbarian of state.barbarians) {
    if (!barbarian.isAlive) continue;
    const detectedUnits = state.units
      .filter((unit) => distanceBetween(unit.position, barbarian.position) <= MINION_THREAT_DETECTION_RADIUS)
      .sort((first, second) => first.id.localeCompare(second.id));
    if (detectedUnits.length === 0) {
      barbarian.alertedUnitIds = [];
      barbarian.alertSoundedThisEncounter = false;
    }
    for (const unit of detectedUnits) {
      const minionKey = `minion:${unit.id}`;
      if (!barbarian.alertedUnitIds.includes(minionKey)) {
        barbarian.alertedUnitIds.push(minionKey);
        const playSound = !barbarian.alertSoundedThisEncounter;
        barbarian.alertSoundedThisEncounter = true;
        recordDetectionAlert(state, 'minion', unit.id, unit.position, playSound);
      }

      if (distanceBetween(unit.position, barbarian.position) <= BARBARIAN_DETECTION_RADIUS) {
        const barbarianKey = `barbarian:${unit.id}`;
        if (!barbarian.alertedUnitIds.includes(barbarianKey)) {
          barbarian.alertedUnitIds.push(barbarianKey);
          recordDetectionAlert(state, 'barbarian', barbarian.id, barbarian.position, false);
        }
      }
    }
  }

  const totemMoving = state.totem.isCarried || state.totem.moving;
  for (const [index, unit] of state.units.entries()) {
    const canFight = MINION_ATTACK_STATS[unit.role] !== undefined;
    if (totemMoving) {
      const currentTarget = state.barbarians.find((barbarian) => (
        barbarian.isAlive && barbarian.id === unit.task.targetEntityId
      ));
      const stats = MINION_ATTACK_STATS[unit.role];
      const stillCanFinishStrike = unit.task.kind === 'combat'
        && !!currentTarget
        && !!stats
        && distanceBetween(unit.position, currentTarget.position) <= stats.range + 1e-6;
      if (stillCanFinishStrike) {
        unit.withdrawAfterAttack = true;
      } else if (unit.task.kind === 'combat' || unit.task.kind === 'flee' || unit.task.kind === 'hunt') {
        setTaskState(unit, returnToTotemTask(state, index, 'totem-moved'));
      }
      continue;
    }

    unit.withdrawAfterAttack = false;
    const threat = nearestBarbarian(unit, state.barbarians, MINION_THREAT_DETECTION_RADIUS);
    if (canFight && threat) {
      const target = chooseCombatTarget(state, unit) ?? threat;
      setTaskState(unit, entityTask('combat', 'threat-nearby', target.id));
      continue;
    }

    if (!canFight && threat && distanceBetween(unit.position, threat.position) <= BARBARIAN_DETECTION_RADIUS) {
      setTaskState(unit, entityTask('flee', 'threat-nearby', threat.id));
      continue;
    }
    if (unit.task.kind === 'flee' || unit.task.kind === 'combat') {
      setTaskState(unit, idleTask('combat-ended'));
    }

    if (!state.totem.moving && unit.role === 'hunter') {
      const currentAnimal = state.animals.find((animal) => (
        animal.isAlive && animal.id === unit.task.targetEntityId
      ));
      const rabbit = currentAnimal
        && distanceBetween(unit.position, currentAnimal.position)
          <= getResourceDetectionRadius(state.totem.commandRadius) + 2
        ? currentAnimal
        : chooseRabbit(state, unit);
      if (rabbit) {
        setTaskState(unit, entityTask('hunt', 'animal-found', rabbit.id));
        continue;
      }
    }
    if (unit.task.kind === 'hunt') setTaskState(unit, idleTask('no-valid-resource'));
  }

  for (const [index, unit] of state.units.entries()) {
    if (unit.role === 'hunter' && unit.attackLockRemainingSeconds > 0) continue;

    if (unit.task.kind === 'flee') {
      moveUnitTowards(state, unit, formationTarget(state, index), TOTEM_CHASE_SPEED * deltaSeconds);
      continue;
    }

    if (unit.task.kind === 'combat') {
      const barbarian = state.barbarians.find((candidate) => (
        candidate.isAlive && candidate.id === unit.task.targetEntityId
      ));
      const stats = MINION_ATTACK_STATS[unit.role];
      if (!barbarian || !stats) {
        setTaskState(
          unit,
          totemMoving
            ? returnToTotemTask(state, index, 'totem-moved')
            : idleTask('combat-ended'),
        );
        continue;
      }
      const distance = distanceBetween(unit.position, barbarian.position);
      if (unit.withdrawAfterAttack) {
        if (distance > stats.range + 1e-6) {
          setTaskState(unit, returnToTotemTask(state, index, 'totem-moved'));
          continue;
        }
        if (unit.attackCooldownRemainingSeconds <= 1e-9) {
          applyMinionAttack(state, unit, barbarian, stats, 'barbarian');
          setTaskState(unit, returnToTotemTask(state, index, 'totem-moved'));
        }
        continue;
      }
      if (unit.role === 'hunter'
        && distance <= stats.range + 1e-6
        && unit.attackCooldownRemainingSeconds <= 1e-9) {
        applyMinionAttack(state, unit, barbarian, stats, 'barbarian');
        continue;
      }
      const attackPosition = combatApproachPoint(state, unit, barbarian, stats.range);
      const distanceToSlot = distanceBetween(unit.position, attackPosition);
      if (distanceToSlot > 0.2) {
        moveUnitTowards(
          state,
          unit,
          attackPosition,
          (unit.role === 'hunter' ? HUNTER_COMBAT_SPEED : UNIT_SPEED) * deltaSeconds,
        );
      }
      if (unit.role !== 'hunter'
        && distanceBetween(unit.position, barbarian.position) <= stats.range + 1e-6
        && unit.attackCooldownRemainingSeconds <= 1e-9) {
        applyMinionAttack(state, unit, barbarian, stats, 'barbarian');
      }
      continue;
    }

    if (unit.task.kind === 'hunt') {
      const animal = state.animals.find((candidate) => (
        candidate.isAlive && candidate.id === unit.task.targetEntityId
      ));
      if (!animal) {
        setTaskState(
          unit,
          totemMoving
            ? returnToTotemTask(state, index, 'totem-moved')
            : idleTask('action-complete'),
        );
        continue;
      }
      const distance = distanceBetween(unit.position, animal.position);
      if (distance > ANIMAL_ATTACK_STATS.range) {
        moveUnitTowards(
          state,
          unit,
          approachPoint(unit.position, animal.position, ANIMAL_ATTACK_STATS.range),
          UNIT_SPEED * deltaSeconds,
        );
      }
      if (distanceBetween(unit.position, animal.position) <= ANIMAL_ATTACK_STATS.range + 1e-6
        && unit.attackCooldownRemainingSeconds <= 1e-9) {
        applyMinionAttack(state, unit, animal, ANIMAL_ATTACK_STATS, 'animal');
      }
    }
  }

  for (const barbarian of state.barbarians) {
    if (!barbarian.isAlive) continue;
    const hadTarget = barbarian.targetUnitId !== null;
    const target = nearestUnit(barbarian, state.units, BARBARIAN_DETECTION_RADIUS);
    barbarian.targetUnitId = target?.id ?? null;
    if (target) {
      barbarian.returningToSpawn = false;
      const distance = distanceBetween(barbarian.position, target.position);
      if (distance > BARBARIAN_ATTACK_RANGE) {
        moveTowards(
          barbarian.position,
          approachPoint(barbarian.position, target.position, BARBARIAN_ATTACK_RANGE),
          BARBARIAN_MOVEMENT_SPEED * deltaSeconds,
        );
      }
      if (distanceBetween(barbarian.position, target.position) <= BARBARIAN_ATTACK_RANGE + 1e-6) {
        barbarian.attackProgressSeconds = Math.min(
          barbarian.attackProgressSeconds + deltaSeconds,
          BARBARIAN_ATTACK_COOLDOWN_SECONDS,
        );
        if (barbarian.attackProgressSeconds + 1e-9 >= BARBARIAN_ATTACK_COOLDOWN_SECONDS) {
          barbarian.attackProgressSeconds = 0;
          addEffect(state, 'attack-lunge', barbarian.id, target.position, ATTACK_LUNGE_DURATION_SECONDS);
          applyDamageToUnit(state, target.id, BARBARIAN_ATTACK_DAMAGE, 'barbarian');
        }
      } else {
        barbarian.attackProgressSeconds = Math.min(
          barbarian.attackProgressSeconds + deltaSeconds,
          BARBARIAN_ATTACK_COOLDOWN_SECONDS,
        );
      }
      continue;
    }

    const distanceToSpawn = distanceBetween(barbarian.position, barbarian.spawnPosition);
    if (barbarian.returningToSpawn || (hadTarget && distanceToSpawn > 0.25)) {
      barbarian.returningToSpawn = true;
      const reachedSpawn = moveTowards(
        barbarian.position,
        barbarian.spawnPosition,
        BARBARIAN_MOVEMENT_SPEED * deltaSeconds,
      );
      if (reachedSpawn) {
        barbarian.returningToSpawn = false;
        barbarian.patrolTarget = { ...barbarian.spawnPosition };
        barbarian.patrolStep = 0;
        barbarian.patrolWaitRemainingSeconds = patrolWaitSeconds(
          state.seed,
          barbarian.id,
          barbarian.spawnCycle,
          barbarian.patrolStep,
        );
      }
      continue;
    }

    if (barbarian.patrolWaitRemainingSeconds > 0) {
      barbarian.patrolWaitRemainingSeconds = Math.max(
        barbarian.patrolWaitRemainingSeconds - deltaSeconds,
        0,
      );
      if (barbarian.patrolWaitRemainingSeconds > 0) continue;
      barbarian.patrolTarget = moveToSeededPatrolPoint(
        state.seed,
        barbarian.id,
        barbarian.spawnCycle,
        barbarian.patrolStep,
        barbarian.patrolCenter,
        barbarian.patrolRadius,
      );
      barbarian.patrolStep += 1;
    }

    if (distanceBetween(barbarian.position, barbarian.patrolTarget) <= 0.25) {
      barbarian.patrolWaitRemainingSeconds = patrolWaitSeconds(
        state.seed,
        barbarian.id,
        barbarian.spawnCycle,
        barbarian.patrolStep,
      );
      continue;
    }
    const reachedPatrolTarget = moveTowards(
      barbarian.position,
      barbarian.patrolTarget,
      BARBARIAN_PATROL_SPEED * deltaSeconds,
    );
    if (reachedPatrolTarget) {
      barbarian.patrolWaitRemainingSeconds = patrolWaitSeconds(
        state.seed,
        barbarian.id,
        barbarian.spawnCycle,
        barbarian.patrolStep,
      );
    }
  }
}

function updateSurvivalUnit(
  state: GameState,
  unit: UnitState,
  index: number,
  deltaSeconds: number,
): void {
  if (unit.role === 'hunter' && unit.attackLockRemainingSeconds > 0) return;

  if (unit.task.kind === 'idle') {
    if (totalResourceAmount(unit.cargo.amounts) > 0) {
      dropCargoAtPosition(state, unit, unit.position, null);
      return;
    }

    // Priority order: enemies (when combat exists) > resources > drops.
    // The enemy branch will be inserted before this resource selection; the
    // totem pickup interruption is handled outside autonomous task choice.
    const gatherTask = chooseGatherTask({
      role: unit.role,
      unitPosition: unit.position,
      totemPosition: state.totem.position,
      commandRadius: state.totem.commandRadius,
      cargo: unit.cargo,
      resources: state.resources,
      reservedTargetIds: reservedTargetIds(state, unit, 'gather'),
      excludedTargetId: unit.cancelledTargetId,
    });
    const corpseTask = chooseCorpseTask(state, unit);
    if (corpseTask) {
      setTaskState(unit, corpseTask);
      return;
    }
    if (gatherTask.kind === 'gather') {
      setTaskState(unit, gatherTask);
      return;
    }

    const dropTask = chooseCollectDropTask({
      unitPosition: unit.position,
      drops: state.drops,
      commandRadius: state.totem.commandRadius,
      reservedTargetIds: reservedTargetIds(state, unit, 'collect-drop'),
      excludedTargetId: unit.cancelledTargetId,
    });
    if (dropTask.kind === 'collect-drop') {
      setTaskState(unit, dropTask);
      return;
    }

    setTaskState(unit, gatherTask);
    if (!isWithinTotemIdleRadius(state, unit.position)) {
      setTaskState(unit, returnToTotemTask(state, index, 'no-valid-resource'));
    }
    return;
  }

  if (unit.task.kind === 'loot-corpse') {
    const corpse = state.barbarianCorpses.find((candidate) => (
      candidate.id === unit.task.targetEntityId
    ));
    if (!corpse || totalResourceAmount(corpse.loot) <= 0) {
      setTaskState(unit, idleTask('corpse-looted'));
      return;
    }

    const lootInteractionPosition = approachPoint(unit.position, corpse.position, 1.25);
    if (!moveUnitTowards(state, unit, lootInteractionPosition, UNIT_SPEED * deltaSeconds)) {
      unit.state = 'looting-corpse';
      return;
    }

    unit.state = 'looting-corpse';
    unit.actionProgressSeconds += deltaSeconds;
    if (unit.actionProgressSeconds + 1e-9 < GATHER_ACTION_DURATION_SECONDS) return;

    for (const resourceType of ['gold', 'food', 'wood'] as const) {
      dropResourceAtPosition(
        state,
        corpse.position,
        unit.id,
        corpse.id,
        resourceType,
        corpse.loot[resourceType],
      );
    }
    state.barbarianCorpses = state.barbarianCorpses.filter((candidate) => candidate.id !== corpse.id);
    setTaskState(unit, idleTask('corpse-looted'));
    return;
  }

  if (unit.task.kind === 'gather') {
    const resource = resourceForTask(state, unit);
    if (!resource || resource.amount <= 0) {
      if (totalResourceAmount(unit.cargo.amounts) > 0) {
        dropCargoAtPosition(state, unit, resource?.position ?? unit.position, resource?.id ?? null);
      } else {
        setTaskState(unit, idleTask('resource-depleted'));
      }
      return;
    }

    if (!moveUnitTowards(
      state,
      unit,
      resourceApproachPosition(unit.position, resource),
      UNIT_SPEED * deltaSeconds,
    )) {
      unit.state = 'seeking-task';
      return;
    }

    unit.state = 'gathering';
    unit.actionProgressSeconds += deltaSeconds;
    if (unit.actionProgressSeconds < GATHER_ACTION_DURATION_SECONDS) return;

    // Hito 2A economy: one completed action always produces one whole unit.
    const gathered = gatherFromNode(resource, 1);
    resource.amount = gathered.node.amount;
    // A node never adds resources directly to inventory or cargo. Consuming
    // the node creates the physical drop, which must be detected and picked
    // up in a later task before it reaches the inventory.
    dropResourceAtPosition(
      state,
      resource.position,
      unit.id,
      resource.id,
      resource.type,
      resource.yieldAmount ?? gathered.gathered,
    );
    if (gathered.gathered > 0) {
      awardExperience(
        state.progression,
        PROGRESSION_BALANCE.experiencePerGatherAction,
      );
    }
    setTaskState(unit, idleTask('action-complete'));
    return;
  }

  if (unit.task.kind === 'collect-drop') {
    const drop = state.drops.find((candidate) => candidate.id === unit.task.targetResourceId);
    if (!drop || drop.amount <= 0) {
      setTaskState(unit, idleTask('drop-empty'));
      return;
    }

    if (!moveUnitTowards(state, unit, drop.position, UNIT_SPEED * deltaSeconds)) {
      unit.state = 'collecting-drop';
      return;
    }

    const collected = collectDrop(drop, state.inventory.amounts);
    state.inventory.amounts = collected.inventory;
    state.drops = state.drops.filter((candidate) => candidate.id !== drop.id);
    setTaskState(unit, idleTask('drop-collected'));
    return;
  }

  if (unit.task.kind === 'return-to-totem') {
    const destination = unit.task.destination ?? formationTarget(state, index);
    if (!moveUnitTowards(state, unit, destination, TOTEM_CHASE_SPEED * deltaSeconds)) {
      unit.state = 'returning-to-totem';
      return;
    }

    setTaskState(unit, idleTask('action-complete'));
  }
}

function updateFormationUnit(
  state: GameState,
  unit: UnitState,
  index: number,
  deltaSeconds: number,
): boolean {
  const target = formationTarget(state, index);
  const reached = moveUnitTowards(state, unit, target, TOTEM_CHASE_SPEED * deltaSeconds);
  const distanceToTarget = Math.hypot(
    target.x - unit.position.x,
    target.y - unit.position.y,
  );

  unit.state = state.totem.isCarried || state.totem.moving
    ? 'follow-totem'
    : 'formation';
  unit.task = idleTask('totem-moved');

  return reached || distanceToTarget <= FORMATION_TOLERANCE;
}

function applyAction(state: GameState, action: InputAction): void {
  if (action.type === 'toggle-pause') {
    if (state.phase === 'playing') state.phase = 'paused';
    else if (state.phase === 'paused') state.phase = 'playing';
    return;
  }

  if (action.type === 'debug-add-resource') {
    const amount = Number.isFinite(action.amount) ? Math.max(action.amount, 0) : 0;
    state.inventory.amounts[action.resource] += amount;
    return;
  }

  if (action.type === 'debug-damage-one-minion') {
    const target = [...state.units]
      .sort((first, second) => first.health - second.health || first.id.localeCompare(second.id))[0];
    if (target) applyDamageToUnit(state, target.id, 1, 'barbarian');
    return;
  }

  if (action.type === 'debug-level-up') {
    const progression = state.progression;
    awardExperience(
      progression,
      Math.max(0, progression.experienceToNextLevel - progression.experience),
    );
    return;
  }

  if (state.phase !== 'playing') return;

  switch (action.type) {
    case 'pick-up-totem':
      if (state.totem.isCarried) return;
      state.totem.isCarried = true;
      state.totem.moving = false;
      state.totem.destination = null;
      state.totem.dragTarget = { ...state.totem.position };
      return;
    case 'drag-totem':
      if (!state.totem.isCarried) return;
      state.totem.position = clampWorldPosition(action.position);
      state.totem.dragTarget = { ...state.totem.position };
      return;
    case 'drop-totem':
      if (!state.totem.isCarried) return;
      state.totem.isCarried = false;
      state.totem.moving = true;
      state.totem.destination = null;
      state.totem.dragTarget = null;
      return;
    case 'damage-unit':
      applyDamageToUnit(state, action.unitId, action.amount, action.sourceKind);
      return;
    case 'place-campfire':
      if (
        state.campfires.length >= MAX_ACTIVE_CAMPFIRES
        || state.inventory.amounts.wood < CAMPFIRE_WOOD_COST
      ) return;
      state.inventory.amounts.wood -= CAMPFIRE_WOOD_COST;
      state.campfires.push({
        id: `campfire-${String(state.nextCampfireId).padStart(2, '0')}`,
        position: clampWorldPosition(action.position),
        healingRadius: CAMPFIRE_HEALING_RADIUS,
        remainingLifetimeSeconds: CAMPFIRE_LIFETIME_SECONDS,
      });
      state.nextCampfireId += 1;
      return;
    case 'recruit-gatherer': {
      const cost = getMinionPurchaseCost(
        state.units.length,
        STARTING_MINION_COUNT,
      );
      if (
        state.units.length >= MAX_PLAYABLE_MINIONS
        || state.inventory.amounts.food < cost
      ) return;

      state.inventory.amounts.food -= cost;
      state.purchaseCounts.gatherer += 1;
      const unit = createUnitState(
        `unit-gatherer-${String(state.purchaseCounts.gatherer + 1).padStart(2, '0')}`,
        'gatherer',
        projectRecruitmentPosition(action.position, state.totem.position),
      );
      state.units.push(unit);
      setTaskState(
        unit,
        returnToTotemTask(state, state.units.length - 1, 'action-complete'),
      );
      return;
    }
    case 'unlock-technology':
      unlockTechnology(state.progression, action.technology);
      return;
    case 'equip-shield': {
      if (!state.progression.unlockedTechnologies.includes('shield')) return;
      const unit = state.units.find((candidate) => candidate.id === action.unitId);
      if (!unit || unit.role !== 'guardian' || unit.hasShield) return;

      const shieldsInUse = state.units.filter((candidate) => (
        candidate.role === 'guardian' && candidate.hasShield
      )).length;
      const cost = getMinionPurchaseCost(shieldsInUse);
      if (state.inventory.amounts.gold < cost) return;

      state.inventory.amounts.gold -= cost;
      unit.hasShield = true;
      unit.maxHealth += PROGRESSION_BALANCE.shieldMaximumHealthBonus;
      unit.health = Math.min(
        unit.health + PROGRESSION_BALANCE.shieldMaximumHealthBonus,
        unit.maxHealth,
      );
      return;
    }
    case 'transform-unit': {
      const unit = state.units.find((candidate) => candidate.id === action.unitId);
      if (!unit || unit.role !== 'gatherer') return;
      if (action.item === 'hammer'
        && !state.progression.unlockedTechnologies.includes('artisan')) return;
      if (action.item === 'axe' && !canConvertLastGathererToLumberjack(state.units)) return;

      const purchaseKey = action.item === 'axe'
        ? 'lumberjack'
        : action.item === 'bow'
          ? 'hunter'
          : action.item === 'hammer'
            ? 'artisan'
            : 'guardian';
      const targetRole = getSpecializationRole(action.item);
      const activeTargetMinions = countUnitsWithRole(state.units, targetRole);
      if (activeTargetMinions >= MAX_MINIONS_PER_TYPE) return;
      const cost = action.item === 'sword' ? 2 : getMinionPurchaseCost(activeTargetMinions);
      const costType = action.item === 'sword' ? 'gold' : 'wood';
      if (state.inventory.amounts[costType] < cost) return;

      state.inventory.amounts[costType] -= cost;
      state.purchaseCounts[purchaseKey] += 1;
      unit.role = targetRole;
      setTaskState(unit, idleTask('action-complete'));
      return;
    }
  }
}

export function applyInputActions(state: GameState, actions: InputAction[]): void {
  for (const action of actions) applyAction(state, action);
}

export function stepSimulation(
  state: GameState,
  deltaSeconds: number,
  actions: InputAction[] = [],
  options: StepSimulationOptions = {},
): void {
  applyInputActions(state, actions);
  if (state.units.length === 0 && state.phase !== 'victory') state.phase = 'defeat';
  if (state.phase === 'paused' || state.phase === 'victory') return;

  state.tick += 1;

  if (state.phase === 'defeat') {
    updateEffects(state, deltaSeconds);
    updateAlerts(state, deltaSeconds);
    return;
  }

  updateWeather(state, deltaSeconds);

  updateMinionAttackCooldowns(state, deltaSeconds);

  if (options.enableSurvival && !state.totem.isCarried && !state.totem.moving) {
    // Calls are a lightweight coordination pass: a minion can ask for help
    // without dropping its own active task, and every target is still reserved
    // for at most one responder.
    for (const caller of state.units) dispatchResourceCall(state, caller);
  }
  if (options.enableSurvival) updateConflict(state, deltaSeconds);

  let allUnitsInFormation = true;
  for (const [index, unit] of state.units.entries()) {
    if (unit.task.kind === 'combat' || unit.task.kind === 'flee' || unit.task.kind === 'hunt') {
      allUnitsInFormation = false;
      continue;
    }
    if (state.totem.isCarried || state.totem.moving || !options.enableSurvival) {
      if (options.enableSurvival && (
        unit.task.kind === 'gather'
        || unit.task.kind === 'collect-drop'
        || unit.task.kind === 'loot-corpse'
      )) {
        unit.cancelledTargetId = unit.task.targetResourceId;
        unit.actionProgressSeconds = 0;
      }
      if (options.enableSurvival && totalResourceAmount(unit.cargo.amounts) > 0) {
        dropCargoAtPosition(
          state,
          unit,
          unit.position,
          resourceForTask(state, unit)?.id ?? null,
        );
      }
      if (!updateFormationUnit(state, unit, index, deltaSeconds)) {
        allUnitsInFormation = false;
      }
    } else {
      updateSurvivalUnit(state, unit, index, deltaSeconds);
    }
  }

  if (!state.totem.isCarried && state.totem.moving && allUnitsInFormation) {
    state.totem.moving = false;
    for (const unit of state.units) unit.cancelledTargetId = null;
  }

  resolveActorSpacing(state);

  updateCampfireLifetimes(state, deltaSeconds);
  updateCampfireHealing(state, deltaSeconds);
  updateEffects(state, deltaSeconds);
  updateAlerts(state, deltaSeconds);
}

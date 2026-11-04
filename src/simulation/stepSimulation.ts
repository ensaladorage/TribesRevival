import type { InputAction } from '../input/actions';
import { createUnitState } from './createInitialState';
import type { AnimalState, BarbarianState, GameState, UnitState, Vec2 } from './types';
import { createSeededRandom } from './seededRandom';
import {
  chooseCollectDropTask,
  chooseGatherTask,
  canRoleGatherNode,
  canConvertLastGathererToNonCombatSpecialist,
  collectDrop,
  countUnitsWithRole,
  gatherFromNode,
  getResourceDetectionRadius,
  getSpecializationRole,
  totalResourceAmount,
} from './survivalRules';
import {
  MAX_PLAYABLE_MINIONS,
  MAX_TOOL_LEVEL,
  canAffordCost,
  getGatherActionDurationMultiplier,
  getGathererRecruitmentCost,
  getShieldCost,
  getSpecializationCost,
  getSpecializationLimit,
  getToolUpgradeCost,
  rollsToolBonusResource,
  spendCost,
} from './economyConfig';
import {
  createEmptyResourceAmounts,
  CAMPFIRE_HEALING_RADIUS,
  CAMPFIRE_LIFETIME_SECONDS,
  CAMPFIRE_TOTEM_MAX_DISTANCE,
  MAX_ACTIVE_CAMPFIRES,
  CAMPFIRE_WOOD_COST,
  RESOURCE_TYPES,
} from './survivalTypes';
import type { ResourceNode, ResourceType, TaskCause, UnitTask } from './survivalTypes';
import {
  ANIMAL_ATTACK_STATS,
  BARBARIAN_ATTACK_COOLDOWN_SECONDS,
  BARBARIAN_ATTACK_DAMAGE,
  BARBARIAN_ATTACK_RANGE,
  BARBARIAN_CHASE_SPEED,
  BARBARIAN_DETECTION_RADIUS,
  BARBARIAN_RESPAWN_SECONDS,
  BARBARIAN_RETURN_SPEED,
  COMBAT_ALERT_DURATION_SECONDS,
  CAMPFIRE_HEAL_INTERVAL_SECONDS,
  DAMAGE_FLASH_DURATION_SECONDS,
  HEAL_EFFECT_DURATION_SECONDS,
  getMinionAttackStats,
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
import {
  MINION_NAVIGATION_CONFIG, chooseNavigationStep, idleYieldTarget, velocityTowards,
  createMinionNavigationState, planMinionRoute, segmentIsClear,
  type NavigationAgent,
} from './minionNavigation';
import { assignCombatPositions, combatPositionRadius } from './minionCombatPositions';
import { chooseEntityCalls, type EntityCall } from './minionAwareness';
import {
  MINION_IDLE_CONFIG,
  chooseIdleDestination,
  createMinionIdleState,
  isWithinTotemRange,
  idleWaitSeconds,
  totemRangeEntry,
  type IdleArea,
} from './minionIdle';

export const WORLD_SIZE = 160;
export const UNIT_SPEED = 6;
export const TOTEM_FOLLOW_SPEED = 10;
export const TOTEM_RETURN_SPEED = 8;
export const HUNTER_COMBAT_SPEED = UNIT_SPEED;
export const HUNTER_TOTEM_LEASH_RADIUS = 10;
export const FORMATION_RADIUS = 4;
export const RECRUITMENT_RADIUS = 15;
export const TOTEM_EDGE_PADDING = 2;
export const FORMATION_TOLERANCE = 0.08;
export const GATHER_ACTION_DURATION_SECONDS = 1.5;
export const RESOURCE_SOURCE_GATHER_DURATION_SECONDS = {
  tree: 3,
  'stone-vein': { 1: 5, 2: 7 },
} as const;
export const TOTEM_NO_STOP_RADIUS = 2;
export const UNIT_COLLISION_RADIUS = 0.45;
export const UNIT_ACTOR_SEPARATION = MINION_NAVIGATION_CONFIG.minimumSeparation;
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

function gatherActionDuration(state: GameState, resource: ResourceNode): number {
  const baseDuration = resource.source === 'tree'
    ? RESOURCE_SOURCE_GATHER_DURATION_SECONDS.tree
    : resource.source === 'stone-vein'
      ? RESOURCE_SOURCE_GATHER_DURATION_SECONDS['stone-vein'][resource.tier === 2 ? 2 : 1]
      : GATHER_ACTION_DURATION_SECONDS;
  const tool = resource.type === 'wood' ? 'axe' : resource.type === 'stone' ? 'hammer' : null;
  if (!tool) return baseDuration;
  return baseDuration
    / getGatherActionDurationMultiplier(tool, state.toolLevels[tool]);
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

function idleArea(state: GameState): IdleArea {
  return {
    center: state.totem.position,
    commandRadius: state.totem.commandRadius,
    minimumCoordinate: TOTEM_EDGE_PADDING,
    maximumCoordinate: WORLD_SIZE - TOTEM_EDGE_PADDING,
  };
}

type NavigationFrame = {
  deltaSeconds: number;
  origins: Map<string, Vec2>;
  reservations: Map<string, NavigationAgent>;
  combatPositions: Map<string, Vec2>;
};

function holdsWorkingPosition(state: GameState, unit: UnitState): boolean {
  if (unit.attackLockRemainingSeconds > 0) return true;
  if (unit.task.kind === 'gather' && unit.state === 'gathering') return true;
  if (unit.task.kind === 'loot-corpse' && unit.actionProgressSeconds > 0) return true;
  if (unit.task.kind === 'combat') {
    const target = state.barbarians.find((target) => target.id === unit.task.targetEntityId && target.isAlive);
    const stats = getMinionAttackStats(unit.role, state.toolLevels.sword);
    const offset = unit.navigation?.combatOffset;
    return !!target && !!stats && !!offset
      && distanceBetween(unit.position, { x: target.position.x + offset.x, y: target.position.y + offset.y }) <= 0.1
      && distanceBetween(unit.position, target.position) <= stats.range;
  }
  if (unit.task.kind === 'hunt') {
    const target = state.animals.find((target) => target.id === unit.task.targetEntityId && target.isAlive);
    return !!target && distanceBetween(unit.position, target.position) <= ANIMAL_ATTACK_STATS.range;
  }
  return false;
}

function navigationAgent(state: GameState, unit: UnitState, frame: NavigationFrame): NavigationAgent {
  const reserved = frame.reservations.get(unit.id);
  if (reserved) return reserved;
  const index = state.units.indexOf(unit);
  const position = frame.origins.get(unit.id) ?? unit.position;
  let destination: Vec2 | null = null;
  let speed = UNIT_SPEED;
  let fixed = holdsWorkingPosition(state, unit);
  if (state.totem.isCarried || state.totem.moving) {
    destination = formationTarget(state, index);
    speed = TOTEM_FOLLOW_SPEED;
    fixed ||= unit.withdrawAfterAttack;
  } else if (unit.task.kind === 'idle') {
    destination = (unit.idleMovement?.waitRemainingSeconds ?? 0) > 0 ? null : unit.idleMovement?.destination ?? null;
    speed = MINION_IDLE_CONFIG.speed;
  } else if (unit.task.kind === 'gather') {
    const resource = resourceForTask(state, unit);
    if (resource) destination = resourceApproachPosition(position, resource);
  } else if (unit.task.kind === 'collect-drop') {
    destination = state.drops.find((drop) => drop.id === unit.task.targetResourceId)?.position ?? null;
  } else if (unit.task.kind === 'loot-corpse') {
    const corpse = state.barbarianCorpses.find((corpse) => corpse.id === unit.task.targetEntityId);
    if (corpse) destination = approachPoint(position, corpse.position, 1.25);
  } else if (unit.task.kind === 'return-to-totem' || unit.task.kind === 'flee') {
    destination = unit.task.kind === 'return-to-totem'
      ? totemRangeEntry(position, idleArea(state))
      : approachPoint(position, state.totem.position, TOTEM_NO_STOP_RADIUS + TOTEM_CLEARANCE_EPSILON);
    speed = unit.task.kind === 'return-to-totem' ? TOTEM_RETURN_SPEED : TOTEM_FOLLOW_SPEED;
  } else if (unit.task.kind === 'combat') {
    const target = state.barbarians.find((target) => target.id === unit.task.targetEntityId && target.isAlive);
    const stats = getMinionAttackStats(unit.role, state.toolLevels.sword);
    if (target && stats) {
      destination = frame.combatPositions.get(unit.id) ?? unit.position;
    }
    speed = UNIT_SPEED;
  } else if (unit.task.kind === 'hunt') {
    const target = state.animals.find((target) => target.id === unit.task.targetEntityId && target.isAlive);
    if (target) {
      destination = approachPoint(position, target.position, ANIMAL_ATTACK_STATS.range);
    }
  }
  const committedWaypoint = destination && unit.navigation && distanceBetween(unit.navigation.goal, destination) <= 0.6
    ? unit.navigation.waypoints[0] : null;
  const movingTarget = !fixed ? committedWaypoint ?? destination : null;
  return {
    id: unit.id, position, fixed, priority: fixed ? 3 : unit.task.kind === 'idle' ? 1 : 2,
    velocity: movingTarget ? velocityTowards(position, movingTarget, speed) : { x: 0, y: 0 },
    stopAfterSeconds: movingTarget ? distanceBetween(position, movingTarget) / speed : 0,
    tickVelocity: { x: 0, y: 0 },
  };
}

function navigationNeighbors(state: GameState, unit: UnitState, frame: NavigationFrame): NavigationAgent[] {
  return [
    ...state.units.filter((other) => other.id !== unit.id).map((other) => navigationAgent(state, other, frame)),
    ...state.barbarians.filter((other) => other.isAlive).map((other): NavigationAgent => ({
      id: other.id, position: other.position, velocity: { x: 0, y: 0 }, tickVelocity: { x: 0, y: 0 },
      priority: 4, fixed: true, stopAfterSeconds: 0,
    })),
  ];
}

function cancelIdleMovement(unit: UnitState): void {
  if (!unit.idleMovement) return;
  unit.idleMovement.destination = null;
  unit.idleMovement.waitRemainingSeconds = 0;
}

function idleNeighbors(state: GameState, unit: UnitState) {
  return state.units.filter((other) => other.id !== unit.id)
    .sort((a, b) => a.id.localeCompare(b.id))
    .map((other) => ({ position: other.position,
      destination: other.idleMovement?.destination ?? (other.task.kind === 'return-to-totem' ? other.task.destination : null) }));
}

function updateIdleMovement(state: GameState, unit: UnitState, deltaSeconds: number, navigation: NavigationFrame): void {
  const idle = unit.idleMovement ??= createMinionIdleState();
  if (!idle.destination && idle.waitRemainingSeconds <= 0) {
    idle.waitRemainingSeconds = idleWaitSeconds(state.seed, unit.id, idle.step);
    idle.destination = chooseIdleDestination(state.seed, unit.id, idle.step, unit.position, idleArea(state), idleNeighbors(state, unit));
    idle.step += 1;
  }
  unit.state = 'idle';
  if (idle.waitRemainingSeconds > 0) {
    idle.waitRemainingSeconds = Math.max(0, idle.waitRemainingSeconds - deltaSeconds);
    const yieldTarget = idleYieldTarget(navigationAgent(state, unit, navigation), navigationNeighbors(state, unit, navigation));
    if (yieldTarget) moveUnitTowards(state, unit, yieldTarget, MINION_IDLE_CONFIG.speed * deltaSeconds, navigation);
    return;
  }
  if (idle.destination && moveUnitTowards(state, unit, idle.destination, MINION_IDLE_CONFIG.speed * deltaSeconds, navigation)) {
    idle.destination = null;
  }
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

function moveUnitTowards(state: GameState, unit: UnitState, destination: Vec2, distance: number, frame: NavigationFrame): boolean {
  const safeDestination = projectOutsideTotemClearance(destination, state.totem.position, unit.id);
  const agent = { ...navigationAgent(state, unit, frame), position: { ...unit.position }, fixed: false };
  const memory = unit.navigation ??= createMinionNavigationState(safeDestination);
  const neighbors = navigationNeighbors(state, unit, frame);
  const isAllowed = (point: Vec2) => {
      if (point.x < TOTEM_EDGE_PADDING || point.y < TOTEM_EDGE_PADDING
        || point.x > WORLD_SIZE - TOTEM_EDGE_PADDING || point.y > WORLD_SIZE - TOTEM_EDGE_PADDING) return false;
      if (!state.totem.moving && !state.totem.isCarried && unit.task.kind === 'idle') {
        if (!isWithinTotemRange(point, idleArea(state))) return false;
        if (distanceBetween(point, state.totem.position) < Math.min(distanceBetween(unit.position, state.totem.position), TOTEM_NO_STOP_RADIUS + TOTEM_CLEARANCE_EPSILON) - 1e-8) return false;
      }
      return !(unit.role === 'hunter' && unit.task.kind === 'combat')
        || distanceBetween(point, state.totem.position) <= Math.min(state.totem.commandRadius, HUNTER_TOTEM_LEASH_RADIUS) + 1e-8;
    };
  if (distanceBetween(memory.goal, safeDestination) > 0.6) {
    memory.waypoints = [];
    memory.side = 0;
    memory.replanSeconds = 0;
  }
  memory.goal = { ...safeDestination };
  memory.replanSeconds = Math.max(0, memory.replanSeconds - frame.deltaSeconds);
  memory.sideHoldSeconds = Math.max(0, memory.sideHoldSeconds - frame.deltaSeconds);
  while (memory.waypoints.length && distanceBetween(unit.position, memory.waypoints[0]) < 0.08) memory.waypoints.shift();
  const obstacles = neighbors.filter((other) => other.fixed || memory.blockedSeconds >= 0.3);
  const next = memory.waypoints[0] ?? safeDestination;
  if (memory.replanSeconds <= 0 && (!memory.waypoints.length || !segmentIsClear(unit.position, next, obstacles, 0.96))) {
    memory.waypoints = planMinionRoute(unit.position, safeDestination, obstacles, isAllowed);
    memory.replanSeconds = 0.6;
  }
  if (memory.waypoints.length === 1) memory.waypoints[0] = { ...safeDestination };
  const waypoint = memory.waypoints[0] ?? safeDestination;
  const routeUnavailable = memory.waypoints.length === 0 && !segmentIsClear(unit.position, safeDestination, obstacles);
  const result = routeUnavailable ? { position: { ...unit.position }, velocity: { x: 0, y: 0 }, blocked: true } : chooseNavigationStep({
    agent, destination: waypoint, speed: distance / Math.max(frame.deltaSeconds, 1e-8),
    deltaSeconds: frame.deltaSeconds, neighbors, isAllowed,
    previousVelocity: memory.velocity, preferredSide: memory.side,
  });
  const forward = velocityTowards(unit.position, waypoint, 1);
  const turn = forward.x * result.velocity.y - forward.y * result.velocity.x;
  if (Math.abs(turn) > 1e-6) {
    if (!memory.side) memory.side = Math.sign(turn);
    memory.sideHoldSeconds = 0.6;
  }
  if (memory.sideHoldSeconds <= 0 && !result.blocked) memory.side = 0;
  memory.velocity = result.velocity;
  memory.blockedSeconds = result.blocked ? memory.blockedSeconds + frame.deltaSeconds : 0;
  if (memory.blockedSeconds >= 0.3 && memory.replanSeconds <= 0) {
    memory.waypoints = planMinionRoute(unit.position, safeDestination, neighbors, isAllowed);
    memory.side = 0;
    memory.replanSeconds = 0.6;
  }
  Object.assign(unit.position, result.position);
  const origin = frame.origins.get(unit.id) ?? agent.position;
  frame.reservations.set(unit.id, {
    ...agent, position: origin, velocity: result.velocity,
    stopAfterSeconds: distanceBetween(origin, waypoint) / Math.max(Math.hypot(result.velocity.x, result.velocity.y), 1e-8),
    tickVelocity: { x: (unit.position.x - origin.x) / frame.deltaSeconds, y: (unit.position.y - origin.y) / frame.deltaSeconds },
  });
  if (memory.blockedSeconds >= 1.2 && unit.task.kind === 'idle') cancelIdleMovement(unit);
  return distanceBetween(unit.position, safeDestination) <= FORMATION_TOLERANCE;
}

function separatePair(first: Vec2, second: Vec2, minDistance: number, seed: string, firstShare = 0.5): void {
  let dx = second.x - first.x;
  let dy = second.y - first.y;
  let distance = Math.hypot(dx, dy);
  if (distance >= minDistance) return;
  if (distance < 1e-8) {
    const angle = (stableHash(seed) / 0xffffffff) * Math.PI * 2;
    dx = Math.cos(angle);
    dy = Math.sin(angle);
    distance = 0;
  }
  const adjustment = minDistance - distance;
  const nx = distance > 0 ? dx / distance : dx;
  const ny = distance > 0 ? dy / distance : dy;
  first.x -= nx * adjustment * firstShare;
  first.y -= ny * adjustment * firstShare;
  second.x += nx * adjustment * (1 - firstShare);
  second.y += ny * adjustment * (1 - firstShare);
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
    if (!state.totem.isCarried && !state.totem.moving && unit.task.kind === 'idle'
      && unit.idleMovement?.destination) {
      Object.assign(unit.position, projectWithinRadius(
        unit.position, state.totem.position, state.totem.commandRadius,
      ));
      Object.assign(unit.position, clampWorldPosition(projectOutsideTotemClearance(
        unit.position, state.totem.position, unit.id,
      )));
    }
  };
  for (const unit of units) {
    constrainUnit(unit);
  }

  for (let pass = 0; pass < 8; pass += 1) {
    for (let firstIndex = 0; firstIndex < units.length; firstIndex += 1) {
      const first = units[firstIndex];
      for (let secondIndex = firstIndex + 1; secondIndex < units.length; secondIndex += 1) {
        const second = units[secondIndex];
        const firstFixed = holdsWorkingPosition(state, first);
        const secondFixed = holdsWorkingPosition(state, second);
        const firstShare = firstFixed && !secondFixed ? 0 : secondFixed && !firstFixed ? 1 : 0.5;
        separatePair(first.position, second.position, UNIT_ACTOR_SEPARATION, `${first.id}:${second.id}`, firstShare);
        constrainUnit(first);
        constrainUnit(second);
      }
      for (const barbarian of barbarians) {
        separatePair(first.position, barbarian.position, UNIT_ACTOR_SEPARATION, `${first.id}:${barbarian.id}`, 1);
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

function reserveCombatPositions(state: GameState, frame: NavigationFrame): void {
  for (const target of state.barbarians.filter((other) => other.isAlive).sort((a, b) => a.id.localeCompare(b.id))) {
    const attackers = state.units.filter((unit) => unit.task.kind === 'combat' && unit.task.targetEntityId === target.id);
    const occupied = state.units.filter((unit) => !attackers.includes(unit) && holdsWorkingPosition(state, unit)).map((unit) => unit.position);
    occupied.push(...frame.combatPositions.values());
    const positions = assignCombatPositions(target.position, attackers.map((unit) => ({
      id: unit.id, position: unit.position, range: getMinionAttackStats(unit.role, state.toolLevels.sword)!.range,
      ranged: unit.role === 'hunter',
      offset: unit.navigation?.combatTargetId === target.id ? unit.navigation.combatOffset : null,
    })), occupied, (attacker, point) => point.x >= TOTEM_EDGE_PADDING && point.y >= TOTEM_EDGE_PADDING
      && point.x <= WORLD_SIZE - TOTEM_EDGE_PADDING && point.y <= WORLD_SIZE - TOTEM_EDGE_PADDING
      && distanceBetween(point, state.totem.position) >= TOTEM_NO_STOP_RADIUS + TOTEM_CLEARANCE_EPSILON
      && (attacker.ranged === false || distanceBetween(point, state.totem.position) <= Math.min(state.totem.commandRadius, HUNTER_TOTEM_LEASH_RADIUS))
      && state.barbarians.every((other) => !other.isAlive || other.id === target.id || distanceBetween(point, other.position) >= UNIT_ACTOR_SEPARATION));
    for (const unit of attackers) {
      const position = positions.get(unit.id)!;
      frame.combatPositions.set(unit.id, position);
      const memory = unit.navigation ??= createMinionNavigationState(position);
      memory.combatTargetId = target.id;
      memory.combatOffset = { x: position.x - target.position.x, y: position.y - target.position.y };
    }
  }
}

function moveBarbarianTowards(state: GameState, barbarian: BarbarianState, destination: Vec2, distance: number, frame: NavigationFrame): boolean {
  const zero = { x: 0, y: 0 };
  const neighbors: NavigationAgent[] = state.units.map((unit) => {
    const origin = frame.origins.get(unit.id) ?? unit.position;
    const velocity = frame.reservations.get(unit.id)?.tickVelocity ?? zero;
    return { id: unit.id, position: origin, velocity, tickVelocity: velocity, stopAfterSeconds: frame.deltaSeconds, fixed: true, priority: 4 };
  });
  neighbors.push(...state.barbarians.filter((other) => other.isAlive && other.id !== barbarian.id).map((other) => ({
    id: other.id, position: other.position, velocity: zero, tickVelocity: zero, stopAfterSeconds: 0, fixed: true, priority: 4,
  })));
  const result = chooseNavigationStep({
    agent: { id: barbarian.id, position: barbarian.position, velocity: zero, tickVelocity: zero, stopAfterSeconds: 0, fixed: false, priority: 2 },
    destination, speed: distance / frame.deltaSeconds, deltaSeconds: frame.deltaSeconds, neighbors,
    isAllowed: (point) => point.x >= TOTEM_EDGE_PADDING && point.y >= TOTEM_EDGE_PADDING
      && point.x <= WORLD_SIZE - TOTEM_EDGE_PADDING && point.y <= WORLD_SIZE - TOTEM_EDGE_PADDING,
  });
  Object.assign(barbarian.position, result.position);
  return distanceBetween(barbarian.position, destination) <= FORMATION_TOLERANCE;
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
  if (unit.task.kind !== task.kind || unit.task.targetEntityId !== task.targetEntityId
    || unit.task.targetResourceId !== task.targetResourceId) unit.navigation = undefined;
  if (task.kind !== 'idle' || unit.task.kind !== 'idle') cancelIdleMovement(unit);
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
    destination: totemRangeEntry(state.units[index].position, idleArea(state)),
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
        && !canRoleGatherNode(caller.role, resource, state.toolLevels)
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
        && canRoleGatherNode(candidate.role, resource, state.toolLevels)
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
  unit.attackLockRemainingSeconds = ATTACK_LUNGE_DURATION_SECONDS;
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

function updateConflict(state: GameState, deltaSeconds: number, navigation: NavigationFrame): void {
  updateRespawnsAndFauna(state, deltaSeconds);
  const totemMoving = state.totem.isCarried || state.totem.moving;
  const entityCalls = totemMoving ? new Map<string, EntityCall>() : chooseEntityCalls(
    state.units.map((unit) => ({
      id: unit.id, position: unit.position, currentKind: unit.task.kind, currentTargetId: unit.task.targetEntityId,
      available: (unit.task.kind === 'idle' || unit.task.kind === 'return-to-totem') && totalResourceAmount(unit.cargo.amounts) === 0,
      canFight: getMinionAttackStats(unit.role, state.toolLevels.sword) !== undefined,
      canHunt: unit.role === 'hunter',
    })),
    [...state.barbarians.map(({ id, position, isAlive }) => ({ id, position, isAlive, kind: 'combat' as const })),
      ...state.animals.map(({ id, position, isAlive }) => ({ id, position, isAlive, kind: 'hunt' as const }))],
    MINION_THREAT_DETECTION_RADIUS, getResourceDetectionRadius(state.totem.commandRadius),
    (unit, entity) => entity.kind !== 'combat' || !unit.canHunt
      || distanceBetween(entity.position, state.totem.position) <= Math.min(state.totem.commandRadius, HUNTER_TOTEM_LEASH_RADIUS)
        + combatPositionRadius(getMinionAttackStats('hunter', state.toolLevels.sword)!.range, true),
  );

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

  for (const [index, unit] of state.units.entries()) {
    const canFight = getMinionAttackStats(unit.role, state.toolLevels.sword) !== undefined;
    if (totemMoving) {
      const currentTarget = state.barbarians.find((barbarian) => (
        barbarian.isAlive && barbarian.id === unit.task.targetEntityId
      ));
      const stats = getMinionAttackStats(unit.role, state.toolLevels.sword);
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
    const call = entityCalls.get(unit.id);
    const calledEnemy = call?.kind === 'combat'
      ? state.barbarians.find((enemy) => enemy.id === call.targetId && enemy.isAlive) : null;
    const threat = nearestBarbarian(unit, state.barbarians, MINION_THREAT_DETECTION_RADIUS) ?? calledEnemy;
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
      const calledAnimal = call?.kind === 'hunt'
        ? state.animals.find((animal) => animal.id === call.targetId && animal.isAlive) : null;
      const rabbit = currentAnimal
        && (distanceBetween(unit.position, currentAnimal.position)
          <= getResourceDetectionRadius(state.totem.commandRadius) + 2 || currentAnimal.id === calledAnimal?.id)
        ? currentAnimal
        : chooseRabbit(state, unit) ?? calledAnimal;
      if (rabbit) {
        setTaskState(unit, entityTask('hunt', 'animal-found', rabbit.id));
        continue;
      }
    }
    if (unit.task.kind === 'hunt') setTaskState(unit, idleTask('no-valid-resource'));
  }

  reserveCombatPositions(state, navigation);
  for (const [index, unit] of state.units.entries()) {
    if (unit.attackLockRemainingSeconds > 0) continue;

    if (unit.task.kind === 'flee') {
      moveUnitTowards(state, unit,
        approachPoint(unit.position, state.totem.position, TOTEM_NO_STOP_RADIUS + TOTEM_CLEARANCE_EPSILON),
        TOTEM_FOLLOW_SPEED * deltaSeconds, navigation);
      continue;
    }

    if (unit.task.kind === 'combat') {
      const barbarian = state.barbarians.find((candidate) => (
        candidate.isAlive && candidate.id === unit.task.targetEntityId
      ));
      const stats = getMinionAttackStats(unit.role, state.toolLevels.sword);
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
      const attackPosition = navigation.combatPositions.get(unit.id) ?? unit.position;
      const distanceToSlot = distanceBetween(unit.position, attackPosition);
      if (distanceToSlot > 0.025) {
        moveUnitTowards(
          state,
          unit,
          attackPosition,
          UNIT_SPEED * deltaSeconds,
          navigation,
        );
      }
      if (distanceBetween(unit.position, attackPosition) <= 0.15
        && distanceBetween(unit.position, barbarian.position) <= stats.range + 1e-6
        && (unit.role !== 'hunter' || distanceBetween(unit.position, barbarian.position) >= stats.range - 0.6)
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
          navigation,
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
        moveBarbarianTowards(
          state, barbarian,
          approachPoint(barbarian.position, target.position, BARBARIAN_ATTACK_RANGE),
          BARBARIAN_CHASE_SPEED * deltaSeconds,
          navigation,
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
      const reachedSpawn = moveBarbarianTowards(
        state, barbarian,
        barbarian.spawnPosition,
        BARBARIAN_RETURN_SPEED * deltaSeconds,
        navigation,
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
    const reachedPatrolTarget = moveBarbarianTowards(
      state, barbarian,
      barbarian.patrolTarget,
      BARBARIAN_PATROL_SPEED * deltaSeconds,
      navigation,
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
  navigation: NavigationFrame,
): void {
  if (unit.role === 'hunter' && unit.attackLockRemainingSeconds > 0) return;

  if (unit.task.kind === 'idle') {
    if (totalResourceAmount(unit.cargo.amounts) > 0) {
      dropCargoAtPosition(state, unit, unit.position, null);
      return;
    }

    // Conflict and totem movement have already taken precedence. Work remains
    // available every tick, even while the unit is waiting or strolling.
    const gatherTask = chooseGatherTask({
      role: unit.role,
      unitPosition: unit.position,
      totemPosition: state.totem.position,
      commandRadius: state.totem.commandRadius,
      cargo: unit.cargo,
      resources: state.resources,
      toolLevels: state.toolLevels,
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
    if (!isWithinTotemRange(unit.position, idleArea(state))) {
      setTaskState(unit, returnToTotemTask(state, index, 'no-valid-resource'));
    } else {
      updateIdleMovement(state, unit, deltaSeconds, navigation);
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
    if (!moveUnitTowards(state, unit, lootInteractionPosition, UNIT_SPEED * deltaSeconds, navigation)) {
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
      navigation,
    )) {
      unit.state = 'seeking-task';
      return;
    }

    unit.state = 'gathering';
    unit.actionProgressSeconds += deltaSeconds;
    if (unit.actionProgressSeconds < gatherActionDuration(state, resource)) return;

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
      (resource.yieldAmount ?? gathered.gathered)
        + ((resource.type === 'wood' || resource.type === 'stone')
          && rollsToolBonusResource({
            seed: state.seed,
            tick: state.tick,
            unitId: unit.id,
            nodeId: resource.id,
            tool: resource.type === 'wood' ? 'axe' : 'hammer',
            level: state.toolLevels[resource.type === 'wood' ? 'axe' : 'hammer'],
          }) ? 1 : 0),
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

    if (!moveUnitTowards(state, unit, drop.position, UNIT_SPEED * deltaSeconds, navigation)) {
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
    // Old saves may still contain a central regroup destination. Stop as soon
    // as command range is reached, regardless of that obsolete destination.
    if (!isWithinTotemRange(unit.position, idleArea(state))) {
      const destination = totemRangeEntry(unit.position, idleArea(state));
      unit.task.destination = destination;
      moveUnitTowards(state, unit, destination, TOTEM_RETURN_SPEED * deltaSeconds, navigation);
      if (!isWithinTotemRange(unit.position, idleArea(state))) {
        unit.state = 'returning-to-totem';
        return;
      }
    }

    setTaskState(unit, idleTask('action-complete'));
  }
}

function updateFormationUnit(
  state: GameState,
  unit: UnitState,
  index: number,
  deltaSeconds: number,
  navigation: NavigationFrame,
): boolean {
  const target = formationTarget(state, index);
  cancelIdleMovement(unit);
  const reached = moveUnitTowards(state, unit, target, TOTEM_FOLLOW_SPEED * deltaSeconds, navigation);
  const distanceToTarget = Math.hypot(
    target.x - unit.position.x,
    target.y - unit.position.y,
  );

  const inFormation = reached || distanceToTarget <= FORMATION_TOLERANCE;
  unit.state = !state.totem.isCarried && inFormation ? 'formation' : 'follow-totem';
  unit.task = idleTask('totem-moved');

  return inFormation;
}

function applyAction(state: GameState, action: InputAction): void {
  if (action.type === 'toggle-pause') {
    if (state.phase === 'playing') state.phase = 'paused';
    else if (state.phase === 'paused') state.phase = 'playing';
    return;
  }

  if (action.type === 'debug-add-all-resources') {
    for (const resource of RESOURCE_TYPES) state.inventory.amounts[resource] += 100;
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
      const cost = getGathererRecruitmentCost(state.units.length);
      if (
        state.units.length >= MAX_PLAYABLE_MINIONS
        || !canAffordCost(state.inventory.amounts, cost)
      ) return;

      spendCost(state.inventory.amounts, cost);
      state.purchaseCounts.gatherer += 1;
      const unit = createUnitState(
        `unit-gatherer-${String(state.purchaseCounts.gatherer + 1).padStart(2, '0')}`,
        'gatherer',
        projectRecruitmentPosition(action.position, state.totem.position),
      );
      state.units.push(unit);
      setTaskState(
        unit,
        isWithinTotemRange(unit.position, idleArea(state))
          ? idleTask('action-complete')
          : returnToTotemTask(state, state.units.length - 1, 'action-complete'),
      );
      return;
    }
    case 'upgrade-tool': {
      const currentLevel = state.toolLevels[action.tool];
      if (currentLevel >= MAX_TOOL_LEVEL) return;
      const cost = getToolUpgradeCost(action.tool, currentLevel + 1);
      if (!cost || !spendCost(state.inventory.amounts, cost)) return;
      state.toolLevels[action.tool] += 1;
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
      const cost = getShieldCost(shieldsInUse);
      if (!spendCost(state.inventory.amounts, cost)) return;

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
      if (action.item === 'mage'
        && !state.progression.unlockedTechnologies.includes('mage')) return;
      if (action.item === 'axe' && !canConvertLastGathererToNonCombatSpecialist(state.units)) return;
      if (action.item === 'hammer' && !canConvertLastGathererToNonCombatSpecialist(state.units)) return;

      const purchaseKey = action.item === 'axe'
        ? 'lumberjack'
        : action.item === 'bow'
          ? 'hunter'
          : action.item === 'hammer'
            ? 'artisan'
            : action.item === 'mage'
              ? 'mage'
              : 'guardian';
      const targetRole = getSpecializationRole(action.item);
      const activeTargetMinions = countUnitsWithRole(state.units, targetRole);
      if (activeTargetMinions >= getSpecializationLimit(action.item)) return;
      const cost = getSpecializationCost(action.item, activeTargetMinions);
      if (!spendCost(state.inventory.amounts, cost)) return;

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
  const navigation: NavigationFrame = {
    deltaSeconds,
    origins: new Map(state.units.map((unit) => [unit.id, { ...unit.position }])),
    reservations: new Map(),
    combatPositions: new Map(),
  };

  // Resolve threat/animal calls before resource calls consume free responders.
  if (options.enableSurvival) updateConflict(state, deltaSeconds, navigation);
  if (options.enableSurvival && !state.totem.isCarried && !state.totem.moving) {
    // Calls are a lightweight coordination pass: a minion can ask for help
    // without dropping its own active task, and every target is still reserved
    // for at most one responder.
    for (const caller of state.units) dispatchResourceCall(state, caller);
  }

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
      if (!updateFormationUnit(state, unit, index, deltaSeconds, navigation)) {
        allUnitsInFormation = false;
      }
    } else {
      updateSurvivalUnit(state, unit, index, deltaSeconds, navigation);
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

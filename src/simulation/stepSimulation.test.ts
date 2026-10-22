import { describe, expect, it } from 'vitest';
import { createInitialState, createUnitState } from './createInitialState';
import {
  FORMATION_RADIUS,
  HUNTER_COMBAT_SPEED,
  HUNTER_TOTEM_LEASH_RADIUS,
  RECRUITMENT_RADIUS,
  TOTEM_CLEARANCE_EPSILON,
  TOTEM_NO_STOP_RADIUS,
  TOTEM_CHASE_SPEED,
  UNIT_SPEED,
  applyInputActions,
  projectOutsideTotemClearance,
  stepSimulation,
} from './stepSimulation';
import { BARBARIAN_PATROL_RADIUS, BARBARIAN_PATROL_SPEED } from './survivalCatalog';
import {
  CAMPFIRE_HEALING_RADIUS,
  CAMPFIRE_LIFETIME_SECONDS,
  MAX_ACTIVE_CAMPFIRES,
} from './survivalTypes';
import { CAMPFIRE_HEAL_INTERVAL_SECONDS } from './survivalCombat';

const TICK = 1 / 20;

function clearanceDistance(position: { x: number; y: number }, totem: { x: number; y: number }): number {
  return Math.hypot(position.x - totem.x, position.y - totem.y);
}

describe('stepSimulation', () => {
  it('starts a deterministic two-minion formation with empty resources', () => {
    const state = createInitialState();
    const initialPositions = state.units.map((unit) => ({ ...unit.position }));

    stepSimulation(state, TICK);

    expect(state.units.map((unit) => unit.position)).toEqual(initialPositions);
    expect(state.units[0].position).toEqual({ x: 84, y: 80 });
    expect(state.units[1].position).toEqual({ x: 76, y: 80 });
    expect(state.units[0].role).toBe('gatherer');
    expect(['lumberjack', 'hunter']).toContain(state.units[1].role);
    expect(state.units.every((unit) => unit.health === 4 && unit.maxHealth === 4)).toBe(true);
    expect(state.inventory.amounts).toEqual({ food: 0, wood: 0, stone: 0, spark: 0, gold: 0 });
    expect(state.barbarians).toHaveLength(5);
    expect(state.animals).toHaveLength(6);
    const repeatedSeedA = createInitialState('hito-4-seed-check');
    const repeatedSeedB = createInitialState('hito-4-seed-check');
    expect(repeatedSeedA.barbarians).toEqual(repeatedSeedB.barbarians);
    expect(repeatedSeedA.animals).toEqual(repeatedSeedB.animals);
    expect(repeatedSeedA.barbarians).not.toEqual(createInitialState('other-seed').barbarians);
    expect(repeatedSeedA.barbarians.every((barbarian) => (
      barbarian.position.x >= 0 && barbarian.position.x <= 160
      && barbarian.position.y >= 0 && barbarian.position.y <= 160
    ))).toBe(true);
  });

  it('engages detected barbarians, applies hunter damage, and signals once per encounter', () => {
    const state = createInitialState('hito-4-combat');
    const hunter = createUnitState('test-hunter', 'hunter', { x: 80, y: 80 });
    const barbarian = state.barbarians[0];
    state.units = [hunter];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    barbarian.position = { x: 85, y: 80 };
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };

    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(hunter.task.kind).toBe('combat');
    expect(hunter.state).toBe('combat');
    expect(barbarian.health).toBe(4);
    expect(hunter.attackLockRemainingSeconds).toBeCloseTo(0.22);
    expect(state.alerts.filter((alert) => alert.playSound)).toHaveLength(1);
    expect(state.alerts.some((alert) => alert.detectorKind === 'minion')).toBe(true);
    expect(state.alerts.some((alert) => alert.detectorKind === 'barbarian')).toBe(true);

    for (let tick = 0; tick < 20; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(state.nextAlertId).toBe(3);
    expect(state.phase).toBe('playing');
  });

  it('slows the hunter in combat, locks movement during the strike, and keeps it in the totem leash', () => {
    const state = createInitialState('hunter-leash-and-strike');
    const hunter = createUnitState('leashed-hunter', 'hunter', { x: 84, y: 80 });
    const barbarian = state.barbarians[0];
    state.units = [hunter];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    barbarian.position = { x: 96, y: 80 };
    barbarian.spawnPosition = { ...barbarian.position };
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };

    const beforeApproach = { ...hunter.position };
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(hunter.task.kind).toBe('combat');
    expect(Math.hypot(
      hunter.position.x - beforeApproach.x,
      hunter.position.y - beforeApproach.y,
    )).toBeLessThanOrEqual(HUNTER_COMBAT_SPEED * TICK + 1e-6);

    let verifiedStrikeLock = false;
    for (let tick = 0; tick < 300; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (hunter.task.kind === 'combat') {
        expect(Math.hypot(
          hunter.position.x - state.totem.position.x,
          hunter.position.y - state.totem.position.y,
        )).toBeLessThanOrEqual(HUNTER_TOTEM_LEASH_RADIUS + 1e-6);
      }
      if (!verifiedStrikeLock && hunter.attackLockRemainingSeconds > 0) {
        const lockedPosition = { ...hunter.position };
        for (let lockTick = 0; lockTick < 4; lockTick += 1) {
          stepSimulation(state, TICK, [], { enableSurvival: true });
          expect(hunter.position).toEqual(lockedPosition);
        }
        expect(hunter.attackLockRemainingSeconds).toBeCloseTo(0.02);
        verifiedStrikeLock = true;
      }
    }
    expect(verifiedStrikeLock).toBe(true);
    expect(barbarian.health).toBeLessThan(barbarian.maxHealth);
    expect(hunter.health).toBeLessThan(hunter.maxHealth);
  });

  it('finishes one pending in-range attack after the totem moves, then follows it', () => {
    const state = createInitialState('hito-4-totem-retreat');
    const guardian = createUnitState('test-guardian', 'guardian', { x: 40, y: 40 });
    const barbarian = state.barbarians[0];
    state.units = [guardian];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    state.totem.position = { x: 80, y: 80 };
    state.totem.moving = true;
    barbarian.position = { x: 40.9, y: 40 };
    barbarian.health = 5;
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };
    guardian.task = {
      kind: 'combat',
      targetResourceId: null,
      targetEntityId: barbarian.id,
      destination: null,
      cause: 'threat-nearby',
    };
    guardian.attackCooldownRemainingSeconds = 0.75;

    for (let tick = 0; tick < 14; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(guardian.task.kind).toBe('combat');
    expect(barbarian.health).toBe(5);
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(barbarian.health).toBe(3);
    expect(guardian.task.kind).not.toBe('combat');
    expect(guardian.position.x).toBeGreaterThan(40);
  });

  it('keeps a minion attack cooldown when its target dies and selects another target', () => {
    const state = createInitialState('global-attack-cooldown');
    const hunter = createUnitState('global-cooldown-hunter', 'hunter', { x: 40, y: 40 });
    const [first, second] = state.barbarians;
    state.units = [hunter];
    state.totem.position = { x: 40, y: 50 };
    state.barbarians = [first, second];
    state.animals = [];
    state.resources = [];
    first.position = { x: 44.5, y: 40 };
    first.health = 1;
    second.position = { x: 44.8, y: 40 };
    first.patrolCenter = { ...first.position };
    second.patrolCenter = { ...second.position };
    first.patrolTarget = { ...first.position };
    second.patrolTarget = { ...second.position };

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(first.isAlive).toBe(false);
    expect(hunter.attackCooldownRemainingSeconds).toBeCloseTo(1.3);

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(hunter.task.targetEntityId).toBe(second.id);
    expect(second.health).toBe(5);
    for (let tick = 0; tick < 24; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(second.health).toBe(5);
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(second.health).toBe(4);
  });

  it('waits at a deterministic patrol point and moves at the slower patrol speed', () => {
    const firstState = createInitialState('slow-patrol');
    const secondState = createInitialState('slow-patrol');
    const first = firstState.barbarians[0];
    const second = secondState.barbarians[0];
    expect(first.patrolRadius).toBe(BARBARIAN_PATROL_RADIUS);
    expect(first.patrolRadius).toBe(3.5);
    expect(first.patrolWaitRemainingSeconds).toBeGreaterThanOrEqual(2);
    expect(first.patrolWaitRemainingSeconds).toBeLessThanOrEqual(4);
    expect(first.patrolWaitRemainingSeconds).toBe(second.patrolWaitRemainingSeconds);

    firstState.units = [createUnitState('patrol-observer', 'gatherer', { x: 80, y: 80 })];
    secondState.units = [createUnitState('patrol-observer', 'gatherer', { x: 80, y: 80 })];
    stepSimulation(firstState, TICK, [], { enableSurvival: true });
    stepSimulation(secondState, TICK, [], { enableSurvival: true });
    expect(first.position).toEqual(first.spawnPosition);
    expect(first.position).toEqual(second.position);

    const patrolState = createInitialState('slow-patrol-step');
    const barbarian = patrolState.barbarians[0];
    patrolState.units = [createUnitState('far-minion', 'gatherer', { x: 80, y: 80 })];
    patrolState.barbarians = [barbarian];
    barbarian.position = { x: 40, y: 40 };
    barbarian.spawnPosition = { ...barbarian.position };
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };
    barbarian.patrolWaitRemainingSeconds = 0;
    const before = { ...barbarian.position };
    stepSimulation(patrolState, TICK, [], { enableSurvival: true });
    expect(Math.hypot(
      barbarian.position.x - before.x,
      barbarian.position.y - before.y,
    )).toBeLessThanOrEqual(BARBARIAN_PATROL_SPEED * TICK + 1e-6);
    expect(Math.hypot(
      barbarian.position.x - barbarian.patrolCenter.x,
      barbarian.position.y - barbarian.patrolCenter.y,
    )).toBeLessThanOrEqual(BARBARIAN_PATROL_RADIUS + 1e-6);
  });

  it('returns a disengaged barbarian to spawn at chase speed before slow patrol resumes', () => {
    const state = createInitialState('barbarian-return-home');
    const unit = createUnitState('far-away-minion', 'gatherer', { x: 10, y: 10 });
    const barbarian = state.barbarians[0];
    const spawn = { x: 40, y: 40 };
    state.units = [unit];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    barbarian.spawnPosition = { ...spawn };
    barbarian.patrolCenter = { ...spawn };
    barbarian.patrolTarget = { ...spawn };
    barbarian.position = { x: 50, y: 40 };
    barbarian.returningToSpawn = false;
    barbarian.targetUnitId = unit.id;

    const beforeReturn = { ...barbarian.position };
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(Math.hypot(
      barbarian.position.x - beforeReturn.x,
      barbarian.position.y - beforeReturn.y,
    )).toBeCloseTo(8 * TICK);
    expect(barbarian.returningToSpawn).toBe(true);

    for (let tick = 0; tick < 30; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(barbarian.position).toEqual(spawn);
    expect(barbarian.returningToSpawn).toBe(false);
    expect(barbarian.patrolWaitRemainingSeconds).toBeGreaterThanOrEqual(2);
    expect(barbarian.patrolWaitRemainingSeconds).toBeLessThanOrEqual(4);

    barbarian.patrolWaitRemainingSeconds = 0;
    barbarian.patrolTarget = { x: spawn.x + 2, y: spawn.y };
    const beforePatrol = { ...barbarian.position };
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(Math.hypot(
      barbarian.position.x - beforePatrol.x,
      barbarian.position.y - beforePatrol.y,
    )).toBeLessThanOrEqual(BARBARIAN_PATROL_SPEED * TICK + 1e-6);
    expect(Math.hypot(
      barbarian.position.x - beforePatrol.x,
      barbarian.position.y - beforePatrol.y,
    )).toBeGreaterThan(0);
  });

  it('keeps units outside the totem footprint and combatants spaced around their target', () => {
    const state = createInitialState('combat-spacing');
    const guardian = createUnitState('slot-guardian', 'guardian', { x: 60, y: 60 });
    const hunter = createUnitState('slot-hunter', 'hunter', { x: 61, y: 60 });
    const barbarian = state.barbarians[0];
    state.units = [guardian, hunter];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    state.totem.position = { x: 50, y: 50 };
    barbarian.position = { x: 60, y: 61 };
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };

    for (let tick = 0; tick < 15; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      for (const unit of state.units) {
        expect(clearanceDistance(unit.position, state.totem.position)).toBeGreaterThanOrEqual(
          TOTEM_NO_STOP_RADIUS - 1e-6,
        );
      }
      expect(Math.hypot(
        guardian.position.x - hunter.position.x,
        guardian.position.y - hunter.position.y,
      )).toBeGreaterThanOrEqual(0.94 - 1e-4);
      expect(Math.hypot(
        guardian.position.x - barbarian.position.x,
        guardian.position.y - barbarian.position.y,
      )).toBeGreaterThanOrEqual(0.94 - 1e-4);
      expect(projectOutsideTotemClearance(
        guardian.position,
        state.totem.position,
        guardian.id,
      )).toEqual(guardian.position);
    }
    expect(guardian.task.kind).toBe('combat');
    expect(hunter.task.kind).toBe('combat');

    const edgePosition = projectOutsideTotemClearance(
      { x: 50, y: 50 },
      { x: 1, y: 1 },
      'edge-minion',
    );
    expect(clearanceDistance(edgePosition, { x: 1, y: 1 })).toBeGreaterThanOrEqual(
      TOTEM_NO_STOP_RADIUS + TOTEM_CLEARANCE_EPSILON - 1e-6,
    );
  });

  it('lets unarmed minions flee toward the totem and lets a gatherer loot all corpse resources', () => {
    const state = createInitialState('hito-4-loot');
    const gatherer = createUnitState('test-gatherer', 'gatherer', { x: 90, y: 80 });
    const barbarian = state.barbarians[0];
    state.units = [gatherer];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    state.totem.position = { x: 80, y: 80 };
    barbarian.position = { x: 100, y: 80 };
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(gatherer.task.kind).toBe('flee');
    expect(gatherer.state).toBe('fleeing');
    expect(gatherer.position.x).toBeLessThan(90);
    expect(clearanceDistance(gatherer.position, state.totem.position)).toBeGreaterThanOrEqual(
      TOTEM_NO_STOP_RADIUS - 1e-6,
    );

    state.barbarians = [];
    gatherer.position = { x: 80, y: 80 };
    gatherer.task = {
      kind: 'idle',
      targetResourceId: null,
      destination: null,
      cause: 'no-valid-resource',
    };
    state.barbarianCorpses = [{
      id: 'lootable-corpse',
      barbarianId: 'barbarian-loot-test',
      position: { x: 80, y: 80 },
      loot: { food: 1, wood: 1, stone: 0, spark: 0, gold: 1 },
    }];
    state.totem.position = { x: 70, y: 80 };

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(gatherer.task.kind).toBe('loot-corpse');
    for (let tick = 0; tick < 30; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }

    expect(state.barbarianCorpses).toHaveLength(0);
    expect(state.drops.map((drop) => drop.type).sort()).toEqual(['food', 'gold', 'wood']);
    expect(state.drops.every((drop) => drop.amount === 1)).toBe(true);

    for (let tick = 0; tick < 100; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(state.drops).toHaveLength(0);
    expect(state.inventory.amounts).toMatchObject({ food: 1, gold: 1, wood: 1 });
    expect(gatherer.cargo.capacity).toBe(4);
  });

  it('reserves a barbarian corpse for one free minion and releases it when looting is interrupted', () => {
    const state = createInitialState('corpse-exclusive-reservation');
    const first = createUnitState('corpse-minion-a', 'gatherer', { x: 80, y: 80 });
    const second = createUnitState('corpse-minion-b', 'lumberjack', { x: 78, y: 80 });
    state.units = [first, second];
    state.barbarians = [];
    state.animals = [];
    state.resources = [];
    state.drops = [];
    state.barbarianCorpses = [{
      id: 'exclusive-corpse',
      barbarianId: 'defeated-barbarian',
      position: { x: 80, y: 80 },
      loot: { food: 1, wood: 1, stone: 0, spark: 0, gold: 2 },
    }];

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(state.units.filter((unit) => unit.task.kind === 'loot-corpse')).toHaveLength(1);
    expect(first.task.kind).toBe('loot-corpse');
    expect(second.task.kind).not.toBe('loot-corpse');

    for (let tick = 0; tick < 10; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(first.actionProgressSeconds).toBeGreaterThan(0);

    state.totem.moving = true;
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(state.barbarianCorpses).toHaveLength(1);
    expect(state.drops).toHaveLength(0);
    expect(state.units.every((unit) => unit.task.kind !== 'loot-corpse')).toBe(true);

    state.totem.moving = false;
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(state.units.filter((unit) => unit.task.kind === 'loot-corpse')).toHaveLength(1);
  });

  it('hunts rabbits for physical food drops and respawns them after 30 seconds', () => {
    const state = createInitialState('hito-4-rabbits');
    const hunter = createUnitState('rabbit-hunter', 'hunter', { x: 80, y: 80 });
    const rabbit = state.animals[0];
    state.units = [hunter];
    state.barbarians = [];
    state.animals = [rabbit];
    state.resources = [];
    state.totem.position = { x: 50, y: 50 };
    rabbit.position = { x: 80, y: 80 };
    rabbit.spawnPosition = { ...rabbit.position };
    rabbit.homeCenter = { ...rabbit.position };
    rabbit.patrolTarget = { ...rabbit.position };

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(rabbit.isAlive).toBe(true);
    expect(rabbit.health).toBe(1);
    expect(rabbit.respawnRemainingSeconds).toBe(0);
    expect(state.drops).toHaveLength(0);
    for (let tick = 0; tick < 25; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(rabbit.isAlive).toBe(true);
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(rabbit.isAlive).toBe(false);
    expect(rabbit.health).toBe(0);
    expect(rabbit.respawnRemainingSeconds).toBe(30);
    expect(state.drops.length).toBeGreaterThanOrEqual(1);
    expect(state.drops.length).toBeLessThanOrEqual(2);
    expect(state.drops.every((drop) => drop.type === 'food' && drop.amount === 1)).toBe(true);

    hunter.position = { x: 40, y: 40 };
    hunter.role = 'gatherer';
    for (let tick = 0; tick < 599; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(rabbit.isAlive).toBe(false);
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(rabbit.isAlive).toBe(true);
    expect(rabbit.health).toBe(2);
  });

  it('transforms a gatherer into a guardian for two gold and respawns defeated barbarians after 60 seconds', () => {
    const state = createInitialState('hito-4-guardian');
    const gatherer = state.units[0];
    state.inventory.amounts.gold = 2;
    stepSimulation(state, TICK, [{ type: 'transform-unit', item: 'sword', unitId: gatherer.id }]);
    expect(gatherer.role).toBe('guardian');
    expect(state.inventory.amounts.gold).toBe(0);

    const guardian = createUnitState('respawn-guardian', 'guardian', { x: 80, y: 80 });
    const barbarian = state.barbarians[0];
    state.units = [guardian];
    state.barbarians = [barbarian];
    state.animals = [];
    state.resources = [];
    barbarian.position = { x: 81, y: 80 };
    barbarian.health = 1;
    barbarian.patrolCenter = { ...barbarian.position };
    barbarian.patrolTarget = { ...barbarian.position };
    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(barbarian.isAlive).toBe(false);
    expect(barbarian.respawnRemainingSeconds).toBe(60);
    expect(state.barbarianCorpses).toHaveLength(1);
    expect(state.phase).toBe('playing');
    const loot = state.barbarianCorpses[0].loot;
    expect(loot.gold).toBeGreaterThanOrEqual(1);
    expect(loot.gold).toBeLessThanOrEqual(2);
    expect(loot.food).toBeGreaterThanOrEqual(0);
    expect(loot.food).toBeLessThanOrEqual(2);
    expect(loot.wood).toBeGreaterThanOrEqual(0);
    expect(loot.wood).toBeLessThanOrEqual(1);

    guardian.position = { x: 40, y: 40 };
    guardian.role = 'gatherer';
    for (let tick = 0; tick < 1199; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }
    expect(barbarian.isAlive).toBe(false);
    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(barbarian.isAlive).toBe(true);
    expect(barbarian.health).toBe(5);
  });

  it('applies damage to minions, flashes feedback, and rejects animal attacks', () => {
    const state = createInitialState();
    const unit = state.units[0];

    stepSimulation(state, TICK, [{
      type: 'damage-unit',
      unitId: unit.id,
      amount: 1,
      sourceKind: 'barbarian',
    }]);

    expect(unit.health).toBe(3);
    expect(state.effects).toHaveLength(1);
    expect(state.effects[0].kind).toBe('damage-flash');

    stepSimulation(state, TICK, [{
      type: 'damage-unit',
      unitId: unit.id,
      amount: 1,
      sourceKind: 'animal',
    }]);
    expect(unit.health).toBe(3);

    for (let tick = 0; tick < 6; tick += 1) stepSimulation(state, TICK);
    expect(state.effects).toHaveLength(0);
  });

  it('damages one minion by one point and grants debug resources in batches of ten', () => {
    const state = createInitialState();

    stepSimulation(state, TICK, [
      { type: 'debug-damage-one-minion' },
      { type: 'debug-add-resource', resource: 'food', amount: 10 },
      { type: 'debug-add-resource', resource: 'wood', amount: 10 },
      { type: 'debug-add-resource', resource: 'stone', amount: 10 },
      { type: 'debug-add-resource', resource: 'spark', amount: 10 },
    ]);

    expect(state.units.filter((unit) => unit.health === 3)).toHaveLength(1);
    expect(state.units.filter((unit) => unit.health === 4)).toHaveLength(1);
    expect(state.inventory.amounts).toEqual({ food: 10, wood: 10, stone: 10, spark: 10, gold: 0 });
  });

  it('keeps a corpse on the map and triggers defeat when the last minion dies', () => {
    const state = createInitialState();
    const lastMinion = state.units[0];
    lastMinion.health = 1;
    lastMinion.position = { x: 91, y: 73 };
    state.units = [lastMinion];

    stepSimulation(state, TICK, [{
      type: 'damage-unit',
      unitId: lastMinion.id,
      amount: 1,
      sourceKind: 'barbarian',
    }]);

    expect(state.units).toHaveLength(0);
    expect(state.corpses).toEqual([{
      id: 'corpse-001',
      formerUnitId: lastMinion.id,
      position: { x: 91, y: 73 },
    }]);
    expect(state.phase).toBe('defeat');
    const tickAtDefeat = state.tick;

    stepSimulation(state, TICK);
    expect(state.phase).toBe('defeat');
    expect(state.tick).toBe(tickAtDefeat + 1);
  });

  it('heals a damaged minion inside a campfire range and spends one food per point', () => {
    expect(CAMPFIRE_HEALING_RADIUS).toBe(15);
    expect(CAMPFIRE_HEAL_INTERVAL_SECONDS).toBe(8);
    const state = createInitialState();
    const unit = state.units[0];
    unit.health = 2;
    unit.position = { x: 84, y: 80 };
    state.inventory.amounts.food = 2;
    state.campfires = [{
      id: 'campfire-test',
      position: { x: 84, y: 80 },
      healingRadius: CAMPFIRE_HEALING_RADIUS,
      remainingLifetimeSeconds: CAMPFIRE_LIFETIME_SECONDS,
    }];

    for (let tick = 0; tick < 159; tick += 1) stepSimulation(state, TICK);
    expect(unit.health).toBe(2);
    stepSimulation(state, TICK);
    expect(unit.health).toBe(3);
    expect(state.inventory.amounts.food).toBe(1);
    expect(state.effects.some((effect) => effect.kind === 'heal-crosses')).toBe(true);

    for (let tick = 0; tick < 160; tick += 1) stepSimulation(state, TICK);
    expect(unit.health).toBe(4);
    expect(state.inventory.amounts.food).toBe(0);

    const blockedState = createInitialState();
    const blockedUnit = blockedState.units[0];
    blockedUnit.health = 2;
    blockedUnit.position = { x: 84, y: 80 };
    blockedState.campfires = [{
      id: 'campfire-test',
      position: { x: 84, y: 80 },
      healingRadius: CAMPFIRE_HEALING_RADIUS,
      remainingLifetimeSeconds: CAMPFIRE_LIFETIME_SECONDS,
    }];

    for (let tick = 0; tick < 160; tick += 1) stepSimulation(blockedState, TICK);
    expect(blockedUnit.health).toBe(2);

    blockedState.inventory.amounts.food = 1;
    blockedUnit.position = { x: 100, y: 80 };
    for (let tick = 0; tick < 160; tick += 1) stepSimulation(blockedState, TICK);
    expect(blockedUnit.health).toBe(2);
    expect(blockedState.inventory.amounts.food).toBe(1);
  });

  it('prices gatherers from total population, unaffected by specialization and lowered by deaths', () => {
    const state = createInitialState();
    state.inventory.amounts.food = 50;

    stepSimulation(state, TICK, [{ type: 'recruit-gatherer', position: { x: 84, y: 80 } }]);
    expect(state.inventory.amounts.food).toBe(48);
    const gatherer = state.units.find((unit) => unit.role === 'gatherer');
    if (!gatherer) throw new Error('Expected a gatherer to specialize');
    stepSimulation(state, TICK, [{ type: 'transform-unit', item: 'axe', unitId: gatherer.id }]);
    expect(state.units).toHaveLength(3);

    stepSimulation(state, TICK, [{ type: 'recruit-gatherer', position: { x: 84, y: 80 } }]);
    expect(state.inventory.amounts.food).toBe(45);
    stepSimulation(state, TICK, [{ type: 'recruit-gatherer', position: { x: 84, y: 80 } }]);
    expect(state.inventory.amounts.food).toBe(42);
    expect(state.units).toHaveLength(5);

    stepSimulation(state, TICK, [
      { type: 'damage-unit', unitId: 'unit-gatherer-02', amount: 4, sourceKind: 'barbarian' },
      { type: 'damage-unit', unitId: 'unit-gatherer-03', amount: 4, sourceKind: 'barbarian' },
    ]);
    expect(state.units).toHaveLength(3);

    stepSimulation(state, TICK, [{ type: 'recruit-gatherer', position: { x: 84, y: 80 } }]);
    expect(state.purchaseCounts.gatherer).toBe(4);
    expect(state.units).toHaveLength(4);
    expect(state.inventory.amounts.food).toBe(39);

    const replacementState = createInitialState();
    const startingSpecialist = replacementState.units.find((unit) => unit.role !== 'gatherer');
    if (!startingSpecialist) throw new Error('Expected the starting specialist');
    startingSpecialist.health = 1;
    replacementState.inventory.amounts.food = 10;

    stepSimulation(replacementState, TICK, [
      { type: 'damage-unit', unitId: startingSpecialist.id, amount: 1, sourceKind: 'barbarian' },
      { type: 'recruit-gatherer', position: { x: 84, y: 80 } },
    ]);
    expect(replacementState.inventory.amounts.food).toBe(8);

    stepSimulation(replacementState, TICK, [{ type: 'recruit-gatherer', position: { x: 84, y: 80 } }]);
    expect(replacementState.inventory.amounts.food).toBe(6);

    stepSimulation(replacementState, TICK, [{ type: 'recruit-gatherer', position: { x: 84, y: 80 } }]);
    expect(replacementState.inventory.amounts.food).toBe(3);
  });

  it('keeps recruited gatherers inside the recruitment radius around the totem', () => {
    const state = createInitialState();
    state.inventory.amounts.food = 10;
    const totemPosition = { ...state.totem.position };

    applyInputActions(state, [{
      type: 'recruit-gatherer',
      position: { x: totemPosition.x + 3, y: totemPosition.y + 4 },
    }]);
    const nearbyGatherer = state.units.at(-1);
    if (!nearbyGatherer) throw new Error('Expected the recruited gatherer');
    expect(nearbyGatherer.position).toEqual({
      x: totemPosition.x + 3,
      y: totemPosition.y + 4,
    });

    applyInputActions(state, [{
      type: 'recruit-gatherer',
      position: { x: totemPosition.x + 100, y: totemPosition.y },
    }]);
    const clampedGatherer = state.units.at(-1);
    if (!clampedGatherer) throw new Error('Expected the clamped gatherer');
    expect(Math.hypot(
      clampedGatherer.position.x - totemPosition.x,
      clampedGatherer.position.y - totemPosition.y,
    )).toBeCloseTo(RECRUITMENT_RADIUS);
    expect(state.inventory.amounts.food).toBe(5);
  });

  it('keeps the global cap at eight after specialization, including seven gatherers and one specialist', () => {
    const state = createInitialState();
    state.units = [
      ...Array.from({ length: 7 }, (_, index) => createUnitState(`gatherer-${index}`, 'gatherer', { x: 80, y: 80 })),
      createUnitState('hunter-01', 'hunter', { x: 80, y: 80 }),
    ];
    state.inventory.amounts.food = 100;
    state.inventory.amounts.wood = 100;
    const candidate = state.units.find((unit) => unit.role === 'gatherer');
    if (!candidate) throw new Error('Expected a gatherer to specialize');

    stepSimulation(state, TICK, [{ type: 'transform-unit', item: 'axe', unitId: candidate.id }]);
    expect(state.units).toHaveLength(8);
    expect(state.units.filter((unit) => unit.role === 'gatherer')).toHaveLength(6);
    expect(state.units.filter((unit) => unit.role === 'lumberjack')).toHaveLength(1);

    const foodAfterTransform = state.inventory.amounts.food;
    stepSimulation(state, TICK, [{ type: 'recruit-gatherer', position: { x: 80, y: 80 } }]);
    expect(state.units).toHaveLength(8);
    expect(state.inventory.amounts.food).toBe(foodAfterTransform);
    const lostUnit = state.units.find((unit) => unit.role === 'lumberjack');
    if (!lostUnit) throw new Error('Expected the newly specialized minion');
    lostUnit.health = 1;
    stepSimulation(state, TICK, [
      { type: 'damage-unit', unitId: lostUnit.id, amount: 1, sourceKind: 'barbarian' },
      { type: 'recruit-gatherer', position: { x: 80, y: 80 } },
    ]);
    expect(state.units).toHaveLength(8);
    expect(state.units.filter((unit) => unit.role === 'gatherer')).toHaveLength(7);
    expect(state.units.some((unit) => unit.role === 'lumberjack')).toBe(false);
  });

  it('prices each specialist from its own active count, independent of gatherers and total population', () => {
    for (const item of ['axe', 'bow'] as const) {
      const state = createInitialState();
      const targetRole = item === 'axe' ? 'lumberjack' : 'hunter';
      const candidates = Array.from({ length: 7 }, (_, index) => (
        createUnitState(`specialist-candidate-${index}`, 'gatherer', { x: 80, y: 80 })
      ));
      state.units = candidates;
      state.inventory.amounts.food = 100;
      state.inventory.amounts.wood = 50;

      stepSimulation(state, TICK, [
        { type: 'transform-unit', item, unitId: candidates[0].id },
        { type: 'transform-unit', item, unitId: candidates[1].id },
      ]);
      expect(state.inventory.amounts.wood).toBe(45);

      // Adding a gatherer changes total population but not the specialist's next price.
      stepSimulation(state, TICK, [{ type: 'recruit-gatherer', position: { x: 80, y: 80 } }]);
      expect(state.units).toHaveLength(8);
      stepSimulation(state, TICK, [{ type: 'transform-unit', item, unitId: candidates[2].id }]);
      expect(state.inventory.amounts.wood).toBe(42);

      stepSimulation(state, TICK, [{ type: 'transform-unit', item, unitId: candidates[3].id }]);
      expect(state.inventory.amounts.wood).toBe(38);
      stepSimulation(state, TICK, [
        { type: 'damage-unit', unitId: candidates[0].id, amount: 4, sourceKind: 'barbarian' },
        { type: 'damage-unit', unitId: candidates[1].id, amount: 4, sourceKind: 'barbarian' },
        { type: 'transform-unit', item, unitId: candidates[4].id },
      ]);
      expect(state.inventory.amounts.wood).toBe(35);
      expect(state.units.filter((unit) => unit.role === targetRole)).toHaveLength(3);
    }
  });

  it('allows gatherers up to the global cap and limits each specialist role to five', () => {
    const gathererState = createInitialState();
    const initialSpecialist = gathererState.units.find((unit) => unit.role !== 'gatherer');
    if (!initialSpecialist) throw new Error('Expected the starting specialist');
    gathererState.inventory.amounts.food = 100;
    const recruitActions = Array.from({ length: 7 }, (_, index) => ({
      type: 'recruit-gatherer' as const,
      position: { x: 80 + index, y: 80 },
    }));
    stepSimulation(gathererState, TICK, [
      { type: 'damage-unit', unitId: initialSpecialist.id, amount: 4, sourceKind: 'barbarian' },
      ...recruitActions,
    ]);
    expect(gathererState.units).toHaveLength(8);
    expect(gathererState.units.every((unit) => unit.role === 'gatherer')).toBe(true);
    const foodAtCap = gathererState.inventory.amounts.food;
    stepSimulation(gathererState, TICK, [{ type: 'recruit-gatherer', position: { x: 80, y: 80 } }]);
    expect(gathererState.units).toHaveLength(8);
    expect(gathererState.inventory.amounts.food).toBe(foodAtCap);

    const makeState = (role: 'lumberjack' | 'hunter') => {
      const state = createInitialState();
      state.units = [
        ...Array.from({ length: 5 }, (_, index) => createUnitState(`${role}-${index}`, role, { x: 80, y: 80 })),
        ...Array.from({ length: 2 }, (_, index) => createUnitState(`gatherer-candidate-${index}`, 'gatherer', { x: 80, y: 80 })),
      ];
      state.inventory.amounts.wood = 100;
      return state;
    };

    const lumberjackState = makeState('lumberjack');
    stepSimulation(lumberjackState, TICK, [{
      type: 'transform-unit', item: 'axe', unitId: 'gatherer-candidate-0',
    }]);
    expect(lumberjackState.units.filter((unit) => unit.role === 'lumberjack')).toHaveLength(5);

    const hunterState = makeState('hunter');
    stepSimulation(hunterState, TICK, [{
      type: 'transform-unit', item: 'bow', unitId: 'gatherer-candidate-0',
    }]);
    expect(hunterState.units.filter((unit) => unit.role === 'hunter')).toHaveLength(5);
  });

  it('limits active campfires to two and allows a replacement when one expires after two minutes', () => {
    const state = createInitialState();
    const unit = state.units[0];
    unit.health = 2;
    unit.position = { x: 80, y: 80 };
    state.inventory.amounts.wood = 10;

    stepSimulation(state, TICK, [
      { type: 'place-campfire', position: { x: 80, y: 80 } },
      { type: 'place-campfire', position: { x: 84, y: 80 } },
    ]);
    expect(state.campfires).toHaveLength(MAX_ACTIVE_CAMPFIRES);
    const nextId = state.nextCampfireId;
    const woodAfterPlacement = state.inventory.amounts.wood;

    stepSimulation(state, TICK, [{ type: 'place-campfire', position: { x: 80, y: 80 } }]);
    expect(state.campfires).toHaveLength(MAX_ACTIVE_CAMPFIRES);
    expect(state.inventory.amounts.wood).toBe(woodAfterPlacement);
    expect(state.nextCampfireId).toBe(nextId);

    stepSimulation(state, CAMPFIRE_LIFETIME_SECONDS);
    expect(state.campfires).toHaveLength(0);
    expect(unit.health).toBe(2);

    stepSimulation(state, TICK, [{ type: 'place-campfire', position: { x: 80, y: 80 } }]);
    expect(state.campfires).toHaveLength(1);
    expect(state.campfires[0].id).not.toBe('campfire-01');
  });

  it('protects the last gatherer from lumberjack conversion but keeps hunter available', () => {
    const state = createInitialState();
    const gatherer = state.units.find((unit) => unit.role === 'gatherer');
    if (!gatherer) throw new Error('Expected the initial gatherer');
    state.inventory.amounts.wood = 5;

    stepSimulation(state, TICK, [{ type: 'transform-unit', item: 'axe', unitId: gatherer.id }]);

    expect(gatherer.role).toBe('gatherer');
    expect(state.inventory.amounts.wood).toBe(5);

    stepSimulation(state, TICK, [{ type: 'transform-unit', item: 'bow', unitId: gatherer.id }]);

    expect(gatherer.role).toBe('hunter');
    expect(state.inventory.amounts.wood).toBe(3);
  });

  it('handles totem drag, drop, world bounds, and ignores terrain-only clicks', () => {
    const dragged = createInitialState();
    stepSimulation(dragged, TICK, [
      { type: 'pick-up-totem' },
      { type: 'drag-totem', position: { x: 120, y: 100 } },
    ]);
    expect(dragged.totem.isCarried).toBe(true);
    expect(dragged.totem.position).toEqual({ x: 120, y: 100 });
    expect(dragged.totem.moving).toBe(false);

    const dropped = createInitialState();
    stepSimulation(dropped, TICK, [{ type: 'pick-up-totem' }]);
    stepSimulation(dropped, TICK, [{ type: 'drag-totem', position: { x: 120, y: 100 } }]);
    const positionAtDrop = { ...dropped.totem.position };
    stepSimulation(dropped, TICK, [{ type: 'drop-totem', position: { x: 120, y: 100 } }]);
    expect(dropped.totem.isCarried).toBe(false);
    expect(dropped.totem.position).toEqual(positionAtDrop);
    expect(dropped.totem.moving).toBe(true);
    expect(dropped.units.every((unit) => unit.state === 'follow-totem')).toBe(true);

    const clamped = createInitialState();
    stepSimulation(clamped, TICK, [{ type: 'pick-up-totem' }]);
    stepSimulation(clamped, TICK, [{ type: 'drag-totem', position: { x: -20, y: 300 } }]);
    expect(clamped.totem.dragTarget).toEqual({ x: 2, y: 158 });

    const terrainClick = createInitialState();
    const initialPosition = { ...terrainClick.totem.position };
    stepSimulation(terrainClick, TICK, [
      { type: 'drag-totem', position: { x: 120, y: 100 } },
      { type: 'drop-totem', position: { x: 120, y: 100 } },
    ]);
    expect(terrainClick.totem.position).toEqual(initialPosition);
    expect(terrainClick.totem.isCarried).toBe(false);
  });

  it('freezes the simulation while paused and can resume with the same action', () => {
    const state = createInitialState();

    stepSimulation(state, TICK, [{ type: 'toggle-pause' }]);
    expect(state.phase).toBe('paused');
    expect(state.tick).toBe(0);

    stepSimulation(state, TICK);
    expect(state.tick).toBe(0);

    stepSimulation(state, TICK, [{ type: 'toggle-pause' }]);
    expect(state.phase).toBe('playing');
    expect(state.tick).toBe(1);
  });

  it('converges units to deterministic formation slots', () => {
    const state = createInitialState();

    stepSimulation(state, TICK, [{ type: 'pick-up-totem' }]);
    stepSimulation(state, TICK, [{ type: 'drag-totem', position: { x: 120, y: 100 } }]);
    stepSimulation(state, TICK, [{ type: 'drop-totem', position: { x: 120, y: 100 } }]);
    for (let tick = 0; tick < 150; tick += 1) stepSimulation(state, TICK);

    expect(state.totem.moving).toBe(false);
    expect(state.units.every((unit) => unit.state === 'formation')).toBe(true);
    expect(Math.hypot(
      state.units[0].position.x - (state.totem.position.x + FORMATION_RADIUS),
      state.units[0].position.y - state.totem.position.y,
    ))
      .toBeLessThanOrEqual(FORMATION_RADIUS + 0.001);
  });

  it('moves minions toward the totem fifty percent faster without changing gather speed', () => {
    const following = createInitialState('totem-chase-speed');
    following.units = [createUnitState('following-minion', 'gatherer', { x: 80, y: 80 })];
    following.totem.isCarried = true;
    following.totem.position = { x: 100, y: 100 };

    stepSimulation(following, TICK);

    expect(Math.hypot(
      following.units[0].position.x - 80,
      following.units[0].position.y - 80,
    )).toBeCloseTo(TOTEM_CHASE_SPEED * TICK);
    expect(TOTEM_CHASE_SPEED).toBe(UNIT_SPEED * 1.5);

    const returning = createInitialState('totem-return-speed');
    returning.units = [createUnitState('returning-minion', 'gatherer', { x: 80, y: 80 })];
    returning.totem.position = { x: 60, y: 60 };
    returning.units[0].task = {
      kind: 'return-to-totem',
      targetResourceId: null,
      destination: { x: 100, y: 80 },
      cause: 'no-valid-resource',
    };

    stepSimulation(returning, TICK, [], { enableSurvival: true });

    expect(returning.units[0].position.x - 80).toBeCloseTo(TOTEM_CHASE_SPEED * TICK);

    const gathering = createInitialState('gather-speed-unchanged');
    gathering.units = [createUnitState('gathering-minion', 'gatherer', { x: 80, y: 80 })];
    gathering.totem.position = { x: 60, y: 60 };
    gathering.units[0].task = {
      kind: 'gather',
      targetResourceId: 'gather-speed-node',
      destination: { x: 100, y: 80 },
      cause: 'resource-found',
    };
    gathering.resources = [{
      id: 'gather-speed-node',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1,
      position: { x: 100, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
    }];

    stepSimulation(gathering, TICK, [], { enableSurvival: true });

    expect(gathering.units[0].position.x - 80).toBeCloseTo(UNIT_SPEED * TICK);
  });

  it('produces the same result for the same action stream', () => {
    const first = createInitialState();
    const second = createInitialState();
    const actions = [
      { type: 'pick-up-totem' as const },
      { type: 'drag-totem' as const, position: { x: 110, y: 90 } },
      { type: 'drop-totem' as const, position: { x: 110, y: 90 } },
    ];

    stepSimulation(first, TICK, [actions[0]]);
    stepSimulation(second, TICK, [actions[0]]);
    stepSimulation(first, TICK, [actions[1]]);
    stepSimulation(second, TICK, [actions[1]]);
    stepSimulation(first, TICK, [actions[2]]);
    stepSimulation(second, TICK, [actions[2]]);
    for (let tick = 0; tick < 20; tick += 1) {
      stepSimulation(first, TICK);
      stepSimulation(second, TICK);
    }

    expect(second).toEqual(first);
  });

  it('lets the initial gatherers drop berries and collect them without returning to the totem', () => {
    const state = createInitialState('berry-integration');
    state.resources = [{
      id: 'berry-bush-test',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 88, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
    }];

    let sawDropBeforeInventory = false;
    for (let tick = 0; tick < 200; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (state.drops.length > 0) {
        sawDropBeforeInventory = true;
        expect(state.inventory.amounts.food).toBe(0);
        expect(state.drops.every((drop) => {
          const distance = Math.hypot(drop.position.x - 88, drop.position.y - 80);
          return drop.amount === 1 && distance >= 1.49 && distance <= 1.51;
        })).toBe(true);
        expect(state.units.some((unit) => {
          const distanceToNode = Math.hypot(unit.position.x - 88, unit.position.y - 80);
          const distanceToTotem = Math.hypot(
            unit.position.x - state.totem.position.x,
            unit.position.y - state.totem.position.y,
          );
          return distanceToNode >= 1.4 && distanceToNode < 2 && distanceToTotem > 4;
        })).toBe(true);
        break;
      }
    }

    expect(sawDropBeforeInventory).toBe(true);
    for (let tick = 0; tick < 200; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (state.drops.length === 0 && state.inventory.amounts.food > 0) break;
    }
    expect(state.inventory.amounts.food).toBeCloseTo(1);
    expect(state.resources[0].amount).toBe(0);
    expect(state.drops).toHaveLength(0);
    expect(state.units.every((unit) => unit.cargo.amounts.food === 0)).toBe(true);
  });

  it('lets every minion role harvest a twig node that drops two wood', () => {
    for (const role of ['explorer', 'gatherer', 'lumberjack', 'hunter', 'guardian', 'artisan'] as const) {
      const state = createInitialState(`twigs-${role}`);
      const unit = createUnitState(`twig-harvester-${role}`, role, { x: 80, y: 80 });
      state.units = [unit];
      state.resources = [{
        id: 'twigs-test',
        type: 'wood',
        source: 'twigs',
        biome: 'clearing',
        biomeInstanceId: 'starting-clearing',
        isSecondary: true,
        interactionRadius: 1.2,
        position: { x: 80, y: 80 },
        amount: 1,
        maxAmount: 1,
        gatherRate: 1,
        yieldAmount: 2,
      }];

      for (let tick = 0; tick < 100 && state.drops.length === 0; tick += 1) {
        stepSimulation(state, TICK, [], { enableSurvival: true });
      }

      expect(state.resources[0].amount).toBe(0);
      expect(state.drops).toHaveLength(2);
      expect(state.drops.every((drop) => drop.type === 'wood'
        && drop.amount === 1
        && drop.sourceNodeId === 'twigs-test')).toBe(true);
    }
  });

  it('lets a lumberjack harvest a tree and deliver its wood drop to the inventory', () => {
    const state = createInitialState('tree-integration');
    state.units = [createUnitState('tree-lumberjack', 'lumberjack', { x: 80, y: 80 })];
    state.totem.position = { x: 50, y: 50 };
    state.resources = [{
      id: 'tree-test',
      type: 'wood',
      source: 'tree',
      biome: 'forest',
      isSecondary: false,
      interactionRadius: 1.35,
      position: { x: 80, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
      yieldAmount: 3,
    }];

    for (let tick = 0; tick < 100 && state.drops.length === 0; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }

    expect(state.resources[0].amount).toBe(0);
    expect(state.drops).toHaveLength(3);
    expect(state.drops.every((drop) => drop.type === 'wood'
      && drop.amount === 1
      && drop.sourceNodeId === 'tree-test')).toBe(true);
    expect(state.inventory.amounts.wood).toBe(0);

    for (let tick = 0; tick < 100 && state.drops.length > 0; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }

    expect(state.drops).toHaveLength(0);
    expect(state.inventory.amounts.wood).toBe(3);
  });

  it('keeps stone and spark untouched for the playable roles', () => {
    for (const role of ['gatherer', 'lumberjack', 'hunter'] as const) {
      const state = createInitialState(`unavailable-advanced-${role}`);
      state.units = [createUnitState(`unit-${role}`, role, { x: 80, y: 80 })];
      state.resources = [
        {
          id: 'stone-test',
          type: 'stone',
          source: 'stone-vein',
          biome: 'rocky',
          isSecondary: false,
          interactionRadius: 1.35,
          position: { x: 80, y: 80 },
          amount: 1,
          maxAmount: 1,
          gatherRate: 1,
        },
        {
          id: 'spark-test',
          type: 'spark',
          source: 'ruin',
          biome: 'ruins',
          isSecondary: false,
          interactionRadius: 1.3,
          position: { x: 80, y: 80 },
          amount: 1,
          maxAmount: 1,
          gatherRate: 1,
        },
      ];

      for (let tick = 0; tick < 20; tick += 1) {
        stepSimulation(state, TICK, [], { enableSurvival: true });
      }

      expect(state.units[0].task.kind).toBe('idle');
      expect(state.resources.map((resource) => resource.amount)).toEqual([1, 1]);
      expect(state.drops).toHaveLength(0);
      expect(state.inventory.amounts.stone).toBe(0);
      expect(state.inventory.amounts.spark).toBe(0);
    }
  });

  it('continues with a nearby drop before returning to the totem', () => {
    const state = createInitialState('local-follow-up');
    state.units = [state.units[0]];
    state.resources = [{
      id: 'berry-bush-follow-up',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 88, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
    }];

    let sawFollowUpDrop = false;
    let sawReturnBeforeFollowUp = false;
    for (let tick = 0; tick < 300; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (state.drops.length > 0) {
        sawFollowUpDrop = true;
        if (state.units.some((unit) => unit.task.kind === 'return-to-totem')) {
          sawReturnBeforeFollowUp = true;
        }
      }
      if (state.inventory.amounts.food > 0) break;
    }

    expect(sawFollowUpDrop).toBe(true);
    expect(sawReturnBeforeFollowUp).toBe(false);
    expect(state.inventory.amounts.food).toBe(1);
  });

  it('keeps an idle minion near the stationary totem and returns only outside its radius', () => {
    const state = createInitialState('totem-idle-radius');
    state.units = [state.units[0]];
    state.resources = [];
    state.drops = [];
    state.units[0].position = { x: 86, y: 80 };

    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(state.units[0].task.kind).toBe('idle');
    expect(state.units[0].position).toEqual({ x: 86, y: 80 });

    state.units[0].position = { x: 95, y: 80 };
    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(state.units[0].task.kind).toBe('return-to-totem');
  });

  it('keeps an unusable resource untouched when no capable minion is available', () => {
    const state = createInitialState('wood-only');
    state.inventory.amounts.wood = 0;
    state.units = [createUnitState('only-gatherer', 'gatherer', { x: 80, y: 80 })];
    state.resources = [{
      id: 'tree-test',
      type: 'wood',
      source: 'tree',
      biome: 'forest',
      isSecondary: false,
      interactionRadius: 1.35,
      position: { x: 82.5, y: 80 },
      amount: 5,
      maxAmount: 5,
      gatherRate: 1,
    }];

    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(state.units.every((unit) => unit.task.kind === 'idle')).toBe(true);
    expect(state.inventory.amounts.wood).toBe(0);
    expect(state.resources[0].amount).toBe(5);
  });

  it('lets a nearby minion call the nearest available lumberjack across the map', () => {
    const state = createInitialState('resource-call');
    const caller = createUnitState('caller-gatherer', 'gatherer', { x: 82.5, y: 80 });
    caller.task = {
      kind: 'gather',
      targetResourceId: 'caller-berry',
      destination: { x: 82.5, y: 80 },
      cause: 'resource-found',
    };
    state.units = [
      caller,
      createUnitState('near-hunter', 'hunter', { x: 83, y: 80 }),
      createUnitState('distant-lumberjack', 'lumberjack', { x: 145, y: 145 }),
      createUnitState('called-lumberjack', 'lumberjack', { x: 125, y: 80 }),
    ];
    state.resources = [
      {
        id: 'called-tree',
        type: 'wood',
        source: 'tree',
        biome: 'forest',
        isSecondary: false,
        interactionRadius: 1.35,
        position: { x: 84, y: 80 },
        amount: 2,
        maxAmount: 2,
        gatherRate: 1,
      },
      {
        id: 'caller-berry',
        type: 'food',
        source: 'berry-bush',
        biome: 'meadow',
        isSecondary: false,
        interactionRadius: 1.45,
        position: { x: 82.5, y: 80 },
        amount: 2,
        maxAmount: 2,
        gatherRate: 1,
      },
    ];

    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(state.units[0].task).toMatchObject({
      kind: 'gather',
      targetResourceId: 'caller-berry',
    });
    expect(state.units[1].task.kind).not.toBe('gather');
    expect(state.units[2].task.kind).not.toBe('gather');
    expect(state.units[3].task).toMatchObject({
      kind: 'gather',
      targetResourceId: 'called-tree',
      cause: 'resource-call-received',
    });
    expect(state.resources[0].amount).toBe(2);
    expect(state.effects).toHaveLength(0);
  });

  it('reserves one resource node for only one minion', () => {
    const state = createInitialState('ticketed-resource');
    state.resources = [{
      id: 'single-berry-bush',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 82.5, y: 80 },
      amount: 5,
      maxAmount: 5,
      gatherRate: 1,
    }];

    stepSimulation(state, TICK, [], { enableSurvival: true });

    expect(state.units.filter((unit) => unit.task.kind === 'gather')).toHaveLength(1);
    expect(state.units.filter((unit) => unit.task.kind === 'idle')).toHaveLength(1);
  });

  it('keeps minions idle near the totem after collecting', () => {
    const state = createInitialState('return-after-action');
    state.resources = [{
      id: 'return-berry-bush',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 88, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
    }];

    for (let tick = 0; tick < 500; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }

    expect(state.inventory.amounts.food).toBeCloseTo(1);
    expect(state.units.every((unit) => unit.state === 'idle')).toBe(true);
    expect(state.units.every((unit) => Math.hypot(
      unit.position.x - state.totem.position.x,
      unit.position.y - state.totem.position.y,
    ) <= state.totem.commandRadius)).toBe(true);
  });

  it('freezes autonomous gathering while paused', () => {
    const state = createInitialState('pause-survival');
    state.resources = [{
      id: 'berry-bush-pause-test',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 82.5, y: 80 },
      amount: 1,
      maxAmount: 1,
      gatherRate: 1,
    }];

    stepSimulation(state, TICK, [], { enableSurvival: true });
    stepSimulation(state, TICK, [{ type: 'toggle-pause' }], { enableSurvival: true });
    const pausedSnapshot = JSON.stringify(state);
    for (let tick = 0; tick < 20; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
    }

    expect(state.phase).toBe('paused');
    expect(JSON.stringify(state)).toBe(pausedSnapshot);
  });

  it('cancels a gathering task when the totem starts moving', () => {
    const state = createInitialState('totem-move-survival');
    state.resources = [{
      id: 'berry-bush-move-test',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 82.5, y: 80 },
      amount: 5,
      maxAmount: 5,
      gatherRate: 1,
    }];

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(state.units.some((unit) => unit.task.kind === 'gather')).toBe(true);

    stepSimulation(state, TICK, [{ type: 'pick-up-totem' }], { enableSurvival: true });
    expect(state.units.every((unit) => unit.task.cause === 'totem-moved')).toBe(true);
    expect(state.units.every((unit) => unit.state === 'follow-totem')).toBe(true);
  });

  it('does not consume or drop a resource when gathering is interrupted', () => {
    const state = createInitialState('interrupt-gathering');
    state.units = [state.units[0]];
    state.totem.position = { x: 78, y: 78 };
    state.resources = [{
      id: 'berry-bush-interrupt-test',
      type: 'food',
      source: 'berry-bush',
      biome: 'meadow',
      isSecondary: false,
      interactionRadius: 1.45,
      position: { x: 82.5, y: 80 },
      amount: 5,
      maxAmount: 5,
      gatherRate: 1,
    }];

    for (let tick = 0; tick < 100; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (state.units[0].state === 'gathering') break;
    }

    expect(state.units[0].state).toBe('gathering');
    expect(state.resources[0].amount).toBe(5);
    expect(state.drops).toHaveLength(0);
    expect(state.units[0].cargo.amounts.food).toBe(0);

    stepSimulation(state, TICK, [{ type: 'pick-up-totem' }], { enableSurvival: true });

    expect(state.resources[0].amount).toBe(5);
    expect(state.drops).toHaveLength(0);
    expect(state.units[0].cargo.amounts.food).toBe(0);
    expect(state.units[0].actionProgressSeconds).toBe(0);

    stepSimulation(state, TICK, [{ type: 'drag-totem', position: { x: 80, y: 80 } }], {
      enableSurvival: true,
    });
    stepSimulation(state, TICK, [{ type: 'drop-totem', position: { x: 80, y: 80 } }], {
      enableSurvival: true,
    });
    for (let tick = 0; tick < 220; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (state.resources[0].amount < 5) break;
    }

    expect(state.resources[0].amount).toBeLessThan(5);
  });

  it('re-detects a cancelled drop after the totem finishes moving', () => {
    const state = createInitialState('cancel-drop-survival');
    state.units = [state.units[0]];
    state.resources = [];
    state.drops = [{
      id: 'drop-cancel-test',
      type: 'food',
      sourceNodeId: null,
      position: { x: 86, y: 80 },
      amount: 1,
    }];

    stepSimulation(state, TICK, [], { enableSurvival: true });
    expect(state.units[0].task.targetResourceId).toBe('drop-cancel-test');
    stepSimulation(state, TICK, [{ type: 'pick-up-totem' }], { enableSurvival: true });
    stepSimulation(state, TICK, [{ type: 'drag-totem', position: { x: 84, y: 80 } }], {
      enableSurvival: true,
    });
    stepSimulation(state, TICK, [{ type: 'drop-totem', position: { x: 84, y: 80 } }], {
      enableSurvival: true,
    });
    for (let tick = 0; tick < 140; tick += 1) {
      stepSimulation(state, TICK, [], { enableSurvival: true });
      if (state.inventory.amounts.food > 0) break;
    }

    expect(state.totem.moving).toBe(false);
    expect(state.units[0].cancelledTargetId).toBeNull();
    expect(state.inventory.amounts.food).toBe(1);
    expect(state.drops).toHaveLength(0);
  });
});

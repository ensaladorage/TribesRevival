import {
  DEFAULT_SURVIVAL_SEED,
  HITO_3_GENERATION_CONFIG,
  createBarbarianStates,
  createRabbitStates,
  createSurvivalBlueprint,
} from './survivalCatalog';
import { createSeededRandom } from './seededRandom';
import { createEmptyResourceAmounts } from './survivalTypes';
import { MINION_MAX_HEALTH } from './survivalCombat';
import { createWeatherState } from './weatherSystem';
import { createInitialProgressionState } from './progression';
import type { GameState } from './types';

export function createUnitState(
  id: string,
  role: GameState['units'][number]['role'],
  position: { x: number; y: number },
): GameState['units'][number] {
  return {
    id,
    position,
    role,
    hasShield: false,
    health: MINION_MAX_HEALTH,
    maxHealth: MINION_MAX_HEALTH,
    healingProgressSeconds: 0,
    state: 'formation',
    cargo: {
      amounts: createEmptyResourceAmounts(),
      capacity: 4,
    },
    task: {
      kind: 'idle',
      targetResourceId: null,
      destination: null,
      cause: 'no-valid-resource',
    },
    cancelledTargetId: null,
    actionProgressSeconds: 0,
    attackCooldownRemainingSeconds: 0,
    attackLockRemainingSeconds: 0,
    withdrawAfterAttack: false,
  };
}

export function createInitialState(seed = DEFAULT_SURVIVAL_SEED): GameState {
  const blueprint = createSurvivalBlueprint(seed, HITO_3_GENERATION_CONFIG);
  const rosterRandom = createSeededRandom(`${blueprint.seed}:initial-roster`);
  const secondRole = rosterRandom.nextInt(0, 1) === 0 ? 'lumberjack' : 'hunter';

  return {
    version: 16,
    seed: blueprint.seed,
    tick: 0,
    phase: 'playing',
    totem: {
      position: { x: 80, y: 80 },
      dragTarget: null,
      destination: null,
      moving: false,
      isCarried: false,
      commandRadius: 10,
      dangerRadius: 18,
      bondEnergy: 100,
    },
    units: [
      createUnitState('unit-gatherer-01', 'gatherer', { x: 84, y: 80 }),
      createUnitState('unit-initial-specialist-02', secondRole, { x: 76, y: 80 }),
    ],
    corpses: [],
    barbarians: createBarbarianStates(blueprint.seed),
    animals: createRabbitStates(blueprint.seed, blueprint.biomes),
    barbarianCorpses: [],
    purchaseCounts: {
      gatherer: 0,
      lumberjack: 0,
      hunter: 0,
      guardian: 0,
      artisan: 0,
    },
    progression: createInitialProgressionState(),
    biomes: [...blueprint.biomes],
    resources: [...blueprint.resources],
    decorations: [...blueprint.decorations],
    drops: [],
    nextDropId: 1,
    campfires: [],
    nextCampfireId: 1,
    inventory: {
      amounts: createEmptyResourceAmounts(),
    },
    effects: [],
    nextEffectId: 1,
    alerts: [],
    nextAlertId: 1,
    weather: createWeatherState(),
  };
}

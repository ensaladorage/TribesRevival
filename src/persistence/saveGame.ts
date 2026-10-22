import type { GameState } from '../simulation/types';
import {
  BIOME_IDS,
  RESOURCE_TYPES,
  SURVIVAL_ROLES,
  type BiomeId,
  type ResourceType,
} from '../simulation/survivalTypes';

export const SAVE_SLOT_COUNT = 3;
export const SAVE_SCHEMA_VERSION = 1;
const SAVE_KEY_PREFIX = 'tribes-revival.save.v1.slot.';

export type SaveSlotId = 1 | 2 | 3;

export type SaveMetadata = {
  savedAt: string;
  level: number;
  minionCount: number;
};

export type SaveEnvelope = {
  schemaVersion: typeof SAVE_SCHEMA_VERSION;
  metadata: SaveMetadata;
  gameState: GameState;
};

export type SaveSlotStatus =
  | { slot: SaveSlotId; status: 'empty' }
  | { slot: SaveSlotId; status: 'valid'; save: SaveEnvelope }
  | { slot: SaveSlotId; status: 'invalid'; reason: 'corrupt' | 'incompatible' };

export type SaveStorage = Pick<Storage, 'getItem' | 'setItem'>;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isFiniteNumber(value: unknown, minimum = 0): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= minimum;
}

function isVec2(value: unknown): boolean {
  return isRecord(value) && isFiniteNumber(value.x, -Infinity) && isFiniteNumber(value.y, -Infinity);
}

function isResourceAmounts(value: unknown): boolean {
  return isRecord(value) && RESOURCE_TYPES.every((resource) => isFiniteNumber(value[resource]));
}

function isResourceType(value: unknown): value is ResourceType {
  return RESOURCE_TYPES.includes(value as ResourceType);
}

function isBiomeId(value: unknown): value is BiomeId {
  return BIOME_IDS.includes(value as (typeof BIOME_IDS)[number]) || value === 'great-fire';
}

function isNullableString(value: unknown): boolean {
  return value === null || typeof value === 'string';
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((entry) => typeof entry === 'string');
}

function isUnit(value: unknown): boolean {
  if (!isRecord(value) || !isRecord(value.cargo) || !isRecord(value.task)) return false;
  const unitStates = [
    'follow-totem', 'formation', 'seeking-task', 'gathering', 'collecting-drop', 'combat',
    'fleeing', 'looting-corpse', 'hunting', 'returning-to-totem', 'idle',
  ];
  const taskKinds = ['idle', 'gather', 'collect-drop', 'return-to-totem', 'combat', 'flee', 'loot-corpse', 'hunt'];
  const taskCauses = [
    'resource-found', 'resource-call-received', 'resource-depleted', 'over-capacity',
    'no-valid-resource', 'totem-moved', 'cargo-dropped', 'drop-found', 'drop-collected',
    'drop-empty', 'animal-found', 'corpse-found', 'corpse-looted', 'threat-nearby',
    'combat-ended', 'action-complete',
  ];
  return typeof value.id === 'string'
    && isVec2(value.position)
    && SURVIVAL_ROLES.includes(value.role as (typeof SURVIVAL_ROLES)[number])
    && typeof value.hasShield === 'boolean'
    && isFiniteNumber(value.health)
    && isFiniteNumber(value.maxHealth, 1)
    && isFiniteNumber(value.healingProgressSeconds)
    && unitStates.includes(String(value.state))
    && isResourceAmounts(value.cargo.amounts)
    && isFiniteNumber(value.cargo.capacity, 1)
    && taskKinds.includes(String(value.task.kind))
    && isNullableString(value.task.targetResourceId)
    && (value.task.targetEntityId === undefined || isNullableString(value.task.targetEntityId))
    && (value.task.destination === null || isVec2(value.task.destination))
    && taskCauses.includes(String(value.task.cause))
    && isNullableString(value.cancelledTargetId)
    && isFiniteNumber(value.actionProgressSeconds)
    && isFiniteNumber(value.attackCooldownRemainingSeconds)
    && isFiniteNumber(value.attackLockRemainingSeconds)
    && typeof value.withdrawAfterAttack === 'boolean';
}

function isResourceNode(value: unknown): boolean {
  if (!isRecord(value)) return false;
  const sources = ['berry-bush', 'tree', 'stone-vein', 'ruin', 'twigs'];
  return typeof value.id === 'string'
    && isResourceType(value.type)
    && sources.includes(String(value.source))
    && isBiomeId(value.biome)
    && (value.biomeInstanceId === undefined || typeof value.biomeInstanceId === 'string')
    && typeof value.isSecondary === 'boolean'
    && isFiniteNumber(value.interactionRadius)
    && isVec2(value.position)
    && isFiniteNumber(value.amount)
    && isFiniteNumber(value.maxAmount)
    && isFiniteNumber(value.gatherRate)
    && (value.yieldAmount === undefined || isFiniteNumber(value.yieldAmount));
}

function isBiome(value: unknown): boolean {
  if (!isRecord(value) || !isRecord(value.region)) return false;
  return isBiomeId(value.id)
    && typeof value.instanceId === 'string'
    && typeof value.isDecorativeOnly === 'boolean'
    && typeof value.displayName === 'string'
    && isFiniteNumber(value.movementMultiplier)
    && Array.isArray(value.visibleResourceTypes)
    && value.visibleResourceTypes.every(isResourceType)
    && isFiniteNumber(value.region.x, -Infinity)
    && isFiniteNumber(value.region.y, -Infinity)
    && isFiniteNumber(value.region.size)
    && value.region.shape === 'circle';
}

function isGameState(value: unknown): value is GameState {
  if (!isRecord(value) || !isRecord(value.totem) || !isRecord(value.progression)) return false;
  const phases = ['playing', 'paused', 'victory', 'defeat'];
  const technologyIds = ['artisan', 'shield'];
  const amountLists = [
    value.totem.position,
    value.totem.dragTarget,
    value.totem.destination,
  ];
  const totemPositionsValid = amountLists.every((position) => position === null || isVec2(position));
  const purchases = value.purchaseCounts;
  const inventory = value.inventory;
  const weather = value.weather;
  if (!isRecord(purchases) || !isRecord(inventory) || !isRecord(weather)) return false;

  const validUnitCorpses = Array.isArray(value.corpses) && value.corpses.every((corpse) => (
    isRecord(corpse) && typeof corpse.id === 'string'
    && typeof corpse.formerUnitId === 'string' && isVec2(corpse.position)
  ));
  const validBarbarians = Array.isArray(value.barbarians) && value.barbarians.every((actor) => (
    isRecord(actor) && typeof actor.id === 'string' && isVec2(actor.position)
    && isVec2(actor.spawnPosition) && isVec2(actor.patrolCenter) && isVec2(actor.patrolTarget)
    && isFiniteNumber(actor.patrolRadius) && isFiniteNumber(actor.patrolWaitRemainingSeconds)
    && isFiniteNumber(actor.patrolStep) && typeof actor.returningToSpawn === 'boolean'
    && isFiniteNumber(actor.health) && isFiniteNumber(actor.maxHealth, 1)
    && typeof actor.isAlive === 'boolean' && isFiniteNumber(actor.respawnRemainingSeconds)
    && isFiniteNumber(actor.attackProgressSeconds) && isNullableString(actor.targetUnitId)
    && isStringArray(actor.alertedUnitIds) && typeof actor.alertSoundedThisEncounter === 'boolean'
    && isFiniteNumber(actor.spawnCycle)
  ));
  const validAnimals = Array.isArray(value.animals) && value.animals.every((animal) => (
    isRecord(animal) && typeof animal.id === 'string' && animal.kind === 'rabbit'
    && isVec2(animal.position) && isVec2(animal.spawnPosition) && isVec2(animal.homeCenter)
    && isFiniteNumber(animal.homeRadius) && isVec2(animal.patrolTarget)
    && isFiniteNumber(animal.health) && isFiniteNumber(animal.maxHealth, 1)
    && typeof animal.isAlive === 'boolean' && isFiniteNumber(animal.respawnRemainingSeconds)
    && isFiniteNumber(animal.attackProgressSeconds) && isFiniteNumber(animal.spawnCycle)
  ));
  const validBarbarianCorpses = Array.isArray(value.barbarianCorpses)
    && value.barbarianCorpses.every((corpse) => (
      isRecord(corpse) && typeof corpse.id === 'string' && typeof corpse.barbarianId === 'string'
      && isVec2(corpse.position) && isResourceAmounts(corpse.loot)
    ));
  const validDecorations = Array.isArray(value.decorations) && value.decorations.every((decoration) => (
    isRecord(decoration) && typeof decoration.id === 'string'
    && ['grass', 'mushroom', 'flower'].includes(String(decoration.kind))
    && (decoration.flowerColor === undefined
      || ['yellow', 'blue', 'gray', 'pink'].includes(String(decoration.flowerColor)))
    && isBiomeId(decoration.biome) && typeof decoration.biomeInstanceId === 'string'
    && isVec2(decoration.position) && isFiniteNumber(decoration.scale)
  ));
  const validDrops = Array.isArray(value.drops) && value.drops.every((drop) => (
    isRecord(drop) && typeof drop.id === 'string' && isResourceType(drop.type)
    && isNullableString(drop.sourceNodeId) && isVec2(drop.position) && isFiniteNumber(drop.amount)
  ));
  const validCampfires = Array.isArray(value.campfires) && value.campfires.every((fire) => (
    isRecord(fire) && typeof fire.id === 'string' && isVec2(fire.position)
    && isFiniteNumber(fire.healingRadius) && isFiniteNumber(fire.remainingLifetimeSeconds)
  ));
  const validEffects = Array.isArray(value.effects) && value.effects.every((effect) => (
    isRecord(effect) && typeof effect.id === 'string'
    && ['damage-flash', 'heal-crosses', 'attack-lunge'].includes(String(effect.kind))
    && typeof effect.targetId === 'string' && isVec2(effect.position)
    && isFiniteNumber(effect.ageSeconds) && isFiniteNumber(effect.durationSeconds)
  ));
  const validAlerts = Array.isArray(value.alerts) && value.alerts.every((alert) => (
    isRecord(alert) && typeof alert.id === 'string'
    && ['minion', 'barbarian'].includes(String(alert.detectorKind))
    && typeof alert.detectorId === 'string' && isVec2(alert.position)
    && isFiniteNumber(alert.ageSeconds) && isFiniteNumber(alert.durationSeconds)
    && typeof alert.playSound === 'boolean'
  ));
  const validClouds = Array.isArray(weather.clouds) && weather.clouds.every((cloud) => (
    isRecord(cloud) && typeof cloud.id === 'string' && isVec2(cloud.position)
    && typeof cloud.targetBiomeInstanceId === 'string'
    && ['approaching', 'raining', 'departing'].includes(String(cloud.phase))
    && isFiniteNumber(cloud.phaseElapsedSeconds) && isFiniteNumber(cloud.rainRemainingSeconds)
  ));

  return value.version === 16
    && typeof value.seed === 'string'
    && isFiniteNumber(value.tick)
    && phases.includes(String(value.phase))
    && isVec2(value.totem.position)
    && totemPositionsValid
    && typeof value.totem.moving === 'boolean'
    && typeof value.totem.isCarried === 'boolean'
    && isFiniteNumber(value.totem.commandRadius)
    && isFiniteNumber(value.totem.dangerRadius)
    && isFiniteNumber(value.totem.bondEnergy)
    && Array.isArray(value.units) && value.units.every(isUnit)
    && validUnitCorpses
    && validBarbarians
    && validAnimals
    && validBarbarianCorpses
    && isRecord(purchases)
    && ['gatherer', 'lumberjack', 'hunter', 'guardian', 'artisan']
      .every((role) => isFiniteNumber(purchases[role]))
    && isFiniteNumber(value.progression.level, 1)
    && isFiniteNumber(value.progression.experience)
    && isFiniteNumber(value.progression.experienceToNextLevel, 1)
    && isFiniteNumber(value.progression.technologyPoints)
    && Array.isArray(value.progression.unlockedTechnologies)
    && value.progression.unlockedTechnologies.every((technology) => technologyIds.includes(String(technology)))
    && Array.isArray(value.biomes) && value.biomes.every(isBiome)
    && Array.isArray(value.resources) && value.resources.every(isResourceNode)
    && validDecorations
    && validDrops
    && isFiniteNumber(value.nextDropId, 1)
    && validCampfires
    && isFiniteNumber(value.nextCampfireId, 1)
    && isRecord(inventory) && isResourceAmounts(inventory.amounts)
    && validEffects
    && isFiniteNumber(value.nextEffectId, 1)
    && validAlerts
    && isFiniteNumber(value.nextAlertId, 1)
    && isFiniteNumber(weather.nextCloudInSeconds)
    && isFiniteNumber(weather.nextCloudIndex)
    && validClouds;
}


function isSaveEnvelope(value: unknown): value is SaveEnvelope {
  if (!isRecord(value)) return false;
  if (value.schemaVersion !== SAVE_SCHEMA_VERSION) return false;
  if (!isRecord(value.metadata) || !isGameState(value.gameState)) return false;
  return typeof value.metadata.savedAt === 'string'
    && Number.isFinite(Date.parse(value.metadata.savedAt))
    && isFiniteNumber(value.metadata.level, 1)
    && isFiniteNumber(value.metadata.minionCount);
}

export function normalizeSaveState(state: GameState): GameState {
  const normalized = JSON.parse(JSON.stringify(state)) as GameState;
  normalized.phase = 'playing';
  return normalized;
}

export function getSaveFingerprint(state: GameState): string {
  return JSON.stringify(normalizeSaveState(state));
}

export function getSaveSlotIds(): SaveSlotId[] {
  return [1, 2, 3];
}

export class SaveGameRepository {
  public constructor(private readonly storage: SaveStorage) {}

  public listSlots(): SaveSlotStatus[] {
    return getSaveSlotIds().map((slot) => this.readSlot(slot));
  }

  public readSlot(slot: SaveSlotId): SaveSlotStatus {
    let raw: string | null;
    try {
      raw = this.storage.getItem(`${SAVE_KEY_PREFIX}${slot}`);
    } catch {
      return { slot, status: 'invalid', reason: 'corrupt' };
    }
    if (raw === null) return { slot, status: 'empty' };

    try {
      const parsed: unknown = JSON.parse(raw);
      if (
        isRecord(parsed)
        && (parsed.schemaVersion !== SAVE_SCHEMA_VERSION
          || (isRecord(parsed.gameState) && parsed.gameState.version !== 16))
      ) {
        return { slot, status: 'invalid', reason: 'incompatible' };
      }
      if (!isSaveEnvelope(parsed)) return { slot, status: 'invalid', reason: 'corrupt' };
      return { slot, status: 'valid', save: parsed };
    } catch {
      return { slot, status: 'invalid', reason: 'corrupt' };
    }
  }

  public save(slot: SaveSlotId, state: GameState, savedAt = new Date().toISOString()): SaveEnvelope {
    const gameState = normalizeSaveState(state);
    const save: SaveEnvelope = {
      schemaVersion: SAVE_SCHEMA_VERSION,
      metadata: {
        savedAt,
        level: gameState.progression.level,
        minionCount: gameState.units.length,
      },
      gameState,
    };
    this.storage.setItem(`${SAVE_KEY_PREFIX}${slot}`, JSON.stringify(save));
    return save;
  }
}

export function createBrowserSaveRepository(): SaveGameRepository {
  return new SaveGameRepository({
    getItem: (key) => window.localStorage.getItem(key),
    setItem: (key, value) => window.localStorage.setItem(key, value),
  });
}

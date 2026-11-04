import { describe, expect, it } from 'vitest';
import { createInitialState } from '../simulation/createInitialState';
import { chooseIdleDestination } from '../simulation/minionIdle';
import { createMinionNavigationState } from '../simulation/minionNavigation';
import {
  getSaveFingerprint,
  SaveGameRepository,
  type SaveStorage,
} from './saveGame';

function createMemoryStorage(): SaveStorage & { values: Map<string, string> } {
  const values = new Map<string, string>();
  return {
    values,
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => { values.set(key, value); },
    removeItem: (key) => { values.delete(key); },
  };
}

describe('save game repository', () => {
  it('preserves a committed route and combat offset without requiring them in older saves', () => {
    const repository = new SaveGameRepository(createMemoryStorage());
    const state = createInitialState('navigation-save');
    state.units[0].navigation = { ...createMinionNavigationState({ x: 85, y: 82 }),
      waypoints: [{ x: 83, y: 83 }], velocity: { x: 3, y: 2 }, side: 1, sideHoldSeconds: 0.4,
      combatTargetId: 'barbarian-1', combatOffset: { x: 0.98, y: 0 } };
    repository.save(1, state, '2026-11-04T10:00:00.000Z');
    const slot = repository.readSlot(1);
    if (slot.status !== 'valid') throw new Error('Expected a valid save slot');
    expect(slot.save.gameState).toEqual(state);
    expect(slot.save.gameState.units[1].navigation).toBeUndefined();
  });

  it('preserves an idle destination, pause and deterministic continuation', () => {
    const repository = new SaveGameRepository(createMemoryStorage());
    const state = createInitialState('idle-save');
    state.units[0].idleMovement = { destination: { x: 82.6, y: 81 }, waitRemainingSeconds: 0.8, step: 12 };
    repository.save(1, state, '2026-11-04T10:00:00.000Z');
    const slot = repository.readSlot(1);
    if (slot.status !== 'valid') throw new Error('Expected a valid save slot');
    expect(slot.save.gameState).toEqual(state);
    const restored = slot.save.gameState.units[0];
    const area = { center: state.totem.position, commandRadius: 10, minimumCoordinate: 2, maximumCoordinate: 158 };
    expect(chooseIdleDestination(state.seed, restored.id, restored.idleMovement!.step, restored.position, area))
      .toEqual(chooseIdleDestination(state.seed, state.units[0].id, 12, state.units[0].position, area));
  });

  it.each([16, 17])('initializes absent or malformed idle data in v%s without losing existing progress', (version) => {
    const storage = createMemoryStorage();
    const state = createInitialState('legacy-idle-save');
    state.inventory.amounts.gold = 7;
    state.progression.unlockedTechnologies = ['artisan'];
    const stored = structuredClone(state) as unknown as Record<string, unknown>;
    stored.version = version;
    const units = stored.units as Array<Record<string, unknown>>;
    delete units[0].idleMovement;
    units[1].idleMovement = { destination: null, waitRemainingSeconds: -1, step: 1.5 };
    storage.values.set('tribes-revival.save.v1.slot.1', JSON.stringify({
      schemaVersion: 1,
      metadata: { savedAt: '2026-11-04T10:00:00.000Z', level: 0, minionCount: 2 },
      gameState: stored,
    }));
    const slot = new SaveGameRepository(storage).readSlot(1);
    if (slot.status !== 'valid') throw new Error('Expected a migrated save slot');
    expect(slot.save.gameState).toEqual(state);
  });

  it('preserves points and existing technology unlocks without applying new purchase requirements on load', () => {
    const repository = new SaveGameRepository(createMemoryStorage());
    const state = createInitialState('technology-trees-save');
    state.progression.technologyPoints = 4;
    state.progression.unlockedTechnologies = ['artisan', 'mage', 'shield'];
    repository.save(1, state, '2026-11-04T10:00:00.000Z');
    const slot = repository.readSlot(1);
    if (slot.status !== 'valid') throw new Error('Expected a valid save slot');
    expect(slot.save.gameState.version).toBe(17);
    expect(slot.save.gameState.progression).toEqual(state.progression);
  });

  it('lists three empty slots and saves a resumable snapshot with metadata', () => {
    const storage = createMemoryStorage();
    const repository = new SaveGameRepository(storage);
    const state = createInitialState('save-round-trip');
    state.phase = 'paused';

    expect(repository.listSlots().map(({ status }) => status)).toEqual(['empty', 'empty', 'empty']);
    repository.save(2, state, '2026-10-20T10:00:00.000Z');

    const slot = repository.readSlot(2);
    expect(slot.status).toBe('valid');
    if (slot.status !== 'valid') throw new Error('Expected a valid save slot');
    expect(slot.save.metadata).toEqual({
      savedAt: '2026-10-20T10:00:00.000Z',
      level: state.progression.level,
      minionCount: state.units.length,
    });
    expect(slot.save.gameState.phase).toBe('playing');
    expect(getSaveFingerprint(slot.save.gameState)).toBe(getSaveFingerprint(state));
  });

  it('marks corrupt and incompatible slots unavailable without affecting other slots', () => {
    const storage = createMemoryStorage();
    storage.values.set('tribes-revival.save.v1.slot.1', '{broken');
    storage.values.set('tribes-revival.save.v1.slot.2', JSON.stringify({ schemaVersion: 999 }));
    storage.values.set('tribes-revival.save.v1.slot.3', JSON.stringify({
      schemaVersion: 1,
      metadata: { savedAt: '2026-10-20T10:00:00.000Z', level: 1, minionCount: 2 },
      gameState: { version: 15 },
    }));
    const repository = new SaveGameRepository(storage);

    expect(repository.readSlot(1)).toEqual({ slot: 1, status: 'invalid', reason: 'corrupt' });
    expect(repository.readSlot(2)).toEqual({ slot: 2, status: 'invalid', reason: 'incompatible' });
    expect(repository.readSlot(3)).toEqual({ slot: 3, status: 'invalid', reason: 'incompatible' });
  });

  it('replaces a slot only when save is explicitly called for that slot', () => {
    const repository = new SaveGameRepository(createMemoryStorage());
    const first = createInitialState('save-overwrite-one');
    const second = createInitialState('save-overwrite-two');

    repository.save(1, first, '2026-10-20T10:00:00.000Z');
    repository.save(1, second, '2026-10-20T10:01:00.000Z');

    const slot = repository.readSlot(1);
    expect(slot.status).toBe('valid');
    if (slot.status !== 'valid') throw new Error('Expected a valid save slot');
    expect(slot.save.gameState.seed).toBe(second.seed);
    expect(slot.save.metadata.savedAt).toBe('2026-10-20T10:01:00.000Z');
  });

  it('migrates a version 16 state with no tool or mage progress', () => {
    const storage = createMemoryStorage();
    const state = createInitialState('legacy-save');
    const legacy = structuredClone(state) as unknown as Record<string, unknown>;
    legacy.version = 16;
    delete legacy.toolLevels;
    const legacyPurchases = { ...(legacy.purchaseCounts as Record<string, number>) };
    delete legacyPurchases.mage;
    legacy.purchaseCounts = legacyPurchases;
    storage.values.set('tribes-revival.save.v1.slot.1', JSON.stringify({
      schemaVersion: 1,
      metadata: {
        savedAt: '2026-10-20T10:00:00.000Z',
        level: state.progression.level,
        minionCount: state.units.length,
      },
      gameState: legacy,
    }));

    const slot = new SaveGameRepository(storage).readSlot(1);
    expect(slot.status).toBe('valid');
    if (slot.status !== 'valid') throw new Error('Expected a migrated save slot');
    expect(slot.save.gameState.version).toBe(17);
    expect(slot.save.gameState.toolLevels).toEqual({ axe: 0, hammer: 0, sword: 0 });
    expect(slot.save.gameState.purchaseCounts.mage).toBe(0);
  });

  it('normalizes partial v17 tool levels and treats legacy resource nodes as tier one', () => {
    const storage = createMemoryStorage();
    const state = createInitialState('partial-v17-save');
    state.toolLevels = { axe: 8, hammer: 5, sword: 3 };
    const partial = structuredClone(state) as unknown as Record<string, unknown>;
    partial.toolLevels = { axe: 8 };
    const resources = partial.resources as Array<Record<string, unknown>>;
    delete resources[0].tier;
    storage.values.set('tribes-revival.save.v1.slot.1', JSON.stringify({
      schemaVersion: 1,
      metadata: {
        savedAt: '2026-11-04T10:00:00.000Z',
        level: state.progression.level,
        minionCount: state.units.length,
      },
      gameState: partial,
    }));

    const slot = new SaveGameRepository(storage).readSlot(1);
    expect(slot.status).toBe('valid');
    if (slot.status !== 'valid') throw new Error('Expected a normalized v17 save slot');
    expect(slot.save.gameState.toolLevels).toEqual({ axe: 8, hammer: 0, sword: 0 });
    expect(slot.save.gameState.resources[0].tier).toBeUndefined();
  });

  it('uses normalized state to detect unsaved changes while ignoring pause state', () => {
    const saved = createInitialState('dirty-state');
    const samePaused = structuredClone(saved);
    samePaused.phase = 'paused';
    const changed = structuredClone(saved);
    changed.tick += 1;

    expect(getSaveFingerprint(samePaused)).toBe(getSaveFingerprint(saved));
    expect(getSaveFingerprint(changed)).not.toBe(getSaveFingerprint(saved));
  });
});

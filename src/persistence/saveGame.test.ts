import { describe, expect, it } from 'vitest';
import { createInitialState } from '../simulation/createInitialState';
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
  };
}

describe('save game repository', () => {
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

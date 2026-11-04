import { describe, expect, it } from 'vitest';
import { chooseEntityCalls, type EntitySighting, type SightingResponder } from './minionAwareness';

const observer: SightingResponder = { id: 'observer', position: { x: 59, y: 40 },
  available: false, canFight: false, canHunt: false, currentKind: 'gather' };
const guardian: SightingResponder = { id: 'guardian', position: { x: 40, y: 40 },
  available: true, canFight: true, canHunt: false, currentKind: 'idle' };
const hunter: SightingResponder = { ...guardian, id: 'hunter', canHunt: true };
const enemy: EntitySighting = { id: 'enemy', kind: 'combat', position: { x: 60, y: 40 }, isAlive: true };
const animal: EntitySighting = { id: 'rabbit', kind: 'hunt', position: { x: 60, y: 41 }, isAlive: true };
const calls = (units: SightingResponder[], entities: EntitySighting[]) => chooseEntityCalls(units, entities, 18, 10.5);

describe('shared minion sightings (pure assignment rules)', () => {
  it('calls a fighter beyond its own detection range without interrupting the observer', () => {
    const before = structuredClone(observer);
    expect(calls([observer, guardian], [enemy]).get(guardian.id)).toEqual({ kind: 'combat', targetId: enemy.id });
    expect(observer).toEqual(before);
    expect(calls([guardian], [enemy]).size).toBe(0);
  });

  it('calls only the closest free hunter to an animal outside its local range', () => {
    const farther = { ...hunter, id: 'farther', position: { x: 35, y: 40 } };
    const result = calls([observer, guardian, farther, hunter], [animal]);
    expect([...result]).toEqual([[hunter.id, { kind: 'hunt', targetId: animal.id }]]);
  });

  it('keeps an assigned remote target while observed without calling extra responders', () => {
    const assigned = { ...guardian, available: false, currentKind: 'combat', currentTargetId: enemy.id };
    expect([...calls([observer, assigned, hunter], [enemy])]).toEqual([[guardian.id, { kind: 'combat', targetId: enemy.id }]]);
    expect(calls([assigned, hunter], [enemy]).size).toBe(0);
    expect(calls([observer, assigned, hunter], [{ ...enemy, isAlive: false }]).size).toBe(0);
  });

  it('does not interrupt busy specialists or assign incompatible roles', () => {
    expect(calls([observer, guardian], [animal]).size).toBe(0);
    expect(calls([observer, { ...hunter, available: false, currentKind: 'gather' }], [animal]).size).toBe(0);
    expect(calls([observer, { ...guardian, available: false, currentKind: 'loot-corpse' }], [enemy]).size).toBe(0);
  });

  it('prioritizes enemies over animals and does not assign a responder twice', () => {
    const result = calls([observer, hunter], [animal, enemy]);
    expect([...result]).toEqual([[hunter.id, { kind: 'combat', targetId: enemy.id }]]);
    expect(result).toEqual(calls([hunter, observer], [enemy, animal]));
  });

  it('uses stable identifiers for tied responders', () => {
    const first = { ...hunter, id: 'a' };
    const second = { ...hunter, id: 'z' };
    expect([...calls([observer, second, first], [animal])]).toEqual([['a', { kind: 'hunt', targetId: animal.id }]]);
  });

  it('respects existing movement requirements when choosing a responder', () => {
    const result = chooseEntityCalls([observer, hunter, { ...guardian, position: { x: 30, y: 40 } }], [enemy], 18, 10.5,
      (unit) => unit.id !== hunter.id);
    expect([...result]).toEqual([[guardian.id, { kind: 'combat', targetId: enemy.id }]]);
  });
});

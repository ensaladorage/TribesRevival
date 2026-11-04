import { describe, expect, it } from 'vitest';
import { assignCombatPositions } from './minionCombatPositions';

const target = { x: 20, y: 20 };
const distance = (a: typeof target, b: typeof target) => Math.hypot(a.x - b.x, a.y - b.y);
const attackers = Array.from({ length: 8 }, (_, index) => ({
  id: `unit-${index}`, position: { x: 15, y: 18 + index }, range: index < 6 ? 1 : 5, ranged: index >= 6,
}));

describe('combat position reservations (pure geometry)', () => {
  it('surrounds the target with separated melee and ranged positions', () => {
    const slots = assignCombatPositions(target, attackers, [], () => true);
    const values = [...slots.values()];
    for (const attacker of attackers) {
      expect(distance(slots.get(attacker.id)!, target)).toBeCloseTo(attacker.ranged ? 4.6 : 0.98);
    }
    for (const [index, point] of values.entries()) {
      expect(values.slice(index + 1).every((other) => distance(point, other) >= 0.96 - 1e-7)).toBe(true);
    }
  });

  it('keeps existing slots when another attacker joins, independent of iteration order', () => {
    const initial = assignCombatPositions(target, attackers.slice(0, 3), [], () => true);
    const existing = attackers.slice(0, 3).map((attacker) => ({ ...attacker, offset: {
      x: initial.get(attacker.id)!.x - target.x, y: initial.get(attacker.id)!.y - target.y,
    } }));
    const next = assignCombatPositions(target, [...existing, attackers[3]], [], () => true);
    for (const attacker of existing) expect(next.get(attacker.id)).toEqual(initial.get(attacker.id));
    expect(next).toEqual(assignCombatPositions(target, [attackers[3], ...existing.reverse()], [], () => true));
  });

  it('avoids occupied slots and bounds, placing excess melee in a waiting ring', () => {
    const melee = attackers.map((attacker) => ({ ...attacker, range: 1, ranged: false }));
    const worker = { x: 20.98, y: 20 };
    const slots = assignCombatPositions(target, melee, [worker], (_attacker, point) => point.x >= 19);
    expect([...slots.values()].every((point) => point.x >= 19 && distance(point, worker) >= 0.96 - 1e-7)).toBe(true);
    expect([...slots.values()].some((point) => distance(point, target) > 2)).toBe(true);
  });
});

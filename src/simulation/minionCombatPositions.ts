import type { Vec2 } from './types';

type Attacker = { id: string; position: Vec2; range: number; ranged: boolean; offset?: Vec2 | null };
const distance = (a: Vec2, b: Vec2) => Math.hypot(a.x - b.x, a.y - b.y);

export function combatPositionRadius(range: number, ranged: boolean): number {
  return range - (ranged ? 0.4 : 0.02);
}

/** Reserve stable, physically free melee/ranged positions, with an outer waiting ring. */
export function assignCombatPositions(
  target: Vec2,
  attackers: readonly Attacker[],
  occupied: readonly Vec2[],
  isAllowed: (attacker: Attacker, point: Vec2) => boolean,
): Map<string, Vec2> {
  const result = new Map<string, Vec2>();
  const used = [...occupied];
  const free = (attacker: Attacker, point: Vec2) => isAllowed(attacker, point)
    && used.every((other) => distance(point, other) >= 0.96 - 1e-7);
  const hasAttackingSlot = (attacker: Attacker) => !!attacker.offset
    && Math.abs(Math.hypot(attacker.offset.x, attacker.offset.y) - combatPositionRadius(attacker.range, attacker.ranged)) <= 0.05;
  const ordered = [...attackers].sort((a, b) => Number(hasAttackingSlot(b)) - Number(hasAttackingSlot(a)) || a.id.localeCompare(b.id));
  // Reserve all still-valid old slots before allocating replacements or newcomers.
  for (const attacker of ordered) {
    if (!hasAttackingSlot(attacker)) continue;
    const point = { x: target.x + attacker.offset!.x, y: target.y + attacker.offset!.y };
    if (free(attacker, point)) {
      result.set(attacker.id, point);
      used.push(point);
    }
  }
  for (const attacker of ordered) {
    if (result.has(attacker.id)) continue;
    const radius = combatPositionRadius(attacker.range, attacker.ranged);
    const candidates: Vec2[] = [];
    if (attacker.offset) {
      const length = Math.hypot(attacker.offset.x, attacker.offset.y);
      if (length >= radius - 0.05 && length <= radius + 0.05) candidates.push({ x: target.x + attacker.offset.x, y: target.y + attacker.offset.y });
    }
    // An actor already in a good attacking position should stand and attack.
    if (Math.abs(distance(attacker.position, target) - radius) <= 0.05) candidates.push(attacker.position);
    const count = attacker.ranged ? 24 : 6;
    const ring = Array.from({ length: count }, (_, index) => ({
      x: target.x + Math.cos(index * Math.PI * 2 / count) * radius,
      y: target.y + Math.sin(index * Math.PI * 2 / count) * radius,
    })).sort((a, b) => distance(attacker.position, a) - distance(attacker.position, b));
    candidates.push(...ring);
    let selected = candidates.find((point) => free(attacker, point));
    if (!selected && !attacker.ranged) {
      const waiting = Array.from({ length: 12 }, (_, index) => ({
        x: target.x + Math.cos(index * Math.PI / 6) * 2.1,
        y: target.y + Math.sin(index * Math.PI / 6) * 2.1,
      })).sort((a, b) => distance(attacker.position, a) - distance(attacker.position, b));
      selected = waiting.find((point) => free(attacker, point));
    }
    const position = selected ? { ...selected } : { ...attacker.position };
    result.set(attacker.id, position);
    used.push(position);
  }
  return result;
}

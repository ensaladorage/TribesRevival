import type { Vec2 } from './types';

export type EntitySighting = { id: string; kind: 'combat' | 'hunt'; position: Vec2; isAlive: boolean };
export type SightingResponder = {
  id: string;
  position: Vec2;
  available: boolean;
  canFight: boolean;
  canHunt: boolean;
  currentKind: string;
  currentTargetId?: string | null;
};
export type EntityCall = { kind: 'combat' | 'hunt'; targetId: string };

const distance = (a: Vec2, b: Vec2) => Math.hypot(a.x - b.x, a.y - b.y);

/** Current sightings only: no unseen targets, stored messages or recursive relays. */
export function chooseEntityCalls(
  units: readonly SightingResponder[],
  entities: readonly EntitySighting[],
  enemyRadius: number,
  animalRadius: number,
  canRespond: (unit: SightingResponder, entity: EntitySighting) => boolean = () => true,
): Map<string, EntityCall> {
  const calls = new Map<string, EntityCall>();
  const seen = entities.filter((entity) => entity.isAlive && units.some((unit) =>
    distance(unit.position, entity.position) <= (entity.kind === 'combat' ? enemyRadius : animalRadius)))
    .sort((a, b) => Number(b.kind === 'combat') - Number(a.kind === 'combat') || a.id.localeCompare(b.id));
  const assigned = new Set<string>();
  // Keep a received assignment while somebody can still see the living target.
  for (const unit of [...units].sort((a, b) => a.id.localeCompare(b.id))) {
    const current = seen.find((entity) => entity.id === unit.currentTargetId && entity.kind === unit.currentKind);
    if (!current || !(current.kind === 'combat' ? unit.canFight : unit.canHunt)) continue;
    calls.set(unit.id, { kind: current.kind, targetId: current.id });
    assigned.add(`${current.kind}:${current.id}`);
  }
  for (const entity of seen) {
    const key = `${entity.kind}:${entity.id}`;
    if (assigned.has(key)) continue;
    const responder = units.filter((unit) => unit.available && !calls.has(unit.id)
      && (entity.kind === 'combat' ? unit.canFight : unit.canHunt) && canRespond(unit, entity))
      .sort((a, b) => distance(a.position, entity.position) - distance(b.position, entity.position) || a.id.localeCompare(b.id))[0];
    if (!responder) continue;
    calls.set(responder.id, { kind: entity.kind, targetId: entity.id });
    assigned.add(key);
  }
  return calls;
}

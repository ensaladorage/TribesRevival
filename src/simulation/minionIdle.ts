import { createSeededRandom } from './seededRandom';
import type { Vec2 } from './types';
import { WORLD_VIEW_FRONT } from './worldView';

export const MINION_IDLE_CONFIG = {
  innerRadius: 4,
  outerRadius: 8,
  speed: 3,
  waitMinimumSeconds: 1,
  waitMaximumSeconds: 3,
  maximumAngleChange: Math.PI / 3,
  crowdRadius: 1.5,
  crowdWeight: 2,
} as const;

export type MinionIdleState = {
  destination: Vec2 | null;
  waitRemainingSeconds: number;
  step: number;
};

export type IdleArea = {
  center: Vec2;
  commandRadius: number;
  minimumCoordinate: number;
  maximumCoordinate: number;
};

export type IdleNeighbor = { position: Vec2; destination?: Vec2 | null };

export function idleDestinationScore(point: Vec2, center: Vec2, neighbors: readonly IdleNeighbor[]): number {
  const dx = point.x - center.x;
  const dy = point.y - center.y;
  const distance = Math.hypot(dx, dy) || 1;
  const behind = Math.max(0, -(dx * WORLD_VIEW_FRONT.x + dy * WORLD_VIEW_FRONT.y) / distance);
  const crowd = neighbors.reduce((sum, other) => {
    const proximity = (position: Vec2): number => Math.max(0, 1 - Math.hypot(point.x - position.x, point.y - position.y) / MINION_IDLE_CONFIG.crowdRadius);
    return sum + Math.max(proximity(other.position), other.destination ? proximity(other.destination) : 0);
  }, 0);
  return behind + MINION_IDLE_CONFIG.crowdWeight * crowd;
}

export function createMinionIdleState(): MinionIdleState {
  return { destination: null, waitRemainingSeconds: 0, step: 0 };
}

export function getIdleRadius(commandRadius: number): number {
  return Math.max(0, Math.min(MINION_IDLE_CONFIG.outerRadius, commandRadius));
}

export function idleWaitSeconds(seed: string, id: string, step: number): number {
  return createSeededRandom(`${seed}:${id}:idle-wait:${step}`).nextFloat(
    MINION_IDLE_CONFIG.waitMinimumSeconds, MINION_IDLE_CONFIG.waitMaximumSeconds,
  );
}

function pointAt(area: IdleArea, angle: number, radius: number): Vec2 {
  return { x: area.center.x + Math.cos(angle) * radius, y: area.center.y + Math.sin(angle) * radius };
}

function insideWorld(point: Vec2, area: IdleArea): boolean {
  return point.x >= area.minimumCoordinate && point.x <= area.maximumCoordinate
    && point.y >= area.minimumCoordinate && point.y <= area.maximumCoordinate;
}

export function isWithinTotemRange(position: Vec2, area: Pick<IdleArea, 'center' | 'commandRadius'>): boolean {
  return Math.hypot(position.x - area.center.x, position.y - area.center.y) <= Math.max(0, area.commandRadius) + 1e-8;
}

/** Nearest entry into command range, never an assigned formation slot. */
export function totemRangeEntry(position: Vec2, area: IdleArea): Vec2 {
  const dx = position.x - area.center.x;
  const dy = position.y - area.center.y;
  const distance = Math.hypot(dx, dy);
  const scale = distance > 0 ? Math.min(1, Math.max(0, area.commandRadius) / distance) : 0;
  return {
    x: Math.max(area.minimumCoordinate, Math.min(area.maximumCoordinate, area.center.x + dx * scale)),
    y: Math.max(area.minimumCoordinate, Math.min(area.maximumCoordinate, area.center.y + dy * scale)),
  };
}

export function chooseIdleDestination(
  seed: string, id: string, step: number, position: Vec2, area: IdleArea, neighbors: readonly IdleNeighbor[] = [],
): Vec2 {
  const random = createSeededRandom(`${seed}:${id}:idle-destination:${step}`);
  const outer = getIdleRadius(area.commandRadius);
  const inner = Math.min(MINION_IDLE_CONFIG.innerRadius, outer);
  const dx = position.x - area.center.x;
  const dy = position.y - area.center.y;
  const distance = Math.hypot(dx, dy);
  const angle = distance > 1e-8 ? Math.atan2(dy, dx) : random.nextFloat(0, Math.PI * 2);
  let best: Vec2 | undefined;
  let bestScore = Infinity;
  for (let attempt = 0; attempt < 24; attempt += 1) {
    const radius = random.nextFloat(inner, outer);
    // Keep the straight segment outside the inner ring, not just its endpoint.
    const safeAngle = distance < inner || outer === 0 ? 0 : Math.min(
      MINION_IDLE_CONFIG.maximumAngleChange,
      Math.acos(Math.min(inner / Math.max(distance, 1e-8), 1))
        + Math.acos(Math.min(inner / Math.max(radius, 1e-8), 1)),
    ) * 0.95;
    const candidate = pointAt(area, angle + random.nextFloat(-safeAngle, safeAngle), radius);
    if (insideWorld(candidate, area) && Math.hypot(candidate.x - position.x, candidate.y - position.y) > 0.25) {
      const score = idleDestinationScore(candidate, area.center, neighbors);
      if (score < bestScore - 1e-8) { bestScore = score; best = candidate; }
    }
  }
  if (best) return best;
  // Near a border, staying put is preferable to leaving the map or spinning.
  if (insideWorld(position, area) && distance >= inner && distance <= outer) return { ...position };
  return totemRangeEntry(position, area);
}

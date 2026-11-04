import type { Vec2 } from './types';

export const MINION_NAVIGATION_CONFIG = {
  minimumSeparation: 0.94,
  predictionSeconds: 0.6,
  angles: [0, 25, -25, 50, -50, 75, -75],
} as const;

/** Serializable continuity only; reservations are still rebuilt every tick. */
export type MinionNavigationState = {
  goal: Vec2;
  waypoints: Vec2[];
  velocity: Vec2;
  side: number;
  sideHoldSeconds: number;
  blockedSeconds: number;
  replanSeconds: number;
  combatTargetId: string | null;
  combatOffset: Vec2 | null;
};

export function createMinionNavigationState(goal: Vec2): MinionNavigationState {
  return { goal: { ...goal }, waypoints: [], velocity: { x: 0, y: 0 }, side: 0, sideHoldSeconds: 0,
    blockedSeconds: 0, replanSeconds: 0, combatTargetId: null, combatOffset: null };
}

export type NavigationObstacle = { id: string; position: Vec2 };

export function segmentIsClear(start: Vec2, end: Vec2, obstacles: readonly NavigationObstacle[], clearance = 0.96): boolean {
  const length = Math.hypot(end.x - start.x, end.y - start.y);
  const velocity = velocityTowards(start, end, length);
  return obstacles.every((obstacle) => closestApproach(
    { position: start, velocity, stopAfterSeconds: 1 },
    { position: obstacle.position, velocity: { x: 0, y: 0 }, stopAfterSeconds: 0 }, 1,
  ) >= Math.min(clearance, Math.hypot(start.x - obstacle.position.x, start.y - obstacle.position.y)) - 1e-7);
}

/** Small visibility graph around actors; a committed route avoids frame-by-frame side changes. */
export function planMinionRoute(start: Vec2, goal: Vec2, obstacles: readonly NavigationObstacle[], isAllowed: (point: Vec2) => boolean): Vec2[] {
  const ordered = [...obstacles].sort((a, b) => a.id.localeCompare(b.id));
  const edgeAllowed = (a: Vec2, b: Vec2) => {
    if (!segmentIsClear(a, b, ordered)) return false;
    const samples = Math.max(1, Math.ceil(Math.hypot(a.x - b.x, a.y - b.y) / 0.4));
    for (let step = 1; step <= samples; step += 1) {
      if (!isAllowed({ x: a.x + (b.x - a.x) * step / samples, y: a.y + (b.y - a.y) * step / samples })) return false;
    }
    return true;
  };
  if (edgeAllowed(start, goal)) return [{ ...goal }];
  const points = [start, goal];
  for (const obstacle of ordered) {
    for (let index = 0; index < 12; index += 1) {
      const angle = index * Math.PI / 6;
      const point = { x: obstacle.position.x + Math.cos(angle) * 1.2, y: obstacle.position.y + Math.sin(angle) * 1.2 };
      if (isAllowed(point) && ordered.every((other) => Math.hypot(point.x - other.position.x, point.y - other.position.y) >= 1.02)) points.push(point);
    }
  }
  const costs = points.map(() => Infinity);
  const previous = points.map(() => -1);
  const visited = new Set<number>();
  costs[0] = 0;
  while (visited.size < points.length) {
    let current = -1;
    for (let index = 0; index < points.length; index += 1) {
      if (!visited.has(index) && (current < 0 || costs[index] < costs[current] - 1e-7)) current = index;
    }
    if (current < 0 || !Number.isFinite(costs[current])) break;
    if (current === 1) {
      const path: Vec2[] = [];
      for (let index = 1; index !== 0; index = previous[index]) path.unshift({ ...points[index] });
      return path;
    }
    visited.add(current);
    for (let index = 1; index < points.length; index += 1) {
      if (visited.has(index)) continue;
      const cost = costs[current] + Math.hypot(points[index].x - points[current].x, points[index].y - points[current].y);
      if (cost < costs[index] - 1e-7 && edgeAllowed(points[current], points[index])) {
        costs[index] = cost;
        previous[index] = current;
      }
    }
  }
  return [];
}

export type NavigationAgent = {
  id: string;
  position: Vec2;
  velocity: Vec2;
  stopAfterSeconds: number;
  priority: number;
  fixed: boolean;
  /** Resolved displacement this tick, or zero for an unprocessed neighbor. */
  tickVelocity: Vec2;
};

export function velocityTowards(position: Vec2, target: Vec2, speed: number): Vec2 {
  const dx = target.x - position.x;
  const dy = target.y - position.y;
  const distance = Math.hypot(dx, dy);
  return distance > 1e-8 ? { x: dx / distance * speed, y: dy / distance * speed } : { x: 0, y: 0 };
}

function at(position: Vec2, velocity: Vec2, time: number): Vec2 {
  return { x: position.x + velocity.x * time, y: position.y + velocity.y * time };
}

/** Continuous closest distance, including actors stopping before the horizon. */
export function closestApproach(
  first: Pick<NavigationAgent, 'position' | 'velocity' | 'stopAfterSeconds'>,
  second: Pick<NavigationAgent, 'position' | 'velocity' | 'stopAfterSeconds'>,
  horizon: number,
): number {
  const cuts = [0, Math.min(first.stopAfterSeconds, horizon), Math.min(second.stopAfterSeconds, horizon), horizon]
    .sort((a, b) => a - b);
  let minimum = Math.hypot(first.position.x - second.position.x, first.position.y - second.position.y);
  for (let index = 1; index < cuts.length; index += 1) {
    const start = cuts[index - 1];
    const length = cuts[index] - start;
    const a = at(first.position, first.velocity, Math.min(start, first.stopAfterSeconds));
    const b = at(second.position, second.velocity, Math.min(start, second.stopAfterSeconds));
    const vx = (start < first.stopAfterSeconds ? first.velocity.x : 0) - (start < second.stopAfterSeconds ? second.velocity.x : 0);
    const vy = (start < first.stopAfterSeconds ? first.velocity.y : 0) - (start < second.stopAfterSeconds ? second.velocity.y : 0);
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const time = Math.max(0, Math.min(length, -(dx * vx + dy * vy) / (vx * vx + vy * vy || 1)));
    minimum = Math.min(minimum, Math.hypot(dx + vx * time, dy + vy * time));
  }
  return minimum;
}

export function givesWayTo(agent: NavigationAgent, other: NavigationAgent): boolean {
  return other.fixed || other.priority > agent.priority
    || (other.priority === agent.priority && other.id.localeCompare(agent.id) < 0);
}

function separationIsSafe(agent: NavigationAgent, other: NavigationAgent, horizon: number): boolean {
  const initial = Math.hypot(agent.position.x - other.position.x, agent.position.y - other.position.y);
  const required = Math.min(MINION_NAVIGATION_CONFIG.minimumSeparation, initial);
  if (closestApproach(agent, other, horizon) < required - 1e-7) return false;
  // Let initially overlapping actors escape, but never move deeper into overlap.
  if (initial < MINION_NAVIGATION_CONFIG.minimumSeparation - 1e-7) {
    const end = at(agent.position, agent.velocity, Math.min(horizon, agent.stopAfterSeconds));
    const otherEnd = at(other.position, other.velocity, Math.min(horizon, other.stopAfterSeconds));
    return Math.hypot(end.x - otherEnd.x, end.y - otherEnd.y) > initial + 1e-7;
  }
  return true;
}

export function chooseNavigationStep(input: {
  agent: NavigationAgent;
  destination: Vec2;
  speed: number;
  deltaSeconds: number;
  neighbors: readonly NavigationAgent[];
  isAllowed: (position: Vec2) => boolean;
  previousVelocity?: Vec2;
  preferredSide?: number;
}): { position: Vec2; velocity: Vec2; blocked: boolean } {
  const { agent, destination, speed, deltaSeconds, isAllowed } = input;
  const neighbors = [...input.neighbors].sort((a, b) => a.id.localeCompare(b.id));
  const distance = Math.hypot(destination.x - agent.position.x, destination.y - agent.position.y);
  const forward = velocityTowards(agent.position, destination, 1);
  for (const fraction of [1, 0.5]) {
    let best: { position: Vec2; velocity: Vec2; score: number } | undefined;
    for (const degrees of MINION_NAVIGATION_CONFIG.angles) {
      if (input.preferredSide && degrees && Math.sign(degrees) !== input.preferredSide) continue;
      // A fixed right-hand preference avoids alternating sides in symmetric encounters.
      const angle = degrees * Math.PI / 180;
      const velocity = {
        x: (forward.x * Math.cos(angle) - forward.y * Math.sin(angle)) * speed * fraction,
        y: (forward.x * Math.sin(angle) + forward.y * Math.cos(angle)) * speed * fraction,
      };
      const stopAfterSeconds = distance / Math.max(speed * fraction, 1e-8);
      const candidate = { ...agent, velocity, stopAfterSeconds };
      const position = at(agent.position, velocity, Math.min(deltaSeconds, stopAfterSeconds));
      if (!isAllowed(position)) continue;
      const tickCandidate = { ...candidate, stopAfterSeconds: deltaSeconds,
        velocity: { x: (position.x - agent.position.x) / deltaSeconds, y: (position.y - agent.position.y) / deltaSeconds } };
      const safe = neighbors.every((other) => {
        // Actual tick paths are always protected, regardless of right of way.
        const tickOther = { ...other, velocity: other.tickVelocity, stopAfterSeconds: deltaSeconds };
        if (!separationIsSafe(tickCandidate, tickOther, deltaSeconds)) return false;
        if (!givesWayTo(agent, other) && !other.fixed && Math.hypot(other.velocity.x, other.velocity.y) > 1e-8) return true;
        return separationIsSafe(candidate, other, MINION_NAVIGATION_CONFIG.predictionSeconds);
      });
      if (!safe) continue;
      const previousSpeed = input.previousVelocity ? Math.hypot(input.previousVelocity.x, input.previousVelocity.y) : 0;
      const continuity = previousSpeed > 1e-8
        ? (velocity.x * input.previousVelocity!.x + velocity.y * input.previousVelocity!.y) / (speed * fraction * previousSpeed) : 1;
      const score = distance - Math.hypot(destination.x - position.x, destination.y - position.y) - 0.12 * (1 - continuity);
      if (!best || score > best.score + 1e-7) best = { position, velocity, score };
    }
    if (best) return { position: best.position, velocity: best.velocity, blocked: false };
  }
  return { position: { ...agent.position }, velocity: { x: 0, y: 0 }, blocked: true };
}

/** Idle units yield even during a pause when an approaching worker needs space. */
export function idleYieldTarget(agent: NavigationAgent, neighbors: readonly NavigationAgent[]): Vec2 | null {
  for (const other of [...neighbors].sort((a, b) => a.id.localeCompare(b.id))) {
    if (other.fixed || !givesWayTo(agent, other) || Math.hypot(other.velocity.x, other.velocity.y) < 1e-8) continue;
    if (closestApproach({ ...agent, velocity: { x: 0, y: 0 }, stopAfterSeconds: 0 }, other, 0.6) >= 1.15) continue;
    const speed = Math.hypot(other.velocity.x, other.velocity.y);
    const side = { x: -other.velocity.y / speed, y: other.velocity.x / speed };
    const dot = (agent.position.x - other.position.x) * side.x + (agent.position.y - other.position.y) * side.y;
    const sign = dot < 0 ? -1 : 1;
    return { x: agent.position.x + side.x * sign * 1.2, y: agent.position.y + side.y * sign * 1.2 };
  }
  return null;
}

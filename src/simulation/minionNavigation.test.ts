import { describe, expect, it } from 'vitest';
import { chooseNavigationStep, closestApproach, givesWayTo, idleYieldTarget, planMinionRoute, segmentIsClear, type NavigationAgent } from './minionNavigation';

function agent(id: string, x: number, y: number, vx = 0, vy = 0): NavigationAgent {
  return { id, position: { x, y }, velocity: { x: vx, y: vy }, stopAfterSeconds: 10,
    priority: 2, fixed: false, tickVelocity: { x: 0, y: 0 } };
}

function resolve(self: NavigationAgent, neighbors: NavigationAgent[], speed = 3, allowed = (_point: { x: number; y: number }) => true) {
  return chooseNavigationStep({ agent: self, destination: { x: self.position.x + 5, y: self.position.y },
    speed, deltaSeconds: 0.05, neighbors, isAllowed: allowed });
}

describe('local minion navigation (pure geometry)', () => {
  it('plans a deterministic route around working actors, protecting every segment', () => {
    const start = { x: 0, y: 0 };
    const goal = { x: 6, y: 0 };
    const workers = [{ id: 'a', position: { x: 2, y: 0 } }, { id: 'b', position: { x: 4, y: 0.3 } }];
    const route = planMinionRoute(start, goal, workers, () => true);
    expect(route.length).toBeGreaterThan(1);
    expect(route.at(-1)).toEqual(goal);
    expect(route).toEqual(planMinionRoute(start, goal, [...workers].reverse(), () => true));
    for (const [index, point] of route.entries()) {
      expect(segmentIsClear(index ? route[index - 1] : start, point, workers)).toBe(true);
    }
  });

  it('routes on the available side of a worker and waits when the goal is occupied', () => {
    const worker = [{ id: 'a', position: { x: 2, y: 0 } }];
    const route = planMinionRoute({ x: 0, y: 0 }, { x: 4, y: 0 }, worker, (point) => point.y <= 0);
    expect(route.length).toBeGreaterThan(1);
    expect(route.every((point) => point.y <= 0)).toBe(true);
    expect(planMinionRoute({ x: 0, y: 0 }, worker[0].position, worker, () => true)).toEqual([]);
  });

  it('keeps the chosen avoidance side instead of reversing on small crossing changes', () => {
    const self = agent('walker', 0, 0);
    for (const y of [-0.02, 0.02]) {
      const result = chooseNavigationStep({ agent: self, destination: { x: 5, y: 0 }, speed: 3,
        deltaSeconds: 0.05, neighbors: [{ ...agent('worker', 1.5, y), fixed: true }],
        preferredSide: 1, previousVelocity: { x: 2, y: 2 }, isAllowed: () => true });
      expect(result.blocked).toBe(false);
      expect(result.velocity.y).toBeGreaterThan(0);
    }
  });
  it('detects head-on, perpendicular and overtaking conflicts continuously', () => {
    expect(closestApproach(agent('a', -1, 0, 3, 0), agent('b', 1, 0, -3, 0), 0.6)).toBeCloseTo(0);
    expect(closestApproach(agent('a', -1, 0, 3, 0), agent('b', 0, -1, 0, 3), 0.6)).toBeCloseTo(0);
    expect(closestApproach(agent('a', 0, 0, 3, 0), agent('b', 2, 0, 1, 0), 0.6)).toBeCloseTo(0.8);
  });

  it.each([
    [agent('z', -1.2, 0), agent('a', 1.2, 0, -3, 0)],
    [agent('z', -1, 0), agent('a', 0, -1, 0, 3)],
    [agent('z', 0, 0), agent('a', 2, 0, 1, 0)],
  ])('steers safely around an approaching ally', (self, other) => {
    const result = resolve(self, [other]);
    expect(result.blocked).toBe(false);
    expect(Math.abs(result.position.y - self.position.y)).toBeGreaterThan(0);
    expect(closestApproach({ ...self, velocity: result.velocity }, other, 0.6)).toBeGreaterThanOrEqual(0.94 - 1e-7);
  });

  it('routes around a stationary worker without changing the worker', () => {
    const worker = { ...agent('worker', 1.5, 0), priority: 3, fixed: true };
    const before = structuredClone(worker);
    const result = resolve(agent('walker', 0, 0), [worker]);
    expect(result.blocked).toBe(false);
    expect(Math.abs(result.position.y)).toBeGreaterThan(0);
    expect(worker).toEqual(before);
  });

  it('halves speed in a constrained passage, and waits if no step is safe', () => {
    const passage = (point: { x: number; y: number }) => Math.abs(point.y) < 0.001;
    const result = resolve(agent('walker', 0, 0), [{ ...agent('worker', 2, 0), fixed: true }], 3, passage);
    expect(result.velocity.x).toBe(1.5);
    const blocked = resolve(agent('walker', 0, 0), [{ ...agent('worker', 1, 0), fixed: true }], 3, passage);
    expect(blocked.blocked).toBe(true);
    expect(blocked.position).toEqual({ x: 0, y: 0 });
  });

  it('protects a reserved crossing even when both endpoints would be clear', () => {
    const self = agent('a', -1, 0);
    const other = { ...agent('z', 0, -1), tickVelocity: { x: 0, y: 40 } };
    const result = chooseNavigationStep({ agent: self, destination: { x: 1, y: 0 }, speed: 40,
      deltaSeconds: 0.05, neighbors: [other], isAllowed: () => true });
    expect(result.position).not.toEqual({ x: 1, y: 0 });
    expect(closestApproach({ ...self, velocity: result.velocity }, { ...other, velocity: other.tickVelocity }, 0.05))
      .toBeGreaterThanOrEqual(0.94 - 1e-7);
  });

  it('uses stable priorities and gives a waiting idle unit a yielding target', () => {
    const idle = { ...agent('a', 0, 0), priority: 1 };
    const worker = agent('z', -2, 0, 3, 0);
    expect(givesWayTo(idle, worker)).toBe(true);
    expect(givesWayTo(worker, idle)).toBe(false);
    expect(givesWayTo(agent('z', 0, 0), agent('a', 2, 0))).toBe(true);
    expect(idleYieldTarget(idle, [worker])).not.toBeNull();
    const neighbors = [agent('a', 1.2, 0, -3, 0), agent('b', 5, 5)];
    expect(resolve(idle, neighbors)).toEqual(resolve(idle, [...neighbors].reverse()));
  });

  it('respects bounds and does not claim arrival when steering away from the goal', () => {
    const result = resolve(agent('walker', 0, 0), [], 3, (point) => point.x <= 0);
    expect(result.blocked).toBe(true);
    expect(result.position.x).toBe(0);
  });

  it('does not extrapolate an actor past its destination', () => {
    const moving = { ...agent('a', 0, 0, 8, 0), stopAfterSeconds: 0.1 };
    expect(closestApproach(moving, { ...agent('b', 2, 0), stopAfterSeconds: 0 }, 0.6)).toBeCloseTo(1.2);
  });
});

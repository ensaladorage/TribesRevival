import { describe, expect, it } from 'vitest';
import {
  chooseIdleDestination, idleWaitSeconds, idleDestinationScore, isWithinTotemRange, totemRangeEntry, type IdleArea,
} from './minionIdle';

const area: IdleArea = {
  center: { x: 80, y: 80 }, commandRadius: 10, minimumCoordinate: 2, maximumCoordinate: 158,
};

describe('minion idle decisions (pure functions)', () => {
  it('prefers the front, but values free space over crowding', () => {
    const front = { x: 84, y: 84 };
    const behind = { x: 76, y: 76 };
    expect(idleDestinationScore(front, area.center, [])).toBeLessThan(idleDestinationScore(behind, area.center, []));
    expect(idleDestinationScore(front, area.center, [{ position: front }]))
      .toBeGreaterThan(idleDestinationScore(behind, area.center, []));
    expect(idleDestinationScore(front, area.center, [{ position: { x: 90, y: 90 }, destination: front }])).toBe(2);
  });

  it('changes an idle destination when another unit has reserved the same spot', () => {
    const position = { x: 85, y: 80 };
    const target = chooseIdleDestination('seed', 'unit', 0, position, area);
    expect(chooseIdleDestination('seed', 'unit', 0, position, area, [{ position: target, destination: target }])).not.toEqual(target);
  });

  it('allows rear destinations rather than forcing units through the totem', () => {
    const target = chooseIdleDestination('seed', 'unit', 0, { x: 75, y: 75 }, area);
    expect(target.x + target.y).toBeLessThan(160);
  });

  it('keeps resting positions throughout command range, including beyond the preferred idle ring', () => {
    for (const position of [{ x: 89, y: 80 }, { x: 80, y: 90 }, { x: 75, y: 75 }]) {
      expect(isWithinTotemRange(position, area)).toBe(true);
      expect(totemRangeEntry(position, area)).toEqual(position);
    }
    expect(isWithinTotemRange({ x: 90.01, y: 80 }, area)).toBe(false);
    expect(isWithinTotemRange({ x: 89, y: 80 }, { ...area, commandRadius: 8 })).toBe(false);
  });

  it('returns only to the nearest edge of command range, without assigning a central slot', () => {
    expect(totemRangeEntry({ x: 95, y: 80 }, area)).toEqual({ x: 90, y: 80 });
    expect(totemRangeEntry({ x: 80, y: 65 }, area)).toEqual({ x: 80, y: 70 });
    const diagonal = totemRangeEntry({ x: 95, y: 95 }, area);
    expect(Math.hypot(diagonal.x - 80, diagonal.y - 80)).toBeCloseTo(10);
    expect(diagonal.x - 80).toBeCloseTo(diagonal.y - 80);
  });
  it('repeats the same decision and staggers different units', () => {
    const position = { x: 83.25, y: 80 };
    const target = chooseIdleDestination('seed', 'unit-1', 3, position, area);
    expect(chooseIdleDestination('seed', 'unit-1', 3, position, area)).toEqual(target);
    expect(chooseIdleDestination('seed', 'unit-2', 3, position, area)).not.toEqual(target);
    expect(idleWaitSeconds('seed', 'unit-1', 3)).toBe(idleWaitSeconds('seed', 'unit-1', 3));
    expect(idleWaitSeconds('seed', 'unit-1', 3)).not.toBe(idleWaitSeconds('seed', 'unit-2', 3));
  });

  it('chooses short segments outside the inner ring and pauses within 1–3 seconds', () => {
    let position = { x: 85, y: 80 };
    for (let step = 0; step < 40; step += 1) {
      const destination = chooseIdleDestination('seed', 'unit', step, position, area);
      const distance = Math.hypot(destination.x - 80, destination.y - 80);
      expect(distance).toBeGreaterThanOrEqual(4 - 1e-9);
      expect(distance).toBeLessThanOrEqual(8 + 1e-9);
      const angle = Math.atan2(position.y - 80, position.x - 80);
      const targetAngle = Math.atan2(destination.y - 80, destination.x - 80);
      const difference = Math.atan2(Math.sin(targetAngle - angle), Math.cos(targetAngle - angle));
      expect(Math.abs(difference)).toBeLessThanOrEqual(Math.PI / 3 + 1e-9);
      const dx = destination.x - position.x;
      const dy = destination.y - position.y;
      const t = Math.max(0, Math.min(1, ((80 - position.x) * dx + (80 - position.y) * dy) / (dx * dx + dy * dy || 1)));
      expect(Math.hypot(position.x + dx * t - 80, position.y + dy * t - 80)).toBeGreaterThanOrEqual(4 - 1e-9);
      expect(idleWaitSeconds('seed', 'unit', step)).toBeGreaterThanOrEqual(1);
      expect(idleWaitSeconds('seed', 'unit', step)).toBeLessThanOrEqual(3);
      position = destination;
    }
  });

  it.each([{ x: 2, y: 2 }, { x: 158, y: 2 }, { x: 2, y: 158 }, { x: 158, y: 158 }])(
    'keeps range entries and idle destinations inside the map at $x,$y', (center) => {
      const corner = { ...area, center };
      for (let index = 0; index < 8; index += 1) {
        const entry = totemRangeEntry({ x: center.x + (center.x === 2 ? 15 : -15), y: center.y + (center.y === 2 ? 15 : -15) }, corner);
        expect(isWithinTotemRange(entry, corner)).toBe(true);
        expect(Math.hypot(entry.x - center.x, entry.y - center.y)).toBeCloseTo(10);
        const target = chooseIdleDestination('seed', `unit-${index}`, 0, entry, corner);
        expect(target.x).toBeGreaterThanOrEqual(2);
        expect(target.x).toBeLessThanOrEqual(158);
        expect(target.y).toBeGreaterThanOrEqual(2);
        expect(target.y).toBeLessThanOrEqual(158);
        expect(Math.hypot(target.x - center.x, target.y - center.y)).toBeLessThanOrEqual(8 + 1e-9);
      }
    },
  );

  it('limits destinations to the command radius if it is smaller than the idle zone', () => {
    const small = { ...area, commandRadius: 3 };
    const position = totemRangeEntry({ x: 95, y: 80 }, small);
    const target = chooseIdleDestination('seed', 'unit', 0, position, small);
    expect(Math.hypot(target.x - 80, target.y - 80)).toBeLessThanOrEqual(3 + 1e-9);
  });
});

import { describe, expect, it } from 'vitest';
import { canUnlockTechnology } from './technologyConfig';
import {
  PROGRESSION_BALANCE,
  awardExperience,
  createInitialProgressionState,
  unlockTechnology,
} from './progression';

describe('progression', () => {
  it.each(['artisan', 'mage'] as const)('requires level two for %s even with enough points', (technology) => {
    const progression = createInitialProgressionState();
    progression.level = 1;
    progression.technologyPoints = 3;
    const before = structuredClone(progression);
    expect(canUnlockTechnology(progression, technology)).toBe(false);
    expect(unlockTechnology(progression, technology)).toBe(false);
    expect(progression).toEqual(before);
    progression.level = 2;
    expect(canUnlockTechnology(progression, technology)).toBe(true);
    expect(unlockTechnology(progression, technology)).toBe(true);
    expect(progression.technologyPoints).toBe(2);
  });

  it('allows shield at level one when a point is available', () => {
    const progression = createInitialProgressionState();
    progression.technologyPoints = 1;
    expect(unlockTechnology(progression, 'shield')).toBe(false);
    expect(progression.technologyPoints).toBe(1);
    progression.level = 1;
    expect(unlockTechnology(progression, 'shield')).toBe(true);
    expect(progression.technologyPoints).toBe(0);
  });

  it.each(['artisan', 'mage', 'shield'] as const)('rejects insufficient points and duplicate %s purchases without mutation', (technology) => {
    const progression = createInitialProgressionState();
    progression.level = 2;
    const before = structuredClone(progression);
    expect(unlockTechnology(progression, technology)).toBe(false);
    expect(progression).toEqual(before);
    progression.technologyPoints = 2;
    expect(unlockTechnology(progression, technology)).toBe(true);
    expect(progression.technologyPoints).toBe(1);
    const purchased = structuredClone(progression);
    expect(unlockTechnology(progression, technology)).toBe(false);
    expect(progression).toEqual(purchased);
  });

  it('starts at the configured level and first XP threshold', () => {
    expect(createInitialProgressionState()).toEqual({
      level: 0,
      experience: 0,
      experienceToNextLevel: 12,
      technologyPoints: 0,
      unlockedTechnologies: [],
    });
    expect(PROGRESSION_BALANCE.experiencePerGatherAction).toBe(1);
    expect(PROGRESSION_BALANCE.experiencePerRabbitDefeated).toBe(3);
    expect(PROGRESSION_BALANCE.experiencePerBarbarianDefeated).toBe(5);
  });

  it('grants a point per level and raises each next threshold by twelve XP', () => {
    const progression = createInitialProgressionState();

    expect(awardExperience(progression, 12)).toBe(1);
    expect(progression).toMatchObject({
      level: 1,
      experience: 0,
      experienceToNextLevel: 24,
      technologyPoints: 1,
    });

    expect(awardExperience(progression, 25)).toBe(1);
    expect(progression).toMatchObject({
      level: 2,
      experience: 1,
      experienceToNextLevel: 36,
      technologyPoints: 2,
    });
  });

  it('spends one point to unlock a technology only once', () => {
    const progression = createInitialProgressionState();
    awardExperience(progression, 12);

    expect(unlockTechnology(progression, 'shield')).toBe(true);
    expect(unlockTechnology(progression, 'shield')).toBe(false);
    expect(unlockTechnology(progression, 'artisan')).toBe(false);
    expect(progression.technologyPoints).toBe(0);
    expect(progression.unlockedTechnologies).toEqual(['shield']);
  });
});

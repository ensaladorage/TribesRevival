import { describe, expect, it } from 'vitest';
import {
  PROGRESSION_BALANCE,
  awardExperience,
  createInitialProgressionState,
  unlockTechnology,
} from './progression';

describe('progression', () => {
  it('starts at the configured level and first XP threshold', () => {
    expect(createInitialProgressionState()).toEqual({
      level: 1,
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
      level: 2,
      experience: 0,
      experienceToNextLevel: 24,
      technologyPoints: 1,
    });

    expect(awardExperience(progression, 25)).toBe(1);
    expect(progression).toMatchObject({
      level: 3,
      experience: 1,
      experienceToNextLevel: 36,
      technologyPoints: 2,
    });
  });

  it('spends one point to unlock a technology only once', () => {
    const progression = createInitialProgressionState();
    awardExperience(progression, 12);

    expect(unlockTechnology(progression, 'artisan')).toBe(true);
    expect(unlockTechnology(progression, 'artisan')).toBe(false);
    expect(unlockTechnology(progression, 'shield')).toBe(false);
    expect(progression.technologyPoints).toBe(0);
    expect(progression.unlockedTechnologies).toEqual(['artisan']);
  });
});

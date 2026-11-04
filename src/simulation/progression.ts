import type { ProgressionState } from './types';
import type { TechnologyId } from './survivalTypes';
import { canUnlockTechnology, getTechnology } from './technologyConfig';

export const PROGRESSION_BALANCE = {
  initialLevel: 0,
  initialExperience: 0,
  initialTechnologyPoints: 0,
  experiencePerGatherAction: 1,
  experiencePerRabbitDefeated: 3,
  experiencePerBarbarianDefeated: 5,
  initialExperienceToNextLevel: 12,
  experienceRequirementIncreasePerLevel: 12,
  shieldMaximumHealthBonus: 1,
} as const;

export function createInitialProgressionState(): ProgressionState {
  return {
    level: PROGRESSION_BALANCE.initialLevel,
    experience: PROGRESSION_BALANCE.initialExperience,
    experienceToNextLevel: PROGRESSION_BALANCE.initialExperienceToNextLevel,
    technologyPoints: PROGRESSION_BALANCE.initialTechnologyPoints,
    unlockedTechnologies: [],
  };
}

export function awardExperience(progression: ProgressionState, amount: number): number {
  const gained = Number.isFinite(amount) ? Math.max(Math.floor(amount), 0) : 0;
  if (gained === 0) return 0;

  progression.experience += gained;
  let levelsGained = 0;
  while (progression.experience >= progression.experienceToNextLevel) {
    progression.experience -= progression.experienceToNextLevel;
    progression.level += 1;
    progression.technologyPoints += 1;
    progression.experienceToNextLevel += PROGRESSION_BALANCE.experienceRequirementIncreasePerLevel;
    levelsGained += 1;
  }
  return levelsGained;
}

export function unlockTechnology(
  progression: ProgressionState,
  technology: TechnologyId,
): boolean {
  const definition = getTechnology(technology);
  if (!definition || !canUnlockTechnology(progression, technology)) return false;

  progression.technologyPoints -= definition.cost;
  progression.unlockedTechnologies.push(technology);
  return true;
}

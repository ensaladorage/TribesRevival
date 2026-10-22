import type { ProgressionState } from './types';
import type { TechnologyId } from './survivalTypes';

export const PROGRESSION_BALANCE = {
  initialLevel: 1,
  initialExperience: 0,
  initialTechnologyPoints: 0,
  experiencePerGatherAction: 1,
  experiencePerRabbitDefeated: 3,
  experiencePerBarbarianDefeated: 5,
  initialExperienceToNextLevel: 12,
  experienceRequirementIncreasePerLevel: 12,
  technologyPointCost: 1,
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
  if (
    progression.technologyPoints < PROGRESSION_BALANCE.technologyPointCost
    || progression.unlockedTechnologies.includes(technology)
  ) return false;

  progression.technologyPoints -= PROGRESSION_BALANCE.technologyPointCost;
  progression.unlockedTechnologies.push(technology);
  return true;
}

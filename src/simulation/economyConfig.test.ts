import { describe, expect, it } from 'vitest';
import {
  MAX_PLAYABLE_MINIONS,
  TOOL_UPGRADES,
  canAffordCost,
  getGathererRecruitmentCost,
  getMissingResources,
  getShieldCost,
  getSpecializationCost,
  getSpecializationLimit,
  isResourceNodeToolRequirementMet,
  rollsToolBonusResource,
  spendCost,
} from './economyConfig';
import { createEmptyResourceAmounts } from './survivalTypes';

describe('economy configuration', () => {
  it('keeps recruitment and specialization curves tied to living composition', () => {
    expect(MAX_PLAYABLE_MINIONS).toBe(8);
    expect([2, 3, 4, 5, 6, 7].map((population) => getGathererRecruitmentCost(population)))
      .toEqual([{ food: 2 }, { food: 3 }, { food: 3 }, { food: 4 }, { food: 4 }, { food: 4 }]);
    expect([0, 1, 2, 3, 4, 5].map((count) => getSpecializationCost('sword', count)))
      .toEqual([{ gold: 2 }, { gold: 3 }, { gold: 3 }, { gold: 4 }, { gold: 4 }, { gold: 4 }]);
    expect(getSpecializationCost('mage', 0)).toEqual({ spark: 2 });
    expect(getSpecializationCost('mage', 1)).toEqual({ spark: 2 });
    expect(getSpecializationLimit('mage')).toBe(1);
    expect(getShieldCost(0)).toEqual({ gold: 2 });
  });

  it('defines all eleven levels and advanced mixed costs without cross-tool effects', () => {
    for (const tool of ['axe', 'hammer', 'sword'] as const) {
      expect(TOOL_UPGRADES[tool]).toHaveLength(11);
      expect(TOOL_UPGRADES[tool][8].cost).toEqual({ stone: 8, spark: 1 });
      expect(TOOL_UPGRADES[tool][9].cost).toEqual({ stone: 9, spark: 1, gold: 1 });
      expect(TOOL_UPGRADES[tool][10].cost).toEqual({ stone: 10, spark: 2, gold: 2 });
    }
    expect(TOOL_UPGRADES.axe.map(({ effect }) => effect.gatherSpeedPercent))
      .toEqual([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5]);
    expect(TOOL_UPGRADES.hammer.map(({ effect }) => effect.bonusResourceChance))
      .toEqual([0, 0, 0.5, 1, 1.5, 2, 5, 10, 15, 20, 30]);
    expect(TOOL_UPGRADES.sword.map(({ effect }) => effect.guardianDamageBonus))
      .toEqual([0, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5]);
    expect(TOOL_UPGRADES.axe[10].effect).toEqual({ gatherSpeedPercent: 5, bonusResourceChance: 30 });
    expect(TOOL_UPGRADES.hammer[5].effect).toEqual({ gatherSpeedPercent: 2.5, bonusResourceChance: 2 });
    expect(TOOL_UPGRADES.sword[10].effect).toEqual({ guardianDamageBonus: 2.5 });
    expect(TOOL_UPGRADES.sword[10].effect.bonusResourceChance).toBeUndefined();
  });

  it('reports missing resources and never partially spends a mixed cost', () => {
    const amounts = createEmptyResourceAmounts();
    amounts.stone = 10;
    amounts.spark = 1;
    const cost = TOOL_UPGRADES.axe[10].cost;
    expect(canAffordCost(amounts, cost)).toBe(false);
    expect(getMissingResources(amounts, cost)).toEqual({ spark: 1, gold: 2 });
    expect(spendCost(amounts, cost)).toBe(false);
    expect(amounts).toEqual({ food: 0, wood: 0, stone: 10, spark: 1, gold: 0 });

    amounts.spark = 2;
    amounts.gold = 2;
    expect(spendCost(amounts, cost)).toBe(true);
    expect(amounts).toEqual({ food: 0, wood: 0, stone: 0, spark: 0, gold: 0 });
  });

  it('uses deterministic single-resource bonus rolls and gates stone tier II at hammer +5', () => {
    const roll = (tick: number) => rollsToolBonusResource({
      seed: 'bonus-seed', tick, unitId: 'artisan-01', nodeId: 'stone-01', tool: 'hammer', level: 10,
    });
    expect(rollsToolBonusResource({
      seed: 'bonus-seed', tick: 1, unitId: 'artisan-01', nodeId: 'stone-01', tool: 'hammer', level: 0,
    })).toBe(false);
    expect(Array.from({ length: 100 }, (_, tick) => roll(tick))).toContain(true);
    expect(roll(42)).toBe(roll(42));

    const tierTwoStone = { source: 'stone-vein' as const, tier: 2 as const };
    expect(isResourceNodeToolRequirementMet(tierTwoStone, { axe: 0, hammer: 4, sword: 0 })).toBe(false);
    expect(isResourceNodeToolRequirementMet(tierTwoStone, { axe: 0, hammer: 5, sword: 0 })).toBe(true);
  });
});

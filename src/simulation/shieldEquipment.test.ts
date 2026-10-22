import { describe, expect, it } from 'vitest';
import { createInitialState } from './createInitialState';
import { applyInputActions } from './stepSimulation';

describe('shield equipment', () => {
  it('adds one current and maximum HP when equipped without reducing relative health', () => {
    const state = createInitialState('shield-equipment-test');
    const guardian = state.units[0];
    guardian.role = 'guardian';
    guardian.health = 2;
    guardian.maxHealth = 4;
    state.progression.unlockedTechnologies.push('shield');
    state.inventory.amounts.gold = 2;

    applyInputActions(state, [{ type: 'equip-shield', unitId: guardian.id }]);

    expect(guardian).toMatchObject({ hasShield: true, health: 3, maxHealth: 5 });
    expect(state.inventory.amounts.gold).toBe(0);
  });
});

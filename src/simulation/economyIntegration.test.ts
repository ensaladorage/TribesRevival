import { describe, expect, it } from 'vitest';
import { createInitialState, createUnitState } from './createInitialState';
import { applyInputActions } from './stepSimulation';

describe('economy simulation integration', () => {
  it('transforms a single gatherer into the only exterior Mage without increasing population', () => {
    const state = createInitialState('one-mage');
    const first = state.units[0];
    const second = createUnitState('gatherer-02', 'gatherer', { x: 82, y: 80 });
    state.units = [first, second];
    state.inventory.amounts.spark = 4;
    state.progression.unlockedTechnologies.push('mage');

    applyInputActions(state, [{ type: 'transform-unit', item: 'mage', unitId: first.id }]);
    expect(state.units).toHaveLength(2);
    expect(first.role).toBe('mage');
    expect(state.inventory.amounts.spark).toBe(2);

    applyInputActions(state, [{ type: 'transform-unit', item: 'mage', unitId: second.id }]);
    expect(second.role).toBe('gatherer');
    expect(state.inventory.amounts.spark).toBe(2);
  });

  it('requires every advanced resource before applying a tool level', () => {
    const state = createInitialState('atomic-level-ten');
    state.toolLevels.axe = 9;
    state.inventory.amounts.stone = 10;
    state.inventory.amounts.spark = 2;
    state.inventory.amounts.gold = 1;

    applyInputActions(state, [{ type: 'upgrade-tool', tool: 'axe' }]);
    expect(state.toolLevels.axe).toBe(9);
    expect(state.inventory.amounts).toMatchObject({ stone: 10, spark: 2, gold: 1 });

    state.inventory.amounts.gold = 2;
    applyInputActions(state, [{ type: 'upgrade-tool', tool: 'axe' }]);
    expect(state.toolLevels.axe).toBe(10);
    expect(state.inventory.amounts).toMatchObject({ stone: 0, spark: 0, gold: 0 });

    applyInputActions(state, [{ type: 'upgrade-tool', tool: 'axe' }]);
    expect(state.toolLevels.axe).toBe(10);
  });

  it('recalculates Guardian cost after a Guardian dies', () => {
    const state = createInitialState('guardian-reprice');
    const first = state.units[0];
    const second = createUnitState('gatherer-02', 'gatherer', { x: 82, y: 80 });
    const third = createUnitState('gatherer-03', 'gatherer', { x: 84, y: 80 });
    state.units = [first, second, third];
    state.inventory.amounts.gold = 20;

    applyInputActions(state, [
      { type: 'transform-unit', item: 'sword', unitId: first.id },
      { type: 'transform-unit', item: 'sword', unitId: second.id },
    ]);
    expect(state.inventory.amounts.gold).toBe(15);
    first.health = 1;
    applyInputActions(state, [{ type: 'damage-unit', unitId: first.id, amount: 1, sourceKind: 'barbarian' }]);
    applyInputActions(state, [{ type: 'transform-unit', item: 'sword', unitId: third.id }]);
    expect(state.inventory.amounts.gold).toBe(12);
  });
});

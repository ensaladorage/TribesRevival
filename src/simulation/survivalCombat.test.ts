import { describe, expect, it } from 'vitest';
import {
  BARBARIAN_ATTACK_COOLDOWN_SECONDS,
  BARBARIAN_ATTACK_DAMAGE,
  BARBARIAN_ATTACK_RANGE,
  BARBARIAN_DETECTION_RADIUS,
  BARBARIAN_MAX_HEALTH,
  BARBARIAN_MOVEMENT_SPEED,
  BARBARIAN_RESPAWN_SECONDS,
  MINION_ATTACK_STATS,
  MINION_THREAT_DETECTION_RADIUS,
  canCombatantDealDamage,
  canCombatantReceiveDamage,
  dealDamage,
  healCombatant,
} from './survivalCombat';

const target = {
  id: 'combatant-test',
  position: { x: 0, y: 0 },
  health: 4,
  maxHealth: 4,
};

describe('survival combat contracts', () => {
  it('uses the Hito 4 balance values without an armor stat', () => {
    expect(BARBARIAN_MAX_HEALTH).toBe(5);
    expect(BARBARIAN_ATTACK_DAMAGE).toBe(1);
    expect(BARBARIAN_ATTACK_COOLDOWN_SECONDS).toBe(2.5);
    expect(BARBARIAN_ATTACK_RANGE).toBe(1.2);
    expect(BARBARIAN_DETECTION_RADIUS).toBe(15);
    expect(BARBARIAN_MOVEMENT_SPEED).toBe(8);
    expect(BARBARIAN_RESPAWN_SECONDS).toBe(60);
    expect(MINION_THREAT_DETECTION_RADIUS).toBe(18);
    expect(MINION_ATTACK_STATS.guardian).toEqual({ damage: 2, range: 1, cooldownSeconds: 1.5 });
    expect(MINION_ATTACK_STATS.lumberjack).toEqual({ damage: 1.5, range: 1, cooldownSeconds: 2 });
    expect(MINION_ATTACK_STATS.hunter).toEqual({ damage: 1, range: 5, cooldownSeconds: 1.3 });
    expect(MINION_ATTACK_STATS.gatherer).toBeUndefined();
  });

  it('allows minions and barbarians to attack, but animals only receive damage', () => {
    expect(canCombatantDealDamage('minion')).toBe(true);
    expect(canCombatantDealDamage('barbarian')).toBe(true);
    expect(canCombatantDealDamage('animal')).toBe(false);
    expect(canCombatantReceiveDamage('minion')).toBe(true);
    expect(canCombatantReceiveDamage('barbarian')).toBe(true);
    expect(canCombatantReceiveDamage('animal')).toBe(true);
  });

  it('clamps damage and healing to the combatant health bounds', () => {
    expect(dealDamage('barbarian', 'minion', target, 1.5)).toEqual({
      damageApplied: 1.5,
      health: 2.5,
      defeated: false,
    });
    expect(dealDamage('animal', 'minion', target, 2).damageApplied).toBe(0);
    expect(dealDamage('minion', 'minion', { ...target, health: 1 }, 4).defeated).toBe(true);
    expect(healCombatant({ ...target, health: 2 }, 10)).toEqual({
      healingApplied: 2,
      health: 4,
    });
  });
});

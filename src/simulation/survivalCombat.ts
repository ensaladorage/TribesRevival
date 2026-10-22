import type { Vec2 } from './types';
import type { SurvivalRole } from './survivalTypes';

export const MINION_MAX_HEALTH = 4;
export const BARBARIAN_MAX_HEALTH = 5;
export const BARBARIAN_ATTACK_DAMAGE = 1;
export const BARBARIAN_ATTACK_RANGE = 1.2;
export const BARBARIAN_ATTACK_COOLDOWN_SECONDS = 2.5;
export const BARBARIAN_DETECTION_RADIUS = 15;
export const BARBARIAN_MOVEMENT_SPEED = 8;
export const BARBARIAN_RESPAWN_SECONDS = 60;
export const MINION_THREAT_DETECTION_RADIUS = 18;
export const COMBAT_ALERT_DURATION_SECONDS = 1.4;
export const CAMPFIRE_HEAL_INTERVAL_SECONDS = 8;
export const DAMAGE_FLASH_DURATION_SECONDS = 0.3;
export const HEAL_EFFECT_DURATION_SECONDS = 0.9;

export type AttackStats = {
  damage: number;
  range: number;
  cooldownSeconds: number;
};

export const MINION_ATTACK_STATS: Readonly<Partial<Record<SurvivalRole, AttackStats>>> = {
  guardian: { damage: 2, range: 1, cooldownSeconds: 1.5 },
  lumberjack: { damage: 1.5, range: 1, cooldownSeconds: 2 },
  hunter: { damage: 1, range: 5, cooldownSeconds: 1.3 },
};

export const ANIMAL_ATTACK_STATS: AttackStats = {
  damage: 1,
  range: 5,
  cooldownSeconds: 1.3,
};

export type CombatantKind = 'minion' | 'barbarian' | 'animal';

export type DamageableCombatant = {
  id: string;
  position: Vec2;
  health: number;
  maxHealth: number;
};

export type DamageResult = {
  damageApplied: number;
  health: number;
  defeated: boolean;
};

export type HealResult = {
  healingApplied: number;
  health: number;
};

const COMBATANT_CAPABILITIES: Readonly<Record<CombatantKind, {
  canDealDamage: boolean;
  canReceiveDamage: boolean;
}>> = {
  minion: { canDealDamage: true, canReceiveDamage: true },
  barbarian: { canDealDamage: true, canReceiveDamage: true },
  animal: { canDealDamage: false, canReceiveDamage: true },
};

export function canCombatantDealDamage(kind: CombatantKind): boolean {
  return COMBATANT_CAPABILITIES[kind].canDealDamage;
}

export function canCombatantReceiveDamage(kind: CombatantKind): boolean {
  return COMBATANT_CAPABILITIES[kind].canReceiveDamage;
}

export function dealDamage(
  sourceKind: CombatantKind,
  targetKind: CombatantKind,
  target: DamageableCombatant,
  amount: number,
): DamageResult {
  if (!canCombatantDealDamage(sourceKind) || !canCombatantReceiveDamage(targetKind)) {
    return {
      damageApplied: 0,
      health: Math.max(target.health, 0),
      defeated: target.health <= 0,
    };
  }

  const normalizedAmount = Number.isFinite(amount) ? Math.max(amount, 0) : 0;
  const currentHealth = Math.max(target.health, 0);
  const health = Math.max(currentHealth - normalizedAmount, 0);

  return {
    damageApplied: currentHealth - health,
    health,
    defeated: health <= 0,
  };
}

export function healCombatant(
  target: DamageableCombatant,
  amount: number,
): HealResult {
  const normalizedAmount = Number.isFinite(amount) ? Math.max(amount, 0) : 0;
  const currentHealth = Math.max(target.health, 0);
  const maximumHealth = Math.max(target.maxHealth, 0);
  const health = Math.min(currentHealth + normalizedAmount, maximumHealth);

  return {
    healingApplied: health - currentHealth,
    health,
  };
}

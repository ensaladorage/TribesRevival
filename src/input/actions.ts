import type { Vec2 } from '../simulation/types';
import type { ResourceType, SpecializationItem, TechnologyId } from '../simulation/survivalTypes';
import type { CombatantKind } from '../simulation/survivalCombat';

export type InputAction =
  | { type: 'pick-up-totem' }
  | { type: 'drag-totem'; position: Vec2 }
  | { type: 'drop-totem'; position: Vec2 }
  | { type: 'place-campfire'; position: Vec2 }
  | { type: 'recruit-gatherer'; position: Vec2 }
  | { type: 'transform-unit'; item: SpecializationItem; unitId: string }
  | { type: 'equip-shield'; unitId: string }
  | { type: 'unlock-technology'; technology: TechnologyId }
  | { type: 'damage-unit'; unitId: string; amount: number; sourceKind: CombatantKind }
  | { type: 'debug-damage-one-minion' }
  | { type: 'debug-level-up' }
  | { type: 'debug-add-resource'; resource: ResourceType; amount: number }
  | { type: 'toggle-pause' };

export class ActionQueue {
  private readonly actions: InputAction[] = [];

  public enqueue(action: InputAction): void {
    this.actions.push(action);
  }

  public drain(): InputAction[] {
    return this.actions.splice(0, this.actions.length);
  }
}

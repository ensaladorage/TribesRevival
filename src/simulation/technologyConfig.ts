import type { TechnologyId } from './survivalTypes';
import type { ProgressionState } from './types';

export const TECHNOLOGY_TREES = {
  survival: 'Supervivencia',
  exploration: 'Exploración',
  combat: 'Combate',
} as const;

export type TechnologyTreeId = keyof typeof TECHNOLOGY_TREES;

type TechnologyDefinition = {
  id: TechnologyId;
  tree: TechnologyTreeId;
  order: number;
  cost: number;
  minimumLevel: number;
  name: string;
  description: string;
};

export const TECHNOLOGIES: readonly TechnologyDefinition[] = [
  { id: 'artisan', tree: 'survival', order: 0, cost: 1, minimumLevel: 2,
    name: 'Artesana', description: 'Permite convertir un recolector en artesana para reunir Piedra y Brillo.' },
  { id: 'mage', tree: 'exploration', order: 0, cost: 1, minimumLevel: 2,
    name: 'Mago', description: 'Permite convertir un recolector en Mago para entrar en mazmorras.' },
  { id: 'shield', tree: 'combat', order: 0, cost: 1, minimumLevel: 1,
    name: 'Escudo', description: 'Permite equipar a los guardianes para aumentar su vida máxima en 1.' },
];

export function getTechnology(id: TechnologyId): TechnologyDefinition | undefined {
  return TECHNOLOGIES.find((technology) => technology.id === id);
}

export function canUnlockTechnology(progression: ProgressionState, id: TechnologyId): boolean {
  const technology = getTechnology(id);
  return !!technology
    && !progression.unlockedTechnologies.includes(id)
    && progression.level >= technology.minimumLevel
    && progression.technologyPoints >= technology.cost;
}

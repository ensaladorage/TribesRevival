export type SeededRandom = {
  nextUint(): number;
  nextFloat(): number;
  nextFloat(min: number, max: number): number;
  nextInt(min: number, max: number): number;
};

function hashSeed(seed: string): number {
  let hash = 2166136261;

  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }

  return hash >>> 0;
}

/**
 * Small deterministic PRNG for simulation data generation.
 * It deliberately has no dependency on browser state or Math.random().
 */
export function createSeededRandom(seed: string): SeededRandom {
  let state = hashSeed(seed);

  const nextUint = (): number => {
    state = (state + 0x6d2b79f5) | 0;
    let value = Math.imul(state ^ (state >>> 15), 1 | state);
    value ^= value + Math.imul(value ^ (value >>> 7), 61 | value);
    return (value ^ (value >>> 14)) >>> 0;
  };

  const nextFloat = (min?: number, max?: number): number => {
    const normalized = nextUint() / 4294967296;
    if (min === undefined || max === undefined) return normalized;
    return min + normalized * (max - min);
  };

  return {
    nextUint,
    nextFloat,
    nextInt(min: number, max: number): number {
      if (!Number.isInteger(min) || !Number.isInteger(max) || max < min) {
        throw new RangeError('nextInt requires integer bounds with max >= min');
      }
      return Math.floor(nextFloat() * (max - min + 1)) + min;
    },
  };
}

import { createSeededRandom } from './seededRandom';
import type { GameState, Vec2, WeatherCloudState, WeatherState } from './types';
import type { BiomeId } from './survivalTypes';

export const WEATHER_CLOUD_INTERVAL_SECONDS = 30;
export const WEATHER_RAIN_DURATION_SECONDS = 6;
export const WEATHER_CLOUD_SPEED = 2.5;
export const WEATHER_CLOUD_APPROACH_DISTANCE = 64;
// Continue far enough up-screen to leave the viewport before removing the cloud.
export const WEATHER_CLOUD_EXIT_DISTANCE = 180;
export const WEATHER_RAIN_DRIFT_SPEED = 0.75;

// The isometric camera looks from world +X/+Z. This diagonal therefore reads
// as the bottom of the screen; its inverse is the screen-up travel direction.
const SCREEN_DOWN = Math.SQRT1_2;
const SCREEN_UP_VECTOR = { x: -SCREEN_DOWN, y: -SCREEN_DOWN } as const;
const RAIN_TARGET_BIOME_TYPES: readonly BiomeId[] = ['clearing', 'meadow', 'forest'];

type WeatherSimulationState = Pick<GameState, 'seed' | 'weather' | 'biomes' | 'resources'>;

export function createWeatherState(): WeatherState {
  return {
    nextCloudInSeconds: WEATHER_CLOUD_INTERVAL_SECONDS,
    nextCloudIndex: 0,
    clouds: [],
  };
}

function shuffledTargetTypes(seed: string, cycle: number): BiomeId[] {
  const types = [...RAIN_TARGET_BIOME_TYPES];
  const random = createSeededRandom(`${seed}:weather-type-cycle:${cycle}`);
  for (let index = types.length - 1; index > 0; index -= 1) {
    const swapIndex = random.nextInt(0, index);
    [types[index], types[swapIndex]] = [types[swapIndex], types[index]];
  }
  return types;
}

function chooseTargetBiome(
  state: WeatherSimulationState,
  cloudIndex: number,
): GameState['biomes'][number] | null {
  const cycle = Math.floor(cloudIndex / RAIN_TARGET_BIOME_TYPES.length);
  const slot = cloudIndex % RAIN_TARGET_BIOME_TYPES.length;
  const targetType = shuffledTargetTypes(state.seed, cycle)[slot];
  const candidates = state.biomes
    .filter((biome) => biome.id === targetType && state.resources.some((resource) => (
      resource.biomeInstanceId === biome.instanceId
      && (resource.type === 'food' || resource.type === 'wood')
    )))
    .sort((first, second) => first.instanceId.localeCompare(second.instanceId));
  if (candidates.length === 0) return null;

  const random = createSeededRandom(`${state.seed}:weather-target:${cloudIndex}`);
  return candidates[random.nextInt(0, candidates.length - 1)];
}

function spawnWeatherCloud(state: WeatherSimulationState): void {
  const cloudIndex = state.weather.nextCloudIndex;
  state.weather.nextCloudIndex += 1;
  const targetBiome = chooseTargetBiome(state, cloudIndex);
  if (!targetBiome) return;

  const target = { x: targetBiome.region.x, y: targetBiome.region.y };
  state.weather.clouds.push({
    id: `weather-cloud-${String(cloudIndex + 1).padStart(3, '0')}`,
    position: {
      x: target.x + SCREEN_DOWN * WEATHER_CLOUD_APPROACH_DISTANCE,
      y: target.y + SCREEN_DOWN * WEATHER_CLOUD_APPROACH_DISTANCE,
    },
    targetBiomeInstanceId: targetBiome.instanceId,
    phase: 'approaching',
    phaseElapsedSeconds: 0,
    rainRemainingSeconds: 0,
  });
}

function moveTowards(position: Vec2, destination: Vec2, maxDistance: number): boolean {
  const dx = destination.x - position.x;
  const dy = destination.y - position.y;
  const distance = Math.hypot(dx, dy);
  if (distance <= maxDistance || distance < 1e-8) {
    position.x = destination.x;
    position.y = destination.y;
    return true;
  }

  position.x += (dx / distance) * maxDistance;
  position.y += (dy / distance) * maxDistance;
  return false;
}

function restoreBiomeResources(state: WeatherSimulationState, biomeInstanceId: string): void {
  for (const resource of state.resources) {
    if (
      resource.biomeInstanceId !== biomeInstanceId
      || (resource.type !== 'food' && resource.type !== 'wood')
      || resource.amount > 0
    ) continue;
    resource.amount = Math.max(resource.maxAmount, 0);
  }
}

function advanceCloud(state: WeatherSimulationState, cloud: WeatherCloudState, deltaSeconds: number): boolean {
  const biome = state.biomes.find((candidate) => (
    candidate.instanceId === cloud.targetBiomeInstanceId
  ));
  if (!biome) return false;

  const center = { x: biome.region.x, y: biome.region.y };
  if (cloud.phase === 'approaching') {
    if (moveTowards(cloud.position, center, WEATHER_CLOUD_SPEED * deltaSeconds)) {
      cloud.phase = 'raining';
      cloud.phaseElapsedSeconds = 0;
      cloud.rainRemainingSeconds = WEATHER_RAIN_DURATION_SECONDS;
      restoreBiomeResources(state, biome.instanceId);
    }
    return true;
  }

  if (cloud.phase === 'raining') {
    cloud.phaseElapsedSeconds += deltaSeconds;
    cloud.rainRemainingSeconds = Math.max(0, cloud.rainRemainingSeconds - deltaSeconds);
    cloud.position.x += SCREEN_UP_VECTOR.x * WEATHER_RAIN_DRIFT_SPEED * deltaSeconds;
    cloud.position.y += SCREEN_UP_VECTOR.y * WEATHER_RAIN_DRIFT_SPEED * deltaSeconds;
    if (cloud.rainRemainingSeconds <= 1e-9) {
      cloud.rainRemainingSeconds = 0;
      cloud.phase = 'departing';
      cloud.phaseElapsedSeconds = 0;
    }
    return true;
  }

  const exitTarget = {
    x: center.x + SCREEN_UP_VECTOR.x * WEATHER_CLOUD_EXIT_DISTANCE,
    y: center.y + SCREEN_UP_VECTOR.y * WEATHER_CLOUD_EXIT_DISTANCE,
  };
  return !moveTowards(cloud.position, exitTarget, WEATHER_CLOUD_SPEED * deltaSeconds);
}

/** Advances deterministic cloud routes and restores depleted food/wood nodes on rain. */
export function updateWeather(state: WeatherSimulationState, deltaSeconds: number): void {
  if (!Number.isFinite(deltaSeconds) || deltaSeconds <= 0) return;

  state.weather.nextCloudInSeconds -= deltaSeconds;
  while (state.weather.nextCloudInSeconds <= 1e-9) {
    spawnWeatherCloud(state);
    state.weather.nextCloudInSeconds += WEATHER_CLOUD_INTERVAL_SECONDS;
  }

  for (let index = state.weather.clouds.length - 1; index >= 0; index -= 1) {
    const cloud = state.weather.clouds[index];
    if (!advanceCloud(state, cloud, deltaSeconds)) {
      state.weather.clouds.splice(index, 1);
    }
  }
}

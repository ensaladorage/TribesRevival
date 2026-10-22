import { describe, expect, it } from 'vitest';
import { createInitialState } from './createInitialState';
import {
  WEATHER_CLOUD_INTERVAL_SECONDS,
  WEATHER_CLOUD_EXIT_DISTANCE,
  WEATHER_CLOUD_SPEED,
  WEATHER_RAIN_DURATION_SECONDS,
  createWeatherState,
  updateWeather,
} from './weatherSystem';

const TICK = 1 / 20;

describe('weatherSystem', () => {
  it('starts seeded clouds every 30 seconds and cycles through the three requested biome types', () => {
    const states = [createInitialState('weather-route-seed'), createInitialState('weather-route-seed')];
    const targetTypes: string[] = [];

    for (let tick = 0; tick < WEATHER_CLOUD_INTERVAL_SECONDS * 3 / TICK; tick += 1) {
      for (const state of states) updateWeather(state, TICK);
      if (states[0].weather.nextCloudIndex > targetTypes.length) {
        const spawned = states[0].weather.clouds.find((cloud) => (
          cloud.id === `weather-cloud-${String(targetTypes.length + 1).padStart(3, '0')}`
        ));
        expect(spawned).toBeDefined();
        const biome = states[0].biomes.find((candidate) => (
          candidate.instanceId === spawned?.targetBiomeInstanceId
        ));
        expect(biome).toBeDefined();
        targetTypes.push(biome!.id);
        expect(states[0].weather).toEqual(states[1].weather);
      }
    }

    expect(targetTypes).toHaveLength(3);
    expect(new Set(targetTypes)).toEqual(new Set(['clearing', 'meadow', 'forest']));
  });

  it('spawns below its target in the isometric view and travels upward to rain', () => {
    const state = createInitialState('weather-direction-seed');
    const target = state.biomes.find((biome) => (
      biome.id === 'clearing'
      && state.resources.some((resource) => resource.biomeInstanceId === biome.instanceId)
    ));
    expect(target).toBeDefined();

    state.weather.nextCloudInSeconds = TICK;
    updateWeather(state, TICK);
    const cloud = state.weather.clouds[0];
    expect(cloud.position.x).toBeGreaterThan(target!.region.x);
    expect(cloud.position.y).toBeGreaterThan(target!.region.y);

    const startPosition = { ...cloud.position };
    for (let tick = 0; tick < 515; tick += 1) updateWeather(state, TICK);
    expect(cloud.position.x).toBeLessThan(startPosition.x);
    expect(cloud.position.y).toBeLessThan(startPosition.y);
    expect(cloud.phase).toBe('raining');
  });

  it('restores depleted food and wood in the rained biome but leaves stone and spark untouched', () => {
    const state = createInitialState('weather-regrowth-seed');
    const target = state.biomes.find((biome) => biome.id === 'forest');
    expect(target).toBeDefined();
    const targetResources = state.resources.filter((resource) => (
      resource.biomeInstanceId === target!.instanceId
    ));
    expect(targetResources.length).toBeGreaterThan(0);
    const partiallyDepleted = targetResources.find((resource) => (
      (resource.type === 'food' || resource.type === 'wood') && resource.maxAmount > 1
    ));
    for (const resource of targetResources) {
      resource.amount = resource === partiallyDepleted ? 1 : 0;
    }
    state.weather.clouds = [{
      id: 'weather-cloud-test',
      position: { x: target!.region.x, y: target!.region.y },
      targetBiomeInstanceId: target!.instanceId,
      phase: 'approaching',
      phaseElapsedSeconds: 0,
      rainRemainingSeconds: 0,
    }];

    updateWeather(state, TICK);

    expect(state.weather.clouds[0].phase).toBe('raining');
    for (const resource of targetResources) {
      if (resource.type === 'food' || resource.type === 'wood') {
        expect(resource.amount).toBe(resource === partiallyDepleted ? 1 : resource.maxAmount);
      } else {
        expect(resource.amount).toBe(0);
      }
    }
  });

  it('keeps the six-second rain window and regenerates clearing twigs', () => {
    const state = createInitialState('weather-rain-duration-seed');
    const twig = state.resources.find((resource) => resource.source === 'twigs');
    expect(twig).toBeDefined();
    twig!.amount = 0;
    const clearing = state.biomes.find((biome) => biome.instanceId === twig!.biomeInstanceId);
    expect(clearing).toBeDefined();
    state.weather.clouds = [{
      id: 'weather-cloud-clearing',
      position: { x: clearing!.region.x, y: clearing!.region.y },
      targetBiomeInstanceId: twig!.biomeInstanceId!,
      phase: 'approaching',
      phaseElapsedSeconds: 0,
      rainRemainingSeconds: 0,
    }];

    updateWeather(state, TICK);
    expect(twig!.amount).toBe(twig!.maxAmount);
    for (let tick = 0; tick < WEATHER_RAIN_DURATION_SECONDS / TICK - 1; tick += 1) {
      updateWeather(state, TICK);
    }
    expect(state.weather.clouds[0].phase).toBe('raining');
    expect(state.weather.clouds[0].rainRemainingSeconds).toBeCloseTo(TICK);
    updateWeather(state, TICK);
    expect(state.weather.clouds[0].phase).toBe('departing');
  });

  it('continues upward after rain and despawns only after its long exit route', () => {
    const state = createInitialState('weather-cloud-exit-seed');
    const target = state.biomes.find((biome) => biome.id === 'forest');
    expect(target).toBeDefined();
    state.weather.nextCloudInSeconds = 1_000;
    state.weather.clouds = [{
      id: 'weather-cloud-exit',
      position: { x: target!.region.x, y: target!.region.y },
      targetBiomeInstanceId: target!.instanceId,
      phase: 'departing',
      phaseElapsedSeconds: 0,
      rainRemainingSeconds: 0,
    }];

    const cloud = state.weather.clouds[0];
    const elapsedTicks = Math.ceil(
      (WEATHER_CLOUD_EXIT_DISTANCE / WEATHER_CLOUD_SPEED) / TICK,
    );
    const firstLegTicks = Math.ceil((32 / WEATHER_CLOUD_SPEED) / TICK);
    for (let tick = 0; tick < firstLegTicks; tick += 1) updateWeather(state, TICK);

    expect(state.weather.clouds).toContain(cloud);
    expect(cloud.position.x).toBeLessThan(target!.region.x - 20);

    for (let tick = firstLegTicks; tick <= elapsedTicks; tick += 1) updateWeather(state, TICK);

    expect(state.weather.clouds).not.toContain(cloud);
  });

  it('initializes weather consistently for identical seeds', () => {
    expect(createInitialState('weather-initial-seed').weather)
      .toEqual(createInitialState('weather-initial-seed').weather);
    expect(createWeatherState().nextCloudInSeconds).toBe(WEATHER_CLOUD_INTERVAL_SECONDS);
  });
});

import {
  Color3,
  Engine,
  FreeCamera,
  HemisphericLight,
  Matrix,
  Mesh,
  MeshBuilder,
  Plane,
  PointerEventTypes,
  PointerInfo,
  Scene,
  StandardMaterial,
  TransformNode,
  Vector3,
} from '@babylonjs/core';
import { ActionQueue } from '../input/actions';
import { createInitialState } from '../simulation/createInitialState';
import {
  clampWorldPosition,
  HUNTER_TOTEM_LEASH_RADIUS,
  projectWithinRadius,
  stepSimulation,
  WORLD_SIZE,
} from '../simulation/stepSimulation';
import {
  countUnitsWithRole,
  canConvertLastGathererToLumberjack,
  getMinionPurchaseCost,
  MAX_PLAYABLE_MINIONS,
  MAX_MINIONS_PER_TYPE,
  getResourceDetectionRadius,
  STARTING_MINION_COUNT,
} from '../simulation/survivalRules';
import type {
  AnimalState,
  BarbarianCorpse,
  BarbarianState,
  GameState,
  Vec2,
} from '../simulation/types';
import {
  CAMPFIRE_HEALING_RADIUS,
  CAMPFIRE_WOOD_COST,
  MAX_ACTIVE_CAMPFIRES,
} from '../simulation/survivalTypes';
import type {
  BiomeId,
  ResourceDrop,
  ResourceNode,
  ResourceType,
  SpecializationItem,
  WorldDecoration,
} from '../simulation/survivalTypes';
import { RESOURCE_TYPES } from '../simulation/survivalTypes';
import type { TechnologyId } from '../simulation/survivalTypes';
import {
  createBrowserSaveRepository,
  getSaveFingerprint,
  getSaveSlotIds,
  type SaveGameRepository,
  type SaveSlotId,
  type SaveSlotStatus,
} from '../persistence/saveGame';

const FIXED_DT = 1 / 20;
const MAX_STEPS_PER_FRAME = 4;
const BASE_VIEW_HEIGHT = 72;
const CAMERA_DISTANCE = 120;
const CAMERA_YAW = Math.PI / 4;
const CAMERA_PITCH = (35 * Math.PI) / 180;
const CAMERA_ZOOM_LIMIT_MIN = 0.5;
const CAMERA_ZOOM_LIMIT_MAX = 2;
const CAMERA_ZOOM_STEP = 0.05;
const DEFAULT_CAMERA_ZOOM_MIN = 0.5;
const DEFAULT_CAMERA_ZOOM_MAX = 1;
const CAMERA_EDGE_MARGIN = 72;
const CAMERA_EDGE_SCROLL_SPEED = 32;
const CAMERA_RECENTER_SPEED = 4.5;
const HUD_HELD_ITEM_SCALE = 1.25;
const HUD_HELD_ITEM_LIFT = 0.7;
const WEATHER_CLOUD_VISUAL_SCALE = 3;

type RenderSnapshot = {
  totem: Vec2;
  units: Map<string, Vec2>;
  barbarians: Map<string, Vec2>;
  animals: Map<string, Vec2>;
  clouds: Map<string, Vec2>;
};

type WeatherCloudView = {
  root: TransformNode;
  puffs: Mesh[];
  raindrops: Mesh[];
  rainOffsets: Vec2[];
  cloudMaterial: StandardMaterial;
  rainMaterial: StandardMaterial;
};

type HudBuildItem = 'campfire' | 'gatherer' | 'shield' | SpecializationItem;
type MenuScreen = 'main' | 'tutorial' | 'pause' | 'slots' | 'confirmation' | 'game';
type SlotMenuMode = 'save' | 'load';
type ConfirmationAction = 'exit' | 'overwrite';

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function lerp(from: number, to: number, alpha: number): number {
  return from + (to - from) * alpha;
}

export class BabylonGame {
  private readonly canvas: HTMLCanvasElement;
  private readonly engine: Engine;
  private readonly scene: Scene;
  private readonly camera: FreeCamera;
  private readonly ground: Mesh;
  private readonly totem: Mesh;
  private readonly totemShadow: Mesh;
  private readonly totemDirectionArrow: Mesh;
  private readonly totemMaterial: StandardMaterial;
  private readonly units = new Map<string, Mesh>();
  private readonly corpseMeshes = new Map<string, Mesh[]>();
  private readonly barbarianMeshes = new Map<string, Mesh[]>();
  private readonly barbarianHealthHud = new Map<string, HTMLDivElement>();
  private readonly barbarianHealthPips = new Map<string, HTMLSpanElement[]>();
  private readonly animalMeshes = new Map<string, Mesh[]>();
  private readonly barbarianCorpseMeshes = new Map<string, Mesh[]>();
  private readonly alertIndicators = new Map<string, HTMLDivElement>();
  private readonly playedAlertIds = new Set<string>();
  private readonly healthOverlay: HTMLDivElement;
  private readonly unitHealthHud = new Map<string, HTMLDivElement>();
  private readonly unitHealthPips = new Map<string, HTMLSpanElement[]>();
  private readonly unitShieldMeshes = new Map<string, Mesh[]>();
  private readonly unitDetectionMeshes = new Map<string, Mesh>();
  private readonly resourceMeshes = new Map<string, Mesh[]>();
  private readonly weatherCloudViews = new Map<string, WeatherCloudView>();
  private readonly resourceDropMeshes = new Map<string, Mesh>();
  private readonly biomeMeshes = new Map<string, Mesh>();
  private readonly decorationMeshes = new Map<string, Mesh[]>();
  private readonly campfireMeshes = new Map<string, Mesh[]>();
  private readonly effectMeshes = new Map<string, Mesh[]>();
  private state: GameState = createInitialState();
  private readonly actionQueue = new ActionQueue();
  private readonly saveRepository: SaveGameRepository;
  private previousSnapshot: RenderSnapshot;
  private currentSnapshot: RenderSnapshot;
  private cameraFocus = new Vector3(WORLD_SIZE / 2, 0, WORLD_SIZE / 2);
  private cameraRecentering = false;
  private dragging = false;
  private lastDragPosition: Vec2 = { x: WORLD_SIZE / 2, y: WORLD_SIZE / 2 };
  private lastDragDirection: Vec2 = { x: 0, y: 1 };
  private accumulator = 0;
  private speedMultiplier = 1;
  private cameraZoomMin = DEFAULT_CAMERA_ZOOM_MIN;
  private cameraZoomMax = DEFAULT_CAMERA_ZOOM_MAX;
  private zoom = DEFAULT_CAMERA_ZOOM_MIN;
  private hudItemDragging: HudBuildItem | null = null;
  private hudPointerId: number | null = null;
  private hudPointerTarget: HTMLButtonElement | null = null;
  private hudPreviewPosition: Vec2 | null = null;
  private hudHeldItemMeshes: Mesh[] = [];
  private technologyTreeOpen = false;
  private lastObservedProgressionLevel = this.state.progression.level;
  private pendingTechnologyUnlock: TechnologyId | null = null;
  private alertAudioContext: AudioContext | null = null;
  private menuScreen: MenuScreen = 'main';
  private slotMenuMode: SlotMenuMode = 'load';
  private previousMenuScreen: 'main' | 'pause' = 'main';
  private confirmationReturnScreen: MenuScreen = 'pause';
  private confirmationAction: ConfirmationAction | null = null;
  private pendingOverwriteSlot: SaveSlotId | null = null;
  private lastSavedFingerprint: string | null = null;

  public constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    this.saveRepository = createBrowserSaveRepository();
    this.healthOverlay = document.createElement('div');
    this.healthOverlay.id = 'unit-health-overlay';
    this.healthOverlay.setAttribute('aria-hidden', 'true');
    canvas.parentElement?.append(this.healthOverlay);

    this.engine = new Engine(canvas, true, { adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor.set(0.09, 0.075, 0.12, 1);

    this.camera = new FreeCamera('isometric-camera', this.cameraFocus.clone(), this.scene);
    this.camera.mode = FreeCamera.ORTHOGRAPHIC_CAMERA;
    this.camera.minZ = 0.1;
    this.camera.maxZ = 1000;
    this.updateCameraProjection();

    new HemisphericLight('world-light', new Vector3(0, 1, 0), this.scene).intensity = 0.9;
    this.ground = this.createWorld();
    this.totemMaterial = this.material('totem-material', '#d8904f');
    this.totem = this.createTotem();
    this.totemShadow = this.createTotemShadow();
    this.totemDirectionArrow = this.createTotemDirectionArrow();
    this.createUnits();
    this.createResourceNodes();
    this.createCampfires();

    this.previousSnapshot = this.captureSnapshot();
    this.currentSnapshot = this.captureSnapshot();
    this.bindInput();

    this.engine.runRenderLoop(this.frame);
    window.addEventListener('resize', this.resize);
    window.addEventListener('blur', this.handleWindowBlur);
    this.updateHud();
    this.renderMenu();
  }

  public destroy(): void {
    window.removeEventListener('resize', this.resize);
    window.removeEventListener('blur', this.handleWindowBlur);
    document.querySelector('#game-shell')?.removeEventListener('click', this.handleMenuClick);
    window.removeEventListener('keydown', this.handleKeyDown);
    window.removeEventListener('pointermove', this.handleHudPointerMove);
    window.removeEventListener('pointerup', this.handleHudPointerUp);
    window.removeEventListener('pointercancel', this.handleHudPointerCancel);
    this.canvas.removeEventListener('wheel', this.handleWheel);
    this.healthOverlay.remove();
    this.alertAudioContext?.close();
    this.scene.onPointerObservable.removeCallback(this.handlePointer);
    const hud = document.querySelector('#hud');
    hud?.removeEventListener('click', this.handleHudClick);
    hud?.removeEventListener('pointerdown', this.handleHudPointerDown);
    hud?.removeEventListener('input', this.handleHudInput);
    document.querySelector('#technology-hud')
      ?.removeEventListener('click', this.handleTechnologyHudClick);
    document.querySelector('#game-over-overlay')
      ?.removeEventListener('click', this.handleGameOverClick);
    this.engine.stopRenderLoop(this.frame);
    this.disposeWeatherCloudViews();
    this.scene.dispose();
    this.engine.dispose();
  }

  private readonly resize = (): void => {
    this.engine.resize();
    this.updateCameraProjection();
  };

  private readonly frame = (): void => {
    const frameSeconds = Math.min(this.engine.getDeltaTime() / 1000, 0.25);
    if (this.menuScreen === 'game') {
      this.syncCursor();
      this.updateCameraFromDragEdge(frameSeconds);
      this.queueDragFromPointer();
      this.accumulator = Math.min(
        this.accumulator + frameSeconds * this.speedMultiplier,
        FIXED_DT * MAX_STEPS_PER_FRAME,
      );

      let steps = 0;
      while (this.accumulator >= FIXED_DT && steps < MAX_STEPS_PER_FRAME) {
        this.previousSnapshot = this.currentSnapshot;
        stepSimulation(this.state, FIXED_DT, this.actionQueue.drain(), {
          enableSurvival: true,
        });
        this.currentSnapshot = this.captureSnapshot();
        this.accumulator -= FIXED_DT;
        steps += 1;
      }
    } else {
      this.accumulator = 0;
      this.actionQueue.drain();
    }

    const alpha = this.accumulator / FIXED_DT;
    this.syncCamera(frameSeconds);
    this.scene.updateTransformMatrix(true);
    this.syncView(alpha);
    this.updateHud();
    this.scene.render();
  };

  private createWorld(): Mesh {
    const ground = MeshBuilder.CreateGround('world-ground', {
      width: WORLD_SIZE,
      height: WORLD_SIZE,
      subdivisions: 1,
    }, this.scene);
    ground.position.set(WORLD_SIZE / 2, 0, WORLD_SIZE / 2);
    ground.material = this.material('ground', '#777b7d');
    this.createBiomeRegions();
    this.createDecorations();

    for (let coordinate = 0; coordinate <= WORLD_SIZE; coordinate += 10) {
      const xLine = MeshBuilder.CreateLines(`grid-x-${coordinate}`, {
        points: [new Vector3(coordinate, 0.02, 0), new Vector3(coordinate, 0.02, WORLD_SIZE)],
      }, this.scene);
      xLine.color = Color3.FromHexString('#b1b4b5');
      xLine.alpha = 0.22;

      const zLine = MeshBuilder.CreateLines(`grid-z-${coordinate}`, {
        points: [new Vector3(0, 0.02, coordinate), new Vector3(WORLD_SIZE, 0.02, coordinate)],
      }, this.scene);
      zLine.color = Color3.FromHexString('#b1b4b5');
      zLine.alpha = 0.22;
    }

    return ground;
  }

  private createBiomeRegions(): void {
    const colors: Readonly<Record<BiomeId, string>> = {
      clearing: '#6f8959',
      meadow: '#687b55',
      forest: '#3f6049',
      rocky: '#77736a',
      ruins: '#554d62',
      'great-fire': '#8b5a4a',
    };

    for (const biome of this.state.biomes) {
      const patch = MeshBuilder.CreateCylinder(`biome-${biome.instanceId}`, {
        diameter: biome.region.size,
        height: 0.06,
        tessellation: 32,
      }, this.scene);
      patch.position.set(biome.region.x, 0.04, biome.region.y);
      patch.material = this.material(
        `biome-material-${biome.instanceId}`,
        colors[biome.id],
      );
      this.biomeMeshes.set(biome.instanceId, patch);
    }
  }

  private createDecorations(): void {
    for (const decoration of this.state.decorations) {
      this.decorationMeshes.set(
        decoration.id,
        this.createDecorationMeshes(decoration),
      );
    }
  }

  private createDecorationMeshes(decoration: WorldDecoration): Mesh[] {
    const { x, y } = decoration.position;
    const scale = decoration.scale;
    const meshes: Mesh[] = [];

    if (decoration.kind === 'grass') {
      const grassMaterial = this.material(`decoration-${decoration.id}-grass-material`, '#5e9a48');
      const blades = [
        { x: -0.16, z: 0.03, tilt: -0.2 },
        { x: 0, z: -0.04, tilt: 0 },
        { x: 0.15, z: 0.05, tilt: 0.2 },
        { x: -0.04, z: 0.14, tilt: -0.1 },
        { x: 0.04, z: -0.16, tilt: 0.1 },
      ];
      for (const [index, bladeShape] of blades.entries()) {
        const blade = MeshBuilder.CreateCylinder(`decoration-${decoration.id}-grass-${index}`, {
          diameterTop: 0.025,
          diameterBottom: 0.1,
          height: 0.7,
          tessellation: 4,
        }, this.scene);
        blade.position.set(
          x + bladeShape.x * scale,
          0.35 * scale,
          y + bladeShape.z * scale,
        );
        blade.rotation.z = bladeShape.tilt;
        blade.rotation.x = bladeShape.tilt * 0.65;
        blade.material = grassMaterial;
        blade.scaling.setAll(scale);
        meshes.push(blade);
      }
    } else if (decoration.kind === 'mushroom') {
      const stem = MeshBuilder.CreateCylinder(`decoration-${decoration.id}-mushroom-stem`, {
        diameter: 0.16,
        height: 0.42,
        tessellation: 8,
      }, this.scene);
      stem.position.set(x, 0.21 * scale, y);
      stem.material = this.material(`decoration-${decoration.id}-mushroom-stem-material`, '#f2eee0');
      stem.scaling.setAll(scale);
      meshes.push(stem);

      const cap = MeshBuilder.CreateSphere(`decoration-${decoration.id}-mushroom-cap`, {
        diameter: 0.52,
        segments: 8,
      }, this.scene);
      cap.position.set(x, 0.46 * scale, y);
      cap.material = this.material(`decoration-${decoration.id}-mushroom-cap-material`, '#c64b45');
      cap.scaling.set(0.95 * scale, 0.48 * scale, 0.95 * scale);
      meshes.push(cap);

      const dotMaterial = this.material(`decoration-${decoration.id}-mushroom-dot-material`, '#fff9e8');
      for (const [index, dotPosition] of [
        { x: -0.12, z: 0.02 },
        { x: 0.1, z: 0.04 },
        { x: 0, z: -0.11 },
      ].entries()) {
        const dot = MeshBuilder.CreateSphere(`decoration-${decoration.id}-mushroom-dot-${index}`, {
          diameter: 0.1,
          segments: 6,
        }, this.scene);
        dot.position.set(
          x + dotPosition.x * scale,
          0.63 * scale,
          y + dotPosition.z * scale,
        );
        dot.material = dotMaterial;
        dot.scaling.setAll(scale);
        meshes.push(dot);
      }
    } else if (decoration.kind === 'flower') {
      const stem = MeshBuilder.CreateCylinder(`decoration-${decoration.id}-flower-stem`, {
        diameter: 0.07,
        height: 0.48,
        tessellation: 6,
      }, this.scene);
      stem.position.set(x, 0.24 * scale, y);
      stem.material = this.material(`decoration-${decoration.id}-flower-stem-material`, '#4f9a4b');
      stem.scaling.setAll(scale);
      meshes.push(stem);

      const flowerColors: Readonly<Record<NonNullable<WorldDecoration['flowerColor']>, string>> = {
        yellow: '#e5c84f',
        blue: '#5e83d8',
        gray: '#a5a8ad',
        pink: '#e879b9',
      };
      const flower = MeshBuilder.CreateSphere(`decoration-${decoration.id}-flower-head`, {
        diameter: 0.3,
        segments: 8,
      }, this.scene);
      flower.position.set(x, 0.53 * scale, y);
      flower.material = this.material(
        `decoration-${decoration.id}-flower-head-material`,
        flowerColors[decoration.flowerColor ?? 'yellow'],
      );
      flower.scaling.setAll(scale);
      meshes.push(flower);
    }

    for (const mesh of meshes) mesh.isPickable = false;
    return meshes;
  }

  private createTotem(): Mesh {
    const totem = MeshBuilder.CreateBox('totem', {
      width: 2.4,
      height: 4,
      depth: 1.6,
    }, this.scene);
    totem.material = this.totemMaterial;
    return totem;
  }

  private createTotemShadow(): Mesh {
    const shadow = MeshBuilder.CreateCylinder('totem-shadow', {
      diameter: 3.8,
      height: 0.04,
      tessellation: 32,
    }, this.scene);
    shadow.material = this.material('totem-shadow-material', '#2f2631');
    const shadowMaterial = shadow.material as StandardMaterial;
    shadowMaterial.alpha = 0.45;
    return shadow;
  }

  private createTotemDirectionArrow(): Mesh {
    const arrow = MeshBuilder.CreateLines('totem-direction-arrow', {
      points: [
        new Vector3(0, 0, 2.8),
        new Vector3(-0.65, 0, 1.9),
        new Vector3(-0.2, 0, 2.05),
        new Vector3(-0.2, 0, 0),
        new Vector3(0.2, 0, 0),
        new Vector3(0.2, 0, 2.05),
        new Vector3(0.65, 0, 1.9),
        new Vector3(0, 0, 2.8),
      ],
    }, this.scene);
    arrow.color = Color3.FromHexString('#f1d27a');
    arrow.isVisible = false;
    return arrow;
  }

  private createUnits(): void {
    for (const unit of this.state.units) {
      this.createUnitMeshes(unit);
    }
  }

  private createBarbarianMeshes(barbarian: BarbarianState): Mesh[] {
    const body = MeshBuilder.CreateCylinder(`barbarian-${barbarian.id}-body`, {
      diameter: 0.92,
      height: 1.05,
      tessellation: 10,
    }, this.scene);
    body.material = this.material(`barbarian-${barbarian.id}-body-material`, '#9b5548');
    body.isPickable = false;

    const head = MeshBuilder.CreateSphere(`barbarian-${barbarian.id}-head`, {
      diameter: 0.55,
      segments: 8,
    }, this.scene);
    head.material = this.material(`barbarian-${barbarian.id}-head-material`, '#c28c68');
    head.isPickable = false;

    const handle = MeshBuilder.CreateCylinder(`barbarian-${barbarian.id}-weapon-handle`, {
      diameter: 0.11,
      height: 0.9,
      tessellation: 6,
    }, this.scene);
    handle.material = this.material(`barbarian-${barbarian.id}-weapon-handle-material`, '#6f4b34');
    handle.isPickable = false;

    const blade = MeshBuilder.CreateBox(`barbarian-${barbarian.id}-weapon-blade`, {
      width: 0.52,
      height: 0.22,
      depth: 0.13,
    }, this.scene);
    blade.material = this.material(`barbarian-${barbarian.id}-weapon-blade-material`, '#b0a69a');
    blade.isPickable = false;

    this.createBarbarianHealthHud(barbarian);
    return [body, head, handle, blade];
  }

  private createBarbarianHealthHud(barbarian: BarbarianState): void {
    if (this.barbarianHealthHud.has(barbarian.id)) return;
    const healthRow = document.createElement('div');
    healthRow.className = 'barbarian-health-hud';
    healthRow.dataset.barbarianId = barbarian.id;
    const pips: HTMLSpanElement[] = [];
    for (let index = 0; index < barbarian.maxHealth; index += 1) {
      const pip = document.createElement('span');
      pip.className = 'barbarian-health-pip is-filled';
      healthRow.append(pip);
      pips.push(pip);
    }
    this.healthOverlay.append(healthRow);
    this.barbarianHealthHud.set(barbarian.id, healthRow);
    this.barbarianHealthPips.set(barbarian.id, pips);
  }

  private removeBarbarianHealthHud(barbarianId: string): void {
    this.barbarianHealthHud.get(barbarianId)?.remove();
    this.barbarianHealthHud.delete(barbarianId);
    this.barbarianHealthPips.delete(barbarianId);
  }

  private createAnimalMeshes(animal: AnimalState): Mesh[] {
    const body = MeshBuilder.CreateSphere(`animal-${animal.id}-body`, {
      diameter: 0.58,
      segments: 8,
    }, this.scene);
    body.scaling.set(1.3, 0.8, 0.85);
    body.material = this.material(`animal-${animal.id}-body-material`, '#e7d9bd');
    body.isPickable = false;

    const head = MeshBuilder.CreateSphere(`animal-${animal.id}-head`, {
      diameter: 0.35,
      segments: 8,
    }, this.scene);
    head.material = this.material(`animal-${animal.id}-head-material`, '#eee3ce');
    head.isPickable = false;

    const ears = Array.from({ length: 2 }, (_, index) => {
      const ear = MeshBuilder.CreateCylinder(`animal-${animal.id}-ear-${index}`, {
        diameterTop: 0.08,
        diameterBottom: 0.13,
        height: 0.42,
        tessellation: 6,
      }, this.scene);
      ear.material = head.material;
      ear.isPickable = false;
      return ear;
    });
    return [body, head, ...ears];
  }

  private createBarbarianCorpseMeshes(corpse: BarbarianCorpse): Mesh[] {
    const body = MeshBuilder.CreateCylinder(`barbarian-corpse-${corpse.id}-body`, {
      diameter: 0.74,
      height: 0.9,
      tessellation: 8,
    }, this.scene);
    body.rotation.z = Math.PI / 2;
    body.material = this.material(`barbarian-corpse-${corpse.id}-body-material`, '#63453f');
    body.isPickable = false;

    const marker = MeshBuilder.CreateTorus(`barbarian-corpse-${corpse.id}-loot-marker`, {
      diameter: 0.46,
      thickness: 0.09,
      tessellation: 8,
    }, this.scene);
    marker.rotation.x = Math.PI / 2;
    const markerMaterial = this.material(`barbarian-corpse-${corpse.id}-loot-material`, '#e6bf5b');
    markerMaterial.emissiveColor = Color3.FromHexString('#8d6d22');
    marker.material = markerMaterial;
    marker.isPickable = false;
    return [body, marker];
  }

  private createActionRangeRing(name: string, color: string): Mesh {
    const ring = MeshBuilder.CreateTorus(name, {
      diameter: 2,
      thickness: 0.045,
      tessellation: 64,
    }, this.scene);
    ring.material = this.material(`${name}-material`, color);
    (ring.material as StandardMaterial).alpha = 0.35;
    ring.isPickable = false;
    return ring;
  }

  private createUnitMeshes(unit: GameState['units'][number]): void {
    const mesh = MeshBuilder.CreateCylinder(`unit-${unit.id}`, {
      diameter: 0.9,
      height: 0.7,
      tessellation: 16,
    }, this.scene);
    mesh.material = this.material(
      `unit-material-${unit.id}`,
      this.unitRoleColor(unit.role),
    );
    this.units.set(unit.id, mesh);

    const healthRow = document.createElement('div');
    healthRow.className = 'unit-health-hud';
    healthRow.dataset.unitId = unit.id;
    const healthPips: HTMLSpanElement[] = [];
    for (let index = 0; index < unit.maxHealth; index += 1) {
      const pip = document.createElement('span');
      pip.className = 'unit-health-pip is-filled';
      healthRow.append(pip);
      healthPips.push(pip);
    }
    this.healthOverlay.append(healthRow);
    this.unitHealthHud.set(unit.id, healthRow);
    this.unitHealthPips.set(unit.id, healthPips);

    const detection = this.createActionRangeRing(`unit-detection-${unit.id}`, '#f1d27a');
    detection.position.y = 0.08;
    this.unitDetectionMeshes.set(unit.id, detection);
  }

  private createUnitShieldMeshes(unitId: string): Mesh[] {
    const shield = MeshBuilder.CreateCylinder(`unit-${unitId}-shield`, {
      diameter: 0.76,
      height: 0.14,
      tessellation: 16,
    }, this.scene);
    shield.rotation.x = Math.PI / 2;
    shield.rotation.y = CAMERA_YAW;
    shield.material = this.material(`unit-${unitId}-shield-wood`, '#81512f');
    shield.isPickable = false;

    const stud = MeshBuilder.CreateSphere(`unit-${unitId}-shield-stud`, {
      diameter: 0.2,
      segments: 10,
    }, this.scene);
    stud.material = this.material(`unit-${unitId}-shield-metal`, '#a5a5a2');
    stud.isPickable = false;
    const meshes = [shield, stud];
    this.unitShieldMeshes.set(unitId, meshes);
    return meshes;
  }

  private unitRoleColor(role: GameState['units'][number]['role']): string {
    return {
      gatherer: '#f1d27a',
      lumberjack: '#b98158',
      hunter: '#8ed6d1',
      explorer: '#a7a0d8',
      guardian: '#d27575',
      artisan: '#d79aff',
    }[role];
  }

  private createResourceNodes(): void {
    for (const resource of this.state.resources) {
      this.resourceMeshes.set(resource.id, this.createResourceMesh(resource));
    }
  }

  private createCampfires(): void {
    for (const campfire of this.state.campfires) {
      this.campfireMeshes.set(
        campfire.id,
        this.createCampfireMeshes(campfire.id, campfire.position, false, campfire.healingRadius),
      );
    }
  }

  private createCampfireMeshes(
    id: string,
    position: Vec2,
    isPreview = false,
    healingRadius = CAMPFIRE_HEALING_RADIUS,
  ): Mesh[] {
    const base = MeshBuilder.CreateCylinder(`campfire-${id}-base`, {
      diameter: 1.8,
      height: 0.18,
      tessellation: 12,
    }, this.scene);
    const logA = MeshBuilder.CreateBox(`campfire-${id}-log-a`, {
      width: 1.35,
      height: 0.22,
      depth: 0.28,
    }, this.scene);
    const logB = MeshBuilder.CreateBox(`campfire-${id}-log-b`, {
      width: 1.35,
      height: 0.22,
      depth: 0.28,
    }, this.scene);
    const flame = MeshBuilder.CreateCylinder(`campfire-${id}-flame`, {
      diameterTop: 0.05,
      diameterBottom: 0.72,
      height: 1.05,
      tessellation: 6,
    }, this.scene);

    base.material = this.material(`campfire-${id}-base-material`, '#2f2631');
    logA.material = this.material(`campfire-${id}-log-a-material`, '#9a6b43');
    logB.material = this.material(`campfire-${id}-log-b-material`, '#9a6b43');
    flame.material = this.material(`campfire-${id}-flame-material`, '#ef5b2a');

    // Use the exact same base ring as minions; only the material color changes.
    const healingRange = this.createActionRangeRing(
      `campfire-${id}-healing-range`,
      '#74db6a',
    );
    const visibleRange = getResourceDetectionRadius(healingRadius);
    healingRange.scaling.set(visibleRange, 1, visibleRange);

    const meshes = [base, logA, logB, flame, healingRange];
    for (const mesh of meshes) mesh.isPickable = false;

    if (isPreview) {
      for (const mesh of meshes) {
        const material = mesh.material as StandardMaterial;
        material.alpha = 0.48;
      }
    }

    this.positionCampfireMeshes(meshes, position);
    return meshes;
  }

  private positionCampfireMeshes(
    meshes: readonly Mesh[],
    position: Vec2,
    verticalOffset = 0,
  ): void {
    const [base, logA, logB, flame, healingRange] = meshes;
    base.position.set(position.x, 0.12 + verticalOffset, position.y);
    logA.position.set(position.x, 0.31 + verticalOffset, position.y);
    logA.rotation.y = Math.PI / 4;
    logB.position.set(position.x, 0.38 + verticalOffset, position.y);
    logB.rotation.y = -Math.PI / 4;
    flame.position.set(position.x, 0.86 + verticalOffset, position.y);
    healingRange?.position.set(position.x, 0.06 + verticalOffset, position.y);
  }

  private createHudHeldItemMeshes(item: HudBuildItem): Mesh[] {
    if (item === 'campfire') {
      const meshes = this.createCampfireMeshes('hud-held-campfire', { x: 0, y: 0 }, true);
      for (const mesh of meshes) mesh.scaling.setAll(HUD_HELD_ITEM_SCALE);
      return meshes;
    }

    if (item === 'gatherer') {
      const gatherer = MeshBuilder.CreateCylinder('hud-held-gatherer', {
        diameter: 0.9,
        height: 0.7,
        tessellation: 16,
      }, this.scene);
      gatherer.material = this.material('hud-held-gatherer-material', '#f1d27a');
      gatherer.scaling.setAll(HUD_HELD_ITEM_SCALE);
      gatherer.isPickable = false;
      return [gatherer];
    }

    if (item === 'axe') {
      const handle = MeshBuilder.CreateCylinder('hud-held-axe-handle', {
        diameter: 0.14,
        height: 1.35,
        tessellation: 8,
      }, this.scene);
      const head = MeshBuilder.CreateBox('hud-held-axe-head', {
        width: 0.62,
        height: 0.28,
        depth: 0.2,
      }, this.scene);
      handle.material = this.material('hud-held-axe-handle-material', '#9a6b43');
      head.material = this.material('hud-held-axe-head-material', '#a5a5a2');
      handle.rotation.z = -Math.PI / 14;
      head.rotation.z = -Math.PI / 14;
      handle.scaling.setAll(HUD_HELD_ITEM_SCALE);
      head.scaling.setAll(HUD_HELD_ITEM_SCALE);
      handle.isPickable = false;
      head.isPickable = false;
      return [handle, head];
    }

    if (item === 'hammer') {
      const handle = MeshBuilder.CreateCylinder('hud-held-hammer-handle', {
        diameter: 0.13,
        height: 0.9,
        tessellation: 8,
      }, this.scene);
      const head = MeshBuilder.CreateBox('hud-held-hammer-head', {
        width: 0.68,
        height: 0.3,
        depth: 0.28,
      }, this.scene);
      handle.material = this.material('hud-held-hammer-handle-material', '#9a6b43');
      head.material = this.material('hud-held-hammer-head-material', '#a5a5a2');
      handle.scaling.setAll(HUD_HELD_ITEM_SCALE);
      head.scaling.setAll(HUD_HELD_ITEM_SCALE);
      handle.isPickable = false;
      head.isPickable = false;
      return [handle, head];
    }

    if (item === 'shield') {
      const shield = MeshBuilder.CreateCylinder('hud-held-shield-wood', {
        diameter: 0.9,
        height: 0.15,
        tessellation: 16,
      }, this.scene);
      shield.rotation.x = Math.PI / 2;
      shield.rotation.y = CAMERA_YAW;
      const stud = MeshBuilder.CreateSphere('hud-held-shield-stud', {
        diameter: 0.2,
        segments: 10,
      }, this.scene);
      shield.material = this.material('hud-held-shield-wood-material', '#81512f');
      stud.material = this.material('hud-held-shield-stud-material', '#a5a5a2');
      shield.scaling.setAll(HUD_HELD_ITEM_SCALE);
      stud.scaling.setAll(HUD_HELD_ITEM_SCALE);
      shield.isPickable = false;
      stud.isPickable = false;
      return [shield, stud];
    }

    if (item === 'sword') {
      const blade = MeshBuilder.CreateBox('hud-held-sword-blade', {
        width: 0.26,
        height: 1.05,
        depth: 0.09,
      }, this.scene);
      const grip = MeshBuilder.CreateCylinder('hud-held-sword-grip', {
        diameter: 0.12,
        height: 0.5,
        tessellation: 8,
      }, this.scene);
      const guard = MeshBuilder.CreateBox('hud-held-sword-guard', {
        width: 0.55,
        height: 0.1,
        depth: 0.13,
      }, this.scene);
      blade.material = this.material('hud-held-sword-blade-material', '#d7d5cd');
      grip.material = this.material('hud-held-sword-grip-material', '#9a6b43');
      guard.material = this.material('hud-held-sword-guard-material', '#514943');
      for (const mesh of [blade, grip, guard]) {
        mesh.scaling.setAll(HUD_HELD_ITEM_SCALE);
        mesh.isPickable = false;
      }
      return [blade, grip, guard];
    }

    // One continuous, rounded stave: the limbs narrow toward both nocks and
    // swell into a short central grip, instead of reading as two thin lines.
    const bowPoints: Vector3[] = [];
    const stavePointCount = 33;
    const bowCenterX = 0.4;
    const bowCenterY = 0.95;
    const bowHalfWidth = 0.8;
    const bowHalfHeight = 0.88;
    for (let index = 0; index < stavePointCount; index += 1) {
      const angle = Math.PI / 2 - (index / (stavePointCount - 1)) * Math.PI;
      bowPoints.push(new Vector3(
        bowCenterX - bowHalfWidth * Math.cos(angle),
        bowCenterY + bowHalfHeight * Math.sin(angle),
        0,
      ));
    }
    const stave = MeshBuilder.CreateTube('hud-held-bow-wood-stave', {
      path: bowPoints,
      radius: 0.07,
      radiusFunction: (index) => {
        const limbPosition = index / (stavePointCount - 1);
        const taper = Math.sin(Math.PI * limbPosition);
        return 0.024 + 0.052 * Math.pow(taper, 0.7);
      },
      tessellation: 12,
      cap: Mesh.CAP_ALL,
    }, this.scene);
    stave.material = this.material('hud-held-bow-wood-material', '#81512f');

    const upperTip = bowPoints[0];
    const lowerTip = bowPoints[bowPoints.length - 1];
    const string = MeshBuilder.CreateTube('hud-held-bow-taut-string', {
      path: [upperTip, lowerTip],
      radius: 0.012,
      tessellation: 8,
      cap: Mesh.CAP_ALL,
    }, this.scene);
    string.material = this.material('hud-held-bow-string-material', '#e8d8a6');

    // The grip follows the stave's tangent at its midpoint and is seated on
    // the front of the wood, with two subtle wraps anchoring its ends.
    const grip = MeshBuilder.CreateCylinder('hud-held-bow-grip', {
      diameter: 0.15,
      height: 0.34,
      tessellation: 10,
    }, this.scene);
    grip.material = this.material('hud-held-bow-grip-material', '#888681');
    const gripUpperWrap = MeshBuilder.CreateCylinder('hud-held-bow-grip-upper-wrap', {
      diameter: 0.17,
      height: 0.035,
      tessellation: 10,
    }, this.scene);
    const gripLowerWrap = MeshBuilder.CreateCylinder('hud-held-bow-grip-lower-wrap', {
      diameter: 0.17,
      height: 0.035,
      tessellation: 10,
    }, this.scene);
    gripUpperWrap.material = this.material('hud-held-bow-grip-wrap-material', '#585653');
    gripLowerWrap.material = gripUpperWrap.material;

    // Small dark nock wraps make the string's attachment points legible.
    const upperNock = MeshBuilder.CreateSphere('hud-held-bow-upper-nock', {
      diameter: 0.085,
      segments: 8,
    }, this.scene);
    const lowerNock = MeshBuilder.CreateSphere('hud-held-bow-lower-nock', {
      diameter: 0.085,
      segments: 8,
    }, this.scene);
    const nockMaterial = this.material('hud-held-bow-nock-material', '#503a29');
    upperNock.material = nockMaterial;
    lowerNock.material = nockMaterial;

    const meshes = [stave, string, grip, gripUpperWrap, gripLowerWrap, upperNock, lowerNock];
    for (const mesh of meshes) {
      mesh.scaling.setAll(HUD_HELD_ITEM_SCALE);
      mesh.isPickable = false;
    }
    return meshes;
  }

  private positionHudHeldItem(item: HudBuildItem, position: Vec2): void {
    if (this.hudHeldItemMeshes.length === 0) return;

    if (item === 'campfire') {
      this.positionCampfireMeshes(this.hudHeldItemMeshes, position, HUD_HELD_ITEM_LIFT);
      return;
    }

    if (item === 'gatherer') {
      this.hudHeldItemMeshes[0].position.set(position.x, HUD_HELD_ITEM_LIFT, position.y);
      return;
    }

    if (item === 'axe') {
      // Keep the handle attached to one side of the head so the silhouette
      // reads as an axe instead of a centered hammer.
      this.hudHeldItemMeshes[0].position.set(position.x - 0.22, 0.9, position.y);
      this.hudHeldItemMeshes[1].position.set(position.x + 0.15, 1.42, position.y);
      return;
    }

    if (item === 'hammer') {
      this.hudHeldItemMeshes[0].position.set(position.x, 0.76, position.y);
      this.hudHeldItemMeshes[1].position.set(position.x, 1.38, position.y);
      return;
    }

    if (item === 'shield') {
      this.hudHeldItemMeshes[0].position.set(position.x, 0.85, position.y);
      this.hudHeldItemMeshes[1].position.set(
        position.x,
        0.85,
        position.y + 0.13 * HUD_HELD_ITEM_SCALE,
      );
      return;
    }

    if (item === 'sword') {
      this.hudHeldItemMeshes[0].position.set(position.x, 1.3, position.y);
      this.hudHeldItemMeshes[1].position.set(position.x, 0.48, position.y);
      this.hudHeldItemMeshes[2].position.set(position.x, 0.92, position.y);
      return;
    }

    const scale = HUD_HELD_ITEM_SCALE;
    const originY = 0.35;
    const originZ = position.y;
    this.hudHeldItemMeshes[0].position.set(position.x, originY, originZ);
    this.hudHeldItemMeshes[1].position.set(position.x, originY, originZ + 0.035 * scale);
    this.hudHeldItemMeshes[2].position.set(position.x - 0.4 * scale, originY + 0.95 * scale, originZ + 0.105 * scale);
    this.hudHeldItemMeshes[3].position.set(position.x - 0.4 * scale, originY + (0.95 + 0.17) * scale, originZ + 0.105 * scale);
    this.hudHeldItemMeshes[4].position.set(position.x - 0.4 * scale, originY + (0.95 - 0.17) * scale, originZ + 0.105 * scale);
    this.hudHeldItemMeshes[5].position.set(position.x + 0.4 * scale, originY + (0.95 + 0.88) * scale, originZ + 0.02 * scale);
    this.hudHeldItemMeshes[6].position.set(position.x + 0.4 * scale, originY + (0.95 - 0.88) * scale, originZ + 0.02 * scale);
  }

  private syncHudHeldItemView(): void {
    const visible = this.hudItemDragging !== null
      && this.hudPreviewPosition !== null
      && this.hudHeldItemMeshes.length > 0;
    for (const mesh of this.hudHeldItemMeshes) mesh.isVisible = visible;
    if (visible && this.hudItemDragging && this.hudPreviewPosition) {
      this.positionHudHeldItem(this.hudItemDragging, this.hudPreviewPosition);
    }
  }

  private disposeHudHeldItem(): void {
    for (const mesh of this.hudHeldItemMeshes) mesh.dispose(false, true);
    this.hudHeldItemMeshes = [];
  }

  private createResourceDropMesh(drop: ResourceDrop): Mesh {
    const mesh = MeshBuilder.CreateCylinder(`resource-drop-${drop.id}`, {
      diameter: 0.9,
      height: 0.22,
      tessellation: 12,
    }, this.scene);
    mesh.position.set(drop.position.x, 0.18, drop.position.y);
    mesh.material = this.material(
      `resource-drop-material-${drop.id}`,
      this.resourceTypeColor(drop.type),
    );
    return mesh;
  }

  private resourceTypeColor(type: ResourceType): string {
    return {
      food: '#d95c5c',
      wood: '#9a6b43',
      stone: '#c2c2bd',
      spark: '#d79aff',
      gold: '#e6bf5b',
    }[type];
  }

  private createResourceMesh(resource: ResourceNode): Mesh[] {
    const position = new Vector3(resource.position.x, 0, resource.position.y);

    if (resource.source === 'twigs') {
      const twigScale = 1.5;
      const twigModel = [
        { x: -0.18, z: 0.04, length: 0.78, angle: 0.28 },
        { x: 0.14, z: -0.08, length: 0.94, angle: -0.42 },
        { x: 0.02, z: 0.16, length: 0.62, angle: 0.88 },
      ];
      const bundleOffsets = [
        { x: -0.62, z: -0.36, rotation: -0.45 },
        { x: 0.62, z: -0.36, rotation: 0.4 },
        { x: 0, z: 0.76, rotation: 1.0 },
      ];

      return bundleOffsets.flatMap((offset, bundleIndex) => {
        const bundle = new TransformNode(
          `resource-${resource.id}-twig-bundle-${bundleIndex}`,
          this.scene,
        );
        bundle.position.set(position.x + offset.x, 0.08 * twigScale, position.z + offset.z);
        bundle.rotation.y = offset.rotation;
        bundle.scaling.setAll(twigScale);

        return twigModel.map((twig, twigIndex) => {
          const mesh = MeshBuilder.CreateCylinder(
            `resource-${resource.id}-twig-${bundleIndex}-${twigIndex}`,
            { diameter: 0.12, height: twig.length, tessellation: 5 },
            this.scene,
          );
          mesh.position.set(twig.x, twigIndex * 0.012, twig.z);
          mesh.rotation.z = Math.PI / 2;
          mesh.rotation.y = twig.angle;
          mesh.material = this.material(`resource-twigs-material-${resource.id}`, '#79502f');
          mesh.parent = bundle;
          return mesh;
        });
      });
    }

    if (resource.source === 'berry-bush') {
      const root = MeshBuilder.CreateCylinder(`resource-${resource.id}-root`, {
        diameter: 1.55,
        height: 0.26,
        tessellation: 8,
      }, this.scene);
      root.position.set(position.x, 0.18, position.z);
      root.material = this.material(`resource-root-material-${resource.id}`, '#2f5133');

      const foliage: Mesh[] = [root];
      const foliageMaterialColors = ['#3f7948', '#4d8a4d', '#376b42'];
      const foliageParts = [
        { x: -0.48, y: 0.55, z: 0.08, scale: 1.02 },
        { x: 0.46, y: 0.6, z: 0.12, scale: 0.94 },
        { x: 0.02, y: 0.86, z: -0.24, scale: 0.8 },
      ];
      for (const [index, part] of foliageParts.entries()) {
        const leafCluster = MeshBuilder.CreateSphere(`resource-${resource.id}-foliage-${index}`, {
          diameter: 1.18,
          segments: 8,
        }, this.scene);
        leafCluster.position.set(
          position.x + part.x,
          part.y,
          position.z + part.z,
        );
        leafCluster.scaling.set(part.scale, part.scale * 0.88, part.scale);
        leafCluster.material = this.material(
          `resource-foliage-material-${resource.id}-${index}`,
          foliageMaterialColors[index],
        );
        foliage.push(leafCluster);
      }

      // The node contains one logical berry, so only one berry is shown.
      const berry = MeshBuilder.CreateSphere(`resource-${resource.id}-berry`, {
        diameter: 0.34,
        segments: 8,
      }, this.scene);
      // Place the single berry on the camera-facing central face of the bush
      // so it remains readable against the foliage from the isometric view.
      berry.position.set(position.x + 0.25, 1.1, position.z + 0.25);
      berry.material = this.material(`resource-berry-material-${resource.id}`, '#d95c5c');
      foliage.push(berry);
      return foliage;
    }

    if (resource.source === 'tree') {
      const trunk = MeshBuilder.CreateCylinder(`resource-${resource.id}-trunk`, {
        diameter: 0.42,
        height: 2.2,
        tessellation: 8,
      }, this.scene);
      trunk.position.set(position.x, 1.1, position.z);
      trunk.material = this.material(`resource-tree-trunk-material-${resource.id}`, '#755033');

      const canopyMaterial = this.material(
        `resource-tree-canopy-material-${resource.id}`,
        '#3f7548',
      );
      const canopyParts = [
        { x: 0, y: 2.15, z: 0, diameter: 1.65 },
        { x: -0.42, y: 1.75, z: 0.08, diameter: 1.25 },
        { x: 0.4, y: 1.8, z: -0.06, diameter: 1.22 },
      ];
      const canopy = canopyParts.map((part, index) => {
        const cluster = MeshBuilder.CreateSphere(
          `resource-${resource.id}-canopy-${index}`,
          { diameter: part.diameter, segments: 8 },
          this.scene,
        );
        cluster.position.set(position.x + part.x, part.y, position.z + part.z);
        cluster.material = canopyMaterial;
        return cluster;
      });

      return [trunk, ...canopy];
    }

    if (resource.source === 'stone-vein') {
      const rockMaterial = this.material(
        `resource-stone-material-${resource.id}`,
        '#a5a5a2',
      );
      const rockParts = [
        { x: 0, y: 0.48, z: 0, size: 0.95 },
        { x: -0.58, y: 0.3, z: 0.12, size: 0.58 },
        { x: 0.52, y: 0.34, z: -0.08, size: 0.66 },
      ];
      return rockParts.map((part, index) => {
        const rock = MeshBuilder.CreateBox(`resource-${resource.id}-rock-${index}`, {
          width: part.size,
          height: part.size * 0.82,
          depth: part.size,
        }, this.scene);
        rock.position.set(position.x + part.x, part.y, position.z + part.z);
        rock.rotation.y = index === 1 ? 0.18 : index === 2 ? -0.12 : 0;
        rock.material = rockMaterial;
        return rock;
      });
    }

    if (resource.source === 'ruin') {
      const diamond = MeshBuilder.CreatePolyhedron(`resource-${resource.id}-diamond`, {
        type: 1,
        size: 0.72,
      }, this.scene);
      diamond.position.set(position.x, 1.45, position.z);
      diamond.scaling.set(0.8, 1.28, 0.8);
      diamond.rotation.y = Math.PI / 4;
      const diamondMaterial = this.material(
        `resource-spark-material-${resource.id}`,
        '#e6b5ff',
      );
      diamondMaterial.emissiveColor = Color3.FromHexString('#d79aff');
      diamond.material = diamondMaterial;

      const innerDiamond = MeshBuilder.CreatePolyhedron(
        `resource-${resource.id}-diamond-core`,
        { type: 1, size: 0.34 },
        this.scene,
      );
      innerDiamond.position.copyFrom(diamond.position);
      innerDiamond.scaling.set(0.8, 1.28, 0.8);
      innerDiamond.rotation.y = Math.PI / 4;
      const coreMaterial = this.material(
        `resource-spark-core-material-${resource.id}`,
        '#fff0ff',
      );
      coreMaterial.emissiveColor = Color3.FromHexString('#fff0ff');
      innerDiamond.material = coreMaterial;

      const halo = MeshBuilder.CreateTorus(`resource-${resource.id}-spark-halo`, {
        diameter: 1.35,
        thickness: 0.055,
        tessellation: 32,
      }, this.scene);
      halo.position.set(position.x, 1.42, position.z);
      halo.rotation.x = Math.PI / 2;
      const haloMaterial = this.material(
        `resource-spark-halo-material-${resource.id}`,
        '#d79aff',
      );
      haloMaterial.emissiveColor = Color3.FromHexString('#d79aff');
      haloMaterial.alpha = 0.72;
      halo.material = haloMaterial;

      return [diamond, innerDiamond, halo];
    }

    return [];
  }

  private bindInput(): void {
    this.scene.onPointerObservable.add(this.handlePointer);
    window.addEventListener('keydown', this.handleKeyDown);
    window.addEventListener('pointermove', this.handleHudPointerMove);
    window.addEventListener('pointerup', this.handleHudPointerUp);
    window.addEventListener('pointercancel', this.handleHudPointerCancel);
    this.canvas.addEventListener('wheel', this.handleWheel, { passive: false });
    const hud = document.querySelector('#hud');
    hud?.addEventListener('click', this.handleHudClick);
    hud?.addEventListener('pointerdown', this.handleHudPointerDown);
    hud?.addEventListener('input', this.handleHudInput);
    document.querySelector('#technology-hud')
      ?.addEventListener('click', this.handleTechnologyHudClick);
    document.querySelector('#game-over-overlay')
      ?.addEventListener('click', this.handleGameOverClick);
    document.querySelector('#game-shell')
      ?.addEventListener('click', this.handleMenuClick);
  }

  private readonly handleHudPointerDown = (event: Event): void => {
    this.unlockCombatAlertAudio();
    const pointerEvent = event as PointerEvent;
    const target = pointerEvent.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>('[data-build-item]');
    const item = button?.dataset.buildItem as HudBuildItem | undefined;
    if (!button || !item || button.disabled || this.state.phase !== 'playing') return;

    pointerEvent.preventDefault();
    this.hudItemDragging = item;
    this.hudPointerId = pointerEvent.pointerId;
    this.hudPointerTarget = button;
    button.classList.add('is-dragging');
    button.setPointerCapture(pointerEvent.pointerId);
    this.hudPreviewPosition = this.pickGroundPositionAt(
      pointerEvent.clientX,
      pointerEvent.clientY,
    );
    this.hudHeldItemMeshes = this.createHudHeldItemMeshes(item);
    this.syncHudHeldItemView();
  };

  private readonly handleHudPointerMove = (event: PointerEvent): void => {
    if (!this.hudItemDragging || event.pointerId !== this.hudPointerId) return;
    this.hudPreviewPosition = this.pickGroundPositionAt(event.clientX, event.clientY);
    this.syncHudHeldItemView();
    event.preventDefault();
  };

  private readonly handleHudPointerUp = (event: PointerEvent): void => {
    if (!this.hudItemDragging || event.pointerId !== this.hudPointerId) return;

    const item = this.hudItemDragging;
    const position = this.pickGroundPositionAt(event.clientX, event.clientY);
    const canDropOnMap = this.isPointerOverCanvas(event.clientX, event.clientY);
    if (canDropOnMap && this.state.phase === 'playing') {
      if (item === 'campfire' && position) {
        this.actionQueue.enqueue({ type: 'place-campfire', position });
      } else if (item === 'gatherer' && position) {
        this.actionQueue.enqueue({ type: 'recruit-gatherer', position });
      } else if (item === 'shield') {
        const unitId = this.pickUnitIdAt(event.clientX, event.clientY);
        if (unitId) this.actionQueue.enqueue({ type: 'equip-shield', unitId });
      } else if (item === 'axe' || item === 'bow' || item === 'sword' || item === 'hammer') {
        const unitId = this.pickUnitIdAt(event.clientX, event.clientY);
        if (unitId) {
          this.actionQueue.enqueue({ type: 'transform-unit', item, unitId });
        }
      }
    }

    this.endHudPlacement();
    event.preventDefault();
  };

  private readonly handleHudPointerCancel = (event: PointerEvent): void => {
    if (!this.hudItemDragging || event.pointerId !== this.hudPointerId) return;
    this.endHudPlacement();
  };

  private endHudPlacement(): void {
    if (this.hudPointerTarget?.hasPointerCapture(this.hudPointerId ?? -1)) {
      this.hudPointerTarget.releasePointerCapture(this.hudPointerId ?? -1);
    }
    this.hudPointerTarget?.classList.remove('is-dragging');
    this.disposeHudHeldItem();
    this.hudItemDragging = null;
    this.hudPointerId = null;
    this.hudPointerTarget = null;
    this.hudPreviewPosition = null;
    this.canvas.style.cursor = 'default';
  }

  private readonly handlePointer = (pointerInfo: PointerInfo): void => {
    if (pointerInfo.type === PointerEventTypes.POINTERDOWN) {
      this.unlockCombatAlertAudio();
    }
    const pointerEvent = pointerInfo.event as PointerEvent;
    if (this.hudItemDragging) return;

    if (pointerInfo.type === PointerEventTypes.POINTERDOWN) {
      if (this.state.phase !== 'playing' || this.dragging) return;
      const pick = this.scene.pick(
        this.scene.pointerX,
        this.scene.pointerY,
        (mesh) => mesh === this.totem,
      );
      if (!pick?.hit) return;

      this.dragging = true;
      this.cameraRecentering = false;
      const initialPointerPosition = this.pickGroundPosition();
      this.lastDragPosition = initialPointerPosition ?? { ...this.state.totem.position };
      this.lastDragDirection = { x: 0, y: 1 };
      this.canvas.style.cursor = 'grabbing';
      this.actionQueue.enqueue({ type: 'pick-up-totem' });
      if (initialPointerPosition) {
        this.actionQueue.enqueue({ type: 'drag-totem', position: initialPointerPosition });
      }
      if (pointerEvent.pointerId !== undefined) {
        this.canvas.setPointerCapture(pointerEvent.pointerId);
      }
      return;
    }

    if (pointerInfo.type === PointerEventTypes.POINTERMOVE) {
      if (this.dragging) this.queueDragFromPointer();
      else this.updateCursorFromPointer();
      return;
    }

    if (pointerInfo.type === PointerEventTypes.POINTERUP && this.dragging) {
      // Pointerup can arrive without a final pointermove, especially when the
      // pointer is released at the edge of the canvas. Capture that position
      // before ending the drag so the drop uses the latest valid target.
      this.queueDragFromPointer();
      this.dragging = false;
      this.cameraRecentering = true;
      this.canvas.style.cursor = 'default';
      this.actionQueue.enqueue({
        type: 'drop-totem',
        position: this.lastDragPosition,
      });
      if (pointerEvent.pointerId !== undefined && this.canvas.hasPointerCapture(pointerEvent.pointerId)) {
        this.canvas.releasePointerCapture(pointerEvent.pointerId);
      }
    }
  };

  private readonly handleKeyDown = (event: KeyboardEvent): void => {
    if (event.key === 'Escape') {
      if (!event.repeat) this.handleEscape();
      event.preventDefault();
      return;
    }

    if (this.menuScreen !== 'game') return;
    this.unlockCombatAlertAudio();

    if (event.key === '1' || event.key === '2' || event.key === '3') {
      this.speedMultiplier = Number(event.key);
      event.preventDefault();
      return;
    }

    if (event.key === '+' || event.key === '=') {
      this.zoom = clamp(this.zoom - 0.1, this.cameraZoomMin, this.cameraZoomMax);
      this.updateCameraProjection();
      event.preventDefault();
      return;
    }

    if (event.key === '-') {
      this.zoom = clamp(this.zoom + 0.1, this.cameraZoomMin, this.cameraZoomMax);
      this.updateCameraProjection();
      event.preventDefault();
    }
  };

  private readonly handleWheel = (event: WheelEvent): void => {
    this.zoom = clamp(
      this.zoom + (event.deltaY > 0 ? 0.1 : -0.1),
      this.cameraZoomMin,
      this.cameraZoomMax,
    );
    this.updateCameraProjection();
    event.preventDefault();
  };

  private readonly handleHudClick = (event: Event): void => {
    const target = event.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>('button');
    if (!button) return;

    if (button.dataset.debugAction === 'damage-one-minion') {
      this.actionQueue.enqueue({ type: 'debug-damage-one-minion' });
      return;
    }

    if (button.dataset.debugAction === 'level-up') {
      this.actionQueue.enqueue({ type: 'debug-level-up' });
      return;
    }

    const debugResource = button.dataset.debugResource as ResourceType | undefined;
    if (debugResource && RESOURCE_TYPES.includes(debugResource)) {
      this.actionQueue.enqueue({
        type: 'debug-add-resource',
        resource: debugResource,
        amount: 10,
      });
      return;
    }

    if (button.dataset.action === 'pause') {
      if (this.state.phase === 'playing') this.openPauseMenu();
      else if (this.state.phase === 'paused') this.resumeGame();
      return;
    }

    const speed = Number(button.dataset.speed);
    if (speed === 1 || speed === 2 || speed === 3) {
      this.speedMultiplier = speed;
      if (this.state.phase === 'paused') {
        this.actionQueue.enqueue({ type: 'toggle-pause' });
      }
    }
  };

  private readonly handleTechnologyHudClick = (event: Event): void => {
    event.stopPropagation();
    const target = event.target as HTMLElement;
    if (target.closest<HTMLButtonElement>('[data-technology-toggle]')) {
      this.technologyTreeOpen = !this.technologyTreeOpen;
      this.updateHud();
      return;
    }

    const button = target.closest<HTMLButtonElement>('[data-unlock-technology]');
    const technology = button?.dataset.unlockTechnology as TechnologyId | undefined;
    if (
      !button
      || button.disabled
      || (technology !== 'artisan' && technology !== 'shield')
    ) return;

    this.pendingTechnologyUnlock = technology;
    this.actionQueue.enqueue({ type: 'unlock-technology', technology });
  };

  private readonly handleGameOverClick = (event: Event): void => {
    const target = event.target as HTMLElement;
    if (target.closest<HTMLButtonElement>('[data-action="restart"]')) {
      this.startNewGame();
    }
  };

  private readonly handleMenuClick = (event: Event): void => {
    const target = event.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>('[data-menu-action]');
    const action = button?.dataset.menuAction;
    if (!button || !action) return;

    switch (action) {
      case 'play':
        this.startNewGame();
        break;
      case 'tutorial':
        this.setMenuScreen('tutorial');
        break;
      case 'open-load':
        this.openSlotMenu('load');
        break;
      case 'open-save':
        if (this.menuScreen === 'pause') this.openSlotMenu('save');
        break;
      case 'resume':
        this.resumeGame();
        break;
      case 'exit':
        this.requestExitToMenu();
        break;
      case 'back-main':
        this.setMenuScreen('main');
        break;
      case 'back':
        this.setMenuScreen(this.previousMenuScreen);
        break;
      case 'save-slot':
      case 'load-slot': {
        const slot = Number(button.dataset.slot) as SaveSlotId;
        if (!getSaveSlotIds().includes(slot)) return;
        if (action === 'save-slot') this.selectSaveSlot(slot);
        else this.selectLoadSlot(slot);
        break;
      }
      case 'confirm-confirmation':
        this.confirmPendingAction();
        break;
      case 'cancel-confirmation':
        this.cancelPendingAction();
        break;
      default:
        break;
    }
  };

  private handleEscape(): void {
    switch (this.menuScreen) {
      case 'game':
        if (this.state.phase === 'playing') this.openPauseMenu();
        break;
      case 'pause':
        this.resumeGame();
        break;
      case 'tutorial':
        this.setMenuScreen('main');
        break;
      case 'slots':
        this.setMenuScreen(this.previousMenuScreen);
        break;
      case 'confirmation':
        this.cancelPendingAction();
        break;
      case 'main':
        break;
    }
  }

  private openPauseMenu(): void {
    this.endHudPlacement();
    this.actionQueue.drain();
    if (this.state.totem.isCarried) {
      this.state.totem.position = { ...this.lastDragPosition };
      this.state.totem.dragTarget = { ...this.lastDragPosition };
      this.state.totem.destination = null;
      this.state.totem.moving = false;
      this.state.totem.isCarried = false;
    }
    this.dragging = false;
    this.state.phase = 'paused';
    this.setMenuScreen('pause');
  }

  private resumeGame(): void {
    if (this.state.phase === 'paused') this.state.phase = 'playing';
    this.setMenuScreen('game');
  }

  private startNewGame(): void {
    this.resetGame(createInitialState());
    this.lastSavedFingerprint = null;
    this.state.phase = 'playing';
    this.setMenuScreen('game');
  }

  private startLoadedGame(state: GameState): void {
    const restored = JSON.parse(JSON.stringify(state)) as GameState;
    restored.phase = 'playing';
    this.resetGame(restored);
    this.lastSavedFingerprint = getSaveFingerprint(restored);
    this.speedMultiplier = 1;
    this.zoom = DEFAULT_CAMERA_ZOOM_MIN;
    this.updateCameraProjection();
    this.setMenuScreen('game');
  }

  private setMenuScreen(screen: MenuScreen): void {
    this.menuScreen = screen;
    this.renderMenu();
  }

  private renderMenu(): void {
    for (const panel of document.querySelectorAll<HTMLElement>('[data-menu-screen]')) {
      panel.hidden = panel.dataset.menuScreen !== this.menuScreen;
    }
    document.querySelector<HTMLElement>('#slot-menu-overlay')
      ?.classList.toggle('menu-overlay-opaque', this.menuScreen === 'slots' && this.previousMenuScreen === 'main');
    const gameVisible = this.menuScreen === 'game';
    const hud = document.querySelector<HTMLElement>('#hud');
    const technologyHud = document.querySelector<HTMLElement>('#technology-hud');
    hud?.toggleAttribute('hidden', !gameVisible);
    technologyHud?.toggleAttribute('hidden', !gameVisible);
    this.healthOverlay.hidden = !gameVisible;

    const slotTitle = document.querySelector<HTMLElement>('#slot-menu-title');
    const slotDescription = document.querySelector<HTMLElement>('#slot-menu-description');
    if (slotTitle) slotTitle.textContent = this.slotMenuMode === 'save' ? 'Guardar' : 'Cargar';
    if (slotDescription) {
      slotDescription.textContent = this.slotMenuMode === 'save'
        ? 'Elige un slot para guardar.'
        : 'Elige un slot para cargar.';
    }
    if (this.menuScreen === 'slots') this.renderSaveSlots();

    if (this.menuScreen === 'pause') {
      document.querySelector<HTMLButtonElement>('[data-menu-action="resume"]')?.focus();
    } else if (this.menuScreen === 'tutorial') {
      document.querySelector<HTMLButtonElement>('[data-menu-action="back-main"]')?.focus();
    } else if (this.menuScreen === 'slots') {
      document.querySelector<HTMLButtonElement>('#save-slot-list button:not(:disabled)')?.focus();
    } else if (this.menuScreen === 'main') {
      document.querySelector<HTMLButtonElement>('[data-menu-action="play"]')?.focus();
    }
  }

  private openSlotMenu(mode: SlotMenuMode): void {
    this.previousMenuScreen = this.menuScreen === 'pause' ? 'pause' : 'main';
    this.slotMenuMode = mode;
    const feedback = document.querySelector<HTMLElement>('#menu-feedback');
    if (feedback) feedback.textContent = '';
    this.setMenuScreen('slots');
  }

  private renderSaveSlots(): void {
    const list = document.querySelector<HTMLElement>('#save-slot-list');
    if (!list) return;
    list.replaceChildren();

    for (const slotStatus of this.saveRepository.listSlots()) {
      list.append(this.createSaveSlotButton(slotStatus));
    }
  }

  private createSaveSlotButton(slotStatus: SaveSlotStatus): HTMLButtonElement {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'save-slot-button';
    button.dataset.slot = String(slotStatus.slot);
    button.dataset.menuAction = this.slotMenuMode === 'save' ? 'save-slot' : 'load-slot';

    const main = document.createElement('span');
    main.className = 'save-slot-main';
    const title = document.createElement('strong');
    title.textContent = `Slot ${slotStatus.slot}`;
    const detail = document.createElement('small');
    const progress = document.createElement('span');
    progress.className = 'save-slot-detail';
    const actionLabel = document.createElement('span');
    actionLabel.className = 'save-slot-action';

    if (slotStatus.status === 'empty') {
      detail.textContent = this.slotMenuMode === 'save' ? 'Vacío · Guardar aquí' : 'Vacío';
      actionLabel.textContent = this.slotMenuMode === 'save' ? 'Guardar' : '';
      button.disabled = this.slotMenuMode === 'load';
    } else if (slotStatus.status === 'invalid') {
      detail.textContent = slotStatus.reason === 'incompatible'
        ? 'Guardado incompatible con esta versión'
        : 'Guardado dañado o ilegible';
      actionLabel.textContent = this.slotMenuMode === 'save' ? 'Reemplazar' : 'No disponible';
      button.disabled = this.slotMenuMode === 'load';
    } else {
      const { metadata } = slotStatus.save;
      detail.textContent = new Date(metadata.savedAt).toLocaleString();
      const level = document.createElement('small');
      level.textContent = `Nivel ${metadata.level} · ${metadata.minionCount} minions`;
      progress.append(level);
      actionLabel.textContent = this.slotMenuMode === 'save' ? 'Sobrescribir' : 'Cargar';
    }

    main.append(title, detail);
    button.append(main, progress, actionLabel);
    return button;
  }

  private selectSaveSlot(slot: SaveSlotId): void {
    const existing = this.saveRepository.readSlot(slot);
    if (existing.status === 'empty') {
      this.performSave(slot);
      return;
    }

    this.pendingOverwriteSlot = slot;
    this.requestConfirmation(
      'overwrite',
      'slots',
      `El Slot ${slot} ya contiene una partida. ¿Quieres sobrescribirla?`,
      'Sobrescribir',
    );
  }

  private selectLoadSlot(slot: SaveSlotId): void {
    const result = this.saveRepository.readSlot(slot);
    if (result.status !== 'valid') {
      this.showMenuFeedback('Esta partida no se puede cargar.');
      return;
    }
    this.startLoadedGame(result.save.gameState);
  }

  private performSave(slot: SaveSlotId): void {
    try {
      const save = this.saveRepository.save(slot, this.state);
      this.lastSavedFingerprint = getSaveFingerprint(save.gameState);
      this.renderSaveSlots();
      this.showMenuFeedback(`Partida guardada en el Slot ${slot}.`);
    } catch {
      this.showMenuFeedback('No se pudo guardar. Puede que el almacenamiento del navegador esté lleno o bloqueado.');
    }
  }

  private showMenuFeedback(message: string): void {
    const feedback = document.querySelector<HTMLElement>('#menu-feedback');
    if (feedback) feedback.textContent = message;
  }

  private requestExitToMenu(): void {
    if (!this.hasUnsavedProgress()) {
      this.returnToMainMenu();
      return;
    }
    this.requestConfirmation(
      'exit',
      'pause',
      'Hay progreso desde el último guardado. Si sales ahora, se perderá. ¿Volver al menú?',
      'Salir sin guardar',
    );
  }

  private hasUnsavedProgress(): boolean {
    if (this.lastSavedFingerprint === null) return this.state.tick > 0;
    return getSaveFingerprint(this.state) !== this.lastSavedFingerprint;
  }

  private requestConfirmation(
    action: ConfirmationAction,
    returnScreen: MenuScreen,
    message: string,
    confirmLabel: string,
  ): void {
    this.confirmationAction = action;
    this.confirmationReturnScreen = returnScreen;
    const title = document.querySelector<HTMLElement>('#confirmation-title');
    const body = document.querySelector<HTMLElement>('#confirmation-message');
    const confirm = document.querySelector<HTMLButtonElement>('[data-menu-action="confirm-confirmation"]');
    if (title) title.textContent = action === 'overwrite' ? '¿Sobrescribir partida?' : '¿Salir sin guardar?';
    if (body) body.textContent = message;
    if (confirm) confirm.textContent = confirmLabel;
    this.setMenuScreen('confirmation');
    confirm?.focus();
  }

  private confirmPendingAction(): void {
    const action = this.confirmationAction;
    this.confirmationAction = null;
    if (action === 'exit') {
      this.returnToMainMenu();
    } else if (action === 'overwrite' && this.pendingOverwriteSlot !== null) {
      const slot = this.pendingOverwriteSlot;
      this.pendingOverwriteSlot = null;
      this.setMenuScreen('slots');
      this.performSave(slot);
    }
  }

  private cancelPendingAction(): void {
    this.confirmationAction = null;
    this.pendingOverwriteSlot = null;
    this.setMenuScreen(this.confirmationReturnScreen);
  }

  private returnToMainMenu(): void {
    this.actionQueue.drain();
    this.endHudPlacement();
    this.dragging = false;
    if (this.state.phase === 'playing') this.state.phase = 'paused';
    this.setMenuScreen('main');
  }

  private resetGame(nextState: GameState = createInitialState()): void {
    this.actionQueue.drain();
    document.querySelector<HTMLDetailsElement>('.hud-debug')?.removeAttribute('open');
    this.dragging = false;
    this.lastDragPosition = { x: WORLD_SIZE / 2, y: WORLD_SIZE / 2 };
    this.lastDragDirection = { x: 0, y: 1 };
    this.hudItemDragging = null;
    this.hudPointerId = null;
    this.hudPointerTarget?.classList.remove('is-dragging');
    this.hudPointerTarget = null;
    this.hudPreviewPosition = null;
    this.technologyTreeOpen = false;
    this.pendingTechnologyUnlock = null;
    for (const mesh of this.hudHeldItemMeshes) mesh.dispose(false, true);
    this.hudHeldItemMeshes = [];
    this.canvas.style.cursor = 'default';

    for (const mesh of this.units.values()) mesh.dispose(false, true);
    this.units.clear();
    for (const meshes of this.barbarianMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.barbarianMeshes.clear();
    for (const meshes of this.animalMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.animalMeshes.clear();
    for (const meshes of this.barbarianCorpseMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.barbarianCorpseMeshes.clear();
    for (const meshes of this.corpseMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.corpseMeshes.clear();
    this.barbarianHealthHud.clear();
    this.barbarianHealthPips.clear();
    this.alertIndicators.clear();
    this.playedAlertIds.clear();
    for (const mesh of this.unitDetectionMeshes.values()) mesh.dispose(false, true);
    this.unitDetectionMeshes.clear();
    for (const meshes of this.unitShieldMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.unitShieldMeshes.clear();
    this.unitHealthHud.clear();
    this.unitHealthPips.clear();
    this.healthOverlay.replaceChildren();
    for (const mesh of this.resourceDropMeshes.values()) mesh.dispose(false, true);
    this.resourceDropMeshes.clear();
    for (const meshes of this.campfireMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.campfireMeshes.clear();
    for (const meshes of this.effectMeshes.values()) {
      for (const mesh of meshes) mesh.dispose(false, true);
    }
    this.effectMeshes.clear();
    this.disposeWeatherCloudViews();

    this.state = nextState;
    this.lastObservedProgressionLevel = this.state.progression.level;
    this.previousSnapshot = this.captureSnapshot();
    this.currentSnapshot = this.captureSnapshot();
    this.accumulator = 0;
    this.speedMultiplier = 1;
    this.cameraZoomMin = DEFAULT_CAMERA_ZOOM_MIN;
    this.cameraZoomMax = DEFAULT_CAMERA_ZOOM_MAX;
    this.zoom = DEFAULT_CAMERA_ZOOM_MIN;
    this.cameraFocus.set(this.state.totem.position.x, 0, this.state.totem.position.y);
    this.cameraRecentering = false;
    this.updateCameraProjection();
    this.applyCameraTransform();
    this.createUnits();
    this.createCampfires();
    this.syncView(0);
    this.updateHud();
  }

  private readonly handleHudInput = (event: Event): void => {
    const input = event.target as HTMLInputElement;
    if (input.tagName !== 'INPUT' || input.type !== 'range') return;

    const value = Number(input.value);
    if (!Number.isFinite(value)) return;

    if (input.dataset.debug === 'zoom-min') {
      this.cameraZoomMin = clamp(
        value,
        CAMERA_ZOOM_LIMIT_MIN,
        this.cameraZoomMax - CAMERA_ZOOM_STEP,
      );
    } else if (input.dataset.debug === 'zoom-max') {
      this.cameraZoomMax = clamp(
        value,
        this.cameraZoomMin + CAMERA_ZOOM_STEP,
        CAMERA_ZOOM_LIMIT_MAX,
      );
    } else {
      return;
    }

    this.zoom = clamp(this.zoom, this.cameraZoomMin, this.cameraZoomMax);
    this.updateCameraProjection();
  };

  private readonly handleWindowBlur = (): void => {
    if (this.hudItemDragging) this.endHudPlacement();
    if (!this.dragging) return;
    this.dragging = false;
    this.cameraRecentering = true;
    this.canvas.style.cursor = 'default';
    this.actionQueue.enqueue({
      type: 'drop-totem',
      position: this.lastDragPosition,
    });
  };

  private pickGroundPosition(): Vec2 | null {
    return this.pickGroundPositionFromCanvasCoordinates(this.scene.pointerX, this.scene.pointerY);
  }

  private pickGroundPositionAt(clientX: number, clientY: number): Vec2 | null {
    const rect = this.canvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return null;

    const renderWidth = Math.max(this.engine.getRenderWidth(), 1);
    const renderHeight = Math.max(this.engine.getRenderHeight(), 1);
    const canvasX = (clientX - rect.left) * (renderWidth / rect.width);
    const canvasY = (clientY - rect.top) * (renderHeight / rect.height);
    return this.pickGroundPositionFromCanvasCoordinates(canvasX, canvasY);
  }

  private pickUnitIdAt(clientX: number, clientY: number): string | null {
    const rect = this.canvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return null;

    const renderWidth = Math.max(this.engine.getRenderWidth(), 1);
    const renderHeight = Math.max(this.engine.getRenderHeight(), 1);
    const canvasX = (clientX - rect.left) * (renderWidth / rect.width);
    const canvasY = (clientY - rect.top) * (renderHeight / rect.height);
    const unitMeshes = new Set(this.units.values());
    const pick = this.scene.pick(
      canvasX,
      canvasY,
      (mesh) => mesh instanceof Mesh && unitMeshes.has(mesh),
    );
    if (pick?.hit && pick.pickedMesh) {
      for (const [unitId, mesh] of this.units) {
        if (mesh === pick.pickedMesh) return unitId;
      }
    }

    // The item can be released slightly beside a minion. Use a small screen
    // tolerance as well, so the totem or the ring does not make the drop feel
    // pixel-perfect, especially for minions at the back of the formation.
    const viewport = this.camera.viewport.toGlobal(renderWidth, renderHeight);
    const transform = this.scene.getTransformMatrix();
    const pointer = new Vector3(canvasX, canvasY, 0);
    let closestUnitId: string | null = null;
    let closestDistance = Number.POSITIVE_INFINITY;

    for (const [unitId, mesh] of this.units) {
      const screenPosition = Vector3.Project(
        mesh.position,
        Matrix.Identity(),
        transform,
        viewport,
      );
      const screenEdge = Vector3.Project(
        mesh.position.add(new Vector3(1.25, 0, 0)),
        Matrix.Identity(),
        transform,
        viewport,
      );
      const radius = Math.max(Math.abs(screenEdge.x - screenPosition.x), 24);
      const distance = Math.hypot(
        pointer.x - screenPosition.x,
        pointer.y - screenPosition.y,
      );
      if (distance <= radius && distance < closestDistance) {
        closestUnitId = unitId;
        closestDistance = distance;
      }
    }

    return closestUnitId;
  }

  private pickGroundPositionFromCanvasCoordinates(pointerX: number, pointerY: number): Vec2 | null {
    const pick = this.scene.pick(
      pointerX,
      pointerY,
      (mesh) => mesh === this.ground,
    );
    if (pick?.hit && pick.pickedPoint) {
      return clampWorldPosition({
        x: pick.pickedPoint.x,
        y: pick.pickedPoint.z,
      });
    }

    // Pointer capture lets the drag continue outside the green ground mesh.
    // Project the pointer ray onto the world plane and clamp that point to the
    // playable rectangle instead of waiting for the cursor to re-enter it.
    const ray = this.scene.createPickingRay(
      pointerX,
      pointerY,
      Matrix.Identity(),
      this.camera,
    );
    const distance = ray.intersectsPlane(
      Plane.FromPositionAndNormal(Vector3.Zero(), Vector3.Up()),
    );
    if (distance === null || distance < 0) return null;

    const point = ray.origin.add(ray.direction.scale(distance));
    return clampWorldPosition({ x: point.x, y: point.z });
  }

  private isPointerOverCanvas(clientX: number, clientY: number): boolean {
    const rect = this.canvas.getBoundingClientRect();
    return clientX >= rect.left
      && clientX <= rect.right
      && clientY >= rect.top
      && clientY <= rect.bottom;
  }

  private updateCursorFromPointer(): void {
    const pick = this.scene.pick(
      this.scene.pointerX,
      this.scene.pointerY,
      (mesh) => mesh === this.totem,
    );
    this.canvas.style.cursor = pick?.hit ? 'grab' : 'default';
  }

  private syncCursor(): void {
    if (this.dragging) {
      this.canvas.style.cursor = 'grabbing';
      return;
    }

    if (this.hudItemDragging) {
      this.canvas.style.cursor = 'grabbing';
      return;
    }

    this.updateCursorFromPointer();
  }

  private queueDragFromPointer(): void {
    if (!this.dragging || this.state.phase !== 'playing') return;

    this.canvas.style.cursor = 'grabbing';

    const pointerPosition = this.pickGroundPosition();
    if (!pointerPosition) return;

    const position = pointerPosition;

    const moved = Math.hypot(
      position.x - this.lastDragPosition.x,
      position.y - this.lastDragPosition.y,
    ) > 0.001;
    if (!moved) return;

    const distance = Math.hypot(
      position.x - this.lastDragPosition.x,
      position.y - this.lastDragPosition.y,
    );
    this.lastDragDirection = {
      x: (position.x - this.lastDragPosition.x) / distance,
      y: (position.y - this.lastDragPosition.y) / distance,
    };
    this.lastDragPosition = position;
    this.actionQueue.enqueue({ type: 'drag-totem', position });
  }

  private captureSnapshot(): RenderSnapshot {
    return {
      totem: { ...this.state.totem.position },
      units: new Map(this.state.units.map((unit) => [unit.id, { ...unit.position }])),
      barbarians: new Map(this.state.barbarians.map((barbarian) => [barbarian.id, { ...barbarian.position }])),
      animals: new Map(this.state.animals.map((animal) => [animal.id, { ...animal.position }])),
      clouds: new Map(this.state.weather.clouds.map((cloud) => [cloud.id, { ...cloud.position }])),
    };
  }

  private syncView(alpha: number): void {
    const totemX = lerp(this.previousSnapshot.totem.x, this.currentSnapshot.totem.x, alpha);
    const totemZ = lerp(this.previousSnapshot.totem.y, this.currentSnapshot.totem.y, alpha);
    const carriedPosition = this.dragging || this.state.totem.isCarried
      ? this.lastDragPosition
      : null;
    const visualTotemX = carriedPosition?.x ?? totemX;
    const visualTotemZ = carriedPosition?.y ?? totemZ;
    this.totem.position.set(visualTotemX, this.state.totem.isCarried ? 4.6 : 2, visualTotemZ);
    this.totemShadow.position.set(visualTotemX, 0.04, visualTotemZ);
    this.totemDirectionArrow.position.set(visualTotemX, 3.1, visualTotemZ);
    this.totemDirectionArrow.rotation.y = Math.atan2(
      this.lastDragDirection.x,
      this.lastDragDirection.y,
    );
    this.totemDirectionArrow.isVisible = this.dragging || this.state.totem.isCarried;

    const livingUnitIds = new Set(this.state.units.map((unit) => unit.id));
    for (const [unitId, unitMesh] of this.units) {
      if (livingUnitIds.has(unitId)) continue;
      unitMesh.dispose(false, true);
      this.units.delete(unitId);
      this.unitHealthHud.get(unitId)?.remove();
      this.unitHealthHud.delete(unitId);
      this.unitHealthPips.delete(unitId);
      const detection = this.unitDetectionMeshes.get(unitId);
      detection?.dispose(false, true);
      this.unitDetectionMeshes.delete(unitId);
      for (const mesh of this.unitShieldMeshes.get(unitId) ?? []) mesh.dispose(false, true);
      this.unitShieldMeshes.delete(unitId);
    }

    for (const unit of this.state.units) {
      if (!this.units.has(unit.id)) this.createUnitMeshes(unit);
      const previous = this.previousSnapshot.units.get(unit.id) ?? unit.position;
      const current = this.currentSnapshot.units.get(unit.id) ?? unit.position;
      const interpolatedPosition = {
        x: lerp(previous.x, current.x, alpha),
        y: lerp(previous.y, current.y, alpha),
      };
      const leashPosition = unit.role === 'hunter' && unit.task.kind === 'combat'
        ? projectWithinRadius(interpolatedPosition, { x: visualTotemX, y: visualTotemZ }, Math.min(
          this.state.totem.commandRadius,
          HUNTER_TOTEM_LEASH_RADIUS,
        ))
        : interpolatedPosition;
      const lunge = this.attackLungeOffset(unit.id, leashPosition);
      const interpolatedX = leashPosition.x + lunge.x;
      const interpolatedY = leashPosition.y + lunge.y;
      const unitMesh = this.units.get(unit.id);
      unitMesh?.position.set(interpolatedX, 0.35, interpolatedY);
      if (unitMesh) {
        unitMesh.rotation.x = -lunge.y * 0.3;
        unitMesh.rotation.z = lunge.x * 0.3;
      }
      if (unitMesh?.material instanceof StandardMaterial) {
        const damageFlash = this.state.effects
          .filter((effect) => effect.kind === 'damage-flash' && effect.targetId === unit.id)
          .sort((first, second) => second.ageSeconds - first.ageSeconds)[0];
        if (damageFlash) {
          const pulse = 0.65 + 0.35 * Math.sin(
            (damageFlash.ageSeconds / damageFlash.durationSeconds) * Math.PI * 4,
          );
          unitMesh.material.diffuseColor = Color3.FromHexString('#ef5b5b');
          unitMesh.material.emissiveColor = Color3.FromHexString('#ef3d3d').scale(pulse);
        } else {
          unitMesh.material.diffuseColor = Color3.FromHexString(this.unitRoleColor(unit.role));
          unitMesh.material.emissiveColor = Color3.Black();
        }
      }
      this.positionUnitHealthHud(
        unit.id,
        interpolatedX,
        interpolatedY,
        unit.health,
        unit.maxHealth,
      );
      this.syncUnitShield(unit.id, unit.hasShield, interpolatedX, interpolatedY);
      const detection = this.unitDetectionMeshes.get(unit.id);
      if (detection) {
        detection.position.set(interpolatedX, 0.08, interpolatedY);
        const radius = getResourceDetectionRadius(this.state.totem.commandRadius);
        detection.scaling.set(radius, 1, radius);
      }
    }

    this.syncBarbarianViews(alpha);
    this.syncAnimalViews(alpha);
    this.syncCorpseViews();
    this.syncBarbarianCorpseViews();
    this.syncResourceViews();
    this.syncWeatherCloudViews(alpha);
    this.syncCampfireViews();
    this.syncEffectViews();
    this.syncDetectionAlerts();
    this.syncHudHeldItemView();
  }

  private syncUnitShield(unitId: string, equipped: boolean, x: number, z: number): void {
    let meshes = this.unitShieldMeshes.get(unitId);
    if (!equipped) {
      if (meshes) {
        for (const mesh of meshes) mesh.dispose(false, true);
        this.unitShieldMeshes.delete(unitId);
      }
      return;
    }

    if (!meshes) meshes = this.createUnitShieldMeshes(unitId);
    meshes[0].position.set(x + 0.34, 0.56, z + 0.34);
    meshes[1].position.set(x + 0.34, 0.56, z + 0.44);
  }

  private attackLungeOffset(actorId: string, actorPosition: Vec2): Vec2 {
    const effect = this.state.effects.find((candidate) => (
      candidate.kind === 'attack-lunge' && candidate.targetId === actorId
    ));
    if (!effect) return { x: 0, y: 0 };
    const dx = effect.position.x - actorPosition.x;
    const dy = effect.position.y - actorPosition.y;
    const distance = Math.hypot(dx, dy);
    if (distance < 1e-8) return { x: 0, y: 0 };
    const progress = clamp(effect.ageSeconds / effect.durationSeconds, 0, 1);
    const offset = Math.sin(progress * Math.PI) * 0.2;
    return { x: (dx / distance) * offset, y: (dy / distance) * offset };
  }

  private syncBarbarianViews(alpha: number): void {
    for (const barbarian of this.state.barbarians) {
      let meshes = this.barbarianMeshes.get(barbarian.id);
      if (!meshes) {
        meshes = this.createBarbarianMeshes(barbarian);
        this.barbarianMeshes.set(barbarian.id, meshes);
      }
      const previous = this.previousSnapshot.barbarians.get(barbarian.id) ?? barbarian.position;
      const current = this.currentSnapshot.barbarians.get(barbarian.id) ?? barbarian.position;
      const x = lerp(previous.x, current.x, alpha);
      const z = lerp(previous.y, current.y, alpha);
      const lunge = this.attackLungeOffset(barbarian.id, { x, y: z });
      const visualX = x + lunge.x;
      const visualZ = z + lunge.y;
      meshes[0].position.set(visualX, 0.56, visualZ);
      meshes[1].position.set(visualX, 1.32, visualZ);
      meshes[2].position.set(visualX - 0.53, 0.63, visualZ + 0.12);
      meshes[2].rotation.z = -Math.PI / 2.3;
      meshes[3].position.set(visualX - 0.81, 0.98, visualZ + 0.12);
      for (const mesh of meshes) mesh.isVisible = barbarian.isAlive;

      const flash = this.state.effects.some((effect) => (
        effect.kind === 'damage-flash'
        && effect.targetId === barbarian.id
        && effect.ageSeconds < effect.durationSeconds
      ));
      for (const mesh of meshes.slice(0, 2)) {
        if (!(mesh.material instanceof StandardMaterial)) continue;
        mesh.material.emissiveColor = flash ? Color3.FromHexString('#b33131') : Color3.Black();
      }
      const row = this.barbarianHealthHud.get(barbarian.id);
      if (!barbarian.isAlive) {
        this.removeBarbarianHealthHud(barbarian.id);
      } else if (!row) {
        this.createBarbarianHealthHud(barbarian);
      }
      const activeRow = this.barbarianHealthHud.get(barbarian.id);
      const pips = this.barbarianHealthPips.get(barbarian.id);
      if (activeRow && pips) {
        this.positionHudElement(activeRow, visualX, 1.92, visualZ, -3);
        const filled = Math.ceil(Math.max(barbarian.health, 0));
        for (const [index, pip] of pips.entries()) pip.classList.toggle('is-filled', index < filled);
      }
    }
  }

  private syncAnimalViews(alpha: number): void {
    for (const animal of this.state.animals) {
      let meshes = this.animalMeshes.get(animal.id);
      if (!meshes) {
        meshes = this.createAnimalMeshes(animal);
        this.animalMeshes.set(animal.id, meshes);
      }
      const previous = this.previousSnapshot.animals.get(animal.id) ?? animal.position;
      const current = this.currentSnapshot.animals.get(animal.id) ?? animal.position;
      const x = lerp(previous.x, current.x, alpha);
      const z = lerp(previous.y, current.y, alpha);
      meshes[0].position.set(x, 0.3, z);
      meshes[1].position.set(x + 0.28, 0.42, z + 0.03);
      meshes[2].position.set(x + 0.24, 0.77, z - 0.03);
      meshes[3].position.set(x + 0.38, 0.77, z - 0.03);
      for (const mesh of meshes) mesh.isVisible = animal.isAlive;
    }
  }

  private syncBarbarianCorpseViews(): void {
    const activeIds = new Set<string>();
    for (const corpse of this.state.barbarianCorpses) {
      activeIds.add(corpse.id);
      let meshes = this.barbarianCorpseMeshes.get(corpse.id);
      if (!meshes) {
        meshes = this.createBarbarianCorpseMeshes(corpse);
        this.barbarianCorpseMeshes.set(corpse.id, meshes);
      }
      meshes[0].position.set(corpse.position.x, 0.22, corpse.position.y);
      meshes[1].position.set(corpse.position.x + 0.52, 0.08, corpse.position.y - 0.2);
    }
    for (const [corpseId, meshes] of this.barbarianCorpseMeshes) {
      if (activeIds.has(corpseId)) continue;
      for (const mesh of meshes) mesh.dispose(false, true);
      this.barbarianCorpseMeshes.delete(corpseId);
    }
  }

  private syncDetectionAlerts(): void {
    const activeIds = new Set<string>();
    for (const alert of this.state.alerts) {
      activeIds.add(alert.id);
      let indicator = this.alertIndicators.get(alert.id);
      if (!indicator) {
        indicator = document.createElement('div');
        indicator.className = 'combat-alert-hud';
        indicator.textContent = '!';
        indicator.setAttribute('aria-hidden', 'true');
        this.healthOverlay.append(indicator);
        this.alertIndicators.set(alert.id, indicator);
        if (alert.playSound) this.playCombatAlertSound();
        this.playedAlertIds.add(alert.id);
      }
      const position = alert.detectorKind === 'minion'
        ? this.state.units.find((unit) => unit.id === alert.detectorId)?.position ?? alert.position
        : this.state.barbarians.find((barbarian) => barbarian.id === alert.detectorId)?.position ?? alert.position;
      this.positionHudElement(indicator, position.x, 2.1, position.y, -2);
      indicator.style.opacity = String(clamp(1 - alert.ageSeconds / alert.durationSeconds, 0, 1));
    }
    for (const [alertId, indicator] of this.alertIndicators) {
      if (activeIds.has(alertId)) continue;
      indicator.remove();
      this.alertIndicators.delete(alertId);
      this.playedAlertIds.delete(alertId);
    }
  }

  private playCombatAlertSound(): void {
    try {
      this.unlockCombatAlertAudio();
      const context = this.alertAudioContext;
      if (!context) return;
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = 'triangle';
      oscillator.frequency.setValueAtTime(880, context.currentTime);
      oscillator.frequency.exponentialRampToValueAtTime(620, context.currentTime + 0.11);
      gain.gain.setValueAtTime(0.0001, context.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.08, context.currentTime + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.14);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start();
      oscillator.stop(context.currentTime + 0.15);
    } catch {
      // Audio is an optional browser capability; the visual alert remains available.
    }
  }

  private unlockCombatAlertAudio(): void {
    try {
      this.alertAudioContext ??= new AudioContext();
      if (this.alertAudioContext.state === 'suspended') {
        void this.alertAudioContext.resume().catch(() => undefined);
      }
    } catch {
      // Audio is an optional browser capability; the visual alert remains available.
    }
  }

  private positionHudElement(
    element: HTMLElement,
    x: number,
    y: number,
    z: number,
    verticalOffset: number,
  ): void {
    const rect = this.canvas.getBoundingClientRect();
    const renderWidth = Math.max(this.engine.getRenderWidth(), 1);
    const renderHeight = Math.max(this.engine.getRenderHeight(), 1);
    if (rect.width <= 0 || rect.height <= 0) {
      element.hidden = true;
      return;
    }
    const viewport = this.camera.viewport.toGlobal(renderWidth, renderHeight);
    const screenPosition = Vector3.Project(
      new Vector3(x, y, z),
      Matrix.Identity(),
      this.scene.getTransformMatrix(),
      viewport,
    );
    const screenX = screenPosition.x * (rect.width / renderWidth);
    const screenY = screenPosition.y * (rect.height / renderHeight);
    element.hidden = screenPosition.z < 0 || screenPosition.z > 1
      || !Number.isFinite(screenX) || !Number.isFinite(screenY)
      || screenX < -48 || screenX > rect.width + 48
      || screenY < -24 || screenY > rect.height + 24;
    element.style.left = `${screenX}px`;
    element.style.top = `${screenY + verticalOffset}px`;
  }

  private syncCorpseViews(): void {
    for (const corpse of this.state.corpses) {
      let meshes = this.corpseMeshes.get(corpse.id);
      if (!meshes) {
        const body = MeshBuilder.CreateCylinder(`corpse-${corpse.id}-body`, {
          diameter: 0.58,
          height: 0.9,
          tessellation: 10,
        }, this.scene);
        body.rotation.z = Math.PI / 2;
        body.material = this.material(`corpse-${corpse.id}-body-material`, '#62534d');
        body.isPickable = false;

        const head = MeshBuilder.CreateSphere(`corpse-${corpse.id}-head`, {
          diameter: 0.42,
          segments: 8,
        }, this.scene);
        head.material = this.material(`corpse-${corpse.id}-head-material`, '#76665d');
        head.isPickable = false;
        meshes = [body, head];
        this.corpseMeshes.set(corpse.id, meshes);
      }

      meshes[0].position.set(corpse.position.x, 0.3, corpse.position.y);
      meshes[1].position.set(corpse.position.x + 0.47, 0.27, corpse.position.y);
    }
  }

  private positionUnitHealthHud(
    unitId: string,
    x: number,
    z: number,
    health: number,
    maxHealth: number,
  ): void {
    const pips = this.unitHealthPips.get(unitId);
    const row = this.unitHealthHud.get(unitId);
    if (!pips || !row) return;

    while (pips.length < maxHealth) {
      const pip = document.createElement('span');
      pip.className = 'unit-health-pip';
      pips.push(pip);
      row.append(pip);
    }
    while (pips.length > maxHealth) {
      pips.pop()?.remove();
    }

    const rect = this.canvas.getBoundingClientRect();
    const renderWidth = Math.max(this.engine.getRenderWidth(), 1);
    const renderHeight = Math.max(this.engine.getRenderHeight(), 1);
    if (rect.width <= 0 || rect.height <= 0) {
      row.hidden = true;
      return;
    }

    const viewport = this.camera.viewport.toGlobal(renderWidth, renderHeight);
    const screenPosition = Vector3.Project(
      new Vector3(x, 0, z),
      Matrix.Identity(),
      this.scene.getTransformMatrix(),
      viewport,
    );
    const screenX = screenPosition.x * (rect.width / renderWidth);
    const screenY = screenPosition.y * (rect.height / renderHeight);
    row.hidden = screenPosition.z < 0 || screenPosition.z > 1
      || !Number.isFinite(screenX) || !Number.isFinite(screenY)
      || screenX < -48 || screenX > rect.width + 48
      || screenY < -24 || screenY > rect.height + 24;
    row.style.left = `${screenX}px`;
    // Anchor to the minion's ground point, then leave a small visible gap.
    row.style.top = `${screenY + 5}px`;

    const filledPips = Math.ceil(Math.max(health, 0));
    for (const [index, pip] of pips.entries()) {
      // Pips are laid out left-to-right, so the rightmost pip empties first.
      pip.classList.toggle('is-filled', index < filledPips);
    }
  }

  private syncResourceViews(): void {
    for (const resource of this.state.resources) {
      const meshes = this.resourceMeshes.get(resource.id);
      if (!meshes) continue;

      const visible = resource.amount > 0.001;
      for (const mesh of meshes) mesh.isVisible = visible;
    }

    const activeDropIds = new Set<string>();
    for (const drop of this.state.drops) {
      activeDropIds.add(drop.id);
      let mesh = this.resourceDropMeshes.get(drop.id);
      if (!mesh) {
        mesh = this.createResourceDropMesh(drop);
        this.resourceDropMeshes.set(drop.id, mesh);
      }
      mesh.position.set(drop.position.x, 0.18, drop.position.y);
      mesh.scaling.setAll(0.75);
      mesh.isVisible = drop.amount === 1;
    }

    for (const [dropId, mesh] of this.resourceDropMeshes) {
      if (activeDropIds.has(dropId)) continue;
      mesh.dispose();
      this.resourceDropMeshes.delete(dropId);
    }
  }

  private createWeatherCloudView(cloudId: string): WeatherCloudView {
    const root = new TransformNode(`weather-cloud-${cloudId}`, this.scene);
    const cloudMaterial = this.material(`weather-cloud-material-${cloudId}`, '#d8dee2');
    cloudMaterial.alpha = 0.88;
    cloudMaterial.emissiveColor = Color3.FromHexString('#525d64');
    const rainMaterial = this.material(`weather-rain-material-${cloudId}`, '#a9d8ec');
    rainMaterial.alpha = 0.76;
    rainMaterial.emissiveColor = Color3.FromHexString('#548aa0');

    const puffs: Mesh[] = [];
    const puffShapes = [
      { x: 0, y: 13.4, z: 0, sx: 2.5, sy: 0.78, sz: 1.7 },
      { x: -1.5, y: 13.8, z: 0, sx: 1.55, sy: 1.05, sz: 1.45 },
      { x: 0.1, y: 14.15, z: 0.05, sx: 1.75, sy: 1.3, sz: 1.5 },
      { x: 1.55, y: 13.65, z: -0.05, sx: 1.5, sy: 0.95, sz: 1.35 },
      { x: 0, y: 13.3, z: 0.95, sx: 1.55, sy: 0.75, sz: 1.15 },
    ];
    for (const [index, shape] of puffShapes.entries()) {
      const puff = MeshBuilder.CreateSphere(`weather-cloud-${cloudId}-puff-${index}`, {
        diameter: 1,
        segments: 7,
      }, this.scene);
      puff.parent = root;
      puff.position.set(
        shape.x * WEATHER_CLOUD_VISUAL_SCALE,
        shape.y,
        shape.z * WEATHER_CLOUD_VISUAL_SCALE,
      );
      puff.scaling.set(
        shape.sx * WEATHER_CLOUD_VISUAL_SCALE,
        shape.sy * WEATHER_CLOUD_VISUAL_SCALE,
        shape.sz * WEATHER_CLOUD_VISUAL_SCALE,
      );
      puff.material = cloudMaterial;
      puff.isPickable = false;
      puffs.push(puff);
    }

    const rainOffsets: Vec2[] = [];
    const raindrops: Mesh[] = [];
    for (let index = 0; index < 10; index += 1) {
      const angle = index * 2.399963229728653;
      const radius = 0.55 + (index % 3) * 0.52;
      const offset = {
        x: Math.cos(angle) * radius * WEATHER_CLOUD_VISUAL_SCALE,
        y: Math.sin(angle) * radius * WEATHER_CLOUD_VISUAL_SCALE,
      };
      rainOffsets.push(offset);
      const raindrop = MeshBuilder.CreateCylinder(`weather-cloud-${cloudId}-rain-${index}`, {
        diameter: 0.055,
        height: 0.72,
        tessellation: 5,
      }, this.scene);
      raindrop.parent = root;
      raindrop.position.set(offset.x, 5, offset.y);
      raindrop.material = rainMaterial;
      raindrop.isPickable = false;
      raindrop.isVisible = false;
      raindrops.push(raindrop);
    }

    return { root, puffs, raindrops, rainOffsets, cloudMaterial, rainMaterial };
  }

  private syncWeatherCloudViews(alpha: number): void {
    const activeCloudIds = new Set<string>();
    for (const cloud of this.state.weather.clouds) {
      activeCloudIds.add(cloud.id);
      let view = this.weatherCloudViews.get(cloud.id);
      if (!view) {
        view = this.createWeatherCloudView(cloud.id);
        this.weatherCloudViews.set(cloud.id, view);
      }

      const previous = this.previousSnapshot.clouds.get(cloud.id) ?? cloud.position;
      const current = this.currentSnapshot.clouds.get(cloud.id) ?? cloud.position;
      const x = lerp(previous.x, current.x, alpha);
      const z = lerp(previous.y, current.y, alpha);
      view.root.position.set(x, 0, z);
      view.root.rotation.y = Math.sin(cloud.phaseElapsedSeconds * 0.7) * 0.035;

      const isRaining = cloud.phase === 'raining';
      for (const [index, raindrop] of view.raindrops.entries()) {
        raindrop.isVisible = isRaining;
        if (!isRaining) continue;
        const offset = view.rainOffsets[index];
        const progress = (cloud.phaseElapsedSeconds * 0.8 + index / view.raindrops.length) % 1;
        const y = 12.2 - progress * 11.3;
        raindrop.position.set(offset.x, Math.max(y, 0.55), offset.y);
      }
    }

    for (const [cloudId, view] of this.weatherCloudViews) {
      if (activeCloudIds.has(cloudId)) continue;
      view.root.dispose(false, false);
      view.cloudMaterial.dispose();
      view.rainMaterial.dispose();
      this.weatherCloudViews.delete(cloudId);
    }
  }

  private disposeWeatherCloudViews(): void {
    for (const view of this.weatherCloudViews.values()) {
      view.root.dispose(false, false);
      view.cloudMaterial.dispose();
      view.rainMaterial.dispose();
    }
    this.weatherCloudViews.clear();
  }

  private syncCampfireViews(): void {
    const activeCampfireIds = new Set(this.state.campfires.map((campfire) => campfire.id));
    for (const campfire of this.state.campfires) {
      let meshes = this.campfireMeshes.get(campfire.id);
      if (!meshes) {
        meshes = this.createCampfireMeshes(
          campfire.id,
          campfire.position,
          false,
          campfire.healingRadius,
        );
        this.campfireMeshes.set(campfire.id, meshes);
      }
      this.positionCampfireMeshes(meshes, campfire.position);
      for (const mesh of meshes) mesh.isVisible = true;
    }
    for (const [id, meshes] of this.campfireMeshes) {
      if (activeCampfireIds.has(id)) continue;
      for (const mesh of meshes) mesh.dispose();
      this.campfireMeshes.delete(id);
    }
  }

  private createHealingEffectMeshes(effectId: string): Mesh[] {
    const material = this.material(`effect-${effectId}-material`, '#74e57a');
    material.emissiveColor = Color3.FromHexString('#3f9e50');
    const meshes: Mesh[] = [];

    for (let index = 0; index < 3; index += 1) {
      const horizontal = MeshBuilder.CreateBox(`effect-${effectId}-${index}-horizontal`, {
        width: 0.3,
        height: 0.06,
        depth: 0.07,
      }, this.scene);
      const vertical = MeshBuilder.CreateBox(`effect-${effectId}-${index}-vertical`, {
        width: 0.07,
        height: 0.06,
        depth: 0.3,
      }, this.scene);
      horizontal.material = material;
      vertical.material = material;
      horizontal.isPickable = false;
      vertical.isPickable = false;
      meshes.push(horizontal, vertical);
    }

    return meshes;
  }

  private syncEffectViews(): void {
    const activeEffectIds = new Set<string>();

    for (const effect of this.state.effects) {
      if (effect.kind !== 'heal-crosses') continue;

      activeEffectIds.add(effect.id);
      let meshes = this.effectMeshes.get(effect.id);
      if (!meshes) {
        meshes = this.createHealingEffectMeshes(effect.id);
        this.effectMeshes.set(effect.id, meshes);
      }

      const progress = clamp(effect.ageSeconds / effect.durationSeconds, 0, 1);
      const unit = this.state.units.find((candidate) => candidate.id === effect.targetId);
      const basePosition = unit?.position ?? effect.position;
      const scale = 1 - progress * 0.25;

      for (let index = 0; index < 3; index += 1) {
        const horizontal = meshes[index * 2];
        const vertical = meshes[index * 2 + 1];
        const spread = (index - 1) * 0.24;
        const y = 0.62 + progress * 1.15 + index * 0.08;
        horizontal.position.set(basePosition.x + spread, y, basePosition.y);
        vertical.position.set(basePosition.x + spread, y, basePosition.y);
        horizontal.scaling.setAll(scale);
        vertical.scaling.setAll(scale);
      }
    }

    for (const [effectId, meshes] of this.effectMeshes) {
      if (activeEffectIds.has(effectId)) continue;
      const effectMaterial = meshes[0]?.material;
      for (const mesh of meshes) mesh.dispose();
      effectMaterial?.dispose();
      this.effectMeshes.delete(effectId);
    }
  }

  private syncCamera(frameSeconds: number): void {
    if (this.cameraRecentering && !this.dragging) {
      const target = new Vector3(
        this.currentSnapshot.totem.x,
        0,
        this.currentSnapshot.totem.y,
      );
      this.cameraFocus = Vector3.Lerp(
        this.cameraFocus,
        target,
        Math.min(frameSeconds * CAMERA_RECENTER_SPEED, 1),
      );

      if (Vector3.DistanceSquared(this.cameraFocus, target) < 0.01) {
        this.cameraFocus.copyFrom(target);
        this.cameraRecentering = false;
      }
    }

    this.applyCameraTransform();
  }

  private updateCameraFromDragEdge(frameSeconds: number): void {
    if (!this.dragging) return;

    const width = Math.max(this.engine.getRenderWidth(), 1);
    const height = Math.max(this.engine.getRenderHeight(), 1);
    const pointerX = this.scene.pointerX;
    const pointerY = this.scene.pointerY;
    const horizontal = pointerX < CAMERA_EDGE_MARGIN
      ? -(1 - pointerX / CAMERA_EDGE_MARGIN)
      : pointerX > width - CAMERA_EDGE_MARGIN
        ? (1 - (width - pointerX) / CAMERA_EDGE_MARGIN)
        : 0;
    const vertical = pointerY < CAMERA_EDGE_MARGIN
      ? 1 - pointerY / CAMERA_EDGE_MARGIN
      : pointerY > height - CAMERA_EDGE_MARGIN
        ? -(1 - (height - pointerY) / CAMERA_EDGE_MARGIN)
        : 0;

    if (horizontal === 0 && vertical === 0) return;

    const screenRight = this.camera.getDirection(Vector3.Right());
    screenRight.y = 0;
    screenRight.normalize();
    const screenUp = this.camera.getDirection(Vector3.Up());
    screenUp.y = 0;
    screenUp.normalize();

    const movement = screenRight.scale(horizontal).add(screenUp.scale(vertical));
    if (movement.lengthSquared() === 0) return;
    movement.normalize();
    this.cameraFocus.addInPlace(movement.scale(CAMERA_EDGE_SCROLL_SPEED * frameSeconds));
    this.cameraFocus.x = clamp(this.cameraFocus.x, 0, WORLD_SIZE);
    this.cameraFocus.z = clamp(this.cameraFocus.z, 0, WORLD_SIZE);
    this.applyCameraTransform();
  }

  private applyCameraTransform(): void {

    const horizontalDistance = CAMERA_DISTANCE * Math.cos(CAMERA_PITCH);
    const offset = new Vector3(
      Math.sin(CAMERA_YAW) * horizontalDistance,
      CAMERA_DISTANCE * Math.sin(CAMERA_PITCH),
      Math.cos(CAMERA_YAW) * horizontalDistance,
    );
    this.camera.position.copyFrom(this.cameraFocus.add(offset));
    this.camera.setTarget(this.cameraFocus);
  }

  private updateCameraProjection(): void {
    const width = Math.max(this.engine.getRenderWidth(), 1);
    const height = Math.max(this.engine.getRenderHeight(), 1);
    const aspect = width / height;
    const viewHeight = BASE_VIEW_HEIGHT * this.zoom;
    this.camera.orthoTop = viewHeight / 2;
    this.camera.orthoBottom = -viewHeight / 2;
    this.camera.orthoRight = (viewHeight * aspect) / 2;
    this.camera.orthoLeft = -(viewHeight * aspect) / 2;
  }

  private updateHud(): void {
    const status = document.querySelector<HTMLElement>('#hud-status');
    const speed = document.querySelector<HTMLElement>('#hud-speed');
    const inventory = document.querySelector<HTMLElement>('#hud-inventory');
    const pauseButton = document.querySelector<HTMLButtonElement>('[data-action="pause"]');
    const gameOverOverlay = document.querySelector<HTMLElement>('#game-over-overlay');
    const gathererButton = document.querySelector<HTMLButtonElement>('[data-build-item="gatherer"]');
    const axeButton = document.querySelector<HTMLButtonElement>('[data-build-item="axe"]');
    const bowButton = document.querySelector<HTMLButtonElement>('[data-build-item="bow"]');
    const swordButton = document.querySelector<HTMLButtonElement>('[data-build-item="sword"]');
    const hammerButton = document.querySelector<HTMLButtonElement>('[data-build-item="hammer"]');
    const shieldButton = document.querySelector<HTMLButtonElement>('[data-build-item="shield"]');
    const campfireButton = document.querySelector<HTMLButtonElement>('[data-build-item="campfire"]');
    if (!status || !speed || !inventory || !pauseButton) return;

    const isWorking = this.state.units.some((unit) => (
      unit.state === 'seeking-task'
      || unit.state === 'gathering'
      || unit.state === 'collecting-drop'
      || unit.state === 'looting-corpse'
      || unit.state === 'hunting'
    ));
    const isCombat = this.state.units.some((unit) => unit.state === 'combat');
    const isFleeing = this.state.units.some((unit) => unit.state === 'fleeing');
    const mode = this.state.phase === 'defeat'
      ? 'Derrota · No quedan minions'
      : this.hudItemDragging
      ? this.hudItemDragging === 'campfire'
        ? 'Colocando hoguera'
        : this.hudItemDragging === 'gatherer'
          ? 'Colocando recolector'
          : 'Equipando minion'
      : this.state.phase === 'paused'
        ? 'Pausa'
      : this.state.totem.isCarried
        ? 'Tótem levantado'
        : this.state.totem.moving
          ? 'Marchando'
          : isCombat
            ? 'Combatiendo'
            : isFleeing
              ? 'Reagrupándose'
          : isWorking
            ? this.state.units.some((unit) => unit.state === 'looting-corpse')
              ? 'Saqueando cadáver'
              : this.state.units.some((unit) => unit.state === 'hunting')
                ? 'Cazando fauna'
                : this.state.units.some((unit) => unit.state === 'collecting-drop')
              ? 'Recogiendo recursos'
              : 'Recolectando recursos'
            : 'Formación';
    status.textContent = `${mode} · tick ${this.state.tick}`;
    speed.textContent = `Velocidad ${this.speedMultiplier}×`;
    const amounts = this.state.inventory.amounts;
    inventory.textContent = `Comida ${Math.floor(amounts.food)} · Madera ${Math.floor(amounts.wood)} · Piedra ${Math.floor(amounts.stone)} · Brillo ${Math.floor(amounts.spark)} · Oro ${Math.floor(amounts.gold)}`;
    const totalMinionLimitReached = this.state.units.length >= MAX_PLAYABLE_MINIONS;
    const lumberjackLimitReached = countUnitsWithRole(this.state.units, 'lumberjack') >= MAX_MINIONS_PER_TYPE;
    const hunterLimitReached = countUnitsWithRole(this.state.units, 'hunter') >= MAX_MINIONS_PER_TYPE;
    const guardianLimitReached = countUnitsWithRole(this.state.units, 'guardian') >= MAX_MINIONS_PER_TYPE;
    const artisanLimitReached = countUnitsWithRole(this.state.units, 'artisan') >= MAX_MINIONS_PER_TYPE;
    const gathererUnavailable = countUnitsWithRole(this.state.units, 'gatherer') === 0;
    const guardianUnavailable = gathererUnavailable;
    const axeBlockedByLastGatherer = !canConvertLastGathererToLumberjack(this.state.units);
    const gathererCost = getMinionPurchaseCost(
      this.state.units.length,
      STARTING_MINION_COUNT,
    );
    const axeCost = getMinionPurchaseCost(countUnitsWithRole(this.state.units, 'lumberjack'));
    const bowCost = getMinionPurchaseCost(countUnitsWithRole(this.state.units, 'hunter'));
    const artisanCost = getMinionPurchaseCost(countUnitsWithRole(this.state.units, 'artisan'));
    const shieldedGuardianCount = this.state.units.filter((unit) => (
      unit.role === 'guardian' && unit.hasShield
    )).length;
    const guardianCount = countUnitsWithRole(this.state.units, 'guardian');
    const shieldCost = getMinionPurchaseCost(shieldedGuardianCount);
    const artisanUnlocked = this.state.progression.unlockedTechnologies.includes('artisan');
    const shieldUnlocked = this.state.progression.unlockedTechnologies.includes('shield');
    const artisanEntry = document.querySelector<HTMLElement>('#artisan-build-entry');
    const shieldEntry = document.querySelector<HTMLElement>('#shield-build-entry');
    const progressionHud = document.querySelector<HTMLElement>('#hud-progression');
    const technologyPanel = document.querySelector<HTMLElement>('#technology-panel');
    const technologyToggle = document.querySelector<HTMLButtonElement>('[data-technology-toggle]');
    const technologyBadge = document.querySelector<HTMLElement>('#technology-point-badge');
    const technologyPointsSummary = document.querySelector<HTMLElement>('#technology-points-summary');

    if (this.state.progression.level > this.lastObservedProgressionLevel) {
      this.technologyTreeOpen = true;
    }
    this.lastObservedProgressionLevel = this.state.progression.level;
    if (
      this.pendingTechnologyUnlock
      && this.state.progression.unlockedTechnologies.includes(this.pendingTechnologyUnlock)
    ) {
      if (this.state.progression.technologyPoints === 0) this.technologyTreeOpen = false;
      this.pendingTechnologyUnlock = null;
    }

    if (progressionHud) {
      progressionHud.textContent = `Nivel ${this.state.progression.level} · XP ${this.state.progression.experience}/${this.state.progression.experienceToNextLevel} · Puntos ${this.state.progression.technologyPoints}`;
    }
    if (technologyPanel) technologyPanel.hidden = !this.technologyTreeOpen;
    if (technologyToggle) technologyToggle.setAttribute('aria-expanded', String(this.technologyTreeOpen));
    if (technologyBadge) technologyBadge.textContent = String(this.state.progression.technologyPoints);
    if (technologyPointsSummary) {
      technologyPointsSummary.textContent = `Puntos disponibles: ${this.state.progression.technologyPoints}`;
    }
    for (const technology of ['artisan', 'shield'] as const) {
      const button = document.querySelector<HTMLButtonElement>(`[data-unlock-technology="${technology}"]`);
      const stateLabel = document.querySelector<HTMLElement>(`[data-technology-state="${technology}"]`);
      const unlocked = this.state.progression.unlockedTechnologies.includes(technology);
      if (button) {
        button.disabled = unlocked || this.state.progression.technologyPoints < 1;
        button.setAttribute('aria-pressed', String(unlocked));
      }
      if (stateLabel) stateLabel.textContent = unlocked ? 'Desbloqueada' : '1 punto';
    }
    if (artisanEntry) artisanEntry.hidden = !artisanUnlocked;
    if (shieldEntry) shieldEntry.hidden = !shieldUnlocked;
    this.updateBuildCost(
      document.querySelector<HTMLElement>('#cost-gatherer'),
      gathererCost,
      'comida',
      'resource-square-food',
    );
    this.updateBuildCost(
      document.querySelector<HTMLElement>('#cost-axe'),
      axeCost,
      'madera',
      'resource-square-wood',
    );
    this.updateBuildCost(
      document.querySelector<HTMLElement>('#cost-bow'),
      bowCost,
      'madera',
      'resource-square-wood',
    );
    const swordCost = 2;
    this.updateBuildCost(
      document.querySelector<HTMLElement>('#cost-sword'),
      swordCost,
      'oro',
      'resource-square-gold',
    );
    this.updateBuildCost(
      document.querySelector<HTMLElement>('#cost-hammer'),
      artisanCost,
      'madera',
      'resource-square-wood',
    );
    this.updateBuildCost(
      document.querySelector<HTMLElement>('#cost-shield'),
      shieldCost,
      'oro',
      'resource-square-gold',
    );
    if (gathererButton) {
      gathererButton.disabled = totalMinionLimitReached
        || amounts.food < gathererCost
        || this.state.phase !== 'playing';
      gathererButton.title = totalMinionLimitReached ? 'Máximo alcanzado' : 'Recolector';
      gathererButton.setAttribute('aria-label', totalMinionLimitReached ? 'Máximo alcanzado' : 'Recolector');
    }
    if (axeButton) {
      axeButton.disabled = lumberjackLimitReached
        || axeBlockedByLastGatherer
        || amounts.wood < axeCost
        || this.state.phase !== 'playing';
      axeButton.title = lumberjackLimitReached
        ? 'Máximo alcanzado'
        : axeBlockedByLastGatherer
          ? 'Solo tienes un recolector'
          : 'Convertir en Leñador';
      axeButton.setAttribute(
        'aria-label',
        lumberjackLimitReached
          ? 'Máximo alcanzado'
          : axeBlockedByLastGatherer
            ? 'Solo tienes un recolector'
            : 'Convertir en Leñador',
      );
    }
    if (bowButton) {
      bowButton.disabled = hunterLimitReached
        || gathererUnavailable
        || amounts.wood < bowCost
        || this.state.phase !== 'playing';
      const bowLabel = hunterLimitReached ? 'Máximo alcanzado' : 'Convertir en Cazador';
      bowButton.title = bowLabel;
      bowButton.setAttribute('aria-label', bowLabel);
    }
    if (swordButton) {
      swordButton.disabled = guardianLimitReached
        || guardianUnavailable
        || amounts.gold < 2
        || this.state.phase !== 'playing';
      swordButton.title = guardianLimitReached ? 'Máximo alcanzado' : 'Convertir en Guardián';
      swordButton.setAttribute('aria-label', guardianLimitReached
        ? 'Máximo alcanzado'
        : guardianUnavailable
          ? 'Necesitas un recolector para transformarlo'
          : 'Convertir en Guardián');
    }
    if (hammerButton) {
      hammerButton.disabled = artisanLimitReached
        || gathererUnavailable
        || amounts.wood < artisanCost
        || this.state.phase !== 'playing';
      const hammerLabel = artisanLimitReached ? 'Máximo alcanzado' : 'Convertir en Artesana';
      hammerButton.title = hammerLabel;
      hammerButton.setAttribute('aria-label', hammerLabel);
    }
    if (shieldButton) {
      const allGuardiansEquipped = guardianCount > 0 && shieldedGuardianCount >= guardianCount;
      const shieldLabel = allGuardiansEquipped ? 'Máximo alcanzado' : 'Escudo +1 HP';
      shieldButton.disabled = allGuardiansEquipped
        || guardianCount === 0
        || amounts.gold < shieldCost
        || this.state.phase !== 'playing';
      shieldButton.title = shieldLabel;
      shieldButton.setAttribute('aria-label', shieldLabel);
    }
    if (campfireButton) {
      const campfireLimitReached = this.state.campfires.length >= MAX_ACTIVE_CAMPFIRES;
      campfireButton.disabled = campfireLimitReached
        || amounts.wood < CAMPFIRE_WOOD_COST
        || this.state.phase !== 'playing';
      campfireButton.title = campfireLimitReached
        ? 'Máximo alcanzado'
        : 'Cura a tus minions, gasta comida';
      campfireButton.setAttribute('aria-label', campfireLimitReached ? 'Máximo alcanzado' : 'Hoguera');
      campfireButton.setAttribute('aria-pressed', String(this.hudItemDragging === 'campfire'));
    }
    if (gameOverOverlay) {
      const wasHidden = gameOverOverlay.hidden;
      gameOverOverlay.hidden = this.state.phase !== 'defeat';
      if (wasHidden && !gameOverOverlay.hidden) {
        gameOverOverlay.querySelector<HTMLButtonElement>('[data-action="restart"]')?.focus();
      }
    }
    pauseButton.textContent = this.state.phase === 'paused'
      ? 'Reanudar'
      : this.state.phase === 'defeat'
        ? 'Derrota'
        : 'Pausa';
    pauseButton.disabled = this.state.phase === 'defeat';
    this.updateDebugHud();
    this.totemMaterial.diffuseColor = Color3.FromHexString(
      this.state.totem.isCarried ? '#f1b35c' : '#d8904f',
    );
  }

  private updateBuildCost(
    container: HTMLElement | null,
    cost: number | null,
    resourceLabel: string,
    squareClass: string,
  ): void {
    if (!container) return;

    const normalizedCost = cost === null ? null : Math.max(Math.floor(cost), 0);
    if (container.dataset.costValue !== String(normalizedCost)) {
      container.replaceChildren();
      if (normalizedCost !== null) {
        for (let index = 0; index < normalizedCost; index += 1) {
          const square = document.createElement('span');
          square.className = `resource-square ${squareClass}`;
          square.setAttribute('aria-hidden', 'true');
          container.append(square);
        }
      }
      container.dataset.costValue = String(normalizedCost);
    }

    container.setAttribute(
      'aria-label',
      normalizedCost === null
        ? 'Límite de minions alcanzado'
        : `Coste: ${normalizedCost} ${resourceLabel}`,
    );
  }

  private updateDebugHud(): void {
    const zoomMinInput = document.querySelector<HTMLInputElement>('#debug-zoom-min');
    const zoomMinOutput = document.querySelector<HTMLOutputElement>('#debug-zoom-min-value');
    const zoomMaxInput = document.querySelector<HTMLInputElement>('#debug-zoom-max');
    const zoomMaxOutput = document.querySelector<HTMLOutputElement>('#debug-zoom-max-value');

    if (zoomMinInput && zoomMinOutput) {
      zoomMinInput.value = this.cameraZoomMin.toFixed(2);
      zoomMinOutput.value = `${this.cameraZoomMin.toFixed(2)}×`;
    }
    if (zoomMaxInput && zoomMaxOutput) {
      zoomMaxInput.value = this.cameraZoomMax.toFixed(2);
      zoomMaxOutput.value = `${this.cameraZoomMax.toFixed(2)}×`;
    }
  }

  private material(name: string, hex: string): StandardMaterial {
    const material = new StandardMaterial(name, this.scene);
    material.diffuseColor = Color3.FromHexString(hex);
    material.specularColor = Color3.Black();
    material.specularPower = 1;
    material.emissiveColor = Color3.Black();
    material.reflectionTexture = null;
    material.refractionTexture = null;
    return material;
  }
}

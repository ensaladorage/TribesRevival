# TECHNICAL_DESIGN — Tribes Revival

**Propósito:** contratos técnicos, arquitectura y restricciones para implementar el diseño. Las reglas de juego se definen en el GDD; este documento explica las estructuras y decisiones técnicas necesarias para implementarlas.

## 12. Arquitectura técnica

### Stack

-   Babylon.js para escena, cámara, materiales, luces, picking, modelos
    y postprocesado.
-   TypeScript para tipos y lógica.
-   Vite para desarrollo y build.
-   DOM para HUD, menús y accesibilidad.
-   GLB/glTF para modelos 3D finales.

### Estructura

``` text
src/
  app/
    main.ts
    createEngine.ts
    createScene.ts
  simulation/
    types.ts
    createInitialState.ts
    fixedStep.ts
    systems/
      movement.ts
      needs.ts
      gathering.ts
      combat.ts
      progression.ts
    ai/
      stateMachine.ts
      taskScoring.ts
  rendering/
    camera.ts
    terrain.ts
    totemView.ts
    unitView.ts
    assetManifest.ts
    postprocess.ts
  input/
    actions.ts
    pointerToWorld.ts
  ui/
    hud/
    menus/
  persistence/
    saveGame.ts
    replay.ts
  data/
    roles.json
    technologies.json
    biomes.json
```

### Separación de responsabilidades

La simulación posee entidades, reglas, temporizadores, recursos, IA,
combate, progresión y guardado. Babylon.js posee meshes, materiales,
cámara, animaciones, partículas, luces y efectos. Ningún `Mesh`,
`Scene`, textura o nodo Babylon puede entrar en `GameState`.

### Bucle fijo

-   simulación a 20 ticks por segundo;
-   render a `requestAnimationFrame`;
-   máximo de cuatro ticks acumulados por frame;
-   interpolation visual entre estados;
-   replay basado en semilla e inputs semánticos.

``` ts
type GameState = {
  version: 17;
  seed: string;
  tick: number;
  phase: 'playing' | 'paused' | 'victory' | 'defeat';
  totem: TotemState;
  units: UnitState[];
  resources: ResourceNode[];
  threats: ThreatState[];
  inventory: Inventory;
  research: ResearchState;
  purchaseCounts: PurchaseCounts;
  toolLevels: ToolLevels;
};
```

El esquema mostrado es orientativo; `src/simulation/types.ts` es la
definición concreta del estado actual. El lector de guardados conserva
compatibilidad con la versión 16 y normaliza los campos de herramientas
y reclutamiento del Mago al cargarla.

`SaveGameRepository` administra slots locales, incluyendo la eliminación
de un slot. La interfaz pide confirmación antes de invocar esa operación;
el repositorio solo elimina la clave del slot solicitado.

------------------------------------------------------------------------

## Contratos de simulación, recursos y tareas

Esta sección fija los contratos de simulación para recursos y tareas. El sistema debe conservar el tick fijo y la separación entre simulación, renderizado y HUD.

### Contratos

-   `ResourceNode` representa un nodo serializable con `id`, tipo,
    bioma, posición, cantidad restante, cantidad máxima, ritmo de
    recolección, radio de interacción y marca de recurso secundario.
-   `ResourceDrop` representa la carga dejada en el suelo: tipo,
    cantidad, posición y nodo de origen. No pertenece al tótem y puede
    ser recogido por cualquier unidad libre.
-   La recolección de un nodo es una transformación
    `ResourceNode → ResourceDrop`; no modifica directamente el
    inventario. El inventario solo cambia al completar `collect-drop`.
-   Los tipos de simulación son `food`, `wood`, `stone`, `spark` y
    `gold`. Bayas y carne de fauna o bárbaros usan siempre `food`; no
    existe un recurso separado de carne.
-   El inventario del tótem usa cantidades por tipo; la carga de una
    unidad usa las mismas cantidades y una capacidad total
    independiente.
-   Las tareas incluyen `idle`, `gather`, `collect-drop`, `combat`,
    `flee`, `hunt` y `loot-corpse`. Cada tarea conserva un objetivo
    opcional y una causa legible.
-   La afinidad de rol es explícita: una unidad solo puede elegir
    recursos admitidos por su rol. Si no existe una tarea válida, vuelve
    a `idle`; si la carga está llena o el nodo se agota, crea un drop en
    el lugar de recolección y queda libre.
-   La prioridad de decisión autónoma es `enemigos` > `nodos de recursos` > `drops`. Si no hay enemigos elegibles, se comparan nodos y drops.
    Levantar el tótem interrumpe tareas de recolección, caza y saqueo.
    El combate continúa hasta romper contacto; los minions sin arma
    huyen hacia la posición actual del tótem.
-   El rango de detección de recursos y drops usa un multiplicador
    inicial de `1.05` sobre el radio de mando del tótem, medido desde
    cada minion. El render muestra ese rango con un anillo de debug
    alrededor de cada unidad.
-   Una tarea activa funciona como ticket: un nodo o drop reservado no
    se ofrece a otro minion. Mover el tótem cancela el ticket, bloquea
    temporalmente su objetivo cancelado y devuelve el minion a la
    formación; al terminar la recolocación se vuelve a evaluar el rango
    normal, por lo que un nodo o drop disponible puede detectarse de
    nuevo.
-   La recolección es transaccional: al llegar al radio de interacción
    comienza una acción de `1.5` segundos, pero el nodo y la carga no
    cambian hasta completarla. Si el tótem se mueve durante esa ventana,
    el progreso se descarta y el nodo conserva su cantidad original; no
    se crea un drop parcial.
-   El radio de mando del tótem (`10` metros en la configuración
    inicial) funciona también como radio de calma: un minion sin tarea
    puede quedarse `idle` dentro de él y seguir escaneando. Tras
    completar un nodo o recoger un drop, primero busca otra tarea local;
    solo vuelve a la formación si no encuentra nada y está fuera de ese
    radio.
-   No existe hambre en el diseño actual. La comida es un recurso
    almacenado que se gastará en curación mediante hoguera y en compras
    o transformaciones que la requieran.

### Generación determinista del mundo

-   El blueprint del mundo recibe una semilla textual y genera
    posiciones, radios, cantidades y tipos con un PRNG local; no usa
    `Math.random()`, Babylon.js ni el DOM. Entrega un número
    configurable de áreas de recursos, con al menos una instancia de
    cada bioma funcional, más los claros decorativos. La configuración de generación activa nodos `food` de tipo `berry-bush`,
    `wood` de tipo `tree`, `stone` de tipo `stone-vein` y `spark` de
    tipo `ruin`, además de los nodos de emergencia `wood` de tipo
    `twigs`.

-   La distancia angular de cada drop se genera con la misma semilla de
    simulación, dentro de un radio cercano al nodo, para variar la
    presentación sin romper el determinismo.

-   La configuración de mundo puede generar `10` áreas de recursos para
    facilitar las pruebas y añade el `Claro` inicial más `12` claros
    decorativos independientes y no superpuestos. Los claros pueden
    quedar muy próximos a otros biomas, siempre que sus círculos no se
    toquen. La referencia de diseño del mapa final apunta a unas 20
    regiones principales. La colocación rechaza cualquier solapamiento
    entre áreas de bioma, incluidos los claros y las áreas del mismo
    tipo. El suelo base permanece gris y cada región superpone un color
    de bioma. Los claros pueden incluir nodos funcionales de ramitas: al
    menos la mitad de los claros generados tienen uno y el claro inicial
    siempre tiene uno. Los arbustos de las `Praderas` crean nodos
    funcionales de bayas; las ramitas son recolectables por cualquier
    rol y entregan `2` maderas. Los árboles son recolectables por
    `lumberjack`; las piedras y las ruinas luminosas quedan preparadas
    pero no son asignables a los roles jugables actuales. El diseño de mundo incorpora bárbaros, conejos, oro, drops de comida de origen cárnico y combate automático. Los recursos se representan únicamente mediante
    sus nodos activos: los decorados antiguos de árboles, rocas y ruinas
    ya no se generan. La vegetación decorativa de césped, setas y flores
    no es interactuable. La decoración de suelo usa `60 %` césped,
    `25 %` flores y `15 %` setas en claros y praderas; en bosques usa
    `58 %` césped, `27 %` flores y `15 %` setas. Nunca se generan más de
    `2` setas por instancia de bioma. La vegetación decorativa usa una
    escala lógica de `1.26` a `1.62`.

-   La distribución se mantiene como blueprint aislado para que la
    futura generación circular pueda sustituir al contenedor provisional
    sin entrar en la simulación ni en el DOM.

## Generación y representación de recursos avanzados

-   `HITO_3_GENERATION_CONFIG` activa los cuatro tipos de recurso sin
    modificar la configuración histórica de Hito 2 usada por sus
    fixtures.
-   Cada acción de árbol, veta o ruina conserva el contrato
    `ResourceNode → ResourceDrop`; el inventario solo cambia al recoger
    el drop.
-   `lumberjack` puede seleccionar `wood` de fuente `tree`. Los roles
    jugables actuales no pueden seleccionar `stone` ni `spark`; la
    afinidad futura de `artisan` permanece sin exponer en el HUD o en el
    reclutamiento.
-   Una unidad que detecta un nodo recolectable por otro rol puede pedir
    ayuda a la tribu sin abandonar su tarea actual: el especialista
    libre más cercano recibe el nodo aunque esté fuera de su radio local
    de detección. La llamada solo se atiende si existe un rol vivo y
    libre con afinidad válida; no desbloquea recursos sin recolector
    jugable. La comunicación es puramente interna y no genera feedback
    visual ni sonoro.
-   Los drops son universales para todos los roles y por eso no
    requieren llamadas; cada drop sigue representando una unidad
    individual.
-   Cada nodo de árbol genera un rendimiento determinista de `2` o `3`
    maderas, representadas como `2` o `3` drops físicos separados de `1`
    unidad; las ramitas producen `2` drops de `1` unidad.
-   En todo el juego cada `ResourceDrop` visible representa exactamente
    `1` recurso. La carga soltada al morir o cancelarse se divide
    también en drops independientes por unidad.
-   Las ruinas luminosas usan una malla emisiva y un halo local como
    feedback visual provisional; no se introducen modelos externos ni
    efectos que entren en `GameState`.
-   Los nodos de madera se ven como tronco y copa; los nodos de piedra
    como un conjunto de bloques cúbicos; los nodos de Brillo como un
    octaedro romboidal con núcleo emisivo y halo. Los tipos decorativos
    quedan limitados a césped, setas y flores.
-   La validación cubre determinismo del blueprint, cobertura por bioma,
    tala, drops, inventario, ramitas y rechazo de tareas inaccesibles.

## Entidades de combate, fauna y botín

-   El estado de partida incorpora entidades lógicas separadas para
    bárbaros, conejos, cadáveres saqueables y alertas. `GameState`
    versión `14` incluye temporizadores de ataque del minion, estado de
    regreso al punto de aparición y reserva de tareas de saqueo.
    Babylon.js solo representa su posición, salud, silueta y feedback.
-   La generación de cinco bárbaros, seis conejos, patrullas, botín y
    drops usa PRNG con semilla; no depende de `Math.random()`, meshes ni
    DOM. Los bárbaros reaparecen en `60 s`, los conejos en `30 s`.
-   El combate corre en el tick fijo de `20 Hz`, con cooldown global por
    minion, bloqueo breve del cazador durante el golpe, leash de `10 m`
    al tótem y velocidad de combate de `6 m/s`; conserva selección
    equilibrada de objetivos y posiciones de ataque distribuidas. Roles
    armados responden automáticamente; roles sin arma huyen.
-   La separación y el despeje del tótem se aplican en simulación; la
    vista vuelve a proyectar las posiciones interpoladas para evitar
    solapes visuales. El impulso al golpear es procedural.
-   Al mover el tótem, los combatientes completan como máximo un golpe
    en curso y se reagrupan. Los bárbaros abandonan la persecución
    cuando todos los minions salen de `15 m`.
-   Las barras de vida y alertas 2D del bárbaro se destruyen al morir y
    se crean de nuevo al respawn.
-   La tarea de saqueo reserva el cadáver para un minion. Tras `1,5 s`
    crea en el mismo tick todos los drops físicos individuales de oro,
    comida (carne) y madera, y elimina el nodo; al cancelar la tarea se
    conserva el cadáver y se libera la reserva.
-   El HUD añade un contador unificado de comida y oro y un acceso de
    espada para transformar un `gatherer` en `guardian` por `2` de oro.
    No se requiere nivel y el límite por tipo especial sigue en cinco.
-   El feedback de amenaza es un "!" sobre el detector y un sonido
    sintético breve, una vez por encuentro. La comunicación interna
    minion-minion sigue siendo puramente lógica y silenciosa.
-   La derrota ocurre al quedar `0` minions vivos. No hay armadura ni retirada automática por salud o energía de vínculo.

------------------------------------------------------------------------

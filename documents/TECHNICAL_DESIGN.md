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
definición concreta del estado actual. El flujo de guardar y cargar la
versión actual funciona. Aunque el lector implementa compatibilidad con v16
y normaliza algunos campos heredados o parciales, ampliar y validar
compatibilidad entre versiones queda aplazado a una fase avanzada: no es un
objetivo de trabajo ni una matriz de pruebas activa en esta etapa.

`SaveGameRepository` administra slots locales, incluyendo la eliminación
de un slot. La interfaz pide confirmación antes de invocar esa operación;
el repositorio solo elimina la clave del slot solicitado.

------------------------------------------------------------------------

## Contratos de simulación, recursos y tareas

Esta sección fija los contratos de simulación para recursos y tareas. El sistema debe conservar el tick fijo y la separación entre simulación, renderizado y HUD.

### Contratos

-   Los paneles de gestión se anclan de forma absoluta sobre la fila de
    botones del dock, sin participar en su ancho. Los tooltips de sus tarjetas
    se ajustan a los límites visibles del juego al recibir puntero o foco y
    al redimensionar. El nivel inicial es 0; la lectura de guardados admite
    nivel 0 tanto en el estado como en sus metadatos, sin renumerar partidas
    existentes ni cambiar la versión del esquema.

-   `technologyConfig.ts` define los tres árboles y el catálogo de tecnologías
    con identificador, árbol, orden, coste y nivel mínimo. La simulación y el
    HUD comparten `canUnlockTechnology`; `progression.ts` valida antes de
    descontar puntos y registrar el desbloqueo. Los identificadores persistidos
    no cambian y los requisitos solo se aplican a nuevas compras. El árbol
    seleccionado pertenece al estado temporal del HUD, no a `GameState`.

-   `ResourceNode` representa un nodo serializable con `id`, tipo,
    bioma, posición, cantidad restante, cantidad máxima, ritmo de
    recolección, radio de interacción, marca de recurso secundario y un tier
    opcional; la ausencia de tier significa nivel 1 para guardados heredados.
-   `economyConfig.ts` concentra curvas, límites, costes compuestos y
    efectos de herramientas. La simulación decide compras y el HUD solo
    consulta esas mismas funciones para no duplicar reglas.
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
    comienza una acción. El tiempo base es `3` segundos por árbol,
    `5` segundos por veta de piedra tier 1, `7` segundos por veta tier 2
    y `1.5` segundos para otros nodos; las mejoras de herramienta reducen
    el tiempo de árbol/piedra según su efecto. El nodo y la carga no
    cambian hasta completarla. Si el tótem se mueve durante esa ventana,
    el progreso se descarta y el nodo conserva su cantidad original; no
    se crea un drop parcial.
-   `minionIdle.ts` centraliza el paseo: destinos entre 4 y 8 m, velocidad
    3 m/s y pausas 1–3 s. Ese anillo solo selecciona destinos preferidos;
    la posición inicial del descanso puede estar en cualquier punto válido
    dentro del radio real de mando. Los trayectos son cortos y evitan cruzar
    el anillo interior; los candidatos fuera del mapa se descartan.
-   Tras completar un trabajo, el minion primero busca otra tarea local.
    Solo regresa si no encuentra trabajo y está fuera del radio de mando.
    Dentro de ese radio mantiene `task.kind = idle` y alterna paseo y pausa, sin
    perder la disponibilidad para tareas o llamadas. Las interrupciones
    cancelan destino y espera; no reinician el contador de paseo.
-   `UnitState.idleMovement` es opcional y serializa destino, espera restante
    y contador. La semilla, ID de unidad y contador gobiernan la secuencia,
    sin depender del render ni de aleatoriedad global. La carga v16/v17
    inicializa solo datos idle ausentes o inválidos, conservando el resto
    del estado y la versión 17. La formación durante arrastre sigue usando
    su radio original. `totemRangeEntry` proyecta el retorno sin trabajo
    sobre el radio de mando; `isWithinTotemRange` determina cuándo detenerlo.
    `return-to-totem` recalcula el punto de entrada y cancela el regreso
    inmediatamente al estar dentro, ignorando destinos centrales de guardados
    anteriores. No asigna slots ni necesita migración de GameState v17.
    `formationTarget` solo se usa en seguimiento/formación al mover el tótem;
    una huida se dirige hacia el tótem respetando su despeje, sin slot asignado.
-   `minionNavigation.ts` contiene funciones puras de evitación: mínima
    separación 0,94 m, horizonte 0,6 s, candidatos directos y desviados
    ±25/50/75 grados, velocidad normal o mitad y espera cuando no hay paso.
    El movimiento compartido conserva el objetivo de tarea y determina
    la llegada desde la posición resuelta, no desde la intención de avanzar.
-   Cada tick construye posiciones iniciales y reservas de trayectorias,
    transmitidas explícitamente a conflicto, supervivencia y formación.
    Los segmentos efectivos se comprueban continuamente para evitar cruces
    entre endpoints despejados; la predicción cesa cuando se alcanza el destino.
    La prioridad favorece trabajadores estacionarios y tareas activas frente
    al idle, con desempate por ID y preferencia lateral determinista. Los
    idles en pausa pueden ceder ante un trabajador que se aproxima.
-   La separación residual entre aliados mueve preferentemente al actor
    que no está trabajando y resuelve también posiciones coincidentes.
    Sigue siendo una salvaguarda posterior a la evitación, no el sistema
    principal de navegación. La reacción de enemigos conserva sus reglas.
-   La navegación conserva una ruta de puntos intermedios elegida mediante
    un pequeño grafo de visibilidad alrededor de actores. Un rodeo a un
    trabajador conserva la ruta; los cruces móviles mantienen lado de evasión
    al menos 0,6 s y puntúan continuidad de dirección. El bloqueo activa
    replanteamiento con espera, limitado a una consulta cada 0,6 s; el idle
    descarta el destino tras 1,2 s sin poder avanzar. Se reinicia la ruta
    al cambiar tarea/objetivo. Movimiento ordinario y combate comparten
    6 m/s; idle usa 3 m/s, seguimiento del tótem 10 m/s y retorno sin
    trabajo 8 m/s mediante constantes separadas.
-   `minionCombatPositions.ts` reserva huecos geométricamente libres por
    objetivo antes de mover atacantes: conserva los offsets válidos antes
    de asignar nuevas posiciones, anillo de seis plazas a 0,98 m para
    cuerpo a cuerpo, espera a 2,1 m y anillo de cazadores a 4,6 m. Los
    candidatos se descartan por límites, tótem, trabajadores, otras reservas
    y otros bárbaros. Los cazadores reposicionan antes de atacar; los golpes
    requieren alcance real y proximidad al hueco. Los bárbaros también
    comprueban las trayectorias reservadas de aliados antes de desplazarse.
    La corrección residual minion/bárbaro nunca mueve al bárbaro.
-   `worldView.ts` comparte la orientación fija entre cámara y simulación.
    Los candidatos idle se puntúan por dirección posterior y proximidad
    a posiciones/destinos aliados (radio 1,5 m, peso 2 para aglomeración).
    El retorno al rango usa la entrada más cercana sin puntuación visual ni
    slots centrales. Las reservas de trayectorias son temporales por tick.
    El campo opcional `UnitState.navigation` guarda objetivo, waypoints,
    velocidad previa, lado/espera de evasión, temporizadores y offset de
    combate para mantener continuidad tras cargar. Los guardados sin él
    siguen siendo válidos; los datos de navegación malformados se descartan
    conservando la unidad y el resto del progreso. Se mantiene GameState v17.
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
    ya no se generan. En Godot, la vegetación decorativa de césped, setas
    y arbustos no es interactuable. Usa pesos `60/25/15` para
    césped/arbustos/setas en claros y praderas, y `58/27/15` en bosques.
    El límite de `2` setas por instancia se aplica también al reparto
    inicial entero, antes de asignar las plazas sobrantes a otros tipos.
    Se generan `12–18` decoraciones por claro (también el inicial),
    `18–26` por pradera y `16–24` por bosque; ninguna en pedregales/ruinas.
    Se conserva la escala lógica `1.26–1.62` y el margen de colocación.
    Las ocho variantes Sprite3D editables heredan `DecorationSprite.tscn`,
    usan AtlasTexture sin márgenes transparentes, nearest y billboard,
    con el borde inferior apoyado sobre el suelo. La vista elige tamaño
    y reflejo con un PRNG independiente por semilla/ID; no añade datos
    visuales al guardado ni altera el estado. Las flores retiradas no se
    representan si aparecen en datos cargados; sus escenas se eliminan.

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
-   `minionAwareness.ts` calcula llamadas de enemigos y animales desde una
    instantánea de unidades/objetivos vivos por tick. Ordena enemigos antes
    que animales y desempata por distancia e ID. Conserva asignaciones
    existentes mientras haya observación real; para objetivos sin atender
    reserva un único combatiente/cazador libre, sin carga. Un respondedor
    recibe como máximo una llamada. La elegibilidad del cazador considera
    su leash y el radio de posición de combate compartido con las reservas.
    No propaga mensajes recursivos ni persiste una memoria de entidades ocultas.
-   `updateConflict` combina detección personal y llamadas recibidas, con
    prioridad de amenazas sobre caza. La comunicación permite conservar un
    objetivo remoto observado por un compañero, sin ampliar el radio personal.
    Las llamadas se resuelven antes que las de recursos; se suspenden durante
    el movimiento del tótem. Usa `combat`/`hunt` y causas existentes:
    no cambia GameState v17 ni añade alertas o datos de guardado.
-   Los drops son universales para todos los roles y por eso no
    requieren llamadas; cada drop sigue representando una unidad
    individual.
-   Cada nodo de árbol genera un rendimiento determinista de `2` o `3`
    maderas, representadas como `2` o `3` drops físicos separados de `1`
    unidad; las ramitas producen `2` drops de `1` unidad.
-   En todo el juego cada `ResourceDrop` visible representa exactamente
    `1` recurso. La carga soltada al morir o cancelarse se divide
    también en drops independientes por unidad.
-   En Godot, piedra y Brillo usan Sprite3D pequeños y grandes en escenas
    editables (`Rock`/`RockLarge` y `Spark`/`SparkLarge`), con filtro Nearest
    y sin los meshes provisionales ni el halo anterior. Heredan la base
    `ResourceSprite.tscn`. La vista elige la variante con probabilidad
    equivalente mediante PRNG separado por semilla e ID; reconstruir el
    mismo nodo conserva su apariencia. El tamaño aún es visual: no modifica
    tier, cantidad, rendimiento, radio ni estructura de guardado. Las piedras
    de nivel 2 no se instancian ni se configuran.
-   Los nodos de madera se ven como tronco y copa. Los tipos decorativos
    quedan limitados a césped, setas y arbustos decorativos en Godot.
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
    minion, bloqueo de 0,22 s de los minions durante el golpe, leash de `10 m`
    al tótem y velocidad normal y de combate de `6 m/s`; conserva selección
    equilibrada de objetivos y posiciones de ataque distribuidas. Roles
    armados responden automáticamente; roles sin arma huyen.
-   La separación y el despeje del tótem se aplican en simulación; la
    vista vuelve a proyectar las posiciones interpoladas para evitar
    solapes visuales. El impulso al golpear es procedural.
-   Al mover el tótem, los combatientes completan como máximo un golpe
    en curso y se reagrupan. Los bárbaros abandonan la persecución
    cuando todos los minions salen de `15 m`.
    En Godot, durante el seguimiento, `conflict_system.gd` comprueba primero
    la distancia del minion al tótem: fuera del radio de mando espera solo
    a que termine `attackLockRemainingSeconds` y asigna retorno, sin esperar
    al cooldown ni readquirir amenazas mientras siga fuera. No cambia v17.
-   Los bárbaros usan velocidades separadas: `7 m/s` al perseguir minions
    y `8 m/s` al volver a su punto de aparición.
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

### IA táctica en Godot

`tactical_movement.gd` puntúa destinos locales deterministas según distancia a amenazas, espacio aliado, continuidad y dominio permitido. Los civiles mantienen la tarea de huida dentro del mando; si el tótem los deja fuera, retornan progresivamente. Los bárbaros priorizan combatientes dirigidos contra ellos, conservan el objetivo ante diferencias pequeñas de distancia y realizan maniobras cortas durante parte del enfriamiento si hay varios atacantes. Se reutilizan navegación, daño y temporizadores existentes. La simulación no depende del renderizado y el formato de guardado permanece en versión 17.

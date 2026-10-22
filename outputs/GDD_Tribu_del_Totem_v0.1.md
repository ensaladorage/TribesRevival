# GDD — **Tribu del Tótem**
## Juego de navegador 2D de supervivencia tribal

**Versión:** 0.1 — diseño base implementable  
**Idioma de trabajo:** español  
**Alcance acordado:** modo tribal; primero simulación local, después multijugador  
**Arte:** pixel art original  
**Relación con Wanderers.io:** inspirado en el bucle y la fantasía de liderazgo, no en su identidad visual, nombres, balance ni assets.

> **Regla de lectura:** cada apartado distingue entre `[VERIFICADO]` (respaldado por fuentes históricas o documentación preservada), `[INFERIDO]` (coincide en varias fuentes pero no está confirmado por el creador) y `[PROPUESTO]` (decisión nueva para este proyecto).

---

## 1. Resumen ejecutivo

**Tribu del Tótem** es un juego 2D de supervivencia y estrategia ligera en el que el jugador guía una comunidad nómada mediante un tótem móvil. El jugador no microgestiona cada aldeano: decide hacia dónde se desplaza la tribu, cuándo detenerse, qué tecnología priorizar y cuándo aceptar o evitar un combate. Los miembros interpretan esas órdenes mediante IA contextual.

La experiencia debe transmitir tres sensaciones:

1. **Dirección indirecta:** mover el tótem es la orden principal; la tribu “cobra vida” alrededor de ella.
2. **Crecimiento visible:** pasar de dos supervivientes vulnerables a una pequeña comunidad especializada.
3. **Riesgo legible:** cada expedición ofrece más recursos, pero también mayor exposición a hambre, depredadores y facciones hostiles.

### Objetivo del primer producto jugable

Una partida local de 15–25 minutos en un mapa procedural pequeño, con:

- tótem arrastrable;
- 2–8 unidades autónomas;
- madera, comida, piedra y mineral brillante;
- recolección automática contextual;
- combate contra fauna y una facción enemiga;
- reclutamiento, equipamiento y tres mejoras tecnológicas;
- derrota por pérdida de la tribu y victoria por completar el rito de la Gran Hoguera.

---

## 2. Investigación histórica de referencia

### 2.1 Mecánicas con evidencia fuerte

`[VERIFICADO / ALTA CONFIANZA]`

- El jugador dirige una tribu pequeña a través de un sandbox hostil.
- La tribu sigue un tótem que el jugador mueve con el ratón.
- Las unidades actúan automáticamente y sus herramientas determinan qué recursos pueden recolectar.
- El bucle incluye reunir recursos, reclutar nuevos miembros, equiparlos y desbloquear tecnologías.
- Hay combate contra bárbaros y otras tribus o jugadores.
- Se documentan recursos como comida, madera y monedas/oro.
- La pérdida de todos los miembros de la tribu implica perder la partida.

Estas afirmaciones aparecen en fichas históricas de juego, la wiki comunitaria y el proyecto de preservación del cliente. La ficha de Miniplay resume explícitamente “reclutar”, “equipar”, “inventar tecnologías” y combatir; la wiki describe el seguimiento del tótem y la separación contextual de los recolectores. [Miniplay](https://www.miniplay.com/game/wanderers-io), [Wanderers.io Wiki — The Tribe](https://wanderersio.fandom.com/wiki/The_Tribe), [Not Doppler](https://www.notdoppler.com/wanderersio.php)

### 2.2 Mecánicas plausibles, pero no totalmente verificables

`[INFERIDO / CONFIANZA MEDIA]`

- El límite de miembros era reducido —la wiki documenta 1–6 en una versión— y podía variar por modo o actualización.
- Existían roles reconocibles como cazador, leñador, minero, arquero, constructor o misionero.
- Había al menos dos modos, incluyendo uno tribal y otro centrado en construcciones/defensas.
- La economía incluía conversiones, edificios defensivos y objetos como catapultas en versiones posteriores.

La información procede de documentación comunitaria, espejos de fichas y un proyecto de preservación que advierte que el código original no está publicado y que parte de la reconstrucción es ingeniería inversa. [GitHub — proyecto de preservación](https://github.com/Avoxel284/wanderersio), [Wanderers.io Wiki](https://wanderersio.fandom.com/wiki/Wanderers.io_Wiki), [Yepi](https://yepi.com/games/wanderersio)

### 2.3 Qué no se copiará

`[DECISIÓN DE DISEÑO]`

- No se usarán el nombre Wanderers.io, sus facciones, sprites, sonidos, mapas, textos ni valores exactos.
- No se reproducirá su modo multijugador en la primera versión.
- No se asumirá que el comportamiento documentado por fans sea una especificación oficial.
- El tótem será una interfaz de mando propia: tendrá energía de vínculo, modos de parada y señales visuales originales.

---

## 3. Pilares y límites de diseño

### Pilares

1. **Una orden, muchas reacciones:** una acción simple del jugador genera comportamientos ricos.
2. **Información antes que castigo:** las amenazas deben ser visibles y la causa de cada fallo debe poder explicarse.
3. **Decisiones de ruta:** el jugador elige entre seguridad, recursos, conocimiento y velocidad.
4. **Pixel art con lectura funcional:** cada rol, estado y peligro se reconoce en menos de un segundo.
5. **Simulación independiente del render:** la partida debe poder reproducirse, guardarse y testearse sin depender del canvas.

### Fuera de alcance de v0.1

- construcción libre de ciudades;
- diplomacia compleja;
- campaña narrativa extensa;
- clases con habilidades activas individuales;
- servidores persistentes;
- comercio entre jugadores;
- móvil táctil como plataforma objetivo primaria.

---

## 4. Bucle principal

```text
Explorar → detectar oportunidad/amenaza → detener el tótem
→ unidades recolectan o combaten → transportar recursos
→ decidir reclutar/equipar/investigar → elegir siguiente ruta
→ repetir hasta completar el rito o perder la tribu
```

### 4.1 Sesión tipo

1. El jugador recibe dos unidades iniciales y una reserva mínima.
2. Mueve el tótem hacia un claro cercano.
3. Un explorador revela recursos y amenazas.
4. El jugador detiene el tótem dentro del radio de trabajo.
5. Leñador y cazadora abandonan temporalmente la formación, recolectan y regresan.
6. El jugador decide entre ampliar la tribu, fabricar equipo o continuar.
7. Una amenaza obliga a escoger: retirarse, combatir o gastar comida para acelerar la marcha.
8. El mapa introduce zonas de mayor riesgo y la Gran Hoguera como objetivo final.

### 4.2 Condición de victoria y derrota

`[PROPUESTO]`

- **Victoria:** activar tres piedras de memoria y completar el rito en la Gran Hoguera con al menos una unidad viva.
- **Derrota:** `aliveUnits == 0` o hambre crítica durante 60 segundos sin comida.
- **Retirada:** el jugador puede abandonar la partida y conservar estadísticas y desbloqueos permanentes, pero no completar el rito.

**Aceptación:** una partida puede comenzar, progresar y finalizar sin recarga de página; el estado final se comunica con una pantalla DOM accesible y una opción clara de reiniciar.

---

## 5. Cámara, mapa y controles

### 5.1 Cámara

`[PROPUESTO]`

- vista cenital 2D;
- mundo continuo en coordenadas flotantes;
- cámara centrada en el tótem con interpolación de 0,12 s;
- zoom inicial `1.0`, límites `0.8–1.5`;
- mapa inicial: `3200 × 3200` unidades lógicas;
- render por chunks de `256 × 256` para permitir ampliar el mapa después.

### 5.2 Mapa procedural

Generar con semilla guardable:

- 45 % pradera;
- 25 % bosque;
- 15 % pedregal;
- 10 % humedal;
- 5 % ruinas y zona de rito.

Cada bioma define recursos, velocidad, visibilidad, fauna y probabilidad de encuentros. La semilla debe aparecer en el menú de depuración y permitir repetir exactamente una partida.

### 5.3 Acciones de entrada

| Acción | Ratón | Teclado | Resultado |
|---|---|---|---|
| Mover tótem | mantener y arrastrar | WASD/flechas | establece destino continuo |
| Detener/seguir | soltar | Espacio | alterna marcha y formación |
| Interactuar | clic | E | abre objetivo cercano |
| Panel de tribu | clic UI | Tab | muestra unidades y equipo |
| Pausa | botón UI | Esc | congela simulación local |
| Velocidad | botón UI | 1/2/3 | normal, rápida, muy rápida |

El arrastre debe usar coordenadas del mundo, no la posición del cursor sin convertir. En touch futuro se admitirá arrastre con un dedo y pellizco de zoom, pero no es requisito de v0.1.

**Aceptación:** el jugador puede recorrer 1000 unidades, parar la tribu y reanudarla sin que el tótem salte más de 2 píxeles de pantalla; la pausa detiene IA, temporizadores y regeneración.

---

## 6. Tótem y formación

### Concepto

`[PROPUESTO, inspirado en el patrón histórico]` El tótem es a la vez avatar de mando, centro de formación y ancla de navegación.

Parámetros iniciales:

```ts
type TotemState = {
  position: Vec2;
  destination: Vec2 | null;
  moving: boolean;
  commandRadius: number; // 96
  dangerRadius: number;  // 180
  bondEnergy: number;    // 0..100
};
```

- Al moverse, las unidades siguen una cola de formación con separación de 18–28 px.
- Al detenerse, la tribu ocupa posiciones alrededor del tótem mediante slots reservados.
- Las unidades pueden abandonar la formación si existe una tarea válida dentro de 220 px.
- Si una unidad queda a más de 420 px, entra en `RETURN_TO_TOTEM`.
- La energía de vínculo baja un 1 % por segundo cuando la tribu se divide y se recupera alrededor del tótem; a cero, las unidades priorizan regresar.

**Aceptación:** con 8 unidades y 20 obstáculos, ninguna unidad debe quedarse bloqueada más de 3 segundos; si no encuentra ruta, debe ejecutar fallback hacia el último punto navegable del tótem.

---

## 7. IA de unidades

### 7.1 Máquina de estados común

```text
FOLLOW_TOTEM
  ├─ STOPPED_FORMATION
  ├─ SEEK_TASK
  │    ├─ GATHER
  │    ├─ HUNT
  │    ├─ BUILD
  │    └─ INVESTIGATE
  ├─ FLEE
  ├─ COMBAT
  ├─ RETURN_WITH_LOAD
  ├─ RESTORE_HEALTH
  └─ DOWNED / DEAD
```

Cada transición debe tener una razón registrable (`task-found`, `threat-nearby`, `low-health`, `over-capacity`, etc.) para depuración y tutorial.

### 7.2 Puntuación de tareas

Cada unidad evalúa tareas candidatas:

```ts
score = roleAffinity
      * distanceFactor
      * urgency
      * resourceValue
      * safetyFactor;
```

La unidad solo acepta la tarea si `score >= 0.35`. El jugador no asigna manualmente en v0.1; puede influir mediante órdenes globales: **Recolectar**, **Defender**, **Retirarse**.

### 7.3 Roles iniciales

| Rol | Tarea principal | Herramienta | Debilidad |
|---|---|---|---|
| Explorador | revelar mapa, detectar amenazas | brújula | poco daño |
| Leñador | madera | hacha | corto alcance |
| Recolectora | comida vegetal | cesta | baja defensa |
| Cazador | fauna y carne | lanza/arco | munición limitada |
| Guardián | proteger formación | escudo | lento |
| Artesana | fabricar/mejorar | kit | no combate |

**Aceptación:** una unidad recolectora no intenta minar piedra; un cazador prioriza una presa válida antes que un arbusto; una unidad herida abandona una tarea de riesgo y retorna si su vida baja del 30 %.

---

## 8. Recursos y economía

### Recursos

| Recurso | Obtención | Uso v0.1 | Riesgo |
|---|---|---|---|
| Comida | caza, bayas, pesca | hambre, reclutamiento | caduca lentamente |
| Madera | árboles y restos | herramientas, hoguera | requiere exposición |
| Piedra | vetas y ruinas | mejoras, defensas | transporte lento |
| Brillo | ruinas y guardianes | investigación | zonas peligrosas |

`[PROPUESTO]` Sin inventario individual complejo: las unidades transportan una carga temporal y la depositan en el tótem o campamento. Capacidad base: 3 unidades de carga por recolector; capacidad global inicial: 40.

### Reglas de hambre

- consumo: `0.015 comida / unidad / segundo` en velocidad normal;
- si la reserva llega a 0, cada unidad pierde `1 HP/s` después de 20 s de gracia;
- comer en campamento recupera 10 % de vida por segundo, hasta 60 %;
- la comida no se consume durante la pausa.

### Economía de reclutamiento

Coste de nuevos miembros:

```text
foodCost = 8 + 4 * currentPopulation
woodCost = 4 + 2 * currentPopulation
```

El coste debe mostrarse antes de confirmar y nunca permitir saldo negativo.

**Aceptación:** recoger un recurso actualiza el HUD en el mismo tick de simulación; recargar la partida conserva cantidades exactas; un recurso agotado no vuelve a estar disponible hasta que su temporizador de regeneración termina.

---

## 9. Combate

### Principios

El combate es autónomo y legible. El jugador decide posicionamiento, composición, retirada y prioridad global; no hace clics de ataque por unidad.

### Datos mínimos

```ts
type CombatStats = {
  hp: number;
  maxHp: number;
  damage: number;
  range: number;
  attackCooldown: number;
  armor: number;
  morale: number;
};
```

### Prioridad de objetivos

1. enemigo que ataca al tótem;
2. enemigo dentro de la formación;
3. enemigo con menor vida si está dentro de alcance;
4. amenaza más cercana.

### Resolución

`damageTaken = max(1, attacker.damage - defender.armor)`  
`hitChance = clamp(0.65 + attacker.morale*0.2 - distancePenalty, 0.1, 0.95)`

El primer prototipo puede usar daño determinista con una semilla de combate para que los tests sean reproducibles.

### Retirada

Si la media de vida del grupo baja del 35 %, o si muere el Guardián, la IA propone retirada. El jugador la confirma con la orden global o el sistema la ejecuta automáticamente si la energía de vínculo es 0.

**Aceptación:** un combate termina en victoria, retirada o derrota; no existen estados infinitos; cada muerte muestra atacante, víctima y causa en el registro de depuración.

---

## 10. Progresión

### Árbol de tecnología v0.1

```text
Supervivencia
├─ Cestas reforzadas       (+25 % capacidad de comida)
├─ Hoguera estable         (cura y conserva comida)
└─ Curación con hierbas    (desbloquea recuperación)

Defensa
├─ Escudos de corteza      (+2 armadura)
├─ Formación cerrada       (-15 % daño recibido)
└─ Trampa de espinas       (defensa de campamento)

Exploración
├─ Mapas de piedra         (+20 % radio revelado)
├─ Señales de peligro      (amenazas visibles antes)
└─ Rito de la Gran Hoguera (condición de victoria)
```

Cada nodo cuesta Brillo y requiere el anterior. El árbol debe estar definido en JSON, no codificado en botones.

### Recompensa y persistencia

- La partida guarda semilla, tick, entidades y progreso de investigación.
- Los desbloqueos permanentes de metajuego se limitan a cosméticos y semillas especiales; no aumentar estadísticas entre partidas en v0.1.
- Guardado automático cada 15 s y al pausar.

---

## 11. Arquitectura técnica para Codex

### Stack recomendado

`[PROPUESTO]` TypeScript + Vite + Phaser 3 para el mundo 2D, con HUD y menús en DOM. Phaser encaja con sprites, cámara cenital, input y render 2D; la simulación debe permanecer separada del render según la guía de arquitectura.

### Capas

```text
src/
  app/              // bootstrap, escenas, configuración
  simulation/
    world.ts        // estado serializable
    tick.ts         // reloj fijo
    entities/
    systems/        // movement, needs, gathering, combat, progression
    ai/             // estados y selección de tareas
    procgen/        // semilla, biomas, recursos, spawns
  render/
    sprites/
    animation/
    camera/
    effects/
  input/
    actions.ts      // mapa físico → acciones semánticas
  ui/
    hud/
    menus/
    accessibility/
  data/
    roles.json
    technologies.json
    biomes.json
  persistence/
    save-game.ts
  debug/
    overlay.ts
    replay.ts
```

### Bucle fijo

- simulación: 20 ticks por segundo;
- render: `requestAnimationFrame` independiente;
- acumulador de tiempo con máximo de 4 ticks por frame para evitar espirales;
- renderer interpola entre estados, pero nunca modifica la verdad de simulación.

### Contrato de estado

```ts
type GameState = {
  version: 1;
  seed: string;
  tick: number;
  phase: 'playing' | 'victory' | 'defeat' | 'paused';
  totem: TotemState;
  units: UnitState[];
  resources: ResourceNode[];
  threats: ThreatState[];
  inventory: Inventory;
  research: ResearchState;
};
```

Regla: ningún objeto Phaser, textura, escena o referencia DOM puede entrar en `GameState`.

### Futuro online

El modo online se añadirá después del vertical slice local:

- servidor autoritativo con el mismo módulo de simulación;
- cliente envía acciones semánticas, no posiciones finales;
- snapshots de estado y reconciliación;
- semilla y reglas versionadas;
- anti-cheat: el servidor valida costes, alcance, cooldowns y daño.

No iniciar networking hasta que el replay local sea determinista.

---

## 12. UI, arte y audio

### HUD

- esquina superior izquierda: comida, población, salud del tótem, objetivo;
- esquina superior derecha: minimapa y semilla opcional;
- parte inferior: orden global, pausa, velocidad, tecnología;
- panel de unidad: rol, vida, carga, estado IA y equipo;
- mensajes breves de causa: “La cazadora vuelve: amenaza cercana”.

Usar DOM para texto, botones y accesibilidad; usar canvas solo para el campo de juego y feedback diegético.

### Pixel art

`[PROPUESTO]`

- resolución lógica 320×180 escalada por entero;
- tiles de 16×16;
- unidades de 16×20 a 24×28;
- tótem de 32×40;
- paleta limitada por bioma, con colores reservados para estados: verde, ámbar, rojo, azul.

Todos los assets deben tener claves de manifiesto estables, por ejemplo `unit.hunter.idle`, `resource.tree.01`, `ui.icon.food`; los nombres de archivo no deben formar parte del API del juego.

### Audio

Prioridad: pasos, recolección, impacto, alarma, muerte, victoria y confirmación de investigación. El mezclador debe permitir silenciar música y efectos por separado.

---

## 13. QA y criterios de aceptación del vertical slice

### Tests automáticos

- generación con la misma semilla produce el mismo mapa;
- guardar y cargar produce un estado profundo equivalente;
- costes nunca generan recursos negativos;
- tick fijo produce el mismo resultado con el mismo input;
- todas las transiciones de IA son alcanzables y tienen fallback;
- daño, cooldown y muerte son deterministas en modo test;
- pausa congela el reloj de simulación.

### Pruebas manuales

- teclado y ratón;
- ventana 1280×720 y 1920×1080;
- escala de navegador 100 % y 150 %;
- pérdida de foco y recuperación;
- mapa sin ruta válida;
- 8 unidades en combate;
- guardado durante recolección y durante combate;
- lector de teclado para menú y panel de tribu.

### Definición de terminado del vertical slice

El slice está terminado cuando:

1. una persona nueva entiende el objetivo en menos de 90 segundos;
2. puede reclutar una unidad, recolectar dos recursos y sobrevivir a un combate;
3. puede ganar o perder en menos de 25 minutos;
4. no hay bloqueos conocidos que impidan completar la partida;
5. el replay de una semilla produce el mismo resultado en dos ejecuciones;
6. el rendimiento mantiene 60 FPS con 8 unidades, 40 nodos de recursos y 12 amenazas en un portátil normal.

---

## 14. Roadmap por hitos

### Hito 0 — Fundaciones (1–2 días)

- repositorio TypeScript/Vite/Phaser;
- acciones de input;
- reloj fijo;
- `GameState` y guardado mínimo;
- escena vacía con cámara.

**Salida:** movimiento del tótem reproducible y estado serializable.

### Hito 1 — Fantasía jugable (3–5 días)

- mapa procedural básico;
- tótem, dos unidades y formación;
- cámara, sprites provisionales y HUD;
- seguir/detener/pausar.

**Salida:** caminar y reunir la tribu se siente estable.

### Hito 2 — Supervivencia (4–6 días)

- recursos, cargas, depósito;
- hambre;
- tareas automáticas;
- reclutamiento.

**Salida:** bucle de exploración y crecimiento completo.

### Hito 3 — Conflicto (4–6 días)

- fauna hostil;
- combate, retirada y muerte;
- primer enemigo tribal;
- feedback de peligro.

**Salida:** partida con riesgo y derrota comprensibles.

### Hito 4 — Progresión (3–5 días)

- árbol de tecnología;
- Gran Hoguera;
- victoria;
- guardado automático y pantalla de resultados.

**Salida:** vertical slice completo de 15–25 minutos.

### Hito 5 — Pulido (5–8 días)

- pixel art final del slice;
- audio;
- tutorial contextual;
- accesibilidad;
- telemetría local y herramientas de replay.

**Salida:** demo compartible.

### Hito 6 — Preparación online (posterior)

- extraer simulación a paquete compartido;
- servidor autoritativo;
- lobby y reconexión;
- sincronización de snapshots;
- pruebas de carga.

No se considera parte del MVP local.

---

## 15. Riesgos y decisiones abiertas

| Riesgo | Mitigación |
|---|---|
| IA parece errática | máquina de estados visible, razones de transición y replay |
| demasiada microgestión | órdenes globales y roles con prioridades claras |
| pixel art ilegible | siluetas únicas, iconos de estado y zoom limitado |
| combate frustrante | telemetría de causa de muerte y retirada automática configurable |
| online prematuro | congelar red hasta lograr determinismo local |
| similitud excesiva con la referencia | nombres, arte, mundo, roles, economía y progresión propios |

Decisiones para el siguiente documento de producción:

- nombre definitivo;
- número y tipo de biomas finales;
- si el objetivo de victoria es fijo o variable por semilla;
- si el tótem puede recibir daño directo;
- si el modo online será cooperativo, competitivo o ambos.

---

## 16. Primer paquete de tareas para Codex

1. Crear el proyecto TypeScript/Vite/Phaser y configurar lint, test y build.
2. Implementar `GameState`, `Vec2`, reloj fijo y serialización.
3. Implementar el mapa con semilla y chunks.
4. Implementar tótem arrastrable y mapa de acciones.
5. Implementar `UnitState` y estados `FOLLOW_TOTEM`, `STOPPED_FORMATION`, `SEEK_TASK`, `RETURN_WITH_LOAD`.
6. Añadir tres nodos de recursos y recolección automática.
7. Añadir HUD de comida, población y objetivo.
8. Añadir un test de replay: misma semilla + mismas acciones = mismo hash de estado final.

**Criterio global:** cada tarea debe poder ejecutarse y validarse de forma independiente; no introducir networking, assets finales ni sistemas de construcción antes de que el replay local sea determinista.

---

## Fuentes consultadas

- [Wanderers.io Wiki — The Tribe](https://wanderersio.fandom.com/wiki/The_Tribe) — comportamiento de seguimiento, recolección y pérdida de la tribu.
- [Wanderers.io Wiki — página principal](https://wanderersio.fandom.com/wiki/Wanderers.io_Wiki) — contexto del juego, modos y documentación comunitaria.
- [Miniplay — Wanderers.io](https://www.miniplay.com/game/wanderers-io) — descripción de recursos, reclutamiento, equipamiento y tecnologías.
- [Not Doppler — Wanderers.io](https://www.notdoppler.com/wanderersio.php) — atribución a Rezoner y descripción resumida del objetivo.
- [GitHub — Avoxel284/wanderersio](https://github.com/Avoxel284/wanderersio) — proyecto de preservación, enlaces de archivo y advertencia sobre ingeniería inversa.
- [Yepi — Wanderers.io](https://yepi.com/games/wanderersio) — ficha histórica con fecha, controles y resumen de recursos.
- [Wanderers.userecho — beta de 2017](https://wanderers.userecho.com/communities/1/topics/7-wanderersio-verified-discord-server) — evidencia comunitaria de la etapa beta.

**Nota:** las fuentes de terceros y comunitarias sirven para reconstruir la experiencia histórica, no como licencia para reutilizar contenido protegido. Este GDD define un juego nuevo.

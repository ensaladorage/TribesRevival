# IMPLEMENTATION_STATUS --- Tribes Revival

## Sprites de nodos de piedra y Brillo — 07-11-2026

- Reemplazadas las mallas provisionales de `Rock.tscn` y `Spark.tscn`,
  incluido el halo de Brillo, por sprites pequeños. Añadidas `RockLarge.tscn`
  y `SparkLarge.tscn`; las cuatro heredan `ResourceSprite.tscn`, con Nearest,
  billboard, recorte AtlasTexture y apoyo inferior en el terreno.
- `world_view.gd` elige tamaño con probabilidad equivalente por semilla/ID,
  mediante PRNG de apariencia independiente. Ambas variantes conservan los
  datos de recurso originales; no cambian cantidades, rendimiento, tier,
  posiciones, radios, generación ni formato de guardado. No se configura ni
  se referencia el sprite de piedra de nivel 2 en escenas o scripts.
- Verificado en Godot 4.7.2: importación, carga de 36 scripts/79 escenas,
  10946 comprobaciones de datos y guardado actual y 29309 de decoración.
  Comprobación dirigida de recursos en 32 semillas: sin meshes, Nearest,
  variedad estable tras reconstruir desde JSON y estado intacto. Reparto:
  86/81 piedras pequeñas/grandes y 89/100 nodos de Brillo pequeños/grandes.
- Revisada captura conjunta de las cuatro variantes junto a un minion para
  comprobar escala y apoyo. Pendiente de ajuste artístico por el usuario y
  revisión manual de las escenas desde el Inspector.

## Centrado y seguimiento del efecto de curación — 07-11-2026

- Centrado en X/Z el sprite de `HealEffect.tscn`, conservando su altura,
  escala y animación. Retirado de `heal_effect_view.gd` el desplazamiento,
  ascenso y encogimiento que se aplicaban a las antiguas cruces 3D.
- `world_view.gd` sigue la posición visible/interpolada del minion objetivo,
  en lugar de adelantarse a la posición lógica del siguiente tick.
- Verificado mediante comprobación dirigida sin ticks: seis clases, cuatro
  fases de interpolación, transform editable intacto, estado sin mutaciones
  y retirada del efecto al expirar. Pasan carga de 36 scripts/76 escenas y
  10946 comprobaciones de datos/guardado actual. Revisada captura centrada
  con el efecto sobre un minion; queda la prueba manual durante movimiento.

## Filtro Nearest en toda la interfaz — 07-11-2026

- Configurado `textures/canvas_textures/default_texture_filter=0` en
  `godot/project.godot`: HUD, menús, tooltips y controles 2D nuevos heredan
  Nearest. Se mantienen las sobrescrituras Nearest existentes.
- Corregido el AnimatedSprite3D del fuego de `Campfire.tscn`, que todavía
  conservaba el filtro predeterminado con suavizado.
- Verificado con Godot 4.7.2: valor efectivo Nearest del viewport y recorrido
  de las 76 escenas, sin sobrescrituras lineales en CanvasItem ni sprites 3D
  con otro filtro; carga de scripts/escenas, 101 comprobaciones de callbacks
  de menús y prueba de entrada de colocación, sin errores.
- Pendiente de revisión visual en el editor y durante una partida; no se
  modifican escalas, posiciones ni imágenes originales.

## Vegetación decorativa con sprites en Godot — 07-11-2026

- Sustituidas por Sprite3D las setas y el césped 3D provisionales; eliminadas
  las cuatro escenas de flores y su generación. Integrados los ocho sprites
  existentes de `godot/assets/environment/`: tres tamaños de setas, tres de
  arbustos decorativos y dos de césped, con escenas heredadas editables.
- Aumentada la cantidad a `12–18` por claro (incluido el inicial), `18–26`
  por pradera y `16–24` por bosque. Se conservan el margen interior, la escala
  lógica y el máximo de dos setas; ninguna decoración en pedregales/ruinas.
  Los arbustos decorativos no sustituyen los nodos recolectables de bayas.
- Variante y reflejo estables por semilla/ID en presentación, sin campos
  nuevos de guardado ni consumo del PRNG de simulación.
- Verificado con Godot 4.7.2 en Windows: importación, carga de 36 scripts y
  76 escenas; suite de decoración (29309 comprobaciones en 32 semillas), datos
  y guardado actual (10946 comparaciones), callbacks de menús (101), entrada
  de colocación y las dos suites tácticas. Todas las comprobaciones Godot pasan.
- Revisadas cuatro capturas renderizadas con Compatibility: claro inicial
  a zoom normal y en detalle, bosque y pradera. Pendientes una partida manual
  con movimiento/zoom y la comprobación de edición desde el Inspector.
- `verify_original.py` no pasa: su inventario histórico no coincide con numerosos
  archivos actuales del repositorio, incluidos documentos y fuentes Babylon.
  No se regenera el inventario ni se modifican esas fuentes para esta tarea.

## Presentación numérica en Godot — 06-11-2026

- Recursos, XP, niveles y puntos de tecnologías usan el formato entero común
  de `godot/scripts/ui/player_numbers.gd`, también para números leídos de JSON.
  Los porcentajes de eficiencia y el daño admiten fracciones decimales por
  decisión explícita del usuario. La precisión interna no cambia.
- Verificados importación, scripts/escenas y pruebas puras de formato y
  guardado actual. La presentación al cargar una partida queda pendiente de
  revisión manual; no se automatiza gameplay ni una comprobación visual.

**Propósito:** registro del estado real conocido de implementación y
validación. No define mecánicas ni sustituye el GDD.

**Alcance de persistencia:** el guardado y la carga de la versión actual
funcionan. La compatibilidad y migración entre versiones se aplazan a una
fase avanzada; las menciones a v16/v17 más abajo documentan comportamiento
ya existente, no trabajo ni validación que debamos priorizar ahora.

## Revisión de progreso --- 04-11-2026

### Formación exclusiva del movimiento del tótem

- Eliminado el retorno sin trabajo a slots de 3,25 m. El descanso empieza
  donde termina la tarea si está dentro del radio de mando, incluida la
  franja exterior al anillo de paseos de 8 m. Fuera de rango, vuelve solo
  hasta entrar por el borde más cercano, a 8 m/s, y pasa a idle.
- Formación reservada al seguimiento del tótem a 10 m/s; se marca al alcanzar
  el slot y después se reevalúan tareas/idle. La huida ya no usa ese slot.
  Reclutamiento dentro del rango empieza disponible sin regreso central.
- Los destinos antiguos de `return-to-totem` no fuerzan volver al centro:
  se recalcula el acceso y se cancela al estar dentro. GameState v17 sin
  migración adicional.
- Verificado: TypeScript y 36 pruebas dirigidas de decisiones idle/rango,
  geometría de navegación y persistencia. Se adaptaron expectativas antiguas
  de regresión; no se ejecutó automatización visual ni del loop de gameplay.
- Pendiente de validación manual: finales de cada tarea dentro/fuera del
  rango, cargas antiguas, retorno al borde y transición formación/idle al
  mover el tótem con 2 y 8 minions.

### Comunicación de enemigos y animales

- Implementado `minionAwareness.ts` e integrado con detección, combate y
  caza: cualquier minion puede compartir avistamientos actuales; un objetivo
  sin atender llama al combatiente/cazador libre más cercano, fuera incluso
  de su radio personal. Mantiene reservas observadas y evita duplicarlas por
  llamadas; enemigos antes que animales y recursos. Respeta roles, tareas
  ocupadas, movimiento del tótem y límite de combate del cazador.
- Las llamadas son temporales, silenciosas y usan tareas/campos existentes.
  GameState v17 no necesita migración ni campos nuevos.
- Verificado: TypeScript y 21 pruebas dirigidas de reglas puras de llamadas,
  posiciones de combate y persistencia en tres archivos. No se han añadido
  ni ejecutado pruebas visuales o del loop de gameplay para esta ampliación.
- Pendiente: comprobar manualmente llamadas a respondedores lejanos, pérdida
  de objetivos, prioridades y ausencia de aglomeraciones con la tribu completa.

### Actualización de pruebas existentes de combate

- Adaptados los escenarios de `stepSimulation.test.ts` a huecos de ataque
  válidos, fuera del tótem y sin bárbaros solapados. La retirada comprueba
  avance hacia el tótem admitiendo rodeos; el cooldown conserva sus plazos
  y verifica el siguiente golpe desde una posición válida.
- El regreso a aparición compara coordenadas con tolerancia decimal.
- Verificado: las 42 pruebas existentes de ese archivo pasan. Este ajuste
  modifica pruebas y documentación, sin cambiar la lógica de juego. La
  fluidez visual y el playtest de navegación siguen pendientes del usuario.

### Continuidad de navegación y posiciones de combate

- Implementados rodeos con waypoints alrededor de trabajadores/actores,
  continuidad del lado de evasión y replanteamiento espaciado ante bloqueo.
  El idle espera antes de descartar su destino. Las reservas predicen el
  siguiente waypoint en vez de prolongar el movimiento hasta el objetivo final.
- Reservas de combate en `minionCombatPositions.ts`: conserva huecos válidos
  al incorporarse atacantes; anillos separados de cuerpo a cuerpo y cazadores,
  espera exterior si no hay plaza, validación de espacio y límites.
- Bárbaros y aliados evitan sus trayectorias; la corrección residual de un
  minion contra un bárbaro ya no desplaza al enemigo.
- Velocidad ordinaria/caza/combate 6 m/s, idle 3 m/s, seguimiento del tótem
  10 m/s y retorno sin trabajo 8 m/s. Sustituye los parámetros anteriores.
- Bárbaros: persecución a 7 m/s y regreso al punto de aparición a 8 m/s.
- El campo opcional de navegación conserva rutas y offsets en GameState v17;
  los guardados anteriores no lo necesitan. No cambia inventario ni progresión.
- Verificado: TypeScript, 37 pruebas dirigidas en cuatro archivos (geometría,
  asignación de huecos, idle y persistencia) y `git diff --check`.
  No se ejecutaron pruebas visuales ni del loop de gameplay.
- Pendiente de playtest manual: vibraciones, bloqueos, rodeos a trabajadores,
  combate con 2/8 minions y distintos roles, bordes y varios bárbaros.

### Evitación entre aliados y visibilidad idle

- Navegación compartida en idle, trabajo, regreso, formación, caza, huida
  y combate: predicción de 0,6 s, separación de 0,94 m, desvíos, frenado y
  espera. Se comprueban posiciones iniciales y movimientos reservados por tick.
- Los idles ceden ante tareas activas, incluso durante pausas; los trabajadores
  estacionarios conservan prioridad. Un paseo bloqueado descarta su destino
  para replantearlo tras otra pausa. Las acciones comprueban la llegada resuelta.
- Idle y reagrupación puntúan visibilidad y espacio entre aliados; se comparte
  orientación de cámara y se permite usar la zona posterior. La reagrupación
  conserva su objetivo durante el regreso para evitar cambios de slot continuos.
- Se mantienen 3 m/s, destinos idle 4–8 m, pausas 1–3 s y regreso a 3,25 m.
  No se añaden datos de navegación persistentes; se mantiene GameState v17.
- Verificado: TypeScript y 30 pruebas dirigidas de geometría, idle y persistencia
  en 3 archivos. No se han ejecutado pruebas visuales ni del loop de gameplay.
- Pendiente: validación manual de cruces, fluidez, bloqueos, prioridades y
  visibilidad con 2 y 8 minions, también cerca de los bordes y en combate.

### Idle dinámico y reagrupación

- Implementado `minionIdle.ts`: paseos a 3 m/s, destinos de 4–8 m,
  pausas deterministas de 1–3 s y retorno sin trabajo a 3,25 m.
- El paseo conserva la tarea idle y la búsqueda de trabajo en cada tick.
  Se permiten trabajos encadenados; sin trabajo, fuera de 4 m se regresa.
  Asignar otra tarea o mover el tótem cancela destino/espera del paseo.
- La carga v16/v17 normaliza los nuevos datos idle opcionales y conserva
  los válidos; no cambia la versión del estado ni los identificadores de tareas.
- Verificado: TypeScript y 17 pruebas dirigidas de funciones puras y
  persistencia en 2 archivos. Sin automatización visual ni del loop.
- Pendiente: validar manualmente ritmo, separación, bordes, interrupciones,
  retorno y guardado/carga con 2 y 8 minions.

### Correcciones de HUD y nivel inicial

- Retirado el coste en puntos de los tooltips tecnológicos; sigue visible
  junto al icono y disponible en la etiqueta accesible del botón.

- El nivel inicial pasa a 0 con 0 XP, requisito inicial de 12 XP y 0 puntos.
  Guardados y metadatos admiten nivel 0; los niveles existentes se conservan.
- Los paneles de gestión se posicionan sobre la fila de botones sin afectar
  su distribución; los tooltips de sus tarjetas se ajustan al área visible
  del juego al pasar el puntero, recibir foco o redimensionar.
- El requisito tecnológico se expresa como «Nivel requerido: 2» para
  Artesana/Mago y «Nivel requerido: 1» para Escudo.
- Verificado: TypeScript, 16 pruebas dirigidas de progresión y persistencia,
  y `git diff --check`. Servidor Vite disponible (HTTP 200).
- Pendiente: revisión visual manual de tooltips, botón Mejoras y reflujo.

### Tiempos de recolección

- Las acciones de árbol usan una base de 3 s; vetas de piedra tier 1,
  5 s; vetas tier 2, 7 s. Se conserva el efecto de velocidad de las
  herramientas sobre los tiempos base; los demás nodos mantienen 1,5 s.
- Verificado mediante TypeScript. Pendiente validar visualmente el ritmo
  en juego; no se han automatizado comprobaciones de loop de gameplay.

### Tres árboles tecnológicos, primera iteración

- Catálogo compartido por compra y HUD: Supervivencia/Artesana y
  Exploración/Mago requieren nivel 2; Combate/Escudo requiere nivel 1.
  Todas cuestan 1 punto; no se añadieron las tecnologías propuestas futuras.
- El panel abre con tres botones cerrados. Solo un árbol puede desplegarse,
  en una fila horizontal con reflujo, manteniendo los iconos y estilos actuales.
  Los tooltips incluyen nivel mínimo sin avisos de puntos faltantes.
- Se mantiene v17 y los desbloqueos previos; la selección del árbol no se guarda.
- Verificado: TypeScript y pruebas dirigidas de progresión/persistencia
  (`16` pruebas, `2` archivos). Incluyen requisitos con puntos disponibles,
  compra única, falta de puntos y conservación de desbloqueos heredados.
- Pendiente: comprobación manual del panel, teclado, reflujo y compras visibles.

### Economía y mejoras, fase 1

- **Economía centralizada:** `economyConfig.ts` es la fuente única de las
  curvas de Recolector, especializaciones, Escudo y herramientas. La
  simulación y el HUD consultan las mismas reglas; las compras consumen
  recursos solo cuando puede completarse toda la operación.
- **Minions:** Recolector conserva la curva por población viva; Leñador,
  Cazador, Artesana, Guardián y Escudo usan su curva por unidades activas.
  El Mago exterior transforma un Recolector por 2 Brillo, no aumenta la
  población y se limita a uno. Muertes y transformaciones recalculan desde
  la composición actual.
- **Herramientas:** los niveles 0–10 guardan costes de piedra, Brillo y Oro
  según corresponda. Hacha y Martillo usan velocidad `+0,5 %` a `+5 %` y
  probabilidad de un único drop adicional `0 %` a `30 %`; Espada aumenta
  el daño del Guardián `+0,25` a `+2,50`.
- **Piedra II:** `ResourceNode` admite tier serializable; una veta II queda
  bloqueada hasta Martillo +5. La generación de vetas II sigue aplazada
  porque sus parámetros de balance no están aprobados.
- **Guardado:** se conserva `GameState` v17. Al leer v16/v17 parcial se
  normalizan niveles de herramienta ausentes y los nodos sin tier se tratan
  como nivel 1, sin descartar el resto de la partida.

### Evidencia automática

- `npx tsc -b --pretty false`: correcto.
- `npm test`: correcto, 9 archivos y 82 pruebas. Incluye curvas, costes
  mixtos atómicos, Mago exterior, recálculo de Guardián, efectos/tablas,
  requisito Martillo +5 y migración v16/v17 parcial.

### Validación manual pendiente

Comprobar en navegador los costes e indicadores mixtos, recursos faltantes,
el límite exterior del Mago, los procs visibles de madera/piedra, el ritmo de
recolección y el balance del daño. Estas comprobaciones no se han sustituido
por automatización visual ni de loop de juego.

## Revisión de progreso --- 02-11-2026

### Alcance de esta revisión

Se han contrastado los documentos con el checkout local disponible y el
código fuente actual. Hay modificaciones locales sin confirmar en código y documentación.
Esta revisión corrigió el flujo del Mago para que su objeto transforme
un Recolector en lugar de crear un minion nuevo. Se ejecutó
`npm run build`; queda pendiente la validación manual por el usuario.

La inspección del código confirma que ya existen la transformación
exterior del Mago y las mejoras de hacha, martillo y espada,
además de persistencia en `GameState` versión 17 y migración desde la
versión 16. Esto acredita presencia de implementación en el checkout,
pero no demuestra su funcionamiento en ejecución ni su validación manual.

### Cambios visibles en el código actual

-   **Conversión del último recolector:** se permite transformarlo en
    leñador si existe al menos un cazador; sin cazadores, se mantiene el
    bloqueo y el tooltip explica el requisito. La regla se aplica tanto
    en la acción de simulación como en el estado interactivo del HUD.
    Artesana comparte esta protección: sin Cazador no se puede convertir
    al último Recolector. Mago y Guardián conservan la excepción por su
    capacidad de combate. Pendiente de validación manual en el navegador.
-   **Mago:** la tecnología cuesta 1 punto y desbloquea el objeto que
    transforma un Recolector en Mago. La transformación consume Brillo
    con la curva `2, 3, 3, 4, 4`, no aumenta la población total y respeta
    el máximo de 5 Magos; una entrega inválida no consume recursos. El
    modelo 3D de Artesana usa color gris. Compila; ambos cambios quedan
    pendientes de validación manual.
-   **Herramientas:** hay mejoras para hacha, martillo y espada, coste
    incremental en piedra, tope de nivel 10 y efectos conectados a la
    recolección de madera, duración de extracción y daño del Guardián.
-   **Guardado:** el estado actual es versión 17; el lector acepta v16 y
    v17 y rellena valores por defecto para los niveles y compras del
    Mago ausentes en v16. Los slots ocupados tienen una acción de borrado
    con confirmación, tanto desde Guardar como desde Cargar.
-   **Validación pendiente:** la tarjeta de tecnología del Mago y el flujo
    de borrado de slots compilan; queda pendiente comprobarlos manualmente
    en el juego.
-   **Tutorial:** retirado el texto sobre mejoras; la descripción del Mago
    ahora indica que es avanzado, poderoso en combate y necesario para
    Mazmorras.
-   **HUD:** la fila superior muestra los cinco recursos con iconos de
    pixel art y sus cantidades. Comida, Madera, Piedra, Brillo y Oro
    usan sprites PNG en `sprites/ui/`; los mismos iconos aparecen en
    los indicadores de coste. Las imágenes elegidas para roles y
    herramientas también sustituyen los modelos CSS en la lista lateral,
    el panel de tecnologías y mejoras, el acceso al Escudo y el tutorial.
    La Hoguera usa ahora su sprite en el botón del HUD; su modelo 3D de
    gameplay y el preview de colocación no se han modificado. La lista
    lateral mantiene el orden aprobado y Artesana y Mago permanecen ocultos
    hasta desbloquear sus tecnologías. El panel tecnológico muestra
    Artesana, Mago y Escudo, en ese orden.
    Tecnologías y Mejoras comparten
    un dock inferior izquierdo, con apertura exclusiva y paneles que
    reacomodan sus tarjetas según el ancho disponible. Las tres tarjetas
    de mejora muestran icono a la izquierda y nivel o `Max` a la derecha,
    con ancho reservado, y tooltip con efecto y coste; las
    tecnologías se presentan en horizontal con nombre y descripción en
    tooltip. El nivel colorea el fondo de la tarjeta lateral y el rótulo
    de nivel, sin teñir el modelo. El Escudo conserva su
    acceso superior derecho. Se corrigió la posición de Tecnologías, la
    orientación horizontal de las tarjetas, el color aplicado al fondo
    de la tarjeta lateral, el tooltip nativo duplicado y el anclaje de
    tooltips superiores/derechos para que aparezcan hacia dentro. El
    tooltip de Artesana se alinea desde el borde izquierdo de su tarjeta
    para que el texto se extienda hacia el interior de la pantalla.
-   **Debug:** el bloque agrupa pausa y velocidad, permanece oculto al
    inicio y se alterna con `Insert` o `Numpad0`; sus acciones se
    conservaron. La presentación queda pendiente de playtest manual.
-   **Compilación:** `npm run build` finalizó correctamente tras estos
    cambios. No se ejecutaron pruebas automatizadas ni playtest visual;
    Vite avisó que el chunk principal de JavaScript supera el límite de
    500 kB (salida minificada: aproximadamente 7,1 MB).

### Decisiones de diseño vigentes registradas

La decisión añadida en esta revisión es que el Mago requiera desbloquear
su tecnología por 1 punto; se mantienen las decisiones aprobadas:

-   En cuevas, el héroe legendario inicial cuenta para el límite de su
    clase; puede haber hasta cinco unidades legendarias adicionales, con
    un máximo de dos por clase y seis en total.
-   Las mejoras de herramientas usan nivel 0 neutro; `+1/+2` gris
    `#A7A7A7`; `+3/+4` verde `#3F8F54`; `+5/+6` cian `#168397`;
    `+7/+8/+9` violeta `#80508F`; y nivel 10 naranja `#B77D35`.
-   Las especializaciones del Mago, Nigromante y Fuego, quedan
    aplazadas.
-   El proyecto continúa siendo local y para un jugador. No se añade
    planificación multijugador.
-   La condición de victoria continúa sin diseñar.

Estas reglas permanecen especificadas en el GDD; no se copian aquí como
sustituto de la especificación.

### Validaciones manuales registradas

Se conservan como validaciones históricas comunicadas anteriormente:

-   Hitos 2, 3, 5A y 5B: registrados como implementados y validados
    manualmente.
-   Hito 4: registrado como completado, con pruebas automáticas y
    playtest manual de combate/HUD.
-   Hito 5C: registrado como completado y validado manualmente por el
    usuario.

No se han repetido estas pruebas durante esta revisión. Estos datos no
equivalen a una auditoría actual de los hitos 0--5.

### Tareas pendientes prioritarias

1.  Probar manualmente la tecnología del Mago: coste de 1 punto, posición
    después de Artesana en el menú, aparición de su objeto entre Artesana
    y Hoguera, conversión de Recolector con Brillo, límites, cancelación
    sobre objetivos inválidos y partida antigua con Magos ya transformados.
2.  Probar las mejoras de hacha, martillo y espada: coste en piedra,
    niveles `0–10`, efecto por nivel, tope, compra sin recursos
    suficientes y feedback visual.
3.  Comprobar que los efectos implementados coinciden con el GDD: hacha
    `+1` madera por acción y nivel; martillo `−5 %` de tiempo por nivel
    hasta `−50 %`; espada `+0,5` de daño por nivel.
4.  Completar el reclutamiento exterior de Pícaro y Paladín solo después
    de definir sus curvas de coste; esas curvas siguen sin estar
    decididas.
5.  Mantener Hitos 7--10 como pendientes según el roadmap.

### Evidencia de esta revisión

Se actualizó el GDD v0.6.0 para registrar el orden del HUD, la nueva tabla
de colores y el desbloqueo del Mago; QA_TEST_PLAN recoge los puntos de
comprobación manual. La compilación acredita coherencia de tipos y
empaquetado, no el aspecto visual ni la interacción en navegador. Quedan
pendientes las comprobaciones manuales del HUD y del desbloqueo.

------------------------------------------------------------------------

## Fuente y fiabilidad

El estado de Hitos 0--5 que sigue abajo procede de validaciones
históricas comunicadas antes del 01-11-2026 y no se repitió en esta
revisión. Para Hito 6, la revisión del 01-11-2026 inspeccionó el código
local; la existencia del código no equivale a validación de ejecución o
playtest.

## Hitos completados según el registro anterior

-   **Hito 0 --- Migración 3D:** motor/escena 3D, cámara ortográfica,
    terreno, tótem y unidades provisionales.
-   **Hito 1 --- Movimiento y formación:** arrastre del tótem,
    proyección del cursor, cámara de seguimiento, formación y pruebas
    deterministas.
-   **Hito 2 --- Supervivencia:** biomas, bayas, ramitas, cargas, tareas
    autónomas, drops, reclutamiento básico, hoguera, vida y curación.
    Registrado como implementado y validado manualmente.
-   **Hito 3 --- Recursos avanzados:** nodos de madera, piedra y Brillo,
    tala, drops e interacción por rol. Registrado como completado y
    validado.
-   **Hito 4 --- Conflicto:** bárbaros, conejos, combate, cadáveres,
    botín, HUD y derrota. Registrado como completado, con pruebas
    automáticas y playtest manual de combate/HUD.
-   **Hito 5A --- Lluvia y regeneración:** registrado como implementado
    y probado manualmente.
-   **Hito 5B --- Experiencia, tecnologías y equipo:** registrado como
    implementado y probado manualmente.
-   **Hito 5C --- Menú, tutorial y guardado:** registrado como
    completado y validado manualmente.

## Estado actual de Hito 6

-   **Mejoras de herramientas:** las tres acciones y sus efectos
    numéricos están presentes por inspección del código. Falta
    validación manual de costes, límites, efecto real y feedback.
-   **Reclutamiento legendario:** el Mago está presente por inspección
    del código y pendiente de playtest. Pícaro y Paladín no están
    implementados; sus curvas de coste exterior siguen pendientes de
    decisión de diseño.

## Pendiente de desarrollo

-   **Hito 7:** fronteras, campamentos, jefes, llaves y desbloqueo de
    regiones.
-   **Hito 8:** cuevas, expediciones legendarias, reclutamiento temporal
    y persistencia de encuentros/cofres/botín.
-   **Hito 9:** dirección visual final, modelos, animaciones, audio y
    feedback.
-   **Hito 10:** ampliación futura del guardado para regiones, llaves y
    cuevas; mantener la compatibilidad actual con `GameState` v16 y v17.

## Regla de mantenimiento

Actualizar este documento cuando el trabajo se ejecute y exista
evidencia del resultado. Diferenciar siempre implementación, tests
automáticos y validación manual. No marcar una función como validada
manualmente solo porque Codex haya escrito el código.


- Godot: escenas de presentación renombradas a `CharactersBase`, `Sheep` y `HealthController`; importación y validación estructural headless completadas. Los identificadores y semillas internos de `rabbit` se conservan por compatibilidad y determinismo. Pendiente comprobación visual en el editor.

- Godot: sprites propios asignados a recolector, cazador, guardián, artesano, leñador y mago; cada estado visual usa un fotograma. Importación y validación estructural headless correctas; apariencia y escala pendientes de revisión visual.

- Godot: el tótem jugable usa `TotemSprite.tscn` con `Totem 2.png`; el modelo anterior se conserva en `Totem3D.tscn`. Importación y validaciones estructural y de entrada de colocación completadas sin renderizado; pendiente revisión visual y arrastre manual.

- Godot: retirados título, mensaje y experiencia del overlay superior izquierdo. La casilla adicional del escudo usa dorado, incluido su borde cuando está vacía. Validación estructural y comprobación headless de estilos con daño y cambio de equipo correctas; pendiente revisión visual.

- Godot: HUD incorpora barra de experiencia y nivel con tooltip de progreso y fuentes de experiencia; validaciones estructural y de callbacks de menú completadas sin renderizado. Pendiente revisión visual, tooltip y disposición en distintas resoluciones.

- Godot: el material del tótem 3D incluye un contorno configurable; importación y validación estructural headless completadas. Aspecto y grosor pendientes de revisión visual en partida.
- Godot: el hacha del panel de reclutamiento usa un nodo `Icon` editable por
  separado. Comprobadas carga estructural, escala sin cambio de tamaño del
  botón y alternancia de texturas normal/deshabilitada mediante headless.
  Pendiente revisión visual en el editor.
- Godot: todos los iconos gráficos de los paneles del HUD usan un nodo `Icon`
  y un AtlasTexture editable; los recursos usan `IconSlot/Icon`.
  Verificadas carga estructural, escala independiente, filtros del ratón y
  texturas normal/deshabilitada de 14 botones en headless; callbacks de menú:
  101 comprobaciones correctas. Pendiente revisión visual de tarjetas y recursos.

- Cadáveres Godot: integradas las hojas Dead_Minion_Spritesheet y Dead_Enemy_Spritesheet mediante AnimatedSprite3D, siete frames y reproducción única. Validados carga estructural, reproducción y permanencia del último frame; 16119 comprobaciones de datos correctas. Pendiente comprobación visual y saqueo en partida.

- IA táctica Godot implementada: civiles que buscan distancia de amenazas y
  espacio entre aliados dentro del mando; continúan esquivando si los persiguen
  y pueden detenerse cuando están seguros. Bárbaros que priorizan atacantes,
  mantienen objetivos estables y alternan golpes con maniobras cortas bajo
  presión de varios combatientes.
  Verificados: persecución determinista, seis y ocho civiles, dos perseguidores,
  cuatro esquinas, límites y separación, mando móvil, retorno gradual tras
  desplazar el tótem, pausa, fin de amenaza, guardado/carga, combate y saqueo
  con estadísticas normales. Pasan las dos suites tácticas, la validación
  estructural y 16119 comprobaciones de datos. Revisadas cinco capturas
  renderizadas de un combate mixto con Godot Compatibility.
  Con mando móvil, el escenario de prueba registra hasta 0,04 m fuera del radio
  debido al desplazamiento del propio tótem; se verifica ausencia de huida
  voluntaria hacia fuera, recuperación en menos de un segundo y regreso dentro
  del límite al detenerse. La fluidez se apoya en trazas y capturas; queda como
  ajuste de sensaciones la valoración del usuario en una partida libre.

- Hoguera Godot: fuego en bucle y brasas intermitentes configurados como AnimatedSprite3D editables en Campfire.tscn. Validados estructura y reproducción headless; revisión visual de posición y ritmo pendiente.

- Hoguera: tres animaciones de brasas alternadas con pausas editables. Secuencia y carga verificadas headless; pendiente revisión visual.

- Hoguera: brasas en tres nodos independientes con bucle y pausa transparente editable; inicio y duración verificados headless, pendiente revisión visual.

- Hoguera HUD y cursor: corregido el AtlasTexture del icono nuevo de
  1254 × 1254 (el recorte anterior de 64 × 64 mostraba transparencia).
  La previsualización de colocación comparte el nuevo icono y conserva su
  tamaño mundial mediante `pixel_size`. Verificados importación, textura
  con contenido visible, recurso compartido, tamaño, estructura, callbacks
  de menú y entrada de colocación en Godot headless. Comprobador estático:
  cero errores y avisos. Pendiente revisión visual en partida.

- Combate Godot y tótem levantado: el minion que supera los 10 m del mando
  termina el impulso activo y pasa a seguimiento sin soltar el tótem ni iniciar
  otro golpe. La comprobación precede a la adquisición de amenazas, incluso
  cuando el enemigo permanece dentro del mando. Regresión reproducida antes
  del cambio y superada después para guardián, leñador y cazador, con y sin
  impulso activo. Pasan `test_tactical_behavior.gd`, `test_tactical_edges.gd`, validación estructural
  (36 scripts y 79 escenas) y 10946 comparaciones de datos/guardados en Godot
  4.7.2 headless. La estructura emite avisos de UID de Theme y usa las rutas
  de archivo como alternativa. Pendiente comprobación manual del arrastre.

# GDD — Tribes Revival (Tribu del Tótem 3D)

## Documento de diseño del juego

**Versión:** 0.6.0
**Plataforma objetivo:** navegador de escritorio
**Modo:** juego local para un jugador
**Presentación:** supervivencia y estrategia ligera en mundo 3D con cámara isométrica
**Relación con Wanderers.io:** inspiración mecánica; mundo, economía, nomenclatura y recursos propios.

## Cómo leer este documento

Este documento define **qué juego se quiere construir**: fantasía, pilares, alcance, reglas, sistemas, controles, progresión y comportamiento deseado, estén implementados o no. No es un registro del estado actual del código ni un plan de trabajo. Para implementación, planificación y validación, consultar `TECHNICAL_DESIGN.md`, `ROADMAP.md`, `IMPLEMENTATION_STATUS.md`, `QA_TEST_PLAN.md` y `AGENTS.md`.

Las etiquetas `[DECISIÓN DE DISEÑO]`, `[PROPUESTO]` e `[INFERIDO]` distinguen decisiones del proyecto de elementos aún por concretar o referencias históricas. Una regla sin estado de implementación sigue siendo parte del diseño aprobado o provisional según su etiqueta.

---

## 1. Visión del producto
**Tribes Revival** es un juego 3D de supervivencia y estrategia ligera.
El jugador guía una pequeña comunidad mediante un tótem que puede
desplazar por un mundo isométrico. Las unidades no se controlan una por
una de forma constante: interpretan la posición del tótem, el estado de
la tribu y las oportunidades del entorno.
La fantasía principal es actuar como guía de una comunidad viva:
-   explorar un territorio peligroso;
-   detenerse en lugares con recursos;
-   dejar que los especialistas trabajen de forma autónoma;
-   decidir cuándo crecer, investigar, equiparse o huir;
-   sobrevivir, ampliar el territorio, mejorar herramientas y explorar
    cuevas; la condición de victoria todavía no está definida.
### Experiencia objetivo de una partida inicial
Una partida inicial de referencia de 15–25 minutos con:
-   cámara ortográfica isométrica;
-   terreno 3D navegable;
-   tótem arrastrable;
-   dos unidades autónomas;
-   comida, madera, piedra y Brillo;
-   recolección contextual;
-   fauna y amenazas;
-   reclutamiento y tres tecnologías;
-   derrota clara; condición de victoria pendiente de diseño;
-   guardado y replay determinista.
------------------------------------------------------------------------

---

## 2. Pilares de diseño
1.  **Dirección indirecta:** el tótem es la orden principal; la tribu
    reacciona.
2.  **Vida autónoma:** la IA debe parecer útil sin convertirse en una
    caja negra.
3.  **Riesgo legible:** el jugador debe entender por qué una expedición
    salió mal.
4.  **Crecimiento visible:** la comunidad cambia visual y
    funcionalmente.
5.  **3D ampliable:** el render puede evolucionar desde formas simples
    hasta modelos y postprocesado.
6.  **Simulación independiente:** el estado jugable no depende de
    meshes, escenas o materiales.
### Fuera de alcance del MVP
-   ciudades complejas;
-   diplomacia avanzada;
-   campaña narrativa extensa;
-   economía entre jugadores;
-   condición de victoria definitiva;
-   especializaciones avanzadas del Mago (Nigromante y Fuego), en una ampliación futura.
------------------------------------------------------------------------

---

## 3. Bucle principal
``` text
Mover tótem → explorar → detectar recursos o amenaza
→ detenerse → unidades trabajan o combaten
→ depositar recursos → reclutar/equipar/investigar
→ elegir nueva ruta → repetir
```
### Partida tipo
1.  El jugador comienza con un `gatherer` y un `lumberjack` o `hunter`
    aleatorio.
2.  Mueve el tótem hacia un claro o una zona con recursos.
3.  Los minions detectan su entorno y realizan las acciones permitidas
    por sus herramientas.
4.  La tribu obtiene comida, madera y otros materiales para reclutar y
    equiparse.
5.  El jugador decide si mantener la posición, curarse, crecer o
    avanzar.
6.  Aparecen conejos y bárbaros; los minions adecuados cazan o combaten
    automáticamente.
7.  El jugador elige mejoras y nuevos roles al subir de nivel.
8.  La tribu busca mejorar sus herramientas, desbloquear regiones y
    preparar expediciones a campamentos y cuevas.
### Estados finales
`[DECISIÓN DEL PROYECTO]`
-   **Victoria:** no definida. No se consideran actuales ni aprobadas la
    Gran Hoguera, las piedras de memoria ni ningún rito final.
-   **Derrota:** `aliveUnits == 0`.
-   Mover el tótem sirve para reagrupar; no cancela automáticamente un combate activo.
------------------------------------------------------------------------

---

## 4. Cámara y presentación 3D
### Cámara
`[DECISIÓN DE DISEÑO]`
-   cámara ortográfica isométrica;
-   ángulo horizontal: 45°;
-   inclinación: 35°;
-   seguimiento suave del tótem;
-   zoom configurable mediante límites de debug; valores actuales: 0.5×
    cerca y 1× lejos;
-   rotación de cámara bloqueada durante el MVP;
-   pan opcional con botón central o tecla modificadora en una fase
    posterior.
La cámara debe mostrar suficiente terreno para que el jugador anticipe
recursos y amenazas, sin perder la legibilidad de las unidades.
### Escala del mundo
-   1 unidad lógica = 1 metro;
-   límites provisionales del prototipo: 160 × 160 metros;
-   mundo objetivo: mapa circular con radio y contenido configurables;
-   chunks de 16 × 16 metros;
-   radio de mando del tótem: 10 metros;
-   radio de peligro: 18 metros;
-   radio de formación inicial: 4 metros, para mantener los minions
    visibles alrededor del tótem;
`[DECISIÓN DE DISEÑO]` El mundo jugable será circular. Para pruebas de escala y navegación puede utilizarse un área de referencia de `160 × 160 metros`; una expansión posterior podrá distribuir el mundo en chunks alrededor del círculo.
### Estilo 3D inicial
El primer prototipo usará geometría simple, colores planos, sombras
suaves y materiales sin texturas complejas. El aspecto final podrá
evolucionar hacia:
-   low-poly;
-   texturas pixeladas;
-   render a baja resolución;
-   outlines;
-   dithering;
-   sombras duras;
-   postprocesado retro opcional.
La simulación y la geometría se mantendrán desacopladas para que estos
cambios no afecten a las reglas.
------------------------------------------------------------------------

---

## 5. Controles
  -----------------------------------------------------------------------
  Acción            Ratón             Teclado           Resultado
  ----------------- ----------------- ----------------- -----------------
  Levantar tótem    `pointerdown`     ---               inicia el
                    sobre el tótem                      arrastre
  Mover tótem       mantener pulsado  ---               el tótem sigue el
                    y mover                             objetivo mundial
                                                        del cursor
  Soltar tótem      `pointerup`       ---               fija la posición
                                                        alcanzada e
                                                        inicia la marcha
  Pausa             botón HUD         `Esc`             congela la
                                                        simulación local
  Zoom              rueda             `+` / `-`         cambia la escala
                                                        ortográfica
                                                        dentro de los
                                                        límites
                                                        configurados
  Velocidad de      botones HUD       `1/2/3`           normal, rápida,
  simulación                                            muy rápida
  Panel debug      ---               `Insert` /         alterna el panel
                                      `Numpad0`          de depuración y
                                                         sus controles
  -----------------------------------------------------------------------
El panel de depuración empieza oculto. Al mostrarlo, contiene también
los botones HUD de pausa y velocidad; `Esc` y las teclas `1/2/3` siguen
disponibles como atajos.
El input se convierte en acciones semánticas. La simulación no recibe
eventos DOM directamente.
El teclado no mueve el tótem. El teclado queda reservado para pausa,
velocidad de simulación y zoom. El clic sobre terreno vacío no produce
ninguna acción de movimiento.
Mientras el tótem está agarrado, su posición mundial se actualiza
directamente con la posición del cursor: no tiene una velocidad propia
ni persigue un objetivo. El navegador no permite recolocar físicamente
el cursor nativo. La cámara permanece fija mientras el arrastre no llega
al borde de la pantalla; en ese borde se desplaza para permitir llevar
el tótem a nuevas zonas. Una vez soltado, la cámara continúa hasta
volver a centrar el tótem. Una flecha amarilla flotante indica la
dirección del arrastre.
------------------------------------------------------------------------

---

## 6. Tótem y formación
``` ts
type TotemState = {
  position: Vec2;
  dragTarget: Vec2 | null;
  destination: Vec2 | null;
  moving: boolean;
  isCarried: boolean;
  commandRadius: number;
  dangerRadius: number;
  bondEnergy: number;
};
```
-   El tótem es el centro de navegación y formación.
-   `isCarried = true` indica que el jugador lo mantiene levantado;
    `false` indica que está colocado.
-   Mientras se arrastra, el tótem sigue el objetivo del cursor a
    velocidad limitada.
-   Al soltarlo, conserva la posición alcanzada y las unidades convergen
    hacia sus slots.
-   En marcha, las unidades siguen slots deterministas alrededor del
    tótem.
-   Al comenzar la partida, las unidades ya aparecen en sus slots y no
    se recolocan.
-   La formación actual usa un radio de 4 metros y dos unidades
    provisionales, evitando que las unidades traseras queden ocultas por
    el tótem.
-   El feedback de arrastre es el tótem elevado y una flecha amarilla
    flotante orientada hacia el cursor.
-   El radio de mando del tótem es también el radio de calma inicial:
    dentro de él, una unidad sin tarea puede permanecer `idle` y seguir
    buscando oportunidades locales.
-   La unidad solo vuelve a la formación si no tiene una acción válida y
    se encuentra fuera del radio de calma, o si el tótem está siendo
    movido.
-   Las unidades pueden separarse si encuentran una tarea válida dentro
    del radio de mando.
-   Una unidad a más de 42 metros entra en `RETURN_TO_TOTEM`.
-   La energía de vínculo baja cuando la tribu se divide y se recupera
    alrededor del tótem.
------------------------------------------------------------------------

---

## 7. IA autónoma
### Máquina de estados
``` text
FOLLOW_TOTEM
  ├─ FORMATION
  ├─ SEEK_TASK
  │    ├─ GATHER
  │    ├─ HUNT
  │    ├─ BUILD
  │    └─ INVESTIGATE
  ├─ COMBAT
  ├─ FLEE
  ├─ RETURN_WITH_LOAD
  ├─ RESTORE_HEALTH
  └─ DOWNED / DEAD
```
Cada transición debe guardar una causa legible: `resource-found`,
`threat-nearby`, `low-health`, `over-capacity`, `return-distance`, etc.
### Roles y especializaciones
  ----------------------------------------------------------------------------
  Rol            Función        Herramienta    Puede hacer    Estado
  -------------- -------------- -------------- -------------- ----------------
  `gatherer`     personaje base cesta          recoge comida  inicial y
                 y recolección                 y todos los    reclutable
                 de bayas                      drops
  `lumberjack`   tala árboles   hacha          tala y combate básico equipable
                                               con hacha
  `hunter`       caza fauna     arco           caza conejos y básico equipable
                                               combate con
                                               flechas
  `guardian`     combate cuerpo espada         combate con    transformación
                 a cuerpo                      espada         por 2
                                                              de oro
  `explorer`     exploración y  por definir    por definir    futuro
                 detección
  `artisan`      fabricación y  por definir    por definir    futuro
                 mejoras
  ----------------------------------------------------------------------------
Al comenzar una partida aparece un `gatherer` y un segundo minion
aleatorio entre `lumberjack` y `hunter`. El `gatherer` puede
transformarse en cualquier especialización mediante un objeto; los roles
especializados no pueden volver a `gatherer` ni cambiar directamente a
otro rol.
Todos los minions pueden recoger drops y saquear cadáveres. La
herramienta no limita la recogida física; sí determina la recolección y
el combate: `lumberjack`, `hunter` y `guardian` luchan con sus
diferencias de alcance y daño; los roles sin arma no combaten y huyen al
detectar un bárbaro.
La unidad elige tareas mediante una puntuación combinando afinidad de
rol, distancia, urgencia, valor del recurso y seguridad. La prioridad
global de las tareas autónomas queda fijada, de mayor a menor, como:
`enemigos` → `nodos de recursos` → `drops`. Un enemigo cercano
interrumpirá una tarea de recolección cuando se implemente el combate;
un nodo válido tendrá prioridad sobre recoger un drop. Levantar el tótem
no es una tarea autónoma: es una interrupción global que domina sobre
cualquier tarea y cancela su acción activa.
------------------------------------------------------------------------

---

## 8. Mundo, recursos y navegación
### Biomas iniciales
-   claro: área verde decorativa, la más pequeña, sin recursos ni
    función de recolección;
-   pradera: arbustos con bayas;
-   bosque: árboles;
-   pedregal: piedras;
-   ruinas: Brillo.
El `Claro` es una zona de relleno visual y no forma parte del total de
biomas de recursos. Puede haber tantos claros como necesite el mapa. El
área inicial donde aparece el tótem y la tribu es siempre un `Claro`;
nunca contiene un bioma de recursos.
El mapa final será circular. Su contenido se distribuirá mediante una
semilla: regiones verdes de distintos tamaños, cantidades y
combinaciones de recursos. Las zonas pequeñas pueden ser solo
decoración; las regiones principales de una partida serán
aproximadamente `20`, sin contar esas manchas menores. La generación debe producir un mapa circular con regiones principales y manchas decorativas pequeñas, sin solapamientos.
Distribución prevista:
-   claros pequeños: vegetación decorativa y relleno del mapa. Su
    distribución visual es de `60 %` césped, `25 %` flores y `15 %`
    setas. Las setas son de tallo blanco y copa roja con puntos blancos;
    las flores tienen tallo verde y cabezas amarillas, azules, grises o
    rosas. Cada instancia de bioma puede contener como máximo `2` setas;
-   praderas: arbustos con bayas;
-   bosques: nodos de recursos con silueta de árbol y vegetación
    decorativa de suelo. La vegetación se distribuye como `58 %` césped,
    `27 %` flores y `15 %` setas, con un máximo de `2` setas por
    instancia;
-   pedregales: nodos de recursos con silueta de roca cúbica;
-   ruinas: nodos de Brillo con silueta de rombo luminoso.
La escala visual de la vegetación decorativa se incrementa un `20 %`
adicional respecto al tamaño anterior, dentro de un multiplicador lógico
de `1.26` a `1.62`. Esto incluye césped, flores y setas. La selección y
colocación se mantienen deterministas mediante la semilla del mapa; esta
decoración es visual y no interactuable.
Ningún área de bioma puede superponerse con otra, incluidos los `Claros`
decorativos y el `Claro` inicial. Cuando el recurso de un bioma está
activo, cada área genera entre `1` y `3` nodos: al menos uno es del
recurso propio del bioma y los restantes tienen una alta probabilidad de
ser también propios, aunque pueden pertenecer a otro bioma. Esta regla
queda preparada para activar nuevos recursos progresivamente.
### Recursos
  -----------------------------------------------------------------------
  Recurso                 Obtención               Uso
  ----------------------- ----------------------- -----------------------
  Comida                  bayas, animales cazados curación, reclutamiento
                          y bárbaros (carne)      y objetos
  Madera                  ramitas de emergencia   hachas, arcos y hoguera
                          en claros, árboles y
                          drops futuros
  Piedra                  vetas y ruinas          mejorar hacha, martillo
                                                  y espada
  Oro                     drops de bárbaros       equipo existente y
                                                  objetos avanzados ya
                                                  definidos
  Brillo                  ruinas luminosas        reclutar clases
                                                  legendarias y futuras
                                                  habilidades
  -----------------------------------------------------------------------
Las praderas contienen nodos activos de `food` mediante
arbustos de bayas. Además, como salvaguarda de progresión, al menos la
mitad de los claros generados ---incluido el claro inicial--- contiene
como mínimo un nodo de ramitas.
El mundo contiene nodos de árboles (`wood`), vetas de piedra (`stone`) y ruinas luminosas (`spark`). La madera puede ser recolectada
por `lumberjack`; piedra y Brillo quedan visibles y serializables, pero
no se asignan a ningún rol jugable hasta que exista un minion adecuado.
Cada árbol entrega entre `2` y `3` maderas por acción de tala,
representadas como drops físicos separados de una unidad cada uno.
Piedra y Brillo solo pueden recolectarse cuando exista un rol con la afinidad correspondiente. El oro procede de bárbaros y la comida obtenida de bayas, animales y bárbaros comparte un único recurso e inventario.
Las ramitas son un pequeño asset marrón de ramas en el suelo. Cualquier
rol de minion puede recolectarlas; al completar una acción, el nodo se
consume y genera un drop de `2` unidades de madera. Así la tribu puede
obtener madera aunque solo conserve recolectores o cazadores.
La economía inicial usa únicamente cantidades enteras: cada arbusto
contiene exactamente `1` baya y cada baya añade exactamente `1` unidad
de comida al inventario. No se utilizan decimales ni cantidades
parciales; la acción tarda, pero la recompensa siempre es de una unidad.
El nodo nunca entrega recursos directamente al inventario. Cuando
termina la acción de recolección, consume su contenido y crea un
`ResourceDrop` visual junto al nodo. Al recolectar, el arbusto consume su
única baya y crea una drop de `1` baya. Cualquier unidad libre puede
desplazarse hasta esa drop y recogerla; solo entonces se suma `1` comida
al inventario. La economía no necesita física realista: las colisiones y
rutas se resolverán con navegación lógica y colisionadores simples.
### Navegación 3D
La navegación forma parte de la simulación lógica; la capa de presentación solo representa el resultado. Para el MVP se puede usar una cuadrícula
lógica sobre el terreno; posteriormente se podrá sustituir por navmesh y
crowd agents sin cambiar las reglas de alto nivel.
------------------------------------------------------------------------

---

## 9. Combate
El jugador decide posición, composición y movimiento del tótem. Las
unidades resuelven ataques automáticamente; mover el tótem inicia el
reagrupamiento sin cancelar un combate en curso.
### Bárbaros y fauna
-   El mapa contiene cinco bárbaros con posiciones, patrullas y botín
    reproducibles por semilla. Cada uno vuelve a su punto de aparición
    `60 s` después de morir.
-   La patrulla de cada bárbaro queda dentro de `3,5 m` de su aparición,
    espera entre `2–4 s` deterministas entre destinos y se desplaza a
    `1 m/s`; la persecución conserva `8 m/s`.
-   Los bárbaros detectan minions a `15 m`; todos los minions detectan
    bárbaros a `18 m`. Se muestran signos de exclamación sobre quienes
    detectan y se reproduce un sonido breve una sola vez por encuentro,
    aunque ambos bandos se detecten.
-   Los bárbaros persiguen a `8 m/s`, seleccionan al minion vivo más
    cercano dentro de `15 m` y, si pierden el rastro lejos de su
    aparición, regresan a ella a `8 m/s`. Al llegar, esperan el
    intervalo determinista de patrulla y retoman su recorrido a `1 m/s`.
-   Hay seis conejos pasivos en praderas, con `2 HP`. Se mueven dentro
    de su bioma; el `hunter` los caza en al menos dos golpes y genera
    `1–2` drops físicos de comida. Reaparecen en su punto a los `30 s`.
### Estadísticas y comportamiento de combate
  Combatiente      HP   Daño   Alcance   Cadencia
  -------------- ---- ------ --------- ----------
  `guardian`        4      2       1 m      1,5 s
  `lumberjack`      4    1,5       1 m        2 s
  `hunter`          4      1       5 m      1,3 s
  Bárbaro           5      1     1,2 m      2,5 s
-   Los tres roles armados combaten automáticamente al detectar
    bárbaros; la IA selecciona la amenaza válida menos ocupada,
    priorizando distancia e identificador estable. Los atacantes usan
    posiciones deterministas distribuidas alrededor del objetivo y
    separación suave entre actores. Los conejos solo son objetivo del
    `hunter`. El cazador se reposiciona a `6 m/s`, queda inmóvil durante
    el impulso de ataque de `0,22 s` y no se aleja más del radio de
    mando (`10 m`) del tótem.
-   El enfriamiento es un temporizador restante por minion, compartido
    entre objetivos y tareas de combate/caza: solo se recarga al golpear
    y nunca se reinicia al cambiar de objetivo.
-   `gatherer`, `explorer` y `artisan` no atacan. Si un bárbaro los
    detecta, huyen hacia el tótem.
-   Al mover/cargar el tótem, un combatiente a distancia válida termina
    como máximo el golpe pendiente y después se reagrupa; si el objetivo
    muere o queda fuera de alcance, vuelve de inmediato. Los bárbaros
    persiguen hasta que nadie queda a menos de `15 m`.
-   Los minions mantienen una separación mínima, pueden atravesar el
    tótem y no terminan dentro de un radio de `2 m` desde su centro. El
    recorrido no usa un collider rígido para el tótem; los golpes se
    refuerzan con un breve impulso procedural.
-   No existe armadura. Los futuros objetos defensivos aumentarán los HP
    máximos.
### Cadáveres, botín y derrota
-   Al morir, cada bárbaro deja un cadáver como nodo de saqueo reservado
    por un único minion libre. Una acción de `1,5 s` genera de una vez
    todo su botín ---`1–2` de oro, `0–2` de comida (carne) y `0–1` de
    madera--- y elimina el cadáver. Si la tarea se interrumpe antes de
    completarse, el cadáver permanece y queda disponible para otro
    minion.
-   Cada unidad del botín crea un drop físico independiente; cualquier
    minion puede recogerlo para añadirlo al inventario. Las cantidades
    se generan desde la semilla del mundo y ciclo de aparición del
    bárbaro.
-   La derrota ocurre únicamente cuando no queda ningún minion vivo. La condición de victoria no está definida.
### Herramientas en combate
-   El `hunter` combate a distancia y lanza flechas.
-   El `lumberjack` combate con el hacha.
-   El `guardian` combate con espada y está dedicado principalmente a la
    protección y al combate. La espada del HUD y el modelo de arrastre
    muestran hoja gris, empuñadura de madera y guarda oscura, alineadas
    en un eje vertical.
-   `gatherer`, `explorer` y `artisan` no atacan; huyen hacia el tótem cuando un bárbaro los detecta.
------------------------------------------------------------------------

---

## 10. Progresión
### HUD de reclutamiento y equipamiento
El HUD mostrará iconos de los objetos disponibles. La barra de compra básica tendrá tres opciones:
  ------------------------------------------------------------------------
  Icono/objeto                         Coste inicial Resultado
  --------------------- ---------------------------- ---------------------
  `gatherer`               progresión según total de recluta un minion
                          minions activos, en `food` base; máximo global
                                                     de 8
  hacha                   progresión según leñadores convierte un
                                  activos, en `wood` `gatherer` en
                                                     `lumberjack`; máximo
                                                     5 leñadores
  arco                    progresión según cazadores convierte un
                                  activos, en `wood` `gatherer` en
                                                     `hunter`; máximo 5
                                                     cazadores
  ------------------------------------------------------------------------
Los costes desde las unidades activas,
no desde el historial de compras. Para los recolectores se toma el total
de la tribu, con dos minions iniciales como base; para los especiales se
cuenta solo el tipo correspondiente:
  -----------------------------------------------------------------------
  Unidades activas relevantes                             Coste siguiente
  antes de comprar/convertir
  ------------------------------ ----------------------------------------
  Recolectores: total de la          `2` / `3` / `3` / `4` / `4` / `4` de
  tribu `2` / `3` / `4` / `5` /                                    comida
  `6` / `7`
  Especiales: mismo tipo `0` /      `2` / `3` / `3` / `4` / `4` de madera
  `1` / `2` / `3` / `4`
  -----------------------------------------------------------------------
La compra de recolectores se bloquea con `8` minions totales y la
conversión a un tipo especial se bloquea cuando ya hay `5` activos de
ese tipo. Transformar no incrementa el total global. Al morir un minion,
los costes se recalculan desde la población superviviente.
El nuevo minion se compra al soltar el icono sobre el mapa y el
placeholder 3D sigue al cursor durante el arrastre. Si el punto soltado
está a más de `15 m` del tótem, el minion aparece automáticamente en el
borde de ese radio; después regresa al tótem y entra en la formación.
Los roles especializados no se convierten entre sí: solo un `gatherer`
puede recibir el hacha o el arco, y la transformación es irreversible.
Si el objeto se suelta fuera de un `gatherer`, la compra se cancela y no
se consume madera.
Los tooltips básicos del HUD son `Recolector`, `Convertir en Leñador` y
`Convertir en Cazador`. Cuando solo queda un recolector, el tooltip del
hacha cambia a `Solo tienes un recolector` y el icono queda inhabilitado
aunque haya madera suficiente. La tienda se presenta como una columna
vertical; sus costes quedan fuera de cada tarjeta, centrados a la
derecha. Al arrastrar un objeto se muestra su placeholder 3D bajo el
cursor y la entrega sobre un minion admite una pequeña tolerancia
visual.
La hoguera es un objeto de soporte del HUD: cuesta `2` de madera y se
coloca en el mapa. La hoguera cuesta `2` de madera y se coloca en el mapa. Las unidades próximas consumen `1` de comida para recuperar `1` punto de vida.
### Progresión y tecnologías
La progresión es determinista. Comienza en nivel
1, con 0 XP y 0 puntos tecnológicos. Cada acción de recolección
completada concede 1 XP, cada conejo cazado 3 XP y cada bárbaro
derrotado 5 XP. El primer nivel requiere 12 XP; el requisito aumenta en
12 XP por cada nivel posterior. Cada nivel concede 1 punto tecnológico.
El panel de tecnologías puede abrirse durante la partida y no la pausa.
Cada tecnología cuesta 1 punto y solo se puede desbloquear una vez. Los
valores de XP y progresión se centralizan en la configuración de
balance.
El panel se muestra en la parte inferior izquierda. Al desbloquear una
tecnología, su objeto aparece en la barra lateral izquierda. El Mago es
una clase especial de minion: su tecnología desbloquea la tarjeta de
reclutamiento, que aparece después de Artesana y antes de Hoguera. El
Escudo conserva su acceso separado arriba a la derecha. Los objetos se
arrastran sobre un objetivo válido; una asignación inválida no consume
recursos.
  --------------------------------------------------------------------------------
  Tecnología        Desbloqueo y      Coste posterior    Límite y tooltip
                    efecto
  ----------------- ----------------- ------------------ -------------------------
  Supervivencia:    1 punto; habilita Madera, progresión Máximo 5;
  Artesana          el martillo para  por Artesanas      `Convertir en Artesana` /
                    convertir un      activas            `Máximo alcanzado`
                    `gatherer` en     `2, 3, 3, 4, 4`;
                    `artisan`, capaz  no modifica el
                    de recolectar     máximo global
                    piedra y Brillo
  Clase especial:   1 punto; habilita Brillo, progresión  Máximo global de 8
  Mago              la clase Mago y    `2, 3, 3, 4, 4`    unidades y máximo de
                    su reclutamiento                     5 Magos; habilidad
                    con Brillo                            por definir
  Defensa: Escudo   1 punto; habilita Oro, progresión    Un escudo por Guardián;
                    equipar un        por Guardianes     `Escudo +1 HP` /
                    `guardian` sin    equipados          `Máximo alcanzado` cuando
                    escudo,           `2, 3, 3, 4, 4`    todos los Guardianes
                    aumentando su                        tienen uno
                    vida máxima en 1
  --------------------------------------------------------------------------------
El Guardián sigue disponible mediante su transformación existente por 2
de oro, sin requisito de nivel. Al equiparlo, el Guardián gana `1` HP
máximo y `1` HP actual, manteniendo su vida previa y terminando con un
punto adicional. Si no hay Guardianes disponibles, el botón de equipo
permanece inhabilitado; el texto de coste se conserva visible. El
martillo y el escudo usan modelos procedurales, sin assets externos.
------------------------------------------------------------------------

---



---

## 11. Mejoras de herramientas

La piedra se utiliza para mejorar hacha, martillo y espada. Cada herramienta tiene un nivel global compartido por todas las unidades de su clase, de `0` a `10`. La mejora de nivel `n` cuesta `n` unidades de piedra: la primera cuesta 1, la segunda 2 y así sucesivamente.

- **Hacha:** añade `+1` madera por acción de tala por nivel.
- **Martillo:** reduce un `5 %` el tiempo de extracción de piedra por nivel, hasta un máximo acumulado del `50 %` en nivel 10. El tiempo nunca puede ser cero ni negativo.
- **Espada:** añade `+0,5` de daño por nivel.

Las mejoras se compran desde un menú independiente, coherente con el panel de experiencia/tecnologías. Los botones «Tecnologías» y «Mejoras» se sitúan juntos abajo a la izquierda; solo puede estar abierto uno de los dos paneles. Las tarjetas se ordenan de izquierda a derecha y se distribuyen en filas cuando no caben en el ancho disponible. En «Mejoras», hacha, martillo y espada aparecen en ese orden, con el icono a la izquierda y el nivel a la derecha. Cada tarjeta reserva espacio para mostrar el nivel o `Max` junto al icono. El fondo de cada tarjeta lateral refleja el color del nivel; en la tarjeta de mejora el icono conserva su color base y el nivel usa la banda correspondiente. El efecto y el coste de la siguiente mejora se consultan mediante tooltip al pasar el cursor o enfocar la tarjeta; en nivel 10 se muestra `Max` y no hay coste siguiente. Las compras son atómicas: si falta piedra, ni el inventario ni el nivel cambian, y el nivel máximo es 10.

La fila superior centrada presenta, en este orden, Comida, Madera,
Piedra, Brillo y Oro, cada una con su icono de pixel art y cantidad. Los
contadores reservan espacio para al menos tres cifras, se amplían con
valores mayores y pueden pasar a varias líneas si la pantalla es estrecha.
La barra lateral izquierda lista Recolector, Leñador, Cazador, Guardián,
Artesana, Mago y Hoguera, en ese orden. Artesana y Mago solo aparecen
tras desbloquear sus tecnologías; el Escudo sigue en su acceso separado.

El color de nivel se aplica al fondo de la tarjeta lateral y al rótulo de
nivel de la tarjeta de mejora, sin teñir el modelo del objeto. Nivel 0
conserva el color base; las bandas son `+1/+2` gris `#A7A7A7`, `+3/+4`
verde `#3F8F54`, `+5/+6` cian `#168397`, `+7/+8/+9` violeta `#80508F`
y nivel 10 (`Max`) naranja `#B77D35`. El color complementa el número y
no lo sustituye.

Las tecnologías se presentan en una fila horizontal, con icono y coste en
puntos en cada tarjeta. El nombre y la descripción aparecen en el mismo
tooltip contextual que se usa para las mejoras y los objetos del HUD.

## 12. Clases legendarias

Hay tres clases legendarias: **Mago** (libro), **Pícaro** (daga) y **Paladín** (espada luminosa). La tecnología de Mago cuesta 1 punto; tras desbloquearla, se recluta con Brillo mediante su tarjeta del HUD. La curva inicial propuesta para el reclutamiento del Mago es `2, 3, 3, 4, 4`. El Pícaro tiene menos vida que las demás clases legendarias y puede asestar golpes críticos; sus valores numéricos quedan por definir. Las curvas de Pícaro y Paladín siguen sin fijarse y no deben inventarse como decisiones de diseño.

El límite global de la tribu exterior es de 8 unidades y solo puede haber una clase legendaria activa fuera de una cueva. La regla de selección o sustitución debe mantener un único arquetipo legendario exterior. Los objetos solo se aplican a objetivos válidos y no consumen Brillo si el reclutamiento falla. Las especializaciones del Mago —Nigromante y Fuego— quedan fuera del alcance actual y se reservan para una ampliación futura.

## 13. Fronteras, campamentos y jefes

El mundo se divide en regiones separadas por barreras de energía oscura. Cada barrera tiene una fuente de llave designada: un jefe asociado a un campamento o una cueva. Derrotar al jefe entrega una llave única; usarla despeja la barrera correspondiente y permite acceder a la siguiente región.

Los campamentos contienen grupos mixtos de enemigos y pueden incluir un nuevo arquetipo, el **arquero bárbaro**. La generación debe ser determinista respecto a la semilla y el desbloqueo de regiones debe persistir entre sesiones. Toda barrera debe tener una fuente de llave accesible, y cada llave debe corresponder a una barrera identificable. La ubicación y composición exacta de los campamentos, las estadísticas de jefes y el balance de las llaves siguen pendientes de diseño detallado.

## 14. Cuevas y expediciones legendarias

Las entradas de cueva aparecen en el mapa exterior y conducen a un mapa interior compacto. Para entrar, el jugador mueve el tótem hasta la entrada. La tribu exterior permanece fuera: solo entra la unidad legendaria activa (Mago, Pícaro o Paladín). Los roles ordinarios no pueden cruzar el umbral.

La cueva mantiene una expedición temporal separada del grupo exterior. Al salir, se conserva la clase legendaria con la que se entró; las unidades legendarias adicionales reclutadas dentro desaparecen al abandonar la cueva.

Dentro de la cueva se pueden reclutar unidades legendarias adicionales pagando Brillo, con costes superiores a los del reclutamiento exterior. Puede haber como máximo dos unidades de cada clase dentro —dos Magos, dos Pícaros y dos Paladines— contando la unidad inicial si pertenece a esa clase. El máximo simultáneo es seis unidades legendarias. El reclutamiento se bloquea al alcanzar el límite de clase o si no hay Brillo suficiente. Las unidades reclutadas dentro son temporales y no se incorporan a la tribu exterior al salir.

Cada cueva conserva su estado: enemigos derrotados, jefe derrotado, cofres abiertos, botín recogido y llave obtenida. Los enemigos y cofres completados no reaparecen al salir y volver a entrar ni después de guardar y cargar. Los usos de piedra y Brillo dentro de las cuevas, la distribución interior, los encuentros, las recompensas, las estadísticas y las condiciones exactas de salida quedan por definir; no se debe asumir una función adicional hasta diseñarla.

## 15. Guardado como comportamiento del juego

La partida debe permitir guardar y cargar el estado local. El estado persistente debe incluir inventario, unidades, progresión, niveles de herramientas, clases legendarias, regiones desbloqueadas, llaves y estado de cuevas/cofres. La carga de partidas antiguas debe conservar el progreso existente y asignar valores seguros a campos añadidos posteriormente. Las unidades temporales de una expedición no deben guardarse como parte de la tribu exterior. No se contempla sincronización en la nube ni multijugador online.

Cada slot ocupado ofrece una opción para eliminar la partida. Antes de borrarla, el juego solicita confirmación explícita; cancelar conserva el guardado y confirmar elimina solo el slot seleccionado. Los slots vacíos no muestran la opción de borrado.

---

## 16. Arte y postprocesado
### Fase 1 --- prototipo
-   geometría básica;
-   colores planos;
-   formas reconocibles;
-   iluminación simple;
-   sin depender de texturas finales.
### Fase 2 --- dirección visual
-   modelos low-poly propios;
-   materiales estilizados;
-   animaciones de caminar, trabajar, combatir e idle;
-   elementos de entorno modular.
### Fase 3 --- opción retro
-   texturas pixeladas;
-   render a resolución reducida;
-   nearest-neighbor filtering;
-   outline y dithering;
-   postprocesado activable desde ajustes.
El filtro retro no será una dependencia del gameplay. Debe poder
activarse o desactivarse sin cambiar el estado de la partida.
------------------------------------------------------------------------

---

## Registro de decisiones pendientes de diseño

- Definir una condición de victoria. La Gran Hoguera, las piedras de memoria y cualquier rito final **no** son mecánicas aprobadas.
- Definir funciones y objetos de los roles avanzados Explorador y Artesana.
- Definir las curvas de coste de reclutamiento exterior del Pícaro y el Paladín.
- Definir distribución, encuentros, recompensas, estadísticas y salida de las cuevas.
- Definir usos de piedra y Brillo dentro de las cuevas.
- Definir composición exacta de campamentos, estadísticas de jefes y balance de llaves.
- Definir detalles de las especializaciones futuras del Mago (Nigromante y Fuego), fuera del alcance actual.

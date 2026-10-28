# GDD --- Tribes Revival (Tribu del Tótem 3D)

## Juego web de supervivencia tribal e isométrica

**Versión:** 0.5.0  
**Plataforma:** navegador de escritorio inicialmente  
**Stack objetivo:** Babylon.js + TypeScript + Vite  
**Modo:** simulación local para un jugador  
**Arte:** 3D estilizado; pixel art y postprocesado como opción posterior  
**Relación con Wanderers.io:** inspiración mecánica, no recreación ni copia de contenido.

> Las etiquetas `[VERIFICADO]`, `[INFERIDO]` y `[PROPUESTO]` distinguen
> hechos históricos, deducciones razonables y decisiones nuevas de este
> proyecto.

------------------------------------------------------------------------

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

### Objetivo del primer prototipo jugable

Una partida local de 15--25 minutos con:

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

## 2. Investigación histórica de Wanderers.io

### 2.1 Mecánicas con evidencia fuerte

`[VERIFICADO / CONFIANZA ALTA]`

-   El jugador dirigía una tribu pequeña en un sandbox hostil.
-   La tribu seguía un tótem que el jugador movía con el ratón.
-   Las unidades actuaban automáticamente y sus herramientas
    condicionaban qué recursos podían recoger.
-   El bucle incluía reunir recursos, reclutar miembros, equiparlos y
    desbloquear tecnologías.
-   Existía combate contra bárbaros y otras tribus o jugadores.
-   Se documentan recursos como comida, madera y monedas/oro.
-   Perder todos los miembros de la tribu implicaba perder la partida.

Fuentes: [Wanderers.io Wiki --- The
Tribe](https://wanderersio.fandom.com/wiki/The_Tribe),
[Miniplay](https://www.miniplay.com/game/wanderers-io), [Not
Doppler](https://www.notdoppler.com/wanderersio.php).

### 2.2 Datos plausibles, pero no plenamente oficiales

`[INFERIDO / CONFIANZA MEDIA]`

-   El número máximo de miembros era reducido y podía depender de la
    versión o del modo.
-   Había roles como cazador, leñador, minero, arquero, constructor y
    misionero.
-   Versiones posteriores incluían edificios defensivos y objetos de
    asedio.

La información procede de documentación comunitaria y proyectos de
preservación. El código original no está publicado de forma oficial; por
tanto, estos datos no se tratan como especificación exacta. [Proyecto de
preservación](https://github.com/Avoxel284/wanderersio), [wiki
comunitaria](https://wanderersio.fandom.com/wiki/Wanderers.io_Wiki).

### 2.3 Límites de inspiración

`[DECISIÓN DEL PROYECTO]`

No se reutilizarán el nombre Wanderers.io, sus sprites, sonidos, mapas,
facciones, textos, valores exactos ni assets. El juego tendrá mundo,
nomenclatura, economía, personajes y estética propios.

### 2.4 Observaciones para la base del prototipo

`[OBSERVADO EN EL VÍDEO Y CONSOLIDADO COMO REFERENCIA DE DISEÑO]`

Estas reglas describen la base mecánica que queremos reproducir como
prototipo jugable. No significa que todo esté implementado todavía: las
reglas que aún no aparecen en la simulación se incorporarán por hitos y
mantendrán valores configurables.

#### Inicio de partida

-   La partida comienza con dos minions: un `gatherer` y un segundo
    minion elegido aleatoriamente entre `lumberjack` y `hunter`.
-   El `gatherer` es el personaje base. Puede convertirse en cualquier
    otro rol mediante el objeto y el coste correspondientes.
-   Un minion ya especializado no puede volver a `gatherer` ni cambiar
    directamente a otro rol.
-   El último `gatherer` está protegido: si la tribu solo conserva un
    recolector, el hacha queda inhabilitada y no puede convertirlo en
    `lumberjack`. El arco permanece disponible como opción de cazador
    según la regla actual del prototipo; el reclutamiento de
    recolectores y la hoguera tampoco se bloquean.
-   Todos los roles pueden recoger drops del suelo; la herramienta
    determina qué acciones autónomas pueden realizar.

#### Reclutamiento y equipamiento

-   La tribu empieza con dos minions y puede tener hasta `8` minions
    activos en total.
-   Los recolectores no tienen un límite individual menor: pueden ocupar
    los ocho espacios si los demás minions mueren. Reclutarlos está
    bloqueado al alcanzar el límite global.
-   El coste del siguiente recolector depende del total de minions
    activos, independientemente de sus roles. Especializar un recolector
    no cambia el total ni el coste; la muerte de cualquier minion vuelve
    a calcularlo.
-   Cada tipo especial tiene su propio máximo de `5` minions activos. Su
    coste depende únicamente del total activo de ese mismo tipo; las
    muertes y conversiones se reflejan en el siguiente coste.
-   En la implementación actual, la progresión es `2, 3, 3, 4, 4, 4`
    para recolectores según la población total (partiendo de dos
    minions), y `2, 3, 3, 4, 4` para cada tipo especial. El coste se
    paga en comida para recolectores y madera para conversiones
    especiales.
-   La comida procede de bayas y de animales cazados.
-   El HUD tendrá accesos para el `gatherer`, el hacha y el arco como
    objetos básicos.
-   El hacha y el arco usan la progresión escalable de costes de su
    propio tipo: el coste se paga en madera y depende del número actual
    de leñadores o cazadores, respectivamente. Permiten
    convertir/equipar un minion como `lumberjack` o `hunter`,
    respectivamente.
-   Los objetos y roles avanzados se desbloquean mediante niveles y
    elecciones de progreso.

#### Progresión y desbloqueos

-   La experiencia se obtiene al ganar combates contra bárbaros,
    recolectar determinados recursos y cazar animales.
-   Al subir de nivel puede haber varias opciones de desbloqueo; el
    jugador elige una.
-   El `guardian` se incorpora en Hito 4 mediante transformación de un
    `gatherer` con una espada que cuesta `2` de oro, sin requisito de
    nivel.
-   El explorador y la artesana quedan definidos como roles avanzados;
    sus funciones y objetos se concretarán en una iteración posterior.

#### Amenazas, fauna y curación

-   Los bárbaros son NPC que aparecen y se desplazan por zonas reducidas
    del mapa.
-   Los bárbaros detectan minions a `15 m`; los minions detectan
    amenazas a `18 m`.
-   Un bárbaro derrotado deja un cadáver saqueable por cualquier rol.
    Cada aparición entrega de forma determinista `1–2` de oro, `0–2` de
    comida (carne) y `0–1` de madera.
-   Se generan seis conejos pasivos en praderas; el `hunter` puede
    cazarlos y obtener `1–2` de comida. Cada conejo reaparece a los
    `30 s`.
-   El HUD incluye una hoguera con coste de `2` de madera. Se coloca en
    el mapa.
-   Los minions próximos a una hoguera gastan `1` de comida para
    recuperar `1` punto de vida.
-   La vida inicial de un minion es `4` y la de un bárbaro es `5`.
-   Vida máxima, daño, alcance, cadencia y costes viven en configuración
    para poder balancearse; no hay estadística de armadura. Los futuros
    objetos defensivos aumentarán los HP.

#### Mundo y biomas

-   El mapa jugable es circular, no cuadrado.
-   Dentro del círculo se generan zonas verdes de tamaño y número
    variables mediante una semilla.
-   Las zonas pequeñas pueden contener solo vegetación decorativa y no
    cuentan para el total de regiones principales.
-   Las regiones grandes pueden contener árboles y arbustos; otras
    combinan piedra y árboles.
-   El tamaño, la cantidad y la distribución de biomas y recursos son
    aleatorios deterministas.
-   La referencia visual de una partida es de unas `20` regiones
    principales, sin contar las zonas decorativas pequeñas.

------------------------------------------------------------------------

## 3. Pilares de diseño

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
-   especializaciones avanzadas del Mago (Nigromante y Fuego), hasta un
    hito posterior.

------------------------------------------------------------------------

## 4. Bucle principal

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
-   En Hito 4 no hay victoria ni orden de retirada. Mover el tótem sirve
    para reagrupar; no cancela automáticamente un combate activo.

**Aceptación de persistencia:** una partida debe poder empezar, guardarse y cargarse sin recargar la página. La victoria no forma parte de los criterios actuales porque su condición sigue sin diseñarse.

------------------------------------------------------------------------

## 5. Cámara y presentación 3D

### Cámara

`[PROPUESTO]`

-   cámara Babylon.js en modo ortográfico (`FreeCamera` con proyección
    ortográfica en el prototipo);
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

-   1 unidad Babylon = 1 metro lógico;
-   límites provisionales del prototipo: 160 × 160 metros;
-   mundo objetivo: mapa circular con radio y contenido configurables;
-   chunks de 16 × 16 metros;
-   radio de mando del tótem: 10 metros;
-   radio de peligro: 18 metros;
-   radio de formación inicial: 4 metros, para mantener los minions
    visibles alrededor del tótem;

`[DECISIÓN CONFIRMADA — PROTOTIPO]` El slice actual usa límites de
`160 × 160 metros` para probar cámara, recursos y simulación. La versión
jugable objetivo sustituirá ese contenedor por un mapa circular sin
cambiar las reglas de alto nivel; una expansión posterior podrá usar
chunks alrededor de ese círculo.

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

## 6. Controles del Hito 1

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
  -----------------------------------------------------------------------

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

**Aceptación:** arrastrar el tótem produce un destino en coordenadas del
mundo; el clic sobre terreno vacío nunca crea una unidad ni altera
recursos.

------------------------------------------------------------------------

## 7. Tótem y formación

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

**Aceptación:** con ocho unidades y obstáculos, ninguna puede quedar
bloqueada más de tres segundos sin cambiar a una ruta alternativa o
volver al último punto navegable.

------------------------------------------------------------------------

## 8. IA autónoma

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
                 a cuerpo                      espada         en Hito 4 por 2
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

**Aceptación:** una recolectora no intenta minar piedra; los roles sin
arma huyen de bárbaros detectados; toda unidad tiene un fallback hacia
el tótem.

------------------------------------------------------------------------

## 9. Mundo, recursos y navegación

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
aproximadamente `20`, sin contar esas manchas menores. El prototipo
actual conserva un límite cuadrado provisional para no mezclar todavía
la generación circular con la implementación de supervivencia.

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

En el Hito 2, las praderas instancian nodos activos de `food` mediante
arbustos de bayas. Además, como salvaguarda de progresión, al menos la
mitad de los claros generados ---incluido el claro inicial--- contiene
como mínimo un nodo de ramitas.

El Hito 3 activa los nodos de árboles (`wood`), vetas de piedra
(`stone`) y ruinas luminosas (`spark`). La madera puede ser recolectada
por `lumberjack`; piedra y Brillo quedan visibles y serializables, pero
no se asignan a ningún rol jugable hasta que exista un minion adecuado.
Cada árbol entrega entre `2` y `3` maderas por acción de tala,
representadas como drops físicos separados de una unidad cada uno.
Piedra y Brillo quedan visibles y preparados, sin minion asignable. Hito
4 activa oro y botín de comida de animales y bárbaros; toda la comida
comparte el mismo recurso e inventario.

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
`ResourceDrop` visual junto al nodo. En Hito 2A, el arbusto consume su
única baya y crea una drop de `1` baya. Cualquier unidad libre puede
desplazarse hasta esa drop y recogerla; solo entonces se suma `1` comida
al inventario. La economía no necesita física realista: las colisiones y
rutas se resolverán con navegación lógica y colisionadores simples.

### Navegación 3D

La navegación se diseñará como sistema de simulación. Babylon.js solo
representará el resultado. Para el MVP se puede usar una cuadrícula
lógica sobre el terreno; posteriormente se podrá sustituir por navmesh y
crowd agents sin cambiar las reglas de alto nivel.

------------------------------------------------------------------------

## 10. Combate

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
-   No se activa una condición de victoria en este hito. La derrota
    ocurre únicamente cuando no queda ningún minion vivo; la victoria se
    añadirá después de completar el bucle principal de supervivencia.

### Herramientas en combate

-   El `hunter` combate a distancia y lanza flechas.
-   El `lumberjack` combate con el hacha.
-   El `guardian` combate con espada y está dedicado principalmente a la
    protección y al combate. La espada del HUD y el modelo de arrastre
    muestran hoja gris, empuñadura de madera y guarda oscura, alineadas
    en un eje vertical.
-   `gatherer`, `explorer` y `artisan` no atacan en este hito; huyen
    hacia el tótem cuando un bárbaro los detecta.

**Aceptación:** las posiciones, combates y botín son deterministas; se
respetan HP, daño, alcance y cadencia; las unidades no reciben daño
fuera del alcance; las reapariciones ocurren tras sus temporizadores; el
cadáver y los drops se agotan sin recursos negativos; la derrota solo
sucede al perder toda la tribu; ningún minion solapa el tótem; las
barras enemigas se retiran al morir y se recrean al reaparecer.

------------------------------------------------------------------------

## 11. Progresión

### HUD de reclutamiento y equipamiento

El HUD mostrará iconos de los objetos disponibles. La primera barra de
compra tendrá tres opciones básicas:

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

La implementación actual calcula los costes desde las unidades activas,
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
coloca en el mapa. En la primera implementación solo se prepara el
botón, el coste y la colocación visual. La vida, el área de curación y
el consumo de `1` comida para recuperar `1` de vida quedan para una
iteración posterior.

### Progresión y tecnologías --- Hito 5B

La progresión está en `GameState` y es determinista. Comienza en nivel
1, con 0 XP y 0 puntos tecnológicos. Cada acción de recolección
completada concede 1 XP, cada conejo cazado 3 XP y cada bárbaro
derrotado 5 XP. El primer nivel requiere 12 XP; el requisito aumenta en
12 XP por cada nivel posterior. Cada nivel concede 1 punto tecnológico.
El panel de tecnologías puede abrirse durante la partida y no la pausa.
Cada tecnología cuesta 1 punto y solo se puede desbloquear una vez. Los
valores de XP y progresión se centralizan en la configuración de
balance.

El panel se muestra en la parte inferior. Al desbloquear una tecnología,
su objeto aparece en la barra lateral: roles y especialidades a la
izquierda, equipo y mejoras a la derecha. Los objetos se arrastran sobre
un objetivo válido; una asignación inválida no consume recursos.

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

  Defensa: Escudo   1 punto; habilita Oro, progresión    Un escudo por Guardián;
                    equipar un        por Guardianes     `Escudo +1 HP` /
                    `guardian` sin    equipados          `Máximo alcanzado` cuando
                    escudo,           `2, 3, 3, 4, 4`    todos los Guardianes
                    aumentando su                        tienen uno
                    vida máxima en 1                     
                    HP                                   
  --------------------------------------------------------------------------------

El Guardián sigue disponible mediante su transformación existente por 2
de oro, sin requisito de nivel. Al equiparlo, el Guardián gana `1` HP
máximo y `1` HP actual, manteniendo su vida previa y terminando con un
punto adicional. Si no hay Guardianes disponibles, el botón de equipo
permanece inhabilitado; el texto de coste se conserva visible. El
martillo y el escudo usan modelos procedurales, sin assets externos.

------------------------------------------------------------------------

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
  version: 16;
  seed: string;
  tick: number;
  phase: 'playing' | 'paused' | 'victory' | 'defeat';
  totem: TotemState;
  units: UnitState[];
  resources: ResourceNode[];
  threats: ThreatState[];
  inventory: Inventory;
  research: ResearchState;
};
```

------------------------------------------------------------------------

## 13. Arte y postprocesado

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

## 14. QA y criterios de aceptación

### Tests automáticos

#### Hito 1 --- verificado

-   levantar el tótem solo mediante la acción semántica correspondiente;
-   hacer clic sobre terreno vacío no mueve el tótem;
-   arrastrar actualiza el objetivo mundial y respeta los límites del
    terreno;
-   soltar fija la posición alcanzada e inicia la marcha;
-   el tótem aparece bajo el cursor y se mueve directamente con él
    mientras se mantiene pulsado;
-   pausar congela el tick de simulación;
-   las mismas acciones producen el mismo estado final;
-   la formación converge a posiciones deterministas;
-   las unidades aparecen en sus slots iniciales sin intercambio al
    arrancar.

#### Pendiente para hitos posteriores

-   misma semilla = mismo mundo;
-   guardar/cargar conserva el estado;
-   costes nunca producen recursos negativos;
-   todas las transiciones de IA tienen fallback;
-   daño y cooldown son reproducibles.

### Pruebas manuales

-   cámara en 1280×720 y 1920×1080;
-   zoom mínimo y máximo;
-   arrastre del tótem sobre terreno libre y bloqueado;
-   unidades separadas y retorno;
-   combate con ocho unidades;
-   pérdida de foco del navegador;
-   guardado durante recolección y combate;
-   HUD manejable por teclado.

### Definición de terminado del vertical slice

1.  Una persona nueva entiende el objetivo en menos de 90 segundos.
2.  Puede mover el tótem, recoger dos recursos y reclutar una unidad.
3.  Puede sobrevivir o perder frente a una amenaza.
4.  Puede ganar en menos de 25 minutos.
5.  El replay de una semilla produce el mismo resultado.
6.  Se mantienen 60 FPS con ocho unidades, cuarenta nodos de recursos y
    doce amenazas en un equipo de referencia.

------------------------------------------------------------------------

## 15. Roadmap

### Hito 0 --- Migración 3D

-   retirar Phaser;
-   instalar Babylon.js;
-   crear engine y escena;
-   cámara ortográfica isométrica;
-   terreno, tótem y dos unidades provisionales;
-   HUD DOM conservado.

**Salida:** escena 3D navegable y compilación limpia.

### Hito 1 --- Movimiento y formación

**Estado: COMPLETADO**

-   picking exclusivo del mesh del tótem;
-   levantar, arrastrar y soltar mediante ratón;
-   proyección del cursor a coordenadas mundiales y continuidad fuera
    del terreno visible;
-   movimiento lógico directo ligado al cursor;
-   unidades siguiendo slots deterministas alrededor del tótem;
-   cinco bárbaros y seis conejos con generación y reaparición
    deterministas;
-   combate automático y caza según rol, con estadísticas configuradas;
-   Guardian por transformación de recolector a cambio de `2` de oro;
-   cadáveres saqueables, drops de oro/comida/madera y drops de comida
    de fauna;
-   alerta visual y sonora al detectar amenazas; comunicación entre
    minions sin feedback;
-   persecución que persiste al mover el tótem y derrota al perder toda
    la tribu; sin victoria.

### Hito 5 --- Supervivencia y progresión

#### Hito 5A --- Lluvia y regeneración de recursos

**Estado: COMPLETADO Y VALIDADO POR PLAYTEST MANUAL**

-   El clima forma parte del estado determinista y se detiene con la
    pausa.
-   Cada 30 segundos se inicia una nube cuya ruta se decide a partir de
    la semilla. Los primeros destinos de cada ciclo recorren, en orden
    barajado determinista, un claro, una pradera y un bosque; las
    instancias concretas también se seleccionan con la semilla.
-   La nube aparece en el lado inferior de la pantalla respecto a su
    destino y avanza lentamente hacia la parte superior. Al llegar al
    bioma llueve durante 6 segundos y después sigue ascendiendo hasta
    salir por el borde superior antes de desaparecer, sin necesitar otro
    destino de bioma.
-   La lluvia restaura hasta `maxAmount` los nodos agotados de `food` y
    `wood` del bioma visitado, incluidas las ramitas de los claros. No
    repone nodos parcialmente agotados, piedra, Brillo ni animales.

#### Hito 5B --- Experiencia, tecnologías y equipo

**Estado: COMPLETADO Y VALIDADO POR PLAYTEST MANUAL**

-   `GameState` versión 16 incluye nivel, XP, umbral del siguiente
    nivel, puntos tecnológicos y tecnologías desbloqueadas.
-   Recolección completada: +1 XP; conejo cazado: +3 XP; bárbaro
    derrotado: +5 XP. El umbral inicial es 12 XP y aumenta en 12 por
    nivel; cada nivel concede 1 punto.
-   Artesana permite transformar recolectores por madera escalable y
    recolectar piedra/Brillo; máximo 5 Artesanas. El Escudo permite
    equipar Guardianes por oro escalable y aumenta en 1 su vida máxima y
    actual.
-   El árbol de tecnologías se abre al subir de nivel y puede cerrarse
    manualmente; comprar una tecnología consume un punto.

#### Hito 5C --- Menú, tutorial y guardado

**Estado: COMPLETADO Y VALIDADO MANUALMENTE POR EL USUARIO**

-   La aplicación abre el menú principal de **Tribes Revival**. «Jugar»
    inicia una partida nueva sin eliminar guardados; «Tutorial» abre una
    guía estática ilustrada y «Cargar» muestra los slots.
-   Escape abre Pausa con Volver, Guardar, Cargar y Salir. En submenús
    Escape regresa al menú anterior; Salir solicita confirmación cuando
    existe progreso no guardado.
-   Hay tres slots locales del navegador. Cada uno muestra fecha/hora,
    nivel y cantidad de minions; guardar en un slot ocupado requiere
    confirmar la sobrescritura.
-   La versión 0.5.0 debe mantener la carga de guardados de `GameState`
    versión 16. Los campos nuevos se inicializan de forma segura al
    migrar partidas antiguas; no se debe perder el estado existente ni
    inventar progreso desbloqueado.

### Hito 6 --- Recursos y equipamiento

**Estado: EN DISEÑO / IMPLEMENTACIÓN PARCIAL**

#### 6.1 Mejoras de herramientas con piedra

-   La piedra mejora tres objetos: hacha, martillo y espada.
-   Cada herramienta tiene nivel global compartido por todas las
    unidades de su clase, de `0` a `10`.
-   La mejora de nivel `n` cuesta `n` unidades de piedra. Por tanto, la
    primera mejora cuesta 1 piedra, la segunda 2, etc.
-   El hacha añade `+1` madera por acción de tala por nivel.
-   El martillo reduce un `5 %` el tiempo de extracción de piedra por
    nivel, con reducción acumulada máxima del `50 %` al nivel 10. El
    cálculo debe evitar tiempos cero o negativos.
-   La espada añade `+0,5` de daño por nivel.
-   El acceso a las mejoras se presenta en un menú separado, siguiendo
    el patrón visual del menú de experiencia/tecnologías. Cada objeto
    disponible puede seleccionarse y muestra nivel actual, coste de la
    siguiente mejora y efecto numérico.
-   Cada nivel cambia el color del icono/objeto. La escala visual tiene
    cinco bandas de dos niveles: `+1/+2`, `+3/+4`, `+5/+6`, `+7/+8`,
    `+9/+10`. Mostrar además el número de nivel `+N`. El color comunica
    progreso, pero el número sigue siendo la indicación inequívoca.
-   Las mejoras son compras atómicas: si no hay piedra suficiente, no
    cambia nivel ni inventario. No se permite superar nivel 10.

#### 6.2 Reclutamiento de clases legendarias

-   Hay tres clases legendarias reclutables mediante objetos: Mago
    (libro), Pícaro (daga) y Paladín (espada luminosa).
-   El coste se paga en Brillo y cada clase tiene una curva de coste
    independiente configurable. Costes iniciales propuestos para el
    Mago: `2, 3, 3, 4, 4`; la curva para Pícaro y Paladín debe ser
    configurable y no inventarse hasta decidir balance.
-   El límite global de la tribu exterior sigue siendo 8 unidades. Solo
    puede haber una clase legendaria activa fuera de una cueva; la regla
    de reemplazo/selección debe mantener un único arquetipo legendario
    exterior.
-   Los objetos legendarios solo pueden aplicarse a un objetivo válido y
    no consumen Brillo si el reclutamiento falla.

### Hito 7 --- Fronteras, campamentos y jefes

**Estado: PENDIENTE**

-   El mundo se divide en regiones separadas por una barrera de energía
    oscura.
-   Cada barrera tiene una fuente de llave designada: un jefe asociado a
    un campamento o una cueva.
-   Derrotar al jefe entrega una llave única. Usar esa llave despeja la
    barrera correspondiente y habilita el acceso a la región siguiente.
-   Los campamentos contienen grupos mixtos de enemigos y pueden incluir
    un nuevo arquetipo de bárbaro: arquero bárbaro.
-   La generación debe ser determinista respecto a la semilla y el
    estado de regiones desbloqueadas debe persistir al guardar/cargar.
-   No debe haber una barrera sin fuente de llave accesible ni una llave
    que no corresponda a una barrera identificable.
-   La colocación, composición exacta de campamentos, estadísticas del
    jefe y balance de las llaves quedan como parámetros de diseño
    pendientes.

### Hito 8 --- Cuevas y expediciones legendarias

**Estado: PENDIENTE**

#### Entrada y composición de la expedición

-   Las entradas de cueva aparecen en el mapa exterior y llevan a un
    mapa interior compacto.
-   Para entrar, el jugador mueve el tótem a la entrada. La tribu
    exterior permanece fuera: entra únicamente la unidad legendaria
    activa en ese momento (Mago, Pícaro o Paladín).
-   Solo Mago, Pícaro y Paladín pueden entrar. Los roles ordinarios no
    pueden cruzar el umbral.
-   La cueva mantiene una expedición temporal separada del grupo
    exterior. Al salir, se conserva la clase legendaria con la que se
    entró; las unidades legendarias adicionales reclutadas dentro
    desaparecen al abandonar la cueva.

#### Reclutamiento dentro de cuevas

-   Dentro de una cueva se pueden reclutar unidades legendarias
    adicionales pagando Brillo, a costes superiores a los del
    reclutamiento exterior.
-   Puede haber como máximo dos unidades de cada clase dentro: dos
    Magos, dos Pícaros y dos Paladines, contando la unidad inicial si
    pertenece a esa clase.
-   Por tanto, el máximo simultáneo es seis unidades legendarias (dos
    por cada una de las tres clases). El reclutamiento se bloquea al
    alcanzar el límite de clase o si no hay Brillo suficiente.
-   Las unidades reclutadas dentro de la cueva son temporales y no se
    incorporan al grupo exterior al salir.

#### Combate, botín y persistencia

-   Cada cueva tiene estado persistente: enemigos derrotados, jefe
    derrotado, cofres abiertos, botín recogido y llave obtenida.
-   Los enemigos y cofres ya completados no reaparecen al salir y volver
    a entrar, ni después de guardar y cargar.
-   La piedra y el Brillo dentro de las cuevas quedan como usos por
    definir; no se debe asumir una función adicional hasta diseñarla.
-   Los detalles de distribución interior, encuentros, recompensas,
    estadísticas y condiciones exactas de salida se definirán antes de
    implementar el hito.

### Hito 9 --- Dirección visual

-   modelos low-poly propios;
-   animaciones de caminar, trabajar, combatir e idle;
-   materiales finales y elementos de entorno modular;
-   audio y feedback de combate/recolección;
-   postprocesado opcional, sin dependencia del gameplay.

### Hito 10 --- Guardado, migración y validación ampliada

-   Incorporar en el estado persistente niveles de
    hacha/martillo/espada, reclutamiento legendario, regiones
    desbloqueadas, llaves y estado de cuevas/cofres.
-   Migrar guardados existentes de `GameState` versión 16 inicializando
    los campos nuevos a valores por defecto seguros: herramientas nivel
    0; ninguna región adicional desbloqueada; ninguna llave adquirida;
    cuevas y cofres con estado inicial coherente; sin unidades
    temporales de cueva guardadas como parte de la tribu exterior.
-   Validar ida y vuelta de guardado/carga y la migración con fixtures
    de versión 16, conservando inventario, unidades, nivel, XP,
    tecnologías y mundo ya generado.
-   No añadir sincronización online ni infraestructura multijugador: el
    proyecto es local para un jugador.

------------------------------------------------------------------------

## 16. Estado de implementación

### Completado en el Hito 1

1.  Sustituir Phaser por Babylon.js en `package.json`.
2.  Crear `Engine`, `Scene`, cámara ortográfica y render loop.
3.  Crear terreno 3D y luces básicas.
4.  Crear el tótem con geometría provisional.
5.  Crear dos unidades con geometría provisional.
6.  Conectar el `GameState` a vistas Babylon desechables.
7.  Implementar picking exclusivo del tótem y proyección del cursor al
    terreno.
8.  Añadir movimiento directo del tótem ligado al cursor durante el
    arrastre.
9.  Añadir cámara que siga suavemente al tótem.
10. Añadir tests deterministas del movimiento, pausa, formación y spawn
    inicial.

### Completado en el Hito 2

-   supervivencia, biomas, bayas, ramitas, cargas, tareas autónomas y
    drops;
-   reclutamiento, especializaciones básicas, hoguera, vida y curación;
-   HUD funcional y generación determinista del mapa provisional.

### Completado en el Hito 3

-   nodos activos de madera, piedra y Brillo;
-   tala de árboles mediante `lumberjack`;
-   representación emisiva de las ruinas luminosas;
-   conservación del flujo transaccional de drops y del contrato de
    ramitas;
-   pruebas deterministas y de accesibilidad por rol.

### Próximas tareas

1.  Implementar y validar las mejoras de hacha, martillo y espada del
    Hito 6.
2.  Completar el reclutamiento legendario con Mago, Pícaro y Paladín.
3.  Diseñar y construir fronteras, campamentos, jefes y llaves del Hito
    7.
4.  Diseñar e implementar la entrada, los encuentros y la persistencia
    de cuevas del Hito 8.
5.  Validar migración y compatibilidad de guardados versión 16 con los
    nuevos campos.

**Criterio global:** el juego sigue siendo local para un jugador, con
simulación determinista y estado persistente. No implementar online ni
añadir una condición de victoria no diseñada.

## 17. Diseño técnico del Hito 2 --- Supervivencia

Esta sección fija los contratos de simulación que ya están conectados al
bucle jugable. La implementación conserva el comportamiento del Hito 1,
el tick fijo y la separación entre simulación, render de Babylon.js y
HUD.

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
-   La prioridad de decisión autónoma es `enemigos` \>
    `nodos de recursos` \> `drops`. En Hito 2A todavía no existe
    combate, por lo que se aplica `nodos de recursos` \> `drops`.
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

### Estado de implementación y determinismo

-   Hito 2 está completado y validado mediante playtest manual. Incluye
    biomas deterministas, nodos, drops, detección, tickets, radio de
    calma, recolección, HUD, reclutamiento, transformaciones, hoguera,
    vida y curación, además de la salvaguarda de madera con ramitas.

-   El combate, la fauna y el oro se incorporan en Hito 4; la generación
    circular final sigue pendiente.

-   El blueprint del mundo recibe una semilla textual y genera
    posiciones, radios, cantidades y tipos con un PRNG local; no usa
    `Math.random()`, Babylon.js ni el DOM. Entrega un número
    configurable de áreas de recursos, con al menos una instancia de
    cada bioma funcional, más los claros decorativos. En Hito 3 la
    configuración jugable activa nodos `food` de tipo `berry-bush`,
    `wood` de tipo `tree`, `stone` de tipo `stone-vein` y `spark` de
    tipo `ruin`, además de los nodos de emergencia `wood` de tipo
    `twigs`.

-   La distancia angular de cada drop se genera con la misma semilla de
    simulación, dentro de un radio cercano al nodo, para variar la
    presentación sin romper el determinismo.

-   La configuración de Hito 2C.2 genera `10` áreas de recursos para
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
    pero no son asignables a los roles jugables actuales. En Hito 4 se
    añaden bárbaros, conejos, oro, drops de comida de origen cárnico y
    combate automático. Los recursos se representan únicamente mediante
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

### Secuencia de implementación

1.  Hito 2A: nodos, tareas de recolección, drops, recogida por unidades
    libres, HUD mínimo y comportamiento `idle` alrededor del tótem.
    **Estado: implementado.**
2.  Hito 2B: botón de hoguera, coste de `2` madera, arrastre desde el
    HUD y colocación en el mapa. **Estado: implementado y validado
    manualmente.** La curación se completó en Hito 2D.
3.  Hito 2C.1: reclutamiento de `gatherer`, transformación irreversible
    con hacha/arco, costes dinámicos según población activa, límite
    global de 8, máximo de 5 por tipo especial y protección del último
    recolector. **Estado: implementado.** La partida empieza con `0`
    unidades de comida, madera, piedra y Brillo.
4.  Hito 2C.2: distribución compacta y determinista de 10 áreas de
    recursos, separación entre regiones, claro inicial, 12 claros
    decorativos y vegetación abundante sin interacción. **Estado:
    implementado.**
5.  Hito 2D: vida de los minions, daño preparado para
    minions/bárbaros/animales, círculos de vida, parpadeo rojo al
    recibir daño, radio de curación de la hoguera, consumo de comida y
    VFX de curación. **Estado: implementado.** Fauna y combate activo
    quedan fuera.
6.  Salvaguarda de madera: nodo de ramitas en al menos la mitad de los
    claros (incluido el inicial), recolectable por cualquier rol y con
    drop de `2` maderas. Curación de hoguera ajustada a un punto cada
    `8` segundos. **Estado: implementado.**

**Cierre del Hito 2:** todos los subhitos y la salvaguarda de madera
están implementados y validados manualmente. No quedan tareas pendientes
dentro de este hito.

Cada corte debe conservar los tests del Hito 1, mantener el tick fijo de
20 Hz y verificar que los recursos nunca son negativos, la carga nunca
supera su capacidad y toda unidad tiene un fallback válido.

## 18. Diseño técnico del Hito 3 --- Recursos avanzados

**Estado: COMPLETADO Y VALIDADO**

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

## 19. Diseño técnico del Hito 4 --- Conflicto

**Estado: COMPLETADO; PRUEBAS AUTOMÁTICAS Y PLAYTEST MANUAL DE
COMBATE/HUD**

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
-   No hay victoria en Hito 4; la derrota ocurre al quedar `0` minions
    vivos. No hay armadura ni retirada automática por salud o energía de
    vínculo.
-   La aceptación cubre determinismo, estadísticas, alertas sin
    repetición por tick, caza y botín, reapariciones, persecución al
    mover el tótem, derrota, pausa y recursos no negativos.
-   La aceptación incluye regreso del bárbaro a su spawn antes de
    patrullar, leash/bloqueo del cazador y desaparición del cadáver
    después de un único saqueo completo.

------------------------------------------------------------------------

## Registro de cambios

### 0.5.0

-   Se fija el alcance del proyecto como juego local para un jugador y
    se eliminan hitos/secciones de multijugador online.
-   Se actualiza el roadmap con los Hitos 6--8: mejoras de herramientas,
    clases legendarias, fronteras/campamentos y cuevas.
-   Se define que solo Mago, Pícaro y Paladín pueden entrar en cuevas;
    entra únicamente la clase legendaria activa y la tribu exterior se
    queda fuera.
-   Se define el reclutamiento temporal dentro de cuevas, máximo dos
    unidades por clase y seis unidades legendarias simultáneas.
-   Se especifican los efectos iniciales de las mejoras de hacha,
    martillo y espada, el menú separado y los cinco rangos de color.
-   Se establece compatibilidad de guardados con `GameState` versión 16
    y valores por defecto para los nuevos campos.
-   Se mantiene sin definir la condición de victoria; Gran Hoguera y
    piedras de memoria no son mecánicas actuales.
-   El Mago queda preparado para futuras especializaciones
    Nigromante/Fuego, pero estas se aplazan a un hito posterior.

## Fuentes

-   [Vídeo de referencia compartido --- observación de
    mecánicas](https://www.youtube.com/watch?v=zeov1Zzq9f0)

-   [Wanderers.io Wiki --- The
    Tribe](https://wanderersio.fandom.com/wiki/The_Tribe)

-   [Wanderers.io
    Wiki](https://wanderersio.fandom.com/wiki/Wanderers.io_Wiki)

-   [Miniplay ---
    Wanderers.io](https://www.miniplay.com/game/wanderers-io)

-   [Not Doppler ---
    Wanderers.io](https://www.notdoppler.com/wanderersio.php)

-   [GitHub --- proyecto de
    preservación](https://github.com/Avoxel284/wanderersio)

-   [Babylon.js --- especificaciones del
    motor](https://www.babylonjs.com/specifications/)

-   [Babylon.js --- motor para juegos
    web](https://www.babylonjs.com/games/)

-   [Babylon.js ---
    física](https://doc.babylonjs.com/features/featuresDeepDive/physics/usingPhysicsEngine/)

Este documento define un juego original inspirado en un patrón de diseño
histórico. No constituye una licencia para reutilizar contenido de
Wanderers.io.

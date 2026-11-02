# Investigación de referencia — Wanderers.io

**Propósito:** documento de contexto histórico. No es una especificación de Tribes Revival; las decisiones propias están en el GDD.

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


## Separación entre referencia y diseño propio

Los datos de esta investigación no deben trasladarse automáticamente a Tribes Revival. Si una mecánica no está recogida en el GDD como decisión del proyecto, se considera referencia o hipótesis, no requisito de implementación.

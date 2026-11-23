# IMPLEMENTATION_STATUS --- Tribes Revival

## Agarre durante la persecución

El cazador y el mago mantienen el bloqueo de agarre durante la huida con ataques y los dos segundos posteriores. En Godot 4.7.2 pasaron 23 pruebas de combate y agarre y 69 comprobaciones de entrada. Se comprobó el rechazo del arrastre para los siete roles y durante 80 ticks consecutivos de persecución para cada combatiente a distancia.

## Cursor de prohibición

La interfaz usa `prohibited.png` para agarres bloqueados, destinos inválidos, herramientas que no se pueden aplicar, sacrificios bloqueados y botones deshabilitados. El PNG conserva los 64 × 64 píxeles, compresión sin pérdida, mipmaps desactivados y filtrado nearest.

Al soltar un minion, el cursor espera a que se procese la suelta antes de volver a evaluar el agarre. En un destino prohibido, el icono acompaña al minion elevado. Una herramienta reservada para un minion conserva el cursor de agarre hasta que se señala un destinatario incompatible.

Se ejecutaron 62 comprobaciones de arrastre y cursor en modo headless y con ventana en Compatibility. También pasaron la prueba de entrada de colocación y la suite de datos.

## Bloqueo de agarre durante el combate

El agarre se bloquea durante la tarea de combate y durante los 40 ticks posteriores a su fin. Durante el bloqueo, el cursor muestra el icono de prohibición. El guardado conserva la espera pendiente. La huida sin combate previo permite agarrar al minion.

Verificado en Godot 4.7.2 con 21 pruebas GdUnit de combate y agarre, 47 comprobaciones de entrada y 29 748 comparaciones de datos y guardados. La regresión cubre el arrastre a un nivel superior, la retirada, el reinicio de la espera tras otro combate y su persistencia al pausar y recargar.

## Detección de enemigos por nivel

La simulación filtra los objetivos nuevos y los avisos de combate por nivel de terreno. Conserva los rivales activos al cruzar un desnivel. La prueba de rutas cubre ambos sentidos de detección y el daño a distancia. En una copia en memoria del slot 1 se simularon 200 ticks, con 493 observaciones de parejas cercanas en niveles distintos sin combate previo y ninguna adquisición nueva entre ellas.

## Superposición de sprites junto a mesetas

Los personajes, recursos y adornos terrestres con sprite frontal usan profundidad por píxel sobre su pivote. La prueba de render en Compatibility verifica el solapamiento delante, detrás y a ambos lados del borde de una pared.

## Recogida de drops junto a bordes

- Los minions pueden recoger drops desde suelo firme junto a mesetas,
  costas y el límite del mapa. Las tareas existentes que apuntan a un
  centro inaccesible se reajustan al continuar.
- La llegada al destino de navegación ya no condiciona la recogida si
  el drop está al alcance por el mismo lado del desnivel. El último
  tramo dentro de la casilla admite la holgura normal de movimiento.
- En la reproducción headless del slot 2, los tres drops originales
  quedaron bloqueados durante 400 ticks antes de la corrección. Con ella
  se recogieron en 25 ticks. `test_island_routes.gd` cubre ambos lados de
  la pared y el rechazo de la recogida a través del desnivel.

## Grupos de rocas acuáticas

- La generación reparte las rocas costeras en grupos de dos a cinco con
  un mínimo de dos casillas entre rocas. Se mantiene el triple del total
  base en las 32 semillas comparadas, con 45–48 rocas por mapa.
- Se revisaron dos costas a dos niveles de zoom en Compatibility.

## Mayor densidad de rocas acuáticas

- Ocho variantes de roca costera con animación a 10 FPS. Los mapas nuevos
  triplican el total del generador anterior. Los guardados conservan sus
  posiciones y cantidades.
- En 32 semillas se verificaron 45–48 rocas por mapa, el triple exacto y
  las posiciones anteriores intactas. Pasaron 46 957 comprobaciones de
  decoración. Se revisaron dos costas a dos niveles de zoom en Compatibility.

## Posición de salida de la flecha

- El Cazador usa el marcador editable `Body/Sprite/ArrowSpawn` para
  colocar la salida sobre el arco. El desplazamiento lateral se refleja
  según el sentido del tiro. La salida se revisó en Compatibility.
  La rotación Z del marcador define el ángulo inicial de la flecha.
  La transición al ángulo de vuelo se verificó en Compatibility.

## Builds de desarrollo del 23 de noviembre de 2026

- Exportadas y empaquetadas Windows x86-64, Linux x86-64 y web con Godot 4.7.2. Los ZIP y sus hashes están en `godot/builds/`. Los complementos del editor se excluyeron en la copia temporal usada para exportar.
- Arranque headless comprobado en Windows y menú inicial comprobado en Edge por HTTP. En Linux se verificó el binario ELF x86-64. La ejecución en Linux queda pendiente.

## Lanzamiento y recogida de recursos

- Los seis sprites de recogida sustituyen a los cilindros. Las piezas salen hacia un destino transitable, dan dos rebotes y los minions las recogen al asentarse.
- Los sprites mantienen su orientación durante el vuelo y al asentarse usan la posición de sprite y la escala y altura de sombra del drop de madera. Verificado con `test_drop_flight.gd` y una captura en Compatibility al zoom inicial.
- El guardado conserva la fase del lanzamiento. Los objetos de guardados antiguos aparecen asentados.
- Godot 4.7.2 headless verificó el lanzamiento, la recogida, la carga, los datos y el trabajo civil durante combate. Se revisaron cuatro capturas con los seis sprites simultáneos en Compatibility al zoom inicial.

## Rendimiento base de nodos y fauna

- Cada recolección genera una unidad base del recurso del nodo y cada oveja cazada deja una unidad de comida. El hacha y el martillo conservan la posibilidad de añadir una unidad. El botín de los bárbaros conserva su tabla.
- Los nodos de partidas existentes aplican la regla al recolectarse. Los objetos ya guardados en el suelo se conservan.
- Verificado en Godot 4.7.2 headless con `test_tree_resources.gd`, `test_data.gd` y `test_respawn_interpolation.gd`.

## Animaciones y pastoreo de las ovejas

- La oveja usa clips de reposo, movimiento y pastoreo a 10 FPS.
  Alterna patrulla, reposo y pastoreo mediante el reloj de simulación.
  Retoma su destino al acabar y guarda la fase en curso.
- Pasan 1024 comprobaciones de animación, incluidas pausa, velocidad
  acelerada, guardado, reaparición e impacto del Cazador mientras pasta.

## Disparo del Cazador sincronizado con el impacto

- El reloj fijo coordina el sexto fotograma, la salida, el vuelo y el
  impacto. Los objetivos pueden esquivar la flecha al salir del punto
  fijado. Los aciertos muestran un destello y los fallos levantan polvo.
- Pasan las pruebas de disparo y de guardado con una flecha en vuelo.
  Revisado en Compatibility un acierto a velocidad normal y un fallo
  a velocidad triple. Persiste la diferencia conocida de ocho destinos
  de recolección en `test_data.gd`.

## Orientación de los sprites en pantalla

- Minions, bárbaros y ovejas orientan el cuerpo según su desplazamiento
  horizontal en pantalla y conservan la orientación al detenerse o ser
  transportados. El cambio de sentido conserva el fotograma.
- Pasan 970 comprobaciones de animación, las pruebas de arrastre y
  visibilidad y la prueba de oclusión con el cuerpo reflejado en Compatibility.
  Revisadas capturas del Cazador y la oveja en ambos sentidos.

## Disparo del Cazador

- La flecha visual sale en el sexto fotograma y usa el sprite propio del
  Cazador con Nearest. Pasan 957 comprobaciones de animación, incluida la
  salida de una sola flecha y su retirada al terminar el vuelo.

## Retorno a reposo de los minions

- La vista activa la carrera según el desplazamiento entre ticks. Al detenerse,
  el minion vuelve a reposo aunque navegación conserve su última velocidad.
  Pasan 953 comprobaciones de animación, el arrastre y la interpolación de reaparición.

## Animaciones de unidades y recursos de campamento — 2026-11-22

- Recolector, Cazador, Guardián, Leñador, Artesana y Mago usan SpriteFrames
  editables a 10 FPS. Los ataques del Guardián, Cazador, Mago y
  Leñador se reproducen una vez por evento de combate. El Leñador reutiliza
  el gesto de hacha. El Mago rojo usa la lámina `Attack.png`
  que trae el lote actual.
- Preparadas dos escenas rojas adicionales, nueve unidades negras y ocho
  edificios negros para colocar desde el editor. Los 87 PNG del lote
  se reimportaron con Lossless y sin mipmaps. Las escenas nuevas usan Nearest.
- En Godot 4.7.2 pasan 951 comprobaciones de animación e importación, 2644
  de visibilidad y las pruebas de profundidad y oclusión con Compatibility.
  Se revisaron capturas de las seis clases y se verificó la selección mediante
  rayos a dos tamaños de cámara. Pasan 41 comprobaciones de selección y
  arrastre. Queda el recorrido interactivo en partida.
- `test_data.gd` devuelve ocho diferencias de destino de recolección. Se
  reprodujeron con los mismos valores en una copia que solo contiene la
  simulación y sus pruebas.

## Relieve del archipiélago — 2026-11-22

- Nueva partida y Reiniciar generan islas y biomas de huella rectangular con
  recortes desiguales. El claro queda llano y las cimas se reparten entre
  mesetas distintas alrededor de la isla inicial.
- En Godot 4.7.2, las 64 semillas probadas produjeron mapas distintos y
  repetibles, con 7–8 mesetas, 3–4 cimas y aproximadamente un 80 % de tierra
  de nivel 1. Se verificaron las rutas por escaleras a cada altura, el viaje
  de ida y vuelta en simulación y la decoración en otras pruebas de 32 semillas.
- La carga de una partida del generador anterior conservó sus cinco mesetas,
  biomas, recursos y decoración. Se revisaron las capturas de las semillas
  `tree-biomes-0`, `tree-biomes-1` y `tree-biomes-2`.

## Costas rectas y recursos agrupados — 2026-11-22

- Las partidas nuevas generan costas e istmos rectos y terrazas de tamaño
  acotado. Los bosques agrupan 5 a 8 pinos recolectables, las praderas
  2 a 4 árboles y los pedregales 4 a 6 nodos de piedra.
- Arbustos y césped aparecen en grupos. Las setas son ocasionales y las
  cuatro variantes de roca animada quedan sobre el agua. Las escenas de
  las rocas permiten editar sus ocho cuadros a 10 FPS.
- Pasaron 23 casos GdUnit4, las comprobaciones de terreno y recursos en
  64 semillas y las de decoración en 32. También se verificaron rutas
  entre alturas, recolección y carga del formato 4 con registros de
  decoración previos y nuevos. Se revisaron capturas de tres semillas
  en Godot. Queda pendiente una partida manual completa.

## Terrazas de tres alturas y tilesets revisados — 2026-11-21

- El formato de guardado 4 conserva los tiles cubiertos de cada bioma y la
  superficie transitable. Las parcelas altas tienen contraste local, las cimas
  están rodeadas de una terraza intermedia y montaña permite piedra, madera y bayas.
- El catálogo contiene 296 AtlasTexture. Las pruebas de cobertura incluyen
  los PNG actuales y las seis escenas de bioma. La comprobación geométrica
  de la escena de referencia verifica un tile de base cubierto y las dos
  filas del atlas en una misma pared que cruza la orilla.
- Verificados en Godot 4.7.2 la importación sin caché, el arranque, los 23 casos
  GdUnit4, la generación en 64 semillas, las rutas de ida y vuelta hasta la cima,
  guardado/carga, arrastre, visibilidad y decoración. Se revisaron capturas de
  la escena de referencia y de una partida. Queda pendiente una partida manual completa.

## Apoyo visual de los recursos — 2026-11-21

Los diez modelos recolectables tienen el apoyo del sprite ajustado a la cámara y una sombra horizontal editable por variante. Se compararon capturas de la escena principal en ambas alturas con sustituciones temporales de atlas por referencias de terreno sin resolver. Se capturaron los ocho fotogramas de cada árbol.

## Archipiélago jugable de dos alturas — 2026-11-21

- Las partidas nuevas generan una isla inicial, istmos y cinco mesetas. Los
  cinco biomas conservan su identidad. El terreno bajo es verde y el pedregal,
  las ruinas y los nodos de piedra y Brillo solo aparecen en el nivel superior.
  El guardado local usa el esquema 3 con archivos propios. Los archivos del
  esquema 2 se conservan en disco y quedan fuera de la lista de partidas actuales.
- El tótem y los minions recuperan su último aterrizaje válido al soltarlos sobre
  agua o paredes. Las unidades navegan por las escaleras y las ovejas patrullan
  y reaparecen en su pradera. La escena TerrainReference permite revisar el
  desnivel y la selección de superficies con F6.
- El catálogo contiene 332 recortes, incluidos el agua y 16 fotogramas de espuma.
  Se inspeccionaron capturas del archipiélago generado y de la escena de
  referencia en Godot 4.7.2 Compatibility. La comparación de fotogramas
  mostró movimiento en la espuma y sombra visible bajo el acantilado.
- Pasaron los 23 casos de GdUnit4, las comprobaciones de recursos en 64 semillas,
  decoración en 32 y visibilidad en ocho. La prueba de rutas trasladó la tribu
  entre alturas en el bucle de partida, recorrió escaleras con un bárbaro y
  comprobó el combate, la patrulla de ovejas, la reaparición y el puntero.
  También pasaron guardado/carga, arrastre, colocación y comportamiento
  táctico. Queda pendiente una sesión completa jugada manualmente.

## Suelo modular de los cinco biomas — 2026-11-20

- Claro, pradera, bosque, pedregal y ruinas usan huellas conexas de celdas
  de 1,5 m. La generación y la recolocación visual de vegetación utilizan la
  misma huella que el suelo. Los recursos funcionales respetan la exclusión
  inicial del tótem. Las ovejas patrullan dentro de sus praderas. Los slots del esquema 2 guardan las celdas y sus recursos.
- Disponibles 315 recortes AtlasTexture, incluidas las piezas agrupadas,
  las variantes de color, las piezas elevadas y la sombra. Las escenas activas
  usan exclusivamente las 16 piezas planas del bioma correspondiente.
- Godot 4.7.2 completó 23 de 23 casos GdUnit4. Las pruebas de recursos cubrieron
  64 semillas, las de decoración 32 y las de recolocación ocho. Pasaron paridad
  de datos, guardado/carga y flujo del menú. La prueba de atlas verificó la
  cobertura de los píxeles visibles de todas las fuentes.
- Se revisó la composición de bosque en el editor y se inspeccionaron capturas
  de los cinco biomas a tamaños de cámara 36 y 18. Pasaron las pruebas gráficas
  de sombras de nubes y oclusión de árboles. Queda pendiente el recorrido
  interactivo de una partida completa.


## Límite del tótem para aceptar avisos de recursos — 2026-11-15

- Los avisos de nodos solo asignan receptores si el recurso está dentro del radio
  de mando del tótem más el margen del 5 %, según decisión del usuario. El
  límite se mide desde el tótem y se adapta al radio actual. Se conservan las
  reglas de emisores levantados, afinidad, disponibilidad y reservas.
- Actualizados `work_system.gd`, las regresiones de `test_minion_carry.gd`, GDD,
  contratos técnicos y QA. No cambian detección directa ni llamadas de combate/caza.
- Verificado con Godot 4.7.2: 17/17 pruebas GdUnit y 8584 comparaciones de datos.
  Incluye el escenario tras soltar lejos y destinos dentro/en/fuera del borde
  con dos radios distintos. Pendiente validación manual en partida.


## Corrección de avisos de recursos desde minions levantados — 2026-11-15

- `dispatch_resource_call` rechaza emisores con `isCarried`: levantar una unidad
  ya no puede enviar a un aliado hacia recursos lejanos por una llamada suya.
  Los avisos normales de unidades en el suelo conservan su comportamiento.
- Añadida regresión en `test_minion_carry.gd`: reproduce el fallo antes del
  arreglo, comprueba cuatro segundos de simulación sin que el aliado abandone
  el mando y verifica que el emisor vuelve a poder avisar al depositarlo.
- Verificado con Godot 4.7.2: 16/16 pruebas GdUnit y 8584 comparaciones de datos,
  sin errores. Pendiente comprobación manual del escenario en partida.



## Reposicionamiento manual de minions — 2026-11-15

- Implementado pulsar/mantener/soltar sobre minions propios, uno cada vez,
  sin coste ni límite de distancia al tótem. Cámara fija; cuerpo elevado,
  marcador de suelo y altura editable desde las escenas de personajes.
- En el aire no trabajan, atacan, detectan, bloquean ni reciben daño; no avanzan
  su enfriamiento/bloqueo de ataque ni su curación. Los enemigos cambian de
  objetivo inmediatamente o regresan a patrulla. Al soltar, recuperan IA y
  vulnerabilidad; fuera del mando regresan sin iniciar tareas o combate.
- Colocación libre más cercana determinista, sin empujar otros cuerpos. HUD,
  pausa y pérdida de foco depositan en la última posición de mapa. Guardados
  conservan la unidad en el suelo; el estado portado es opcional en v17.
- Archivos: `minion_carry.gd`, entrada `main.gd`, comandos, combate, trabajo,
  movimiento, supervivencia, persistencia y vistas; escena `MinionCarryMarker`
  y sus instancias en CharactersBase/Minion. Cobertura nueva en GdUnit y
  `test_minion_drag_input.gd`, integrada en `godot/tools/validate.sh`.
- Verificado con Godot 4.7.2: 15/15 pruebas GdUnit (11 nuevas); 17 comprobaciones
  de entrada nativa/escenas; 8584 comparaciones de datos/guardados; 101 de menús;
  cuatro ciclos de entrada de colocación; escenarios tácticos, bordes tácticos,
  combate del mago, huida civil e interpolación de respawn, todos sin errores.
  Carga de 38 scripts/90 escenas; verificador estático: cero errores y seis
  avisos en fixtures del complemento GdUnit4.
- Captura automatizada renderizada y revisada con Compatibility/AMD Radeon
  RX 6700: cuerpo elevado, marcador en el suelo y salud desplazada. Evidencia
  local: `godot/reports/minion-carry-preview.png`. No equivale a playtest manual.
- La importación headless cargó el editor, pero al cerrarlo emitió avisos de
  siete instancias ObjectDB y tres recursos retenidos. El log verbose identifica
  los tres scripts retenidos en `addons/funplay_mcp/core/` (settings, core_tools y
  tool_registry); no se ha modificado ese complemento. Los runners de estructura,
  pruebas y captura terminaron sin esos avisos.
- Pendiente: playtest con dos/ocho unidades, selección entre oclusiones,
  distintos zooms, comodidad del rescate y edición de altura/marcador en Inspector.

## Interruptor de dither y césped grande — 2026-11-13

- Añadido `dither_enabled` editable por escena; desactivarlo limpia el recorte y omite las comprobaciones de oclusión.
- Grass usa el dither de arbustos; GrassSmall permanece sin efecto.
- Validación ejecutada: carga de 37 scripts y 87 escenas; visibilidad natural, 5184 comprobaciones; referencias, cero errores y seis avisos existentes de fixtures de gdUnit4.
- Pendiente revisión visual del césped grande en juego.

## Ajustes de dither de arbustos — 2026-11-13

- Las cinco variantes decorativas usan hole_radius 0.6, dither_edge_width 0.5
  y dither_pixel_size 1 por indicación del usuario.

## Corrección del centro dither en arbustos — 2026-11-13

- Reproducido fallo de integración: el centro basado en rectángulos completos
  podía caer sobre márgenes transparentes, dejando el follaje visible intacto.
  491 de 732 solapamientos con un personaje real tenían centros mal colocados.
- covered_point selecciona una muestra opaca del cuerpo realmente oculta por
  follaje, próxima al centro del cuerpo. Árboles mantienen su centro anterior;
  arbustos conservan sus radios pequeños y detección previa optimizada.
- test_bush_occlusion pasa 732 solapamientos, cinco variantes y ambos reflejos:
  cero centros mal colocados. Verificado también en Compatibility con captura
  bush-character-dither.png. Pasan visibilidad (5184) y vegetación (31722).

## Dither en arbustos decorativos — 2026-11-13

- Cinco variantes con recorte localizado: radio/borde 0.2/0.1; pequeño 0.1/0.05.
  Centrado en el solapamiento cuerpo/follaje, usando detección optimizada compartida.
- Sin cambios en bayas, césped, setas ni datos de simulación. Escenas editables.
- Pasan test_bush_dither renderizado, vegetación (31722), visibilidad (5184)
  y estructura (37 scripts/87 escenas). Captura de las cinco variantes revisada
  y radios reducidos para conservar follaje. Pendiente recorrido interactivo.

## Círculos dither en árboles — 2026-11-13

- Sustituida la atenuación global por recortes circulares: centro completamente
  despejado, anillo Bayer y exterior opaco. Radio, ancho y tamaño del patrón
  editables; varios círculos independientes por árbol, máximo 32. Tótem excluido.
- Shader con profundidad normal, atlas/animaciones originales y material por
  instancia. Conservado el descarte previo por cajas proyectadas optimizado.
- Pasan visibilidad (5184), árboles (36845), estructura (37 scripts/87 escenas),
  pruebas de píxeles renderizados (centro/exterior/borde) y escenas reales en
  bosque/pradera a dos zooms, con avance de animación y exclusión del tótem.
- Capturas revisadas. Benchmark sintético de ocho minions con sombras: 2–5 ms
  por fotograma en tres tandas; no equivale a FPS de una partida completa ni
  mide el peor caso con 32 círculos. Pendiente recorrido interactivo prolongado.
- Comprobador de referencias: cero errores; seis advertencias en plantillas
  y recursos de pruebas del addon gdUnit4 ajeno a este cambio.

## Transparencia de árboles sin tótem — 2026-11-13

- El tótem deja de activar la atenuación de árboles; minions y enemigos mantienen
  el comportamiento. Retirado el muestreo de la malla del tótem y su caché.
- Pasan visibilidad (5183), árboles (36845) y renderizado Compatibility en
  bosque/pradera a dos zooms con tótem delante/detrás y personajes ocultos.

## Optimización de oclusión con ocho minions — 2026-11-13

- Identificado coste excesivo en update_occlusion: cada árbol recorría las
  muestras de todos los cuerpos aunque no se solaparan. Añadido descarte previo
  por cajas proyectadas y reutilización de transformaciones por cuerpo.
- Sombras TotemShadow conservadas. Medición Compatibility/Radeon RX 6700,
  semilla shadow-bench, ocho minions, VSync desactivado, tres tandas alternadas
  de 60 frames después de calentamiento: mediana con sombras 18.99 → 2.12 ms;
  sin sombras 18.85 → 2.03 ms. Escena de presentación sin ticks de simulación:
  no representa FPS garantizados de una partida completa.
- Microbenchmark headless de oclusión: ocho minions ~37.37 → 1.14 ms; informes
  y scripts en godot/reports/bench_shadows*.gd y bench-shadows-*.log.
- Pasan visibilidad (5183 checks), vegetación (31722), árboles (36845) y
  renderizado real de transparencia con personajes/tótem en bosque/pradera
  a dos zooms. Pendiente confirmar mejora en la partida concreta del usuario.

## Sombras de minions y enemigos — 2026-11-08

- CharactersBase y Minion incorporan una instancia centrada y reducida de
  TotemShadow como GroundShadow; las clases y Barbarian la heredan.
  Sheep oculta la heredada y conserva su sombra existente.
- Validación Godot: 37 scripts/87 escenas. Comprobador de referencias:
  cero errores/advertencias en 330 archivos. Pendiente revisión visual en partida.

## Ajuste de densidad y altura de nubes — 2026-11-08

- Altura central reducida a 15 m. Composiciones Cloud/2/3/4 con cantidades
  grande/mediana/pequeña: 1/1/1, 1/2/2, 1/1/3 y 1/2/3 respectivamente.
  Sombra, recorte alfa y velocidad física de lluvia conservados; origen de
  gotas adaptado automáticamente a la altura.
- Pasan 127 comprobaciones de nubes y 48 elecciones estables. Captura de las
  cuatro composiciones renderizada en Compatibility y revisada visualmente.

## Nubes elevadas y sombra de terreno — 2026-11-08

- Veinte sprites con Discard 0.5; eliminada la franja pintada al 33 %. Altura
  central editable de 22 m mediante Clouds; conservadas las cuatro composiciones.
- GroundShadow compartida: plano 14 × 9, elipse suave, opacidad máxima 12 %,
  profundidad normal. Altura ajustada a 0.08 m porque el bioma llega a 0.07;
  el valor previsto de 0.06 quedaría oculto por el terreno.
- Lluvia desde altura − 1.2 hasta 0.9, conservando velocidad física original.
- Importación, estructura (37 scripts/87 escenas), referencias (324 archivos),
  pruebas de nubes (131 checks/48 elecciones) y datos/guardados (8575) pasan.
- Compatibility/Radeon RX 6700: seis capturas sobre claro/pradera/bosque a
  zoom 36/72 y comparación de píxeles con/sin sombra pasan. Revisadas capturas
  de altura, lluvia y composiciones. Pendiente recorrido interactivo prolongado.

## Nubes sprite en cuatro composiciones — 2026-11-08

- Retiradas las cinco esferas y sus materiales provisionales de Cloud. Cuatro
  composiciones editables Cloud/Cloud2/Cloud3/Cloud4, cada una con una grande,
  dos medianas y dos pequeñas de los dos tipos; CloudBase comparte Rain y adaptador.
- Selección visual estable por semilla/ID independiente del PRNG de simulación;
  posiciones, fases, lluvia y guardados conservan sus contratos. Texturas
  Lossless, sin mipmaps, detección 3D desactivada y sprites Nearest.
- Godot 4.7.2: importación y estructura (37 scripts/87 escenas), 83 comprobaciones
  de nubes y 48 elecciones estables, datos/guardados (8575), árboles/tala/lluvia
  (36845) pasan. Referencias: cero errores/advertencias en 320 archivos.
- Captura Compatibility/Radeon RX 6700 de las cuatro composiciones generada y
  revisada en `godot/reports/cloud-compositions.png`. Pendiente recorrido
  interactivo de un ciclo completo de clima y ajuste manual desde Inspector.

## Profundidad natural, separación y transparencia — 2026-11-08

- Sustituye las prioridades visuales documentadas en las entradas históricas
  inferiores: recursos, personajes, tótem 3D y contorno vuelven a respetar profundidad.
- Separación decorativa solo visual, determinista por semilla/ID; doce candidatos
  dentro del bioma u omisión, con huellas editables y reservas de nodos agotados.
- Cuatro árboles con zona de copa, opacidad 35 % y tiempos 150/250/150 ms editables.
  Detección por muestras de cuerpo/malla y alfa de la copa; atlas comprimidos
  descomprimidos antes de recortar. Animación y opacidad independientes por instancia.
- Conservados transforms, velocidades y sombras editadas por el usuario. Las
  pruebas antiguas aceptan velocidad positiva editable y sombras auxiliares,
  sin permitir que vuelva la geometría provisional del árbol.
- Godot 4.7.2: importación y estructura (37 scripts/83 escenas), visibilidad
  (5108 checks, ocho semillas), vegetación (31722), árboles (36845, tala/lluvia
  y mundo guardado), datos (8575, guardados actuales) e input (cuatro ciclos) pasan.
- Compatibility/Radeon RX 6700: ocho comprobaciones de profundidad con malla real
  del tótem y contorno; pruebas de transparencia con personaje y tótem detrás/delante,
  y avance de animación en bosque/pradera a cámara 36/18 pasan. Capturas en
  `godot/reports/visibility-*.png`, inspeccionadas visualmente; arranque renderizado
  de 120 frames sin errores. No equivale a un recorrido interactivo manual.
- Pendiente recorrido prolongado con arrastre, movimiento y zoom y comprobación
  de los controles del Inspector. No se ha ejecutado la matriz ampliada de
  migraciones ni el wrapper completo de validación de sistemas ajenos.

## Retirada del tótem sprite

- Eliminados su escena, adaptador GDScript/UID y textura exclusiva con import.
  Retiradas la referencia y la instancia oculta Totem2 de main.tscn; se conserva
  el tótem 3D jugable. Documentación de edición y prueba de capas adaptadas.

## Prioridad máxima del tótem 3D y sprite

- La partida usa Totem3D; el ajuste anterior solo cubría TotemSprite.
  Corregidos material y contorno del modelo 3D y elevada a 127 la prioridad
  de ambas versiones (contorno 126), por encima de recursos y personajes.
- Pasan siete solapamientos renderizados con Compatibility/Radeon RX 6700,
  incluido el material real del tótem 3D sobre geometría de prueba, y estructura
  (36 scripts/84 escenas). Pendiente recorrido visual con la malla completa.

## Recursos por delante de la decoración

- Prioridad 10 para árboles, bayas, piedra, Brillo y ramitas; prioridad 20 para
  minions, enemigos, animales y tótem sprite. Sin test de profundidad en estas
  capas; recursos sprite con Alpha Cut desactivado.
- Pasan cinco solapamientos renderizados con Godot 4.7.2 Compatibility/AMD
  Radeon RX 6700 y estructura (36 scripts/84 escenas). Pendiente recorrido
  manual de todos los recursos con distintos zooms.

## Bordes del atlas del minion

- Activado `filter_clip` en el icono del minion de tutorial y reclutamiento
  para evitar repetición de píxeles al extender la región de recorte.
  La edición visual documenta `Region`, `Margin` y `Filter Clip`.

## Recorte editable de iconos del tutorial

- Los seis iconos de clases de `TutorialMenu.tscn` usan AtlasTexture propios,
  con la región inicial igual a la imagen completa y editable en el Inspector.
  Las instrucciones de recorte están en `godot/EDITING_VISUALS.md`.
- Pasan estructura (36 scripts/84 escenas) y callbacks de menús (101 checks)
  en Godot 4.7.2 headless. Pendiente comprobación manual del recorte en Inspector;
  no se ha realizado una revisión visual del menú en esta tarea.

## Restauración de la escena de bayas — 08-11-2026

- La escena antigua `scenes/world/Bush.tscn` fue eliminada, pero `WorldView`
  todavía la esperaba para presentar los recursos `berry-bush`.
- Se añadió `scenes/world/BerryBush.tscn`, basada en `assets/resources/bush node.png`,
  y se actualizó la referencia semántica `berry-bush`. Ya no quedan referencias
  a la ruta antigua en scripts, escenas o documentación.
- Godot 4.7.2 pasa la carga headless, la validación de estructura (36 scripts,
  84 escenas), datos/guardados (8575 comparaciones) y el arranque con escena
  principal durante dos segundos.

## Arbustos decorativos animados — 08-11-2026

- Sustituidos medianos/grandes por cuatro escenas AnimatedSprite3D editables:
  Bushe1/2 en claros/praderas y Bushe3/4 en bosques, ocho fotogramas a 10 FPS.
  Se conserva la elección equiprobable pequeño/mediano/grande y su reflejo
  estable. Pequeños y césped siguen estáticos; bayas y simulación intactas.
- Pasan importación, estructura (36 scripts/84 escenas), vegetación (31722
  comprobaciones) y datos/guardados (8575) en Godot 4.7.2. Revisadas capturas
  de los tres biomas a cámara 36/18 y composición de cuatro variantes con
  Compatibility/AMD Radeon RX 6700; confirmado avance de la animación.
- La suite de árboles falla en cuatro aserciones de velocidad: las escenas
  existentes están a 6 FPS y el test anterior exige 10. Se conservan esos
  ajustes ajenos al cambio de arbustos. Pendiente edición manual de variantes
  desde Inspector y recorrido para valorar oclusión en movimiento.
- Capturas locales regenerables: `godot/reports/bushes-*.png`.

## Árboles animados por bioma — 08-11-2026

- Sustituidos los meshes de árbol por cuatro escenas AnimatedSprite3D editables,
  ocho fotogramas a 10 FPS: 1/2 en bosques y otros biomas, 3/4 en praderas.
  Elección visual equiprobable por semilla/ID, sin campos nuevos en guardados.
- Mapas nuevos: mínimo tres bosques dentro de diez biomas de recursos y al
  menos un árbol por pradera, conservando bayas. Los mundos guardados mantienen
  sus biomas y recursos; solo actualizan su presentación.
- Godot 4.7.2: pasa importación, estructura (36 scripts/82 escenas), suite de
  árboles (36845 comprobaciones en 64 semillas, tala/lluvia y guardado v17),
  vegetación (31414), datos/guardados (8575), menús, colocación y suites tácticas
  y civiles existentes. La referencia Babylon permanece intacta; se contrastan
  por separado los campos del mundo que ahora divergen por diseño.
- Revisadas capturas renderizadas con Compatibility/AMD Radeon RX 6700 de las
  cuatro variantes y de bosque/pradera con cámara 36/18. Confirmado avance de
  animación. Pendiente recorrido manual para oclusión con minions en movimiento
  y edición desde Inspector. Capturas locales: `godot/reports/trees-*.png`.
- El verificador histórico de hashes `verify_original.py` falla por diferencias
  frente a su manifiesto en numerosos archivos ajenos a esta tarea y documentos
  actualizados. No se modifica el manifiesto ni se declara ese control superado.

## Trabajo en combate y transferencia de foco por golpe — 08-11-2026

- Los civiles no perseguidos pueden iniciar y completar recolección, drops
  y saqueo dentro del área de combate. La tarea en curso o disponible tiene
  prioridad sobre apartarse, evitando el bucle de acercarse al cadáver y
  retirarse. Se comparte la selección existente mediante `choose_work_task`.
- Un golpe con daño de un combatiente transfiere a este el foco de un bárbaro
  que persigue a un civil. Daño cero no transfiere; una vez centrado en un
  combatiente no cambia por otros golpes. El impacto letal limpia el foco.
- Pasan en Godot 4.7.2 headless: aproximación/saqueo completo junto a enemigo,
  drops y nodos dentro del combate, interrupción por persecución real,
  transferencia de guardián/leñador/cazador, no transferencia entre combatientes
  y continuación de guardado/carga. Se corrigió la semilla de drops para usar
  tick entero tras cargar JSON. Pasan suite civil, ambas suites tácticas,
  estructura (36 scripts/79 escenas) y 10946 comparaciones de datos/guardados.
  Pendiente revisión manual en partida del saqueo y rescate por impacto.

## Foco enemigo persistente — 08-11-2026

- Diagnosticado cambio por cercanía: el foco anterior solo se retenía si era
  atacante y estaba como máximo 0,8 m más lejos que otro atacante. Sustituido
  por retención del objetivo vivo actual mientras siga dentro de 15 m.
  Nuevos atacantes, mayor cercanía de otro minion o transformación no roban
  el foco. Muerte/desaparición o salida de alcance permiten adquirir otro;
  la muerte del bárbaro limpia el ID. Se conserva guardado v17 sin nuevos campos.
- Regresión verificada en Godot 4.7.2 headless: 100 ticks con presa civil y
  guardián atacante, transformación, ventaja de distancia de otro combatiente,
  muerte/desaparición y pérdida de alcance, limpieza al morir el enemigo y
  continuación tras guardar/cargar. Pasan suite civil, ambas suites tácticas,
  estructura (36 scripts/79 escenas) y 10946 comparaciones de datos/guardados.
  Pendiente valoración manual del foco durante una partida.

## Huida aleatoria sin atravesar el tótem — 08-11-2026

- Pausas ampliadas a 2–4 s y destinos aleatorios entre 4 m y el borde del mando,
  con PRNG por semilla, unidad, tick inicial y ciclo. Se conservan 8 m/1,6 s
  entre pausas, huida exclusivamente ante persecución y guardados v17.
- El tótem actúa como obstáculo durante huida: puntos de rodeo, segmentos de
  navegación, pasos y separación respetan el despeje de 2,02 m. El traslado
  del tótem encima de la unidad permite salida gradual sin teletransporte.
- Pasan suite civil (variedad de destinos, determinismo, segmentos sin cruce,
  pausas 2–4 s y guardado/carga), ambas suites tácticas, estructura y 10946
  comparaciones de datos/guardados en Godot 4.7.2 headless. Pendiente comprobar
  en partida la naturalidad de los rodeos y la distribución de destinos.

## Huida condicionada a intención enemiga — 08-11-2026

- El objetivo enemigo se resuelve tras las decisiones armadas y antes de las
  respuestas civiles. Solo el civil elegido activa huida; al perder la
  persecución limpia su episodio. Se conservan pausas y recorridos de 8 m
  para persecuciones reales.
- Los civiles no perseguidos dentro de 3 m de un enemigo que ataca a un aliado
  armado se apartan mediante `avoid-combat`, sin pausas de huida. Fuera de la
  pelea mantienen trabajo/idle; la selección civil omite nodos y drops dentro
  de áreas de combate activas. Al cruzar el tótem y dejar de ser perseguidos,
  salen gradualmente de su despeje para evitar saltos al entrar en idle.
- Verificado: cambio de objetivo entre dos civiles, tribu mixta, retirada
  breve, progreso de recolección conservado, recogida de drops e idle seguros,
  continuación tras guardar/cargar durante retirada. Pasan suite civil, ambas
  suites tácticas, estructura (36 scripts/79 escenas) y 10946 comparaciones
  de datos/guardados en Godot 4.7.2 headless. Pendiente revisión manual en partida.

## Ajuste de huida tras prueba del usuario — 08-11-2026

- Eliminadas la zona fija de 2 m y la exigencia de mejorar la seguridad actual,
  que agotaban las opciones. Cada pausa de 1–2 s permite otro desplazamiento
  de hasta 8 m/1,6 s dentro del mando. La regresión exige al menos tres
  reanudaciones y registra recorridos de 8 m; salud normal: muerte en 168 ticks.
- Pasan suite civil, ambas suites tácticas, estructura y 10946 comprobaciones
  de datos/guardados. Corregido el redondeo de destinos en el borde del mapa
  para mantener la selección tras guardar/cargar. Pendiente revisión manual.

## Huida civil limitada inicial — 08-11-2026

- Implementadas carrera a destino fijo, pausa determinista de 1–2 s y esquivas
  de hasta 1 m/0,4 s dentro de una zona fija de 2 m y del mando. Se aplica a
  cualquier rol sin ataque, también en tribus mixtas. El bloqueo de la carrera
  durante 1 s inicia la fase local. Las pausas publican velocidad cero.
- Alejar el tótem suspende la huida y permite seguirlo hacia una entrada libre
  del mando, conservando la pausa pendiente. Recoger/soltar sin mover, daño y
  cambio de perseguidor no reinician el episodio. Transformación o desaparición
  de amenaza lo limpian. Memoria opcional serializable; guardados v17 sin ella
  siguen cargando, sin cambio de esquema obligatorio.
- Corregido el atasco del bárbaro frente al despeje del tótem cuando persigue
  a un civil parado al otro lado, conservando velocidad, alcance y daño.
- Verificado en Godot 4.7.2 headless: ambas suites tácticas y nueva suite
  `test_civil_flee.gd`; destino estable, tres fases, presupuestos y pausas,
  bloqueo, daño, transformación, tribu mixta, cuatro esquinas, seis/ocho civiles,
  dos perseguidores, tótem móvil y continuación de guardado en cada fase.
  Recolector, artesano y explorador con salud normal mueren en 151 ticks
  (menos de 8 s) en la regresión con tótem fijo y sin curación. El bárbaro
  alcanza al civil estático desde cuatro direcciones y junto a cuatro bordes.
  Pasan validación estructural (36 scripts/79 escenas) y 10946 comparaciones
  de datos/guardados. Pendiente revisión manual de fluidez y aspecto en partida.
- El verificador histórico `verify_original.py` no pasa: detecta diferencias
  de hashes respecto al inventario antiguo, incluidos archivos con CRLF y
  assets retirados. No se modifica ese inventario para ocultarlas.

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

## Huida de cazadores y preferencia por cuerpo a cuerpo — 13-11-2026

- El cazador perseguido comparte la huida limitada de los civiles: destino
  inicial fijo, pausas y esquivas acotadas, suspensión al seguir el tótem y
  memoria opcional persistida. Conserva el ataque a distancia durante las
  pausas dentro del mando y el combate/caza normales cuando no es perseguido.
- Los bárbaros prefieren atacantes cuerpo a cuerpo al adquirir objetivo y
  pueden abandonar a un cazador por uno de ellos dentro de los 15 m. Conservan
  el foco cuerpo a cuerpo; la clasificación usa alcance y admite futuros roles.
- Verificado en Godot 4.7.2 headless: `test_civil_flee.gd` (incluye fases,
  guardado/carga del cazador, disparos durante pausas, mortalidad frente a
  enemigo resistente y relevo por guardián/leñador), `test_tactical_behavior.gd`,
  `test_tactical_edges.gd`, `test_data.gd` (8575 comparaciones) y estructura
  (37 scripts, 87 escenas), sin errores. Pendiente valoración manual en partida
  de las persecuciones alrededor del tótem y del combate de tribus mixtas.
# Herramientas de desarrollo — 13-11-2026

- Ambos complementos figuran activados. Funplay respondió por MCP stdio
  autenticado con la escena abierta y 49 nodos; queda comprobar su disponibilidad
  en un nuevo chat de Codex y el panel de GdUnit en el editor.

- GdUnit4 6.2.3 incorporado; cuatro pruebas de economía y combate pasan en
  Godot 4.7.2 headless. Falta validar su panel dentro del editor.
- Funplay MCP 0.9.2 copiado al proyecto; activación y comunicación con Codex
  pendientes. MemPalace y las Skills se detallan en `DEVELOPMENT_TOOLS.md`.

## Sombras de recursos recolectables

- Piedras y Brillo de ambos tamaños, bayas y ramitas tienen la sombra compartida
  ajustada por escena. Retiradas las sombras añadidas a decoración y otros objetos.
- Captura comparativa con renderer Compatibility revisada junto a un árbol; queda
  pendiente comprobar las sombras durante una partida completa.

- Sombras de recursos corregidas con escala uniforme y centradas bajo sus sprites;
  captura comparativa revisada con Compatibility. Pendiente revisión en partida.

## Combate básico del mago

- Implementado ataque automático de objetivo único: 2 de daño, alcance 3 m y
  cooldown 2.5 s. Comparte reservas a distancia, huida y límites del tótem con
  hunter, sin adquirir animales para caza. Las ramas futuras siguen pendientes.
- Añadida escena editable MageProjectile y presentación violeta provisional
  desde el evento de ataque existente; captura mage-basic-attack.png revisada.
- Godot 4.7.2: pasan estructura (37 scripts/88 escenas), test_mage_combat,
  test_tactical_behavior (incluye mago), test_tactical_edges, test_civil_flee y
  test_data (8584 comparaciones). Captura con renderer Compatibility ejecutada.
- Pendiente playtest del ritmo de disparo y del proyectil en movimiento.

## Proyectil provisional del cazador

- Añadida HunterProjectile.tscn y conexión visual en WorldView al evento
  attack-lunge del cazador, compartido por combate y caza. Flecha orientada
  al punto del ataque; daño y cadencia conservan su resolución existente.
- Captura de combate revisada con Compatibility; pasan estructura
  (37 scripts, 89 escenas) y datos (8584 comparaciones).
- Pendiente revisión en partida del vuelo durante combate/caza.

## Reaparición sin deslizamiento

- Corregida la captura de posiciones previas de TribeSession: excluye actores
  muertos para evitar interpolar desde la muerte hasta el punto de reaparición.
- Godot 4.7.2 headless: pasa test_respawn_interpolation (bárbaro y oveja, cinco
  fracciones de render y movimiento posterior), estructura, test_data y
  test_tree_resources. Pendiente observación visual durante una partida.

## Cursor de agarre

- Flecha personalizada en menús, HUD y espacio vacío; interact al pasar sobre
  minions o tótem agarrables; grab al llevarlos o colocar un elemento del HUD.
  Texturas y puntos activos editables en el Inspector de main.
- Durante el transporte de minions o tótem, CarryCursor.tscn dibuja la mano
  elevada según la proyección de la altura visual y el zoom. Conserva el
  punto lógico del ratón; restaura el cursor nativo al soltar, perder foco o salir.
- Godot 4.7.2 headless pasa las 33 comprobaciones de
  `test_minion_drag_input.gd`, incluidos estados del cursor, cruce del HUD y pausa.
  Pendiente revisar apariencia y puntos activos durante una partida.

## Área de interacción del menú principal

- Sustituido el desplazamiento visual de los cuatro botones por espacio real
  en el contenedor del título para alinear dibujo y área de interacción.
- Godot 4.7.2 headless pasa las 40 comprobaciones de hover y clic de
  `test_main_menu_hit_areas.gd` en las cuatro esquinas y el borde inferior de
  cada botón. Pendiente observación visual en ventana.

## Suelta sobre entidades — 2026-11-19

Corregido el rechazo por redondeo de posiciones libres junto al cursor en minion_carry.gd. La prueba reprodujo el salto antes de la corrección. Pasan las 18 pruebas GdUnit y las 33 comprobaciones de entrada. Pendiente revisión manual en partida.

## Presentación del arrastre

Retirado el círculo amarillo de las escenas de minions. Pasan las 33 comprobaciones de entrada y estructura de test_minion_drag_input.gd. Pendiente comprobación visual en partida.

## Sacrificio desde el HUD

Implementada la calavera contextual con protección del último minion y recompensa de una comida. Pasan 19 pruebas GdUnit y 40 comprobaciones de entrada y escena.

El sacrificio usa el fotograma final del cadáver de minion y detecta el solapamiento de su cuerpo elevado. HUD y simulación protegen al último productor de comida. Pasan 20 pruebas GdUnit y 40 comprobaciones de entrada.

La suelta sobre la calavera desactivada se resuelve en simulación colocando al minion protegido dentro del mando. Verificado con 20 pruebas GdUnit y 41 comprobaciones de entrada y escena.

La calavera de sacrificio usa la variante en escala de grises del HUD al deshabilitarse. Pasan las 41 comprobaciones de entrada y escena. Pendiente revisión visual.

El sacrificio rechazado actualiza el origen de interpolación del minion en el mismo tick de la recolocación. Pasan las 21 pruebas GdUnit y 41 comprobaciones de entrada y escena. Validación automática.

## Submenú Jugar

- El menú principal muestra Jugar, Tutorial y Salir. Jugar abre una escena
  editable con Nueva Partida, Cargar cuando hay un guardado válido y Volver.
- En Godot 4.7.2 pasa `test_play_menu_flow.gd` con guardados aislados.
  Verifica el inicio con los tres slots ocupados sin alterarlos, la carga,
  el borrado y los retornos de menú. Pasan también las 60 comprobaciones de
  puntero y clic de `test_main_menu_hit_areas.gd` en ventana a 960 × 540.
  Se revisó una captura del submenú a esa resolución.

- El submenú hereda la escena principal. La prueba de flujo confirma en
  ventana a 960 × 540 que mantiene el título y su posición, y que el panel
  conserva sus dimensiones con y sin guardados. También confirma que
  Jugar desde el tutorial abre el submenú. Pasan las 60 comprobaciones
  de puntero y clic.

- Retirado el foco automático de Nueva Partida. La prueba de flujo reproduce
  el fallo antes de la corrección y confirma que Jugar y la selección de slots
  se abren sin foco. Pasan las 60 comprobaciones de puntero y clic en ventana.

La simulación selecciona recursos y objetivos enemigos según la conectividad del terreno. El cruce compartido de escaleras y la salida tras cancelar una tarea se comprobaron con test_island_routes.gd en Godot 4.7.2 headless. Pendiente la comprobación visual.

Los mapas nuevos generan una escalera de dos casillas contiguas por meseta y por cima. Las pruebas headless de Godot 4.7.2 verificaron la geometría en 64 semillas y el cruce simultáneo de dos minions en sentidos opuestos. Los terrenos guardados conservan su distribución.

Arrastre del tótem por el borde. En una reproducción de 200 ticks con la semilla drag-edge-profile, el percentil 95 de la simulación pasó de 29 a 11 ms tras optimizar las consultas de terreno y límites de formación. Pasaron las pruebas headless de rutas, combate táctico, bordes y huida civil.

La generación mezcla biomas en islas de nivel 1 e incorpora una pradera de inicio con exactamente un arbusto de bayas, un árbol recolectable y dos ovejas. Verificadas 64 semillas con test_tree_resources.gd y recorridos y patrullas con test_island_routes.gd.

Las nubes cruzan el mapa desde el inicio con nuevas entradas cada 30 segundos. La lluvia que repone comida y madera se programa cada 90 segundos y los bárbaros reaparecen a los 180 segundos. Pasaron las pruebas de cadencia, guardado, nubes e interpolación de reaparición en Godot 4.7.2. La paridad histórica reporta ocho diferencias de coordenadas de trabajo en la selección de recolección.

Las ovejas reaparecen en su punto de origen 90 segundos después de ser cazadas. Verificado con la prueba de temporizadores y la de interpolación de reaparición en Godot 4.7.2.

## Mapa exterior y recorrido de revisión — 2026-11-23

El generador de partidas nuevas combina costas curvadas, una llanura costera asimétrica, bocas de paso ensanchadas y terrazas con escaleras principales de cinco carriles. Los árboles y grupos decorativos reservan espacio delante de las escaleras. El catálogo comprueba posiciones de trabajo y cuotas antes de aceptar un candidato. Tras ocho intentos puede cargar un plano poblado de reserva. El formato de los slots se conserva.

Godot 4.7.2 completó 128 trayectos de ida y vuelta sobre 64 semillas, con uno y ocho artesanos, entrega de piedra y reagrupación. El trayecto más largo con ocho unidades fue relieve-061 con 422 ticks. Dos procesos produjeron los mismos hashes para los 64 planos completos. Pasaron las suites de datos, árboles, rutas y decoración. Se comprobó la conservación de terreno, regiones, recursos agotados, decoración, animales y bárbaros de un mundo generado con la revisión 0318d04 tras guardar y cargar. La prueba de captura usó proyección real del puntero y revisó la subida con ocho unidades; la evaluación de comodidad con ratón físico queda pendiente. El renderer Compatibility informó al cerrar de una textura pendiente de liberar.

La formación reparte huecos por superficie y puede extenderse fuera del radio antes de usar otra altura. La recogida local, separación, determinismo y asentamiento se verificaron con test_island_routes.gd y test_data.gd. Pasó test_tactical_behavior.gd. La reproducción de 200 ticks de arrastre por el borde midió 10 ms en el percentil 95 de simulación.

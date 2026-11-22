# QA_TEST_PLAN — Tribes Revival

**Propósito:** pruebas y criterios de aceptación. Los requisitos funcionales se derivan del GDD; los criterios aquí verifican su implementación. Este documento no define nuevas mecánicas.

**Alcance actual de guardado:** guardar y cargar una partida de la versión
actual funciona y se comprueba como flujo normal. Las pruebas de migración,
compatibilidad entre versiones antiguas y nuevas, y guardados parciales o
malformados quedan aplazadas para una fase avanzada del proyecto. No añadir
casos ni invertir tiempo en esa matriz de compatibilidad hasta que se reactive
explícitamente ese hito. Esta pausa no elimina la comprobación básica de
guardar y cargar durante el desarrollo de sistemas que dependan de ello.

## Pruebas automáticas y manuales

### Tests automáticos

#### Terreno, recursos y decoración

- Verificar cobertura de los recortes, agua y espuma, además de los dos
  acabados de acantilado en la escena de referencia.
- En 64 semillas comprobar determinismo, conectividad, contraste y tamaño
  de terrazas, pertenencia de recursos y densidades de árboles y piedras.
- Verificar que las manchas de vegetación respetan las huellas de recursos,
  que el grupo conserva su forma al cargar y que las rocas quedan sobre agua
  y reproducen sus ocho fotogramas. Revisar varias semillas en Godot.
- Probar en el bucle de partida el traslado del tótem, las rutas por escalera,
  la recolección, y la persistencia de terreno, nodos y decoración.

#### Menú principal y submenú Jugar

- `test_main_menu_hit_areas.gd` envía movimiento y clic reales del sistema GUI
  en las cuatro esquinas interiores y el centro inferior de los botones del
  menú principal y del submenú Jugar con un guardado disponible.
  Comprueba el Control bajo el puntero y la señal pressed.
- `test_play_menu_flow.gd` comprueba la visibilidad de Cargar con cero a tres
  guardados válidos y con un guardado inválido, el inicio de una partida con
  los tres slots ocupados, la conservación de los guardados, la carga real,
  el regreso con Volver o Esc y el borrado del último guardado válido.
- El mismo test comprueba que Jugar desde el tutorial abre el submenú y que
  el título, su posición y el tamaño del panel coinciden con los del menú
  principal, haya o no guardados válidos.
- El test comprueba también que ningún botón recibe el foco al abrir Jugar
  desde el menú principal o el tutorial, ni al abrir la selección de slots.
- Revisar en ventana el resaltado y la alineación del cursor en esos bordes.

#### Cursores de interacción

- `test_minion_drag_input.gd` comprueba interact sobre minion y tótem,
  flecha sobre UI y pausa, y grab durante transporte y colocación desde HUD,
  incluido transporte sobre UI.
- En partida, verificar los tres PNG, alineación del punto activo, flecha en
  espacio vacío y botones de menús, y transición al agarrar y soltar.
- El test de arrastre verifica la elevación proyectada de la mano para minion
  y tótem con dos tamaños ortográficos y la restauración del cursor al soltar.
  Revisar visualmente seguimiento, zoom y pérdida de foco durante transporte.

#### Profundidad natural, separación y transparencia

- Headless: `test_natural_visibility.gd`, ocho semillas, separación de huellas,
  pertenencia al bioma, repetibilidad tras JSON, estado intacto, agotamiento y
  omisión sin candidatos válidos. Comprueba márgenes alfa, orden por profundidad,
  zona de copa, opacidades independientes, espera y tiempos de recuperación.
- Compatibility, sin headless: `test_sprite_layers.gd`, ocho comprobaciones de
  profundidad, usando también la malla real y el contorno del tótem.
- Compatibility: `test_visibility_render.gd`, capturas de bosque/pradera a
  tamaños de cámara 36 y 18 con suelo e iluminación del juego; comprobar avance
  de animación y transparencia con personaje detrás; comprobar que el tótem detrás/delante no activa transparencia.
- Revisar las capturas opacas/atenuadas de `godot/reports/visibility-*.png`.
  Completar recorrido interactivo con arrastre, movimiento y zoom para valorar
  parpadeos, legibilidad y edición de radios/copas desde Inspector.

#### Árboles animados por bioma — Godot

- `test_tree_resources.gd`: 64 semillas repetibles, diez áreas de recursos,
  mínimo tres bosques, árboles y bayas en cada pradera, IDs únicos, recursos
  dentro del bioma y ausencia de solapamientos.
- Cuatro variantes animadas de ocho fotogramas con velocidad editable; nearest,
  sin geometría de árbol provisional (se permiten sombras editables);
  reparto por bioma, variedad y estabilidad tras JSON, sin mutar estado.
- Tala real de un árbol de pradera, duración base, drops individuales,
  desaparición al agotarse y reaparición por lluvia con la misma variante.
- Guardar y cargar un mundo modular del esquema actual. Comparar celdas y recursos y comprobar que la presentación conserva los datos.
- Capturas renderizadas de bosque/pradera a tamaños de cámara 36 y 18, y
  composición de las cuatro variantes. Pendiente recorrido manual con minions
  para valorar oclusión en movimiento y ajustes de Inspector.

#### Variantes de nodos de piedra y Brillo — Godot

- Verificar tamaños pequeños/grandes estables por semilla e ID, también al
  reconstruir desde JSON; muestrear distintas semillas para comprobar variedad.
- Las cuatro escenas deben contener Sprite3D con Nearest y ninguna geometría
  provisional. No deben referenciar el sprite de piedra de nivel 2.
- Confirmar que la presentación no modifica posiciones, niveles, cantidades,
  rendimientos, radios ni el estado serializado. Conservar la regresión de datos
  y guardado/carga actual.
- Revisar visualmente tamaño, centrado y apoyo en el suelo; comprobar edición
  de las cuatro variantes desde el Inspector en la siguiente prueba manual.

#### Seguimiento del efecto de curación — Godot

- Comprobar que el efecto coincide con la posición interpolada del minion
  en las seis clases, conserva el transform del sprite definido en escena,
  no modifica el estado y se retira al expirar.
- Revisión manual: centrar el anillo alrededor de los pies y observar la
  curación mientras camina, sin separación entre ticks ni ascenso adicional.

#### Filtrado de sprites e iconos — Godot

- Comprobar que el viewport usa Nearest como filtro 2D predeterminado,
  que ningún CanvasItem de la UI lo sobrescribe con Linear y que los
  Sprite3D/AnimatedSprite3D usan Nearest, incluido el fuego de la hoguera.
- Revisión visual manual: recursos del HUD, reclutamiento, equipo,
  tecnologías, mejoras, menús y tooltips, tanto en editor como en ejecución.

#### Vegetación decorativa con sprites — Godot

- `test_world_decorations.gd`: generación repetible en 32 semillas; césped,
  arbustos y setas solo en claros, praderas y bosques; cantidades por bioma,
  incluido el claro inicial, margen interior y máximo de dos setas.
- Carga de las diez variantes con filtro nearest, sin meshes ni colisiones;
  pequeños y césped estáticos; cuatro arbustos animados con velocidad editable positiva, hojas 1/2
  en claros/praderas y 3/4 en bosques. Muestreo de ambas variantes y pequeño
  en cada bioma; autoplay y estabilidad al reconstruir desde JSON;
  selección visual estable al reconstruir el mundo y estado lógico intacto.
- La referencia Babylon se mantiene sin modificar. `test_data.gd` compara
  los datos iniciales ajenos a biomas, recursos, decoración y animales; las
  divergencias aprobadas del mundo se comprueban en las suites específicas.
  Conserva la comparación de posiciones de biomas y la generación de animales
  sobre los biomas históricos. Guardado/carga actual sigue cubierto por `test_data.gd`.
- Revisión visual: capturas del claro inicial al zoom normal y en detalle,
  bosque y pradera. Revisar además en una partida manual el zoom, la oclusión
  durante el movimiento y la edición de variantes desde el Inspector.

#### Suite de regresión — movimiento y formación

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

#### Cobertura general de regresión

-   Tótem levantado: guardianes, leñadores y cazadores conservan combate
    cercano dentro del mando. Al superar los 10 m terminan el impulso activo
    y siguen al tótem sin soltarlo, sin otro golpe ni readquisición fuera
    del radio, incluso si el enemigo sigue dentro. Regresión automatizada
    en `godot/tests/test_tactical_behavior.gd`; repetir manualmente el arrastre.

-   llamadas puras de enemigos/animales: detector de cualquier rol,
    respondedor fuera de rango propio, afinidad, disponibilidad, reserva
    única por llamada, prioridad de enemigos, desempates y restricciones
    de movimiento; conservar objetivos observados y liberar muertos/perdidos.

-   En los escenarios existentes de combate, usar posiciones de ataque
    válidas fuera del tótem y enemigos sin solapamiento; distinguir el
    enfriamiento de la llegada al hueco. La retirada puede rodear obstáculos
    antes de acercarse al tótem. Comparar posiciones calculadas con tolerancia
    decimal, manteniendo comprobaciones de daño y tiempos de reaparición.

-   funciones puras de navegación: distancia continua en cruces frontales,
    perpendiculares y adelantamientos; rodear trabajadores sin mutarlos;
    reducción de velocidad, bloqueo, prioridades y cesión del idle en pausa;
    reservas de trayectos, desempates estables, límites y parada en destino;
-   rutas de rodeo deterministas con cada segmento libre, trabajadores
    consecutivos, camino limitado a un lado y objetivo ocupado; continuidad
    del lado elegido ante pequeñas variaciones del cruce;
-   reservas puras de combate: huecos separados, anillos cuerpo a cuerpo y
    cazador, continuidad al incorporarse atacantes, huecos ocupados y espera
    exterior cuando no cabe otro atacante;
-   persistencia de ruta, lado de evasión y offset de combate, conservando
    compatibilidad con unidades sin datos de navegación;
-   puntuación idle: frente frente a zona posterior, aglomeraciones de
    posiciones o destinos y admisión de destinos traseros;
-   funciones puras de retorno al rango: conservar posiciones interiores
    (incluida la franja 8–10 m), usar el radio de mando vigente y el acceso
    más cercano desde fuera, sin slots centrales; respetar bordes;

-   funciones puras de idle: repetibilidad, variación entre unidades,
    espera 1–3 s, destinos y segmentos del anillo, esquinas y radio de mando;
-   persistencia idle: continuar destino/espera/contador al guardar y cargar
    en la versión actual;

-   misma semilla = mismo mundo;
-   guardar/cargar conserva el estado;
-   costes nunca producen recursos negativos;
-   todas las transiciones de IA tienen fallback;
-   daño y cooldown son reproducibles.

### Pruebas manuales

-   hacer que un recolector vea un enemigo con un combatiente libre fuera
    de su radio personal: comprobar que acude; repetir con un animal y un
    cazador fuera de su radio de detección. Confirmar que el detector puede
    continuar trabajando o huir de una amenaza local según su rol.
-   repetir llamadas con especialistas ocupados, varios objetivos y varios
    minions libres: comprobar que la llamada no duplica respondedores para
    objetivos atendidos y que amenazas prevalecen sobre caza/recursos.
    Matar/perder el objetivo y mover el tótem debe liberar o interrumpir la
    tarea; el cazador sigue respetando su límite alrededor del tótem.

-   con 2 y 8 minions, revisar cruces frontales/perpendiculares, adelantamientos,
    rodeos a unidades trabajando y pasos con poco espacio; comprobar que no
    haya entrelazado, vibraciones, empujes frecuentes o bloqueos permanentes;
-   revisar seguimiento, retorno, recolección, caza, combate y huida con aliados
    en la trayectoria; confirmar llegada real antes de completar acciones;
-   rodear un trabajador sin desplazarlo y comprobar que el rodeo mantiene
    su lado; tras bloquear un idle, comprobar espera y elección de otro destino;
-   con guardianes/leñadores y cazadores contra un bárbaro, comprobar huecos
    libres alrededor, espera si el anillo está lleno y cazadores a distancia;
    añadir/quitar un atacante sin que todos cambien de hueco ni empujen al
    bárbaro. Repetir con varios bárbaros, junto al tótem y al borde del mapa;
-   comprobar ritmo: movimiento normal/combate 6 m/s, idle 3 m/s, seguimiento
    al tótem 10 m/s y retorno sin trabajo 8 m/s;
-   observar idle desde la cámara habitual: preferencia por
    frente/laterales, reparto del grupo y posibilidad de ocupar la zona posterior;
    repetir junto a bordes y después de guardar/cargar. Sin automatizar el loop;

-   con 2 y 8 minions sin trabajo, comprobar paseos lentos variados y pausas,
    sin sincronización, bloqueos ni vibración junto al tótem y bordes del mapa;
-   finalizar recolección, drops, saqueo, caza y combate dentro del radio
    de mando (también entre 8 y 10 m): entrar en idle donde termina la tarea,
    sin caminar a una formación. Fuera de rango, volver solo hasta entrar
    y comenzar idle; los trabajos locales pueden seguir encadenándose;
-   mover el tótem: seguirlo a 10 m/s, alcanzar la formación y pasar después
    a trabajo/idle. Reclutar dentro del rango no debe activar formación;
-   cargar un guardado con `return-to-totem` apuntando al antiguo anillo
    de 3,25 m: si ya está en rango, cancelar el regreso sin desplazamiento;
    si está fuera, entrar por el borde sin continuar al destino antiguo;
-   interrumpir paseo/pausa con recursos, drops, llamadas o enemigos;
    comprobar prioridades y arrastre del tótem, pausa/reanudación y carga
    durante un paseo. Estas comprobaciones del loop no se automatizan;

-   abrir/cerrar ambos paneles y cambiar de árbol sin desplazar los botones
    Tecnologías/Mejoras; revisar tooltips de Artesana, Mago y Escudo (también
    inactivos) en ventanas estrechas y 1280×720, con texto legible dentro del
    juego y etiqueta «Nivel requerido: 2» o «Nivel requerido: 1» según el caso;
-   iniciar en nivel 0 con XP 0/12 y 0 puntos; guardar/cargar antes de subir
    de nivel y comprobar que se conserva el estado de esa partida;

-   revisar el tutorial: no debe aparecer el texto que explica mejoras y el Mago debe decir «Minion avanzado. Poderoso en combate. Necesario para Mazmorras.»;
-   cámara en 1280×720 y 1920×1080;
-   zoom mínimo y máximo;
-   arrastre del tótem sobre terreno libre y bloqueado;
-   unidades separadas y retorno;
-   combate con ocho unidades;
-   pérdida de foco del navegador;
-   guardado durante recolección y combate;
-   en el menú de slots, comprobar que cada guardado ocupado ofrece una papelera, cancelar conserva la partida y confirmar elimina solo el slot elegido; los slots vacíos no muestran la papelera;
-   HUD manejable por teclado;
-   comprobar la fila superior centrada de recursos, sus iconos y cantidades de tres o más cifras en 1280×720 y 1920×1080, y el reflujo en una ventana estrecha;
-   comprobar que los sprites de comida, madera, piedra, Brillo y oro se ven en contadores y los cuadrados de colores permanecen en los costes; verificar que los iconos de minion, hacha, arco, espada, martillo, libro, escudo y Hoguera aparecen en tutorial/HUD/tecnologías/mejoras donde corresponda, sin cambios en los modelos de la escena;
-   comprobar el orden lateral Recolector, Leñador, Cazador, Guardián, Artesana, Mago y Hoguera; Artesana y Mago solo aparecen tras sus tecnologías y el Escudo permanece arriba a la derecha;
-   abrir/cerrar «Tecnologías» y «Mejoras» abajo a la izquierda; verificar exclusividad, posición de sus paneles, opciones de tecnologías en fila, orden izquierda-derecha, expansión y reflujo sin salir de pantalla;
-   comprobar que las tarjetas de tecnología solo muestran icono y coste; el tooltip contextual muestra nombre, descripción y nivel requerido, sin repetir el coste en puntos;
-   verificar que Tecnologías abre con Supervivencia, Exploración y Combate cerrados; cada botón abre su fila, sustituye la anterior y cierra la activa al pulsarla otra vez; comprobar reflujo y navegación por teclado;
-   verificar Artesana en Supervivencia, Mago en Exploración y Escudo en Combate, a 1 punto cada una; el tooltip muestra nivel mínimo y no avisos de puntos faltantes; el libro sigue apareciendo entre Artesana y Hoguera tras desbloquear Mago;
-   pruebas de lógica: bloquear Artesana/Mago en nivel 1 aunque haya puntos, permitirlos desde nivel 2, permitir Escudo desde nivel 1 con puntos; rechazar compras sin puntos o duplicadas sin mutaciones; conservar puntos y desbloqueos al guardar/cargar sin revocar tecnologías anteriores;
-   arrastrar el objeto del Mago sobre un Recolector: debe cambiar de clase, consumir el Brillo correspondiente y no aumentar el número total de minions; al soltarlo en el mapa o sobre otra clase no debe transformarlo ni consumir recursos;
-   comprobar que el objeto del Mago queda inactivo sin Recolectores, con Brillo insuficiente o al alcanzar el máximo de Magos;
-   comprobar que guardar/cargar en la versión actual conserva los Magos y
    el desbloqueo tecnológico;
-   revisar tooltips contextuales del HUD lateral en condiciones normales y bloqueadas (coste insuficiente, límites, falta de recolector y desbloqueos), confirmar que siguen legibles cuando el botón está inactivo y que no aparece un tooltip nativo duplicado;
-   comprobar que el último recolector puede convertirse en leñador y en artesana si hay al menos un cazador; sin cazadores, ambas transformaciones quedan bloqueadas con el tooltip «No puedes convertir a tu último recolector»; Mago y Guardián sí pueden transformar al último recolector; sin recolectores, el botón de Artesana queda inactivo y el tooltip dice «Necesitas un recolector»;
-   enfocar y pasar el cursor por cada mejora y verificar tooltip de efecto/coste; en nivel máximo debe decir «Max» y omitir el coste siguiente;
-   verificar visualmente las bandas de nivel 0, +1/+2, +3/+4, +5/+6, +7/+8/+9 y +10 (`#A7A7A7`, `#3F8F54`, `#168397`, `#80508F`, `#B77D35`), comprobando que solo se tiñe el fondo de la tarjeta lateral y el rótulo de mejora, nunca el modelo;
-   comprobar que debug, pausa y velocidad empiezan ocultos y se muestran/ocultan con `Insert` y `Numpad0`, conservando las acciones de sus botones.

### Definición de terminado del vertical slice

1.  Una persona nueva entiende el objetivo en menos de 90 segundos.
2.  Puede mover el tótem, recoger dos recursos y reclutar una unidad.
3.  Puede sobrevivir o perder frente a una amenaza.
4.  La partida de referencia debe poder jugarse en aproximadamente 15–25 minutos. La condición de victoria y su validación quedan pendientes hasta que se diseñen.
5.  El replay de una semilla produce el mismo resultado.
6.  Se mantienen 60 FPS con ocho unidades, cuarenta nodos de recursos y
    doce amenazas en un equipo de referencia.

------------------------------------------------------------------------

## Criterios técnicos adicionales registrados

### Controles y movimiento del tótem

**Aceptación:** arrastrar el tótem produce un destino en coordenadas del
mundo; el clic sobre terreno vacío nunca crea una unidad ni altera
recursos.

### Combate, botín y derrota

**Aceptación:** las posiciones, combates y botín son deterministas; se
respetan HP, daño, alcance y cadencia; las unidades no reciben daño
fuera del alcance; las reapariciones ocurren tras sus temporizadores; el
cadáver y los drops se agotan sin recursos negativos; la derrota solo
sucede al perder toda la tribu; ningún minion solapa el tótem; las
barras enemigas se retiran al morir y se recrean al reaparecer.

## Pruebas de regresión para nuevos sistemas

- Economía: comprobar curvas por población viva y rol, límites de 8/5 y Mago exterior 1, recálculo tras muertes y transformaciones, y ausencia de consumo en acciones inválidas.
- Mejoras: comprobar niveles 0–10, coste de piedra y costes mixtos de Brillo/Oro en 8–10, efectos tabulados, máximo 10 y atomicidad cuando falta un recurso.
- Recursos: comprobar procs deterministas de un máximo de +1 madera/piedra, y que una veta de piedra II no sea elegible antes de Martillo +5.
- Guardado: comprobar ida y vuelta en la versión actual y conservación del
  estado. La migración desde v16/v17 y la compatibilidad con guardados
  parciales quedan aplazadas; no forman parte de la cobertura de esta fase.
- Fronteras: comprobar que cada barrera tiene una fuente de llave accesible, que una llave solo abre su barrera y que el desbloqueo persiste tras cargar.
- Cuevas: comprobar acceso exclusivo de Mago/Pícaro/Paladín, límite de dos unidades por clase y seis en total, eliminación de unidades temporales al salir y persistencia de enemigos/cofres/botín entre visitas y cargas.
- Determinismo: repetir una misma semilla y secuencia de acciones y comparar el estado lógico resultante.

Los casos anteriores describen cobertura de validación, no implican que las funciones estén implementadas ni que los tests ya existan.

### IA táctica en Godot

- Foco enemigo: durante 100 ticks, conservar la presa aunque otro minion la
  adelante sin golpear. Un impacto con daño de guardián, leñador o cazador
  transfiere el foco si la presa es civil; daño cero no. Un segundo atacante
  no roba foco al combatiente cuerpo a cuerpo; sí puede relevar a un cazador.
  Comprobar preferencia inicial y cambio desde cazador hacia guardianes y
  leñadores atacantes, excluyendo los que estén fuera de 15 m.
  Comprobar golpe letal sin foco residual y
  guardado/carga después de la transferencia. Comprobar transformación sin perder ID, guardado/
  carga del foco y adquisición nueva al morir/desaparecer la presa o salir de
  15 m. La muerte del bárbaro limpia el ID. Solo el civil elegido huye; acercar
  un segundo civil no transfiere la huida mientras el primero sea válido.

- Destinos de huida: variedad entre ciclos y reproducción determinista, dentro
  del mando y a partir de 4 m del centro. Pausas completas de 2–4 s. Verificar
  cada segmento recorrido frente al despeje del tótem, además de guardar/cargar
  en las tres fases. Revisar manualmente rodeos y ausencia de persecución circular
  pegada al tótem.
- Regresión de intención: dos civiles y un enemigo; solo huye el elegido,
  al cambiar de objetivo el anterior abandona la huida en ese tick. En tribu
  mixta, el guardián combate, el civil cercano se aparta sin `fleeMemory`,
  y el civil fuera de la pelea conserva progreso de recolección, recoge drops
  y puede estar en idle. Guardar/cargar durante `avoid-combat` conserva la
  continuación. Verificar manualmente el retiro breve y la vuelta al trabajo.

- Ejecutar `godot --headless --path godot --script res://tests/test_tactical_behavior.gd`: persecución civil acotada, repetición determinista y respuesta de un bárbaro superado en número.
- Ejecutar `godot --headless --path godot --script res://tests/test_tactical_edges.gd`: seis civiles, cuatro esquinas, mando móvil y ocho civiles con dos perseguidores; límites, separación, bloqueo y continuidad tras guardado/carga.
- Ejecutar `godot --headless --path godot --script res://tests/test_civil_flee.gd`:
  mortalidad de recolector/artesano/explorador antes de 60 s con salud normal,
  y cazador ante enemigo resistente: debe recibir daño y morir, conservando
  disparos durante las pausas a un máximo de 5 m. Repetir fases y continuidad
  de guardado/carga para cazador; comprobar que al ser rescatado deja la huida
  y recupera combate a distancia. Revisar manualmente la ausencia de vueltas
  indefinidas alrededor del tótem en tribu de cazadores y tribu mixta.
  mando fijo y sin curación; destino inicial estable, pausa completa, esquivas
  de hasta 8 m/1,6 s; al menos tres desplazamientos tras sus pausas,
  con recorridos amplios y sin límite local fijo; bloqueo inicial de 1 s; guardado/carga
  en cada fase y carga v17 sin memoria opcional; pausa de simulación, daño,
  cambio de perseguidor, transformación y fin de amenaza. Levantar/soltar sin
  mover no reinicia pausas; alejar el tótem suspende la huida y permite seguirlo.
  Comprobar tribu mixta y que un bárbaro alcance a un civil parado al otro lado
  del tótem desde las cuatro direcciones y junto a los cuatro bordes del mapa,
  sin atravesar su despeje ni aumentar su velocidad.
- Trabajo dentro del combate: un civil no perseguido se acerca a un cadáver
  junto a un enemigo centrado en un guardián y termina el saqueo sin alternar
  retirada/acercamiento. Recoge drops y elige nodos dentro del área; conservar
  guardado/carga durante ese trabajo. Al pasar a ser objetivo interrumpe y huye.
- Las pruebas ya no exigen movimiento civil continuo ni consideran fallo
  detenerse ante un enemigo. Exigen pausas, vulnerabilidad y límites del mando.
- Revisión renderizada: `godot --path godot --script res://tools/capture_tactical_review.gd` captura un combate mixto en `godot/reports/tactics/`. Utiliza 40 HP en el bárbaro de prueba para observar varias maniobras. No modifica las estadísticas normales.

En mando fijo se exige distancia máxima de 10 m. Si el tótem se desplaza, el
límite de cada paso parte de la distancia tras ese desplazamiento: el civil no
puede aumentarla. El ensayo de movimiento usa pasos del tótem de 0,04 m,
comprueba recuperación en menos de un segundo y exige estar dentro del radio
al final tras detenerlo; no se corrige mediante teletransporte. La suite de
comportamiento incluye prioridades ante un civil más próximo, calma en zona
segura, pausa, regreso al spawn, traslado distante del mando y combate normal
con cadáver y botín. La persecución individual exige daño recibido, destino
estable durante el escape y reanudación de desplazamientos amplios tras
varias pausas dentro del mando.
Pendiente revisión manual en partida: carreras comprensibles, pausas visibles,
ausencia de órbitas continuas y oportunidad de transformar al civil mientras
el bárbaro puede alcanzarlo. Repetir con tribu mixta y obstáculos.

### Composiciones visuales de nubes

- `test_cloud_visuals.gd`: cuatro escenas con una grande, entre una y dos medianas y entre una y tres
  pequeñas próximas, Nearest, profundidad normal, sin esferas antiguas;
  lluvia visible solo en su fase y animada, 48 selecciones estables tras JSON
  y reconstrucción, sin cambios de estado.
- `capture_cloud_variants.gd` genera `godot/reports/cloud-compositions.png`
  con las cuatro composiciones en proyección isométrica para revisar tamaño,
  agrupación y detalle. Completar recorrido manual durante un ciclo de clima.

### Altura y sombra de nubes

- test_cloud_visuals verifica Discard/umbral en veinte sprites, altura inicial y
  actualización desde Inspector, seguimiento de sombra, tamaño/opacidad y
  origen/velocidad física de gotas, además de determinismo y JSON.
- capture_cloud_height genera seis capturas (claro/pradera/bosque, cámara 36/72)
  con recursos, personaje y tótem. Compara píxeles con sombra activa/inactiva
  para detectar su ocultación accidental por el terreno. Revisar separación
  visual nube/suelo y lluvia; completar recorrido interactivo de clima.

### Rendimiento de visibilidad con ocho minions

- test_natural_visibility incluye 75 casos con orientaciones distintas para
  comprobar que las cajas proyectadas nunca excluyen un solapamiento opaco.
- Comparar renderizado con ocho minions y sombras activas/inactivas, VSync
  desactivado, misma semilla/cámara y varias tandas tras calentamiento.
  Distinguir coste de oclusión CPU, tiempo de fotograma de presentación y
  rendimiento de una partida completa con simulación.
- Revalidar test_visibility_render para copa/personaje/tótem a dos zooms.
# GdUnit4: pruebas iniciales

- `godot/tests/gdunit/economy/test_economy.gd`: gasto con recursos suficientes
  e insuficientes, sin mutación cuando no alcanza.
- `godot/tests/gdunit/combat/test_combat_rules.gd`: límites de daño y curación.
- Ejecutar el comando de `documents/DEVELOPMENT_TOOLS.md` después de importar
  el proyecto. Las interacciones visuales no se validan en modo headless.


### Recorte circular dither de árboles

- test_dither_pixels (Compatibility) comprueba centro vacío, exterior opaco y
  mezcla de píxeles solo en el anillo. Captura en reports/dither-pixel-test.png.
- test_natural_visibility: círculos independientes/múltiples, apertura, espera,
  cierre, alfa global intacto y restauración del material nativo.
- test_visibility_render: animación, círculo sobre personaje, ausencia de
  activación por tótem, bosque/pradera y dos zooms. Revisión en movimiento pendiente.

### Dither decorativo

Ejecutar test_bush_dither con Compatibility: cinco variantes estáticas/animadas,
radios inferiores a árboles, alfa global intacto, registro en WorldView y ausencia
de duplicados/mutación de estado tras reconstrucción. Revisar captura
reports/bush-dither-variants.png para confirmar silueta conservada.

- Regresión de integración: test_bush_occlusion prueba posiciones reales de un
  Gatherer ante cinco arbustos y ambos reflejos horizontales; cada centro activo
  debe coincidir con follaje opaco que oculte al personaje. En Compatibility
  guarda reports/bush-character-dither.png. No basta activar update_holes a mano.

### Sombras de recursos recolectables

- Comparar visualmente árbol, piedra, Brillo, bayas y ramitas; verificar tamaño,
  apoyo y ausencia de sombras en decoración durante una partida.

### Combate básico del mago

- Ejecutar test_mage_combat: daño 2, alcance 3, cadencia mínima 2.5 s, posiciones
  a distancia, radio de mando, cooldown tras cambio de tarea y ausencia de caza.
- test_tactical_behavior incluye mago en el retorno con tótem transportado.
- capture_mage_attack.gd con Compatibility captura el proyectil provisional.
- Manual: revisar disparos repetidos en partida, retirada al mover tótem y
  combate con tribu mixta. Nigromante/Fuego quedan pendientes.

### Proyectil del cazador

Ejecutar capture_hunter_attack.gd con Compatibility para capturar la flecha
provisional frente a un bárbaro. Revisar en partida cada disparo de combate y
caza, orientación hacia objetivo y desaparición al acabar el impulso.

### Reaparición sin deslizamiento

- test_respawn_interpolation.gd ejecuta el temporizador real de bárbaro y oveja,
  con muerte y spawn alejados. Comprueba ausencia visual mientras están muertos,
  aparición en posición actual con cinco fracciones de interpolación y movimiento
  interpolado posterior. Incluido en validate.sh.
- Manual pendiente: observar reapariciones en partida a varias velocidades;
  no debe aparecer un recorrido rápido desde la posición de muerte al spawn.


## Reposicionamiento manual de minions — Godot

Cobertura automática: `tests/gdunit/combat/test_minion_carry.gd` comprueba las
clases implementadas, exclusión mutua con el tótem, daño y temporizadores,
liberación de reservas, cambio inmediato de objetivo enemigo, retorno fuera del
mando, recogidas repetidas, colocación segura determinista, pausa y guardado.
`tests/test_minion_drag_input.gd` usa despacho nativo para recoger/soltar,
liberación sobre un Control, pérdida de foco, pausa, cámara y presentación
estructural. Ambos están integrados en `godot/tools/validate.sh`.

Validación manual pendiente:

- Reorganizar una tribu de dos y ocho minions; seleccionar entre solapamientos
  y bajo oclusión, con prioridad del tótem y sin mover la cámara.
- Rescatar un combatiente justo antes/después de un golpe, mantenerlo elevado
  sobre una hoguera y soltarlo dentro/fuera del mando. Comprobar cambio de foco,
  ausencia de curación en el aire y vulnerabilidad inmediata al depositarlo.
- Revisar altura, marcador, barras de vida y precisión del cursor con varios
  niveles de zoom; comprobar los ajustes desde el Inspector.
- Soltar en aglomeraciones, bordes, sobre el tótem y el HUD; pausar o cambiar de
  ventana durante el arrastre. Confirmar que el marcador desaparece al soltar.
- Comprobar en partida que reclutamiento, conversiones y movimiento del tótem
  mantienen sus interacciones, y guardar/cargar después de un rescate.

Las pruebas headless de entrada/estructura no acreditan apariencia ni sensación
manual de control.


### Regresión: avisos de recursos desde un minion levantado

`test_carried_minion_cannot_call_allies_to_distant_resources` coloca un emisor
levantado junto a un árbol lejos del tótem y un leñador libre dentro del mando.
Comprueba que la llamada se rechaza, que tras cuatro segundos el leñador no
recibe ese objetivo ni sale del mando. Al depositar al emisor lejos, los avisos del recurso remoto siguen
rechazándose; con emisor y recurso próximos al tótem vuelven a funcionar. Repetir manualmente el arrastre junto a recursos
fuera de pantalla y observar al aliado junto al tótem.


### Límite de distancia de los recursos comunicados

`test_resource_calls_respect_totem_radius_and_five_percent_margin` comprueba
recursos justo dentro, en el borde y justo fuera del radio de mando multiplicado
por `1.05`, con dos radios de mando diferentes. La regresión de arrastre simula
cuatro segundos después de depositar al emisor lejos: el aliado no recibe el
objetivo remoto ni abandona el mando. Validar manualmente el mismo escenario y
un aviso válido junto al borde del área de trabajo del tótem.

La regresión de colocación prueba 36 direcciones de suelta sobre el tótem y sobre otro minion en posiciones fraccionarias. Comprueba la distancia al cursor y el despeje respecto al cuerpo ocupado.

Al sacrificar, verificar la visibilidad y el resaltado de la calavera, la suelta sobre ella y la protección del último minion. Comprobar el saldo y población al recargar y ante acciones duplicadas.

Sacrificio: verificar soltar con el cuerpo elevado sobre la calavera, y comprobar por separado el bloqueo del único recolector y del único cazador sin otras fuentes de comida.

Verificar un sacrificio rechazado lejos del mando con un aliado ocupando el punto de entrada más cercano. El minion debe quedar dentro del mando junto al aliado, respetando la separación y el saldo de comida.

Al rechazar un sacrificio, comprobar que el origen de interpolación del primer tick en el suelo coincide con el punto de aterrizaje junto al tótem.

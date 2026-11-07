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

- Ejecutar `godot --headless --path godot --script res://tests/test_tactical_behavior.gd`: persecución civil acotada, repetición determinista y respuesta de un bárbaro superado en número.
- Ejecutar `godot --headless --path godot --script res://tests/test_tactical_edges.gd`: seis civiles, cuatro esquinas, mando móvil y ocho civiles con dos perseguidores; límites, separación, bloqueo y continuidad tras guardado/carga.
- Revisión renderizada: `godot --path godot --script res://tools/capture_tactical_review.gd` captura un combate mixto en `godot/reports/tactics/`. Utiliza 40 HP en el bárbaro de prueba para observar varias maniobras. No modifica las estadísticas normales.

En mando fijo se exige distancia máxima de 10 m. Si el tótem se desplaza, el
límite de cada paso parte de la distancia tras ese desplazamiento: el civil no
puede aumentarla. El ensayo de movimiento usa pasos del tótem de 0,04 m,
comprueba recuperación en menos de un segundo y exige estar dentro del radio
al final tras detenerlo; no se corrige mediante teletransporte. La suite de
comportamiento incluye prioridades ante un civil más próximo, calma en zona
segura, pausa, regreso al spawn, traslado distante del mando y combate normal
con cadáver y botín. La persecución individual mide inversiones bruscas de
trayectoria para detectar oscilaciones frecuentes.

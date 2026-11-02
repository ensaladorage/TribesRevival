# IMPLEMENTATION_STATUS --- Tribes Revival

**Propósito:** registro del estado real conocido de implementación y
validación. No define mecánicas ni sustituye el GDD.

## Revisión de progreso --- 02-11-2026

### Alcance de esta revisión

Se han contrastado los documentos con el checkout local disponible y el
código fuente actual. La rama está en `main`, alineada en commits con
`origin/main`, pero hay modificaciones locales sin confirmar en código y
documentación. La auditoría inicial no ejecutó tests ni build ni incluyó
validación visual/manual. Después se implementaron ajustes del HUD, el
desbloqueo tecnológico del Mago y el borrado confirmado de guardados; se
ejecutó `npm run build`. Sigue pendiente la validación manual por el
usuario.

La inspección del código confirma que ya existen las acciones de
reclutamiento exterior del Mago y de mejora de hacha, martillo y espada,
además de persistencia en `GameState` versión 17 y migración desde la
versión 16. Esto acredita presencia de implementación en el checkout,
pero no demuestra su funcionamiento en ejecución ni su validación manual.

### Cambios visibles en el código actual

-   **Mago:** la tecnología cuesta 1 punto y desbloquea una clase especial
    de minion. Su reclutamiento consume Brillo, usa la curva `2, 3, 3, 4,
    4` y respeta los límites global y por clase; la carga reconoce el
    desbloqueo en partidas antiguas con Magos ya reclutados.
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
    pixel art y sus cantidades. Comida, Madera y Piedra usan sprites
    PNG en `sprites/` con siluetas de alpha binario; Brillo y Oro
    conservan sus SVG. La lista
    lateral mantiene el orden aprobado y Artesana y Mago permanecen ocultos
    hasta desbloquear sus tecnologías. El panel tecnológico muestra
    Artesana, Mago y Escudo, en ese orden.
    Comida y Madera reciben compensación leve de brillo y escala para
    igualar la lectura de Piedra. Tecnologías y Mejoras comparten
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
    después de Artesana en el menú, aparición de su tarjeta entre Artesana
    y Hoguera, reclutamiento con Brillo, límites y partida antigua con
    Magos ya reclutados.
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

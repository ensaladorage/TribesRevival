# QA_TEST_PLAN — Tribes Revival

**Propósito:** pruebas y criterios de aceptación. Los requisitos funcionales se derivan del GDD; los criterios aquí verifican su implementación. Este documento no define nuevas mecánicas.

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

-   misma semilla = mismo mundo;
-   guardar/cargar conserva el estado;
-   costes nunca producen recursos negativos;
-   todas las transiciones de IA tienen fallback;
-   daño y cooldown son reproducibles.

### Pruebas manuales

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
-   comprobar el orden lateral Recolector, Leñador, Cazador, Guardián, Artesana, Mago y Hoguera; Artesana y Mago solo aparecen tras sus tecnologías y el Escudo permanece arriba a la derecha;
-   abrir/cerrar «Tecnologías» y «Mejoras» abajo a la izquierda; verificar exclusividad, posición de sus paneles, opciones de tecnologías en fila, orden izquierda-derecha, expansión y reflujo sin salir de pantalla;
-   comprobar que las tarjetas de tecnología solo muestran icono y coste; el tooltip contextual muestra su nombre y descripción;
-   verificar el orden de tecnologías Artesana, Mago y Escudo; el Mago cuesta 1 punto y su tarjeta de reclutamiento aparece entre Artesana y Hoguera tras desbloquearlo;
-   comprobar que una partida anterior con Magos ya reclutados conserva el desbloqueo de la tecnología Mago al cargar;
-   revisar tooltips contextuales del HUD lateral en condiciones normales y bloqueadas (coste insuficiente, límites, falta de recolector y desbloqueos) y confirmar que no aparece un tooltip nativo duplicado;
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

- Mejoras: comprobar coste `n` de piedra para pasar al nivel `n`, límite de nivel 10, efectos numéricos y ausencia de cambios si la compra no puede completarse.
- Guardado: cargar una partida de `GameState` v16, conservar inventario/unidades/XP/tecnologías/mundo y asignar valores seguros a campos nuevos.
- Fronteras: comprobar que cada barrera tiene una fuente de llave accesible, que una llave solo abre su barrera y que el desbloqueo persiste tras cargar.
- Cuevas: comprobar acceso exclusivo de Mago/Pícaro/Paladín, límite de dos unidades por clase y seis en total, eliminación de unidades temporales al salir y persistencia de enemigos/cofres/botín entre visitas y cargas.
- Determinismo: repetir una misma semilla y secuencia de acciones y comparar el estado lógico resultante.

Los casos anteriores describen cobertura de validación, no implican que las funciones estén implementadas ni que los tests ya existan.

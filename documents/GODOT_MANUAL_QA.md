# Validación manual pendiente — Godot

Proyecto y comandos: `../godot/README.md`.

Usar el proyecto nativo o los builds de desarrollo. Comparar con Babylon
servido en `/TribesRevival/`. No sustituir estos casos por automatización de
capturas ni del loop de gameplay. Los casos siguen pendientes salvo los
resultados registrados abajo; una corrección técnica requiere repetición manual.

## Primer resultado manual — 2026-11-05

El usuario informó fallos en Tutorial, Guardar/Cargar y volver al menú
principal desde pausa. Se reprodujo un error de liberación del botón mientras
emitía su señal y se corrigió mediante retirada inmediata y liberación diferida.
Tras el arreglo, el usuario confirmó que Tutorial, Guardar/Cargar y retorno
al menú principal «ya funcionan». Esto valida esas rutas manualmente sin
extender la confirmación a todos los slots, plataformas o casos de la tabla.

Una revisión posterior corrigió Esc para volver al listado desde las
confirmaciones de slot y los mensajes, igual que «Cancelar»/«Volver», conservando
origen y modo. Las 101 comprobaciones headless de callbacks pasan; no validan
aspecto ni input gráfico. Pendiente manual: Esc en confirmar reemplazo/borrado/
carga → slots; otro Esc → pausa o principal; Esc en confirmar salida → pausa.

## Lista manual

El usuario confirmó además el recorrido iniciar → arrastrar/soltar tótem
cerca de recursos → seguimiento → recolección → aumento de inventario.
La aclaración posterior identifica la plataforma como ejecutable Linux;
los casos adicionales se registran a continuación.

En el bloque reclutamiento/equipo/mejora/tecnología/combate, el usuario informó
que la segunda pulsación de reclutar se perdía y que el resto funcionaba.
Se registra éxito básico de equipo, mejora/tecnología y combate con daño y
botín; no se acredita aún alcanzar ocho unidades ni una plataforma concreta.
La pérdida de pulsaciones se reprodujo en el despacho nativo de input y se
corrigió dejando llegar la suelta al botón del HUD. El usuario confirmó después
«Ya funciona» y especificó que las pruebas reportadas se hicieron en el
**ejecutable Linux**. Quedan validados esos recorridos en Linux, incluido
reclutamiento consecutivo. No se da por probado el límite de ocho ni cancelar
sobre el HUD sin una comprobación específica.

Los tooltips ahora incluyen motivos de bloqueo y recursos faltantes derivados
de las reglas existentes. Su revisión visual queda pendiente junto al HUD.

## Incidencia de rendimiento — borde del mundo

El usuario reportó lag al arrastrar por el borde de la pantalla y precisó
que ocurre solo cerca del límite del mundo, en el ejecutable Linux.
Se encontró una búsqueda costosa de rutas hacia posiciones de formación
fuera de los límites: ya se rechazan antes de generar el grafo, manteniendo
el mismo resultado sin modificar las reglas de movimiento. Hay evidencia
de coste en una función pura; no se automatizó la partida ni se midieron FPS.

Tras reabrir el build actualizado para repetir el recorrido cerca del límite,
también con 8 unidades, el usuario respondió «Ahora esta perfecto». La incidencia
de lag queda resuelta manualmente en Linux; se acredita uso de ocho unidades
y fluidez en ese recorrido. No se extrapola a todos los controles ni casos
de navegación.

## Supervivencia y HP — Linux

El usuario confirma curación con hoguera, lluvia y derrota → Reiniciar.
Reporta que los indicadores de vida de los minions apenas se ven. Se amplía
su presentación y se compensa el zoom para mantener el tamaño en pantalla,
con contorno oscuro y colores aliados/enemigos. El usuario confirma después
«Si ya se ven bien», al comprobar cámara cerca/alejada y daño/curación en
Linux. La legibilidad queda validada en ese recorrido. Escudo y otras
plataformas no quedan acreditados por esa respuesta.

El usuario no dispone de Windows y pide centrar las pruebas en Linux por
ahora. Se aplaza esa prueba manual; el build Windows se conserva disponible.

## Controles y slots — Linux

Confirmados Esc para pausar/reanudar y velocidades 1/2/3. Con las revisiones
anteriores de cámara, zoom, arrastre y bordes con ocho unidades, se cierra F2.

Confirmados los tres slots, persistencia tras cerrar/reabrir, carga desde
principal y pausa, cancelación de borrado conservando datos y borrado exclusivo
del slot elegido. Se acredita el guardado de la versión actual en Linux;
las migraciones históricas siguen fuera del alcance activo.

| Área | Comprobación y resultado esperado |
|---|---|
| Inicio | Menú principal y tutorial opacos; «Jugar» inicia 2 minions, inventario vacío y nivel 0 |
| Tótem | Solo se agarra sobre su modelo; arrastre directo, flecha, límites 2–158 m; terreno vacío y teclado no lo mueven |
| Cámara | 45°/35°, rueda/+/- y zoom debug; cámara fija al arrastrar salvo borde, recentrado al soltar |
| Formación/idle | Seguimiento 10 m/s, retorno al radio real 8 m/s, idle a 3 m/s con pausas; repetir con 2 y 8 minions |
| Navegación | Cruces, rodeos a trabajadores, cesión del idle, bordes, detención y llegada real; sin aglomeraciones ni vibración |
| Recolección | Afinidades, ramitas universales, tickets y llamadas; árboles 3 s, piedra I 5 s, otros 1.5 s; mover tótem cancela progreso sin consumir nodo |
| Drops | Árboles 2–3 maderas y ramitas 2, siempre drops individuales; inventario cambia solo al recogerlos |
| Combate | Plazas melee/rango, cooldowns, cazador dentro del leash; sin arma huye; al mover tótem máximo un golpe pendiente y reagrupar |
| Comunicación | Detector llama a combatiente/cazador libre fuera de su rango personal; no duplicar objetivo; enemigos antes que fauna/recursos |
| Daño/vida | Minion 4 HP, bárbaro 5 HP, conejos 2 HP; flashes, impulso, alertas y sonido una vez por encuentro |
| Fauna/loot | Patrullas, bárbaros reaparecen a 60 s y conejos a 30 s; saqueo 1.5 s y drops unitarios de oro/comida/madera |
| Hoguera | Coste 2 madera, máximo 2, vida 120 s, radio 15 m; 1 comida cura 1 HP cada 8 s; desaparece al alejar tótem más de 30 m |
| Clima | Nubes cada 30 s hacia claro/pradera/bosque; llegada repone nodos agotados de comida/madera, lluvia 6 s y salida |
| Reclutamiento | Coste por población viva y límite 8; preview sigue libre al cursor y solo el spawn se limita a 15 m; sin anillo de reclutamiento |
| Transformaciones | Equipo sobre recolector válido; límites y coste por activos; conservar proveedor de comida para hacha/martillo; Mago tras tecnología, 2 Brillo, máximo 1 |
| Escudo | Acceso separado arriba a la derecha, oculto hasta su tecnología; sobre guardián sin escudo, coste por guardianes equipados; +1 HP actual/máximo, sin repetición |
| Progresión | 1 XP por acción, 3 conejo, 5 bárbaro; nivel inicial 0, umbral 12 y +12 por nivel; tecnologías con requisitos 2/2/1 y 1 punto; mostrar puntos, abrir Tecnologías al subir nivel y cerrar al gastar el último en desbloquear; cargar no abre el panel |
| Mejoras/HUD | Niveles 0–10, costes mixtos, bonus entero y Max; paneles excluyentes y árboles plegables; tooltips, orden, colores, reflujo, iconos y tres cifras |
| Pausa/debug | Esc congela la simulación; velocidades 1/2/3 y debug oculto inicialmente; el input del mapa no atraviesa menús |
| Slots | Guardar/cargar los 3 slots conserva progreso y mundo; cargar desde principal/pausa enfoca tótem; cancelar borrar conserva datos, confirmar solo elimina ese slot |
| Salir/reiniciar | Advertencia de cambios sin guardar cuando corresponda; derrota con 0 vivos; «Reiniciar» restaura partida inicial |
| Plataformas | Abrir ejecutable Linux y Windows en sus sistemas, audio y cierre; web secundaria en servidor HTTP; no asumir jugabilidad desde un export exitoso |

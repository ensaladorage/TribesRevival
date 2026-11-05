# Estado de migración a Godot

Actualizado: 2026-11-05. Rama: `migration/godot`. Objetivo completo: activo.

## Continuidad

- Última fase completada: F4 (economía/progresión). F0, F1 y F3 completadas.
- Fase actual: F9 exportaciones generadas; validación manual de paridad pendiente.
- Próxima tarea ejecutable: completar controles/casos avanzados de QA y
  comprobar Windows. Usuario confirma reclutamiento consecutivo corregido;
  las pruebas manuales reportadas corresponden al ejecutable Linux.
- Incidencia activa: al arrastrar el tótem por el borde de la pantalla en
  Linux, el usuario reporta lag intenso. F2 sigue abierta. Investigar antes
  de cerrar controles; no alterar velocidades ni reglas para ocultarlo.
- Ejecución local: abrir `godot/project.godot` con el ejecutable local
  `godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2 confirmado).
- Comparación original: `npm run dev`, ruta `/TribesRevival/`.

## Tabla de progreso

| Fase | Estado |
|---|---|
| F0 auditoría | Completada: 42 archivos con hashes/imports; originales verificados |
| F1 base | Completada: editor importa, 1 script y 1 escena válidos; arranque sin ticks |
| F2 controles | Inicio y arrastre confirmados por usuario; zoom/bordes/pausa/velocidad/debug pendientes |
| F3 determinismo/mundo | Completada: estados iniciales completos equivalentes en 4 semillas |
| F4 economía/progresión | Completada: tablas/XP/tecnologías/costes y bonuses verificados; integración de compras sigue en F7 |
| F5 IA/recolección | Usuario confirma seguimiento y recolección con aumento de inventario; casos de 8 unidades/obstáculos/interrupciones pendientes |
| F6 combate/clima | Usuario confirma combate con daño/botín; clima/respawn/hogueras/derrota pendientes |
| F7 compras/equipo | Usuario confirma equipo/mejora/tecnología y reclutamiento consecutivo en Linux; límites/todas las clases pendientes |
| F8 UI/guardado | Usuario confirma Tutorial, Guardar/Cargar y retorno al principal; HUD/slots exhaustivos y Esc pendientes |
| F9 integración/exportación | Tres builds exportados; usuario confirma arranque y recorridos básicos en ejecutable Linux; Windows/web y QA restante pendientes |

## Pruebas y límites

- Ejecutable local: versión 4.7.2.stable.official.ed1daf0bf.
- Game Development Studio CLI 1.5.1 disponible; capabilities/doctor consultados.
  Proveedores de pago no configurados; no son necesarios para placeholders.
  No se solicitan ni ejecutan capturas GPU o pruebas visuales automatizadas.
- F1: `bash godot/tools/validate.sh` correcto (editor headless, carga e
  inicialización de escena sin frames de gameplay; 42 originales intactos).
  `git diff --check` correcto. Informes locales: `reports/f1-validation.log`.
- Usuario confirma que Tutorial, Guardar/Cargar y retorno al principal ya
  funcionan tras la corrección. Confirma también iniciar, mover el tótem,
  seguimiento y recolección con aumento de inventario. Resto de UI/gameplay pendientes;
  no se afirma paridad completa todavía.
- Export templates 4.7.2 instalados y verificados (13 archivos desktop/web).
  Recibo `audit/export_templates.json`; ZIP de desarrollo generados.
- Pendientes de diseño heredados: cuevas/jefes/regiones y costes de Pícaro/
  Paladín. No bloquean la migración de los sistemas que sí existen.
- El original mantiene guardados del navegador; portarlos a `user://` no
  implica acceso al localStorage desde Godot.

## Cambios

- F0/F1: plan, inventario, proyecto Compatibility, escena mínima y validador
  estructural sin avanzar el juego. Original Babylon sin cambios.
- F2a: cámara ortográfica 45°/35°, altura 72 × zoom 0.5–1, arrastre directo,
  límites 2–158 m, scroll de borde a 32 m/s y recentrado a 4.5; cola de acciones,
  driver 20 Hz/máximo 4 ticks, pausa/1–3/debug y cancelación al perder foco.
  Importación y arranque estructural correctos: 4 scripts/1 escena, sin ticks.
  Informe `reports/f2-validation.log`. Sin playtest. Flecha y sliders de zoom se incorporan en F7;
  revisión manual pendiente, F2 no se declara completada.
- F5 incorpora formación y libera la orden de marcha al llegar las unidades.
  F6 conecta combate, fauna móvil, clima y curación; falta presentar su feedback.

- F3: portados FNV-1a UTF-16/Mulberry32 bit a bit, 23 biomas por mundo Hito 3,
  nodos y rendimientos, ramitas, decoración, cinco bárbaros, seis conejos,
  roster inicial y estado v17 completo. `generate_reference.mjs` obtiene
  referencias de TypeScript sin modificarlo ni ejecutar el loop.
- F3 verificada: `bash godot/tools/validate.sh` correcto; 6 scripts/1 escena,
  10.764 comparaciones de paridad sobre 4 semillas (incluye Unicode/emoji),
  tolerancia numérica 1e-9, 42 originales intactos.
  Informe `reports/f3-validation.log`. Esto valida datos, no gameplay ni píxeles.

- F4: economía y progresión puras portadas, incluidas curvas por composición
  viva, escudo, costes mixtos, efectos 0–10, bonus determinista, requisito de
  martillo +5, XP y las tres tecnologías vigentes. Sin cambios de balance.
- F4 verificada: editor/8 scripts/1 escena correctos; 11.302 comparaciones
  de paridad e invariantes (incluyen 128 tiradas de bonus), compras atómicas
  fallidas/exitosas y límites de nivel/recompra/requisito tecnológico.
  `npm test -- src/simulation/economyConfig.test.ts`: 4/4 pruebas puras.
  Informe `reports/f4-validation.log`; originales intactos; Vite HTTP 200.

- F5a: portadas reglas puras de tareas/afinidad, navegación continua, grafo
  de visibilidad, continuidad de evasión, idle, llamadas de entidades y
  posiciones de combate. Ordenación estable explícita donde TS la garantiza.
- F5b: seguimiento 10 m/s, retorno al rango 8 m/s, trabajo 6 m/s e idle
  3 m/s; tickets y llamadas de recursos, acciones transaccionales, drops
  físicos unitarios, recolección al inventario y XP. Cancelación y separación
  residual respetan tótem/trabajadores. Vista provisional del mundo y actores
  con interpolación entre ticks; contadores provisionales de inventario/XP.
- F5 verificación técnica: editor e inicialización estructural de 18 scripts
  y 1 escena sin errores, 11.766 comparaciones de datos/reglas/geométría
  contra TS, incluyendo cruces, rutas con obstáculos, idle/bordes, llamadas,
  reservas de combate y proyección de reclutamiento/despeje del tótem.
  Informe `reports/f5-work-validation.log`. Cero ticks de gameplay automatizados.
- F5 NO completada: revisión manual de navegación/recolección con 2/8
  minions pendiente; llamadas de combate y saqueo esperan integración F6;
  herramientas/vida/efectos aún no tienen su representación final.

- F6a: lógica de combate/caza/fuga, plazas, reservas de movimiento enemigo,
  patrullas, reaparición 60/30 s, botín/saqueo, alertas/efectos temporales,
  curación por hoguera, derrota y clima con reposición de madera/comida.
  Orden 20 Hz: clima → cooldowns → conflicto → trabajo → separación →
  hogueras → efectos. Los valores provienen del código vigente.
- F6 verificación técnica: importación/21 scripts/1 escena sin errores;
  paridad de estadísticas, daño y curación contra TS añadida a las reglas
  puras. Informe `reports/f6-validation.log`. No se ejecutó combate, clima
  ni gameplay automatizado; F6 no se declara completa.
- El feedback F6 se incorpora en F8d; sigue pendiente probar manualmente
  daño/retirada/respawn/lluvia y presentación.

- F7: comandos atómicos separados, población máxima 8, especializaciones,
  protección de proveedor de comida, 1 Mago exterior por 2 Brillo, Escudo,
  mejoras, tecnologías y debug. Interfaz nativa lateral y paneles excluyentes
  cerrados por defecto; arrastrar/comprar/equipar con tolerancia de 24 px.
  Preview libre; solo el spawn se proyecta a 15 m. No se dibuja anillo de
  reclutamiento. Arrastre del tótem sin retraso visual, flecha y ajustes zoom.
- F7 verificación: 23 scripts/1 escena importados/inicializados sin errores;
  12.670 comparaciones de paridad/reglas puras, incluidas cinco transacciones
  económicas contra TS (cap 8, 1 Mago, último proveedor, Escudo, coste mixto
  fallido). No se avanzó el loop de gameplay ni se automatizó UI.
  Informe `reports/f7-validation.log`. F7 no cerrada por playtest pendiente.

- F8a: repositorio nativo de tres slots JSON v17 bajo `user://saves`,
  escritura con temporal/backup, errores de I/O, metadatos, fase normalizada
  y borrado de un slot con confirmación desde UI. Prueba de ida/vuelta actual
  en directorio aislado; no se amplía la matriz histórica ni se importan
  automáticamente guardados del navegador.
- F8b: menú principal/tutorial/carga principal opacos; pausa/carga desde
  pausa translúcidas. Pausa congela simulación y bloquea controles del mapa.
  Carga enfoca inmediatamente el tótem; reinicio restaura nueva partida.
  Confirmaciones de borrar/reemplazar y pérdida de cambios sin guardar.
- F8c: reutilizados 13 iconos propios existentes sin alterar sus bytes,
  recibo `audit/ui_assets.json`. Contadores en el orden actual del juego.
  Auditoría ampliada a los 838 archivos versionados originales (incluidos
  arte, documentación y configuración), todos intactos.
- La importación detectó un uso incorrecto de `icon_max_width` como propiedad;
  corregido a constante de tema. Nueva validación completa posterior correcta:
  25 scripts/1 escena, 15.304 comparaciones y guardado actual, sin ticks de
  gameplay. Informe `reports/f8-menu-validation.log`. Sin validación visual.
- F9 preparación independiente: instalación de templates oficiales
  4.7.2 terminada y verificada con SHA256 publicado.

- F8d: feedback provisional de salud, escudos, herramientas/libro por rol,
  golpes/flashes/cruces de curación, cadáveres y loot, hogueras, alertas y
  sonido sintético, nubes/lluvia. Bandas de color 0–10 en tarjetas; los
  materiales de herramientas/unidades no se tiñen por nivel.
- F8d verificada técnicamente: scripts/importación/inicialización sin errores,
  pruebas de datos/reglas/guardado actuales correctas;
  `reports/f8-feedback-validation.log`. Sin capturas ni playtest automático.
  `../documents/GODOT_MANUAL_QA.md` enumera todas las revisiones aún pendientes.
- F9 templates: descarga oficial 4.7.2 validada con SHA256
  `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`;
  instalados Linux/Windows x86_64 y web, sin binarios añadidos a Git.

## Entrega técnica de F9 (sin cierre de paridad)

- `tools/export.sh`: validación previa, exportaciones reales Linux/Windows
  x86_64 y web sin threads; arranque del menú Linux en headless y salida
  inmediata, sin iniciar partida. Ejecución completa correcta.
- Formatos confirmados: ELF x86_64, PE32+ x86_64, WebAssembly.
- ZIP en `builds/TribesRevival-{linux,windows,web}-development.zip`, con
  instrucciones y licencia de Godot. `builds/manifest.json` registra revisión,
  hashes de fuentes, archivos y paquetes. Builds/cache/binarios fuera de Git.
- Informes: `reports/export-all.log`, `reports/export-{linux,windows,web}.log`,
  `reports/linux-startup.log`; no errores de scripts/referencias en esos runs.
- Última validación de datos: 15.325 comparaciones (paridad TS, invariantes
  puras y guardado actual), 4 mundos iniciales completos, compra posterior a
  lectura JSON y tiempos por fuente/herramienta. No se ejecutó gameplay.
- Revisión estática posterior incorporó los anillos de detección por minion
  y de curación de hogueras del original (ningún anillo de reclutamiento),
  leash visual de cazador, flash rojo y tono de alerta 880→620 Hz.
- QA y auditoría se mantienen en `../documents/GODOT_MANUAL_QA.md` y
  `../documents/GODOT_PARITY_AUDIT.md`; plan/status permanecen aquí por la
  ruta solicitada explícitamente para la migración.
- Original: 838 archivos intactos; 13 iconos copiados idénticos.
- Servidores de revisión: Babylon `http://localhost:5173/TribesRevival/`
  y build web Godot `http://localhost:8078/`, ambos con respuesta HTTP 200.
- Pendiente: abrir gráficamente Windows/Linux/web y completar controles, IA,
  combate, economía, menús, guardado y fluidez según QA. Los modelos/efectos
  son provisionales. No hay evidencia para declarar la migración completa.

## Corrección tras primera revisión manual: navegación de menús

- El usuario informó fallos en Tutorial, Guardar/Cargar y retorno desde pausa
  al menú principal. La validación anterior inicializaba el menú principal,
  pero no ejecutaba sus callbacks; no cubría este fallo.
- Reproducción headless aislada: emitir `Tutorial.pressed` provocaba
  `Object is locked and can't be freed` y `Attempted to free a locked object`
  en `game_menus.gd::_clear`. Se destruía el botón durante su propia señal,
  abortando la limpieza del menú y mezclando controles anteriores y nuevos.
- Corrección: retirar inmediatamente cada control del contenedor y liberar
  con `queue_free`, después de terminar la señal. Mismo tratamiento para
  navegación, confirmaciones y refresco de slots al guardar/eliminar.
- Regresión técnica: `tests/test_menu_callbacks.gd`, 87 comprobaciones de
  señales, destinos y liberación diferida en un árbol aislado sin escena de
  juego, renderizado, ticks ni acceso a guardados del usuario. Incluye las
  tres rutas reportadas, cancelar/confirmar y selección de slot.
- `bash tools/export.sh` correcto tras el arreglo: importación, 25 scripts/
  1 escena, callbacks, 15.325 comparaciones de datos y exportaciones Linux/
  Windows/web. Arranque headless del build Linux correcto. 838 originales y
  13 iconos sin cambios. Informe `reports/menu-fix-export-all.log`.
- El usuario confirmó después: «Ya funcionan perfetos», referido a Tutorial,
  Guardar/Cargar y retorno al menú principal. Evidencia funcional manual de
  esas rutas; no acredita cada slot/confirmación, plataforma ni el resto de F8.
- Revisión posterior: Esc en confirmaciones de slot saltaba al menú de origen
  en vez de volver a slots como «Cancelar»; desde el mensaje también omitía
  slots. Corregido conservando origen y modo. La regresión aislada falla con
  el comportamiento anterior y pasa con 101 comprobaciones tras el cambio.
  No guarda/carga/elimina archivos ni ejecuta gameplay. Esc manual pendiente.
- `tools/export.sh` volvió a pasar con el ajuste de Esc: 101 comprobaciones
  de callbacks, 15.325 de datos, importación y tres exports; arranque headless
  Linux correcto. Informe `reports/menu-escape-export-all.log`.
- F8/F9 continúan abiertas.

## Segunda evidencia manual: loop básico

- A la pregunta sobre iniciar partida, arrastrar/soltar el tótem junto a
  recursos, seguimiento de la tribu, recolección y aumento del inventario,
  el usuario respondió: «Todo funciona, si».
- Se acredita ese recorrido básico. No se extrapola a combate, balance,
  8 unidades, navegación extrema, compras ni sistemas operativos nativos;
  el mensaje no identifica la plataforma utilizada.

## Paridad del HUD de tecnologías

- Cotejados GDD (progresión/HUD) y `BabylonGame.ts::updateHud`: el HUD Godot
  omitía puntos disponibles, apertura al subir de nivel y cierre al gastar
  el último punto en un desbloqueo. Se incorporan esos comportamientos y
  el estado «Desbloqueada» sin modificar reglas ni datos de simulación.
- Al iniciar/cargar, se establece el nivel observado sin abrir el panel;
  alternar Tecnologías reinicia la selección del árbol como el original.
- Escudo separado arriba a la derecha y oculto hasta su tecnología; la
  columna izquierda conserva el orden vigente. Los costes no cambian.
- Importación, inicialización estructural, 101 comprobaciones de callbacks
  y 15.325 de datos correctas (`reports/hud-progression-validation.log`).
  No se automatiza la apariencia ni el loop; revisión manual del HUD pendiente.
- `tools/export.sh` completo correcto con el HUD actualizado: Linux/Windows/
  web regenerados; menú Linux inicia headless sin errores. Informe
  `reports/hud-progression-export-all.log`. Servidores originales y Godot
  confirmados activos (HTTP 200).

## Reclutamiento consecutivo: segunda pulsación ignorada

- Revisión manual del bloque reclutar/equipar/mejora/tecnología/combate:
  el usuario informa que la segunda pulsación de reclutar necesita varios
  intentos, y que «el resto funciona». Se acredita equipo/mejora/tecnología
  y combate con daño/botín con ese alcance; no se acredita llegar a 8 unidades
  ni una plataforma específica.
- Reproducido sin escena de juego, gráficos ni ticks: el callback de
  `main._input` consumía la suelta antes de llegar a `BaseButton`. Su estado
  interno seguía pulsado y omitía el siguiente `button_down`.
- Corregido dejando pasar la suelta tras terminar la colocación. El arrastre
  del tótem conserva su consumo de input; los botones de colocación solo
  tienen acción al pulsar, por lo que la suelta no repite una compra.
- `tests/test_placement_input.gd` hereda el `_input` real con colocación
  sustituida por un contador, sin mundo ni acceso a guardados. Despacha cuatro
  pares pulsar/soltar a un botón nativo: falla antes (solo dos comienzos) y
  pasa después (cuatro comienzos, cuatro finales, botón liberado siempre).
- Repetición manual pendiente para confirmar la experiencia completa.
- `tools/export.sh` correcto: originales/iconos intactos, importación,
  estructura, 101 comprobaciones de menú, input consecutivo, 15.325 de datos,
  tres exports y arranque headless Linux. Informe
  `reports/placement-release-export-all.log`.

## Confirmación manual de reclutamiento y plataforma

- El usuario responde «Ya funciona» al repetir el reclutamiento tras el
  arreglo. El defecto reportado queda corregido también por evidencia manual.
- Confirma «Ejecutable Linux» como versión usada para las pruebas reportadas:
  menús/guardado básico, inicio, arrastre, seguimiento, recolección, compras/
  equipo/mejora/tecnología, combate con daño/botín y repetición de reclutamiento.
- Linux acredita arranque gráfico y esos recorridos. No se extrapola a
  Windows/web, todos los slots o los casos extremos de QA aún pendientes.

## Feedback de disponibilidad del HUD

- Se cotejan los tooltips de `BabylonGame.ts` y el GDD: faltaban los motivos
  de bloqueo del último recolector, ausencia de objetivos y límites de
  tribu/clase/hogueras/escudos. Se presentan junto con coste y recursos
  faltantes calculados por la economía existente, sin cambiar disponibilidad
  ni transacciones. Se conservan las instrucciones de arrastre.
- Aspecto y tooltips manuales pendientes; no se automatiza validación visual.
- `tools/export.sh` completo correcto: importación, estructura, regresiones
  de menús/input, 15.325 comparaciones de datos, Linux/Windows/web y arranque
  headless Linux. Informe `reports/hud-reasons-export-all.log`.

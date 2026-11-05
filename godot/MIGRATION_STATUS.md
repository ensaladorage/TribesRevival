# Estado de migración a Godot

Actualizado: 2026-11-05. Rama: `migration/godot`. Objetivo completo: activo.

## Continuidad

- Última fase cerrada: F7 (compras/equipo, confirmación final de colores Linux).
  F0, F1, F2, F3, F4 y F7 completadas antes del refactor visual.
- Fase actual: F11 arquitectura visual editable; F10 paridad visual obligatoria.
- Próxima tarea ejecutable: terminar cotejo F10 de entorno/menús y regenerar
  exportaciones. F11 implementada a nivel estructural; revisión en editor y
  funcionamiento percibido pendientes de la etapa manual final.
- Decisión vigente: testeo manual al terminar la migración; no solicitar más
  recorridos intermedios ni centrarse en bugs menores. Windows manual aplazado.
- F5/F6: atasco diagnosticado con copia de solo lectura del slot 1 y corregido
  a nivel de navegación pura; repetición en partida y lag de combate pendientes
  de la etapa manual final. No se ha avanzado automáticamente ese guardado.
- Incidencias reportadas resueltas por confirmación manual en Linux:
  menús, segunda pulsación de reclutamiento, lag en los límites con 8 unidades
  y legibilidad de HP al cambiar zoom.
- Ejecución local: abrir `godot/project.godot` con el ejecutable local
  `godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2 confirmado).
- Comparación original: `npm run dev`, ruta `/TribesRevival/`.

## Tabla de progreso

| Fase | Estado |
|---|---|
| F0 auditoría | Completada: inventario de fuentes y 838 originales con hashes; verificados |
| F1 base | Completada: editor importa, 1 script y 1 escena válidos; arranque sin ticks |
| F2 controles | Completada: contratos cotejados, validación técnica y controles/cámara/bordes/Esc/velocidades confirmados en Linux |
| F3 determinismo/mundo | Completada: estados iniciales completos equivalentes en 4 semillas |
| F4 economía/progresión | Completada: tablas/XP/tecnologías/costes y bonuses verificados; integración de compras sigue en F7 |
| F5 IA/recolección | Usuario confirma seguimiento/recolección y bordes con 8 unidades; movimiento e interrupciones confirmados; bloqueo/lag reportado, retest final pendiente |
| F6 combate/clima | Usuario confirma combate, daño/botín, hoguera, lluvia y derrota/reinicio en Linux; huida/respawn pendientes |
| F7 compras/equipo | Compras/equipo, preview, Mago único y Escudo +1 HP sin repetición confirmados en Linux; distinción visual del Mago confirmada («si, colores correctos»); cierre F7 previo al refactor |
| F8 UI/guardado | Menús/HP y persistencia de los tres slots tras reabrir validados en Linux; borrado/cancelación correctos; resto de revisión UI pendiente |
| F9 integración/exportación | Tres builds exportados; recorridos Linux confirmados; Windows manual aplazado por usuario, QA Linux restante pendiente |

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

## Lag al alcanzar el borde del mundo

- El usuario precisa que el lag aparece **solo cerca del límite del mundo**,
  al mover el tótem por el borde de la pantalla en Linux.
- Las posiciones de formación pueden quedar fuera de 2–158 m. El planificador
  generaba y recorría todo el grafo antes de concluir que un destino así es
  inválido. Una ruta no puede terminar en un punto rechazado por `is_allowed`.
- Cambio acotado en `navigation.gd::plan_route`: rechazar el destino inválido
  antes de construir el grafo. No se cambian destinos, velocidades, límites,
  formación, predicción, cadencias ni reglas de movimiento.
- Reproducción con función pura, sin escena/ticks: inicio (80,80), objetivo
  (162,80), cinco obstáculos del mundo inicial. Antes: 19.681 llamadas al
  predicado, ~31,676 ms; después: 1 llamada, ~0,002 ms; ambas devuelven `[]`.
  Son tiempos de una función aislada, no FPS ni medición de una partida.
  Informes locales `reports/navigation-{baseline,candidate}.log`.
- Referencias de TypeScript ampliadas con nueve objetivos dentro/fuera/en
  el límite y obstáculos reales. Guard de complejidad comprobado por conteo
  de llamadas, sin umbral temporal. Validación correcta: 15.342 comparaciones,
  101 de menús, cuatro pulsaciones de input, estructura e integridad original.
  Informe `reports/border-route-validation.log`.
- Repetición manual en Linux pendiente: mismo recorrido por el borde con
  2 y 8 unidades y soltar para reagrupar. F2 sigue abierta hasta esa evidencia.
- `tools/export.sh` completo correcto después del cambio: importación,
  estructura, regresiones permitidas, datos, tres exports y arranque headless
  Linux. Informe `reports/border-route-export-all.log`. Builds regenerados.
- El usuario responde «Ahora esta perfecto» a repetir el recorrido cerca
  del límite con 8 unidades en Linux. La incidencia de lag queda cerrada por
  evidencia manual. Esto no acredita por extensión cada control de F2.

## Supervivencia y legibilidad de HP

- Al comprobar hoguera/curación, lluvia y derrota → Reiniciar en Linux,
  el usuario confirma que funciona todo bien. Se registra ese recorrido de F6.
- Reporta que la vida de los minions es demasiado pequeña. El indicador
  provisional `Label3D` tenía 30 px de fuente a 0,006 m/px: aproximadamente
  3,6 px en el zoom inicial a 720p, y menos al alejarse.
- Presentación actualizada a fuente de 20 px con escala compensada según
  altura ortográfica/viewport, manteniendo tamaño de pantalla al cambiar zoom.
  Contorno oscuro, verde aliado/rojo enemigo y margen sobre el cuerpo que se
  conserva al alejar la cámara. Sigue leyendo health/maxHealth del estado;
  no cambian reglas de vida/daño/curación ni guardados.
- No se ejecutan pruebas visuales automatizadas. Importación/inicialización
  estructural y revisión manual posterior son evidencias distintas.
- `tools/export.sh` correcto: 25 scripts/1 escena, 101 comprobaciones de
  menú, input de cuatro pulsaciones, 15.342 comparaciones de datos, integridad
  de 838 originales/13 iconos, tres exports y menú Linux headless. Informe
  `reports/health-legibility-export-all.log`. Revisión visual de HP pendiente.
- El usuario no dispone de Windows y pide centrarse en Linux por ahora.
  Prueba Windows aplazada expresamente; el export sigue disponible y no se
  declara probado en ese sistema. No reabrir esta petición durante QA Linux.
- Tras reabrir el ejecutable, a la comprobación de legibilidad con cámara
  cerca/alejada y vida dañada/curada, responde «Si ya se ven bien».
  Legibilidad de HP confirmada manualmente en Linux; incidencia cerrada.
  No se extrapola a otras plataformas ni al caso específico del escudo.

## Cierre de controles F2 y guardado actual en Linux

- A la comprobación de Esc para pausar/reanudar y teclas 1/2/3 para cambiar
  velocidad, el usuario responde «si». Sumado a cámara/zoom, arrastre y
  bordes con ocho unidades ya revisados, cumple el criterio manual de F2.
- Validación técnica de cierre correcta: importación, 25 scripts/1 escena,
  101 comprobaciones de menús, cuatro pulsaciones de input y 15.342 de datos;
  838 originales y 13 iconos intactos. Informe
  `reports/f2-manual-closure-validation.log`. No se automatizó gameplay.
- El usuario confirma «si, funciona todo» al guardar en los tres slots,
  cerrar/reabrir, cargar desde principal/pausa, cancelar borrado y confirmar
  eliminación de solo el slot elegido. Persistencia vigente acreditada
  manualmente en Linux; no se amplía a migraciones de versiones antiguas.
- No se modificó código ni se regeneraron builds para registrar estas
  confirmaciones. El build técnico vigente sigue siendo `8ca52ad`.
- El usuario confirma además «si todo correcto» a preview libre lejos del
  tótem, spawn próximo al soltar y cancelación de equipo sobre terreno/clase
  incompatible sin gasto. Interacción de colocación acreditada en Linux.
  La distancia exacta de 15 m se acredita con regla pura comparada con TS;
  la confirmación manual acredita el comportamiento percibido.

## Identificación visual de clases

- El usuario confirma Mago único, Escudo +1 HP y rechazo de un segundo
  Escudo sin gasto, pero informa que no distingue al Mago del Recolector.
- La revisión estática muestra que Godot usaba una paleta provisional:
  Mago cian pálido y Recolector crema, distinta de `BabylonGame.unitRoleColor`.
  Se restaura la paleta de las seis clases activas del original: Mago violeta
  `#a276ff`, Recolector dorado `#f1d27a`, y colores originales del resto.
- La vista ya sustituye el cuerpo/herramienta cuando cambia `unit.role` y
  restaura el material del rol después de los efectos. No se atribuye la
  incidencia a un rol lógico sin actualizar: falta evidencia de ese fallo.
- La previsualización de Mago/Recolector usa la misma paleta que su unidad;
  los demás objetos conservan su placeholder. Sin cambios de reglas/guardados.
- Verificación estructural y de datos correcta; distinción visual pendiente
  de repetición manual. No se añaden tests automatizados de color ni capturas.
- `tools/export.sh` correcto: importación, 25 scripts/1 escena, 101 comprobaciones
  de menús, cuatro pulsaciones de input, 15.342 comparaciones de datos,
  integridad de originales/iconos, tres exports y arranque headless Linux.
  Informe `reports/role-colors-export-all.log`; builds actualizados.

## Objetivo ampliado y bloqueo del slot 1

- El usuario confirma colores de Mago/Recolector. Se registra cierre F7 con
  controles económicos, preview, cancelación y equipo ya confirmados en Linux.
- Objetivo actualizado: F11 prioritaria para escenas realmente editables y
  F10 paridad visual obligatoria. Testeo manual concentrado al final.
- Slot 1 leído sin modificar; copia diagnóstica completa solo en reports/
  ignorado. Un Leñador collect-drop está bloqueado por Guardián idle; la salida
  preferida del Guardián está a su vez ocupada por una Artesana. No son reservas
  duplicadas. La hipótesis inicial de radio de trabajo se descartó al comparar
  la función pura con TypeScript; no se cambió ese radio.
- El idle puede elegir una dirección lateral libre cuando el solicitante está
  bloqueado. La predicción de ese solicitante usa movimiento real reservado,
  manteniendo comprobación de trayectorias del tick. Flag efímero derivado de
  navegación, sin campos nuevos de guardado ni cambios de velocidad/estadísticas.
- Rutas a metas ocupadas se descartan tras comprobar escape directo: mismo
  resultado [] y menos trabajo. Proyección estática de segmentos equivalente
  al original en 256 referencias deterministas. Caso aislado: ~35,21 ms y
  10.734 llamadas al predicado antes, ~0,017 ms y una llamada después.
  Son medidas de función, no FPS ni un benchmark de combate jugado.
- Validación: validate.sh correcto; 15.669 comparaciones puras, 101 de callbacks
  de menú, cuatro pulsaciones de input, importación/25 scripts/1 escena;
  838 fuentes originales y 13 iconos intactos. Informe
  reports/blocked-yield-validation.log. Fixture mínima de geometría incluida;
  no se guardan datos completos del jugador ni se ejecuta el loop.
- Efecto en la partida del slot y lag de combate aún no validados manualmente.

## F11a — HUD y menús editables

- HUD.tscn instancia paneles independientes de recursos, reclutamiento,
  equipo, tecnologías y mejoras. Los controles estáticos ya no se construyen
  en GDScript. Metadata semántica conecta señales; disponibilidad y precios
  siguen consultando los mismos módulos de reglas.
- MainMenu/PauseMenu/TutorialMenu/DefeatMenu/ConfirmationMenu/SlotsMenu/
  FeedbackMenu y SlotRow son escenas Control editables. Filas de slots se
  instancian como contenido dinámico. Navegación libera la página diferida
  tras separarla del árbol, preservando callbacks seguros.
- Overlay.tscn contiene progreso y debug; main solo conecta acciones/sliders.
  TribesTheme.tres centraliza fuente monoespaciada, paleta y estilos/variantes
  de nivel. Primer cotejo F10 con src/styles.css: fondos #2b2538/#231e2d,
  bordes #b2b2a0, texto #f4e8c1 y estados hover/pressed/disabled.
- validate.sh correcto: 25 scripts/17 escenas, 101 comprobaciones aisladas
  de navegación de menús, cuatro pulsaciones y 15.669 comparaciones de datos;
  fuentes/iconos originales intactos. reports/editable-ui-validation.log.
  Sin frames de gameplay ni pruebas visuales automáticas. Aspecto/interacción
  completa del nuevo HUD pendiente de la etapa final; F11 global continúa.

## F11b — Actores y mundo como escenas

- Minion.tscn usa AnimatedSprite3D y SpriteFrames editables con animaciones
  idle/move/work/attack de un frame provisional. Variantes de las seis clases,
  bárbaro y conejo heredan la base, sin duplicar lógica. Reutilizan iconos ya
  existentes; no se genera arte ni se afirma disponer de sprites definitivos.
- actor_view.gd solo presenta estado/feedback y selección. Navegación, IA,
  economía, progresión y guardados conservan sus módulos e interfaces.
  Picking usa la caja Selection/Shape de la escena y conserva fallback de 24 px.
- Tree/Rock/Bush/Twigs/Spark, cinco drops, hoguera, cadáveres, biomas,
  decoración y nubes son PackedScene; WorldView.tscn expone su catálogo.
  world_element.gd permite asignar appearance_override (escena Sprite3D,
  AnimatedSprite3D o modelo) y editar escala/desplazamiento en inspector.
- Generación procedural sigue calculando los mismos datos/posiciones; la vista
  instancia escenas. Ya no construye meshes del mundo o cuerpos por código.
  Se conservan cadáveres geométricos provisionales, sin crear el sprite final
  pendiente del usuario. Flecha y previews de colocación también son escenas.
- Guía EDITING_VISUALS.md explica puntos editables y nombres/metadata que
  conectan los adaptadores. No se atribuye validación en el editor no realizada.

## F10 — Primer cotejo visual por fuentes

- HUD: iconos originales, tarjetas 56×56, recursos 30 px/cifras 20 px,
  separación/posición y costes variables en cuadrados; fuente monoespaciada y
  paleta/estados del CSS concentrados en Theme. CostSquare y ResourceCost
  editables, instanciación dinámica solo por cantidad de recursos.
- HP: bolitas de 9 px para aliados y 7 px enemigos a tamaño de pantalla,
  contorno oscuro/colores del CSS; HealthPip/HealthPips y variantes de Theme.
  Nueva presentación tras el refactor pendiente de revisión final, aunque el
  indicador anterior de texto sí había sido aprobado manualmente.
- Mundo: paletas originales de biomas, drops, troncos/follaje, piedras,
  flores/hogueras restauradas en materiales de escenas. Árbol/arbusto/rocas
  retoman dimensiones/piezas originales. Brillo conserva aproximación de
  cristal/halo, no se afirma equivalencia geométrica exacta.
- Entorno editable en main.tscn: fondo original (0.09,0.075,0.12), materiales
  mates sin especular, exposición 1 y tonemapping lineal; aproximación de la
  hemisférica 0.9 mediante ambiente blanco 0.45 + luz superior blanca 0.45,
  sin sombras proyectadas. Los motores difieren en sus modelos de iluminación:
  esto es un cotejo de configuración, no equivalencia fotométrica medida.
- Cámara conserva ortográfica, 45°/35°, altura 72×zoom, distancia 120 y límites
  vigentes. Menús opacos #777 y pausa (15,12,20)/72% según CSS original.
- Validación técnica: 29 scripts/70 escenas, 101 callbacks aislados de menú,
  cuatro pulsaciones y 15.669 comparaciones de datos. 838 originales y 13 iconos
  intactos. reports/editable-hp-validation.log. Sin gameplay/visual automatizado.
- Pendientes F10: revisión perceptual/capturas comparables si se obtienen;
  gradientes/sombras CSS de menú, layout detallado de tutorial/slots, efectos
  animados y sprites definitivos. Diferencias conocidas quedan explícitas;
  no declarar F10 ni F11 completamente validadas por importar escenas.

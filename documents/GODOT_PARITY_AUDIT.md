# Auditoría de migración y aceptación — 2026-11-05

Las rutas de implementación y de informes son relativas a `godot/`, salvo
las referencias a `src/`, `index.html` y `documents/` del original.

Esta auditoría distingue código equivalente, comprobaciones técnicas,
confirmaciones manuales y pendientes aceptados. Una exportación o un número de
comparaciones no demuestra por sí solo cada recorrido de una partida.

## Decisiones y aceptación actuales

El usuario confirma en Linux apertura, colores/aspecto general correctos y
capacidad de edición satisfactoria en Godot. Confirma además que ya no hay
lag ni minions bloqueados en el caso reportado del slot 1/combate. Los problemas
restantes de HUD/UI y de IA los solucionará más adelante, por decisión explícita.
No son trabajo pendiente autorizado para continuar corrigiendo en esta etapa.
No se afirma que esos defectos estén resueltos ni que no existan otros bugs.

Windows manual está aplazado expresamente: no dispone de Windows y pide
centrarse en Linux. El objetivo mantiene el ejecutable/ZIP de Windows y la
verificación técnica, sin atribuir una ejecución real en ese sistema.

## Requisitos del objetivo y fuentes de evidencia

| Requisito | Implementación y evidencia que lo respalda | Límite de la evidencia |
|---|---|---|
| Rama exclusiva y original intacto | `migration/godot`; `audit/source_inventory.json` y `tools/verify_original.py` comprueban 838 archivos originales y 13 iconos reutilizados | Archivos nuevos/ediciones concurrentes del usuario se conservan fuera de los commits del agente |
| Godot 4, GDScript, Compatibility | `project.godot`, motor local 4.7.2, carga de los 33 scripts y 72 escenas con el editor headless | No presupone soporte gráfico idéntico en cada equipo |
| Análisis del código/GDD y dependencias | Inventario de módulos en MIGRATION_PLAN.md, índice documental/GDD v0.6.0 y contratos de TECHNICAL_DESIGN.md consultados | Migrar el original implementado no implica añadir su diseño futuro |
| Arquitectura/escena principal y separación | `scenes/main.tscn`; `game_session.gd`/simulación son RefCounted y datos, vistas/UI instancian escenas y emiten acciones; 20 Hz/máximo cuatro ticks e interpolación | No se ejecuta el loop automáticamente para verificarlo |
| Estado, semilla, mundo, regiones/biomas existentes | `game_state.gd`, `seeded_random.gd`, `world_catalog.gd`; comparación del estado inicial completo en cuatro semillas (Unicode incluido), PRNG y datos | No hay regiones bloqueadas/cuevas/jefes en el original; no se inventan |
| Cámara/control/tótem/seguimiento | `isometric_camera.gd`, `main.gd`, `minion_movement.gd`; contratos ortográficos/zoom/velocidades cotejados, proyección/geometría pura; cámara, bordes con ocho unidades, Esc y 1/2/3 confirmados en Linux | La revisión no cubre cada periférico/resolución |
| Roles, IA, navegación, trabajo y recolección | `minion_idle.gd`, `navigation.gd`, `minion_awareness.gd`, `work_system.gd`, `combat_positions.gd`; fixtures de reglas/selección/cesión/rutas; seguimiento/recolección/interrupción y corrección del atasco confirmados | Otros problemas de IA comunicados quedan aplazados por el usuario; no se promete comportamiento perfecto |
| Economía, reclutamiento, transformaciones y equipo | `economy.gd`, `commands.gd`; costes/límites/afinidades y compras atómicas cotejadas; cap 8, preview/cancelación, Mago único y Escudo +1 HP/sin repetición confirmados | No se ha recorrido manualmente cada composición posible |
| Herramientas/XP/tecnologías | `progression.gd`, `economy.gd`; tablas 0–10, bonus determinista, requisitos/XP/tres tecnologías comparados con TS; compra/mejora/tecnología confirmadas | QA exhaustiva de todos los niveles sigue recomendada |
| Combate, salud, enemigos, fauna, botín | `conflict_system.gd`, `combat_rules.gd`, `survival_system.gd`; estadísticas/daño/curación puros cotejados y revisión del port de respawns/patrullas/loot; combate/daño/botín/derrota y desaparición del lag confirmados | No se afirma haber jugado automáticamente huida/respawn; seguimiento de IA aplazado |
| Hogueras y clima | `weather_system.gd`/`survival_system.gd` portan orden, intervalos/fases/reposición y curación del original; usuario confirma lluvia/hoguera/curación | Casos extremos de expiración/distancia no se dan por ensayados manualmente |
| HUD, menús, tutorial, debug y sonido | Escenas UI, adaptadores de señales, iconos originales; 101 comprobaciones aisladas de callbacks/Esc y cuatro de despacho de pulsar/soltar, sin mundo; rutas funcionales confirmadas | Defectos HUD/UI restantes aplazados por el usuario |
| Guardado actual y compatibilidad | JSON v17 en `user://`, tres slots; ida/vuelta en archivos aislados; tres slots tras reabrir, principal/pausa y borrado/cancelación confirmados | No se importan automáticamente datos de localStorage; matriz de versiones antiguas aplazada |
| Integración y ejecutables descargables | `export_presets.cfg`, templates oficiales 4.7.2 y recibo; `tools/export.sh` produce Linux ELF x86_64 y Windows PE x86_64, ZIP con licencias y manifiesto SHA256; menú Linux inicializa sin errores | Windows no se ha ejecutado manualmente; los ZIP son de desarrollo |
| Web secundaria | HTML/JS/PCK/WASM sin threads, servidor HTTP y capturas reales del menú | No acredita gameplay web completo |
| Pruebas, errores de scripts/escenas/referencias | `tools/validate.sh` verifica hashes, importación, inicialización y logs, callbacks/input aislados y 15.669 comparaciones de datos/reglas/guardado | El total incluye muchos campos de estado inicial: no equivale a 15.669 escenarios jugados |
| Continuidad y commits por subhitos | MIGRATION_PLAN.md, MIGRATION_STATUS.md, commits locales; sin push; ambos servidores se mantienen disponibles | Los ajustes concurrentes del usuario no se incorporan automáticamente a los commits |
| Sin dependencias/arte definitivo innecesarios | Godot/GDScript; iconos existentes como sprites provisionales; Liberation Mono incluida con OFL; sin proveedores de pago ni servicios de juego remotos | Las animaciones de personaje son de un frame provisional, sustituibles en editor |

## Paridad visual obligatoria: seis áreas

| Área | Comprobación posible realizada | Diferencias/validación pendiente |
|---|---|---|
| Paleta: terreno, biomas, recursos, actores y enemigos | Colores cotejados con BabylonGame; materiales/variantes en escenas; usuario confirma colores y aspecto general Linux | Sprites provisionales tintados representan personajes 2D según la nueva dirección artística; no son los antiguos cuerpos geométricos |
| Materiales/luz/sombras/exposición/tonemapping | Entorno en main.tscn, materiales mates sin especular; fondo original, exposición 1/lineal; aproximación hemisférica mediante ambiente/luz superior; sombra plana del tótem | Modelos de iluminación distintos; no hay equivalencia fotométrica medida |
| Cámara ortográfica, ángulos, zoom y escala | Código original y isometric_camera.gd cotejados; 45°/35°, altura 72×zoom/distancia 120 y controles confirmados | No se compararon todos los tamaños de ventana mediante capturas |
| HUD: posición, tamaño, fuente, colores, iconos y distribución | CSS/index originales cotejados; tarjetas 56×56, recursos, costes, tipografía/Theme y escenas | El usuario acepta posponer los defectos restantes de HUD/UI |
| Menús/botones/barras/indicadores | Capturas reales comparables 1280×720 del menú sin pulsar Jugar: reports/f10-babylon-main.jpg y f10-godot-main-final.jpg; fuente, gradiente/espaciado ajustados | Salir nativo añade altura; sombra SVG aproximada y tipografía dependiente de plataforma; no se atribuye esa captura a todo el HUD |
| Efectos, transparencias y animaciones | Nubes/lluvia, curación, alertas, lunge, HP y previews cotejados por código; escenas/scripts de presentación usan edad/duración del estado | Sin playtest automático de efectos; animaciones/sprites definitivos y pulido posterior quedan al editor |

## Arquitectura visual editable: criterios de aceptación

| Requisito explícito | Fuente actual/evidencia |
|---|---|
| Abrir CharactersBase.tscn y sustituir sprite sin GDScript | Body/Sprite es AnimatedSprite3D con SpriteFrames; inspector permite cambiar imágenes/frames/escala; seis clases y enemigos heredan la base; usuario confirma capacidad de edición |
| IA/navegación/combate/estadísticas independientes de assets | Scripts de simulación solo poseen datos; actor_view presenta estado y selección, sin gobernar reglas; guardado no incorpora nodos |
| Variantes sin duplicar lógica | Gatherer/Lumberjack/Hunter/Guardian/Artisan/Mage/Barbarian/Rabbit instancian CharactersBase.tscn y comparten el adaptador |
| Conservar selección/colisiones/navegación | Selection/Shape y fallback de 24 px; radios lógicos conservados y pruebas geométricas puras; no confundir escala visual con radios del estado |
| Árbol, roca, arbusto, drop e interactivos editables | Tree/Rock/Bush/Twigs/Spark/Drop/Campfire/cuerpos, biomas/decoración/nube son escenas; Drop es base compartida de sus cinco variantes |
| Generación procedural instancia PackedScene | world_catalog produce datos; WorldView.tscn expone catálogos y world_view._spawn instancia escenas |
| Sprite3D, AnimatedSprite3D o modelos intercambiables | world_element @export appearance_override/visual_scale/visual_offset y @tool; la geometría Default se oculta sin borrarla; usuario confirma edición satisfactoria |
| HUD.tscn y paneles/menús Control independientes | Recursos/reclutamiento/equipo/tecnologías/mejoras y páginas/fila de slot/overlay tienen sus escenas; no se construyen controles estáticos en scripts |
| Theme central para colores/fuentes/estilos | TribesTheme.tres con variantes de panel/botón/nivel/coste/vida y fondos; controles dinámicos se instancian desde plantillas editables |
| Reorganizar jerarquías desde el editor | Referencias de nodos serializadas/asignables en HUD/Menus; metadata semántica recursiva; copia reparentada/renombrada y serializada conserva nueve referencias y bindings (reports/authoring-references.log), sin input/render/gameplay |
| Interfaces y sistemas existentes conservados | Señales semánticas originales conservadas, consumidores adaptados; callbacks/input/datos/guardado pasan; usuario confirma que no persisten los bloqueos graves |
| No eliminar un sistema sin sustituto validado | Subhitos con importación/referencias antes de commit; sustitutos ahora aceptados en editor por el usuario; historial Git conserva implementaciones anteriores |

## Alcance preservado y seguimiento

- No se añaden multijugador, servicios remotos de juego ni una victoria.
- Cuevas/campamentos/jefes/llaves/regiones bloqueadas y Pícaro/Paladín no se
  implementan inventando requisitos: no existen en la base original migrada.
- Compatibilidad de guardados antiguos y ejecución manual Windows permanecen
  aplazadas por las decisiones ya registradas.
- No se genera el sprite definitivo de cadáver pendiente del usuario.
- La lista de QA no ensayada se conserva en GODOT_MANUAL_QA.md; no se convierte
  en una afirmación de éxito. Las pruebas visuales o del loop no se automatizan.
- Los pendientes aceptados de IA y HUD/UI pasan a trabajo posterior del usuario.
  El cierre de la migración no es una declaración de ausencia de defectos.

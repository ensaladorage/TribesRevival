# Migración de Tribes Revival a Godot 4

## Contrato y alcance

Rama exclusiva `migration/godot`. Proyecto autónomo en esta carpeta: Godot 4,
GDScript, Compatibility, primero Windows/Linux y exportación web secundaria.
El original (`src/`, `public/`, configuración Vite y dependencias) se conserva.
No hacer push sin nueva instrucción. Se permiten commits locales por fase.

Fuentes: `../documents/README_DOCUMENTACION.md`, GDD v0.6.0, diseño técnico,
estado, roadmap y QA; el código concreta los sistemas realmente existentes.
El objetivo de paridad es el original implementado, no completar diseño futuro.
Las discrepancias entre GDD y código se registran antes de fijar reglas nuevas.

## Inventario de sistemas y dependencias

| Original | Responsabilidad | Dependencias / destino Godot |
|---|---|---|
| `simulation/types.ts`, `survivalTypes.ts` | Estado v17, entidades, tareas, inventario, efectos | Datos sin nodos; `scripts/simulation/` |
| `seededRandom.ts` | Hash FNV-1a UTF-16 y Mulberry32 | Base de generación, loot, idle, clima y bonuses |
| `economyConfig.ts` | Costes por población viva, límites, herramientas 0–10 | Datos, PRNG; reglas puras compartidas con UI |
| `technologyConfig.ts`, `progression.ts` | Nivel inicial 0, XP, tres tecnologías | Economía, acciones semánticas, UI |
| `survivalCatalog.ts` | Biomas circulares, nodos, ramitas, decoración, 5 bárbaros y 6 conejos | PRNG, constantes de combate, estado inicial |
| `createInitialState.ts` | Tótem (80,80), 2 minions, especialista aleatorio, inventario vacío | Catálogo, PRNG, progresión, clima |
| `minionIdle.ts`, `worldView.ts` | Paseos y retorno al radio real | PRNG, geometría, orientación fija |
| `minionNavigation.ts` | Rutas, predicción, separación, cesión y continuidad | Geometría pura, reservas por tick, navegación persistible |
| `minionCombatPositions.ts` | Plazas melee/cazador y espera | Navegación, actores y límites |
| `minionAwareness.ts` | Llamadas silenciosas a enemigos/animales | Roles, disponibilidad, reservas, prioridad enemigo |
| `survivalRules.ts` | Afinidades, selección/tickets, carga, drops unitarios | Economía y tareas |
| `survivalCombat.ts` | Estadísticas, daño, curación | Espada, roles y capacidades |
| `weatherSystem.ts` | Nubes y reposición de recursos por lluvia | PRNG, biomas/nodos |
| `stepSimulation.ts` | Acciones, formación, trabajo, combate, fauna, saqueo, hogueras, derrota | Todos los módulos anteriores; fijo 20 Hz, máximo 4 ticks/frame |
| `input/actions.ts` | Cola y órdenes semánticas | Input Godot → simulación; no leer meshes desde lógica |
| `engine/BabylonGame.ts` | Cámara, picking, presentación, menús, HUD, sonido, opciones debug | `Node3D`, `Camera3D`, `Control`, audio; vistas del estado |
| `persistence/saveGame.ts` | 3 slots locales y metadatos, borrado individual | JSON bajo `user://`, confirmación desde UI |
| `main.ts`, `styles.css`, `index.html` | Arranque/DOM/estilo | Escena principal y UI nativa |

El manifiesto `audit/source_inventory.json` registra todos los archivos fuente,
hashes e imports en el punto de partida para comprobar que el original no cambia.

No existen todavía en el código regiones bloqueadas, campamentos, jefes,
llaves, cuevas ni Pícaro/Paladín. No implementarlos inventando costes o balance.
`great-fire` es un identificador histórico del catálogo, no una victoria.
Mago exterior: código vigente 2 Brillo, límite 1. El GDD conserva una curva
más larga: no extenderla sin decisión de diseño. Piedra II no se genera.
La compatibilidad de guardados antiguos sigue diferida; conservar v17 y el
flujo actual sin abrir una matriz histórica nueva. No prometer importación
automática de localStorage del navegador en un ejecutable de escritorio.

## Fases y criterios de aceptación

Cada fase registra implementación y evidencia por separado. Las fases con
playtest pendiente no se declaran completas. Una revisión manual pendiente
permite continuar con módulos independientes según la autorización del usuario.

| Fase | Trabajo y dependencias | Criterios para cierre |
|---|---|---|
| F0 | Auditar fuentes y dependencias, fijar plan y continuidad | Inventario completo del código fuente y mapa anterior; originales intactos; rama correcta |
| F1 | Proyecto, escena mínima, luz/terreno/tótem provisional, herramientas de validación | Editor headless importa sin errores, scripts y escenas cargan e instancian sin ejecutar frames; renderer Compatibility |
| F2 | Cámara 45°/35°, zoom, picking, arrastre, pausa/velocidad/debug; depende F1 | Scripts/referencias válidos; cotejo de contratos con original; usuario verifica controles, cámara y bordes manualmente |
| F3 | PRNG, estado inicial y generación procedural; depende F1 | Vectores exactos del PRNG y datos iniciales cotejados con TS; mismas semillas reproducibles; biomas/recursos/fauna/decoración equivalentes |
| F4 | Economía, progresión, herramientas, costes; depende F3 base | Pruebas puras de tablas y límites, costes atómicos, tecnologías/XP, sin introducir balance nuevo |
| F5 | Minions, seguimiento, navegación, idle, roles, tickets y recolección; depende F2/F3/F4 | Scripts válidos y reglas puras relevantes; playtest manual de formación/idle/recolección/llamadas/evitación con 2 y 8 unidades |
| F6 | Combate, fauna, respawn, cuerpos/loot, hogueras, curación, clima; depende F5 | Constantes y reglas conservadas; playtest manual de enfrentamientos, huida, lluvia, derrota/reinicio |
| F7 | Reclutamiento, transformaciones, escudo, mejoras; depende F4/F5/F6 | Límites/afinidad/costes vigentes, compra atómica; interacción y preview libres comprobados manualmente |
| F8 | HUD/menús/tutorial/sonido/debug y guardado local; depende F2–F7 | Tres slots con ida/vuelta actual, borrar solo tras confirmar; main/tutorial/load opacos, pausa translúcida, carga enfoca tótem; revisión manual UI |
| F9 | Integración y exportación Windows/Linux; secundaria web | Exportaciones reales generadas con templates compatibles; Linux abre; Windows probado manualmente o limitación explícita que impide cierre; paridad completa y validación manual resuelta |

En F3 se adelanta generación porque la IA necesita el mundo real. F4 puede
avanzar mientras F2 espera revisión manual. Los subhitos implementados no
equivalen al cierre de una fase mayor.

## Validación y commits

`bash godot/tools/validate.sh` importa con el editor headless, carga scripts y
escenas sin frames, comprueba callbacks/lifetimes de menús y despacho de
pulsar/soltar en árboles aislados sin mundo ni simulación,
y ejecuta tests de datos/reglas puras disponibles.
No ejecutar automatización visual, capturas, simulaciones largas ni tests del
loop de gameplay. Las comprobaciones manuales corresponden al usuario.
Godot puede imprimir errores de GDScript y devolver 0: el wrapper comprueba
también los logs. Informes regenerables en `reports/`, excluidos de Git.

En cada subhito: revisar diff → validar → registrar evidencia/pendientes →
commit local con archivos explícitos. No incluir el binario local de Godot,
cachés, builds, `node_modules` ni archivos ajenos. Mantener Vite disponible
para comparar manualmente; no modificar el original para servir Godot.

QA y auditoría de la migración viven en `../documents/GODOT_MANUAL_QA.md` y
`../documents/GODOT_PARITY_AUDIT.md`. Plan y estado se conservan en las rutas
`godot/MIGRATION_PLAN.md` y `godot/MIGRATION_STATUS.md` solicitadas por el usuario.

## Referencias técnicas

- [CLI headless, importación y exportación](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Camera3D y proyección de rayos](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)

---
name: tribes-revival-development
description: >
  Guiar todas las tareas de desarrollo de Tribes Revival en Godot y GDScript,
  durante la migración y después: mecánicas, IA, escenas, pixel art en 3D,
  interfaces, persistencia, depuración y pruebas. Mantener la simulación
  independiente y la presentación editable desde Godot. Exclusiva de este
  repositorio; no aplicar a otros juegos ni al desarrollo del original Babylon.
---

# Desarrollo de Tribes Revival

La prioridad es que el desarrollador pueda sustituir y ajustar escenas, sprites,
mapas, interfaces y animaciones desde el editor sin reprogramar el comportamiento.
Responder en español. Aplicar esta guía al trabajo Godot solicitado, sin ampliar
su alcance ni reescribir automáticamente código que incumpla estas convenciones.

## Fuentes y contexto

Las rutas de proyecto indicadas aquí son relativas a la raíz del repositorio,
que contiene `AGENTS.md`, `documents/` y `godot/project.godot`; `res://` parte de
`godot/`. Consultar `AGENTS.md`, `documents/README_DOCUMENTACION.md` y siempre las
secciones pertinentes de `documents/GDD_Tribes_Revival_v0.6.0.md` para las mecánicas.
Consultar `documents/TECHNICAL_DESIGN.md` para contratos y, según la tarea,
roadmap, estado y QA definidos en ese índice.

El diseño técnico conserva información del original Babylon/TypeScript. Para
trabajar sobre Godot, contrastarla con `godot/README.md`, `godot/MIGRATION_PLAN.md`,
`godot/MIGRATION_STATUS.md` y el código actual. Consultar `godot/DESIGN_CHANGES.md`
para decisiones posteriores a la migración. No resolver una contradicción de
mecánicas inventando una regla: pedir aclaración cuando afecte al comportamiento
o al guardado. Mantener las decisiones pendientes del GDD como pendientes.

La dirección visual solicitada para esta skill es pixel art 2D dentro de un mundo
3D isométrico; las alternativas históricas de arte del GDD no obligan a sustituir
esta dirección. Esto no autoriza una conversión masiva del arte existente.

Antes de editar, leer [el mapa de contratos locales](references/project-map.md)
y los archivos afectados. Para presentación, consultar además
`godot/EDITING_VISUALS.md`. Usar las skills Godot instaladas cuando aporten detalles
del área concreta; sus ejemplos genéricos no sustituyen las reglas del juego.

## Separación entre simulación y presentación

- La simulación posee IA, estados, movimiento, navegación, economía, combate,
  salud, inventario, reclutamiento, transformaciones, mejoras, tecnologías,
  progresión y generación procedural. Preservar semilla, orden determinista,
  tick fijo y acciones semánticas existentes.
- El estado lógico y persistido no depende de nodos, meshes, materiales,
  spritesheets, animaciones ni eventos de la interfaz. Mantener guardado/carga en
  su capa actual y respetar el alcance vigente de compatibilidad de partidas.
- Cada elemento visual debe disponer de una escena `.tscn` editable: minions y
  clases, criaturas, recursos, drops, interactivos, tótem, estructuras, mapa,
  HUD, menús, paneles y efectos. Componer e instanciar escenas reutilizables y
  compartir recursos donde corresponda.
- Los scripts pueden instanciar escenas, sincronizar estado y cambiar propiedades
  dinámicas. Definir apariencia y jerarquías visuales en escenas y recursos;
  evitar reconstruirlas rígidamente mediante código.
- El generador decide tipos, posiciones y cantidades; la presentación elige
  `PackedScene` editables. Conservar biomas, regiones y semillas. Un cambio de
  sprite, modelo o material no debe modificar el algoritmo ni sus resultados.
- Separar posición lógica, raíz mundial, desplazamiento visual, selección,
  colisiones y navegación. Cambiar tamaño de un sprite no debe alterar radios
  de combate, navegación o recolección.

## Pixel art, animaciones y edición

- Conservar mundo 3D y cámara ortográfica isométrica. Preferir `Sprite3D` para
  elementos estáticos y `AnimatedSprite3D` con `SpriteFrames` para animados.
  Usar `MeshInstance3D` para elementos realmente tridimensionales y
  `AnimationPlayer` para coordinar propiedades y efectos complejos.
- Exponer desde el Inspector texturas, `SpriteFrames`, escala, orientación,
  rotación, desplazamiento y altura visual, fotogramas, velocidad de animación,
  materiales, efectos y orden de representación cuando proceda. Usar filtrado
  nearest para pixel art; evitar suavizado innecesario. No imponer billboard:
  decidirlo según el objeto y la cámara.
- La lógica solicita estados mediante una interfaz de presentación. El adaptador
  traduce esos estados a animaciones; no hacer que la simulación conozca archivos
  o spritesheets. No ligar resolución de golpes o tareas al final de un clip visual.
- Configurar solo las animaciones que requiera cada personaje. Idle, caminar,
  recolectar, talar, minar, atacar, daño y muerte son posibilidades, no una lista
  obligatoria. Conservar los contratos actuales o adaptar su traducción al cambiar
  nombres. Un spritesheet debe poder sustituirse sin alterar las mecánicas.
- Usar arte provisional fácilmente sustituible mientras falte el definitivo.
  El desarrollador importa arte, configura animaciones y ajusta apariencia;
  Codex implementa sistemas y conexiones. Cuando Codex cree o modifique una
  escena, dejarla preparada para edición posterior y no asumir su arte definitivo.

## HUD, datos y programación

- Construir HUD y menús en `.tscn` con `Control`, contenedores y layouts adecuados.
  Centralizar fuentes, colores, bordes y estilos en recursos `Theme`. Crear o
  reutilizar componentes editables para recursos, minions, mejoras, reclutamiento,
  salud, menú principal, opciones, pausa, tooltips y notificaciones según la tarea.
- El código actualiza datos e interacciones. No fijar la distribución del HUD con
  posiciones rígidas en scripts ni crear botones, paneles o etiquetas con `.new()`
  sin justificación técnica concreta. Para listas dinámicas, instanciar plantillas
  de escena; conservar referencias y metadata semánticas al reorganizar controles.
- Usar `Resource` y `.tres` para configuración editable cuando aporten valor
  (estadísticas, clases, enemigos, recursos, herramientas, mejoras o costes).
  Respetar los valores del GDD; no migrar automáticamente todos los datos ni
  persistir objetos del motor dentro del estado lógico.
- Priorizar GDScript tipado, `@export` para configuración y `@onready` para nodos
  existentes cuando corresponda. Preferir composición, señales para desacoplar
  donde resulten útiles, lógica compartida entre clases y dependencias sin ciclos.
  Seguir nombres y rutas actuales. Documentar complejidad real; no introducir
  plugins, dependencias o refactors ajenos a la necesidad de la tarea.
- Si aparece una infracción existente, señalarla y corregirla cuando sea necesaria
  para el trabajo solicitado; no convertir esta guía en una migración permanente.

## Cierre y validación

Para cambios de código/escenas, comprobar análisis de scripts y referencias de
los recursos afectados, ejecutar las pruebas automatizadas pertinentes disponibles
y revisar que no cambien mecánicas ajenas a la tarea. Usar los puntos de entrada
del mapa local y comprobar el motor real antes de ejecutar; no dar por instalada
una versión solo porque figure en documentación.

Para elementos visuales nuevos, comprobar que escena, recursos y propiedades
queden accesibles desde el editor. Una comprobación estática o headless acredita
estructura y carga, no apariencia ni facilidad de edición comprobada manualmente.
Indicar cualquier prueba visual/editorial pendiente y cualquier validación
bloqueada, sin afirmar que funciona lo que no se ha observado.

Informar cambios, archivos, pruebas realmente ejecutadas y limitaciones. Mantener
diseño, planificación, estado y QA en sus documentos según `AGENTS.md`; registrar
estados solo con evidencia. La creación o edición de esta skill no implica cambios
en las mecánicas ni progreso de implementación del juego.

---
name: tribes-revival-ui-design
description: Diseñar o modificar HUD, menús y componentes de interfaz de Tribes Revival en Godot, con pixel art y escenas editables.
---

# Interfaces de Tribes Revival

Consultar `AGENTS.md`, el GDD, `godot/EDITING_VISUALS.md` y la skill de desarrollo del proyecto. Partir de la tarea del jugador y de su contexto tribal de supervivencia; definir una jerarquía, paleta, tipografía e iconografía coherentes y revisar su legibilidad en juego. Evitar soluciones genéricas de web, SaaS o panel empresarial. Aplicar los principios de diseño intencional de `frontend-design` adaptados al juego, sin imponer sus patrones web.

Construir presentación editable con escenas `.tscn`, nodos `Control`, `Container`, `PanelContainer`, `MarginContainer` y recursos `Theme` reutilizables; usar componentes existentes y escenas plantilla para listas dinámicas. Separar presentación, estado y lógica, usar señales cuando aporten claridad y evitar construir interfaces completas con GDScript. Mantener escala de píxeles coherente y filtrado nearest, sin desenfocar sprites. Comprobar anclajes, contenedores, resolución, legibilidad, foco y navegación cuando corresponda.

Contemplar según la tarea el HUD de comida, madera, piedra, brillo y oro; panel de tribu; barras de vida; transformación de recolectores; mejoras de herramientas; tecnologías; inventario; tooltips; pausa y configuración. Respetar `player_numbers.gd` y las excepciones de visualización numérica de `AGENTS.md`. No inventar mecánicas ni datos pendientes. Revisar en el editor y en partida cuando sea posible; distinguir pruebas automáticas de revisión visual.

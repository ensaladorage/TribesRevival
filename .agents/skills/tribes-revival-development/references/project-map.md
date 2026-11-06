# Contratos locales para orientar la inspección

Rutas relativas a la raíz. Son puntos de entrada observados: releer el código
actual antes de modificarlos; este mapa no sustituye la documentación de estado.

| Área | Punto de entrada y contrato |
| --- | --- |
| Proyecto | `godot/project.godot`; `godot/README.md` documenta Godot 4.7.2 y Compatibility. Confirmar ejecutable y renderer reales. `src/` es el original Babylon/TypeScript. |
| Coordinación | `godot/scripts/main.gd`: entrada, conexión de señales, acciones semánticas y sincronización de vistas. |
| Simulación | `godot/scripts/simulation/game_session.gd`: `TribeSession`, `RefCounted`, tick de 20 Hz, máximo cuatro pasos por frame. Estado serializable en `game_state.gd`; sistemas separados en el mismo directorio. |
| Persistencia | `godot/scripts/persistence/save_repository.gd`: slots locales; consultar esquema actual y alcance de compatibilidad antes de tocarlo. |
| Mundo | `godot/scenes/WorldView.tscn` y `godot/scripts/view/world_view.gd`: mapas exportados de escenas por identificador para actores, recursos, drops, biomas y decoración. Conservar claves semánticas. |
| Actores | `godot/scenes/actors/Minion.tscn` y variantes; `godot/scripts/view/actor_view.gd` traduce `present(actor)` a `idle`, `move`, `work`, `attack`. La simulación no elige spritesheets. |
| Contrato de actor | `Body/Sprite` contiene `AnimatedSprite3D`; `Selection/Shape` sirve para picking, separado de navegación lógica. `Health` y `HealthDisplay` intervienen en la presentación de salud. Preservar rutas o actualizar adaptador y escenas juntos. |
| Apariencia mundial | `godot/scripts/view/world_element.gd` expone `appearance_override: PackedScene`, `visual_scale` y `visual_offset`; la sustitución requiere raíz `Node3D`. Conservar `Visual/Default`, que el adaptador muestra u oculta. |
| Interactivos | `godot/scenes/world/` contiene recursos, drops y estructuras; `godot/scenes/placement/` contiene previsualizaciones de colocación. `HealingRange` en hogueras y `Rain` en nubes son conexiones opcionales de presentación. |
| HUD/menús | `godot/scenes/ui/HUD.tscn`, `Menus.tscn` y subescenas; scripts `godot/scripts/ui/game_hud.gd` y `game_menus.gd`. Referencias exportadas en el grupo `Scene references`. |
| Estilos y repetición | `godot/themes/TribesTheme.tres`; plantillas `SlotRow.tscn`, `CostSquare.tscn`, `HealthPip.tscn`. Reutilizar escenas para elementos dinámicos. |

En UI, conservar o adaptar expresamente la metadata `item`, `item_row`, `cost_for`,
`resource`, `tree`, `tree_options`, `technology` y `tool`. Las páginas de menú
mantienen nombres semánticos como `Title`, `Play`, `Back`, `Message` y `Rows`.
Consultar `godot/EDITING_VISUALS.md` para sustituir assets sin romper conexiones.

## Validación disponible

`godot/tools/validate.sh` usa `GODOT_BIN` o un binario Linux local por defecto.
Comprobar plataforma, disponibilidad de Bash y ejecutable antes de usarlo.
Actualmente comprueba el original, importa en headless, valida estructura y
ejecuta `test_menu_callbacks.gd`, `test_placement_input.gd` y `test_data.gd`.
Inspeccionar el script antes de ejecutar para conocer su cobertura vigente.

Si se invoca Godot directamente, usar `--headless --path godot --import` y después
los runners pertinentes con `--script res://...`, conservando las comprobaciones
de errores del wrapper. Leer códigos de salida y logs; un `SCRIPT ERROR` no
siempre provoca una salida no cero. El verificador Python de la skill
`godot-nodes-scenes` es un complemento estático, no reemplaza el análisis del motor.

No regenerar fixtures de referencia para ocultar fallos ni dar por verificados
spritesheets, layouts o edición desde Inspector mediante estas pruebas.

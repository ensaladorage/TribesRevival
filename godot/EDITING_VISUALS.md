# Editar la presentación desde Godot

Abrir `project.godot` en Godot 4.7.2. Los sprites actuales reutilizan iconos
originales; son placeholders de un solo frame, no animaciones definitivas.
No hace falta modificar la simulación para sustituirlos.

## Personajes

1. Abrir `scenes/actors/Minion.tscn`.
2. Seleccionar `Body/Sprite` (`AnimatedSprite3D`), abrir `Sprite Frames` y
   sustituir las imágenes de `idle`, `move`, `work` y `attack`. Se pueden añadir
   frames y cambiar su velocidad desde ese mismo recurso.
3. Cambiar `pixel_size`, escala/posición del sprite o `visual_scale` y
   `visual_tint` en la raíz. El filtro nearest conserva los bordes de pixel art.
4. Las seis clases heredan esta escena. Abrir `Mage.tscn`, `Guardian.tscn`, etc.
   para editar su tinte/equipo o sobrescribir sus SpriteFrames. La base se
   comparte mientras una variante no sobrescriba esa propiedad.
5. `Barbarian.tscn` y `Rabbit.tscn` son variantes de presentación independientes;
   usan el mismo icono provisional hasta disponer de sprites adecuados.

`Selection/Shape` es la caja editable del picking de equipo. La separación y
navegación lógica conservan sus radios originales: cambiar la apariencia o esa
caja no cambia colisiones/reglas de simulación. Se conserva además la tolerancia
de selección de 24 px del original. `Shield`, `DetectionRange` y el marcador
`Health` pueden editarse en la escena; mantener sus nombres o adaptar el
adaptador de presentación. El tamaño de las bolitas está en
`scenes/ui/HealthPips.tscn`; sus estilos en el Theme. `health_screen_margin_pixels`
controla el margen sobre el marcador, sin cambiar la vida real.

## Árboles, recursos, drops e interactivos

Abrir `scenes/world/Tree.tscn`, `Rock.tscn`, `Bush.tscn`, `DropFood.tscn`,
`Campfire.tscn`, etc. Editar meshes/materiales bajo `Visual/Default`, su escala
o posición. Cada color de drop tiene su propia escena; `Drop.tscn` es la base
compartida por las cinco variantes; editar su geometría afecta a todas.

Para reemplazar un modelo por pixel art, crear una escena con raíz `Node3D`,
`Sprite3D` o `AnimatedSprite3D`, asignarle la textura/animaciones y colocarla en
`appearance_override` de la raíz. También se pueden añadir esos nodos a
`Visual/Default` y ocultar/eliminar sus meshes. `visual_scale` y `visual_offset`
se previsualizan en el editor mediante `@tool`. El generador no se modifica.
La geometría predeterminada se oculta al asignar una sustitución; no se borra.

`scenes/WorldView.tscn` expone los mapas `actor_scenes`, `resource_scenes`,
`drop_scenes`, `biome_scenes` y `decoration_scenes`, y las escenas de efectos,
nubes, hogueras y cuerpos. Para cambiar un tipo completo, asignar otra
PackedScene al mismo identificador. Mantener los contratos de los personajes
anteriores; los recursos solo requieren una raíz Node3D. Una hoguera personalizada
puede conservar un nodo `HealingRange` para el indicador; una nube puede
incluir un nodo `Rain` para alternarlo al llover. No renombrar claves semánticas.

La generación determina posiciones/cantidades/tipos; `world_view.gd` instancia
escenas y sincroniza presentación. Ningún mesh/sprite decide tareas o botín.
El cadáver de bárbaro mantiene una representación geométrica provisional;
no se ha generado el sprite definitivo pendiente del usuario.

## HUD y menús

- Abrir `scenes/ui/HUD.tscn`: mover/redimensionar paneles en el editor 2D.
- Abrir sus subescenas para editar recursos, reclutamiento, equipo, tecnologías
  y mejoras. Los iconos y tamaños están en los controles, no en el script.
- `scenes/ui/Menus.tscn` contiene el marco modal; MainMenu, PauseMenu,
  TutorialMenu, SlotsMenu, ConfirmationMenu, FeedbackMenu y DefeatMenu contienen
  las páginas. `SlotRow.tscn` define el aspecto de cada fila dinámica.
- `Overlay.tscn` contiene progreso y debug; `scenes/placement/` las
  previsualizaciones de arrastre.
- Abrir `themes/TribesTheme.tres`: fuente, texto, botones, paneles, foco y
  variantes de nivel/costes/vida. Los fondos de panel usan StyleBoxTexture
  y SVG de gradientes derivados del CSS; se pueden sustituir desde el recurso. La fuente monoespaciada Liberation Mono se incluye en assets/fonts para
  mantener el aspecto en web/Windows/Linux; su licencia OFL acompaña los ZIP.

En la raíz de HUD.tscn y Menus.tscn, el grupo `Scene references` del inspector
contiene las referencias de nodos. Se guardan dentro de la escena, en lugar de
rutas escritas en GDScript: se pueden mover/renombrar paneles y contenedores
conservando esas referencias. Si se sustituye un control por otro, reasignarlo
en ese grupo del inspector. Las páginas de menú conservan nombres semánticos
como Title, Play, Back, Message y Rows para conectar su contenido dinámico.

Conservar la metadata `item`, `item_row`, `cost_for`, `resource`, `tree`, `tree_options`,
`technology` y `tool`: conectan la presentación con acciones semánticas. Se
pueden reorganizar los controles conservando esa metadata y las referencias. Los únicos controles
instanciados como datos variables son filas de slots, cuadrados de coste y
bolitas de HP; sus plantillas también son escenas editables.

Disponibilidad, costes, salud y textos de estado cambian en ejecución porque
representan datos del juego. Los estilos permanecen en las escenas/Theme.

## Validación pendiente

Importación, referencias y contratos de señales comprobados sin avanzar una
partida. La etapa manual final verificará sustitución de assets en el editor,
interacción completa y apariencia a distintos tamaños/zoom. No se considera
esta guía evidencia de una inspección visual que todavía no se ha realizado.

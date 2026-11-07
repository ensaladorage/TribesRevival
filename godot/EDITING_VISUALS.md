# Editar la presentación desde Godot

Abrir `project.godot` en Godot 4.7.2. Los personajes usan imágenes de un solo fotograma por estado; no son animaciones definitivas.
No hace falta modificar la simulación para sustituirlos.

El filtro 2D predeterminado del proyecto es Nearest, también para los iconos
del HUD, menús, tooltips y controles nuevos que hereden el filtro. En el
Inspector se configura en `CanvasItem > Texture > Filter`; conservar Nearest
o la herencia, sin sobrescribirlo con Linear. Los Sprite3D/AnimatedSprite3D
configuran Nearest por separado en sus escenas, incluido el fuego de la hoguera.

## Personajes

1. Abrir `scenes/actors/CharactersBase.tscn`.
2. Seleccionar `Body/Sprite` (`AnimatedSprite3D`), abrir `Sprite Frames` y
   sustituir las imágenes de `idle`, `move`, `work` y `attack`. Se pueden añadir
   frames y cambiar su velocidad desde ese mismo recurso.
3. Cambiar `pixel_size`, escala/posición del sprite o `visual_scale` y
   `visual_tint` en la raíz. El filtro nearest conserva los bordes de pixel art.
4. Las seis clases heredan esta escena. Abrir `Mage.tscn`, `Guardian.tscn`, etc.
   para editar su tinte o sobrescribir sus SpriteFrames. La base se
   comparte mientras una variante no sobrescriba esa propiedad.
   Las herramientas, armas y escudos no tienen sprites o meshes separados en
   los minions; su aspecto formará parte del sprite de cada clase.
5. `Barbarian.tscn` y `Sheep.tscn` son variantes de presentación independientes;
   la oveja usa su sprite propio y el bárbaro conserva el icono provisional.

`Selection/Shape` es la caja editable del picking de equipo. La separación y
navegación lógica conservan sus radios originales: cambiar la apariencia o esa
caja no cambia colisiones/reglas de simulación. Se conserva además la tolerancia
de selección de 24 px del original. `DetectionRange` y el marcador
`Health` pueden editarse en la escena; mantener sus nombres o adaptar el
adaptador de presentación. El tamaño de las bolitas está en
`scenes/ui/HealthController.tscn`; sus estilos en el Theme. `health_screen_margin_pixels`
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

La hoguera usa el sprite de `scenes/placement/campfire.tscn` dentro de
`Visual/Default`, con color normal para el mundo. Conserva `Visual/Default`
como contenedor aunque cambies el sprite: `world_element.gd` lo utiliza para
mostrar u ocultar la apariencia. El aro `HealingRange` está separado para
seguir visible si se asigna otra apariencia.

`scenes/WorldView.tscn` expone los mapas `actor_scenes`, `resource_scenes`,
`drop_scenes`, `biome_scenes` y `decoration_scenes`, y las escenas de efectos,
nubes, hogueras y cuerpos. Para cambiar un tipo completo, asignar otra
PackedScene al mismo identificador. Mantener los contratos de los personajes
anteriores; los recursos solo requieren una raíz Node3D. Una hoguera personalizada
puede conservar un nodo `HealingRange` para el indicador; una nube puede
incluir un nodo `Rain` para alternarlo al llover. No renombrar claves semánticas.

La generación determina posiciones/cantidades/tipos; `world_view.gd` instancia
escenas y sincroniza presentación. Ningún mesh/sprite decide tareas o botín.
El cadáver de bárbaro utiliza el sprite creado por el usuario en
`assets/enemies/dead.png`; su tamaño y posición se editan desde el nodo
`Visual/Default/Sprite` de `BarbarianCorpse.tscn`.

## Nodos de piedra y Brillo

`scenes/world/Rock.tscn` y `RockLarge.tscn` representan piedra pequeña y grande;
`Spark.tscn` y `SparkLarge.tscn`, Brillo pequeño y grande. Las cuatro escenas
heredan `ResourceSprite.tscn`, con `Visual/Default/Sprite`, filtro Nearest,
billboard y recorte AtlasTexture. La base define el apoyo en el suelo; cada
variante expone textura, región, offset y tamaño por píxel en el Inspector.

`WorldView.resource_scenes` contiene las variantes pequeñas y
`large_resource_scenes` las grandes, conservando las claves `stone-vein` y `ruin`.
La elección tiene la misma probabilidad para ambos tamaños y se mantiene por
semilla/ID. El tamaño es solo visual por ahora: no altera recursos ni niveles.
El sprite `stone node level 2.png` permanece sin escenas ni referencias activas.

## Efecto de curación

En `scenes/world/HealEffect.tscn`, editar `Visual/HealVFX` para ajustar posición,
escala, textura, fotogramas y velocidad. La posición X/Z está centrada en el
minion; la altura conserva el ajuste de la escena. El script mueve únicamente
la raíz para seguir la posición interpolada del personaje, sin sobrescribir
el transform del sprite ni añadir el antiguo ascenso de las cruces 3D.

## Vegetación decorativa

`scenes/world/DecorationSprite.tscn` define el Sprite3D compartido: filtro nearest,
billboard, recorte alfa y tamaño por píxel. No contiene geometría provisional.
Las ocho variantes son `Grass.tscn` y `GrassSmall.tscn`,
`Mushroom.tscn`, `MushroomSmall.tscn`, `MushroomBig.tscn`,
`DecorationBush.tscn`, `DecorationBushSmall.tscn` y `DecorationBushBig.tscn`.
Cada variante expone `Visual/Default/Sprite`, su textura AtlasTexture, región y
offset. El offset vertical es la mitad de la altura recortada para apoyar el
borde inferior en el terreno; revisarlo si se sustituye la imagen o su recorte.

`WorldView.decoration_scenes` permite sustituir cada variante. La semilla y el ID
del decorado eligen una variante y su reflejo horizontal estable; la escala lógica
se aplica a la raíz sin cambiar navegación o recolección. Los arbustos decorativos
no dan comida: `Bush.tscn` sigue siendo el nodo de bayas funcional. Las flores se
han retirado. La generación de cantidades, tipos y posiciones permanece en
`world_catalog.gd`; el claro inicial sigue las mismas reglas que los demás claros.

## HUD y menús

- Reclutamiento, equipo, tecnologías y mejoras usan un hijo `Icon`
  (`TextureRect`) en cada botón. Su escala se edita en
  `Layout > Transform > Scale`; `Texture > Region` del AtlasTexture controla
  el recorte. Los recursos usan `IconSlot/Icon` con el mismo sistema.
  Los iconos ignoran el ratón; los textos de tarjetas usan el hijo `Caption`.
  Recargar las escenas desde disco si Godot mantiene versiones abiertas
  anteriores antes de guardar nuevos cambios del editor.
- Para cambiar el tamaño del hacha, abre `scenes/ui/RecruitmentPanel.tscn` y
  selecciona `axeRow/axe/Icon` en el árbol. En `Layout > Transform > Scale`,
  usa el mismo valor en X e Y: `1` mantiene el tamaño, `1.2` lo amplía un 20 %.
  El pivote mantiene el dibujo centrado y el botón conserva su tamaño.
  `Icon` es un TextureRect independiente; su `Texture` recorta los márgenes
  transparentes de la imagen mediante un AtlasTexture.
- Abrir `scenes/ui/HUD.tscn`: mover/redimensionar paneles en el editor 2D.
- El icono de Hoguera usa `assets/ui/icon-fireplace.png`, actualmente de
  1254 × 1254 píxeles. Su AtlasTexture en `RecruitmentPanel.tscn` abarca
  la imagen completa: al sustituirla por otra resolución, ajustar también
  `Texture > Region`. Un recorte antiguo puede mostrar solo transparencia.
  `scenes/placement/campfire.tscn` comparte esta imagen; ajustar `pixel_size`
  si cambia la resolución para conservar el tamaño de la previsualización.
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

El tótem jugable se edita en `scenes/world/TotemSprite.tscn`: selecciona el nodo hijo `Sprite` para ajustar su textura, tamaño, posición y orientación. Su posición vertical es independiente de la posición de juego. El modelo previo está en `scenes/world/Totem3D.tscn`.

Para cambiar el tótem de la partida, abre `scenes/main.tscn`, sustituye la instancia `Totem` por `scenes/world/Totem3D.tscn` o `TotemSprite.tscn` y conserva el nombre `Totem`. La posición inicial es (80, 2, 80); el código la actualiza durante la partida.

En `Totem3D.tscn`, selecciona la raíz `Totem` y abre `Model Material → Next Pass → Shader Parameters`: `Outline Color` cambia el color del contorno y `Outline Width` su grosor.

Los cadáveres usan `Corpse.tscn` (minions) y `BarbarianCorpse.tscn` (bárbaros). En `Visual/Default/Sprite`, editar `Sprite Frames > death` para ajustar velocidad y fotogramas. La animación se reproduce una vez a 10 FPS y conserva el último fotograma hasta que la simulación retira el cadáver. `pixel_size` y posición controlan su apariencia. Al cargar una partida, los cadáveres recreados vuelven a reproducir esta animación visual.

En `scenes/world/Campfire.tscn`, los nodos `Visual/Default/Fire` y `Visual/Default/Embers1`, `Embers2`, `Embers3` permiten ajustar posición y tamaño (`pixel_size`). En `Sprite Frames` se editan los fotogramas y la velocidad; cada nodo de brasas se reproduce en bucle; la duración de su primer fotograma transparente determina la pausa.

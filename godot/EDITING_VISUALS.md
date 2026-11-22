# Editar la presentación desde Godot

Abrir `project.godot` en Godot 4.7.2. Los personajes usan imágenes de un solo fotograma por estado; no son animaciones definitivas.
No hace falta modificar la simulación para sustituirlos.

El filtro 2D predeterminado del proyecto es Nearest, también para los iconos
del HUD, menús, tooltips y controles nuevos que hereden el filtro. En el
Inspector se configura en `CanvasItem > Texture > Filter`; conservar Nearest
o la herencia, sin sobrescribirlo con Linear. Los Sprite3D/AnimatedSprite3D
configuran Nearest por separado en sus escenas, incluido el fuego de la hoguera.

## Suelo modular de los biomas

Abrir `scenes/world/TerrainReference.tscn` y pulsar **F6** para ver la costa,
tres alturas, escaleras y una pared que termina sobre tierra y agua.
Para cambiar la apariencia del mundo jugable, abrir `IslandSurface.tscn`
y editar **Palettes**, **Cliff**, **Shadow** o **Foam** en el Inspector.
El material de **Ground** en `main.tscn` contiene la textura de agua.

Cada pieza de 64 × 64 px cubre 1,5 m. El atlas se selecciona por bioma,
altura, vecinos cardinales y orientación de las escaleras. El pedregal usa
la plataforma y las paredes de `Tilemap_Pegregal.png`. Sobre el agua utiliza el remate costero de la lámina de montaña.
La espuma y la sombra ocupan tres tiles de ancho y están centradas en su
celda. La espuma va sobre el agua y la sombra bajo la plataforma. Los
fotogramas de espuma se leen de izquierda a derecha en `Water Foam.png`.

Los recortes individuales siguen disponibles en `assets/biomes/recortes/`
como recursos AtlasTexture. Las escenas `Biome*.tscn` permiten inspeccionar
las piezas planas aisladas. La composición de las tres alturas en partida la
construye `IslandSurface` a partir de la cuadrícula de simulación.

Las rocas costeras se editan en las cuatro escenas WaterRock. Cada una usa
ocho cuadros de 128 × 128 a 10 FPS. La posición lógica se guarda junto a las
decoraciones y la vista aplica la elevación necesaria sobre el plano del agua.

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

La profundidad es natural: `render_priority = 0` y `no_depth_test = false`.
No elevar el tótem por encima del resto. Los recursos y personajes usan Alpha
Cut Discard; el árbol usa temporalmente un shader de recorte circular con
borde dither, sin mezcla alfa. El contorno del tótem también respeta profundidad.

En la raíz de cada recurso, **Visual clearance > Decoration Clearance Radius**
define la huella en metros que debe quedar libre de decoración (árboles 1.2,
bayas 1.4, otros recursos 1). En decoración, el radio predeterminado es 0.45
y se multiplica por su escala. Cambiar estos radios requiere reconstruir/cargar
la vista para recalcular la separación; no cambia los datos guardados.

Las cuatro escenas de árbol exponen **Canopy occlusion**: `canopy_region` es un
Rect2 normalizado de la textura, con origen arriba a la izquierda, ajustado a
la copa. Además se descartan sus píxeles transparentes. `hole_radius` (1.15 m)
controla el centro completamente despejado; `dither_edge_width` (0.5 m), el
anillo de transición; `dither_pixel_size` (2 píxeles de render), el tamaño del patrón.
Los tiempos son 0.15 s para abrir, 0.25 s para cerrar y 0.15 s de espera antes
de cerrar. El círculo sigue el centro del cuerpo de cada minion/enemigo oculto;
el tótem queda excluido. El resto del árbol permanece opaco. Hasta 32 círculos
por árbol, con estado y material propios. El radio en metros escala naturalmente
con el zoom. Se conservan escalas, apoyos y SpriteFrames.
El shader usa billboard completo, eje Z y atlas/frames de los árboles actuales.
Una sustitución sin SpriteBase3D visible no recibe el efecto.

Abrir `scenes/world/Tree.tscn`, `Rock.tscn`, `BerryBush.tscn`, `DropFood.tscn`,
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

## Árboles animados de madera

`scenes/world/Tree.tscn`, `Tree2.tscn`, `Tree3.tscn` y `Tree4.tscn` contienen
`Visual/Default/Sprite` (AnimatedSprite3D). Editar allí `Sprite Frames > idle`,
velocidad, `pixel_size`, `offset` y posición. El bucle usa los ocho fotogramas
originales a 10 FPS, nearest y billboard. Las hojas 1/2 usan celdas 192 × 256;
3/4, 192 × 192. Los offsets individuales apoyan la base visible sobre el bioma.

`WorldView.tree_scenes` asigna las cuatro escenas. Bosques y otros biomas eligen
1/2; praderas, 3/4. La elección es estable por semilla/ID incluso al cargar.
Se retira el árbol al agotarse y reaparece con la misma variante con la lluvia.
La edición del sprite no afecta a navegación, afinidad, duración ni botín.

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
Las variantes estáticas son `Grass.tscn` y `GrassSmall.tscn`,
`Mushroom.tscn`, `MushroomSmall.tscn`, `MushroomBig.tscn`,
`DecorationBushSmall.tscn`. Los arbustos medianos/grandes ahora usan
`DecorationBush.tscn` y `DecorationBushBig.tscn` (hojas 1/2, praderas y claros),
y `DecorationBushForest.tscn` y `DecorationBushForestBig.tscn` (3/4, bosques).
Estas cuatro escenas contienen AnimatedSprite3D con ocho celdas de 128 × 128,
bucle `idle` a 10 FPS. Editar Sprite Frames, pixel_size y offset desde el
Inspector; cada variante conserva la altura aproximada mediana/grande previa.
Cada variante expone `Visual/Default/Sprite`: textura AtlasTexture en las
estáticas, SpriteFrames en las animadas, y offset para ajustar el apoyo. El offset vertical es la mitad de la altura recortada para apoyar el
borde inferior en el terreno; revisarlo si se sustituye la imagen o su recorte.

`WorldView.decoration_scenes` permite sustituir cada variante. La semilla y el ID
del decorado eligen una variante y su reflejo horizontal estable; la escala lógica
se aplica a la raíz sin cambiar navegación o recolección. Los arbustos decorativos
no dan comida: `BerryBush.tscn` sigue siendo el nodo de bayas funcional. Las flores se
han retirado. La generación de cantidades, tipos y posiciones permanece en
`world_catalog.gd`; el claro inicial sigue las mismas reglas que los demás claros.

## HUD y menús

- Si un AtlasTexture repite píxeles en los bordes al ampliar `Region`, activar
  `Texture > Filter Clip`. Los atlas del minion en tutorial y reclutamiento
  lo tienen activado. Mantener el recorte dentro de la imagen; para añadir
  espacio transparente alrededor, usar `Margin` en vez de extender `Region`.
- Los seis iconos de clases del tutorial usan AtlasTexture independientes.
  Abrir `scenes/ui/TutorialMenu.tscn`, seleccionar `Roles/Role0` a `Role5/Row/Icon`
  (el nodo `Icon` dentro de `Row` de cada tarjeta) y desplegar `Texture > Region`
  para recortar los márgenes transparentes. Cada región comienza abarcando la
  imagen completa. El recorte es propio del tutorial y no cambia los del HUD.
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

El tótem jugable se edita en `scenes/world/Totem3D.tscn`. La versión sprite se ha retirado del proyecto.

La instancia `Totem` de `scenes/main.tscn` usa `scenes/world/Totem3D.tscn`. Conserva su nombre. La posición inicial es (80, 2, 80); el código la actualiza durante la partida.

En `Totem3D.tscn`, selecciona la raíz `Totem` y abre `Model Material → Next Pass → Shader Parameters`: `Outline Color` cambia el color del contorno y `Outline Width` su grosor.

Los cadáveres usan `Corpse.tscn` (minions) y `BarbarianCorpse.tscn` (bárbaros). En `Visual/Default/Sprite`, editar `Sprite Frames > death` para ajustar velocidad y fotogramas. La animación se reproduce una vez a 10 FPS y conserva el último fotograma hasta que la simulación retira el cadáver. `pixel_size` y posición controlan su apariencia. Al cargar una partida, los cadáveres recreados vuelven a reproducir esta animación visual.

En `scenes/world/Campfire.tscn`, los nodos `Visual/Default/Fire` y `Visual/Default/Embers1`, `Embers2`, `Embers3` permiten ajustar posición y tamaño (`pixel_size`). En `Sprite Frames` se editan los fotogramas y la velocidad; cada nodo de brasas se reproduce en bucle; la duración de su primer fotograma transparente determina la pausa.

## Nubes de clima

Las cuatro composiciones son `scenes/world/Cloud.tscn`, `Cloud2.tscn`,
`Cloud3.tscn` y `Cloud4.tscn`. Cada una contiene una nube grande, entre una y dos medianas
y entre una y tres pequeñas de los dos tipos suministrados. Editar sus Sprite3D bajo
`Visual/Default/Clouds`: posición, escala, textura y pixel_size son libres.
Los sprites usan billboard, Nearest y Alpha Cut Discard con umbral 0.5 para
eliminar la sombra pintada al 33 % sin cambiar el cuerpo opaco. Las seis texturas usan Lossless sin mipmaps.

`CloudBase.tscn` comparte el adaptador y el efecto `Visual/Default/Rain`;
no contiene las antiguas esferas. Editar la base cambia la lluvia de las cuatro
composiciones. `WorldView.cloud_variants` permite asignar otras escenas;
`cloud_scene` se conserva como alternativa si la lista está vacía. La selección
es estable por semilla e ID y también se aplica a nubes guardadas, sin cambiar
trayectorias, duración, cantidad de nubes lógicas ni regeneración de recursos.

### Altura y sombra de las nubes

En la raíz de cualquiera de las cuatro composiciones, `cloud_height` controla
la altura central (15 m). El contenedor Clouds aplica el desplazamiento sobre
las posiciones originales de sus sprites y actualiza la previsualización
en el editor. La lluvia parte 1.2 m por debajo; `rain_speed` conserva su significado
anterior: velocidad física de caída = rain_speed × 11.3 m/s.

En CloudBase, GroundShadow es un plano horizontal independiente del contenedor
Clouds. Mesh > Size controla el tamaño (14 × 9); el ShaderMaterial expone
shadow_color, opacity (máximo 0.12) y soft_edge. Su altura es 0.08 m y el suelo modular del bioma está a 0.03 m. Respeta profundidad, no escribe
en ella y no usa prioridades. La sombra sigue la posición horizontal del grupo.

### Sombra de minions y enemigos

CharactersBase y Minion instancian TotemShadow como GroundShadow en la raíz.
Todas las clases y Barbarian heredan esa sombra; permanece bajo los pies durante
los movimientos visuales de Body. Su escala es 0.32 × 1 × 0.26; visual_offset
compensa el desplazamiento original del mesh para centrarlo en el personaje.
Editar posición/escala de GroundShadow para ajustar el apoyo. Sheep conserva
su sombra propia y oculta esta instancia heredada para evitar duplicados.

### Dither en arbustos decorativos

Las cinco variantes DecorationBush usan el mismo adaptador de recorte que los
árboles. En sus raíces: hole_radius 0.6, dither_edge_width 0.5 y dither_pixel_size 1 en todas,
incluida la pequeña. center_on_overlap centra el círculo en una muestra opaca del cuerpo
realmente tapada por el follaje, excluyendo los márgenes vacíos, para que funcione también al tapar los pies.
El resto de la silueta conserva su opacidad y las animaciones permanecen activas.
Los valores están en unidades del mundo y se pueden editar por escena.
Grass (césped grande) también usa este efecto con los mismos parámetros.
GrassSmall, bayas recolectables y setas quedan fuera.
En la raíz de árboles, arbustos y Grass, desmarca **Canopy Occlusion > Dither Enabled**
para desactivar el recorte por escena. Al desactivarlo se retira inmediatamente cualquier
recorte activo y se omiten sus comprobaciones de oclusión.

### Sombras de recursos recolectables

Los diez modelos recolectables comparten `ResourceShadow.tscn` bajo `Visual/Default`. La posición y escala de cada instancia definen su huella sobre el suelo. El offset vertical del sprite sitúa la última fila visible de la textura en el punto de apoyo. Los árboles conservan ese punto en los ocho fotogramas.

### Disparo básico del mago

WorldView expone `mage_projectile_scene`, por defecto
`scenes/world/MageProjectile.tscn`. Editar Orb para sustituir la esfera violeta
provisional. WorldView lo desplaza hacia el punto de ataque durante el impulso
existente; daño, alcance y cadencia pertenecen a la simulación.

### Flecha provisional del cazador

WorldView expone `hunter_projectile_scene`, que usa
`scenes/world/HunterProjectile.tscn`. Shaft y Tip definen la flecha editable,
orientada hacia -Z. Se muestra tanto al combatir como al cazar, durante el
impulso de ataque existente.


## Minion levantado

En `scenes/actors/CharactersBase.tscn`, la raíz expone `carried_height` para la
altura visual al arrastrar. Las variantes heredan este ajuste. La sombra
permanece en el suelo y la barra de vida acompaña al cuerpo elevado.

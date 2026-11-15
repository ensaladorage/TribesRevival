# Ajustes de diseño de la versión Godot

## Trabajo cerca de enemigos y rescate por impacto — 2026-11-08

- Mientras un civil no sea objetivo puede iniciar y completar recolección,
  recogida de drops o saqueo aunque un enemigo cercano combata con un guardián.
  El trabajo tiene prioridad sobre apartarse y no se filtra por esa proximidad.
- Un golpe con daño de un combatiente cambia el foco de un bárbaro que perseguía
  a un civil hacia ese atacante. Sin impacto no hay transferencia; si ya se
  centra en un combatiente, otros atacantes no le roban el foco.
- La persecución real sigue interrumpiendo el trabajo. Se conserva v17 y
  el ID de foco existente, sin añadir campos al guardado.

## Foco enemigo persistente — 2026-11-08

- El bárbaro mantiene al objetivo vivo actual dentro de 15 m hasta derrotarlo
  o perderlo. Un atacante nuevo o más cercano no le roba el foco; tampoco lo
  reinicia transformar al minion. Si muere el bárbaro, se limpia el objetivo.
- Al necesitar otro objetivo se conservan prioridades de atacantes y distancia.
  La salida del radio de persecución sigue permitiendo escapar/reagruparse.
  El `targetUnitId` guardado conserva el foco al cargar, sin cambiar v17.

## Destinos aleatorios y rodeo durante huida — 2026-11-08

- Pausas de 2–4 s. Al comenzar y después de cada pausa se eligen puntos
  aleatorios dentro del mando, a partir de 4 m del centro, con PRNG reproducible.
  Se conservan los límites de 8 m/1,6 s entre pausas y la huida solo al ser objetivo.
- Los fugitivos no atraviesan el tótem: rutas, pasos y separación respetan su
  despeje. Si el tótem se desplaza encima, salen gradualmente sin salto.

## Huida solo ante persecución directa — 2026-11-08

- Detección no implica huida: los civiles mantienen idle, nodos y drops si
  ningún enemigo los elige como objetivo. Las decisiones usan la intención
  enemiga del mismo tick, después de resolver las respuestas de combatientes.
- Un civil no perseguido dentro de 3 m de un enemigo que ataca a un aliado
  armado se aparta a velocidad normal, sin pausas ni episodio de huida.
  Fuera de la pelea retoma tareas; evita elegir trabajo dentro de ese área.
- La huida con pausas y carreras de 8 m solo se aplica al civil perseguido
  y termina al perder la persecución. Se conserva el seguimiento del tótem.

Este documento complementa el GDD v0.6.0 para los cambios solicitados después
de la migración. El GDD y las fuentes del juego Babylon se conservan como
referencia original; los ajustes de esta lista se aplican a Godot.

## Huida civil ampliada — 2026-11-08

- Ajuste tras prueba del usuario: desplazamientos de hasta 8 m/1,6 s entre
  pausas de 1–2 s dentro del mando, sin zona fija ni exigir mejorar la seguridad
  actual. Permite buscar otro punto distante después de cada pausa.

## Huida civil limitada inicial (sustituida por el ajuste anterior) — 2026-11-08

- Todos los roles sin capacidad de combate usan una carrera hacia un destino
  fijo seguro del borde del mando; la navegación puede rodear obstáculos.
- Al llegar, pausa de 1–2 s y esquivas de hasta 1 m/0,4 s dentro de una zona
  fija de 2 m, siempre dentro del mando. Cada esquiva termina en otra pausa;
  si no hay un destino más seguro, permanecen parados durante otra pausa.
- Si la carrera queda bloqueada sin avanzar durante 1 s, la zona se fija en
  la posición alcanzada. Los civiles pueden recibir daño y morir normalmente.
- Alejar el tótem fuera de su alcance suspende la huida para seguirlo hasta
  entrar al mando, conservando la pausa pendiente. Reubicar la zona si ya no
  es válida; levantarlo/soltarlo sin alejarlo no concede otra carrera.
- Perseguidor nuevo o daño no reinician el episodio. Transformación o fin de
  amenaza lo terminan. No cambian costes, salud ni estadísticas de combate.

## Seguimiento y formación del tótem — 2026-11-06

- La formación conserva como referencia el anillo de 4 m. Cada minion ocupa
  una posición ligeramente distinta en cada recogida del tótem, en lugar de
  exigir siempre los mismos puntos exactos.
- Mientras se lleva el tótem, los destinos varían suavemente e independientemente
  para romper el movimiento rígido del grupo. La llegada se desacelera de forma
  individual; el seguimiento conserva el máximo de 10 m/s.
- Al soltar el tótem, los destinos se fijan en sus posiciones de ese instante
  para permitir terminar la formación y retomar tareas. La convergencia final
  recupera una velocidad mínima de 6 m/s. No hay variación de destinos durante
  esa convergencia.
- Ajuste ampliado tras la primera prueba manual: dispersión de hasta 0,6 m y
  desplazamiento suave adicional de hasta 0,65 m. Cada minion también responde
  al destino con una velocidad de aproximación diferente para dejar de seguir
  como un anillo compacto. Son parámetros ajustables tras la siguiente prueba.
- Se conservan la navegación, evasión y separación entre unidades. Este cambio
  solo afecta al seguimiento del tótem; terminar una tarea sigue llevando al
  reposo dentro del radio o al retorno al radio si se está fuera.
- Una amenaza bárbara que esté cerca tanto del tótem como de un minion armado
  interrumpe su seguimiento y activa el combate, incluso mientras el tótem se
  lleva o la tribu termina de reagruparse. Durante el seguimiento la tribu no
  persigue enemigos que queden fuera del radio de mando.
- Si un combatiente supera los 10 m del radio de mando durante el seguimiento,
  termina solo el impulso del golpe ya iniciado y sigue al tótem sin esperar
  a que se suelte. No inicia otro ataque fuera del radio, aunque el enemigo
  permanezca dentro de él.
- Al terminar el combate con el tótem colocado, cada minion busca trabajo o
  entra en reposo desde su posición; si está fuera del radio de mando, regresa
  solo hasta entrar en él. Esto también se aplica si otros minions aún están
  completando la formación. Al volver a levantar el tótem se reanuda el
  seguimiento normal de toda la tribu.
- La flecha amarilla del tótem se ha eliminado. Los minions tampoco muestran
  armas, herramientas o escudos separados: su representación estará integrada
  en los sprites de cada clase.

## Contrato técnico

Al pasar directamente del seguimiento al combate, la velocidad se ajusta de
forma gradual durante 0,4 s hasta la velocidad normal de combate (6 m/s). Los
bárbaros mantienen libre el espacio físico del tótem al perseguir o patrullar;
si el tótem se mueve encima de uno, puede salir sin teletransportarse. Los
seis huecos cuerpo a cuerpo y la separación siguen sujetos al alcance real.

La simulación calcula el perfil con la semilla de partida, el ID de la unidad
y el tick en el que se levanta el tótem. Las fases y periodos de cada unidad
son distintos, sin generar ruido aleatorio por frame. El frame de navegación
comparte un único destino y velocidad por unidad entre predicción y movimiento.

Los campos opcionales `totem.formationStartTick` y `totem.formationStopTick`
conservan la fase al guardar/cargar. El estado inicial sigue siendo v17; un
guardado sin esos campos usa un perfil estable hasta la próxima recogida.
No cambia la estructura obligatoria ni se requiere migrar los slots actuales.

## Profundidad natural y legibilidad de vegetación

Se retiran las prioridades visuales por categoría y el tótem superpuesto a todo.
La decoración deja espacio en torno a las huellas de recursos mediante colocación
solo visual, estable por semilla/ID. Las copas que ocultan cuerpos de personajes
o el tótem se atenúan al 35 %, con transiciones y espera configurables por escena.
No se cambian posiciones lógicas, guardados, rendimientos ni navegación.

## Ataque básico del mago

Aprobado: 2 de daño, 3 m de alcance y disparo cada 2.5 s. Base compartida para
las ramas futuras Nigromante/Fuego. Reutiliza combate a distancia sin caza.

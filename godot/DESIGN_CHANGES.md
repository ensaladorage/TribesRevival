# Ajustes de diseño de la versión Godot

Este documento complementa el GDD v0.6.0 para los cambios solicitados después
de la migración. El GDD y las fuentes del juego Babylon se conservan como
referencia original; los ajustes de esta lista se aplican a Godot.

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

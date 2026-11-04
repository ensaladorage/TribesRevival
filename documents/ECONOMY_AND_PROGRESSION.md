# Tribes Revival — Economía y progresión

**Documento:** propuesta de balance y progresión  
**Base de diseño:** `GDD_Tribes_Revival_v0.6.0.md`  

> **Leyenda:** **Base GDD** = coste o regla ya documentada.
> **Propuesta** = ampliación recomendada. **Pendiente** = requiere
> validación o diseño adicional.

------------------------------------------------------------------------

## 1. Principios de economía

| Principio                   | Aplicación                                                                                                 |
|:----------------------------|:-----------------------------------------------------------------------------------------------------------|
| Varios usos por recurso     | Evitar que piedra, oro o Brillo se acumulen sin utilidad.                                                  |
| Costes progresivos          | Mantener las curvas actuales y 	añadir costes mixtos al final de las mejoras.                               |
| Progresión por riesgo       | Regiones avanzadas, campamentos y cuevas deben aportar recursos difíciles de conseguir en la zona inicial. |
| Mejoras por hitos           | Alternar velocidad, probabilidad de botín y desbloqueos; no sumar producción fija por nivel.               |
| Sin mantenimiento constante | No consumir comida por segundo o por unidad. Usarla en reclutamiento, curación y expediciones.             |
| Recompensas únicas          | Descubrir regiones, abrir cofres y derrotar jefes debe recompensarse una sola vez.                         |

## 2. Recursos y economía

| Recurso                                 | Fuentes actuales / previstas         | Usos actuales                                     | Usos futuros recomendados                      |
|:----------------------------------------|:-------------------------------------|:--------------------------------------------------|:-----------------------------------------------|
| **Comida**                              | Bayas, conejos, carne de bárbaros    | Reclutar Recolectores; curación en hoguera        | Provisiones y consumibles de expedición        |
| **Madera**                              | Ramitas, árboles, drops de bárbaros  | Transformaciones de roles; hoguera                | Mejoras de campamento y estructuras            |
| **Piedra**                              | Vetas mediante Artesana              | Mejoras de hacha, martillo y espada               | Mejoras estructurales y nodos avanzados        |
| **Oro**                                 | Cadáveres de bárbaros y cofres en mazmorras o campamentos                | Transformación en Guardián; escudos, armaduras               | Mejoras avanzadas y equipo de élite            |
| **Brillo**                              | Ruinas mediante Artesana            y cofres en mazmorras y campamentos | Transformación en Mago y otras clases legendarias | Habilidades legendarias y reliquias            |
| **Fragmento de reliquia** (idea a futuro) | Cofres, campamentos de élite y jefes | —                                                 | Mejoras especiales y recompensas de expedición |

**Regla de acceso:** piedra y Brillo dependen de la Artesana. Las
ramitas deben seguir siendo una vía de emergencia para obtener madera y
evitar bloqueos si la tribu pierde a sus Leñadores.

## 3. Costes de reclutamiento y transformación

| Acción                         | Recurso |   Coste progresivo | Estado / condición                                                                        |
|:-------------------------------|--------:|-------------------:|:------------------------------------------------------------------------------------------|
| Añadir Recolector              |  Comida | `2, 3, 3, 4, 4, 4` | **Base GDD**. Según población total; máximo 8 unidades.                                   |
| Transformar en Leñador         |  Madera |    `2, 3, 3, 4, 4` | **Base GDD**. Cuenta Leñadores activos; máximo 5.                                         |
| Transformar en Cazador         |  Madera |    `2, 3, 3, 4, 4` | **Base GDD**. Cuenta Cazadores activos; máximo 5.                                         |
| Transformar en Artesana        |  Madera |    `2, 3, 3, 4, 4` | **Base GDD**. Requiere tecnología Artesana; máximo 5.                                     |
| Transformar en Guardián        |     Oro |    `2, 3, 3, 4, 4` | **Base GDD**. Sin requisito de nivel.                                                     |
| Equipar escudo a Guardián      |     Oro |    `2, 3, 3, 4, 4` | **Base GDD**. Un escudo por Guardián; +1 HP máximo y actual.                              |
| Transformar Recolector en Mago |  Brillo |                 `2` | **Aprobado para esta fase**. Transforma una unidad existente; no aumenta la población. Límite de 1 fuera de mazmorras. |
| Transformación en Pícaro       |  Brillo |    `3, 4, 4, 5, 6` | **Propuesta**. Limite de 1 fuera de mazmorras. La curva es solo valida dentro de mazmorras |
| Transformación en Paladín      |  Brillo |    `3, 4, 4, 5, 6` | **Propuesta**. Limite de 1 fuera de mazmorras. La curva es solo valida dentro de mazmorras |

**Reglas de legendarios:** fuera de las cuevas solo puede haber una
clase legendaria activa. La transformación en Mago convierte un
Recolector existente y es irreversible.

## 4. Árboles de tecnologías

### Primera iteración aprobada

| Árbol | Tecnología | Coste | Nivel mínimo |
|:------|:-----------|------:|-------------:|
| Supervivencia | Artesana | 1 punto | 2 |
| Exploración | Mago | 1 punto | 2 |
| Combate | Escudo | 1 punto | 1 |

Esta tabla prevalece sobre las propuestas posteriores para la primera
iteración. Solo estas tres tecnologías están aprobadas; mantienen sus
efectos actuales y comparten puntos. No se incorporan las demás propuestas.
En particular, Escudo requiere nivel 1, no el nivel 2 de la tabla futura.

### Propuestas futuras, fuera de esta iteración

Las tecnologias son propuestas no confirmadas hasta que yo lo diga, son solo ideas por el momento (a excepcion de la artesana y el escudo) tienen **tres árboles independientes**. Cada nivel de jugador
concede 1 punto tecnológico; los puntos se guardan hasta que el jugador
decida gastarlos.

| Regla                                  | Propuesta                                                      |
|:---------------------------------------|:---------------------------------------------------------------|
| Coste                                  | 1, 2 o 3 puntos según la tecnología                            |
| Desbloqueo                             | Nivel mínimo y, cuando corresponda, tecnología previa          |
| Compra                                 | Una vez por tecnología, salvo que se diseñen rangos explícitos |
| Reinicio                               | Sin reespecialización inicialmente                             |
| Total de los tres árboles              | Sin maximo definido por ahora |

### Árbol de Supervivencia

| Nivel mínimo | Tecnología              | Coste | Requisito       | Función propuesta                                                           |
|-------------:|:------------------------|------:|:----------------|:----------------------------------------------------------------------------|
|            2 | Artesana                |     1 | —               | Habilita la transformación en Artesana y la recolección de piedra y Brillo. |
|            4 | Aprovechamiento         |     2 | Artesana        | Mejora rendimiento o tiempo de recolección básica.                          |
|            6 | Campamento              |     2 | Artesana        | Habilita mejoras y servicios de campamento.                                 |
|            8 | Logística               |     2 | Aprovechamiento | Mejora preparación y capacidad de expedición.                               |
|           10 | Provisiones             |     3 | Campamento      | Habilita consumibles de expedición basados en comida.                       |
|           13 | Maestría de recolección |     3 | Logística       | Mejora avanzada de producción de recursos.                                  |

### Árbol de Combate

| Nivel mínimo | Tecnología             | Coste | Requisito | Función propuesta                               |
|-------------:|:-----------------------|------:|:----------|:------------------------------------------------|
|            2 | Escudo                 |     1 | —         | Habilita equipar escudos a Guardianes.          |
|            4 | Formación              |     2 | Escudo    | Mejora supervivencia o coordinación del grupo.  |
|            6 | Cazador experto        |     2 | Escudo    | Mejora la eficacia del Cazador.                 |
|            8 | Armería                |     2 | Formación | Habilita equipo y mejoras de combate avanzadas. |
|           11 | Tácticas de campamento |     3 | Formación | Ventajas contra grupos de campamentos.          |
|           14 | Cazador de jefes       |     3 | Armería   | Mejora específica contra jefes.                 |

### Árbol de Exploración

| Nivel mínimo | Tecnología           | Coste | Requisito            | Función propuesta                                        |
|-------------:|:---------------------|------:|:---------------------|:---------------------------------------------------------|
|            3 | Rastreador           |     1 | —                    | Detecta recursos y amenazas cercanas.                    |
|            5 | Cartografía          |     2 | Rastreador           | Revela información de regiones.                          |
|            7 | Explorador de ruinas |     2 | Cartografía          | Detecta ruinas y puntos de interés.                      |
|           10 | Expedicionario       |     2 | Explorador de ruinas | Mejora la preparación para cuevas.                       |
|           13 | Conocimiento antiguo |     3 | Expedicionario       | Permite interactuar con reliquias y mecanismos antiguos. |
|           16 | Maestro explorador   |     3 | Conocimiento antiguo | Mejora recompensas o eficiencia de exploración.          |

Las funciones son objetivos de diseño y deben concretarse antes de
implementarlas. No es necesario incorporar todas las tecnologías en el
siguiente hito.

## 5. Experiencia y niveles

### Curva de XP propuesta

El jugador empieza en nivel 0 con 0 XP y 0 puntos tecnológicos. La regla
actual exige 12 XP para llegar a nivel 1 y aumenta el requisito en 12 XP
por subida; cada subida concede 1 punto. La tabla siguiente es una propuesta
futura de curva alternativa, fuera de esta iteración.

| Nivel actual | XP para el siguiente nivel | XP acumulada para alcanzar el siguiente |
|-------------:|---------------------------:|----------------------------------------:|
|            1 |                         12 |                                      12 |
|            2 |                         24 |                                      36 |
|            3 |                         36 |                                      72 |
|            4 |                         48 |                                     120 |
|            5 |                         64 |                                     184 |
|            6 |                         80 |                                     264 |
|            7 |                        100 |                                     364 |
|            8 |                        120 |                                     484 |
|            9 |                        145 |                                     629 |
|           10 |                        170 |                                     799 |
|           11 |                        200 |                                     999 |
|           12 |                        230 |                                   1.229 |
|           13 |                        265 |                                   1.494 |
|           14 |                        300 |                                   1.794 |
|           15 |                        340 |                                   2.134 |
|           16 |                        380 |                                   2.514 |
|           17 |                        425 |                                   2.939 |
|           18 |                        470 |                                   3.409 |
|           19 |                        520 |                                   3.929 |

### Recompensas de XP

| Acción                          |  XP | Estado / límite                                      |
|:--------------------------------|----:|:-----------------------------------------------------|
| Recolección completada          |   1 | **Base GDD**                                         |
| Conejo cazado                   |   3 | **Base GDD**                                         |
| Bárbaro derrotado               |   5 | **Base GDD**                                         |
| Enemigo de campamento derrotado |   8 | **Propuesta**. Primera derrota de ese enemigo.       |
| Enemigo de élite derrotado      |  12 | **Propuesta**. Primera derrota.                      |
| Descubrir una región            |  10 | **Propuesta**. Una vez por región.                   |
| Limpiar un campamento           |  25 | **Propuesta**. Una vez por campamento.               |
| Abrir un cofre de cueva         |  10 | **Propuesta**. Una vez por cofre.                    |
| Derrotar un jefe regional       |  60 | **Propuesta**. Una vez por jefe.                     |
| Completar una expedición        |  20 | **Propuesta**. Al cumplir objetivo y salir con vida. |

**Control anti-farmeo:** descubrimientos, campamentos, cofres y jefes se
registran en el estado persistente. El XP repetible de enemigos
ordinarios debe probarse teniendo en cuenta los tiempos de reaparición.

## 6. Mejoras de herramientas

Los niveles son globales por tipo de herramienta y afectan a todas las
unidades que la utilizan. Se mantiene el coste progresivo en piedra y se
añaden Brillo y Oro en los niveles finales.

### Coste por nivel — por herramienta

| Nivel comprado | Piedra | Brillo | Oro | Piedra acumulada | Brillo acumulado | Oro acumulado |
|---------------:|-------:|-------:|----:|-----------------:|-----------------:|--------------:|
|              1 |      1 |      0 |   0 |                1 |                0 |             0 |
|              2 |      2 |      0 |   0 |                3 |                0 |             0 |
|              3 |      3 |      0 |   0 |                6 |                0 |             0 |
|              4 |      4 |      0 |   0 |               10 |                0 |             0 |
|              5 |      5 |      0 |   0 |               15 |                0 |             0 |
|              6 |      6 |      0 |   0 |               21 |                0 |             0 |
|              7 |      7 |      0 |   0 |               28 |                0 |             0 |
|              8 |      8 |      1 |   0 |               36 |                1 |             0 |
|              9 |      9 |      1 |   1 |               45 |                2 |             1 |
|             10 |     10 |      2 |   2 |               55 |                4 |             3 |

| Objetivo                             |                    Coste total |
|:-------------------------------------|-------------------------------:|
| Una herramienta al nivel 10          |   55 piedra + 4 Brillo + 3 Oro |
| Hacha, martillo y espada al nivel 10 | 165 piedra + 12 Brillo + 9 Oro |

### Efecto del hacha

Los porcentajes son acumulados respecto al hacha sin mejorar. La
probabilidad genera **1 madera adicional** en una acción de tala; no
añade cantidades fraccionarias.

| Nivel | Velocidad de tala | Probabilidad de +1 madera |
|------:|------------------:|--------------------------:|
|     0 |               0 % |                       0 % |
|     1 |             +0.5 % |                       0 % |
|     2 |             +1 % |                       0.5 % |
|     3 |             +1.5 % |                       1 % |
|     4 |             +2 % |                      1.5 % |
|     5 |             +2.5 % |                      2 % |
|     6 |             +3 % |                      5 % |
|     7 |             +3.5 % |                      10 % |
|     8 |             +4 % |                      15 % |
|     9 |             +4.5 % |                      20 % |
|    10 |             +5 % |                      30 % |

### Efecto del martillo

La probabilidad genera **1 piedra adicional** al completar una acción de
extracción. La velocidad acumulada no supera el `+5 %`.
| Nivel | Velocidad de romper piedra | Probabilidad de +1 piedra |
|------:|------------------:|--------------------------:|
|     0 |               0 % |                       0 % |
|     1 |             +0.5 % |                       0 % |
|     2 |             +1 % |                       0.5 % |
|     3 |             +1.5 % |                       1 % |
|     4 |             +2 % |                      1.5 % |
|     5 |             +2.5 % |                      2 % | Permite extraer de nodos de piedra de nivel 2, de mayor tamaño
|     6 |             +3 % |                      5 % |
|     7 |             +3.5 % |                      10 % |
|     8 |             +4 % |                      15 % |
|     9 |             +4.5 % |                      20 % |
|    10 |             +5 % |                      30 % |

El tamaño, resistencia, tiempo base y rendimiento exactos de los nodos
de piedra de nivel 2 quedan pendientes de balance.

### Efecto de la espada

| Nivel | Daño adicional acumulado |
|------:|-------------------------:|
|     0 |                       +0 |
|     1 |                    +0,25 |
|     2 |                    +0,50 |
|     3 |                    +0,75 |
|     4 |                    +1,00 |
|     5 |                    +1,25 |
|     6 |                    +1,50 |
|     7 |                    +1,75 |
|     8 |                    +2,00 |
|     9 |                    +2,25 |
|    10 |                    +2,50 |

Con el daño base actual del Guardián (`2`), la espada de nivel 10
alcanzaría `4,5` de daño por golpe. Conviene probarlo contra los 5 HP
actuales del bárbaro antes de fijar el valor definitivo.

## 7. Campamentos, regiones y cuevas

| Contenido            | Riesgo   | Recompensas recomendadas                        | Función en la progresión                                      |
|:---------------------|:---------|:------------------------------------------------|:--------------------------------------------------------------|
| Regiones iniciales   | Bajo     | Comida y madera                                 | Supervivencia y primeras transformaciones.                    |
| Bosques avanzados    | Medio    | Mayor acceso a madera                           | Financiar especializaciones y campamentos.                    |
| Pedregales avanzados | Medio    | Piedra; nodos de nivel 2 tras martillo +5       | Financiar mejoras de herramientas.                            |
| Ruinas               | Medio    | Brillo                                          | Financiar transformaciones legendarias y habilidades futuras. |
| Campamentos          | Alto     | Oro, comida, madera y XP                        | Preparar mejoras avanzadas y desbloquear regiones.            |
| Campamentos de élite | Muy alto | Más Oro y Fragmentos de reliquia                | Recompensar combates de mayor dificultad.                     |
| Cuevas               | Alto     | Piedra, Brillo, cofres y Fragmentos de reliquia | Financiar expediciones y mejoras especiales.                  |
| Jefes regionales     | Muy alto | Llave de barrera y recompensa única             | Abrir regiones y marcar hitos de progreso.                    |

### Expediciones y clases legendarias

| Acción dentro de una cueva | Coste propuesto | Regla                                                      |
|:---------------------------|----------------:|:-----------------------------------------------------------|
| Mago temporal adicional    |        6 Brillo | Máximo 2 Magos dentro, contando el inicial si corresponde. |
| Pícaro temporal adicional  |        7 Brillo | Máximo 2 Pícaros dentro.                                   |
| Paladín temporal adicional |        8 Brillo | Máximo 2 Paladines dentro.                                 |

Las unidades adicionales de cueva son temporales y desaparecen al salir;
no se incorporan a la tribu exterior. Los costes son provisionales y
deben ajustarse según disponibilidad de Brillo y dificultad de cada
cueva.

### Recurso avanzado propuesto

| Recurso               | Obtención                                       | Usos potenciales                                                                              |
|:----------------------|:------------------------------------------------|:----------------------------------------------------------------------------------------------|
| Fragmento de reliquia | Cofres especiales, campamentos de élite y jefes | Rangos avanzados de tecnologías, habilidades legendarias y mejoras especiales de herramientas |

No conviene añadir más monedas comunes por ahora. El Fragmento de
reliquia debe ser escaso y estar ligado a contenido de riesgo alto.

## 8. Ritmo de progresión esperado

| Fase            | Niveles orientativos | Objetivo                                              | Recursos principales          |
|:----------------|---------------------:|:------------------------------------------------------|:------------------------------|
| Supervivencia   |                  1–3 | Asegurar comida, madera y composición básica          | Comida, madera                |
| Especialización |                  4–6 | Artesana, Guardián y primeras mejoras de herramientas | Madera, piedra, oro           |
| Expansión       |                 7–10 | Campamentos, regiones nuevas y mejoras intermedias    | Piedra, oro, Brillo           |
| Expediciones    |                11–14 | Cuevas, élites, jefes y equipo avanzado               | Brillo, oro, piedra           |
| Maestría        |                15–19 | Tecnologías especializadas y mejoras de nivel alto    | Todos; Fragmentos de reliquia |

Los niveles son referencias de ritmo, no bloqueos absolutos para entrar
en una región. Las llaves y los jefes siguen siendo la barrera principal
de progresión territorial.

## 9. Orden recomendado de incorporación

| Orden | Sistema                         | Qué validar antes de ampliarlo                                                    |
|------:|:--------------------------------|:----------------------------------------------------------------------------------|
|     1 | Economía base                   | Tiempos y cantidades de comida/madera; acceso de emergencia a madera.             |
|     2 | Mejoras de herramientas 1–5     | Producción por minuto, velocidad de extracción y efecto de la probabilidad extra. |
|     3 | XP y tres árboles               | Ritmo de subida, puntos disponibles y decisiones de especialización.              |
|     4 | Mejoras 6–10 con costes mixtos  | Disponibilidad de Brillo/Oro y coste total al mejorar varias herramientas.        |
|     5 | Regiones y campamentos          | Riesgo, recompensas y utilidad de los recursos obtenidos.                         |
|     6 | Cuevas y Fragmentos de reliquia | Duración, coste, recompensas y persistencia de la expedición.                     |

**Criterio de balance:** medir recursos obtenidos y gastados por minuto,
no solo el coste nominal. Una mejora es demasiado fuerte si acelera
tanto la recolección que financia la siguiente mejora con demasiada
facilidad; es demasiado débil si tarda demasiado en amortizarse o no
cambia decisiones de juego.

## 10. Decisiones pendientes

| Tema             | Pendiente                                                                                                                   |
|:-----------------|:----------------------------------------------------------------------------------------------------------------------------|
| Mago             | La transformación exterior cuesta 2 Brillo y se limita a 1 Mago. Los costes y límites de reclutamiento temporal en cuevas siguen pendientes. |
| Pícaro y Paladín | Confirmar si usan la misma transformación de Recolector y aprobar sus curvas de Brillo.                                     |
| Herramientas     | Validar probabilidades de recurso extra y rendimiento de nodos de piedra de nivel 2.                                        |
| XP repetible     | Decidir cómo se recompensa la derrota de bárbaros que reaparecen.                                                           |
| Árboles          | Definir efectos concretos y prerrequisitos finales de cada tecnología.                                                      |
| Cuevas           | Definir usos de piedra y Brillo, botín de cofres y costes temporales definitivos.                                           |
| Reliquias        | Definir costes y efectos antes de introducir Fragmentos de reliquia en la economía.                                         |

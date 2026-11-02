# ROADMAP — Tribes Revival

**Propósito:** organizar el trabajo de implementación en hitos. Cada hito apunta a sistemas definidos en el GDD; las reglas detalladas viven allí, no se duplican aquí. El estado real de implementación se registra en `IMPLEMENTATION_STATUS.md`.

## Base técnica y sistemas existentes

Los hitos 0–5 establecieron la migración a 3D, el movimiento del tótem y formación, supervivencia, recursos, combate, progresión, menú/tutorial y guardado. Su estado registrado está en `IMPLEMENTATION_STATUS.md`; no usar esta sección como prueba de validación del repositorio actual.

## Hito 6 — Mejoras de herramientas y clases legendarias

**Referencia de diseño:** GDD, secciones 11–12.

- [ ] Validar manualmente menú, coste, niveles, efectos, límites y feedback visual de mejoras (la implementación está presente en el código local; ver `IMPLEMENTATION_STATUS.md`).
- [ ] Validar manualmente el Mago y completar Pícaro y Paladín cuando se decidan sus costes exteriores.
- [ ] Definir las curvas de coste de Pícaro y Paladín antes de fijar su balance.

## Hito 7 — Fronteras, campamentos y jefes

**Referencia de diseño:** GDD, sección 13.

- [ ] Implementar barreras de energía oscura y regiones bloqueadas.
- [ ] Implementar campamentos, grupos de enemigos y arquero bárbaro.
- [ ] Implementar jefes, llaves únicas y desbloqueo de la barrera correspondiente.
- [ ] Persistir regiones y llaves en guardado/carga.

## Hito 8 — Cuevas y expediciones legendarias

**Referencia de diseño:** GDD, sección 14.

- [ ] Implementar entradas y mapas interiores de cuevas.
- [ ] Implementar entrada exclusiva de la clase legendaria activa.
- [ ] Implementar reclutamiento temporal interior y límites por clase.
- [ ] Implementar encuentros, jefes, cofres, botín y persistencia entre visitas y guardados.
- [ ] Resolver los detalles de diseño pendientes antes de cerrar el hito.

## Hito 9 — Dirección visual y presentación

**Referencia de diseño:** GDD, sección 16.

- [ ] Sustituir geometría provisional por modelos propios low-poly.
- [ ] Añadir animaciones de caminar, trabajar, combatir e idle.
- [ ] Finalizar materiales y elementos modulares del entorno.
- [ ] Añadir audio y feedback de combate/recolección.
- [ ] Evaluar postprocesado opcional sin acoplarlo al gameplay.

## Hito 10 — Guardado y migración ampliada

**Referencia de diseño:** GDD, sección 15; diseño técnico: `TECHNICAL_DESIGN.md`.

- [ ] Añadir al estado persistente niveles de herramientas, clases legendarias, regiones, llaves y estados de cuevas/cofres.
- [ ] Ampliar `GameState` desde la versión actual 17 y conservar la migración existente desde la versión 16, con valores por defecto seguros para los campos nuevos.
- [ ] Validar ida y vuelta de guardado/carga y conservar inventario, unidades, nivel, XP, tecnologías y mundo generado.
- [ ] Confirmar que las unidades temporales de cuevas no pasan al grupo exterior guardado.

## Reglas de planificación

- No añadir hitos online: el proyecto es local para un jugador.
- No planificar una condición de victoria hasta que se diseñe y se añada al GDD.
- Si cambia el diseño, actualizar primero el GDD y después ajustar este roadmap.
- Los criterios de aceptación se mantienen en `QA_TEST_PLAN.md`; no duplicarlos aquí.

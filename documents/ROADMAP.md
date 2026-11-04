# ROADMAP — Tribes Revival

**Propósito:** organizar el trabajo de implementación en hitos. Cada hito apunta a sistemas definidos en el GDD; las reglas detalladas viven allí, no se duplican aquí. El estado real de implementación se registra en `IMPLEMENTATION_STATUS.md`.

## Base técnica y sistemas existentes

Los hitos 0–5 establecieron la migración a 3D, el movimiento del tótem y formación, supervivencia, recursos, combate, progresión, menú/tutorial y guardado. Su estado registrado está en `IMPLEMENTATION_STATUS.md`; no usar esta sección como prueba de validación del repositorio actual.

- [x] Incorporar idle dinámico determinista y reagrupación sin trabajo.
- [x] Integrar evitación local entre minions y preferencia por posiciones idle visibles.
- [ ] Validar manualmente cruces, cesión de paso y visibilidad con 2 y 8 minions.
- [ ] Validar manualmente paseos, interrupciones, retorno solo al rango y formación exclusiva al mover el tótem con 2 y 8 minions.

## Hito 6 — Mejoras de herramientas y clases legendarias

**Referencia de diseño:** GDD, secciones 11–12.

- [x] Centralizar e implementar las curvas exteriores de Recolector, especializaciones, Mago, Escudo y mejoras 0–10; queda validación manual de balance/HUD.
- [x] Integrar la primera iteración de tres árboles con las tecnologías actuales y sus requisitos; ver estado y evidencia en `IMPLEMENTATION_STATUS.md`.
- [ ] Validar manualmente navegación, reflujo y compras en los tres árboles.
- [ ] Validar manualmente menú, costes mixtos, niveles, efectos, límites y feedback visual de mejoras.
- [ ] Validar manualmente el Mago exterior (1 Mago, 2 Brillo) y completar Pícaro y Paladín cuando se decidan sus costes exteriores.
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

## Hito 10 — Guardado y migración ampliada (diferido)

Este hito se pospone para una fase avanzada del proyecto. El flujo actual de
guardar y cargar funciona; no dedicar trabajo ahora a probar ni ampliar la
compatibilidad entre versiones antiguas y nuevas. Reactivar este hito cuando
el alcance de persistencia del juego esté más completo.

**Referencia de diseño:** GDD, sección 15; diseño técnico: `TECHNICAL_DESIGN.md`.

- [ ] Añadir al estado persistente niveles de herramientas, clases legendarias, regiones, llaves y estados de cuevas/cofres.
- [ ] Ampliar `GameState` desde la versión actual 17 y conservar la migración existente desde la versión 16, con valores por defecto seguros para los campos nuevos.
- [ ] En la fase avanzada, validar ida y vuelta y compatibilidad entre versiones, conservando inventario, unidades, nivel, XP, tecnologías y mundo generado.
- [ ] Confirmar que las unidades temporales de cuevas no pasan al grupo exterior guardado.

## Reglas de planificación

- No añadir hitos online: el proyecto es local para un jugador.
- No planificar una condición de victoria hasta que se diseñe y se añada al GDD.
- Si cambia el diseño, actualizar primero el GDD y después ajustar este roadmap.
- Los criterios de aceptación se mantienen en `QA_TEST_PLAN.md`; no duplicarlos aquí.

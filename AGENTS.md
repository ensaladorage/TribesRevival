# AGENTS.md --- Instrucciones para Codex

Este archivo se encuentra en la raíz del repositorio. La documentación
del proyecto está en `documents/`.

## Fuentes de verdad

Antes de modificar el proyecto, consulta los documentos relevantes:

-   `documents/README_DOCUMENTACION.md`: índice y precedencia
    documental.
-   `documents/GDD_Tribes_Revival_v0.6.0.md`: fuente de verdad para
    pilares, alcance, mecánicas y comportamiento deseado del juego.
-   `documents/TECHNICAL_DESIGN.md`: arquitectura, contratos
    técnicos y restricciones de implementación.
-   `documents/ROADMAP.md`: hitos y orden de implementación.
-   `documents/IMPLEMENTATION_STATUS.md`: estado conocido de
    implementación; actualizarlo cuando el usuario confirme cambios de
    estado o cuando el trabajo ejecutado los verifique.
-   `documents/QA_TEST_PLAN.md`: cobertura y criterios de
    validación.
-   `documents/RESEARCH_Wanderers_io.md`: contexto histórico
    únicamente, no especificación de requisitos.

## Reglas de trabajo

- Hasta indicación explícita del usuario, no mostrar números con decimales en
  ninguna interfaz del juego, incluidos tooltips, tecnologías, mejoras, slots
  y debug. Usar `godot/scripts/ui/player_numbers.gd` para los nuevos textos
  numéricos. Conservar la precisión interna de la simulación y los guardados;
  Los porcentajes de eficiencia y el daño pueden mostrar decimales por
  indicación explícita del usuario; recursos, experiencia y puntos de
  tecnologías siempre se muestran como enteros.

1.  No mezclar diseño, planificación, estado y QA en el GDD. Si cambia
    una mecánica del juego, actualizar el GDD; si cambia el orden de
    trabajo, actualizar el roadmap; si una tarea se implementa o valida,
    actualizar el estado; si se añade o cambia cobertura de pruebas,
    actualizar el plan de QA.
2.  El juego es local para un jugador. No introducir multijugador,
    sincronización online ni servicios remotos sin una decisión
    explícita del usuario.
3.  No inventar reglas que el GDD deja pendientes. Entre otras:
    condición de victoria, costes de Pícaro/Paladín, uso de
    piedra/Brillo dentro de cuevas y balance exacto de
    jefes/campamentos.
4.  No convertir referencias de Wanderers.io en requisitos
    automáticamente. Los hechos históricos y las decisiones propias
    deben mantenerse separados.
5.  Preservar determinismo, separación entre simulación lógica y
    renderizado, y compatibilidad de guardados cuando corresponda. No
    permitir que meshes, DOM o materiales gobiernen el estado de juego.
6.  Implementar cambios pequeños y acotados. Inspeccionar el código
    existente antes de editar; reutilizar patrones y tipos actuales;
    evitar refactors amplios no solicitados.
7.  Ejecutar las pruebas relevantes disponibles después de los cambios.
    No afirmar que algo está validado manualmente si solo se ejecutaron
    tests automáticos, ni afirmar que los tests pasan sin ejecutarlos.
8.  Al terminar una tarea, informar brevemente: cambios realizados,
    archivos modificados, pruebas ejecutadas y limitaciones o validación
    manual pendiente. Actualizar
    `documents/IMPLEMENTATION_STATUS.md` solo con estados
    respaldados por evidencia.
9.  Si el diseño es ambiguo y la decisión afecta a una mecánica o al
    guardado, pedir aclaración antes de fijar una regla irreversible.
    Para detalles internos no ambiguos, seguir los patrones del
    proyecto.

## Restricciones de alcance conocidas

-   Límite de la tribu exterior: 8 unidades.
-   Solo una clase legendaria activa en el exterior.
-   Solo Mago, Pícaro y Paladín pueden entrar en cuevas; la tribu
    ordinaria permanece fuera.
-   En cuevas: máximo dos unidades por clase y seis en total; las
    unidades adicionales son temporales y desaparecen al salir.
-   Las cuevas deben conservar enemigos derrotados, cofres abiertos,
    botín recogido y llaves obtenidas.
-   La condición de victoria está sin diseñar; no añadir Gran Hoguera,
    piedras de memoria ni rito final como mecánica actual.

## Mantenimiento de documentación

-   Mantener este `AGENTS.md` en la raíz del repositorio.
-   Mantener todos los documentos de diseño, planificación, estado, QA e
    investigación dentro de `documents/`.
-   Usar rutas relativas desde la raíz al consultar documentos desde
    este archivo.
-   No duplicar el contenido del GDD en el roadmap ni el estado de
    implementación en el GDD.

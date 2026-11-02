El archivo `AGENTS.md` se mantiene en la raíz del repositorio. Los demás
documentos de este índice se encuentran en esta carpeta
(`documents/`).

# Tribes Revival --- Índice de documentación

Este conjunto separa diseño, arquitectura, planificación, estado y
validación para que cada documento tenga una responsabilidad clara.

  --------------------------------------------------------------------------------
  Documento                        Propósito               Cuándo actualizarlo
  -------------------------------- ----------------------- -----------------------
  `GDD_Tribes_Revival_v0.6.0.md`   Diseño del juego:       Cuando se aprueba o
                                   pilares, alcance,       cambia el diseño
                                   controles, sistemas y
                                   reglas, estén
                                   implementados o no

  `TECHNICAL_DESIGN.md`            Arquitectura, contratos Cuando cambia la
                                   y especificaciones      solución técnica o un
                                   técnicas                contrato

  `ROADMAP.md`                     Hitos y orden de        Cuando cambia la
                                   implementación          planificación

  `IMPLEMENTATION_STATUS.md`       Implementado, validado  Cuando el estado real
                                   y pendiente             cambia y hay evidencia

  `QA_TEST_PLAN.md`                Pruebas y criterios de  Cuando cambian
                                   aceptación              requisitos de
                                                           validación o cobertura

  `AGENTS.md`                      Instrucciones de        Cuando cambian las
                                   trabajo para Codex      reglas de colaboración
                                                           o fuentes de verdad

  `RESEARCH_Wanderers_io.md`       Investigación histórica Cuando se añade o
                                   de la referencia        corrige evidencia de la
                                                           referencia
  --------------------------------------------------------------------------------

## Precedencia

1.  El GDD manda sobre el comportamiento deseado del juego.
2.  El diseño técnico concreta cómo expresarlo en la arquitectura
    actual, sin cambiar la mecánica por su cuenta.
3.  El roadmap organiza el trabajo, pero no añade requisitos de juego.
4.  El estado registra hechos de implementación; nunca convierte una
    tarea pendiente en diseño aprobado.
5.  QA verifica los requisitos, pero no debe inventarlos.
6.  La investigación sirve de contexto, no de especificación automática.

## Nota de migración

Estos documentos se han separado a partir de
`GDD_Tribes_Revival_v0.5.0.md`. Antes de borrar el documento anterior,
comparar la información técnica y de diseño con el repositorio y
conservarlo como referencia histórica si fuera necesario.

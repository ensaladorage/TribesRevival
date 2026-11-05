# Estado de migración a Godot

Actualizado: 2026-11-05. Rama: `migration/godot`. Objetivo completo: activo.

## Continuidad

- Última fase completada: F1 (base); F0 (auditoría) completada.
- Fase actual: F2, cámara y controles.
- Próxima tarea ejecutable: portar cámara, input semántico y estado del tótem.
- Ejecución local: abrir `godot/project.godot` con el ejecutable local
  `godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2 confirmado).
- Comparación original: `npm run dev`, ruta `/TribesRevival/`.

## Tabla de progreso

| Fase | Estado |
|---|---|
| F0 auditoría | Completada: 42 archivos con hashes/imports; originales verificados |
| F1 base | Completada: editor importa, 1 script y 1 escena válidos; arranque sin ticks |
| F2 controles | Pendiente |
| F3 determinismo/mundo | Pendiente |
| F4 economía/progresión | Pendiente |
| F5 IA/recolección | Pendiente |
| F6 combate/clima | Pendiente |
| F7 compras/equipo | Pendiente |
| F8 UI/guardado | Pendiente |
| F9 integración/exportación | Pendiente |

## Pruebas y límites

- Ejecutable local: versión 4.7.2.stable.official.ed1daf0bf.
- Game Development Studio CLI 1.5.1 disponible; capabilities/doctor consultados.
  Proveedores de pago no configurados; no son necesarios para placeholders.
  No se solicitan ni ejecutan capturas GPU o pruebas visuales automatizadas.
- F1: `bash godot/tools/validate.sh` correcto (editor headless, carga e
  inicialización de escena sin frames de gameplay; 42 originales intactos).
  `git diff --check` correcto. Informes locales: `reports/f1-validation.log`.
- Sin validación manual ni prueba de gameplay; no se afirma paridad todavía.
- Export templates, builds Windows/Linux y web todavía no comprobados.
- Pendientes de diseño heredados: cuevas/jefes/regiones y costes de Pícaro/
  Paladín. No bloquean la migración de los sistemas que sí existen.
- El original mantiene guardados del navegador; portarlos a `user://` no
  implica acceso al localStorage desde Godot.

## Cambios

- F0/F1: plan, inventario, proyecto Compatibility, escena mínima y validador
  estructural sin avanzar el juego. Original Babylon sin cambios.

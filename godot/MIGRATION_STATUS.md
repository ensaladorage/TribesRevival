# Estado de migración a Godot

Actualizado: 2026-11-05. Rama: `migration/godot`. Objetivo completo: activo.

## Continuidad

- Última fase completada: F4 (economía/progresión). F0, F1 y F3 completadas.
- Fase actual: F5 (IA/recolección); F2 sigue abierta por pendientes manuales.
- Próxima tarea ejecutable: portar geometría/navegación/idle/reglas de tareas,
  integrar seguimiento y representar el mundo generado.
- Ejecución local: abrir `godot/project.godot` con el ejecutable local
  `godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2 confirmado).
- Comparación original: `npm run dev`, ruta `/TribesRevival/`.

## Tabla de progreso

| Fase | Estado |
|---|---|
| F0 auditoría | Completada: 42 archivos con hashes/imports; originales verificados |
| F1 base | Completada: editor importa, 1 script y 1 escena válidos; arranque sin ticks |
| F2 controles | Cámara/arrastre/zoom/pausa/velocidad/debug implementados; flecha, ajustes y revisión manual pendientes |
| F3 determinismo/mundo | Completada: estados iniciales completos equivalentes en 4 semillas |
| F4 economía/progresión | Completada: tablas/XP/tecnologías/costes y bonuses verificados; integración de compras sigue en F7 |
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
- F2a: cámara ortográfica 45°/35°, altura 72 × zoom 0.5–1, arrastre directo,
  límites 2–158 m, scroll de borde a 32 m/s y recentrado a 4.5; cola de acciones,
  driver 20 Hz/máximo 4 ticks, pausa/1–3/debug y cancelación al perder foco.
  Importación y arranque estructural correctos: 4 scripts/1 escena, sin ticks.
  Informe `reports/f2-validation.log`. Sin playtest. Falta flecha de arrastre,
  sliders de zoom y revisión manual; F2 no se declara completada.
- Mientras no se migre formación (F5), `totem.moving` conserva la orden de
  marcha después de soltar; hay unidades en el estado, todavía sin vista ni comportamiento autónomo.

- F3: portados FNV-1a UTF-16/Mulberry32 bit a bit, 23 biomas por mundo Hito 3,
  nodos y rendimientos, ramitas, decoración, cinco bárbaros, seis conejos,
  roster inicial y estado v17 completo. `generate_reference.mjs` obtiene
  referencias de TypeScript sin modificarlo ni ejecutar el loop.
- F3 verificada: `bash godot/tools/validate.sh` correcto; 6 scripts/1 escena,
  10.764 comparaciones de paridad sobre 4 semillas (incluye Unicode/emoji),
  tolerancia numérica 1e-9, 42 originales intactos.
  Informe `reports/f3-validation.log`. Esto valida datos, no gameplay ni píxeles.

- F4: economía y progresión puras portadas, incluidas curvas por composición
  viva, escudo, costes mixtos, efectos 0–10, bonus determinista, requisito de
  martillo +5, XP y las tres tecnologías vigentes. Sin cambios de balance.
- F4 verificada: editor/8 scripts/1 escena correctos; 11.302 comparaciones
  de paridad e invariantes (incluyen 128 tiradas de bonus), compras atómicas
  fallidas/exitosas y límites de nivel/recompra/requisito tecnológico.
  `npm test -- src/simulation/economyConfig.test.ts`: 4/4 pruebas puras.
  Informe `reports/f4-validation.log`; originales intactos; Vite HTTP 200.

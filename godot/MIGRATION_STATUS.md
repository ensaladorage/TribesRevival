# Estado de migración a Godot

Actualizado: 2026-11-05. Rama: `migration/godot`. Objetivo completo: activo.

## Continuidad

- Última fase completada: F4 (economía/progresión). F0, F1 y F3 completadas.
- Fase actual: F8 (guardado/menús implementados; feedback en curso).
- Próxima tarea ejecutable: completar feedback visible (vida/alertas/efectos/
  nubes/hogueras) y preparar exports; revisar manualmente F2/F5/F6/F7/F8.
- Ejecución local: abrir `godot/project.godot` con el ejecutable local
  `godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2 confirmado).
- Comparación original: `npm run dev`, ruta `/TribesRevival/`.

## Tabla de progreso

| Fase | Estado |
|---|---|
| F0 auditoría | Completada: 42 archivos con hashes/imports; originales verificados |
| F1 base | Completada: editor importa, 1 script y 1 escena válidos; arranque sin ticks |
| F2 controles | Cámara/arrastre/flecha/zoom/pausa/velocidad/debug y ajustes implementados; revisión manual pendiente |
| F3 determinismo/mundo | Completada: estados iniciales completos equivalentes en 4 semillas |
| F4 economía/progresión | Completada: tablas/XP/tecnologías/costes y bonuses verificados; integración de compras sigue en F7 |
| F5 IA/recolección | Implementada base, seguimiento/idle/navegación/trabajo; pendiente revisión manual e integración de conflicto F6 |
| F6 combate/clima | Lógica integrada; efectos/vida/alertas/nubes/sonido y playtest pendientes |
| F7 compras/equipo | Comandos/drag-to-equip/HUD básico implementados; validación manual pendiente |
| F8 UI/guardado | Menús/tutorial/slots/confirmación/reinicio implementados; feedback/revisión manual pendientes |
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
- Export templates: carpeta local vacía verificada; faltan templates 4.7.2.
  Builds Windows/Linux/web todavía pendientes.
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
  Informe `reports/f2-validation.log`. Sin playtest. Flecha y sliders de zoom se incorporan en F7;
  revisión manual pendiente, F2 no se declara completada.
- F5 incorpora formación y libera la orden de marcha al llegar las unidades.
  F6 conecta combate, fauna móvil, clima y curación; falta presentar su feedback.

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

- F5a: portadas reglas puras de tareas/afinidad, navegación continua, grafo
  de visibilidad, continuidad de evasión, idle, llamadas de entidades y
  posiciones de combate. Ordenación estable explícita donde TS la garantiza.
- F5b: seguimiento 10 m/s, retorno al rango 8 m/s, trabajo 6 m/s e idle
  3 m/s; tickets y llamadas de recursos, acciones transaccionales, drops
  físicos unitarios, recolección al inventario y XP. Cancelación y separación
  residual respetan tótem/trabajadores. Vista provisional del mundo y actores
  con interpolación entre ticks; contadores provisionales de inventario/XP.
- F5 verificación técnica: editor e inicialización estructural de 18 scripts
  y 1 escena sin errores, 11.766 comparaciones de datos/reglas/geométría
  contra TS, incluyendo cruces, rutas con obstáculos, idle/bordes, llamadas,
  reservas de combate y proyección de reclutamiento/despeje del tótem.
  Informe `reports/f5-work-validation.log`. Cero ticks de gameplay automatizados.
- F5 NO completada: revisión manual de navegación/recolección con 2/8
  minions pendiente; llamadas de combate y saqueo esperan integración F6;
  herramientas/vida/efectos aún no tienen su representación final.

- F6a: lógica de combate/caza/fuga, plazas, reservas de movimiento enemigo,
  patrullas, reaparición 60/30 s, botín/saqueo, alertas/efectos temporales,
  curación por hoguera, derrota y clima con reposición de madera/comida.
  Orden 20 Hz: clima → cooldowns → conflicto → trabajo → separación →
  hogueras → efectos. Los valores provienen del código vigente.
- F6 verificación técnica: importación/21 scripts/1 escena sin errores;
  paridad de estadísticas, daño y curación contra TS añadida a las reglas
  puras. Informe `reports/f6-validation.log`. No se ejecutó combate, clima
  ni gameplay automatizado; F6 no se declara completa.
- F6 pendiente: barras de vida, alertas, animaciones/sonido, cadáveres,
  hogueras y nubes visibles; probar manualmente daño/retirada/respawn/lluvia.

- F7: comandos atómicos separados, población máxima 8, especializaciones,
  protección de proveedor de comida, 1 Mago exterior por 2 Brillo, Escudo,
  mejoras, tecnologías y debug. Interfaz nativa lateral y paneles excluyentes
  cerrados por defecto; arrastrar/comprar/equipar con tolerancia de 24 px.
  Preview libre; solo el spawn se proyecta a 15 m. No se dibuja anillo de
  reclutamiento. Arrastre del tótem sin retraso visual, flecha y ajustes zoom.
- F7 verificación: 23 scripts/1 escena importados/inicializados sin errores;
  12.670 comparaciones de paridad/reglas puras, incluidas cinco transacciones
  económicas contra TS (cap 8, 1 Mago, último proveedor, Escudo, coste mixto
  fallido). No se avanzó el loop de gameplay ni se automatizó UI.
  Informe `reports/f7-validation.log`. F7 no cerrada por playtest pendiente.

- F8a: repositorio nativo de tres slots JSON v17 bajo `user://saves`,
  escritura con temporal/backup, errores de I/O, metadatos, fase normalizada
  y borrado de un slot con confirmación desde UI. Prueba de ida/vuelta actual
  en directorio aislado; no se amplía la matriz histórica ni se importan
  automáticamente guardados del navegador.
- F8b: menú principal/tutorial/carga principal opacos; pausa/carga desde
  pausa translúcidas. Pausa congela simulación y bloquea controles del mapa.
  Carga enfoca inmediatamente el tótem; reinicio restaura nueva partida.
  Confirmaciones de borrar/reemplazar y pérdida de cambios sin guardar.
- F8c: reutilizados 13 iconos propios existentes sin alterar sus bytes,
  recibo `audit/ui_assets.json`. Contadores en el orden actual del juego.
  Auditoría ampliada a los 838 archivos versionados originales (incluidos
  arte, documentación y configuración), todos intactos.
- La importación detectó un uso incorrecto de `icon_max_width` como propiedad;
  corregido a constante de tema. Nueva validación completa posterior correcta:
  25 scripts/1 escena, 15.304 comparaciones y guardado actual, sin ticks de
  gameplay. Informe `reports/f8-menu-validation.log`. Sin validación visual.
- F9 preparación independiente: iniciada instalación de templates oficiales
  4.7.2 con SHA256 publicado; proceso debe consultarse hasta su resultado.

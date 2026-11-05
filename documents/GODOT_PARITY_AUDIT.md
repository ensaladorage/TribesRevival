# Auditoría de paridad — 2026-11-05

Las rutas de scripts e informes de esta tabla son relativas a `godot/`.

Esta tabla compara el objetivo completo con el estado del proyecto. La
presencia de código y una exportación correcta no demuestran por sí solas
equivalencia funcional. La revisión manual está en `GODOT_MANUAL_QA.md`: el
usuario confirma menús, arrastre/seguimiento/recolección y equipo/mejoras/
tecnología/combate básicos y reclutamiento consecutivo corregido tras su aviso.
Especifica que usó el ejecutable Linux y confirma corregido el lag en los
bordes del mundo con 8 unidades, así como hoguera, lluvia y derrota/reinicio.
Windows manual aplazado por petición del usuario; QA se centra en Linux.
Los demás casos siguen pendientes.
La migración completa todavía no está acreditada.

| Requisito | Evidencia actual | Falta para acreditarlo completamente |
|---|---|---|
| Rama exclusiva, original intacto | `migration/godot`; 838 hashes de archivos originales en `audit/source_inventory.json`, verificados por `tools/verify_original.py` | Mantener la comprobación en cada cambio |
| Godot 4/GDScript/Compatibility | `project.godot`, 33 scripts/72 escenas, escena principal importada e inicializada headless; arranque gráfico Linux confirmado por usuario | Mantener estos contratos y terminar QA restante |
| Escena 3D y cámara | Contratos cotejados, validación técnica; usuario confirma cámara/zoom/arrastre/bordes con 8 unidades y Esc/velocidades; F2 cerrada en Linux | Mantener contratos y resolver los otros bloques de QA |
| Estado y mundo deterministas | PRNG bit exacto UTF-16/Mulberry32 y estados iniciales completos comparados con TS en 4 semillas, incluida Unicode/emoji | Vista/generación percibida en partida |
| Tótem/minions/IA/navegación | `minion_movement.gd`, `navigation.gd`, `minion_idle.gd`, `work_system.gd`; funciones puras comparadas con TS; usuario confirma arrastre/seguimiento y bordes con 8 unidades | Cruces, llamadas, obstáculos e interrupciones de F5 |
| Recolección/economía | Afinidades, tickets, llamadas, tiempos, drops unitarios, inventario y tablas portados; transacciones/reglas puras verificadas; usuario confirma recolección y aumento del inventario | Interrupción y continuidad en los casos restantes de QA |
| Combate/salud/fauna/loot | `conflict_system.gd`, `combat_rules.gd`, `survival_system.gd`; estadísticas/daño/curación comparados con TS; usuario confirma combate, daño/botín, derrota/reinicio y HP legibles con zoom/daño/curación | Huida, respawn y casos restantes de QA |
| Compras/equipo/legendarias | Reglas comparadas con TS; usuario confirma equipo/reclutamiento, 8 unidades, preview/cancelación, Mago único y Escudo +1 HP sin repetición en Linux | Distinción visual confirmada por usuario; tras refactor AnimatedSprite3D, repetición final pendiente |
| Herramientas/XP/tecnologías | Tablas 0–10, bonus, XP y tres tecnologías vigentes con requisitos/costes compartidos; usuario confirma mejora/tecnología básica; HUD de puntos y paneles alineado al original | Resto de niveles/requisitos y revisión manual del HUD actualizado |
| Clima/hogueras | Sistemas portados en el orden original; usuario confirma lluvia y curación con hoguera en Linux | Casos específicos de reposición/expiración/distancia y restante QA |
| HUD/menús/tutorial | Controles nativos, 13 iconos originales verificados; usuario confirma Tutorial, Guardar/Cargar y retorno al principal tras arreglo de callbacks; regresión aislada de señales y Esc | Resto del HUD, foco/teclado (incluido Esc corregido), tooltips, opacidad y legibilidad manuales |
| Guardado local actual | Tres slots/JSON v17 e ida/vuelta aislada; usuario confirma tres slots tras cerrar/reabrir, cargar desde principal/pausa, cancelar borrado y eliminar solo el elegido en Linux | Mantener el flujo; migraciones antiguas diferidas |
| Exportación Windows/Linux | Presets x86_64, templates oficiales 4.7.2 verificados por SHA256; formatos PE/ELF confirmados; Linux inicia headless y usuario confirma recorridos funcionales | QA Linux restante; prueba Windows aplazada expresamente por el usuario |
| Exportación web secundaria | Exportación actualizada HTML/JS/PCK/WASM sin threads, servida localmente (HTTP 200) | Revisar en navegador manualmente |
| Pruebas permitidas | Importación/carga/inicialización, paridad/reglas puras, guardado actual; arranque del menú Linux sin entrar en partida | No sustituir el playtest del usuario por automatización de gameplay o imágenes |
| Continuidad y commits | Plan/status en esta carpeta, commits locales por subhito técnico; sin push | Actualizar con evidencia manual y builds definitivos de la migración |

## Límites preservados

- No se añaden multijugador, servicios remotos de juego ni una victoria.
- Regiones/barreras, campamentos/jefes/llaves y cuevas no están implementados
  en el original: siguen pendientes, sin inventar encuentros ni balance.
- No se crean Pícaro/Paladín ni costes no aprobados. El Mago conserva el
  comportamiento vigente del código (transformación por 2 Brillo, máximo 1).
- La matriz de guardados antiguos sigue diferida. El original conserva sus
  datos del navegador; Godot usa almacenamiento local nativo y el estado v17.
- Los modelos/efectos nativos son provisionales; no se afirma equivalencia
  artística ni se han tomado capturas o ejecutado un playtest automatizado.

## Ampliación del objetivo: edición visual y paridad artística

F11 implementa escenas de HUD/menús, Theme, actores AnimatedSprite3D con variantes
heredadas, recursos/drops/interactivos PackedScene y overrides de apariencia.
`godot/EDITING_VISUALS.md` documenta los contratos editables. F10 coteja CSS,
materiales, dimensiones y configuración contra las fuentes; no se declara
paridad de píxeles ni validación manual de esta nueva arquitectura.

Por instrucción actual del usuario, concentrar el testeo manual al final y
atender durante implementación solo bloqueos graves. El atasco del slot 1 se
analizó con copia de solo lectura y helpers geométricos aislados; hay corrección
de cesión/rutas, pendiente de comprobar en partida. No se ejecutó ese guardado
automáticamente. El informe de lag de combate sigue pendiente de evidencia
manual final; un ahorro en rutas no demuestra FPS de una batalla.

El menú inicial sí se ha inspeccionado mediante capturas estáticas comparables
1280×720 (sin entrar en partida). Se corrigió el fallback proporcional de web
incluyendo Liberation Mono y licencia OFL. Persisten fondo plano/gradiente y
espaciado del menú; Salir es una acción nativa de Godot. Materiales/cámara,
cuadrícula/tótem, HUD, nubes/lluvia, curación y alertas se cotejaron por fuentes,
pero la vista en movimiento sigue sin acreditación manual tras el refactor.

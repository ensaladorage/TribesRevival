# Auditoría de paridad — 2026-11-05

Las rutas de scripts e informes de esta tabla son relativas a `godot/`.

Esta tabla compara el objetivo completo con el estado del proyecto. La
presencia de código y una exportación correcta no demuestran por sí solas
equivalencia funcional. La revisión manual está en `GODOT_MANUAL_QA.md`: el
usuario confirma menús, arrastre/seguimiento/recolección y equipo/mejoras/
tecnología/combate básicos y reclutamiento consecutivo corregido tras su aviso.
Especifica que usó el ejecutable Linux y confirma corregido el lag en los
bordes del mundo con 8 unidades. Los demás casos siguen pendientes.
La migración completa todavía no está acreditada.

| Requisito | Evidencia actual | Falta para acreditarlo completamente |
|---|---|---|
| Rama exclusiva, original intacto | `migration/godot`; 838 hashes de archivos originales en `audit/source_inventory.json`, verificados por `tools/verify_original.py` | Mantener la comprobación en cada cambio |
| Godot 4/GDScript/Compatibility | `project.godot`, 25 scripts, escena principal importada e inicializada headless; arranque gráfico Linux confirmado por usuario | Mantener estos contratos y terminar QA restante |
| Escena 3D y cámara | `scenes/main.tscn`, `view/isometric_camera.gd`, `main.gd`; usuario confirma arrastre y fluidez en bordes con 8 unidades tras el arreglo | Confirmación explícita de zoom/pausa/velocidades/debug y casos restantes de F2 |
| Estado y mundo deterministas | PRNG bit exacto UTF-16/Mulberry32 y estados iniciales completos comparados con TS en 4 semillas, incluida Unicode/emoji | Vista/generación percibida en partida |
| Tótem/minions/IA/navegación | `minion_movement.gd`, `navigation.gd`, `minion_idle.gd`, `work_system.gd`; funciones puras comparadas con TS; usuario confirma arrastre/seguimiento y bordes con 8 unidades | Cruces, llamadas, obstáculos e interrupciones de F5 |
| Recolección/economía | Afinidades, tickets, llamadas, tiempos, drops unitarios, inventario y tablas portados; transacciones/reglas puras verificadas; usuario confirma recolección y aumento del inventario | Interrupción y continuidad en los casos restantes de QA |
| Combate/salud/fauna/loot | `conflict_system.gd`, `combat_rules.gd`, `survival_system.gd`; estadísticas/daño/curación comparados con TS; usuario confirma combate básico con daño y botín | Huida, respawn, derrota y casos restantes de QA |
| Compras/equipo/legendarias | `commands.gd`, UI nativa y picking; cap 8, Mago único, proveedor de comida, Escudo y costes mixtos comparados con TS sin ticks; usuario confirma equipo, reclutamiento consecutivo y uso de 8 unidades en Linux | Resto de clases/escudo/preview/cancelación/feedback |
| Herramientas/XP/tecnologías | Tablas 0–10, bonus, XP y tres tecnologías vigentes con requisitos/costes compartidos; usuario confirma mejora/tecnología básica; HUD de puntos y paneles alineado al original | Resto de niveles/requisitos y revisión manual del HUD actualizado |
| Clima/hogueras | Sistemas lógicos portados en el orden original, vistas provisionales y audio | Lluvia/reposición, expiración/distancia/curación manuales |
| HUD/menús/tutorial | Controles nativos, 13 iconos originales verificados; usuario confirma Tutorial, Guardar/Cargar y retorno al principal tras arreglo de callbacks; regresión aislada de señales y Esc | Resto del HUD, foco/teclado (incluido Esc corregido), tooltips, opacidad y legibilidad manuales |
| Guardado local actual | Tres slots, JSON v17, metadatos, ida/vuelta aislada, compra tras carga, borrado individual; usuario confirma Guardar/Cargar básico en Linux | Tres slots, borrado/cancelación y persistencia tras reabrir manuales |
| Exportación Windows/Linux | Presets x86_64, templates oficiales 4.7.2 verificados por SHA256; formatos PE/ELF confirmados; Linux inicia headless y usuario confirma recorridos funcionales en su ejecutable | Abrir gráficamente Windows y completar QA restante |
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

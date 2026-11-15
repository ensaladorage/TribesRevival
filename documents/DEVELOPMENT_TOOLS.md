# Herramientas de desarrollo

Actualización: ambos complementos figuran activos en `project.godot`. Funplay
escucha en localhost y se registró en Codex como `funplay-tribes`, con puente
local en `C:/Users/Javi/.codex/tools/funplay-0.9.2`. Una prueba MCP stdio
autenticada devolvió `res://scenes/main.tscn` y 49 nodos. La sesión actual de
Codex todavía no expone los dos MCP como herramientas; comprobar en un chat
nuevo o tras reiniciar la aplicación. El panel de GdUnit sigue sin comprobarse.
Para revertir el registro: `codex mcp remove funplay-tribes`. Copia adicional
de configuración: `C:/Users/Javi/.codex/config.toml.before-funplay-20261113.bak`.

Auditoría del 13-11-2026: Windows, Godot 4.7.2, Node 22.22.3, Python 3.14.5 y Codex CLI 0.167.0-alpha.4.1 (incluido en Codex desktop). El pedido mencionaba Omarchy; estas rutas son de Windows. No se ha configurado otra máquina.

| Herramienta | Versión y ubicación | Estado |
| --- | --- | --- |
| Funplay Godot MCP | 0.9.2, `godot/addons/funplay_mcp` | Copiado; activación, configuración y comunicación pendientes. La tienda marca esta versión inestable y solo cita pruebas con Godot 4.6.3. |
| MemPalace | 3.12.0, `C:/Users/Javi/.codex/tools/mempalace-venv` | Instalado localmente, registrado en Codex; 372 fragmentos de `documents/` indexados en `C:/Users/Javi/.codex/tools/tribes-revival-palace`. Prueba directa por protocolo MCP completada; falta verificar desde una nueva sesión de la aplicación. |
| frontend-design | copia de `anthropics/skills`, `C:/Users/Javi/.codex/skills/frontend-design` | Instalada con el instalador de Codex; disponible desde el próximo turno. |
| tribes-revival-development | `.agents/skills/tribes-revival-development` | Existente, ampliada y validada. |
| tribes-revival-ui-design | `.agents/skills/tribes-revival-ui-design` | Creada y validada. |
| GdUnit4 | 6.2.3, `godot/addons/gdUnit4` | Cuatro pruebas pasan headless; panel del editor pendiente. El autor enumera 4.7 y 4.7.1, no 4.7.2. |

## Funcionamiento y fuentes

La memoria es una ayuda de búsqueda; manda el código y la documentación vigente según `documents/README_DOCUMENTACION.md`. Antes de trabajos complejos, buscar contexto y contrastarlo; registrar decisiones relevantes con su fuente, sin duplicados. Los documentos indexados están en la sala `general` y `AGENTS.md` en `convenciones`; el archivo local `mempalace.yaml` define categorías para recuerdos posteriores: arquitectura, diseño, mecánicas, pendientes, economía, convenciones, problemas, descartes, hitos y pruebas. La prueba de memoria tiene el identificador textual `tótem violeta 74281` en la sala `pruebas`.

MemPalace usa inferencia local de EmbeddingGemma; la primera ejecución descarga el modelo público de Hugging Face. No se ha configurado un proveedor de IA remoto. La indexación copia textos locales a la base, que puede quedar desactualizada: consultar los originales. `mempalace init` creó `mempalace.yaml` y `entities.json` ignorados por Git y añadió sus reglas a `.gitignore`; las entidades detectadas erróneamente se vaciaron.

Para terminar Funplay, abrir el proyecto en Godot, activar **Project > Project Settings > Plugins > Funplay MCP for Godot**, abrir su panel y usar **Configure** para Codex. Mantener el token generado fuera del repositorio. El servidor usa localhost y necesita el editor abierto. Comprobar con `get_scene_info` desde una sesión nueva; el perfil `full` ofrece más herramientas. El panel genera la configuración stdio autenticada: no usar el ejemplo HTTP sin token de la versión antigua del README.

Activar GdUnit4 en el mismo panel de complementos; después usar su inspector para ejecutar suites en el editor. La activación de ambos complementos modifica `godot/project.godot`: guardar antes una copia. No se ha comprobado la recarga de MCP en la aplicación ya abierta; abrir un chat nuevo o reiniciar Codex si no aparece, y verificar explícitamente antes de afirmar que funciona. Invocar Skills por nombre o `$tribes-revival-ui-design`; la instalación queda disponible a partir del siguiente turno.

## Comandos ejecutados

```powershell
git clone --depth 1 --branch v0.9.2 https://github.com/FunplayAI/funplay-godot-mcp.git "$env:TEMP/tribes-funplay-v092"
git clone --depth 1 --branch v6.2.3 https://github.com/godot-gdunit-labs/gdUnit4.git "$env:TEMP/tribes-gdunit-v623"
# Se copiaron los directorios addons correspondientes y sus licencias a godot/addons.
python 'C:/Users/Javi/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py' --repo anthropics/skills --path skills/frontend-design
python -m venv 'C:/Users/Javi/.codex/tools/mempalace-venv'
& 'C:/Users/Javi/.codex/tools/mempalace-venv/Scripts/python.exe' -m pip install mempalace
& 'C:/Users/Javi/.codex/tools/mempalace-venv/Scripts/mempalace.exe' init 'D:/Godot/Tribes Revival' --palace 'C:/Users/Javi/.codex/tools/tribes-revival-palace' --yes --no-llm --embedding-model embeddinggemma --direct
codex mcp add mempalace-tribes --env PYTHONIOENCODING=utf-8 -- 'C:/Users/Javi/.codex/tools/mempalace-venv/Scripts/mempalace-mcp.exe' --palace 'C:/Users/Javi/.codex/tools/tribes-revival-palace'
& 'C:/Users/Javi/.codex/tools/mempalace-venv/Scripts/mempalace.exe' --palace 'C:/Users/Javi/.codex/tools/tribes-revival-palace' mine 'D:/Godot/Tribes Revival/documents' --wing tribes_revival --direct
& 'C:/Users/Javi/.codex/tools/mempalace-venv/Scripts/python.exe' 'C:/Users/Javi/.codex/skills/.system/skill-creator/scripts/quick_validate.py' '.agents/skills/tribes-revival-ui-design'
```

El mismo validador pasó para `tribes-revival-development`. Las pruebas MCP se ejecutaron mediante JSON-RPC stdio local (`initialize`, `mempalace_add_drawer`, `mempalace_search`); esto no demuestra que la aplicación gráfica ya haya cargado el servidor.

## Ejecutar pruebas

Desde la raíz del repositorio, en PowerShell:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --import
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/gdunit --ignoreHeadlessMode
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/test_data.gd
```

Resultado observado: 4/4 pruebas GdUnit y 8575 comparaciones del runner existente. La organización inicial contiene `economy/` y `combat/`; para futuras suites añadir directorios de recolección, transformaciones, población, herramientas, estados, tótem, mapa, derrota y persistencia según cobertura real, sin inventar reglas. Headless no verifica interacciones de interfaz.

## Reversión

Cerrar primero Godot y retirar los complementos desde sus ajustes. Para desinstalar, retirar `godot/addons/funplay_mcp`, `godot/addons/gdUnit4` y, si se desea, `godot/tests/gdunit`; retirar también las entradas de QA y estado añadidas en esta tarea. Eliminar las carpetas de Skills indicadas arriba o revertir solamente la ampliación de la Skill principal. `codex mcp remove mempalace-tribes` elimina el registro; después pueden retirarse el entorno virtual y el palacio indicados, con pérdida de su memoria. Retirar las dos reglas añadidas a `.gitignore` y los archivos locales `mempalace.yaml` y `entities.json` si ya no se necesitan. Hay copia previa de Codex en `C:/Users/Javi/.codex/config.toml.before-tribes-tools-20261113.bak` y copia de `.gitignore` en `C:/Users/Javi/.codex/tools/gitignore-before-tribes-tools-20261113.bak`; comparar antes de restaurar para no perder cambios posteriores. La caché del modelo Hugging Face y `C:/Users/Javi/.mempalace/known_entities.json` son datos locales adicionales creados durante la instalación.

Fuentes: [Funplay](https://store.godotengine.org/asset/funplay/funplay-godot-mcp/), [MemPalace](https://github.com/MemPalace/mempalace), [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), [Skills de Anthropic](https://github.com/anthropics/skills), [MCP en Codex](https://developers.openai.com/codex/mcp/).

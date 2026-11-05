# Tribes Revival — Godot

Migración del juego local para un jugador implementada y aceptada en Linux,
con incidencias de IA y HUD/UI aplazadas por decisión del usuario. Proyecto separado del
original Babylon.js, que permanece disponible desde la raíz del repositorio.
Motor verificado: Godot 4.7.2, GDScript, renderer Compatibility.

## Abrir

Importar `project.godot` en Godot y ejecutar el proyecto (F5), o desde
la raíz del repositorio:

```sh
bash godot/tools/run.sh
```

El ejecutable local de Godot no se incluye en Git. En otra máquina indicar
su ubicación mediante `GODOT_BIN=/ruta/a/godot` al ejecutar los scripts.
El juego de Babylon sigue en `http://localhost:5173/TribesRevival/` con
`npm run dev` desde la raíz; no se utiliza Vite para ejecutar Godot.

## Controles

- Ratón: agarrar y arrastrar el tótem; el terreno vacío no lo mueve.
- Rueda o `+`/`−`: zoom; `Esc`: menú de pausa; `1`/`2`/`3`: velocidad.
- Arrastrar Recolector/Hoguera al mapa y equipo sobre la unidad.
- Tecnologías y Mejoras: paneles independientes abajo a la izquierda.
- `Insert` o `Numpad0`: debug oculto inicialmente, con pausa/velocidad,
  recursos, daño, nivel y límites de zoom.

Los guardados de Godot tienen tres slots locales bajo `user://saves` y
conservan el estado v17 actual. No se accede automáticamente al localStorage
del navegador; la matriz de compatibilidad antigua sigue diferida.

## Validación técnica

```sh
bash godot/tools/validate.sh
```

Comprueba hashes del original, importación headless, scripts/escenas e
inicialización sin avanzar gameplay. Compara datos y funciones puras con
referencias de TypeScript, y comprueba guardado actual en archivos temporales
aislados de los slots del jugador. No ejecuta tests visuales ni del loop.

Para regenerar las referencias de datos con las dependencias originales ya
instaladas: `node godot/tools/generate_reference.mjs`. No cambia TypeScript.
Informes locales regenerables en `reports/`, fuera de Git.

## Continuidad y pendientes

Consultar `MIGRATION_PLAN.md` y `MIGRATION_STATUS.md` antes de continuar.
Las comprobaciones de scripts/datos no sustituyen el playtest. El usuario
confirma apertura/aspecto general Linux, edición desde Godot y desaparición de
los bloqueos graves reportados. Los problemas restantes de IA y HUD/UI se
tratarán después; no se declara ausencia de bugs ni cobertura exhaustiva.
La presentación combina sprites de personajes provisionales y modelos del mundo
editables; reutiliza iconos del proyecto sin generar arte definitivo.
Consultar [EDITING_VISUALS.md](EDITING_VISUALS.md) para sustituir sprites,
modelos, paneles y estilos desde el inspector. La revisión general final se ha realizado
en Linux; los casos de QA no ensayados se conservan como seguimiento.
La lista de comprobaciones manuales está en
[`GODOT_MANUAL_QA.md`](../documents/GODOT_MANUAL_QA.md).

## Exportar

Las plantillas deben coincidir con Godot 4.7.2. El instalador local descarga
las plantillas de la [publicación oficial](https://github.com/godotengine/godot/releases/tag/4.7.2-stable),
verifica el SHA256 publicado e instala solo Linux/Windows x86_64 y web:

```sh
python3 godot/tools/install_templates.py
bash godot/tools/export.sh
```

Los ZIP de desarrollo y `manifest.json` quedan en `godot/builds/`, fuera de
Git. El script valida primero el proyecto, exporta las tres plataformas y
comprueba únicamente la inicialización headless del menú Linux, sin entrar
en una partida. Los ZIP incluyen la licencia del motor. Windows manual sigue
aplazado por el usuario. La web tiene inspección del menú inicial; su gameplay
completo no se ha acreditado. El manifiesto incluye hashes de inputs y señala
si incorpora cambios locales del editor aún sin commit.

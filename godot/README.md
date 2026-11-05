# Tribes Revival — Godot

Migración en curso del juego local para un jugador. Proyecto separado del
original Babylon.js, que permanece disponible desde la raíz del repositorio.
Motor verificado: Godot 4.7.2, GDScript, renderer Compatibility.

## Abrir

Importar `project.godot` en Godot y ejecutar la escena principal (F6), o desde
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
Las comprobaciones de scripts/datos no acreditan la calidad visual ni el
playtest. Las fases con revisión manual pendiente permanecen abiertas.
Los assets 3D son provisionales; los iconos se reutilizan del proyecto.

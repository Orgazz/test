#!/usr/bin/env bash
# Comprobacion completa: analisis estatico, compilacion del .rbxlx y pruebas.
# Descarga Rojo, Lune y luau-lsp en .tools/ si no estan instalados.
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS=.tools
mkdir -p "$TOOLS" build

fetch() { # nombre url
	if [ ! -x "$TOOLS/$1" ]; then
		echo "Descargando $1..."
		curl -sSL -o "$TOOLS/$1.zip" "$2"
		unzip -o -q "$TOOLS/$1.zip" -d "$TOOLS"
		chmod +x "$TOOLS/$1"
	fi
}
fetch rojo https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-linux-x86_64.zip
fetch lune https://github.com/lune-org/lune/releases/download/v0.8.9/lune-0.8.9-linux-x86_64.zip
fetch luau-lsp https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.62.0/luau-lsp-linux-x86_64.zip
[ -f "$TOOLS/globalTypes.d.luau" ] || curl -sSL -o "$TOOLS/globalTypes.d.luau" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

echo "== Analisis estatico (luau-lsp) =="
"$TOOLS/rojo" sourcemap default.project.json -o sourcemap.json
"$TOOLS/luau-lsp" analyze --definitions="$TOOLS/globalTypes.d.luau" --sourcemap=sourcemap.json src

echo "== Compilando el lugar =="
"$TOOLS/rojo" build default.project.json -o build/TinyEmpireTycoon.rbxlx

echo "== Pruebas de integracion =="
"$TOOLS/lune" run tests/run.luau build/TinyEmpireTycoon.rbxlx
"$TOOLS/lune" run tests/run_nostore.luau build/TinyEmpireTycoon.rbxlx

echo "== Balance =="
"$TOOLS/lune" run tests/balance.luau

echo "== Horneando el mapa en TinyEmpireTycoon.rbxl =="
"$TOOLS/lune" run tools/bake.luau build/TinyEmpireTycoon.rbxlx TinyEmpireTycoon.rbxl
"$TOOLS/lune" run tests/run.luau TinyEmpireTycoon.rbxl > build/baked-tests.log
tail -n 1 build/baked-tests.log

#!/usr/bin/env bash
set -euo pipefail

# Directorio a analizar: por defecto, $HOME
ORIGEN="${1:-$HOME}"

# Archivo de salida
SALIDA="${2:-$HOME/directorios_home.txt}"

# Validar que el origen exista y sea un directorio
if [[ ! -d "$ORIGEN" ]]; then
  echo "Error: '$ORIGEN' no es un directorio válido." >&2
  exit 1
fi

# Listar solo los directorios del primer nivel,
# guardar únicamente el nombre y encerrarlo entre comillas dobles
find "$ORIGEN" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
  sed 's/^/"/; s/$/"/' >"$SALIDA"

echo "Listado generado en: $SALIDA"

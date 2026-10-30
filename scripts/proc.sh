#!/bin/bash
# Script: proc.sh - Procesador genérico de archivos
# Uso: ./proc.sh -d <directorio> -p <patrón> -c <comando> [-s <texto>] [-o <archivo>]

# Colores y emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
CHECK="✅"
WARN="⚠️"
ERROR="❌"
INFO="ℹ️"

# Variables
DIRECTORY=""
PATTERN=""
SEARCH=""
COMMAND=""
OUTPUT=""
VERBOSE=0

# Función de ayuda
show_help() {
  echo "Uso: $0 -d <directorio> -p <patrón> -c <comando> [-s <texto>] [-o <archivo>]"
  echo ""
  echo "Opciones:"
  echo "  -d, --directory     Directorio donde buscar"
  echo "  -p, --pattern       Patrón de selección de archivos (ej: *.sh)"
  echo "  -c, --command       Comando a ejecutar por archivo (use {} para el archivo)"
  echo "  -s, --search        Texto literal a buscar dentro de archivos (filtro)"
  echo "  -o, --output        Archivo de salida (si no, salida por consola)"
  echo "  -h, --help          Mostrar esta ayuda"
  echo ""
  echo "Ejemplos:"
  echo "  $0 -d . -p \"*.sh\" -c \"md5sum {}\""
  echo "  $0 -d . -p \"*.sh\" -s \"ERROR\" -c \"wc -l {}\" -o resultados.txt"
  echo "  $0 -d /var/log -p \"*.log\" -s \"failed\" -c \"grep -H 'failed' {}\""
}

# Verificar si no hay argumentos
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

# Parsear argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
  -d | --directory)
    DIRECTORY="$2"
    shift 2
    ;;
  -p | --pattern)
    PATTERN="$2"
    shift 2
    ;;
  -s | --search)
    SEARCH="$2"
    shift 2
    ;;
  -c | --command)
    COMMAND="$2"
    shift 2
    ;;
  -o | --output)
    OUTPUT="$2"
    shift 2
    ;;
  -h | --help)
    show_help
    exit 0
    ;;
  *)
    echo -e "${ERROR} Error: Opción desconocida: $1"
    show_help
    exit 1
    ;;
  esac
done

# Validar argumentos requeridos
if [[ -z "$DIRECTORY" ]]; then
  echo -e "${ERROR} Error: Directorio requerido (-d)"
  exit 1
fi

if [[ -z "$PATTERN" ]]; then
  echo -e "${ERROR} Error: Patrón requerido (-p)"
  exit 1
fi

if [[ -z "$COMMAND" ]]; then
  echo -e "${ERROR} Error: Comando requerido (-c)"
  exit 1
fi

# Verificar que {} existe en el comando
if [[ ! "$COMMAND" =~ "{}" ]]; then
  echo -e "${WARN} Advertencia: El comando no contiene '{}' para sustituir el archivo"
fi

# Verificar que el directorio existe
if [[ ! -d "$DIRECTORY" ]]; then
  echo -e "${ERROR} Error: El directorio '$DIRECTORY' no existe"
  exit 1
fi

# Verificar que se puede escribir en el archivo de salida
if [[ -n "$OUTPUT" ]]; then
  if ! touch "$OUTPUT" 2>/dev/null; then
    echo -e "${ERROR} Error: No se puede escribir en '$OUTPUT'"
    exit 1
  fi
fi

# Función para mostrar mensajes
log() {
  if [[ -n "$OUTPUT" ]]; then
    echo "$1" >>"$OUTPUT"
  else
    echo "$1"
  fi
}

# Función para buscar archivos
find_files() {
  local dir="$1"
  local pattern="$2"
  find "$dir" -type f -name "$pattern" 2>/dev/null
}

# Función para filtrar por contenido
filter_by_content() {
  local search="$1"
  while IFS= read -r file; do
    if grep -qF "$search" "$file" 2>/dev/null; then
      echo "$file"
    fi
  done
}

# Función para ejecutar comando
execute_command() {
  local file="$1"
  local cmd="${COMMAND//\{\}/\"$file\"}"
  eval "$cmd" 2>&1
}

# Procesamiento principal
main() {
  # Buscar archivos
  local files
  files=$(find_files "$DIRECTORY" "$PATTERN")

  if [[ -z "$files" ]]; then
    log "${WARN} No se encontraron archivos con el patrón '$PATTERN' en '$DIRECTORY'"
    exit 0
  fi

  # Contar archivos
  local total_files
  total_files=$(echo "$files" | wc -l)
  log "${INFO} Encontrados $total_files archivos con el patrón '$PATTERN'"

  # Filtrar por contenido si se especificó
  if [[ -n "$SEARCH" ]]; then
    log "${INFO} Filtrando archivos que contienen '$SEARCH'..."
    files=$(echo "$files" | filter_by_content "$SEARCH")

    if [[ -z "$files" ]]; then
      log "${WARN} No se encontraron archivos que contengan '$SEARCH'"
      exit 0
    fi

    local filtered_count
    filtered_count=$(echo "$files" | wc -l)
    log "${INFO} $filtered_count archivos contienen '$SEARCH'"
  fi

  # Ejecutar comando en cada archivo
  local count=0
  local success=0
  local failed=0

  while IFS= read -r file; do
    count=$((count + 1))
    log "${INFO} Procesando [$count]: $file"

    if output=$(execute_command "$file"); then
      success=$((success + 1))
      if [[ -n "$output" ]]; then
        log "$output"
      fi
    else
      failed=$((failed + 1))
      log "${ERROR} Falló al procesar: $file"
      if [[ -n "$output" ]]; then
        log "$output"
      fi
    fi

  done <<<"$files"

  # Resumen final
  log ""
  log "${INFO} Resumen:"
  log "  Total procesados: $count"
  log "  Exitosos: $success"
  log "  Fallidos: $failed"

  if [[ -n "$OUTPUT" ]]; then
    log "${CHECK} Resultados guardados en: $OUTPUT"
  else
    log "${CHECK} Procesamiento completado"
  fi
}

# Ejecutar
main

exit 0

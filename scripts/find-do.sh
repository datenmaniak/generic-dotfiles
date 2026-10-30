#!/bin/bash
# Script: proc.sh - Procesador genérico de archivos
# Uso: ./proc.sh -d <directorio> -p <patrón_archivo> {-c <comando> | -s <patrón_contenido>} [-o <archivo>]

# Emojis para claridad visual (Texto plano sin secuencias de escape ANSI)
CHECK="✅"
WARN="⚠️"
ERROR="❌"
INFO="ℹ️"

# Variables globales
DIRECTORY=""
FILE_PATTERN=""
CONTENT_PATTERN=""
COMMAND=""
OUTPUT=""

# Función de ayuda
show_help() {
  echo "Uso: $0 -d <directorio> -p <patrón_archivo> {-c <comando> | -s <patrón_contenido>} [-o <archivo>]"
  echo ""
  echo "Opciones:"
  echo "  -d, --directory         Directorio donde buscar"
  echo "  -p, --pattern           Patrón de comodines para filtrar ARCHIVOS por nombre (ej: *.txt)"
  echo "  -s, --search            Patrón de texto literal para buscar CONTENIDO dentro de los archivos"
  echo "  -c, --command           Comando a ejecutar por archivo (use {} para el archivo)"
  echo "  -o, --output            Archivo de destino para los resultados (opcional)"
  echo "  -h, --help              Mostrar esta ayuda"
  echo ""
  echo "Regla crítica: El parámetro de comando (-c) y el patrón de contenido (-s) son mutuamente excluyentes."
  echo ""
  echo "Ejemplos:"
  echo "  $0 -d . -p \"*.sh\" -c \"md5sum {}\""
  echo "  $0 -d /var/log -p \"*.log\" -s \"connection timeout\" -o reporte.txt"
}

# Verificar si no se enviaron argumentos
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

# Parsear argumentos de la línea de comandos
while [[ $# -gt 0 ]]; do
  case $1 in
  -d | --directory)
    DIRECTORY="$2"
    shift 2
    ;;
  -p | --pattern)
    FILE_PATTERN="$2"
    shift 2
    ;;
  -s | --search)
    CONTENT_PATTERN="$2"
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
    echo "${ERROR} Error: Opción desconocida: $1"
    show_help
    exit 1
    ;;
  esac
done

# 1. Validar parámetros obligatorios mínimos
if [[ -z "$DIRECTORY" || -z "$FILE_PATTERN" ]]; then
  echo "${ERROR} Error: El directorio (-d) y el patrón de archivo (-p) son requeridos."
  exit 1
fi

# 2. Validar regla de exclusión mutua entre -c y -s
if [[ -n "$COMMAND" && -n "$CONTENT_PATTERN" ]]; then
  echo "${ERROR} Error: Configuración inválida. Si utilizas un comando (-c), no puedes definir un patrón de contenido (-s)."
  exit 1
fi

if [[ -z "$COMMAND" && -z "$CONTENT_PATTERN" ]]; then
  echo "${ERROR} Error: Falta acción. Debes especificar un comando (-c) o un patrón de búsqueda de contenido (-s)."
  exit 1
fi

# Auto-completar el token {} al final del comando si el usuario lo omitió
if [[ -n "$COMMAND" && ! "$COMMAND" =~ "{}" ]]; then
  echo "${WARN} El comando no contiene '{}', se agregará automáticamente al final de la instrucción."
  COMMAND="$COMMAND {}"
fi

# Verificar la existencia física del directorio raíz
if [[ ! -d "$DIRECTORY" ]]; then
  echo "${ERROR} Error: El directorio especificado '$DIRECTORY' no existe."
  exit 1
fi

# Verificar permisos de escritura en el archivo de salida si se definió
if [[ -n "$OUTPUT" ]]; then
  if ! touch "$OUTPUT" 2>/dev/null; then
    echo "${ERROR} Error: No se tienen permisos de escritura sobre el archivo destino '$OUTPUT'."
    exit 1
  fi
fi

# Función centralizada de logging para bifurcar o duplicar salidas hacia el archivo descriptor
log() {
  if [[ -n "$OUTPUT" ]]; then
    echo "$1" >>"$OUTPUT"
  fi
  echo "$1"
}

# Generar la barra de progreso visual dinámica en stderr (Evita ensuciar flujos de redirección)
draw_progress_bar() {
  local current="$1"
  local total="$2"
  [[ $total -eq 0 ]] && return

  local percent=$((current * 100 / total))
  local bar_length=20
  local filled=$((percent * bar_length / 100))
  local empty=$((bar_length - filled))

  local bar
  bar=$(printf "%${filled}s" | tr ' ' '█')
  bar+=$(printf "%${empty}s" | tr ' ' '░')

  printf "\r${INFO} Progreso: [%s] %d%% (%d/%d)" "$bar" "$percent" "$current" "$total" >&2
}

# Ejecución segura de comandos externos mediante escaping estricto con eval
execute_command() {
  local file="$1"
  local escaped_file
  escaped_file=$(printf '%q' "$file")
  local cmd="${COMMAND//\{\}/$escaped_file}"
  eval "$cmd" 2>&1
}

# Hilo de ejecución principal
main() {
  local -a files=()

  # ETAPA 1: Búsqueda y filtrado de nombres de archivos vía find + delimitador nulo
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$DIRECTORY" -type f -name "$FILE_PATTERN" -print0 2>/dev/null)

  local total_files=${#files[@]}

  if [[ $total_files -eq 0 ]]; then
    log "${WARN} No se encontraron archivos que coincidan con el criterio de nombre '$FILE_PATTERN' en '$DIRECTORY'."
    exit 0
  fi

  log "${INFO} Encontrados $total_files archivos de interés. Iniciando procesamiento..."
  log "--------------------------------------------------------"

  local count=0
  local success=0
  local failed=0
  local -a buffered_outputs=()

  # Renderizar estado 0% de la barra
  draw_progress_bar 0 "$total_files"

  for file in "${files[@]}"; do
    count=$((count + 1))

    # MODO DE OPERACIÓN A: Búsqueda de contenido literal (-s) mediante grep
    if [[ -n "$CONTENT_PATTERN" ]]; then
      output=$(grep -HnF "$CONTENT_PATTERN" "$file" 2>/dev/null)
      exit_code=$?
      if [[ $exit_code -eq 0 ]]; then
        success=$((success + 1))
        buffered_outputs+=("$output")
      else
        failed=$((failed + 1))
      fi

    # MODO DE OPERACIÓN B: Procesamiento por comando (-c)
    else
      output=$(execute_command "$file")
      exit_code=$?
      if [[ $exit_code -eq 0 ]]; then
        success=$((success + 1))
        if [[ -n "$output" ]]; then
          buffered_outputs+=("${INFO} [OK] $file:\n$output")
        fi
      else
        failed=$((failed + 1))
        buffered_outputs+=("${ERROR} [FALLO] $file (código de salida: $exit_code)\n$output")
      fi
    fi

    # Actualización de la interfaz en cada iteración discreta
    draw_progress_bar "$count" "$total_files"
  done

  # Limpiar el buffer de la barra de progreso en el retorno de carro final
  printf "\r%${COLUMNS:-80}s\r" "" >&2

  # ETAPA 2: Volcado ordenado de los resultados recolectados en memoria
  if [[ ${#buffered_outputs[@]} -gt 0 ]]; then
    log "${INFO} DETALLE DE RESULTADOS:"
    for out in "${buffered_outputs[@]}"; do
      log "$out"
    done
    log "--------------------------------------------------------"
  fi

  # ETAPA 3: Reporte métrico resumido
  log "${INFO} Resumen de Actividad:"
  if [[ -n "$CONTENT_PATTERN" ]]; then
    log "  Archivos mapeados y analizados: $count"
    log "  Archivos con coincidencias del patrón: $success"
    log "  Archivos sin texto coincidente: $failed"
  else
    log "  Total de comandos lanzados: $count"
    log "  Procesamientos exitosos: $success"
    log "  Procesamientos fallidos: $failed"
  fi
  log "--------------------------------------------------------"

  if [[ -n "$OUTPUT" ]]; then
    echo "${CHECK} Procesamiento finalizado. Resultados exportados a: $OUTPUT"
  else
    log "${CHECK} Procesamiento completado con éxito."
  fi
}

main
exit 0

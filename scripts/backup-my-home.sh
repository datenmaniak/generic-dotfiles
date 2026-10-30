#!/usr/bin/zsh

# ============================================
# backup-my-home.sh
# - Respaldo incremental de $HOME en disco externo
# ============================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
USER="datenmaniak"
EXT_DISK_PATH="/run/media/datenmaniak/wp2026.backups/respaldos-de-Victus/"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="${HOME}/.backup_home_${TIMESTAMP}.log"

# Modos (por defecto: dry-run = false)
DRY_RUN=""
DRY_RUN_FLAG=""

# ============================================
# Funciones
# ============================================

print_color() {
    echo -e "${2}${1}${NC}"
}

show_help() {
    cat << EOF
Uso: $0 [OPCIÓN]

Opciones:
  --dry-run    Simula el respaldo sin copiar archivos
  --run        Ejecuta el respaldo realmente
  -h, --help   Muestra esta ayuda

Ejemplos:
  $0 --dry-run   # Ver qué se respaldaría
  $0 --run       # Ejecutar respaldo completo

Nota: Por defecto se ejecuta en modo dry-run por seguridad.
EOF
    exit 0
}

validate_user() {
    local current_user=$(whoami)
    if [[ "$current_user" != "$USER" ]]; then
        print_color "ERROR: Usuario actual ($current_user) no coincide con el esperado ($USER)" "$RED"
        print_color "Abortando respaldo por seguridad..." "$RED"
        exit 1
    fi
    print_color "✓ Usuario validado: $current_user" "$GREEN"
}

validate_backup_path() {
    if [[ ! -d "$EXT_DISK_PATH" ]]; then
        print_color "ERROR: Ruta de respaldo no existe o no es accesible:" "$RED"
        print_color "  $EXT_DISK_PATH" "$YELLOW"
        print_color "Sugerencia: Monta el disco externo en /run/media/datenmaniak/wp2026.backups/" "$YELLOW"
        exit 1
    fi
    
    if [[ ! -w "$EXT_DISK_PATH" ]]; then
        print_color "ERROR: No hay permisos de escritura en:" "$RED"
        print_color "  $EXT_DISK_PATH" "$YELLOW"
        exit 1
    fi
    
    print_color "✓ Ruta de respaldo válida: $EXT_DISK_PATH" "$GREEN"
}

show_backup_info() {
    local home_size=$(du -sh ${HOME} 2>/dev/null | cut -f1)
    local disk_free=$(df -h "$EXT_DISK_PATH" | awk 'NR==2 {print $4}')
    
    print_color "\n========== INFO RESPALDO ==========" "$BLUE"
    print_color "Origen:      ${HOME}" "$YELLOW"
    print_color "Tamaño aprox: $home_size" "$YELLOW"
    print_color "Destino:     ${EXT_DISK_PATH}" "$YELLOW"
    print_color "Espacio libre destino: $disk_free" "$YELLOW"
    print_color "Modo:        $([ -n "$DRY_RUN" ] && echo "DRY-RUN (simulación)" || echo "REAL (copiando)")" "$YELLOW"
    print_color "Log:         $LOG_FILE" "$YELLOW"
    print_color "===================================\n" "$BLUE"
}

do_backup() {
    local rsync_opts="-avh --delete --progress"
    
    if [ -n "$DRY_RUN" ]; then
        rsync_opts="$rsync_opts --dry-run"
    fi
    
    print_color "Iniciando respaldo... (puede tomar varios minutos)" "$GREEN"
    
    rsync $rsync_opts \
        --exclude='.cache' \
        --exclude='.local/share/Trash' \
        --exclude='.npm' \
        --exclude='.cargo' \
        --exclude='.gradle' \
        --exclude='.m2' \
        --exclude='snap' \
        --exclude='VirtualBox VMs' \
        --exclude='.thumbnails' \
        --exclude='.Trash' \
        --exclude='.wine' \
        --exclude='.android' \
        --exclude='.local/share/Steam' \
        --exclude='.rustup' \
        --exclude='go' \
        --exclude='.vscode-server' \
        --exclude='.cache' \
        --exclude='.mozilla/firefox/*.default-release/cache2' \
        --exclude='.config/google-chrome' \
        --exclude='.zoom' \
        "${HOME}/" \
        "${EXT_DISK_PATH}" \
        2>&1 | tee -a "$LOG_FILE"
    
    local rsync_exit=${PIPESTATUS[0]}
    
    if [ $rsync_exit -eq 0 ]; then
        print_color "\n✓ Respaldo completado exitosamente" "$GREEN"
        if [ -z "$DRY_RUN" ]; then
            print_color "Log guardado en: $LOG_FILE" "$GREEN"
        fi
    else
        print_color "\n✗ Error durante el respaldo (código: $rsync_exit)" "$RED"
        print_color "Revisa el log: $LOG_FILE" "$RED"
        exit $rsync_exit
    fi
}

show_summary() {
    if [ -n "$DRY_RUN" ]; then
        print_color "\n========== RESUMEN (DRY-RUN) ==========" "$BLUE"
        print_color "Los archivos listados arriba SERÍAN respaldados." "$YELLOW"
        print_color "Ejecuta '--run' para realizar el respaldo real." "$YELLOW"
    else
        local backup_time=$(stat -c %y "$EXT_DISK_PATH" 2>/dev/null | cut -d'.' -f1)
        print_color "\n========== RESPALDO COMPLETADO ==========" "$GREEN"
        print_color "Fecha/Hora: $backup_time" "$GREEN"
        print_color "Destino: ${EXT_DISK_PATH}" "$GREEN"
    fi
    print_color "======================================\n" "$BLUE"
}

# ============================================
# Main
# ============================================

# Procesar argumentos
case "$1" in
    --dry-run)
        DRY_RUN="true"
        ;;
    --run)
        DRY_RUN=""
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        print_color "Opción inválida: $1" "$RED"
        show_help
        ;;
esac

# Validaciones
clear
print_color "===== BACKUP HOME SCRIPT =====" "$BLUE"
validate_user
validate_backup_path
show_backup_info

# Confirmación para modo real
if [ -z "$DRY_RUN" ]; then
    print_color "⚠️  ATENCIÓN: Esto ejecutará el respaldo REAL" "$YELLOW"
    echo -n "¿Continuar? (escribe 'yes' para confirmar): "
    read confirmation
    if [[ "$confirmation" != "yes" ]]; then
        print_color "Respaldo cancelado." "$RED"
        exit 0
    fi
fi

# Ejecutar respaldo
START_TIME=$(date +%s)
do_backup
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

print_color "Tiempo total: ${ELAPSED} segundos (~$((ELAPSED/60)) minutos)" "$GREEN"
show_summary

#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Script de Respaldo Incremental Espejo para $HOME
# Entorno: Fedora Bluefin (Soporta ejecuciones interactivas y mediante Cron)
# -----------------------------------------------------------------------------

# Configuración de robustez: Fallar rápido si algo sale mal
set -euo pipefail

# Asegurar un PATH absoluto básico para entornos cron desatendidos
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"

# --- CONFIGURACIÓN DE RUTAS Y ARCHIVOS ---
HOSTNAME_DIR=$(hostname)
LOG_FILE="${HOME}/backup_log.txt"
LOCK_FILE="/tmp/backup_home.lock"
ORIGEN="${HOME}/"

# Rutas comunes de montaje dinámico en escritorios Linux
BASE_USB="/run/media/${USER}"

# --- DECLARACIÓN DE FILTROS (INCLUSIONES / EXCLUSIONES) ---
FILTROS=(
    # 📥 Inclusiones específicas
    "--include=/.local/"
    "--include=/.local/bin/"
    "--include=/.local/bin/***"
    "--include=/.local/share/"
    "--include=/.local/share/chezmoi/"
    "--include=/.local/share/chezmoi/***"

    # 📤 Exclusiones de cachés y directorios temporales
    "--exclude=/.local/*"
    "--exclude=/.cache"
    "--exclude=/.mozilla/"
    "--exclude=/.npm"
    "--exclude=/.cargo"
    "--exclude=/.gradle"
    "--exclude=/.m2"
    "--exclude=/.rustup"
    "--exclude=/go"
    "--exclude=/.vscode-server"

    # 📤 Exclusiones de aplicaciones y máquinas virtuales
    "--exclude=/snap"
    "--exclude=/VirtualBox VMs"
    "--exclude=/.wine"
    "--exclude=/.android"
    "--exclude=/.zoom"

    # 📤 Exclusiones de basura y cachés de aplicaciones
    "--exclude=/.thumbnails"
    "--exclude=/.Trash"
    "--exclude=/.local/share/Steam"
    "--exclude=/.local/share/containers"
    "--exclude=/.mozilla/firefox/*.default-release/cache2"
    "--exclude=/.config/google-chrome"
)

# --- VARIABLES DE CONTROL INTERNO ---
DRY_RUN=""
MODO_EJECUCION="REAL"
RESPALDO_PARCIAL=false
MOSTRAR_PROGRESO=""
INTERACTIVO=false

# Determinar de forma automática si hay un humano conectado (Terminal activa)
if [ -t 0 ]; then
    INTERACTIVO=true
fi

# --- FUNCIONES ---

mensajes_ayuda() {
    cat << EOF
Uso: $0 [OPCIONES]

Script de respaldo incremental espejo para el directorio $HOME.

Opciones para ejecución desatendida (ej. Cron):
  -f, --full         Ejecuta un respaldo completo de todo el directorio \$HOME.
  -s, --select       Activa el modo de respaldo parcial/selectivo por directorio.
  -d, --dry-run      Simulación de corrida en frío (no realiza cambios reales).
  -e, --exclusions   Muestra la lista de exclusiones configuradas y finaliza.
  -v, --verbose      Muestra el progreso detallado de los archivos en tiempo real.
  -h, --help         Muestra este menú de ayuda.

Nota: Si ejecutas el script a mano en la terminal (modo interactivo) sin parámetros,
se desplegará automáticamente un menú visual asistido.
EOF
}

mostrar_exclusiones() {
    echo "📋 Lista de filtros configurados (Inclusiones/Exclusiones):"
    for filtro in "${FILTROS[@]}"; do
        echo "  $filtro"
    done
}

verificar_bloqueo() {
    exec 9>>"$LOCK_FILE"
    if ! flock -n 9; then
        echo "❌ El script de respaldo ya se está ejecutando en otra instancia."
        exit 1
    fi
}

detectar_usb() {
    if [ -d "$BASE_USB" ] && [ "$(ls -A "$BASE_USB")" ]; then
        PRIMER_USB=$(ls -d "$BASE_USB"/* | head -n 1)
        DESTINO_FINAL="${PRIMER_USB}/${HOSTNAME_DIR}"
    else
        echo "❌ No se detectó ningún disco USB externo montado en $BASE_USB."
        exit 1
    fi
}

# calcular_espacio() {
#     echo "📊 Análisis de espacio en disco:"
#     if [ -d "$ORIGEN" ]; then
#         ESPACIO_ORIGEN=$(du -sh "$ORIGEN" | cut -f1)
#         echo "  Espacio ocupado en origen: $ESPACIO_ORIGEN"
#     fi
#     ESPACIO_DESTINO=$(df -h "$PRIMER_USB" | tail -n 1 | awk '{print "Disponible: " $4 " (Total: " $2 ", Uso: " $5 ")"}')
#     echo "  Espacio en USB destino ($PRIMER_USB): $ESPACIO_DESTINO"
#     echo ""
# }

calcular_espacio() {
    echo "📊 Análisis de espacio en disco:"
    if [ -d "$ORIGEN" ]; then
        # Redirigimos los errores de 'du' a /dev/null y usamos '|| true' 
        # para que Bash no aborte el script si encuentra carpetas protegidas.
        ESPACIO_ORIGEN=$(du -sh "$ORIGEN" 2>/dev/null | cut -f1) || ESPACIO_ORIGEN="Desconocido (Permisos limitados)"
        echo "  Espacio ocupado en origen: $ESPACIO_ORIGEN"
    fi
    ESPACIO_DESTINO=$(df -h "$PRIMER_USB" | tail -n 1 | awk '{print "Disponible: " $4 " (Total: " $2 ", Uso: " $5 ")"}')
    echo "  Espacio en USB destino ($PRIMER_USB): $ESPACIO_DESTINO"
    echo ""
}

menu_respaldo_parcial() {
    echo "💾 Seleccione el directorio específico de $HOME que desea respaldar:"
    echo ""
    
    local dirs=()
    mapfile -t dirs < <(find "$HOME" -maxdepth 1 -mindepth 1 -type d ! -name ".*" | sort)
    
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "❌ No se encontraron directorios válidos para respaldar."
        exit 1
    fi

    # Formatear la lista en 3 columnas limpias sin códigos de escape ANSI
    local buffer=""
    local count=0
    local i=1
    for d in "${dirs[@]}"; do
        buffer+=$(printf "%-25s" "$i) $(basename "$d")")
        count=$((count + 1))
        
        if [ $((count % 3)) -eq 0 ]; then
            echo "$buffer"
            buffer=""
        fi
        i=$((i+1))
    done
    
    if [ -n "$buffer" ]; then
        echo "$buffer"
    fi
    
    echo ""
    echo "0) Volver al menú principal"
    echo ""

    read -r -p "Seleccione una opción: " opcion

    if [ "$opcion" = "0" ]; then
        return 99 # Código especial para regresar
    fi

    if [[ "$opcion" =~ ^[0-9]+$ ]] && [ "$opcion" -ge 1 ] && [ "$opcion" -le "${#dirs[@]}" ]; then
        local dir_seleccionado="${dirs[$((opcion-1))]}"
        ORIGEN="${dir_seleccionado}/"
        DESTINO_FINAL="${DESTINO_FINAL}/$(basename "$dir_seleccionado")"
        RESPALDO_PARCIAL=true
        echo "✅ Seleccionado para respaldar: $ORIGEN"
        echo ""
    else
        echo "❌ Opción inválida. Abortando proceso."
        exit 1
    fi
}

menu_principal_interactivo() {
    while true; do
        clear
        echo "💾 SISTEMA DE RESPALDOS ESPEJO (Host: $HOSTNAME_DIR)"
        echo "-------------------------------------------------------"
        echo "Seleccione la operación que desea realizar:"
        echo "1) Respaldo COMPLETO (Sincronizar todo el \$HOME)"
        echo "2) Respaldo PARCIAL (Seleccionar un directorio específico)"
        echo "3) Ver lista de exclusiones (Filtros configurados)"
        echo "0) Salir del script"
        echo "-------------------------------------------------------"
        read -r -p "Seleccione una opción [0-3]: " opcion_principal

        case "$opcion_principal" in
            1)
                echo "✅ Configurado: Respaldo Completo de todo el \$HOME."
                echo ""
                break
                ;;
            2)
                # Invoca el menú de directorios en 3 columnas
                if menu_respaldo_parcial; then
                    break
                fi
                # Si retorna 99 (volver), el bucle continúa y redibuja el menú principal
                ;;
            3)
                echo ""
                mostrar_exclusiones
                read -r -p "Presione [Enter] para regresar al menú principal..."
                ;;
            0)
                echo "👋 Salida del script solicitada por el usuario."
                exit 0
                ;;
            *)
                echo "❌ Opción inválida. Intente de nuevo."
                sleep 1
                ;;
        esac
    done

    # Segunda capa interactiva: Configurar el modo visual
    echo "Configuración del modo visual de ejecución:"
    echo "1) Modo Normal (Muestra el resumen estadístico al finalizar)"
    echo "2) Modo Detallado (Muestra el progreso de archivos en tiempo real)"
    echo "3) Modo Simulación (Corrida en frío - Dry Run)"
    read -r -p "Seleccione una opción [1-3]: " opcion_visual

    case "$opcion_visual" in
        1)
            MOSTRAR_PROGRESO=""
            ;;
        2)
            MOSTRAR_PROGRESO="--progress"
            ;;
        3)
            DRY_RUN="--dry-run"
            MODO_EJECUCION="SIMULACIÓN (Dry Run)"
            ;;
        *)
            echo "❌ Opción inválida. Pasando a Modo Normal por seguridad."
            MOSTRAR_PROGRESO=""
            sleep 1
            ;;
    esac
    echo ""
}

confirmacion_prevuelo() {
    clear
    echo "📋 RESUMEN DEL RESPALDO PROGRAMADO:"
    echo "-------------------------------------------------------"
    if [ "$RESPALDO_PARCIAL" = true ]; then
        echo "· Tipo de respaldo: PARCIAL (Solo el directorio seleccionado)"
    else
        echo "· Tipo de respaldo: COMPLETO (Todo el \$HOME)"
    fi
    echo "· Origen:           $ORIGEN"
    echo "· Destino en USB:   $DESTINO_FINAL"
    echo "· Modo de ejecución: $MODO_EJECUCION"
    echo "-------------------------------------------------------"
    calcular_espacio
    
    echo "⚠️  RECUERDE: Al ser un espejo idéntico, los archivos que eliminó"
    echo "   en su computadora también se borrarán físicamente de su USB."
    echo ""
    read -r -p "¿Está seguro de que desea continuar? (Escriba 'SI' para confirmar): " confirmacion

    if [ "$confirmacion" != "SI" ]; then
        echo "❌ Operación cancelada de forma segura por el usuario."
        exit 0
    fi
    echo ""
}

ejecutar_rsync() {
    if [ -z "$DRY_RUN" ]; then
        mkdir -p "$DESTINO_FINAL"
    fi

    # Incorporación estricta de tus argumentos solicitados: -aHXh --delete --stats
    #local args=(-aHXh --delete --stats)
    local args=(-aHXh --stats)
    args+=("${FILTROS[@]}")

    if [ -n "$DRY_RUN" ]; then
        args+=("$DRY_RUN")
    fi

    if [ -n "$MOSTRAR_PROGRESO" ]; then
        args+=("$MOSTRAR_PROGRESO")
    fi

    echo "🚀 Iniciando sincronización espejo..."
    echo "  Origen:  $ORIGEN"
    echo "  Destino: $DESTINO_FINAL"
    echo "  Log:     $LOG_FILE"
    echo "---"

    # Si se solicitó progreso visual, se duplica la salida a la consola con 'tee'
    if [ -n "$MOSTRAR_PROGRESO" ]; then
        rsync "${args[@]}" "$ORIGEN" "$DESTINO_FINAL" 2>&1 | tee "$LOG_FILE"
    else
        # Modo desatendida/cron o silencioso humano: Todo va directo al log sin saturar la terminal
        rsync "${args[@]}" "$ORIGEN" "$DESTINO_FINAL" > "$LOG_FILE" 2>&1
        tail -n 15 "$LOG_FILE"
    fi

    echo "---"
    echo "✅ Proceso finalizado con éxito."
}

# --- CONTROLADOR PRINCIPAL (MAIN) ---
main() {
    # ESCENARIO A: Ejecución interactiva por un humano (Sin argumentos en la consola)
    if [ "$INTERACTIVO" = true ] && [ $# -eq 0 ]; then
        verificar_bloqueo
        detectar_usb
        menu_principal_interactivo
        confirmacion_prevuelo
        ejecutar_rsync
        exit 0
    fi

    # ESCENARIO B: Ejecución por comandos o mediante CRON (Requiere flags explícitos)
    if [ $# -eq 0 ]; then
        # Si corre en cron sin argumentos, aborta por seguridad para no asumir nada
        echo "❌ Error: No se especificaron argumentos para la ejecución desatendida."
        mensajes_ayuda
        exit 1
    fi

    local flag_full=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--full)
                flag_full=true
                shift
                ;;
            -s|--select)
                RESPALDO_PARCIAL=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="--dry-run"
                MODO_EJECUCION="SIMULACIÓN (Dry Run)"
                shift
                ;;
            -e|--exclusions)
                mostrar_exclusiones
                exit 0
                ;;
            -v|--verbose)
                MOSTRAR_PROGRESO="--progress"
                shift
                ;;
            -h|--help)
                mensajes_ayuda
                exit 0
                ;;
            *)
                echo "❌ Argumento desconocido: $1"
                mensajes_ayuda
                exit 1
                ;;
        esac
    done

    # Evitar que cron intente activar la selección y el full al mismo tiempo
    if [ "$flag_full" = true ] && [ "$RESPALDO_PARCIAL" = true ]; then
        echo "❌ Error: No puede usar --full y --select simultáneamente en modo comando."
        exit 1
    fi

    if [ "$flag_full" = false ] && [ "$RESPALDO_PARCIAL" = false ]; then
        echo "❌ Error: Debe especificar explícitamente si el respaldo es --full o --select."
        exit 1
    fi

    # Validaciones obligatorias de fondo
    verificar_bloqueo
    detectar_usb

    # Si se especificó el modo selectivo por comandos, invoca el menú de columnas
    if [ "$RESPALDO_PARCIAL" = true ]; then
        if [ "$INTERACTIVO" = false ]; then
            echo "❌ Error: El modo parcial (--select) requiere una terminal interactiva para elegir la carpeta."
            exit 1
        fi
        menu_respaldo_parcial
        confirmacion_prevuelo
    fi

    # Si pasa las validaciones en modo comando / cron, ejecuta directamente sin pausas
    if [ "$INTERACTIVO" = true ] && [ "$RESPALDO_PARCIAL" = false ]; then
        confirmacion_prevuelo
    fi

    ejecutar_rsync
}

# Ejecutar pasándole la totalidad de los argumentos ingresados
main "$@"

#!/usr/bin/env bash

# ==============================================================================
# Nombre: dump-manifests (o tu alternativa favorita)
# Descripción: Auditor universal e idempotente de capas de software.
#              Detecta dinámicamente el entorno del Host (Multi-Distro)
#              y exporta manifiestos aislados para su posterior replicación.
# ==============================================================================

set -euo pipefail

# --- CONFIGURACIÓN Y REGLAS DE NEGOCIO ---
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dump-manifests"
FORZAR_REFRESCO=false
MODO_RAW=false
EXPORTAR_REQS=false

# Flags de activación de capas
VER_SYSTEM=false
VER_APPS=false
VER_BREW=false
VER_BBREW=false
VER_DISTROBOX=""

# --- PALETA DE COLORES ANSI ---
CLR_AZUL="\033[1;34m"
CLR_VERDE="\033[1;32m"
CLR_CIAN="\033[1;36m"
CLR_ROJO="\033[1;31m"
CLR_NEGRET="\033[1m"
CLR_RESET="\033[0m"

# --- DETECCIÓN DE ENTORNO ---
es_distrobox() {
  [ -f "/.dockerenv" ] || [ -f "/run/.containerenv" ] || [ -n "${CONTAINER_ID:-}" ]
}

# --- PROCESADOR ESTÁNDAR DE SALIDA Y CACHÉ ---
obtener_salida() {
  local capa="$1"
  local archivo_cache="$2"
  local comando="$3"
  local nombre_archivo_req="$4"

  # 1. Asegurar sincronización de datos en Caché
  if [ "$FORZAR_REFRESCO" = true ] || [ ! -f "$archivo_cache" ]; then
    eval "$comando" >"$archivo_cache" 2>/dev/null || true
  fi

  # 2. Modo Lectura: Impresión formateada en terminal
  if [ "$EXPORTAR_REQS" = false ]; then
    if [ "$MODO_RAW" = false ]; then
      echo -e "\n${CLR_AZUL}=== CAPA: ${capa^^} ===${CLR_RESET}"
    fi
    cat "$archivo_cache"
    return
  fi

  # 3. Modo Declarativo: Exportación de Manifiestos puros (-e)
  local ruta_destino="$(pwd)/$nombre_archivo_req"

  # Filtrar mensajes de control para dejar solo nombres puros de paquetes
  grep -v -E "^(No hay|Homebrew vacío|Bbrew vacío|Gestor|Error:|Bbrew no disponible)" "$archivo_cache" >"$ruta_destino" || true

  local total_items
  total_items=$(grep -c '^' "$ruta_destino" || echo "0")

  echo -e "${CLR_VERDE}✓${CLR_RESET} Exportada capa ${CLR_NEGRET}${capa}${CLR_RESET}"
  echo -e "  └─ ${CLR_NEGRET}Total ítems:${CLR_RESET} $total_items"
  echo -e "  └─ ${CLR_NEGRET}Archivo:${CLR_RESET}     ${CLR_VERDE}$ruta_destino${CLR_RESET}\n"
}

# --- CAPAS TECNOLÓGICAS (DETECCIÓN DINÁMICA) ---

listar_sistema() {
  local cmd=""

  if command -v rpm-ostree &>/dev/null; then
    # Entornos Inmutables (Fedora Bluefin/Aurora/Silverblue)
    if [ "$EXPORTAR_REQS" = true ] || [ "$MODO_RAW" = true ]; then
      cmd="rpm-ostree status | awk '/^(LocalPackages|LayeredPackages):/ {for(i=2;i<=NF;i++) print \$i}'"
    else
      cmd="rpm-ostree status | grep -E '^(LocalPackages|LayeredPackages):' || echo 'No hay paquetes superpuestos.'"
    fi
  elif command -v apt-get &>/dev/null; then
    # Servidores o estaciones Debian / Ubuntu
    cmd="apt-mark showmanual | sort"
  elif command -v pacman &>/dev/null; then
    # Entornos Arch Linux
    cmd="pacman -Qe -q | sort"
  elif command -v dnf &>/dev/null; then
    # Fedora Estándar / Workstation tradicional
    cmd="dnf history userinstalled | awk 'NR>1 {print \$1}' | sort"
  else
    cmd="echo 'Gestor de paquetes del Host no soportado o desconocido.'"
  fi

  obtener_salida "sistema base" "$CACHE_DIR/sistema.txt" "$cmd" "requisitos-sistema.txt"
}

listar_apps() {
  local cmd=""
  if command -v flatpak &>/dev/null; then
    if [ "$EXPORTAR_REQS" = true ]; then
      cmd="flatpak list --app --columns=application"
    else
      cmd="flatpak list --app --columns=application,name"
    fi
  else
    cmd="echo 'Flatpak no está instalado en este sistema.'"
  fi
  obtener_salida "aplicaciones (flatpak)" "$CACHE_DIR/apps.txt" "$cmd" "requisitos-apps.txt"
}

listar_brew() {
  local cmd="if command -v brew &>/dev/null; then brew list -1 2>/dev/null; else echo 'Homebrew vacío o no inicializado.'; fi"
  obtener_salida "herramientas cli (brew)" "$CACHE_DIR/brew.txt" "$cmd" "requisitos-brew.txt"
}

listar_bbrew() {
  local cmd=""
  if command -v bbrew &>/dev/null; then
    cmd="bbrew list -1 2>/dev/null"
  else
    cmd="echo 'Bbrew no disponible en esta distribución (Capa exclusiva de Bluefin).'"
  fi
  obtener_salida "herramientas cli (bbrew)" "$CACHE_DIR/bbrew.txt" "$cmd" "requisitos-bbrew.txt"
}

listar_interno_distrobox() {
  if command -v dpkg-query &>/dev/null; then
    dpkg-query -f '${binary:Package}\n' -W
  elif command -v rpm &>/dev/null; then
    rpm -qa --queryformat '%{NAME}\n' | sort
  elif command -v pacman &>/dev/null; then
    pacman -Q -q
  else
    echo "Gestor interno del contenedor no soportado."
  fi
}

listar_externo_distrobox() {
  local caja="$VER_DISTROBOX"
  local archivo_cache="$CACHE_DIR/distrobox_$caja.txt"
  local nombre_archivo_req="requisitos-distrobox-$caja.txt"

  if ! distrobox list | grep -q "$caja"; then
    echo -e "${CLR_ROJO}Error: El contenedor '$caja' no existe en Distrobox.${CLR_RESET}" >&2
    exit 1
  fi

  # Ejecución directa acoplada para evitar fallos de comillas con eval e inyección remota
  if [ "$FORZAR_REFRESCO" = true ] || [ ! -f "$archivo_cache" ]; then
    distrobox-enter -n "$caja" -- rpm -qa --queryformat '%{NAME}\n' | sort >"$archivo_cache" 2>/dev/null || true
  fi

  if [ "$EXPORTAR_REQS" = false ] || [ "$MODO_RAW" = true ]; then
    if [ "$MODO_RAW" = false ]; then
      echo -e "\n${CLR_AZUL}=== CAPA: DISTROBOX ($caja) ===${CLR_RESET}"
    fi
    cat "$archivo_cache"
  fi

  if [ "$EXPORTAR_REQS" = true ]; then
    local ruta_destino="$(pwd)/$nombre_archivo_req"
    grep -v -E "^(Error:|No hay|OS interno)" "$archivo_cache" >"$ruta_destino" || true

    local total_items
    total_items=$(grep -c '^' "$ruta_destino" || echo "0")

    echo -e "${CLR_VERDE}✓${CLR_RESET} Exportada capa ${CLR_NEGRET}distrobox ($caja)${CLR_RESET}"
    echo -e "  └─ ${CLR_NEGRET}Total ítems:${CLR_RESET} $total_items"
    echo -e "  └─ ${CLR_NEGRET}Archivo:${CLR_RESET}     ${CLR_VERDE}$ruta_destino${CLR_RESET}\n"
  fi
}

# --- INTERFAZ DE AYUDA ---
mostrar_ayuda() {
  cat <<EOF
Uso: $(basename "$0") [opciones de capa] [modificadores]

Opciones por Capa tecnológica (Detección portátil automática):
  -s, --system         Filtrar por paquetes del sistema base (Autodetecta ostree/apt/dnf/pacman)
  -a, --apps           Filtrar por aplicaciones gráficas (Flatpak)
  -b, --brew           Filtrar por herramientas de línea de comandos (Homebrew estándar)
  -bb, --bbrew         Filtrar por herramientas de sistema Bluefin (Bbrew)
  -c, --cli            Atajo unificado: Procesa de forma independiente Brew y Bbrew
  -d, --distrobox CAJA Filtrar por el contenido de un contenedor Distrobox basado en Fedora

Modificadores de comportamiento:
  -e, --export         Genera automáticamente los archivos de requerimientos declarativos aislados (ej: requisitos-brew.txt)
  -r, --refresh        Ignorar caché y forzar consulta en tiempo real al host/contenedor
  --raw                Salida de texto plano sin formatos de colores
  -h, --help           Mostrar este menú de ayuda
EOF
  exit 0
}

# --- PARSER DE ARGUMENTOS ---
if [ $# -eq 0 ] && ! es_distrobox; then
  mostrar_ayuda
fi

while [ $# -gt 0 ]; do
  case "$1" in
  -s | --system)
    VER_SYSTEM=true
    shift
    ;;
  -a | --apps)
    VER_APPS=true
    shift
    ;;
  -b | --brew)
    VER_BREW=true
    shift
    ;;
  -bb | --bbrew)
    VER_BBREW=true
    shift
    ;;
  -c | --cli)
    VER_BREW=true
    VER_BBREW=true
    shift
    ;;
  -d | --distrobox)
    if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
      echo "Error: --distrobox requiere especificar el nombre de la caja." >&2
      exit 1
    fi
    VER_DISTROBOX="$2"
    shift 2
    ;;
  -e | --export)
    EXPORTAR_REQS=true
    shift
    ;;
  -r | --refresh)
    FORZAR_REFRESCO=true
    shift
    ;;
  --raw)
    MODO_RAW=true
    shift
    ;;
  -h | --help) mostrar_ayuda ;;
  *)
    echo "Opción desconocida: $1" >&2
    exit 1
    ;;
  esac
done

# --- EJECUCIÓN MAESTRA SEGURO ---
if ! es_distrobox; then
  mkdir -p "$CACHE_DIR"
fi

if [ "$EXPORTAR_REQS" = true ] || [ ! -t 1 ] || [ "$MODO_RAW" = true ]; then
  MODO_RAW=true
  CLR_AZUL=""
  CLR_VERDE=""
  CLR_CIAN=""
  CLR_ROJO=""
  CLR_NEGRET=""
  CLR_RESET=""
fi

if es_distrobox; then
  listar_interno_distrobox
else
  if [ "$VER_SYSTEM" = false ] && [ "$VER_APPS" = false ] && [ "$VER_BREW" = false ] && [ "$VER_BBREW" = false ] && [ -z "$VER_DISTROBOX" ]; then
    echo "Error: Debe especificar al menos una capa (-s, -a, -b, -bb, -c o -d)." >&2
    exit 1
  fi

  if [ "$EXPORTAR_REQS" = true ] && [ "$MODO_RAW" = false ]; then
    echo -e "${CLR_CIAN}=== INICIANDO EXPORTACIÓN DE MANIFIESTOS ===${CLR_RESET}\n"
  fi

  [ "$VER_SYSTEM" = true ] && listar_sistema
  [ "$VER_APPS" = true ] && listar_apps
  [ "$VER_BREW" = true ] && listar_brew

  if [ "$VER_BBREW" = true ]; then
    if command -v bbrew &>/dev/null || [ "$EXPORTAR_REQS" = false ]; then
      listar_bbrew
    fi
  fi

  [ -n "$VER_DISTROBOX" ] && listar_externo_distrobox
fi

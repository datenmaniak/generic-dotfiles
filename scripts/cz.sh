#!/usr/bin/env bash

# ============================================================
# chezmoi - Gestor interactivo de dotfiles (Versión Optimizada)
# Ubicación: ~/admin/cz
# ============================================================

# Configuración del repositorio oculto
CHEZMOI_REPO="$HOME/.local/share/chezmoi"

# Iconos/Emojis para feedback visual ("Tech-Zen")
ICON_SUCCESS="✓"
ICON_ERROR="✗"
ICON_INFO="ℹ"
ICON_WARNING="⚠"
ICON_PROGRESS="▶"
DASH_="─"
ICON_FOLDER="📁"
ICON_GIT="📦"
ICON_CLOUD="☁️"
ICON_SSH="🔐"
ICON_K8S="⎈"
ICON_CONFIG="⚙️"
ICON_SCRIPT="📜"

# ============================================================
# Funciones de ayuda e interfaz
# ============================================================

print_header() {
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║               Gestor de Dotfiles (chezmoi)             ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
}

print_success() { echo "$ICON_SUCCESS $1"; }
print_error() { echo "$ICON_ERROR $1"; }
print_info() { echo "$ICON_INFO $1"; }
print_warning() { echo "$ICON_WARNING $1"; }
print_progress() { echo "$ICON_PROGRESS $1"; }

print_separator() {
  echo "${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}"
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  if [[ "$default" == "y" ]]; then prompt="$prompt [Y/n]: "; else prompt="$prompt [y/N]: "; fi
  read -r response
  response=${response:-$default}
  [[ "$response" =~ ^[Yy]$ ]] && return 0 || return 1
}

get_commit_message() {
  local msg="$1"
  [[ -n "$msg" ]] && { echo "$msg"; return 0; }
  local default_msg="Update dotfiles $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "┌────────────────────────────────────────────────────────┐"
  echo "│  Mensaje de commit (Enter para usar sugerencia)        │"
  echo "│  Sugerencia: $default_msg"
  echo "└────────────────────────────────────────────────────────┘"
  echo -n "> "
  read -r user_msg
  [[ -z "$user_msg" ]] && echo "$default_msg" || echo "$user_msg"
}

# ============================================================
# Acciones principales del menú
# ============================================================

action_status() {
  echo ""
  print_info "Estado actual de los dotfiles en el sistema:"
  print_separator
  chezmoi status
  print_separator
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_diff() {
  echo ""
  print_info "Diferencias detectadas entre el repositorio y tu \$HOME:"
  print_separator
  chezmoi diff
  print_separator
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_sync_matrix() {
  echo ""
  print_info "Sincronizando dotfiles mediante Matriz Asociativa"
  print_warning "Añadirá elementos nuevos y actualizará los ya existentes de forma quirúrgica"
  print_separator

  if confirm "¿Proceder con el escaneo inteligente?"; then
    echo ""
    
    # 1. DECLARACIÓN DE LA MATRIZ ASOCIATIVA UNIFICADA
    declare -A dotfiles_matrix
    
    # Entornos de terminal públicos (Texto Plano)
    dotfiles_matrix["$HOME/.bashrc"]="clear"
    dotfiles_matrix["$HOME/.zshrc"]="clear"
    dotfiles_matrix["$HOME/.bash_aliases"]="clear"
    dotfiles_matrix["$HOME/.zsh_aliases"]="clear"
    dotfiles_matrix["$HOME/.config/zellij"]="clear"
    dotfiles_matrix["$HOME/.config/starship.toml"]="clear"
    dotfiles_matrix["$HOME/.config/nvim"]="clear"
    dotfiles_matrix["$HOME/admin"]="clear"
    dotfiles_matrix["$HOME/.bin"]="clear"
    
    # Emuladores de terminal y multiplexores (Texto Plano)
    dotfiles_matrix["$HOME/.tmux.conf"]="clear"
    dotfiles_matrix["$HOME/.config/tmux"]="clear"
    dotfiles_matrix["$HOME/.config/alacritty"]="clear"
    dotfiles_matrix["$HOME/.config/kitty"]="clear"
    dotfiles_matrix["$HOME/.config/ghostty"]="clear"

    # Credenciales e infraestructura (Requieren Cifrado)
    dotfiles_matrix["$HOME/.ssh/id_ed25519"]="encrypt"
    dotfiles_matrix["$HOME/.ssh/id_ed25519.pub"]="clear"
    dotfiles_matrix["$HOME/.ssh/datenmaniak"]="encrypt"
    dotfiles_matrix["$HOME/.ssh/datenmaniak.pub"]="clear"
    dotfiles_matrix["$HOME/.ssh/config"]="clear"
    dotfiles_matrix["$HOME/.kube/config"]="encrypt"

    # LISTA DE CONTROL INTERMEDIA: Evita el bloqueo de expansión de Bash
    local targets=(
      "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_aliases" "$HOME/.zsh_aliases"
      "$HOME/.config/starship.toml" "$HOME/.config/nvim" "$HOME/admin" "$HOME/.bin"
      "$HOME/.config/zellij" "$HOME/.tmux.conf" "$HOME/.config/tmux"
      "$HOME/.config/alacritty" "$HOME/.config/kitty" "$HOME/.config/ghostty"
      "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"
      "$HOME/.ssh/datenmaniak" "$HOME/.ssh/datenmaniak.pub"
      "$HOME/.ssh/config" "$HOME/.kube/config"
    )

    # Listas temporales de procesamiento por lote
    local clear_batch=()
    local encrypt_targets=()
    
    echo "$ICON_FOLDER Analizando rutas y políticas de seguridad..."
    
    # # 2. VALIDACIÓN DE EXISTENCIA Y CLASIFICACIÓN
    # for path in "${!dotfiles_matrix[@]}"; do

    #   printf "\r   $ICON_PROGRESS Inspeccionando: %-40s" "$(basename "$path")"

    #   if [ -e "$path" ]; then
    #     if [ "${dotfiles_matrix[$path]}" == "clear" ]; then
    #       clear_batch+=("$path")
    #     elif [ "${dotfiles_matrix[$path]}" == "encrypt" ]; then
    #       encrypt_targets+=("$path")
    #     fi
    #   fi
    # done
    # ============================================================
    # 2. VALIDACIÓN DE EXISTENCIA CON FEEDBACK DINÁMICO
    # ============================================================
    for path in "${targets[@]}"; do
      # Imprime el archivo actual limpiando la línea para el efecto de scroll zen
      printf "\r\033[K   $ICON_PROGRESS Inspeccionando: %-40s" "$(basename "$path")"
      sleep 0.03  # Breve delay estético para percibir el escaneo visualmente
      
      if [ -e "$path" ]; then
        if [ "${dotfiles_matrix[$path]}" == "clear" ]; then
          clear_batch+=("$path")
        elif [ "${dotfiles_matrix[$path]}" == "encrypt" ]; then
          encrypt_targets+=("$path")
        fi
      fi
    done

    # Limpiamos la línea de lectura dinámica para dar paso al resumen fijo
    printf "\r\033[K"

    # Resumen estático en pantalla de lo encontrado
    echo "   $ICON_SUCCESS Análisis completado de forma segura."
    echo "   • Configuraciones públicas listas: ${#clear_batch[@]}"
    echo "   • Archivos cifrados protegidos: ${#encrypt_targets[@]}"
    echo ""

    # # Mostrar resumen visual del lote detectado
    # echo "   • Elementos en texto plano listos: ${#clear_batch[@]}"
    # echo "   • Elementos cifrados seguros listos: ${#encrypt_targets[@]}"
    # echo ""

    if [ ${#clear_batch[@]} -eq 0 ] && [ ${#encrypt_targets[@]} -eq 0 ]; then
      print_error "No se encontraron rutas locales válidas para procesar."
      read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
      return 1
    fi

    # 3. PROCESAMIENTO POR LOTE (TEXTO PLANO)
    if [ ${#clear_batch[@]} -gt 0 ]; then
      print_progress "Procesando configuraciones públicas de forma masiva..."
      if chezmoi add "${clear_batch[@]}"; then
        for item in "${clear_batch[@]}"; do
          echo "     $ICON_SUCCESS Sincronizado: $(basename "$item")"
        done
      else
        print_error "Ocurrió un inconveniente al indexar el lote de texto plano."
      fi
      echo ""
    fi

    # 4. PROCESAMIENTO AISLADO (CIFRADO GPG/AGE)
    if [ ${#encrypt_targets[@]} -gt 0 ]; then
      print_warning "Cifrando elementos sensibles de infraestructura..."
      print_info "Asegúrate de tener tu agente de claves desbloqueado para evitar demoras."
      echo ""
      
      for secure_path in "${encrypt_targets[@]}"; do
        echo -n "   $ICON_SSH Protegiendo: $(basename "$secure_path") ... "
        if chezmoi add --encrypt "$secure_path" 2>/dev/null; then
          echo "¡Completado!"
        else
          echo "Fallo"
          print_error "Revisa si chezmoi tiene acceso a tus claves de encriptación."
        fi
      done
      echo ""
    fi

    print_success "Matriz de dotfiles sincronizada con éxito."
    echo ""

    # Resumen automático posterior al escaneo
    print_info "Resumen del repositorio:"
    print_separator
    chezmoi status
    print_separator
  else
    print_info "Operación cancelada"
  fi

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_apply() {
  echo ""
  print_warning "Vas a aplicar los cambios del repositorio local hacia tu \$HOME"
  print_info "Esto puede sobrescribir cualquier cambio local que no haya sido trackeado"
  print_separator

  if confirm "¿Deseas ejecutar 'chezmoi apply'?"; then
    echo ""
    print_progress "Aplicando estado de dotfiles al sistema..."
    chezmoi apply -v
    print_success "Entorno actualizado correctamente"
  else
    print_info "Operación cancelada"
  fi

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_commit() {
  local quick_msg="$1"
  echo ""
  print_info "Preparando persistencia en Git"
  print_separator

  # Subshell aislada para evitar alterar el path del usuario al salir
  (
    cd "$CHEZMOI_REPO" || exit 1

    if git diff --quiet && git diff --cached --quiet; then
      print_warning "No existen modificaciones pendientes en el repositorio de chezmoi"
      exit 0
    fi

    local commit_msg
    commit_msg=$(get_commit_message "$quick_msg")

    echo ""
    print_info "Mensaje a registrar: $commit_msg"
    print_separator

    if confirm "¿Confirmar el registro de los cambios?"; then
      echo ""
      print_progress "Indexando y generando punto de control (Commit)..."
      git add -A
      git commit -m "$commit_msg"
      print_success "Punto de restauración guardado localmente"

      echo ""
      if confirm "¿Deseas subir los cambios a tu servidor Git remoto remoto ahora?"; then
        echo ""
        print_progress "Transfiriendo cambios al servidor de respaldo (Push)..."
        git push && print_success "Respaldo en la nube completado" || print_error "Error en la conexión con el servidor remoto"
      else
        print_info "Cambios resguardados localmente de forma segura."
      fi
    else
      print_info "Operación Git cancelada"
    fi
  )

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_log() {
  echo ""
  print_info "Historial de modificaciones del repositorio (Últimos 10 puntos):"
  print_separator
  (
    cd "$CHEZMOI_REPO" || exit 1
    git --no-pager log --oneline --graph -n 10
  )
  print_separator
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_open_repo() {
  echo ""
  print_info "Accediendo al entorno directo del repositorio de chezmoi"
  print_separator
  
  if [ -d "$CHEZMOI_REPO" ]; then
    (
      cd "$CHEZMOI_REPO" || exit 1
      ls -la
      echo ""
      print_info "Ruta: $CHEZMOI_REPO"
      print_warning "Escribe 'exit' o presiona Ctrl+D para volver al gestor interactivo"
      echo ""
      
      if [[ -n "$SHELL" ]]; then "$SHELL"; else /bin/bash; fi
    )
    print_success "Saliendo de la raíz de chezmoi. Retornando al menú..."
  else
    print_error "No se pudo localizar el directorio del repositorio en $CHEZMOI_REPO"
  fi
  
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

# ============================================================
# Interfaz del Menú Simplificado
# ============================================================

show_menu() {
  print_header
  echo "  1. Ver estado             - chezmoi status"
  echo "  2. Ver diferencias         - chezmoi diff"
  echo "  3. Sincronizar dotfiles   - Agregar/Actualizar (Matriz Inteligente)"
  echo "  4. Aplicar al sistema     - chezmoi apply"
  echo "  5. Confirmar en Git       - git commit + push remoto"
  echo "  6. Ver historial          - git log"
  echo "  7. Explorar repositorio   - Abrir shell en $CHEZMOI_REPO"
  echo ""
  echo "  0. Salir"
  print_separator
  echo -n "Elige una opción: "
}

quick_commit_mode() {
  local msg="$1"
  action_commit "$msg"
  exit 0
}

# ============================================================
# Hilo conductor principal (Main)
# ============================================================

main() {
  # Validación de dependencias críticas
  if ! command -v chezmoi &>/dev/null; then
    print_error "La utilidad 'chezmoi' no está instalada en este sistema o no se encuentra en el PATH."
    exit 1
  fi

  # Modo abreviado de confirmación instantánea (Alias externo)
  if [[ "$1" == "--quick-commit" ]]; then
    quick_commit_mode "$2"
    exit 0
  fi

  # Bucle interactivo continuo
  while true; do
    clear
    show_menu
    read -r choice

    case $choice in
    1) action_status ;;
    2) action_diff ;;
    3) action_sync_matrix ;;
    4) action_apply ;;
    5) action_commit ;;
    6) action_log ;;
    7) action_open_repo ;;
    0)
      echo ""
      print_success "Gestor cerrado correctamente. ¡Entorno listo!"
      exit 0
      ;;
    *)
      print_error "Opción incorrecta en el menú interactivo"
      sleep 1
      ;;
    esac
  done
}

# Despachar argumentos iniciales
main "$@"
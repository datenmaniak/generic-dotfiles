#!/usr/bin/env bash

# ============================================================
# chezmoi - Gestor interactivo de dotfiles
# Ubicación: ~/admin/cz
# ============================================================

# Configuración
CHEZMOI_REPO="$HOME/.local/share/chezmoi"

# Iconos/Emojis para feedback visual
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
# Funciones de ayuda
# ============================================================

print_header() {
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║               Gestor de Dotfiles (chezmoi)             ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
}

print_success() {
  echo "$ICON_SUCCESS $1"
}

print_error() {
  echo "$ICON_ERROR $1"
}

print_info() {
  echo "$ICON_INFO $1"
}

print_warning() {
  echo "$ICON_WARNING $1"
}

print_progress() {
  echo "$ICON_PROGRESS $1"
}

print_separator() {
  echo "$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_$DASH_"
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"

  if [[ "$default" == "y" ]]; then
    prompt="$prompt [Y/n]: "
  else
    prompt="$prompt [y/N]: "
  fi

  read -r response
  response=${response:-$default}

  if [[ "$response" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

get_commit_message() {
  local msg="$1"

  if [[ -n "$msg" ]]; then
    echo "$msg"
    return 0
  fi

  local default_msg="Update dotfiles $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "┌────────────────────────────────────────────────────────┐"
  echo "│  Mensaje de commit (Enter para usar sugerencia)        │"
  echo "│  Sugerencia: $default_msg"
  echo "└────────────────────────────────────────────────────────┘"
  echo -n "> "
  read -r user_msg

  if [[ -z "$user_msg" ]]; then
    echo "$default_msg"
  else
    echo "$user_msg"
  fi
}

# ============================================================
# Acciones principales
# ============================================================

action_status() {
  echo ""
  print_info "Estado actual de los dotfiles:"
  print_separator
  chezmoi status
  print_separator
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_diff() {
  echo ""
  print_info "Diferencias entre repo y sistema:"
  print_separator
  chezmoi diff
  print_separator
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_re_add() {
    echo ""
    print_warning "Vas a capturar cambios externos en el repositorio de chezmoi"
    print_info "Esto incluirá cualquier modificación hecha fuera de chezmoi"
    print_separator
    
    if confirm "¿Continuar con 'chezmoi re-add'?"; then
        echo ""
        
        # Mostrar qué directorios se van a escanear
        print_progress "$ICON_FOLDER Directorios a escanear:"
        echo "   • .zshrc, .bashrc, .tmux.conf"
        echo "   • .config/ (alacritty, kitty, nvim)"
        echo "   • .ssh/ (2 claves - encriptadas)"
        echo "   • .kube/ (config - encriptado)"
        echo "   • admin/ (scripts personalizados)"
        echo "   • .bin/ (binarios)"
        echo ""
        
        print_progress "$ICON_PROGRESS Iniciando captura de cambios..."
        echo ""
        
        # Spinner animado
        spinner() {
            local pid=$1
            local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            local i=0
            local start=$(date +%s)
            
            while kill -0 $pid 2>/dev/null; do
                i=$(( (i+1) % ${#spin} ))
                elapsed=$(($(date +%s) - start))
                printf "\r   ${spin:$i:1}  Procesando archivos...  [%02d:%02d]   " $((elapsed/60)) $((elapsed%60))
                sleep 0.1
            done
            printf "\r"
        }
        
        # Ejecutar re-add en background con spinner
        START_TIME=$(date +%s)
        
        # Temporal file para capturar output
        TMP_OUTPUT=$(mktemp)
        # chezmoi re-add -v > "$TMP_OUTPUT" 2>&1 &
        # chezmoi re-add -v 2>&1 | pv -l -s 100 > /dev/null
        chezmoi re-add --verbose --debug 2>&1 | while read line; do
            echo "$ICON_PROGRESS $line"
        done
        CMD_PID=$!
        
        # Mostrar spinner
        spinner $CMD_PID
        
        # Esperar a que termine
        wait $CMD_PID
        EXIT_CODE=$?
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        # Mostrar líneas importantes del output (las que no son silenciosas)
        echo ""
        echo ""
        if [ $EXIT_CODE -eq 0 ]; then
            # Filtrar y mostrar solo líneas relevantes
            grep -E "add|update|encrypt|skip" "$TMP_OUTPUT" 2>/dev/null | head -20
            if [ $(grep -c "add\|update" "$TMP_OUTPUT" 2>/dev/null) -gt 20 ]; then
                echo "   ... y $(($(grep -c "add\|update" "$TMP_OUTPUT") - 20)) archivos más"
            fi
            echo ""
            print_success "$ICON_SUCCESS Captura completada en ${DURATION}s"
            
            # Mostrar estadísticas
            MODIFIED_COUNT=$(grep -c "add\|update" "$TMP_OUTPUT" 2>/dev/null || echo "0")
            ENCRYPT_COUNT=$(grep -c "encrypt" "$TMP_OUTPUT" 2>/dev/null || echo "0")
            
            if [ $MODIFIED_COUNT -gt 0 ]; then
                echo ""
                print_info "Estadísticas de la captura:"
                echo "   • Archivos añadidos/actualizados: $MODIFIED_COUNT"
                [ $ENCRYPT_COUNT -gt 0 ] && echo "   • Archivos encriptados: $ENCRYPT_COUNT"
            fi
            
            # Mostrar resumen de cambios
            echo ""
            print_info "Resumen de cambios en el repositorio:"
            print_separator
            chezmoi status
            print_separator
        else
            print_error "$ICON_ERROR Error durante la captura"
            echo ""
            echo "Salida de error:"
            cat "$TMP_OUTPUT"
        fi
        
        # Limpiar
        rm -f "$TMP_OUTPUT"
        
        # Preguntar si quiere aplicar los cambios
        echo ""
        if confirm "¿Aplicar estos cambios al sistema ahora?"; then
            echo ""
            print_progress "$ICON_PROGRESS Aplicando cambios al sistema..."
            echo ""
            chezmoi apply -v
            print_success "$ICON_SUCCESS Cambios aplicados al sistema"
        else
            print_info "$ICON_INFO Puedes aplicar los cambios después con la opción 4 del menú"
        fi
    else
        print_info "$ICON_INFO Operación cancelada"
    fi
    
    echo ""
    read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_apply() {
  echo ""
  print_warning "Vas a aplicar los cambios del repositorio a tu sistema"
  print_info "Esto puede sobrescribir archivos locales modificados"
  print_separator

  if confirm "¿Continuar con 'chezmoi apply -v'?"; then
    echo ""
    print_progress "$ICON_PROGRESS Aplicando cambios del repositorio al sistema..."
    chezmoi apply -v
    print_success "$ICON_SUCCESS Cambios aplicados correctamente"
  else
    print_info "$ICON_INFO Operación cancelada"
  fi

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_add_new() {
  echo ""
  print_info "Vas a añadir NUEVOS directorios/archivos a chezmoi"
  print_warning "Esto es para archivos que NO están siendo trackeados actualmente"
  print_separator

  # Lista de directorios/archivos recomendados según tu configuración
  echo ""
  print_info "Directorios/archivos recomendados para añadir:"
  echo ""
  echo "  1. ~/.zshrc"
  echo "  2. ~/.bashrc"
  echo "  3. ~/.tmux.conf"
  echo "  4. ~/.config/alacritty/ (directorio completo)"
  echo "  5. ~/.config/kitty/ (directorio completo)"
  echo "  6. ~/.config/nvim/ (directorio completo)"
  echo "  7. ~/admin/ (tus scripts)"
  echo "  8. ~/.bin/ (binarios personales)"
  echo "  9. ~/.ssh/ $ICON_SSH (claves SSH - se encriptarán automáticamente)"
  echo " 10. ~/.kube/ $ICON_K8S (configuración K8s - se encriptará)"
  echo " 11. Todos los anteriores"
  echo "  0. Cancelar"
  echo ""
  echo -n "Elige una opción (0-11): "
  read -r add_choice

  case $add_choice in
  1)
    print_progress "$ICON_PROGRESS Añadiendo ~/.zshrc..."
    chezmoi add ~/.zshrc
    print_success "$ICON_SUCCESS ~/.zshrc añadido"
    ;;
  2)
    print_progress "$ICON_PROGRESS Añadiendo ~/.bashrc..."
    chezmoi add ~/.bashrc
    print_success "$ICON_SUCCESS ~/.bashrc añadido"
    ;;
  3)
    print_progress "$ICON_PROGRESS Añadiendo ~/.tmux.conf..."
    chezmoi add ~/.tmux.conf
    print_success "$ICON_SUCCESS ~/.tmux.conf añadido"
    ;;
  4)
    print_progress "$ICON_PROGRESS Añadiendo ~/.config/alacritty/..."
    chezmoi add ~/.config/alacritty/
    print_success "$ICON_SUCCESS ~/.config/alacritty/ añadido"
    ;;
  5)
    print_progress "$ICON_PROGRESS Añadiendo ~/.config/kitty/..."
    chezmoi add ~/.config/kitty/
    print_success "$ICON_SUCCESS ~/.config/kitty/ añadido"
    ;;
  6)
    print_progress "$ICON_PROGRESS Añadiendo ~/.config/nvim/..."
    chezmoi add ~/.config/nvim/
    print_success "$ICON_SUCCESS ~/.config/nvim/ añadido"
    ;;
  7)
    print_progress "$ICON_PROGRESS Añadiendo ~/admin/..."
    chezmoi add ~/admin/
    print_success "$ICON_SUCCESS ~/admin/ añadido"
    ;;
  8)
    print_progress "$ICON_PROGRESS Añadiendo ~/.bin/..."
    chezmoi add ~/.bin/
    print_success "$ICON_SUCCESS ~/.bin/ añadido"
    ;;
  9)
    print_progress "$ICON_PROGRESS $ICON_SSH Añadiendo claves SSH con encriptación..."
    chezmoi add --encrypt ~/.ssh/datenmaniak 2>/dev/null || print_warning "$ICON_WARNING datenmaniak no encontrado"
    chezmoi add --encrypt ~/.ssh/datenmaniak.pub 2>/dev/null || print_warning "$ICON_WARNING datenmaniak.pub no encontrado"
    chezmoi add --encrypt ~/.ssh/id_ed25519 2>/dev/null || print_warning "$ICON_WARNING id_ed25519 no encontrado"
    chezmoi add --encrypt ~/.ssh/id_ed25519.pub 2>/dev/null || print_warning "$ICON_WARNING id_ed25519.pub no encontrado"
    chezmoi add ~/.ssh/config 2>/dev/null || print_warning "$ICON_WARNING config no encontrado"
    print_success "$ICON_SUCCESS Archivos SSH añadidos (claves encriptadas)"
    ;;
  10)
    print_progress "$ICON_PROGRESS $ICON_K8S Añadiendo ~/.kube/ con encriptación..."
    if [ -d ~/.kube ]; then
      chezmoi add --encrypt ~/.kube/config 2>/dev/null || print_warning "$ICON_WARNING config no encontrado"
      print_success "$ICON_SUCCESS ~/.kube/config añadido (encriptado)"
    else
      print_warning "$ICON_WARNING ~/.kube/ no existe"
    fi
    ;;
  11)
    print_progress "$ICON_PROGRESS Añadiendo TODOS los directorios recomendados..."
    echo ""
    # Zsh y Bash
    [ -f ~/.zshrc ] && chezmoi add ~/.zshrc
    [ -f ~/.bashrc ] && chezmoi add ~/.bashrc
    [ -f ~/.tmux.conf ] && chezmoi add ~/.tmux.conf

    # Configuraciones
    [ -d ~/.config/alacritty ] && chezmoi add ~/.config/alacritty/
    [ -d ~/.config/kitty ] && chezmoi add ~/.config/kitty/
    [ -d ~/.config/nvim ] && chezmoi add ~/.config/nvim/

    # Scripts
    [ -d ~/admin ] && chezmoi add ~/admin/
    [ -d ~/.bin ] && chezmoi add ~/.bin/

    # SSH (encriptado)
    [ -f ~/.ssh/datenmaniak ] && chezmoi add --encrypt ~/.ssh/datenmaniak
    [ -f ~/.ssh/datenmaniak.pub ] && chezmoi add --encrypt ~/.ssh/datenmaniak.pub
    [ -f ~/.ssh/id_ed25519 ] && chezmoi add --encrypt ~/.ssh/id_ed25519
    [ -f ~/.ssh/id_ed25519.pub ] && chezmoi add --encrypt ~/.ssh/id_ed25519.pub
    [ -f ~/.ssh/config ] && chezmoi add ~/.ssh/config

    # Kubernetes
    [ -f ~/.kube/config ] && chezmoi add --encrypt ~/.kube/config

    print_success "$ICON_SUCCESS Todos los directorios añadidos"
    ;;
  0)
    print_info "$ICON_INFO Operación cancelada"
    ;;
  *)
    print_error "$ICON_ERROR Opción inválida"
    ;;
  esac

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_commit() {
  local quick_msg="$1"

  echo ""
  print_info "Vas a guardar los cambios en git"
  print_separator

  # Verificar si hay cambios para commitear
  cd "$CHEZMOI_REPO" || {
    print_error "$ICON_ERROR No se puede acceder al repositorio"
    return 1
  }

  if git diff --quiet && git diff --cached --quiet; then
    print_warning "$ICON_WARNING No hay cambios para commitear"
    cd - >/dev/null
    read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    return 0
  fi

  # Obtener mensaje de commit
  local commit_msg
  commit_msg=$(get_commit_message "$quick_msg")

  echo ""
  print_info "Mensaje: $commit_msg"
  print_separator

  if confirm "¿Guardar cambios con este mensaje?"; then
    echo ""
    print_progress "$ICON_GIT Añadiendo archivos al staging area..."
    git add -A
    print_progress "$ICON_GIT Realizando commit..."
    git commit -m "$commit_msg"
    print_success "$ICON_SUCCESS Commit realizado correctamente"

    # Preguntar por push
    echo ""
    if confirm "¿Push al remoto?"; then
      echo ""
      print_progress "$ICON_CLOUD Subiendo cambios al remoto..."
      git push
      print_success "$ICON_SUCCESS Push completado"
    else
      print_info "$ICON_INFO Cambios guardados localmente (sin push)"
    fi
  else
    print_info "$ICON_INFO Operación cancelada"
  fi

  cd - >/dev/null
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_log() {
  echo ""
  print_info "Historial de commits:"
  print_separator
  cd "$CHEZMOI_REPO" || {
    print_error "$ICON_ERROR No se puede acceder al repositorio"
    return 1
  }
  git --no-pager log --oneline --graph -n 10
  cd - >/dev/null
  print_separator
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_open_repo() {
  echo ""
  print_info "Abriendo repositorio de chezmoi..."
  print_separator
  cd "$CHEZMOI_REPO" || {
    print_error "$ICON_ERROR No se puede acceder al repositorio"
    return 1
  }
  ls -la
  echo ""
  print_info "Repositorio: $CHEZMOI_REPO"
  print_info "Para salir, escribe 'exit' o presiona Ctrl+D"
  echo ""

  # Abrir shell en el repositorio
  if [[ -n "$SHELL" ]]; then
    "$SHELL"
  else
    /bin/bash
  fi

  print_success "$ICON_SUCCESS Regresando al menú principal"
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

# ============================================================
# Menú principal
# ============================================================

show_menu() {
  print_header
  echo "  1. Ver estado         - chezmoi status"
  echo "  2. Ver diferencias     - chezmoi diff"
  echo "  3. Capturar cambios    - chezmoi re-add (con feedback)"
  echo "  4. Aplicar cambios     - chezmoi apply"
  echo "  5. Añadir nuevos archivos - primer vez o archivos nuevos"
  echo "  6. Guardar en git      - commit + push (opcional)"
  echo "  7. Ver historial       - git log"
  echo "  8. Abrir repositorio   - explorar $CHEZMOI_REPO"
  echo ""
  echo "  0. Salir"
  print_separator
  echo -n "Elige una opción: "
}

# ============================================================
# Modo quick commit (para usar con alias czc)
# ============================================================

quick_commit_mode() {
  local msg="$1"
  action_commit "$msg"
  exit 0
}

# ============================================================
# Main
# ============================================================

main() {
  # Verificar que chezmoi está instalado
  if ! command -v chezmoi &>/dev/null; then
    print_error "$ICON_ERROR chezmoi no está instalado"
    echo "Instálalo con: brew install chezmoi   (o tu gestor de paquetes)"
    exit 1
  fi

  # Modo quick commit
  if [[ "$1" == "--quick-commit" ]]; then
    quick_commit_mode "$2"
    exit 0
  fi

  # Modo interactivo
  while true; do
    clear
    show_menu
    read -r choice

    case $choice in
    1) action_status ;;
    2) action_diff ;;
    3) action_re_add ;;
    4) action_apply ;;
    5) action_add_new ;;
    6) action_commit ;;
    7) action_log ;;
    8) action_open_repo ;;
    0)
      echo ""
      print_success "$ICON_SUCCESS ¡Hasta luego!"
      exit 0
      ;;
    *)
      print_error "$ICON_ERROR Opción inválida"
      sleep 1
      ;;
    esac
  done
}

# Ejecutar main con todos los argumentos
main "$@"

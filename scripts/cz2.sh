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
  echo "${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}${DASH_}"
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

spinner() {
  local pid=$1
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  local start
  start=$(date +%s)
  
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % ${#spin} ))
    local elapsed=$(( $(date +%s) - start ))
    printf "\r   ${spin:$i:1}  Procesando archivos...  [%02d:%02d]   " $((elapsed/60)) $((elapsed%60))
    sleep 0.1
  done
  printf "\r"
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

# action_re_add() {
#   echo ""
#   print_warning "Vas a capturar cambios externos en el repositorio de chezmoi"
#   print_info "Esto incluirá cualquier modificación hecha fuera de chezmoi"
#   print_separator
  
#   if confirm "¿Continuar con 'chezmoi re-add'?"; then
#     echo ""
    
#     print_progress "$ICON_FOLDER Directorios controlados actuales:"
#     echo "   • .zshrc, .bashrc"
#     echo "   • .config/ (zellij, starship, nvim)"
#     echo "   • .ssh/ (Claves encriptadas)"
#     echo "   • .kube/ (Configuración K8s encriptada)"
#     echo "   • admin/ (Scripts de administración personalizados)"
#     echo "   • .bin/ (Binarios locales)"
#     echo ""
    
#     print_progress "$ICON_PROGRESS Iniciando captura de cambios..."
#     echo ""
    
#     local start_time
#     start_time=$(date +%s)
#     local tmp_output
#     tmp_output=$(mktemp)
    
#     # Ejecución correcta en background redirigiendo flujos al archivo temporal
#     chezmoi re-add --verbose --debug > "$tmp_output" 2>&1 &
#     local cmd_pid=$!
    
#     # Invocar spinner sobre el PID capturado
#     spinner "$cmd_pid"
    
#     wait "$cmd_pid"
#     local exit_code=$?
#     local end_time
#     end_time=$(date +%s)
#     local duration=$((end_time - start_time))
    
#     echo ""
#     if [ "$exit_code" -eq 0 ]; then
#       # Mostrar líneas relevantes de cambios del archivo temporal
#       grep -E "(add|update|encrypt|skip)" "$tmp_output" 2>/dev/null | head -20
      
#       local total_lines
#       total_lines=$(grep -c -E "(add|update)" "$tmp_output" 2>/dev/null || echo "0")
#       if [ "$total_lines" -gt 20 ]; then
#         echo "   ... y $((total_lines - 20)) archivos más."
#       fi
      
#       echo ""
#       print_success "Captura completada con éxito en ${duration}s"
      
#       # Estadísticas basadas en la salida real capturada
#       local modified_count
#       modified_count=$(grep -c -E "(add|update)" "$tmp_output" 2>/dev/null || echo "0")
#       local encrypt_count
#       encrypt_count=$(grep -c "encrypt" "$tmp_output" 2>/dev/null || echo "0")
      
#       if [ "$modified_count" -gt 0 ]; then
#         echo ""
#         print_info "Estadísticas de la captura:"
#         echo "   • Archivos añadidos/actualizados: $modified_count"
#         [ "$encrypt_count" -gt 0 ] && echo "   • Archivos encriptados: $encrypt_count"
#       fi
      
#       echo ""
#       print_info "Resumen del estado del repositorio:"
#       print_separator
#       chezmoi status
#       print_separator
#     else
#       print_error "Error crítico durante la captura de archivos"
#       echo ""
#       echo "Detalle del error:"
#       cat "$tmp_output"
#     fi
    
#     rm -f "$tmp_output"
    
#     echo ""
#     if confirm "¿Aplicar estos cambios al sistema ahora?"; then
#       echo ""
#       print_progress "$ICON_PROGRESS Aplicando cambios al sistema..."
#       echo ""
#       chezmoi apply -v
#       print_success "Cambios aplicados al sistema correctamente"
#     else
#       print_info "Puedes aplicar los cambios acumulados después con la opción 4 del menú."
#     fi
#   else
#     print_info "Operación cancelada"
#   fi
  
#   echo ""
#   read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
# }

action_re_add() {
  echo ""
  print_warning "Vas a capturar cambios externos en el repositorio de chezmoi"
  print_info "Esto incluirá cualquier modificación hecha fuera de chezmoi"
  print_separator
  
  if confirm "¿Continuar con 'chezmoi re-add'?"; then
    echo ""
    
    # 1. DEFINIR LOS TARGETS QUE REQUIERES RESPALDAR
    # Añadimos solo tus rutas clave para acotar el escaneo
    local targets=(
      "$HOME/.zshrc"
      "$HOME/.bashrc"
      "$HOME/.config/zellij"
      "$HOME/.config/starship.toml"
      "$HOME/.config/nvim"
      "$HOME/admin"
      "$HOME/.bin"
    )
    
    # 2. FILTRAR SOLO LOS QUE EXISTEN EN TU SISTEMA
    local valid_targets=()
    echo "$ICON_FOLDER Validando directorios a escanear:"
    for target in "${targets[@]}"; do
      if [ -e "$target" ]; then
        valid_targets+=("$target")
        echo "   • $(basename "$target") -> Listo"
      fi
    done
    echo ""
    
    # Si por alguna razón no hay directorios válidos, abortamos para evitar errores
    if [ ${#valid_targets[@]} -eq 0 ]; then
      print_error "No se encontraron directorios o archivos válidos para respaldar."
      read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
      return 1
    fi
    
    print_progress "$ICON_PROGRESS Iniciando captura de cambios..."
    echo ""
    
    local start_time
    start_time=$(date +%s)
    local tmp_output
    tmp_output=$(mktemp)
    
    # 3. CONDICIONAR EL COMANDO A LOS TARGETS VALIDADOS
    # Pasamos "${valid_targets[@]}" al final del comando de chezmoi
    chezmoi re-add --verbose --debug "${valid_targets[@]}" > "$tmp_output" 2>&1 &
    local cmd_pid=$!
    
    # Invocar spinner sobre el PID capturado
    spinner "$cmd_pid"
    
    wait "$cmd_pid"
    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    if [ "$exit_code" -eq 0 ]; then
      # Mostrar líneas relevantes de cambios del archivo temporal
      grep -E "(add|update|encrypt|skip)" "$tmp_output" 2>/dev/null | head -20
      
      local total_lines
      total_lines=$(grep -c -E "(add|update)" "$tmp_output" 2>/dev/null || echo "0")
      if [ "$total_lines" -gt 20 ]; then
        echo "   ... y $((total_lines - 20)) archivos más."
      fi
      
      echo ""
      print_success "Captura completada con éxito en ${duration}s"
      
      # Estadísticas basadas en la salida real capturada
      local modified_count
      modified_count=$(grep -c -E "(add|update)" "$tmp_output" 2>/dev/null || echo "0")
      local encrypt_count
      encrypt_count=$(grep -c "encrypt" "$tmp_output" 2>/dev/null || echo "0")
      
      if [ "$modified_count" -gt 0 ]; then
        echo ""
        print_info "Estadísticas de la captura:"
        echo "   • Archivos añadidos/actualizados: $modified_count"
        [ "$encrypt_count" -gt 0 ] && echo "   • Archivos encriptados: $encrypt_count"
      fi
      
      echo ""
      print_info "Resumen del estado del repositorio:"
      print_separator
      chezmoi status
      print_separator
    else
      print_error "Error crítico durante la captura de archivos"
      echo ""
      echo "Detalle del error:"
      cat "$tmp_output"
    fi
    
    rm -f "$tmp_output"
    
    echo ""
    if confirm "¿Aplicar estos cambios al sistema ahora?"; then
      echo ""
      print_progress "$ICON_PROGRESS Aplicando cambios al sistema..."
      echo ""
      chezmoi apply -v
      print_success "Cambios aplicados al sistema correctamente"
    else
      print_info "Puedes aplicar los cambios acumulados después con la opción 4 del menú."
    fi
  else
    print_info "Operación cancelada"
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
    print_success "Cambios aplicados correctamente"
  else
    print_info "Operación cancelada"
  fi

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_add_new() {
  echo ""
  print_info "Vas a añadir NUEVOS directorios/archivos a chezmoi"
  print_warning "Esto es para archivos que NO están siendo rastreados actualmente"
  print_separator

  echo ""
  print_info "Estructuras y entornos recomendados disponibles:"
  echo ""
  echo "  1. ~/.zshrc"
  echo "  2. ~/.bashrc"
  echo "  3. ~/.config/zellij/   $ICON_CONFIG (Configuración del multiplexor)"
  echo "  4. ~/.config/starship.toml (Prompt minimalista)"
  echo "  5. ~/.config/nvim/     $ICON_SCRIPT (Entorno Neovim)"
  echo "  6. ~/admin/            $ICON_FOLDER (Scripts personales de automatización)"
  echo "  7. ~/.bin/             $ICON_FOLDER (Binarios locales)"
  echo "  8. ~/.ssh/             $ICON_SSH (Claves de seguridad - Encriptación automática)"
  echo "  9. ~/.kube/            $ICON_K8S (Configuraciones de Clúster K8s - Encriptado)"
  echo " 10. Rastrear TODOS los elementos de forma masiva"
  echo "  0. Cancelar"
  echo ""
  echo -n "Elige una opción (0-10): "
  read -r add_choice

  case $add_choice in
  1)
    [ -f ~/.zshrc ] && { chezmoi add ~/.zshrc; print_success "~/.zshrc añadido"; } || print_error "No encontrado"
    ;;
  2)
    [ -f ~/.bashrc ] && { chezmoi add ~/.bashrc; print_success "~/.bashrc añadido"; } || print_error "No encontrado"
    ;;
  3)
    [ -d ~/.config/zellij ] && { chezmoi add ~/.config/zellij/; print_success "Configuración de Zellij añadida"; } || print_error "Directorio no encontrado"
    ;;
  4)
    [ -f ~/.config/starship.toml ] && { chezmoi add ~/.config/starship.toml; print_success "Configuración de Starship añadida"; } || print_error "Archivo no encontrado"
    ;;
  5)
    [ -d ~/.config/nvim ] && { chezmoi add ~/.config/nvim/; print_success "Configuración de Neovim añadida"; } || print_error "Directorio no encontrado"
    ;;
  6)
    [ -d ~/admin ] && { chezmoi add ~/admin/; print_success "Directorio admin/ añadido"; } || print_error "Directorio no encontrado"
    ;;
  7)
    [ -d ~/.bin ] && { chezmoi add ~/.bin/; print_success "Directorio .bin/ añadido"; } || print_error "Directorio no encontrado"
    ;;
  8)
    print_progress "$ICON_SSH Evaluando y encriptando claves de seguridad SSH..."
    local ssh_files=(
      "$HOME/.ssh/datenmaniak" "$HOME/.ssh/datenmaniak.pub"
      "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"
    )
    for file in "${ssh_files[@]}"; do
      if [ -f "$file" ]; then
        if [[ "$file" == *.pub ]]; then
          chezmoi add "$file"
        else
          chezmoi add --encrypt "$file"
        fi
        print_success "$(basename "$file") gestionado"
      fi
    done
    [ -f ~/.ssh/config ] && { chezmoi add ~/.ssh/config; print_success "Configuración de SSH añadida"; }
    ;;
  9)
    if [ -f ~/.kube/config ]; then
      print_progress "$ICON_K8S Encriptando archivo de configuración Kubernetes..."
      chezmoi add --encrypt ~/.kube/config
      print_success "Configuración de Kubernetes añadida y protegida"
    else
      print_warning "No se localizó configuración de clúster activa en ~/.kube/config"
    fi
    ;;
  10)
    print_progress "$ICON_PROGRESS Rastreando de forma segura toda la suite de desarrollo..."
    echo ""
    [ -f ~/.zshrc ] && chezmoi add ~/.zshrc
    [ -f ~/.bashrc ] && chezmoi add ~/.bashrc
    [ -d ~/.config/zellij ] && chezmoi add ~/.config/zellij/
    [ -f ~/.config/starship.toml ] && chezmoi add ~/.config/starship.toml
    [ -d ~/.config/nvim ] && chezmoi add ~/.config/nvim/
    [ -d ~/admin ] && chezmoi add ~/admin/
    [ -d ~/.bin ] && chezmoi add ~/.bin/
    
    # Encriptación de claves SSH y K8s preventivas
    for f in "$HOME"/.ssh/id_* "$HOME"/.ssh/datenmaniak*; do [ -f "$f" ] && [[ "$f" != *.pub ]] && chezmoi add --encrypt "$f"; [ -f "$f" ] && [[ "$f" == *.pub ]] && chezmoi add "$f"; done
    [ -f ~/.ssh/config ] && chezmoi add ~/.ssh/config
    [ -f ~/.kube/config ] && chezmoi add --encrypt ~/.kube/config
    
    print_success "Estructura completa de dotfiles sincronizada con la zona local de chezmoi"
    ;;
  0)
    print_info "Operación cancelada"
    ;;
  *)
    print_error "Opción inválida"
    ;;
  esac

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_commit() {
  local quick_msg="$1"

  echo ""
  print_info "Preparando persistencia de cambios en Git"
  print_separator

  # Uso de subshell para aislar de forma segura el entorno de trabajo y el cambio de directorios
  (
    cd "$CHEZMOI_REPO" || exit 1

    if git diff --quiet && git diff --cached --quiet; then
      print_warning "No existen modificaciones pendientes en el repositorio de chezmoi"
      exit 0
    fi

    local commit_msg
    commit_msg=$(get_commit_message "$quick_msg")

    echo ""
    print_info "Mensaje definitivo: $commit_msg"
    print_separator

    if confirm "¿Confirmar el registro de los cambios con este mensaje?"; then
      echo ""
      print_progress "$ICON_GIT Indexando cambios locales al árbol de staging..."
      git add -A
      print_progress "$ICON_GIT Confirmando commit..."
      git commit -m "$commit_msg"
      print_success "Commit registrado correctamente"

      echo ""
      if confirm "¿Deseas realizar un push inmediato hacia el repositorio remoto?"; then
        echo ""
        print_progress "$ICON_CLOUD Subiendo confirmaciones locales al servidor de control de versiones..."
        git push && print_success "Sincronización remota completada" || print_error "Fallo en la comunicación con el servidor remoto"
      else
        print_info "Cambios almacenados localmente de forma segura (sin push remoto)"
      fi
    else
      print_info "Operación de Git abortada"
    fi
  )

  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

action_log() {
  echo ""
  print_info "Historial de confirmaciones (Git Log):"
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
  print_info "Accediendo temporalmente al repositorio raíz de chezmoi..."
  print_separator
  
  if [ -d "$CHEZMOI_REPO" ]; then
    (
      cd "$CHEZMOI_REPO" || exit 1
      ls -la
      echo ""
      print_info "Ruta de trabajo activa: $CHEZMOI_REPO"
      print_info "Escribe 'exit' o presiona Ctrl+D para retornar al script"
      echo ""

      if [[ -n "$SHELL" ]]; then
        "$SHELL"
      else
        /bin/bash
      fi
    )
    print_success "Retornando al flujo principal del gestor"
  else
    print_error "No se puede localizar la raíz en $CHEZMOI_REPO"
  fi
  
  echo ""
  read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

# ============================================================
# Menú principal
# ============================================================

show_menu() {
  print_header
  echo "  1. Ver estado             - chezmoi status"
  echo "  2. Ver diferencias         - chezmoi diff"
  echo "  3. Capturar cambios locales - chezmoi re-add (con Spinner modular)"
  echo "  4. Aplicar configuraciones  - chezmoi apply"
  echo "  5. Rastrear nuevos dotfiles - Inicializar nuevos entornos"
  echo "  6. Confirmar cambios en git - commit + push opcional"
  echo "  7. Ver historial de cambios - git log"
  echo "  8. Abrir entorno del repo   - shell en $CHEZMOI_REPO"
  echo ""
  echo "  0. Salir"
  print_separator
  echo -n "Elige una opción: "
}

# ============================================================
# Modo quick commit (Alias externo)
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
  # Validación de dependencias básicas
  if ! command -v chezmoi &>/dev/null; then
    print_error "La utilidad 'chezmoi' no se encuentra disponible en el PATH actual."
    echo "Instálala a través del ecosistema de tu distribución actual."
    exit 1
  fi

  # Evaluar el modo abreviado
  if [[ "$1" == "--quick-commit" ]]; then
    quick_commit_mode "$2"
    exit 0
  fi

  # Flujo de ejecución interactivo
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
      print_success "Entorno de dotfiles cerrado de forma segura. ¡Hasta luego!"
      exit 0
      ;;
    *)
      print_error "Opción inválida en el menú"
      sleep 1
      ;;
    esac
  done
}

# Delegación de parámetros iniciales
main "$@"
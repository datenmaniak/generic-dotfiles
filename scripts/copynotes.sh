#!/bin/bash

# ============================================================
# sync-notes.sh - Sincroniza notas via NFS/SSH con chown
# Alternativa A: Permisos asignados durante rsync
# ============================================================

# Configuracion NFS/SSH
NFS_SERVER="root@pve1.dk.lab"
NFS_BASE="/pool/dknotes/app/public/notes"
SSH_KEY="~/.ssh/datenmaniak"
SSH_CMD="ssh -i ${SSH_KEY}"
-i ~/.ssh/datenmaniak

# Propietario para la app web
OWNER="www-data"
GROUP="www-data"

# Valores por defecto
DRY_RUN=false
DELETE_ORPHANS=false
RUTA_PERSONAL=""
LOCAL_DIR=""

# Exclusiones de directorios (siempre excluidos)
EXCLUDE_DIRS=".git node_modules .vscode .idea __pycache__ vendor dist build coverage .terraform"

# Exclusiones de archivos
EXCLUDE_FILES=".DS_Store *.swp .env* Thumbs.db *.log *.tmp"

# ============================================================
# Mostrar ayuda
# ============================================================
show_help() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "sync-notes.sh - Sincroniza notas con servidor NFS (DKNotes)"
  echo "Alternativa A: Permisos asignados durante rsync"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Uso: $0 <DIRECTORIO_LOCAL> --personal <RUTA> [OPCIONES]"
  echo ""
  echo "Argumentos:"
  echo "  DIRECTORIO_LOCAL       Ruta local de las notas (requerido)"
  echo "  -p, --personal RUTA    Ruta personal (subcarpeta) (requerido)"
  echo ""
  echo "Opciones:"
  echo "  -d, --dry-run          Simula la sincronizacion (no copia archivos)"
  echo "  -D, --delete-orphans   Elimina archivos en destino no existentes en origen"
  echo "  -h, --help             Muestra esta ayuda"
  echo ""
  echo "Caracteristicas:"
  echo "  - Los archivos se crean con propietario ${OWNER}:${GROUP}"
  echo "  - Permisos: directorios=755, archivos=644"
  echo "  - No requiere acceso a Kubernetes"
  echo ""
  echo "Ejemplos:"
  echo "  $0 ~/notes --personal usuario"
  echo "  $0 ~/notes -p proyecto-x --delete-orphans"
  echo "  $0 ~/mis-notas -p usuario --dry-run"
  echo ""
}

# ============================================================
# Normalizar ruta personal (solo a-z)
# ============================================================
normalize_personal_path() {
  local original="$RUTA_PERSONAL"
  local normalized

  normalized=$(echo "$original" | tr '[:upper:]' '[:lower:]')
  normalized=$(echo "$normalized" | sed 's/[áäâà]/a/g; s/[éëêè]/e/g; s/[íïîì]/i/g; s/[óöôò]/o/g; s/[úüûù]/u/g')
  normalized=$(echo "$normalized" | sed 's/ñ/n/g')
  normalized=$(echo "$normalized" | sed 's/[^a-z]//g')

  if [ -z "$normalized" ]; then
    echo ""
    echo "ERROR: La ruta personal no contiene caracteres validos"
    echo "Original: \"$original\" → Despues de normalizar: (vacio)"
    echo ""
    exit 1
  fi

  if [ ${#normalized} -gt 100 ]; then
    normalized="${normalized:0:100}"
    echo "  (Ruta personal truncada a 100 caracteres)"
  fi

  if [ "$normalized" != "$original" ]; then
    echo "  Ruta personal normalizada: \"$original\" → \"$normalized\""
  fi

  RUTA_PERSONAL="$normalized"
  echo "  OK: Ruta personal: $RUTA_PERSONAL"
}

# ============================================================
# Verificar conectividad SSH
# ============================================================
check_ssh_connection() {
  echo -n "  Verificando conexion SSH con servidor NFS... "

  if ${SSH_CMD} -o ConnectTimeout=5 "${NFS_SERVER}" "exit" 2>/dev/null; then
    echo "OK"
    return 0
  else
    echo "ERROR"
    echo ""
    echo "❌ No se pudo conectar al servidor NFS: ${NFS_SERVER}"
    echo ""
    echo "Verifica:"
    echo "  - La clave SSH existe en: ${SSH_KEY}"
    echo "  - El servidor es accesible"
    echo "  - La clave esta autorizada en el servidor"
    echo ""
    exit 1
  fi
}

# ============================================================
# Verificar si el directorio local existe
# ============================================================
check_local_dir() {
  if [ ! -d "$LOCAL_DIR" ]; then
    echo "ERROR: El directorio local no existe: ${LOCAL_DIR}"
    exit 1
  fi
  echo "  OK: Directorio local encontrado: ${LOCAL_DIR}"
}

# ============================================================
# Verificar usuario www-data en el servidor NFS
# ============================================================
check_www_data_on_nfs() {
  echo -n "  Verificando usuario ${OWNER} en servidor NFS... "

  if ${SSH_CMD} "${NFS_SERVER}" "id ${OWNER} >/dev/null 2>&1"; then
    echo "OK"
    return 0
  else
    echo "ERROR"
    echo ""
    echo "⚠️  El usuario ${OWNER} no existe en el servidor NFS"
    echo ""
    echo "Esto significa que --chown=${OWNER}:${GROUP} podria fallar."
    echo ""
    echo "Sugerencias:"
    echo "  1. Crear el usuario www-data en el servidor NFS"
    echo "  2. Usar Alternativa C (kubectl) en su lugar"
    echo "  3. Forzar el uso de UID numerico (33:33) modificando este script"
    echo ""

    read -p "¿Deseas continuar de todas formas? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
      exit 1
    fi
  fi
}

# ============================================================
# Verificar/Crear directorio destino
# ============================================================
check_and_create_dest_dir() {
  DESTINO_FINAL="${NFS_BASE}/${RUTA_PERSONAL}"

  echo -n "  Verificando directorio destino... "

  if ${SSH_CMD} "${NFS_SERVER}" "test -d '${DESTINO_FINAL}'" 2>/dev/null; then
    echo "existe"
    return 0
  else
    echo "no existe, creando..."

    # Crear directorio con permisos correctos desde el inicio
    ${SSH_CMD} "${NFS_SERVER}" "mkdir -p '${DESTINO_FINAL}' && chown ${OWNER}:${GROUP} '${DESTINO_FINAL}' && chmod 755 '${DESTINO_FINAL}'"

    if [ $? -eq 0 ]; then
      echo "  ✅ Directorio creado con permisos ${OWNER}:${GROUP} (755)"
      return 0
    else
      echo ""
      echo "❌ ERROR: No se pudo crear el directorio destino"
      exit 1
    fi
  fi
}

# ============================================================
# Mostrar resumen (dry-run)
# ============================================================
show_dry_run_summary() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Modo simulacion (dry-run)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  echo "Origen: ${LOCAL_DIR}"
  echo "Destino: ${NFS_SERVER}:${NFS_BASE}/${RUTA_PERSONAL}"
  echo "Propietario: ${OWNER}:${GROUP}"
  echo "Permisos: Directorios=755, Archivos=644"
  echo ""

  RSYNC_CMD="rsync -avzn --chown=${OWNER}:${GROUP} --chmod=D755,F644"

  for dir in $EXCLUDE_DIRS; do
    RSYNC_CMD="${RSYNC_CMD} --exclude='${dir}'"
  done

  # Exclusiones de archivos
  for pattern in $EXCLUDE_FILES; do
    RSYNC_CMD="${RSYNC_CMD} --exclude='${pattern}'"
  done

  # Excluir todo lo demás
  RSYNC_CMD="${RSYNC_CMD} --exclude='*'"

  if [ "$DELETE_ORPHANS" = true ]; then
    RSYNC_CMD="${RSYNC_CMD} --delete"
    echo "Eliminacion de huerfanos: ACTIVADA"
  else
    echo "Eliminacion de huerfanos: DESACTIVADA"
  fi

  RSYNC_CMD="${RSYNC_CMD} -e '${SSH_CMD}'"
  RSYNC_CMD="${RSYNC_CMD} '${LOCAL_DIR}/' '${NFS_SERVER}:${NFS_BASE}/${RUTA_PERSONAL}/'"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  eval ${RSYNC_CMD}
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================
# Ejecutar sincronizacion real
# ============================================================
run_sync() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Sincronizando notas (con asignacion de permisos)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Construir comando rsync con --chown y --chmod
  RSYNC_CMD="rsync -avz --progress --chown=${OWNER}:${GROUP} --chmod=D755,F644"

  # Patrones de inclusión (solo .md y directorios)
  RSYNC_CMD="${RSYNC_CMD} --include='*.md'"
  RSYNC_CMD="${RSYNC_CMD} --include='*/'"

  # Exclusiones de directorios
  for dir in $EXCLUDE_DIRS; do
    RSYNC_CMD="${RSYNC_CMD} --exclude='${dir}'"
  done

  # Exclusiones de archivos
  for pattern in $EXCLUDE_FILES; do
    RSYNC_CMD="${RSYNC_CMD} --exclude='${pattern}'"
  done

  # Excluir todo lo demás
  RSYNC_CMD="${RSYNC_CMD} --exclude='*'"

  if [ "$DELETE_ORPHANS" = true ]; then
    RSYNC_CMD="${RSYNC_CMD} --delete"
    echo "  Modo: Sincronizacion completa (con eliminacion de huerfanos)"
  else
    echo "  Modo: Sincronizacion incremental (sin eliminar huerfanos)"
  fi

  RSYNC_CMD="${RSYNC_CMD} -e '${SSH_CMD}'"
  RSYNC_CMD="${RSYNC_CMD} '${LOCAL_DIR}/' '${NFS_SERVER}:${NFS_BASE}/${RUTA_PERSONAL}/'"

  echo "  Origen:   ${LOCAL_DIR}"
  echo "  Destino:  ${NFS_SERVER}:${NFS_BASE}/${RUTA_PERSONAL}"
  echo "  Dueño:    ${OWNER}:${GROUP}"
  echo "  Permisos: d=755, f=644"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Ejecutar rsync
  eval ${RSYNC_CMD}

  if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Sincronizacion completada exitosamente"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📌 Los archivos ya tienen los permisos correctos (${OWNER}:${GROUP})"
    echo "   Las notas estan disponibles para la aplicacion web."
    echo ""
    echo "   Si las notas no aparecen inmediatamente:"
    echo "   1. Accede a la aplicacion web DKNotes"
    echo "   2. Ve a 'Sincronizacion' y haz clic en 'Sincronizar notas'"
    echo "   3. Revisa 'Mis Notas'"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo ""
    echo "❌ ERROR: La sincronizacion fallo"
    exit 1
  fi
}

# ============================================================
# Procesar argumentos
# ============================================================
while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
    show_help
    exit 0
    ;;
  -d | --dry-run)
    DRY_RUN=true
    shift
    ;;
  -D | --delete-orphans)
    DELETE_ORPHANS=true
    shift
    ;;
  -p | --personal)
    RUTA_PERSONAL="$2"
    shift 2
    ;;
  -*)
    echo "ERROR: Opcion desconocida: $1"
    exit 1
    ;;
  *)
    LOCAL_DIR="$1"
    shift
    ;;
  esac
done

# ============================================================
# Validaciones iniciales
# ============================================================
if [ -z "$LOCAL_DIR" ]; then
  echo "ERROR: Debes especificar el directorio local de notas"
  show_help
  exit 1
fi

if [ -z "$RUTA_PERSONAL" ]; then
  echo "ERROR: Debes especificar la ruta personal con --personal"
  echo "Ejemplo: $0 ~/notes --personal usuario"
  exit 1
fi

# ============================================================
# Ejecutar script
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DKNotes - Sincronizacion de notas (Alternativa A)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check_local_dir
check_ssh_connection
check_www_data_on_nfs
normalize_personal_path

if [ "$DRY_RUN" = true ]; then
  # En dry-run no creamos directorio, solo verificamos existencia
  DESTINO_FINAL="${NFS_BASE}/${RUTA_PERSONAL}"
  if ! ${SSH_CMD} "${NFS_SERVER}" "test -d '${DESTINO_FINAL}'" 2>/dev/null; then
    echo ""
    echo "⚠️  El directorio destino no existe (dry-run)"
    echo "   En modo real se creara automaticamente"
    echo ""
  fi
  show_dry_run_summary
else
  check_and_create_dest_dir
  run_sync
fi

echo ""

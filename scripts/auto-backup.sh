#!/bin/bash

# Respalda lo esencial 
#
#

#rsync -av --dry-run ~/Documents ~/Pictures ~/Projects ~/admin \
#~/.ssh /run/media/wpp/WD-external/western/desktop-pc/ 


MOUNTDSK="/run/media/wpp/WD-external"
DEST="/run/media/wpp/WD-external/western/desktop-pc-ryzer5-backup/"

SOURCE="/home/wpp"

DIRS=("Documents" "Pictures" "Projects" "admin" ".ssh" ".config" ".kube" ".password-store" ".vscode")

if ! mountpoint -q "$MOUNTDSK"; then 
   echo "Error: destino no esta montado"
  exit 1
fi

echo 'Inicia Backup'

rsync -av --dry-run --progress "$SOURCE" "$DEST" > /home/wpp/auto-backup.log 2>&1
for dir in "${DIRS[@]}"
do 
    echo -e "$SOURCE/$dir"
    rsync -av  \
    --exclude="vivaldi" \
    --exclude='thunderbird' \
    --exclude='opencode' \
    --exclude='libreoffice' \
    --exclude='chromium' \
    --exclude='.cache' \
    "$SOURCE/$dir" "$DEST" 
done



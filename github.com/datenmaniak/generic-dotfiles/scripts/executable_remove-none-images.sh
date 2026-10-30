#!/bin/bash
# Script para eliminar todas las imágenes <none> en Podman

echo "Buscando imágenes <none>..."

# Listar imágenes con <none> y eliminarlas
podman images -f "dangling=true" -q | while read -r img; do
  if [ -n "$img" ]; then
    echo "Eliminando imagen: $img"
    podman rmi -f "$img"
  fi
done

echo "Proceso completado."

podman image ls

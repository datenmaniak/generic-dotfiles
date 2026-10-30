#!/usr/bin/env python3
"""
redimensionar_imagen.py
Redimensiona y optimiza imágenes usando ImageMagick.

Uso:
    ./redimensionar_imagen.py <archivo> <dpi> <largo> [ancho] [opciones]

Parámetros obligatorios:
    archivo      : Ruta de la imagen de entrada
    dpi          : DPI (número o alias: web, screen, photo, print, logo)
    largo        : Dimensión principal en píxeles

Opciones:
    ancho        : Dimensión secundaria en píxeles (opcional; se calcula proporcionalmente)
    -d, --dest   : Directorio de salida (opcional; si no existe, muestra alerta y sale)
    --code       : Generar código para embedir la imagen (Markdown + HTML)
    -o, --overwrite : Sobrescribir el archivo original
    -n, --dry-run   : Solo mostrar qué haría sin crear archivo
"""

import argparse
import os
import sys
import subprocess
import shutil
import uuid
from pathlib import Path
from functools import partial

# Mapeo de alias de DPI a valores numéricos
DPI_ALIASES = {
    "web": 72,
    "screen": 96,
    "photo": 150,
    "print": 300,
    "logo": 600
}

# Rango válido de DPI
DPI_MIN = 1
DPI_MAX = 2400

# Rango máximo de píxeles para dimensiones
DIMENSION_MAX = 10000

# Namespace para UUIDv5 (usamos el namespace URL)
UUID_NAMESPACE = uuid.NAMESPACE_URL


def parse_dpi(value: str) -> int:
    """Convierte un alias o número de DPI a valor numérico."""
    v_lower = value.lower()
    if v_lower in DPI_ALIASES:
        return DPI_ALIASES[v_lower]
    try:
        dpi = int(value)
        if dpi < DPI_MIN or dpi > DPI_MAX:
            raise ValueError(f"DPI fuera de rango ({DPI_MIN}–{DPI_MAX})")
        return dpi
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"DPI inválido '{value}': {e}")


def parse_dimension(value: str, name: str = "Dimensión") -> int:
    """Valida una dimensión (largo/ancho)."""
    value = value.strip()
    try:
        dim = int(value)
        if dim <= 0 or dim > DIMENSION_MAX:
            raise ValueError(f"{name} fuera de rango (1–{DIMENSION_MAX})")
        return dim
    except ValueError as e:
        if "invalid literal" in str(e):
            raise argparse.ArgumentTypeError(f"{name} inválido '{value}': debe ser un número entero (ej. 640)")
        raise argparse.ArgumentTypeError(f"{name} inválido '{value}': {e}")


def generar_nombre_uuid(ruta_origen: Path) -> str:
    """
    Genera un nombre de archivo usando UUIDv5 determinista basado en la ruta absoluta.
    Devuelve solo el nombre (sin directorio), manteniendo la extensión original.
    """
    ruta_abs = str(ruta_origen.resolve())
    u = uuid.uuid5(UUID_NAMESPACE, ruta_abs)
    uuid_con_guiones = str(u)
    suffix = ruta_origen.suffix
    nombre_nuevo = f"{uuid_con_guiones}{suffix}"
    return nombre_nuevo


def get_file_size_kb(filepath: str) -> float:
    """Devuelve el tamaño del archivo en KB."""
    size_bytes = os.path.getsize(filepath)
    return size_bytes / 1024.0


def get_image_dimensions(filepath: str) -> tuple:
    """Obtiene ancho y alto de la imagen usando ImageMagick (identify)."""
    cmd = ["identify", "-format", "%w %h", filepath]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Error al leer dimensiones: {result.stderr}")
    ancho, alto = map(int, result.stdout.strip().split())
    return ancho, alto


def generarCodigoEmbedir(ruta_salida_abs: str, nombre_original: str) -> None:
    """
    Genera y imprime en consola el código para embedir la imagen en Markdown y HTML.
    - 2 formas en Markdown: sintaxis ![alt](src) y tag <img src>
    - 1 forma en HTML: <img src="" alt="">
    - Usa ruta ABSOLUTA en src
    - Alt text basado en el nombre original sin extensión
    """
    alt_text = nombre_original
    src = ruta_salida_abs
    
    print("\n### Código para embedir la imagen:\n")
    print("Markdown (sintaxis):")
    print(f"![{alt_text}]({src})")
    print()
    print("Markdown (tag HTML):")
    print(f"<img src=\"{src}\" alt=\"{alt_text}\">")
    print()
    print("HTML:")
    print(f"<img src=\"{src}\" alt=\"{alt_text}\">")


def redimensionar_imagen(
    archivo_entrada: str,
    dpi: int,
    largo: int,
    ancho: int | None,
    destino_dir: str | None,
    sobrescribir: bool = False,
    dry_run: bool = False,
    generar_cod: bool = False
) -> None:
    """
    Redimensiona la imagen con ImageMagick.

    Si ancho es None, se calcula proporcionalmente.
    Si destino_dir es None, se usa el mismo directorio que el original.
    Si destino_dir no existe, muestra alerta y sale.
    Si sobrescribir=True, sobrescribe el original.
    Si dry_run=True, solo muestra lo que haría sin crear archivo.
    Si generar_cod=True, imprime código para embedir la imagen.
    """
    ruta_entrada = Path(archivo_entrada).resolve()
    if not ruta_entrada.exists():
        raise FileNotFoundError(f"Archivo no encontrado: {ruta_entrada}")

    # Validar directorio de destino si se proporcionó
    if destino_dir is not None:
        ruta_destino = Path(destino_dir).resolve()
        if not ruta_destino.exists():
            print(f"❌ El directorio de destino no existe: {ruta_destino}", file=sys.stderr)
            print("Ejecución cancelada.", file=sys.stderr)
            sys.exit(1)
        if not ruta_destino.is_dir():
            print(f"❌ El destino proporcionado no es un directorio: {ruta_destino}", file=sys.stderr)
            print("Ejecución cancelada.", file=sys.stderr)
            sys.exit(1)
    else:
        ruta_destino = ruta_entrada.parent

    # Obtener dimensiones originales
    ancho_orig, alto_orig = get_image_dimensions(str(ruta_entrada))
    rel_aspect_original = ancho_orig / alto_orig

    # Calcular dimensiones finales
    if ancho is None:
        if alto_orig >= ancho_orig:
            nuevo_alto = largo
            nuevo_ancho = int(round(nuevo_alto * rel_aspect_original))
        else:
            nuevo_ancho = largo
            nuevo_alto = int(round(nuevo_ancho / rel_aspect_original))
    else:
        nuevo_ancho = ancho
        nuevo_alto = largo

    # Validar dimensiones finales
    if nuevo_ancho <= 0 or nuevo_alto <= 0:
        raise ValueError("Dimensiones finales inválidas (deben ser > 0)")
    if nuevo_ancho > DIMENSION_MAX or nuevo_alto > DIMENSION_MAX:
        raise ValueError(f"Dimensiones finales exceden el máximo ({DIMENSION_MAX})")

    # Preparar ruta de salida
    if sobrescribir:
        ruta_salida = ruta_entrada
        nombre_salida = str(ruta_entrada)
        nombre_original = ruta_entrada.stem
    else:
        nombre_con_uuid = generar_nombre_uuid(ruta_entrada)
        ruta_salida = ruta_destino / nombre_con_uuid
        nombre_salida = str(ruta_salida)
        nombre_original = ruta_entrada.stem

    if dry_run:
        print("=== MODO DRY-RUN (no se crea archivo) ===")
        print(f"Entrada      : {ruta_entrada}")
        print(f"Salida       : {nombre_salida}")
        print(f"DPI aplicado : {dpi}")
        print(f"Dimensiones originales: {ancho_orig}x{alto_orig}")
        print(f"Dimensiones finales   : {nuevo_ancho}x{nuevo_alto}")
        print(f"Relación de aspecto original: {rel_aspect_original:.4f}")
        if ancho is None:
            print("Ancho calculado proporcionalmente (largo interpretado según orientación)")
        else:
            print("Ancho forzado (puede deformar la imagen)")
        if destino_dir is not None:
            print(f"Directorio de destino: {ruta_destino}")
        return

    # Construir comando ImageMagick
    convert_cmd = "convert" if shutil.which("convert") else None
    magick_cmd = "magick" if shutil.which("magick") else None

    if not convert_cmd and not magick_cmd:
        raise RuntimeError("ImageMagick no encontrado. Instala 'imagemagick' (convert o magick).")

    base_cmd = [magick_cmd] if magick_cmd else [convert_cmd]

    cmd = base_cmd + [
        str(ruta_entrada),
        "-strip",
        "-density", str(dpi),
        "-resize", f"{nuevo_ancho}x{nuevo_alto}",
        "-quality", "85",
        "-interlace", "Plane",
        nombre_salida
    ]

    print(f"Ejecutando: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        raise RuntimeError(f"Error al redimensionar: {result.stderr}")

    # Reportar resultados
    tamaño_orig_kb = get_file_size_kb(str(ruta_entrada))
    tamaño_final_kb = get_file_size_kb(nombre_salida)
    reduccion_pct = (1 - tamaño_final_kb / tamaño_orig_kb) * 100 if tamaño_orig_kb > 0 else 0

    print("\n=== RESULTADOS ===")
    print(f"Archivo entrada     : {ruta_entrada}")
    print(f"Archivo salida      : {nombre_salida}")
    print(f"DPI aplicado        : {dpi}")
    print(f"Dimensiones orig.   : {ancho_orig}x{alto_orig}")
    print(f"Dimensiones finales : {nuevo_ancho}x{nuevo_alto}")
    print(f"Tamaño original     : {tamaño_orig_kb:.2f} KB")
    print(f"Tamaño final        : {tamaño_final_kb:.2f} KB")
    print(f"Reducción           : {reduccion_pct:.1f}%")

    # Generar código para embedir si se solicitó
    if generar_cod:
        ruta_salida_abs = str(ruta_salida.resolve())
        generarCodigoEmbedir(ruta_salida_abs, nombre_original)


def main():
    parser = argparse.ArgumentParser(
        description="Redimensiona y optimiza imágenes usando ImageMagick.",
        epilog="""Ejemplos:
  %(prog)s foto.jpg web 800
  %(prog)s foto.jpg web 800 -d ~/public/images/
  %(prog)s logo.png print 1024 1024 --code
  %(prog)s imagen.webp screen 600 -d ./output --code

Opciones de DPI:
  web    -> 72 DPI   (redes sociales, web básica)
  screen -> 96 DPI   (web moderna, pantallas HD)
  photo  -> 150 DPI  (fotografía para impresión pequeña)
  print  -> 300 DPI  (fotografía profesional, impresión de alta calidad)
  logo   -> 600 DPI  (logotipos para impresión fina/alta resolución)
""",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument("archivo", help="Ruta de la imagen de entrada")
    parser.add_argument(
        "dpi",
        type=parse_dpi,
        help="DPI (número o alias: web, screen, photo, print, logo)"
    )
    parser.add_argument(
        "largo",
        type=partial(parse_dimension, name="Largo"),
        help="Dimensión principal en píxeles (obligatorio)"
    )
    parser.add_argument(
        "ancho",
        nargs="?",
        type=partial(parse_dimension, name="Ancho"),
        default=None,
        help="Dimensión secundaria en píxeles (opcional; se calcula proporcionalmente si se omite)"
    )
    parser.add_argument(
        "-d", "--dest",
        type=str,
        default=None,
        help="Directorio donde guardar la imagen redimensionada. Si no existe, muestra alerta y sale."
    )
    parser.add_argument(
        "--code",
        action="store_true",
        help="Generar en consola código para embedir la imagen (Markdown + HTML con ruta absoluta)"
    )
    parser.add_argument(
        "-o", "--overwrite",
        action="store_true",
        help="Sobrescribir el archivo original en lugar de crear archivo con UUID"
    )
    parser.add_argument(
        "-n", "--dry-run",
        action="store_true",
        help="Solo mostrar qué haría sin crear archivo"
    )

    args = parser.parse_args()

    try:
        redimensionar_imagen(
            archivo_entrada=args.archivo,
            dpi=args.dpi,
            largo=args.largo,
            ancho=args.ancho,
            destino_dir=args.dest,
            sobrescribir=args.overwrite,
            dry_run=args.dry_run,
            generar_cod=args.code
        )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

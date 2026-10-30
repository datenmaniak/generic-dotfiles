configure_flathub_and_apps() {
    if command -v flatpak >/dev/null 2>&1; then
        echo "🔄 Añadiendo Flathub..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

        echo "📦 Instalando Flatpaks básicos..."
        flatpak install -y --system flathub md.obsidian.Obsidian \
            com.obsproject.Studio \
            org.videolan.VLC \
            com.vivaldi.Vivaldi
    else
        echo "ℹ 'flatpak' no disponible; se omiten los paquetes Flatpak."
    fi
}

configure_flathub_and_apps


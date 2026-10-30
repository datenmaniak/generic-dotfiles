#!/usr/bin/bash

# Respaldo de configuraciones del sistema base en Hypervisor Proxmox
# Uso: Este script respalda configuraciones críticas de Debian/Proxmox
#       para facilitar una reinstalación limpia del sistema.

DST="/home/datenmaniak/wjpp/70-79_devops/72_proxmox/server"

check_dir() {
    NDST=${DST}/$1
    if [ ! -d "${NDST}" ]; then
        echo "Destino no existe: ${NDST}..."
        mkdir -p ${NDST}
        chmod 775 ${NDST}
    fi
}

# TODO:  '--delete' '--progress'
#
#   1. agregar estos argumentos a rsync
#   2. refactorizar el codigo, no repetir la isntruccion: rsync

# ============================================================
# 1. Respaldo de /root
# ============================================================
REMOTEPATH="/root"
check_dir "$REMOTEPATH"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH}/ ${DST}/${REMOTEPATH}/

# ============================================================
# 2. Respaldo de /root/.ssh (claves SSH de root)
# ============================================================
REMOTEPATH="/root/.ssh"
check_dir "$REMOTEPATH"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH}/ ${DST}/${REMOTEPATH}/

# ============================================================
# 3. Respaldo de configuración de red
# ============================================================
REMOTEPATH="/etc/network/interfaces"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 4. Respaldo de /etc/hosts
# ============================================================
REMOTEPATH="/etc/hosts"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 5. Respaldo de /etc/hostname
# ============================================================
REMOTEPATH="/etc/hostname"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 6. Respaldo de repositorios APT
# ============================================================
REMOTEPATH="/etc/apt/sources.list"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

REMOTEPATH="/etc/apt/sources.list.d"
check_dir "$REMOTEPATH"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH}/ ${DST}${REMOTEPATH}/

# ============================================================
# 7. Respaldo de /etc/fstab (montajes)
# ============================================================
REMOTEPATH="/etc/fstab"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 8. Respaldo de configuración NFS
# ============================================================
REMOTEPATH="/etc/exports"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

REMOTEPATH="/etc/default/nfs-common"
if ssh -i ~/.ssh/datenmaniak root@192.168.1.201 "test -f ${REMOTEPATH}"; then
    check_dir "$(dirname ${REMOTEPATH})"
    rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}
fi

REMOTEPATH="/etc/default/nfs-kernel-server"
if ssh -i ~/.ssh/datenmaniak root@192.168.1.201 "test -f ${REMOTEPATH}"; then
    check_dir "$(dirname ${REMOTEPATH})"
    rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}
fi

# ============================================================
# 9. Respaldo de tareas programadas (cron)
# ============================================================
REMOTEPATH="/etc/crontab"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

REMOTEPATH="/etc/cron.d"
check_dir "$REMOTEPATH"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH}/ ${DST}${REMOTEPATH}/

# ============================================================
# 10. Respaldo de configuración SSH
# ============================================================
REMOTEPATH="/etc/ssh/sshd_config"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

REMOTEPATH="/etc/ssh/ssh_config"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 11. Respaldo de configuración systemd (timesync)
# ============================================================
REMOTEPATH="/etc/systemd/timesyncd.conf"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 12. Respaldo de /etc/resolv.conf (DNS)
# ============================================================
REMOTEPATH="/etc/resolv.conf"
check_dir "$(dirname ${REMOTEPATH})"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}

# ============================================================
# 13. Respaldo de configuración LVM
# ============================================================
REMOTEPATH="/etc/lvm"
if ssh -i ~/.ssh/datenmaniak root@192.168.1.201 "test -d ${REMOTEPATH}"; then
    check_dir "$REMOTEPATH"
    rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH}/ ${DST}${REMOTEPATH}/
fi

# ============================================================
# 14. Respaldo de scripts personalizados en /usr/local/bin
# ============================================================
REMOTEPATH="/usr/local/bin"
check_dir "$REMOTEPATH"
rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH}/ ${DST}${REMOTEPATH}/

# ============================================================
# 15. Respaldo de crontab del usuario root (via crontab -e)
# ============================================================
REMOTEPATH="/var/spool/cron/crontabs/root"
if ssh -i ~/.ssh/datenmaniak root@192.168.1.201 "test -f ${REMOTEPATH}"; then
    check_dir "$(dirname ${REMOTEPATH})"
    rsync -av -e "ssh -i ~/.ssh/datenmaniak" root@192.168.1.201:${REMOTEPATH} ${DST}${REMOTEPATH}
fi

echo "=== Respaldo completado ==="
echo "Configuraciones guardadas en: ${DST}"

#!/bin/bash
set -e

echo "==> Nettoyage agressif pour réduire la taille de l'image"

# Nettoyage APT
apt-get -y autoremove --purge
apt-get -y clean
apt-get -y autoclean

# Supprimer les caches APT
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*.deb
rm -rf /var/cache/apt/archives/partial/*.deb
rm -rf /var/cache/apt/*.bin

# Supprimer les logs
find /var/log -type f -delete
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.log" -delete

# Supprimer les fichiers temporaires
rm -rf /tmp/*
rm -rf /var/tmp/*

# Supprimer l'historique bash
rm -f /root/.bash_history
rm -f /home/vagrant/.bash_history

# Supprimer les fichiers de cache utilisateur
rm -rf /home/vagrant/.cache/*
rm -rf /root/.cache/*

# Supprimer la documentation et les man pages (optionnel - économise ~100MB)
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*

# Supprimer les locales non utilisées (garde seulement en_US)
locale-gen --purge en_US.UTF-8
rm -rf /usr/share/locale/[a-d]*
rm -rf /usr/share/locale/[f-z]*
rm -rf /usr/share/locale/e[a-m]*
rm -rf /usr/share/locale/e[o-z]*

# Nettoyer les anciennes versions du kernel (garde seulement le courant)
dpkg --list | awk '{ print $2 }' | grep 'linux-image-.*-generic' | grep -v $(uname -r) | xargs apt-get -y purge || true
dpkg --list | awk '{ print $2 }' | grep 'linux-headers' | grep -v $(uname -r) | xargs apt-get -y purge || true

# Supprimer les fichiers orphelins
find /usr -type f -size +50M -delete 2>/dev/null || true

# Nettoyer snapd (si présent)
systemctl stop snapd.service
systemctl disable snapd.service
apt-get -y purge snapd || true
rm -rf /snap
rm -rf /var/snap
rm -rf /var/lib/snapd
rm -rf /var/cache/snapd

# Nettoyer le journal systemd
journalctl --vacuum-time=1s

# Supprimer les fichiers SSH host keys (seront régénérés au premier boot)
rm -f /etc/ssh/ssh_host_*

# Remplir l'espace libre avec des zéros pour une meilleure compression
echo "==> Zéroïsation de l'espace libre (peut prendre plusieurs minutes)..."
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY

# Synchroniser le système de fichiers
sync

echo "==> Nettoyage terminé!"
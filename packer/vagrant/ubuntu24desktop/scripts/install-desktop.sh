#!/bin/bash
set -e

echo "==> Installation ultra-légère de l'interface graphique"

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get update

# Installation GNOME minimal absolu
apt-get install -y --no-install-recommends \
    gdm3 \
    gnome-shell \
    gnome-session \
    gnome-terminal \
    nautilus 

# Activer le gestionnaire de connexion graphique
systemctl set-default graphical.target
systemctl enable gdm3

# Connexion automatique pour vagrant
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf <<EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=vagrant
EOF

echo "==> Installation terminée - Desktop ultra-léger prêt"
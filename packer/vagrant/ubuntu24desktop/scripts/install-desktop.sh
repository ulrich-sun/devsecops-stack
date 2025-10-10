#!/bin/bash
set -e

echo "==> Installation de l'interface graphique Ubuntu Desktop"

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Mise à jour des paquets
apt-get update

# Installation de ubuntu-desktop-minimal (environ 1.5GB mais fonctionnel)
# OU ubuntu-desktop complet (environ 3GB mais plus complet)
apt-get install -y --no-install-recommends \
    ubuntu-desktop-minimal

# Alternative: Pour un environnement encore plus léger avec Xfce
# Décommentez les lignes suivantes et commentez ubuntu-desktop-minimal ci-dessus
# apt-get install -y --no-install-recommends \
#     xfce4 \
#     xfce4-goodies \
#     lightdm \
#     lightdm-gtk-greeter

# Configuration de GDM3 pour connexion automatique
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf <<'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=vagrant
WaylandEnable=false

[security]

[xdmcp]

[chooser]

[debug]
EOF

# S'assurer que le système démarre en mode graphique
systemctl set-default graphical.target
systemctl enable gdm3

# Ajouter vagrant au groupe video pour l'accélération graphique
usermod -aG video vagrant

# Désactiver Wayland (parfois problématique avec VirtualBox)
sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf

echo "==> Installation du bureau terminée"

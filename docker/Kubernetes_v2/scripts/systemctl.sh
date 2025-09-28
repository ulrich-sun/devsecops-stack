#!/bin/bash
# Faux systemctl pour Docker (simule systemd)

echo "[FAKE-SYSTEMCTL] $@"

case "$1" in
  start|stop|restart|enable|disable|status)
    # Toujours retourner succès
    exit 0
    ;;
  *)
    # Pour tout le reste, afficher un warning
    echo "[FAKE-SYSTEMCTL] Commande non supportée: $@"
    exit 0
    ;;
esac

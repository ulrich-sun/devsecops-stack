# ================================
# Dockerfile Kubernetes + faux systemctl
# ================================

FROM ubuntu:22.04

# Variables d'environnement
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:${PATH}"

# ------------------------
# Étape 1 : Préparation
# ------------------------
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    iproute2 \
    iptables \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ------------------------
# Étape 2 : Installer le faux systemctl
# ------------------------
RUN cat <<'EOF' > /usr/local/bin/systemctl && \
    chmod +x /usr/local/bin/systemctl
#!/bin/bash
UNIT_DIR="/etc/systemd/system"

case "$1" in
    start)
        SERVICE=$2
        if [ -f "$UNIT_DIR/$SERVICE" ]; then
            CMD=$(grep '^ExecStart=' "$UNIT_DIR/$SERVICE" | cut -d'=' -f2-)
            nohup $CMD >/var/log/$SERVICE.log 2>&1 &
            echo $! > "/var/run/${SERVICE}.pid"
            echo "$SERVICE started"
        else
            echo "Unit $SERVICE not found"
        fi
        ;;
    stop)
        SERVICE=$2
        if [ -f "/var/run/${SERVICE}.pid" ]; then
            kill $(cat "/var/run/${SERVICE}.pid")
            rm -f "/var/run/${SERVICE}.pid"
            echo "$SERVICE stopped"
        else
            echo "$SERVICE not running"
        fi
        ;;
    restart)
        $0 stop $2
        $0 start $2
        ;;
    enable|disable)
        echo "$2 $1 simulated"
        ;;
    status)
        SERVICE=$2
        if [ -f "/var/run/${SERVICE}.pid" ]; then
            echo "$SERVICE is running (PID $(cat /var/run/${SERVICE}.pid))"
        else
            echo "$SERVICE is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|enable|disable|status} <service>"
        exit 1
        ;;
esac
EOF

# ------------------------
# Étape 3 : Installer containerd + Kubernetes
# ------------------------
RUN apt-get update && apt-get install -y \
    containerd \
    && rm -rf /var/lib/apt/lists/*

# Installer kubeadm, kubelet et kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && apt-get install -y kubelet kubeadm kubectl && \
    apt-mark hold kubelet kubeadm kubectl && \
    rm -rf /var/lib/apt/lists/*

# ------------------------
# Étape 4 : Créer des unit files simulés
# ------------------------
RUN mkdir -p /etc/systemd/system && \
    cat <<'EOF' > /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
After=network.target

[Service]
ExecStart=/usr/bin/containerd
Restart=always

[Install]
WantedBy=multi-user.target
EOF

RUN cat <<'EOF' > /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: Kubernetes Node Agent
After=network.target

[Service]
ExecStart=/usr/bin/kubelet --container-runtime=remote --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ------------------------
# Étape 5 : Script d'init (ton 2ème script adapté)
# ------------------------
RUN cat <<'EOF' > /usr/local/bin/init-k8s.sh
#!/bin/bash
set -e

echo "[INFO] Démarrage de containerd"
systemctl start containerd

echo "[INFO] Démarrage de kubelet"
systemctl start kubelet

echo "[INFO] Kubernetes et containerd sont démarrés"
tail -f /var/log/containerd.service.log /var/log/kubelet.service.log
EOF
RUN chmod +x /usr/local/bin/init-k8s.sh

# ------------------------
# Commande par défaut
# ------------------------
CMD ["/usr/local/bin/init-k8s.sh"]

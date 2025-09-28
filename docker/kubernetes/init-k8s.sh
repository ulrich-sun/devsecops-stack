#!/bin/bash
set -e

echo "[INFO] 🔹 Désactivation temporaire du swap"
swapoff -a

echo "[INFO] 🔹 Lancement de containerd"
systemctl start containerd

echo "[INFO] 🔹 Lancement de kubelet"
systemctl start kubelet

# Attendre un peu que containerd et kubelet démarrent
sleep 5

# Initialiser Kubernetes control plane
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "[INFO] 🔹 Initialisation du cluster Kubernetes (control-plane)"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -i)

    # Configurer kubectl pour l'utilisateur root
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
else
    echo "[INFO] ✅ Kubernetes déjà initialisé, on ne refait pas kubeadm init"
fi

# Déployer le CNI (Flannel)
if ! kubectl get ns kube-flannel >/dev/null 2>&1; then
    echo "[INFO] 🔹 Déploiement du plugin réseau Flannel"
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
else
    echo "[INFO] ✅ Flannel déjà installé"
fi

# Suivre les logs
echo "[INFO] 🔹 Cluster démarré, suivi des logs..."
tail -f /var/log/containerd.service.log /var/log/kubelet.service.log

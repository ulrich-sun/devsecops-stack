#!/bin/bash
set -e

echo "[INFO] 🔹 Désactivation du swap"
swapoff -a

echo "[INFO] 🔹 Démarrage de containerd et kubelet"
systemctl start containerd
systemctl start kubelet

sleep 5

if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "[INFO] 🔹 Initialisation du control-plane"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -i)

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
else
    echo "[INFO] ✅ Kubernetes déjà initialisé"
fi

if ! kubectl get ns kube-flannel >/dev/null 2>&1; then
    echo "[INFO] 🔹 Installation de Flannel CNI"
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
else
    echo "[INFO] ✅ Flannel déjà installé"
fi

echo "[INFO] 🔹 Cluster prêt"
tail -f /var/log/containerd.service.log /var/log/kubelet.service.log

#!/bin/bash
set -e

echo "[INFO] 🔹 Installation de Kubernetes v${KUBERNETES_VERSION}"

# Ajouter la clé et le dépôt Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update && apt-get install -y \
    kubelet=${KUBERNETES_VERSION}-1.1 \
    kubeadm=${KUBERNETES_VERSION}-1.1 \
    kubectl=${KUBERNETES_VERSION}-1.1 \
    containerd \
    && apt-mark hold kubelet kubeadm kubectl containerd

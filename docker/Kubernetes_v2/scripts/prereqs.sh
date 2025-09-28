#!/bin/bash
set -e

echo "[INFO] 🔹 Installation des prérequis systèmes"

apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg \
    conntrack \
    socat \
    && rm -rf /var/lib/apt/lists/*

echo "[INFO] 🔹 Chargement des modules kernel"
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

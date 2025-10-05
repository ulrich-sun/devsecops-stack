# Dockerfile pour Kubernetes master/worker (Ubuntu + containerd + kubeadm)

FROM ubuntu:22.04

COPY systemctl /usr/local/bin/systemctl
RUN chmod +x /usr/local/bin/*.sh \
    && ln -sf /usr/local/bin/systemctl.sh /usr/bin/systemctl

ENV DEBIAN_FRONTEND=noninteractive
ENV K8S_VERSION=1.33.0
ENV K8S_DEB_VERSION=${K8S_VERSION}-1.1
ENV K8S_REPO_VERSION=v${K8S_VERSION%.*}
ENV K8S_REPO_URL=https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VERSION}/deb/
ENV CRI_SOCKET=unix:///var/run/containerd/containerd.sock
ENV POD_NETWORK_CIDR=10.244.0.0/16
ENV INTERFACE=enp0s8
ENV JOIN_COMMAND_FILE=/vagrant/join-command.sh
ENV KUBEADM_LOG=kubeadm-init.log
ENV LOG_FILE=/var/log/k8s-install.log
ENV HOSTNAME=master

# Installer les dépendances de base
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gpg conntrack socat iproute2 iputils-ping sudo gnupg lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Désactiver swap (inutile dans un conteneur mais inclus pour compatibilité)
RUN swapoff -a

# Modules kernel
RUN modprobe overlay && modprobe br_netfilter && \
    echo -e "overlay\nbr_netfilter" > /etc/modules-load.d/k8s.conf && \
    echo -e "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1" > /etc/sysctl.d/k8s.conf && \
    sysctl --system

# Installer containerd
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y containerd.io && \
    mkdir -p /etc/containerd && \
    containerd config default > /etc/containerd/config.toml && \
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Installer Kubernetes
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL ${K8S_REPO_URL}Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] $K8S_REPO_URL /" > /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubelet=${K8S_DEB_VERSION} kubeadm=${K8S_DEB_VERSION} kubectl=${K8S_DEB_VERSION} && \
    apt-mark hold kubelet kubeadm kubectl

# Copier le script d'installation
COPY k8s-install.sh /usr/local/bin/k8s-install.sh
RUN chmod +x /usr/local/bin/k8s-install.sh

# Point d'entrée
ENTRYPOINT ["/usr/local/bin/k8s-install.sh"]

# Ubuntu base
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Mettre à jour et installer outils de base
RUN apt-get update && apt-get install -y \
    curl \
    git \
    bash-completion \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    iproute2 \
    iputils-ping \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Installer Docker CE
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && rm -rf /var/lib/apt/lists/*

# Installer Kubernetes
ARG KUBERNETES_VERSION=1.31.0

# Ajouter le dépôt Kubernetes officiel moderne
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/Release.key \
       | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
       https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/ /" \
       | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y kubelet=${KUBERNETES_VERSION}-00 kubeadm=${KUBERNETES_VERSION}-00 kubectl=${KUBERNETES_VERSION}-00 \
    && apt-mark hold kubelet kubeadm kubectl \
    && rm -rf /var/lib/apt/lists/*


# Installer jq et docker-compose
RUN curl -Lf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
    && curl -Lf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m) \
    && chmod +x /usr/bin/jq /usr/bin/docker-compose

# Copier fichiers nécessaires
COPY ./kube* /etc/systemd/system/
COPY ./wrapkubeadm.sh /usr/local/bin/kubeadm
COPY ./tokens.csv /etc/pki/tokens.csv
COPY ./daemon.json /etc/docker/
COPY ./resolv.conf.override /etc/
COPY ./.bashrc /root/
COPY motd /etc/motd

# Configurer bash completion
RUN echo 'source <(kubectl completion bash)' >>~/.bashrc \
    && kubectl completion bash >> /etc/bash_completion.d/kubectl

# Configurer kube config
RUN mkdir -p /root/.kube \
    && ln -s /etc/kubernetes/admin.conf /root/.kube/config \
    && rm -f /etc/machine-id

WORKDIR /root

# CMD pour lancer services et bash interactif
CMD ["bash", "-c", "\
    dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 & \
    kubelet --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock --fail-swap-on=false & \
    while true; do script -q -c '/bin/bash -l' /dev/null; done \
"]

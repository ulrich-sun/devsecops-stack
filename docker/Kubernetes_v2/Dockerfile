FROM ubuntu:22.04

# 🔹 Variables de build
ARG KUBERNETES_VERSION=1.32.0
ENV KUBERNETES_VERSION=${KUBERNETES_VERSION}

# 🔹 Mise à jour et installation de dépendances de base
RUN apt-get update && apt-get install -y \
    systemd sudo vim net-tools iproute2 iputils-ping \
    curl wget gnupg2 lsb-release kmod \
    && rm -rf /var/lib/apt/lists/*

# 🔹 Copier les scripts externes
COPY scripts/systemctl.sh /usr/local/bin/systemctl.sh
COPY scripts/prereqs.sh /usr/local/bin/prereqs.sh
COPY scripts/install-k8s.sh /usr/local/bin/install-k8s.sh
COPY scripts/init-k8s.sh /usr/local/bin/init-k8s.sh

RUN chmod +x /usr/local/bin/*.sh \
    && ln -sf /usr/local/bin/systemctl.sh /usr/bin/systemctl

# 🔹 Exécuter les prérequis + installation Kubernetes
RUN /usr/local/bin/prereqs.sh \
    && /usr/local/bin/install-k8s.sh

# 🔹 EntryPoint pour démarrer le cluster
CMD ["/usr/local/bin/init-k8s.sh"]

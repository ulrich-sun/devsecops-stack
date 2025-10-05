#!/bin/bash
set -e

# === Version unique à modifier ===
K8S_VERSION="${K8S_VERSION:-1.33.0}"  # Utilise la variable d'environnement si définie

# === Variables dérivées automatiquement ===
K8S_DEB_VERSION="${K8S_VERSION}-1.1"
K8S_REPO_VERSION="v${K8S_VERSION%.*}"
K8S_REPO_URL="https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VERSION}/deb/"
CRI_SOCKET="unix:///var/run/containerd/containerd.sock"
POD_NETWORK_CIDR="10.244.0.0/16"
INTERFACE="${INTERFACE:-enp0s8}"
JOIN_COMMAND_FILE="/vagrant/join-command.sh"
KUBEADM_LOG="kubeadm-init.log"
LOG_FILE="/var/log/k8s-install.log"
HOSTNAME=$(hostname)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

check_existing_installation() {
    log "Vérification des installations existantes..."
    if command -v kubeadm &> /dev/null; then
        log "WARNING: kubeadm déjà installé"
        kubeadm version
        exit 1
    fi
    if command -v docker &> /dev/null; then
        log "WARNING: Docker est actif. Continuer avec containerd ?"
    fi
}

install_prerequisites() {
    log "Installation des pré-requis..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg conntrack socat iproute2 iputils-ping lsb-release
}

setup_system_config() {
    log "Configuration du système..."
    modprobe overlay
    modprobe br_netfilter
    echo -e "overlay\nbr_netfilter" > /etc/modules-load.d/k8s.conf
    echo -e "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1" > /etc/sysctl.d/k8s.conf
    sysctl --system
}

install_containerd_clean() {
    log "Installation de containerd..."
    if ! command -v containerd &> /dev/null; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y containerd.io
    fi
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl enable containerd || true
}

setup_k8s_repo() {
    log "Ajout du dépôt Kubernetes..."
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL ${K8S_REPO_URL}Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] $K8S_REPO_URL /" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update
}

install_k8s_components() {
    log "Installation des composants Kubernetes version $K8S_DEB_VERSION..."
    apt-get install -y kubelet=$K8S_DEB_VERSION kubeadm=$K8S_DEB_VERSION kubectl=$K8S_DEB_VERSION
    apt-mark hold kubelet kubeadm kubectl
}

setup_master_node() {
    if [ ! -f /etc/kubernetes/admin.conf ]; then
        log "Initialisation du master..."
        kubeadm config images pull --kubernetes-version=$K8S_VERSION
        host_ip=$(ip -f inet addr show $INTERFACE | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
        kubeadm init \
            --apiserver-advertise-address=$host_ip \
            --pod-network-cidr=$POD_NETWORK_CIDR \
            --cri-socket=$CRI_SOCKET \
            --kubernetes-version=$K8S_VERSION | tee $KUBEADM_LOG

        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config

        mkdir -p /home/vagrant/.kube
        cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
        chown vagrant:vagrant /home/vagrant/.kube/config || true

        grep "kubeadm join" $KUBEADM_LOG -A 2 > $JOIN_COMMAND_FILE
        chmod +x $JOIN_COMMAND_FILE

        kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
        kubectl taint nodes $HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule- || true

        log "Master initialisé avec succès"
        sleep 30
        kubectl get nodes
        kubectl get pods -A
    else
        log "Cluster déjà initialisé"
    fi
}

setup_worker_node() {
    log "Configuration du worker..."
    if [ -f /etc/kubernetes/kubelet.conf ]; then
        log "Worker déjà joint"
        return
    fi

    ELAPSED=0
    while [ ! -f "$JOIN_COMMAND_FILE" ] && [ $ELAPSED -lt 300 ]; do
        log "Attente de la commande join... ($ELAPSED/300)"
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    if [ -f "$JOIN_COMMAND_FILE" ]; then
        sed -i "s|kubeadm join|kubeadm join --cri-socket=$CRI_SOCKET|" "$JOIN_COMMAND_FILE"
        bash "$JOIN_COMMAND_FILE"
        log "Worker joint avec succès"
    else
        log "Commande join introuvable après 5 minutes"
    fi
}

main() {
    check_existing_installation
    install_prerequisites
    setup_system_config
    install_containerd_clean
    setup_k8s_repo
    install_k8s_components

    case $HOSTNAME in
        "master") setup_master_node ;;
        "worker"*) setup_worker_node ;;
        *) log "Nom d'hôte non reconnu : $HOSTNAME" ;;
    esac

    log "Installation terminée pour $HOSTNAME"
}

if [ "$1" = "--diagnostic" ]; then
    log "=== DIAGNOSTIC ==="
    log "containerd: $(containerd --version 2>/dev/null || echo 'Non installé')"
    log "kubelet: $(kubelet --version 2>/dev/null || echo 'Non installé')"
else
    main "$@"
fi

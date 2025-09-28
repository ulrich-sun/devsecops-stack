#!/bin/bash
set -e

# === Version unique à modifier ===
K8S_VERSION="1.33.0"  # ← Change cette valeur pour mettre à jour toute la stack Kubernetes

# === Variables dérivées automatiquement ===
K8S_DEB_VERSION="${K8S_VERSION}-1.1"
K8S_REPO_VERSION="v${K8S_VERSION%.*}"
K8S_REPO_URL="https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VERSION}/deb/"
CRI_SOCKET="unix:///var/run/containerd/containerd.sock"
POD_NETWORK_CIDR="10.244.0.0/16"
INTERFACE="enp0s8"
JOIN_COMMAND_FILE="/vagrant/join-command.sh"
KUBEADM_LOG="kubeadm-init.log"
LOG_FILE="/var/log/k8s-install.log"
HOSTNAME=$(hostname)

# Désactiver temporairement (jusqu'au reboot)
sudo swapoff -a

# Désactiver de façon permanente
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Ou plus précis pour Ubuntu
sudo sed -i '/swap.img/d' /etc/fstab

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
    if systemctl is-active --quiet docker; then
        log "WARNING: Docker est actif. Continuer avec containerd ? (y/N)"
        read -r response
        [[ ! "$response" =~ ^[Yy]$ ]] && exit 1
    fi
}

install_prerequisites() {
    log "Installation des pré-requis..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg conntrack socat
}

setup_system_config() {
    log "Configuration du système..."
    sudo modprobe overlay
    sudo modprobe br_netfilter
    echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
    echo -e "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/k8s.conf
    sudo sysctl --system
}

install_containerd_clean() {
    log "Installation de containerd..."
    if ! command -v containerd &> /dev/null; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y containerd.io
    fi
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd
}

setup_k8s_repo() {
    log "Ajout du dépôt Kubernetes..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL ${K8S_REPO_URL}Release.key | sudo gpg --batch --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] $K8S_REPO_URL /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
}

install_k8s_components() {
    log "Installation des composants Kubernetes version $K8S_DEB_VERSION..."
    sudo apt-get install -y \
        kubelet=$K8S_DEB_VERSION \
        kubeadm=$K8S_DEB_VERSION \
        kubectl=$K8S_DEB_VERSION
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable --now kubelet
}

setup_master_node() {
    if [ ! -f /etc/kubernetes/admin.conf ]; then
        log "Initialisation du master..."
        sudo kubeadm config images pull --kubernetes-version=$K8S_VERSION
        host_ip=$(ip -f inet addr show $INTERFACE | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
        sudo kubeadm init \
            --apiserver-advertise-address=$host_ip \
            --pod-network-cidr=$POD_NETWORK_CIDR \
            --cri-socket=$CRI_SOCKET \
            --kubernetes-version=$K8S_VERSION | sudo tee $KUBEADM_LOG

        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        sudo mkdir -p /home/vagrant/.kube
        sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
        sudo chown vagrant:vagrant /home/vagrant/.kube/config

        sudo grep "kubeadm join" $KUBEADM_LOG -A 2 > $JOIN_COMMAND_FILE
        sudo chmod +x $JOIN_COMMAND_FILE
        sudo cp $JOIN_COMMAND_FILE /vagrant/ 2>/dev/null || true

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
        sudo sed -i "s|kubeadm join|kubeadm join --cri-socket=$CRI_SOCKET|" "$JOIN_COMMAND_FILE"
        sudo bash "$JOIN_COMMAND_FILE"
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
    log "Status containerd: $(systemctl is-active containerd)"
    log "Status kubelet: $(systemctl is-active kubelet)"
    if [ "$HOSTNAME" = "master" ]; then
        kubectl get nodes 2>/dev/null || log "Erreur kubectl"
        kubectl get pods -n kube-system 2>/dev/null || log "Erreur kubectl"
    fi
else
    main "$@"
fi

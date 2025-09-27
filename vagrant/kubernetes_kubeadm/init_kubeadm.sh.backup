#!/bin/bash

# Récupérer le hostname de la machine
HOSTNAME=$(hostname)

echo 
echo "[INFO] Configuration pour le hostname: $HOSTNAME"
echo

# Pré-requis communs à toutes les machines
echo 
echo "[INFO] Pré-requis pour l'installation de Kubernetes"
echo
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Configuration du dépôt pour Kubernetes 1.32
echo 
echo "[INFO] Configuration du dépôt pour Kubernetes 1.32"
echo
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

# Installation des composants Kubernetes
echo 
echo "[INFO] Installation des composants de Kubernetes"
echo
sudo apt-get install -y kubelet kubeadm kubectl

# Empêcher les mises à jour automatiques
echo 
echo "[INFO] Empêcher les mises à jour automatiques de kubelet, kubeadm et kubectl"
echo
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# Installation de conntrack
echo 
echo "[INFO] Installation de conntrack"
echo
sudo apt install -y conntrack

# Installation de crictl
echo 
echo "[INFO] Installation de crictl"
echo
CRICTL_VERSION="v1.31.0"
curl -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
tar -zxvf "crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
sudo mv crictl /usr/local/bin/

# Installation des plugins CNI
echo 
echo "[INFO] Installation des plugins CNI"
echo
CNI_VERSION="v1.5.1"
curl -LO "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzvf "cni-plugins-linux-amd64-${CNI_VERSION}.tgz"

# Installation de cri-dockerd
echo 
echo "[INFO] Installation de cri-dockerd"
echo
sudo wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd-0.3.15.amd64.tgz
sudo tar -xvf cri-dockerd-0.3.15.amd64.tgz
sudo mv cri-dockerd/cri-dockerd /usr/local/bin/
sudo chmod +x /usr/local/bin/cri-dockerd

# Installation de Docker
echo 
echo "[INFO] Installation de Docker"
echo
curl -fsSL https://get.docker.com | sudo sh

# Configuration de cri-dockerd
sudo bash -c 'cat <<EOF > /etc/systemd/system/cri-dockerd.service
[Unit]
Description=CRI for Docker
Documentation=https://github.com/Mirantis/cri-dockerd
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/cri-dockerd
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable cri-dockerd.service
sudo systemctl start cri-dockerd.service

# Socket cri-docker
sudo bash -c 'cat <<EOF > /etc/systemd/system/cri-docker.socket
[Unit]
Description=Socket for CRI for Docker

[Socket]
ListenStream=0.0.0.0:50051
Accept=yes

[Install]
WantedBy=sockets.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable cri-docker.socket
sudo systemctl start cri-docker.socket

# Configuration réseau commune
echo 
echo "[INFO] Configuration des modules réseau"
echo
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Téléchargement des images Kubernetes
echo 
echo "[INFO] Téléchargement des images Kubernetes"
echo
sudo kubeadm config images pull

# Logique conditionnelle basée sur le hostname
case $HOSTNAME in
    "master")
        echo 
        echo "[INFO] Configuration du nœud MASTER (master)"
        echo
        
        # Initialisation du cluster Kubernetes
        echo 
        echo "[INFO] Initialisation du cluster Kubernetes"
        echo
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///var/run/cri-dockerd.sock | sudo tee kubeadm-init.log

        # Sauvegarde de la commande join
        sudo grep "kubeadm join" kubeadm-init.log -A 2 > /home/vagrant/join-command.sh
        sudo chmod +x /home/vagrant/join-command.sh

        # Configuration de kubectl
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        # Installation de Flannel
        echo 
        echo "[INFO] Installation de Flannel CNI"
        echo
        kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

        # Suppression du taint pour permettre les pods sur le master (optionnel)
        echo 
        echo "[INFO] Configuration des taints du nœud master"
        echo
        kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

        echo 
        echo "[SUCCESS] Nœud master configuré avec succès!"
        echo "Commande join disponible dans: /home/vagrant/join-command.sh"
        ;;

    "worker")
        echo 
        echo "[INFO] Configuration du nœud WORKER (worker)"
        echo
        
        # Attendre que le fichier join-command.sh soit disponible (via partage de fichiers)
        echo 
        echo "[INFO] Attente de la commande join depuis le master..."
        echo
        
        # Cette partie dépend de votre méthode de partage de fichiers
        # Option 1: Via un partage Vagrant
        JOIN_COMMAND_FILE="/vagrant/join-command.sh"
        
        if [ -f "$JOIN_COMMAND_FILE" ]; then
            echo 
            echo "[INFO] Commande join trouvée, jointure au cluster..."
            echo
            sudo bash $JOIN_COMMAND_FILE
        else
            echo 
            echo "[WARNING] Fichier join-command.sh non trouvé."
            echo "Le worker doit être joint manuellement au cluster avec la commande:"
            echo "kubeadm join ..."
            echo
        fi

        echo 
        echo "[SUCCESS] Nœud worker joint au cluster!"
        ;;

    *)
        echo 
        echo "[WARNING] Hostname non reconnu: $HOSTNAME"
        echo "Installation de base effectuée, mais configuration Kubernetes non appliquée."
        echo "Hostnames supportés: 'master' (master) ou 'worker'"
        ;;
esac

# Fonction commune pour afficher le statut (sur le master)
if [ "$HOSTNAME" = "master" ]; then
    echo
    echo "[INFO] Vérification du statut du cluster..."
    kubectl get nodes
    kubectl get pods --all-namespaces
fi

echo
echo "[INFO] Installation terminée pour $HOSTNAME"
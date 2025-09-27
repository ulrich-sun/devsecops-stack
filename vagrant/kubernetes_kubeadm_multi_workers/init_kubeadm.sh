#!/bin/bash

# Récupérer le hostname de la machine
HOSTNAME=$(hostname)

echo 
echo "[INFO] Configuration pour le hostname: $HOSTNAME"
echo

# Détection du rôle (master ou worker) et du numéro de worker
if [[ $HOSTNAME == "master" ]]; then
    ROLE="master"
    WORKER_NUMBER=""
elif [[ $HOSTNAME =~ ^worker-([0-9]+)$ ]]; then
    ROLE="worker"
    WORKER_NUMBER="${BASH_REMATCH[1]}"
elif [[ $HOSTNAME == "worker" ]]; then
    ROLE="worker"
    WORKER_NUMBER="1"  # Par défaut pour compatibilité
else
    ROLE="unknown"
    WORKER_NUMBER=""
fi

echo 
echo "[INFO] Rôle détecté: $ROLE"
if [[ $ROLE == "worker" ]]; then
    echo "[INFO] Numéro de worker: $WORKER_NUMBER"
fi
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

# Logique conditionnelle basée sur le rôle
case $ROLE in
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
        
        # Copie dans le dossier partagé pour les workers
        cp /home/vagrant/join-command.sh /vagrant/join-command.sh
        chmod +x /vagrant/join-command.sh

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
        echo "Commande join disponible dans: /vagrant/join-command.sh"
        ;;

    "worker")
        echo 
        echo "[INFO] Configuration du nœud WORKER ($HOSTNAME)"
        echo
        
        # Attendre que le fichier join-command.sh soit disponible
        echo 
        echo "[INFO] Attente de la commande join depuis le master..."
        echo
        
        JOIN_COMMAND_FILE="/vagrant/join-command.sh"
        MAX_ATTEMPTS=30
        ATTEMPT=1
        
        while [ ! -f "$JOIN_COMMAND_FILE" ] && [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
            echo "Tentative $ATTEMPT/$MAX_ATTEMPTS - Commande join non trouvée, attente de 10 secondes..."
            sleep 10
            ATTEMPT=$((ATTEMPT + 1))
        done

        if [ -f "$JOIN_COMMAND_FILE" ]; then
            echo 
            echo "[INFO] Commande join trouvée, jointure au cluster..."
            echo
            sudo bash $JOIN_COMMAND_FILE
            
            # Ajouter un label avec le numéro du worker
            if [[ -n "$WORKER_NUMBER" ]]; then
                echo "[INFO] Attente de l'initialisation du nœud..."
                sleep 30
                # Cette partie nécessite d'avoir accès à la config kubectl (normalement sur master seulement)
                # On peut le faire via une autre méthode si nécessaire
            fi
            
        else
            echo 
            echo "[ERROR] Fichier join-command.sh non trouvé après $MAX_ATTEMPTS tentatives."
            echo "Le worker doit être joint manuellement au cluster."
            echo
        fi

        echo 
        echo "[SUCCESS] Nœud worker $HOSTNAME joint au cluster!"
        ;;

    *)
        echo 
        echo "[WARNING] Rôle non reconnu: $ROLE"
        echo "Installation de base effectuée, mais configuration Kubernetes non appliquée."
        ;;
esac

# Fonction commune pour afficher le statut (sur le master)
if [ "$ROLE" = "master" ]; then
    echo
    echo "[INFO] Vérification du statut du cluster..."
    sleep 30  # Attendre que les pods soient initialisés
    kubectl get nodes -o wide
    kubectl get pods --all-namespaces
fi

echo
echo "[INFO] Installation terminée pour $HOSTNAME ($ROLE)"
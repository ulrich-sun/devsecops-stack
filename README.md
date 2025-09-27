#Vagrant utils
vagrant destroy -f


vagrant global-status --prune


#retrait des caracteres speciaux
# Installer dos2unix
sudo apt-get update
sudo apt-get install -y dos2unix

# Convertir le fichier
dos2unix init_kubeadm.sh.containerd

# Puis exécuter
bash init_kubeadm.sh.containerd
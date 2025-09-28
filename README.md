
#Git Utils
git add .
git commit -m "Initial commit - ajout du rôle Kubernetes"
git tag v1.0.0
git push origin main
git push origin v1.0.0


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
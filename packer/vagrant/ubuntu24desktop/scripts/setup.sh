#!/bin/bash -eux

# Créer utilisateur vagrant s'il n'existe pas (dans ton cas, déjà via autoinstall)
id vagrant &>/dev/null || useradd -m -s /bin/bash -G sudo vagrant
echo "vagrant:vagrant" | chpasswd

# SSH: ajouter clé publique officielle de Vagrant
mkdir -pm 700 /home/vagrant/.ssh
curl -fsSL https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Sudo sans mot de passe
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant

# SSHD configuration
sed -i 's/^#*\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*\s*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo 'UseDNS no' >> /etc/ssh/sshd_config

# Redémarrer SSH
systemctl restart ssh

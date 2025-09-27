#!/bin/bash
apt-get update
apt-get install -y linux-headers-$(uname -r) build-essential dkms
mount -o loop /home/vagrant/VBoxGuestAdditions.iso /mnt
sh /mnt/VBoxLinuxAdditions.run
umount /mnt
rm -f /home/vagrant/VBoxGuestAdditions.iso
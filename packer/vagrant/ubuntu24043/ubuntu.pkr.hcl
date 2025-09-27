packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "virtualbox-iso" "ubuntu" {
  # Updated boot command for Ubuntu 24.04
  boot_command = [
    "<wait10s>",
    "c<wait5s>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]

  boot_wait      = "5s"
  disk_size      = "20480"
  guest_os_type  = "Ubuntu_64"
  headless       = false  # Set to false for debugging
  http_directory = "http"

  iso_urls = [
    "ubuntu-24.04.3-live-server-amd64.iso",
    "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
  ]

  iso_checksum            = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
  ssh_username            = "vagrant"
  ssh_password            = "vagrant"
  ssh_port                = 22
  ssh_wait_timeout        = "1800s"  # Increased timeout
  ssh_timeout             = "1800s"   # Additional timeout setting
  shutdown_command        = "echo 'vagrant' | sudo -S shutdown -P now"
  guest_additions_path    = "VBoxGuestAdditions_{{.Version}}.iso"
  guest_additions_mode    = "upload"
  virtualbox_version_file = ".vbox_version"
  vm_name                 = "packer-ubuntu-24.04-amd64"

  vboxmanage = [
    [
      "modifyvm",
      "{{.Name}}",
      "--memory",
      "6144"
    ],
    [
      "modifyvm",
      "{{.Name}}",
      "--cpus",
      "4"
    ],
    [
      "modifyvm",
      "{{.Name}}",
      "--nat-localhostreachable1",
      "on"
    ]
  ]
}

build {
  sources = ["source.virtualbox-iso.ubuntu"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script          = "scripts/virtualbox.sh"
  }

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script          = "scripts/setup.sh"
  }

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script          = "scripts/cleanup.sh"
  }

  provisioner "file" {
    source      = "./motd"
    destination = "/tmp/motd"
  }

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash -c '{{.Path}}'"
    inline          = ["sudo mv /tmp/motd /etc/motd"]
  }

  post-processors {
    post-processor "vagrant" {
      output = "builds/{{.Provider}}-ubuntu2404.box"
    }
  }
}
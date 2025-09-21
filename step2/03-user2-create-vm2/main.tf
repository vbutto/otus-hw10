# Образ Ubuntu 24.04
data "yandex_compute_image" "ubuntu" {
  provider = yandex.sa_user2
  family   = "ubuntu-2404-lts"
}

resource "yandex_compute_instance" "vm_2" {
  provider    = yandex.sa_user2
  name        = var.vm_name
  folder_id   = var.folder_id
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = true
    security_group_ids = [var.security_group_id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${var.ssh_public_key}"
    user-data = <<-EOF
      #cloud-config
      users:
        - name: ubuntu
          groups: sudo
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      runcmd:
        - echo "Created by user2 via Terraform" > /var/log/hw10-user2.log
    EOF
  }

  labels = {
    environment = "homework"
    project     = "hw10"
    created_by  = "user2"
    step        = "2"
  }
}

# Роли сервисного аккаунта для terraform
# vpc.privateAdmin - для управления сетями
# vpc.publicAdmin - для управления внешними IP
# iam.serviceAccounts.admin - для управления сервисными аккаунтами
# securityGroups.admin - для управления security group
# compute.admin - для управления ВМ
# audit-trails.admin - для управления Audit Trail
# storage.admin - для управления Object Storage

# ============================================================================
# HW10 - Аудит действий пользователей с виртуальными машинами
# ============================================================================

# Получаем образ Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

# ============================================================================
# Сетевая инфраструктура
# ============================================================================

resource "yandex_vpc_network" "hw10_network" {
  name        = "hw10-network"
  description = "Network for HW10 audit demo"
  folder_id   = var.folder_id
}

resource "yandex_vpc_subnet" "hw10_subnet" {
  name           = "hw10-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.hw10_network.id
  v4_cidr_blocks = ["10.10.0.0/24"]
  folder_id      = var.folder_id
}

# Security Group для ВМ
resource "yandex_vpc_security_group" "hw10_sg" {
  name       = "hw10-security-group"
  network_id = yandex_vpc_network.hw10_network.id
  folder_id  = var.folder_id

  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH access"
    v4_cidr_blocks = [var.my_ip != "" ? var.my_ip : "0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "ICMP"
    description    = "ICMP ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================================
# Сервисные аккаунты (два пользователя)
# ============================================================================

# Сервисный аккаунт - Пользователь 1
resource "yandex_iam_service_account" "user1" {
  name        = "hw10-user1"
  description = "Service Account representing User1 - creator of VM"
  folder_id   = var.folder_id
}

# Сервисный аккаунт - Пользователь 2  
resource "yandex_iam_service_account" "user2" {
  name        = "hw10-user2"
  description = "Service Account representing User2 - VM modifier"
  folder_id   = var.folder_id
}

# ============================================================================
# IAM роли для пользователей
# ============================================================================

# Роли для User1 - создание и управление ВМ
resource "yandex_resourcemanager_folder_iam_member" "user1_compute_admin" {
  folder_id = var.folder_id
  role      = "compute.admin"
  member    = "serviceAccount:${yandex_iam_service_account.user1.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "user1_vpc_user" {
  folder_id = var.folder_id
  role      = "vpc.user"
  member    = "serviceAccount:${yandex_iam_service_account.user1.id}"
}

# Роли для User2 - управление ВМ
resource "yandex_resourcemanager_folder_iam_member" "user2_compute_admin" {
  folder_id = var.folder_id
  role      = "compute.admin"
  member    = "serviceAccount:${yandex_iam_service_account.user2.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "user2_vpc_user" {
  folder_id = var.folder_id
  role      = "vpc.user"
  member    = "serviceAccount:${yandex_iam_service_account.user2.id}"
}

# ============================================================================
# Object Storage bucket для Audit Trail
# ============================================================================

# Сервисный аккаунт для Audit Trail
resource "yandex_iam_service_account" "audit_sa" {
  name        = "hw10-audit-sa"
  description = "Service Account for Audit Trail"
  folder_id   = var.folder_id
}

# Роль для записи в Object Storage
resource "yandex_resourcemanager_folder_iam_member" "audit_storage_uploader" {
  folder_id = var.folder_id
  role      = "storage.uploader"
  member    = "serviceAccount:${yandex_iam_service_account.audit_sa.id}"
}

# Object Storage bucket для хранения логов аудита
resource "yandex_storage_bucket" "audit_bucket" {
  bucket        = "hw10-audit-logs-${random_string.bucket_suffix.result}"
  folder_id     = var.folder_id
  force_destroy = true

  anonymous_access_flags {
    read = false
    list = false
  }
}

# Random строка для уникальности имени bucket
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ============================================================================
# Audit Trail (исправленная версия с правильным синтаксисом)
# ============================================================================

# Дополнительные роли для Audit Trail
resource "yandex_resourcemanager_folder_iam_member" "audit_trails_admin" {
  folder_id = var.folder_id
  role      = "audit-trails.admin"
  member    = "serviceAccount:${yandex_iam_service_account.audit_sa.id}"
}

# Исправленная версия Audit Trail
resource "yandex_audit_trails_trail" "hw10_audit" {
  name        = "hw10-audit-trail"
  folder_id   = var.folder_id
  description = "Audit trail for HW10 - tracking user actions with VM"

  labels = {
    environment = "homework"
    project     = "hw10"
  }

  service_account_id = yandex_iam_service_account.audit_sa.id

  storage_destination {
    bucket_name   = yandex_storage_bucket.audit_bucket.bucket
    object_prefix = "audit-logs"
  }

  # Используем новый синтаксис filtering_policy
  filtering_policy {
    management_events_filter {
      resource_scope {
        resource_id   = var.folder_id
        resource_type = "resource-manager.folder"
      }
    }
    data_events_filter {
      service = "compute"
      resource_scope {
        resource_id   = var.folder_id
        resource_type = "resource-manager.folder"
      }
      included_events = ["*"]
    }
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.audit_trails_admin,
    yandex_storage_bucket.audit_bucket
  ]
}

# ============================================================================
# Виртуальная машина (минимальная конфигурация)
# ============================================================================

resource "yandex_compute_instance" "hw10_vm" {
  name        = "hw10-demo-vm"
  platform_id = "standard-v3"
  zone        = var.zone
  folder_id   = var.folder_id
  hostname    = "hw10-vm"

  # Минимальная конфигурация
  resources {
    cores         = 2
    memory        = 1  # 1 GB RAM - минимум
    core_fraction = 20 # 20% CPU - минимум для standard-v3
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10            # 10 GB - минимальный размер диска
      type     = "network-hdd" # Самый дешевый тип диска
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.hw10_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.hw10_sg.id]
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
      
      packages:
        - htop
        - curl
        - wget
        
      runcmd:
        - echo "HW10 Demo VM initialized at $(date)" > /var/log/hw10-init.log
        - systemctl enable ssh
        - systemctl start ssh
    EOF
  }

  labels = {
    environment = "homework"
    project     = "hw10"
    created_by  = "user1"
  }

  # Предотвращаем случайное удаление
  lifecycle {
    prevent_destroy = false
  }
}

# ============================================================================
# Статические ключи доступа для Object Storage
# ============================================================================

resource "yandex_iam_service_account_static_access_key" "audit_sa_key" {
  service_account_id = yandex_iam_service_account.audit_sa.id
  description        = "Static access key for audit trail bucket"
}

# ============================================================================
# Outputs
# ============================================================================

output "vm_id" {
  description = "ID виртуальной машины"
  value       = yandex_compute_instance.hw10_vm.id
}

output "vm_external_ip" {
  description = "Внешний IP виртуальной машины"
  value       = yandex_compute_instance.hw10_vm.network_interface.0.nat_ip_address
}

output "vm_internal_ip" {
  description = "Внутренний IP виртуальной машины"
  value       = yandex_compute_instance.hw10_vm.network_interface.0.ip_address
}

output "user1_service_account_id" {
  description = "ID сервисного аккаунта User1"
  value       = yandex_iam_service_account.user1.id
}

output "user2_service_account_id" {
  description = "ID сервисного аккаунта User2"
  value       = yandex_iam_service_account.user2.id
}

output "audit_trail_id" {
  description = "ID Audit Trail"
  value       = yandex_audit_trails_trail.hw10_audit.id
}

output "audit_bucket_name" {
  description = "Имя bucket для audit логов"
  value       = yandex_storage_bucket.audit_bucket.bucket
}

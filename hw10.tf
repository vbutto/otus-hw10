###############################################
# Pre-req (инфо):
# Аккаунт, который запускает terraform, должен иметь на папке:
#  - vpc.privateAdmin, vpc.publicAdmin, vpc.securityGroups.admin
#  - compute.admin
#  - iam.serviceAccounts.admin       (создание SAs)
#  - audit-trails.admin              (создание trail)
#  - storage.admin                   (создание bucket)
###############################################

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

# ---------------------
# Network & Security
# ---------------------
resource "yandex_vpc_network" "net" {
  name        = "hw10-network"
  description = "Network for HW10 audit demo"
  folder_id   = var.folder_id
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "hw10-subnet-a"
  folder_id      = var.folder_id
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_security_group" "sg" {
  name       = "hw10-sg"
  folder_id  = var.folder_id
  network_id = yandex_vpc_network.net.id

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = [var.my_ip != "" ? var.my_ip : "0.0.0.0/0"]
  }

  ingress {
    protocol       = "ICMP"
    description    = "Ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------
# Service Accounts (симулируем двух пользователей)
# ---------------------
resource "yandex_iam_service_account" "user1" {
  name        = "hw10-user1"
  description = "User1 - VM creator"
  folder_id   = var.folder_id
}

resource "yandex_iam_service_account" "user2" {
  name        = "hw10-user2"
  description = "User2 - VM modifier"
  folder_id   = var.folder_id
}

# Роли на папке: пользователи умеют управлять ВМ и сетью (user-level доступ)
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

# ---------------------
# Object Storage for Audit logs
# ---------------------
resource "random_string" "bucket_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "yandex_storage_bucket" "audit_bucket" {
  bucket        = "hw10-audit-logs-${random_string.bucket_suffix.result}"
  folder_id     = var.folder_id
  force_destroy = true

  anonymous_access_flags {
    read = false
    list = false
  }
}

# SA, от имени которого Trail пишет в Object Storage
resource "yandex_iam_service_account" "audit_sa" {
  name        = "hw10-audit-sa"
  description = "Service Account for Audit Trails writer"
  folder_id   = var.folder_id
}

# Разрешаем trail-сервисному аккаунту СБОР логов в заданной папке
resource "yandex_resourcemanager_folder_iam_member" "audit_sa_at_viewer" {
  folder_id = var.folder_id
  role      = "audit-trails.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.audit_sa.id}"
}


# === Дадим trail-SA право собирать логи на уровне облака ===
resource "yandex_resourcemanager_cloud_iam_member" "audit_sa_at_viewer_cloud" {
  cloud_id = var.cloud_id
  role     = "audit-trails.viewer"
  member   = "serviceAccount:${yandex_iam_service_account.audit_sa.id}"
}


# Права только на загрузку в bucket
resource "yandex_resourcemanager_folder_iam_member" "audit_sa_storage_uploader" {
  folder_id = var.folder_id
  role      = "storage.uploader"
  member    = "serviceAccount:${yandex_iam_service_account.audit_sa.id}"
}




# ---------------------
# Audit Trail (только management events по папке)
# ---------------------
resource "yandex_audit_trails_trail" "trail" {
  name        = "hw10-audit-trail"
  folder_id   = var.folder_id
  description = "Audit trail for HW10 - VM user actions"

  labels = {
    environment = "homework"
    project     = "hw10"
  }

  service_account_id = yandex_iam_service_account.audit_sa.id

  storage_destination {
    bucket_name   = yandex_storage_bucket.audit_bucket.bucket
    object_prefix = "audit-logs"
  }



  filtering_policy {
    management_events_filter {
      resource_scope {
        resource_id   = var.folder_id
        resource_type = "resource-manager.folder"
      }
      # included_events по умолчанию = все mgmt события сервиса; можно сузить при необходимости
    }
    # Data events опущены намеренно, чтобы не упереться в неподдерживаемые сервисы
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.audit_sa_storage_uploader
  ]
}

# ---------------------
# Minimal VM
# ---------------------
resource "yandex_compute_instance" "vm" {
  name        = "hw10-demo-vm"
  hostname    = "hw10-vm"
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
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
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
}

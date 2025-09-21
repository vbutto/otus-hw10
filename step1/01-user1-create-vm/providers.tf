provider "yandex" {
  alias                    = "sa_user1"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = var.sa_user1_key_file
}

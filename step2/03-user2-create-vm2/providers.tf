provider "yandex" {
  alias                    = "sa_user2"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = var.sa_user2_key_file
}

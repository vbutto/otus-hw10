# ============================================================================
# Основные переменные
# ============================================================================

variable "cloud_id" {
  description = "Yandex Cloud cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "zone" {
  description = "Default availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "sa_terraform_key_file" {
  description = "Path to terraform service account key JSON file"
  type        = string
}

# ============================================================================
# Настройки доступа
# ============================================================================

variable "ssh_public_key" {
  description = "SSH public key content (not path to file)"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "Your IP address in CIDR format for SSH access (e.g., 1.2.3.4/32). Leave empty to disable SSH"
  type        = string
  default     = ""
}

###############################################
# Ключи сервисных аккаунтов (JSON выгрузка)
###############################################

variable "sa_user1_key_file" {
  description = "Путь для JSON-ключа hw10-user1"
  type        = string
  default     = "keys/hw10-user1.json"
}
variable "sa_user2_key_file" {
  description = "Путь для JSON-ключа hw10-user2"
  type        = string
  default     = "keys/hw10-user2.json"
}
variable "sa_audit_key_file" {
  description = "Путь для JSON-ключа hw10-audit-sa"
  type        = string
  default     = "keys/hw10-audit-sa.json"
}

variable "cloud_id" { type = string }
variable "folder_id" { type = string }

variable "zone" {
  type        = string
  description = "Зона размещения"
  default     = "ru-central1-a"
}

variable "subnet_id" {
  type        = string
  description = "ID существующей подсети (в этой зоне)"
}

variable "security_group_id" {
  type        = string
  description = "ID существующей security group"
}

variable "sa_user1_key_file" {
  type        = string
  description = "JSON-ключ сервисного аккаунта hw10-user1"
  default     = "keys/hw10-user1.json"
}

variable "ssh_public_key" {
  type        = string
  description = "Публичный SSH-ключ (строка вида 'ssh-ed25519 AAAA... user@host')"
}

variable "vm_name" {
  type        = string
  description = "Имя ВМ"
  default     = "hw10-user1-vm"
}

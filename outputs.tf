# ============================================================================
# HW10 Outputs - Аудит действий пользователей
# ============================================================================

output "hw10_instructions" {
  description = "Пошаговые инструкции для выполнения HW10"
  value       = <<-EOT
    
    ==================== HW10 - Аудит действий пользователей ====================
    
    🎯 ЗАДАЧА: Продемонстрировать аудит действий двух пользователей с ВМ
    
    ✅ СОЗДАННАЯ ИНФРАСТРУКТУРА:
    • Два сервисных аккаунта (User1 и User2)
    • Audit Trail для логирования действий
    • Минимальная ВМ (2 vCPU, 1GB RAM, 5% CPU)
    • Object Storage bucket для хранения логов
    
    📊 ДАННЫЕ ДЛЯ ТЕСТИРОВАНИЯ:
    
    VM ID:           ${yandex_compute_instance.hw10_vm.id}
    VM Name:         ${yandex_compute_instance.hw10_vm.name}
    External IP:     ${yandex_compute_instance.hw10_vm.network_interface.0.nat_ip_address}
    Internal IP:     ${yandex_compute_instance.hw10_vm.network_interface.0.ip_address}
    
    User1 SA ID:     ${yandex_iam_service_account.user1.id}
    User2 SA ID:     ${yandex_iam_service_account.user2.id}
    
    Audit Trail ID:  ${yandex_audit_trails_trail.hw10_audit.id}
    Audit Bucket:    ${yandex_storage_bucket.audit_bucket.bucket}
    
    🔄 СЦЕНАРИЙ ТЕСТИРОВАНИЯ:
    
    1️⃣ User1 создает минимальную ВМ ✅ (уже создана)
    
    2️⃣ User2 останавливает ВМ и меняет CPU:
       yc compute instance stop ${yandex_compute_instance.hw10_vm.id}
       yc compute instance update ${yandex_compute_instance.hw10_vm.id} --cores 4
       yc compute instance start ${yandex_compute_instance.hw10_vm.id}
    
    3️⃣ User1 останавливает ВМ и меняет RAM:
       yc compute instance stop ${yandex_compute_instance.hw10_vm.id}
       yc compute instance update ${yandex_compute_instance.hw10_vm.id} --memory 2GB
       yc compute instance start ${yandex_compute_instance.hw10_vm.id}
    
    📋 КОМАНДЫ ДЛЯ ПРОВЕРКИ АУДИТ ЛОГОВ:
    
    # Список событий Audit Trail
    yc audit-trails trail list-operations ${yandex_audit_trails_trail.hw10_audit.id}
    
    # Просмотр логов в bucket
    yc storage bucket list-objects ${yandex_storage_bucket.audit_bucket.bucket}
    
    # Скачать и просмотреть логи
    yc storage cp s3://${yandex_storage_bucket.audit_bucket.bucket}/audit-logs/ . --recursive
    
    🔐 ДЛЯ ТЕСТИРОВАНИЯ ОТ ИМЕНИ ПОЛЬЗОВАТЕЛЕЙ:
    
    1. Создайте ключи для сервисных аккаунтов:
       yc iam key create --service-account-id ${yandex_iam_service_account.user1.id} --output user1-key.json
       yc iam key create --service-account-id ${yandex_iam_service_account.user2.id} --output user2-key.json
    
    2. Переключайтесь между пользователями:
       yc config set service-account-key user1-key.json  # User1
       yc config set service-account-key user2-key.json  # User2
    
    🔍 ЧТО АНАЛИЗИРОВАТЬ В ЛОГАХ:
    • Время действий пользователей
    • Типы операций (stop, start, update)
    • Изменения параметров ВМ (cores, memory)
    • Идентификаторы пользователей в event_type
    
    🌐 WEB ИНТЕРФЕЙС:
    Audit Trail: https://console.cloud.yandex.ru/folders/${var.folder_id}/audit-trails
    VM Console:  https://console.cloud.yandex.ru/folders/${var.folder_id}/compute/instances
    
    ===============================================================================
    
    💡 ПОДСКАЗКА: Audit логи могут появляться с задержкой 5-15 минут!
    
  EOT
}

output "vm_ssh_command" {
  description = "Команда для SSH подключения к ВМ"
  value       = "ssh ubuntu@${yandex_compute_instance.hw10_vm.network_interface.0.nat_ip_address}"
}

output "user_service_accounts" {
  description = "ID сервисных аккаунтов пользователей"
  value = {
    user1_id   = yandex_iam_service_account.user1.id
    user1_name = yandex_iam_service_account.user1.name
    user2_id   = yandex_iam_service_account.user2.id
    user2_name = yandex_iam_service_account.user2.name
  }
}

output "audit_info" {
  description = "Информация об Audit Trail"
  value = {
    trail_id    = yandex_audit_trails_trail.hw10_audit.id
    trail_name  = yandex_audit_trails_trail.hw10_audit.name
    bucket_name = yandex_storage_bucket.audit_bucket.bucket
    sa_id       = yandex_iam_service_account.audit_sa.id
  }
}

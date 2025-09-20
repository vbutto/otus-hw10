output "vm_id" {
  description = "VM ID"
  value       = yandex_compute_instance.vm.id
}
output "vm_external_ip" {
  description = "VM external IP"
  value       = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}
output "vm_internal_ip" {
  description = "VM internal IP"
  value       = yandex_compute_instance.vm.network_interface.0.ip_address
}
output "user1_sa_id" {
  value       = yandex_iam_service_account.user1.id
  description = "Service Account ID (User1)"
}
output "user2_sa_id" {
  value       = yandex_iam_service_account.user2.id
  description = "Service Account ID (User2)"
}
output "audit_trail_id" {
  value       = yandex_audit_trails_trail.trail.id
  description = "Audit Trail ID"
}
output "audit_bucket_name" {
  value       = yandex_storage_bucket.audit_bucket.bucket
  description = "Bucket name for audit logs"
}

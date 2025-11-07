// These outputs have a usage in tests.(not redundant)

output "main_password" {
  value       = local.main_password
  sensitive   = true
  description = "The main (active) password."
}

output "backup_password" {
  value       = local.backup_password
  sensitive   = true
  description = "The backup (inactive / standby) password."
}
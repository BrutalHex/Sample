output "main_password" {
  value     = module.password_manager.main_password
  sensitive = true
}

output "backup_password" {
  value     = module.password_manager.backup_password
  sensitive = true
}
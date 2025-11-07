//TODO: check namespace existance before creating secret.

// Kubernetes Secret holding the active (main) and standby (backup) passwords.
// The values are resolved after swap/rotation parity logic so that "main" always
// reflects the currently active credential and "backup" the future/previous one.
resource "kubernetes_secret" "password_secret" {
  metadata {
    name        = var.SECRET_NAME
    namespace   = var.NAMESPACE
    annotations = var.ANNOTATIONS
  }

  data = {
    // Active password exposed to consumers
    main = local.main_password
    // Standby password; rotated when operation = "rotate" then promoted on "swap"
    backup = local.backup_password
  }
}

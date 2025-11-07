
// Local composite annotations applied to the password secret.
// Adds a static marker plus any user-provided annotations.
locals {
  annotations = merge(
    var.ANNOTATIONS,
    {
      "example.io/generated" = "true" // indicates generated via password-manager module
    }
  )
}

// The module that handles password generation, rotation, and swapping.
module "password_manager" {
  source = "./modules/password-generator"

  // Control operation: none | rotate | swap
  OPERATION = var.OPERATION
  // Kubernetes secret identity
  SECRET_NAME = var.SECRET_NAME
  NAMESPACE   = var.NAMESPACE
  // Merged annotations passed into underlying secret
  ANNOTATIONS = local.annotations
  // Parameterized password generation settings
  PASSWORD_LENGTH            = var.PASSWORD_LENGTH
  PASSOWORD_OVERRIDE_SPECIAL = var.PASSOWORD_OVERRIDE_SPECIAL

  // Ensure namespace exists before secret creation
  depends_on = [kubernetes_namespace.managed]
}

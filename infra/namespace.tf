// Conditionally creates a Kubernetes namespace when a non-default namespace is requested.
// If `var.NAMESPACE` is "default" we assume it already exists and skip creation (count = 0).
resource "kubernetes_namespace" "managed" {
  count = var.NAMESPACE == "default" ? 0 : 1
  metadata {
    name = var.NAMESPACE
  }
}
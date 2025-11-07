// Reads prior parity counters (swap & rotation) from parity.json if it exists.
// Provides continuity across Terraform runs so rotation/swap decisions are stateful.
data "local_file" "previous_parity" {
  count    = fileexists("${path.module}/parity.json") ? 1 : 0
  filename = "${path.module}/parity.json"
}

locals {
  previous_parity_content = try(data.local_file.previous_parity[0].content, jsonencode({
    swap_parity     = "0"
    rotate_parity_a = "0"
    rotate_parity_b = "0"
  }))
}

// TODO: switch to s3 bucket with versioning and deletion protection.
// Persists updated parity counters after evaluating the requested operation so that
// subsequent applies reference the latest state (used by external manager + keepers).
resource "local_file" "parity" {
  content = jsonencode({
    swap_parity     = local.swap_parity
    rotate_parity_a = local.rotate_parity_a
    rotate_parity_b = local.rotate_parity_b
  })
  filename = "${path.module}/parity.json"
}
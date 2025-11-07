// Local parity and mapping logic.
// Parity integers come from the external Python manager and drive deterministic password rotation.
locals {
  // Counters loaded from external data source; incremented according to requested operation.
  swap_parity     = tonumber(data.external.manager.result.swap_parity)
  rotate_parity_a = tonumber(data.external.manager.result.rotate_parity_a)
  rotate_parity_b = tonumber(data.external.manager.result.rotate_parity_b)

  // When swap_parity is odd, logical roles are flipped.
  is_swapped = local.swap_parity % 2 == 1
  //   is_swapped == false -> main_password uses random_password.a
  //   is_swapped == true  -> main_password uses random_password.b
  main_password   = local.is_swapped ? random_password.b.result : random_password.a.result
  backup_password = local.is_swapped ? random_password.a.result : random_password.b.result
}

// Null resource to force Terraform to track changes in parity values in the dependency graph.
// This makes downstream resources react when counters change even if their own config is static.
resource "null_resource" "state_tracker" {
  triggers = {
    swap_parity     = local.swap_parity
    rotate_parity_a = local.rotate_parity_a
    rotate_parity_b = local.rotate_parity_b
  }
}

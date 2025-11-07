// Underlying raw password for the logical "main" role when not swapped.
resource "random_password" "a" {
  length           = var.PASSWORD_LENGTH
  special          = true
  override_special = var.PASSOWORD_OVERRIDE_SPECIAL
  keepers = {
    rotate = local.rotate_parity_a
  }
}

// Underlying raw password for the logical "backup" role when not swapped.
// Rotates only when rotate_parity_b changes; becomes active after a swap.
resource "random_password" "b" {
  length           = var.PASSWORD_LENGTH
  special          = true
  override_special = var.PASSOWORD_OVERRIDE_SPECIAL
  keepers = {
    rotate = local.rotate_parity_b
  }
}

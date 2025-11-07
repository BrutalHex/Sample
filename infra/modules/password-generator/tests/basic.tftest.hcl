// Terraform tests for password rotation/swap behavior.

provider "kubernetes" {
  config_path = "~/.kube/config"
}

variables {
  secret_name = "test-secret"
  namespace   = "default"
}

run "initial" {
  variables { OPERATION = "none" }

  assert {
    condition     = length(output.main_password) > 0
    error_message = "Main password should be generated initially"
  }

  assert {
    condition     = length(output.backup_password) > 0
    error_message = "Backup password should be generated initially"
  }
}

run "rotate" {
  variables { OPERATION = "rotate" }

  assert {
    condition     = output.main_password == run.initial.main_password
    error_message = "Main password should remain the same after rotate"
  }

  assert {
    condition     = output.backup_password != run.initial.backup_password
    error_message = "Backup password should change after rotate"
  }
}

run "none_after_rotate" {
  variables { OPERATION = "none" }

  assert {
    condition     = output.main_password == run.rotate.main_password
    error_message = "Main password should remain the same"
  }

  assert {
    condition     = output.backup_password == run.rotate.backup_password
    error_message = "Backup password should remain the same"
  }
}

run "swap" {
  variables { OPERATION = "swap" }

  assert {
    condition     = output.main_password == run.none_after_rotate.backup_password
    error_message = "Main password should be the old backup after swap"
  }

  assert {
    condition     = output.backup_password == run.none_after_rotate.main_password
    error_message = "Backup password should be the old main after swap"
  }
}

run "none_after_swap" {
  variables { OPERATION = "none" }

  assert {
    condition     = output.main_password == run.swap.main_password
    error_message = "Main password should remain the same"
  }

  assert {
    condition     = output.backup_password == run.swap.backup_password
    error_message = "Backup password should remain the same"
  }
}

run "rotate_after_swap" {
  variables { OPERATION = "rotate" }

  assert {
    condition     = output.main_password == run.none_after_swap.main_password
    error_message = "Main password should remain the same after rotate post-swap"
  }

  assert {
    condition     = output.backup_password != run.none_after_swap.backup_password
    error_message = "Backup password should change after rotate post-swap"
  }
}

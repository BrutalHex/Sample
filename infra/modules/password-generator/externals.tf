// External data source invoking Python parity manager to update swap and rotation counters
// based on requested operation (none | rotate | swap).
data "external" "manager" {
  program = ["python3", "${path.module}/dynamic/manager.py"]

  query = {
    operation = var.OPERATION
    previous  = local.previous_parity_content
  }
}

# Password Manager Terraform Project

This project provisions and manages a Kubernetes `Secret` containing two coordinated passwords (`main` and `backup`) using the `password_manager` Terraform module (`infra/modules/password-generator`). The module implements controlled credential lifecycle operations:

* `none` – It's used to allow resource change propagations in terraform.
* `rotate` – Rotate the *standby* password for the next swap (the parity logic ensures only the inactive password is regenerated). After a future `swap`, that rotated value becomes the new active password.
* `swap` – Atomically flip logical roles between the two stored passwords without regenerating them (promotes `backup` to `main` and demotes the old `main` to `backup`).

Additional features:
* Annotated secrets: user-provided annotations are merged with a generated marker (`example.io/generated=true`).
* Deterministic tracking: Terraform `keepers` and stored parity counters ensure idempotent, explicit rotations only when requested.

## Variables

Root-level variables (from `infra/variables.tf`):

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `operation` | string | `"none"` | Requested lifecycle action: `none`, `rotate`, or `swap`. |
| `namespace` | string | `"default"` | Kubernetes namespace for the secret. |
| `secret_name` | string | `"example-secret"` | Name of the managed Kubernetes secret. |
| `annotations` | map(string) | `{}` | Extra annotations merged onto the secret. |
| `password_length` | number | `16` | Length of generated random passwords. |
| `passoword_override_special` | string | `!@#$%^&*()_+-=[]{}|` | Override set of special characters used by password generation. |

### Rotation Sequence Example

1. pass `operation = "none"` to generate.
2. Apply with `operation = "rotate"` – Generates a new standby password only (inactive until next step).
3. Apply with `operation = "swap"` – Promotes the previously rotated standby to active usage.
4. Revert or continue by repeating the cycle for ongoing credential hygiene.
5. pass `operation = "none"` in case of terraform resource changes.

Use the `test.sh` script to have an actual preview like:

```sh
=== Applying operation: none ===
MAIN: HDekN_&bZI9e}nA}
BACKUP: =DYZc_j-rG0Gv7bt
=== Applying operation: rotate ===
MAIN: HDekN_&bZI9e}nA}
BACKUP: bUnlo{b^(6}5M!Rk
=== Applying operation: swap ===
MAIN: bUnlo{b^(6}5M!Rk
BACKUP: HDekN_&bZI9e}nA}
=== Applying operation: rotate ===
MAIN: bUnlo{b^(6}5M!Rk
BACKUP: ePt9tJezvYHmuXVM
=== Applying operation: none ===
MAIN: bUnlo{b^(6}5M!Rk
BACKUP: ePt9tJezvYHmuXVM
=== Applying operation: swap ===
MAIN: ePt9tJezvYHmuXVM
BACKUP: bUnlo{b^(6}5M!Rk
```

## Sample Input (`terraform.tfvars`)

The file `infra/terraform.tfvars` demonstrates typical values:

```hcl
# Password operation: one of "none", "rotate", "swap".
operation = "swap"

# Target Kubernetes namespace for the secret.
namespace = "app-namespace"

# Name of the Kubernetes secret that will be managed.
secret_name = "my-app-secret"

# Optional annotations to attach to the secret metadata.
annotations = {
	owner       = "team-dev"
	environment = "dev"
	managed-by  = "terraform"
}
```

Adjust these values (and optionally `password_length` or `passoword_override_special`) to fit your environment.

## Make Targets & Workflow

All automation is driven via the `Makefile`. Common targets:

> Note: You usually don't need to run `make tools` manually—other targets depend on it and will trigger tool installation automatically when required.

| Target | Purpose |
|--------|---------|
| `make help` | Lists all available targets with inline descriptions. |
| `make tools` | Installs required local tooling (`kind`, `kubectl`, `terraform`, Python) into `./bin` / `.venv`. Run first. |
| `make check` | Initializes (no backend), formats Terraform, validates configuration. Use before committing changes. |
| `make plan` | Produces a Terraform plan (`tfplan`) after initialization so you can audit intended changes. |
| `make apply` | Applies the previously generated plan (`tfplan`) non-interactively (`-auto-approve`). Requires a prior `make plan`. |
| `make test` | Spins up (or reuses) a local KIND cluster (`setup-kind` dependency) then auto-discovers and runs Terraform tests (`*.tftest.hcl`) per module. Outputs verbose results. |
| `make setup-kind` | Ensures a local KIND Kubernetes cluster exists (override image via `NODE_IMAGE`). |
| `make delete-kind` | Deletes the local KIND cluster (override cluster via `CLUSTER_NAME`). |

Suggested development loop:
1. Edit Terraform/module code
2. `make tools`
3. `make check` (lint/validate)
4. `make test` (verify module behavior)
5. `make plan` (review changes)
6. `make apply` (provision / update secret)


## Test Results

Below is an inline inclusion of the test results. Trigger `test pipeline` to regenerate its contents.

<!-- BEGIN: test_auto_generated.md (included) -->
| Execution Date | Passed | Failed | Status |
|----------------|--------|--------|--------|
| 2025-11-08 13:44:49 | 6 | 0 | ✅ |
<!-- END: test_auto_generated.md -->

## Kubernetes Secret Semantics

The resulting secret holds two keys:

| Key | Meaning |
|-----|---------|
| `main` | Currently active password for consumers. Swapped during `swap` operations. |
| `backup` | Staged password: rotated during `rotate`; promoted to `main` on `swap`. |

This pattern allows for coordinated credential rollouts: update dependent services to read the `backup` value in advance, then `swap` to activate without race conditions.

## Preview
To run Terraform against the KIND cluster, use the `test.sh` script.
Example output:

![sample](https://github.com/user-attachments/assets/1cd5b928-cd29-4012-94ef-c058660def67)

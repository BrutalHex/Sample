# Password Generator Module

## Purpose
This Terraform module generates **two random passwords** (an active `main` password and a passive `backup` password), persists their rotation state locally, and stores their current values in a Kubernetes Secret. It supports:
- Swapping
- Rotating

Only a fixed two-password pair (`main` and `backup`) is supported.

## Core Concepts
| Concept | Description |
|---------|-------------|
| Generation | Two `random_password` resources are created. |
| Main vs Backup | A parity-driven swap mechanism decides which raw password is exposed as `main` vs `backup`. |
| Rotation | The backup password is rotated when `operation = "rotate"`. Active password remains stable. |
| Swap | Flips which underlying password is considered `main` (active) vs `backup`. |
| Persistence | A local JSON file `parity.json` tracks swap and rotation counters across runs. |
| External Manager | A Python script (`dynamic/manager.py`) calculates updated parity values based on the requested operation. |
| Secret Sync | A `kubernetes_secret` stores the current resolved `main` and `backup` values. |

## Operations
The operation gets controled via `var.operation` value according to the following details:
| Value | Effect |
|-------|--------|
| `none` | No state change; passwords preserved.(usefull for changes like: adding,removing resources or manipulating metadata) |
| `rotate` | Rotates the **backup** password only (ensures predictable staged credential rollout). |
| `swap` | Switches roles: previous backup becomes main; previous main becomes backup. |

## Data Flow
1. Read previous parity from `parity.json` (if present).
2. Call `dynamic/manager.py` with requested `operation` and previous state.
3. Compute locals: swap & rotation parity decide which raw password maps to `main` / `backup`.
4. Potentially trigger regeneration of one `random_password` via `keepers` parity change.
5. Persist new parity back to `parity.json`.
6. Persists resolved passwords into a Kubernetes Secret.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `operation` | string | `"none"` | One of `none`, `rotate`, `swap`. Controls lifecycle logic. |
| `secret_name` | string | (required) | Name of the Kubernetes Secret to create/update. |
| `namespace` | string | `"default"` | Target Kubernetes namespace. |
| `annotations` | map(string) | `{}` | Extra annotations applied to the Secret metadata. |
| `password_length` | number | `16` | Fixed length for both generated passwords. To change, edit `random_passwords.tf` (or promote to a variable). |
| `password_override_special` | string | `"!@#$%^&*()_+-=[]{}|"` | Set of special characters used during password generation. Modify in `random_passwords.tf` if needed. |

## Usage Example
```hcl
module "passwords" {
  source      = "./infra/modules/password-generator"
  secret_name = "app-credentials"
  namespace   = "prod"
  operation   = "rotate"   # or "swap" / "none"
}
```

## Testing
The file `tests/basic.tftest.hcl` validates initial generation, rotation semantics, swap behavior, and post-operation stability.
Run (depending on your repo setup):
```sh
make test
```

## Future Improvements
- Support N-password ring with phased rotation.
- Add optional TTL-driven automatic rotation.
- Integrate with external secret managers (Vault, AWS Secrets Manager, GCP Secret Manager).

## Troubleshooting
| Symptom | Cause | Resolution |
|---------|-------|-----------|
| Password not rotating | Wrong `operation` value | Set `operation = "rotate"` and apply again. |
| Secret unchanged after expected change | Parity not incremented | Verify `parity.json` updated; delete file to reset (will re-init). |
| Invalid operation error | Typo in variable | Must be one of `none`, `rotate`, `swap`. |

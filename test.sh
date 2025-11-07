#!/bin/sh

set -euo pipefail

SECRET_NAME="example-secret"
INFRA_DIR="./infra"
KUBECTL=./bin/kubectl
TERRAFORM=./bin/terraform

print_secret() {
  "$KUBECTL" get secret "$SECRET_NAME" -o json | jq -r '
    .data | { MAIN: (.main | @base64d), BACKUP: (.backup | @base64d) } | to_entries[] | "\(.key): \(.value)"'
}

make setup-kind

for op in none rotate swap rotate none swap; do
	echo "=== Applying operation: $op ==="
  "$TERRAFORM" -chdir="$INFRA_DIR" init -input=false -no-color >/tmp/tf.out 2>&1 || { echo "init failed"; cat /tmp/tf.out; exit 1; }
  TF_VAR_OPERATION="$op" "$TERRAFORM" -chdir="$INFRA_DIR" plan -out=tfplan -input=false -no-color >/tmp/tf.out 2>&1 || { echo "plan failed"; cat /tmp/tf.out; exit 1; }
  TF_VAR_OPERATION="$op" "$TERRAFORM" -chdir="$INFRA_DIR" apply -auto-approve -input=false -no-color tfplan >/tmp/tf.out 2>&1 || { echo "apply failed"; cat /tmp/tf.out; exit 1; }
	print_secret
done

echo "Done."

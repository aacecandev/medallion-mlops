#!/usr/bin/env bash
# Generate the MLflow Postgres owner credentials and seal them into a
# committable SealedSecret.
#
# This seals ONLY the Postgres credentials. The RustFS artifact-bucket
# key (rustfs-mlflow-creds) is sealed by k8s/rustfs/secrets/seal.sh,
# together with the bronze/silver/gold bucket keys.
#
# The secret is a kubernetes.io/basic-auth secret with username=mlflow,
# which is required by CloudNativePG: the `username` must match the
# Cluster's initdb `owner`. The same Secret is also referenced by the
# MLflow Helm chart via backendStore.existingDatabaseSecret.
#
# Run this ONCE (or whenever you rotate the password) against a cluster
# whose Sealed Secrets controller is already running. The *-sealed.yaml
# output is encrypted with the controller's public key and safe to commit.
#
# Prerequisites:
#   - kubeseal (mise: `kubeseal = "0.40.0"`) + kubectl pointed at the cluster
#   - the sealed-secrets controller running (ArgoCD app `sealed-secrets`)
#   - openssl
#
# Usage:
#   mise exec -- ./k8s/mlflow/secrets/seal.sh
#   git add k8s/mlflow/secrets/*-sealed.yaml && git commit
set -euo pipefail

cd "$(dirname "$0")"

KUBESEAL=(kubeseal --controller-name sealed-secrets-controller \
  --controller-namespace kube-system --format yaml)

rand() { openssl rand -hex "${1:-24}"; }

# --- MLflow Postgres owner credentials (mlflow namespace) -----------------
# username MUST be "mlflow" to match the Cluster initdb owner.
PG_PASS="$(rand 24)"
kubectl create secret generic mlflow-postgres \
  --namespace mlflow \
  --type kubernetes.io/basic-auth \
  --from-literal=username=mlflow \
  --from-literal=password="$PG_PASS" \
  --dry-run=client -o yaml | "${KUBESEAL[@]}" > mlflow-postgres-sealed.yaml
echo "sealed mlflow-postgres"

echo
echo "Done. Review and commit the *-sealed.yaml file."

#!/usr/bin/env bash
# Generate RustFS credentials and seal them into committable SealedSecrets.
#
# Run this ONCE (or whenever you rotate keys) against a cluster whose
# Sealed Secrets controller is already running. The *-sealed.yaml output
# is encrypted with the controller's public key and is safe to commit;
# the plaintext never touches git.
#
# Prerequisites:
#   - kubeseal (mise: `kubeseal = "0.40.0"`) + kubectl pointed at the cluster
#   - the sealed-secrets controller running (ArgoCD app `sealed-secrets`)
#   - openssl
#
# Usage:
#   ./seal.sh
#   git add k8s/rustfs/secrets/*-sealed.yaml && git commit
set -euo pipefail

cd "$(dirname "$0")"

ENDPOINT="http://rustfs-svc.rustfs.svc.cluster.local:9000"
KUBESEAL=(kubeseal --controller-name sealed-secrets-controller \
  --controller-namespace kube-system --format yaml)

rand() { openssl rand -hex "${1:-24}"; }

# --- RustFS root credentials (rustfs namespace) ---------------------------
ROOT_USER="rustfsroot"
ROOT_PASS="$(rand 24)"
kubectl create secret generic rustfs-root \
  --namespace rustfs \
  --from-literal=RUSTFS_ACCESS_KEY="$ROOT_USER" \
  --from-literal=RUSTFS_SECRET_KEY="$ROOT_PASS" \
  --dry-run=client -o yaml | "${KUBESEAL[@]}" > rustfs-root-sealed.yaml
echo "sealed rustfs-root"

# --- Per-bucket scoped access keys ----------------------------------------
seal_bucket() {
  local layer="$1" namespace="$2" outfile="$3"
  local sk="$4"
  kubectl create secret generic "rustfs-${layer}-creds" \
    --namespace "$namespace" \
    --from-literal=AWS_ACCESS_KEY_ID="$layer" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$sk" \
    --from-literal=AWS_ENDPOINT_URL="$ENDPOINT" \
    --from-literal=BUCKET="$layer" \
    --dry-run=client -o yaml | "${KUBESEAL[@]}" > "$outfile"
  echo "sealed rustfs-${layer}-creds (${namespace})"
}

BRONZE_SK="$(rand 24)"
SILVER_SK="$(rand 24)"
GOLD_SK="$(rand 24)"

# rustfs namespace: all three, consumed by the provisioning Job.
seal_bucket bronze rustfs rustfs-bronze-creds-sealed.yaml "$BRONZE_SK"
seal_bucket silver rustfs rustfs-silver-creds-sealed.yaml "$SILVER_SK"
seal_bucket gold   rustfs rustfs-gold-creds-sealed.yaml   "$GOLD_SK"

# jupyterhub namespace: bronze only, for EDA. Same secret key as the
# rustfs-ns bronze so the single RustFS user works from both namespaces.
seal_bucket bronze jupyterhub rustfs-bronze-creds-jupyterhub-sealed.yaml "$BRONZE_SK"

echo
echo "Done. Review and commit the *-sealed.yaml files."

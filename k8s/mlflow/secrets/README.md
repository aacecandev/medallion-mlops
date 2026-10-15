# MLflow sealed credentials

Encrypted credentials for MLflow, managed GitOps-style with
[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). Only the
encrypted `*-sealed.yaml` files live here — plaintext never touches git.

## What gets created

| SealedSecret | Namespace | Type | Purpose |
| --- | --- | --- | --- |
| `mlflow-postgres` | `mlflow` | `kubernetes.io/basic-auth` | Postgres owner creds. Consumed by the CloudNativePG `Cluster` (initdb bootstrap) **and** by the MLflow chart (`backendStore.existingDatabaseSecret`). |

> The MLflow artifact-bucket key (`rustfs-mlflow-creds`) is **not** here.
> It is sealed by `k8s/rustfs/secrets/seal.sh` alongside the other bucket
> keys and provisioned by the RustFS provisioning Job.

The `username` in `mlflow-postgres` is `mlflow` on purpose: CloudNativePG
requires the basic-auth `username` to match the `Cluster` initdb `owner`.

## How to (re)generate

```sh
# 1. Make sure the sealed-secrets controller is running (ArgoCD app `sealed-secrets`).
kubectl -n kube-system get deploy sealed-secrets-controller

# 2. Generate + seal.
mise exec -- ./k8s/mlflow/secrets/seal.sh

# 3. Commit the encrypted output (safe).
git add k8s/mlflow/secrets/*-sealed.yaml
git commit -m "chore(mlflow): add sealed postgres credentials"
```

## Rotating the password

Re-run `seal.sh` (it generates a fresh random password), commit, and let
ArgoCD apply. CloudNativePG reconciles the owner password on the next sync.

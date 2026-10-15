# RustFS sealed credentials

Encrypted credentials for RustFS, managed GitOps-style with
[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). Only the
encrypted `*-sealed.yaml` files live here — plaintext never touches git.

## What gets created

| SealedSecret | Namespace | Purpose |
| --- | --- | --- |
| `rustfs-root` | `rustfs` | RustFS root credentials (consumed by the chart via `existingSecret`). |
| `rustfs-bronze-creds` | `rustfs` | Bronze bucket access key (consumed by the provisioning Job). |
| `rustfs-silver-creds` | `rustfs` | Silver bucket access key. |
| `rustfs-gold-creds` | `rustfs` | Gold bucket access key. |
| `rustfs-bronze-creds` | `jupyterhub` | Bronze creds exposed to Jupyter for EDA. |

Each per-bucket key is scoped by a bucket-only policy in RustFS, so the
bronze key can only touch `bronze`, etc.

## How to (re)generate

The sealing is cluster-specific (it uses your controller's public key),
so it must be done against your own cluster:

```sh
# 1. Make sure the sealed-secrets controller is running (ArgoCD app `sealed-secrets`).
kubectl -n kube-system get deploy sealed-secrets-controller

# 2. Generate + seal everything.
mise exec -- ./k8s/rustfs/secrets/seal.sh

# 3. Commit the encrypted output (safe).
git add k8s/rustfs/secrets/*-sealed.yaml
git commit -m "chore(rustfs): add sealed credentials"
```

ArgoCD then syncs the SealedSecrets (wave 1), the controller decrypts
them into native Secrets, RustFS starts with its root credentials
(wave 2), and the provisioning Job creates the buckets + scoped users
(wave 3).

## Rotating a key

Re-run `seal.sh` (it generates fresh random secrets), commit, and let
ArgoCD apply. The provisioning Job re-runs on sync and updates the RustFS
users to the new keys.

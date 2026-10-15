# medallion-mlops

A single-node **k3s homelab** that bootstraps itself from bare metal and then
runs on **GitOps**. A short set of imperative [`mise`](https://mise.jdx.dev)
tasks stands the cluster up (k3s → Cilium → ArgoCD); after that, ArgoCD
reconciles everything from the manifests in `k8s/`.

- **k3s** with kube-proxy and flannel disabled — Cilium owns the datapath.
- **Cilium** (eBPF) as CNI + LoadBalancer with L2 announcements.
- **ArgoCD** app-of-apps as the GitOps control plane.

Full details and the diagram live in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

## Quick start

```sh
mise install                 # install pinned tooling
mise run k3s-master-install  # install k3s (no kube-proxy / flannel)
mise run network-install     # install Cilium CNI + LoadBalancer pool
mise run argocd-install      # install ArgoCD + hand over to GitOps
```

To tear everything down (including Cilium datapath leftovers):

```sh
mise run k3s-uninstall
```

## Why "medallion"?

The name is a double entendre. In New York City, a *medallion* is the official license that authorizes the city's iconic yellow taxis. It's also the name of the **medallion architecture** — the bronze/silver/gold layering pattern used to progressively refine data in a lakehouse. This repo leans on that same pattern, so the name nods to both: a licensed, structured flow of data through bronze, silver, and gold tiers.

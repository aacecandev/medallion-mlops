# Architecture

`medallion-mlops` bootstraps a **single-node k3s homelab** and then hands it over
to **GitOps**. The repository has two layers:

1. **Imperative bootstrap** — a handful of idempotent [`mise`](https://mise.jdx.dev)
   tasks that stand the cluster up from bare metal.
2. **Declarative runtime** — once ArgoCD is running, the cluster reconciles itself
   from the manifests committed under `k8s/`.

See [`architecture.excalidraw`](./architecture.excalidraw) for the visual overview.

## Design principles

- **Bootstrap once, GitOps forever.** The `mise` tasks only exist to reach the
  point where ArgoCD can take over. After that, the desired state lives in Git.
- **No kube-proxy, no flannel.** k3s is installed with its default networking
  stack disabled so Cilium owns the entire datapath via eBPF.
- **Reproducible tooling.** Every binary (`k3s`, `cilium-cli`, `helm`,
  `gitleaks`, `pre-commit`) is pinned in `mise.toml` / `mise.lock`.
- **Secrets never land in Git.** A `gitleaks` pre-commit hook scans every staged
  change against the mise-pinned binary.

## Why "medallion"?

The name is a double entendre — a New York taxi *medallion* (a license) and the
lakehouse **medallion architecture** (bronze/silver/gold data tiers). Today this
repo is the **infrastructure foundation**; the medallion data pipeline is the
roadmap it is built to host.

## Bootstrap flow (imperative, `mise`)

Run in order. Each task is idempotent and safe to re-run.

| Task | What it does |
| --- | --- |
| `k3s-master-install` | Installs k3s `v1.36.2+k3s1` with `--flannel-backend=none --disable-network-policy --disable=traefik --disable=servicelb --disable-kube-proxy`, then copies the kubeconfig to `~/.kube/configs/k3s.yaml`. |
| `network-install` | Auto-detects the control-plane `InternalIP`, opens the k3s pod/service CIDRs in UFW if active, installs Cilium `1.19.5` via Helm with `k8sServiceHost` injected, waits for the Cilium CRDs, and applies the LoadBalancer IP pool + L2 announcement policy. |
| `argocd-install` | Installs ArgoCD `10.10.3` via Helm (exposed as a `LoadBalancer` Service), then applies the `root` app-of-apps so GitOps takes over. |
| `k3s-uninstall` | Tears k3s down **and** deep-cleans Cilium leftovers (stale `cilium_*` interfaces, `CILIUM`/`OLD_CILIUM` iptables chains, pinned BPF maps, UFW CIDR rules). Use this for a truly clean slate. |

### Why kube-proxy and flannel are disabled

k3s ships flannel + kube-proxy by default. Cilium replaces **both** with its eBPF
datapath (`kubeProxyReplacement: true`, `routingMode: native`). Because
kube-proxy is gone, Cilium must reach the API server directly — that is why
`k8sServiceHost` is injected at install time instead of being hardcoded in the
values file.

### The UFW gotcha

With kube-proxy disabled, pods reach the API server as `ClusterIP -> node:6443`.
That traffic arrives on the host `INPUT` chain via `lxc*` interfaces and hits
UFW's default deny, so CoreDNS and friends can never reach the API. The
`network-install` task fixes this by allowing the pod CIDR (`10.42.0.0/16`) and
service CIDR (`10.43.0.0/16`) in UFW when it is active.

## Runtime layer (declarative, GitOps)

### Networking — Cilium

- `k8s/network/cilium-values.yaml` — Helm values: eBPF kube-proxy replacement,
  native routing on `10.42.0.0/16`, BPF masquerade, L2 announcements, Hubble
  (relay + UI). `k8sServiceHost` is intentionally **not** set here; it is injected
  by `network-install` and pinned as a Helm parameter once ArgoCD adopts Cilium.
- `k8s/network/cilium-lb.yaml` — a `CiliumLoadBalancerIPPool` (`lan-pool`,
  `192.168.1.240-250`) plus a `CiliumL2AnnouncementPolicy` that advertises
  LoadBalancer / external IPs over L2 (ARP) on interface `wlo1`.

### GitOps — ArgoCD app-of-apps

- `k8s/argocd/values.yaml` — ArgoCD served over plain HTTP (`server.insecure`)
  and exposed as a `LoadBalancer` Service so it gets an IP from `lan-pool`.
- `k8s/argocd/root-app.yaml` — the `root` Application watches
  `k8s/argocd/apps/` with `directory.recurse` and manages every child
  Application it finds there. Add a new app by committing a manifest into that
  directory.
- `k8s/argocd/apps/cilium.yaml` — ArgoCD adopts the CNI using the same values
  file via a multi-source `$values` reference. `prune` is **disabled** here so
  ArgoCD never garbage-collects networking; `k8sServiceHost` is pinned
  (`192.168.1.134`) because ArgoCD can't auto-detect it the way the mise task
  does.
- `k8s/argocd/apps/cilium-lb.yaml` — ArgoCD manages the LoadBalancer IP pool +
  L2 policy (`include: cilium-lb.yaml`, server-side apply).

## Repository layout

```
.
├── mise.toml                     # pinned tools + bootstrap/teardown tasks
├── mise.lock                     # locked tool versions
├── .pre-commit-config.yaml       # gitleaks secret scanning
└── k8s/
    ├── network/
    │   ├── cilium-values.yaml     # Cilium Helm values (eBPF, L2, Hubble)
    │   └── cilium-lb.yaml         # LB IP pool + L2 announcement policy
    └── argocd/
        ├── values.yaml            # ArgoCD Helm values (LoadBalancer, insecure)
        ├── root-app.yaml          # app-of-apps root
        └── apps/
            ├── cilium.yaml        # ArgoCD adopts Cilium (no prune)
            └── cilium-lb.yaml     # ArgoCD manages the LB pool
```

## Access after bootstrap

`argocd-install` prints the ArgoCD LoadBalancer IP and the initial admin
password at the end of the run. Reach the UI at `http://<lb-ip>` (plain HTTP by
design for a homelab LAN).

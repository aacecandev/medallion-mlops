# medallion-mlops

A self-hosted, end-to-end **MLOps lab** built on a **Proxmox VE homelab**
and driven entirely by **GitOps**. The goal is to take raw **NYC Taxi &
Limousine Commission (TLC)** trip data through a full **medallion architecture**
(bronze → silver → gold) and all the way to a monitored, online model-serving
pipeline — every component self-hosted and reconciled from this repository.

## The goal

```
TLC trip data ──▶ Jupyter (EDA) ──▶ PySpark ETL
                                         │
        ┌────────────── RustFS (S3-compatible) ──────────────┐
        │   Bronze ──▶ Silver ──▶ Gold (features per zone)    │
        └────────────────────────┬────────────────────────────┘
                                  ▼
          MLflow ◀── Training ◀── Feast (offline + registry)
            │                        │
            ▼                        ▼
      KServe / MLServer ◀────────  Redis (online store) ──▶ Monitoring
                                                            (Evidently + Grafana)

        Orchestration: Argo Workflows + ArgoCD
        ETL → materialize → train → register, deployed by GitOps
```

The full target pipeline is in [`docs/target-pipeline.excalidraw`](./docs/target-pipeline.excalidraw)
and described in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

### Target stack

| Stage | Component |
| --- | --- |
| Data source | NYC TLC trip data (monthly Parquet) |
| Exploration | Jupyter (JupyterHub) — pandas / DuckDB |
| ETL | PySpark — cleaning + feature engineering |
| Storage | RustFS (S3-compatible), medallion bronze/silver/gold |
| Feature store | Feast — offline + registry, Redis online store |
| Training | Point-in-time join → model training |
| Experiment tracking | MLflow — tracking + model registry |
| Serving | KServe / MLServer — online inference |
| Monitoring | Evidently + Grafana |
| Orchestration | Argo Workflows (pipelines) + ArgoCD (GitOps) |

## Current status

This repo is being built bottom-up. The **infrastructure foundation and GitOps
control plane are in place**; the data/ML pipeline on top is the roadmap.

- ✅ **Proxmox VE 9.2** unattended installs for both hosts (answer files and
  ISO build in this repo, secrets encrypted with sops + age).
- 🔲 Kubernetes on top of Proxmox (the earlier **k3s** setup is retired and
  recoverable from the git tag `k3s`).
- ✅ **Cilium** (eBPF; from the k3s era, to be re-applied) as CNI + LoadBalancer with L2 announcements.
- ✅ **ArgoCD** app-of-apps as the GitOps control plane.
- ✅ **JupyterHub** for the exploration/EDA stage.
- 🔲 RustFS object storage + medallion layers.
- 🔲 PySpark ETL, Feast, MLflow, KServe, Evidently/Grafana.
- 🔲 Argo Workflows pipelines.

## Platform

Two Proxmox VE hosts, reinstalled from scratch with the Proxmox automated
installer:

| Host | Role | Storage |
| --- | --- | --- |
| `beelink` (mini PC) | VMs / LXC | 2x NVMe, ZFS raid1 |
| `nas` | File serving | NVMe system disk (ext4); 4 HDDs in a ZFS raidz1 pool created post-install |

Answer files live in [`packer/proxmox-ve-unnatended`](./packer/proxmox-ve-unnatended).

## Quick start: Proxmox ISO

```sh
mise install                 # install pinned tooling
mise run age-keygen          # create the sops age key (once)
sops packer/proxmox-ve-unnatended/secrets.sops.env   # set the real values
openssl passwd -6            # generates ROOT_PASSWORD_HASHED
mise run pve-validate        # render + validate both answer files
mise run pve-iso -- beelink  # or: nas; output in packer/proxmox-ve-unnatended/build/
```

Download the stock `proxmox-ve_9.2-1.iso` into `packer/proxmox-ve-unnatended/`
first (URL and sha256 are in `.github/workflows/proxmox-iso.yml`). Write the
result to a USB stick, e.g. `sudo dd if=build/proxmox-ve_9.2-1-beelink.iso of=/dev/sdX bs=4M status=progress conv=fsync`.

The prepared ISO embeds the answer file, including the root password hash, in
plaintext: never share or upload it. CI only uses fake secrets and uploads no
artifacts.

## Why "medallion"?

The name is a double entendre, and in this project both meanings are literal. In
New York City, a *medallion* is the official license that authorizes the city's
iconic yellow taxis — the very fleet whose **TLC trip data** feeds this pipeline.
It's also the name of the **medallion architecture** — the bronze/silver/gold
layering pattern used to progressively refine data in a lakehouse, which is
exactly how that taxi data flows through the lab.

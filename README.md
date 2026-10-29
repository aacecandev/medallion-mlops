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

See [`docs/homelab-topology.excalidraw`](./docs/homelab-topology.excalidraw) for
the network and storage layout.

## Step by step: install Proxmox on both hosts

The whole flow is drawn in
[`docs/proxmox-install-flow.excalidraw`](./docs/proxmox-install-flow.excalidraw).
All commands run from the repository root. Paths below are relative to
`packer/proxmox-ve-unnatended/`.

### 1. Install the tooling

```sh
mise install
```

Also needed: `docker` (runs `proxmox-auto-install-assistant`), `sudo`, and
`openssl`.

### 2. Create the sops age key (once per workstation)

```sh
mise run age-keygen
```

The private key stays in `~/.config/sops/age/keys.txt`. Back it up: without it
`secrets.sops.env` cannot be decrypted. A new key must also be added as a
recipient in `.sops.yaml` and the file re-encrypted with `sops updatekeys`.

### 3. Set the real secrets

```sh
openssl passwd -6                                    # prints the root password hash
sops packer/proxmox-ve-unnatended/secrets.sops.env   # set ROOT_PASSWORD_HASHED and MAILTO
```

### 4. Download the stock Proxmox ISO

```sh
cd packer/proxmox-ve-unnatended
curl -fLO https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso
echo "4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c  proxmox-ve_9.2-1.iso" | sha256sum -c -
cd -
```

The URL and checksum are pinned in `.github/workflows/proxmox-iso.yml`.

### 5. Validate both answer files

```sh
mise run pve-validate
```

### 6. Build the prepared ISOs

```sh
mise run pve-iso -- beelink   # mini PC
mise run pve-iso -- nas
```

Output: `build/proxmox-ve_9.2-1-beelink.iso` and `build/proxmox-ve_9.2-1-nas.iso`.

### 7. Write each ISO to a USB stick

Plug in the stick, find its device with `lsblk`, and unmount any mounted
partition. Then:

```sh
mise run pve-usb -- beelink /dev/sdX
mise run pve-usb -- nas /dev/sdY
```

The task only accepts a whole, removable or USB disk with nothing mounted,
asks you to type the device path again before erasing it, and verifies the
written bytes against the ISO. If the host's ISO is not built yet, it runs
step 6 for you first.

### 8. Install

Boot each host from its stick. The installer runs unattended, selects disks
and the NIC from the answer file, and reboots into Proxmox VE. The NAS HDDs are
never touched; their ZFS pool is created after the install.

> **Secrets:** the prepared ISOs (and the sticks) embed the answer file,
> including the root password hash, in plaintext. Never share or upload them,
> and wipe the sticks after installing. CI only uses fake secrets and uploads
> no artifacts.

## Why "medallion"?

The name is a double entendre, and in this project both meanings are literal. In
New York City, a *medallion* is the official license that authorizes the city's
iconic yellow taxis — the very fleet whose **TLC trip data** feeds this pipeline.
It's also the name of the **medallion architecture** — the bronze/silver/gold
layering pattern used to progressively refine data in a lakehouse, which is
exactly how that taxi data flows through the lab.

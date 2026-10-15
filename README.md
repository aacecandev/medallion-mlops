# medallion-mlops

A self-hosted, end-to-end **MLOps lab** built on a single-node **k3s homelab**
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

- ✅ **k3s** with kube-proxy and flannel disabled — Cilium owns the datapath.
- ✅ **Cilium** (eBPF) as CNI + LoadBalancer with L2 announcements.
- ✅ **ArgoCD** app-of-apps as the GitOps control plane.
- ✅ **JupyterHub** for the exploration/EDA stage.
- 🔲 RustFS object storage + medallion layers.
- 🔲 PySpark ETL, Feast, MLflow, KServe, Evidently/Grafana.
- 🔲 Argo Workflows pipelines.

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

The name is a double entendre, and in this project both meanings are literal. In
New York City, a *medallion* is the official license that authorizes the city's
iconic yellow taxis — the very fleet whose **TLC trip data** feeds this pipeline.
It's also the name of the **medallion architecture** — the bronze/silver/gold
layering pattern used to progressively refine data in a lakehouse, which is
exactly how that taxi data flows through the lab.

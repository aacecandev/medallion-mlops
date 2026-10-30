# Feature: proxmox-unattended-install

## Objective

Reinstall both homelab hosts from scratch with Proxmox VE 9.2 using the
automated installer: answer files in the repo, secrets encrypted with
sops+age, ISOs built locally, and a CI check that the build works without
exposing real secrets. k3s is retired (recoverable from tag `k3s`).

## Hosts

| Host | Role | FQDN | IP | OS disk(s) | Data |
|---|---|---|---|---|---|
| Mini PC (Beelink) | VMs / LXC | beelink.home.arpa | 192.168.1.200/24 | 2x NVMe 931.5G, ZFS raid1 | rpool |
| NAS | File serving | nas.home.arpa | 192.168.1.138/24 | 1x NVMe 119G, ext4/LVM | 4x HDD 3.6T raidz1 (post-install, out of scope here) |

Gateway and DNS: 192.168.1.1. Keyboard `es`, country `es`, timezone `Europe/Madrid`.

## Constraints

- Answer files use kebab-case keys (snake_case deprecated in PVE 9.0).
- Installer must never select the NAS HDDs.
- Real secrets (root password hash, mailto) only in `secrets.sops.env`, encrypted with age key `age10zgf…wh68`.
- Prepared ISOs contain secrets in plaintext: never committed, never uploaded as CI artifacts.
- CI uses fake plaintext secrets and uploads no artifacts (public repo).
- Tooling pinned in root `mise.toml`; `proxmox-auto-install-assistant` runs in a container.

## Tasks

- [x] T1 Tooling: root `mise.toml` (age, packer, sops), assistant `Containerfile`, `.sops.yaml`, age key. Route: inline.
- [x] T2 Answer templates, render/build script, mise tasks, encrypted secrets skeleton. Route: delegated writer (2+ non-trivial files).
- [x] T3 CI workflow: validate + prepare-iso with fake secrets, no artifacts. Route: delegated writer (same).
- [x] T4 Retire k3s: remove k3s tool and k3s tasks from `mise.toml`, update README. Tag `k3s` created at 262b2e0. Route: delegated writer (same).

- [x] T5 `pve-usb` mise task (guarded dd + cmp verify) and step-by-step README. Route: inline (one task + docs).

## Acceptance criteria

- `mise run pve-iso -- beelink` and `-- nas` produce prepared ISOs locally once real secrets are set.
- `validate-answer` passes for both rendered answer files.
- CI workflow runs the same script with fake secrets, verifies the official ISO checksum, uploads nothing.
- No plaintext secret or rendered answer file is tracked by git.

## Checks

- `mise run aia -- validate-answer` on both rendered files (fake secrets).
- Full `prepare-iso` run for one host with fake secrets.
- `pre-commit run --all-files` (gitleaks included).

## TDD

Off (no project TDD configuration; infra config, functional checks only).

## Progress / evidence

- T1 done: assistant 9.0.7 runs in container; sops round-trip verified with new key.
- T2-T4 done by one delegated writer. Commits: f137d00 build(proxmox) (T1 + k3s tool/task removal in mise.toml), d897136 feat(proxmox) (T2), dd14e19 ci(proxmox) (T3), b17420c docs (T4 README).
- Evidence: `pve-validate` with CHANGEME refuses; `build-iso.sh {beelink,nas} --validate-only` with fake secrets: valid; full nas build produced a prepared ISO (no inspect subcommand in assistant 9.0.7); `filter` is mandatory in `[network]` (validate-answer fails without it); pre-commit all-files passed; workflow YAML parses.
- Branch `feat/proxmox-unattended-install`; tag `k3s` (local, not pushed).

## Next step

Review, push the branch and `k3s` tag, open PR. Before first real build: set real values with `sops packer/proxmox-ve-unnatended/secrets.sops.env`; narrow the `filter.ID_NET_NAME = "en*"` in both templates to the NIC MAC.

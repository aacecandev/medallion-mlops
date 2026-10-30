# Feature: ansible-host-config

## Objective

Configure both Proxmox VE 9 hosts (Beelink mini PC and NAS) after the
unattended install with Ansible in `ansible/`, porting roles one at a time
from the reference clone in `temp/proxmox-bootstrap` and fixing each on the way.

## Hosts

| Host | Inventory name | IP | OS disk | Notes |
|---|---|---|---|---|
| Mini PC | `beelink` | 192.168.1.200 | 2x NVMe, ZFS raid1 (`rpool`) | VMs / LXC |
| NAS | `nas` | 192.168.1.138 | 1x NVMe, ext4/LVM | 4x HDD, data filesystem undecided |

## Constraints

- Reference clone `temp/proxmox-bootstrap` is read-only reference; never commit it
  (it contains plaintext passwords and personal keys).
- Shared values in `group_vars/all.yml`; per-host values in `host_vars/<host>.yml`
  (auto-loaded by Ansible, no `include_vars`).
- SSH auth via YubiKey key served by gpg-agent (`private_key_file = ~/.ssh/yubikey.pub`); no passwords in vars.
- Secrets, if any are needed, encrypted (repo already uses sops+age).
- PVE 9 / Debian trixie only; no PVE 7/8 branches.
- Roles enabled per host with explicit vars, not hardware guesses.

## Checks

- `ansible-lint` on `ansible/`.
- `ansible-playbook proxmox.yml --check --diff` against both hosts, then a real run.
- TDD: off (no project configuration enables it).

## Delivery

Strategy: `ask-on-risk`. Forecast: well over 400 authored lines across all roles.

## Tasks

- [x] T1 `ansible/requirements.yml` for `ansible.posix` and `community.general`. Route: inline.
- [ ] T2 Base layout + `00_init`: move shared vars to `group_vars/all.yml`, drop `vars_file`/`include_vars`
      and `ansible_ssh_pass`, use facts for CPU vendor. Route: inline.
- [ ] T3+ Port remaining roles one at a time (order agreed with the user), each with per-host values where they differ.

## Progress

- Branch `feat/ansible-host-config` created from `main`.
- `ansible all -m ping` succeeded on both hosts.

## Next step

T1 commit, then T2.

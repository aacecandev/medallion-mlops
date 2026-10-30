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
- [x] T2 Base layout + `00_init`: move shared vars to `group_vars/all.yml`, drop `vars_file`/`include_vars`
      and `ansible_ssh_pass`, use facts for CPU vendor. Route: inline.
- [x] T3 `02_date_timezone`: `community.general.timezone`, NTP pool in `/etc/chrony/sources.d/ntp-pool.sources`
      (Debian layout), reload sources instead of restart; dropped unused offset probe and forced `makestep`.
      Shared values in `group_vars/all.yml`. Route: inline.
- [x] T4 `05_init_sshd`: drop-in `/etc/ssh/sshd_config.d/10-hardening.conf` validated with `sshd -t`,
      reload (not restart), assert effective `sshd -T` values. Policy (user decision): root with keys only
      (`prohibit-password`), password auth off, port 22. Dropped clone's PAM edits (pam_limits/pam_env
      off would break limits and locale), `AddressFamily inet`, and defaults-only lines. Route: inline.
- [ ] T5 `06_configure_users`: user's own admin user (and possibly Proxmox API tokens; scope to agree).
- [ ] T6+ Port remaining roles one at a time (order agreed with the user), each with per-host values where they differ.

## Progress

- Branch `feat/ansible-host-config` created from `main`.
- `ansible all -m ping` succeeded on both hosts.
- T1 committed `9795a00`.
- T2 committed `1fbbfd5`: no shared vars remained, so no `group_vars/all.yml` yet; `host_vars/all.yml`
  (plaintext `changeme`) left untracked for the user to delete. `.ansible-lint` skips `role-name` and
  `var-naming[no-role-prefix]` (numbered roles, shared `global_*` facts). `ansible-lint` passed
  (production profile), `--syntax-check` passed. `--check` on both hosts: all assertions passed;
  facts: both `GenuineIntel`, PVE 9; boot mode beelink `efi` (proxmox-boot-tool), nas `efi-grub`.
- User copied roles 02, 05, 06, 13, 18 into `ansible/roles`; excluded from lint until ported.
- T3: `ansible-lint` passed; `--check --diff` on both hosts: 2 changes each (remove Debian pool line,
  add `es.pool.ntp.org` source), timezone already `Europe/Madrid`. Real run approved: config present on
  both hosts (files dated 02:20, applied just before this session's run, which reported `changed=0`);
  rerun `changed=0`; `chronyc sources` shows `es.pool.ntp.org` servers synced.
- Review assessment `main..HEAD` (untracked excluded): medium, 184 lines, `under_budget`; pending in slice.

- T4: `ansible-lint` passed; `--check --diff`: 2 changes per host (drop-in + reload). Before: both hosts
  `permitrootlogin yes`, `passwordauthentication yes`. Pending: real run (user approval).

## Next step

Real run of `05_init_sshd` once approved (keep a root session open), then `06_configure_users`.

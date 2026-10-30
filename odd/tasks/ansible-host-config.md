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
- Shared values in `group_vars/all.yml`; per-host values in `host_vars/<host>/main.yml`
  (auto-loaded, no `include_vars`). Once `host_vars/<host>/` exists Ansible ignores `host_vars/<host>.yml`.
- SSH auth via YubiKey key served by gpg-agent (`private_key_file = ~/.ssh/yubikey.pub`); no passwords in vars.
- Secrets, if any are needed, encrypted (repo already uses sops+age).
- PVE 9 / Debian trixie only; no PVE 7/8 branches.
- Roles enabled per host with explicit vars, not hardware guesses.

## Checks

- `ansible-lint` on `ansible/`.
- `ansible-playbook proxmox.yml --check --diff` against both hosts, then a real run.
- TDD: off (no project configuration enables it).

## Delivery

Strategy: `ask-on-risk`; chain strategy (user decision): `feature-branch-chain`.
Branches were restructured locally after T5 (commits rebased, so hashes in Progress predate the
chain; content verified identical).

| Slice | Branch | Base | Holds | Size |
|---|---|---|---|---|
| Tracker | `feat/ansible-host-config` | `main` | empty tracker commit; draft, no-merge until chain done | 0 |
| 01 | `feat/ansible-host-config-01-base` | tracker | T1–T4: requirements, `00_init`, `02_date_timezone`, `05_init_sshd` | 245 |
| 02 | `feat/ansible-host-config-02-users` | 01 | T5: sops vars, `06_configure_users`, service users, API tokens | 241 |
| 03 | `feat/ansible-host-config-03-services` | 02 | T6–T8: `13_ksmtuned`, hardening, `18_fail2ban` (#15) | 179 |
| 04 | `feat/ansible-host-config-04-common` | 03 | T9+: tool pinning, common roles | in progress |

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
- [x] T5 `06_configure_users`: admin user `alejandro` (sudo, YubiKey key, PAM realm `Administrator`),
      password hash in sops-encrypted `group_vars/all.sops.yml`; Proxmox API tokens scope to agree.
      Done so far: `community.sops` in requirements, `vars_plugins_enabled` in `ansible.cfg`, `.sops.yaml`
      rule for `ansible/(group|host)_vars/*.sops.y(a)ml`; probe file decrypted via `ansible-inventory`
      (`aeb20be`). User created `group_vars/all.sops.yml` (yescrypt hash). Role rewritten: install `sudo`
      (absent on PVE; Debian sudoers already grants `%sudo` with password), user + hash, exclusive
      `authorized_key` (YubiKey), `pveum` user + `Administrator` ACL on `/` via JSON-checked idempotency.
      Dropped root password change (set at install) and NOPASSWD sudo. `ansible-lint` passed;
      `--check --diff` passed both hosts (3 changes). Real run blocked by the auto-mode classifier
      (admin account creation = permission grant): user ran it (`358f895`); verified on both hosts:
      `alejandro` in `sudo`, `alejandro@pam` `Administrator` on `/`.
      API tokens (user decision): service users `terraform@pve` (`Administrator`, narrow later) and
      `monitoring@pve` (`PVEAuditor`), one privsep token each, ACL on user and token. Tooling decision:
      `pveum`, not `community.proxmox` (2.0.0 installed / 2.1.0 latest: tokens via `proxmox_user`, but
      needs API credentials and `proxmoxer>=2.3`, trixie ships 2.2.0). Secrets saved on creation with
      `community.sops.sops_encrypt` to `host_vars/<host>/pve_tokens.sops.yml` (`pve_token_secrets`);
      assert fails if a token exists without a saved secret. Local probe proved encrypt + per-host
      readback next to `host_vars/<host>.yml`. `ansible-lint` passed; `--check` passed (no-op: command
      tasks skip in check mode). Real run by the user: both hosts have both users, privsep tokens and
      user+token ACLs on `/`; `host_vars/{beelink,nas}/pve_tokens.sops.yml` (0600) decrypt to both
      secrets; each token returns HTTP 200 on `GET /api2/json/version`.
- [x] T6 `13_ksmtuned`: per-host `ksmtuned_enabled` (beelink on, nas off: no VMs), optional
      `ksmtuned_settings` overrides; stock config left alone when empty. Fixed clone bug ("enable" task set
      `enabled: false`). Moved per-host vars to `host_vars/<host>/main.yml`. Route: inline.
- [x] T7 Hardening of the Ansible setup (user-approved items 1-4): host keys pinned in `ansible/known_hosts`
      (fingerprints match each host's own `ssh_host_ed25519_key.pub`), `StrictHostKeyChecking=yes`,
      `IdentitiesOnly=yes`, dropped `host_key_checking = False` and `allow_world_readable_tmpfiles`;
      `temp/` gitignored; roles imported with tags (`always`, `timezone`, `sshd`, `users`, `ksmtuned`).
      Proof: empty known_hosts refused; only the YubiKey key offered; full run `changed=0`. Route: inline.
- [x] T8 `18_fail2ban`: installs fail2ban + python3-systemd, Proxmox filter (journal, pvedaemon), jail file
      in `jail.d/` on top of Debian's sshd defaults, `nftables` banaction (own table, independent of
      pve-firewall), `fail2ban-client --test` before restart. Fixed clone bugs: never installed the package;
      `ignoreregex = .` ignored every line so the proxmox jail could never ban. Vars: bantime 1h, findtime 10m,
      maxretry 5, ignoreip localhost only. Proof: jails `proxmox, sshd` on both hosts, rerun `changed=0`;
      one test login failure on nas counted (`Found 192.168.1.37`, IPv4-normalised). Route: inline.
- [x] T9 Tooling pinned in `mise.toml`: `ansible-core` 2.21.5, `pipx:ansible-lint` 26.10.1 (same as the
      pre-commit hook) with the same `ansible-core` in its venv; `mise run ansible-deps` installs
      `requirements.yml` (mise's ansible-core does not see Debian's bundled collections). Proof: lint passes,
      `--check` on both hosts `changed=0`. Route: inline.
- [ ] T10+ Roles common to both hosts (user scope): candidates from the clone. one at a time (order agreed with the user), each with per-host values where they differ.

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
  `permitrootlogin yes`, `passwordauthentication yes`. Real run (by the user) applied the drop-in on both
  hosts but the verify assert failed: `sshd -T` prints `prohibit-password` as `without-password`. Fixed
  the assert; rerun `changed=0 failed=0`. Effective: `permitrootlogin without-password`,
  `passwordauthentication no`, `kbdinteractiveauthentication no`, `x11forwarding no`.

## Next step

Port `06_configure_users` (admin user; API tokens scope to agree).

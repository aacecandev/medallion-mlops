# Proxmox Golden Image - Ubuntu 24.04

Packer builds an Ubuntu 24.04 cloud-init template on the `beelink` Proxmox
node (`192.168.1.200`). Tool versions are pinned in the repo-root
`mise.toml`; secrets are sops/age-encrypted with the repo-root `.sops.yaml`.

## Layout

| File | Purpose | Committed |
|------|---------|-----------|
| `packer.pkr.hcl` | Source and build; no hardcoded values | yes |
| `variables.pkr.hcl` | Variable declarations only | yes |
| `variables.auto.pkrvars.hcl` | Non-sensitive values (node, storage, IPs, public SSH keys) | yes |
| `secrets.sops.env` | Encrypted `PKR_VAR_*` secrets | yes, encrypted |
| `http/user-data.pkrtpl.yml` | Autoinstall template, rendered in memory via `http_content` | yes |

Secrets in `secrets.sops.env`:

- `PKR_VAR_ssh_password`: build-only password Packer uses to SSH in.
- `PKR_VAR_ssh_password_hash`: SHA-512 crypt hash of that password, for the
  autoinstall identity.

The Proxmox API token is not stored here: ansible role `06_configure_users`
creates `packer@pve!packer` with the least-privilege `Packer` role (see
`pve_custom_roles` and `pve_service_users` in `ansible/group_vars/all.yml`)
and encrypts its secret into
`ansible/host_vars/beelink/pve_tokens.sops.yml`, which `mise run golden-image`
reads.

They reach Packer only as environment variables through `sops exec-env`;
nothing is decrypted to disk. The build password is locked (`passwd -l`) at
the end of the build, so clones only accept the authorized SSH keys.

## Setup

1. Create the `packer@pve` user and its API token on beelink:

   ```bash
   cd ansible && ansible-playbook proxmox.yml --tags users --limit beelink
   ```

2. Download the installer ISO into beelink's `local` ISO storage (role
   `25_upload_isos`, configured by `pve_isos` in
   `ansible/host_vars/beelink/main.yml`):

   ```bash
   cd ansible && ansible-playbook proxmox.yml --tags isos --limit beelink
   ```

To rotate the build password:

```bash
f=images/proxmox-golden-image/secrets.sops.env
pw="$(openssl rand -base64 24 | tr -d '/+=')"
printf %s "$pw" | sops set --value-stdin "$f" '["PKR_VAR_ssh_password"]'
printf %s "$pw" | openssl passwd -6 -stdin | tr -d '\n' | sops set --value-stdin "$f" '["PKR_VAR_ssh_password_hash"]'
```

## Usage

```bash
mise run golden-image-validate   # packer init + validate
mise run golden-image            # validate, then build template 9000
```

The build VM boots with the static IP `vm_ip` (`192.168.1.100`); the Packer
host must reach it over SSH and the VM must reach Packer's HTTP server on
`http_port` (8802) to fetch its user-data. With UFW on the workstation, allow
it once from the LAN:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 8802 proto tcp comment 'Packer HTTP'
```

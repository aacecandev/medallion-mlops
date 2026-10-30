# PROXMOX GOLDEN IMAGE - KNOWLEDGE BASE

Packer builds an Ubuntu 24.04 cloud-init template on the `beelink` Proxmox
node. See `README.md` for setup and usage.

## Conventions

- `packer.pkr.hcl` holds no hardcoded values; `variables.pkr.hcl` holds
  declarations only.
- Non-sensitive values (node, storage, LAN IPs, public SSH keys) go in
  `variables.auto.pkrvars.hcl`.
- The Proxmox API token comes from ansible role `06_configure_users`
  (`ansible/host_vars/beelink/pve_tokens.sops.yml`); never store it here.
- Build secrets go in `secrets.sops.env` as `PKR_VAR_*` keys, encrypted with the
  repo-root `.sops.yaml`. Edit with `sops edit` or `sops set`; never write a
  decrypted copy to disk. Packer does not read sops itself: run it through
  `mise run golden-image` / `golden-image-validate`, which wrap
  `sops exec-env`.
- `http/user-data.pkrtpl.yml` is rendered with `templatefile()` into
  `http_content`; add new values as template variables, not literals.
- No personal identifiers (email, account names) in plaintext files.

## Known gaps

- `files/99-pve.cfg` is not used by the build.
- The ISO comes from ansible role `25_upload_isos` (`pve_isos` in
  `ansible/host_vars/beelink/main.yml`); keep its filename in sync with
  `ubuntu_image`.

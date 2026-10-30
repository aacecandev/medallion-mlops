# Non-sensitive configuration for the beelink Proxmox node.
# Secrets reach Packer as PKR_VAR_* environment variables through
# `mise run golden-image`: the build password from secrets.sops.env, the API
# token from ansible/host_vars/beelink/pve_tokens.sops.yml.

# Proxmox connection
proxmox_url      = "https://192.168.1.200:8006/api2/json"
proxmox_username = "packer@pve!packer" # created by ansible role 06_configure_users

# Proxmox infrastructure (beelink: ZFS install, so disks go to local-zfs)
proxmox_node              = "beelink"
proxmox_iso_pool          = "local"
proxmox_storage_pool      = "local-zfs"
proxmox_storage_format    = "raw"
proxmox_storage_pool_type = "zfs"

# Template
template_name        = "ubuntu-2404-template"
template_description = "Ubuntu 24.04 golden image"
ubuntu_image         = "ubuntu-24.04.3-live-server-amd64.iso"
vm_id                = 9000

# Build VM network (static, only used while Packer provisions the VM)
vm_ip      = "192.168.1.100"
vm_prefix  = 24
vm_gateway = "192.168.1.1"
vm_dns     = ["192.168.1.1", "8.8.8.8"]

# SSH
ssh_username = "ubuntu"
ssh_authorized_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDKwFgVMjJtsFt0vn0AM9Q10RJkgByxevhJY9kRQyH9U cardno:32_247_877",
]

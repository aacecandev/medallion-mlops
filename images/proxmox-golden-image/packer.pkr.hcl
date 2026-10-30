packer {
  required_plugins {
    proxmox = {
      version = "1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu-2404" {
  # PACKER Boot Commands
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  boot      = var.boot_mode
  boot_wait = var.boot_wait

  boot_iso {
    iso_file         = "${var.proxmox_iso_pool}:iso/${var.ubuntu_image}"
    iso_storage_pool = var.proxmox_iso_pool
    unmount          = true
  }

  # VM System Settings
  qemu_agent = var.vm_qemu_agent

  # VM Cloud-Init Settings
  cloud_init              = var.vm_cloud_init
  cloud_init_storage_pool = var.proxmox_storage_pool

  # VM Hardware Configuration
  cores = var.vm_cores

  disks {
    disk_size    = var.vm_disk_size
    format       = var.proxmox_storage_format
    storage_pool = var.proxmox_storage_pool
    type         = var.vm_disk_type
  }

  # Rendered in memory so the password hash is never written to disk.
  http_content = {
    "/meta-data" = ""
    "/user-data" = templatefile("${path.root}/http/user-data.pkrtpl.yml", {
      username        = var.ssh_username
      password_hash   = var.ssh_password_hash
      authorized_keys = var.ssh_authorized_keys
      vm_ip           = var.vm_ip
      vm_prefix       = var.vm_prefix
      vm_gateway      = var.vm_gateway
      vm_dns          = var.vm_dns
    })
  }
  # Fixed port so the workstation firewall can allow the VM to fetch user-data.
  http_port_min            = var.http_port
  http_port_max            = var.http_port
  insecure_skip_tls_verify = var.insecure_skip_tls_verify
  memory                   = var.vm_memory

  network_adapters {
    model    = var.vm_network_model
    bridge   = var.vm_network_bridge
    firewall = var.vm_network_firewall
  }

  node                 = var.proxmox_node
  vm_id                = var.vm_id
  os                   = var.vm_os
  token                = var.proxmox_token
  proxmox_url          = var.proxmox_url
  scsi_controller      = var.vm_scsi_controller
  ssh_password         = var.ssh_password
  ssh_port             = var.ssh_port
  ssh_timeout          = var.ssh_timeout
  ssh_username         = var.ssh_username
  ssh_host             = var.vm_ip
  template_description = var.template_description
  template_name        = var.template_name
  username             = var.proxmox_username
}

build {
  sources = ["source.proxmox-iso.ubuntu-2404"]

  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg",
      "sudo cloud-init clean",
      # Lock (not delete) the build password: -d would leave an empty,
      # usable password on the console of every clone.
      "sudo passwd -l ${var.ssh_username}"
    ]
  }
}

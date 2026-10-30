# Proxmox Connection Variables
variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API username"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

# Proxmox Infrastructure Variables
variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

variable "proxmox_iso_pool" {
  type        = string
  description = "Storage pool for ISO files"
}

variable "proxmox_storage_pool" {
  type        = string
  description = "Storage pool for VM disks"
}

variable "proxmox_storage_format" {
  type        = string
  description = "Disk format (raw, qcow2, etc.)"
}

variable "proxmox_storage_pool_type" {
  type        = string
  description = "Storage pool type"
}

# Template Variables
variable "template_name" {
  type        = string
  description = "Name of the template"
}

variable "template_description" {
  type        = string
  description = "Description of the template"
}

variable "ubuntu_image" {
  type        = string
  description = "Ubuntu ISO image filename"
}

variable "version" {
  type        = string
  description = "Template version"
  default     = ""
}

variable "vm_id" {
  type        = number
  description = "VM ID for the template"
}

# VM Hardware Configuration
variable "vm_cores" {
  type        = string
  description = "Number of CPU cores"
  default     = "2"
}

variable "vm_memory" {
  type        = string
  description = "Amount of memory in MB"
  default     = "2048"
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
  default     = "8G"
}

variable "vm_os" {
  type        = string
  description = "Operating system type"
  default     = "l26"
}

variable "vm_scsi_controller" {
  type        = string
  description = "SCSI controller type"
  default     = "virtio-scsi-single"
}

variable "vm_disk_type" {
  type        = string
  description = "Disk type"
  default     = "scsi"
}

# VM Network Configuration
variable "vm_network_model" {
  type        = string
  description = "Network adapter model"
  default     = "virtio"
}

variable "vm_network_bridge" {
  type        = string
  description = "Network bridge"
  default     = "vmbr0"
}

variable "vm_network_firewall" {
  type        = bool
  description = "Enable firewall on network adapter"
  default     = false
}

variable "vm_ip" {
  type        = string
  description = "Static IP of the build VM; Packer connects to it over SSH"
}

variable "vm_prefix" {
  type        = number
  description = "Network prefix length of vm_ip"
  default     = 24
}

variable "vm_gateway" {
  type        = string
  description = "Default gateway of the build VM"
}

variable "vm_dns" {
  type        = list(string)
  description = "DNS servers of the build VM"
}

# VM Features
variable "vm_qemu_agent" {
  type        = bool
  description = "Enable QEMU guest agent"
  default     = true
}

variable "vm_cloud_init" {
  type        = bool
  description = "Enable Cloud-Init"
  default     = true
}

# Boot Configuration
variable "boot_wait" {
  type        = string
  description = "Time to wait before typing boot command"
  default     = "5s"
}

variable "boot_mode" {
  type        = string
  description = "Boot mode"
  default     = "c"
}

# SSH Configuration
variable "ssh_username" {
  type        = string
  description = "SSH username"
}

variable "ssh_password" {
  type        = string
  description = "SSH password"
  sensitive   = true
}

variable "ssh_password_hash" {
  type        = string
  description = "SHA-512 crypt hash of ssh_password, written to the autoinstall identity"
  sensitive   = true
}

variable "ssh_authorized_keys" {
  type        = list(string)
  description = "Public SSH keys authorized for ssh_username"
}

variable "ssh_port" {
  type        = number
  description = "SSH port"
  default     = 22
}

variable "ssh_timeout" {
  type        = string
  description = "SSH timeout"
  default     = "30m"
}

# Packer Configuration
variable "http_port" {
  type        = number
  description = "Port of Packer's HTTP server that serves user-data to the build VM"
  default     = 8802
}

variable "insecure_skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification"
  default     = true
}

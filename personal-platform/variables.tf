variable "hcloud_token" {
  description = "Hetzner Cloud API token."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name used for resource names."
  type        = string
  default     = "personal-platform"
}

variable "server_name" {
  description = "Hetzner server name."
  type        = string
  default     = "personal-platform-control-plane"
}

variable "server_type" {
  description = "Hetzner server type. Start with an 8 GB RAM class for Coder and Docker workloads."
  type        = string
  default     = "cx33"
}

variable "server_location" {
  description = "Hetzner location. Use a nearby region after latency and price review."
  type        = string
  default     = "fsn1"
}

variable "server_image" {
  description = "Base OS image."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key, relative to this Terraform module."
  type        = string
  default     = "ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to access public SSH during bootstrap. Set to [] after WireGuard access is confirmed."
  type        = list(string)
  default     = []
}

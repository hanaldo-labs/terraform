variable "instance_type" {
  type        = string
  default     = "t4g.nano"
  description = "EC2 instance type for WireGuard server."
}

variable "server_port" {
  type        = number
  default     = 51820
  description = "WireGuard UDP port."
}

variable "ui_port" {
  type        = number
  default     = 51821
  description = "wg-easy Web UI TCP port."
}

variable "init_username" {
  type        = string
  default     = "admin"
  description = "Initial wg-easy admin username."
}

variable "init_password" {
  type        = string
  sensitive   = true
  description = "Initial wg-easy admin password."
}

variable "wireguard_ipv4_cidr" {
  type        = string
  default     = "10.100.100.0/24"
  description = "IPv4 CIDR used for WireGuard clients."
}

variable "wireguard_ipv6_cidr" {
  type        = string
  default     = "fdcc:ad94:bacf:61a3::/64"
  description = "IPv6 CIDR required by wg-easy unattended setup."
}

variable "wireguard_dns" {
  type        = string
  default     = "1.1.1.1"
  description = "DNS servers assigned to WireGuard clients."
}

variable "additional_wireguard_allowed_ips" {
  type        = list(string)
  default     = []
  description = "Additional CIDR blocks assigned to WireGuard clients."
}

variable "enable_private_nat_route" {
  type        = bool
  default     = true
  description = "Whether to route private subnet default traffic through the WireGuard EC2 instance."
}

variable "log_group_name" {
  type        = string
  default     = "/wireguard-server/wg-easy"
  description = "CloudWatch Logs group name for wg-easy container logs."
}

variable "log_retention_in_days" {
  type        = number
  default     = 30
  description = "Retention days for wg-easy CloudWatch Logs."
}

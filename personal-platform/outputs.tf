output "server_ipv4" {
  description = "Public IPv4 address of the platform VM."
  value       = hcloud_server.main.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address of the platform VM."
  value       = hcloud_server.main.ipv6_address
}


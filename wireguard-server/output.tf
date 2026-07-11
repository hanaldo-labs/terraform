output "wireguard_server_public_ip" {
  value = aws_eip.wireguard_server.public_ip
}

output "wireguard_ui_url" {
  value = "http://${cidrhost(var.wireguard_ipv4_cidr, 1)}:${var.ui_port}"
}

output "wireguard_server_instance_id" {
  value = aws_instance.wireguard_server.id
}

output "wireguard_ui_bootstrap_command" {
  value = "aws ssm start-session --target ${aws_instance.wireguard_server.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=${var.ui_port},localPortNumber=${var.ui_port}"
}

output "wg_easy_log_group_name" {
  value = aws_cloudwatch_log_group.wg_easy.name
}

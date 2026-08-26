locals {
  common_labels = {
    project = var.project_name
  }
}

resource "hcloud_ssh_key" "main" {
  name       = "${var.project_name}-admin"
  public_key = file("${path.module}/${var.ssh_public_key_path}")
  labels     = local.common_labels
}

resource "hcloud_firewall" "main" {
  name   = "${var.project_name}-firewall"
  labels = local.common_labels

  dynamic "rule" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []

    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "22"
      source_ips = var.allowed_ssh_cidrs
    }
  }
}

resource "hcloud_server" "main" {
  name         = var.server_name
  image        = var.server_image
  server_type  = var.server_type
  location     = var.server_location
  ssh_keys     = [hcloud_ssh_key.main.id]
  firewall_ids = [hcloud_firewall.main.id]
  user_data    = file("${path.module}/user-data.yaml")
  labels       = local.common_labels

  lifecycle {
    ignore_changes = [user_data]
  }
}

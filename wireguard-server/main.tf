terraform {
  # Save tfstate file as 'wireguard-server' key in S3 bucket
  backend "s3" {
    bucket = "hanaldo-terraform"
    key    = "wireguard-server"
    region = "ap-northeast-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.51.1"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "aws_common" {
  backend = "s3"

  config = {
    bucket = "hanaldo-terraform"
    key    = "aws-common"
    region = "ap-northeast-2"
  }
}

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "common" {
  id = data.terraform_remote_state.aws_common.outputs.vpc_id
}

resource "aws_cloudwatch_log_group" "wg_easy" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_in_days

  tags = {
    Name = "wireguard-server-wg-easy-logs"
  }
}

resource "aws_eip" "wireguard_server" {
  domain = "vpc"

  tags = {
    Name = "wireguard-server-eip"
  }
}

resource "aws_security_group" "wireguard_server" {
  name        = "wireguard-server-sg"
  description = "Security group for WireGuard EC2 server"
  vpc_id      = data.terraform_remote_state.aws_common.outputs.vpc_id

  ingress {
    description = "WireGuard"
    protocol    = "udp"
    from_port   = var.server_port
    to_port     = var.server_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wireguard-server-sg"
  }
}

resource "aws_iam_role" "wireguard_server" {
  name = "wireguard-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "wireguard_server_ssm" {
  role       = aws_iam_role.wireguard_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "wireguard_server_logs" {
  name = "wireguard-server-logs"
  role = aws_iam_role.wireguard_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.wg_easy.arn}:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "wireguard_server" {
  name = "wireguard-server-profile"
  role = aws_iam_role.wireguard_server.name
}

resource "aws_instance" "wireguard_server" {
  ami                         = data.aws_ami.al2023_arm64.id
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.aws_common.outputs.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.wireguard_server.id]
  iam_instance_profile        = aws_iam_instance_profile.wireguard_server.name
  key_name                    = "common-key"
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/init.sh", {
    docker_compose = templatefile("${path.module}/templates/docker-compose.yml", {
      init_host           = aws_eip.wireguard_server.public_ip
      init_password       = var.init_password
      init_username       = var.init_username
      init_allowed_ips    = join(",", concat([data.aws_vpc.common.cidr_block, var.wireguard_ipv4_cidr], var.additional_wireguard_allowed_ips))
      log_group_name      = aws_cloudwatch_log_group.wg_easy.name
      region              = "ap-northeast-2"
      server_port         = var.server_port
      ui_port             = var.ui_port
      wireguard_dns       = var.wireguard_dns
      wireguard_ipv4_cidr = var.wireguard_ipv4_cidr
      wireguard_ipv6_cidr = var.wireguard_ipv6_cidr
    })
    vpc_cidr            = data.aws_vpc.common.cidr_block
    wireguard_ipv4_cidr = var.wireguard_ipv4_cidr
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "wireguard-server"
  }
}

resource "aws_eip_association" "wireguard_server" {
  instance_id   = aws_instance.wireguard_server.id
  allocation_id = aws_eip.wireguard_server.id
}

resource "aws_route" "private_default_via_wireguard" {
  count = var.enable_private_nat_route ? 1 : 0

  route_table_id         = data.terraform_remote_state.aws_common.outputs.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.wireguard_server.primary_network_interface_id
}

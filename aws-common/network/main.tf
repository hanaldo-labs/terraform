/*
 * Data
 */

data "aws_region" "current" {}

data "aws_availability_zones" "current" {
  filter {
    name   = "region-name"
    values = [data.aws_region.current.name]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


/*
 * Resource
 */

resource "aws_vpc" "current" {
  cidr_block = var.cidr

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-vpc"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.current.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-public-subnet-${each.key}"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.current.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-private-subnet-${each.key}"
  })
}

resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.current.id

  # Allow access for SSH from public
  dynamic "ingress" {
    for_each = { for i, v in var.public_access_allowed_cidrs : i => v }

    content {
      rule_no    = 100 + tonumber(ingress.key)
      action     = "allow"
      protocol   = "tcp"
      from_port  = 22
      to_port    = 22
      cidr_block = ingress.value
    }
  }

  # Allow respond from internet or internal
  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 210
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 220
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 230
    action     = "allow"
    protocol   = "udp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 240
    action     = "allow"
    protocol   = "udp"
    from_port  = 53
    to_port    = 53
    cidr_block = var.cidr
  }

  ingress {
    rule_no    = 250
    action     = "allow"
    protocol   = "tcp"
    from_port  = 53
    to_port    = 53
    cidr_block = var.cidr
  }

  ingress {
    rule_no    = 260
    action     = "allow"
    protocol   = "udp"
    from_port  = 51820
    to_port    = 51820
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  # To respond for inbound to internet or internal
  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  # Allow SSH to Instance in private subnet
  egress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_block = var.cidr
  }

  egress {
    rule_no    = 140
    action     = "allow"
    protocol   = "udp"
    from_port  = 53
    to_port    = 53
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 150
    action     = "allow"
    protocol   = "tcp"
    from_port  = 53
    to_port    = 53
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 160
    action     = "allow"
    protocol   = "udp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = var.cidr
  }

  egress {
    rule_no    = 170
    action     = "allow"
    protocol   = "udp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-public-subnet-nacl"
  })
}

resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.current.id

  # Allow respond from internet or internal
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  # Allow SSH from public subnet
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_block = var.cidr
  }

  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "udp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  # Access to K8s API Server
  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 6443
    to_port    = 6443
    cidr_block = var.cidr
  }

  # To respond for inbound to internet or internal
  egress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 140
    action     = "allow"
    protocol   = "udp"
    from_port  = 53
    to_port    = 53
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 150
    action     = "allow"
    protocol   = "tcp"
    from_port  = 53
    to_port    = 53
    cidr_block = "0.0.0.0/0"
  }

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-private-subnet-nacl"
  })
}

resource "aws_network_acl_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.public.id
}

resource "aws_network_acl_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.private.id
}

resource "aws_internet_gateway" "cluster" {
  vpc_id = aws_vpc.current.id

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-IGW"
  })
}

resource "aws_security_group" "nat" {
  vpc_id = aws_vpc.current.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.public_access_allowed_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [var.cidr]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.cidr]
  }

  ingress {
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [var.cidr]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [var.cidr]
  }

  egress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.cidr]
  }

  egress {
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-nat-sg"
  })
}

resource "aws_instance" "nat" {
  count = var.create_nat == true ? 1 : 0

  instance_type = local.nat_instance_type
  ami           = data.aws_ami.ubuntu.id
  key_name      = var.key_pair_name

  subnet_id              = aws_subnet.public["0"].id
  vpc_security_group_ids = [aws_security_group.nat.id]

  source_dest_check = false
  user_data_base64 = base64encode(templatefile("${path.module}/config/cloud-init.nat.yaml", {
    VPC_CIDR = var.cidr
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-nat-instance"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.current.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster.id
  }

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-public-route-table"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.current.id

  dynamic "route" {
    for_each = var.create_nat ? [aws_instance.nat[0].primary_network_interface_id] : []

    content {
      cidr_block           = "0.0.0.0/0"
      network_interface_id = route.value
    }
  }

  tags = merge(local.default_tags, {
    "Name" : "${var.name}-private-route-table"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

terraform {
  # Save tfstate file as 'k8s-cluster' key in S3 bucket
  backend "s3" {
    bucket = "hanaldo-terraform"
    key    = "aws-common"
    region = "ap-northeast-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.51.1"
    }
  }
}

provider "aws" {}


/*
 * SSH Key Pair
 */

resource "aws_key_pair" "common" {
  key_name   = "common-key"
  public_key = file("${path.module}/ssh/id_rsa.pub")
}


/*
 * IAM Role for EKS Cluster and Worker Node
 */

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node" {
  name = "eks-node-role"
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

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


/*
 * Hosted Zone for personal domain
 */

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 3.0"

  zones = {
    for domain in var.domains : domain => {
      comment = "Zones for ${domain}"
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}


/*
 * Common VPC
 */


module "network" {
  source = "./network"

  name                        = var.vpc-name
  cidr                        = var.vpc_cidr
  public_access_allowed_cidrs = var.public_access_allowed_cidrs
  key_pair_name               = aws_key_pair.common.key_name
  create_nat                  = var.create_nat
}

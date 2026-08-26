terraform {
  # Save tfstate file as 'k8s-cluster' key in S3 bucket
  backend "s3" {
    bucket = "hanaldo-terraform"
    key    = "aws-route53-record"
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
 * Read remote state to get Route53 Hosted Zone
 */

data "terraform_remote_state" "aws_common" {
  backend = "s3"
  config = {
    bucket = "hanaldo-terraform"
    key    = "aws-common"
    region = "ap-northeast-2"
  }
}


/*
 * Record for personal domain
 */


module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 3.0"

  for_each = var.domains

  zone_id = data.terraform_remote_state.aws_common.outputs.zones.route53_zone_zone_id[each.key]

  records = [
    for v in each.value : v
  ]
}
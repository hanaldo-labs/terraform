variable "domains" {
  type = list(string)

  default = []
}

variable "vpc-name" {
  type        = string
  description = "Common vpc's name"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block used for Common VPC. EX) 10.0.0.0/16"
}

variable "public_access_allowed_cidrs" {
  type = list(string)
}

variable "create_nat" {
  type = bool
}
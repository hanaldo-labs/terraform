locals {
  default_tags = {
    "Cluster" : var.name
  }

  subnet_netbits = 8

  public_subnets = {
    for index in range(var.public_subnet_count) : tostring(index) => {
      availability_zone = data.aws_availability_zones.current.names[index]
      cidr_block        = cidrsubnet(var.cidr, local.subnet_netbits, index)
    }
  }

  private_subnets = {
    for index in range(var.private_subnet_count) : tostring(index) => {
      availability_zone = data.aws_availability_zones.current.names[index]
      cidr_block        = cidrsubnet(var.cidr, local.subnet_netbits, var.public_subnet_count + index)
    }
  }

  /*
   * Instance
   */

  nat_instance_type = "t3.micro"
}

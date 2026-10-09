data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  # 2 AZs
  public_subnets  = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i)]       # 10.0.0.0/24, 10.0.1.0/24
  private_subnets = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i + 10)]  # 10.0.10.0/24, 10.0.11.0/24

  # One shared NAT gateway for both private subnets (saves money, but single point of failure)
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags the AWS Load Balancer Controller expects for Kubernetes service type=LoadBalancer to work
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

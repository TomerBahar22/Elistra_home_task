# Network created by infra/core: VPC and subnets (already tagged for load balancers)
data "terraform_remote_state" "core" {
  backend = "s3"

  config = {
    bucket  = "elisra-tfstate-tomer-bahar"
    key     = "core/terraform.tfstate"
    region  = "eu-north-1"
    profile = "default"
  }
}

# Public IP of the machine running Terraform - the only address
# allowed to reach the EKS API endpoint.
data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

# Existing public hosted zone; ExternalDNS writes the app's records here
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

locals {
  vpc_id          = data.terraform_remote_state.core.outputs.vpc_id
  private_subnets = data.terraform_remote_state.core.outputs.private_subnets
  admin_cidr      = "${chomp(data.http.my_ip.response_body)}/32"
}

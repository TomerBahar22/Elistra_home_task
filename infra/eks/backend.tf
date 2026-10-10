# Same bucket as infra/core, separate key: EKS can be destroyed
# on its own without touching the network or Jenkins.
terraform {
  backend "s3" {
    bucket       = "elisra-tfstate-tomer-bahar"
    key          = "eks/terraform.tfstate"
    region       = "eu-north-1"
    profile      = "default"
    encrypt      = true
    use_lockfile = true
  }
}

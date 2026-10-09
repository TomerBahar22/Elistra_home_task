terraform {
  backend "s3" {
    bucket       = "elisra-tfstate-tomer-bahar"
    key          = "core/terraform.tfstate"
    region       = "eu-north-1"
    profile      = "default"
    encrypt      = true
    use_lockfile = true
  }
}

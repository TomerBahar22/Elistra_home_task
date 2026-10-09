variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "aws_profile" {
  description = "Local AWS CLI profile used for authentication"
  type        = string
}

variable "project_name" {
  description = "Prefix used for resource names"
  type        = string
  default     = "elisra"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "controller_instance_type" {
  description = "Instance type for the Jenkins controller"
  type        = string
  default     = "t3.small"
}

variable "jenkins_home_volume_size" {
  description = "Size in GB of the EBS volume holding jenkins_home"
  type        = number
  default     = 20
}

variable "agent_ssh_public_key_path" {
  description = "Public key placed on agents; the Jenkins controller holds the private key"
  type        = string
}

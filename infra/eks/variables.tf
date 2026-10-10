variable "aws_region" {
  description = "AWS region (must match infra/core)"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used for authentication"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Prefix used for resource names"
  type        = string
  default     = "elisra"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "elisra-eks"
}

variable "kubernetes_version" {
  description = "EKS control plane version"
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "Instance types for the node group. Several types = several spot capacity pools."
  type        = list(string)
  default     = ["t3.large", "m5.large", "m6i.large", "c5.large"]
}

variable "node_capacity_type" {
  description = "SPOT (cheap, can be reclaimed) or ON_DEMAND"
  type        = string
  default     = "SPOT"
}

variable "lbc_chart_version" {
  description = "aws-load-balancer-controller Helm chart version"
  type        = string
  default     = "3.6.0"
}

variable "domain_name" {
  description = "Existing public Route 53 hosted zone, e.g. example.com"
  type        = string
}

variable "external_dns_chart_version" {
  description = "ExternalDNS Helm chart version"
  type        = string
  default     = "1.23.0"
}

variable "keda_chart_version" {
  description = "KEDA Helm chart version"
  type        = string
  default     = "2.21.0"
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Run locally to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "admin_cidr" {
  description = "The only address allowed to reach the EKS API (re-apply if your IP changes)"
  value       = local.admin_cidr
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Use one of these as subnet_id for the Packer build"
  value       = module.vpc.public_subnets
}

output "controller_instance_id" {
  value = module.jenkins_controller.id
}

output "jenkins_ui_command" {
  description = "Run locally, then open http://localhost:8080"
  value       = "aws ssm start-session --profile ${var.aws_profile} --region ${var.aws_region} --target ${module.jenkins_controller.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=8080,localPortNumber=8080"
}

# Values to enter in Jenkins: Manage Jenkins -> Clouds -> Amazon EC2
output "ec2_plugin_settings" {
  value = {
    region               = var.aws_region
    subnet_id            = module.vpc.private_subnets[0]
    security_group       = aws_security_group.jenkins_agent.name
    key_pair_name        = aws_key_pair.jenkins_agent.key_name
    iam_instance_profile = aws_iam_instance_profile.jenkins_agent.arn
    remote_user          = "ubuntu"
  }
}

# Security group the EC2 plugin attaches to every agent
resource "aws_security_group" "jenkins_agent" {
  name        = "${var.project_name}-jenkins-agent"
  description = "Jenkins agents - SSH from controller only"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-jenkins-agent"
  }
}

resource "aws_vpc_security_group_ingress_rule" "agent_ssh_from_controller" {
  security_group_id            = aws_security_group.jenkins_agent.id
  description                  = "SSH from Jenkins controller"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = module.jenkins_controller.security_group_id
}

resource "aws_vpc_security_group_egress_rule" "agent_all_outbound" {
  security_group_id = aws_security_group.jenkins_agent.id
  description       = "Outbound via NAT (GitHub, Docker Hub, packages)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Key pair: AWS puts the public key on each agent at launch;
# the matching private key goes into Jenkins Credentials.
resource "aws_key_pair" "jenkins_agent" {
  key_name   = "${var.project_name}-jenkins-agent"
  public_key = trimspace(file(pathexpand(var.agent_ssh_public_key_path)))
}

# IAM role for agents (SSM access for debugging, nothing else)
resource "aws_iam_role" "jenkins_agent" {
  name = "${var.project_name}-jenkins-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "agent_ssm" {
  role       = aws_iam_role.jenkins_agent.name
  policy_arn = local.ssm_policy
}

resource "aws_iam_instance_profile" "jenkins_agent" {
  name = "${var.project_name}-jenkins-agent"
  role = aws_iam_role.jenkins_agent.name
}

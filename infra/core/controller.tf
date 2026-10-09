locals {
  # Canonical's public SSM parameter for the latest Ubuntu 24.04 AMI
  ubuntu_ami_ssm = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"

  # Lets instances register with Systems Manager (SSM) - no SSH/VPN needed
  ssm_policy = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

  controller_subnet_id = module.vpc.private_subnets[0]
  controller_az        = module.vpc.azs[0]
}

# ---------------------------------------------------------------------------
# Jenkins controller
# ---------------------------------------------------------------------------
module "jenkins_controller" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.4"

  name          = "${var.project_name}-jenkins-controller"
  instance_type = var.controller_instance_type
  subnet_id     = local.controller_subnet_id

  ami_ssm_parameter  = local.ubuntu_ami_ssm
  ignore_ami_changes = true

  user_data                   = file("${path.module}/user_data/controller.sh")
  user_data_replace_on_change = true # safe: Jenkins data lives on the separate EBS volume

  create_iam_instance_profile = true
  iam_role_policies           = { SSM = local.ssm_policy }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  security_group_vpc_id        = module.vpc.vpc_id
  security_group_description   = "Jenkins controller - no inbound, outbound only"
  security_group_ingress_rules = null

  root_block_device = {
    size      = 20
    type      = "gp3"
    encrypted = true
  }
}

# ---------------------------------------------------------------------------
# jenkins_home on its own EBS volume, so credentials, cloud config, plugins
# and build history survive replacing the instance.
# ---------------------------------------------------------------------------
resource "aws_ebs_volume" "jenkins_home" {
  availability_zone = local.controller_az
  size              = var.jenkins_home_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-jenkins-home"
  }

  lifecycle {
    prevent_destroy = true 
  }
}

resource "aws_volume_attachment" "jenkins_home" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.jenkins_home.id
  instance_id                    = module.jenkins_controller.id
  stop_instance_before_detaching = true # clean unmount when the instance is replaced
}

# ---------------------------------------------------------------------------
# Permissions for the Jenkins "Amazon EC2" plugin to launch and terminate
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "controller_ec2_plugin" {
  name = "jenkins-ec2-plugin"
  role = module.jenkins_controller.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageAgents"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeSpotInstanceRequests",
          "ec2:DescribeSpotPriceHistory",
          "ec2:RunInstances",
          "ec2:RequestSpotInstances",
          "ec2:CancelSpotInstanceRequests",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          "ec2:GetConsoleOutput",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "*"
      },
      {
        Sid      = "PassAgentRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.jenkins_agent.arn
      }
    ]
  })
}

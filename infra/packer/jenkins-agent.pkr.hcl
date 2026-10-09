#   packer init .
#   packer build -var-file=agent.pkrvars.hcl .

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type    = string
  default = "default"
}

variable "subnet_id" {
  description = "A PUBLIC subnet (terraform output public_subnets) - Packer needs to SSH into the build instance"
  type        = string
}

variable "project_name" {
  type    = string
  default = "elisra"
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "jenkins_agent" {
  region  = var.aws_region
  profile = var.aws_profile

  # Latest official Ubuntu 24.04 from Canonical
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  ssh_username                = "ubuntu"

  # Temporary security group open only to the IP running Packer
  temporary_security_group_source_public_ip = true

  ami_name        = "${var.project_name}-jenkins-agent-${local.timestamp}"
  ami_description = "Jenkins agent: Ubuntu 24.04, Java 21, Git, Docker + Compose"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-jenkins-agent"
    Project   = var.project_name
    Role      = "jenkins-agent"
    BaseAMI   = "{{ .SourceAMI }}"
    ManagedBy = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.jenkins_agent"]

  provisioner "shell" {
    script          = "${path.root}/scripts/install-agent.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  # Writes the new AMI ID to manifest.json
  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
  }
}

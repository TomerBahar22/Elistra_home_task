#!/bin/bash
# Runs ONCE during the Packer build, baked into the AMI.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Wait until first-boot setup finishes (otherwise apt may be locked)
cloud-init status --wait || true

apt-get update
apt-get upgrade -y
apt-get install -y openjdk-21-jre-headless git curl   # Java: the Jenkins agent process

curl -fsSL https://get.docker.com | sh                # Docker + Compose plugin
systemctl enable docker

# The EC2 plugin connects as 'ubuntu' (AWS injects the key pair for this user)
usermod -aG docker ubuntu

apt-get clean
rm -rf /var/lib/apt/lists/*

# Remove Packer's temporary SSH key from the image; each agent gets
# the real key pair injected by cloud-init at launch.
rm -f /home/ubuntu/.ssh/authorized_keys

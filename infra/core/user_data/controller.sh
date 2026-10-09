#!/bin/bash
# Jenkins controller bootstrap:
#   1. mount the separate EBS data volume (format it only the first time)
#   2. install Docker
#   3. run Jenkins with jenkins_home on the data volume
set -euxo pipefail

DATA_LABEL="jenkins-data"
DATA_MOUNT="/var/jenkins-data"

# --- 1. Find the data disk: the disk that is not the root disk -------------
# On Nitro instances (t3) EBS volumes appear as /dev/nvmeXn1, not /dev/sdf.
# The volume is attached after the instance starts, so wait for it.
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
DATA_DISK=""
for _ in $(seq 1 60); do
  DATA_DISK=$(lsblk -dpno NAME,TYPE | awk '$2 == "disk" {print $1}' | grep -v "/dev/$ROOT_DISK$" | head -n1 || true)
  [ -n "$DATA_DISK" ] && break
  sleep 5
done
[ -n "$DATA_DISK" ] || { echo "Data volume not attached"; exit 1; }

# Format ONLY if it has no filesystem yet - never wipe existing Jenkins data
if ! blkid "$DATA_DISK"; then
  mkfs.ext4 -L "$DATA_LABEL" "$DATA_DISK"
fi

mkdir -p "$DATA_MOUNT"
grep -q "LABEL=$DATA_LABEL" /etc/fstab || \
  echo "LABEL=$DATA_LABEL $DATA_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
mount -a

mkdir -p "$DATA_MOUNT/jenkins_home"
chown 1000:1000 "$DATA_MOUNT/jenkins_home"   # uid of the jenkins user in the image

# --- 2. Docker ----------------------------------------------------------------
curl -fsSL https://get.docker.com | sh

# --- 3. Jenkins ---------------------------------------------------------------
# Bound to 127.0.0.1: only reachable from the instance itself,
# which is exactly where SSM port forwarding connects.
docker run -d --name jenkins --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  -v "$DATA_MOUNT/jenkins_home":/var/jenkins_home \
  jenkins/jenkins:lts-jdk21

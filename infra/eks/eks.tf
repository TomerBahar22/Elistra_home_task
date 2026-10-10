module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # API endpoint: public but only from my IP (for kubectl / Terraform);
  # nodes use the private endpoint inside the VPC.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = [local.admin_cidr]
  endpoint_private_access      = true

  # Whoever runs 'terraform apply' becomes cluster admin
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnets
  control_plane_subnet_ids = local.private_subnets

  addons = {
    # Networking add-ons must exist before the nodes join
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    kube-proxy = {
      most_recent    = true
      before_compute = true
    }
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }
    coredns = {
      most_recent = true
    }

    # Persistent volumes (RabbitMQ stores queued messages on disk).
    # Also creates a default gp3 StorageClass, since EKS no longer
    # marks one as default.
    aws-ebs-csi-driver = {
      most_recent = true
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
      configuration_values = jsonencode({
        defaultStorageClass = { enabled = true }
      })
    }
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
    }
  }
}

# EKS add-ons installed via Helm charts, with IAM permissions via EKS Pod Identity.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.aws_region
    vpcId       = local.vpc_id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller" # must match the Pod Identity association
    }
  })]

  depends_on = [module.lbc_pod_identity]
}

# Watches Ingresses and creates/updates/deletes the matching Route 53 records
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_chart_version
  namespace        = "external-dns"
  create_namespace = true

  values = [yamlencode({
    provider      = { name = "aws" }
    sources       = ["ingress"]
    domainFilters = [var.domain_name]  # never touch any other zone
    policy        = "sync"             # also delete records when the Ingress is deleted
    registry      = "txt"
    txtOwnerId    = var.cluster_name   # only delete records this cluster created
    serviceAccount = {
      create = true
      name   = "external-dns"          # must match the Pod Identity association
    }
    env = [{ name = "AWS_DEFAULT_REGION", value = var.aws_region }]
  })]

  depends_on = [module.external_dns_pod_identity]
}

# Issues TLS certificates inside the cluster. Required by the RabbitMQ
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  values = [yamlencode({
    crds = {
      enabled = true # install the Certificate / Issuer CRDs with the chart
      keep    = true # don't delete CRDs (and every certificate) on uninstall
    }
  })]

  depends_on = [module.eks]
}

# KEDA: Kubernetes Event-Driven Autoscaling, for scaling workloads based on external events (e.g. RabbitMQ queue length).
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.keda_chart_version
  namespace        = "keda"
  create_namespace = true

  depends_on = [module.eks]
}

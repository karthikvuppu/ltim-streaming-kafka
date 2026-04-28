# ArgoCD Installation
# Installs ArgoCD via Helm into the argocd namespace
# Exposed via internet-facing NLB for sandbox access

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.11"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  timeout    = 600

  # Run ArgoCD server without TLS (NLB terminates, sandbox only)
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Expose ArgoCD UI via internet-facing NLB
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "argocd-sandbox.aws.internal"
  }

  # Reduce resource usage for sandbox
  set {
    name  = "applicationSet.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "applicationSet.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "repoServer.resources.requests.cpu"
    value = "100m"
  }

  # GitHub webhook secret — ArgoCD verifies push events from GitHub
  # Matches the secret configured in GitHub repo webhook settings
  set {
    name  = "configs.secret.githubSecret"
    value = "6f1ef1f99dbc09de290676e4dcad3c9e48865caa"
  }

  # Annotation-based resource tracking — Strimzi inherits the Kafka CR's
  # labels (incl. argocd.argoproj.io/instance) onto its dynamically-created
  # PVCs. With default label tracking, ArgoCD claims ownership of those
  # PVCs and tries to prune them on sync, which would destroy Kafka data.
  # Annotation tracking avoids this — Strimzi does not propagate
  # annotations onto PVCs.
  set {
    name  = "configs.cm.application\\.resourceTrackingMethod"
    value = "annotation"
  }

  depends_on = [
    kubernetes_namespace.argocd,
    module.eks,
    module.iam_oidc
  ]
}

# ECR repositories for portal images
resource "aws_ecr_repository" "kafka_portal_api" {
  name                 = "kafka-portal-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "kafka_portal_ui" {
  name                 = "kafka-portal-ui"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

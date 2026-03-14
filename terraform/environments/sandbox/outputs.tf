# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "eks_cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = module.eks.cluster_version
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# IAM Outputs
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = module.iam.eks_node_group_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = module.iam_oidc.ebs_csi_driver_role_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = module.iam_oidc.aws_load_balancer_controller_role_arn
}

# kubectl config command
output "kubectl_config_command" {
  description = "Command to update kubeconfig for this cluster"
  value       = "aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region}"
}

# Console Access Outputs
output "eks_console_access_policy_arn" {
  description = "ARN of the IAM policy for EKS console access"
  value       = aws_iam_policy.eks_console_access.arn
}

output "console_access_info" {
  description = "Information about EKS console access"
  value = {
    policy_name        = aws_iam_policy.eks_console_access.name
    policy_arn         = aws_iam_policy.eks_console_access.arn
    mapped_users       = [for user in var.aws_auth_users : user.username]
    mapped_roles       = [for role in var.aws_auth_roles : role.username]
    console_url        = "https://console.aws.amazon.com/eks/home?region=${var.aws_region}#/clusters/${local.cluster_name}"
  }
}

# External DNS Outputs
output "route53_zone_id" {
  description = "Route53 private hosted zone ID"
  value       = aws_route53_zone.private.zone_id
}

output "route53_zone_name" {
  description = "Route53 private hosted zone name"
  value       = aws_route53_zone.private.name
}

output "external_dns_role_arn" {
  description = "IAM role ARN for ExternalDNS"
  value       = aws_iam_role.external_dns.arn
}

output "kafka_dns_name" {
  description = "Kafka cluster DNS name (will be created by ExternalDNS)"
  value       = "kafka-sandbox.aws.internal"
}

# Glue Schema Registry Outputs
output "glue_schema_registry_name" {
  description = "AWS Glue Schema Registry name"
  value       = aws_glue_registry.kafka.registry_name
}

output "glue_schema_registry_arn" {
  description = "AWS Glue Schema Registry ARN"
  value       = aws_glue_registry.kafka.arn
}

output "kafka_schema_registry_role_arn" {
  description = "IAM role ARN for Kafka pods to access Glue Schema Registry (IRSA)"
  value       = aws_iam_role.kafka_schema_registry.arn
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.kafka_portal.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID (used in Streamlit env vars)"
  value       = aws_cognito_user_pool_client.kafka_portal.id
}

output "cognito_client_secret" {
  description = "Cognito App Client Secret (used in Streamlit env vars)"
  value       = aws_cognito_user_pool_client.kafka_portal.client_secret
  sensitive   = true
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = "ltim-sandbox-kafka-portal.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_jwks_url" {
  description = "Cognito JWKS URL for JWT verification in FastAPI"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.kafka_portal.id}/.well-known/jwks.json"
}

# ArgoCD / ECR Outputs
output "argocd_dns" {
  description = "ArgoCD UI DNS (created by ExternalDNS after deploy)"
  value       = "argocd-sandbox.aws.internal"
}

output "ecr_api_repo_url" {
  description = "ECR URL for kafka-portal-api image"
  value       = aws_ecr_repository.kafka_portal_api.repository_url
}

output "ecr_ui_repo_url" {
  description = "ECR URL for kafka-portal-ui image"
  value       = aws_ecr_repository.kafka_portal_ui.repository_url
}

# Kafka Access Information
output "kafka_access" {
  description = "Kafka cluster access endpoints"
  value = {
    # External access (internet-facing NLB - accessible from internet and VPC)
    external_port         = "9094"
    external_access_info  = "Accessible from anywhere (internet and VPC)"
    external_dns_note     = "Use 'kubectl get svc -n kafka' to get NLB DNS name"
    security_warning      = "⚠️ POC/Testing only - Enable TLS and authentication for production"
  }
}

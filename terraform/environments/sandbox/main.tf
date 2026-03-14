# Local values
locals {
  project_name = "ltim"
  environment  = "sandbox"
  cluster_name = "${local.project_name}-${local.environment}-eks"

  common_tags = merge(
    var.common_tags,
    {
      Project     = local.project_name
      Environment = local.environment
      ManagedBy   = "Terraform"
    }
  )
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name         = local.project_name
  environment          = local.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  cluster_name         = local.cluster_name

  tags = local.common_tags
}

# IAM Module - Create base IAM roles first (before EKS cluster)
# Note: This module creates cluster and node roles that don't need OIDC
module "iam" {
  source = "../../modules/iam"

  project_name = local.project_name
  environment  = local.environment

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  project_name                         = local.project_name
  environment                          = local.environment
  cluster_name                         = local.cluster_name
  cluster_version                      = var.cluster_version
  cluster_role_arn                     = module.iam.eks_cluster_role_arn
  node_role_arn                        = module.iam.eks_node_group_role_arn
  vpc_id                               = module.vpc.vpc_id
  private_subnet_ids                   = module.vpc.private_subnet_ids
  public_subnet_ids                    = module.vpc.public_subnet_ids
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  enable_cluster_logging               = var.enable_cluster_logging
  cluster_log_types                    = var.cluster_log_types
  node_groups                          = var.node_groups

    # Add AWS Auth configuration
  aws_auth_roles                       = var.aws_auth_roles
  aws_auth_users                       = var.aws_auth_users

  tags = local.common_tags

  depends_on = [module.vpc, module.iam]
}

# IAM OIDC Module - Create OIDC-dependent IAM roles (after EKS cluster creation)
module "iam_oidc" {
  source = "../../modules/iam-oidc"

  project_name                        = local.project_name
  environment                         = local.environment
  oidc_provider_arn                   = module.eks.oidc_provider_arn
  oidc_provider_url                   = module.eks.oidc_provider_url
  enable_ebs_csi_driver               = var.enable_ebs_csi_driver
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_efs_csi_driver               = var.enable_efs_csi_driver

  tags = local.common_tags

  depends_on = [module.eks]
}

# EBS CSI Driver Add-on (created after IAM OIDC module)
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = module.eks.cluster_id
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = module.iam_oidc.ebs_csi_driver_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [
    module.eks,
    module.iam_oidc
  ]
}

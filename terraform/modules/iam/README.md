# IAM Module

This module creates IAM roles and policies for EKS cluster, node groups, and various add-ons using IRSA (IAM Roles for Service Accounts).

## Features

- EKS cluster IAM role with required policies
- EKS node group IAM role with ECR, CNI, and worker node policies
- EBS CSI driver IAM role (optional)
- AWS Load Balancer Controller IAM role (optional)
- EFS CSI driver IAM role (optional)
- Support for IAM Roles for Service Accounts (IRSA)

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project_name                        = "ltim"
  environment                         = "sandbox"
  oidc_provider_arn                   = module.eks.oidc_provider_arn
  oidc_provider_url                   = module.eks.oidc_provider_url
  enable_ebs_csi_driver               = true
  enable_aws_load_balancer_controller = true
  enable_efs_csi_driver               = false

  tags = {
    Environment = "sandbox"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| environment | Environment name | string | - | yes |
| oidc_provider_arn | ARN of EKS OIDC provider | string | - | yes |
| oidc_provider_url | URL of EKS OIDC provider | string | - | yes |
| enable_ebs_csi_driver | Enable EBS CSI driver IAM role | bool | true | no |
| enable_aws_load_balancer_controller | Enable AWS LB controller IAM role | bool | true | no |
| enable_efs_csi_driver | Enable EFS CSI driver IAM role | bool | false | no |
| tags | Common tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| eks_cluster_role_arn | EKS cluster IAM role ARN |
| eks_cluster_role_name | EKS cluster IAM role name |
| eks_node_group_role_arn | EKS node group IAM role ARN |
| eks_node_group_role_name | EKS node group IAM role name |
| ebs_csi_driver_role_arn | EBS CSI driver IAM role ARN |
| aws_load_balancer_controller_role_arn | AWS LB controller IAM role ARN |
| efs_csi_driver_role_arn | EFS CSI driver IAM role ARN |

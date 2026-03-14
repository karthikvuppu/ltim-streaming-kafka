# EKS Module

This module creates an Amazon EKS cluster with node groups, security groups, and add-ons.

## Features

- EKS cluster with configurable Kubernetes version
- OIDC provider for IRSA support
- Security groups for cluster and nodes
- Multiple node groups with custom configurations
- EKS add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI Driver
- Public and/or private API endpoint access
- CloudWatch logging support

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name        = "ltim"
  environment         = "sandbox"
  cluster_name        = "ltim-sandbox-eks"
  cluster_version     = "1.32"
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_role_arn       = module.iam.eks_node_group_role_arn
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  enable_cluster_logging          = true

  enable_ebs_csi_driver      = true
  ebs_csi_driver_role_arn    = module.iam.ebs_csi_driver_role_arn

  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      labels         = { role = "general" }
      taints         = []
    }
  }

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
| cluster_name | Name of the EKS cluster | string | - | yes |
| cluster_version | Kubernetes version | string | "1.28" | no |
| cluster_role_arn | IAM role ARN for cluster | string | - | yes |
| node_role_arn | IAM role ARN for nodes | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| private_subnet_ids | Private subnet IDs | list(string) | - | yes |
| public_subnet_ids | Public subnet IDs | list(string) | - | yes |
| cluster_endpoint_public_access | Enable public API access | bool | true | no |
| cluster_endpoint_private_access | Enable private API access | bool | true | no |
| cluster_endpoint_public_access_cidrs | Public access CIDR blocks | list(string) | ["0.0.0.0/0"] | no |
| enable_cluster_logging | Enable CloudWatch logging | bool | true | no |
| cluster_log_types | Log types to enable | list(string) | [...] | no |
| node_groups | Node group configurations | map(object) | {} | no |
| enable_ebs_csi_driver | Enable EBS CSI driver | bool | true | no |
| ebs_csi_driver_role_arn | EBS CSI driver IAM role ARN | string | "" | no |
| tags | Common tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_arn | EKS cluster ARN |
| cluster_endpoint | EKS cluster endpoint |
| cluster_version | Kubernetes version |
| cluster_security_group_id | Cluster security group ID |
| cluster_certificate_authority_data | Cluster CA data (sensitive) |
| oidc_provider_arn | OIDC provider ARN |
| oidc_provider_url | OIDC provider URL |
| node_security_group_id | Node security group ID |
| node_group_ids | Node group IDs |
| node_group_arns | Node group ARNs |
| node_group_statuses | Node group statuses |

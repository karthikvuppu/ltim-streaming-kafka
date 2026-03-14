# VPC Module

This module creates a VPC with public and private subnets across multiple availability zones, including Internet Gateway and NAT Gateways.

## Features

- Multi-AZ VPC with configurable CIDR
- Public and private subnets
- Internet Gateway for public subnets
- NAT Gateways for private subnets (configurable)
- Automatic subnet tagging for EKS integration
- Configurable single or multi-NAT Gateway setup

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name         = "ltim"
  environment          = "sandbox"
  vpc_cidr             = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = false
  cluster_name         = "ltim-sandbox-eks"

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
| vpc_cidr | VPC CIDR block | string | - | yes |
| private_subnet_cidrs | Private subnet CIDR blocks | list(string) | - | yes |
| public_subnet_cidrs | Public subnet CIDR blocks | list(string) | - | yes |
| availability_zones | List of AZs (auto-detected if empty) | list(string) | [] | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT Gateway | bool | false | no |
| cluster_name | EKS cluster name for tagging | string | - | yes |
| tags | Common tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr_block | VPC CIDR block |
| private_subnet_ids | Private subnet IDs |
| public_subnet_ids | Public subnet IDs |
| nat_gateway_ids | NAT Gateway IDs |
| private_route_table_ids | Private route table IDs |
| public_route_table_id | Public route table ID |

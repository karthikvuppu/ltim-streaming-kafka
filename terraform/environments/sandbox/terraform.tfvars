# Environment Configuration
aws_region = "eu-north-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false

# EKS Cluster Configuration
cluster_version                      = "1.32"
cluster_endpoint_public_access       = true
cluster_endpoint_private_access      = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # Restrict this in production
enable_cluster_logging               = true
cluster_log_types                    = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# Node Groups Configuration
node_groups = {
  general = {
    desired_size   = 2
    min_size       = 1
    max_size       = 4
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    labels = {
      role = "general"
    }
    taints = []
  }
  # Uncomment for Kafka-specific node group
  # kafka = {
  #   desired_size   = 3
  #   min_size       = 3
  #   max_size       = 6
  #   instance_types = ["t3.large"]
  #   capacity_type  = "ON_DEMAND"
  #   disk_size      = 100
  #   labels = {
  #     role = "kafka"
  #   }
  #   taints = [
  #     {
  #       key    = "workload"
  #       value  = "kafka"
  #       effect = "NoSchedule"
  #     }
  #   ]
  # }
}

# Add-ons
enable_aws_load_balancer_controller = true
enable_ebs_csi_driver               = true
enable_efs_csi_driver               = false

# Tags
common_tags = {
  Environment = "sandbox"
  Project     = "ltim"
  ManagedBy   = "Terraform"
  Team        = "Platform"
}
# AWS Auth Configuration for EKS Console Access
# These users and roles will have full admin access to the EKS cluster
aws_auth_users = [
  {
    userarn  = "arn:aws:iam::292481751409:user/terraformuser"
    username = "terraformuser"
    groups   = ["system:masters"]
  },
  {
    userarn  = "arn:aws:iam::292481751409:user/karthikvuppu"
    username = "karthikvuppu"
    groups   = ["system:masters"]
  },
  # WARNING: Root account mapping is NOT RECOMMENDED for security reasons
  # This may not work as expected for console access
  {
    userarn  = "arn:aws:iam::292481751409:root"
    username = "root-account"
    groups   = ["system:masters"]
  }
]

aws_auth_roles = [
  {
    rolearn  = "arn:aws:iam::292481751409:role/terraformrole"
    username = "terraformrole"
    groups   = ["system:masters"]
  }
]
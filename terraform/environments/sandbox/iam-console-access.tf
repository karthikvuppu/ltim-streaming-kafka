# IAM Policy for EKS Console Access
# This policy allows users to view EKS cluster resources in the AWS Console

resource "aws_iam_policy" "eks_console_access" {
  name        = "${local.project_name}-${local.environment}-eks-console-access"
  description = "Policy for viewing EKS clusters and resources in AWS Console"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:AccessKubernetesApi",
          "eks:ListUpdates",
          "eks:ListFargateProfiles",
          "eks:DescribeUpdate",
          "eks:DescribeFargateProfile"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListRoles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach the policy to terraformrole
resource "aws_iam_role_policy_attachment" "terraformrole_console_access" {
  role       = "terraformrole"
  policy_arn = aws_iam_policy.eks_console_access.arn
}

# Attach the policy to terraformuser
resource "aws_iam_user_policy_attachment" "terraformuser_console_access" {
  user       = "terraformuser"
  policy_arn = aws_iam_policy.eks_console_access.arn
}

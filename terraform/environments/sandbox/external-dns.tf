# External DNS Configuration for Automatic DNS Management
# Creates Route53 hosted zone and ExternalDNS setup

# Create Private Route53 Hosted Zone
resource "aws_route53_zone" "private" {
  name = "aws.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-private-zone"
      Type = "Private"
    }
  )
}

# IAM Policy for ExternalDNS
resource "aws_iam_policy" "external_dns" {
  name        = "${local.project_name}-${local.environment}-external-dns-policy"
  description = "Policy for ExternalDNS to manage Route53 records"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${aws_route53_zone.private.zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role for ExternalDNS (using IRSA)
resource "aws_iam_role" "external_dns" {
  name = "${local.project_name}-${local.environment}-external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:external-dns:external-dns"
            "${replace(module.eks.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

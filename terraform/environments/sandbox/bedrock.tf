# Bedrock IRSA Role for kafka-portal-api pod
# Allows the FastAPI pod to call Amazon Bedrock (eu-west-1) without any API key.
# The pod uses this IAM role automatically via IRSA (projected service account token).

resource "aws_iam_role" "kafka_portal_bedrock" {
  name = "ltim-sandbox-kafka-portal-bedrock-role"

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
            "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kafka-portal:kafka-portal-api-sa"
            "${replace(module.eks.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "kafka_portal_bedrock" {
  name        = "ltim-sandbox-kafka-portal-bedrock-policy"
  description = "Allow kafka-portal FastAPI to invoke Bedrock Claude models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0",
          "arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "kafka_portal_bedrock" {
  role       = aws_iam_role.kafka_portal_bedrock.name
  policy_arn = aws_iam_policy.kafka_portal_bedrock.arn
}

output "kafka_portal_bedrock_role_arn" {
  description = "IRSA role ARN for kafka-portal-api to call Bedrock"
  value       = aws_iam_role.kafka_portal_bedrock.arn
}

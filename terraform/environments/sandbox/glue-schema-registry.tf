# AWS Glue Schema Registry for Kafka
# Provides managed schema registry for Avro, JSON Schema, and Protobuf formats
# Applications use GlueSchemaRegistryKafkaSerializer/Deserializer with IRSA auth

# Glue Schema Registry
resource "aws_glue_registry" "kafka" {
  registry_name = "${local.project_name}-${local.environment}-kafka-registry"
  description   = "Kafka schema registry for ${local.project_name} ${local.environment} - supports Avro, JSON Schema, and Protobuf"

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.project_name}-${local.environment}-kafka-registry"
      Service = "kafka"
    }
  )
}

# IAM Policy for Glue Schema Registry Access
resource "aws_iam_policy" "kafka_schema_registry" {
  name        = "${local.project_name}-${local.environment}-kafka-schema-registry-policy"
  description = "Policy for Kafka producers/consumers to access Glue Schema Registry"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueSchemaRegistryAccess"
        Effect = "Allow"
        Action = [
          "glue:GetRegistry",
          "glue:ListRegistries",
          "glue:CreateSchema",
          "glue:UpdateSchema",
          "glue:GetSchema",
          "glue:ListSchemas",
          "glue:RegisterSchemaVersion",
          "glue:GetSchemaVersion",
          "glue:GetSchemaVersionValidity",
          "glue:ListSchemaVersions",
          "glue:DeleteSchemaVersions",
          "glue:QuerySchemaVersionMetadata",
          "glue:GetTags"
        ]
        Resource = [
          aws_glue_registry.kafka.arn,
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schema/${local.project_name}-${local.environment}-kafka-registry/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# IAM Role for Kafka application pods (IRSA)
# Trusted by service account: kafka/kafka-schema-registry-sa
resource "aws_iam_role" "kafka_schema_registry" {
  name = "${local.project_name}-${local.environment}-kafka-schema-registry-role"

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
            "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kafka:kafka-schema-registry-sa"
            "${replace(module.eks.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.project_name}-${local.environment}-kafka-schema-registry-role"
      Service = "kafka"
    }
  )

  depends_on = [module.eks]
}

# Attach policy to IRSA role
resource "aws_iam_role_policy_attachment" "kafka_schema_registry" {
  role       = aws_iam_role.kafka_schema_registry.name
  policy_arn = aws_iam_policy.kafka_schema_registry.arn
}

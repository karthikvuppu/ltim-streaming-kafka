# Cognito User Pool for Kafka Self-Service Portal
# Handles authentication for the FastAPI + Streamlit portal

resource "aws_cognito_user_pool" "kafka_portal" {
  name = "ltim-sandbox-kafka-portal"

  # Login with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Allow users to sign themselves up (sandbox)
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Add team as a custom attribute (maps to Kafka ACL team)
  schema {
    name                     = "team"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  tags = local.common_tags
}

# App client for Streamlit UI (OAuth2 Authorization Code flow)
resource "aws_cognito_user_pool_client" "kafka_portal" {
  name         = "ltim-sandbox-kafka-portal-client"
  user_pool_id = aws_cognito_user_pool.kafka_portal.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]

  # Update these URLs after deploying the portal
  callback_urls = [
    "http://localhost:8501",
    "https://kafka-portal-sandbox.aws.internal"
  ]

  logout_urls = [
    "http://localhost:8501",
    "https://kafka-portal-sandbox.aws.internal"
  ]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # Token expiry
  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 7  # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Hosted UI domain for Cognito login page
resource "aws_cognito_user_pool_domain" "kafka_portal" {
  domain       = "ltim-sandbox-kafka-portal"
  user_pool_id = aws_cognito_user_pool.kafka_portal.id
}

# Pre-create user groups that map to Kafka teams
resource "aws_cognito_user_group" "teams" {
  for_each = toset(["payments", "analytics", "engineering", "platform", "audit"])

  name         = each.value
  user_pool_id = aws_cognito_user_pool.kafka_portal.id
  description  = "Kafka team: ${each.value}"
}

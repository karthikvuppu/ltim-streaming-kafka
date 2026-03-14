# Kafka Public Access Security Configuration
# Allows internet access to Kafka on port 9095 for POC/Testing

# Security group rule to allow public internet access to Kafka
# ⚠️ POC/Testing only - Restrict source IPs in production
resource "aws_security_group_rule" "kafka_public_ingress" {
  description       = "Allow public internet access to Kafka on port 9095 (POC/Testing only)"
  type              = "ingress"
  from_port         = 9095
  to_port           = 9095
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

# Optional: Uncomment to restrict access to specific IP addresses in production
# resource "aws_security_group_rule" "kafka_public_ingress_restricted" {
#   description       = "Allow Kafka access from specific IPs only"
#   type              = "ingress"
#   from_port         = 9095
#   to_port           = 9095
#   protocol          = "tcp"
#   cidr_blocks       = [
#     "YOUR_IP_ADDRESS/32",  # Replace with your IP
#     "YOUR_OFFICE_IP/24",   # Replace with your office IP range
#   ]
#   security_group_id = module.eks.node_security_group_id
# }

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = try(aws_iam_role.ebs_csi_driver[0].arn, null)
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = try(aws_iam_role.aws_load_balancer_controller[0].arn, null)
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI driver IAM role"
  value       = try(aws_iam_role.efs_csi_driver[0].arn, null)
}

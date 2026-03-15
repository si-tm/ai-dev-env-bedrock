# ============================================================
# terraform/outputs.tf
# ============================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.ai_dev.id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.ai_dev.public_ip
}

output "code_server_url" {
  description = "code-server URL (HTTP)"
  value       = "http://${aws_eip.ai_dev.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.ai_dev.public_ip}"
}

output "ssm_command" {
  description = "AWS SSM Session Manager connection (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.ai_dev.id} --region ${var.aws_region}"
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.ai_dev.id
}

# Output the public IP of the EC2 instance

# Output the instance ID
output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

# Output the security group ID
output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.app_sg.id
}

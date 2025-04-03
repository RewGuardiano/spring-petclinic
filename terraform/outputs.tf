# Output the public IP of the EC2 instance
output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

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
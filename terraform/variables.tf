# Variable for the AWS region
variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-north-1"
}

# Variable for the EC2 instance type
variable "instance_type" {
  description = "The type of EC2 instance to launch"
  type        = string
  default     = "t3.micro" # Free-tier eligible for testing
}

# Variable for the SSH key pair name
variable "key_name" {
  description = "The name of the SSH key pair to access the EC2 instance"
  type        = string
  default     = "AWS_Key_Pair" # Replace with your actual key pair name
}

# Variable for the application port
variable "app_port" {
  description = "The port the application will run on"
  type        = number
  default     = 8081
}
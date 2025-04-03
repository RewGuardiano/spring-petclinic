provider "aws" {
  region = var.region
}

resource "aws_instance" "app_server" {
  ami           = "ami-088c89fc150027121" # Amazon Linux 2 AMI
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [aws_security_group.app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  EOF

  tags = {
    Name = "PetClinic-App-Server"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
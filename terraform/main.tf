terraform {
    backend "s3" {
        bucket            = "rew-state-bucket"
        key               = "petclinic/terraform.tfstate"
        region            = "eu-north-1"
        dynamodb_endpoint = "https://dynamodb.eu-north-1.amazonaws.com"
        dynamodb_table    = "terraform-locks"
    }
}

provider "aws" {
    region = "eu-north-1"
}

resource "random_id" "suffix" {
    byte_length = 8
}

resource "aws_security_group" "app_sg" {
    name        = "app-security-group-${random_id.suffix.hex}"
    description = "Security group for PetClinic app"
    vpc_id      = "vpc-044bc9e9528107aed"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 8081
        to_port     = 8081
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

resource "aws_instance" "app_server" {
  ami           = "ami-088c89fc150027121" # Amazon Linux 2 AMI
  instance_type = var.instance_type
  key_name      = "AWS_Key_Pair"
  security_groups = [aws_security_group.app_sg.name]
  associate_public_ip_address = true

    user_data = <<-EOF
        #!/bin/bash
        sudo yum update -y
        sudo amazon-linux-extras install docker -y
        sudo service docker start
        sudo usermod -a -G docker ec2-user
    EOF

    tags = {
        Name = "PetClinicServer"
    }
}

output "instance_public_ip" {
    value = aws_instance.app_server.public_ip
}

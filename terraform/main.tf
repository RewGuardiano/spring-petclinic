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

# Reference the existing Internet Gateway
data "aws_internet_gateway" "existing_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = ["vpc-044bc9e9528107aed"]
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = "vpc-044bc9e9528107aed"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing_igw.internet_gateway_id
  }

  tags = {
    Name = "PetClinicPublicRT"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = "subnet-098f458e7260ac711" 
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_instance" "app_server" {
  ami           = "ami-088c89fc150027121" # Latest Amazon Linux 2 AMI for eu-north-1
  instance_type = "t3.micro"
  key_name      = "AWS_Key_Pair"
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  subnet_id      = "subnet-098f458e7260ac711" # Replace with the correct subnet ID

  user_data = <<-EOF
              #!/bin/bash
              echo "Starting user_data script..." > /var/log/user-data.log
              echo "Updating package index..." >> /var/log/user-data.log
              sudo yum update -y >> /var/log/user-data.log 2>&1
              if [ $? -eq 0 ]; then
                  echo "Package index updated successfully." >> /var/log/user-data.log
              else
                  echo "Failed to update package index." >> /var/log/user-data.log
              fi
              echo "Trying to install Docker via amazon-linux-extras..." >> /var/log/user-data.log
              if sudo amazon-linux-extras install docker -y >> /var/log/user-data.log 2>&1; then
                  echo "Docker installed via amazon-linux-extras" >> /var/log/user-data.log
              else
                  echo "Falling back to yum install docker..." >> /var/log/user-data.log
                  if sudo yum install -y docker >> /var/log/user-data.log 2>&1; then
                      echo "Docker installed via yum" >> /var/log/user-data.log
                  else
                      echo "Falling back to Docker official repository..." >> /var/log/user-data.log
                      sudo yum install -y yum-utils >> /var/log/user-data.log 2>&1
                      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> /var/log/user-data.log 2>&1
                      sudo yum install -y docker-ce docker-ce-cli containerd.io >> /var/log/user-data.log 2>&1
                  fi
              fi
              echo "Starting Docker service..." >> /var/log/user-data.log
              sudo systemctl start docker >> /var/log/user-data.log 2>&1
              echo "Enabling Docker service..." >> /var/log/user-data.log
              sudo systemctl enable docker >> /var/log/user-data.log 2>&1
              echo "Adding ec2-user to docker group..." >> /var/log/user-data.log
              sudo usermod -aG docker ec2-user >> /var/log/user-data.log 2>&1
              echo "Verifying Docker installation..." >> /var/log/user-data.log
              sudo -u ec2-user docker --version >> /var/log/user-data.log 2>&1
              if [ $? -eq 0 ]; then
                  echo "Docker installation verified." >> /var/log/user-data.log
              else
                  echo "Docker installation failed." >> /var/log/user-data.log
              fi
              echo "user_data script completed." >> /var/log/user-data.log
              EOF

  tags = {
    Name = "PetClinicServer"
  }
}
output "instance_public_ip" {
    value = aws_instance.app_server.public_ip
}

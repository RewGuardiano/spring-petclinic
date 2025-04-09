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
        description = "SSH access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "PetClinic app access (blue)"
        from_port   = 8081
        to_port     = 8081
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "PetClinic app access (green)"
        from_port   = 8082
        to_port     = 8082
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Prometheus access"
        from_port   = 9090
        to_port     = 9090
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Node Exporter access"
        from_port   = 9100
        to_port     = 9100
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Docker Exporter access"
        from_port   = 9323
        to_port     = 9323
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "PetClinicSG"
    }
}

# Reference the existing Internet Gateway
data "aws_internet_gateway" "existing_igw" {
    filter {
        name   = "attachment.vpc-id"
        values = ["vpc-044bc9e9528107aed"]
    }
}


# Update the existing route table to include the route to the Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = data.aws_route_table.existing_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = data.aws_internet_gateway.existing_igw.internet_gateway_id
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

                # Install Docker
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

                # Install Prometheus
                echo "Installing Prometheus..." >> /var/log/user-data.log
                wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz >> /var/log/user-data.log 2>&1
                tar -xzf prometheus-2.47.0.linux-amd64.tar.gz >> /var/log/user-data.log 2>&1
                sudo mv prometheus-2.47.0.linux-amd64 /usr/local/prometheus >> /var/log/user-data.log 2>&1
                sudo mkdir -p /usr/local/prometheus/data >> /var/log/user-data.log 2>&1
                sudo chown -R ec2-user:ec2-user /usr/local/prometheus >> /var/log/user-data.log 2>&1
                cat <<EOT > /usr/local/prometheus/prometheus.yml
                global:
                  scrape_interval: 15s

                scrape_configs:
                  - job_name: 'prometheus'
                    static_configs:
                      - targets: ['localhost:9090']
                  - job_name: 'node'
                    static_configs:
                      - targets: ['localhost:9100']
                  - job_name: 'docker'
                    static_configs:
                      - targets: ['localhost:9323']
                EOT
                sudo chown ec2-user:ec2-user /usr/local/prometheus/prometheus.yml >> /var/log/user-data.log 2>&1
                cat <<EOT > /etc/systemd/system/prometheus.service
                [Unit]
                Description=Prometheus Monitoring
                Wants=network-online.target
                After=network-online.target

                [Service]
                User=ec2-user
                Group=ec2-user
                Type=simple
                ExecStart=/usr/local/prometheus/prometheus \
                  --config.file=/usr/local/prometheus/prometheus.yml \
                  --storage.tsdb.path=/usr/local/prometheus/data \
                  --log.level=debug
                StandardOutput=journal
                StandardError=journal
                Restart=always
                RestartSec=5

                [Install]
                WantedBy=multi-user.target
                EOT
                sudo systemctl daemon-reload >> /var/log/user-data.log 2>&1
                sudo systemctl enable prometheus >> /var/log/user-data.log 2>&1
                sudo systemctl start prometheus >> /var/log/user-data.log 2>&1
                if [ $? -eq 0 ]; then
                    echo "Prometheus installed and started successfully." >> /var/log/user-data.log
                else
                    echo "Failed to start Prometheus." >> /var/log/user-data.log
                fi

                # Install Node Exporter
                echo "Installing Node Exporter..." >> /var/log/user-data.log
                wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz >> /var/log/user-data.log 2>&1
                tar -xzf node_exporter-1.6.1.linux-amd64.tar.gz >> /var/log/user-data.log 2>&1
                sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/ >> /var/log/user-data.log 2>&1
                cat <<EOT > /etc/systemd/system/node-exporter.service
                [Unit]
                Description=Node Exporter
                Wants=network-online.target
                After=network-online.target

                [Service]
                User=ec2-user
                Group=ec2-user
                Type=simple
                ExecStart=/usr/local/bin/node_exporter
                Restart=always

                [Install]
                WantedBy=multi-user.target
                EOT
                sudo systemctl daemon-reload >> /var/log/user-data.log 2>&1
                sudo systemctl enable node-exporter >> /var/log/user-data.log 2>&1
                sudo systemctl start node-exporter >> /var/log/user-data.log 2>&1
                if [ $? -eq 0 ]; then
                    echo "Node Exporter installed and started successfully." >> /var/log/user-data.log
                else
                    echo "Failed to start Node Exporter." >> /var/log/user-data.log
                fi

                # Install Docker Exporter
                echo "Installing Docker Exporter..." >> /var/log/user-data.log
                sudo docker run -d --name docker-exporter \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  -p 9323:9323 \
                  prom/container-exporter >> /var/log/user-data.log 2>&1
                if [ $? -eq 0 ]; then
                    echo "Docker Exporter installed and started successfully." >> /var/log/user-data.log
                else
                    echo "Failed to start Docker Exporter." >> /var/log/user-data.log
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

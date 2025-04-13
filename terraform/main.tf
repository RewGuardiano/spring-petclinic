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

    ingress {
        description = "Grafana access"
        from_port   = 3000
        to_port     = 3000
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

# Reference the existing route table associated with the subnet
data "aws_route_table" "existing_rt" {
    subnet_id = "subnet-098f458e7260ac711"
}

resource "aws_instance" "app_server" {
    ami           = "ami-088c89fc150027121" # Latest Amazon Linux 2 AMI for eu-north-1
    instance_type = "t3.micro"
    key_name      = "AWS_Key_Pair"
    vpc_security_group_ids = [aws_security_group.app_sg.id]
    subnet_id      = "subnet-098f458e7260ac711"

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

                # Create a Docker network
                echo "Creating Docker network 'docker-devops-network'..." >> /var/log/user-data.log
                sudo docker network create docker-devops-network >> /var/log/user-data.log 2>&1 || true
                if [ $? -eq 0 ]; then
                    echo "Docker network created successfully or already exists." >> /var/log/user-data.log
                else
                    echo "Failed to create Docker network." >> /var/log/user-data.log
                fi

                # Configure Docker daemon to expose metrics
                echo "Configuring Docker daemon to expose metrics..." >> /var/log/user-data.log
                sudo mkdir -p /etc/docker
                cat <<EOT > /etc/docker/daemon.json
                {
                  "metrics-addr": "0.0.0.0:9323",
                  "experimental": true
                }
                EOT
                sudo systemctl restart docker >> /var/log/user-data.log 2>&1
                if [ $? -eq 0 ]; then
                    echo "Docker daemon configured and restarted successfully." >> /var/log/user-data.log
                else
                    echo "Failed to restart Docker daemon." >> /var/log/user-data.log
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

                # Retrieve the EC2 instance's private IP using IMDSv2
                echo "Retrieving EC2 instance private IP using IMDSv2..." >> /var/log/user-data.log
                TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
                if [ $? -eq 0 ]; then
                    echo "IMDSv2 token retrieved successfully." >> /var/log/user-data.log
                else
                    echo "Failed to retrieve IMDSv2 token." >> /var/log/user-data.log
                    exit 1
                fi
                EC2_PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
                if [ $? -eq 0 ]; then
                    echo "EC2 private IP retrieved: $EC2_PRIVATE_IP" >> /var/log/user-data.log
                else
                    echo "Failed to retrieve EC2 private IP." >> /var/log/user-data.log
                    exit 1
                fi

                # Run Prometheus as a Docker container on the custom network
                echo "Running Prometheus as a Docker container..." >> /var/log/user-data.log
                sudo mkdir -p /etc/prometheus
                cat <<EOT > /etc/prometheus/prometheus.yml
                global:
                  scrape_interval: 15s

                scrape_configs:
                  - job_name: 'prometheus'
                    static_configs:
                      - targets: ['localhost:9090']
                  - job_name: 'node'
                    static_configs:
                      - targets: ['$EC2_PRIVATE_IP:9100']
                  - job_name: 'docker'
                    static_configs:
                      - targets: ['$EC2_PRIVATE_IP:9323']
                    metrics_path: '/metrics'
                  - job_name: 'petclinic'
                    static_configs:
                      - targets: ['petclinic-blue:8081']
                    metrics_path: '/actuator/prometheus'
                EOT
                sudo docker run -d --name prometheus \
                  --network docker-devops-network \
                  -p 9090:9090 \
                  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
                  prom/prometheus:latest \
                  --config.file=/etc/prometheus/prometheus.yml \
                  --log.level=debug >> /var/log/user-data.log 2>&1
                if [ $? -eq 0 ]; then
                    echo "Prometheus container started successfully." >> /var/log/user-data.log
                else
                    echo "Failed to start Prometheus container." >> /var/log/user-data.log
                fi

                # Run Grafana as a Docker container on the custom network
                echo "Running Grafana as a Docker container..." >> /var/log/user-data.log
                sudo docker run -d --name grafana \
                  --network docker-devops-network \
                  -p 3000:3000 \
                  grafana/grafana:latest >> /var/log/user-data.log 2>&1
                if [ $? -eq 0 ]; then
                    echo "Grafana container started successfully." >> /var/log/user-data.log
                else
                    echo "Failed to start Grafana container." >> /var/log/user-data.log
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

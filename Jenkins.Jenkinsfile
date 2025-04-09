pipeline {
    agent any
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
    }
    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/RewGuardiano/rew-spring-petclinic.git', branch: 'main'
            }
        }
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar -Dsonar.token=$SONAR_TOKEN'
                }
            }
        }
        stage('Provision Infrastructure') {
            steps {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t rewg/petclinic:latest .'
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh 'docker push rewg/petclinic:latest'
            }
        }
        stage('Deploy to AWS') {
            steps {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        script {
                            def ec2Ip = sh(script: 'terraform output -raw instance_public_ip', returnStdout: true).trim()
                            sh 'ls -l /var/jenkins_home/AWS_Key_Pair.pem'
                            sh 'which ssh' // Debug: Check if ssh is available
                            sh """
                                ssh -i /var/jenkins_home/AWS_Key_Pair.pem -o StrictHostKeyChecking=no ec2-user@${ec2Ip} '
                                    echo "Checking Docker installation..." &&
                                    if ! command -v docker >/dev/null 2>&1; then
                                        echo "Docker not found, attempting to install..." &&
                                        sudo yum update -y &&
                                        if sudo amazon-linux-extras install docker -y; then
                                            echo "Docker installed via amazon-linux-extras" &&
                                            sudo systemctl start docker &&
                                            sudo systemctl enable docker &&
                                            sudo usermod -aG docker ec2-user;
                                        else
                                            echo "Falling back to Docker official repository..." &&
                                            sudo yum install -y yum-utils &&
                                            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &&
                                            sudo yum install -y docker-ce docker-ce-cli containerd.io &&
                                            sudo systemctl start docker &&
                                            sudo systemctl enable docker &&
                                            sudo usermod -aG docker ec2-user;
                                        fi;
                                    fi &&
                                    if ! command -v docker >/dev/null 2>&1; then
                                        echo "Docker installation failed, exiting..." &&
                                        exit 1;
                                    fi &&
                                    if getent group docker >/dev/null; then
                                        echo "Docker group exists, using sg..." &&
                                        sg docker -c "docker --version" &&
                                        echo "Pulling Docker image..." &&
                                        sg docker -c "docker pull rewg/petclinic:latest" &&
                                        echo "Running Docker container..." &&
                                        sg docker -c "docker run -d -p 8081:8081 -e SERVER_PORT=8081 rewg/petclinic:latest";
                                    else
                                        echo "Docker group does not exist, using sudo..." &&
                                        sudo docker --version &&
                                        echo "Pulling Docker image..." &&
                                        sudo docker pull rewg/petclinic:latest &&
                                        echo "Running Docker container..." &&
                                        sudo docker run -d -p 8081:8081 -e SERVER_PORT=8081 rewg/petclinic:latest;
                                    fi
                                '
                            """
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            stage('Cleanup') {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
    }
}


pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('SonarQube-Token')
        DOCKER_CREDENTIALS = credentials('docker-credentials')
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/RewGuardiano/rew-spring-petclinic.git'
            }
        }

        stage('Build & Test') {
            steps {
                sh 'rm -rf terraform/.terraform'
                sh 'mvn spring-javaformat:apply'
                sh 'mvn clean package'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        mvn sonar:sonar \
                        -Dsonar.host.url=http://sonarqube:9000 \
                        -Dsonar.token=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Provision AWS Resources') {
            steps {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        sh 'terraform init -migrate-state -force-copy'
                        sh 'terraform destroy -auto-approve'
                        sh 'terraform apply -auto-approve'
                        sh 'terraform output instance_public_ip'
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t rewg/petclinic:latest .'
                sh 'echo $DOCKER_CREDENTIALS_PSW | docker login -u $DOCKER_CREDENTIALS_USR --password-stdin'
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
                            sh """
                                ssh -i /var/jenkins_home/AWS_Key_Pair.pem -o StrictHostKeyChecking=no ec2-user@${ec2Ip} '
                                    sudo service docker start &&
                                    docker pull rewg/petclinic:latest && 
                                    docker run -d -p 8081:8081 -e SERVER_PORT=8081 rewg/petclinic:latest
                                '
                            """
                        }
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve'
                        sh 'aws ec2 describe-security-groups --region eu-north-1 --filters Name=tag:Name,Values=PetClinicSG --query "SecurityGroups[*].GroupName" --output text || true'
                    }
                }
            }
        }
    }
}

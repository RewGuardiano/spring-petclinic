pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('SonarQube-Token')
        DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
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

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t rewguardiano/petclinic:latest .'
                sh 'echo $DOCKER_CREDENTIALS_PSW | docker login -u $DOCKER_CREDENTIALS_USR --password-stdin'
                sh 'docker push rewguardiano/petclinic:latest'
            }
        }

        stage('Provision AWS Resources') {
            steps {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Deploy to AWS') {
            steps {
                script {
                    def ec2Ip = sh(script: 'terraform output -raw instance_public_ip', returnStdout: true).trim()
                    sh "ssh -i /path/to/AWS_Key_Pair.pem ec2-user@${ec2Ip} 'docker pull rewguardiano/petclinic:latest && docker run -d -p 8081:8081 rewguardiano/petclinic:latest'"
                }
            }
        }
    }
}

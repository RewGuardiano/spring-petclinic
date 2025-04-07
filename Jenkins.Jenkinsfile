pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('SonarQube-Token')
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
                        sh 'terraform output instance_public_ip' // Print the public IP to the console
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
        stage('Cleanup') {
            steps {
                withAWS(credentials: 'aws-credentials') {
                    dir('terraform') {
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
    }
}

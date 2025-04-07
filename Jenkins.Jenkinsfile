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
                }
            }
        }

        stage('Provision AWS Resources') {
            steps {
                withAWS(credentials: 'aws-credentials') {
~                    dir('terraform') {
~                        sh 'terraform init'
~                        sh 'terraform apply -auto-approve'
~                    }
~                }
~            }
~        }
~    }
~}

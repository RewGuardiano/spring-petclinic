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
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}

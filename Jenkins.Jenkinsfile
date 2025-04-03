pipeline {
    agent any
    environment {
        SONAR_TOKEN = credentials('SONAR_TOKEN')  // Ensure this is configured in Jenkins
    }
    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/RewGuardiano/rew_spring-petclinic.git'
                    credentialsId: 'github-pat'
            }
        }
        stage('Build & Test') {
            steps {
                sh 'mvn clean package'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        mvn sonar:sonar \
                        -Dsonar.host.url=http://sonarqube:9000 \
                        -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }
    }
}

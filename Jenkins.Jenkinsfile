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
                        sh '''
                            terraform init \
                            -backend-config="bucket=rew-state-bucket" \
                            -backend-config="key=petclinic/terraform.tfstate" \
                            -backend-config="region=eu-north-1" \
                            -backend-config="dynamodb_table=terraform-locks" \
                            -migrate-state -force-copy
                        '''
                        sh 'terraform destroy -auto-approve || true'
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }
    }
}

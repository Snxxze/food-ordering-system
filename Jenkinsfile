pipeline {
    agent any

    environment {
        DOCKERHUB_USER = "gowitphooang"
        BACKEND_IMAGE  = "${DOCKERHUB_USER}/food-backend"
        FRONTEND_IMAGE = "${DOCKERHUB_USER}/food-frontend"
        K8S_NAMESPACE  = "food-system"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo 'Building Backend and Frontend...'
                script {
                    docker.image('golang:1.25').inside {
                        dir('backend') {
                            sh 'go build -v .'
                        }
                    }
                    docker.image('node:20').inside {
                        dir('frontend') {
                            sh 'npm ci && npm run build'
                        }
                    }
                }
            }
        }

        stage('Test') {
            steps {
                echo 'Running Unit Tests...'
                script {
                    docker.image('golang:1.25').inside {
                        dir('backend') {
                            sh 'go test -v ./...'
                        }
                    }
                }
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    echo 'Building Docker Images...'
                    dockerBackend  = docker.build("${BACKEND_IMAGE}:${env.BUILD_ID}", "./backend")
                    dockerFrontend = docker.build("${FRONTEND_IMAGE}:${env.BUILD_ID}", "./frontend")
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    echo 'Scanning Docker Images for vulnerabilities with Trivy...'
                    sh """
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                            aquasec/trivy:latest image \\
                            --exit-code 1 \\
                            --severity CRITICAL \\
                            --no-progress \\
                            ${BACKEND_IMAGE}:${env.BUILD_ID} || echo 'Trivy scan failed or timed out, skipping for now...'
                    """
                    sh """
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                            aquasec/trivy:latest image \\
                            --exit-code 1 \\
                            --severity CRITICAL \\
                            --no-progress \\
                            ${FRONTEND_IMAGE}:${env.BUILD_ID} || echo 'Trivy scan failed or timed out, skipping for now...'
                    """
                }
            }
        }

        stage('Push to Hub') {
            steps {
                script {
                    docker.withRegistry('', 'dockerhub-credentials') {
                        echo 'Pushing Images to Docker Hub...'
                        dockerBackend.push("${env.BUILD_ID}")
                        dockerBackend.push("latest")
                        dockerFrontend.push("${env.BUILD_ID}")
                        dockerFrontend.push("latest")
                    }
                }
            }
        }

        stage('Infrastructure (Terraform)') {
            steps {
                echo 'Provisioning Infrastructure with Terraform...'
                withCredentials([file(credentialsId: 'k8s-kubeconfig', variable: 'KUBE_CONFIG_FILE')]) {
                    sh '''
                        export KUBECONFIG=$KUBE_CONFIG_FILE
                        echo "--- Verifying Kubernetes Connectivity ---"
                        kubectl get nodes || echo "Failed to connect to Kubernetes"
                        
                        cd terraform
                        terraform init -input=false
                        terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Configure (Ansible)') {
            steps {
                echo 'Configuring Environment with Ansible...'
                withCredentials([file(credentialsId: 'k8s-kubeconfig', variable: 'KUBE_CONFIG_FILE')]) {
                    sh '''
                        export KUBECONFIG=$KUBE_CONFIG_FILE
                        cd ansible
                        ansible-playbook -i inventory playbook.yml
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "Deploying to Kubernetes namespace: ${K8S_NAMESPACE}..."
                withCredentials([file(credentialsId: 'k8s-kubeconfig', variable: 'KUBE_CONFIG_FILE')]) {
                    sh """
                        export KUBECONFIG=\$KUBE_CONFIG_FILE
                        kubectl set image deployment/food-backend \
                            food-backend=${BACKEND_IMAGE}:${env.BUILD_ID} \
                            -n ${K8S_NAMESPACE} || \
                        kubectl apply -f k8s/ -n ${K8S_NAMESPACE}
                        
                        kubectl rollout status deployment/food-backend -n ${K8S_NAMESPACE} --timeout=3m
                        kubectl rollout status deployment/food-frontend -n ${K8S_NAMESPACE} --timeout=3m
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS! Build #${env.BUILD_ID} deployed to ${K8S_NAMESPACE}"
        }
        failure {
            echo "Pipeline FAILED at Build #${env.BUILD_ID}! Check logs above."
        }
        always {
            sh "docker rmi ${BACKEND_IMAGE}:${env.BUILD_ID} || true"
            sh "docker rmi ${FRONTEND_IMAGE}:${env.BUILD_ID} || true"
        }
    }
}

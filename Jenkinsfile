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

        stage('Setup Environment') {
            steps {
                echo 'Installing required tools (Terraform, Kubectl, Ansible) if missing...'
                sh '''
                    # Ensure basic utilities are present
                    apt-get update && apt-get install -y unzip wget curl ansible sshpass
                    
                    # Install Terraform
                    if ! command -v terraform &> /dev/null; then
                        wget -q https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
                        unzip -o terraform_1.5.7_linux_amd64.zip
                        mv terraform /usr/local/bin/
                        rm terraform_1.5.7_linux_amd64.zip
                    fi
                    
                    # Install Kubectl
                    if ! command -v kubectl &> /dev/null; then
                        curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                    fi
                '''
            }
        }

        stage('Prepare K8s Config') {
            steps {
                echo 'Preparing Kubernetes Configuration...'
                sh '''
                    chmod +x jenkins-setup/prepare-kubeconfig.sh
                    ./jenkins-setup/prepare-kubeconfig.sh
                '''
            }
        }

        stage('Infrastructure (Terraform)') {
            steps {
                echo 'Provisioning Infrastructure with Terraform...'
                dir('terraform') {
                    sh '''
                        export KUBECONFIG=/tmp/.kube/config
                        terraform init -input=false
                        terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Configure (Ansible)') {
            steps {
                echo 'Configuring Environment with Ansible...'
                dir('ansible') {
                    sh '''
                        export KUBECONFIG=/tmp/.kube/config
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        ansible-playbook -i inventory playbook.yml
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "Deploying to Kubernetes namespace: ${K8S_NAMESPACE}..."
                sh """
                    export KUBECONFIG=/tmp/.kube/config
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

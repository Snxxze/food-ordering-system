#!/bin/bash
set -e
echo "=== Preparing Kubernetes Configuration ==="

# 1. Extract the real minikube port from the mounted host kubeconfig
MINIKUBE_PORT=$(grep 'server:.*127.0.0.1' /root/.kube/config | grep -o '[0-9]*$')

if [ -z "$MINIKUBE_PORT" ]; then
    echo "ERROR: Could not find minikube port in kubeconfig"
    exit 1
fi
echo "Minikube Port from host kubeconfig: $MINIKUBE_PORT"

# 2. Generate a clean kubeconfig pointing to host.docker.internal
mkdir -p /tmp/.kube
cat > /tmp/.kube/config << EOF
apiVersion: v1
kind: Config
current-context: minikube
clusters:
- cluster:
    server: https://host.docker.internal:${MINIKUBE_PORT}
    insecure-skip-tls-verify: true
  name: minikube
contexts:
- context:
    cluster: minikube
    user: minikube
    namespace: default
  name: minikube
users:
- name: minikube
  user:
    client-certificate: /root/.minikube/profiles/minikube/client.crt
    client-key: /root/.minikube/profiles/minikube/client.key
EOF

echo "Kubeconfig written to /tmp/.kube/config"

# 3. Test connection
export KUBECONFIG=/tmp/.kube/config
echo "Testing connection to https://host.docker.internal:${MINIKUBE_PORT}..."
kubectl get nodes --request-timeout=10s || echo "WARNING: kubectl pre-check failed, proceeding anyway..."

echo "=== Kubernetes Configuration Ready ==="

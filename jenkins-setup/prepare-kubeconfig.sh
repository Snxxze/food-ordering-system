#!/bin/bash
set -e
echo "=== Preparing Kubernetes Configuration ==="

# 1. Copy kubeconfig to a writable location
mkdir -p /tmp/.kube
cp /root/.kube/config /tmp/.kube/config
chmod 600 /tmp/.kube/config

# 2. Discover Minikube port from Docker Socket API
echo "Discovering Minikube port..."
JSON=$(curl -s --unix-socket /var/run/docker.sock http://localhost/containers/minikube/json 2>/dev/null || echo "")

if [ -n "$JSON" ]; then
    MINIKUBE_PORT=$(echo "$JSON" | grep -o '"HostPort":"[0-9]*"' | head -n 1 | grep -o '[0-9]*')
fi

if [ -z "$MINIKUBE_PORT" ]; then
    echo "WARNING: Could not discover port, using default 8443"
    MINIKUBE_PORT=8443
fi
echo "Minikube Port: $MINIKUBE_PORT"

# 3. Build a clean minikube-only kubeconfig from scratch
# This avoids all sed escaping issues with Windows paths
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

# 4. Verify connection
export KUBECONFIG=/tmp/.kube/config
echo "Testing connection to cluster..."
kubectl get nodes --request-timeout=10s || echo "WARNING: kubectl pre-check failed, proceeding anyway..."

echo "=== Kubernetes Configuration Ready ==="

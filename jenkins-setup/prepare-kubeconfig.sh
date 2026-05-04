#!/bin/bash
echo "Preparing Kubernetes Configuration..."

mkdir -p ~/.kube
cp /root/.kube/config ~/.kube/config

echo "Discovering Minikube Port via Docker Socket..."
# Fetch container info
JSON=$(curl -s --unix-socket /var/run/docker.sock http://localhost/containers/minikube/json)

# Extract port using simple string matching to avoid escape character issues
MINIKUBE_PORT=$(echo "$JSON" | grep -o '"8443/tcp":\[{"HostIp":"127.0.0.1","HostPort":"[0-9]*"' | grep -o '[0-9]*$')

if [ -z "$MINIKUBE_PORT" ]; then
    echo "Failed to discover port, checking fallback..."
    MINIKUBE_PORT=$(echo "$JSON" | grep -o '"HostPort":"[0-9]*"' | head -n 1 | grep -o '[0-9]*$')
fi

echo "Current Minikube Port: $MINIKUBE_PORT"

# Replace the Windows paths with Linux paths
# We match 'C:.*minikube' to avoid dealing with backslash escapes
sed -i 's|C:.*minikube|/root/.minikube|g' ~/.kube/config

# Replace localhost with host.docker.internal and the correct port
sed -i "s|127.0.0.1:[0-9]*|host.docker.internal:$MINIKUBE_PORT|g" ~/.kube/config

# Add insecure-skip-tls-verify to avoid cert hostname issues
sed -i '/certificate-authority:/d' ~/.kube/config
sed -i '/server:/a \    insecure-skip-tls-verify: true' ~/.kube/config

echo "Testing connection..."
kubectl get nodes || echo "Warning: Pre-check failed, but proceeding..."

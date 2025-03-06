#!/bin/bash

# Function to check if a command exists
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "$1 is not installed. Please install $1 before running this script."
        exit 1
    fi
}

# Check if necessary commands are installed
check_command minikube
check_command kubectl
check_command git
check_command docker

# Clone the repository and handle errors
echo "Cloning the repository..."
if ! git clone --branch For_local_test_only git@github.com:NUS-ISS-Projects/bit-scout-backend-k8s.git bit-scout-backend-k8s-minikube; then
    echo "Failed to clone the repository. Please check your Git credentials or the repository URL."
    exit 1
fi

# Check if the secrets directory exists
if [ ! -d "secrets" ]; then
    echo "Secrets directory not found. Please ensure that the secrets are available."
    exit 1
fi

# Copy secrets files
echo "Copying secrets..."
cp secrets/.dockerconfigjson bit-scout-backend-k8s-minikube/k8s/base/
cp secrets/*.json bit-scout-backend-k8s-minikube/k8s/base/

cd bit-scout-backend-k8s-minikube || exit

# Start Minikube
echo "Starting Minikube..."
minikube start

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

# Modify /etc/hosts to prompt for password at the start
if ! grep -q "crypto.local" /etc/hosts; then
    echo "Adding crypto.local to /etc/hosts..."
    echo "You will be prompted for your password to modify /etc/hosts and add the domain 'crypto.local'."
    echo "$MINIKUBE_IP crypto.local" | sudo tee -a /etc/hosts > /dev/null
    echo "Added crypto.local to /etc/hosts"
else
    echo "crypto.local already exists in /etc/hosts"
fi

# Enable Minikube ingress addon
echo "Enabling Minikube ingress addon..."
minikube addons enable ingress

# Wait for ingress-nginx-controller and webhook to be ready
echo "Waiting for ingress-nginx-controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=600s

# Wait for ingress-nginx-admission service to be ready
echo "Waiting for ingress-nginx-admission service to be available..."
while ! kubectl get svc -n ingress-nginx ingress-nginx-controller-admission &> /dev/null; do
    echo "Waiting for ingress-nginx-admission service to be ready..."
    sleep 5
done
echo "Ingress admission service is ready!"

# Apply Kubernetes configurations
echo "Applying Kubernetes configuration..."
if ! kubectl apply -k k8s/overlays/prod; then
    echo "Failed to apply Kubernetes configurations. Please check for errors in the Kubernetes configuration files."
    exit 1
fi

# Check if all services in the default namespace are up and ready (timeout 30 minutes)
echo "Waiting for all services in the default namespace to be ready..."
timeout=1800
start_time=$(date +%s)
while true; do
    # Check for pods that are not in a 1/1, 2/2, etc. state (fully ready)
    not_ready_pods=$(kubectl get pods -n default --no-headers | awk '$2 != "1/1" && $2 != "2/2" && $2 != "3/3"' | wc -l)
    
    if [ "$not_ready_pods" -eq 0 ]; then
        echo "All services in the default namespace are up and ready."
        break
    fi
    
    if [ $(( $(date +%s) - $start_time )) -ge $timeout ]; then
        echo "Timed out waiting for services to be ready."
        kubectl get pods -n default
        exit 1
    fi

    echo "Waiting for services... ($not_ready_pods pods not ready)"
    sleep 10
done

# Test connection by pinging the domain
echo "Pinging crypto.local to ensure connectivity..."
if ! ping -c 4 crypto.local; then
    echo "Failed to ping crypto.local. Please check your network settings."
    exit 1
fi

# Provide the user with the access URL
echo "Your application should be accessible at http://crypto.local"
echo "To stop the application, run 'minikube stop' and 'minikube delete'"
echo "To start the application again, run 'minikube start' and 'kubectl apply -k k8s/overlays/prod'"
#!/bin/bash

# Build and Deploy Script for Local Development with Kong API Gateway
# This script replaces the ingress-based setup with Kong Gateway

set -e

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
check_command docker
check_command mvn

echo "Starting Minikube..."
minikube start

# Configure Docker to use Minikube's Docker daemon
echo "Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env)

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

# Update /etc/hosts for dis.local domain
if ! grep -q "dis.local" /etc/hosts; then
    echo "Adding dis.local to /etc/hosts..."
    echo "You will be prompted for your password to modify /etc/hosts and add the domain 'dis.local'."
    echo "$MINIKUBE_IP dis.local" | sudo tee -a /etc/hosts > /dev/null
    echo "Added dis.local to /etc/hosts"
else
    echo "dis.local already exists in /etc/hosts"
fi

# Build and package the Spring Boot applications
echo "Building data-ingestion-service..."
cd ../cap-backend-dataIngestion
mvn clean package -DskipTests

echo "Building data-processing-service..."
cd ../cap-backend-dataProcessing
mvn clean package -DskipTests

echo "Building data-acquisition-service..."
cd ../cap-backend-dataAcquisition
mvn clean package -DskipTests

echo "Building cap-user-service..."
cd ../cap-user-service
mvn clean package -DskipTests

# Build Docker images
echo "Building Docker images..."
cd ../cap-backend-dataIngestion
docker build -t cap-backend-data-ingestion:latest .

cd ../cap-backend-dataProcessing
docker build -t cap-backend-data-processing:latest .

cd ../cap-backend-dataAcquisition
docker build -t cap-backend-data-acquisition:latest .

cd ../cap-user-service
docker build -t cap-user-service:latest .

echo "Building cap-pdu-prediction service..."
cd ../cap-pdu-prediction
docker build -t cap-pdu-prediction:latest .

# Return to k8s directory
cd ../cap-backend-k8s

# Create Firebase service account secret
echo "Creating Firebase service account secret..."
if kubectl get secret firebase-service-account &> /dev/null; then
    echo "Firebase service account secret already exists, deleting and recreating..."
    kubectl delete secret firebase-service-account
fi

# Create the secret from the Firebase service account JSON file
kubectl create secret generic firebase-service-account \
    --from-literal=service-account-b64="$(base64 -w 0 cap-backend-user-1944058edd4f.json)"

echo "Firebase service account secret created successfully!"

# Apply Kubernetes configurations with local overlay (Kong Gateway)
echo "Applying Kubernetes configuration with Kong Gateway..."
kubectl apply -k k8s/overlays/local

# Wait for Kong Gateway to be ready
echo "Waiting for Kong Gateway to be ready..."
kubectl wait --for=condition=Ready pod -l app=kong-gateway --timeout=300s

# Wait for all other services to be ready
echo "Waiting for all services to be ready..."
timeout=1800
start_time=$(date +%s)
while true; do
    # Check for pods that are not in a ready state
    not_ready_pods=$(kubectl get pods --no-headers | grep -v "1/1\|2/2\|3/3\|4/4\|5/5" | grep -v "Completed" | wc -l)
    
    if [ "$not_ready_pods" -eq 0 ]; then
        echo "All services are ready!"
        break
    fi
    
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    
    if [ $elapsed_time -ge $timeout ]; then
        echo "Timeout reached. Some services may not be ready yet."
        kubectl get pods
        break
    fi
    
    echo "Waiting for services to be ready... ($elapsed_time/$timeout seconds)"
    sleep 10
done

# Display service information
echo "\n=== Kong Gateway Service Information ==="
echo "Kong Proxy (API Gateway): http://dis.local:32080"
echo "Kong Admin API: http://dis.local:32081"
echo "Kong Manager: http://dis.local:32082"
echo ""
echo "=== API Endpoints (via Kong Gateway) ==="
echo "Data Acquisition Health: http://dis.local:32080/api/acquisition/health"
echo "Data Ingestion Health: http://dis.local:32080/api/ingestion/health"
echo "Data Processing Health: http://dis.local:32080/api/processing/health"
echo "User Service Health: http://dis.local:32080/api/user/health"
echo "Prediction Service Health: http://dis.local:32080/api/prediction/health"
echo "Real-time Metrics: http://dis.local:32080/api/ingestion/internal/metrics/realtime"
echo ""
echo "=== Testing API Gateway ==="
echo "Testing Kong Gateway health..."
curl -s http://dis.local:32081/status && echo " - Kong Gateway is healthy!"

echo "\nTesting service endpoints through Kong Gateway..."
curl -s http://dis.local:32080/api/acquisition/health && echo " - Data Acquisition service is accessible!"
curl -s http://dis.local:32080/api/ingestion/health && echo " - Data Ingestion service is accessible!"
curl -s http://dis.local:32080/api/processing/health && echo " - Data Processing service is accessible!"
curl -s http://dis.local:32080/api/user/health && echo " - User service is accessible!"
curl -s http://dis.local:32080/api/prediction/health && echo " - Prediction service is accessible!"

echo "\n=== Deployment Complete ==="
echo "Your DIS Platform is now running with Kong API Gateway!"
echo "You can access the services through: http://dis.local:32080/api/"
echo "Kong Admin interface: http://dis.local:32081"
echo "Kong Manager interface: http://dis.local:32082"
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
check_command docker
check_command mvn

# Start Minikube if not running
if ! minikube status &> /dev/null; then
    echo "Starting Minikube..."
    minikube start
fi

# Set docker to use minikube's docker daemon
echo "Configuring docker to use Minikube's docker daemon..."
eval $(minikube docker-env)

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

# Update /etc/hosts if needed
if ! grep -q "dis.local" /etc/hosts; then
    echo "Adding dis.local to /etc/hosts..."
    echo "You will be prompted for your password to modify /etc/hosts and add the domain 'dis.local'."
    echo "$MINIKUBE_IP dis.local" | sudo tee -a /etc/hosts > /dev/null
    echo "Added dis.local to /etc/hosts"
else
    echo "dis.local already exists in /etc/hosts"
fi

# Enable Minikube ingress addon
echo "Enabling Minikube ingress addon..."
minikube addons enable ingress

# Wait for ingress-nginx-controller to be ready
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

# Build Docker images
echo "Building Docker images..."
cd ../cap-backend-dataIngestion
docker build -t cap-backend-data-ingestion:latest .

cd ../cap-backend-dataProcessing
docker build -t cap-backend-data-processing:latest .

cd ../cap-backend-dataAcquisition
docker build -t cap-backend-data-acquisition:latest .

# Return to k8s directory
cd ../cap-backend-k8s

# Apply Kubernetes configurations with local overlay
echo "Applying Kubernetes configuration with local overlay..."
kubectl apply -k k8s/overlays/local

# Wait for all pods to be ready
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

# Update sendPdu.py to use Minikube IP
echo "Updating sendPdu.py to use Minikube IP..."
sed -i "" "s/DESTINATION_ADDRESS = \".*\"/DESTINATION_ADDRESS = \"$MINIKUBE_IP\"/" sendPdu.py

# Provide the user with the access URL
echo "Your application should be accessible at http://dis.local"
echo "To test UDP traffic, run: python3 sendPdu.py"
echo "To stop the application, run 'minikube stop'"
echo "To start the application again, run 'minikube start' and 'kubectl apply -k k8s/overlays/local'"
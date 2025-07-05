# Local Development with Minikube

This guide explains how to build and deploy the CAP project services locally using Minikube.

## Prerequisites

- Docker
- Minikube
- kubectl
- Maven
- Java 17

## Setup and Deployment

### Option 1: Automated Setup

Use the provided script to build and deploy all services:

```bash
./build-and-deploy-local.sh
```

This script will:
1. Start Minikube if not running
2. Configure Docker to use Minikube's Docker daemon
3. Build the Spring Boot applications
4. Build Docker images directly in Minikube's Docker daemon
5. Deploy the services using the local overlay
6. Update the sendPdu.py script to use the Minikube IP

### Option 2: Manual Setup

If you prefer to do the setup manually, follow these steps:

1. Start Minikube:
   ```bash
   minikube start
   ```

2. Configure Docker to use Minikube's Docker daemon:
   ```bash
   eval $(minikube docker-env)
   ```

3. Build the Spring Boot applications:
   ```bash
   cd ../cap-backend-dataIngestion
   mvn clean package -DskipTests
   
   cd ../cap-backend-dataProcessing
   mvn clean package -DskipTests
   
   cd ../cap-backend-dataAcquisition
   mvn clean package -DskipTests
   ```

4. Build Docker images:
   ```bash
   cd ../cap-backend-dataIngestion
   docker build -t cap-backend-data-ingestion:latest .
   
   cd ../cap-backend-dataProcessing
   docker build -t cap-backend-data-processing:latest .
   
   cd ../cap-backend-dataAcquisition
   docker build -t cap-backend-data-acquisition:latest .
   ```

5. Deploy using the local overlay:
   ```bash
   cd ../cap-backend-k8s
   kubectl apply -k k8s/overlays/local
   ```

6. Update /etc/hosts to add the Minikube IP:
   ```bash
   echo "$(minikube ip) dis.local" | sudo tee -a /etc/hosts
   ```

### Option 3: Multipass VM Deployment

If you want to deploy the application in a Multipass Ubuntu VM, follow these steps:

1. Ensure you have Multipass installed and an Ubuntu VM created:
   ```bash
   # Install Multipass (if not already installed)
   # For macOS:
   brew install --cask multipass
   
   # Create an Ubuntu VM (if not already created)
   multipass launch ubuntu --name ubuntu
   ```

2. Use the provided script to transfer files and deploy all services:
   ```bash
   # From the project root directory
   ./deploy-to-multipass.sh
   ```

   This script will:
   - Create the project directory on the VM
   - Transfer all project files to the VM
   - Make the build script executable
   - Run the build and deploy script on the VM
   - Display the Minikube IP for accessing the application

3. For manual deployment to Multipass, see the `MULTIPASS_DEPLOYMENT.md` file.

## Testing

1. Access the web interface at http://dis.local

2. To test UDP traffic, update the sendPdu.py script with your Minikube IP:
   ```python
   # In sendPdu.py
   DESTINATION_ADDRESS = "<minikube-ip>"  # Replace with the output of `minikube ip`
   ```

   Then run:
   ```bash
   python3 sendPdu.py
   ```

   For Multipass deployment, use the provided script:
   ```bash
   python3 sendPdu-multipass.py
   ```

## Troubleshooting

### Checking Pod Status

```bash
kubectl get pods
```

For Multipass:
```bash
multipass exec ubuntu -- kubectl get pods
```

### Viewing Pod Logs

```bash
kubectl logs <pod-name>
```

For Multipass:
```bash
multipass exec ubuntu -- kubectl logs <pod-name>
```

### Restarting Deployment

```bash
kubectl rollout restart deployment <deployment-name>
```

For Multipass:
```bash
multipass exec ubuntu -- kubectl rollout restart deployment <deployment-name>
```

### Cleaning Up

To stop Minikube:
```bash
minikube stop
```

To delete the Minikube cluster:
```bash
minikube delete
```

For Multipass:
```bash
multipass exec ubuntu -- minikube stop
multipass exec ubuntu -- minikube delete
```
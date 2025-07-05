# Setting Up Ingress for Local Development

## Overview

This guide explains how to set up and configure ingress for local development using Minikube. The ingress configuration allows you to access the services through a domain name (dis.local) instead of using port forwarding or direct IP access.

## Prerequisites

- Minikube installed and running
- kubectl installed
- sudo access (for modifying /etc/hosts)

## Automatic Setup

The easiest way to set up ingress locally is to use the provided `build-and-deploy-local.sh` script, which will:

1. Start Minikube if not running
2. Enable the Minikube ingress addon
3. Wait for the ingress controller to be ready
4. Add the Minikube IP to your /etc/hosts file with the domain name 'dis.local'
5. Apply the Kubernetes configurations with the local overlay, including the ingress patch

```bash
./build-and-deploy-local.sh
```

## Manual Setup

If you prefer to set up ingress manually, follow these steps:

1. Start Minikube:
   ```bash
   minikube start
   ```

2. Enable the Minikube ingress addon:
   ```bash
   minikube addons enable ingress
   ```

3. Wait for the ingress controller to be ready:
   ```bash
   kubectl wait --namespace ingress-nginx \
     --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller \
     --timeout=600s
   ```

4. Get the Minikube IP:
   ```bash
   MINIKUBE_IP=$(minikube ip)
   echo "Minikube IP: $MINIKUBE_IP"
   ```

5. Add the Minikube IP to your /etc/hosts file:
   ```bash
   echo "$MINIKUBE_IP dis.local" | sudo tee -a /etc/hosts
   ```

6. Apply the Kubernetes configurations with the local overlay:
   ```bash
   kubectl apply -k k8s/overlays/local
   ```

## How It Works

The local ingress configuration works by:

1. Using the nginx ingress controller provided by Minikube instead of the GCE ingress controller used in production
2. Adding a host rule for 'dis.local' to the ingress configuration
3. Mapping the Minikube IP to 'dis.local' in your /etc/hosts file

The key differences between the production and local ingress configurations are:

- Production uses the GCE ingress controller (`spec.ingressClassName: "gce"`)
- Local uses the nginx ingress controller (`spec.ingressClassName: "nginx"`)
- Local adds a host rule for 'dis.local'

## Verifying the Setup

To verify that the ingress is working correctly:

1. Check the status of the ingress:
   ```bash
   kubectl get ingress
   ```

2. Access the services through the domain name:
   ```bash
   curl http://dis.local/api/ingestion/health
   curl http://dis.local/api/processing/health
   curl http://dis.local/api/acquisition/health
   ```

3. Open the services in your browser:
   - http://dis.local/api/ingestion/health
   - http://dis.local/api/processing/health
   - http://dis.local/api/acquisition/health

## Troubleshooting

### Ingress Not Working

1. Check if the ingress addon is enabled:
   ```bash
   minikube addons list
   ```

2. Check if the ingress controller is running:
   ```bash
   kubectl get pods -n ingress-nginx
   ```

3. Check the ingress configuration:
   ```bash
   kubectl describe ingress capstone-ingress
   ```

4. Check if the domain name resolves to the Minikube IP:
   ```bash
   ping dis.local
   ```

5. Check the ingress controller logs:
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

### Services Not Accessible

1. Check if the services are running:
   ```bash
   kubectl get pods
   ```

2. Check if the services are exposed:
   ```bash
   kubectl get svc
   ```

3. Check if the ingress is correctly configured for the services:
   ```bash
   kubectl describe ingress capstone-ingress
   ```

4. Try accessing the services directly using port forwarding:
   ```bash
   kubectl port-forward svc/data-ingestion-service 8080:8080
   ```
   Then access http://localhost:8080/api/ingestion/health in your browser.
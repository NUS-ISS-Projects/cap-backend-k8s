#!/bin/bash

# Variables
PROJECT_ID="third-hangout-460905-m7"
CLUSTER_NAME="dis-cluster"
ZONE="asia-southeast1"
NAMESPACE="default"
STATIC_IP_NAME="dis-ingress-ip"  # If you want to use a static IP for Ingress, extra charges apply
K8S_MANIFEST_PATH="k8s/overlays/prod"
SA_KEY_PATH="/home/ubuntu/cap_project/third-hangout-460905-m7-bd6e1a71c870.json"

# Authenticate with GCP
gcloud auth activate-service-account --key-file $SA_KEY_PATH
gcloud config set project $PROJECT_ID

// Create a secret for GitHub Container Registry
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-personal-access-token> \
  --docker-email=<your-github-email>

# Create GKE Cluster (Better use webapp)
gcloud container clusters create-auto $CLUSTER_NAME \
    --region $ZONE \
    --enable-autopilot

# Get credentials for kubectl
gcloud container clusters get-credentials $CLUSTER_NAME --region $ZONE

# Reserve a Static IP for Ingress
# gcloud compute addresses create dis-ingress-ip --global
gcloud compute addresses create $STATIC_IP_NAME \
    --global

# Apply Kubernetes manifests
kubectl apply -k $K8S_MANIFEST_PATH

# Wait for cluster and pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=600s -n $NAMESPACE

# Get Ingress details
kubectl get ingress -n $NAMESPACE

# Get Static IP
gcloud compute addresses list

echo "Setup complete!"

# ghcr credential in drive
.dockerconfigjson

# inspect postgres db inside docker
kubectl exec -it <postgres-pod-name> -- psql -U dis_user -d dis_db
\dt
\d entity_state_record;
SELECT * FROM entity_state_record LIMIT 10;
SELECT * FROM pg_stat_activity;
\q


# Get GKE ingress ip
kubectl get ingress capstone-ingress -n default --output jsonpath='{.status.loadBalancer.ingress[0].ip}'  # Ingress IP
kubectl get nodes -o wide # External IP, for UDP comms
kubectl get svc

# Firewall rule for udp
https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list?inv=1&invt=AbzCpg&project=third-hangout-460905-m7

# Get HPA status
kubectl get hpa -n default
#!/bin/bash

# Variables
PROJECT_ID="modified-badge-241302"
CLUSTER_NAME="crypto-cluster"
ZONE="asia-southeast1"
NAMESPACE="default"
STATIC_IP_NAME="crypto-ingress-ip"  # If you want to use a static IP for Ingress, extra charges apply
K8S_MANIFEST_PATH="k8s/overlays/prod"
SA_KEY_PATH="/path/to/your/service-account-key.json"

# Authenticate with GCP
gcloud auth activate-service-account --key-file $SA_KEY_PATH
gcloud config set project $PROJECT_ID

// Create a secret for GitHub Container Registry
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-personal-access-token> \
  --docker-email=<your-github-email>

# Create GKE Cluster
gcloud container clusters create-auto $CLUSTER_NAME \
    --region $ZONE \
    --enable-autopilot

# Get credentials for kubectl
gcloud container clusters get-credentials $CLUSTER_NAME --region $ZONE

# Reserve a Static IP for Ingress
# gcloud compute addresses create crypto-ingress-ip --global
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

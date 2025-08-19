#!/bin/bash

# GKE Deployment Validation Script
# This script validates that the DIS Platform is properly deployed and running on GKE

# Example usage:
# ./validate-gke-deployment.sh

# Your GKE configuration
export PROJECT_ID="green-jet-469501-u7"
export CLUSTER_NAME="dis-cluster"
export ZONE="asia-southeast1"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is configured
check_kubectl() {
    print_status "Checking kubectl configuration..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cannot connect to cluster"
        exit 1
    fi
    print_success "kubectl is properly configured"
}

# Function to check if all pods are running
check_pods() {
    print_status "Checking pod status..."
    
    # Get all pods and their status
    kubectl get pods -o wide
    
    # Check for any pods that are not running
    not_running=$(kubectl get pods --no-headers | grep -v "Running\|Completed" | wc -l)
    
    if [ "$not_running" -gt 0 ]; then
        print_warning "Some pods are not in Running state:"
        kubectl get pods --no-headers | grep -v "Running\|Completed"
        return 1
    else
        print_success "All pods are running"
        return 0
    fi
}

# Function to check services
check_services() {
    print_status "Checking service status..."
    kubectl get services -o wide
    
    # Check if Kong Gateway LoadBalancer has external IP
    external_ip=$(kubectl get service kong-gateway-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$external_ip" ]; then
        print_warning "Kong Gateway LoadBalancer does not have an external IP yet"
        print_status "Waiting for external IP assignment..."
        kubectl get service kong-gateway-service -w &
        sleep 30
        kill %1 2>/dev/null || true
        external_ip=$(kubectl get service kong-gateway-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    fi
    
    if [ -n "$external_ip" ]; then
        print_success "Kong Gateway external IP: $external_ip"
        echo "$external_ip" > /tmp/kong_external_ip
    else
        print_error "Kong Gateway LoadBalancer still does not have an external IP"
        return 1
    fi
}

# Function to check secrets
check_secrets() {
    print_status "Checking required secrets..."
    
    # Check GHCR secret
    if kubectl get secret ghcr-secret &> /dev/null; then
        print_success "GHCR secret exists"
    else
        print_error "GHCR secret is missing"
        return 1
    fi
    
    # Check Firebase service account secret
    if kubectl get secret firebase-service-account &> /dev/null; then
        print_success "Firebase service account secret exists"
    else
        print_error "Firebase service account secret is missing"
        return 1
    fi
}

# Function to test API endpoints
test_api_endpoints() {
    print_status "Testing API endpoints..."
    
    if [ ! -f /tmp/kong_external_ip ]; then
        print_error "External IP not available for testing"
        return 1
    fi
    
    external_ip=$(cat /tmp/kong_external_ip)
    base_url="http://$external_ip"
    
    print_status "Testing endpoints at: $base_url"
    
    # Test health endpoints
    endpoints=(
        "/api/acquisition/health"
        "/api/ingestion/health"
        "/api/processing/health"
        "/api/user/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        print_status "Testing $endpoint..."
        if curl -s -f "$base_url$endpoint" > /dev/null; then
            print_success "$endpoint is accessible"
        else
            print_error "$endpoint is not accessible"
            return 1
        fi
    done
    
    # Test real-time metrics endpoint
    print_status "Testing real-time metrics endpoint..."
    if curl -s -f "$base_url/api/ingestion/internal/metrics/realtime" > /dev/null; then
        print_success "Real-time metrics endpoint is accessible"
    else
        print_warning "Real-time metrics endpoint is not accessible (this may be normal if no data has been ingested)"
    fi
}

# Function to test UDP service
test_udp_service() {
    print_status "Checking UDP service configuration..."
    
    # Check if UDP NodePort service exists
    if kubectl get service data-ingestion-service-udp &> /dev/null; then
        udp_nodeport=$(kubectl get service data-ingestion-service-udp -o jsonpath='{.spec.ports[0].nodePort}')
        print_success "UDP service exists with NodePort: $udp_nodeport"
        
        # Get node external IPs
        node_ips=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}')
        if [ -n "$node_ips" ]; then
            print_success "Node external IPs for UDP access: $node_ips"
            print_status "UDP PDUs can be sent to any of these IPs on port $udp_nodeport"
        else
            print_warning "No external IPs found for nodes (this may be normal in some GKE configurations)"
        fi
    else
        print_error "UDP service data-ingestion-service-udp not found"
        return 1
    fi
}

# Function to check Kong Gateway configuration
check_kong_config() {
    print_status "Checking Kong Gateway configuration..."
    
    if [ ! -f /tmp/kong_external_ip ]; then
        print_error "External IP not available for Kong admin access"
        return 1
    fi
    
    external_ip=$(cat /tmp/kong_external_ip)
    admin_url="http://$external_ip:8001"
    
    print_status "Testing Kong Admin API at: $admin_url"
    if curl -s -f "$admin_url/status" > /dev/null; then
        print_success "Kong Admin API is accessible"
        
        # Check if services are configured
        services=$(curl -s "$admin_url/services" | jq -r '.data[].name' 2>/dev/null || echo "")
        if [ -n "$services" ]; then
            print_success "Kong services configured: $(echo $services | tr '\n' ' ')"
        else
            print_warning "No Kong services found or jq not available"
        fi
    else
        print_error "Kong Admin API is not accessible"
        return 1
    fi
}

# Function to check Firebase JWT plugin
check_firebase_jwt() {
    print_status "Checking Firebase JWT plugin configuration..."
    
    if [ ! -f /tmp/kong_external_ip ]; then
        print_error "External IP not available for Kong admin access"
        return 1
    fi
    
    external_ip=$(cat /tmp/kong_external_ip)
    admin_url="http://$external_ip:8001"
    
    # Check if jwt-firebase plugin is loaded
    plugins=$(curl -s "$admin_url/plugins" | jq -r '.data[].name' 2>/dev/null || echo "")
    if echo "$plugins" | grep -q "jwt-firebase"; then
        print_success "Firebase JWT plugin is configured"
    else
        print_warning "Firebase JWT plugin not found in active plugins"
    fi
}

# Main validation function
main() {
    echo "==========================================="
    echo "    GKE Deployment Validation Script"
    echo "==========================================="
    echo ""
    
    # Run all checks
    check_kubectl
    echo ""
    
    check_secrets
    echo ""
    
    check_pods
    pods_ok=$?
    echo ""
    
    check_services
    services_ok=$?
    echo ""
    
    if [ $pods_ok -eq 0 ] && [ $services_ok -eq 0 ]; then
        test_api_endpoints
        api_ok=$?
        echo ""
        
        test_udp_service
        echo ""
        
        check_kong_config
        echo ""
        
        check_firebase_jwt
        echo ""
    else
        print_warning "Skipping API tests due to pod or service issues"
        api_ok=1
    fi
    
    # Summary
    echo "==========================================="
    echo "            VALIDATION SUMMARY"
    echo "==========================================="
    
    if [ $pods_ok -eq 0 ] && [ $services_ok -eq 0 ] && [ ${api_ok:-1} -eq 0 ]; then
        print_success "✅ All validation checks passed!"
        print_success "✅ DIS Platform is successfully deployed on GKE"
        
        if [ -f /tmp/kong_external_ip ]; then
            external_ip=$(cat /tmp/kong_external_ip)
            echo ""
            print_status "🌐 Access your platform at:"
            echo "   • Kong Proxy: http://$external_ip"
            echo "   • Kong Admin: http://$external_ip:8001"
            echo "   • API Health Checks: http://$external_ip/api/{service}/health"
        fi
    else
        print_error "❌ Some validation checks failed"
        print_error "❌ Please review the issues above before using the platform"
        exit 1
    fi
    
    # Cleanup
    rm -f /tmp/kong_external_ip
}

# Run main function
main "$@"
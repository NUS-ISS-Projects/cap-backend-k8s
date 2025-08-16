#!/bin/bash

# Endpoint Testing Script for DIS Platform via Kong Gateway
# This script tests all available API endpoints through Kong Gateway

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-"local"}
VERBOSE=${2:-false}

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Function to test endpoint
test_endpoint() {
    local method=$1
    local url=$2
    local description=$3
    local expected_status=${4:-200}
    
    print_status "INFO" "Testing: $description"
    print_status "INFO" "URL: $method $url"
    
    if [ "$VERBOSE" = "true" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" 2>/dev/null || echo "000")
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n -1)
        
        echo "Response Body: $body"
        echo "HTTP Status: $http_code"
    else
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" 2>/dev/null || echo "000")
    fi
    
    if [ "$http_code" = "$expected_status" ]; then
        print_status "SUCCESS" "✓ $description - Status: $http_code"
        return 0
    else
        print_status "ERROR" "✗ $description - Expected: $expected_status, Got: $http_code"
        return 1
    fi
}

# Function to setup environment-specific configuration
setup_environment() {
    case $ENVIRONMENT in
        "local")
            # Check if minikube is running
            if ! minikube status >/dev/null 2>&1; then
                print_status "ERROR" "Minikube is not running. Please start minikube first."
                exit 1
            fi
            
            MINIKUBE_IP=$(minikube ip)
            BASE_URL="http://$MINIKUBE_IP:32080"
            ADMIN_URL="http://$MINIKUBE_IP:32081"
            MANAGER_URL="http://$MINIKUBE_IP:32082"
            
            # Alternative using dis.local (if configured in /etc/hosts)
            if ping -c 1 dis.local >/dev/null 2>&1; then
                BASE_URL="http://dis.local:32080"
                ADMIN_URL="http://dis.local:32081"
                MANAGER_URL="http://dis.local:32082"
            fi
            ;;
        "staging"|"production")
            # Get LoadBalancer external IP
            EXTERNAL_IP=$(kubectl get service kong-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
            if [ -z "$EXTERNAL_IP" ]; then
                print_status "ERROR" "Could not get LoadBalancer external IP. Is the service deployed?"
                exit 1
            fi
            BASE_URL="http://$EXTERNAL_IP"
            ADMIN_URL="http://$EXTERNAL_IP:8001"
            MANAGER_URL="http://$EXTERNAL_IP:8002"
            ;;
        *)
            print_status "ERROR" "Unknown environment: $ENVIRONMENT. Use 'local', 'staging', or 'production'"
            exit 1
            ;;
    esac
}

# Function to test Kong Gateway infrastructure
test_kong_infrastructure() {
    print_status "INFO" "=== Testing Kong Gateway Infrastructure ==="
    
    # Test Kong Admin API
    test_endpoint "GET" "$ADMIN_URL/status" "Kong Admin API Status"
    
    # Test Kong services configuration
    test_endpoint "GET" "$ADMIN_URL/services" "Kong Services Configuration"
    
    # Test Kong routes configuration
    test_endpoint "GET" "$ADMIN_URL/routes" "Kong Routes Configuration"
    
    echo
}

# Function to test health endpoints
test_health_endpoints() {
    print_status "INFO" "=== Testing Health Endpoints ==="
    
    test_endpoint "GET" "$BASE_URL/api/acquisition/health" "Data Acquisition Service Health"
    test_endpoint "GET" "$BASE_URL/api/ingestion/health" "Data Ingestion Service Health"
    test_endpoint "GET" "$BASE_URL/api/processing/health" "Data Processing Service Health"
    
    echo
}

# Function to test API endpoints
test_api_endpoints() {
    print_status "INFO" "=== Testing API Endpoints ==="
    
    # Data Acquisition API endpoints
    test_endpoint "GET" "$BASE_URL/api/acquisition/entity-states" "Data Acquisition - Get Entity States"
    test_endpoint "GET" "$BASE_URL/api/acquisition/fire-events" "Data Acquisition - Get Fire Events"
    test_endpoint "GET" "$BASE_URL/api/acquisition/collision-events" "Data Acquisition - Get Collision Events"
    test_endpoint "GET" "$BASE_URL/api/acquisition/detonation-events" "Data Acquisition - Get Detonation Events"
    test_endpoint "GET" "$BASE_URL/api/acquisition/metrics" "Data Acquisition - Get Metrics"
    test_endpoint "GET" "$BASE_URL/api/acquisition/realtime" "Data Acquisition - Get Realtime Metrics"
    
    # Test aggregate endpoint with various scenarios
    test_aggregate_endpoints
    
    # Monthly data requires year and month parameters
    CURRENT_YEAR=$(date +%Y)
    CURRENT_MONTH=$(date +%-m)
    test_endpoint "GET" "$BASE_URL/api/acquisition/monthly?year=$CURRENT_YEAR&month=$CURRENT_MONTH" "Data Acquisition - Monthly Data"
    
    # Test realtime logs endpoint with timestamp parameters
    # Using epoch timestamps: 0 (1970-01-01) to current time + 1 day
    CURRENT_TIMESTAMP=$(date +%s)000  # Convert to milliseconds
    FUTURE_TIMESTAMP=$((CURRENT_TIMESTAMP + 86400000))  # Add 24 hours in milliseconds
    test_endpoint "GET" "$BASE_URL/api/acquisition/realtime/logs?startTime=0&endTime=$FUTURE_TIMESTAMP" "Data Acquisition - Realtime Logs"
    
    # Test realtime logs with specific time range (last hour)
    HOUR_AGO_TIMESTAMP=$((CURRENT_TIMESTAMP - 3600000))  # Subtract 1 hour in milliseconds
    test_endpoint "GET" "$BASE_URL/api/acquisition/realtime/logs?startTime=$HOUR_AGO_TIMESTAMP&endTime=$CURRENT_TIMESTAMP" "Data Acquisition - Realtime Logs (Last Hour)"
    
    # Note: Internal metrics endpoint (/api/ingestion/internal/metrics/realtime) is for
    # service-to-service communication only and not exposed via API gateway
    # Note: Realtime logs may return empty Pdu_messages array if no PDU data exists in the database
    
    echo
}

# Function to test aggregate endpoints with various scenarios
test_aggregate_endpoints() {
    print_status "INFO" "=== Testing Aggregate Endpoints ==="
    
    # Test "today" view - no parameters required
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?today=true" "Data Acquisition - Aggregate Today View"
    
    # Test single date aggregation
    CURRENT_DATE=$(date +%Y-%m-%d)
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?startDate=$CURRENT_DATE" "Data Acquisition - Aggregate Single Date"
    
    # Test week view aggregation
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?startDate=$CURRENT_DATE&week=true" "Data Acquisition - Aggregate Week View"
    
    # Test month view aggregation
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?startDate=$CURRENT_DATE&month=true" "Data Acquisition - Aggregate Month View"
    
    # Test custom date range aggregation
    START_DATE=$(date -d "7 days ago" +%Y-%m-%d)
    END_DATE=$(date +%Y-%m-%d)
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?startDate=$START_DATE&endDate=$END_DATE" "Data Acquisition - Aggregate Custom Range"
    
    # Test with historical date range (should return zero counts)
    HISTORICAL_START="2025-01-01"
    HISTORICAL_END="2025-01-02"
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?startDate=$HISTORICAL_START&endDate=$HISTORICAL_END" "Data Acquisition - Aggregate Historical Range"
    
    # Test edge cases
    test_endpoint "GET" "$BASE_URL/api/acquisition/aggregate?startDate=$CURRENT_DATE&endDate=$CURRENT_DATE" "Data Acquisition - Aggregate Same Start/End Date"
    
    echo
}

# Function to test CORS configuration
test_cors() {
    print_status "INFO" "=== Testing CORS Configuration ==="
    
    # Test OPTIONS request for CORS preflight
    test_endpoint "OPTIONS" "$BASE_URL/api/acquisition/health" "CORS Preflight - Acquisition Health" "200"
    
    # Test with Origin header
    cors_response=$(curl -s -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: GET" -X OPTIONS "$BASE_URL/api/acquisition/health" -w "%{http_code}" 2>/dev/null || echo "000")
    if echo "$cors_response" | grep -q "200"; then
        print_status "SUCCESS" "✓ CORS Headers - Status: 200"
    else
        print_status "ERROR" "✗ CORS Headers - Failed"
    fi
    
    echo
}

# Function to test rate limiting
test_rate_limiting() {
    print_status "INFO" "=== Testing Rate Limiting ==="
    
    # Make multiple requests to test rate limiting
    print_status "INFO" "Making 5 rapid requests to test rate limiting..."
    
    success_count=0
    for i in {1..5}; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/acquisition/health" 2>/dev/null || echo "000")
        if [ "$http_code" = "200" ]; then
            ((success_count++))
        fi
        sleep 0.1
    done
    
    if [ $success_count -eq 5 ]; then
        print_status "SUCCESS" "✓ Rate Limiting - All requests successful (within limits)"
    else
        print_status "WARNING" "⚠ Rate Limiting - $success_count/5 requests successful"
    fi
    
    echo
}

# Function to generate summary report
generate_summary() {
    print_status "INFO" "=== Test Summary ==="
    print_status "INFO" "Environment: $ENVIRONMENT"
    print_status "INFO" "Base URL: $BASE_URL"
    print_status "INFO" "Admin URL: $ADMIN_URL"
    print_status "INFO" "Manager URL: $MANAGER_URL"
    
    if [ $failed_tests -eq 0 ]; then
        print_status "SUCCESS" "All tests passed! 🎉"
    else
        print_status "ERROR" "$failed_tests test(s) failed. Please check the logs above."
    fi
}

# Main execution
main() {
    print_status "INFO" "Starting DIS Platform Endpoint Tests"
    print_status "INFO" "Environment: $ENVIRONMENT"
    print_status "INFO" "Verbose: $VERBOSE"
    echo
    
    # Setup environment
    setup_environment
    
    # Initialize counters
    failed_tests=0
    
    # Run tests
    test_kong_infrastructure || ((failed_tests++))
    test_health_endpoints || ((failed_tests++))
    test_api_endpoints || ((failed_tests++))
    test_cors || ((failed_tests++))
    test_rate_limiting || ((failed_tests++))
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate code
    exit $failed_tests
}

# Help function
show_help() {
    echo "Usage: $0 [ENVIRONMENT] [VERBOSE]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local      - Test local Minikube deployment (default)"
    echo "  staging    - Test staging GKE deployment"
    echo "  production - Test production GKE deployment"
    echo ""
    echo "VERBOSE:"
    echo "  true       - Show response bodies"
    echo "  false      - Show only status codes (default)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test local environment"
    echo "  $0 local true         # Test local with verbose output"
    echo "  $0 staging            # Test staging environment"
    echo "  $0 production true    # Test production with verbose output"
}

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Run main function
main
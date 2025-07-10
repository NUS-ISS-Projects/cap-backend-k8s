#!/bin/bash

# Test Data Flow Script for DIS Platform
# This script tests the complete data flow from PDU generation to API endpoints

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
BASE_URL="http://dis.local:32080"
TEST_DURATION=10

print_status "INFO" "=== DIS Platform Data Flow Test ==="
print_status "INFO" "This test will:"
print_status "INFO" "1. Send DIS PDUs for $TEST_DURATION seconds"
print_status "INFO" "2. Wait for data processing"
print_status "INFO" "3. Check API endpoints for received data"
echo

# Step 1: Check if services are running
print_status "INFO" "Step 1: Checking service health..."
if curl -s "$BASE_URL/api/acquisition/health" > /dev/null; then
    print_status "SUCCESS" "✓ Data Acquisition service is healthy"
else
    print_status "ERROR" "✗ Data Acquisition service is not responding"
    exit 1
fi

if curl -s "$BASE_URL/api/ingestion/health" > /dev/null; then
    print_status "SUCCESS" "✓ Data Ingestion service is healthy"
else
    print_status "ERROR" "✗ Data Ingestion service is not responding"
    exit 1
fi

if curl -s "$BASE_URL/api/processing/health" > /dev/null; then
    print_status "SUCCESS" "✓ Data Processing service is healthy"
else
    print_status "ERROR" "✗ Data Processing service is not responding"
    exit 1
fi
echo

# Step 2: Get baseline counts
print_status "INFO" "Step 2: Getting baseline entity counts..."
BASELINE_ENTITIES=$(curl -s "$BASE_URL/api/acquisition/entity-states" | jq '. | length' 2>/dev/null || echo "0")
BASELINE_FIRES=$(curl -s "$BASE_URL/api/acquisition/fire-events" | jq '. | length' 2>/dev/null || echo "0")
print_status "INFO" "Baseline - Entity States: $BASELINE_ENTITIES, Fire Events: $BASELINE_FIRES"
echo

# Step 3: Send DIS PDUs
print_status "INFO" "Step 3: Sending DIS PDUs for $TEST_DURATION seconds..."
python3 -c "
import sys
sys.path.append('.')
exec(open('sendPdu.py').read().replace('SIMULATION_DURATION_SECONDS = 9999', 'SIMULATION_DURATION_SECONDS = $TEST_DURATION'))
" &
PDU_PID=$!

# Wait for PDU generation to complete
wait $PDU_PID
print_status "SUCCESS" "✓ PDU generation completed"
echo

# Step 4: Wait for data processing
print_status "INFO" "Step 4: Waiting 5 seconds for data processing..."
sleep 5
echo

# Step 5: Check for new data
print_status "INFO" "Step 5: Checking for new data..."
NEW_ENTITIES=$(curl -s "$BASE_URL/api/acquisition/entity-states" | jq '. | length' 2>/dev/null || echo "0")
NEW_FIRES=$(curl -s "$BASE_URL/api/acquisition/fire-events" | jq '. | length' 2>/dev/null || echo "0")

ENTITY_INCREASE=$((NEW_ENTITIES - BASELINE_ENTITIES))
FIRE_INCREASE=$((NEW_FIRES - BASELINE_FIRES))

print_status "INFO" "Results:"
print_status "INFO" "Entity States: $BASELINE_ENTITIES → $NEW_ENTITIES (+$ENTITY_INCREASE)"
print_status "INFO" "Fire Events: $BASELINE_FIRES → $NEW_FIRES (+$FIRE_INCREASE)"
echo

# Step 6: Evaluate results
print_status "INFO" "Step 6: Evaluating results..."
if [ $ENTITY_INCREASE -gt 0 ]; then
    print_status "SUCCESS" "✓ Entity State PDUs were successfully processed!"
else
    print_status "WARNING" "⚠ No new Entity State PDUs detected"
fi

if [ $FIRE_INCREASE -gt 0 ]; then
    print_status "SUCCESS" "✓ Fire Event PDUs were successfully processed!"
else
    print_status "WARNING" "⚠ No new Fire Event PDUs detected"
fi

if [ $ENTITY_INCREASE -gt 0 ] || [ $FIRE_INCREASE -gt 0 ]; then
    print_status "SUCCESS" "🎉 Data flow test PASSED! DIS PDUs are being processed correctly."
    exit 0
else
    print_status "ERROR" "❌ Data flow test FAILED! No PDUs were processed."
    print_status "INFO" "Check if:"
    print_status "INFO" "- UDP port 32000 is accessible"
    print_status "INFO" "- Data ingestion service is receiving UDP traffic"
    print_status "INFO" "- Kafka is running and processing messages"
    exit 1
fi
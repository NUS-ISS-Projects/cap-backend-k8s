#!/bin/bash

# Script to demonstrate the DIS Data Platform on GKE,
# focusing on basic end-to-end functionality.

# Variables - Replace with your actual Ingress IP if it changes
GKE_INGRESS_EXTERNAL_IP="34.98.89.167" # Your GKE Ingress IP
NAMESPACE="default" # Assuming default namespace

# PDU Sender Configuration
SEND_PDU_SCRIPT_NAME="sendPdu.py"
SEND_PDU_LOG_FILE="sendPdu.log"
SEND_PDU_PID_FILE="sendPdu.pid"
# Run sendPdu.py for a shorter duration, just to get some data in
PDU_SEND_DURATION_SECONDS=10 

# Function to print a header
print_header() {
  echo ""
  echo "================================================================================"
  echo "===== $1 "
  echo "================================================================================"
  echo ""
}

# Function to wait for user to press Enter
wait_for_enter() {
  echo ""
  read -p ">>> Press Enter to continue..."
  echo ""
}

# Function to stop a background process by PID file
stop_background_process() {
  local pid_file="$1"
  local process_name="$2"

  if [ -f "$pid_file" ]; then
      STORED_PID=$(cat "$pid_file")
      if ps -p "$STORED_PID" > /dev/null; then
          echo "Stopping '$process_name' (PID: $STORED_PID)..."
          kill $STORED_PID # Send SIGTERM first
          sleep 2 # Give it a moment to terminate
          if ps -p "$STORED_PID" > /dev/null; then
              echo "'$process_name' (PID $STORED_PID) did not terminate with SIGTERM, sending SIGKILL..."
              kill -9 "$STORED_PID"
          fi
          echo "'$process_name' (PID $STORED_PID) stopped."
      else
          echo "'$process_name' (PID: $STORED_PID from $pid_file) was not found running or already stopped."
      fi
      rm -f "$pid_file"
  else
      echo "PID file '$pid_file' for '$process_name' not found. Assuming it was not started or already stopped."
  fi
}

# Get current date components for dynamic queries later
YEAR_QUERY=$(date +%Y)
MONTH_QUERY=$(date +%m | sed 's/^0*//') # Remove leading zero for month if any
DAY_QUERY=$(date +%d | sed 's/^0*//')   # Remove leading zero for day if any
START_DATE_QUERY=$(date +%Y-%m-%d)
END_DATE_QUERY=$(date +%Y-%m-%d)


# --- Section 1: Initial System State ---
print_header "SECTION 1: INITIAL SYSTEM STATE"

echo "--- Checking GKE Nodes ---"
kubectl get nodes -o wide
wait_for_enter

echo "--- Checking Core Deployments (Applications & Postgres) ---"
kubectl get deployments -n $NAMESPACE
wait_for_enter

echo "--- Checking Core StatefulSets (Kafka & Zookeeper) ---"
kubectl get statefulsets -n $NAMESPACE
wait_for_enter

echo "--- Checking All Pods (Initial State) ---"
kubectl get pods -n $NAMESPACE -o wide
wait_for_enter

echo "--- Checking Kubernetes Services ---"
kubectl get svc -n $NAMESPACE
echo ""
echo "Key services to note:"
echo "- data-ingestion-service-udp (NodePort for UDP ingestion)"
echo "- data-acquisition-service, data-ingestion-service, data-processing-service (ClusterIP for internal/Ingress access)"
echo "- postgres, kafka, zookeeper (Backend services)"
wait_for_enter

echo "--- Checking Ingress Configuration ---"
kubectl get ingress capstone-ingress -n $NAMESPACE
echo "The Ingress External IP is: $GKE_INGRESS_EXTERNAL_IP"
echo "(Ensure this matches the GKE_INGRESS_EXTERNAL_IP variable in this script if it's dynamic)"
wait_for_enter

echo "--- Checking Horizontal Pod Autoscalers (HPAs) - Presence & Initial State ---"
kubectl get hpa -n $NAMESPACE
echo "This shows HPAs are deployed. We won't wait for scaling in this demo for brevity."
wait_for_enter

echo "--- Checking Initial Resource Usage (CPU/Memory of Pods) ---"
echo "(Metrics Server needs a short time to collect data after pod startup)"
kubectl top pods -n $NAMESPACE
wait_for_enter

echo "--- Initial Health Checks via Ingress ---"
echo "Checking Data Acquisition Service health..."
curl -s http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/health && echo ""
echo "Checking Data Ingestion Service health..."
curl -s http://$GKE_INGRESS_EXTERNAL_IP/api/ingestion/health && echo ""
echo "Checking Data Processing Service health..."
curl -s http://$GKE_INGRESS_EXTERNAL_IP/api/processing/health && echo ""
wait_for_enter

# --- Section 2: Start Data Ingestion (Briefly) ---
print_header "SECTION 2: STARTING DATA INGESTION (Brief UDP Load)"
if [ ! -f "$SEND_PDU_SCRIPT_NAME" ]; then
    echo "ERROR: '$SEND_PDU_SCRIPT_NAME' not found in the current directory."
    echo "Please ensure it's present and configured correctly before proceeding."
    exit 1
fi

echo "Starting '$SEND_PDU_SCRIPT_NAME' in the background for $PDU_SEND_DURATION_SECONDS seconds."
echo "Output from '$SEND_PDU_SCRIPT_NAME' will be saved to '$SEND_PDU_LOG_FILE'."
echo "Please ensure '$SEND_PDU_SCRIPT_NAME' is configured with:"
echo "  DESTINATION_ADDRESS = \"<One_of_your_GKE_Node_External_IPs>\" (e.g., 35.240.132.69)"
echo "  UDP_PORT = 32000"
echo ""

# Start sendPdu.py in the background
nohup python3 $SEND_PDU_SCRIPT_NAME > $SEND_PDU_LOG_FILE 2>&1 &
SEND_PDU_PID=$!
echo $SEND_PDU_PID > $SEND_PDU_PID_FILE
echo "'$SEND_PDU_SCRIPT_NAME' started with PID: $SEND_PDU_PID."
echo "You can monitor its output by running: tail -f $SEND_PDU_LOG_FILE"
echo ""
echo "Waiting for $PDU_SEND_DURATION_SECONDS seconds while PDUs are sent..."
sleep $PDU_SEND_DURATION_SECONDS

echo ""
echo "Stopping '$SEND_PDU_SCRIPT_NAME'..."
stop_background_process "$SEND_PDU_PID_FILE" "$SEND_PDU_SCRIPT_NAME"
wait_for_enter

# --- Section 3: Verify Data Flow via APIs ---
print_header "SECTION 3: VERIFYING DATA FLOW VIA APIs"
echo "--- Checking Real-time Metrics API ---"
curl -s http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/realtime | jq
echo "Expect 'pdusInLastSixtySeconds' to reflect recently sent PDUs (may be non-zero or zero if >60s passed since sending stopped)."
echo "'lastPduReceivedTimestampMs' should be recent."
wait_for_enter

echo "--- Checking Aggregated Metrics API (last 60 minutes) ---"
curl -s "http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/metrics?period=last60minutes" | jq
echo "Expect 'totalPackets' to reflect the PDUs sent by the script."
wait_for_enter

echo "--- Checking Raw Fire Events ---"
curl -s "http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/fire-events" | jq '. | if type == "array" and length > 0 then .[0] else . end' # Show first record if any
echo "Expect an array of FireEventRecord objects if Fire PDUs were sent."
wait_for_enter

echo "--- Checking Raw Entity State Events ---"
curl -s "http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/entity-states" | jq '. | if type == "array" and length > 0 then .[0] else . end' # Show first record if any
echo "Expect an array of EntityStateRecord objects if Entity State PDUs were sent."
wait_for_enter

# --- Section 4: Final System State ---
print_header "SECTION 4: FINAL SYSTEM STATE"
echo "--- Final check of HPAs (expecting baseline replicas) ---"
kubectl get hpa -n $NAMESPACE
wait_for_enter

echo "--- Final check of all Pods ---"
kubectl get pods -n $NAMESPACE -o wide
wait_for_enter

echo "--- Verifying data with aggregation queries (using current date from script start) ---"
echo "Querying /api/acquisition/aggregate for $START_DATE_QUERY to $END_DATE_QUERY:"
curl -s "http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/aggregate?startDate=$START_DATE_QUERY&endDate=$END_DATE_QUERY" | jq
wait_for_enter

echo "Querying /api/acquisition/monthly for $YEAR_QUERY-$MONTH_QUERY:"
curl -s "http://$GKE_INGRESS_EXTERNAL_IP/api/acquisition/monthly?year=$YEAR_QUERY&month=$MONTH_QUERY" | jq
wait_for_enter

print_header "DEMONSTRATION COMPLETE"
echo "This script has walked through:"
echo "1. Initial system state and HPA presence."
echo "2. Briefly running '$SEND_PDU_SCRIPT_NAME' to ingest data."
echo "3. Verifying data flow with curl through data-acquisition-service."
echo "4. Final system state."
echo "Ensure '$SEND_PDU_SCRIPT_NAME' is in the same directory as this script and configured correctly."
echo "Log for PDU sender is in '$SEND_PDU_LOG_FILE'."

# Clean up PID file at the end
rm -f $SEND_PDU_PID_FILE

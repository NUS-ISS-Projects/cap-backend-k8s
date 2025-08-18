#!/bin/bash

# Correct CAP User Service API Test through Kong Gateway
# Based on actual source code analysis

set -e

# Configuration
KONG_BASE_URL="http://dis.local:32080"
TEST_USER="testuser$(date +%s)"
TEST_EMAIL="${TEST_USER}@example.com"
TEST_PASSWORD="TestPassword123!"
TEST_NAME="Test User Full Name"

echo "=== CAP User Service Correct API Tests ==="
echo "Kong Gateway URL: $KONG_BASE_URL"
echo "Test User: $TEST_USER"
echo "Test Email: $TEST_EMAIL"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test 1: Health Check
echo -e "${BLUE}=== Test 1: Health Check ===${NC}"
echo "GET $KONG_BASE_URL/api/user/health"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$KONG_BASE_URL/api/user/health")
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -n -1)

if [ "$HEALTH_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed (Status: $HEALTH_STATUS)${NC}"
    echo "Response: $HEALTH_BODY"
else
    echo -e "${RED}✗ Health check failed (Status: $HEALTH_STATUS)${NC}"
    echo "Response: $HEALTH_BODY"
fi
echo

# Test 2: User Registration (CORRECTED - using 'username' not 'userName')
echo -e "${BLUE}=== Test 2: User Registration (Corrected) ===${NC}"
echo "POST $KONG_BASE_URL/api/auth/register"
echo "Using 'username' field (not 'userName') based on RegisterRequest.java"

REGISTER_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"username\": \"$TEST_USER\"
  }" \
  "$KONG_BASE_URL/api/auth/register")

REGISTER_STATUS=$(echo "$REGISTER_RESPONSE" | tail -n1)
REGISTER_BODY=$(echo "$REGISTER_RESPONSE" | head -n -1)

echo "Status: $REGISTER_STATUS"
echo "Response: $REGISTER_BODY"

if [ "$REGISTER_STATUS" = "200" ] || [ "$REGISTER_STATUS" = "201" ]; then
    echo -e "${GREEN}✓ Registration successful${NC}"
else
    echo -e "${RED}✗ Registration failed${NC}"
fi
echo

# Test 3: User Login
echo -e "${BLUE}=== Test 3: User Login ===${NC}"
echo "POST $KONG_BASE_URL/api/auth/login"

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }" \
  "$KONG_BASE_URL/api/auth/login")

LOGIN_STATUS=$(echo "$LOGIN_RESPONSE" | tail -n1)
LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | head -n -1)

echo "Status: $LOGIN_STATUS"
echo "Response: $LOGIN_BODY"

# Extract JWT token if login successful
JWT_TOKEN=""
if [ "$LOGIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Login successful${NC}"
    # Try to extract token from response
    JWT_TOKEN=$(echo "$LOGIN_BODY" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    if [ -n "$JWT_TOKEN" ]; then
        echo "JWT Token extracted: ${JWT_TOKEN:0:50}..."
    else
        echo "Could not extract JWT token from response"
    fi
else
    echo -e "${RED}✗ Login failed${NC}"
fi
echo

# Test 4: User Profile (with authentication)
echo -e "${BLUE}=== Test 4: User Profile ===${NC}"
if [ -n "$JWT_TOKEN" ]; then
    echo "GET $KONG_BASE_URL/api/users/profile (with JWT token)"
    
    PROFILE_RESPONSE=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $JWT_TOKEN" \
      "$KONG_BASE_URL/api/users/profile")
    
    PROFILE_STATUS=$(echo "$PROFILE_RESPONSE" | tail -n1)
    PROFILE_BODY=$(echo "$PROFILE_RESPONSE" | head -n -1)
    
    echo "Status: $PROFILE_STATUS"
    echo "Response: $PROFILE_BODY"
    
    if [ "$PROFILE_STATUS" = "200" ]; then
        echo -e "${GREEN}✓ Profile retrieval successful${NC}"
    else
        echo -e "${RED}✗ Profile retrieval failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping profile test - no JWT token available${NC}"
fi
echo

# Test 5: User Session (CORRECTED - using 'userName' field based on UserSession.java)
echo -e "${BLUE}=== Test 5: User Session (Corrected) ===${NC}"
echo "POST $KONG_BASE_URL/api/user-sessions"
echo "Using 'userName' field based on UserSession.java model"

SESSION_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"test-user-id-$(date +%s)\",
    \"userName\": \"$TEST_USER\",
    \"name\": \"$TEST_NAME\",
    \"lastSession\": {
      \"page\": \"/dashboard\",
      \"date\": \"$(date -Iseconds)\",
      \"view\": \"main\"
    }
  }" \
  "$KONG_BASE_URL/api/user-sessions")

SESSION_STATUS=$(echo "$SESSION_RESPONSE" | tail -n1)
SESSION_BODY=$(echo "$SESSION_RESPONSE" | head -n -1)

echo "Status: $SESSION_STATUS"
echo "Response: $SESSION_BODY"

if [ "$SESSION_STATUS" = "200" ] || [ "$SESSION_STATUS" = "201" ]; then
    echo -e "${GREEN}✓ Session creation successful${NC}"
else
    echo -e "${RED}✗ Session creation failed${NC}"
fi
echo

# Test 6: Kong Gateway Headers Check
echo -e "${BLUE}=== Test 6: Kong Gateway Headers ===${NC}"
echo "Checking Kong Gateway headers and rate limiting"

HEADERS_RESPONSE=$(curl -v "$KONG_BASE_URL/api/user/health" 2>&1)
echo "Kong Gateway Headers:"
echo "$HEADERS_RESPONSE" | grep -E "(X-Kong|X-RateLimit|Via: kong|RateLimit-|Access-Control)" || echo "No Kong headers found"
echo

echo "=== Test Summary ==="
echo "All tests completed with corrected API parameters based on source code analysis."
echo "Key corrections made:"
echo "1. Registration uses 'username' field (RegisterRequest.java)"
echo "2. User sessions use 'userName' field (UserSession.java model)"
echo "3. Proper JSON structure for LastSession embedded object"

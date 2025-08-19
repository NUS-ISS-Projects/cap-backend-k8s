# Manual cURL Endpoint Tests - Complete Guide

This document provides comprehensive manual cURL tests for all CAP system endpoints through Kong Gateway.

## Base Configuration

**Kong Gateway URL:** `http://dis.local:32080`
**All endpoints are accessible through Kong Gateway with proper routing, rate limiting, and CORS.**

---

## 1. User Service Endpoints

### 1.1 Health Check (Public)
```bash
curl -X GET http://dis.local:32080/api/user/health \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** `{"service": "cap-user-service", "status": "UP"}`

### 1.2 User Registration (Public)
```bash
curl -X POST http://dis.local:32080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"your.unique.email@example.com","password":"SecurePass123!","username":"yourusername"}' \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** `"User registered successfully!"`

**⚠️ Important:** 
- Use unique email addresses for each test
- Include all three fields: `email`, `password`, `username`
- Password should be strong (8+ characters with special chars)

### 1.3 User Login (Public)
```bash
curl -X POST http://dis.local:32080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your.email@example.com","password":"SecurePass123!"}' \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** `{"token":"eyJhbGciOiJSUzI1NiI..."}`

**💡 Save the JWT token from response for protected endpoint tests!**

### 1.4 User Profile (Protected)
```bash
# Replace YOUR_JWT_TOKEN with actual token from login
curl -X GET http://dis.local:32080/api/users/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** `{"userId":"...","username":"...","email":"..."}`

### 1.5 User Session Management (Protected)
```bash
curl -X POST http://dis.local:32080/api/user-sessions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "userId": "test-user-id-123",
    "userName": "yourusername",
    "name": "Your Full Name",
    "lastSession": {
      "page": "/dashboard",
      "date": "2024-01-15T10:00:00Z",
      "view": "main"
    }
  }' \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## 2. Data Acquisition Service Endpoints

### 2.1 Health Check (Public)
```bash
curl -X GET http://dis.local:32080/api/acquisition/health \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.2 Get Entities (Protected)
```bash
curl -X GET http://dis.local:32080/api/acquisition/entities \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.3 Fire Events (Protected)
```bash
curl -X POST http://dis.local:32080/api/acquisition/fire-events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "eventType": "test_event",
    "entityId": "entity_123",
    "timestamp": "2024-01-15T10:00:00Z",
    "data": {
      "key": "value"
    }
  }' \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.4 Flexible Aggregate Data (Protected)
```bash
# Today's aggregation (hourly buckets)
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?today=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Week aggregation (from Monday of the given date to the date)
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?startDate=2025-01-20&week=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Month aggregation (4 weeks from the given date)
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?startDate=2025-07-12&month=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Custom date range
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?startDate=2025-01-01&endDate=2025-01-07" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Single date aggregation
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?startDate=2025-01-15" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.5 Monthly Data (Protected)
```bash
curl -X GET "http://dis.local:32080/api/acquisition/monthly?year=2024&month=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.6 Realtime Data (Protected)
```bash
curl -X GET http://dis.local:32080/api/acquisition/realtime \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.7 Realtime PDU Logs (Protected) ⭐ **NEW**
```bash
# Get PDU logs for the last hour
START_TIME=$(($(date +%s) - 3600))  # 1 hour ago
END_TIME=$(date +%s)               # Now

curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs?startTime=$START_TIME&endTime=$END_TIME" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Get PDU logs for a specific time range (Unix epoch timestamps)
curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs?startTime=1755580000&endTime=1755583200" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Get PDU logs for the last 24 hours
START_TIME_24H=$(($(date +%s) - 86400))
curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs?startTime=$START_TIME_24H&endTime=$(date +%s)" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

### 2.8 Metrics Overview (Protected)
```bash
# Default metrics (last 60 minutes)
curl -X GET http://dis.local:32080/api/acquisition/metrics \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Last 60 minutes metrics
curl -X GET "http://dis.local:32080/api/acquisition/metrics?period=last60minutes" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Last day metrics
curl -X GET "http://dis.local:32080/api/acquisition/metrics?period=lastDay" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## 3. Data Ingestion Service Endpoints

### 3.1 Health Check (Public)
```bash
curl -X GET http://dis.local:32080/api/ingestion/health \
  -w "\nHTTP Status: %{http_code}\n"
```

### 3.2 Ingest Data (Protected)
```bash
curl -X POST http://dis.local:32080/api/ingestion/data \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "source": "sensor_001",
    "timestamp": "2024-01-15T10:00:00Z",
    "data": {
      "temperature": 25.5,
      "humidity": 60.2,
      "pressure": 1013.25
    }
  }' \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## 4. Data Processing Service Endpoints

### 4.1 Health Check (Public)
```bash
curl -X GET http://dis.local:32080/api/processing/health \
  -w "\nHTTP Status: %{http_code}\n"
```

### 4.2 Process Data (Protected)
```bash
curl -X POST http://dis.local:32080/api/processing/process \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "dataId": "data_123",
    "processingType": "analysis",
    "parameters": {
      "algorithm": "linear_regression",
      "window_size": 100
    }
  }' \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## 5. Complete Authentication Flow Test

### Step-by-Step Authentication Test:

```bash
# Step 1: Register a new user
curl -X POST http://dis.local:32080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test.user.$(date +%s)@example.com","password":"TestPass123!","username":"testuser$(date +%s)"}' \
  -w "\nHTTP Status: %{http_code}\n"

# Step 2: Login to get JWT token
JWT_RESPONSE=$(curl -s -X POST http://dis.local:32080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test.user.$(date +%s)@example.com","password":"TestPass123!"}')

# Step 3: Extract token (manual step - copy token from response)
echo "JWT Response: $JWT_RESPONSE"

# Step 4: Use token for protected endpoint
curl -X GET http://dis.local:32080/api/users/profile \
  -H "Authorization: Bearer YOUR_EXTRACTED_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## 6. Error Testing Scenarios

### 6.1 Test Missing Authentication
```bash
curl -X GET http://dis.local:32080/api/users/profile \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** HTTP 401 Unauthorized

### 6.2 Test Invalid JWT Token
```bash
curl -X GET http://dis.local:32080/api/users/profile \
  -H "Authorization: Bearer invalid.jwt.token" \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** HTTP 401 Unauthorized

### 6.3 Test Duplicate Registration
```bash
# Register same email twice
curl -X POST http://dis.local:32080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"duplicate@example.com","password":"TestPass123!","username":"duplicate1"}' \
  -w "\nHTTP Status: %{http_code}\n"

curl -X POST http://dis.local:32080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"duplicate@example.com","password":"TestPass123!","username":"duplicate2"}' \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** Second request should return HTTP 400 with "EMAIL_EXISTS" error

### 6.4 Test Missing Required Fields
```bash
curl -X POST http://dis.local:32080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"incomplete@example.com","password":"TestPass123!"}' \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** HTTP 500 with "displayName cannot be null" error

### 6.5 Test Realtime/Logs Parameter Validation ⭐ **NEW**
```bash
# Missing startTime parameter (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs?endTime=1755583200" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Missing endTime parameter (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs?startTime=1755580000" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Missing both parameters (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Unauthorized access to realtime/logs (401 Unauthorized)
curl -X GET "http://dis.local:32080/api/acquisition/realtime/logs?startTime=1755580000&endTime=1755583200" \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** Various error responses for parameter validation and authentication failures

### 6.6 Test Aggregation Endpoints Parameter Validation ⭐ **NEW**
```bash
# Missing parameters for aggregate endpoint (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/aggregate" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Invalid date format (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?startDate=invalid-date&month=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Invalid month for monthly endpoint (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/monthly?year=2025&month=13" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Missing year parameter for monthly endpoint (400 Bad Request)
curl -X GET "http://dis.local:32080/api/acquisition/monthly?month=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -w "\nHTTP Status: %{http_code}\n"

# Unauthorized access to aggregation endpoints (401 Unauthorized)
curl -X GET "http://dis.local:32080/api/acquisition/aggregate?today=true" \
  -w "\nHTTP Status: %{http_code}\n"

curl -X GET "http://dis.local:32080/api/acquisition/monthly?year=2025&month=1" \
  -w "\nHTTP Status: %{http_code}\n"

curl -X GET "http://dis.local:32080/api/acquisition/metrics" \
  -w "\nHTTP Status: %{http_code}\n"
```
**Expected:** Various error responses for parameter validation and authentication failures

---

## 7. Kong Gateway Features Verification

### 7.1 Rate Limiting Test
```bash
# Make multiple rapid requests to test rate limiting
for i in {1..5}; do
  curl -X GET http://dis.local:32080/api/user/health \
    -w "\nRequest $i - HTTP Status: %{http_code}\n"
  sleep 0.1
done
```
**Expected:** Headers showing rate limit info:
- `X-RateLimit-Limit-Minute: 1000`
- `X-RateLimit-Remaining-Minute: 999`
- `X-RateLimit-Limit-Hour: 10000`

### 7.2 CORS Headers Test
```bash
curl -X OPTIONS http://dis.local:32080/api/user/health \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -v
```
**Expected:** CORS headers in response:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`

### 7.3 Kong Proxy Headers Test
```bash
curl -v -X GET http://dis.local:32080/api/user/health
```
**Expected Kong headers:**
- `X-Kong-Upstream-Latency`
- `X-Kong-Proxy-Latency`
- `Via: kong/3.4.2`

---

## 8. Quick Test Scripts

### 8.1 Full System Health Check
```bash
#!/bin/bash
echo "=== CAP System Health Check ==="
echo "User Service:"
curl -s http://dis.local:32080/api/user/health | jq .

echo -e "\nData Acquisition Service:"
curl -s http://dis.local:32080/api/acquisition/health | jq .

echo -e "\nData Ingestion Service:"
curl -s http://dis.local:32080/api/ingestion/health | jq .

echo -e "\nData Processing Service:"
curl -s http://dis.local:32080/api/processing/health | jq .
```

### 8.2 Authentication Flow Test
```bash
#!/bin/bash
TIMESTAMP=$(date +%s)
TEST_EMAIL="test.user.$TIMESTAMP@example.com"
TEST_USERNAME="testuser$TIMESTAMP"
TEST_PASSWORD="TestPass123!"

echo "=== Authentication Flow Test ==="
echo "Test Email: $TEST_EMAIL"

# Register
echo "1. Registering user..."
REGISTER_RESPONSE=$(curl -s -X POST http://dis.local:32080/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"username\":\"$TEST_USERNAME\"}")
echo "Register Response: $REGISTER_RESPONSE"

# Login
echo "2. Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST http://dis.local:32080/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")
echo "Login Response: $LOGIN_RESPONSE"

# Extract token
JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')
echo "JWT Token: ${JWT_TOKEN:0:50}..."

# Test protected endpoint
echo "3. Testing protected endpoint..."
PROFILE_RESPONSE=$(curl -s -X GET http://dis.local:32080/api/users/profile \
  -H "Authorization: Bearer $JWT_TOKEN")
echo "Profile Response: $PROFILE_RESPONSE"
```

---

## 9. Important Notes

### ✅ Working Endpoints (Verified)
- ✅ User registration with correct fields
- ✅ User login with JWT token generation
- ✅ Protected endpoints with JWT authentication
- ✅ Kong Gateway routing and headers
- ✅ Rate limiting and CORS

### 🔧 Required Fields
- **Registration:** `email`, `password`, `username` (all required)
- **Login:** `email`, `password`
- **Protected endpoints:** `Authorization: Bearer <jwt_token>` header

### 🚨 Common Issues
1. **Missing username field** → "displayName cannot be null" error
2. **Duplicate email** → "EMAIL_EXISTS" error
3. **Missing Authorization header** → HTTP 401
4. **Invalid JWT token** → HTTP 401

### 💡 Tips
- Use unique emails for each registration test
- Save JWT tokens for reuse in protected endpoint tests
- Check Kong headers to verify gateway functionality
- Use `-w "\nHTTP Status: %{http_code}\n"` to see status codes
- Use `-v` flag for verbose output including headers

---

**All endpoints are accessible through Kong Gateway at `http://dis.local:32080` with proper authentication, rate limiting, and CORS configured.**
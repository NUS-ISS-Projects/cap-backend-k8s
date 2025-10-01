# 3.2.4.4 Data Acquisition Service

The Data Acquisition Service is the primary interface for clients to retrieve both historical and real-time data from the platform. It is a Java/Spring Boot microservice that serves as the presentation layer, aggregating data from the PostgreSQL database and fetching live metrics from the Data Ingestion Service. The service is designed to be a stateless, scalable API provider that handles client queries efficiently without participating in the core ingestion pipeline, ensuring read operations do not impact real-time data processing.

## Service Overview

The Data Acquisition Service is a Java/Spring Boot microservice that manages:
- Comprehensive REST API for historical PDU data access across 10+ PDU types
- Real-time metrics integration with Data Ingestion Service
- Advanced aggregation and analytics capabilities for time-series data
- Optimized database queries with time-range filtering and pagination
- Integration with Kong Gateway for HTTP endpoint security
- Health monitoring and observability endpoints

## Architecture Integration

### Kong Gateway Integration
- Public endpoints: /api/acquisition/health (health monitoring)
- Protected endpoints: /api/acquisition/* (data access with Firebase JWT authentication)
- Automatic JWT validation at Kong Gateway level for protected endpoints
- CORS and rate limiting policies applied at gateway level
- User context forwarding via headers (X-User-ID, X-User-Email, X-Consumer-ID)

### Database Integration
- PostgreSQL read access for historical data across 10+ PDU record types
- Optimized JPA queries with time-range filtering using DIS absolute timestamps
- Spring Data JPA repositories for each PDU type with custom query methods
- Connection pooling and transaction management for high-performance reads

### Service-to-Service Communication
- HTTP integration with Data Ingestion Service for real-time metrics
- Internal endpoint communication: /internal/metrics/realtime
- RestTemplate-based service calls with error handling and fallback mechanisms

## Use Cases

The following table outlines the primary use cases for the Data Acquisition Service:

| Use Case ID | Name | Actor(s) | Description |
|-------------|------|----------|-------------|
| UC-ACQ-01 | Query Historical PDU Data | Client / UI | Requests raw PDU data (EntityState, Fire, Collision, Detonation, Data, ActionRequest, StartResume, SetData, Designator, ElectromagneticEmissions) for specified time ranges using DIS absolute timestamps |
| UC-ACQ-02 | Request Aggregated Metrics | Client / UI | Requests aggregated metrics (total packets, average rate, peak load) for predefined periods (last60minutes, today, custom ranges) with comprehensive PDU type breakdowns |
| UC-ACQ-03 | Request Real-time Metrics | Client / UI | Requests latest PDU ingestion statistics by calling Data Ingestion Service's internal metrics endpoint for live data presentation |
| UC-ACQ-04 | Request Data by Date Range | Client / UI | Requests aggregated PDU counts for custom date ranges, monthly views, or weekly aggregations with flexible time window support |
| UC-ACQ-05 | Query Real-time Logs | Client / UI | Requests recent PDU activity logs with timestamp filtering for debugging and monitoring purposes |
| UC-ACQ-06 | Provide Health Status | Kubernetes, Kong Gateway | Provides health check endpoint (/api/acquisition/health) for Kubernetes probes and Kong Gateway routing |
| UC-ACQ-07 | Handle Multiple PDU Types | Client / UI | Supports comprehensive querying across 10+ different DIS PDU types with type-specific filtering and aggregation |

## API Endpoints

### Public Endpoints (No Authentication Required)

**Health Check**
- GET /api/acquisition/health
- Response: Service health status for Kubernetes probes and monitoring

### Protected Endpoints (Firebase JWT Required via Kong Gateway)

**Historical PDU Data Endpoints**
- GET /api/acquisition/entity-states?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/fire-events?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/collision-events?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/detonation-events?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/data-pdus?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/action-request-pdus?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/start-resume-pdus?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/set-data-pdus?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/designator-pdus?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/electromagnetic-emissions-pdus?startTime={timestamp}&endTime={timestamp}

**Aggregated Data Endpoints**
- GET /api/acquisition/aggregate?today=true
- GET /api/acquisition/aggregate?startDate={date}&endDate={date}
- GET /api/acquisition/aggregate?startDate={date}&week=true
- GET /api/acquisition/aggregate?startDate={date}&month=true
- GET /api/acquisition/monthly?year={year}&month={month}

**Real-time and Metrics Endpoints**
- GET /api/acquisition/realtime
- GET /api/acquisition/realtime/logs?startTime={timestamp}&endTime={timestamp}
- GET /api/acquisition/metrics?period={timeWindow}

**Headers**: Authorization: Bearer {firebase_jwt_token} (validated by Kong Gateway)

## Technical Implementation

### Controller Architecture
- HistoricalDataController.java: Main REST controller with comprehensive endpoint mapping
- Dependency injection of 10+ JPA repositories for different PDU types
- MetricsService integration for complex aggregations and analytics
- RealTimeMetricsService integration for live data fetching
- Comprehensive logging and error handling for all endpoints

### Service Layer Architecture
- MetricsService.java: Advanced aggregation logic with time-window calculations
- RealTimeMetricsService.java: HTTP client for Data Ingestion Service integration
- Custom aggregation algorithms for peak load detection and rate calculations
- Time-series data processing with DIS timestamp conversion utilities

### Repository Layer
**Comprehensive PDU Repository Support:**
- EntityStateRepository.java: Entity state and position data access
- FireEventRepository.java: Fire event and weapon discharge data access
- CollisionRepository.java: Collision detection and response data access
- DetonationRepository.java: Explosion and detonation event data access
- DataPduRepository.java: General data transmission PDU access
- ActionRequestPduRepository.java: Action request and command PDU access
- StartResumePduRepository.java: Simulation control PDU access
- SetDataPduRepository.java: Data setting and configuration PDU access
- DesignatorPduRepository.java: Target designation and marking PDU access
- ElectromagneticEmissionsPduRepository.java: Electronic warfare PDU access

### Data Models and DTOs
- AggregatedMetricsOverview.java: Comprehensive metrics aggregation DTO
- RealTimeMetrics.java: Live ingestion statistics DTO
- PduLogResponse.java: Real-time log response wrapper
- MonthlyAggregation.java: Monthly statistics aggregation DTO
- CustomRangeAggregation.java: Flexible time-range aggregation DTO
- TimeBucketAggregation.java: Time-bucketed analytics DTO

### Database Query Optimization
- Custom JPA query methods with findByTimestampBetween for time-range filtering
- DIS absolute timestamp handling and conversion utilities
- Optimized database indexing on timestamp columns for performance
- Connection pooling and transaction management for concurrent read operations

## Testing and Quality Assurance

### Comprehensive Test Coverage
The Data Acquisition Service includes 4 comprehensive test files covering all major components:

**Application Tests (1 file):**
- DataAcquisitionApplicationTests.java: Full application context testing

**Controller Tests (1 file):**
- HistoricalDataControllerTest.java: REST endpoint testing with @WebMvcTest

**Service Tests (2 files):**
- MetricsServiceTest.java: Aggregation logic and time-series calculations testing
- RealTimeMetricsServiceTest.java: Service-to-service communication and HTTP client testing

### Quality Metrics
- JaCoCo code coverage reporting integration
- SonarCloud static code analysis
- Automated test execution in CI/CD pipeline
- Part of platform-wide 75 unit and integration tests across all services

## Deployment Configuration

### Container Specifications
- Image: ghcr.io/nus-iss-projects/cap-backend-data-acquisition/cap-backend-data-acquisition:latest
- Ports: HTTP 8080
- Resources: CPU 100m-300m, Memory 384Mi-768Mi
- Health Probes: /api/acquisition/health (60s readiness, 90s liveness initial delay)

### Environment Variables
- SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/dis_db
- SPRING_DATASOURCE_USERNAME: dis_user
- SPRING_DATASOURCE_PASSWORD: dis_pass
- metrics.dataIngestion.service.url: http://data-ingestion-service:8080

### Horizontal Pod Autoscaling
- HPA Configuration: 1-2 replicas, 85% CPU utilization threshold
- Automatic scaling based on API request load and database query demands

## Performance Optimizations

### Database Query Performance
- Optimized JPA queries with time-range filtering on indexed timestamp columns
- Custom repository methods for efficient data retrieval across PDU types
- Connection pooling for concurrent read operations
- Lazy loading and pagination support for large datasets

### Service Integration Performance
- RestTemplate configuration with connection pooling for Data Ingestion Service calls
- Caching strategies for frequently accessed aggregation data
- Asynchronous processing capabilities for non-blocking operations
- Error handling and circuit breaker patterns for service resilience

### API Response Optimization
- Efficient JSON serialization with optimized DTOs
- Compression support for large response payloads
- Time-series data aggregation at database level to minimize data transfer
- Pagination and filtering support for large result sets

## Integration with Platform Services

### Kong Gateway Integration
- Centralized HTTP endpoint management with Firebase JWT authentication
- Health endpoint exposure for monitoring and probes
- Protected data endpoints with authentication and user context forwarding
- CORS and rate limiting policies for external client access

### Data Ingestion Service Integration
- Real-time metrics fetching via internal HTTP endpoint
- Service-to-service communication for live data presentation
- Error handling and fallback mechanisms for service unavailability
- Integration with internal metrics endpoint (/internal/metrics/realtime)

### Database Integration
- PostgreSQL read access for 10+ structured PDU record types
- JPA/Hibernate ORM for entity management and query optimization
- Time-series data access with DIS timestamp handling
- Optimized queries and indexing for high-performance reads

### Monitoring and Observability
- Standardized health endpoints for Kubernetes probes
- Comprehensive logging for API requests and database operations
- Performance metrics for query response times and throughput
- Integration with platform monitoring systems

### CI/CD Integration
- GitHub Actions pipeline with automated building and testing
- Container image creation and publishing to GHCR
- Kubernetes deployment with rollout verification
- Automated rollback capabilities for failed deployments

## Production Deployment

### Container Specifications
- Base Image: openjdk:17-jdk
- Application JAR: dataAcquisition-0.0.1-SNAPSHOT.jar
- Exposed Port: 8080 (HTTP)
- Health Check Endpoint: /api/acquisition/health

### Environment-Specific Configurations
**Local Development:**
- Image: cap-backend-data-acquisition:latest with imagePullPolicy: Never
- Local PostgreSQL connections and Data Ingestion Service integration

**Staging Environment:**
- LoadBalancer service with moderate rate limiting
- Firebase JWT authentication for protected endpoints
- DAST security scanning integration

**Production Environment:**
- Enhanced security and high-availability configurations
- Optimized resource allocation for high-throughput API serving
- Comprehensive monitoring and alerting

### Scalability and Performance
- HPA Configuration: 1-2 replicas based on 85% CPU utilization
- Automatic scaling based on API request load and database query demands
- Resource allocation: CPU 100m-300m, Memory 384Mi-768Mi
- Health probes with 60s readiness and 90s liveness initial delay

## Figures

**Figure 3.2.4.4.a: UML Class Diagram**

**Figure 3.2.4.4.b: Request for Aggregated Metrics**